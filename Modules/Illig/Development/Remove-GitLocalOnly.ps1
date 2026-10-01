<#
.SYNOPSIS
    Removes Git branches that are only local and have no upstream.
.DESCRIPTION
    Retrieves the list of Git branches for a given location and looks for the
    ones that don't have a corresponding upstream. Removes the branches with no
    upstream.

    Git won't delete a branch that's checked out. If the branch to remove is the
    one currently checked out, this switches to the default branch (from
    'origin/HEAD', falling back to 'main,' 'master,' or 'develop') before
    removing it. If the branch is checked out in a linked worktree, that
    worktree is removed first. Branches that can't be freed up - checked out in
    the main worktree, or blocked by uncommitted changes or a locked worktree -
    are skipped with a warning so the remaining branches and repositories still
    get processed.
.PARAMETER Path
    The location with branches to remove.
.EXAMPLE
   Remove-GitLocalOnly
.EXAMPLE
   Get-ChildItem -Directory | Remove-GitLocalOnly
#>
function Remove-GitLocalOnly {
    [CmdletBinding(SupportsShouldProcess = $True,
        ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $False,
            Position = 0,
            ValueFromPipeline = $True)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD
    )
    begin {
        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error 'Unable to locate git.'
            exit 1
        }
    }
    process {
        if (-not (Test-Path $Path)) {
            throw "Unable to find path $Path"
        }
        try {
            Push-Location $Path
            $ToParse = '['
            $ToParse += (&git branch --format "{`"Name`":`"%(refname:short)`",`"Remote`":`"%(upstream)`",`"Track`":`"%(upstream:track,nobracket)`",`"Worktree`":`"%(worktreepath)`",`"Current`":`"%(HEAD)`"}") -join ','
            $ToParse += ']'
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to retrieve branches.'
                exit 1
            }

            $AllBranches = $ToParse | ConvertFrom-Json -NoEnumerate
            $LocalOnlyBranches = $AllBranches | Where-Object { ($_.Remote.Length -eq 0) -or ($_.Track -eq 'gone') }

            # Git won't delete a checked-out branch, so removing the current one
            # means switching away first. Only branches that are staying put and
            # aren't held by another worktree are valid switch targets.
            $SwitchTarget = $Null
            if ($LocalOnlyBranches | Where-Object { $_.Current -eq '*' }) {
                $DoomedNames = $LocalOnlyBranches | Select-Object -ExpandProperty Name
                $Candidates = $AllBranches |
                    Where-Object { ($DoomedNames -notcontains $_.Name) -and ($_.Worktree.Length -eq 0) } |
                    Select-Object -ExpandProperty Name
                $Preferred = @()
                $DefaultBranch = &git symbolic-ref --short refs/remotes/origin/HEAD 2>$Null
                if ($LASTEXITCODE -eq 0) {
                    # 'origin/main' -> 'main'
                    $Preferred += $DefaultBranch -replace '^origin/', ''
                }

                $Preferred += @('main', 'master', 'develop')
                $SwitchTarget = $Preferred | Where-Object { $Candidates -contains $_ } | Select-Object -First 1
            }

            # The first entry is always the main worktree, which git can't remove.
            $MainWorktree = (&git worktree list --porcelain | Select-Object -First 1) -replace '^worktree ', ''

            $LocalOnlyBranches | ForEach-Object {
                $LocalBranch = $_
                $Name = $LocalBranch.Name
                $IsCurrent = $LocalBranch.Current -eq '*'
                $Worktree = if ($IsCurrent) { '' } else { $LocalBranch.Worktree }
                if ($Worktree -eq $MainWorktree) {
                    Write-Warning "Skipping '$Name' ($Path) - checked out in the main worktree at '$Worktree'. Switch away there and re-run."
                    return
                }

                if ($IsCurrent -and ($Null -eq $SwitchTarget)) {
                    Write-Warning "Skipping '$Name' ($Path) - it's the current branch and there's no default branch (main, master, develop) to switch to. Switch away and re-run."
                    return
                }

                $Operation = if ($IsCurrent) {
                    "Switch to $SwitchTarget, then remove branch with no upstream"
                }
                elseif ($Worktree.Length -gt 0) {
                    "Remove worktree at $Worktree, then remove branch with no upstream"
                }
                else {
                    'Remove branch with no upstream'
                }
                if (-not $PSCmdlet.ShouldProcess("$Name ($Path)", $Operation)) {
                    return
                }

                if ($IsCurrent) {
                    Write-Verbose "Switching from $Name to $SwitchTarget before removing it."
                    &git switch $SwitchTarget
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Skipping '$Name' ($Path) - unable to switch to '$SwitchTarget'. Commit or stash your changes and re-run."
                        return
                    }
                }

                if ($Worktree.Length -gt 0) {
                    Write-Verbose "Removing worktree at $Worktree before removing $Name."
                    &git worktree remove $Worktree
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Skipping '$Name' ($Path) - unable to remove worktree at '$Worktree'. Commit, stash, or unlock it and re-run."
                        return
                    }
                }

                &git branch -D $Name
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Unable to delete branch '$Name' ($Path)."
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}
