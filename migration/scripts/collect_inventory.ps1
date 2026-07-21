[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$SourceRepository = "mygithub05253/EST-CAMP-AI-Quant",
  [string]$TargetOrganization = "EST-Bootcamp-AI-Quant",
  [string]$RepositoryRoot = "",
  [string]$OutputDirectory = "",
  [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrationDirectory = Split-Path -Parent $scriptDirectory
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  $RepositoryRoot = Split-Path -Parent $migrationDirectory
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $migrationDirectory "reports"
}

function Test-CommandAvailable {
  param([Parameter(Mandatory = $true)][string]$Name)

  return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-OptionalPropertyValue {
  param(
    [AllowNull()]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

function ConvertTo-SafeText {
  param([AllowNull()][string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $safeText = $Text
  $safeText = $safeText -replace 'github_pat_[A-Za-z0-9_]+', '[REDACTED_GITHUB_TOKEN]'
  $safeText = $safeText -replace 'gh[pousr]_[A-Za-z0-9]+', '[REDACTED_GITHUB_TOKEN]'
  $safeText = $safeText -replace '(?i)Bearer\s+[A-Za-z0-9._~+\-/=]+', 'Bearer [REDACTED]'
  $safeText = $safeText -replace '(https?://)[^/@\s]+@', '$1[REDACTED]@'
  $safeText = $safeText -replace '(https?://[^\s?]+)\?[^\s]+', '$1?[REDACTED_QUERY]'
  $safeLines = @($safeText -split "`r?`n" | Where-Object {
    ($_ -notmatch '^\s*At\s+.+\.ps1:\d+') -and
    ($_ -notmatch '^\s*\+\s+') -and
    ($_ -notmatch '^\s*\+\s*CategoryInfo') -and
    ($_ -notmatch '^\s*\+\s*FullyQualifiedErrorId')
  })
  return ($safeLines -join [Environment]::NewLine).Trim()
}

function Invoke-NativeText {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [switch]$AllowFailure
  )

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $previousErrorActionPreference = $ErrorActionPreference

  try {
    $ErrorActionPreference = "Continue"
    & $Command @Arguments 1> $stdoutPath 2> $stderrPath
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    $stdout = [System.IO.File]::ReadAllText($stdoutPath)
    $stderr = [System.IO.File]::ReadAllText($stderrPath)

    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
      $message = ConvertTo-SafeText -Text ($stderr + [Environment]::NewLine + $stdout)
      throw "명령 실행 실패(exit=$exitCode): $Command $($Arguments -join ' ')`n$message"
    }

    return [pscustomobject]@{
      exitCode = $exitCode
      rawStdout = $stdout
      stdout = ConvertTo-SafeText -Text $stdout
      stderr = ConvertTo-SafeText -Text $stderr
    }
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-GhJson {
  param(
    [Parameter(Mandatory = $true)][string]$Endpoint,
    [switch]$Paginate
  )

  $arguments = @(
    "api",
    "-H", "Accept: application/vnd.github+json",
    "-H", "X-GitHub-Api-Version: 2022-11-28"
  )

  if ($Paginate) {
    $arguments += @("--paginate", "--slurp")
  }

  $arguments += $Endpoint
  $result = Invoke-NativeText -Command "gh" -Arguments $arguments -AllowFailure

  if ($result.exitCode -ne 0) {
    return [pscustomobject]@{
      status = "unavailable"
      endpoint = $Endpoint
      exitCode = $result.exitCode
      error = $result.stderr
      data = $null
    }
  }

  try {
    $data = $result.rawStdout | ConvertFrom-Json
    if ($Paginate) {
      $flattened = @()
      foreach ($page in @($data)) {
        $flattened += @($page)
      }
      $data = $flattened
    }

    return [pscustomobject]@{
      status = "success"
      endpoint = $Endpoint
      exitCode = 0
      error = $null
      data = $data
    }
  }
  catch {
    return [pscustomobject]@{
      status = "invalid-json"
      endpoint = $Endpoint
      exitCode = 0
      error = ConvertTo-SafeText -Text $_.Exception.Message
      data = $null
    }
  }
}

function Protect-VariableInventory {
  param([Parameter(Mandatory = $true)][pscustomobject]$Result)

  if (($Result.status -ne "success") -or ($null -eq $Result.data)) {
    return $Result
  }

  $variablesProperty = $Result.data.PSObject.Properties["variables"]
  if ($null -eq $variablesProperty) {
    return $Result
  }

  $safeVariables = @()
  foreach ($variable in @($variablesProperty.Value)) {
    $safeVariables += [pscustomobject]@{
      name = Get-OptionalPropertyValue -Object $variable -Name "name"
      createdAt = Get-OptionalPropertyValue -Object $variable -Name "created_at"
      updatedAt = Get-OptionalPropertyValue -Object $variable -Name "updated_at"
    }
  }

  $Result.data = [pscustomobject]@{
    totalCount = $safeVariables.Count
    variables = $safeVariables
    valuesStored = $false
  }
  return $Result
}

function Protect-SecretInventory {
  param([Parameter(Mandatory = $true)][pscustomobject]$Result)

  if (($Result.status -ne "success") -or ($null -eq $Result.data)) {
    return $Result
  }

  $secretsProperty = $Result.data.PSObject.Properties["secrets"]
  if ($null -eq $secretsProperty) {
    return $Result
  }

  $safeSecrets = @()
  foreach ($secret in @($secretsProperty.Value)) {
    $safeSecrets += [pscustomobject]@{
      name = Get-OptionalPropertyValue -Object $secret -Name "name"
      createdAt = Get-OptionalPropertyValue -Object $secret -Name "created_at"
      updatedAt = Get-OptionalPropertyValue -Object $secret -Name "updated_at"
      visibility = Get-OptionalPropertyValue -Object $secret -Name "visibility"
      selectedRepositoriesUrl = Get-OptionalPropertyValue -Object $secret -Name "selected_repositories_url"
    }
  }

  $Result.data = [pscustomobject]@{
    totalCount = $safeSecrets.Count
    secrets = $safeSecrets
    valuesStored = $false
  }
  return $Result
}

function Protect-WebhookInventory {
  param([Parameter(Mandatory = $true)][pscustomobject]$Result)

  if (($Result.status -ne "success") -or ($null -eq $Result.data)) {
    return $Result
  }

  $safeHooks = @()
  foreach ($hook in @($Result.data)) {
    $config = Get-OptionalPropertyValue -Object $hook -Name "config"
    $contentType = Get-OptionalPropertyValue -Object $config -Name "content_type"
    $insecureSsl = Get-OptionalPropertyValue -Object $config -Name "insecure_ssl"

    $safeHooks += [pscustomobject]@{
      id = Get-OptionalPropertyValue -Object $hook -Name "id"
      type = Get-OptionalPropertyValue -Object $hook -Name "type"
      name = Get-OptionalPropertyValue -Object $hook -Name "name"
      active = Get-OptionalPropertyValue -Object $hook -Name "active"
      events = @(Get-OptionalPropertyValue -Object $hook -Name "events")
      contentType = $contentType
      insecureSsl = $insecureSsl
      endpointStored = $false
    }
  }

  $Result.data = $safeHooks
  return $Result
}

function Protect-DeployKeyInventory {
  param([Parameter(Mandatory = $true)][pscustomobject]$Result)

  if (($Result.status -ne "success") -or ($null -eq $Result.data)) {
    return $Result
  }

  $safeKeys = @()
  foreach ($key in @($Result.data)) {
    $safeKeys += [pscustomobject]@{
      id = Get-OptionalPropertyValue -Object $key -Name "id"
      title = Get-OptionalPropertyValue -Object $key -Name "title"
      verified = Get-OptionalPropertyValue -Object $key -Name "verified"
      readOnly = Get-OptionalPropertyValue -Object $key -Name "read_only"
      createdAt = Get-OptionalPropertyValue -Object $key -Name "created_at"
      enabled = Get-OptionalPropertyValue -Object $key -Name "enabled"
      publicKeyStored = $false
    }
  }

  $Result.data = $safeKeys
  return $Result
}

function Protect-ArrayInventory {
  param(
    [Parameter(Mandatory = $true)][pscustomobject]$Result,
    [Parameter(Mandatory = $true)][scriptblock]$Projector
  )

  if (($Result.status -ne "success") -or ($null -eq $Result.data)) {
    return $Result
  }

  $safeItems = @()
  foreach ($item in @($Result.data)) {
    $projected = & $Projector $item
    if ($null -ne $projected) {
      $safeItems += $projected
    }
  }
  $Result.data = $safeItems
  return $Result
}

function Protect-ObjectCollectionInventory {
  param(
    [Parameter(Mandatory = $true)][pscustomobject]$Result,
    [Parameter(Mandatory = $true)][string]$CollectionProperty,
    [Parameter(Mandatory = $true)][scriptblock]$Projector
  )

  if (($Result.status -ne "success") -or ($null -eq $Result.data)) {
    return $Result
  }

  $collection = Get-OptionalPropertyValue -Object $Result.data -Name $CollectionProperty
  $safeItems = @()
  foreach ($item in @($collection)) {
    $projected = & $Projector $item
    if ($null -ne $projected) {
      $safeItems += $projected
    }
  }
  $Result.data = [pscustomobject]@{
    totalCount = $safeItems.Count
    items = $safeItems
  }
  return $Result
}

if (-not $Execute) {
  Write-Host "[DRY-RUN] GitHub 및 로컬 저장소 inventory를 수집하지 않았습니다."
  Write-Host "실행하려면 -Execute를 지정하세요."
  Write-Host "출력 예정 경로: $OutputDirectory"
  exit 0
}

if (-not $PSCmdlet.ShouldProcess($OutputDirectory, "GitHub 및 로컬 저장소 읽기 전용 inventory 수집과 보고서 생성")) {
  exit 0
}

if (-not (Test-CommandAvailable -Name "git")) {
  throw "git 명령을 찾을 수 없습니다."
}

if (-not (Test-CommandAvailable -Name "gh")) {
  throw "gh 명령을 찾을 수 없습니다."
}

$authResult = Invoke-NativeText -Command "gh" -Arguments @("auth", "status", "--hostname", "github.com") -AllowFailure
if ($authResult.exitCode -ne 0) {
  throw "GitHub CLI 인증이 유효하지 않습니다. gh auth status를 확인하세요."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputDirectoryFullPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$repositoryName = ($SourceRepository -split "/")[-1]
$targetRepository = "$TargetOrganization/$repositoryName"

$repositoryResult = Invoke-GhJson -Endpoint "repos/$SourceRepository"
if ($repositoryResult.status -ne "success") {
  throw "원본 저장소 메타데이터 조회에 실패했습니다: $($repositoryResult.error)"
}
$repositoryData = $repositoryResult.data
$defaultBranch = $repositoryData.default_branch
$defaultBranchRefResult = Invoke-GhJson -Endpoint "repos/$SourceRepository/git/ref/heads/$defaultBranch"
$securityAndAnalysis = Get-OptionalPropertyValue -Object $repositoryData -Name "security_and_analysis"
$secretScanning = Get-OptionalPropertyValue -Object $securityAndAnalysis -Name "secret_scanning"
$pushProtection = Get-OptionalPropertyValue -Object $securityAndAnalysis -Name "secret_scanning_push_protection"
$dependabotSecurityUpdates = Get-OptionalPropertyValue -Object $securityAndAnalysis -Name "dependabot_security_updates"
$license = Get-OptionalPropertyValue -Object $repositoryData -Name "license"
$repositoryPermissions = Get-OptionalPropertyValue -Object $repositoryData -Name "permissions"
$repositoryResult.data = [pscustomobject]@{
  id = $repositoryData.id
  node_id = $repositoryData.node_id
  full_name = $repositoryData.full_name
  owner = $repositoryData.owner.login
  visibility = $repositoryData.visibility
  default_branch = $defaultBranch
  main_sha = if ($defaultBranchRefResult.status -eq "success") { $defaultBranchRefResult.data.object.sha } else { $null }
  size_kb = $repositoryData.size
  created_at = $repositoryData.created_at
  updated_at = $repositoryData.updated_at
  pushed_at = $repositoryData.pushed_at
  description = $repositoryData.description
  homepage = $repositoryData.homepage
  topics = @($repositoryData.topics)
  fork = $repositoryData.fork
  archived = $repositoryData.archived
  disabled = $repositoryData.disabled
  has_issues = $repositoryData.has_issues
  has_projects = $repositoryData.has_projects
  has_wiki = $repositoryData.has_wiki
  has_pages = $repositoryData.has_pages
  has_discussions = $repositoryData.has_discussions
  allow_merge_commit = $repositoryData.allow_merge_commit
  allow_squash_merge = $repositoryData.allow_squash_merge
  allow_rebase_merge = $repositoryData.allow_rebase_merge
  allow_auto_merge = $repositoryData.allow_auto_merge
  delete_branch_on_merge = $repositoryData.delete_branch_on_merge
  allow_update_branch = $repositoryData.allow_update_branch
  network_count = $repositoryData.network_count
  forks_count = $repositoryData.forks_count
  watchers_count = $repositoryData.watchers_count
  license_spdx = Get-OptionalPropertyValue -Object $license -Name "spdx_id"
  permissions = [pscustomobject]@{
    admin = Get-OptionalPropertyValue -Object $repositoryPermissions -Name "admin"
    push = Get-OptionalPropertyValue -Object $repositoryPermissions -Name "push"
    pull = Get-OptionalPropertyValue -Object $repositoryPermissions -Name "pull"
  }
  security = [pscustomobject]@{
    secret_scanning = Get-OptionalPropertyValue -Object $secretScanning -Name "status"
    push_protection = Get-OptionalPropertyValue -Object $pushProtection -Name "status"
    dependabot_security_updates = Get-OptionalPropertyValue -Object $dependabotSecurityUpdates -Name "status"
  }
}

$userResult = Invoke-GhJson -Endpoint "user"
if (($userResult.status -eq "success") -and ($null -ne $userResult.data)) {
  $userResult.data = [pscustomobject]@{
    login = Get-OptionalPropertyValue -Object $userResult.data -Name "login"
    id = Get-OptionalPropertyValue -Object $userResult.data -Name "id"
    nodeId = Get-OptionalPropertyValue -Object $userResult.data -Name "node_id"
    type = Get-OptionalPropertyValue -Object $userResult.data -Name "type"
  }
}
$membershipResult = Invoke-GhJson -Endpoint "user/memberships/orgs/$TargetOrganization"
$organizationResult = Invoke-GhJson -Endpoint "orgs/$TargetOrganization"
if ($null -ne $organizationResult.data) {
  # 이관 판단에 불필요한 결제 연락처는 보고서에 저장하지 않는다.
  $organizationResult.data.PSObject.Properties.Remove("billing_email")
}
$targetCollisionResult = Invoke-GhJson -Endpoint "repos/$targetRepository"
$organizationRepositoriesResult = Invoke-GhJson -Endpoint "orgs/$TargetOrganization/repos?type=all&per_page=100" -Paginate
$sourceForksResult = Invoke-GhJson -Endpoint "repos/$SourceRepository/forks?sort=oldest&per_page=100" -Paginate

$organizationAccess = [ordered]@{
  collectedAtKst = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time").ToString("o")
  authenticatedUser = $userResult
  membership = $membershipResult
  organization = $organizationResult
  targetRepositoryProbe = $targetCollisionResult
  organizationRepositories = $organizationRepositoriesResult
  sourceForks = $sourceForksResult
  organizationActionsPermissions = Invoke-GhJson -Endpoint "orgs/$TargetOrganization/actions/permissions"
  organizationActionsWorkflowPermissions = Invoke-GhJson -Endpoint "orgs/$TargetOrganization/actions/permissions/workflow"
  organizationRulesets = Invoke-GhJson -Endpoint "orgs/$TargetOrganization/rulesets?per_page=100" -Paginate
  organizationInstallations = Invoke-GhJson -Endpoint "orgs/$TargetOrganization/installations?per_page=100"
  organizationSecrets = Protect-SecretInventory -Result (Invoke-GhJson -Endpoint "orgs/$TargetOrganization/actions/secrets?per_page=100")
  organizationVariables = Protect-VariableInventory -Result (Invoke-GhJson -Endpoint "orgs/$TargetOrganization/actions/variables?per_page=100")
}

$assets = [ordered]@{
  collectedAtKst = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time").ToString("o")
  sourceRepository = $SourceRepository
  branches = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/branches?per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ name = $item.name; sha = $item.commit.sha; protected = $item.protected } }
  tags = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/tags?per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ name = $item.name; sha = $item.commit.sha } }
  issues = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/issues?state=all&per_page=100" -Paginate) -Projector {
    param($item)
    if ($null -ne $item.PSObject.Properties["pull_request"]) { return $null }
    return [pscustomobject]@{ id = $item.id; number = $item.number; state = $item.state; createdAt = $item.created_at; closedAt = $item.closed_at }
  }
  pullRequests = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/pulls?state=all&per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ id = $item.id; number = $item.number; state = $item.state; mergedAt = $item.merged_at; mergeCommitSha = $item.merge_commit_sha; headSha = $item.head.sha; baseSha = $item.base.sha } }
  releases = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/releases?per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ id = $item.id; tagName = $item.tag_name; draft = $item.draft; prerelease = $item.prerelease; publishedAt = $item.published_at } }
  labels = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/labels?per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ id = $item.id; name = $item.name; color = $item.color; default = $item.default } }
  milestones = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/milestones?state=all&per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ id = $item.id; number = $item.number; state = $item.state; dueOn = $item.due_on } }
  environments = Protect-ObjectCollectionInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/environments?per_page=100") -CollectionProperty "environments" -Projector { param($item) [pscustomobject]@{ id = $item.id; name = $item.name; protectionRuleCount = @($item.protection_rules).Count } }
  actionsWorkflows = Protect-ObjectCollectionInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/actions/workflows?per_page=100") -CollectionProperty "workflows" -Projector { param($item) [pscustomobject]@{ id = $item.id; name = $item.name; path = $item.path; state = $item.state } }
  actionsVariables = Protect-VariableInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/actions/variables?per_page=100")
  actionsSecrets = Protect-SecretInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/actions/secrets?per_page=100")
  deployKeys = Protect-DeployKeyInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/keys?per_page=100" -Paginate)
  webhooks = Protect-WebhookInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/hooks?per_page=100" -Paginate)
  pages = Invoke-GhJson -Endpoint "repos/$SourceRepository/pages"
  collaborators = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/collaborators?affiliation=all&per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ login = $item.login; roleName = $item.role_name } }
  rulesets = Protect-ArrayInventory -Result (Invoke-GhJson -Endpoint "repos/$SourceRepository/rulesets?per_page=100" -Paginate) -Projector { param($item) [pscustomobject]@{ id = $item.id; name = $item.name; enforcement = $item.enforcement; sourceType = $item.source_type } }
  branchProtection = Invoke-GhJson -Endpoint "repos/$SourceRepository/branches/$defaultBranch/protection"
}

$localInventory = [ordered]@{
  collectedAtKst = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time").ToString("o")
  repositoryRoot = $repoRoot
  status = Invoke-NativeText -Command "git" -Arguments @("--no-optional-locks", "-C", $repoRoot, "status", "--porcelain=v2", "--branch")
  currentBranch = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "branch", "--show-current")
  remotes = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "remote", "-v")
  head = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "rev-parse", "HEAD")
  originMain = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "rev-parse", "--verify", "origin/main") -AllowFailure
  refs = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "for-each-ref", "--format=%(objectname) %(refname)", "refs/heads", "refs/remotes", "refs/tags")
  recentLog = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "log", "--oneline", "--decorate", "-20")
  objectCount = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "count-objects", "-vH")
  submodulesFileExists = Test-Path -LiteralPath (Join-Path $repoRoot ".gitmodules")
  lfsFiles = Invoke-NativeText -Command "git" -Arguments @("-C", $repoRoot, "lfs", "ls-files", "--all") -AllowFailure
  remoteHeadsAndTags = Invoke-NativeText -Command "git" -Arguments @("ls-remote", "--heads", "--tags", "https://github.com/$SourceRepository.git")
  fetchedOrPulled = $false
}

$repositoryPath = Join-Path $outputDirectoryFullPath "repository-before.json"
$assetsPath = Join-Path $outputDirectoryFullPath "github-assets-before.json"
$organizationPath = Join-Path $outputDirectoryFullPath "organization-access-before.json"
$localPath = Join-Path $outputDirectoryFullPath "local-repository-before.json"

$repositoryResult.data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $repositoryPath -Encoding UTF8
$assets | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $assetsPath -Encoding UTF8
$organizationAccess | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $organizationPath -Encoding UTF8
$localInventory | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $localPath -Encoding UTF8

$statusLines = @(
  "# Inventory 수집 상태",
  "",
  "- 수집 시각(KST): $($organizationAccess.collectedAtKst)",
  "- 원본 저장소: ``$SourceRepository``",
  "- 대상 Organization: ``$TargetOrganization``",
  "- 원격 변경: 수행하지 않음",
  "- ``git fetch``/``git pull``: 수행하지 않음",
  "- Secret 값: 저장하지 않음",
  "- Actions variable 값: 저장하지 않음",
  "- Webhook endpoint URL: 저장하지 않음",
  "",
  "## 생성 파일",
  "",
  "- ``repository-before.json``",
  "- ``github-assets-before.json``",
  "- ``organization-access-before.json``",
  "- ``local-repository-before.json``"
)
$statusLines | Set-Content -LiteralPath (Join-Path $outputDirectoryFullPath "inventory-collection-status.md") -Encoding UTF8

Write-Host "Inventory 수집을 완료했습니다: $outputDirectoryFullPath"
