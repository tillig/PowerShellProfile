& $PSScriptRoot/ProfileCommon.ps1

# Custom oh-my-posh theme requires ability to get location stack.
$GetLocationStackCount = { (Get-Location -Stack).Count }
Set-Theme Illig
