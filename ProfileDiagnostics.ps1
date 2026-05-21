<#
.SYNOPSIS
    Profile startup diagnostics with timing information.
.DESCRIPTION
    When the environment variable PROFILE_DIAGNOSTICS is set to "1" or "true",
    this module logs timestamped messages during profile startup to a temp file.
    After the profile loads, it tells you where the log file is.

    Usage:
      $env:PROFILE_DIAGNOSTICS = "1"
      # Start a new PowerShell session
      # The log file path will be displayed after startup completes.
#>

$Global:__ProfileDiagnostics = @{
    Enabled   = $false
    LogFile   = $null
    StartTime = $null
}

function Initialize-ProfileDiagnostics {
    [CmdletBinding()]
    param()

    $enabled = $env:PROFILE_DIAGNOSTICS
    if ($enabled -eq '1' -or $enabled -eq 'true') {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $logFile = Join-Path ([System.IO.Path]::GetTempPath()) "pwsh-profile-$timestamp.log"
        $Global:__ProfileDiagnostics.Enabled = $true
        $Global:__ProfileDiagnostics.LogFile = $logFile
        $Global:__ProfileDiagnostics.StartTime = [System.Diagnostics.Stopwatch]::StartNew()
        Write-ProfileLog 'Profile startup begin'
    }
}

function Write-ProfileLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message
    )

    if (-not $Global:__ProfileDiagnostics.Enabled) {
        return
    }

    $elapsed = $Global:__ProfileDiagnostics.StartTime.Elapsed.TotalMilliseconds
    $entry = '[{0,8:F1}ms] {1}' -f $elapsed, $Message
    Add-Content -Path $Global:__ProfileDiagnostics.LogFile -Value $entry
}

function Complete-ProfileDiagnostics {
    [CmdletBinding()]
    param()

    if (-not $Global:__ProfileDiagnostics.Enabled) {
        return
    }

    Write-ProfileLog 'Profile startup complete'
    $Global:__ProfileDiagnostics.StartTime.Stop()
    $total = $Global:__ProfileDiagnostics.StartTime.Elapsed.TotalSeconds
    Write-Host "Profile loaded in $([math]::Round($total, 2))s. Diagnostics log: $($Global:__ProfileDiagnostics.LogFile)" -ForegroundColor Cyan
}
