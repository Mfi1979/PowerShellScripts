# ============================================================
# GPO AUDIT
# Alle GPOs auslesen und tatsächliche AD-Verknüpfungen prüfen
# ============================================================

Import-Module ActiveDirectory
Import-Module GroupPolicy

# ------------------------------------------------------------
# Einstellungen
# ------------------------------------------------------------

$OutputPath = "C:\_Admin\GPO_Audit"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$TxtPath = Join-Path $OutputPath "GPO_Audit_$Timestamp.txt"
$CsvPath = Join-Path $OutputPath "GPO_Audit_$Timestamp.csv"

# Ausgabeordner erstellen
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# ------------------------------------------------------------
# Hilfsfunktion: Log schreiben
# ------------------------------------------------------------

$LogLines = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param (
        [string]$Message,
        [string]$Color = "White"
    )

    $time = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

    $line = "[$time] $Message"

    $LogLines.Add($line)

    Write-Host $line -ForegroundColor $Color
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

Write-Log "============================================================" "Cyan"
Write-Log "GPO AUDIT - VERKNÜPFUNGEN" "Cyan"
Write-Log "============================================================" "Cyan"
Write-Log ""

# ------------------------------------------------------------
# Domäne ermitteln
# ------------------------------------------------------------

try {

    $domain = Get-ADDomain -ErrorAction Stop

    $domainDN = $domain.DistinguishedName
    $domainDNS = $domain.DNSRoot

    Write-Log "Domäne: $domainDNS" "Green"
    Write-Log "DN    : $domainDN" "Green"
    Write-Log ""

}
catch {

    Write-Log "FEHLER beim Ermitteln der Domäne: $($_.Exception.Message)" "Red"
    return
}

# ------------------------------------------------------------
# Alle GPOs auslesen
# ------------------------------------------------------------

try {

    $gpos = @(Get-GPO -All -ErrorAction Stop)

    Write-Log "Gefundene GPOs: $($gpos.Count)" "Green"
    Write-Log ""

}
catch {

    Write-Log "FEHLER beim Auslesen der GPOs: $($_.Exception.Message)" "Red"
    return
}

# ------------------------------------------------------------
# Domäne und OUs ermitteln
# ------------------------------------------------------------

Write-Log "Lese Domäne und OUs aus..." "Yellow"

$adObjects = @()

# Domäne
$domainObject = Get-ADObject `
    -Identity $domainDN `
    -Properties gpLink, gpOptions, objectClass `
    -ErrorAction Stop

$adObjects += $domainObject

# Alle OUs
try {

    $ous = @(Get-ADOrganizationalUnit `
        -Filter * `
        -Properties gpLink, gpOptions `
        -ErrorAction Stop)

    $adObjects += $ous

    Write-Log "Gefundene OUs: $($ous.Count)" "Green"

}
catch {

    Write-Log "FEHLER beim Auslesen der OUs: $($_.Exception.Message)" "Red"
}

# ------------------------------------------------------------
# AD Sites auslesen
# ------------------------------------------------------------

Write-Log "Lese AD Sites aus..." "Yellow"

try {

    $configurationNamingContext = (Get-ADRootDSE).configurationNamingContext

    $sitesSearchBase = "CN=Sites,$configurationNamingContext"

    $sites = @(
        Get-ADObject `
            -SearchBase $sitesSearchBase `
            -LDAPFilter "(objectClass=site)" `
            -Properties gpLink, gpOptions, objectClass `
            -ErrorAction Stop
    )

    $adObjects += $sites

    Write-Log "Gefundene AD Sites: $($sites.Count)" "Green"

}
catch {

    Write-Log "FEHLER beim Auslesen der AD Sites: $($_.Exception.Message)" "Red"
}

Write-Log ""
Write-Log "Zu prüfende AD-Objekte insgesamt: $($adObjects.Count)" "Cyan"
Write-Log ""

# ------------------------------------------------------------
# Ergebnisarray
# ------------------------------------------------------------

$Results = New-Object System.Collections.Generic.List[object]

$gpoCounter = 0

# ------------------------------------------------------------
# Jede GPO prüfen
# ------------------------------------------------------------

foreach ($gpo in $gpos) {

    $gpoCounter++

    $gpoName = $gpo.DisplayName
    $gpoGuid = $gpo.Id.ToString()

    Write-Log "[$gpoCounter/$($gpos.Count)] Prüfe GPO: $gpoName" "Cyan"
    Write-Log "GUID: $gpoGuid" "Gray"

    $foundLink = $false

    # --------------------------------------------------------
    # Alle Domänen/OUs/Sites prüfen
    # --------------------------------------------------------

    foreach ($adObject in $adObjects) {

        $gpLink = $adObject.gpLink

        if ([string]::IsNullOrWhiteSpace($gpLink)) {
            continue
        }

        # ----------------------------------------------------
        # gpLink besteht aus mehreren Einträgen
        # ----------------------------------------------------

        $links = $gpLink -split '\]\['

        foreach ($link in $links) {

            # GUID aus gpLink extrahieren
            if ($link -match '\{([0-9A-Fa-f-]{36})\}') {

                $linkedGuid = $Matches[1]

                # ------------------------------------------------
                # Ist es unsere GPO?
                # ------------------------------------------------

                if ($linkedGuid -ieq $gpoGuid) {

                    $foundLink = $true

                    # ------------------------------------------------
                    # Link-Option bestimmen
                    #
                    # 0 = aktiviert
                    # 1 = deaktiviert
                    # 2 = aktiviert + enforced
                    # 3 = deaktiviert + enforced
                    # ------------------------------------------------

                    $linkOption = 0

                    if ($link -match '\](\d+)$') {
                        $linkOption = [int]$Matches[1]
                    }

                    switch ($linkOption) {

                        0 {
                            $linkEnabled = $true
                            $enforced = $false
                        }

                        1 {
                            $linkEnabled = $false
                            $enforced = $false
                        }

                        2 {
                            $linkEnabled = $true
                            $enforced = $true
                        }

                        3 {
                            $linkEnabled = $false
                            $enforced = $true
                        }

                        default {
                            $linkEnabled = $null
                            $enforced = $null
                        }
                    }

                    # ------------------------------------------------
                    # Objekttyp bestimmen
                    # ------------------------------------------------

                    $objectType = $adObject.ObjectClass

                    if ($objectType -is [array]) {
                        $objectType = $objectType[-1]
                    }

                    # ------------------------------------------------
                    # Ergebnisobjekt
                    # ------------------------------------------------

                    $result = [PSCustomObject]@{
                        GPOName        = $gpoName
                        GUID           = $gpoGuid
                        Status         = "VERLINKT"
                        VerknuepftMit  = $adObject.DistinguishedName
                        ObjektTyp     = $objectType
                        LinkAktiviert = $linkEnabled
                        Enforced      = $enforced
                        LinkOption     = $linkOption
                    }

                    $Results.Add($result)

                    Write-Log "  -> VERLINKT: $($adObject.DistinguishedName)" "Green"
                    Write-Log "     Aktiviert: $linkEnabled | Enforced: $enforced" "Gray"
                }
            }
        }
    }

    # --------------------------------------------------------
    # GPO ist nicht verlinkt
    # --------------------------------------------------------

    if (-not $foundLink) {

        $result = [PSCustomObject]@{
            GPOName        = $gpoName
            GUID           = $gpoGuid
            Status         = "NICHT VERLINKT"
            VerknuepftMit  = ""
            ObjektTyp     = ""
            LinkAktiviert = ""
            Enforced      = ""
            LinkOption     = ""
        }

        $Results.Add($result)

        Write-Log "  -> NICHT VERLINKT" "Yellow"
    }

    Write-Log ""
}

# ============================================================
# AUSWERTUNG
# ============================================================

Write-Log "============================================================" "Cyan"
Write-Log "AUSWERTUNG" "Cyan"
Write-Log "============================================================" "Cyan"

$totalGpos = $gpos.Count

$linkedGpos = @(
    $Results |
    Where-Object { $_.Status -eq "VERLINKT" } |
    Select-Object GPOName, GUID -Unique
).Count

$unlinkedGpos = @(
    $Results |
    Where-Object { $_.Status -eq "NICHT VERLINKT" }
).Count

$totalLinks = @(
    $Results |
    Where-Object { $_.Status -eq "VERLINKT" }
).Count

Write-Log "GPOs gesamt          : $totalGpos"
Write-Log "GPOs verlinkt        : $linkedGpos" "Green"
Write-Log "GPOs nicht verlinkt  : $unlinkedGpos" "Yellow"
Write-Log "Verknüpfungen gesamt : $totalLinks" "Cyan"
Write-Log ""

# ============================================================
# NICHT VERLINKTE GPOs
# ============================================================

Write-Log "============================================================" "Yellow"
Write-Log "NICHT VERLINKTE GPOs" "Yellow"
Write-Log "============================================================" "Yellow"

$unlinked = @(
    $Results |
    Where-Object { $_.Status -eq "NICHT VERLINKT" } |
    Sort-Object GPOName
)

if ($unlinked.Count -eq 0) {

    Write-Log "Keine nicht verlinkten GPOs gefunden." "Green"

}
else {

    foreach ($item in $unlinked) {

        Write-Log "$($item.GPOName) [$($item.GUID)]" "Yellow"
    }
}

Write-Log ""

# ============================================================
# VERLINKTE GPOs
# ============================================================

Write-Log "============================================================" "Green"
Write-Log "VERLINKTE GPOs UND IHRE ZIELE" "Green"
Write-Log "============================================================" "Green"

$linked = @(
    $Results |
    Where-Object { $_.Status -eq "VERLINKT" } |
    Sort-Object GPOName, VerknuepftMit
)

foreach ($item in $linked) {

    Write-Log ""
    Write-Log "GPO: $($item.GPOName)" "Green"
    Write-Log "GUID: $($item.GUID)" "Gray"
    Write-Log "Ziel: $($item.VerknuepftMit)" "White"
    Write-Log "Typ : $($item.ObjektTyp)" "White"
    Write-Log "Link aktiviert: $($item.LinkAktiviert)" "White"
    Write-Log "Enforced       : $($item.Enforced)" "White"
}

# ============================================================
# CSV EXPORT
# ============================================================

try {

    $Results |
        Sort-Object GPOName, VerknuepftMit |
        Export-Csv `
            -Path $CsvPath `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Log ""
    Write-Log "CSV gespeichert: $CsvPath" "Cyan"

}
catch {

    Write-Log "FEHLER beim CSV-Export: $($_.Exception.Message)" "Red"
}

# ============================================================
# TXT EXPORT
# ============================================================

try {

    $LogLines |
        Out-File `
            -FilePath $TxtPath `
            -Encoding UTF8

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "AUDIT ABGESCHLOSSEN" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "GPOs gesamt         : $totalGpos"
    Write-Host "GPOs verlinkt       : $linkedGpos" -ForegroundColor Green
    Write-Host "GPOs nicht verlinkt : $unlinkedGpos" -ForegroundColor Yellow
    Write-Host "Links gesamt        : $totalLinks"
    Write-Host ""
    Write-Host "TXT-Protokoll:" -ForegroundColor Cyan
    Write-Host $TxtPath
    Write-Host ""
    Write-Host "CSV-Ausgabe:" -ForegroundColor Cyan
    Write-Host $CsvPath
    Write-Host ""

}
catch {

    Write-Log "FEHLER beim TXT-Export: $($_.Exception.Message)" "Red"
}
