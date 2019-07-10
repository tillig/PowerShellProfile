<#
.Synopsis
   Opens a shell into a running Kubernetes pod.
.PARAMETER Namespace
   The namespace of the running pod. Defaults to 'default'.
.PARAMETER Selector
   A label selector (e.g., app=my-app) to narrow down which pod. Without a selector, it'll be the first pod in
   the namespace.
.PARAMETER Shell
   The path to the shell to run. Defaults to '/bin/bash'
.DESCRIPTION
   Gets a shell in a running pod. Assumes the first container in the first matching pod.
.EXAMPLE
   Get-KubectlShell -Namespace mynamespace -Shell powershell
#>
function Get-KubectlShell {
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        [Parameter(ValueFromPipeline = $True, Mandatory = $false)]
        [string]$Namespace = "default",

        [Parameter(ValueFromPipeline = $True, Mandatory = $false)]
        [string]$Selector = $null,

        [Parameter(ValueFromPipeline = $True, Mandatory = $false)]
        [string]$Shell = "/bin/bash"
    )
    Begin {
        $kubectl = Get-Command kubectl -ErrorAction Ignore
        if ($Null -eq $kubectl) {
            Write-Error "Unable to locate kubectl."
            Exit 1
        }

        $kubectl = $kubectl.Source
    }
    Process {
        $args = @("get", "pods", "-o", "jsonpath={.items[0]..metadata.name}")
        if (-Not ([string]::IsNullOrWhiteSpace($Namespace))) {
            $args += "-n"
            $args += $Namespace
        }
        if (-Not ([string]::IsNullOrWhiteSpace($Selector))) {
            $args += "-l=$Selector"
        }
        $podName = &$kubectl $args 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Unable to retrieve pod name."
            exit 1
        }

        $args = @("exec", "-it", $podName)
        if (-Not ([string]::IsNullOrWhiteSpace($Namespace))) {
            $args += "-n"
            $args += $Namespace
        }
        $args += "--"
        $args += $Shell

        &$kubectl $args
    }
}