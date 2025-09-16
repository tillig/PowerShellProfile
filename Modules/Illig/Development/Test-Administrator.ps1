<#
.SYNOPSIS
    Determines if the current user is an administrator.
.DESCRIPTION
    Simple cross-platform test to see if the current user is a machine admin or
    not.
.EXAMPLE
    Test-Administrator
#>
function Test-Administrator {
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([bool])]
    param(
    )
    process {
        $isDesktop = ($PSVersionTable.PSEdition -eq 'Desktop')
        if ($isDesktop -or $IsWindows) {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity
            return $windowsPrincipal.IsInRole('Administrators') -eq 1
        }
        else {
            return ((& id -u) -eq 0)
        }
    }
}
