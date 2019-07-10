<#
.Synopsis
   Resets a git source tree and cleans the NuGet cache for a full clean build.
.DESCRIPTION
   Does both a git and NuGet clean to ensure a fresh build on a source tree.
.EXAMPLE
   Reset-Source
#>
function Reset-Source {
    [CmdletBinding()]
    Param
    (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [System.IO.DirectoryInfo[]] $Source
    )
    Begin {
        & nuget locals -clear all
    }
    Process {
        if ($NULL -eq $Source -or $Source.Length -eq 0) {
            & git clean -dfx
        }
        else {
            foreach ($path in $Source) {
                Push-Location $path
                & git clean -dfx
                Pop-Location
            }
        }
    }
}
