<# Original code from @rkeithhill - https://gist.github.com/rkeithhill/4099bfd8420eed0e6dbc #>
<#
.SYNOPSIS
    Optimizes your PSReadline history save file.
.DESCRIPTION
    Optimizes your PSReadline history save file by removing duplicate
    entries and optionally removing commands that are not longer than
    a minimum length
.EXAMPLE
    C:\PS> Optimize-PSReadlineHistory
    Removes all the duplicate commands.
.EXAMPLE
    C:\PS> Optimize-PSReadlineHistory -MinimumCommandLength 3
    Removes all the duplicate commands and any commands less than 3 characters in length.
.NOTES
    May 15, 2017 - fix bug in handling of multiline commands.
#>
function Optimize-PSReadlineHistory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # Path to the PSReadline history file to optimize.
        [Parameter()]
        [string]
        $HistoryPath,

        # If specified, any commands less than $MinimumCommandLength will be removed from the history file.
        [Parameter()]
        [int]
        $MinimumCommandLength = 1,

        # If specified, removes leading whitespace from the beginning of the command or the beginning of
        # the first line of multiline commands.
        [Parameter()]
        [switch]
        $TrimLeadingWhitespace,

        # If specified, the check for other PowerShell processes is skipped. You can do this when you are operating on a
        # copy of PSReadline history file.
        [Parameter()]
        [switch]
        $SkipRunningPowerShellCheck
    )

    if (!$SkipRunningPowerShellCheck -and ((Get-PSHostProcessInfo | Where-Object ProcessId -NE $pid).Count -gt 0)) {
        throw 'This command can only be run when other PowerShell hosts are not running. Other hosts may have PSReadline loaded.'
    }

    if (!$HistoryPath) {
        if (Get-Module PSReadline -ErrorAction SilentlyContinue) {
            $HistoryPath = (Get-PSReadlineOption).HistorySavePath
        }
        else {
            throw 'You must provide a value for the HistoryPath parameter.'
        }

        Remove-Module PSReadline
        if (Get-Module PSReadline -ErrorAction SilentlyContinue) {
            throw 'Failed to remove the PSReadline module. This command can only be run when PSReadline is not loaded.'
        }
    }

    if (![System.IO.Path]::IsPathRooted($HistoryPath)) {
        $HistoryPath = Convert-Path $HistoryPath
    }

    $history = Get-Content -LiteralPath $HistoryPath -Encoding UTF8
    $origFileSize = (Get-Item -LiteralPath $HistoryPath).Length

    $strBld = New-Object System.Text.StringBuilder
    $commands = New-Object System.Collections.Generic.List[string] -ArgumentList $history.Length
    $uniqCommands = New-Object System.Collections.Generic.List[string] -ArgumentList $history.Length

    $comparer = if ($IsLinux) { [System.StringComparer]::Ordinal } else { [System.StringComparer]::OrdinalIgnoreCase }
    $uniqCommandSet = New-Object System.Collections.Generic.HashSet[string] -ArgumentList $comparer

    $numCommands = 0
    $numMinLengthCommandsRemoved = 0
    $numMultilineCommands = 0

    $whatIfMsg = if ($PSBoundParameters['WhatIf']) { 'WHAT IF: ' } else { '' }
    $activityMsg = "${whatIfMsg}Optimizing $HistoryPath"

    # Process multiline commands in the history file contents
    $Ten
    for ($i = 0; $i -lt $history.Count; $i++) {
        $percentComplete = [int](33 * (($i + 1) / $history.Count))
        if ($percentComplete % 10 -eq 0) {
            Write-Progress -Activity $activityMsg -Status 'Processing multiline commands' -PercentComplete $percentComplete
        }

        $line = $history[$i].TrimEnd()

        if ($line[-1] -eq '`') {
            $null = $strBld.Append($line + [System.Environment]::NewLine)
        }
        else {
            $numCommands++

            if ($strBld.Length -gt 0) {
                $null = $strBld.Append($line)
                $commandStr = $strBld.ToString()
                $null = $strBld.Clear()
                $numMultilineCommands++
            }
            else {
                $commandStr = $line
            }

            # Trim leading whitesapce if requested
            if ($TrimLeadingWhitespace) {
                $commandStr = $commandStr.TrimStart()
            }

            # This is where we filter out commands that are less than the specified minimum length
            if ($commandStr.Length -ge $MinimumCommandLength) {
                $null = $commands.Add($commandStr)
            }
            else {
                $numMinLengthCommandsRemoved++
            }
        }
    }

    # Walk the history file backwards so we preserve the most recent duplicate command
    for ($i = $commands.Count - 1; $i -ge 0 ; $i--) {
        $percentComplete = [int](33 + (33 * ($history.Count - 1 - $i) / $history.Count))
        if ($percentComplete % 10 -eq 0) {
            Write-Progress -Activity $activityMsg -Status 'Removing duplicate commands' -PercentComplete $percentComplete
        }

        # This is where we check for a duplicate command
        $commandStr = $commands[$i]
        if (!$uniqCommandSet.Contains($commandStr)) {
            $null = $uniqCommandSet.Add($commandStr)
            $null = $uniqCommands.Add($commandStr)
        }
    }

    $uniqCommandSet = $null
    $numUniqCommands = $uniqCommands.Count

    if ($PSCmdlet.ShouldProcess($HistoryPath, 'Optimize')) {
        Copy-Item -LiteralPath $HistoryPath "${HistoryPath}.bak"
        Remove-Item -LiteralPath $HistoryPath

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)
        $writer = [System.IO.StreamWriter]::new($HistoryPath, $false, $utf8NoBom)
        try {
            for ($i = $uniqCommands.Count - 1; $i -ge 0 ; $i--) {
                $percentComplete = [int](66 + (34 * ($uniqCommands.Count - 1 - $i) / $uniqCommands.Count))
                if ($percentComplete % 25 -eq 0) {
                    Write-Progress -Activity $activityMsg -Status 'Saving optimized history' -PercentComplete $percentComplete
                }

                $line = $uniqCommands[$i]
                $writer.WriteLine($line)
            }
        }
        finally {
            if ($writer) { $writer.Dispose() }
        }

        $newFileSize = (Get-Item -LiteralPath $HistoryPath).Length
    }
    else {
        # Estimate the resulting file size for -WhatIf
        $newFileSize = 0
        foreach ($command in $uniqCommands) {
            $newFileSize += $command.Length + [System.Environment]::NewLine.Length
        }
    }

    $strBld = $commands = $uniqCommands = $null

    Write-Host "Removed $($numCommands - $numUniqCommands) duplicate commands."
    if ($MinimumCommandLength -gt 0) {
        Write-Host "Removed $numMinLengthCommandsRemoved commands with less than $MinimumCommandLength characters."
    }
    Write-Host "Number of commands reduced from $numCommands to $numUniqCommands."
    Write-Host "Number of multiline commands $numMultilineCommands."
    Write-Host ('History file size reduced from {0:F1} KB to {1:F1} KB.' -f ($origFileSize / 1KB), ($newFileSize / 1KB))

    Write-Progress -Activity $activityMsg -Completed
}
