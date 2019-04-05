# VSCode profile needs to skip prompt color and Write-Host because the
# session startup hangs on the parallel prompt startup. Go super-simple.
# Note the standard integrated prompt will use the regular profile and
# may hang until you issue the first command and/or hit enter.
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

  if ($isAdmin) { $adminFlag = " [Admin]" }

  # Write PS> for desktop PowerShell, pwsh> for PowerShell Core.
  if ($isDesktop) {
    return "PS$adminFlag $pwd>"
  }
  else {
    return "pwsh$adminFlag $pwd>"
  }
}