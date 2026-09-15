Import-Module ActiveDirectory

# 1. Alle aktiven Server-Objekte direkt aus dem AD auslesen
$ServerList = (Get-ADComputer -Filter {OperatingSystem -like "*Server*" -and Enabled -eq $true}).Name

Write-Host "Gefundene Server im AD: $($ServerList.Count) ($($ServerList -join ', '))" -ForegroundColor Cyan
Write-Host "Frage Dienste per WinRM parallel ab..." -ForegroundColor Yellow

# 2. Parallel alle Server abfragen
$DienstReport = Invoke-Command -ComputerName $ServerList -ScriptBlock {
    Get-CimInstance -ClassName Win32_Service -Filter "State = 'Running'" | 
        Select-Object @{Name = 'Server'; Expression = { $env:COMPUTERNAME }},
                      Name, 
                      DisplayName, 
                      StartMode, 
                      StartName,
                      PathName
} -ErrorAction SilentlyContinue -ErrorVariable UnreachableHosts

# 3. Warnung ausgeben, falls Server offline waren
if ($UnreachableHosts) {
    $offline = $UnreachableHosts.TargetObject | Select-Object -Unique
    Write-Warning "Folgende Server konnten per WinRM nicht erreicht werden: $($offline -join ', ')"
}

# 4. Als interaktives GridView-Fenster mit Schnellfilter öffnen
$DienstReport | 
    Select-Object Server, DisplayName, Name, StartMode, StartName, PathName | 
    Sort-Object Server, DisplayName | 
    Out-GridView -Title "Laufende Dienste aller AD-Server"
