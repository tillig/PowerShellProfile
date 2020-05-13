<#
.Synopsis
   Alias replacement for 'dir' that includes hidden files.
.DESCRIPTION
   The standard 'dir' alias is just Get-ChildItem. This doesn't include
   dot-files when on a Linux/Mac machine. This replacement alias allows 'dir' to
   get everything without having to constantly pass the -Force parameter.
#>
function AliasFunctionDir {
    [Alias("dir")]
    Param()
    Process {
        Get-ChildItem -Force @args
    }
}
