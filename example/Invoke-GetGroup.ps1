
Import-Module ./modules/ExampleModule.psm1 -Force

$name = "Group1"

$myGroup = Get-Group -AccountName $name

Write-Host $myGroup.sAMAccountName