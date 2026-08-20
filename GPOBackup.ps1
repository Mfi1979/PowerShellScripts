# Modul laden
Import-Module GroupPolicy

# Name des GPOs und Basis-Backup-Pfad definieren
$gpoName = "Rechner_new"
$baseBackupPath = "C:\_Admin\GPO_Backup"

try {
    # 1. GPO ermitteln
    $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
    $gpoGuid = $gpo.Id.ToString()
    Write-Host "✅ GPO '$gpoName' (ID: $gpoGuid) gefunden." -ForegroundColor Green

    # 2. Ordnerstruktur mit der GUID als Ordnername aufbauen
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Hier wird die GUID als Unterordner verwendet: C:\_Admin\GPO_Backup\d053bd20-...\20260820_143015
    $targetBackupPath = Join-Path (Join-Path $baseBackupPath $gpoGuid) $timestamp

    if (!(Test-Path $targetBackupPath)) { 
        New-Item -ItemType Directory -Path $targetBackupPath -Force | Out-Null 
    }

    # 3. Backup ausführen
    Backup-GPO -Guid $gpoGuid -Path $targetBackupPath | Out-Null
    Write-Host "📂 Backup erfolgreich erstellt unter: $targetBackupPath" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Fehler: GPO '$gpoName' wurde nicht gefunden oder es gab ein Problem: $_" -ForegroundColor Red
    return
}

# 4. Verknüpfungen über den GPO-Report (XML) auslesen
$gpoReport = [xml](Get-GPOReport -Guid $gpoGuid -ReportType Xml)
$links = $gpoReport.GPO.LinksTo

# Textdatei-Pfad im Backup-Verzeichnis definieren
$txtReportPath = Join-Path $targetBackupPath "GPO_Link_Info.txt"
$currentTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

if ($null -eq $links -or $links.Count -eq 0) {
    $statusMessage = "Status: Das GPO '$gpoName' ist aktuell nirgendwo verknüpft (Unlinked GPO)."
    Write-Host "⚠️ $statusMessage" -ForegroundColor Yellow
    
    # Ausführliche Informationen in die TXT-Datei schreiben
    "========================================" | Out-File -FilePath $txtReportPath -Encoding UTF8
    " GPO AUDIT & BACKUP REPORT"              | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "========================================" | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "GPO Name          : $gpoName"             | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "GPO ID (GUID)     : $gpoGuid"             | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "Prüfungszeitpunkt : $currentTime"           | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "----------------------------------------" | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    $statusMessage                             | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
} else {
    Write-Host "🔗 Status: Das GPO ist an folgende Ziele verknüpft:" -ForegroundColor Green
    
    $linkReport = foreach ($link in $links) {
        [PSCustomObject]@{
            "Verknüpfungs-Ziel (SOM)" = $link.SOMPath
            "Aktiviert (LinkEnabled)" = $link.Enabled
        }
    }
    $linkReport | Format-Table -AutoSize

    # Ausführliche Informationen in die TXT-Datei schreiben
    "========================================" | Out-File -FilePath $txtReportPath -Encoding UTF8
    " GPO AUDIT & BACKUP REPORT"              | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "========================================" | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "GPO Name          : $gpoName"             | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "GPO ID (GUID)     : $gpoGuid"             | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "Prüfungszeitpunkt : $currentTime"           | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "----------------------------------------" | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    "Das GPO ist an folgende Ziele verknüpft:" | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    foreach ($link in $links) {
        " - Ziel (SOM): $($link.SOMPath) | Aktiviert: $($link.Enabled)" | Out-File -FilePath $txtReportPath -Append -Encoding UTF8
    }
}

Write-Host "📄 Erweiterte Informationen und GUID-Zuordnung wurden in der Textdatei gespeichert: $txtReportPath" -ForegroundColor Cyan
