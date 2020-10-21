#requires -Version 2 -Modules posh-git

# Fork from Paradox theme.
# When writing the segment separator prefix, foreground color is the current
# background color; background color is the background of the NEXT segment.
function Write-Theme {
    param(
        [bool]
        $lastCommandFailed,
        [string]
        $with
    )

    ### Parallel scripts to get data from external files and programs
    ### Consistently shaves off about 40 - 100ms from the rendering of the prompt.
    $dotnetScript = {
        # Get the current dotnet version.
        $dotnetVersion = $null
        if ($null -ne (Get-Command "dotnet" -ErrorAction Ignore)) {
            $dotnetVersion = (& dotnet --version 2> $null)
            if ($LASTEXITCODE -eq 145) {
                $dotnetVersion = "[unsupported global.json]"
            }
        }
        return $dotnetVersion
    }

    $kubectlScript = {
        # Get the current kubectl context.
        $currentContext = $null
        if ($null -ne (Get-Command "kubectl" -ErrorAction Ignore)) {
            $currentContext = (& kubectl config current-context 2> $null)
            if($null -eq $currentContext) {
                $currentContext = "[none]"
            }
        }
        return $currentContext
    }

    $azureScript = {
        # Get the current public cloud Azure CLI subscription.
        # NOTE: You will need sed from somewhere (for example, from Git for Windows).
        # Using manual parsing instead of
        # az account show --query "name"
        # because the az CLI is really slow.
        $currentAccount = $null
        $cloudConfigPath = Resolve-Path "~/.azure/clouds.config"
        if ((Test-Path $cloudConfigPath) -and ($null -ne (Get-Command "sed" -ErrorAction Ignore))) {
            $currentSub = & sed -nr "/^\[AzureCloud\]/ { :l /^subscription[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "$($cloudConfigPath.Path)"
            if ($null -ne $currentSub) {
                $currentAccount = (Get-Content ~/.azure/azureProfile.json | ConvertFrom-Json).subscriptions | Where-Object { $_.id -eq $currentSub } | Select-Object -ExpandProperty Name
            }
            if ($null -eq $currentAccount) {
                $currentAccount = "[none]"
            }
        }
        return $currentAccount
    }

    # Create the set of jobs to run, each in a runspace. Not using RunspacePool
    # because there aren't a lot of jobs and it's really hard to set the current
    # working directory in a pool.
    $scripts = @{ "azure" = $azureScript; "dotnet" = $dotnetScript; "kubectl" = $kubectlScript }
    $jobs = @()

    foreach ($key in $scripts.Keys) {
        $thread = [powershell]::Create().AddScript($scripts[$key])
        $runspace = [RunspaceFactory]::CreateRunspace()
        $runspace.Open()
        $runspace.SessionStateProxy.Path.SetLocation($pwd.Path) | Out-Null
        $thread.Runspace = $runspace
        $handle = $thread.BeginInvoke()
        $jobs += @{ "Handle" = $handle; "Thread" = $thread; "Name" = $key }
    }

    $prompt = Write-Prompt -Object $sl.PromptSymbols.StartSymbol -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.SessionInfoBackgroundColor

    # Write err for any PowerShell errors.
    If ($lastCommandFailed) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.FailedCommandSymbol) " -ForegroundColor $sl.Colors.CommandFailedIconForegroundColor -BackgroundColor $sl.Colors.SessionInfoBackgroundColor
    }

    # Write non-zero exit code from last launched process.
    If ($LASTEXITCODE -ne "") {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.FailedCommandSymbol) [EXIT $LASTEXITCODE]" -ForegroundColor $sl.Colors.CommandFailedIconForegroundColor -BackgroundColor $sl.Colors.SessionInfoBackgroundColor
    }

    #check for elevated prompt
    If (Test-Administrator) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.ElevatedSymbol) " -ForegroundColor $sl.Colors.AdminIconForegroundColor -BackgroundColor $sl.Colors.SessionInfoBackgroundColor
    }

    $user = [System.Environment]::UserName
    $computer = [System.Environment]::MachineName
    $path = Get-FullPath -dir $pwd
    if (Test-NotDefaultUser($user)) {
        $prompt += Write-Prompt -Object "$user@$computer " -ForegroundColor $sl.Colors.SessionInfoForegroundColor -BackgroundColor $sl.Colors.SessionInfoBackgroundColor
    }

    if (Test-VirtualEnv) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $sl.Colors.SessionInfoBackgroundColor -BackgroundColor $sl.Colors.VirtualEnvBackgroundColor
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.VirtualEnvSymbol) $(Get-VirtualEnvName) " -ForegroundColor $sl.Colors.VirtualEnvForegroundColor -BackgroundColor $sl.Colors.VirtualEnvBackgroundColor
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $sl.Colors.VirtualEnvBackgroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor
    }
    else {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $sl.Colors.SessionInfoBackgroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor
    }

    # Writes the drive portion
    $prompt += Write-Prompt -Object "$path" -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor
    $lastColor = $sl.Colors.PromptBackgroundColor

    # Stack count needs to be retrieved from outside the theme module.
    # https://github.com/JanDeDobbeleer/oh-my-posh/issues/113
    $pushstack = &$GetLocationStackCount
    if ($pushstack -gt 0) {
        # Write one + for each level of the pushd stack.
        $prompt += Write-Prompt -Object " " -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor
        $prompt += Write-Prompt -Object (("+" * $pushstack)) -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor
    }

    $prompt += Write-Prompt -Object " " -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor

    # Write any custom prompt environment.
    # $global:PromptEnvironment = " ⌂ vs2017 "
    # DarkMagenta is, by default, "transparent" to Windows, so use DarkGray.
    # https://social.technet.microsoft.com/Forums/en-US/92493f5b-883f-46fd-9714-23603053c143/powershell-text-background-color-quotdarkmagentaquot-does-it-have-a-special-meaning-to-it?forum=winserverpowershell
    if (get-content variable:\PromptEnvironment -ErrorAction Ignore) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol)" -ForegroundColor $lastColor -BackgroundColor $sl.Colors.PromptEnvBackgroundColor
        $lastColor = $sl.Colors.PromptEnvBackgroundColor
        $prompt += Write-Prompt -Object "$PromptEnvironment" -ForegroundColor  $sl.Colors.PromptEnvForegroundColor -BackgroundColor $sl.Colors.PromptEnvBackgroundColor
    }

    while (@($jobs | Where-Object { $_.Handle.IsCompleted -ne $True }).count -gt 0) {
        Start-Sleep -Milliseconds 1
    }

    $scriptReturnValues = @{ }
    foreach ($job in $jobs) {
        $scriptReturnValues.Add($job.Name, $job.Thread.EndInvoke($job.Handle))
        $job.Thread.Runspace.Close()
        $job.Thread.Dispose()
    }

    if (-not [String]::IsNullOrEmpty($scriptReturnValues["dotnet"])) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $lastColor -BackgroundColor $sl.Colors.DotNetBackgroundColor
        $lastColor = $sl.Colors.DotNetBackgroundColor
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.DotNetSymbol)" -ForegroundColor $sl.Colors.DotNetSymbolColor -BackgroundColor $sl.Colors.DotNetBackgroundColor
        $prompt += Write-Prompt -Object " $($scriptReturnValues['dotnet'])" -ForegroundColor $sl.Colors.DotNetForegroundColor -BackgroundColor $sl.Colors.DotNetBackgroundColor
    }

    if (-not [String]::IsNullOrEmpty($scriptReturnValues["kubectl"])) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $lastColor -BackgroundColor $sl.Colors.KubectlBackgroundColor
        $lastColor = $sl.Colors.KubectlBackgroundColor
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.KubectlSymbol) " -ForegroundColor $sl.Colors.KubectlSymbolColor -BackgroundColor $sl.Colors.KubectlBackgroundColor
        $prompt += Write-Prompt -Object " $($scriptReturnValues['kubectl'])" -ForegroundColor $sl.Colors.KubectlForegroundColor -BackgroundColor $sl.Colors.KubectlBackgroundColor
    }

    if (-not [String]::IsNullOrEmpty($scriptReturnValues["azure"])) {
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $lastColor -BackgroundColor $sl.Colors.AzureBackgroundColor
        $lastColor = $sl.Colors.AzureBackgroundColor
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.AzureSymbol)" -ForegroundColor $sl.Colors.AzureSymbolColor -BackgroundColor $sl.Colors.AzureBackgroundColor
        $prompt += Write-Prompt -Object " $($scriptReturnValues['azure'])" -ForegroundColor $sl.Colors.AzureForegroundColor -BackgroundColor $sl.Colors.AzureBackgroundColor
    }

    $status = Get-VCSStatus
    if ($status) {
        $themeInfo = Get-VcsInfo -status ($status)
        $prompt += Write-Prompt -Object "$($sl.PromptSymbols.SegmentForwardSymbol) " -ForegroundColor $lastColor -BackgroundColor $themeInfo.BackgroundColor
        $lastColor = $themeInfo.BackgroundColor
        $prompt += Write-Prompt -Object " $($themeInfo.VcInfo) " -BackgroundColor $lastColor -ForegroundColor $sl.Colors.GitForegroundColor
    }

    # Writes the postfix to the prompt
    $prompt += Write-Prompt -Object $sl.PromptSymbols.SegmentForwardSymbol -ForegroundColor $lastColor

    # Fix the issue where a line wrap at the end of the prompt causes the next
    # line to be colored in.
    $cleanPrompt = $prompt -replace '(\x9B|\x1B\[)[0-?]*[ -\/]*[@-~]',''
    $toClear = $host.UI.RawUI.BufferSize.Width - ($cleanPrompt.Length % $host.UI.RawUI.BufferSize.Width)
    if ($toClear -ne $host.UI.RawUI.BufferSize.Width) {
        $prompt += Write-Prompt -Object (" " * $toClear) -ForegroundColor $host.UI.RawUI.ForegroundColor -BackgroundColor $host.UI.RawUI.BackgroundColor
    }

    $timeStamp = Get-Date -UFormat %R
    $timestamp = "[$timeStamp]"
    $prompt += Set-CursorForRightBlockWrite -textLength ($timestamp.Length + 1)
    $prompt += Write-Prompt $timeStamp -ForegroundColor $sl.Colors.PromptForegroundColor

    $prompt += Set-Newline

    if ($with) {
        $prompt += Write-Prompt -Object "$($with.ToUpper()) " -BackgroundColor $sl.Colors.WithBackgroundColor -ForegroundColor $sl.Colors.WithForegroundColor
    }

    # Write PS> for desktop PowerShell, pwsh> for PowerShell Core.
    If ($PSVersionTable.PSEdition -eq "Desktop") {
        $shellName = "PS"
    }
    Else {
        $shellName = "pwsh"
    }

    If (Test-Administrator) {
        $prompt += Write-Prompt -Object "$shellName$($sl.PromptSymbols.PromptIndicator)" -ForegroundColor $sl.Colors.AdminPromptSymbolColor
    }
    Else {
        $prompt += Write-Prompt -Object "$shellName$($sl.PromptSymbols.PromptIndicator)" -ForegroundColor $sl.Colors.PromptSymbolColor
    }

    $prompt += ' '

    # Clear LASTEXITCODE/Error so the prompt doesn't keep showing it... but this also
    # may interfere with scripting later, so don't forget it's here.
    $global:LASTEXITCODE = 0
    $global:Error.Clear()

    $prompt
}

$sl = $global:ThemeSettings # local settings
$sl.PromptSymbols.StartSymbol = ''
$sl.PromptSymbols.ElevatedSymbol = [char]::ConvertFromUtf32(0x2620) # Skull and crossbones
$sl.PromptSymbols.PromptIndicator = '>' # Was [char]::ConvertFromUtf32(0xE0B1) Hollow angle arrow right
$sl.PromptSymbols.SegmentForwardSymbol = [char]::ConvertFromUtf32(0xE0B0) # Solid angle arrow right
$sl.PromptSymbols.FailedCommandSymbol = [char]::ConvertFromUtf32(0x2327) # X in a rectangle box
$sl.Colors.AdminIconForegroundColor = [ConsoleColor]::Red
$sl.Colors.SessionInfoBackgroundColor = (Get-Host).Ui.RawUI.BackgroundColor
$sl.Colors.PromptForegroundColor = [ConsoleColor]::White
$sl.Colors.PromptSymbolColor = [ConsoleColor]::Green
$sl.Colors.PromptHighlightColor = [ConsoleColor]::DarkBlue
$sl.Colors.GitForegroundColor = [ConsoleColor]::Black
$sl.Colors.WithForegroundColor = [ConsoleColor]::DarkRed
$sl.Colors.WithBackgroundColor = [ConsoleColor]::Magenta
$sl.Colors.VirtualEnvBackgroundColor = [ConsoleColor]::Red
$sl.Colors.VirtualEnvForegroundColor = [ConsoleColor]::White

# Custom symbols
$sl.PromptSymbols.KubectlSymbol = [char]::ConvertFromUtf32(0x2388) # ⎈ Helm symbol
$sl.PromptSymbols.AzureSymbol = [char]::ConvertFromUtf32(0xFD03) # ﴃ Azure logo
$sl.PromptSymbols.DotNetSymbol = [char]::ConvertFromUtf32(0xE77F) #  .NET logo

# Custom colors
$sl.Colors.AdminPromptSymbolColor = [ConsoleColor]::Red
$sl.Colors.PromptEnvForegroundColor = [ConsoleColor]::White
$sl.Colors.PromptEnvBackgroundColor = [ConsoleColor]::DarkGray
$sl.Colors.DotNetSymbolColor = [ConsoleColor]::DarkBlue
$sl.Colors.DotNetForegroundColor = [ConsoleColor]::DarkBlue
$sl.Colors.DotNetBackgroundColor = [ConsoleColor]::Cyan
$sl.Colors.KubectlSymbolColor = [ConsoleColor]::Black
$sl.Colors.KubectlForegroundColor = [ConsoleColor]::Black
$sl.Colors.KubectlBackgroundColor = [ConsoleColor]::DarkYellow
$sl.Colors.AzureSymbolColor = [ConsoleColor]::Black
$sl.Colors.AzureForegroundColor = [ConsoleColor]::White
$sl.Colors.AzureBackgroundColor = [ConsoleColor]::DarkCyan

###
# Custom prompt adapted from Brad Wilson
# http://bradwilson.io/blog/prompt/powershell
# Using char conversions to avoid UTF-8/BOM issues
# Git prompt shape
$gp = $global:GitPromptSettings
$gp.AfterStatus.Text = " "
$gp.BeforeStatus.Text = " $([char]::ConvertFromUtf32(0xE0A0)) " # "  "
$gp.BranchAheadStatusSymbol.Text = [char]::ConvertFromUtf32(0x2191) # "↑"
$gp.BranchBehindStatusSymbol.Text = [char]::ConvertFromUtf32(0x2193) # "↓"
$gp.BranchBehindAndAheadStatusSymbol.Text = [char]::ConvertFromUtf32(0x2195) # "↕"
$gp.BranchIdenticalStatusSymbol.Text = ""
$gp.BranchGoneStatusSymbol.Text = [char]::ConvertFromUtf32(0x2425) # "␥"
$gp.BranchUntrackedText = "$([char]::ConvertFromUtf32(0x25C7)) " # "◇ "
$gp.DelimStatus.Text = " $([char]::ConvertFromUtf32(0x2551))" # " ║"
$gp.LocalStagedStatusSymbol.Text = ""
$gp.LocalWorkingStatusSymbol.Text = ""

# Status
$gp.EnableStashStatus = $false
$gp.ShowStatusWhenZero = $false
