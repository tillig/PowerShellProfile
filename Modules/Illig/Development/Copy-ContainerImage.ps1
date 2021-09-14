<#
.SYNOPSIS
    Copies a container image from one registry to another.
.DESCRIPTION
    Pulls a source container image, retags it for a new registry, and pushes to
    the target.
.PARAMETER SourceImage
    The source container image with tag.
.PARAMETER DestinationRegistry
    The destination registry that should get the image and tag.
.EXAMPLE
    Copy-ContainerImage nginx:latest myregistry.azurecr.io
#>
function Copy-ContainerImage {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceImage,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationRegistry
    )

    Begin {
        $docker = Get-Command docker -ErrorAction Ignore
        if ($Null -eq $docker) {
            Write-Error "Unable to locate Docker."
            Exit 1
        }
    }

    Process {
        If ($PSCmdlet.ShouldProcess("$SourceImage", "Pull container image")) {
            &docker pull $SourceImage
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to pull image $SourceImage."
                exit 1
            }

            $imageData = docker images $SourceImage --format '{{json .}}' | ConvertFrom-Json
            $sourceTag = $imageData.Tag
            $sourceRepository = $imageData.Repository
        }
        Else {
            Write-Verbose "Attempting manual image data parse for WhatIf/Confirm support."
            $tagIndex = $SourceImage.IndexOf(':')
            If ($tagIndex -lt 0) {
                $sourceRepository = $SourceImage
                $sourceTag = "latest"
            }
            Else {
                $sourceRepository = $SourceImage.Substring(0, $tagIndex)
                $sourceTag = $SourceImage.Substring($tagIndex + 1)
            }
        }

        $destinationRepository = $sourceRepository;

        # For some.server.com/repository or some.server.com/my/repository, we need
        # to trim the registry part off so we can update. This won't affect Docker
        # Hub names like "kennethreitz/httpbin" or "nginx" - we assume a dot in the
        # first segment means "this is a server" and we'll trim it.
        $slashIndex = $destinationRepository.IndexOf('/');
        if ($slashIndex -ge 0) {
            # There's a slash, let's see if that first segment has a dot.
            $possibleRegistry = $destinationRepository.Substring(0, $slashIndex);
            if ($possibleRegistry.IndexOf('.') -ge 0) {
                # Yup, there's a dot. Assume it's a server name and trim it.
                $destinationRepository = $destinationRepository.Substring($slashIndex + 1)
            }
        }

        $destinationRepository = "$DestinationRegistry/$destinationRepository`:$sourceTag"

        If ($PSCmdlet.ShouldProcess("$destinationRepository", "Tag source $SourceImage and push")) {
            &docker tag $SourceImage $destinationRepository
            &docker push $destinationRepository
        }
    }
}
