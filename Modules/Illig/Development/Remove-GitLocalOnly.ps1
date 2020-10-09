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

    Process {
        If (-not (Test-Path $Path)) {
            throw "Unable to find path $Path"
        }
        Try {
            Push-Location $Path
            $ToParse = "["
            $ToParse += (&git branch --format "{\`"Name\`":\`"%(refname:short)\`",\`"Remote\`":\`"%(upstream)\`",\`"Track\`":\`"%(upstream:track,nobracket)\`"}") -Join ","
            $ToParse += "]"
            $LocalOnlyBranches = $ToParse | ConvertFrom-Json | Where-Object { ($_.Remote.Length -eq 0) -or ($_.Track -eq "gone") } | Select-Object -ExpandProperty Name
            $LocalOnlyBranches | ForEach-Object {
                $LocalBranch = $_
                if ($pscmdlet.ShouldProcess("$LocalBranch", "Remove branch with no upstream")) {
                    &git branch -D $LocalBranch
                }
            }
        }
        Finally {
            Pop-Location
        }
    }
}
