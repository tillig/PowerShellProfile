<#
.SYNOPSIS
   Gets all the entities from a Kubernetes namespace; or, alternatively, the set
   of all non-namespaced items.
.PARAMETER Namespace
   The namespace from which entities should be retrieved. Omit this parameter to
   retrieve non-namespaced items.
.PARAMETER Context
    The Kubernetes context to use. If not specified, the current context will be
    used.
.DESCRIPTION
   Gets a list of all the API resources available in the Kubernetes cluster that
   are namespaced (or non-namespaced, as the case may be.) Once that list has
   been retrieved, removes the 'events' objects if there are any (these get too
   long and numerous to be valuable), then gets everything as requested.

   This can be a lot of data, so it make take a few seconds. Stick with it.
.EXAMPLE
   Get-KubectlAll
.EXAMPLE
   Get-KubectlAll mynamespace
#>
function Get-KubectlAll {
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        [Parameter(ValueFromPipeline = $True, Position = 0)]
        [string]$Namespace,

        [Parameter(ValueFromPipeline = $True)]
        [string]$Context
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
        $kubectlParams = @('api-resources', '-o', 'name')
        if ([String]::IsNullOrEmpty($Namespace)) {
            $kubectlParams += '--namespaced=false'
        }
        else {
            $kubectlParams += '--namespaced=true'
        }

        if (-not [String]::IsNullOrEmpty($Context)) {
            $kubectlParams += "--context=$Context"
        }

        Write-Verbose 'Retrieving resource IDs from Kubernetes.'
        $allResources = &"$kubectl" @kubectlParams 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Unable to retrieve resources from Kubernetes. Please check your kubectl configuration."
            Write-Error $allResources
            Exit 1
        }

        $filteredResources = $allResources | Where-Object {
            # No events, too noisy
            (-not ($_ -match 'events')) -and
            # No external metrics, causes problems with kubectl
            (-not ($_ -match '\.external\.metrics\.k8s\.io'))
        }
        $resourceList = [String]::Join(',', $filteredResources)

        Write-Verbose "Resource list: $resourceList"
        Write-Verbose 'Retrieving resources from Kubernetes.'

        # Redirect the stderr to stdout so everything shows up correctly rather than overlapping.
        # The Write-Progress moving the cursor around really messes things up. :(
        $kubectlParams = @('get', $resourceList)

        if (-not [String]::IsNullOrEmpty($Namespace)) {
            $kubectlParams += '-n'
            $kubectlParams += $Namespace
        }

        if (-not [String]::IsNullOrEmpty($Context)) {
            $kubectlParams += "--context=$Context"
        }

        &"$kubectl" @kubectlParams 2>&1
        $results
    }
}
