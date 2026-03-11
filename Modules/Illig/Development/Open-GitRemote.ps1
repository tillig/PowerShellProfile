<#
.SYNOPSIS
    Opens the current Git repository in web view.
.DESCRIPTION
    Based on the current Git repository set of remotes, this command attempts to
    calculate the equivalent web view. On success, it opens the default system
    web browser to that web view.

    Default behavior is sufficient for the majority case using public/standard
    hosting providers. However, if you need to support a custom provider or a
    private instance of a known provider, you can provide custom regex pattern
    mappings to remap hosts to providers.

    Examples of the configuration file and profile variable are provided below.
    The configuration file is ideal for user-level customizations that you want
    to share across environments, while the profile variable is ideal for
    machine or environment-specific overrides.
.PARAMETER Path
    The location of the Git repository clone for which the remote web view
    should be opened.
.PARAMETER Remote
    The name of the Git remote for which the web view should be opened. Defaults
    to 'origin'.
.NOTES
    The logic for this cmdlet is largely based on the amazing vscode-gitlens
    plugin (licensed under MIT License) which has the URL parsing and support
    for providers to open a remote view on a repo.

    Optional custom host mappings can be provided in either:
    - ~/.config/powershell/Open-GitRemote.Providers.psd1
    - $Global:OpenGitRemoteProviderMappings

    If both are present, profile variable mappings have higher default
    priority. Invalid mappings emit warnings and are skipped.

    https://github.com/gitkraken/vscode-gitlens
.EXAMPLE
    Open-GitRemote

    Opens the web view for the 'origin' remote of the Git repository at the
    current location.
.EXAMPLE
    Open-GitRemote ~/dev/my-repo

    Opens the web view for the 'origin' remote of the Git repository at
    ~/dev/my-repo.
.EXAMPLE
    Get-Content ~/.config/powershell/Open-GitRemote.Providers.psd1
    @{
        Mappings = @(
            @{
                Pattern = 'my\.custom\.domain\.net'
                Provider = 'GitHub'
            }
        )
    }

    Sample configuration file to remap hosts matching 'my.custom.domain.net'
    to the GitHub provider.
.EXAMPLE
    $Global:OpenGitRemoteProviderMappings = @(
        @{
            Pattern = 'my\.custom\.domain\.net'
            Provider = 'GitHub'
            Priority = 300
        }
    )

    Sample profile variable to remap hosts matching 'my.custom.domain.net' to
    the GitHub provider with a custom priority.
.EXAMPLE
    $Global:OpenGitRemoteProviderMappings = @(
        @{ Pattern = 'dev\.azure\.com'; Provider = 'AzureDevOps' },
        @{ Pattern = '.*\.visualstudio\.com$'; Provider = 'AzureDevOpsLegacy' }
    )

    Sample usage of the Azure DevOps disambiguation keys.
#>
function Open-GitRemote {
    [CmdletBinding(SupportsShouldProcess = $False)]
    param(
        [Parameter(Mandatory = $False, Position = 0)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = $PWD,

        [Parameter(Mandatory = $False)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Remote = 'origin'
    )
    begin {
        class GitInfo {
            [string]$Domain
            [string]$Path
            [string]$Scheme = 'https://'
            [string]$RemoteUrl
            [string]$Hash
            [string]$Head
            [string]$WebViewBaseUrl
            [bool]IsDetachedHead() {
                return '(detached)' -eq $this.Head
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
                if ($GitInfo.WebViewBaseUrl) {
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
                $this.Name = 'Azure DevOps'
                if ($Legacy) {
                    $this.HostMatch = '\bvisualstudio\.com$'
                }
                else {
                    $this.HostMatch = '\bdev\.azure\.com$'
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
                if ($GitInfo.WebViewBaseUrl) {
                    return
                }

                # Convert SSH to HTTPS URLs
                if ($GitInfo.Domain -match '^(ssh|vs-ssh)\.') {
                    # git@ssh.dev.azure.com:v3/OrgName/ProjectName/repo-name
                    # will have been converted to
                    # https://ssh.dev.azure.com/v3/OrgName/ProjectName/repo-name
                    # so remove the `ssh.` on the host and the `v3` in the path.
                    $GitInfo.Domain = $GitInfo.Domain -replace '^(ssh|vs-ssh)\.', ''
                    $GitInfo.Path = $GitInfo.Path -replace '^\/?v\d\/', ''

                    # Add in /_git/ into the URL.
                    if ($GitInfo.Path -match '^\/(.*?)\/(.*?)\/(.*)') {
                        $org = $Matches[1]
                        $project = $Matches[2]
                        $rest = $Matches[3]
                        if ($this.Legacy) {
                            $GitInfo.Host = "$org`.$($GitInfo.Host)"
                            $GitInfo.Path = "$project/_git/$rest"
                        }
                        else {
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
                $this.Name = 'Bitbucket'
                $this.HostMatch = 'bitbucket\.org'
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
                $this.Name = 'Bitbucket Server'
                $this.HostMatch = '^(.+\/(?:bitbucket|stash))\/scm\/(.+)$'
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
                $this.Name = 'Gerrit'
                $this.HostMatch = '\bgerrithub\.io$'
            }
            SetWebViewBaseUrl([GitInfo]$GitInfo) {
                if ($GitInfo.WebViewBaseUrl) {
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
                if ($GitInfo.Scheme.StartsWith('http')) {
                    $GitInfo.Path = $GitInfo.Path -replace '^a\//', ''
                }

                ([GitProvider]$this).SetWebViewBaseUrl($GitInfo)
            }
        }
        class GiteaGitProvider : GitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/gitea.ts
            GiteaGitProvider() {
                $this.Name = 'Gitea'
                $this.HostMatch = '\bgitea\b'
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
                $this.Name = 'GitHub'
                $this.HostMatch = 'github\.com'
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
                $this.Name = 'GitLab'
                $this.HostMatch = 'gitlab\.com'
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
        class GitHubCustomDomainGitProvider : GitHubGitProvider {
            GitHubCustomDomainGitProvider() {
                $this.Name = 'GitHub (Custom Domain)'
                $this.HostMatch = '\bgithub\b'
            }
        }
        class GitLabCustomDomainGitProvider : GitLabGitProvider {
            GitLabCustomDomainGitProvider() {
                $this.Name = 'GitLab (Custom Domain)'
                $this.HostMatch = '\bgitlab\b'
            }
        }
        class GoogleSourceGitProvider : GerritGitProvider {
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/remotes/google-source.ts
            GoogleSourceGitProvider() {
                $this.Name = 'Google Source'
                $this.HostMatch = '\bgooglesource\.com$'
            }
        }
        # Wraps a built-in provider with a custom hostname regex matcher.
        class RemappedGitProvider : GitProvider {
            [GitProvider]$InnerProvider
            RemappedGitProvider([GitProvider]$InnerProvider, [string]$HostMatch) {
                $this.InnerProvider = $InnerProvider
                $this.HostMatch = $HostMatch
                $this.Name = "$($InnerProvider.Name) (Custom Match)"
            }
            [string]GetUrlForBranch([GitInfo]$GitInfo) {
                return $this.InnerProvider.GetUrlForBranch($GitInfo)
            }
            [string]GetUrlForCommit([GitInfo]$GitInfo) {
                return $this.InnerProvider.GetUrlForCommit($GitInfo)
            }
        }

        $git = Get-Command git -ErrorAction Ignore
        if ($Null -eq $git) {
            Write-Error 'Unable to locate git.'
            exit 1
        }

        if (-not (Test-Path $Path)) {
            Write-Error "Unable to find path $Path"
            exit 1
        }

        # Returns providers in the default matching order.
        function GetDefaultProviders {
            return [GitProvider[]]@(
                [BitBucketGitProvider]::new()
                [GitHubGitProvider]::new()
                [GitLabGitProvider]::new()
                [AzureDevOpsGitProvider]::new($True)
                [BitbucketServerGitProvider]::new()
                [GitLabCustomDomainGitProvider]::new()
                [GitHubCustomDomainGitProvider]::new()
                [AzureDevOpsGitProvider]::new($False)
                [GiteaGitProvider]::new()
                [GerritGitProvider]::new()
                [GoogleSourceGitProvider]::new()
            )
        }

        # Builds case-insensitive lookup keys for class names and display names.
        function NewProviderLookup {
            [OutputType([hashtable])]
            param(
                [Parameter(Mandatory = $True)]
                [GitProvider[]]
                $Providers
            )

            $lookup = @{}
            $ambiguousKeys = New-Object 'System.Collections.Generic.HashSet[string]'

            function RegisterProviderLookupKey {
                param(
                    [Parameter(Mandatory = $True)]
                    [string]
                    $Key,

                    [Parameter(Mandatory = $True)]
                    [GitProvider]
                    $Provider
                )

                $normalizedKey = $Key.ToLowerInvariant()
                if ($ambiguousKeys.Contains($normalizedKey)) {
                    return
                }

                if ($lookup.ContainsKey($normalizedKey) -and $lookup[$normalizedKey] -ne $Provider) {
                    [void]$ambiguousKeys.Add($normalizedKey)
                    $lookup.Remove($normalizedKey)
                    return
                }

                if (-not $lookup.ContainsKey($normalizedKey)) {
                    $lookup[$normalizedKey] = $Provider
                }
            }

            foreach ($provider in $Providers) {
                $providerTypeName = $provider.GetType().Name
                RegisterProviderLookupKey -Key $providerTypeName -Provider $provider

                if ($provider.Name) {
                    RegisterProviderLookupKey -Key $provider.Name -Provider $provider
                }

                if ($provider -is [AzureDevOpsGitProvider]) {
                    # Azure DevOps has both modern and legacy hosts, so expose explicit keys.
                    if ($provider.Legacy) {
                        RegisterProviderLookupKey -Key 'AzureDevOpsLegacy' -Provider $provider
                        RegisterProviderLookupKey -Key 'Azure DevOps Legacy' -Provider $provider
                    }
                    else {
                        RegisterProviderLookupKey -Key 'AzureDevOps' -Provider $provider
                        RegisterProviderLookupKey -Key 'Azure DevOps' -Provider $provider
                    }
                }
            }

            # Friendly aliases for common provider names.
            @(
                @{ Alias = 'github'; ProviderType = 'GitHubGitProvider' }
                @{ Alias = 'gitlab'; ProviderType = 'GitLabGitProvider' }
                @{ Alias = 'bitbucket'; ProviderType = 'BitbucketGitProvider' }
                @{ Alias = 'gitea'; ProviderType = 'GiteaGitProvider' }
                @{ Alias = 'gerrit'; ProviderType = 'GerritGitProvider' }
                @{ Alias = 'googlesource'; ProviderType = 'GoogleSourceGitProvider' }
            ) | ForEach-Object {
                $providerKey = $_.ProviderType.ToLowerInvariant()
                if ($lookup.ContainsKey($providerKey) -and -not $lookup.ContainsKey($_.Alias)) {
                    $lookup[$_.Alias] = $lookup[$providerKey]
                }
            }

            return $lookup
        }

        # Reads a named value from either hashtables or PSCustomObject values.
        function GetValueByName {
            [OutputType([object])]
            param(
                [Parameter(Mandatory = $True)]
                [object]
                $Source,

                [Parameter(Mandatory = $True)]
                [string]
                $Name
            )

            if ($Source -is [System.Collections.IDictionary]) {
                if ($Source.Contains($Name)) {
                    return $Source[$Name]
                }

                foreach ($key in $Source.Keys) {
                    if ($null -ne $key -and $key.ToString().Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                        return $Source[$key]
                    }
                }

                return $null
            }

            $property = $Source.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
            if ($null -ne $property) {
                return $property.Value
            }

            return $null
        }

        # Normalizes supported config shapes into a mapping list.
        function GetMappingsFromConfigObject {
            [OutputType([object[]])]
            param(
                [Parameter(Mandatory = $True)]
                [object]
                $Config
            )

            $mappingsValue = GetValueByName $Config 'Mappings'
            if ($null -ne $mappingsValue) {
                return @($mappingsValue)
            }

            return @($Config)
        }

        # Loads mappings from home data file and profile variable sources.
        function GetCustomMappings {
            [OutputType([object[]])]
            $allMappings = New-Object System.Collections.ArrayList

            $homeConfigPath = Join-Path (Join-Path (Join-Path $HOME '.config') 'powershell') 'Open-GitRemote.Providers.psd1'
            if (Test-Path $homeConfigPath) {
                try {
                    $homeConfig = Import-PowerShellDataFile -Path $homeConfigPath
                    $mappings = GetMappingsFromConfigObject $homeConfig
                    $mappingIndex = 0
                    $mappings | ForEach-Object {
                        [void]$allMappings.Add([PSCustomObject]@{
                                Mapping         = $_
                                Source          = $homeConfigPath
                                MappingIndex    = $mappingIndex
                                DefaultPriority = 100
                            })
                        $mappingIndex++
                    }
                }
                catch {
                    Write-Warning "Unable to read Open-GitRemote custom mappings from $homeConfigPath. $($_.Exception.Message)"
                }
            }

            if ($null -ne $Global:OpenGitRemoteProviderMappings) {
                $mappings = GetMappingsFromConfigObject $Global:OpenGitRemoteProviderMappings
                $mappingIndex = 0
                $mappings | ForEach-Object {
                    [void]$allMappings.Add([PSCustomObject]@{
                            Mapping         = $_
                            Source          = '$Global:OpenGitRemoteProviderMappings'
                            MappingIndex    = $mappingIndex
                            DefaultPriority = 200
                        })
                    $mappingIndex++
                }
            }

            return @($allMappings)
        }

        # Validates and converts one mapping into a runtime provider entry.
        function ConvertToRemappedProviderEntry {
            [OutputType([object])]
            param(
                [Parameter(Mandatory = $True)]
                [object]
                $Mapping,

                [Parameter(Mandatory = $True)]
                [string]
                $Source,

                [Parameter(Mandatory = $True)]
                [int]
                $MappingIndex,

                [Parameter(Mandatory = $True)]
                [int]
                $DefaultPriority,

                [Parameter(Mandatory = $True)]
                [int]
                $Order,

                [Parameter(Mandatory = $True)]
                [hashtable]
                $ProviderLookup
            )

            $pattern = [string](GetValueByName $Mapping 'Pattern')
            $providerReference = [string](GetValueByName $Mapping 'Provider')
            $priority = GetValueByName $Mapping 'Priority'
            $mappingId = "$Source[$MappingIndex]"

            if ([string]::IsNullOrWhiteSpace($pattern)) {
                Write-Warning "Skipping invalid Open-GitRemote mapping at $mappingId. Missing required field 'Pattern'."
                return $null
            }

            if ([string]::IsNullOrWhiteSpace($providerReference)) {
                Write-Warning "Skipping invalid Open-GitRemote mapping at $mappingId. Missing required field 'Provider'."
                return $null
            }

            try {
                [void][System.Text.RegularExpressions.Regex]::new($pattern)
            }
            catch {
                Write-Warning "Skipping invalid Open-GitRemote mapping at $mappingId. Pattern '$pattern' is not a valid regex."
                return $null
            }

            $providerKey = $providerReference.ToLowerInvariant()
            if (-not $ProviderLookup.ContainsKey($providerKey)) {
                $knownProviders = ($ProviderLookup.Keys | Sort-Object) -join ', '
                Write-Warning "Skipping invalid Open-GitRemote mapping at $mappingId. Unknown provider '$providerReference'. Known providers: $knownProviders"
                return $null
            }

            $resolvedPriority = $DefaultPriority
            if ($null -ne $priority -and -not [string]::IsNullOrWhiteSpace([string]$priority)) {
                $resolvedPriority = 0
                if (-not [int]::TryParse([string]$priority, [ref]$resolvedPriority)) {
                    Write-Warning "Skipping invalid Open-GitRemote mapping at $mappingId. Priority '$priority' is not an integer."
                    return $null
                }
            }

            $innerProvider = $ProviderLookup[$providerKey]
            $remappedProvider = [RemappedGitProvider]::new($innerProvider, $pattern)
            return [PSCustomObject]@{
                Provider = $remappedProvider
                Priority = $resolvedPriority
                Order    = $Order
            }
        }

        $defaultProviders = GetDefaultProviders
        $providerLookup = NewProviderLookup $defaultProviders
        $providerEntries = New-Object System.Collections.ArrayList

        for ($index = 0; $index -lt $defaultProviders.Length; $index++) {
            [void]$providerEntries.Add([PSCustomObject]@{
                    Provider = $defaultProviders[$index]
                    Priority = 0
                    Order    = $index
                })
        }

        $customMappings = GetCustomMappings
        $customOrder = $defaultProviders.Length
        foreach ($customMapping in $customMappings) {
            $customEntry = ConvertToRemappedProviderEntry -Mapping $customMapping.Mapping -Source $customMapping.Source -MappingIndex $customMapping.MappingIndex -DefaultPriority $customMapping.DefaultPriority -Order $customOrder -ProviderLookup $providerLookup
            if ($null -ne $customEntry) {
                [void]$providerEntries.Add($customEntry)
                $customOrder++
            }
        }

        $providers = [GitProvider[]]($providerEntries | Sort-Object -Property @{ Expression = { $_.Priority }; Descending = $True }, @{ Expression = { $_.Order }; Descending = $False } | ForEach-Object { $_.Provider })
        Write-Verbose "Loaded $($providers.Length) provider matchers ($($defaultProviders.Length) built-in, $($providers.Length - $defaultProviders.Length) custom)."

        function GetGitInfo {
            [OutputType([GitInfo])]
            param(
                [Parameter(Mandatory = $True, Position = 0)]
                [string]
                [ValidateNotNullOrEmpty()]
                $Remote
            )

            $gitInfo = [GitInfo]::new()

            $gitInfo.RemoteUrl = git remote get-url $Remote
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to get URL for remote '$Remote'."
                exit 1
            }

            # SSH URLs come through like
            # git@ssh.dev.azure.com:v3/OrgName/ProjectName/repo-name
            # or git@github.com:autofac/Autofac.git.
            # This parses into domain/host and path so we can calculate from that.
            # https://github.com/gitkraken/vscode-gitlens/blob/main/src/git/parsers/remoteParser.ts
            $gitRemoteParser = '^(?:(git:\/\/)(.*?)\/|(https?:\/\/)(?:.*?@)?(.*?)\/|git@(.*):|(ssh:\/\/)(?:.*@)?(.*?)(?::.*?)?(?:\/|(?=~))|(?:.*?@)(.*?):)(.*)$'
            if ($gitInfo.RemoteUrl -match $gitRemoteParser) {
                $gitInfo.Scheme = $Matches[1] ?? $Matches[3] ?? $Matches[6] ?? 'https://'
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
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to get git status.'
                exit 1
            }
            $gitStatus | ForEach-Object {
                $line = $_.Trim().TrimStart('#').Trim()
                $parts = $line.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
                if ($parts.Length -eq 2) {
                    switch ($parts[0]) {
                        'branch.oid' { $gitInfo.Hash = $parts[1] }
                        'branch.head' { $gitInfo.Head = $parts[1] }
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

        function CalculateWebView {
            [OutputType([string])]
            param(
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
            if ($null -eq $provider) {
                throw "Unable to determine web view for remote URL $($GitInfo.Domain)"
            }
            else {
                Write-Verbose "Using remote provider $($provider.Name)."
            }

            if ($GitInfo.IsDetachedHead()) {
                Write-Verbose 'Working in detached head.'
                $webViewUrl = $provider.GetUrlForCommit($GitInfo)
            }
            else {
                Write-Verbose 'Working on branch.'
                $webViewUrl = $provider.GetUrlForBranch($GitInfo)
            }

            Write-Verbose "Web view URL: $webViewUrl"
            return $webViewUrl
        }
    }
    process {
        try {
            Push-Location $Path

            $gitInfo = GetGitInfo $Remote
            $webViewUrl = CalculateWebView $gitInfo

            # Start the browser process.
            if ($IsMacOS) {
                &open $webViewUrl
            }
            elseif ($IsLinux) {
                &xdg-open $webViewUrl
            }
            else {
                &start $webViewUrl
            }
        }
        finally {
            Pop-Location
        }
    }
}
