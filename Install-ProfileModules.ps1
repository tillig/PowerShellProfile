$releaseModules = @(
    # Common for all OSes.
    "PSBashCompletions",
    "PSScriptAnalyzer",
    "Pester",
    "Terminal-Icons",

    # Used for script-based prompt when oh-my-posh is not available.
    "posh-git",

    # Used only on Windows.
    "VSSetup"
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
