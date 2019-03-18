#Script Browser Begin
#Version: 1.3.2
Add-Type -Path "$PSScriptRoot\ISE\Microsoft Script Browser\System.Windows.Interactivity.dll"
Add-Type -Path "$PSScriptRoot\ISE\Microsoft Script Browser\ScriptBrowser.dll"
Add-Type -Path "$PSScriptRoot\ISE\Microsoft Script Browser\BestPractices.dll"
$scriptBrowser = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Add('Script Browser', [ScriptExplorer.Views.MainView], $true)
$scriptAnalyzer = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Add('Script Analyzer', [BestPractices.Views.BestPracticesView], $true)
$psISE.CurrentPowerShellTab.VisibleVerticalAddOnTools.SelectedAddOnTool = $scriptBrowser
#Script Browser End

Import-Module PSReadline
Import-Module Microsoft.PowerShell.Archive
Import-Module Pscx -NoClobber
Import-Module VSSetup
Import-Module Illig

# Windows defaults to ASCII
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Invoke-VisualStudioDevPrompt

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
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