<#
.SYNOPSIS
    Gets all the GitHub repositories from a given organization and clones them
    to a specified location.
.DESCRIPTION
    Uses the GitHub API to retrieve all the repositories for a given
    organization. Based on the name of the repo, if there is already a folder
    for that repo, a `git pull -p` is executed there; if there is not already a
    folder for that repo, a `git clone` will happen for the repo.

    If there are folders that don't match a repo, a warning will be written
    about those to indicate it may be a stale or renamed repo.
.PARAMETER Path
    The location to serve as the root for the set of clones.
.PARAMETER Organization
    The GitHub organization name.
.PARAMETER Exclude
    A list of one or more regular expression strings. If a repository name
    matches any of these expressions, it won't be synchronized unless there's
    already a folder/clone matching that name (e.g., you manually cloned it).
.EXAMPLE
   Sync-GitHubOrganization -Organization "Autofac"
#>
function Sync-GitHubOrganization {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function', Target='excluded')]
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $False)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD,

        [Parameter(Mandatory = $True, Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Organization,

        [Parameter(Mandatory = $False)]
        [string[]]
        $Exclude = @()
    )
    Begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error "Unable to locate git."
            Exit 1
        }

        If (-not (Test-Path $Path)) {
            Write-Error "Unable to find path $Path"
            Exit 1
        }

        # Bug in ForEach/Parallel requires this to be set in addition to passing the -InformationAction.
        # https://stackoverflow.com/questions/64436812/write-information-does-not-appear-to-work-in-powershell-foreach-object-parallel
        $InformationPreference = 'Continue'
    }
    Process {
        # Not using Write-Progress because it makes it really hard to figure out where any failures happen.
        Try {
            Push-Location $Path
            Write-Verbose "Querying $Organization..."
            $repos = @()
            $repoPage = $Null
            $pageNumber = 1
            do {
                $repoPage = Invoke-RestMethod "https://api.github.com/orgs/$Organization/repos?page=$pageNumber&per_page=100"
                $pageNumber++
                $repos += $repoPage
            } while (
                $repoPage.Count -gt 0
            )

            Write-Verbose "Found $($repos.Count) repositories."

            $currentFolders = Get-ChildItem -Directory -Force | Select-Object -ExpandProperty "Name"

            # Not using Update-GitRepsository because we need to separate the git pull from the removal of local branches.
            Write-Verbose "Updating repository clones."
            $repos | ForEach-Object -ThrottleLimit 10 -Parallel {
                $repo = $_
                $repoName = $repo.name
                $currentFolders = $using:currentFolders
                If ($currentFolders -contains $repoName) {
                    Write-Information -MessageData "Updating $repoName clone..." -InformationAction Continue
                    Try {
                        Push-Location $repoName
                        $path = (Get-Location).Path
                        &git pull -p --recurse-submodules=yes --all -q
                        If ($LASTEXITCODE -ne 0) {
                            throw "Unable to update $path from Git."
                        }
                    }
                    Catch {
                        Write-Error "Error processing $repoName`: $_"
                    }
                    Finally {
                        Pop-Location
                    }
                }
                Else {
                    $excluded = $False
                    If ($null -ne $Exclude) {
                        $Exclude | ForEach-Object {
                            If ($repoName -match $_) {
                                Write-Information -MessageData "Excluding repo $repoName based on exclusion '$_'." -InformationAction Continue
                                $excluded = $True
                            }
                        }
                    }
                    If (-not $excluded) {
                        Write-Information -MessageData "Cloning $repoName..." -InformationAction Continue
                        $url = $repo.clone_url
                        git clone --recurse-submodules -q $url
                    }
                }
            }

            # Can't run this in parallel because you can't do PSCmdlet.ShouldProcess in a parallel loop.
            Write-Verbose "Removing branches that are only local."
            $repos | ForEach-Object {
                $repo = $_
                $repoName = $repo.name
                If ($currentFolders -contains $repoName) {
                    Remove-GitLocalOnly -Path $repoName
                }
            }

            Write-Verbose "Checking for extra folders..."
            $currentFolders | ForEach-Object {
                $folderName = $_
                $found = $repos | Where-Object { $_.name -eq $folderName }
                If (-not $found) {
                    Write-Warning "$folderName is not a repo."
                }
            }
        }
        Finally {
            Pop-Location
        }
    }
}
