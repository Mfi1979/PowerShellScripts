<#
================================================================================
 START-POWERSHELLSCRIPTS: Bilingual Hub & Launcher (DE / EN)
 - Interaktives Einstellungs-GUI für alle Schriftgrößen & Zeilenabstände
 - Rich Code-Viewer mit Zeilennummern & großer Darstellung
 - Hybrid-Betrieb: Live von GitHub oder aus lokalem Verzeichnis
================================================================================
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ==============================================================================
# 0. ZENTRALE GUI-KONFIGURATION
# ==============================================================================
$script:DefaultGuiConfig = @{
    FontFamily         = "Segoe UI"
    TitleFontSize      = 12.0
    ButtonFontSize     = 9.5
    InputFontSize      = 10.5
    ComboFontSize      = 10.0
    LabelFontSize      = 10.0
    GridHeaderFontSize = 10.0
    GridRowFontSize    = 10.0
    GridRowHeight      = 32     # Zeilenhöhe gegen abgeschnittenen Text
    GridHeaderHeight   = 36     # Spaltenkopfhöhe
    ActionButtonSize   = 10.5
    CodeFontFamily     = "Consolas"
    CodeFontSize       = 13.0
    DetailsFontSize    = 11.5   # Große Darstellung für Detailbox unten
}

# Arbeitskopie
$script:GuiConfig = $script:DefaultGuiConfig.Clone()

# -------------------------------------------------------------
# 1. Pfade & Mehrsprachigkeits-Wörterbuch (DE / EN)
# -------------------------------------------------------------
$script:BaseRawUrl  = "https://raw.githubusercontent.com/Mfi1979/PowerShellScripts/main"
$script:RootPath    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:CurrentLang = "DE"

$script:I18N = @{
    "DE" = @{
        "Title"          = "PowerShell Script Hub & Launcher"
        "CategoryFilter" = "Kategorie-Filter:"
        "Search"         = "Suche / Filter:"
        "ColName"        = "Dateiname"
        "ColCategory"    = "Kategorie"
        "ColType"        = "Typ"
        "ColDesc"        = "Beschreibung"
        "BtnRun"         = "▶  Skript ausführen"
        "BtnView"        = "📄 Code / Inhalt anzeigen"
        "BtnFontDlg"     = "🗚 Schriftgrößen anpassen"
        "DetailsTitle"   = "Dateidetails & Beschreibung:"
        "AllCategories"  = "Alle Kategorien"
        "ErrDownload"    = "Fehler beim Laden/Ausführen der Datei:`n"
        "BtnCopyCode"    = "In Zwischenablage kopieren"
        "BtnClose"       = "Schließen"
        "CopiedMsg"      = "Code wurde in die Zwischenablage kopiert!"
        "DlgFontTitle"   = "Schriftgrößen & Abstände konfigurieren"
        "DlgApply"       = "✔ Übernehmen"
        "DlgReset"       = "↺ Standardwerte"
        "DlgCancel"      = "Abbrechen"
        "LblFontTitle"   = "1. Titelleiste (pt):"
        "LblFontFilter"  = "2. Filter & Suche Eingabefelder (pt):"
        "LblFontTable"   = "3. Tabellentext & Header (pt):"
        "LblFontRowH"    = "4. Tabellen-Zeilenhöhe (px):"
        "LblFontDetails" = "5. Detail-Beschreibung unten (pt):"
        "LblFontCode"    = "6. Code-Viewer Fenster (pt):"
    }
    "EN" = @{
        "Title"          = "PowerShell Script Hub & Launcher"
        "CategoryFilter" = "Category Filter:"
        "Search"         = "Search / Filter:"
        "ColName"        = "File Name"
        "ColCategory"    = "Category"
        "ColType"        = "Type"
        "ColDesc"        = "Description"
        "BtnRun"         = "▶  Run Script"
        "BtnView"        = "📄 View Code / Content"
        "BtnFontDlg"     = "🗚 Adjust Font Sizes"
        "DetailsTitle"   = "File Details & Description:"
        "AllCategories"  = "All Categories"
        "ErrDownload"    = "Error loading or running file:`n"
        "BtnCopyCode"    = "Copy to Clipboard"
        "BtnClose"       = "Close"
        "CopiedMsg"      = "Code copied to clipboard!"
        "DlgFontTitle"   = "Configure Font Sizes & Row Spacing"
        "DlgApply"       = "✔ Apply"
        "DlgReset"       = "↺ Reset Defaults"
        "DlgCancel"      = "Cancel"
        "LblFontTitle"   = "1. Title Header (pt):"
        "LblFontFilter"  = "2. Filter & Search Inputs (pt):"
        "LblFontTable"   = "3. Table Rows & Headers (pt):"
        "LblFontRowH"    = "4. Table Row Height (px):"
        "LblFontDetails" = "5. Details Area Bottom (pt):"
        "LblFontCode"    = "6. Code Viewer Window (pt):"
    }
}

function Get-Text([string]$Key) { return $script:I18N[$script:CurrentLang][$Key] }

# Skript-Inventar
$script:FileDatabase = @(
    [PSCustomObject]@{ Name = "AD_AdminAudit.ps1"; Category = "Active Directory"; Type = "PowerShell"; Desc_DE = "Audit privilegierter AD-Admin-Accounts und Gruppenmitgliedschaften."; Desc_EN = "Audit privileged AD administrative accounts and group memberships." },
    [PSCustomObject]@{ Name = "AD_Computer.txt"; Category = "Active Directory"; Type = "Snippet"; Desc_DE = "LDAP- und AD-Abfragen zur Filterung von Domänencomputern."; Desc_EN = "LDAP/AD query snippets for domain computer objects." },
    [PSCustomObject]@{ Name = "AD_DomainForest.txt"; Category = "Active Directory"; Type = "Snippet"; Desc_DE = "Auslesen von Domänen-, Gesamtstruktur- und FSMO-Rolleninformationen."; Desc_EN = "Retrieves Forest, Domain mode, and FSMO role holders." },
    [PSCustomObject]@{ Name = "AD_GPOBackup_alle.txt"; Category = "GPO & Backup"; Type = "Snippet"; Desc_DE = "Massen-Export aller GPOs in ein lokales Backup-Ziel."; Desc_EN = "Mass export snippet for backing up all domain GPOs." },
    [PSCustomObject]@{ Name = "AD_GPOBackup_eine.txt"; Category = "GPO & Backup"; Type = "Snippet"; Desc_DE = "Befehl zur Sicherung einer einzelnen Gruppenrichtlinie."; Desc_EN = "Snippet to backup a single Group Policy Object." },
    [PSCustomObject]@{ Name = "AD_GetAdUser.txt"; Category = "Active Directory"; Type = "Snippet"; Desc_DE = "LDAP-Filterbeispiele für Active Directory Benutzerabfragen."; Desc_EN = "LDAP filter examples for querying AD user objects." },
    [PSCustomObject]@{ Name = "AD_GlassBreakAccount_Readiness_Score.ps1"; Category = "Security & AD"; Type = "PowerShell"; Desc_DE = "Sicherheitsprüfung und Scoring für Notfall-Konten (Break-Glass)."; Desc_EN = "Readiness validation and scoring for break-glass emergency accounts." },
    [PSCustomObject]@{ Name = "AD_Group.txt"; Category = "Active Directory"; Type = "Snippet"; Desc_DE = "Abfragen für AD-Sicherheitsgruppen und Mitglieder."; Desc_EN = "Queries for analyzing AD security groups and memberships." },
    [PSCustomObject]@{ Name = "AD_Module.txt"; Category = "Setup"; Type = "Snippet"; Desc_DE = "Import- und Überprüfungsbefehle für das ActiveDirectory-Modul."; Desc_EN = "Import and check commands for the ActiveDirectory module." },
    [PSCustomObject]@{ Name = "AD_OUs.txt"; Category = "Active Directory"; Type = "Snippet"; Desc_DE = "Ermittlung und Strukturübersicht von Organisationseinheiten (OUs)."; Desc_EN = "Listing and hierarchy queries for Organizational Units (OUs)." },
    [PSCustomObject]@{ Name = "AD_User_lastPWDchange.txt"; Category = "Identity & Audit"; Type = "Snippet"; Desc_DE = "Filterung von Benutzern nach Datum der letzten Kennwortänderung."; Desc_EN = "Queries filtering user accounts by password last set date." },
    [PSCustomObject]@{ Name = "AD_User_noPWDchange.txt"; Category = "Identity & Audit"; Type = "Snippet"; Desc_DE = "Identifiziert Konten mit 'Kennwort läuft nie ab' Flag."; Desc_EN = "Filters user accounts with 'Password Never Expires' flag." },
    [PSCustomObject]@{ Name = "Bitlockerkey_WriteAzure.ps1"; Category = "Cloud & Security"; Type = "PowerShell"; Desc_DE = "Sichert BitLocker-Wiederherstellungsschlüssel in Microsoft Entra ID / Azure AD."; Desc_EN = "Backs up local BitLocker keys directly to Microsoft Entra ID." },
    [PSCustomObject]@{ Name = "Client_ComplianceCheck.ps1"; Category = "Client Security"; Type = "PowerShell"; Desc_DE = "Überprüft TPM 2.0, SecureBoot, Antivirus und OS-Compliance."; Desc_EN = "Checks local system health (TPM 2.0, SecureBoot, Defender, OS)." },
    [PSCustomObject]@{ Name = "GPOBackup.ps1"; Category = "GPO & Backup"; Type = "PowerShell"; Desc_DE = "Automatisiertes GPO-Backup-Skript mit Zeitstempel-Ordnern."; Desc_EN = "Automated GPO backup script creating timestamped archives." },
    [PSCustomObject]@{ Name = "GPOStatus_All.ps1"; Category = "GPO & Backup"; Type = "PowerShell"; Desc_DE = "Vollständige Statusanalyse aller GPOs (Aktiv, Verknüpft, WMI-Filter)."; Desc_EN = "Analyzes state and link status of all domain GPOs." },
    [PSCustomObject]@{ Name = "GPOStatus_One.ps1"; Category = "GPO & Backup"; Type = "PowerShell"; Desc_DE = "Detailanalyse einer spezifischen GPO."; Desc_EN = "Detailed inspection for a specific GPO." },
    [PSCustomObject]@{ Name = "Get-RemoteProgram_Export.ps1"; Category = "Inventory"; Type = "PowerShell"; Desc_DE = "Inventarisiert installierte Software remote via WMI/Registry mit Export."; Desc_EN = "Inventories installed programs via remote registry/WMI." },
    [PSCustomObject]@{ Name = "HotFix_Windows.txt"; Category = "Patch Mgmt"; Type = "Snippet"; Desc_DE = "Befehle zur Abfrage installierter Windows Hotfixes & KBs."; Desc_EN = "Commands to query installed Windows updates and Hotfix IDs." },
    [PSCustomObject]@{ Name = "IPInventory.ps1"; Category = "Network"; Type = "PowerShell"; Desc_DE = "Subnetz-Scanner mit Ping-Sweep und DNS-Namensauflösung."; Desc_EN = "Subnet scanner performing live ping sweeps and DNS resolution." },
    [PSCustomObject]@{ Name = "Server_TLS12_check.txt"; Category = "Hardening"; Type = "Snippet"; Desc_DE = "Registry-Prüfung auf aktivierte TLS 1.0/1.1/1.2 Protokolle."; Desc_EN = "Registry verification for enabled TLS 1.0, 1.1, and 1.2 settings." },
    [PSCustomObject]@{ Name = "Server_TLS12_Set.txt"; Category = "Hardening"; Type = "Snippet"; Desc_DE = "Registry-Härtung zur Erzwingung von TLS 1.2."; Desc_EN = "Registry hardening script enforcing TLS 1.2 standard." },
    [PSCustomObject]@{ Name = "Software-7zip-VersionCheck.ps1"; Category = "Patch Mgmt"; Type = "PowerShell"; Desc_DE = "Prüft die installierte 7-Zip Version auf Sicherheitsaktualität."; Desc_EN = "Audits installed 7-Zip versions for patch management." },
    [PSCustomObject]@{ Name = "WindowsUpdateCheck.txt"; Category = "Patch Mgmt"; Type = "Snippet"; Desc_DE = "Befehle zur Prüfung anstehender Windows-Updates."; Desc_EN = "Queries pending Windows updates via PowerShell/COM." }
)

function Get-ScriptOrSnippetContent([string]$FileName) {
    $localPath = [System.IO.Path]::Combine($script:RootPath, $FileName)
    if (Test-Path -LiteralPath $localPath) {
        $raw = Get-Content -LiteralPath $localPath -Raw -Encoding UTF8
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $url = "$($script:BaseRawUrl)/$FileName"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "PowerShellScriptHub")
        $wc.Encoding = [System.Text.Encoding]::UTF8
        $raw = $wc.DownloadString($url)
    }

    if ($raw) {
        return ($raw -replace "`r`n", "`n" -replace "`r", "`n" -replace "`n", "`r`n")
    }
    return ""
}

# -------------------------------------------------------------
# 2. EINSTELLUNGS-GUI: SCHRIFTGRÖSSEN & ZEILENABSTÄNDE
# -------------------------------------------------------------
function Show-FontSettingsDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = Get-Text "DlgFontTitle"
    $dlg.Size = New-Object System.Drawing.Size(560, 480)
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
    $dlg.Font = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, 9.5)

    # 1. Titel
    $lbl1 = New-Object System.Windows.Forms.Label; $lbl1.Location = "30, 25"; $lbl1.Size = "320, 24"; $lbl1.Text = Get-Text "LblFontTitle"; $dlg.Controls.Add($lbl1)
    $numTitle = New-Object System.Windows.Forms.NumericUpDown; $numTitle.Location = "380, 22"; $numTitle.Size = "120, 26"; $numTitle.Minimum = 8; $numTitle.Maximum = 24; $numTitle.DecimalPlaces = 1; $numTitle.Value = [decimal]$script:GuiConfig.TitleFontSize; $dlg.Controls.Add($numTitle)

    # 2. Filter & Suche
    $lbl2 = New-Object System.Windows.Forms.Label; $lbl2.Location = "30, 70"; $lbl2.Size = "320, 24"; $lbl2.Text = Get-Text "LblFontFilter"; $dlg.Controls.Add($lbl2)
    $numFilter = New-Object System.Windows.Forms.NumericUpDown; $numFilter.Location = "380, 67"; $numFilter.Size = "120, 26"; $numFilter.Minimum = 8; $numFilter.Maximum = 20; $numFilter.DecimalPlaces = 1; $numFilter.Value = [decimal]$script:GuiConfig.InputFontSize; $dlg.Controls.Add($numFilter)

    # 3. Tabelle
    $lbl3 = New-Object System.Windows.Forms.Label; $lbl3.Location = "30, 115"; $lbl3.Size = "320, 24"; $lbl3.Text = Get-Text "LblFontTable"; $dlg.Controls.Add($lbl3)
    $numTable = New-Object System.Windows.Forms.NumericUpDown; $numTable.Location = "380, 112"; $numTable.Size = "120, 26"; $numTable.Minimum = 8; $numTable.Maximum = 20; $numTable.DecimalPlaces = 1; $numTable.Value = [decimal]$script:GuiConfig.GridRowFontSize; $dlg.Controls.Add($numTable)

    # 4. Zeilenhöhe (px)
    $lbl4 = New-Object System.Windows.Forms.Label; $lbl4.Location = "30, 160"; $lbl4.Size = "320, 24"; $lbl4.Text = Get-Text "LblFontRowH"; $dlg.Controls.Add($lbl4)
    $numRowH = New-Object System.Windows.Forms.NumericUpDown; $numRowH.Location = "380, 157"; $numRowH.Size = "120, 26"; $numRowH.Minimum = 20; $numRowH.Maximum = 60; $numRowH.Value = [decimal]$script:GuiConfig.GridRowHeight; $dlg.Controls.Add($numRowH)

    # 5. Detail-Bereich
    $lbl5 = New-Object System.Windows.Forms.Label; $lbl5.Location = "30, 205"; $lbl5.Size = "320, 24"; $lbl5.Text = Get-Text "LblFontDetails"; $dlg.Controls.Add($lbl5)
    $numDetails = New-Object System.Windows.Forms.NumericUpDown; $numDetails.Location = "380, 202"; $numDetails.Size = "120, 26"; $numDetails.Minimum = 8; $numDetails.Maximum = 24; $numDetails.DecimalPlaces = 1; $numDetails.Value = [decimal]$script:GuiConfig.DetailsFontSize; $dlg.Controls.Add($numDetails)

    # 6. Code-Viewer
    $lbl6 = New-Object System.Windows.Forms.Label; $lbl6.Location = "30, 250"; $lbl6.Size = "320, 24"; $lbl6.Text = Get-Text "LblFontCode"; $dlg.Controls.Add($lbl6)
    $numCode = New-Object System.Windows.Forms.NumericUpDown; $numCode.Location = "380, 247"; $numCode.Size = "120, 26"; $numCode.Minimum = 9; $numCode.Maximum = 26; $numCode.DecimalPlaces = 1; $numCode.Value = [decimal]$script:GuiConfig.CodeFontSize; $dlg.Controls.Add($numCode)

    # Buttons
    $btnApply = New-Object System.Windows.Forms.Button; $btnApply.Location = "30, 340"; $btnApply.Size = "150, 42"; $btnApply.Text = Get-Text "DlgApply"; $btnApply.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $btnApply.ForeColor = [System.Drawing.Color]::White; $btnApply.FlatStyle = "Flat"; $btnApply.FlatAppearance.BorderSize = 0; $dlg.Controls.Add($btnApply)
    $btnReset = New-Object System.Windows.Forms.Button; $btnReset.Location = "190, 340"; $btnReset.Size = "170, 42"; $btnReset.Text = Get-Text "DlgReset"; $btnReset.BackColor = [System.Drawing.Color]::FromArgb(226, 232, 240); $btnReset.FlatStyle = "Flat"; $btnReset.FlatAppearance.BorderSize = 0; $dlg.Controls.Add($btnReset)
    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Location = "370, 340"; $btnCancel.Size = "130, 42"; $btnCancel.Text = Get-Text "DlgCancel"; $btnCancel.FlatStyle = "Flat"; $dlg.Controls.Add($btnCancel)

    $btnReset.Add_Click({
        $numTitle.Value   = [decimal]$script:DefaultGuiConfig.TitleFontSize
        $numFilter.Value  = [decimal]$script:DefaultGuiConfig.InputFontSize
        $numTable.Value   = [decimal]$script:DefaultGuiConfig.GridRowFontSize
        $numRowH.Value    = [decimal]$script:DefaultGuiConfig.GridRowHeight
        $numDetails.Value = [decimal]$script:DefaultGuiConfig.DetailsFontSize
        $numCode.Value    = [decimal]$script:DefaultGuiConfig.CodeFontSize
    })

    $btnApply.Add_Click({
        $script:GuiConfig.TitleFontSize      = [float]$numTitle.Value
        $script:GuiConfig.InputFontSize      = [float]$numFilter.Value
        $script:GuiConfig.ComboFontSize      = [float]$numFilter.Value
        $script:GuiConfig.LabelFontSize      = [float]$numFilter.Value
        $script:GuiConfig.GridRowFontSize    = [float]$numTable.Value
        $script:GuiConfig.GridHeaderFontSize = [float]$numTable.Value
        $script:GuiConfig.GridRowHeight      = [int]$numRowH.Value
        $script:GuiConfig.GridHeaderHeight   = [int]($numRowH.Value + 4)
        $script:GuiConfig.DetailsFontSize    = [float]$numDetails.Value
        $script:GuiConfig.CodeFontSize       = [float]$numCode.Value

        Apply-GuiFonts
        $dlg.Close()
    })

    $btnCancel.Add_Click({ $dlg.Close() })

    [void]$dlg.ShowDialog()
    $dlg.Dispose()
}

# -------------------------------------------------------------
# 3. Rich Code-Viewer
# -------------------------------------------------------------
function Show-RichCodeViewer([string]$FileName, [string]$Content) {
    $viewerForm = New-Object System.Windows.Forms.Form
    $viewerForm.Text = "Code-Viewer: $FileName"
    $viewerForm.Size = New-Object System.Drawing.Size(1350, 880)
    $viewerForm.MinimumSize = New-Object System.Drawing.Size(1000, 600)
    $viewerForm.StartPosition = "CenterScreen"
    $viewerForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    $topBar = New-Object System.Windows.Forms.Panel
    $topBar.Dock = "Top"; $topBar.Height = 50; $topBar.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $viewerForm.Controls.Add($topBar)

    $lblFileTitle = New-Object System.Windows.Forms.Label
    $lblFileTitle.Text = "📄 $FileName"
    $lblFileTitle.Location = "20, 13"; $lblFileTitle.Size = "600, 26"
    $lblFileTitle.Font = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, 11.5, [System.Drawing.FontStyle]::Bold)
    $lblFileTitle.ForeColor = [System.Drawing.Color]::White
    $topBar.Controls.Add($lblFileTitle)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = Get-Text "BtnCopyCode"
    $btnCopy.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnCopy.Location = "970, 9"; $btnCopy.Size = "210, 32"
    $btnCopy.Font = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.ButtonFontSize, [System.Drawing.FontStyle]::Bold)
    $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204); $btnCopy.ForeColor = [System.Drawing.Color]::White
    $btnCopy.FlatStyle = "Flat"; $btnCopy.FlatAppearance.BorderSize = 0
    $topBar.Controls.Add($btnCopy)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = Get-Text "BtnClose"
    $btnClose.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnClose.Location = "1195, 9"; $btnClose.Size = "120, 32"
    $btnClose.Font = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.ButtonFontSize)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 74); $btnClose.ForeColor = [System.Drawing.Color]::White
    $btnClose.FlatStyle = "Flat"; $btnClose.FlatAppearance.BorderSize = 0
    $topBar.Controls.Add($btnClose)

    $pnlEditor = New-Object System.Windows.Forms.Panel
    $pnlEditor.Dock = "Fill"
    $viewerForm.Controls.Add($pnlEditor)
    $pnlEditor.BringToFront()

    $txtCode = New-Object System.Windows.Forms.TextBox
    $txtCode.Dock = "Fill"; $txtCode.Multiline = $true; $txtCode.ScrollBars = "Both"; $txtCode.ReadOnly = $true; $txtCode.WordWrap = $false
    $txtCode.Font = New-Object System.Drawing.Font($script:GuiConfig.CodeFontFamily, $script:GuiConfig.CodeFontSize)
    $txtCode.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30); $txtCode.ForeColor = [System.Drawing.Color]::FromArgb(235, 235, 235)
    $txtCode.Text = $Content

    $lines = $Content -split "`r?`n"
    $lineNumbers = (1..([Math]::Max($lines.Count, 1)) | ForEach-Object { "{0,4} " -f $_ }) -join "`r`n"

    $txtLineNumbers = New-Object System.Windows.Forms.TextBox
    $txtLineNumbers.Dock = "Left"; $txtLineNumbers.Width = 75; $txtLineNumbers.Multiline = $true; $txtLineNumbers.ReadOnly = $true; $txtLineNumbers.ScrollBars = "None"; $txtLineNumbers.WordWrap = $false
    $txtLineNumbers.Font = New-Object System.Drawing.Font($script:GuiConfig.CodeFontFamily, $script:GuiConfig.CodeFontSize)
    $txtLineNumbers.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 38); $txtLineNumbers.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
    $txtLineNumbers.BorderStyle = "None"
    $txtLineNumbers.Text = $lineNumbers

    $pnlEditor.Controls.Add($txtCode)
    $pnlEditor.Controls.Add($txtLineNumbers)

    $statusBottom = New-Object System.Windows.Forms.StatusBar
    $statusBottom.Text = "  Zeilen: $($lines.Count)  |  Zeichen: $($Content.Length)  |  Encoding: UTF-8"
    $statusBottom.Font = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, 9.5)
    $statusBottom.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204); $statusBottom.ForeColor = [System.Drawing.Color]::White
    $viewerForm.Controls.Add($statusBottom)

    $btnCopy.Add_Click({
        if ($txtCode.Text) {
            [System.Windows.Forms.Clipboard]::SetText($txtCode.Text)
            [System.Windows.Forms.MessageBox]::Show((Get-Text "CopiedMsg"), "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })
    $btnClose.Add_Click({ $viewerForm.Close() })

    [void]$viewerForm.ShowDialog()
    $viewerForm.Dispose()
}

# -------------------------------------------------------------
# 4. Hauptfenster GUI
# -------------------------------------------------------------
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Size = New-Object System.Drawing.Size(1200, 800)
$mainForm.StartPosition = "CenterScreen"
$mainForm.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

# Header Panel
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Dock = "Top"; $pnlHeader.Height = 65; $pnlHeader.BackColor = [System.Drawing.Color]::FromArgb(238, 242, 246)
$mainForm.Controls.Add($pnlHeader)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = "20, 18"; $lblTitle.Size = "500, 32"
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$pnlHeader.Controls.Add($lblTitle)

# Button zum Öffnen des Einstellungs-GUIs
$btnOpenFontDlg = New-Object System.Windows.Forms.Button
$btnOpenFontDlg.Location = "810, 16"; $btnOpenFontDlg.Size = "220, 34"
$btnOpenFontDlg.BackColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$btnOpenFontDlg.FlatStyle = "Flat"; $btnOpenFontDlg.FlatAppearance.BorderSize = 0
$pnlHeader.Controls.Add($btnOpenFontDlg)

$btnLangEN = New-Object System.Windows.Forms.Button; $btnLangEN.Location = "1045, 16"; $btnLangEN.Size = "48, 34"; $btnLangEN.Text = "EN"; $pnlHeader.Controls.Add($btnLangEN)
$btnLangDE = New-Object System.Windows.Forms.Button; $btnLangDE.Location = "1100, 16"; $btnLangDE.Size = "48, 34"; $btnLangDE.Text = "DE"; $pnlHeader.Controls.Add($btnLangDE)

# Filter Panel (Obere Eingabeleiste)
$pnlFilter = New-Object System.Windows.Forms.Panel
$pnlFilter.Dock = "Top"; $pnlFilter.Height = 56; $pnlFilter.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$mainForm.Controls.Add($pnlFilter)

$lblCat = New-Object System.Windows.Forms.Label; $lblCat.Location = "20, 15"; $lblCat.Size = "150, 26"; $pnlFilter.Controls.Add($lblCat)
$cmbCat = New-Object System.Windows.Forms.ComboBox; $cmbCat.Location = "175, 12"; $cmbCat.Size = "220, 30"; $cmbCat.DropDownStyle = "DropDownList"; $pnlFilter.Controls.Add($cmbCat)

$lblSearch = New-Object System.Windows.Forms.Label; $lblSearch.Location = "420, 15"; $lblSearch.Size = "130, 26"; $pnlFilter.Controls.Add($lblSearch)
$txtSearch = New-Object System.Windows.Forms.TextBox; $txtSearch.Location = "555, 12"; $txtSearch.Size = "270, 30"; $pnlFilter.Controls.Add($txtSearch)

# DataGridView (Mit Zeilenabstands-Fix)
$gridFiles = New-Object System.Windows.Forms.DataGridView
$gridFiles.Dock = "Fill"; $gridFiles.ReadOnly = $true; $gridFiles.SelectionMode = "FullRowSelect"; $gridFiles.MultiSelect = $false
$gridFiles.AutoSizeColumnsMode = "Fill"; $gridFiles.BackgroundColor = [System.Drawing.Color]::White; $gridFiles.RowHeadersVisible = $false
$gridFiles.AllowUserToAddRows = $false
$gridFiles.EnableHeadersVisualStyles = $false
$gridFiles.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(230, 236, 245)
$gridFiles.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 253)
$mainForm.Controls.Add($gridFiles)
$gridFiles.BringToFront()

# Footer Panel (Details & Aktionen)
$pnlFooter = New-Object System.Windows.Forms.Panel
$pnlFooter.Dock = "Bottom"; $pnlFooter.Height = 220; $pnlFooter.BackColor = [System.Drawing.Color]::FromArgb(238, 242, 246)
$mainForm.Controls.Add($pnlFooter)

$lblDetailHdr = New-Object System.Windows.Forms.Label
$lblDetailHdr.Location = "20, 8"; $lblDetailHdr.Size = "350, 20"
$pnlFooter.Controls.Add($lblDetailHdr)

$txtDetails = New-Object System.Windows.Forms.TextBox
$txtDetails.Location = "20, 30"; $txtDetails.Size = "880, 175"
$txtDetails.Multiline = $true; $txtDetails.ReadOnly = $true; $txtDetails.ScrollBars = "Vertical"
$pnlFooter.Controls.Add($txtDetails)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Location = "920, 30"; $btnRun.Size = "240, 80"
$btnRun.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.FlatStyle = "Flat"; $btnRun.FlatAppearance.BorderSize = 0
$pnlFooter.Controls.Add($btnRun)

$btnView = New-Object System.Windows.Forms.Button
$btnView.Location = "920, 120"; $btnView.Size = "240, 80"
$btnView.BackColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$btnView.FlatStyle = "Flat"; $btnView.FlatAppearance.BorderSize = 0
$pnlFooter.Controls.Add($btnView)

# -------------------------------------------------------------
# 5. Dynamische Schriftzuweisung
# -------------------------------------------------------------
function Apply-GuiFonts {
    $fTitle   = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.TitleFontSize, [System.Drawing.FontStyle]::Bold)
    $fBtn     = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.ButtonFontSize, [System.Drawing.FontStyle]::Bold)
    $fInput   = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.InputFontSize, [System.Drawing.FontStyle]::Regular)
    $fCombo   = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.ComboFontSize, [System.Drawing.FontStyle]::Regular)
    $fLabel   = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.LabelFontSize, [System.Drawing.FontStyle]::Bold)
    $fActBtn  = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.ActionButtonSize, [System.Drawing.FontStyle]::Bold)
    $fDetails = New-Object System.Drawing.Font($script:GuiConfig.CodeFontFamily, $script:GuiConfig.DetailsFontSize, [System.Drawing.FontStyle]::Regular)
    $fGridH   = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.GridHeaderFontSize, [System.Drawing.FontStyle]::Bold)
    $fGridR   = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, $script:GuiConfig.GridRowFontSize, [System.Drawing.FontStyle]::Regular)

    $lblTitle.Font       = $fTitle
    $btnOpenFontDlg.Font = $fBtn
    $btnLangEN.Font      = $fBtn
    $btnLangDE.Font      = $fBtn

    $lblCat.Font         = $fLabel
    $cmbCat.Font         = $fCombo
    $lblSearch.Font      = $fLabel
    $txtSearch.Font      = $fInput

    $gridFiles.ColumnHeadersDefaultCellStyle.Font = $fGridH
    $gridFiles.RowsDefaultCellStyle.Font          = $fGridR
    $gridFiles.RowTemplate.Height                 = $script:GuiConfig.GridRowHeight
    $gridFiles.ColumnHeadersHeight                = $script:GuiConfig.GridHeaderHeight

    $lblDetailHdr.Font = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, 10.0, [System.Drawing.FontStyle]::Bold)
    $txtDetails.Font   = $fDetails
    $btnRun.Font       = $fActBtn
    $btnView.Font      = New-Object System.Drawing.Font($script:GuiConfig.FontFamily, 10.0, [System.Drawing.FontStyle]::Regular)
    
    # Grid sofort neu rendern
    foreach ($r in $gridFiles.Rows) { $r.Height = $script:GuiConfig.GridRowHeight }
    $mainForm.Refresh()
}

function Refresh-Grid {
    $searchTerm = $txtSearch.Text.Trim().ToLower()
    $selectedCategory = $cmbCat.SelectedItem

    $filtered = $script:FileDatabase | Where-Object {
        $desc = if ($script:CurrentLang -eq "DE") { $_.Desc_DE } else { $_.Desc_EN }
        $matchCat = ($selectedCategory -eq (Get-Text "AllCategories") -or [string]::IsNullOrEmpty($selectedCategory) -or $_.Category -eq $selectedCategory)
        $matchSearch = ([string]::IsNullOrEmpty($searchTerm) -or $_.Name.ToLower().Contains($searchTerm) -or $desc.ToLower().Contains($searchTerm))
        $matchCat -and $matchSearch
    }

    $tableData = [System.Collections.ArrayList]::new()
    foreach ($item in $filtered) {
        $desc = if ($script:CurrentLang -eq "DE") { $item.Desc_DE } else { $item.Desc_EN }
        $tableData.Add([PSCustomObject]@{
            (Get-Text "ColName")     = $item.Name
            (Get-Text "ColCategory") = $item.Category
            (Get-Text "ColType")     = $item.Type
            (Get-Text "ColDesc")     = $desc
        }) | Out-Null
    }

    $gridFiles.DataSource = $null
    $gridFiles.DataSource = $tableData
    
    if ($gridFiles.Columns -and $gridFiles.Columns.Count -ge 4) {
        $gridFiles.Columns[0].FillWeight = 28
        $gridFiles.Columns[1].FillWeight = 18
        $gridFiles.Columns[2].FillWeight = 12
        $gridFiles.Columns[3].FillWeight = 42
    }
}

function Update-LanguageUI {
    $mainForm.Text        = Get-Text "Title"
    $lblTitle.Text        = Get-Text "Title"
    $lblCat.Text          = Get-Text "CategoryFilter"
    $lblSearch.Text       = Get-Text "Search"
    $lblDetailHdr.Text    = Get-Text "DetailsTitle"
    $btnRun.Text          = Get-Text "BtnRun"
    $btnView.Text         = Get-Text "BtnView"
    $btnOpenFontDlg.Text  = Get-Text "BtnFontDlg"

    $currentCat = $cmbCat.SelectedItem
    $cmbCat.Items.Clear()
    $cmbCat.Items.Add((Get-Text "AllCategories")) | Out-Null
    
    $uniqueCats = $script:FileDatabase | ForEach-Object { $_.Category } | Select-Object -Unique | Sort-Object
    foreach ($cat in $uniqueCats) { [void]$cmbCat.Items.Add($cat) }
    
    if ($currentCat -and $cmbCat.Items.Contains($currentCat)) { 
        $cmbCat.SelectedItem = $currentCat 
    } else { 
        $cmbCat.SelectedIndex = 0 
    }

    if ($script:CurrentLang -eq "DE") {
        $btnLangDE.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $btnLangDE.ForeColor = [System.Drawing.Color]::White
        $btnLangEN.BackColor = [System.Drawing.SystemColors]::Control; $btnLangEN.ForeColor = [System.Drawing.Color]::Black
    } else {
        $btnLangEN.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $btnLangEN.ForeColor = [System.Drawing.Color]::White
        $btnLangDE.BackColor = [System.Drawing.SystemColors]::Control; $btnLangDE.ForeColor = [System.Drawing.Color]::Black
    }

    Apply-GuiFonts
    Refresh-Grid
}

# -------------------------------------------------------------
# 6. Events
# -------------------------------------------------------------
$gridFiles.Add_SelectionChanged({
    if ($gridFiles.SelectedRows.Count -gt 0) {
        $selectedName = $gridFiles.SelectedRows[0].Cells[0].Value
        $entry = $script:FileDatabase | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
        if ($entry) {
            $desc = if ($script:CurrentLang -eq "DE") { $entry.Desc_DE } else { $entry.Desc_EN }
            $txtDetails.Text = "Dateiname:    $($entry.Name)`r`nTyp:          $($entry.Type)`r`nKategorie:    $($entry.Category)`r`n`r`nBeschreibung / Description:`r`n$desc"
        }
    }
})

$btnLangDE.Add_Click({ $script:CurrentLang = "DE"; Update-LanguageUI })
$btnLangEN.Add_Click({ $script:CurrentLang = "EN"; Update-LanguageUI })
$cmbCat.Add_SelectedIndexChanged({ Refresh-Grid })
$txtSearch.Add_TextChanged({ Refresh-Grid })

# Klick: Einstellungsfenster öffnen
$btnOpenFontDlg.Add_Click({ Show-FontSettingsDialog })

$btnView.Add_Click({
    if ($gridFiles.SelectedRows.Count -eq 0) { return }
    $fileName = [string]$gridFiles.SelectedRows[0].Cells[0].Value
    if ([string]::IsNullOrWhiteSpace($fileName)) { return }

    try {
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $code = Get-ScriptOrSnippetContent -FileName $fileName
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
        Show-RichCodeViewer -FileName $fileName -Content $code
    } catch {
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("$(Get-Text 'ErrDownload')$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnRun.Add_Click({
    if ($gridFiles.SelectedRows.Count -eq 0) { return }
    $fileName = [string]$gridFiles.SelectedRows[0].Cells[0].Value
    if ([string]::IsNullOrWhiteSpace($fileName)) { return }

    try {
        $localPath = [System.IO.Path]::Combine($script:RootPath, $fileName)
        
        if (Test-Path -LiteralPath $localPath) {
            if ($fileName.EndsWith(".ps1")) {
                Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$localPath`""
            } else {
                $code = Get-Content -LiteralPath $localPath -Raw -Encoding UTF8
                Show-RichCodeViewer -FileName $fileName -Content $code
            }
            return
        }

        $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $code = Get-ScriptOrSnippetContent -FileName $fileName
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default

        if ($fileName.EndsWith(".ps1")) {
            $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $fileName)
            [System.IO.File]::WriteAllText($tempFile, $code, [System.Text.Encoding]::UTF8)
            Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$tempFile`""
        } else {
            Show-RichCodeViewer -FileName $fileName -Content $code
        }
    } catch {
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("$(Get-Text 'ErrDownload')$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Start
Update-LanguageUI
try {
    [void]$mainForm.ShowDialog()
} finally {
    $mainForm.Dispose()
}
