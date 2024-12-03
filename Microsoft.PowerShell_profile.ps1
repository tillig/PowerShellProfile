. $PSScriptRoot/ProfileCommon.ps1

# oh-my-posh v3
# This will run every time the prompt displays so it's important to keep it fast.
function Set-PoshContextEnvironment {
    # Enable the git segment to indicate if pre-commit is installed.
    If (Get-Command git -ErrorAction SilentlyContinue) {
        $repoRoot = git rev-parse --show-toplevel 2>&1
        If ($LASTEXITCODE -eq 0) {
            $preCommitHook = Test-Path (Join-Path $repoRoot '.git' 'hooks' 'pre-commit')
            $env:PRE_COMMIT_INSTALLED = @{ $true = '✓'; $false = '' }[$preCommitHook]
        }
    }

    # Enable the pushd/popd stack depth to be displayed.
    $stackDepth = (Get-Location -Stack).Count
    $env:LOCATION_STACK_DEPTH = @{ $true = ''; $false = "$stackDepth" }[0 -eq $stackDepth]
}

If ($null -ne (Get-Command 'oh-my-posh' -ErrorAction Ignore)) {
    oh-my-posh init pwsh --config $PSScriptRoot/themes/illig.json | Invoke-Expression
    New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshContextEnvironment' -Scope Global
}
Else {
    Write-Warning 'oh-my-posh not detected. Install to get the prompt: https://ohmyposh.dev/docs/'
    Write-Warning 'Falling back to script-based prompt. This is much slower than oh-my-posh.'
    Enable-ScriptBasedPrompt
}

If (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
If (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
