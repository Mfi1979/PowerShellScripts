Import-Module ActiveDirectory

$TargetOU_DN = "CN=Computers,DC=Domain,DC=net"
$GroupName   = "ADS-SEC-Clients-DomainJoin"

$TargetOU = [ADSI]"LDAP://$TargetOU_DN"
$ACL = $TargetOU.ObjectSecurity
$GroupSID = (Get-ADGroup -Identity $GroupName).SID.Value
$IdentityRef = [System.Security.Principal.SecurityIdentifier]::new($GroupSID)
$ComputerClassGUID = [System.Guid]::Parse("BF967A86-0DE6-11D0-A285-00AA003049E2")

# Nur Erstell-Rechte delegieren
$AccessRule = [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
    $IdentityRef,
    [System.DirectoryServices.ActiveDirectoryRights]::CreateChild,
    [System.Security.AccessControl.AccessControlType]::Allow,
    $ComputerClassGUID,
    [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All
)
$ACL.AddAccessRule($AccessRule)
$TargetOU.CommitChanges()
