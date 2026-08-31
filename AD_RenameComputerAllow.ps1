Import-Module ActiveDirectory

$TargetOU_DN = "OU=Rechner,DC=Domain,DC=net"
$GroupName   = "ADS-SEC-Clients-ManageComputers"

$TargetOU = [ADSI]"LDAP://$TargetOU_DN"
$ACL = $TargetOU.ObjectSecurity
$GroupSID = (Get-ADGroup -Identity $GroupName).SID.Value
$IdentityRef = [System.Security.Principal.SecurityIdentifier]::new($GroupSID)

$ComputerClassGUID = [System.Guid]::Parse("BF967A86-0DE6-11D0-A285-00AA003049E2")
$InheritanceAll     = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All

# Notwendig: CreateChild, DeleteChild UND WriteProperty auf Computer-Objekten
$Rights = [System.DirectoryServices.ActiveDirectoryRights]::CreateChild `
    -bor [System.DirectoryServices.ActiveDirectoryRights]::DeleteChild `
    -bor [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty `
    -bor [System.DirectoryServices.ActiveDirectoryRights]::Delete

$AccessRule = [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
    $IdentityRef,
    $Rights,
    [System.Security.AccessControl.AccessControlType]::Allow,
    $ComputerClassGUID,
    $InheritanceAll
)

$ACL.AddAccessRule($AccessRule)
$TargetOU.CommitChanges()
Write-Host "Rechte für Computer-Rename erfolgreich erweitert!" -ForegroundColor Green
