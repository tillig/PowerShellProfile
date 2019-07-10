<#
.Synopsis
   Sets the console window encoding to support Unicode or default.
.DESCRIPTION
   Updates the current console encoding. By default the console is
   ASCII-based due to the Windows default settings. For Unicode
   command support you need to change your console encoding.
.EXAMPLE
   Set-ConsoleEncoding -Default
.EXAMPLE
   Set-ConsoleEncoding -UTF8
#>
function Set-ConsoleEncoding {
    [CmdletBinding()]
    Param
    (
        [Parameter(ParameterSetName = "Unicode")]
        [Switch]
        $UTF8,

        [Parameter(ParameterSetName = "Default")]
        [Switch]
        $Default
    )
    Process {
        if ($Default) {
            [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(437)
        }
        else {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        }
    }
}
