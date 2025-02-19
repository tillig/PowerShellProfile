<#
.SYNOPSIS
    Opens the current Git repository in web view.
.DESCRIPTION
    Based on the current Git repository set of remotes, this command attempts to
    calculate the equivalent web view. On success, it opens the default system
    web browser to that web view.
.PARAMETER Path
    The location of the Git repository clone for which the remote web view
    should be opened.
.PARAMETER Remote
    The name of the Git remote for which the web view should be opened. Defaults
    to 'origin'.
.EXAMPLE
    Open-GitRemote ~/dev/myrepo
.NOTES
    The logic for this cmdlet is largely based on the amazing vscode-gitlens
    plugin (licensed under MIT License) which has the URL parsing and support
    for providers to open a remote view on a repo.

    https://github.com/gitkraken/vscode-gitlens
#>
function Open-GitRemote {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD,

        [Parameter(Mandatory = $False)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Remote = "origin"
    )
    Begin {
        class GitInfo {
            [string]$Domain
            [string]$Path
            [string]$Scheme = 'https://'
            [string]$RemoteUrl
            [string]$Hash
            [string]$Head
            [string]$WebViewBaseUrl
            [bool]IsDetachedHead() {
                return "(detached)" -eq $this.Head
            }
        }
        class GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/remoteProviders.ts
            [string]$Name
            [string]$HostMatch
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                return $null
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                return $null
            }
            SetWebViewBaseUrl([GitInfo]$GitInfo) {
                If ($GitInfo.WebViewBaseUrl) {
                    return
                }
                $GitInfo.WebViewBaseUrl = "https://$($GitInfo.Domain)/$($GitInfo.Path)"
                Write-Verbose "Set web view base URL to $($GitInfo.WebViewBaseUrl)"
            }
            [string]EncodeUri([string]$uri) {
                # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/remoteProvider.ts
                # https://github.com/gitkraken/vscode-gitlens/blob/main/src/system/encoding.ts
                return [Uri]::EscapeUriString(($uri -replace '%20', ' ')) -replace '#', '%23'
            }
        }
        class AzureDevOpsGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/azure-devops.ts
            [bool]$Legacy # visualstudio.com
            AzureDevOpsGitProvider([bool]$Legacy) {
                $this.Legacy = $Legacy
                $this.Name = "Azure DevOps"
                If ($Legacy) {
                    $this.HostMatch = "\bvisualstudio\.com$"
                }
                Else {
                    $this.HostMatch = "\bdev\.azure\.com$"
                }
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/?version=GB$($GitInfo.Head)")
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/commit/$($GitInfo.Hash)")
            }
            SetWebViewBaseUrl([GitInfo]$GitInfo) {
                If ($GitInfo.WebViewBaseUrl) {
                    return
                }

                # Convert SSH to HTTPS URLs
                If ($GitInfo.Domain -match "^(ssh|vs-ssh)\.") {
                    # git@ssh.dev.azure.com:v3/OrgName/ProjectName/repo-name
                    # will have been converted to
                    # https://ssh.dev.azure.com/v3/OrgName/ProjectName/repo-name
                    # so remove the `ssh.` on the host and the `v3` in the path.
                    $GitInfo.Domain = $GitInfo.Domain -replace "^(ssh|vs-ssh)\.", ''
                    $GitInfo.Path = $GitInfo.Path -replace "^\/?v\d\/", ''

                    # Add in /_git/ into the URL.
                    If ($GitInfo.Path -match "^\/(.*?)\/(.*?)\/(.*)") {
                        $org = $Matches[1]
                        $project = $Matches[2]
                        $rest = $Matches[3]
                        If ($this.Legacy) {
                            $GitInfo.Host = "$org`.$($GitInfo.Host)"
                            $GitInfo.Path = "$project/_git/$rest"
                        }
                        Else {
                            $GitInfo.Path = "/$org/$project/_git/$rest"
                        }
                    }
                }

                ([GitProvider]$this).SetWebViewBaseUrl($GitInfo)
            }
        }
        class BitbucketGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/bitbucket.ts
            BitbucketGitProvider() {
                $this.Name = "Bitbucket"
                $this.HostMatch = "bitbucket\.org"
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/branch/$($GitInfo.Head)")
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/commits/$($GitInfo.Hash)")
            }
        }
        class BitbucketServerGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/bitbucket-server.ts
            BitbucketServerGitProvider() {
                $this.Name = "Bitbucket Server"
                $this.HostMatch = "^(.+\/(?:bitbucket|stash))\/scm\/(.+)$"
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/commits?until=$($GitInfo.Head)")
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/commits/$($GitInfo.Hash)")
            }
        }
        class GerritGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/gerrit.ts
            GerritGitProvider() {
                $this.Name = "Gerrit"
                $this.HostMatch = "\bgerrithub\.io$"
            }
            SetWebViewBaseUrl([GitInfo]$GitInfo) {
                If ($GitInfo.WebViewBaseUrl) {
                    return
                }

                <#
                Git remote URLs differs when cloned by HTTPS with or without authentication.
                An anonymous clone looks like:
                $ git clone "https://review.gerrithub.io/jenkinsci/gerrit-code-review-plugin"
                An authenticated clone looks like:
                $ git clone "https://username@review.gerrithub.io/a/jenkinsci/gerrit-code-review-plugin"
                Where username may be omitted, but the "a/" prefix is always present.
                #>
                If ($GitInfo.Scheme.StartsWith("http")) {
                    $GitInfo.Path = $GitInfo.Path -replace "^a\//", ''
                }

                ([GitProvider]$this).SetWebViewBaseUrl($GitInfo)
            }
        }
        class GiteaGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/gitea.ts
            GiteaGitProvider() {
                $this.Name = "Gitea"
                $this.HostMatch = "\bgitea\b"
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/branch/$($GitInfo.Head)")
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/commit/$($GitInfo.Hash)")
            }
        }
        class GitHubGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/github.ts
            GitHubGitProvider() {
                $this.Name = "GitHub"
                $this.HostMatch = "github\.com"
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/tree/$($GitInfo.Head)")
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/commit/$($GitInfo.Hash)")
            }
        }
        class GitLabGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/gitlab.ts
            GitLabGitProvider() {
                $this.Name = "GitLab"
                $this.HostMatch = "gitlab\.com"
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/-/tree/$($GitInfo.Head)")
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                $this.SetWebViewBaseUrl($GitInfo)
                return $this.EncodeUri("$($GitInfo.WebViewBaseUrl)/-/commit/$($GitInfo.Hash)")
            }
        }
        class GitLabCustomDomainGitProvider : GitLabGitProvider {
            GitLabCustomDomainGitProvider() {
                $this.Name = "GitLab (Custom Domain)"
                $this.HostMatch = "\bgitlab\b"
            }
        }
        class GoogleSourceGitProvider : GerritGitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/google-source.ts
            GoogleSourceGitProvider() {
                $this.Name = "Google Source"
                $this.HostMatch = "\bgooglesource\.com$"
            }
        }

        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error "Unable to locate git."
            Exit 1
        }

        If (-not (Test-Path $Path)) {
            Write-Error "Unable to find path $Path"
            Exit 1
        }

        $providers = [GitProvider[]]@(
            [BitBucketGitProvider]::new()
            [GitHubGitProvider]::new()
            [GitLabGitProvider]::new()
            [AzureDevOpsGitProvider]::new($True)
            [BitbucketServerGitProvider]::new()
            [GitLabCustomDomainGitProvider]::new()
            [AzureDevOpsGitProvider]::new($False)
            [GiteaGitProvider]::new()
            [GerritGitProvider]::new()
            [GoogleSourceGitProvider]::new()
        )

        Function GetGitInfo {
            [OutputType([GitInfo])]
            Param(
                [Parameter(Mandatory = $True, Position = 0)]
                [string]
                [ValidateNotNullOrEmpty()]
                $Remote
            )

            $gitInfo = [GitInfo]::new()

            $gitInfo.RemoteUrl = git remote get-url $Remote
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to get URL for remote '$Remote'."
                exit 1
            }

            # SSH URLs come through like
            # git@ssh.dev.azure.com:v3/OrgName/ProjectName/repo-name
            # or git@github.com:autofac/Autofac.git.
            # This parses into domain/host and path so we can calculate from that.
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/parsers/remoteParser.ts
            $gitRemoteParser = "^(?:(git:\/\/)(.*?)\/|(https?:\/\/)(?:.*?@)?(.*?)\/|git@(.*):|(ssh:\/\/)(?:.*@)?(.*?)(?::.*?)?(?:\/|(?=~))|(?:.*?@)(.*?):)(.*)$"
            If ($gitInfo.RemoteUrl -match $gitRemoteParser) {
                $gitInfo.Scheme = $Matches[1] ?? $Matches[3] ?? $Matches[6] ?? "https://"
                $gitInfo.Domain = $Matches[2] ?? $Matches[4] ?? $Matches[5] ?? $Matches[7] ?? $Matches[8]
                $gitInfo.Path = $Matches[9] -replace '\.git\/?$', ''
            }

            <#
            git status --branch --porcelain=2

            yields

            # branch.oid a9b153f2c59d8dc2f721df8c0584069ebd33e55b
            # branch.head master
            # branch.upstream origin/master
            # branch.ab +0 -0

            or

            # branch.oid 070835a3cdc52279f046cf3973c0b242d302522e
            # branch.head (detached)
            #>
            $gitStatus = &git status --branch --porcelain=2
            If ($LASTEXITCODE -ne 0) {
                throw "Unable to get git status."
                exit 1
            }
            $gitStatus | ForEach-Object {
                $line = $_.Trim().TrimStart('#').Trim()
                $parts = $line.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
                If ($parts.Length -eq 2) {
                    Switch ($parts[0]) {
                        "branch.oid" { $gitInfo.Hash = $parts[1] }
                        "branch.head" { $gitInfo.Head = $parts[1] }
                    }
                }
            }

            Write-Verbose "RemoteUrl: $($gitInfo.RemoteUrl)"
            Write-Verbose "Scheme: $($gitInfo.Scheme)"
            Write-Verbose "Domain: $($gitInfo.Domain)"
            Write-Verbose "Hash: $($gitInfo.Hash)"
            Write-Verbose "Head: $($gitInfo.Head)"
            Write-Verbose "Path: $($gitInfo.Path)"
            $gitInfo
        }

        Function CalculateWebView {
            [OutputType([string])]
            Param(
                [Parameter(Mandatory = $True, Position = 0)]
                [GitInfo]
                [ValidateNotNull()]
                $GitInfo
            )

            <#
            The basic algorithm appears to be...
            - Get the git remote.
            - If no detached head, get the current branch name.
            - If detached head, get the commit.
            - Calculate the location based on branch (getUrlForBranch()) or commit (getUrlForCommit())
            - Detached head at a tag (doesn't seem like there's specific URL support for this?)

            If branch.head is "(detached)" then use the the commit if not.
            If branch.head is something else, that's the branch.
            #>
            Write-Verbose "Calculating web view from remote host '$($GitInfo.Domain)'."
            $provider = $providers | Where-Object { $GitInfo.Domain -match $_.HostMatch } | Select-Object -First 1
            If ($null -eq $provider) {
                throw "Unable to determine web view for remote URL $($GitInfo.Domain)"
            }
            Else {
                Write-Verbose "Using remote provider $($provider.Name)."
            }

            If ($GitInfo.IsDetachedHead()) {
                Write-Verbose "Working in detached head."
                $webViewUrl = $provider.GetUrlForCommit($GitInfo)
            }
            Else {
                Write-Verbose "Working on branch."
                $webViewUrl = $provider.GetUrlForBranch($GitInfo)
            }

            Write-Verbose "Web view URL: $webViewUrl"
            return $webViewUrl
        }
    }
    Process {
        Try {
            Push-Location $Path

            $gitInfo = GetGitInfo $Remote
            $webViewUrl = CalculateWebView $gitInfo

            # Start the browser process.
            If ($IsMacOS) {
                &open $webViewUrl
            }
            ElseIf ($IsLinux) {
                &xdg-open $webViewUrl
            }
            Else {
                &start $webViewUrl
            }
        }
        Finally {
            Pop-Location
        }
    }
}
