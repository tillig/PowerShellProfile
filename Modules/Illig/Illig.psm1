<#
.Synopsis
   Imports Visual Studio environment variables using a fallback method.
.DESCRIPTION
   Looks at the VSPREFERRED variable to require a particular VS version;
   otherwise falls back from 2017 through 2013 to invoke the developer
   command prompt settings.
.EXAMPLE
   Invoke-VisualStudioDevPrompt
#>
function Invoke-VisualStudioDevPrompt {
    [CmdletBinding()]
    Param
    (
    )
    Begin
    {
        $fallbackReleases = @("2015", "2013", "2012", "2010")
    }
    Process
    {
        $origErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = "SilentlyContinue"

            $vsLoaded = $False
            if (-Not ($vsLoaded) -and ($env:VSPREFERRED -eq $NULL -or $env:VSPREFERRED -eq "2017")) {
                $vs2017 = Select-Vs2017InstallPath
                if ($vs2017 -ne $NULL) {
                    Write-Verbose "Attempting VS 2017 load..."
                    Invoke-BatchFile -Path "$vs2017\Common7\Tools\VsDevCmd.bat"
                    $global:PromptEnvironment = " ⌂ vs2017 "
                    $vsLoaded = $True
                }
            }

            foreach ($rel in $fallbackReleases)
            {
                if (-Not ($vsLoaded) -and ($env:VSPREFERRED -eq $NULL -or $env:VSPREFERRED -eq $rel)) {
                    try
                    {
                        Write-Verbose "Attempting VS $rel load..."
                        Import-VisualStudioVars $rel
                        $vsLoaded = $True
                        $global:PromptEnvironment = " ⌂ vs$rel "
                        break;
                    }
                    catch { }
                }
            }
        } catch [Exception]{
            Write-Warning "Unable to initialize VS command settings."
        } finally {
            $ErrorActionPreference = $origErrorAction
        }
    }
}

<#
.Synopsis
   Creates a new machine key element for use in web.config files.
.DESCRIPTION
   Generates new machine key data in XML element format that can be used in a web.config file in an ASP.NET web site.
.EXAMPLE
   New-MachineKey
.EXAMPLE
   New-MachineKey -Validation SHA1
#>
function New-MachineKey
{
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

    Process
    {
        function BinaryToHex {
            [CmdLetBinding()]
            Param($bytes)
            Process
            {
                $builder = new-object System.Text.StringBuilder
                foreach ($b in $bytes)
                {
                    $builder = $builder.AppendFormat([System.Globalization.CultureInfo]::InvariantCulture, "{0:X2}", $b)
                }
                $builder
            }
        }

        switch ($Decryption)
        {
            "AES" { $decryptionObject = new-object System.Security.Cryptography.AesCryptoServiceProvider }
            "DES" { $decryptionObject = new-object System.Security.Cryptography.DESCryptoServiceProvider }
            "3DES" { $decryptionObject = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider }
        }

        $decryptionObject.GenerateKey()
        $decryptionKey = BinaryToHex($decryptionObject.Key)
        $decryptionObject.Dispose()

        switch ($Validation)
        {
            "MD5" { $validationObject = new-object System.Security.Cryptography.HMACMD5 }
            "SHA1" { $validationObject = new-object System.Security.Cryptography.HMACSHA1 }
            "HMACSHA256" { $validationObject = new-object System.Security.Cryptography.HMACSHA256 }
            "HMACSHA385" { $validationObject = new-object System.Security.Cryptography.HMACSHA384 }
            "HMACSHA512" { $validationObject = new-object System.Security.Cryptography.HMACSHA512 }
        }

        $validationKey = BinaryToHex($validationObject.Key)
        $validationObject.Dispose()
        if($PrettyPrint)
        {
            $space = [System.Environment]::NewLine + "            "
        }
        else
        {
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
function Remove-TempFiles
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
    )

    Begin
    {
        $tempFolders = @(
            $env:TEMP,
            "$($env:LOCALAPPDATA)\Temp",
            "$($env:windir)\Microsoft.NET\Framework\v2.0.50727\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework64\v2.0.50727\Temporary ASP.NET Files",
            "$($env:windir)\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files")
    }
    Process
    {
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
function Reset-Source
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [System.IO.DirectoryInfo[]] $Source
    )
    Begin
    {
        & nuget locals -clear all
    }
    Process
    {
        if($Source -eq $null -or $Source.Length -eq 0) {
            & git clean -dfx
        }
        else {
            foreach($path in $Source) {
                Push-Location $path
                & git clean -dfx
                Pop-Location
            }
        }
    }
}

<#
.Synopsis
   Locates the VS 2017 standard install with the most features.
.DESCRIPTION
   Looks at the standard install locations for the various VS 2017 SKUs and
   returns the first found. Iterates through the SKUs from most to least
   featured. Requires the VSSetup module for the "Get-VsSetupInstance" command.
.EXAMPLE
   Select-Vs2017InstallPath
.EXAMPLE
   Select-Vs2017InstallPath -Prerelease
#>
function Select-Vs2017InstallPath {
    [CmdletBinding()]
    Param
    (
        [switch] $Prerelease
    )
    Begin
    {
        $vsReleases = @("Microsoft.VisualStudio.Product.Enterprise", "Microsoft.VisualStudio.Product.Professional", "Microsoft.VisualStudio.Product.Community")
        $vsInstalls = Get-VsSetupInstance -All -Prerelease:$Prerelease | Sort-Object -Property @{ Expression = { $_.Product.Version } } -Descending
    }
    Process
    {
        foreach($rel in $vsReleases) {
            $found = $vsInstalls | Where-Object { $_.Product.Id -eq $rel } | Select-Object -First 1
            if ($found -ne $NULL) {
                return $found.InstallationPath
            }
        }

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
        [Parameter(ParameterSetName="Unicode")]
        [Switch]
        $UTF8,

        [Parameter(ParameterSetName="Default")]
        [Switch]
        $Default
    )
    Process
    {
        if ($Default) {
            [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(437)
        }
        else {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        }
    }
}
