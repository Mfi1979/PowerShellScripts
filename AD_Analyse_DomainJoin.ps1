# Native LDAP-Suche nach Rechnern mit hinterlegter Creator-SID
$searcher = [System.DirectoryServices.DirectorySearcher]::new()
$searcher.Filter = "(&(objectCategory=computer)(ms-DS-CreatorSID=*))"
$searcher.PageSize = 1000
[void]$searcher.PropertiesToLoad.AddRange(@("name", "ms-ds-creatorsid", "userAccountControl"))

$results = $searcher.FindAll()

$grouped = @{}
foreach ($item in $results) {
    $compName = $item.Properties["name"][0]
    
    # ms-DS-CreatorSID liegt als Byte-Array vor
    $sidBytes = $item.Properties["ms-ds-creatorsid"][0]
    $sidObj   = [System.Security.Principal.SecurityIdentifier]::new($sidBytes, 0)
    $sidStr   = $sidObj.Value

    if (-not $grouped.ContainsKey($sidStr)) {
        $grouped[$sidStr] = [System.Collections.Generic.List[string]]::new()
    }
    $grouped[$sidStr].Add($compName)
}

$report = foreach ($sidKey in $grouped.Keys) {
    $resolvedName = $sidKey
    try {
        $sidObj = [System.Security.Principal.SecurityIdentifier]::new($sidKey)
        $resolvedName = $sidObj.Translate([System.Security.Principal.NTAccount]).Value
    } catch {
        $resolvedName = "$sidKey (Unbekannt / Gelöscht)"
    }

    [PSCustomObject]@{
        CreatorAccount = $resolvedName
        CreatorSID     = $sidKey
        JoinedCount    = $grouped[$sidKey].Count
        ComputerNames  = ($grouped[$sidKey]) -join ', '
    }
}

$report | Sort-Object JoinedCount -Descending | Format-Table -AutoSize
