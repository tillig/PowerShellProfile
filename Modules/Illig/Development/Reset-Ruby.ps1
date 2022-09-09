<#
.SYNOPSIS
    Resets the Ruby environment variables and paths back to default/system
    settings.
.DESCRIPTION
    The Enable-Ruby command updates the local path and sets Ruby-related
    environment variables to enable the selected runtime. This command removes
    the updated path settings and removes the extra environment variables.

    Logic based on chruby project: https://github.com/postmodern/chruby
.EXAMPLE
    Reset-Ruby
#>
Function Reset-Ruby {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param(
    )

    Begin {
        $pathSeparator = ":";
        if ($IsWindows) {
            $pathSeparator = ";";
        }

    }

    Process {
        # RUBY_ROOT gets set by Enable-Ruby and signifies other environment variables will be present.
        If (-not $Env:RUBY_ROOT) {
            return
        }

        $pathValues = $Env:PATH.Split($pathSeparator)

        $toRemove = Join-Path $Env:RUBY_ROOT "bin"
        Write-Verbose "Removing $toRemove from path."
        $pathValues = $pathValues | Where-Object { $_ -ne $toRemove }

        If (-not (Test-Administrator)) {
            $gemPathValues = @()
            If ($Env:GEM_PATH) {
                $gemPathValues = $Env:GEM_PATH.Split($pathSeparator)
            }
            If ($Env:GEM_HOME) {
                Write-Verbose "Removing GEM_HOME ($($Env:GEM_HOME)) from paths."
                $toRemove = Join-Path $Env:GEM_HOME "bin"
                $pathValues = $pathValues | Where-Object { $_ -ne $toRemove }
                $gemPathValues = $gemPathValues | Where-Object { $_ -ne $Env:GEM_HOME }
            }
            If ($Env:GEM_ROOT) {
                Write-Verbose "Removing GEM_ROOT ($($Env:GEM_ROOT)) from paths."
                $toRemove = Join-Path $Env:GEM_ROOT "bin"
                $pathValues = $pathValues | Where-Object { $_ -ne $toRemove }
                $gemPathValues = $gemPathValues | Where-Object { $_ -ne $Env:GEM_ROOT }
            }
            If ($gemPathValues.Length -gt 0) {
                $newGemPath = [string]::Join($pathSeparator, $gemPathValues)
                Write-Verbose "Updating GEM_PATH from $($Env:GEM_PATH) to $newGemPath"
                [Environment]::SetEnvironmentVariable("GEM_PATH", $newGemPath)
            }
            Else {
                Write-Verbose "Removing GEM_PATH environment variable."
                [Environment]::SetEnvironmentVariable("GEM_PATH", $null, "User")
            }

            Write-Verbose "Removing GEM_HOME and GEM_ROOT environment variables."
            [Environment]::SetEnvironmentVariable("GEM_HOME", $null, "User")
            [Environment]::SetEnvironmentVariable("GEM_ROOT", $null, "User")
        }

        $newPath = [string]::Join($pathSeparator, $pathValues)
        Write-Verbose "Updating PATH to $newPath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath)

        Write-Verbose "Removing RUBY_ROOT, RUBY_ENGINE, RUBY_VERSION, and RUBYOPT environment variables."
        [Environment]::SetEnvironmentVariable("RUBY_ROOT", $null, "User")
        [Environment]::SetEnvironmentVariable("RUBY_ENGINE", $null, "User")
        [Environment]::SetEnvironmentVariable("RUBY_VERSION", $null, "User")
        [Environment]::SetEnvironmentVariable("RUBYOPT", $null, "User")
    }
}
