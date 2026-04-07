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
.PARAMETER Include
    A list of one or more regular expression strings. If provided, only
    repositories whose names match at least one of these expressions will be
    synchronized. If omitted, all repositories are initially included. Include
    is evaluated before Exclude.
.PARAMETER Exclude
    A list of one or more regular expression strings. If a repository name
    matches any of these expressions, it won't be synchronized. Exclude is
    evaluated after Include and takes precedence on overlap.
.PARAMETER ApiToken
    A personal access token (PAT) for GitHub API authentication. Required for
    GitHub Enterprise endpoints or private organizations. This token is used
    only for API calls, not for git clone/pull operations.
.PARAMETER ApiEndpoint
    The GitHub API endpoint to use. Defaults to 'https://api.github.com'.
.EXAMPLE
   Sync-GitHubOrganization -Organization "Autofac"
.EXAMPLE
   Sync-GitHubOrganization `
     -Organization "Autofac" `
     -Include "^Autofac\." `
     -Exclude "\.Documentation$"
.EXAMPLE
   Sync-GitHubOrganization `
     -Organization "MyOrg" `
     -ApiEndpoint "https://github.example.com/api/v3" `
     -ApiToken $env:CUSTOM_GITHUB_TOKEN
#>
function Sync-GitHubOrganization {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
    [CmdletBinding(SupportsShouldProcess = $True)]
    param(
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
        $Include,

        [Parameter(Mandatory = $False)]
        [string[]]
        $Exclude,

        [Parameter(Mandatory = $False)]
        [string]
        $ApiToken,

        [Parameter(Mandatory = $False)]
        [string]
        [ValidateNotNullOrEmpty()]
        $ApiEndpoint = 'https://api.github.com'
    )
    begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error 'Unable to locate git.'
            exit 1
        }

        if (-not (Test-Path $Path)) {
            Write-Error "Unable to find path $Path"
            exit 1
        }

        # Bug in ForEach/Parallel requires this to be set in addition to passing the -InformationAction.
        # https://stackoverflow.com/questions/64436812/write-information-does-not-appear-to-work-in-powershell-foreach-object-parallel
        $InformationPreference = 'Continue'
    }
    process {
        # Not using Write-Progress because it makes it really hard to figure out where any failures happen.
        try {
            Push-Location $Path
            $headers = @{}
            if ($ApiToken) {
                $headers['Authorization'] = "Bearer $ApiToken"
            }

            Write-Verbose "Querying $Organization..."
            $repos = @()
            $repoPage = $Null
            $pageNumber = 1
            do {
                $repoPage = Invoke-RestMethod "$ApiEndpoint/orgs/$Organization/repos?page=$pageNumber&per_page=100&type=all" -Headers $headers
                Write-Verbose "Page $pageNumber`: Found $($repoPage.Count) repos."
                $pageNumber++
                $repos += $repoPage
            } while (
                $repoPage.Count -gt 0
            )

            $repos = $repos | Sort-Object -Property name
            Write-Verbose "Found $($repos.Count) repositories."

            $currentFolders = Get-ChildItem -Directory -Force | Select-Object -ExpandProperty 'Name'

            # Filter repos: Include first (if provided), then Exclude. Exclude wins on overlap.
            $filteredRepos = @()
            foreach ($repo in $repos) {
                $repoName = $repo.name
                $included = $True
                if ($Include) {
                    $included = $False
                    foreach ($pattern in $Include) {
                        if ($repoName -match $pattern) {
                            $included = $True
                            break
                        }
                    }
                    if (-not $included) {
                        Write-Verbose "Repo $repoName does not match any Include pattern."
                    }
                }
                if ($included -and $Exclude) {
                    foreach ($pattern in $Exclude) {
                        if ($repoName -match $pattern) {
                            Write-Verbose "Excluding repo $repoName based on exclusion '$pattern'."
                            $included = $False
                            break
                        }
                    }
                }
                if ($included) {
                    $filteredRepos += $repo
                }
            }

            # Not using Update-GitRepository because we need to separate the git
            # pull from the removal of local branches.
            #
            # ShouldProcess can't be called inside ForEach-Object -Parallel, so
            # determine which repos to update/clone sequentially, then run the
            # git operations in parallel.
            Write-Verbose "Synchronizing $($filteredRepos.Count) of $($repos.Count) repositories."
            $reposToUpdate = @()
            $reposToClone = @()
            foreach ($repo in $filteredRepos) {
                $repoName = $repo.name
                if ($currentFolders -contains $repoName) {
                    if ($PSCmdlet.ShouldProcess($repoName, 'git pull')) {
                        $reposToUpdate += $repo
                    }
                }
                else {
                    if ($PSCmdlet.ShouldProcess($repoName, 'git clone')) {
                        $reposToClone += $repo
                    }
                }
            }

            ($reposToUpdate + $reposToClone) | ForEach-Object -ThrottleLimit 10 -Parallel {
                $repo = $_
                $repoName = $repo.name
                $currentFolders = $using:currentFolders
                if ($currentFolders -contains $repoName) {
                    Write-Information -MessageData "Updating $repoName clone..." -InformationAction Continue
                    try {
                        Push-Location $repoName
                        $path = (Get-Location).Path
                        &git pull -p --recurse-submodules=yes --all -q
                        if ($LASTEXITCODE -ne 0) {
                            throw "Unable to update $path from Git."
                        }
                    }
                    catch {
                        Write-Error "Error processing $repoName`: $_"
                    }
                    finally {
                        Pop-Location
                    }
                }
                else {
                    Write-Information -MessageData "Cloning $repoName..." -InformationAction Continue
                    $url = $repo.clone_url
                    git clone --recurse-submodules -q $url
                }
            }

            # Can't run this in parallel because you can't do PSCmdlet.ShouldProcess in a parallel loop.
            Write-Verbose 'Removing branches that are only local.'
            $filteredRepos | ForEach-Object {
                $repo = $_
                $repoName = $repo.name
                if ($currentFolders -contains $repoName) {
                    try {
                        Remove-GitLocalOnly -Path $repoName -WhatIf:$WhatIfPreference
                    }
                    catch {
                        Write-Error "Error processing $repoName`: $_"
                    }
                }
            }

            Write-Verbose 'Checking for extra folders...'
            $currentFolders | ForEach-Object {
                $folderName = $_
                $found = $repos | Where-Object { $_.name -eq $folderName }
                if (-not $found) {
                    Write-Warning "$folderName is not a repo."
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}
