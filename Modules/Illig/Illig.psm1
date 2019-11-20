. $PSScriptRoot\Development\New-MachineKey.ps1
. $PSScriptRoot\Development\Remove-TempFiles.ps1
. $PSScriptRoot\Development\Reset-Source.ps1
. $PSScriptRoot\Development\Set-DotEnv.ps1
. $PSScriptRoot\Development\VisualStudio.ps1
. $PSScriptRoot\Kubernetes\Get-KubectlAll.ps1
. $PSScriptRoot\Kubernetes\Get-KubectlShell.ps1
. $PSScriptRoot\Terminal\Set-ConsoleEncoding.ps1
. $PSScriptRoot\Terminal\Test-AnsiSupport.ps1

$exportModuleMemberParams = @{
    Function = @(
        'Get-KubectlAll',
        'Get-KubectlShell',
        'Invoke-VisualStudioDevPrompt',
        'New-MachineKey',
        'Remove-TempFiles',
        'Reset-Source',
        'Select-VsInstall',
        'Set-ConsoleEncoding',
        'Set-DotEnv',
        'Test-AnsiSupport'
    )
}

Export-ModuleMember @exportModuleMemberParams
