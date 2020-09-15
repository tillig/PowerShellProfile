$releaseModules = (
    "PSReadline",
    "Microsoft.PowerShell.Archive",
    "oh-my-posh",
    "PSBashCompletions",
    "VSSetup",
    "ClipboardText"
)

# Settings for posh-git require v1.0.0 minimum, in pre-release
# since 1/10/2018.
$preReleaseModules = (
    "posh-git"
)

$releaseModules | ForEach-Object {
    Install-Module $_ -Scope CurrentUser -AllowClobber
}

$preReleaseModules | ForEach-Object {
    Install-Module $_ -Scope CurrentUser -AllowClobber -AllowPrerelease
}
