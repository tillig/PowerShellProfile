<#
.Synopsis
   Parses a .env file and loads it into the current environment.
.PARAMETER File
   The file that should be parsed into the environment.
.DESCRIPTION
   Reads a standard .env file and brings the values into the current environment.

   - Each line in an env file should be in VAR=VAL format.
   - Lines beginning with # are processed as comments and ignored.
   - Blank lines are ignored.
   - There is no special handling of quotation marks. This means that they are part of the VAL.
.EXAMPLE
   Set-DotEnv ./terraform.env
#>
function Set-DotEnv {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param
    (
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $File
    )

    Process {
        If ( -not (Test-Path $File)) {
            throw "Unable to find file $File"
        }

        Get-Content $File |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not $_.StartsWith('#') -and -not [string]::IsNullOrEmpty($_) } |
        ForEach-Object {
            $kvp = $_ -split "=", 2;
            If ($PSCmdlet.ShouldProcess("$($kvp[0])", "set value $($kvp[1])")) {
                [Environment]::SetEnvironmentVariable($kvp[0], $kvp[1]) | Out-Null
            }
        }
    }
}
