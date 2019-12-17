<#
.SYNOPSIS
    Invokes the specified batch file and retains any environment variable changes it makes.
.DESCRIPTION
    Invoke the specified batch file (and parameters), but also propagate any
    environment variable changes back to the PowerShell environment that
    called it.
.PARAMETER Path
    Path to a .bat or .cmd file.
.PARAMETER Parameters
    Parameters to pass to the batch file.
.PARAMETER Silent
    Use this flag to skip writing out any batch file output.
.EXAMPLE
    C:\PS> Invoke-WindowsBatchFile "$env:ProgramFiles\Microsoft Visual Studio 9.0\VC\vcvarsall.bat"
    Invokes the vcvarsall.bat file.  All environment variable changes it makes will be
    propagated to the current PowerShell session.
.NOTES
    This is a copy/rename of PowerShell Community Extensions "Invoke-BatchFile." Copied
    to avoid needing the whole PSCX set of modules just for this one function; renamed
    to avoid conflict in the event PSCX does get imported. Updated to allow silent execution.
    Source: https://github.com/Pscx/Pscx/blob/eeceb96a9ad4111bbfb6c815fc26ae055e8c7ba7/Src/Pscx/Modules/Utility/Pscx.Utility.psm1#L747
    Original License: MIT
    Author: Lee Holmes
#>
function Invoke-WindowsBatchFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [string]
        $Parameters,

        [switch]
        $Silent)

    $tempFile = [IO.Path]::GetTempFileName()

    ## Store the output of cmd.exe.  We also ask cmd.exe to output
    ## the environment table after the batch file completes
    cmd.exe /c " `"$Path`" $Parameters && set " > $tempFile

    ## Go through the environment variables in the temp file.
    ## For each of them, set the variable in our local environment.
    $verboseOutput = "Output:"
    If($Silent) {
        $verboseOutput = "[Silenced] " + $verboseOutput
    }
    Get-Content $tempFile | Foreach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            Set-Content "env:\$($matches[1])" $matches[2]
            Write-Verbose "Environment variable: $($matches[1]) = $($matches[2])"
        }
        else {
            Write-Verbose "$verboseOutput $_"
            if (-not $Silent) {
                $_
            }
        }
    }

    Remove-Item $tempFile
}
