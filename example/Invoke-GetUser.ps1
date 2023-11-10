
Import-Module ./modules/ExampleModule.psm1 -Force

$name = "Henry"

$myUser = Get-User -AccountName $name

Write-Host $myUser.sAMAccountName
