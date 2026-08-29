<#
.SYNOPSIS
    Prüft Hardware-, BIOS-, TPM- und Partitionsvoraussetzungen für Intune Compliance.
#>

Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "        CLIENT HARDWARE & COMPLIANCE PRE-CHECK (NB101014)        " -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

# 1. BIOS-Modus prüfen
$BiosMode = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -ErrorAction SilentlyContinue)
$IsUefi = $env:firmware_type -eq 'UEFI' -or (Get-ComputerInfo).BiosFirmwareType -eq 'Uefi'

if ($IsUefi) {
    Write-Host "[1/4] BIOS-Modus:              ✅ UEFI (In Ordnung)" -ForegroundColor Green
} else {
    Write-Host "[1/4] BIOS-Modus:              ❌ Vorgängerversion / Legacy BIOS" -ForegroundColor Red
}

# 2. Secure Boot Status
$SecureBoot = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled" -ErrorAction SilentlyContinue
if ($SecureBoot.UEFISecureBootEnabled -eq 1) {
    Write-Host "[2/4] Secure Boot:             ✅ Aktiviert" -ForegroundColor Green
} else {
    Write-Host "[2/4] Secure Boot:             ❌ Deaktiviert oder nicht verfügbar" -ForegroundColor Red
}

# 3. TPM-Status
$Tpm = Get-Tpm -ErrorAction SilentlyContinue
if ($Tpm.TpmPresent -and $Tpm.TpmReady) {
    Write-Host "[3/4] TPM 2.0:                 ✅ Vorhanden und einsatzbereit" -ForegroundColor Green
} elseif ($Tpm.TpmPresent -and -not $Tpm.TpmReady) {
    Write-Host "[3/4] TPM 2.0:                 ⚠️ Vorhanden, aber nicht initialisiert" -ForegroundColor Yellow
} else {
    Write-Host "[3/4] TPM 2.0:                 ❌ Nicht gefunden / im BIOS deaktiviert" -ForegroundColor Red
}

# 4. Partitionsstil des Systemlaufwerks (MBR vs GPT)
$SystemDrive = (Get-Partition -DriveLetter ($env:SystemDrive.Substring(0,1))).DiskNumber
$DiskInfo = Get-Disk -Number $SystemDrive
if ($DiskInfo.PartitionStyle -eq 'GPT') {
    Write-Host "[4/4] Partitionsstil (Laufwerk): ✅ GPT (Bereit für UEFI)" -ForegroundColor Green
} else {
    Write-Host "[4/4] Partitionsstil (Laufwerk): ❌ MBR (Muss vor UEFI-Umstellung konvertiert werden!)" -ForegroundColor Red
}

Write-Host "`n-----------------------------------------------------------------" -ForegroundColor Gray
Write-Host "ERGEBNIS-AUSWERTUNG:" -ForegroundColor Yellow

if ($DiskInfo.PartitionStyle -eq 'MBR') {
    Write-Host "-> Datenträger läuft als MBR. Führe 'mbr2gpt /validate /allowFullOS' aus!" -ForegroundColor Red
}
if (-not $IsUefi -or $SecureBoot.UEFISecureBootEnabled -ne 1) {
    Write-Host "-> BIOS muss nach der GPT-Konvertierung auf UEFI + Secure Boot umgestellt werden." -ForegroundColor Yellow
}
if ($IsUefi -and $SecureBoot.UEFISecureBootEnabled -eq 1 -and $Tpm.TpmReady -and $DiskInfo.PartitionStyle -eq 'GPT') {
    Write-Host "-> Alle lokalen Voraussetzungen erfüllt! Starte den Intune-Sync." -ForegroundColor Green
}
Write-Host "=================================================================" -ForegroundColor Cyan


(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
# Ergibt zusammen das genaue Format: z. B. 10.0.26200.5000

$ver = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
"10.0.$($ver.CurrentBuildNumber).$($ver.UBR)"
# Ausgabe: 10.0.26200.9106
