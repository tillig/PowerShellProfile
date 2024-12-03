<#
.SYNOPSIS
    Enables a custom prompt for PowerShell that is fully Powershell
    script-based.
.DESCRIPTION
    This is a backup for the times you can't use oh-my-posh or other prompt
    tools. This enables a custom prompt that is fully PowerShell and based on
    other tools in the path. It is not customizable, but it should work in a
    pinch.

    This prompt uses the "posh-git" module to get Git status information.
#>
function Enable-ScriptBasedPrompt {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param()
    Begin {
        Import-Module posh-git
    }
    Process {
        ###
        # Custom prompt adapted from Brad Wilson
        # http://bradwilson.io/blog/prompt/powershell
        # Be sure to save as UTF-8 with BOM or the glyphs won't render.

        # Background colors
        $global:GitPromptSettings.AfterStash.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.AfterStatus.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BeforeIndex.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BeforeStash.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BeforeStatus.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BranchAheadStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BranchBehindAndAheadStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BranchBehindStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BranchColor.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BranchGoneStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.BranchIdenticalStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.DefaultColor.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.DelimStatus.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.ErrorColor.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.IndexColor.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.LocalDefaultStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.LocalStagedStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.LocalWorkingStatusSymbol.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.StashColor.BackgroundColor = [ConsoleColor]::Black
        $global:GitPromptSettings.WorkingColor.BackgroundColor = [ConsoleColor]::Black

        # Foreground colors
        $global:GitPromptSettings.AfterStatus.ForegroundColor = [ConsoleColor]::Blue
        $global:GitPromptSettings.BeforeStatus.ForegroundColor = [ConsoleColor]::Yellow
        $global:GitPromptSettings.BranchColor.ForegroundColor = [ConsoleColor]::White
        $global:GitPromptSettings.BranchGoneStatusSymbol.ForegroundColor = [ConsoleColor]::Blue
        $global:GitPromptSettings.BranchIdenticalStatusSymbol.ForegroundColor = [ConsoleColor]::Blue
        $global:GitPromptSettings.DefaultColor.ForegroundColor = [ConsoleColor]::White
        $global:GitPromptSettings.DelimStatus.ForegroundColor = [ConsoleColor]::Blue
        $global:GitPromptSettings.IndexColor.ForegroundColor = [ConsoleColor]::Cyan
        $global:GitPromptSettings.WorkingColor.ForegroundColor = [ConsoleColor]::Yellow

        # Prompt shape
        $global:GitPromptSettings.AfterStatus.Text = ' '
        $global:GitPromptSettings.BeforeStatus.Text = '  '
        $global:GitPromptSettings.BranchAheadStatusSymbol.Text = '↑'
        $global:GitPromptSettings.BranchBehindStatusSymbol.Text = '↓'
        $global:GitPromptSettings.BranchBehindAndAheadStatusSymbol.Text = '↕'
        $global:GitPromptSettings.BranchIdenticalStatusSymbol.Text = ''
        $global:GitPromptSettings.BranchGoneStatusSymbol.Text = '␥'
        $global:GitPromptSettings.BranchUntrackedText = '◇ '
        $global:GitPromptSettings.DelimStatus.Text = ' ║'
        $global:GitPromptSettings.LocalStagedStatusSymbol.Text = ''
        $global:GitPromptSettings.LocalWorkingStatusSymbol.Text = ''

        # Status
        $global:GitPromptSettings.EnableStashStatus = $false
        $global:GitPromptSettings.ShowStatusWhenZero = $false

        Set-Content Function:prompt {
            # Start with a blank line, for breathing room :)
            Write-Host ''

            # Reset the foreground color to default.
            $Host.UI.RawUI.ForegroundColor = $global:GitPromptSettings.DefaultColor.ForegroundColor

            # Write ERR for any PowerShell errors.
            if ($Error.Count -ne 0) {
                Write-Host ' [⌧ ERROR]' -NoNewline -ForegroundColor DarkRed
            }

            # Write non-zero exit code from last launched process.
            if ($LASTEXITCODE -ne '') {
                Write-Host " [⌧ EXIT $LASTEXITCODE]" -NoNewline -ForegroundColor DarkRed
            }

            # Determine if the user is admin, so we color the prompt green or red.
            $isAdmin = $false
            $isDesktop = ($PSVersionTable.PSEdition -eq 'Desktop')

            if ($isDesktop -or $IsWindows) {
                $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $windowsPrincipal = New-Object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity
                $isAdmin = $windowsPrincipal.IsInRole('Administrators') -eq 1
            }
            else {
                $isAdmin = ((& id -u) -eq 0)
            }

            # Icon to indicate the user is admin.
            if ($isAdmin) {
                Write-Host ' ☠' -NoNewline -ForegroundColor DarkRed
            }

            # User and host info.
            $user = $env:USER
            if (-not $user) {
                $user = $env:USERNAME
            }
            $hostname = &hostname
            Write-Host " $user@$hostname " -NoNewline -BackgroundColor DarkGray -ForegroundColor White

            # Path with home normalized to ~.
            $currentPath = $global:GitPromptSettings.DefaultPromptPath.Expand().Text
            Write-Host " 󰉋 $currentPath " -NoNewline -BackgroundColor DarkBlue -ForegroundColor White

            # Write one + for each level of the pushd stack.
            $locationStackCount = (Get-Location -Stack).Count
            if ($locationStackCount) {
                Write-Host "  $locationStackCount " -NoNewline -BackgroundColor Blue -ForegroundColor White
            }

            # Write any custom prompt environment.
            # $global:PromptEnvironment = " ⌂ vs2017 "
            # DarkMagenta is, by default, "transparent" to Windows, so use DarkGray.
            # https://social.technet.microsoft.com/Forums/en-US/92493f5b-883f-46fd-9714-23603053c143/powershell-text-background-color-quotdarkmagentaquot-does-it-have-a-special-meaning-to-it?forum=winserverpowershell
            if (Get-Content variable:\PromptEnvironment -ErrorAction Ignore) {
                Write-Host ' ' -NoNewline
                Write-Host $PromptEnvironment -NoNewline -BackgroundColor DarkGray -ForegroundColor White
            }

            ### Parallel scripts to get data from external files and programs
            ### Consistently shaves off about 40 - 100ms from the rendering of the prompt.
            $dotnetScript = {
                # Get the current dotnet version.
                $dotnetVersion = $null
                if ($null -ne (Get-Command 'dotnet' -ErrorAction Ignore)) {
                    $dotnetVersion = (& dotnet --version 2> $null)
                }
                return $dotnetVersion
            }

            $kubectlScript = {
                # Get the current kubectl context.
                $currentContext = $null
                if ($null -ne (Get-Command 'kubectl' -ErrorAction Ignore)) {
                    $currentContext = (& kubectl config current-context 2> $null)
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
                $cloudConfigPath = Resolve-Path '~/.azure/clouds.config'
                if ((Test-Path $cloudConfigPath) -and ($null -ne (Get-Command 'sed' -ErrorAction Ignore))) {
                    $currentSub = & sed -nr '/^subscription[ ]*=/ { s/.*=[ ]*//; p; q;}' "$($cloudConfigPath.Path)"
                    if ($null -ne $currentSub) {
                        $currentAccount = (Get-Content ~/.azure/azureProfile.json | ConvertFrom-Json).subscriptions | Where-Object { $_.id -eq $currentSub } | Select-Object -ExpandProperty Name
                    }
                }
                return $currentAccount
            }

            # Create the set of jobs to run, each in a runspace. Not using RunspacePool
            # because there aren't a lot of jobs and it's really hard to set the current
            # working directory in a pool.
            $scripts = @{ 'azure' = $azureScript; 'dotnet' = $dotnetScript; 'kubectl' = $kubectlScript }
            $jobs = @()

            foreach ($key in $scripts.Keys) {
                $thread = [powershell]::Create().AddScript($scripts[$key])
                $runspace = [RunspaceFactory]::CreateRunspace()
                $runspace.Open()
                $runspace.SessionStateProxy.Path.SetLocation($pwd.Path) | Out-Null
                $thread.Runspace = $runspace
                $handle = $thread.BeginInvoke()
                $jobs += @{ 'Handle' = $handle; 'Thread' = $thread; 'Name' = $key }
            }

            while (@($jobs | Where-Object { $_.Handle.IsCompleted -ne $True }).count -gt 0) {
                Start-Sleep -Milliseconds 1
            }

            $scriptReturnValues = @{}
            foreach ($job in $jobs) {
                $scriptReturnValues.Add($job.Name, $job.Thread.EndInvoke($job.Handle))
                $job.Thread.Runspace.Close()
                $job.Thread.Dispose()
            }

            if ($null -ne $scriptReturnValues['dotnet']) {
                Write-Host "   $($scriptReturnValues['dotnet']) " -NoNewline -BackgroundColor Cyan -ForegroundColor Black
            }

            if ($null -ne $scriptReturnValues['kubectl']) {
                # Slim down GUIDs in the context.
                $kubeContext = $($scriptReturnValues['kubectl']) -Replace '([-f0-9]{2})[a-f0-9]{6}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{10}([a-f0-9]{2})', "`$1..`$2"
                Write-Host " ⎈ $kubeContext " -NoNewline -BackgroundColor DarkYellow -ForegroundColor Black
            }

            if ($null -ne $scriptReturnValues['azure']) {
                Write-Host " 󰠅 $($scriptReturnValues['azure']) " -NoNewline -BackgroundColor DarkCyan -ForegroundColor Black
            }

            # Write the current Git information.
            if ($null -ne (Get-Command 'Get-GitDirectory' -ErrorAction Ignore)) {
                if (Get-GitDirectory -ne $null) {
                    Write-Host (Write-VcsStatus) -NoNewline
                }
            }

            # Clear the line after the prompt to avoid the background being printed on the next line when at the end of the buffer.
            # See https://github.com/JanDeDobbeleer/oh-my-posh/issues/65
            Write-Host "`e[K`e[0J"

            if ($isAdmin) { $color = 'Red'; }
            else { $color = 'Green'; }

            # Write PS> for desktop PowerShell, pwsh> for PowerShell Core.
            if ($isDesktop) {
                Write-Host ' PS>' -NoNewline -ForegroundColor $color
            }
            else {
                Write-Host ' pwsh>' -NoNewline -ForegroundColor $color
            }

            # Clear LASTEXITCODE/Error so the prompt doesn't keep showing it... but this also
            # may interfere with scripting later, so don't forget it's here.
            $global:LASTEXITCODE = 0
            $global:Error.Clear()

            # Always have to return something or else we get the default prompt.
            return ' '
        }
    }
}
