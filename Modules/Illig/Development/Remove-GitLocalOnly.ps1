<#
.SYNOPSIS
    Removes Git branches that are only local and have no upstream.
.DESCRIPTION
    Retrieves the list of Git branches for a given location and looks for the
    ones that don't have a corresponding upstream. Removes the branches with no
    upstream.
.PARAMETER Path
    The location with branches to remove.
.EXAMPLE
   Remove-GitLocalOnly
.EXAMPLE
   Get-ChildItem -Directory | Remove-GitLocalOnly
#>
function Remove-GitLocalOnly {
    [CmdletBinding(SupportsShouldProcess = $True,
        ConfirmImpact = 'High')]
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
    }
    process {
        if (-not (Test-Path $Path)) {
            throw "Unable to find path $Path"
        }
        try {
            Push-Location $Path
            $ToParse = '['
            $ToParse += (&git branch --format "{`"Name`":`"%(refname:short)`",`"Remote`":`"%(upstream)`",`"Track`":`"%(upstream:track,nobracket)`"}") -join ','
            $ToParse += ']'
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to retrieve branches.'
                exit 1
            }

            $LocalOnlyBranches = $ToParse | ConvertFrom-Json | Where-Object { ($_.Remote.Length -eq 0) -or ($_.Track -eq 'gone') } | Select-Object -ExpandProperty Name
            $LocalOnlyBranches | ForEach-Object {
                $LocalBranch = $_
                if ($pscmdlet.ShouldProcess("$LocalBranch ($Path)", 'Remove branch with no upstream')) {
                    &git branch -D $LocalBranch
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Unable to delete branch.'
                        exit 1
                    }
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}
