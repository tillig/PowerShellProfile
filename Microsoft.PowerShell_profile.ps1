& $PSScriptRoot/ProfileCommon.ps1

# oh-my-posh v3
function Set-PoshContextEnvironment {
    $stackDepth = (Get-Location -Stack).Count
    $env:LOCATION_STACK_DEPTH = @{ $true = ''; $false = "$stackDepth" }[0 -eq $stackDepth];
}
New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshContextEnvironment' -Scope Global
Set-PoshPrompt -Theme $PSScriptRoot/themes/illig.json
