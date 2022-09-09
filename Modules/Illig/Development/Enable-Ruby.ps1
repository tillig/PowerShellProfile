<#
.SYNOPSIS
    Enables a specific version of Ruby that is installed.
.DESCRIPTION
    Updates the environment to use a version of Ruby that has been installed by
    `ruby-install`. Uses the `Get-Ruby` command to locate Ruby installations
    that are available.

    Logic based on chruby project: https://github.com/postmodern/chruby
.PARAMETER Version
    The version of Ruby to enable. This can be a full version ("ruby-3.1.2"),
    just a version number ("3.1.2"), or even a partial match ("3.1").
.PARAMETER RubyOpt
    The value for the RUBYOPT environment variable after running. Sets
    Ruby-specific runtime options.
.EXAMPLE
    Enable-Ruby 3.1.2
.EXAMPLE
    Enable-Ruby 3.1 -Verbose
#>
Function Enable-Ruby {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [string]
        $Version,

        [Parameter(Position = 2)]
        [string]
        $RubyOpt
    )

    Begin {
        $rubies = Get-Ruby
        $pathSeparator = ":";
        if ($IsWindows) {
            $pathSeparator = ";";
        }
    }

    Process {
        # Locate Ruby version - exact match first.
        $match = $rubies | Where-Object { $_.Version -eq $Version } | Select-Object -First 1
        If (-not $match) {
            # Substring match if no exact match.
            $match = $rubies | Where-Object { $_.Version -like "*$Version*" } | Select-Object -First 1
            If (-not $match) {
                throw "Unknown Ruby: $Version"
            }
        }

        $binPath = Join-Path $match.Location.FullName "bin"
        $exePath = Join-Path $binPath "ruby"
        If (-not (Test-Path $exePath -PathType Leaf)) {
            throw "$exePath is not a Ruby executable"
        }

        If ($Env:RUBY_ROOT) {
            Reset-Ruby -Verbose:$VerbosePreference
        }

        Write-Verbose "Setting RUBY_ROOT to $($match.Location.FullName)"
        [Environment]::SetEnvironmentVariable("RUBY_ROOT", $match.Location.FullName)
        If ($RubyOpt) {
            Write-Verbose "Setting RUBYOPT to $RubyOpt"
            [Environment]::SetEnvironmentVariable("RUBYOPT", $RubyOpt)
        }

        $newPath = "$binPath$pathSeparator$($Env:PATH)"
        Write-Verbose "Setting PATH to $newPath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath)

        If (-not (Test-Administrator)) {
            $script = @"
puts "{"
puts "\"ruby_engine\":\"#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'}\","
puts "\"ruby_version\":\"#{RUBY_VERSION}\","
puts "\"gem_root\":"
begin
    require 'rubygems'
    puts "#{Gem.default_dir.inspect}"
    rescue LoadError
        puts "\"\""
end
puts "}"
"@
            $rubyInfo = ($script | & $exePath) | ConvertFrom-Json

            $gemHome = Join-Path $Env:HOME ".gem" $rubyInfo.ruby_engine $rubyInfo.ruby_version
            Write-Verbose "Setting GEM_HOME to $gemHome"
            [Environment]::SetEnvironmentVariable("GEM_HOME", $gemHome)

            $gemPath = $gemHome
            If ($rubyInfo.gem_root) {
                Write-Verbose "Setting GEM_ROOT to $($rubyInfo.gem_root)"
                [Environment]::SetEnvironmentVariable("GEM_ROOT", $rubyInfo.gem_root)
                $gemPath = "$gemPath$pathSeparator$($rubyInfo.gem_root)"
            }
            If ($Env:GEM_PATH) {
                $gemPath = "$gemPath$pathSeparator$($Env:GEM_PATH)"
            }
            Write-Verbose "Setting GEM_PATH to $gemPath"
            [Environment]::SetEnvironmentVariable("GEM_PATH", $gemPath)

            $newPath = $Env:PATH
            If ($rubyInfo.gem_root) {
                $gemRootBin = Join-Path $rubyInfo.gem_root "bin"
                $newPath = "$gemRootBin$pathSeparator$newPath"
            }
            $gemHomeBin = Join-Path $gemHome "bin"
            $newPath = "$gemHomeBin$pathSeparator$newPath"
            Write-Verbose "Setting PATH to $newPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath)
        }
    }
}
