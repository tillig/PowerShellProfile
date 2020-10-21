Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
$releaseModules = (
    "PSReadline",
    "Microsoft.PowerShell.Archive",
    "PSBashCompletions",
    "VSSetup",
    "ClipboardText"
)

# Settings for posh-git require v1.0.0 minimum, in pre-release
# since 1/10/2018.
$preReleaseModules = (
    "posh-git"
)

Write-Host "Installing release modules - watch for warnings, you may need to install a module and include -Force to get side-by-side support."
$releaseModules | ForEach-Object {
    Install-Module $_ -Scope CurrentUser -AllowClobber
}

Write-Host "Installing prerelease modules - watch for warnings, you may need to install a module and include -Force to get side-by-side support."
$preReleaseModules | ForEach-Object {
    Install-Module $_ -Scope CurrentUser -AllowClobber -AllowPrerelease
}

# Force a specfic version for oh-my-posh because v3 has issues in PowerShell.
Install-Module oh-my-posh -RequiredVersion "2.0.487" -Scope CurrentUser -AllowClobber -AllowPrerelease
