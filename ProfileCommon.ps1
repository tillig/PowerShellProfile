Import-Module PSReadline
Import-Module Microsoft.PowerShell.Archive
Import-Module posh-git
Import-Module oh-my-posh
Import-Module VSSetup
Import-Module ClipboardText
Import-Module Illig

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

# Aliases
Set-Alias -Name which -Value Get-Command

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

# Only try enabling bash completions if bash/Git for Windows is here.
$enableBashCompletions = ($Null -ne (Get-Command bash -ErrorAction Ignore)) -or ($Null -ne (Get-Command git -ErrorAction Ignore))
if ($enableBashCompletions) {
    Import-Module PSBashCompletions
    $completionPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($profile), "bash-completion")
    Register-BashArgumentCompleter kubectl "$completionPath/kubectl_completions.sh"
    Register-BashArgumentCompleter git "$completionPath/git_completions.sh"
    Register-BashArgumentCompleter helm "$completionPath/helm_completions.sh"
}
