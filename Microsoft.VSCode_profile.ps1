# VSCode profile needs to skip multi-threaded startup because the
# session startup hangs on the parallel prompt startup.
& $PSScriptRoot/ProfileCommon.ps1

Set-Content Function:prompt {
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
    Write-Host "PS $pwd>" -NoNewLine -ForegroundColor $color
  }
  else {
    Write-Host "pwsh $pwd>" -NoNewLine -ForegroundColor $color
  }

  # Always have to return something or else we get the default prompt.
  return " "
}