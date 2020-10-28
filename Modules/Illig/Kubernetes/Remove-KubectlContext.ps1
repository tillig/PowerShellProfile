<#
.SYNOPSIS
    Removes an entire kubectl context - the user, cluster, and context definition.
.DESCRIPTION
    Gets a particular kubectl context by name and removes the entire thing, not
    just the context definition. This includes the user credentials, the cluster
    endpoint location, and the context definition.
.PARAMETER ContextName
    The name of the kubectl context to remove.
.PARAMETER ConfigurationFile
    The kubectl configuration file containing the context to remove. If omitted,
    uses the default configuration file.
.EXAMPLE
   Remove-KubectlContext mycontext
.EXAMPLE
   Remove-KubectlContext mycontext -ConfigurationFile ./kubeconfig
#>
function Remove-KubectlContext {
    [CmdletBinding(SupportsShouldProcess = $True,
        ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $True,
            Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $ContextName,

        [Parameter(Mandatory = $False)]
        [string]
        $ConfigurationFile = $null
    )

    Process {
        If (-not [System.String]::IsNullOrWhiteSpace($ConfigurationFile)) {
            $configFileParameter = "--kubeconfig=`"$ConfigurationFile`""
        }

        $contextTable = (&kubectl config get-contexts --no-headers=true $configFileParameter).Split("`n")
        $contextTable | ForEach-Object {
            $contextLine = $_
            If ($contextLine -match '\*?\s+(?<name>\S+)\s+(?<cluster>\S+)\s+(?<authinfo>\S+)' -and $Matches.name -eq $ContextName) {
                If ($pscmdlet.ShouldProcess("$ContextName", "Remove kubectl context")) {
                    &kubectl config delete-context $Matches.name $configFileParameter
                    &kubectl config delete-cluster $Matches.cluster $configFileParameter
                    &kubectl config unset "users.$($Matches.authinfo)" $configFileParameter
                }
            }
        }
    }
}
