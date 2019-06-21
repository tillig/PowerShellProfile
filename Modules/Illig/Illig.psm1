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

<#
.Synopsis
   Imports Visual Studio environment variables using a fallback method.
.DESCRIPTION
   Looks at the VSPREFERRED variable to require a particular VS version;
   otherwise falls back from latest VS through 2010 to invoke the developer
   command prompt settings.
.EXAMPLE
   Invoke-VisualStudioDevPrompt
#>
function Invoke-VisualStudioDevPrompt {
    [CmdletBinding()]
    Param
    (
    )
    Begin {
        $fallbackReleases = @("2015", "2013", "2012", "2010")
    }
    Process {
        $origErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = "SilentlyContinue"

            if ($NULL -eq $env:VSPREFERRED -or (-not $fallbackReleases.Contains($env:VSPREFERRED))) {
                $vs = Select-VsInstall -Year "$($env:VSPREFERRED)"
                if ($NULL -ne $vs) {
                    Write-Verbose "Attempting VS load..."
                    Invoke-BatchFile -Path "$($vs.InstallationPath)\Common7\Tools\VsDevCmd.bat"
                    $vsYear = $vs.DisplayName -replace '.*\s+(\d\d\d\d).*', '${1}'
                    $global:PromptEnvironment = " ⌂ vs$vsYear "
                    return
                }
            }

            foreach ($rel in $fallbackReleases) {
                if ($NULL -eq $env:VSPREFERRED -or $env:VSPREFERRED -eq $rel) {
                    try {
                        Write-Verbose "Attempting VS $rel load..."
                        Import-VisualStudioVars $rel
                        $global:PromptEnvironment = " ⌂ vs$rel "
                        break;
                    }
                    catch { }
                }
            }
        }
        catch [Exception] {
            Write-Warning "Unable to initialize VS command settings."
        }
        finally {
            $ErrorActionPreference = $origErrorAction
        }
    }
}

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
function New-MachineKey {
    [CmdletBinding(HelpUri = 'https://support.microsoft.com/en-us/kb/2915218#AppendixA')]
    [OutputType([String])]
    Param
    (
        [ValidateSet("AES", "DES", "3DES")]
        [string]$Decryption = 'AES',
        [ValidateSet("MD5", "SHA1", "HMACSHA256", "HMACSHA384", "HMACSHA512")]
        [string]$Validation = 'HMACSHA256',
        [switch]$PrettyPrint
    )

    Process {
        function BinaryToHex {
            [CmdLetBinding()]
            Param($bytes)
            Process {
                $builder = new-object System.Text.StringBuilder
                foreach ($b in $bytes) {
                    $builder = $builder.AppendFormat([System.Globalization.CultureInfo]::InvariantCulture, "{0:X2}", $b)
                }
                $builder
            }
        }

        switch ($Decryption) {
            "AES" { $decryptionObject = new-object System.Security.Cryptography.AesCryptoServiceProvider }
            "DES" { $decryptionObject = new-object System.Security.Cryptography.DESCryptoServiceProvider }
            "3DES" { $decryptionObject = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider }
        }

        $decryptionObject.GenerateKey()
        $decryptionKey = BinaryToHex($decryptionObject.Key)
        $decryptionObject.Dispose()

        switch ($Validation) {
            "MD5" { $validationObject = new-object System.Security.Cryptography.HMACMD5 }
            "SHA1" { $validationObject = new-object System.Security.Cryptography.HMACSHA1 }
            "HMACSHA256" { $validationObject = new-object System.Security.Cryptography.HMACSHA256 }
            "HMACSHA385" { $validationObject = new-object System.Security.Cryptography.HMACSHA384 }
            "HMACSHA512" { $validationObject = new-object System.Security.Cryptography.HMACSHA512 }
        }

        $validationKey = BinaryToHex($validationObject.Key)
        $validationObject.Dispose()
        if ($PrettyPrint) {
            $space = [System.Environment]::NewLine + "            "
        }
        else {
            $space = " "
        }

        [string]::Format([System.Globalization.CultureInfo]::InvariantCulture,
            "<machineKey decryption=`"{0}`"{4}decryptionKey=`"{1}`"{4}validation=`"{2}`"{4}validationKey=`"{3}`" />",
            $Decryption.ToUpperInvariant(),
            $decryptionKey,
            $Validation.ToUpperInvariant(),
            $validationKey,
            $space)
    }
}

<#
.Synopsis
   Clears out temporary folders.
.DESCRIPTION
   Removes temporary files from the current user and temporary ASP.NET files.
.EXAMPLE
   Remove-TempFiles
#>
function Remove-TempFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param
    (
    )

    Begin {
        $tempFolders = @(
            $env:TEMP,
            "$($env:LOCALAPPDATA)\Temp",
            "$($env:windir)\Microsoft.NET\Framework\v2.0.50727\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework64\v2.0.50727\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files")
    }
    Process {
        foreach ($tempFolder in $tempFolders) {
            if ((Test-Path $tempFolder) -and ($pscmdlet.ShouldProcess("$tempFolder", "Remove items from temporary folder"))) {
                Get-ChildItem $tempFolder | Remove-Item -Force -Recurse
            }
        }
    }
}

<#
.Synopsis
   Resets a git source tree and cleans the NuGet cache for a full clean build.
.DESCRIPTION
   Does both a git and NuGet clean to ensure a fresh build on a source tree.
.EXAMPLE
   Reset-Source
#>
function Reset-Source {
    [CmdletBinding()]
    Param
    (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [System.IO.DirectoryInfo[]] $Source
    )
    Begin {
        & nuget locals -clear all
    }
    Process {
        if ($NULL -eq $Source -or $Source.Length -eq 0) {
            & git clean -dfx
        }
        else {
            foreach ($path in $Source) {
                Push-Location $path
                & git clean -dfx
                Pop-Location
            }
        }
    }
}

<#
.Synopsis
   Locates the VS standard install with the most features.
.DESCRIPTION
   Looks at the standard install locations for the various VS SKUs and
   returns the first found. Iterates through the SKUs from most to least
   featured. Requires the VSSetup module for the "Get-VsSetupInstance" command.
.EXAMPLE
   Select-VsInstall
.EXAMPLE
   Select-VsInstall -Prerelease
#>
function Select-VsInstall {
    [CmdletBinding()]
    Param
    (
        [string] $Year,
        [switch] $Prerelease
    )
    Begin {
        $vsReleases = @("Microsoft.VisualStudio.Product.Enterprise", "Microsoft.VisualStudio.Product.Professional", "Microsoft.VisualStudio.Product.Community")
        $vsInstalls = Get-VsSetupInstance -All -Prerelease:$Prerelease | Sort-Object -Property @{ Expression = { $_.Product.Version } } -Descending
    }
    Process {
        $availableInstalls = $vsInstalls
        if (-not [System.String]::IsNullOrEmpty($Year)) {
            Write-Verbose "Filtering list of VS installs by year [$Year]."
            $availableInstalls = $availableInstalls | Where-Object { ($_.DisplayName -replace '.*\s+(\d\d\d\d).*', '${1}') -eq $Year }
        }
        foreach ($rel in $vsReleases) {
            $found = $availableInstalls | Where-Object { $_.Product.Id -eq $rel } | Select-Object -First 1
            if ($NULL -ne $found) {
                Write-Verbose "Found $($found.DisplayName)."
                return $found
            }
        }

        Write-Verbose "No matching VS installs selected."
        return $NULL
    }
}

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
