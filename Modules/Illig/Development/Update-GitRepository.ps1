<#
.SYNOPSIS
    Updates a Git repo and prunes branches.
.DESCRIPTION
    Executes `git pull -p` on a Git repo location to pull and prune branches.
    Subsequently runs the Remove-GitLocalOnly command to remove local tracking
    branches that don't exist on the remote anymore.
.PARAMETER Path
    The location with branches to remove.
.EXAMPLE
   Update-GitRepository
.EXAMPLE
   Get-ChildItem -Directory | Update-GitRepository
#>
function Update-GitRepository {
    [CmdletBinding(SupportsShouldProcess = $False)]
    param(
        [Parameter(Mandatory = $False,
            Position = 0,
            ValueFromPipeline = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD
    )
    begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error 'Unable to locate git.'
            exit 1
        }

        Write-Progress -Activity 'Updating Git repositories' -Status 'Starting...'
    }
    process {
        if (-not (Test-Path $Path)) {
            throw "Unable to find path $Path"
        }
        try {
            Write-Progress -Activity 'Updating Git repositories' -Status $Path
            Push-Location $Path
            &git pull -p --recurse-submodules=yes --all -q
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to update $Path from Git."
            }

            Remove-GitLocalOnly
        }
        finally {
            Pop-Location
        }
    }
    end {
        Write-Progress -Activity 'Updating Git repositories' -Completed
    }
}
