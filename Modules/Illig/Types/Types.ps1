<#
Individual step in the report for an Azure DevOps pipeline run.
#>
class AzureDevOpsPipelineStep {
    [string] $Id
    [string] $ParentId
    [string] $Name
    [string] $State
    [string] $Result
    [Nullable[DateTime]] $StartTime
    [int] $Order
    [int] $Errors
    [int] $Warnings
    [AzureDevOpsPipelineStep[]] $Children
}

<#
Complete current status for an Azure DevOps pipeline run.
#>
class AzureDevOpsPipelineRun {
    [string] $Id
    [string] $Name
    [string] $State
    [string] $Result
    [DateTime] $ReportTime
    [AzureDevOpsPipelineStep[]] $Timeline
}
