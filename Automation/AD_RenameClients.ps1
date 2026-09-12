<#
.SYNOPSIS
    Remote-Umbenennung von Windows-Clients ohne WinRM (reiner RPC/DCOM/SMB-Weg).
#>

# 1. Pfade definieren
$CSVPath     = "C:\Temp\RenameClientsList.csv"
$LogPath     = "C:\Temp\RenameLog_$(Get-Date -Format 'yyyy-MM-dd').txt"
$FailCSVPath = "C:\Temp\Fehlgeschlagene_Computer.csv"

# 2. Log-Funktion
function Write-Log {
    param (
        [string]$Message,
        [System.ConsoleColor]$Color = [System.ConsoleColor]::White
    )
    $TimeStamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] $Message"
    Write-Host $LogMessage -ForegroundColor $Color
    $LogMessage | Out-File -FilePath $LogPath -Append -Encoding utf8
}

# 3. Anmeldedaten abfragen (Konto mit lokalen Admin-Rechten & AD-Rename-Berechtigung)
$DomainCred = Get-Credential -UserName "$env:USERDOMAIN\" -Message "Bitte Administrator-Zugangsdaten eingeben"

# 4. CSV einlesen (Array-Zwang @(), damit auch Einzelzeilen korrekt gezählt werden)
if (-not (Test-Path $CSVPath)) {
    Write-Error "Die Quell-CSV-Datei wurde unter $CSVPath nicht gefunden!"
    exit
}
$Computers = @(Import-Csv -Path $CSVPath -Delimiter ",")

$FailedComputers = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Log "=== START: Remote-Rename (Weg B: RPC/DCOM) gestartet ===" -Color Cyan
Write-Log "Gefundene Eintraege in CSV: $($Computers.Count)" -Color Cyan

# 5. Schleife durch alle Computer
foreach ($Computer in $Computers) {
    $Old           = $Computer.AlterName.Trim()
    $New           = $Computer.NeuerName.Trim()
    $Status        = "Unbekannt"
    $FehlerDetails = ""

    Write-Log "--------------------------------------------------" -Color Gray
    Write-Log "Verarbeite: $Old -> $New" -Color Cyan

    # Schritt 1: Ping-Prüfung
    if (-not (Test-Connection -ComputerName $Old -Count 1 -Quiet)) {
        $Status        = "Offline"
        $FehlerDetails = "Client antwortet nicht auf ICMP (Ping)."
        Write-Log "[-] $FehlerDetails" -Color Yellow
    }
    else {
        Write-Log "[+] Ping erfolgreich." -Color Gray

        # Schritt 2: RPC/SMB Port 445 prüfen
        $TcpSocket = New-Object System.Net.Sockets.TcpClient
        $PortOk    = $false
        try {
            $AsyncResult = $TcpSocket.BeginConnect($Old, 445, $null, $null)
            $WaitHandle  = $AsyncResult.AsyncWaitHandle.WaitOne(1500, $false)
            if ($WaitHandle -and $TcpSocket.Connected) {
                $TcpSocket.EndConnect($AsyncResult)
                $PortOk = $true
            }
        }
        catch { $PortOk = $false }
        finally { $TcpSocket.Close(); $TcpSocket.Dispose() }

        if (-not $PortOk) {
            $Status        = "RPC/SMB blockiert"
            $FehlerDetails = "Port 445 ist nicht erreichbar (Datei- und Druckerfreigabe / Client-Firewall prüfen)."
            Write-Log "[-] $FehlerDetails" -Color Yellow
        }
        else {
            Write-Log "[+] Port 445 (SMB/RPC) erreichbar. Starte Umbenennung..." -Color Gray

            # Schritt 3: Rename-Computer via RPC/DCOM ausführen
            try {
                Rename-Computer -ComputerName $Old -NewName $New -DomainCredential $DomainCred -Force -Restart -ErrorAction Stop
                Write-Log "[*] Befehl gesendet. Warte auf AD-Synchronisation..." -Color Yellow

                # Schritt 4: Dynamische AD-Verifikation (bis zu 25 Sekunden)
                $ADCheck = $null
                $TimeoutSeconds = 25
                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                while ($Stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
                    Start-Sleep -Seconds 3
                    $ADCheck = Get-ADComputer -Filter "Name -eq '$New' -or sAMAccountName -eq '$New$'" -ErrorAction SilentlyContinue
                    if ($ADCheck) { break }
                }
                $Stopwatch.Stop()

                if ($ADCheck) {
                    Write-Log "[SUCCESS] $Old erfolgreich in $New umbenannt (im AD bestätigt) und Reboot initiiert!" -Color Green
                    $Status = "Erfolgreich"
                } else {
                    $Status        = "AD-Verifikation fehlgeschlagen"
                    $FehlerDetails = "Rename-Befehl ging durch, aber das AD-Objekt wurde nach 25s noch nicht zu '$New' aktualisiert."
                    Write-Log "[-] $FehlerDetails" -Color Red
                }
            }
            catch {
                $Status        = "Rename fehlgeschlagen"
                $FehlerDetails = $_.Exception.Message
                Write-Log "[-] Rename fehlgeschlagen: $FehlerDetails" -Color Red
            }
        }
    }

    # Bei Misserfolg sammeln
    if ($Status -ne "Erfolgreich") {
        $FailedComputers.Add([PSCustomObject]@{
            AlterName        = $Old
            GewuenschterName = $New
            Status           = $Status
            FehlerDetails    = $FehlerDetails
        })
    }
}

# 6. Fehlerliste exportieren
Write-Log "--------------------------------------------------" -Color Gray
if ($FailedComputers.Count -gt 0) {
    $FailedComputers | Export-Csv -Path $FailCSVPath -NoTypeInformation -Delimiter ";" -Encoding utf8
    Write-Log "=== FINISH: Beendet mit $($FailedComputers.Count) Fehlern. ===" -Color Yellow
    Write-Log "Report gespeichert unter: $FailCSVPath" -Color Yellow
} else {
    Write-Log "=== FINISH: Alle Clients erfolgreich ohne WinRM umbenannt! ===" -Color Green
    if (Test-Path $FailCSVPath) { Remove-Item $FailCSVPath -Force }
}
