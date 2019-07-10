<#
.Synopsis
   Gets all the entities from a Kubernetes namespace; or, alternatively, the set of all non-namespaced items.
.PARAMETER Namespace
   The namespace from which entities should be retrieved. Omit this parameter to retrieve non-namespaced items.
.DESCRIPTION
   Gets a list of all the API resources available in the Kubernetes cluster that are namespaced (or non-namespaced,
   as the case may be.) Once that list has been retrieved, removes the 'events' objects if there are any (these get
   too long and numerous to be valuable), then gets everything as requested.

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
        [string]$Namespace
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
        Write-Progress -Activity "Getting resources" -PercentComplete 0
        if ([String]::IsNullOrEmpty($Namespace)) {
            $namespaced = "--namespaced=false"
        }
        else {
            $namespaced = "--namespaced=true"
        }

        Write-Progress -Activity "Getting resources..."
        Write-Progress -Activity "Getting resources..." -CurrentOperation "Retrieving resource IDs from Kubernetes..." -PercentComplete 5
        $resourceList = ([String]::Join(',', (&"$kubectl" api-resources -o name $namespaced)) -replace ',events[^,]*,', ',') -replace ',$', ''
        Write-Verbose "Resource list: $resourceList"
        Write-Progress -Activity "Getting resources..." -CurrentOperation "Retrieving resources from Kubernetes..." -PercentComplete 50

        # Redirect the stderr to stdout so everything shows up correctly rather than overlapping.
        # The Write-Progress moving the cursor around really messes things up. :(
        if ([String]::IsNullOrEmpty($Namespace)) {
            $results = (&kubectl get $resourceList 2>&1)
        }
        else {
            $results = (&kubectl get $resourceList -n $Namespace 2>&1)
        }
        Write-Progress -Activity "Getting resources..." -Completed
        $results
    }
}