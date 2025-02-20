<#
.SYNOPSIS
    Gets the details of a build pipeline run from Azure DevOps.
.DESCRIPTION
    Executes the `az` CLI to get status of a given build along with the
    timeline. Converts the timeline to a hierarchy for later reporting.
.PARAMETER Organization
    The Azure DevOps organization URL (https://dev.azure.com/MyOrg/)
.PARAMETER Project
    The project in the Azure DevOps organization to with the build pipeline.
.PARAMETER BuildId
    The ID of the build pipeline run for which details should be retrieved.
.EXAMPLE
   Get-AzureDevOpsBuild -Organization https://dev.azure.com/MyOrg -Project "My Project" -BuildId 123456
#>
function Get-AzureDevOpsBuild {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Organization,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Project,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $BuildId
    )
    Begin {
        $az = Get-Command az -ErrorAction Ignore
        if ($Null -eq $az) {
            Write-Error "Unable to locate the az CLI."
            Exit 1
        }
    }
    Process {
        $pipeline = az pipelines build show --org $Organization --project $Project --id $buildId | ConvertFrom-Json -Depth 10
        If ($LASTEXITCODE -ne 0) {
            throw "Unable to use az CLI to query $Organization/$Project for pipeline $BuildId. Check for typos, Azure CLI context, authentication issues."
        }

        $report = [AzureDevOpsPipelineRun]@{
            Id = $pipeline.id
            Name = $pipeline.definition.name
            State = $pipeline.status
            Result = $pipeline.result
            Timeline = @()
        }

        $timeline = az devops invoke --org $Organization --area build --resource timeline --route-parameters "project=$Project" "buildId=$buildId" --api-version 7.1 | ConvertFrom-Json -Depth 100

        # Convert to objects in the tree.
        $stepTable = @{}
        $timeline.records | ForEach-Object {
            $id = $_.id
            If (-not $id) {
                $id = '<root>'
            }

            If ($_.startTime) {
                $startTime = $_.startTime.ToLocalTime()
            }

            $step = [AzureDevOpsPipelineStep]@{
                Id        = $id
                ParentId  = $_.parentId
                Name      = $_.name
                State     = $_.state
                Result    = $_.result
                StartTime = $startTime
                Order     = $_.order
                Errors    = $_.errorCount
                Warnings  = $_.warningCount
                Children  = @()
            }
            $stepTable[$step.Id] = $step
        }

        # Link children to parents.
        $stepTable.Values | ForEach-Object {
            If ($_.ParentId) {
                $currentId = $_.Id
                $hasChild = $StepTable[$_.ParentId].Children | Where-Object { $currentId -eq $_.Id }
                If (-not $hasChild) {
                    $StepTable[$_.ParentId].Children += $_
                }
            }
        }

        # Sort children by order.
        $stepTable.Values | ForEach-Object {
            $_.Children = $_.Children | Sort-Object Order
        }

        # Set the timeline to start with the root set of steps.
        $report.Timeline = $stepTable.Values | Where-Object { -not $_.ParentId } | Sort-Object Order
        $report
    }
}
