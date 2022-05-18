﻿& $PSScriptRoot/ProfileCommon.ps1

# oh-my-posh v3
function Set-PoshContextEnvironment {
    $stackDepth = (Get-Location -Stack).Count
    $env:LOCATION_STACK_DEPTH = @{ $true = ''; $false = "$stackDepth" }[0 -eq $stackDepth];
    Write-Host $env:LOCATION_STACK_DEPTH
}

if ($null -ne (Get-Command "oh-my-posh" -ErrorAction Ignore)) {
    oh-my-posh init pwsh --config $PSScriptRoot/themes/illig.json | Invoke-Expression
    New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshContextEnvironment' -Scope Global
} else {
    Write-Warning "oh-my-posh not detected. Install to get the prompt: https://ohmyposh.dev/docs/"
}
