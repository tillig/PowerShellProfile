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
.PARAMETER ReportFormat
    If specified, the output will be formatted in a pretty-printed report.
.PARAMETER Watch
    If specified, the build status will be refreshed periodically until the
    build is completed.
.PARAMETER RefreshIntervalSeconds
    The number of seconds to wait between refreshing the build status in "watch"
    mode. Default is 10 seconds.
.EXAMPLE
   Get-AzureDevOpsBuild -Organization https://dev.azure.com/MyOrg -Project "My Project" -BuildId 123456
#>
function Get-AzureDevOpsBuild {
    [CmdletBinding()]
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
        $BuildId,

        [Parameter(Mandatory = $False)]
        [switch]
        $ReportFormat,

        [Parameter(Mandatory = $False, ParameterSetName = 'Watch')]
        [switch]
        $Watch,

        [Parameter(Mandatory = $False, ParameterSetName = 'Watch')]
        [int]
        $RefreshIntervalSeconds = 10

    )
    Begin {
        $az = Get-Command az -ErrorAction Ignore
        if ($Null -eq $az) {
            Write-Error 'Unable to locate the az CLI.'
            Exit 1
        }

        Function Get-PipelineRun {
            Write-Verbose "Querying Azure DevOps for pipeline run $BuildId in $Organization/$Project."
            $pipeline = az pipelines build show --org $Organization --project $Project --id $buildId | ConvertFrom-Json -Depth 10
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to use az CLI to query $Organization/$Project for pipeline $BuildId. Check for typos, Azure CLI context, authentication issues."
            }

            $report = [AzureDevOpsPipelineRun]@{
                Id         = $pipeline.id
                Name       = $pipeline.definition.name
                State      = $pipeline.status
                Result     = $pipeline.result
                ReportTime = Get-Date
                Timeline   = @()
            }

            Write-Verbose "Querying Azure DevOps for $BuildId timeline in $Organization/$Project."
            $timeline = az devops invoke --org $Organization --area build --resource timeline --route-parameters "project=$Project" "buildId=$buildId" --api-version 7.1 | ConvertFrom-Json -Depth 100

            # Convert to objects in the tree.
            Write-Verbose 'Converting pipeline timeline to objects.'
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

        Function Out-Report {
            Param(
                [AzureDevOpsPipelineRun] $PipelineRun
            )
            Write-Output "$($PipelineRun.Name) - $($PipelineRun.Id) [$($PipelineRun.ReportTime.ToLocalTime().ToString('HH:mm:ss'))]"
            Out-ReportSteps -Steps $PipelineRun.Timeline
            If ($PipelineRun.State -eq 'completed') {
                Write-Output "Status: $($PipelineRun.State) / $($PipelineRun.Result)"
            }
            Else {
                Write-Output "Status: $($PipelineRun.State)"
            }

            Write-Output "$Organization/$([System.Net.WebUtility]::UrlEncode($Project).Replace('+','%20'))/_build/results?buildId=$($PipelineRun.Id)&view=results"
        }

        Function Out-ReportSteps {
            Param(
                [AzureDevOpsPipelineStep[]] $Steps,
                [int] $Indent = 0
            )

            $Steps | Sort-Object Order | ForEach-Object {
                $step = $_
                $result = "($($step.Result))"
                $errors = ''
                $warnings = ''

                If ($step.State -eq 'inProgress') {
                    $result = '➡️'
                }
                ElseIf ($step.State -eq 'pending') {
                    $result = '⏳'
                }
                ElseIf ($step.Result -eq 'succeeded') {
                    $result = '✅'
                }
                ElseIf ($step.Result -eq 'failed') {
                    $result = '❌'
                }
                ElseIf ($step.Result -eq 'failed') {
                    $result = '⊘'
                }

                If ($step.Errors -gt 0) {
                    $errors = " ⛔️ $($step.Errors)"
                }

                If ($step.Warnings -gt 0) {
                    $warnings = " ⚠ $($step.Warnings)"
                }

                $startTime = 'n/a'
                If ($step.StartTime) {
                    $startTime = $step.StartTime.ToLocalTime().ToString('HH:mm:ss')
                }

                If ($step.Result -ne 'skipped') {
                    $indentString = New-Object -TypeName 'System.String' -ArgumentList ' ', $Indent
                    Write-Output "$indentString$result $($step.Name) [$startTime]$errors$warnings"
                }

                Out-ReportSteps -Steps $step.Children -Indent ($Indent + 2)
            }
        }

    }
    Process {
        Do {
            $pipelineRun = Get-PipelineRun
            If ($ReportFormat) {
                Out-Report -PipelineRun $pipelineRun
            }
            Else {
                $pipelineRun
            }

            If ($Watch -and $pipelineRun.State -ne 'completed') {
                If ($ReportFormat) {
                    Write-Host "Refreshing in $RefreshIntervalSeconds seconds..."
                    Write-Host '========================================'
                }

                Start-Sleep -Seconds $RefreshIntervalSeconds
            }
        } While ($Watch -and $pipelineRun.State -ne 'completed')
    }
}
