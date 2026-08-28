$Path = "C:\Program Files\7-Zip\7zFM.exe"
if (Test-Path $Path) {
    $InstalledVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion
    Write-Host "Installierte 7-Zip Version: $InstalledVersion" -ForegroundColor Green
    Write-Host "Erkennung für (>= 26.02): $([version]$InstalledVersion -ge [version]'26.02')" -ForegroundColor Cyan
} else {
    Write-Host "7-Zip Datei nicht gefunden." -ForegroundColor Red
}
