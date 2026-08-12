. (Join-Path -Path $PSScriptRoot -ChildPath ProfileDiagnostics.ps1)
Initialize-ProfileDiagnostics

Write-ProfileLog 'Importing modules'
# Don't import PSScriptAnalyzer or Pester - these will get auto-imported on usage.
@('Terminal-Icons', 'Illig') | ForEach-Object {
    $moduleName = $_
    Write-ProfileLog "  Importing $moduleName"
    Import-Module $moduleName -ErrorAction Stop
    Write-ProfileLog "  Imported $moduleName"
}

Write-ProfileLog 'Modules imported'

# Paths: Put user-specific paths in the OS location for that.
# - On Windows, System/Advanced System Settings/Environment Variables
# - On Mac/Linux, /etc/profile like
# PATH="$PATH:$HOME/go/bin:$HOME/.dotnet/tools:$HOME/.krew/bin"

# Windows defaults to ASCII; set UTF-8 and verify ANSI color support.
Set-ConsoleEncoding -UTF8
$Env:PYTHONIOENCODING = 'UTF-8'
Test-AnsiSupport | Out-Null

# Azure Artifacts Credential Provider doesn't actually cache the token very long
# unless you keep MSAL enabled.
# https://developercommunity.visualstudio.com/t/azure-artifacts-credential-provider-unable-to-auth/1519587
# https://github.com/microsoft/artifacts-credprovider/issues/234
$Env:NUGET_CREDENTIALPROVIDER_MSAL_ENABLED = 'true'

# Update path settings for Windows-specific settings.
if ($isDesktop -or $IsWindows) {
    # Put the user paths before the machine paths so dotnet install overrides are possible.
    $combined = [System.Collections.ArrayList][System.Environment]::GetEnvironmentVariable('PATH').Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    $userSegments = [System.Environment]::GetEnvironmentVariable('PATH', 'User').Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    $userSegments | ForEach-Object { $combined.Remove($_) }
    $combined.InsertRange(0, $userSegments)
    [System.Environment]::SetEnvironmentVariable('PATH', ($combined -join ';'))
}

# Fix double-wide XML icon in Terminal-Icons
# https://github.com/devblackops/Terminal-Icons/issues/34
if ($Null -ne (Get-Module Terminal-Icons)) {
    Set-TerminalIconsIcon -Glyph 'nf-mdi-xml' -NewGlyph 'nf-mdi-file_xml'
}

# Aliases
Set-Alias -Name which -Value Get-Command

# MacOS/dotnet fix - some dotnet global commands require DOTNET_HOST_PATH but
# that doesn't always get set by the dotnet CLI.
$dotnetLocation = Get-Command 'dotnet' -ErrorAction Ignore
if ($null -ne $dotnetLocation) {
    [System.Environment]::SetEnvironmentVariable('DOTNET_HOST_PATH', $dotnetLocation.Source)
}

# Chocolatey profile
if ($isDesktop -or $IsWindows) {
    $ChocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
    if (Test-Path($ChocolateyProfile)) {
        Import-Module "$ChocolateyProfile"
    }
}

# Homebrew settings
if ($IsMacOS -and ($null -ne (Get-Command 'brew' -ErrorAction Ignore))) {
    Write-ProfileLog 'Homebrew shell environment'
    # Uncomment this if you re-enable the brew shell completions below.
    # $script:brewPrefix = & brew --prefix
    . ([scriptblock]::Create((& brew shellenv | Out-String)))
    Write-ProfileLog 'Homebrew shell environment complete'
}


# nvs auto version switching - https://github.com/jasongin/nvs
if ($null -ne (Get-Command 'nvs' -ErrorAction Ignore)) {
    Write-ProfileLog 'nvs auto version switching'
    if (Test-Path '~/.nvmrc') {
        nvs use auto | Out-Null
    }

    nvs auto on
    Write-ProfileLog 'nvs auto version switching complete'
}

# Use nice menu completion for Tab instead of the default completion.
Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete

# PowerShell parameter completion shim for the dotnet CLI
Get-Command dotnet -ErrorAction Ignore | Out-Null
if ($?) {
    Write-ProfileLog 'dotnet completion registration'
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        # Signature is fixed by Register-ArgumentCompleter; not all params are used.
        $null = $commandName
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
    Write-ProfileLog 'dotnet completion registration complete'
}

# Lazy-load git-completion: import the module on first Tab, then delegate to it.
# As of git-completion 2.0.0 the module no longer registers a completer itself, so
# this block stays in place permanently and calls Complete-Git directly. Don't call
# CommandCompletion::CompleteInput here - it would re-enter this same completer and
# recurse until Tab appears to hang.
Write-ProfileLog 'Registering deferred git-completion'
$global:GitCompletionSettings = @{
    ShowAllCommand     = $true
    AdditionalCommands = [string[]]@('force-pull', 'branch-diff')
}
Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    # Signature is fixed by Register-ArgumentCompleter; the full AST is used instead.
    $null = $wordToComplete
    Import-Module git-completion -Global
    Complete-Git -CommandAst $commandAst -CursorPosition $cursorPosition
}
Write-ProfileLog 'Deferred git-completion registered'

# PowerShell native completions
Write-ProfileLog 'Native completions (helm, istioctl, k9s, kubectl, etc.)'
@('crane', 'helm', 'istioctl', 'k9s', 'kubectl', 'minikube', 'oras', 'skopeo') | ForEach-Object {
    $command = $_
    if (Get-Command $command -ErrorAction SilentlyContinue) {
        Write-ProfileLog "  Generating completions for $command"
        . ([scriptblock]::Create((& $command completion powershell | Out-String)))
        Write-ProfileLog "  Completions for $command complete"
    }
}
Write-ProfileLog 'Native completions complete'

# az CLI
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli&pivots=winget#enable-tab-completion-in-powershell
if ($null -ne (Get-Command 'az' -ErrorAction Ignore)) {
    Write-ProfileLog 'az CLI completion registration'
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        # Signature is fixed by Register-ArgumentCompleter; not all params are used.
        $null = $commandName
        $completion_file = New-TemporaryFile
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
        $env:COMP_LINE = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        $env:_ARGCOMPLETE = 1
        $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
        $env:_ARGCOMPLETE_IFS = "`n"
        $env:_ARGCOMPLETE_SHELL = 'powershell'
        az 2>&1 | Out-Null
        Get-Content $completion_file | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
    }
    Write-ProfileLog 'az CLI completion registration complete'
}

# For commands installed by Homebrew that also generate Powershell completions,
# register those. https://docs.brew.sh/Shell-Completion
#
# Currently ignored to allow completions to be generated by the native command
# output above and also work on Windows. If you re-enable this, also uncomment
# the setting of brewPrefix, above.
#
# if ($null -ne $script:brewPrefix -and (Test-Path ($completions = "$script:brewPrefix/share/pwsh/completions"))) {
#     Write-ProfileLog 'Homebrew PowerShell completions'
#     foreach ($f in Get-ChildItem -Path $completions -File) {
#         . $f
#     }
#     Write-ProfileLog 'Homebrew PowerShell completions complete'
# }

# Bash completions in PowerShell - only register if the command is found.
$enableBashCompletions = ([String]::IsNullOrEmpty($env:DISABLE_BASH_COMPLETIONS)) -and (($Null -ne (Get-Command bash -ErrorAction Ignore)) -or ($Null -ne (Get-Command git -ErrorAction Ignore)))
if ($enableBashCompletions) {
    Write-ProfileLog 'Bash completions'
    Import-Module PSBashCompletions
    $completionPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($profile), 'bash-completion')
    Get-ChildItem $completionPath -Exclude '.editorconfig' | ForEach-Object {
        $completerFullPath = $_.FullName
        $completerCommandName = $_.Name
        if (Get-Command $completerCommandName -ErrorAction SilentlyContinue) {
            Register-BashArgumentCompleter $completerCommandName "$completerFullPath"
        }
    }
    Write-ProfileLog 'Bash completions complete'
}

# Set kubectl editor to VS Code if it's present.
Get-Command code -ErrorAction Ignore | Out-Null
if ($?) {
    $Env:KUBE_EDITOR = 'code --wait'
}
