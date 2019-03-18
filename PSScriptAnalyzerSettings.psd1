# Invoke-ScriptAnalyzer -Path MyScript.ps1 -Setting ~\Documents\WindowsPowerShell\PSScriptAnalyzerSettings.psd1
@{
    "IncludeDefaultRules" = $true
    "CustomRulePath" = @("~\Documents\WindowsPowerShell\Modules\InjectionHunter")
    "RecurseCustomRulePath" = $true
}