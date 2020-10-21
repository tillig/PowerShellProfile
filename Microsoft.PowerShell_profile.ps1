& $PSScriptRoot/ProfileCommon.ps1

# oh-my-posh v2
$GetLocationStackCount = { (Get-Location -Stack).Count }
Set-Theme Illig

# oh-my-posh v3 - 10/21/2020 has some known PowerShell issues
## https://github.com/JanDeDobbeleer/oh-my-posh3/issues/65
# function Set-PoshContextEnvironment {
#     $stackDepth = (Get-Location -Stack).Count
#     $env:LOCATION_STACK_DEPTH = @{ $true = ''; $false = "$stackDepth" }[0 -eq $stackDepth];
# }
# New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshContextEnvironment' -Scope Global
# Set-PoshPrompt -Theme $PSScriptRoot/themes/illig.json
