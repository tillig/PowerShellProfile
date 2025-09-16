<#
.SYNOPSIS
    Gets all the Azure DevOps repositories from a given project and clones
    them to a specified location.
.DESCRIPTION
    Executes the `az` CLI to get the list of all repositories from an Azure
    DevOps project. Based on the name of the repo, if there is already a folder
    for that repo, a `git pull -p` is executed there; if there is not already a
    folder for that repo, a `git clone` will happen for the repo.

    If there are folders that don't match a repo, a warning will be written
    about those to indicate it may be a stale or renamed repo.
.PARAMETER Path
    The location to serve as the root for the set of clones.
.PARAMETER Organization
    The Azure DevOps organization URL (https://dev.azure.com/MyOrg/)
.PARAMETER Project
    The project in the Azure DevOps organization to clone.
.PARAMETER Exclude
    A list of one or more regular expression strings. If a repository name
    matches any of these expressions, it won't be synchronized unless there's
    already a folder/clone matching that name (e.g., you manually cloned it).
.EXAMPLE
   Sync-AzureDevOpsProject -Organization https://dev.azure.com/MyOrg -Project "My Project"
#>
function Sync-AzureDevOpsProject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
    [CmdletBinding(SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $False)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Organization,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Project,

        [Parameter(Mandatory = $False)]
        [string[]]
        $Exclude
    )
    begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error 'Unable to locate git.'
            exit 1
        }

        $az = Get-Command az -ErrorAction Ignore
        if ($Null -eq $az) {
            Write-Error 'Unable to locate the az CLI.'
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
            if ($Exclude) {
                Write-Verbose 'Excluding repos matching:'
                $Exclude | ForEach-Object { Write-Verbose "- $_" }
            }

            Write-Verbose "Querying $Organization/$Project..."
            $repos = az repos list --org $Organization -p $Project | ConvertFrom-Json -Depth 100 -NoEnumerate
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to use az CLI to query $Organization/$Project. Check for typos, Azure CLI context, authentication issues."
            }

            Write-Verbose "Found $($repos.Count) repositories."

            $currentFolders = Get-ChildItem -Directory -Force | Select-Object -ExpandProperty 'Name'

            # Not using Update-GitRepository because we need to separate the git pull from the removal of local branches.
            Write-Verbose 'Updating repository clones.'
            $repos | ForEach-Object -ThrottleLimit 10 -Parallel {
                $repo = $_
                $repoName = $repo.name
                $currentFolders = $using:currentFolders
                $Exclude = $using:Exclude
                $VPref = $using:VerbosePreference
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
                    $excluded = $False
                    if ($Exclude) {
                        Write-Verbose "Checking exclusions for $repoName" -Verbose:$VPref
                        $Exclude | ForEach-Object {
                            if ($repoName -match $_) {
                                Write-Information -MessageData "Excluding repo $repoName based on exclusion '$_'." -InformationAction Continue
                                $excluded = $True
                            }
                            else {
                                Write-Verbose "$repoName does not match exclusion '$_'." -Verbose:$VPref
                            }
                        }
                    }
                    if (-not $excluded) {
                        Write-Information -MessageData "Cloning $repoName..." -InformationAction Continue
                        $url = $repo.remoteUrl
                        git clone --recurse-submodules -q $url
                    }
                }
            }

            # Can't run this in parallel because you can't do PSCmdlet.ShouldProcess in a parallel loop.
            Write-Verbose 'Removing branches that are only local.'
            $repos | ForEach-Object {
                $repo = $_
                $repoName = $repo.name
                if ($currentFolders -contains $repoName) {
                    try {
                        Remove-GitLocalOnly -Path $repoName
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
