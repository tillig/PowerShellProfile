& $PSScriptRoot/ProfileCommon.ps1

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
$global:GitPromptSettings.AfterStatus.Text = " "
$global:GitPromptSettings.BeforeStatus.Text = "  "
$global:GitPromptSettings.BranchIdenticalStatusSymbol.Text = ""
$global:GitPromptSettings.BranchUntrackedText = "◇ "
$global:GitPromptSettings.DelimStatus.Text = " ║"
$global:GitPromptSettings.LocalStagedStatusSymbol.Text = ""
$global:GitPromptSettings.LocalWorkingStatusSymbol.Text = ""

# Status
$global:GitPromptSettings.EnableStashStatus = $false
$global:GitPromptSettings.ShowStatusWhenZero = $false

Set-Content Function:prompt {
  # Start with a blank line, for breathing room :)
  Write-Host ""

  # Reset the foreground color to default.
  $Host.UI.RawUI.ForegroundColor = $global:GitPromptSettings.DefaultColor.ForegroundColor

  # Write ERR for any PowerShell errors.
  if ($Error.Count -ne 0) {
    Write-Host " " -NoNewLine
    Write-Host " ⌧ ERR " -NoNewLine -BackgroundColor DarkRed -ForegroundColor Yellow
  }

  # Write non-zero exit code from last launched process.
  if ($LASTEXITCODE -ne "") {
    Write-Host " " -NoNewLine
    Write-Host " ⌧ EXIT $LASTEXITCODE " -NoNewLine -BackgroundColor DarkRed -ForegroundColor Yellow
  }

  # Write any custom prompt environment.
  # $global:PromptEnvironment = " ⌂ vs2017 "
  # DarkMagenta is, by default, "transparent" to Windows, so use DarkGray.
  # https://social.technet.microsoft.com/Forums/en-US/92493f5b-883f-46fd-9714-23603053c143/powershell-text-background-color-quotdarkmagentaquot-does-it-have-a-special-meaning-to-it?forum=winserverpowershell
  if (get-content variable:\PromptEnvironment -ErrorAction Ignore) {
    Write-Host " " -NoNewLine
    Write-Host $PromptEnvironment -NoNewLine -BackgroundColor DarkGray -ForegroundColor White
  }

  ### Parallel scripts to get data from external files and programs
  ### Consistently shaves off about 40 - 100ms from the rendering of the prompt.
  $dotnetScript = {
    # Get the current dotnet version.
    $dotnetVersion = $null
    if ((Get-Command "dotnet" -ErrorAction Ignore) -ne $null) {
      $dotnetVersion = (& dotnet --version 2> $null)
    }
    return $dotnetVersion
  }

  $kubectlScript = {
    # Get the current kubectl context.
    $currentContext = $null
    if ((Get-Command "kubectl" -ErrorAction Ignore) -ne $null) {
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
    $cloudConfigPath = Resolve-Path "~/.azure/clouds.config"
    if ((Test-Path $cloudConfigPath) -and ((Get-Command "sed" -ErrorAction Ignore) -ne $null)) {
      $currentSub = & sed -nr "/^\[AzureCloud\]/ { :l /^subscription[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "$($cloudConfigPath.Path)"
      if ($null -ne $currentSub) {
        $currentAccount = (Get-Content ~/.azure/azureProfile.json | ConvertFrom-Json).subscriptions | Where-Object { $_.id -eq $currentSub } | Select-Object -ExpandProperty Name
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

  while (@($jobs | Where-Object {$_.Handle.IsCompleted -ne $True}).count -gt 0) {
      Start-Sleep -Milliseconds 1
  }

  $scriptReturnValues = @{}
  foreach ($job in $jobs) {
    $scriptReturnValues.Add($job.Name, $job.Thread.EndInvoke($job.Handle))
    $job.Thread.Runspace.Close()
    $job.Thread.Dispose()
  }

  if ($scriptReturnValues["dotnet"] -ne $null) {
    Write-Host " " -NoNewLine
    Write-Host " ◉" -NoNewLine -BackgroundColor Gray -ForegroundColor Blue
    Write-Host " $($scriptReturnValues['dotnet']) " -NoNewLine -BackgroundColor Gray -ForegroundColor Black
  }

  if ($scriptReturnValues["kubectl"] -ne $null) {
    Write-Host " " -NoNewLine
    Write-Host " ▣" -NoNewLine -BackgroundColor DarkCyan -ForegroundColor Green
    Write-Host " $($scriptReturnValues['kubectl']) " -NoNewLine -BackgroundColor DarkCyan -ForegroundColor White
  }

  if ($scriptReturnValues["azure"] -ne $null) {
    Write-Host " " -NoNewLine
    Write-Host " ☼" -NoNewLine -BackgroundColor DarkCyan -ForegroundColor Green
    Write-Host " $($scriptReturnValues['azure']) " -NoNewLine -BackgroundColor DarkCyan -ForegroundColor White
  }

  # Write the current Git information.
  if ((Get-Command "Get-GitDirectory" -ErrorAction Ignore) -ne $null) {
    if (Get-GitDirectory -ne $null) {
      Write-Host (Write-VcsStatus) -NoNewLine
    }
  }

  # Write the current directory, with home folder normalized to ~.
  $currentPath = $global:GitPromptSettings.DefaultPromptPath.Expand().Text
  Write-Host " " -NoNewLine
  Write-Host " ⇪" -NoNewLine -BackgroundColor DarkGreen -ForegroundColor Yellow
  Write-Host " $currentPath " -NoNewLine -BackgroundColor DarkGreen -ForegroundColor White

  # Write one + for each level of the pushd stack.
  if ((get-location -stack).Count -gt 0) {
    Write-Host " " -NoNewLine
    Write-Host (("+" * ((get-location -stack).Count))) -NoNewLine -ForegroundColor Cyan
  }

  # Newline with a no-break space (U+00A0) - the nbsp stops a host bug where resizing
  # the window causes the last item on the status line to stretch all the way to
  # the edge. Regular space won't fix it.
  Write-Host " "

  # Determine if the user is admin, so we color the prompt green or red.
  $isAdmin = $false
  $isDesktop = ($PSVersionTable.PSEdition -eq "Desktop")

  if ($isDesktop -or $IsWindows) {
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = new-object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity
    $isAdmin = $windowsPrincipal.IsInRole("Administrators") -eq 1
  } else {
    $isAdmin = ((& id -u) -eq 0)
  }

  if ($isAdmin) { $color = "Red"; }
  else { $color = "Green"; }

  # Write PS> for desktop PowerShell, pwsh> for PowerShell Core.
  if ($isDesktop) {
    Write-Host " PS>" -NoNewLine -ForegroundColor $color
  }
  else {
    Write-Host " pwsh>" -NoNewLine -ForegroundColor $color
  }

  # Clear LASTEXITCODE/Error so the prompt doesn't keep showing it... but this also
  # may interfere with scripting later, so don't forget it's here.
  $global:LASTEXITCODE = 0
  $global:Error.Clear()

  # Always have to return something or else we get the default prompt.
  return " "
}