<#
.SYNOPSIS
    GUI-Tool zur Überprüfung und Korrektur von AD-Attributen (DisplayName, dNSHostName, Description)
    nach einer Computer-Umbenennung für sauberen Microsoft Entra ID Sync.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# -------------------------------------------------------------
# 1. XAML GUI Definition
# -------------------------------------------------------------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AD Client Rename Inspector &amp; Fix Tool" Height="620" Width="780"
        WindowStartupLocation="CenterScreen" Background="#F4F6F9" FontFamily="Segoe UI" FontSize="13">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Suchbereich -->
        <Border Grid.Row="0" Background="White" CornerRadius="5" Padding="12" Margin="0,0,0,10" BorderBrush="#D1D5DB" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Computername:" VerticalAlignment="Center" FontWeight="SemiBold" Margin="0,0,10,0"/>
                <TextBox Grid.Column="1" Name="TxtComputer" VerticalContentAlignment="Center" Height="28" Padding="5,0,0,0" ToolTip="Neuer PC-Name (z.B. PC123)"/>
                <Button Grid.Column="2" Name="BtnCheck" Content="  Prüfen  " Height="28" Margin="10,0,0,0" Background="#2563EB" Foreground="White" FontWeight="SemiBold"/>
            </Grid>
        </Border>

        <!-- Status / Attributübersicht -->
        <Border Grid.Row="1" Background="White" CornerRadius="5" Padding="12" Margin="0,0,0,10" BorderBrush="#D1D5DB" BorderThickness="1">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="130"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="120"/>
                </Grid.ColumnDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="sAMAccountName:" FontWeight="SemiBold" Margin="0,3,0,3"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="LblSam" Text="-" Margin="0,3,0,3" Foreground="#374151"/>

                <TextBlock Grid.Row="1" Grid.Column="0" Text="displayName:" FontWeight="SemiBold" Margin="0,3,0,3"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="LblDisplayName" Text="-" Margin="0,3,0,3" Foreground="#374151"/>
                <TextBlock Grid.Row="1" Grid.Column="2" Name="LblDisplayNameStatus" Text="" FontWeight="Bold" Margin="0,3,0,3"/>

                <TextBlock Grid.Row="2" Grid.Column="0" Text="dNSHostName:" FontWeight="SemiBold" Margin="0,3,0,3"/>
                <TextBlock Grid.Row="2" Grid.Column="1" Name="LblDnsHostName" Text="-" Margin="0,3,0,3" Foreground="#374151"/>
                <TextBlock Grid.Row="2" Grid.Column="2" Name="LblDnsStatus" Text="" FontWeight="Bold" Margin="0,3,0,3"/>

                <TextBlock Grid.Row="3" Grid.Column="0" Text="Description:" FontWeight="SemiBold" Margin="0,3,0,3"/>
                <TextBlock Grid.Row="3" Grid.Column="1" Grid.ColumnSpan="2" Name="LblDescription" Text="-" TextWrapping="Wrap" Margin="0,3,0,3" Foreground="#374151"/>
            </Grid>
        </Border>

        <!-- Log / Befehlsausgabe -->
        <Border Grid.Row="2" Background="White" CornerRadius="5" Padding="10" Margin="0,0,0,10" BorderBrush="#D1D5DB" BorderThickness="1">
            <DockPanel>
                <TextBlock DockPanel.Dock="Top" Text="Aktivitäten / Empfohlene Befehle:" FontWeight="SemiBold" Margin="0,0,0,5"/>
                <TextBox Name="TxtLog" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" 
                         FontFamily="Consolas" FontSize="11" Background="#1E1E1E" Foreground="#D4D4D4" Padding="8"/>
            </DockPanel>
        </Border>

        <!-- Aktions-Buttons -->
        <Border Grid.Row="3" Background="White" CornerRadius="5" Padding="10" BorderBrush="#D1D5DB" BorderThickness="1">
            <WrapPanel HorizontalAlignment="Right">
                <Button Name="BtnFixAD" Content="AD-Attribute korrigieren" Height="32" Padding="12,0,12,0" Margin="5,0,0,0" 
                        Background="#059669" Foreground="White" FontWeight="SemiBold" IsEnabled="False"/>
                <Button Name="BtnTriggerEntra" Content="Entra Connect Sync triggern" Height="32" Padding="12,0,12,0" Margin="5,0,0,0" 
                        Background="#4B5563" Foreground="White" FontWeight="SemiBold"/>
                <Button Name="BtnClientInfo" Content="Client dsregcmd Befehle" Height="32" Padding="12,0,12,0" Margin="5,0,0,0" 
                        Background="#3B82F6" Foreground="White" FontWeight="SemiBold"/>
            </WrapPanel>
        </Border>
    </Grid>
</Window>
"@

# -------------------------------------------------------------
# 2. GUI Loader & Controls
# -------------------------------------------------------------
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$TxtComputer          = $window.FindName("TxtComputer")
$BtnCheck             = $window.FindName("BtnCheck")
$LblSam               = $window.FindName("LblSam")
$LblDisplayName       = $window.FindName("LblDisplayName")
$LblDisplayNameStatus = $window.FindName("LblDisplayNameStatus")
$LblDnsHostName       = $window.FindName("LblDnsHostName")
$LblDnsStatus         = $window.FindName("LblDnsStatus")
$LblDescription       = $window.FindName("LblDescription")
$TxtLog               = $window.FindName("TxtLog")
$BtnFixAD             = $window.FindName("BtnFixAD")
$BtnTriggerEntra      = $window.FindName("BtnTriggerEntra")
$BtnClientInfo        = $window.FindName("BtnClientInfo")

# Variablen für Session
$script:CurrentADObj = $null
$script:DomainDns    = $null

try {
    $script:DomainDns = (Get-ADDomain).DNSRoot.ToLower()
} catch {
    $script:DomainDns = ""
}

function Log-Gui {
    param([string]$Msg)
    $ts = Get-Date -Format "HH:mm:ss"
    $TxtLog.AppendText("[$ts] $Msg`r`n")
    $TxtLog.ScrollToEnd()
}

# -------------------------------------------------------------
# 3. Logik: AD-Objekt prüfen
# -------------------------------------------------------------
$BtnCheck.Add_Click({
    $SearchName = $TxtComputer.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($SearchName)) {
        [System.Windows.MessageBox]::Show("Bitte einen Computernamen eingeben!", "Eingabe fehlt", 0, 48)
        return
    }

    Log-Gui "Suche nach Computer-Objekt '$SearchName' im Active Directory..."

    try {
        $comp = Get-ADComputer -Filter "Name -eq '$SearchName' -or sAMAccountName -eq '$SearchName$' -or sAMAccountName -eq '$SearchName'" `
                               -Properties DisplayName, dNSHostName, Description, sAMAccountName, ObjectGUID -ErrorAction Stop

        if (-not $comp) {
            Log-Gui "[-] Kein Computerobjekt für '$SearchName' gefunden."
            $BtnFixAD.IsEnabled = $false
            return
        }

        $script:CurrentADObj = $comp
        $CleanName = $comp.Name

        # GUI befüllen
        $LblSam.Text = $comp.sAMAccountName
        $LblDisplayName.Text = if ($comp.DisplayName) { $comp.DisplayName } else { "<NICHT GESETZT>" }
        $LblDnsHostName.Text = if ($comp.dNSHostName) { $comp.dNSHostName } else { "<NICHT GESETZT>" }
        $LblDescription.Text = if ($comp.Description) { $comp.Description } else { "<LEER>" }

        # DisplayName Prüfung
        if ([string]::IsNullOrWhiteSpace($comp.DisplayName)) {
            $LblDisplayNameStatus.Text = "[!] Fehlt"
            $LblDisplayNameStatus.Foreground = [System.Windows.Media.Brushes]::Red
            Log-Gui "[WARNUNG] 'displayName' ist leer! Entra Connect nutzt Fallback '$($comp.sAMAccountName)'."
        } elseif ($comp.DisplayName.EndsWith('$')) {
            $LblDisplayNameStatus.Text = "[!] Hat $"
            $LblDisplayNameStatus.Foreground = [System.Windows.Media.Brushes]::Red
            Log-Gui "[FEHLER] 'displayName' endet mit '$' -> Entra zeigt Dollarzeichen."
        } elseif ($comp.DisplayName -ne $CleanName) {
            $LblDisplayNameStatus.Text = "[!] Abweichend"
            $LblDisplayNameStatus.Foreground = [System.Windows.Media.Brushes]::Orange
            Log-Gui "[WARNUNG] 'displayName' ($($comp.DisplayName)) weicht von Name ($CleanName) ab."
        } else {
            $LblDisplayNameStatus.Text = "[OK]"
            $LblDisplayNameStatus.Foreground = [System.Windows.Media.Brushes]::Green
        }

        # dNSHostName Prüfung
        $ExpectedDns = "$CleanName.$($script:DomainDns)".ToLower()
        if ([string]::IsNullOrWhiteSpace($comp.dNSHostName) -or $comp.dNSHostName.ToLower() -ne $ExpectedDns) {
            $LblDnsStatus.Text = "[!] Falsch"
            $LblDnsStatus.Foreground = [System.Windows.Media.Brushes]::Red
            Log-Gui "[WARNUNG] dNSHostName ('$($comp.dNSHostName)') entspricht nicht Erwartung ('$ExpectedDns')."
        } else {
            $LblDnsStatus.Text = "[OK]"
            $LblDnsStatus.Foreground = [System.Windows.Media.Brushes]::Green
        }

        $BtnFixAD.IsEnabled = $true
        Log-Gui "[+] Objekt erfolgreich geladen. Bereit für Aktionen."

    } catch {
        Log-Gui "[-] Fehler beim Abfragen des AD-Objekts: $($_.Exception.Message)"
        $BtnFixAD.IsEnabled = $false
    }
})

# -------------------------------------------------------------
# 4. Logik: AD-Attribute korrigieren
# -------------------------------------------------------------
$BtnFixAD.Add_Click({
    if (-not $script:CurrentADObj) { return }

    $comp = $script:CurrentADObj
    $CleanName = $comp.Name
    $ExpectedDns = "$CleanName.$($script:DomainDns)".ToLower()
    $User = "$env:USERDOMAIN\$env:USERNAME"
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $LogEntry = "Korrektur am $Timestamp durch $User"

    $NewDescription = if ([string]::IsNullOrWhiteSpace($comp.Description)) {
        $LogEntry
    } else {
        "$($comp.Description) | $LogEntry"
    }

    try {
        Log-Gui "Korrigiere AD-Attribute fuer '$CleanName'..."

        Set-ADComputer -Identity $comp.DistinguishedName `
                       -DisplayName $CleanName `
                       -dNSHostName $ExpectedDns `
                       -Description $NewDescription `
                       -ErrorAction Stop

        Log-Gui "[ERFOLG] Attribute im AD erfolgreich aktualisiert:"
        Log-Gui "   -> displayName = '$CleanName'"
        Log-Gui "   -> dNSHostName = '$ExpectedDns'"
        Log-Gui "   -> Description ergänzt um: '$LogEntry'"

        # UI aktualisieren
        $LblDisplayName.Text = $CleanName
        $LblDisplayNameStatus.Text = "[OK]"
        $LblDisplayNameStatus.Foreground = [System.Windows.Media.Brushes]::Green

        $LblDnsHostName.Text = $ExpectedDns
        $LblDnsStatus.Text = "[OK]"
        $LblDnsStatus.Foreground = [System.Windows.Media.Brushes]::Green

        $LblDescription.Text = $NewDescription

        [System.Windows.MessageBox]::Show("AD-Attribute wurden erfolgreich bereinigt!`n`nDisplayName: $CleanName`ndNSHostName: $ExpectedDns", "Erfolg", 0, 64)
    }
    catch {
        Log-Gui "[-] Fehler beim Setzen der AD-Attribute: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Fehler beim Aktualisieren: $($_.Exception.Message)", "Fehler", 0, 16)
    }
})

# -------------------------------------------------------------
# 5. Logik: Entra Connect Sync per PowerShell triggern
# -------------------------------------------------------------
$BtnTriggerEntra.Add_Click({
    $SyncServer = [Microsoft.VisualBasic.Interaction]::InputBox("Name des Entra Connect Servers eingeben (oder 'localhost' falls lokal ausgeführt):", "Entra Sync Server", "localhost")
    if ([string]::IsNullOrWhiteSpace($SyncServer)) { return }

    Log-Gui "Starte Delta-Sync auf Server '$SyncServer'..."

    try {
        if ($SyncServer -eq "localhost" -or $SyncServer -eq $env:COMPUTERNAME) {
            Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
        } else {
            Invoke-Command -ComputerName $SyncServer -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } -ErrorAction Stop
        }
        Log-Gui "[ERFOLG] Entra Connect Delta-Sync wurde erfolgreich angestoßen!"
        [System.Windows.MessageBox]::Show("Delta-Sync wurde erfolgreich gestartet! Die Werte sollten in ca. 2-5 Minuten im Entra Portal ankommen.", "Sync gestartet", 0, 64)
    }
    catch {
        Log-Gui "[-] Fehler beim Triggern des Syncs: $($_.Exception.Message)"
        Log-Gui "[TIPP] Führe auf dem Entra-Server direkt aus: Start-ADSyncSyncCycle -PolicyType Delta"
    }
})

# -------------------------------------------------------------
# 6. Logik: Client-Befehle ausgeben
# -------------------------------------------------------------
$BtnClientInfo.Add_Click({
    $pc = if ($script:CurrentADObj) { $script:CurrentADObj.Name } else { "<CLIENT_NAME>" }

    Log-Gui "=========================================================="
    Log-Gui "MANUELLE BEFEHLE FÜR DEN CLIENT ($pc):"
    Log-Gui "----------------------------------------------------------"
    Log-Gui "1. Prüfen, ob der Client den neuen Namen an Entra meldet:"
    Log-Gui "   dsregcmd /status"
    Log-Gui "   (Unter 'Diagnostic Data' muss 'HostNameUpdated : YES' stehen)"
    Log-Gui ""
    Log-Gui "2. Entra-Join-Task am Client sofort triggern (Admin CMD):"
    Log-Gui "   schtasks /run /tn `"\Microsoft\Windows\Workplace Join\Automatic-Device-Join`""
    Log-Gui ""
    Log-Gui "3. Sofortige Intune-Synchronisation am Client anstoßen:"
    Log-Gui "   schtasks /run /tn `"\Microsoft\Windows\EnterpriseMgmt\*PushLaunch`""
    Log-Gui "   Restart-Service IntuneManagementExtension"
    Log-Gui "=========================================================="
})

# -------------------------------------------------------------
# 7. Start GUI
# -------------------------------------------------------------
# Microsoft.VisualBasic für InputBox laden
Add-Type -AssemblyName Microsoft.VisualBasic
$window.ShowDialog() | Out-Null
