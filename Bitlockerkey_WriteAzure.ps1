$Volume = Get-BitLockerVolume -MountPoint "C:"
$ProtectorId = ($Volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId
BackupToAAD-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $ProtectorId
