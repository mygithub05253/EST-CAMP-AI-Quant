[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [ValidateSet("PreTransfer", "PostTransfer", "Backup")]
  [string]$Mode = "PreTransfer",
  [string]$SourceRepository = "mygithub05253/EST-CAMP-AI-Quant",
  [string]$TargetRepository = "EST-Bootcamp-AI-Quant/EST-CAMP-AI-Quant",
  [string]$RepositoryRoot = "",
  [string]$BeforeRepositoryPath = "",
  [string]$BackupManifestPath = "",
  [string]$BackupSetPath = "",
  [string]$OutputDirectory = "",
  [switch]$VerifyCurrentSource,
  [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:GIT_OPTIONAL_LOCKS = "0"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrationDirectory = Split-Path -Parent $scriptDirectory
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  $RepositoryRoot = Split-Path -Parent $migrationDirectory
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $migrationDirectory "reports"
}
if ([string]::IsNullOrWhiteSpace($BeforeRepositoryPath)) {
  $BeforeRepositoryPath = Join-Path $OutputDirectory "repository-before.json"
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

function Invoke-NativeCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [switch]$AllowNonZero
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

    if (($exitCode -ne 0) -and (-not $AllowNonZero)) {
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

  $result = Invoke-NativeCommand -Command "gh" -Arguments $arguments -AllowNonZero
  if ($result.exitCode -ne 0) {
    return [pscustomobject]@{
      status = "UNKNOWN"
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
      status = "PASS"
      endpoint = $Endpoint
      exitCode = 0
      error = $null
      data = $data
    }
  }
  catch {
    return [pscustomobject]@{
      status = "UNKNOWN"
      endpoint = $Endpoint
      exitCode = 0
      error = ConvertTo-SafeText -Text $_.Exception.Message
      data = $null
    }
  }
}

function Add-ValidationCheck {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][ValidateSet("PASS", "FAIL", "WARN", "UNKNOWN", "SKIP")][string]$Status,
    [Parameter(Mandatory = $true)][bool]$Critical,
    [AllowNull()][string]$Expected,
    [AllowNull()][string]$Actual,
    [AllowNull()][string]$Details
  )

  [void]$Checks.Add([pscustomobject]@{
    name = $Name
    status = $Status
    critical = $Critical
    expected = ConvertTo-SafeText -Text $Expected
    actual = ConvertTo-SafeText -Text $Actual
    details = ConvertTo-SafeText -Text $Details
  })
}

function Get-ComparableRefs {
  param([Parameter(Mandatory = $true)][string]$Text)

  $refs = @()
  foreach ($line in ($Text -split "`r?`n")) {
    if (($line -notmatch '\^\{\}$') -and ($line -match '^([0-9a-fA-F]{40,64})\s+(refs/(?:heads|tags)/\S+)$')) {
      $refs += "$($Matches[2])`t$($Matches[1].ToLowerInvariant())"
    }
  }
  return @($refs | Sort-Object -Unique)
}

function Get-RepositorySnapshot {
  param([Parameter(Mandatory = $true)][string]$Repository)

  $repositoryResult = Invoke-GhJson -Endpoint "repos/$Repository"
  if ($repositoryResult.status -ne "PASS") {
    return [pscustomobject]@{
      status = "UNKNOWN"
      error = $repositoryResult.error
      repository = $null
    }
  }

  $repo = $repositoryResult.data
  $defaultBranch = $repo.default_branch
  $permissions = Get-OptionalPropertyValue -Object $repo -Name "permissions"
  $branchRefResult = Invoke-GhJson -Endpoint "repos/$Repository/git/ref/heads/$defaultBranch"
  if ($branchRefResult.status -ne "PASS") {
    return [pscustomobject]@{
      status = "UNKNOWN"
      error = $branchRefResult.error
      repository = $null
    }
  }

  return [pscustomobject]@{
    status = "PASS"
    error = $null
    repository = [pscustomobject]@{
      id = $repo.id
      nodeId = $repo.node_id
      fullName = $repo.full_name
      owner = $repo.owner.login
      visibility = $repo.visibility
      defaultBranch = $defaultBranch
      mainSha = $branchRefResult.data.object.sha
      sizeKb = $repo.size
      isFork = $repo.fork
      archived = $repo.archived
      hasIssues = $repo.has_issues
      hasProjects = $repo.has_projects
      hasWiki = $repo.has_wiki
      hasPages = $repo.has_pages
      hasDiscussions = $repo.has_discussions
      allowMergeCommit = $repo.allow_merge_commit
      allowSquashMerge = $repo.allow_squash_merge
      allowRebaseMerge = $repo.allow_rebase_merge
      allowAutoMerge = $repo.allow_auto_merge
      deleteBranchOnMerge = $repo.delete_branch_on_merge
      permissions = [pscustomobject]@{
        admin = Get-OptionalPropertyValue -Object $permissions -Name "admin"
        push = Get-OptionalPropertyValue -Object $permissions -Name "push"
        pull = Get-OptionalPropertyValue -Object $permissions -Name "pull"
      }
    }
  }
}

function Convert-ItemsToKeys {
  param(
    [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()]$Items,
    [Parameter(Mandatory = $true)][scriptblock]$Selector
  )

  $keys = @()
  foreach ($item in @($Items)) {
    if ($null -eq $item) {
      continue
    }
    $value = & $Selector $item
    if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
      $keys += [string]$value
    }
  }
  return @($keys | Sort-Object -Unique)
}

function New-AssetRecord {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][pscustomobject]$Result,
    [Parameter(Mandatory = $true)][scriptblock]$Selector,
    [string]$CollectionProperty = ""
  )

  if ($Result.status -ne "PASS") {
    return [pscustomobject]@{
      name = $Name
      status = "UNKNOWN"
      keys = @()
      error = $Result.error
    }
  }

  $items = $Result.data
  if (-not [string]::IsNullOrWhiteSpace($CollectionProperty)) {
    $items = Get-OptionalPropertyValue -Object $Result.data -Name $CollectionProperty
  }

  try {
    $keys = @(Convert-ItemsToKeys -Items $items -Selector $Selector)
  }
  catch {
    $itemProperties = @()
    foreach ($candidate in @($items)) {
      if ($null -ne $candidate) {
        $itemProperties += "[$($candidate.PSObject.Properties.Name -join ',')]"
      }
    }
    throw "자산 '$Name' key projection 실패: $($_.Exception.Message); properties=$($itemProperties -join ';')"
  }

  return [pscustomobject]@{
    name = $Name
    status = "PASS"
    keys = $keys
    error = $null
  }
}

function Get-AssetSnapshot {
  param([Parameter(Mandatory = $true)][string]$Repository)

  $branches = New-AssetRecord -Name "branches" -Result (Invoke-GhJson -Endpoint "repos/$Repository/branches?per_page=100" -Paginate) -Selector { param($item) "$($item.name)|$($item.commit.sha)" }
  $tags = New-AssetRecord -Name "tags" -Result (Invoke-GhJson -Endpoint "repos/$Repository/tags?per_page=100" -Paginate) -Selector { param($item) "$($item.name)|$($item.commit.sha)" }
  $issues = New-AssetRecord -Name "issues" -Result (Invoke-GhJson -Endpoint "repos/$Repository/issues?state=all&per_page=100" -Paginate) -Selector {
    param($item)
    if ($null -ne $item.PSObject.Properties["pull_request"]) { return "" }
    return "$($item.id)|$($item.number)|$($item.state)"
  }
  $pulls = New-AssetRecord -Name "pullRequests" -Result (Invoke-GhJson -Endpoint "repos/$Repository/pulls?state=all&per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.number)|$($item.state)|$($item.merged_at)|$($item.merge_commit_sha)" }
  $releases = New-AssetRecord -Name "releases" -Result (Invoke-GhJson -Endpoint "repos/$Repository/releases?per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.tag_name)|$($item.draft)|$($item.prerelease)" }
  $labels = New-AssetRecord -Name "labels" -Result (Invoke-GhJson -Endpoint "repos/$Repository/labels?per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.name)|$($item.color)" }
  $milestones = New-AssetRecord -Name "milestones" -Result (Invoke-GhJson -Endpoint "repos/$Repository/milestones?state=all&per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.number)|$($item.state)" }
  $workflows = New-AssetRecord -Name "workflows" -Result (Invoke-GhJson -Endpoint "repos/$Repository/actions/workflows?per_page=100") -CollectionProperty "workflows" -Selector { param($item) "$($item.id)|$($item.path)|$($item.state)" }
  $environments = New-AssetRecord -Name "environments" -Result (Invoke-GhJson -Endpoint "repos/$Repository/environments?per_page=100") -CollectionProperty "environments" -Selector { param($item) "$($item.id)|$($item.name)" }
  $secrets = New-AssetRecord -Name "actionsSecrets" -Result (Invoke-GhJson -Endpoint "repos/$Repository/actions/secrets?per_page=100") -CollectionProperty "secrets" -Selector { param($item) "$($item.name)" }
  $variables = New-AssetRecord -Name "actionsVariables" -Result (Invoke-GhJson -Endpoint "repos/$Repository/actions/variables?per_page=100") -CollectionProperty "variables" -Selector { param($item) "$($item.name)" }
  $deployKeys = New-AssetRecord -Name "deployKeys" -Result (Invoke-GhJson -Endpoint "repos/$Repository/keys?per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.title)|$($item.read_only)" }
  $hooks = New-AssetRecord -Name "webhooks" -Result (Invoke-GhJson -Endpoint "repos/$Repository/hooks?per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.name)|$($item.active)|$(@($item.events) -join ',')" }
  $rulesets = New-AssetRecord -Name "rulesets" -Result (Invoke-GhJson -Endpoint "repos/$Repository/rulesets?per_page=100" -Paginate) -Selector { param($item) "$($item.id)|$($item.name)|$($item.enforcement)" }
  $collaborators = New-AssetRecord -Name "collaborators" -Result (Invoke-GhJson -Endpoint "repos/$Repository/collaborators?affiliation=all&per_page=100" -Paginate) -Selector { param($item) "$($item.login)|$($item.role_name)" }
  $pagesResult = Invoke-GhJson -Endpoint "repos/$Repository/pages"
  $pagesStatus = if ($pagesResult.status -eq "PASS") { "configured" } else { "not-configured-or-inaccessible" }

  return [pscustomobject]@{
    collectedAtKst = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time").ToString("o")
    repository = $Repository
    assets = @($branches, $tags, $issues, $pulls, $releases, $labels, $milestones, $workflows, $environments, $secrets, $variables, $deployKeys, $hooks, $rulesets, $collaborators)
    pages = [pscustomobject]@{
      status = $pagesStatus
      apiStatus = $pagesResult.status
      error = $pagesResult.error
    }
  }
}

function Test-BackupManifest {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$RemoteUrl,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Add-ValidationCheck -Checks $Checks -Name "백업 manifest" -Status "FAIL" -Critical $true -Expected "존재" -Actual "없음" -Details $ManifestPath
    return $null
  }

  $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
  $setRoot = Split-Path -Parent $ManifestPath
  $completePath = Join-Path $setRoot "complete.json"
  $mirrorPath = Join-Path $setRoot "EST-CAMP-AI-Quant.git"
  $bundlePath = Join-Path $setRoot "EST-CAMP-AI-Quant-before-transfer.bundle"
  $emptyVerifyPath = Join-Path $setRoot "bundle-prerequisite-verification.git"
  $restorePath = Join-Path $setRoot "bundle-restore-verification.git"

  $requiredPaths = @($completePath, $mirrorPath, $bundlePath, $emptyVerifyPath, $restorePath)
  $missingPaths = @($requiredPaths | Where-Object { -not (Test-Path -LiteralPath $_) })
  if ($missingPaths.Count -gt 0) {
    Add-ValidationCheck -Checks $Checks -Name "백업 세트 완전성" -Status "FAIL" -Critical $true -Expected "필수 산출물 전체" -Actual "누락 $($missingPaths.Count)개" -Details ($missingPaths -join "; ")
    return $manifest
  }

  $headStatus = if ($manifest.sourceHeadSha -eq $ExpectedHeadSha) { "PASS" } else { "FAIL" }
  Add-ValidationCheck -Checks $Checks -Name "백업 HEAD SHA" -Status $headStatus -Critical $true -Expected $ExpectedHeadSha -Actual $manifest.sourceHeadSha -Details ""

  try {
    Invoke-NativeCommand -Command "git" -Arguments @("-C", $mirrorPath, "fsck", "--full", "--strict") | Out-Null
    Invoke-NativeCommand -Command "git" -Arguments @("-C", $emptyVerifyPath, "bundle", "verify", $bundlePath) | Out-Null
    Invoke-NativeCommand -Command "git" -Arguments @("-C", $restorePath, "fsck", "--full", "--strict") | Out-Null
    $bundleHash = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($bundleHash -ne $manifest.bundleSha256) {
      throw "Bundle SHA256 불일치"
    }
    $mirrorRefs = Get-ComparableRefs -Text (Invoke-NativeCommand -Command "git" -Arguments @("-C", $mirrorPath, "show-ref")).stdout
    $restoreRefs = Get-ComparableRefs -Text (Invoke-NativeCommand -Command "git" -Arguments @("-C", $restorePath, "show-ref")).stdout
    $remoteRefs = Get-ComparableRefs -Text (Invoke-NativeCommand -Command "git" -Arguments @("ls-remote", "--heads", "--tags", $RemoteUrl)).stdout
    $restoreDifference = @(Compare-Object -ReferenceObject $mirrorRefs -DifferenceObject $restoreRefs)
    $remoteDifference = @(Compare-Object -ReferenceObject $mirrorRefs -DifferenceObject $remoteRefs)
    if (($restoreDifference.Count -gt 0) -or ($remoteDifference.Count -gt 0)) {
      throw "Mirror/복원/원격 ref 불일치"
    }
    Add-ValidationCheck -Checks $Checks -Name "Mirror·Bundle 복원 무결성" -Status "PASS" -Critical $true -Expected "fsck/verify/ref exact/hash 성공" -Actual "성공" -Details ""
  }
  catch {
    Add-ValidationCheck -Checks $Checks -Name "Mirror·Bundle 복원 무결성" -Status "FAIL" -Critical $true -Expected "fsck/verify/ref exact/hash 성공" -Actual "실패" -Details $_.Exception.Message
  }

  return $manifest
}

function Get-BackupModeRequiredProperty {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    throw "필수 백업 속성이 없습니다: $Name"
  }
  return $property.Value
}

function Add-BackupModeCondition {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Expected,
    [Parameter(Mandatory = $true)][string]$Actual,
    [string]$Details = ""
  )

  Add-ValidationCheck `
    -Checks $Checks `
    -Name $Name `
    -Status $(if ($Condition) { "PASS" } else { "FAIL" }) `
    -Critical $true `
    -Expected $Expected `
    -Actual $Actual `
    -Details $Details
}

function Resolve-BackupModeChildPath {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [ValidateSet("Any", "Leaf", "Container")][string]$PathType = "Any"
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath)) {
    throw "백업 내부 상대경로가 비어 있습니다."
  }
  $normalized = $RelativePath.Replace('\', '/')
  if (
    [System.IO.Path]::IsPathRooted($RelativePath) -or
    $normalized.StartsWith('/') -or
    ($normalized -match '(^|/)\.\.(/|$)') -or
    ($normalized -match '(^|/)\.(/|$)') -or
    ($normalized -match ':')
  ) {
    throw "안전하지 않은 백업 내부 상대경로입니다: $RelativePath"
  }

  $fullPath = Resolve-BackupPath -Path (Join-Path $SetRoot $RelativePath)
  if (-not (Test-BackupPathStrictChild -Candidate $fullPath -Parent $SetRoot)) {
    throw "백업 세트 밖을 가리키는 상대경로입니다: $RelativePath"
  }
  if (($PathType -eq "Leaf") -and (-not (Test-Path -LiteralPath $fullPath -PathType Leaf))) {
    throw "백업 필수 파일이 없습니다: $RelativePath"
  }
  if (($PathType -eq "Container") -and (-not (Test-Path -LiteralPath $fullPath -PathType Container))) {
    throw "백업 필수 디렉터리가 없습니다: $RelativePath"
  }
  if (($PathType -eq "Any") -and (-not (Test-Path -LiteralPath $fullPath))) {
    throw "백업 필수 경로가 없습니다: $RelativePath"
  }
  return $fullPath
}

function Read-BackupModeJson {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $path = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath $RelativePath -PathType Leaf
  try {
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
  }
  catch {
    throw "백업 JSON을 읽을 수 없습니다($RelativePath): $($_.Exception.Message)"
  }
}

function ConvertTo-BackupModeRemoteRefs {
  param([Parameter(Mandatory = $true)]$Inventory)

  $refs = New-Object 'System.Collections.Generic.List[string]'
  foreach ($entry in @(Get-BackupModeRequiredProperty -Object $Inventory -Name "refs")) {
    $line = [string]$entry
    if ($line -notmatch '^(refs/\S+)\t([0-9a-fA-F]{40,64})$') {
      throw "원격 ref manifest 형식이 올바르지 않습니다."
    }
    $refs.Add("$($Matches[1])`t$($Matches[2].ToLowerInvariant())")
  }
  $ordered = @($refs | Sort-Object -Unique)
  if ($ordered.Count -ne $refs.Count) {
    throw "원격 ref manifest에 중복 항목이 있습니다."
  }
  return $ordered
}

function ConvertTo-BackupModeLocalRefTriples {
  param([Parameter(Mandatory = $true)]$Inventory)

  $refs = New-Object 'System.Collections.Generic.List[string]'
  foreach ($ref in @(Get-BackupModeRequiredProperty -Object $Inventory -Name "refs")) {
    $refName = [string](Get-BackupModeRequiredProperty -Object $ref -Name "refName")
    $objectId = [string](Get-BackupModeRequiredProperty -Object $ref -Name "objectId")
    $objectType = [string](Get-BackupModeRequiredProperty -Object $ref -Name "objectType")
    if (($refName -notmatch '^refs/\S+$') -or ($objectId -notmatch '^[0-9a-fA-F]{40,64}$') -or [string]::IsNullOrWhiteSpace($objectType)) {
      throw "로컬 ref manifest 형식이 올바르지 않습니다."
    }
    $refs.Add("$refName`t$($objectId.ToLowerInvariant())`t$objectType")
  }
  $ordered = @($refs | Sort-Object -Unique)
  if ($ordered.Count -ne $refs.Count) {
    throw "로컬 ref manifest에 중복 항목이 있습니다."
  }
  return $ordered
}

function ConvertTo-BackupModeLocalRefPairs {
  param([Parameter(Mandatory = $true)]$Inventory)

  return @(Get-BackupModeRequiredProperty -Object $Inventory -Name "refs" | ForEach-Object {
    "$([string]$_.refName)`t$([string]$_.objectId)"
  } | Sort-Object -Unique)
}

function Compare-BackupModeLfsManifests {
  param(
    [Parameter(Mandatory = $true)]$Reference,
    [Parameter(Mandatory = $true)]$Difference
  )

  return (
    ([int]$Reference.objectCount -eq [int]$Difference.objectCount) -and
    ([int64]$Reference.objectBytes -eq [int64]$Difference.objectBytes) -and
    ([string]$Reference.digest -eq [string]$Difference.digest) -and
    ([int]$Reference.invalidOidPathCount -eq 0) -and
    ([int]$Reference.oidHashMismatchCount -eq 0) -and
    ([int]$Difference.invalidOidPathCount -eq 0) -and
    ([int]$Difference.oidHashMismatchCount -eq 0)
  )
}

function Assert-BackupModeTreeExact {
  param(
    [Parameter(Mandatory = $true)]$Reference,
    [Parameter(Mandatory = $true)]$Difference,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $comparison = Compare-BackupTreeManifests -Reference $Reference -Difference $Difference
  if (-not $comparison.exact) {
    throw "$Label exact 비교 실패: missingDir=$($comparison.missingDirectoryCount), extraDir=$($comparison.extraDirectoryCount), missingFile=$($comparison.missingFileCount), extraFile=$($comparison.extraFileCount), size=$($comparison.sizeMismatchCount), hash=$($comparison.hashMismatchCount)"
  }
  return $comparison
}

function Test-BackupModeFlagSummary {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$Complete,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $manifestFlags = @(
    $Manifest.copyOnly,
    (-not $Manifest.sourceGitMutationPerformed),
    $Manifest.gitOptionalLocksDisabled,
    $Manifest.remote.mirrorFsckSucceeded,
    $Manifest.remote.bundleVerifySucceeded,
    $Manifest.remote.restoreFsckSucceeded,
    $Manifest.remote.mirrorBundleRefsEqual,
    $Manifest.remote.mirrorRestoreRefsEqual,
    $Manifest.remote.mirrorLiveRemoteRefsEqual,
    $Manifest.local.mirrorFsckSucceeded,
    $Manifest.local.rawGitSourceBeforeVsSnapshotExact,
    $Manifest.local.rawGitSourceStable,
    $Manifest.local.bundleVerifySucceeded,
    $Manifest.local.restoreFsckSucceeded,
    $Manifest.local.allRefsMirrorExact,
    $Manifest.local.refsExact,
    $Manifest.nonMigrationBaseline.exact,
    $Manifest.lfs.localObjectsCopiedExact,
    $Manifest.lfs.remoteObjectsCopiedExact,
    $Manifest.verificationSummary.remoteGitVerified,
    $Manifest.verificationSummary.localRefsVerified,
    $Manifest.verificationSummary.allWorktreesVerified,
    $Manifest.verificationSummary.workingTreesVerified,
    $Manifest.verificationSummary.lfsVerified,
    $Manifest.verificationSummary.sourceStable
  )
  $manifestMismatchTotal = [int]$Manifest.verificationSummary.missingTotal +
    [int]$Manifest.verificationSummary.extraTotal +
    [int]$Manifest.verificationSummary.sizeMismatchTotal +
    [int]$Manifest.verificationSummary.hashMismatchTotal
  $manifestPass = (@($manifestFlags | Where-Object { -not [bool]$_ }).Count -eq 0) -and ($manifestMismatchTotal -eq 0)
  Add-BackupModeCondition -Checks $Checks -Name "manifest 안정성·mismatch 요약" -Condition $manifestPass -Expected "모든 flag=true, mismatch=0" -Actual "flagsFalse=$(@($manifestFlags | Where-Object { -not [bool]$_ }).Count), mismatch=$manifestMismatchTotal"

  $completeFlags = @(
    $Complete.checksumsVerified,
    $Complete.requiredArtifactsVerified,
    $Complete.remoteGitVerified,
    $Complete.localRefsVerified,
    $Complete.allWorktreesVerified,
    $Complete.workingTreesVerified,
    $Complete.lfsVerified,
    $Complete.sourceStable
  )
  $completeMismatchTotal = [int]$Complete.missingTotal + [int]$Complete.extraTotal + [int]$Complete.sizeMismatchTotal + [int]$Complete.hashMismatchTotal
  $completePass = (@($completeFlags | Where-Object { -not [bool]$_ }).Count -eq 0) -and ($completeMismatchTotal -eq 0)
  Add-BackupModeCondition -Checks $Checks -Name "complete 안정성·mismatch 요약" -Condition $completePass -Expected "모든 flag=true, mismatch=0" -Actual "flagsFalse=$(@($completeFlags | Where-Object { -not [bool]$_ }).Count), mismatch=$completeMismatchTotal"
}

function Test-BackupModeChecksums {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$Complete,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $manifestPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath "manifest.json" -PathType Leaf
  $manifestHash = Get-BackupFileSha256 -Path $manifestPath
  Add-BackupModeCondition -Checks $Checks -Name "manifest SHA-256" -Condition ($manifestHash -eq [string]$Complete.manifestSha256) -Expected ([string]$Complete.manifestSha256) -Actual $manifestHash

  $checksumsRelativePath = [string](Get-BackupModeRequiredProperty -Object $Manifest -Name "checksumsPath")
  $checksumsPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath $checksumsRelativePath -PathType Leaf
  $checksumsHash = Get-BackupFileSha256 -Path $checksumsPath
  Add-BackupModeCondition -Checks $Checks -Name "SHA256SUMS 자체 SHA-256" -Condition ($checksumsHash -eq [string]$Complete.checksumsSha256) -Expected ([string]$Complete.checksumsSha256) -Actual $checksumsHash

  $requiredArtifactKeys = @(
    "remoteRefsBefore", "remoteRefsMirror", "remoteRefsBundle", "remoteRefsRestore", "remoteRefsAfter",
    "localRefsBefore", "localRefsMirror", "localRefsAfter",
    "worktreesBefore", "worktreesAfter", "nonMigrationBefore", "nonMigrationAfter",
    "gitCommonBefore", "gitCommonSnapshot", "gitCommonAfter",
    "localLfsBefore", "localLfsSnapshot", "localLfsAfter",
    "remoteLfsBefore", "remoteLfsSnapshot", "remoteLfsAfter"
  )
  $actualArtifactKeys = @($Manifest.artifacts.PSObject.Properties.Name | Sort-Object -Unique)
  $artifactKeyComparison = Compare-BackupStringSets -Reference $requiredArtifactKeys -Difference $actualArtifactKeys
  Add-BackupModeCondition -Checks $Checks -Name "manifest artifact key exact-set" -Condition $artifactKeyComparison.exact -Expected "$($requiredArtifactKeys.Count)개" -Actual "$($actualArtifactKeys.Count)개" -Details "difference=$($artifactKeyComparison.differenceCount)"

  $expectedEntries = New-Object 'System.Collections.Generic.List[string]'
  foreach ($relativePath in @("manifest.json", "remote/EST-CAMP-AI-Quant-before-transfer.bundle", "local/local-state-before-transfer.bundle")) {
    $expectedEntries.Add($relativePath)
  }
  foreach ($property in @($Manifest.artifacts.PSObject.Properties)) {
    $relativePath = ([string]$property.Value).Replace('\', '/')
    Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath $relativePath -PathType Leaf | Out-Null
    $expectedEntries.Add($relativePath)
  }
  foreach ($worktree in @($Manifest.worktrees)) {
    foreach ($propertyName in @("sourceBeforeManifestPath", "snapshotManifestPath", "sourceAfterManifestPath")) {
      $relativePath = ([string](Get-BackupModeRequiredProperty -Object $worktree -Name $propertyName)).Replace('\', '/')
      Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath $relativePath -PathType Leaf | Out-Null
      $expectedEntries.Add($relativePath)
    }
  }
  $expectedEntryList = @($expectedEntries | Sort-Object -Unique)
  if ($expectedEntryList.Count -ne $expectedEntries.Count) {
    throw "필수 checksum 경로에 중복 항목이 있습니다."
  }
  $declaredEntries = @($Manifest.requiredChecksumEntries | ForEach-Object { ([string]$_).Replace('\', '/') } | Sort-Object -Unique)
  $declaredComparison = Compare-BackupStringSets -Reference $expectedEntryList -Difference $declaredEntries
  Add-BackupModeCondition -Checks $Checks -Name "manifest checksum 필수 목록 exact-set" -Condition $declaredComparison.exact -Expected "$($expectedEntryList.Count)개" -Actual "$($declaredEntries.Count)개" -Details "difference=$($declaredComparison.differenceCount)"

  $parsedPaths = New-Object 'System.Collections.Generic.List[string]'
  $checksumFailures = New-Object 'System.Collections.Generic.List[string]'
  foreach ($line in @(Get-Content -LiteralPath $checksumsPath -Encoding ASCII)) {
    if ($line -notmatch '^([0-9a-f]{64}) \*(.+)$') {
      throw "SHA256SUMS 형식이 올바르지 않습니다."
    }
    $expectedHash = $Matches[1]
    $relativePath = $Matches[2].Replace('\', '/')
    if (@($parsedPaths | Where-Object { $_.Equals($relativePath, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
      throw "SHA256SUMS에 중복 경로가 있습니다."
    }
    $artifactPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath $relativePath -PathType Leaf
    $actualHash = Get-BackupFileSha256 -Path $artifactPath
    if ($actualHash -ne $expectedHash) {
      $checksumFailures.Add($relativePath)
    }
    $parsedPaths.Add($relativePath)
  }
  $parsedComparison = Compare-BackupStringSets -Reference $declaredEntries -Difference @($parsedPaths | Sort-Object -Unique)
  $checksumPass = $parsedComparison.exact -and ($checksumFailures.Count -eq 0)
  Add-BackupModeCondition -Checks $Checks -Name "SHA256SUMS exact-set·파일 해시" -Condition $checksumPass -Expected "$($declaredEntries.Count)개 모두 일치" -Actual "entries=$($parsedPaths.Count), hashMismatch=$($checksumFailures.Count), setDifference=$($parsedComparison.differenceCount)"
}

function Test-BackupModeRemoteGit {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $before = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.remoteRefsBefore)
  $storedMirror = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.remoteRefsMirror)
  $storedBundle = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.remoteRefsBundle)
  $storedRestore = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.remoteRefsRestore)
  $after = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.remoteRefsAfter)
  $beforeRefs = @(ConvertTo-BackupModeRemoteRefs -Inventory $before)
  $storedMirrorRefs = @(ConvertTo-BackupModeRemoteRefs -Inventory $storedMirror)
  $storedBundleRefs = @(ConvertTo-BackupModeRemoteRefs -Inventory $storedBundle)
  $storedRestoreRefs = @(ConvertTo-BackupModeRemoteRefs -Inventory $storedRestore)
  $afterRefs = @(ConvertTo-BackupModeRemoteRefs -Inventory $after)

  $mirrorPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.remote.mirrorPath) -PathType Container
  $bundlePath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.remote.bundlePath) -PathType Leaf
  $restorePath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.remote.restorePath) -PathType Container
  $verifyPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath "remote/bundle-prerequisite-verification.git" -PathType Container

  Invoke-BackupGit -RepositoryPath $mirrorPath -Arguments @("fsck", "--full", "--strict") | Out-Null
  Invoke-BackupGit -RepositoryPath $verifyPath -Arguments @("bundle", "verify", $bundlePath) | Out-Null
  Invoke-BackupGit -RepositoryPath $restorePath -Arguments @("fsck", "--full", "--strict") | Out-Null
  $actualMirrorRefs = @(ConvertTo-BackupComparableRefs -Lines (Invoke-BackupGit -RepositoryPath $mirrorPath -Arguments @("show-ref")).lines)
  $actualBundleRefs = @(ConvertTo-BackupComparableRefs -Lines (Invoke-BackupGit -Arguments @("bundle", "list-heads", $bundlePath)).lines)
  $actualRestoreRefs = @(ConvertTo-BackupComparableRefs -Lines (Invoke-BackupGit -RepositoryPath $restorePath -Arguments @("show-ref")).lines)

  $allExact =
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $afterRefs).exact -and
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $storedMirrorRefs).exact -and
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $storedBundleRefs).exact -and
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $storedRestoreRefs).exact -and
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $actualMirrorRefs).exact -and
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $actualBundleRefs).exact -and
    (Compare-BackupStringSets -Reference $beforeRefs -Difference $actualRestoreRefs).exact
  $refText = if ($beforeRefs.Count -gt 0) { ($beforeRefs -join "`n") + "`n" } else { "" }
  $actualDigest = Get-BackupTextSha256 -Text $refText
  $countPass =
    ($beforeRefs.Count -eq [int]$Manifest.remoteRefCount) -and
    (@($beforeRefs | Where-Object { $_ -match '^refs/heads/' }).Count -eq [int]$Manifest.remoteBranchCount) -and
    (@($beforeRefs | Where-Object { $_ -match '^refs/tags/' }).Count -eq [int]$Manifest.remoteTagCount) -and
    (@($beforeRefs | Where-Object { $_ -match '^refs/pull/' }).Count -eq [int]$Manifest.remotePullRefCount)
  $hashPass = (Get-BackupFileSha256 -Path $bundlePath) -eq [string]$Manifest.remote.bundleSha256
  Add-BackupModeCondition -Checks $Checks -Name "Remote mirror·bundle·restore fsck/ref exact" -Condition ($allExact -and $countPass -and $hashPass -and ($actualDigest -eq [string]$Manifest.remoteRefDigest)) -Expected "source-before/after 및 실제 3종 ref exact" -Actual "refs=$($beforeRefs.Count), exact=$allExact, count=$countPass, hash=$hashPass"
}

function Test-BackupModeLocalGit {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $before = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.localRefsBefore)
  $storedMirror = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.localRefsMirror)
  $after = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.localRefsAfter)
  $beforeTriples = @(ConvertTo-BackupModeLocalRefTriples -Inventory $before)
  $storedMirrorTriples = @(ConvertTo-BackupModeLocalRefTriples -Inventory $storedMirror)
  $afterTriples = @(ConvertTo-BackupModeLocalRefTriples -Inventory $after)

  $mirrorPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.local.mirrorPath) -PathType Container
  $bundlePath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.local.bundlePath) -PathType Leaf
  $restorePath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.local.restorePath) -PathType Container
  $verifyPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath "local/bundle-prerequisite-verification.git" -PathType Container

  Invoke-BackupGit -RepositoryPath $mirrorPath -Arguments @("fsck", "--full", "--strict") | Out-Null
  Invoke-BackupGit -RepositoryPath $verifyPath -Arguments @("bundle", "verify", $bundlePath) | Out-Null
  Invoke-BackupGit -RepositoryPath $restorePath -Arguments @("fsck", "--full", "--strict") | Out-Null
  $actualMirror = Get-BackupRefs -RepositoryPath $mirrorPath
  $actualMirrorTriples = @(ConvertTo-BackupModeLocalRefTriples -Inventory $actualMirror)
  $actualBundlePairs = @(ConvertTo-BackupComparableRefs -Lines (Invoke-BackupGit -Arguments @("bundle", "list-heads", $bundlePath)).lines)
  $actualRestorePairs = @(ConvertTo-BackupComparableRefs -Lines (Invoke-BackupGit -RepositoryPath $restorePath -Arguments @("show-ref")).lines)

  $compatiblePairs = New-Object 'System.Collections.Generic.List[string]'
  $excludedTriples = New-Object 'System.Collections.Generic.List[string]'
  foreach ($ref in @($before.refs)) {
    $refName = [string]$ref.refName
    $objectId = ([string]$ref.objectId).ToLowerInvariant()
    $commitProbe = Invoke-BackupGit -RepositoryPath $mirrorPath -Arguments @("rev-parse", "--verify", "$refName^{commit}") -AllowNonZero
    if ($commitProbe.exitCode -eq 0) {
      $compatiblePairs.Add("$refName`t$objectId")
    }
    else {
      $objectProbe = Invoke-BackupGit -RepositoryPath $mirrorPath -Arguments @("cat-file", "-e", $objectId) -AllowNonZero
      if ($objectProbe.exitCode -ne 0) {
        throw "Local non-commit ref object가 exact mirror에 없습니다."
      }
      $excludedTriples.Add("$refName`t$objectId`t$([string]$ref.objectType)")
    }
  }
  $declaredExcluded = @($Manifest.local.bundleExcludedNonCommitRefs | ForEach-Object {
    "$([string]$_.refName)`t$(([string]$_.objectId).ToLowerInvariant())`t$([string]$_.objectType)"
  } | Sort-Object -Unique)
  $compatible = @($compatiblePairs | Sort-Object -Unique)
  $excluded = @($excludedTriples | Sort-Object -Unique)
  $localRefsExact =
    (Compare-BackupStringSets -Reference $beforeTriples -Difference $storedMirrorTriples).exact -and
    (Compare-BackupStringSets -Reference $beforeTriples -Difference $afterTriples).exact -and
    (Compare-BackupStringSets -Reference $beforeTriples -Difference $actualMirrorTriples).exact
  $bundleExact =
    (Compare-BackupStringSets -Reference $compatible -Difference $actualBundlePairs).exact -and
    (Compare-BackupStringSets -Reference $compatible -Difference $actualRestorePairs).exact -and
    (Compare-BackupStringSets -Reference $excluded -Difference $declaredExcluded).exact
  $countPass =
    ($beforeTriples.Count -eq [int]$Manifest.localRefCount) -and
    (@($before.refs | Where-Object { $_.refName -match '^refs/heads/' }).Count -eq [int]$Manifest.localBranchCount) -and
    (@($before.refs | Where-Object { $_.refName -match '^refs/remotes/' }).Count -eq [int]$Manifest.remoteTrackingRefCount) -and
    (@($before.refs | Where-Object { $_.refName -match '^refs/tags/' }).Count -eq [int]$Manifest.tagCount) -and
    (@($before.refs | Where-Object { $_.refName -eq 'refs/stash' }).Count -eq [int]$Manifest.stashRefCount) -and
    (@($before.refs | Where-Object { $_.refName -match '^refs/codex/' }).Count -eq [int]$Manifest.codexRefCount) -and
    ($compatible.Count -eq [int]$Manifest.local.bundleCompatibleRefCount)
  $hashPass = (Get-BackupFileSha256 -Path $bundlePath) -eq [string]$Manifest.local.bundleSha256
  $digestPass =
    ([string]$before.digest -eq [string]$Manifest.localRefDigest) -and
    ([string]$before.digest -eq [string]$Manifest.local.refsSourceBeforeDigest) -and
    ([string]$storedMirror.digest -eq [string]$Manifest.local.refsMirrorDigest) -and
    ([string]$after.digest -eq [string]$Manifest.local.refsSourceAfterDigest) -and
    ([string]$actualMirror.digest -eq [string]$before.digest)
  Add-BackupModeCondition -Checks $Checks -Name "Local exact mirror 전체 ref(stash/codex 포함)" -Condition ($localRefsExact -and $countPass -and $digestPass) -Expected "$($beforeTriples.Count)개 ref exact" -Actual "exact=$localRefsExact, count=$countPass, digest=$digestPass"
  Add-BackupModeCondition -Checks $Checks -Name "Local bundle·restore commit-compatible ref exact" -Condition ($bundleExact -and $hashPass) -Expected "compatible=$($compatible.Count), excluded=$($excluded.Count)" -Actual "bundleExact=$bundleExact, hash=$hashPass"
}

function Get-BackupModeWorktreeDigest {
  param([Parameter(Mandatory = $true)]$Inventory)

  $lines = @($Inventory.worktrees | ForEach-Object {
    "$($_.id)`t$($_.sourcePath)`t$($_.headSha)`t$($_.branchRef)`t$($_.detached)`t$($_.indexSha256)`t$($_.statusDigest)"
  })
  $text = if ($lines.Count -gt 0) { ($lines -join "`n") + "`n" } else { "" }
  return Get-BackupTextSha256 -Text $text
}

function Test-BackupModeTreeState {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)][string]$CurrentRepositoryRoot,
    [Parameter(Mandatory = $true)][bool]$MeasureCurrentSource,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $gitBefore = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.gitCommonBefore)
  $gitSnapshot = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.gitCommonSnapshot)
  $gitAfter = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.gitCommonAfter)
  $gitSnapshotPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.local.rawGitSnapshotPath) -PathType Container
  $gitSnapshotMeasured = Get-BackupTreeManifest -RootPath $gitSnapshotPath -ExcludeGitEntries $false
  Assert-BackupModeTreeExact -Reference $gitBefore -Difference $gitSnapshot -Label "raw .git source-before/snapshot manifest" | Out-Null
  Assert-BackupModeTreeExact -Reference $gitBefore -Difference $gitAfter -Label "raw .git source-before/source-after" | Out-Null
  Assert-BackupModeTreeExact -Reference $gitSnapshot -Difference $gitSnapshotMeasured -Label "raw .git snapshot 현재 재해시" | Out-Null
  Add-BackupModeCondition -Checks $Checks -Name "Raw .git snapshot exact" -Condition (($gitSnapshotMeasured.reparsePointCount -eq 0) -and $Manifest.local.rawGitSourceBeforeVsSnapshotExact -and $Manifest.local.rawGitSourceStable) -Expected "before=snapshot=after, reparse=0" -Actual "files=$($gitSnapshot.fileCount), bytes=$($gitSnapshot.sizeBytes), reparse=$($gitSnapshotMeasured.reparsePointCount)"

  $worktreesBefore = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.worktreesBefore)
  $worktreesAfter = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.worktreesAfter)
  $beforeDigest = Get-BackupModeWorktreeDigest -Inventory $worktreesBefore
  $afterDigest = Get-BackupModeWorktreeDigest -Inventory $worktreesAfter
  $inventoryPass =
    ([int]$worktreesBefore.worktreeCount -eq 4) -and
    ([int]$worktreesAfter.worktreeCount -eq 4) -and
    ([int]$Manifest.worktreeCount -eq 4) -and
    (@($Manifest.worktrees).Count -eq 4) -and
    ($beforeDigest -eq [string]$worktreesBefore.digest) -and
    ($afterDigest -eq [string]$worktreesAfter.digest) -and
    ($beforeDigest -eq $afterDigest)
  Add-BackupModeCondition -Checks $Checks -Name "Worktree inventory source 안정성" -Condition $inventoryPass -Expected "4개 before/after exact" -Actual "before=$($worktreesBefore.worktreeCount), after=$($worktreesAfter.worktreeCount), manifest=$(@($Manifest.worktrees).Count)"

  $beforeById = @{}
  foreach ($item in @($worktreesBefore.worktrees)) {
    $id = [string]$item.id
    if ($beforeById.ContainsKey($id)) { throw "Worktree inventory에 중복 id가 있습니다." }
    $beforeById[$id] = $item
  }
  $recordIds = New-Object 'System.Collections.Generic.List[string]'
  $worktreeFileTotal = [int64]0
  foreach ($record in @($Manifest.worktrees)) {
    $id = [string](Get-BackupModeRequiredProperty -Object $record -Name "id")
    if ($recordIds.Contains($id)) { throw "manifest worktree에 중복 id가 있습니다." }
    if (-not $beforeById.ContainsKey($id)) { throw "manifest worktree id가 inventory에 없습니다." }
    $recordIds.Add($id)
    $inventoryItem = $beforeById[$id]
    $identityPass =
      ([string]$record.headSha -eq [string]$inventoryItem.headSha) -and
      ([string]$record.branchRef -eq [string]$inventoryItem.branchRef) -and
      ([bool]$record.detached -eq [bool]$inventoryItem.detached) -and
      ([string]$record.indexSha256 -eq [string]$inventoryItem.indexSha256) -and
      ([string]$record.statusDigest -eq [string]$inventoryItem.statusDigest)
    if (-not $identityPass) { throw "Worktree record와 source-before inventory가 다릅니다: $id" }

    $sourceBefore = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$record.sourceBeforeManifestPath)
    $snapshotStored = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$record.snapshotManifestPath)
    $sourceAfter = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$record.sourceAfterManifestPath)
    $snapshotPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$record.snapshotPath) -PathType Container
    $snapshotMeasured = Get-BackupTreeManifest -RootPath $snapshotPath -ExcludeGitEntries $true
    $beforeSnapshot = Assert-BackupModeTreeExact -Reference $sourceBefore -Difference $snapshotStored -Label "$id source-before/snapshot"
    $sourceStable = Assert-BackupModeTreeExact -Reference $sourceBefore -Difference $sourceAfter -Label "$id source-before/source-after"
    Assert-BackupModeTreeExact -Reference $snapshotStored -Difference $snapshotMeasured -Label "$id snapshot 현재 재해시" | Out-Null
    $declaredComparison = $record.sourceBeforeVsSnapshot
    $declaredStable = $record.sourceBeforeVsSourceAfter
    $declaredPass =
      [bool]$declaredComparison.exact -and
      [bool]$declaredStable.exact -and
      (([int]$declaredComparison.missingDirectoryCount + [int]$declaredComparison.extraDirectoryCount + [int]$declaredComparison.missingFileCount + [int]$declaredComparison.extraFileCount + [int]$declaredComparison.sizeMismatchCount + [int]$declaredComparison.hashMismatchCount) -eq 0) -and
      (([int]$declaredStable.missingDirectoryCount + [int]$declaredStable.extraDirectoryCount + [int]$declaredStable.missingFileCount + [int]$declaredStable.extraFileCount + [int]$declaredStable.sizeMismatchCount + [int]$declaredStable.hashMismatchCount) -eq 0) -and
      $beforeSnapshot.exact -and $sourceStable.exact -and
      ([string]$record.manifestSha256 -eq [string]$sourceBefore.fileManifestSha256) -and
      ([int]$record.fileCount -eq [int]$sourceBefore.fileCount) -and
      ([int64]$record.sizeBytes -eq [int64]$sourceBefore.sizeBytes) -and
      ([int]$snapshotMeasured.reparsePointCount -eq 0)
    if (-not $declaredPass) { throw "Worktree 비교 요약이 실제 manifest와 다릅니다: $id" }
    $worktreeFileTotal += [int64]$sourceBefore.fileCount
  }
  $idComparison = Compare-BackupStringSets -Reference @($beforeById.Keys | Sort-Object) -Difference @($recordIds | Sort-Object)
  Add-BackupModeCondition -Checks $Checks -Name "4개 Worktree snapshot source-before/snapshot exact" -Condition $idComparison.exact -Expected "4개 snapshot 재해시 exact" -Actual "worktrees=$($recordIds.Count), files=$worktreeFileTotal"

  $nonMigrationBefore = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.nonMigrationBefore)
  $nonMigrationAfter = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts.nonMigrationAfter)
  $nonMigrationComparison = Assert-BackupModeTreeExact -Reference $nonMigrationBefore -Difference $nonMigrationAfter -Label "non-migration source-before/source-after"
  $expectedBaseline = [string]$Manifest.nonMigrationBaseline.expectedManifestSha256
  $expectedPass = [string]::IsNullOrWhiteSpace($expectedBaseline) -or ($expectedBaseline -eq [string]$nonMigrationBefore.fileManifestSha256)
  $baselinePass =
    $nonMigrationComparison.exact -and $expectedPass -and
    ([string]$Manifest.nonMigrationBaseline.sourceBeforeManifestSha256 -eq [string]$nonMigrationBefore.fileManifestSha256) -and
    ([string]$Manifest.nonMigrationBaseline.sourceAfterManifestSha256 -eq [string]$nonMigrationAfter.fileManifestSha256) -and
    ([int]$Manifest.nonMigrationBaseline.sourceBeforeFileCount -eq [int]$nonMigrationBefore.fileCount) -and
    ([int64]$Manifest.nonMigrationBaseline.sourceBeforeSizeBytes -eq [int64]$nonMigrationBefore.sizeBytes) -and
    ([int]$nonMigrationBefore.reparsePointCount -eq 0) -and ([int]$nonMigrationAfter.reparsePointCount -eq 0)
  Add-BackupModeCondition -Checks $Checks -Name "Non-migration source-before/after exact" -Condition $baselinePass -Expected "파일·크기·SHA exact" -Actual "files=$($nonMigrationBefore.fileCount), bytes=$($nonMigrationBefore.sizeBytes)"

  if ($MeasureCurrentSource) {
    $currentRoot = Resolve-BackupPath -Path $CurrentRepositoryRoot
    if (-not (Test-Path -LiteralPath $currentRoot -PathType Container)) {
      throw "현재 원본 재측정 경로가 없습니다."
    }
    $migrationPath = Resolve-BackupPath -Path (Join-Path $currentRoot "migration")
    $currentManifest = Get-BackupTreeManifest -RootPath $currentRoot -ExcludedPaths @($migrationPath) -ExcludeGitEntries $true
    $currentComparison = Compare-BackupTreeManifests -Reference $nonMigrationAfter -Difference $currentManifest
    Add-BackupModeCondition -Checks $Checks -Name "현재 non-migration 원본 재측정" -Condition ($currentComparison.exact -and ($currentManifest.reparsePointCount -eq 0)) -Expected ([string]$nonMigrationAfter.fileManifestSha256) -Actual ([string]$currentManifest.fileManifestSha256) -Details "현재 원본에는 쓰지 않고 읽기 전용 해시만 측정"
  }
  else {
    Add-ValidationCheck -Checks $Checks -Name "현재 non-migration 원본 재측정" -Status "SKIP" -Critical $false -Expected "-VerifyCurrentSource 선택 시 수행" -Actual "미선택" -Details "백업 내부 검증 결과에는 영향 없음"
  }
}

function Test-BackupModeLfs {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  foreach ($scope in @("local", "remote")) {
    $prefix = if ($scope -eq "local") { "localLfs" } else { "remoteLfs" }
    $before = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts."${prefix}Before")
    $snapshotStored = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts."${prefix}Snapshot")
    $after = Read-BackupModeJson -SetRoot $SetRoot -RelativePath ([string]$Manifest.artifacts."${prefix}After")
    $snapshotRelativePath = if ($scope -eq "local") { "lfs/local-objects" } else { "lfs/remote-objects" }
    $snapshotPath = Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath $snapshotRelativePath -PathType Container
    $snapshotMeasured = Get-BackupLfsObjectManifest -ObjectRoot $snapshotPath
    $exact =
      (Compare-BackupModeLfsManifests -Reference $before -Difference $snapshotStored) -and
      (Compare-BackupModeLfsManifests -Reference $before -Difference $after) -and
      (Compare-BackupModeLfsManifests -Reference $snapshotStored -Difference $snapshotMeasured)
    $expectedCount = if ($scope -eq "local") { [int]$Manifest.lfs.localObjectCount } else { [int]$Manifest.lfs.remoteObjectCount }
    $expectedBytes = if ($scope -eq "local") { [int64]$Manifest.lfs.localObjectBytes } else { [int64]$Manifest.lfs.remoteObjectBytes }
    $expectedDigest = if ($scope -eq "local") { [string]$Manifest.lfs.localOidDigest } else { [string]$Manifest.lfs.remoteOidDigest }
    $summaryExact =
      ([int]$before.objectCount -eq $expectedCount) -and
      ([int64]$before.objectBytes -eq $expectedBytes) -and
      ([string]$before.digest -eq $expectedDigest)
    $repositoryPath = if ($scope -eq "local") {
      Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.local.mirrorPath) -PathType Container
    }
    else {
      Resolve-BackupModeChildPath -SetRoot $SetRoot -RelativePath ([string]$Manifest.remote.mirrorPath) -PathType Container
    }
    $pointerResult = Invoke-BackupGit -RepositoryPath $repositoryPath -Arguments @("lfs", "ls-files", "--all", "--name-only")
    $actualPointerCount = @($pointerResult.lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    $expectedPointerCount = if ($scope -eq "local") { [int]$Manifest.lfs.localPointerCount } else { [int]$Manifest.lfs.remotePointerCount }
    Add-BackupModeCondition -Checks $Checks -Name "$scope LFS manifest·object snapshot exact" -Condition ($exact -and $summaryExact -and ($actualPointerCount -eq $expectedPointerCount)) -Expected "objects=$expectedCount, pointers=$expectedPointerCount" -Actual "objects=$($snapshotMeasured.objectCount), pointers=$actualPointerCount, exact=$exact"
  }
}

function Invoke-BackupModeValidation {
  param(
    [Parameter(Mandatory = $true)][string]$SetRoot,
    [Parameter(Mandatory = $true)][string]$CurrentRepositoryRoot,
    [Parameter(Mandatory = $true)][bool]$MeasureCurrentSource
  )

  $checks = New-Object System.Collections.ArrayList
  $resolvedSetRoot = Resolve-BackupPath -Path $SetRoot
  if (-not (Test-Path -LiteralPath $resolvedSetRoot -PathType Container)) {
    Add-ValidationCheck -Checks $checks -Name "백업 final 경로" -Status "FAIL" -Critical $true -Expected "존재하는 final 디렉터리" -Actual "없음" -Details $resolvedSetRoot
    return $checks
  }

  $leafName = Split-Path -Leaf $resolvedSetRoot
  $namePass = ($leafName -match '^before-transfer-\d{8}-\d{6}-[0-9a-fA-F]{12}$') -and ($leafName -notmatch '\.partial(?:-|$)')
  Add-BackupModeCondition -Checks $checks -Name "백업 final 이름·partial 거부" -Condition $namePass -Expected "before-transfer-YYYYMMDD-HHMMSS-<12hex>" -Actual $leafName
  if (-not $namePass) {
    return $checks
  }

  try {
    $complete = Read-BackupModeJson -SetRoot $resolvedSetRoot -RelativePath "complete.json"
    $manifest = Read-BackupModeJson -SetRoot $resolvedSetRoot -RelativePath "manifest.json"
  }
  catch {
    Add-ValidationCheck -Checks $checks -Name "complete.json·manifest.json 읽기" -Status "FAIL" -Critical $true -Expected "유효한 JSON" -Actual "실패" -Details $_.Exception.Message
    return $checks
  }

  try {
    $manifestSchemaPass =
      ([int](Get-BackupModeRequiredProperty -Object $manifest -Name "schemaVersion") -eq 2) -and
      ([string](Get-BackupModeRequiredProperty -Object $manifest -Name "backupType") -eq "phase1-complete") -and
      ([string](Get-BackupModeRequiredProperty -Object $manifest -Name "backupSetName") -eq $leafName)
    $completeSchemaPass =
      ([int](Get-BackupModeRequiredProperty -Object $complete -Name "schemaVersion") -eq 1) -and
      ([string](Get-BackupModeRequiredProperty -Object $complete -Name "status") -eq "PASS") -and
      ([string](Get-BackupModeRequiredProperty -Object $complete -Name "backupType") -eq "phase1-complete") -and
      ([string](Get-BackupModeRequiredProperty -Object $complete -Name "backupSetName") -eq $leafName)
    Add-BackupModeCondition -Checks $checks -Name "manifest schema/status" -Condition $manifestSchemaPass -Expected "schema=2, phase1-complete, 이름 일치" -Actual "schema=$($manifest.schemaVersion), type=$($manifest.backupType)"
    Add-BackupModeCondition -Checks $checks -Name "complete schema/status" -Condition $completeSchemaPass -Expected "schema=1, PASS, phase1-complete" -Actual "schema=$($complete.schemaVersion), status=$($complete.status)"

    $setRootPass = (Resolve-BackupPath -Path ([string]$manifest.backupSetRoot)).Equals($resolvedSetRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $headSha = ([string]$manifest.sourceHeadSha).ToLowerInvariant()
    $crossPass =
      $setRootPass -and
      ($headSha -match '^[0-9a-f]{40,64}$') -and
      $leafName.EndsWith($headSha.Substring(0, 12), [System.StringComparison]::OrdinalIgnoreCase) -and
      ([string]$complete.sourceHeadSha -eq [string]$manifest.sourceHeadSha) -and
      ([string]$complete.remoteRefDigest -eq [string]$manifest.remoteRefDigest) -and
      ([string]$complete.localRefDigest -eq [string]$manifest.localRefDigest)
    Add-BackupModeCondition -Checks $checks -Name "final 경로·HEAD·complete 교차 일치" -Condition $crossPass -Expected "경로/HEAD/ref digest 일치" -Actual "root=$setRootPass, headSuffix=$($leafName.EndsWith($headSha.Substring(0, 12), [System.StringComparison]::OrdinalIgnoreCase))"

    $safeMetadataPass =
      ([int]$manifest.secretCandidateCount -eq 0) -and
      ([string]$manifest.secretPreservationStatus -eq "NOT_REQUIRED") -and
      (-not [bool]$manifest.secretValuesStoredInReports) -and
      ([string]$manifest.sourceUrl -notmatch '(?i)https?://[^/@\s]+@') -and
      ([string]$manifest.sourceUrl -notmatch '\?')
    Add-BackupModeCondition -Checks $checks -Name "시크릿·credential 메타데이터 안전성" -Condition $safeMetadataPass -Expected "secret 후보 0, URL credential/query 없음" -Actual "secretCandidates=$($manifest.secretCandidateCount)"
  }
  catch {
    Add-ValidationCheck -Checks $checks -Name "백업 core schema 교차 검증" -Status "FAIL" -Critical $true -Expected "필수 속성 전체" -Actual "실패" -Details $_.Exception.Message
    return $checks
  }

  try {
    $allItems = @(Get-ChildItem -LiteralPath (ConvertTo-BackupExtendedPath -Path $resolvedSetRoot) -Recurse -Force -ErrorAction Stop)
    $reparseCount = @($allItems | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 }).Count
    $completeItem = Get-Item -LiteralPath (ConvertTo-BackupExtendedPath -Path (Join-Path $resolvedSetRoot "complete.json")) -Force
    $lateFiles = @($allItems | Where-Object {
      (-not $_.PSIsContainer) -and
      (-not $_.FullName.Equals($completeItem.FullName, [System.StringComparison]::OrdinalIgnoreCase)) -and
      ($_.LastWriteTimeUtc -gt $completeItem.LastWriteTimeUtc)
    })
    Add-BackupModeCondition -Checks $checks -Name "complete.json 세트 내부 최종 write" -Condition (($lateFiles.Count -eq 0) -and ($reparseCount -eq 0)) -Expected "complete 이후 파일 write 0, reparse 0" -Actual "lateFiles=$($lateFiles.Count), reparse=$reparseCount"
  }
  catch {
    Add-ValidationCheck -Checks $checks -Name "complete.json 세트 내부 최종 write" -Status "FAIL" -Critical $true -Expected "재귀 LastWriteTimeUtc 확인" -Actual "실패" -Details $_.Exception.Message
  }

  try { Test-BackupModeFlagSummary -Manifest $manifest -Complete $complete -Checks $checks }
  catch { Add-ValidationCheck -Checks $checks -Name "안정성 flag 검증" -Status "FAIL" -Critical $true -Expected "모든 flag 확인" -Actual "실패" -Details $_.Exception.Message }
  try { Test-BackupModeChecksums -SetRoot $resolvedSetRoot -Manifest $manifest -Complete $complete -Checks $checks }
  catch { Add-ValidationCheck -Checks $checks -Name "Checksum 독립 검증" -Status "FAIL" -Critical $true -Expected "exact-set 및 실제 hash" -Actual "실패" -Details $_.Exception.Message }
  try { Test-BackupModeRemoteGit -SetRoot $resolvedSetRoot -Manifest $manifest -Checks $checks }
  catch { Add-ValidationCheck -Checks $checks -Name "Remote Git 독립 검증" -Status "FAIL" -Critical $true -Expected "fsck/bundle/restore/ref exact" -Actual "실패" -Details $_.Exception.Message }
  try { Test-BackupModeLocalGit -SetRoot $resolvedSetRoot -Manifest $manifest -Checks $checks }
  catch { Add-ValidationCheck -Checks $checks -Name "Local Git 독립 검증" -Status "FAIL" -Critical $true -Expected "전체 ref/bundle/restore exact" -Actual "실패" -Details $_.Exception.Message }
  try { Test-BackupModeTreeState -SetRoot $resolvedSetRoot -Manifest $manifest -CurrentRepositoryRoot $CurrentRepositoryRoot -MeasureCurrentSource $MeasureCurrentSource -Checks $checks }
  catch { Add-ValidationCheck -Checks $checks -Name "Raw Git·Worktree·non-migration 독립 검증" -Status "FAIL" -Critical $true -Expected "모든 tree exact" -Actual "실패" -Details $_.Exception.Message }
  try { Test-BackupModeLfs -SetRoot $resolvedSetRoot -Manifest $manifest -Checks $checks }
  catch { Add-ValidationCheck -Checks $checks -Name "LFS 독립 검증" -Status "FAIL" -Critical $true -Expected "pointer/object/snapshot exact" -Actual "실패" -Details $_.Exception.Message }

  return $checks
}

function Compare-AssetSnapshots {
  param(
    [Parameter(Mandatory = $true)]$Before,
    [Parameter(Mandatory = $true)]$After,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $afterByName = @{}
  foreach ($asset in @($After.assets)) {
    $afterByName[$asset.name] = $asset
  }

  foreach ($beforeAsset in @($Before.assets)) {
    if (-not $afterByName.ContainsKey($beforeAsset.name)) {
      Add-ValidationCheck -Checks $Checks -Name "GitHub 자산: $($beforeAsset.name)" -Status "UNKNOWN" -Critical $true -Expected "전후 비교 가능" -Actual "after 항목 없음" -Details ""
      continue
    }

    $afterAsset = $afterByName[$beforeAsset.name]
    if (($beforeAsset.status -ne "PASS") -or ($afterAsset.status -ne "PASS")) {
      Add-ValidationCheck -Checks $Checks -Name "GitHub 자산: $($beforeAsset.name)" -Status "UNKNOWN" -Critical $true -Expected "전후 API 접근" -Actual "$($beforeAsset.status)/$($afterAsset.status)" -Details ($beforeAsset.error + "; " + $afterAsset.error)
      continue
    }

    $difference = @(Compare-Object -ReferenceObject @($beforeAsset.keys) -DifferenceObject @($afterAsset.keys))
    $status = if ($difference.Count -eq 0) { "PASS" } else { "FAIL" }
    Add-ValidationCheck -Checks $Checks -Name "GitHub 자산: $($beforeAsset.name)" -Status $status -Critical $true -Expected "$(@($beforeAsset.keys).Count)개 stable key exact" -Actual "$(@($afterAsset.keys).Count)개" -Details (($difference | ConvertTo-Json -Compress) -as [string])
  }

  $pagesStatus = if ($Before.pages.status -eq $After.pages.status) { "PASS" } else { "WARN" }
  Add-ValidationCheck -Checks $Checks -Name "GitHub Pages 구성 상태" -Status $pagesStatus -Critical $false -Expected $Before.pages.status -Actual $After.pages.status -Details "Pages URL과 배포는 별도 기능 검증 필요"
}

function Write-ValidationMarkdown {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Checks
  )

  $lines = @(
    "# $Title",
    "",
    "- 검증 시각(KST): $([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, 'Korea Standard Time').ToString('o'))",
    "- 원격 변경: 수행하지 않음",
    "",
    "| 검증 항목 | 상태 | 필수 | 기대값 | 실제값 | 비고 |",
    "|---|---|---:|---|---|---|"
  )

  foreach ($check in $Checks) {
    $expected = ($check.expected -replace '\|', '\|') -replace "`r?`n", " "
    $actual = ($check.actual -replace '\|', '\|') -replace "`r?`n", " "
    $details = ($check.details -replace '\|', '\|') -replace "`r?`n", " "
    $lines += "| $($check.name) | $($check.status) | $($check.critical) | $expected | $actual | $details |"
  }

  $criticalFailures = @($Checks | Where-Object { $_.critical -and $_.status -eq "FAIL" }).Count
  $criticalUnknowns = @($Checks | Where-Object { $_.critical -and $_.status -eq "UNKNOWN" }).Count
  $lines += ""
  $lines += "- 필수 실패: $criticalFailures"
  $lines += "- 필수 미확인: $criticalUnknowns"
  $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

if (-not $Execute) {
  Write-Host "[DRY-RUN] 검증을 실행하지 않았습니다."
  Write-Host "모드: $Mode"
  if ($Mode -eq "Backup") {
    $plannedSetPath = if (-not [string]::IsNullOrWhiteSpace($BackupSetPath)) { $BackupSetPath } elseif (-not [string]::IsNullOrWhiteSpace($BackupManifestPath)) { Split-Path -Parent $BackupManifestPath } else { "<미지정>" }
    Write-Host "백업 세트: $plannedSetPath"
    Write-Host "현재 원본 재측정: $([bool]$VerifyCurrentSource)"
    Write-Host "Backup 모드는 백업 세트·활성 원본·보고서에 쓰지 않습니다."
  }
  else {
    Write-Host "원본: $SourceRepository"
    Write-Host "대상: $TargetRepository"
  }
  Write-Host "실행하려면 -Execute를 지정하세요."
  exit 0
}

if ($Mode -eq "Backup") {
  $commonScriptPath = Join-Path $scriptDirectory "backup_common.ps1"
  if (-not (Test-Path -LiteralPath $commonScriptPath -PathType Leaf)) {
    throw "공통 백업 함수 파일을 찾을 수 없습니다."
  }
  . $commonScriptPath

  if ([string]::IsNullOrWhiteSpace($BackupSetPath) -and [string]::IsNullOrWhiteSpace($BackupManifestPath)) {
    throw "Backup 모드에는 -BackupSetPath 또는 -BackupManifestPath가 필요합니다."
  }
  $resolvedBackupSetPath = if (-not [string]::IsNullOrWhiteSpace($BackupSetPath)) {
    Resolve-BackupPath -Path $BackupSetPath
  }
  else {
    $resolvedManifestPath = Resolve-BackupPath -Path $BackupManifestPath
    if ((Split-Path -Leaf $resolvedManifestPath) -ne "manifest.json") {
      throw "-BackupManifestPath는 manifest.json 파일을 가리켜야 합니다."
    }
    Resolve-BackupPath -Path (Split-Path -Parent $resolvedManifestPath)
  }
  if (-not [string]::IsNullOrWhiteSpace($BackupManifestPath)) {
    $resolvedManifestPath = Resolve-BackupPath -Path $BackupManifestPath
    $manifestParent = Resolve-BackupPath -Path (Split-Path -Parent $resolvedManifestPath)
    if (-not $manifestParent.Equals($resolvedBackupSetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "BackupSetPath와 BackupManifestPath가 같은 세트를 가리키지 않습니다."
    }
  }
  if (-not $PSCmdlet.ShouldProcess($resolvedBackupSetPath, "Phase 1 백업 읽기 전용 독립 검증")) {
    exit 0
  }
  if (-not (Test-CommandAvailable -Name "git")) {
    throw "git 명령을 찾을 수 없습니다."
  }

  $checks = Invoke-BackupModeValidation `
    -SetRoot $resolvedBackupSetPath `
    -CurrentRepositoryRoot $RepositoryRoot `
    -MeasureCurrentSource ([bool]$VerifyCurrentSource)
  foreach ($check in @($checks)) {
    Write-Host "[$($check.status)] $($check.name)"
  }
  $criticalFailures = @($checks | Where-Object { $_.critical -and $_.status -eq "FAIL" }).Count
  $criticalUnknowns = @($checks | Where-Object { $_.critical -and $_.status -eq "UNKNOWN" }).Count
  Write-Host "Backup 검증 요약: checks=$($checks.Count), criticalFail=$criticalFailures, criticalUnknown=$criticalUnknowns"
  if ($criticalFailures -gt 0) { exit 8 }
  if ($criticalUnknowns -gt 0) { exit 9 }
  exit 0
}

if (-not $PSCmdlet.ShouldProcess($OutputDirectory, "$Mode 읽기 전용 GitHub/Git 검증 및 보고서 생성")) {
  exit 0
}

foreach ($commandName in @("git", "gh")) {
  if (-not (Test-CommandAvailable -Name $commandName)) {
    throw "$commandName 명령을 찾을 수 없습니다."
  }
}

$authResult = Invoke-NativeCommand -Command "gh" -Arguments @("auth", "status", "--hostname", "github.com") -AllowNonZero
if ($authResult.exitCode -ne 0) {
  throw "GitHub CLI 인증이 유효하지 않습니다."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$checks = New-Object System.Collections.ArrayList
$beforeRepository = Get-Content -Raw -Encoding UTF8 -LiteralPath $BeforeRepositoryPath | ConvertFrom-Json
$beforeRepositoryId = [string](Get-OptionalPropertyValue -Object $beforeRepository -Name "id")
$beforeDefaultBranch = [string](Get-OptionalPropertyValue -Object $beforeRepository -Name "default_branch")
$beforeMainSha = [string](Get-OptionalPropertyValue -Object $beforeRepository -Name "default_branch_ref_sha")
if ([string]::IsNullOrWhiteSpace($beforeMainSha)) {
  $beforeMainSha = [string](Get-OptionalPropertyValue -Object $beforeRepository -Name "main_sha")
}

if ($Mode -eq "PreTransfer") {
  $sourceSnapshot = Get-RepositorySnapshot -Repository $SourceRepository
  if ($sourceSnapshot.status -ne "PASS") {
    Add-ValidationCheck -Checks $checks -Name "원본 저장소 조회" -Status "UNKNOWN" -Critical $true -Expected "접근 가능" -Actual "조회 실패" -Details $sourceSnapshot.error
  }
  else {
    if ([string]::IsNullOrWhiteSpace($beforeMainSha)) {
      $beforeMainSha = $sourceSnapshot.repository.mainSha
    }
    Add-ValidationCheck -Checks $checks -Name "Repository ID" -Status $(if ([string]$sourceSnapshot.repository.id -eq $beforeRepositoryId) { "PASS" } else { "FAIL" }) -Critical $true -Expected $beforeRepositoryId -Actual ([string]$sourceSnapshot.repository.id) -Details ""
    Add-ValidationCheck -Checks $checks -Name "원본 Admin 권한" -Status $(if ($sourceSnapshot.repository.permissions.admin) { "PASS" } else { "FAIL" }) -Critical $true -Expected "true" -Actual ([string]$sourceSnapshot.repository.permissions.admin) -Details ""

    $remoteUrl = "https://github.com/$SourceRepository.git"
    if (-not [string]::IsNullOrWhiteSpace($BackupManifestPath)) {
      Test-BackupManifest -ManifestPath $BackupManifestPath -ExpectedHeadSha $sourceSnapshot.repository.mainSha -RemoteUrl $remoteUrl -Checks $checks | Out-Null
    }
    else {
      Add-ValidationCheck -Checks $checks -Name "백업 manifest" -Status "FAIL" -Critical $true -Expected "-BackupManifestPath 지정" -Actual "미지정" -Details ""
    }

    $statusResult = Invoke-NativeCommand -Command "git" -Arguments @("--no-optional-locks", "-C", $RepositoryRoot, "status", "--porcelain=v1", "--untracked-files=all")
    $isClean = [string]::IsNullOrWhiteSpace($statusResult.stdout)
    Add-ValidationCheck -Checks $checks -Name "현재 working tree clean" -Status $(if ($isClean) { "PASS" } else { "FAIL" }) -Critical $true -Expected "clean" -Actual $(if ($isClean) { "clean" } else { "dirty" }) -Details "dirty 파일 본문은 보고서에 저장하지 않음"

    $membershipResult = Invoke-GhJson -Endpoint "user/memberships/orgs/$($TargetRepository.Split('/')[0])"
    if ($membershipResult.status -eq "PASS") {
      $membershipPass = ($membershipResult.data.state -eq "active") -and ($membershipResult.data.role -eq "admin")
      Add-ValidationCheck -Checks $checks -Name "대상 Organization owner 권한" -Status $(if ($membershipPass) { "PASS" } else { "FAIL" }) -Critical $true -Expected "active/admin" -Actual "$($membershipResult.data.state)/$($membershipResult.data.role)" -Details ""
    }
    else {
      Add-ValidationCheck -Checks $checks -Name "대상 Organization owner 권한" -Status "UNKNOWN" -Critical $true -Expected "active/admin" -Actual "조회 실패" -Details $membershipResult.error
    }

    $targetProbe = Invoke-GhJson -Endpoint "repos/$TargetRepository"
    if ($targetProbe.status -eq "PASS") {
      Add-ValidationCheck -Checks $checks -Name "대상 저장소 이름 충돌" -Status "FAIL" -Critical $true -Expected "동일 이름 저장소 없음" -Actual "존재" -Details ([string]$targetProbe.data.id)
    }
    elseif ($targetProbe.error -match '(?i)not found|404') {
      Add-ValidationCheck -Checks $checks -Name "대상 저장소 이름 충돌" -Status "PASS" -Critical $true -Expected "동일 이름 저장소 없음" -Actual "직접 조회 404" -Details "Organization owner 권한과 함께 판정"
    }
    else {
      Add-ValidationCheck -Checks $checks -Name "대상 저장소 이름 충돌" -Status "UNKNOWN" -Critical $true -Expected "동일 이름 저장소 없음" -Actual "조회 불가" -Details $targetProbe.error
    }

    $beforeAssets = Get-AssetSnapshot -Repository $SourceRepository
    [pscustomobject]@{
      schemaVersion = 1
      repository = $sourceSnapshot.repository
      assets = $beforeAssets
    } | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $OutputDirectory "transfer-validation-baseline.json") -Encoding UTF8
  }

  Write-ValidationMarkdown -Path (Join-Path $OutputDirectory "pre-transfer-validation.md") -Title "이관 전 검증" -Checks $checks
}
else {
  $baselinePath = Join-Path $OutputDirectory "transfer-validation-baseline.json"
  if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
    Add-ValidationCheck -Checks $checks -Name "전송 전 검증 기준" -Status "FAIL" -Critical $true -Expected "transfer-validation-baseline.json" -Actual "없음" -Details $baselinePath
  }
  else {
    $baseline = Get-Content -Raw -Encoding UTF8 -LiteralPath $baselinePath | ConvertFrom-Json
    $targetSnapshot = Get-RepositorySnapshot -Repository $TargetRepository
    if ($targetSnapshot.status -ne "PASS") {
      $sourceStillThere = Get-RepositorySnapshot -Repository $SourceRepository
      $details = if ($sourceStillThere.status -eq "PASS") { "원본 경로에 저장소가 아직 조회됨" } else { "원본·대상 모두 조회 불가" }
      Add-ValidationCheck -Checks $checks -Name "대상 저장소 조회" -Status "UNKNOWN" -Critical $true -Expected "대상 경로에서 조회" -Actual "조회 실패" -Details $details
    }
    else {
      Add-ValidationCheck -Checks $checks -Name "Repository ID 보존" -Status $(if ([string]$targetSnapshot.repository.id -eq [string]$baseline.repository.id) { "PASS" } else { "FAIL" }) -Critical $true -Expected ([string]$baseline.repository.id) -Actual ([string]$targetSnapshot.repository.id) -Details ""
      Add-ValidationCheck -Checks $checks -Name "기본 브랜치 보존" -Status $(if ($targetSnapshot.repository.defaultBranch -eq $baseline.repository.defaultBranch) { "PASS" } else { "FAIL" }) -Critical $true -Expected $baseline.repository.defaultBranch -Actual $targetSnapshot.repository.defaultBranch -Details ""
      Add-ValidationCheck -Checks $checks -Name "기본 브랜치 SHA 보존" -Status $(if ($targetSnapshot.repository.mainSha -eq $baseline.repository.mainSha) { "PASS" } else { "FAIL" }) -Critical $true -Expected $baseline.repository.mainSha -Actual $targetSnapshot.repository.mainSha -Details ""
      Add-ValidationCheck -Checks $checks -Name "공개 범위 보존" -Status $(if ($targetSnapshot.repository.visibility -eq $baseline.repository.visibility) { "PASS" } else { "FAIL" }) -Critical $true -Expected $baseline.repository.visibility -Actual $targetSnapshot.repository.visibility -Details ""

      $afterAssets = Get-AssetSnapshot -Repository $TargetRepository
      Compare-AssetSnapshots -Before $baseline.assets -After $afterAssets -Checks $checks
      $targetSnapshot.repository | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $OutputDirectory "repository-after.json") -Encoding UTF8
      $afterAssets | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $OutputDirectory "github-assets-after.json") -Encoding UTF8
    }
  }

  Write-ValidationMarkdown -Path (Join-Path $OutputDirectory "post-transfer-validation.md") -Title "이관 후 검증" -Checks $checks
  Write-ValidationMarkdown -Path (Join-Path $OutputDirectory "asset-comparison.md") -Title "GitHub 자산 전후 비교" -Checks $checks
}

$criticalFailures = @($checks | Where-Object { $_.critical -and $_.status -eq "FAIL" }).Count
$criticalUnknowns = @($checks | Where-Object { $_.critical -and $_.status -eq "UNKNOWN" }).Count
if ($criticalFailures -gt 0) {
  exit 8
}
if ($criticalUnknowns -gt 0) {
  exit 9
}
exit 0
