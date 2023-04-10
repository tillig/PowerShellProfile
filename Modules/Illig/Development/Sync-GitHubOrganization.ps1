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
    }
    Process {
        # Not using Write-Progress because it makes it really hard to figure out where any failures happen.
        Try {
            Push-Location $Path
            $currentFolders = Get-ChildItem -Directory -Force | Select-Object -ExpandProperty "Name"

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
            $repos | Sort-Object -Property name | ForEach-Object {
                $repo = $_
                $repoName = $repo.name
                If ($currentFolders -contains $repoName) {
                    Write-Information -MessageData "Updating $repoName clone..." -InformationAction Continue
                    Try {
                        If ($PSCmdlet.ShouldProcess($repoName, "Update existing clone")) {
                            Update-GitRepository -Path $repoName
                        }
                    }
                    Catch {
                        Write-Error $_
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
                        If ($PSCmdlet.ShouldProcess($repoName, "Create new clone")) {
                            git clone --recurse-submodules -q $url
                        }
                    }
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
