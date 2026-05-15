. (Join-Path -Path $PSScriptRoot -ChildPath ProfileCommon.ps1)

# oh-my-posh v3
# This will run every time the prompt displays so it's important to keep it fast.
function Set-PromptContext {
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
    New-Alias -Name 'Set-PromptContext' -Value 'Set-PromptContext' -Scope Global
}
Else {
    Write-Warning 'oh-my-posh not detected. Install to get the prompt: https://ohmyposh.dev/docs/'
    Write-Warning 'Falling back to script-based prompt. This is much slower than oh-my-posh.'
    Enable-ScriptBasedPrompt
}

# Enable iTerm2 integration if running in iTerm2. This allows iTerm2 to show the
# current directory and remote host in the title bar. Must be done after
# oh-my-posh is initialized to ensure the prompt function is defined, but also
# to ensure the console output isn't captured/redirected by the prompt function.
# This is a bit hacky but iTerm2 doesn't provide a better way to do this.
if ($env:TERM_PROGRAM -eq 'iTerm.app') {
    $Global:__iterm2OriginalPrompt = $function:prompt
    function Global:prompt {
        # Report current context to iTerm2
        $dir = $PWD.ProviderPath
        [Console]::Write("`e]1337;CurrentDir=$dir`a")
        [Console]::Write("`e]1337;RemoteHost=$env:USER@$(hostname)`a")

        # Call the original prompt (oh-my-posh or whatever is configured)
        if ($Global:__iterm2OriginalPrompt) {
            & $Global:__iterm2OriginalPrompt
        }
    }
}

If (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
If (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
