. $PSScriptRoot\Development\Invoke-WindowsBatchFile.ps1
. $PSScriptRoot\Development\New-MachineKey.ps1
. $PSScriptRoot\Development\Remove-GitLocalOnly.ps1
. $PSScriptRoot\Development\Remove-TempFiles.ps1
. $PSScriptRoot\Development\Reset-Source.ps1
. $PSScriptRoot\Development\Set-DotEnv.ps1
. $PSScriptRoot\Development\VisualStudio.ps1
. $PSScriptRoot\Kubernetes\Get-KubectlAll.ps1
. $PSScriptRoot\Kubernetes\Get-KubectlShell.ps1
. $PSScriptRoot\Kubernetes\Remove-KubectlContext.ps1
. $PSScriptRoot\Terminal\AliasFunctions.ps1
. $PSScriptRoot\Terminal\Set-ConsoleEncoding.ps1
. $PSScriptRoot\Terminal\Test-AnsiSupport.ps1

$exportModuleMemberParams = @{
    Function = @(
        'AliasFunctionDir',
        'Get-KubectlAll',
        'Get-KubectlShell',
        'Invoke-VisualStudioDevPrompt',
        'Invoke-WindowsBatchFile',
        'New-MachineKey',
        'Remove-GitLocalOnly',
        'Remove-KubectlContext',
        'Remove-TempFiles',
        'Reset-Source',
        'Select-VsInstall',
        'Set-ConsoleEncoding',
        'Set-DotEnv',
        'Test-AnsiSupport'
    )
}

Export-ModuleMember @exportModuleMemberParams
