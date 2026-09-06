<#
.SYNOPSIS
    Analysiert Active-Directory-Objekte mit adminCount=1 über LDAP.

.DESCRIPTION
    Das Skript verwendet eine LDAP-Suche über System.DirectoryServices
    und benötigt nicht das ActiveDirectory-PowerShell-Modul.

    Gesucht werden alle AD-Objekte mit:
        (adminCount=1)

    Angezeigt werden:
        - Name
        - Objektklasse
        - DistinguishedName
        - SamAccountName
        - UserPrincipalName
        - adminCount
        - objectSid

.NOTES
    Für die LDAP-Abfrage werden die aktuellen Windows-Anmeldedaten verwendet.
#>

# ------------------------------------------------------------
# Einstellungen
# ------------------------------------------------------------

$LDAPFilter = "(adminCount=1)"

# RootDSE des aktuellen Domänencontrollers abfragen
$RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")

$DefaultNamingContext = $RootDSE.Properties["defaultNamingContext"][0]

if (-not $DefaultNamingContext) {
    Write-Error "Der Default Naming Context konnte nicht ermittelt werden."
    exit 1
}

$LDAPPath = "LDAP://$DefaultNamingContext"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Active Directory LDAP Analyse" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "LDAP Base  : $LDAPPath"
Write-Host "LDAP Filter: $LDAPFilter"
Write-Host ""

# ------------------------------------------------------------
# LDAP-Verbindung
# ------------------------------------------------------------

try {
    $SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($LDAPPath)

    $Searcher = New-Object System.DirectoryServices.DirectorySearcher($SearchRoot)

    $Searcher.Filter = $LDAPFilter

    # Attribute, die abgefragt werden sollen
    @(
        "name"
        "objectClass"
        "distinguishedName"
        "samAccountName"
        "userPrincipalName"
        "adminCount"
        "objectSid"
        "description"
        "whenCreated"
        "whenChanged"
    ) | ForEach-Object {
        [void]$Searcher.PropertiesToLoad.Add($_)
    }

    # Alle Treffer
    $Searcher.PageSize = 1000

    $Results = $Searcher.FindAll()

}
catch {
    Write-Error "LDAP-Abfrage fehlgeschlagen: $($_.Exception.Message)"
    exit 1
}

# ------------------------------------------------------------
# Ergebnisse verarbeiten
# ------------------------------------------------------------

$Objects = foreach ($Result in $Results) {

    $Properties = $Result.Properties

    # objectClass kann mehrere Werte enthalten.
    # Die letzte Klasse ist normalerweise die spezifischste.
    $ObjectClass = $null

    if ($Properties["objectclass"].Count -gt 0) {
        $ObjectClass = $Properties["objectclass"][-1]
    }

    [PSCustomObject]@{
        Name              = if ($Properties["name"])              { $Properties["name"][0] }              else { "" }
        ObjectClass       = $ObjectClass
        SamAccountName    = if ($Properties["samaccountname"])    { $Properties["samaccountname"][0] }    else { "" }
        UserPrincipalName = if ($Properties["userprincipalname"]) { $Properties["userprincipalname"][0] } else { "" }
        AdminCount        = if ($Properties["admincount"])        { $Properties["admincount"][0] }        else { "" }
        DistinguishedName = if ($Properties["distinguishedname"]) { $Properties["distinguishedname"][0] } else { "" }
        Description       = if ($Properties["description"])       { $Properties["description"][0] }       else { "" }
        WhenCreated       = if ($Properties["whencreated"])       { $Properties["whencreated"][0] }       else { "" }
        WhenChanged       = if ($Properties["whenchanged"])       { $Properties["whenchanged"][0] }       else { "" }
    }
}

# LDAP-Verbindung schließen
$Results.Dispose()
$SearchRoot.Dispose()
$RootDSE.Dispose()

# ------------------------------------------------------------
# Übersicht
# ------------------------------------------------------------

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Ergebnis" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Gefundene Objekte: $($Objects.Count)" -ForegroundColor Yellow
Write-Host ""

if ($Objects.Count -eq 0) {

    Write-Host "Keine Objekte mit adminCount=1 gefunden." -ForegroundColor Green

}
else {

    # --------------------------------------------------------
    # Detailanzeige
    # --------------------------------------------------------

    $Objects |
        Sort-Object ObjectClass, Name |
        Format-Table `
            Name,
            ObjectClass,
            SamAccountName,
            AdminCount `
            -AutoSize

    # --------------------------------------------------------
    # Aufteilung nach Objektklasse
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Objekte nach Objektklasse:" -ForegroundColor Cyan
    Write-Host ""

    $Objects |
        Group-Object ObjectClass |
        Sort-Object Count -Descending |
        Format-Table Name, Count -AutoSize

    # --------------------------------------------------------
    # Distinguished Names
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Distinguished Names:" -ForegroundColor Cyan
    Write-Host ""

    $Objects |
        Sort-Object ObjectClass, Name |
        Select-Object Name, ObjectClass, DistinguishedName |
        Format-Table -Wrap -AutoSize

    # --------------------------------------------------------
    # Benutzer separat anzeigen
    # --------------------------------------------------------

    $Users = $Objects |
        Where-Object { $_.ObjectClass -eq "user" }

    if ($Users.Count -gt 0) {

        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host " Benutzer mit adminCount=1" -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host ""

        $Users |
            Sort-Object Name |
            Select-Object Name,
                          SamAccountName,
                          UserPrincipalName,
                          DistinguishedName |
            Format-Table -Wrap -AutoSize
    }

    # --------------------------------------------------------
    # Gruppen separat anzeigen
    # --------------------------------------------------------

    $Groups = $Objects |
        Where-Object { $_.ObjectClass -eq "group" }

    if ($Groups.Count -gt 0) {

        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host " Gruppen mit adminCount=1" -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host ""

        $Groups |
            Sort-Object Name |
            Select-Object Name,
                          DistinguishedName |
            Format-Table -Wrap -AutoSize
    }
}

Write-Host ""
Write-Host "Analyse abgeschlossen." -ForegroundColor Green
Write-Host ""
