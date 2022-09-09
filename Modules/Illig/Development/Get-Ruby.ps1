<#
.SYNOPSIS
    Gets the versions of Ruby installed by `ruby-install`.
.DESCRIPTION
    Searches the current user's `~/.rubies` and `$PREFIX/opt/rubies` folders for
    child folders. Each folder there is considered to be a version of Ruby
    installed by `ruby-install`.

    Logic based on chruby project: https://github.com/postmodern/chruby
.EXAMPLE
    Get-Ruby

    Version    Active Location
    -------    ------ --------
    ruby-3.0.4  False /Users/myname/.rubies/ruby-3.0.4
    ruby-3.1.2  True  /Users/myname/.rubies/ruby-3.1.2
#>
Function Get-Ruby {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param(
    )

    Process {
        $optRubies = Join-Path "opt" "rubies"
        If ($Env:PREFIX) {
            $optRubies = Join-Path $Env:PREFIX $optRubies
        }
        Else {
            $optRubies = "$([System.IO.Path]::DirectorySeparatorChar)$optRubies"
        }
        $search = @($optRubies, (Join-Path $Env:HOME ".rubies"))
        $rubyVersions = @();
        $search | ForEach-Object {
            $dir = $_
            If (Test-Path $dir -PathType Container) {
                Get-ChildItem $dir -Directory | ForEach-Object {
                    $versionDir = $_
                    $active = $False
                    If ($Env:RUBY_ROOT -and $Env:RUBY_ROOT -eq $versionDir.FullName) {
                        $active = $True
                    }
                    $rubyVersion = @{
                        "Version"  = $versionDir.Name
                        "Active"   = $active
                        "Location" = $versionDir
                    }
                    $rubyVersions += [pscustomobject]$rubyVersion
                }
            }
        }
        $rubyVersions
    }
}
