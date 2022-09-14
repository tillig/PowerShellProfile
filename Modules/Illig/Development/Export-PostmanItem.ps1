<#
.SYNOPSIS
    Exports an environment or collection from Postman.
.DESCRIPTION
    Uses the Postman API to export an environment or collection from Postman.
    Helpful in working with Postman in a local context, where you might have to
    create tests in Postman and then export them so they can be packaged into a
    container to run Newman or sent to a teammate for sharing.
.PARAMETER ApiKey
    A Postman API key that enables synchronization with your Postman account.
.PARAMETER ItemType
    The type of item (Collection, Environment) you want to export.
.PARAMETER ItemName
    The name of the item in Postman. If there are multiple items found with the
    same name, the first one found will be picked.
.PARAMETER WorkspaceName
    The name of the Postman workspace the item is in. Defaults to "My Workspace"
    - the standard Postman workspace.
.EXAMPLE
    Export-PostmanItem -ApiKey "YOUR-API-KEY" -ItemType Collection -ItemName "My API"

    Loads the JSON for the "My API" collection from the default Postman
    workspace "My Workspace."
.EXAMPLE
    Export-PostmanItem -ApiKey "YOUR-API-KEY" -ItemType Collection -ItemName "My API" | Out-File ./my-api.postman_collection.json

    Loads the JSON for the "My API" collection from the default Postman
    workspace "My Workspace" and exports it to a file.
.EXAMPLE
    Export-PostmanItem -ApiKey "YOUR-API-KEY" -ItemType Envirionment -ItemName "Testing" -WorkspaceName "QA"

    Loads the JSON for the "Testing" environment from the "QA" workspace.
#>
Function Export-PostmanItem {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $True)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $stringMatch)
                enum ItemType { Collection = 1; Environment = 2; }
                [ItemType].GetEnumValues() | Where-Object { $_.ToString().StartsWith($stringMatch) }
            })]
        [ValidateScript({
                enum ItemType { Collection = 1; Environment = 2; }
                [ItemType]$_
            })]
        $ItemType,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ItemName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $WorkspaceName = "My Workspace"
    )

    Begin {
        enum ItemType { Collection; Environment; }
        $baseUrl = "https://api.getpostman.com"
        $headers = @{
            "Content-Type" = "application/json"
            "X-API-Key"    = $ApiKey
        }

        Function Get-Workspaces {
            Invoke-RestMethod -Uri "$baseUrl/workspaces" -Headers $headers
        }

        <#
        .SYNOPSIS
            Recurses an object tree and removes all properties named 'id.'
        .DESCRIPTION
            Useful in trimming out the properties in an API-exported collection.
            When exporting from the UI, none of the ID properties come out.
        .PARAMETER obj
            The PSObject with properties to iterate/recurse over.
        #>
        Function Remove-IdProperty {
            Param([PSObject] $obj)
            $obj.Properties.Remove("id");
            $obj.Members | Where-Object { $_.MemberType -eq 'NoteProperty' } | ForEach-Object {
                $member = $_
                If ($member.TypeNameOfValue -eq "System.Object[]" ) {
                    $member.Value | ForEach-Object {
                        Remove-IdProperty $_.PSObject
                    }
                }
                ElseIf ($member.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject") {
                    Remove-IdProperty $member.Value.PSObject
                }
            }
        }

        $allWorkspaces = Get-Workspaces | Select-Object -ExpandProperty "workspaces"
    }

    Process {
        If ([ItemType]::Collection -eq $ItemType) {
            $plural = "collections"
            $singular = "collection"
        }
        Else {
            $plural = "environments"
            $singular = "environment"
        }

        $targetWorkspace = $allWorkspaces | Where-Object { $_.name -eq $WorkspaceName } | Select-Object -First 1
        If ($Null -eq $targetWorkspace) {
            throw "Unable to find workspace: $WorkspaceName"
        }
        Write-Verbose "Found workspace $($targetWorkspace.name): $($targetWorkspace.id)"
        $items = Invoke-RestMethod -Uri "$baseUrl/$plural`?workspaceId=$($targetWorkspace.id)" -Headers $headers | Select-Object -ExpandProperty $plural
        Write-Verbose "Found $($items.Count) items."
        $itemMetadata = $items | Where-Object { $_.name -eq $ItemName } | Select-Object -First 1
        If ($Null -eq $itemMetadata) {
            throw "Unable to find item: $ItemName"
        }
        $itemToExport = Invoke-RestMethod -Uri "$baseUrl/$plural/$($itemMetadata.uid)`?workspaceId=$($targetWorkspace.id)" -Headers $headers | Select-Object -ExpandProperty $singular

        # Update properties to be more like what comes from a UI export.
        $itemToExport.PSObject.Properties.Remove("createdAt")
        $itemToExport.PSObject.Properties.Remove("isPublic")
        $itemToExport.PSObject.Properties.Remove("owner")
        $itemToExport.PSObject.Properties.Remove("updatedAt")

        If ([ItemType]::Collection -eq $ItemType) {
            $itemToExport.info.PSObject.Properties.Remove("updatedAt")
            Remove-IdProperty $itemToExport.PSObject
        }
        Else {
            $itemToExport | Add-Member -MemberType NoteProperty -Name "_postman_exported_at" -Value (Get-Date -AsUTC -Format o)
            $itemToExport | Add-Member -MemberType NoteProperty -Name "_postman_exported_using" -Value "PowerShell"
            $itemToExport | Add-Member -MemberType NoteProperty -Name "_postman_variable_scope" -Value $singular
        }

        $itemToExport | ConvertTo-Json -Depth 100
    }
}
