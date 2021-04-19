Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
$releaseModules = @(
    "PSBashCompletions",
    "VSSetup",
    "ClipboardText",
    "oh-my-posh",
    "PSScriptAnalyzer",
    "Pester",
    "Terminal-Icons"
)

$preReleaseModules = @(
)

Write-Host "Installing release modules - watch for warnings, you may need to install a module and include -Force to get side-by-side support."
$releaseModules | ForEach-Object {
    Install-Module $_ -Scope CurrentUser -AllowClobber -Force
}

Write-Host "Installing prerelease modules - watch for warnings, you may need to install a module and include -Force to get side-by-side support."
$preReleaseModules | ForEach-Object {
    Install-Module $_ -Scope CurrentUser -AllowClobber -AllowPrerelease -Force
}
