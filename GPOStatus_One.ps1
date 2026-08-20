# ============================================
# TEST: Eine GPO auf Verknüpfungen prüfen
# ============================================

Import-Module ActiveDirectory
Import-Module GroupPolicy

# --------------------------------------------
# GPO festlegen
# --------------------------------------------

$gpoName = "OLD_Creo_View"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " GPO LINK TEST" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------
# GPO ermitteln
# --------------------------------------------

try {
    $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
}
catch {
    Write-Host "GPO '$gpoName' wurde nicht gefunden!" -ForegroundColor Red
    return
}

$gpoGuid = $gpo.Id.ToString()

Write-Host "GPO     : $($gpo.DisplayName)" -ForegroundColor Green
Write-Host "GUID    : $gpoGuid" -ForegroundColor Green
Write-Host ""

# --------------------------------------------
# AD-Domäne ermitteln
# --------------------------------------------

$domain = Get-ADDomain

Write-Host "Domäne  : $($domain.DNSRoot)" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------
# Alle möglichen Verknüpfungsstellen suchen
# --------------------------------------------
#
# GPO-Verknüpfungen befinden sich als
# gpLink-Attribut an:
#
# - Domäne
# - OUs
# - Sites
#
# --------------------------------------------

Write-Host "Suche nach Verknüpfungen..." -ForegroundColor Yellow
Write-Host ""

$searchBases = @()

# Domäne
$searchBases += $domain.DistinguishedName

# Alle OUs
$ous = Get-ADOrganizationalUnit -Filter * -Properties gpLink, gpOptions

foreach ($ou in $ous) {
    $searchBases += $ou.DistinguishedName
}

# --------------------------------------------
# Ergebnisliste
# --------------------------------------------

$results = @()

foreach ($searchBase in $searchBases) {

    try {

        $object = Get-ADObject `
            -Identity $searchBase `
            -Properties gpLink, gpOptions `
            -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($object.gpLink)) {
            continue
        }

        # gpLink enthält mehrere GPO-Verknüpfungen
        $gpLinks = $object.gpLink -split '\]\['

        foreach ($gpLink in $gpLinks) {

            # GUID aus dem gpLink extrahieren
            if ($gpLink -match '\{([0-9A-Fa-f-]+)\}') {

                $linkedGuid = $Matches[1]

                # Prüfen, ob es unsere GPO ist
                if ($linkedGuid -eq $gpoGuid) {

                    # Link-Optionen auswerten
                    #
                    # 0 = aktiviert
                    # 1 = deaktiviert
                    # 2 = Enforced
                    # 3 = deaktiviert + Enforced
                    #

                    $linkState = 0

                    if ($gpLink -match '\](\d+)$') {
                        $linkState = [int]$Matches[1]
                    }

                    switch ($linkState) {

                        0 {
                            $enabled = $true
                            $enforced = $false
                        }

                        1 {
                            $enabled = $false
                            $enforced = $false
                        }

                        2 {
                            $enabled = $true
                            $enforced = $true
                        }

                        3 {
                            $enabled = $false
                            $enforced = $true
                        }

                        default {
                            $enabled = $null
                            $enforced = $null
                        }
                    }

                    $results += [PSCustomObject]@{
                        GPOName        = $gpo.DisplayName
                        GPOGuid        = $gpoGuid
                        VerknuepftMit  = $object.DistinguishedName
                        ObjektTyp      = $object.ObjectClass
                        LinkAktiviert  = $enabled
                        Enforced       = $enforced
                        LinkOption     = $linkState
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Fehler bei: $searchBase" -ForegroundColor Red
    }
}

# --------------------------------------------
# Ergebnis
# --------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " ERGEBNIS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($results.Count -eq 0) {

    Write-Host "GPO '$($gpo.DisplayName)' ist NICHT verlinkt." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Es wurde keine OU bzw. Domäne mit einem" -ForegroundColor Gray
    Write-Host "gpLink auf diese GPO gefunden." -ForegroundColor Gray
}
else {

    Write-Host "GPO '$($gpo.DisplayName)' ist an folgenden Stellen verlinkt:" -ForegroundColor Green
    Write-Host ""

    $results |
        Format-Table `
            GPOName,
            VerknuepftMit,
            ObjektTyp,
            LinkAktiviert,
            Enforced,
            LinkOption `
            -AutoSize
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
