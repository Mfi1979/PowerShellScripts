<#
.SYNOPSIS
    Collects Windows 11 readiness and hardware lifecycle inventory data
    from Active Directory computer objects.

.DESCRIPTION
    This script enumerates computer objects from Active Directory and
    attempts to collect hardware, operating system, TPM, Secure Boot,
    BIOS, storage, and lifecycle information using CIM and PowerShell
    remoting.

    Results are exported to a timestamped CSV file in the ../data folder
    relative to the script location. A second copy named
    "Windows11_Readiness_Latest.csv" is also created for downstream
    reporting and enrichment workflows.

    This inventory is intended to support:
        - Windows 11 readiness assessments
        - Hardware refresh planning
        - Warranty and lifecycle management
        - Asset inventory reporting
        - Future manufacturer warranty/EOL lookups

.REQUIREMENTS
    - PowerShell 5.1 or later
    - ActiveDirectory PowerShell module
    - Domain connectivity
    - Permissions to query Active Directory
    - Network connectivity to target computers
    - Remote CIM/WMI access to target computers
    - PowerShell remoting (WinRM) for TPM and Secure Boot collection

.CONFIGURATION

    IMPORTANT:

    Before executing this script, verify that the Active Directory
    SearchBase variable reflects the location of computer accounts
    in your environment.

    Current example:

        $SearchBase =
        "OU=<YOUR INFO HERE>,OU=<YOUROU>,DC=<YOURDOMAIN>,DC=<loc/com whatever>"

    Organizations with a different AD structure MUST modify this value.

    Examples:

        Corporate Forest:
        "OU=Workstations,DC=contoso,DC=com"

        Regional OU:
        "OU=Computers,OU=Texas,DC=contoso,DC=com"

        Entire Domain:
        "DC=contoso,DC=com"

    Using an incorrect SearchBase may result in:
        - Missing systems
        - Incomplete inventory results
        - No results returned

.OUTPUTS
    CSV inventory file containing:

        - AD information
        - Network reachability
        - Manufacturer
        - Model
        - Serial number
        - BIOS information
        - Processor information
        - Memory information
        - TPM status
        - Secure Boot status
        - Storage information
        - Windows version information
        - Windows 11 readiness status

.EXAMPLE
    PS C:\> .\Inventory.ps1

    Runs the inventory against the configured SearchBase
    and exports the results to the data folder.

.EXAMPLE
    PS C:\> Get-Help .\Inventory.ps1 -Full

    Displays complete script documentation.

.NOTES
    Author: John Kotski
    Version: 1.0

    Change Log

    1.0
        Initial release
        Windows 11 readiness inventory
        Hardware lifecycle data collection
        Timestamped CSV exports
        Latest.csv reporting copy

#>

Import-Module ActiveDirectory

########################################################################
# CONFIGURATION
#
# IMPORTANT:
# Update this value to match the OU containing computer accounts in
# your Active Directory environment before executing the script.
#
# See the examples above for format
########################################################################

$SearchBase = "OU=<YOUR INFO HERE>,OU=<YOUROU>,DC=<YOURDOMAIN>,DC=<loc/com whatever>"

# Determine paths

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataFolder = Join-Path (Split-Path $ScriptRoot -Parent) "data"

# Create data folder if needed

if (-not (Test-Path $DataFolder))
{
    New-Item -Path $DataFolder -ItemType Directory -Force | Out-Null
}

# Timestamped filename

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$OutputFile = Join-Path `
    $DataFolder `
    "Windows11_Readiness_$TimeStamp.csv"


$Results = @()

$Computers = Get-ADComputer `
    -SearchBase $SearchBase `
    -Filter * `
    -Properties OperatingSystem,
                OperatingSystemVersion,
                LastLogonDate,
                Enabled

foreach ($Computer in $Computers)
{
    Write-Host "Processing $($Computer.Name)..." -ForegroundColor Cyan

    $Online = Test-Connection `
        -ComputerName $Computer.Name `
        -Count 1 `
        -Quiet `
        -ErrorAction SilentlyContinue

    $Record = [ordered]@{
        ComputerName           = $Computer.Name
        Enabled                = $Computer.Enabled
        DistinguishedName      = $Computer.DistinguishedName
        ADOperatingSystem      = $Computer.OperatingSystem
        ADOperatingSystemVer   = $Computer.OperatingSystemVersion
        LastLogon              = $Computer.LastLogonDate
        ReportDate             = Get-Date

        DNSResolved            = $false
        PingSuccess            = $Online
        WinRMAvailable         = $false

        Manufacturer           = $null
        ManufacturerNormalized = $null
        Model                  = $null
        ChassisType            = $null
        SerialNumber           = $null
        DeviceAgeYears         = $null

        CPU                    = $null
        RAMGB                  = $null

        TPMPresent             = $null
        TPMVersion             = $null
        TPMSpecVersion         = $null

        SecureBootEnabled      = $null

        DiskSizeGB             = $null
        DiskFreeGB             = $null

        BIOSVersion            = $null
        BIOSReleaseDate        = $null

        CurrentOS              = $null
        OSBuild                = $null
        InstallDate            = $null

        WarrantyExpiration     = $null
        ManufacturerEOL        = $null
        RefreshYear            = $null
        IPAddress              = $null


        LastBootTime           = $null
        Win11Ready             = $false
        Win11UnsupportedCpu    = $false
        Tpm20                  = $false

    }

    try
    {
        Resolve-DnsName $Computer.Name -ErrorAction Stop | Out-Null
        $Record.DNSResolved = $true
    }
    catch {}

    if ($Online)
    {
        try {
            $Record.IPAddress =
                (Resolve-DnsName $Computer.Name -Type A -ErrorAction Stop |
                    Select-Object -First 1 -ExpandProperty IPAddress)
        }
        catch {}

       
        
        try {
            Test-WSMan $Computer.Name -ErrorAction Stop | Out-Null
            $Record.WinRMAvailable = $true
        }
        catch {
            $Record.WinRMAvailable = $false
        }

        try
        {
            $CimParams = @{
                ComputerName = $Computer.Name
                ErrorAction  = 'Stop'
            }

            $System = Get-CimInstance @CimParams `
                -ClassName Win32_ComputerSystem

            $BIOS = Get-CimInstance @CimParams `
                -ClassName Win32_BIOS

            $CPU = Get-CimInstance @CimParams `
                -ClassName Win32_Processor

            $OS = Get-CimInstance @CimParams `
                -ClassName Win32_OperatingSystem

            $Disk = Get-CimInstance @CimParams `
                -ClassName Win32_LogicalDisk `
                -Filter "DeviceID='C:'"

            Write-Host "$($Computer.Name)"
            Write-Host "BIOS ReleaseDate: [$($BIOS.ReleaseDate)]"
            Write-Host "BIOS Type: $($BIOS.ReleaseDate.GetType().FullName)"

            Write-Host "InstallDate: [$($OS.InstallDate)]"
            Write-Host "Install Type: $($OS.InstallDate.GetType().FullName)"

            Write-Host "LastBootUpTime: [$($OS.LastBootUpTime)]"
            Write-Host "LastBoot Type: $($OS.LastBootUpTime.GetType().FullName)"

            $Enclosure = Get-CimInstance @CimParams -ClassName Win32_SystemEnclosure

            $Record.ChassisType = ($Enclosure.ChassisTypes -join ',')

            $Record.LastBootTime = $OS.LastBootUpTime
            
            $Record.Manufacturer = $System.Manufacturer
            $Record.ManufacturerNormalized =
                switch -Regex ($System.Manufacturer)
                {
                    "Dell"    { "Dell" }
                    "HP|Hewlett" { "HP" }
                    "Lenovo"  { "Lenovo" }
                    default   { $System.Manufacturer }
                }

            $Record.Model = $System.Model
            $Record.SerialNumber = $BIOS.SerialNumber

            $Record.CPU = $CPU.Name

            $Record.RAMGB =
                [Math]::Round(
                    $System.TotalPhysicalMemory / 1GB,
                    2
                )


            $Record.CurrentOS = $OS.Caption
            $Record.OSBuild = $OS.BuildNumber
            $Record.InstallDate = $OS.InstallDate

            $Record.BIOSVersion =
                ($BIOS.SMBIOSBIOSVersion -join ",")

            $Record.BIOSReleaseDate = $BIOS.ReleaseDate

            $Record.DeviceAgeYears =
                [math]::Round(
                    ((Get-Date) - $BIOS.ReleaseDate).TotalDays / 365,
                    1
                )

            if ($Disk)
            {
                $Record.DiskSizeGB =
                    [Math]::Round($Disk.Size / 1GB,2)

                $Record.DiskFreeGB =
                    [Math]::Round($Disk.FreeSpace / 1GB,2)
            }

            try
            {
                $TPM = Invoke-Command `
                    -ComputerName $Computer.Name `
                    -ScriptBlock {
                        Get-Tpm
                    } `
                    -ErrorAction Stop

                $Record.TPMPresent = $TPM.TpmPresent

                if ($TPM.ManufacturerVersion)
                {
                    $Record.TPMVersion = $TPM.ManufacturerVersion
                    $Record.TPMSpecVersion = $TPM.SpecVersion
                    if ($TPM.SpecVersion -match "2.0")
                    {
                        $Record.TPM20 = $true
                    }
                }
            }
            catch {}

            try
            {
                $Record.SecureBootEnabled =
                    Invoke-Command `
                        -ComputerName $Computer.Name `
                        -ScriptBlock {
                            Confirm-SecureBootUEFI
                        } `
                        -ErrorAction Stop
            }
            catch {}
        }
        catch
        {
            Write-Warning "Computer: $($Computer.Name)"
            Write-Warning "Message: $($_.Exception.Message)"
            Write-Warning "Line: $($_.InvocationInfo.ScriptLineNumber)"
            Write-Warning "Code: $($_.InvocationInfo.Line)"
        }
    }

    $Results += New-Object PSObject -Property $Record
}

$Results | ForEach-Object {

    $_.Win11Ready =
    (
        $_.RAMGB -ge 4 -and
        $_.DiskSizeGB -ge 64 -and
        $_.TPMPresent -eq $true -and
        $_.SecureBootEnabled -eq $true
    )
}

$Results |
    Export-Csv `
    -Path $OutputFile `
    -NoTypeInformation `
    -Encoding UTF8

$LatestFile = Join-Path $DataFolder "Windows11_Readiness_Latest.csv"

Copy-Item `
    -Path $OutputFile `
    -Destination $LatestFile `
    -Force

Write-Host ""
Write-Host "Inventory complete." -ForegroundColor Green
Write-Host "Output file: $OutputFile" -ForegroundColor Green


Write-Host ""
Write-Host "Inventory complete." -ForegroundColor Green
Write-Host "Output file: $OutputFile" -ForegroundColor Green

Write-Host ""
Write-Host "Systems Found: $($Results.Count)"

Write-Host "Online: $(
    ($Results | Where-Object PingSuccess).Count
)"

Write-Host "Win11 Ready: $(
    ($Results | Where-Object Win11Ready).Count
)"

