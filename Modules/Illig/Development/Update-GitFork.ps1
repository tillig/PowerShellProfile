<#
.SYNOPSIS
    Updates a local copy of a Git fork with the upstream contents.
.DESCRIPTION
    Assuming the clone in a given location is a fork with a configured upstream
    (e.g., there's 'origin' for the fork, and there's 'upstream' for the
    original repo that got forked), synchronizes the 'master,' 'main,' and
    'develop' branches with the upstream.
.PARAMETER Path
    The location with fork to sync.
.PARAMETER Upstream
    The name of the Git remote pointing to the upstream/original repository.
    Defaults to 'upstream.'
.PARAMETER BranchesToUpdate
    The list of branches to update. Defaults to 'master,' 'main,' and 'develop.'
.EXAMPLE
   Update-GitFork
#>
function Update-GitFork {
    [CmdletBinding(SupportsShouldProcess = $True,
        ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $False,
            Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD,

        [Parameter(Mandatory = $False)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Upstream = "upstream",

        [Parameter(Mandatory = $False)]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $BranchesToUpdate = @("master", "main", "develop")
    )
    Begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error "Unable to locate git."
            Exit 1
        }
    }
    Process {
        If (-not (Test-Path $Path)) {
            throw "Unable to find path $Path"
        }

        Push-Location $Path

        Try {
            # Keep the original branch so we can switch back to it later.
            $originalBranch = &git branch --show-current
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to retrieve current branch."
                exit 1
            }

            Write-Verbose "Current branch is $originalBranch."

            # Validate the remote is configured.
            $remotes = &git remote
            If (-not ($remotes -is [array])) {
                throw "There is only one remote configured for this clone. Forks generally have an origin and an upstream."
            }

            If (-not ($remotes -contains $Upstream)) {
                throw "$Upstream is not one of the configured remotes."
            }

            Write-Verbose "Fetching latest from $Upstream."
            &git fetch $Upstream

            # Get the branches we have locally
            Write-Verbose "Getting the list of local branches."
            $toParse = "["
            $toParse += (&git branch --format "{`"Name`":`"%(refname:short)`",`"Remote`":`"%(upstream)`",`"Track`":`"%(upstream:track,nobracket)`"}") -Join ","
            $toParse += "]"
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to retrieve branches."
                exit 1
            }

            $localBranches = $toParse | ConvertFrom-Json -NoEnumerate
            $filteredBranchesToUpdate = $localBranches | Where-Object { $BranchesToUpdate -contains $_.Name } | Select-Object -ExpandProperty Name
            $filteredBranchesToUpdate | ForEach-Object {
                $branchToUpdate = $_
                If ($pscmdlet.ShouldProcess("$branchToUpdate", "Update branch with upstream")) {
                    Write-Verbose "Switching to $branchToUpdate."
                    &git checkout $branchToUpdate
                    If ($LASTEXITCODE -ne 0) {
                        throw "Unable to switch branches."
                        exit 1
                    }

                    Write-Verbose "Updating from $Upstream/$branchToUpdate."
                    &git merge "$Upstream/$branchToUpdate"
                    If ($LASTEXITCODE -ne 0) {
                        throw "Unable to merge $Upstream/$branchToUpdate - check for conflicts and errors."
                        exit 1
                    }
                }
                If ($pscmdlet.ShouldProcess("$branchToUpdate", "Push merged changes back to fork")) {
                    Write-Verbose "Pushing $branchToUpdate."
                    &git push
                    If ($LASTEXITCODE -ne 0) {
                        throw "Unable to push changes."
                        exit 1
                    }
                }
            }
        }
        Finally {
            &git checkout $originalBranch
            Pop-Location
        }
    }
}
