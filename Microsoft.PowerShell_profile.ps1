. (Join-Path -Path $PSScriptRoot -ChildPath ProfileCommon.ps1)

# oh-my-posh v3
# This will run every time the prompt displays so it's important to keep it fast.
function Set-PromptContext {
    # Enable the git segment to indicate if pre-commit is installed.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $repoRoot = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -eq 0) {
            $preCommitHook = Test-Path (Join-Path $repoRoot '.git' 'hooks' 'pre-commit')
            $env:PRE_COMMIT_INSTALLED = @{ $true = '✓'; $false = '' }[$preCommitHook]
        }
    }

    # Enable the pushd/popd stack depth to be displayed.
    $stackDepth = (Get-Location -Stack).Count
    $env:LOCATION_STACK_DEPTH = @{ $true = ''; $false = "$stackDepth" }[0 -eq $stackDepth]

    # Enable iTerm2 integration if running in iTerm2. This allows iTerm2 to show
    # the current directory and remote host in the title bar.    if
    # ($env:TERM_PROGRAM -eq 'iTerm.app') {
    if ($env:TERM_PROGRAM -eq 'iTerm.app') {
        $dir = $PWD.ProviderPath
        [Console]::Write("`e]1337;CurrentDir=$dir`a")
        [Console]::Write("`e]1337;RemoteHost=$env:USER@$(hostname)`a")
    }
}

Write-ProfileLog 'oh-my-posh initialization'
if ($null -ne (Get-Command 'oh-my-posh' -ErrorAction Ignore)) {
    oh-my-posh init pwsh --config $PSScriptRoot/themes/illig.json | Invoke-Expression
    New-Alias -Name 'Set-PoshContext' -Value 'Set-PromptContext' -Scope Global
}
else {
    Write-Warning 'oh-my-posh not detected. Install to get the prompt: https://ohmyposh.dev/docs/'
    Write-Warning 'Falling back to script-based prompt. This is much slower than oh-my-posh.'
    Enable-ScriptBasedPrompt
}
Write-ProfileLog 'oh-my-posh initialization complete'

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

Complete-ProfileDiagnostics
