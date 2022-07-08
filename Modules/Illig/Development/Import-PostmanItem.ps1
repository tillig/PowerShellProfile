<#
.SYNOPSIS
    Imports an environment or collection into Postman.
.DESCRIPTION
    Uses the Postman API to import an environment or collection into Postman.
    Helpful in working with Postman in a local context, where you might have to
    update some tests that are shared as a file or stored in a Git repo.
.PARAMETER ApiKey
    A Postman API key that enables synchronization with your Postman account.
.PARAMETER ItemType
    The type of item (Collection, Environment) you want to import.
.PARAMETER ItemUid
    The ID of the item in Postman that you are updating. If you omit this
    parameter, it will create a new item in Postman. If you provide the
    parameter and an item with the ID is not found, you'll get an error.

    Get this value from the Postman UI. No validation is done to ensure what you
    provide is correct.
.PARAMETER FilePath
    Path to the JSON file that has the data to import.
.PARAMETER WorkspaceName
    The name of the Postman workspace the item is in. Defaults to "My Workspace"
    - the standard Postman workspace.
.EXAMPLE
    Import-PostmanItem -ApiKey "YOUR-API-KEY" -ItemType Collection -FilePath ./postman.json

    Create a new Postman collection with the provided collection.
.EXAMPLE
    Import-PostmanItem -ApiKey "YOUR-API-KEY" -ItemType Collection -FilePath ./postman.json -ItemUid "ITEM-UID-HERE"

    Update an existing new Postman collection with the provided collection
    data. If the name of the collection in the JSON file is different than the
    name in Postman right now, the name in Postman will also be updated.
#>
Function Import-PostmanItem {
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

        [Parameter(Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ItemUid,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FilePath,

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

        $fullFilePath = Resolve-Path $FilePath
        $entity = Get-Content $fullFilePath | ConvertFrom-Json
        $body = @{
            $singular = $entity
        } | ConvertTo-Json -Depth 100

        $targetWorkspace = $allWorkspaces | Where-Object { $_.name -eq $WorkspaceName } | Select-Object -First 1
        If ($Null -eq $targetWorkspace) {
            throw "Unable to find workspace: $WorkspaceName"
        }
        Write-Verbose "Found workspace $($targetWorkspace.name): $($targetWorkspace.id)"

        $targetUrl = "$baseUrl/$plural"
        If (-not [String]::IsNullOrEmpty($ItemUid)) {
            $verb = "PUT"
            $targetUrl = "$targetUrl/$ItemUid"
        }
        Else {
            $verb = "POST"
        }

        $item = Invoke-RestMethod -Uri "$targetUrl`?workspaceId=$($targetWorkspace.id)" -Method $verb -Headers $headers -Body $body
        return $item
    }
}
