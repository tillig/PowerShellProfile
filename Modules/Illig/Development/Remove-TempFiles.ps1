<#
.Synopsis
   Clears out temporary folders.
.DESCRIPTION
   Removes temporary files from the current user and temporary ASP.NET files.
.EXAMPLE
   Remove-TempFiles
#>
function Remove-TempFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param
    (
    )

    Begin {
        if (-not ($isDesktop -or $IsWindows)) {
            throw "This command is only supported for Windows."
        }

        $tempFolders = @(
            $env:TEMP,
            "$($env:LOCALAPPDATA)\Temp",
            "$($env:windir)\Temp",
            "$($env:windir)\Microsoft.NET\Framework\v2.0.50727\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework64\v2.0.50727\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files")
    }
    Process {
        foreach ($tempFolder in $tempFolders) {
            if ((Test-Path $tempFolder) -and ($pscmdlet.ShouldProcess("$tempFolder", "Remove items from temporary folder"))) {
                Get-ChildItem $tempFolder | Remove-Item -Force -Recurse
            }
        }
    }
}
