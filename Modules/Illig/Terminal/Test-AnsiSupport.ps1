<#
.Synopsis
   Creates a new machine key element for use in web.config files.
.PARAMETER Decryption
   Indicates the decryption algorithm that should be used for the machine key: AES, DES, 3DES.
.PARAMETER Validation
   Indicates the request validation algorithm that should be used: MD5, SHA1, HMACSHA256, HMACSHA384, HMACSHA512.
.DESCRIPTION
   Generates new machine key data in XML element format that can be used in a web.config file in an ASP.NET web site.
.EXAMPLE
   New-MachineKey
.EXAMPLE
   New-MachineKey -Validation SHA1
#>

function Test-AnsiSupport {
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
    )

    Process {
        $isDesktop = ($PSVersionTable.PSEdition -eq "Desktop")
        if (-not ($isDesktop -or $IsWindows)) {
            # Assume other OS has it figured out.
            return $true
        }

        if (-not (Test-Path HKCU:\Console)) {
            # We can't test for it, so call it a day.
            return $true
        }

        $vtl = Get-ItemProperty HKCU:\Console -Name VirtualTerminalLevel -ErrorAction SilentlyContinue
        if (($null -eq $vtl) -or ($vtl.VirtualTerminalLevel -ne 1)) {
            Write-Warning "Enable ANSI color by executing: Set-ItemProperty HKCU:\Console VirtualTerminalLevel -Type DWORD 1"
            return $false
        }

        return $true
    }
}