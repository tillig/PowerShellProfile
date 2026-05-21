<#
.SYNOPSIS
    Downloads a NuGet package from a configured source.
.DESCRIPTION
    Queries all enabled NuGet sources (from `dotnet nuget list source`) and
    downloads the specified package to a local directory. If a version is not
    specified, the latest available version is downloaded. Sources are tried in
    order until one succeeds.
.PARAMETER PackageName
    The name of the NuGet package to download.
.PARAMETER DownloadPath
    The directory where the .nupkg file should be saved. Created if it does not
    exist.
.PARAMETER Version
    The specific version to download. If omitted, the latest version is
    downloaded.
.EXAMPLE
    Save-NuGetPackage -PackageName 'Newtonsoft.Json' -DownloadPath './packages'
.EXAMPLE
    Save-NuGetPackage -PackageName 'Newtonsoft.Json' -DownloadPath './packages' -Version '13.0.3'
#>
function Save-NuGetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PackageName,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DownloadPath,

        [Parameter(Mandatory = $False)]
        [string]
        $Version
    )

    begin {
        $dotnet = Get-Command dotnet -ErrorAction Ignore
        if ($Null -eq $dotnet) {
            Write-Error 'Unable to locate dotnet CLI.'
            return
        }

        if (-not (Test-Path -Path $DownloadPath)) {
            New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        }
    }

    process {
        $sourceOutput = dotnet nuget list source 2>&1 | Out-String
        $sources = @()
        $sourceName = $Null
        foreach ($line in $sourceOutput -split "`n") {
            $line = $line.Trim()
            if ($line -match '^\d+\.\s+.+\[Enabled\]') {
                $sourceName = ($line -replace '^\d+\.\s+', '' -replace '\s*\[Enabled\].*', '').Trim()
                continue
            }
            if ($sourceName -and $line -match '^https?://') {
                $sources += [PSCustomObject]@{ Name = $sourceName; Url = $line }
                $sourceName = $Null
            }
        }

        if ($sources.Count -eq 0) {
            Write-Error "No enabled NuGet sources found. Run 'dotnet nuget list source' to check your configuration."
            return
        }

        Write-Verbose "Found $($sources.Count) enabled source(s): $($sources.Name -join ', ')"

        $lowerName = $PackageName.ToLowerInvariant()
        $errors = @()

        foreach ($source in $sources) {
            Write-Verbose "Trying source '$($source.Name)' ($($source.Url))..."

            try {
                $serviceIndex = Invoke-RestMethod -Uri $source.Url
            }
            catch {
                Write-Verbose "  Could not reach service index: $_"
                $errors += "[$($source.Name)] Service index unreachable: $_"
                continue
            }

            $packageBaseAddress = ($serviceIndex.resources | Where-Object { $_.'@type' -eq 'PackageBaseAddress/3.0.0' }).'@id'
            if (-not $packageBaseAddress) {
                Write-Verbose '  No PackageBaseAddress resource found.'
                $errors += "[$($source.Name)] No PackageBaseAddress resource in service index."
                continue
            }

            $packageBaseAddress = $packageBaseAddress.TrimEnd('/')

            $resolvedVersion = $Version
            if (-not $resolvedVersion) {
                $versionsUrl = "$packageBaseAddress/$lowerName/index.json"
                try {
                    $versionsResponse = Invoke-RestMethod -Uri $versionsUrl
                }
                catch {
                    Write-Verbose '  Package not found at this source.'
                    $errors += "[$($source.Name)] Package '$PackageName' not found."
                    continue
                }
                $resolvedVersion = $versionsResponse.versions | Select-Object -Last 1
                if (-not $resolvedVersion) {
                    Write-Verbose '  No versions available.'
                    $errors += "[$($source.Name)] Package '$PackageName' has no versions."
                    continue
                }
                Write-Verbose "  Resolved latest version: $resolvedVersion"
            }

            $lowerVersion = $resolvedVersion.ToLowerInvariant()
            $nupkgUrl = "$packageBaseAddress/$lowerName/$lowerVersion/$lowerName.$lowerVersion.nupkg"
            $outputFile = Join-Path $DownloadPath "$PackageName.$resolvedVersion.nupkg"

            try {
                Write-Verbose "  Downloading $nupkgUrl"
                Invoke-WebRequest -Uri $nupkgUrl -OutFile $outputFile
            }
            catch {
                Write-Verbose "  Download failed: $_"
                $errors += "[$($source.Name)] Download failed for $PackageName $resolvedVersion`: $_"
                continue
            }

            Write-Verbose "  Downloaded $PackageName $resolvedVersion from '$($source.Name)' to $outputFile"
            [PSCustomObject]@{
                Name    = $PackageName
                Version = $resolvedVersion
                Path    = (Resolve-Path $outputFile).Path
            }
            return
        }

        $errorDetail = $errors -join [Environment]::NewLine
        Write-Error "Package '$PackageName' $(if ($Version) { "version $Version " })not found in any configured source.`n$errorDetail"
    }
}
