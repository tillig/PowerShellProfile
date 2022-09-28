. $PSScriptRoot/ProfileCommon.ps1

#Script Browser Begin
#Version: 1.3.2
Add-Type -Path "$PSScriptRoot\ISE\Microsoft Script Browser\System.Windows.Interactivity.dll"
Add-Type -Path "$PSScriptRoot\ISE\Microsoft Script Browser\ScriptBrowser.dll"
Add-Type -Path "$PSScriptRoot\ISE\Microsoft Script Browser\BestPractices.dll"
$scriptBrowser = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Add('Script Browser', [ScriptExplorer.Views.MainView], $true)
$scriptAnalyzer = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Add('Script Analyzer', [BestPractices.Views.BestPracticesView], $true)
$psISE.CurrentPowerShellTab.VisibleVerticalAddOnTools.SelectedAddOnTool = $scriptBrowser
#Script Browser End
