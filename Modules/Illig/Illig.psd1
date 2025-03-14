@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'Illig.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = '845467c3-17ac-4936-a6d3-45a1c39b8ff8'

    # Author of this module
    Author            = 'Travis Illig'

    # Description of the functionality provided by this module
    Description       = 'Random commands for my PowerShell profile.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module
    FunctionsToExport = @(
        'AliasFunctionDir',
        'Copy-ContainerImage',
        'Enable-Ruby',
        'Enable-ScriptBasedPrompt',
        'Export-PostmanItem',
        'Get-AzureDevOpsBuild',
        'Get-GitBranchReport',
        'Get-KubectlAll',
        'Get-KubectlShell',
        'Get-Ruby',
        'Import-PostmanItem',
        'Invoke-VisualStudioDevPrompt',
        'Invoke-WindowsBatchFile',
        'New-MachineKey',
        'Open-GitRemote',
        'Optimize-PSReadlineHistory',
        'Remove-GitLocalOnly',
        'Remove-KubectlContext',
        'Remove-TempFiles',
        'Reset-Ruby',
        'Reset-Source',
        'Select-VsInstall',
        'Set-ConsoleEncoding',
        'Set-DotEnv',
        'Sync-AzureDevOpsProject',
        'Sync-GitHubOrganization',
        'Test-Administrator',
        'Test-AnsiSupport',
        'Update-GitFork',
        'Update-GitRepository'
    )

    # Custom type formats
    FormatsToProcess  = @(
    )

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @('VSSetup')
}
