<#
.SYNOPSIS
    Gets the authors and last write times from all remote branches in a Git
    repository.
.DESCRIPTION
    Gets author and write time information for all branches. Uses a local clone
    of the repository as the basis for pulling branch information.

    Times in the report are converted to local time.
.PARAMETER Path
    The location of the Git repository clone to query.
.PARAMETER IncludeMain
    Include the main development branches (main, master, develop) in the report.
    By default only non-primary branches are included.
.EXAMPLE
    Get-GitBranchReport

    Branch          Date                        Relative     Author
    ------          ----                        --------     ------
    feature/T-10866 8/29/2022 8:50:38 AM -07:00 4 months ago jsmith

    By default the report does not include primary dev branches.
.EXAMPLE
    Get-GitBranchReport -IncludeMain

    Branch          Date                        Relative     Author
    ------          ----                        --------     ------
    feature/T-10866 8/29/2022 8:50:38 AM -07:00 4 months ago jsmith
    master          12/6/2022 9:46:13 AM -08:00 9 days ago   adoe

    If specified, the primary dev branches are included.
#>
function Get-GitBranchReport {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD,

        [Parameter(Mandatory = $False)]
        [switch]
        $IncludeMain
    )
    Begin {
        $MainBranches = @("/main", "/master", "/develop")
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error "Unable to locate git."
            Exit 1
        }

        If (-not (Test-Path $Path)) {
            Write-Error "Unable to find path $Path"
            Exit 1
        }
    }
    Process {
        Try {
            Push-Location $Path
            $branches = git branch -r --format "%(refname)" | Where-Object { -Not $_.EndsWith("/HEAD") }
            If (-Not $IncludeMain) {
            $branches = $branches | Where-Object {
                    $branch = $_
                    $allow = $True
                    $MainBranches | ForEach-Object {
                        If ($branch.EndsWith($_)) {
                            $allow = $False
                        }
                    }
                    $allow
                }
            }

            $report = @()
            $branches | ForEach-Object {
                $branch = $_
                $branchInfo = git show --format="{`"Date`":`"%ai`",`"Relative`":`"%ar`",`"Author`":`"%an`"}" $_ | Select-Object -First 1 | ConvertFrom-Json
                $reportObject = [PSCustomObject]@{
                    Branch = $branch.Replace("refs/remotes/origin/","")
                    Date = [System.DateTimeOffset]::Parse($branchInfo.Date).ToLocalTime()
                    Relative = $branchInfo.Relative
                    Author = $branchInfo.Author
                }
                $report += $reportObject
            }

            $report | Sort-Object { $_.Date }
        }
        Finally {
            Pop-Location
        }
    }
}
