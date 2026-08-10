[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Interactive setup script; progress is meant for the host.')]
param()

# Each module is a hashtable with a Name and optional AllowPrerelease / RequiredVersion.
$modules = @(
    @{ Name = 'git-completion' },
    @{ Name = 'Pester' },
    @{ Name = 'posh-git' },
    @{ Name = 'PSBashCompletions' },
    @{ Name = 'Terminal-Icons' },

    # Pinned - the PowerShell extension 2025.x for VS Code doesn't work with 1.25.0.
    @{ Name = 'PSScriptAnalyzer'; RequiredVersion = '1.24.0' }
)

Write-Host 'Installing modules - watch for warnings, you may need to install a module and include -Force to get side-by-side support.'
$modules | ForEach-Object {
    $installParams = @{
        Name         = $_.Name
        Scope        = 'CurrentUser'
        AllowClobber = $true
        Force        = $true
    }

    if ($_.AllowPrerelease) {
        $installParams.AllowPrerelease = $true
    }

    if ($_.RequiredVersion) {
        $installParams.RequiredVersion = $_.RequiredVersion
    }

    Install-Module @installParams
}
