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
.EXAMPLE
   Sync-AzureDevOpsProject -Organization https://dev.azure.com/MyOrg -Project "My Project"
#>
function Sync-AzureDevOpsProject {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
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
        $Project
    )
    Begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error "Unable to locate git."
            Exit 1
        }

        $az = Get-Command az -ErrorAction Ignore
        if ($Null -eq $az) {
            Write-Error "Unable to locate the az CLI."
            Exit 1
        }

        If (-not (Test-Path $Path)) {
            Write-Error "Unable to find path $Path"
            Exit 1
        }

        Write-Progress -Activity "Synchronizing Azure DevOps project" -Status "Starting..."
    }
    Process {

        Try {
            Write-Progress -Activity "Synchronizing Azure DevOps project" -Status "Preparing $Path..."
            Push-Location $Path
            $currentFolders = Get-ChildItem -Directory | Select-Object -ExpandProperty "Name"

            Write-Progress -Activity "Synchronizing Azure DevOps project" -Status "Querying $Organization/$Project..."
            $repos = az repos list --org $Organization -p $Project | ConvertFrom-Json
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to use az CLI to query $Organization/$Project. Check for typos, Azure CLI context, authentication issues."
            }

            $repos | ForEach-Object {
                $repo = $_
                $repoName = $repo.name
                If ($currentFolders -contains $repoName) {
                    Write-Progress -Activity "Synchronizing Azure DevOps project" -Status "Updating $repoName clone..."
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
                    Write-Progress -Activity "Synchronizing Azure DevOps project" -Status "Cloning $repoName..."
                    $url = $repo.remoteUrl
                    If ($PSCmdlet.ShouldProcess($repoName, "Create new clone")) {
                        git clone --recurse-submodules -q $url
                    }
                }
            }

            Write-Progress -Activity "Synchronizing Azure DevOps project" -Status "Checking for extra folders..."
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
    End {
        Write-Progress -Activity "Synchronizing Azure DevOps project" -Completed
    }
}
