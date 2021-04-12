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
#>
function Remove-GitLocalOnly {
    [CmdletBinding(SupportsShouldProcess = $True,
        ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $False,
            Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD
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
        Try {
            Push-Location $Path
            $ToParse = "["
            $ToParse += (&git branch --format "{\`"Name\`":\`"%(refname:short)\`",\`"Remote\`":\`"%(upstream)\`",\`"Track\`":\`"%(upstream:track,nobracket)\`"}") -Join ","
            $ToParse += "]"
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to retrieve branches."
                exit 1
            }

            $LocalOnlyBranches = $ToParse | ConvertFrom-Json | Where-Object { ($_.Remote.Length -eq 0) -or ($_.Track -eq "gone") } | Select-Object -ExpandProperty Name
            $LocalOnlyBranches | ForEach-Object {
                $LocalBranch = $_
                if ($pscmdlet.ShouldProcess("$LocalBranch", "Remove branch with no upstream")) {
                    &git branch -D $LocalBranch
                    If ($LASTEXITCODE -ne 0) {
                        throw "Unable to delete branch."
                        exit 1
                    }
                }
            }
        }
        Finally {
            Pop-Location
        }
    }
}
