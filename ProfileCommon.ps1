Import-Module oh-my-posh
Import-Module VSSetup
Import-Module ClipboardText
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

# Import VS environment
# As of VS 2019 16.2 there's a PowerShell module for developer VS prompt.
# However, it is NOT compatible with PowerShell Core.
# Instance ID can be found when locating the VS install information.
# C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "& { Import-Module .\Common7\Tools\vsdevshell\Microsoft.VisualStudio.DevShell.dll; Enter-VsDevShell -InstanceId 5a7ac072}"
If (($isDesktop -or $IsWindows)) {
    Invoke-VisualStudioDevPrompt
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

# Bash completions in PowerShell
$enableBashCompletions = ($Null -ne (Get-Command bash -ErrorAction Ignore)) -or ($Null -ne (Get-Command git -ErrorAction Ignore))
if ($enableBashCompletions) {
    Import-Module PSBashCompletions
    $completionPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($profile), "bash-completion")
    Get-ChildItem $completionPath -Exclude ".editorconfig" | ForEach-Object {
        $completerFullPath = $_.FullName
        $completerCommandName = $_.Name
        Write-Host "$completerCommandName = $completerFullPath"
        Register-BashArgumentCompleter $completerCommandName "$completerFullPath"
    }
}

# Set kubectl editor to VS Code if it's present.
Get-Command code -ErrorAction Ignore | Out-Null
if ($?) {
    $Env:KUBE_EDITOR = "code --wait"
}
