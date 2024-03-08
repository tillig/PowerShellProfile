Import-Module VSSetup
Import-Module PSScriptAnalyzer
Import-Module Pester
Import-Module Terminal-Icons
Import-Module Illig

# Paths: Put user-specific paths in the OS location for that.
# - On Windows, System/Advanced System Settings/Environment Variables
# - On Mac/Linux, /etc/profile like
# PATH="$PATH:$HOME/go/bin:$HOME/.dotnet/tools:$HOME/.krew/bin"

# Windows defaults to ASCII; set UTF-8 and verify ANSI color support.
Set-ConsoleEncoding -UTF8
$Env:PYTHONIOENCODING = "UTF-8"
Test-AnsiSupport | Out-Null

# Azure Artifacts Credential Provider doesn't actually cache the token very long
# unless you keep MSAL enabled.
# https://developercommunity.visualstudio.com/t/azure-artifacts-credential-provider-unable-to-auth/1519587
# https://github.com/microsoft/artifacts-credprovider/issues/234
$Env:NUGET_CREDENTIALPROVIDER_MSAL_ENABLED = "true"

# Update path settings for Windows-specific settings.
If ($isDesktop -or $IsWindows) {
    # Import VS environment
    # As of VS 2019 16.2 there's a PowerShell module for developer VS prompt.
    # However, it is NOT compatible with PowerShell Core.
    # Instance ID can be found when locating the VS install information.
    # C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "& { Import-Module .\Common7\Tools\vsdevshell\Microsoft.VisualStudio.DevShell.dll; Enter-VsDevShell -InstanceId 5a7ac072}"
    Invoke-VisualStudioDevPrompt

    # Put the user paths before the machine paths so dotnet install overrides are possible.
    $combined = [System.Collections.ArrayList][System.Environment]::GetEnvironmentVariable("PATH").Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
    $userSegments = [System.Environment]::GetEnvironmentVariable("PATH", "User").Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
    $userSegments | ForEach-Object { $combined.Remove($_) }
    $combined.InsertRange(0, $userSegments)
    [System.Environment]::SetEnvironmentVariable("PATH", ($combined -join ";"))
}

# Fix double-wide XML icon in Terminal-Icons
# https://github.com/devblackops/Terminal-Icons/issues/34
If ($Null -ne (Get-Module Terminal-Icons)) {
    Set-TerminalIconsIcon -Glyph "nf-mdi-xml" -NewGlyph "nf-mdi-file_xml"
}

# Aliases
Set-Alias -Name which -Value Get-Command

# MacOS/dotnet fix - some dotnet global commands require DOTNET_HOST_PATH but
# that doesn't always get set by the dotnet CLI.
$dotnetLocation = Get-Command "dotnet" -ErrorAction Ignore
if ($null -ne $dotnetLocation) {
    [System.Environment]::SetEnvironmentVariable("DOTNET_HOST_PATH", $dotnetLocation.Source)
}

# Chocolatey profile
if ($isDesktop -or $IsWindows) {
    $ChocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
    if (Test-Path($ChocolateyProfile)) {
        Import-Module "$ChocolateyProfile"
    }
}

# Homebrew settings
if ($IsMacOS -and ($null -ne (Get-Command "brew" -ErrorAction Ignore))) {
    $(brew shellenv) | Invoke-Expression
}


# nvs auto version switching - https://github.com/jasongin/nvs
if ($null -ne (Get-Command "nvs" -ErrorAction Ignore)) {
    if (Test-Path "~/.nvmrc") {
        nvs use auto | Out-Null
    }

    nvs auto on
}

# PowerShell parameter completion shim for the dotnet CLI
Get-Command dotnet -ErrorAction Ignore | Out-Null
if ($?) {
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# PowerShell native completions
@("helm", "istioctl", "k9s", "kubectl") | ForEach-Object {
    $command = $_
    if (Get-Command $command -ErrorAction SilentlyContinue) {
        & $command completion powershell | Out-String | Invoke-Expression
    }
}

# Bash completions in PowerShell
$enableBashCompletions = ($Null -ne (Get-Command bash -ErrorAction Ignore)) -or ($Null -ne (Get-Command git -ErrorAction Ignore))
if ($enableBashCompletions) {
    Import-Module PSBashCompletions
    $completionPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($profile), "bash-completion")
    Get-ChildItem $completionPath -Exclude ".editorconfig" | ForEach-Object {
        $completerFullPath = $_.FullName
        $completerCommandName = $_.Name
        Register-BashArgumentCompleter $completerCommandName "$completerFullPath"
    }
}

# Set kubectl editor to VS Code if it's present.
Get-Command code -ErrorAction Ignore | Out-Null
if ($?) {
    $Env:KUBE_EDITOR = "code --wait"
}
