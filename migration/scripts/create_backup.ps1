[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$SourceRepository = "mygithub05253/EST-CAMP-AI-Quant",
  [string]$SourceUrl = "https://github.com/mygithub05253/EST-CAMP-AI-Quant.git",
  [string]$BackupRoot = (Join-Path $env:USERPROFILE "Backups\EST-CAMP-AI-Quant-Migration"),
  [string]$BackupSetName = "",
  [string]$WorkingTreePath = "",
  [string]$ReportPath = "",
  [string]$ExpectedNonMigrationManifestSha256 = "",
  [switch]$IncludeWorkingTreeSnapshot,
  [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:GIT_OPTIONAL_LOCKS = "0"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrationDirectory = Split-Path -Parent $scriptDirectory
$commonScriptPath = Join-Path $scriptDirectory "backup_common.ps1"
if (-not (Test-Path -LiteralPath $commonScriptPath -PathType Leaf)) {
  throw "공통 백업 함수 파일을 찾을 수 없습니다: $commonScriptPath"
}
. $commonScriptPath

if ([string]::IsNullOrWhiteSpace($WorkingTreePath)) {
  $WorkingTreePath = Split-Path -Parent $migrationDirectory
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path (Join-Path $migrationDirectory "reports") "weekend-backup-verification.md"
}

function Assert-BackupCommandAvailable {
  param([Parameter(Mandatory = $true)][string]$Name)

  if ($null -eq (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
    throw "필수 명령을 찾을 수 없습니다: $Name"
  }
}

function Get-RemoteBackupState {
  param([Parameter(Mandatory = $true)][string]$RepositoryUrl)

  $result = Invoke-BackupGit -Arguments @("ls-remote", "--symref", $RepositoryUrl)
  $defaultBranch = ""
  $headSha = ""
  foreach ($line in @($result.lines)) {
    if ($line -match '^ref:\s+refs/heads/(\S+)\s+HEAD$') {
      $defaultBranch = $Matches[1]
    }
    elseif ($line -match '^([0-9a-fA-F]{40,64})\s+HEAD$') {
      $headSha = $Matches[1].ToLowerInvariant()
    }
  }
  $refs = ConvertTo-BackupComparableRefs -Lines $result.lines
  if ([string]::IsNullOrWhiteSpace($defaultBranch) -or [string]::IsNullOrWhiteSpace($headSha)) {
    throw "원격 HEAD 또는 기본 브랜치를 확인할 수 없습니다: $RepositoryUrl"
  }
  if ($refs.Count -eq 0) {
    throw "원격 ref가 0개입니다: $RepositoryUrl"
  }
  $refText = ($refs -join "`n") + "`n"
  $defaultRefLine = @($refs | Where-Object { $_ -match "^refs/heads/$([regex]::Escape($defaultBranch))`t" })
  if ($defaultRefLine.Count -ne 1) {
    throw "원격 기본 브랜치 ref를 유일하게 확인할 수 없습니다: $defaultBranch"
  }

  return [pscustomobject]@{
    defaultBranch = $defaultBranch
    headSha = $headSha
    refs = $refs
    refCount = $refs.Count
    refDigest = Get-BackupTextSha256 -Text $refText
    branchCount = @($refs | Where-Object { $_ -match '^refs/heads/' }).Count
    tagCount = @($refs | Where-Object { $_ -match '^refs/tags/' }).Count
    pullRefCount = @($refs | Where-Object { $_ -match '^refs/pull/' }).Count
  }
}

function Assert-BackupComparisonExact {
  param(
    [Parameter(Mandatory = $true)]$Comparison,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (-not $Comparison.exact) {
    throw "$Label exact 비교 실패: missingDir=$($Comparison.missingDirectoryCount), extraDir=$($Comparison.extraDirectoryCount), missingFile=$($Comparison.missingFileCount), extraFile=$($Comparison.extraFileCount), size=$($Comparison.sizeMismatchCount), hash=$($Comparison.hashMismatchCount)"
  }
}

function Compare-LfsBackupManifests {
  param(
    [Parameter(Mandatory = $true)]$Reference,
    [Parameter(Mandatory = $true)]$Difference
  )

  $exact = (
    ([int64]$Reference.objectCount -eq [int64]$Difference.objectCount) -and
    ([int64]$Reference.objectBytes -eq [int64]$Difference.objectBytes) -and
    ([string]$Reference.digest -eq [string]$Difference.digest) -and
    ([int]$Reference.invalidOidPathCount -eq 0) -and
    ([int]$Reference.oidHashMismatchCount -eq 0) -and
    ([int]$Difference.invalidOidPathCount -eq 0) -and
    ([int]$Difference.oidHashMismatchCount -eq 0)
  )
  return [pscustomobject]@{
    exact = $exact
    expectedObjectCount = [int]$Reference.objectCount
    actualObjectCount = [int]$Difference.objectCount
    expectedObjectBytes = [int64]$Reference.objectBytes
    actualObjectBytes = [int64]$Difference.objectBytes
    expectedDigest = [string]$Reference.digest
    actualDigest = [string]$Difference.digest
  }
}

function Copy-LfsBackupObjects {
  param(
    [Parameter(Mandatory = $true)][string]$SourceObjectRoot,
    [Parameter(Mandatory = $true)][string]$DestinationObjectRoot
  )

  $sourceBefore = Get-BackupLfsObjectManifest -ObjectRoot $SourceObjectRoot
  if (Test-Path -LiteralPath $SourceObjectRoot -PathType Container) {
    Copy-BackupTree -Source $SourceObjectRoot -Destination $DestinationObjectRoot | Out-Null
  }
  else {
    New-Item -ItemType Directory -Path $DestinationObjectRoot | Out-Null
  }
  $snapshot = Get-BackupLfsObjectManifest -ObjectRoot $DestinationObjectRoot
  $sourceAfter = Get-BackupLfsObjectManifest -ObjectRoot $SourceObjectRoot
  $sourceToSnapshot = Compare-LfsBackupManifests -Reference $sourceBefore -Difference $snapshot
  $sourceStable = Compare-LfsBackupManifests -Reference $sourceBefore -Difference $sourceAfter
  if (-not $sourceToSnapshot.exact) {
    throw "LFS object store snapshot exact 비교가 실패했습니다: $SourceObjectRoot"
  }
  if (-not $sourceStable.exact) {
    throw "LFS object store가 백업 중 변경되었습니다: $SourceObjectRoot"
  }
  return [pscustomobject]@{
    sourceBefore = $sourceBefore
    snapshot = $snapshot
    sourceAfter = $sourceAfter
    sourceToSnapshot = $sourceToSnapshot
    sourceStable = $sourceStable
  }
}

function Get-LocalScalarState {
  param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

  $branchResult = Invoke-BackupGit -RepositoryPath $RepositoryRoot -Arguments @("branch", "--show-current")
  $headResult = Invoke-BackupGit -RepositoryPath $RepositoryRoot -Arguments @("rev-parse", "HEAD")
  $originMainResult = Invoke-BackupGit -RepositoryPath $RepositoryRoot -Arguments @("rev-parse", "--verify", "origin/main") -AllowNonZero
  $remoteResult = Invoke-BackupGit -RepositoryPath $RepositoryRoot -Arguments @("remote", "get-url", "origin")
  return [pscustomobject]@{
    branch = ([string]($branchResult.lines | Select-Object -First 1)).Trim()
    headSha = ([string]($headResult.lines | Select-Object -First 1)).Trim().ToLowerInvariant()
    originMainSha = if ($originMainResult.exitCode -eq 0) { ([string]($originMainResult.lines | Select-Object -First 1)).Trim().ToLowerInvariant() } else { "" }
    originUrl = ([string]($remoteResult.lines | Select-Object -First 1)).Trim()
  }
}

function Test-LocalScalarStateEqual {
  param(
    [Parameter(Mandatory = $true)]$Before,
    [Parameter(Mandatory = $true)]$After
  )

  return (
    ([string]$Before.branch -eq [string]$After.branch) -and
    ([string]$Before.headSha -eq [string]$After.headSha) -and
    ([string]$Before.originMainSha -eq [string]$After.originMainSha) -and
    ([string]$Before.originUrl -eq [string]$After.originUrl)
  )
}

foreach ($commandName in @("git", "robocopy")) {
  Assert-BackupCommandAvailable -Name $commandName
}
$lfsVersionResult = Invoke-BackupGit -Arguments @("lfs", "version") -AllowNonZero
if ($lfsVersionResult.exitCode -ne 0) {
  throw "Git LFS를 사용할 수 없습니다. 설치·업그레이드는 임의로 수행하지 않습니다."
}

$workingTreeFullPath = Resolve-BackupPath -Path $WorkingTreePath
$backupRootFullPath = Resolve-BackupPath -Path $BackupRoot
$reportFullPath = Resolve-BackupPath -Path $ReportPath
$reportsRoot = Resolve-BackupPath -Path (Join-Path $migrationDirectory "reports")
if (-not (Test-Path -LiteralPath $workingTreeFullPath -PathType Container)) {
  throw "활성 working tree가 없습니다: $workingTreeFullPath"
}
if (Test-BackupPathSameOrChild -Candidate $backupRootFullPath -Parent $workingTreeFullPath) {
  throw "백업 루트는 활성 working tree 외부여야 합니다: $backupRootFullPath"
}
if (-not (Test-BackupPathSameOrChild -Candidate $reportFullPath -Parent $reportsRoot)) {
  throw "보고서 경로는 migration/reports/ 아래여야 합니다: $reportFullPath"
}
if ($SourceUrl -match '(?i)^https?://[^/@\s]+@') {
  throw "credential이 포함된 SourceUrl은 사용할 수 없습니다."
}

$topLevelResult = Invoke-BackupGit -RepositoryPath $workingTreeFullPath -Arguments @("rev-parse", "--show-toplevel")
$topLevel = Resolve-BackupPath -Path ([string]($topLevelResult.lines | Select-Object -First 1))
if (-not $topLevel.Equals($workingTreeFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "WorkingTreePath가 저장소 최상위 경로와 다릅니다: $topLevel"
}

if (-not $Execute) {
  Write-Host "[DRY-RUN] Phase 1 완전 백업을 생성하지 않았습니다."
  Write-Host "원본: $SourceRepository ($SourceUrl)"
  Write-Host "활성 루트: $workingTreeFullPath"
  Write-Host "백업 루트: $backupRootFullPath"
  Write-Host "정책: 기존 경로 재사용 금지, 새 .partial 생성 후 complete.json을 마지막에 쓰고 final 이름으로 전환"
  Write-Host "Working tree snapshot: .git 제외, linked worktree는 별도 snapshot, cache·ignored 포함"
  Write-Host "실행하려면 -IncludeWorkingTreeSnapshot -Execute를 함께 지정하세요."
  exit 0
}

if (-not $IncludeWorkingTreeSnapshot) {
  throw "Phase 1 완전 백업에는 -IncludeWorkingTreeSnapshot이 필수입니다."
}
if (-not $PSCmdlet.ShouldProcess($backupRootFullPath, "새 timestamp 경로에 copy-only Phase 1 완전 백업 생성")) {
  exit 0
}

$remoteBefore = Get-RemoteBackupState -RepositoryUrl $SourceUrl
$localScalarBefore = Get-LocalScalarState -RepositoryRoot $workingTreeFullPath
if (-not $localScalarBefore.originUrl.Equals($SourceUrl, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "SourceUrl과 활성 저장소 origin URL이 다릅니다. 임의 원격을 백업하지 않고 중단합니다."
}
$localRefsBefore = Get-BackupRefs -RepositoryPath $workingTreeFullPath
$worktreesBefore = Get-BackupWorktreeInventory -RepositoryRoot $workingTreeFullPath
$gitCommonResult = Invoke-BackupGit -RepositoryPath $workingTreeFullPath -Arguments @("rev-parse", "--git-common-dir")
$gitCommonRaw = [string]($gitCommonResult.lines | Select-Object -First 1)
$gitCommonDirectory = if ([System.IO.Path]::IsPathRooted($gitCommonRaw)) {
  Resolve-BackupPath -Path $gitCommonRaw
}
else {
  Resolve-BackupPath -Path (Join-Path $workingTreeFullPath $gitCommonRaw)
}

$migrationPath = Resolve-BackupPath -Path $migrationDirectory
$nonMigrationBefore = Get-BackupTreeManifest `
  -RootPath $workingTreeFullPath `
  -ExcludedPaths @($migrationPath) `
  -ExcludeGitEntries $true
if ($nonMigrationBefore.reparsePointCount -ne 0) {
  throw "non-migration 기준선에 reparse point가 있습니다. 임의 추적 없이 중단합니다."
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedNonMigrationManifestSha256)) {
  if ($nonMigrationBefore.fileManifestSha256 -ne $ExpectedNonMigrationManifestSha256.ToLowerInvariant()) {
    throw "첫 측정과 백업 직전 non-migration 파일 지문이 다릅니다. 동시 편집 가능성이 있어 백업을 실행하지 않습니다. expected=$ExpectedNonMigrationManifestSha256 actual=$($nonMigrationBefore.fileManifestSha256)"
  }
}

$migrationSecretCandidates = @(Get-ChildItem -LiteralPath $migrationPath -Recurse -Force -File -ErrorAction Stop | Where-Object {
  Test-BackupSecretRelativePath -RelativePath $_.FullName
} | ForEach-Object { Get-BackupRelativePath -Root $workingTreeFullPath -Path $_.FullName })
$nonMigrationSecretCandidates = @($nonMigrationBefore.files | Where-Object {
  Test-BackupSecretRelativePath -RelativePath $_.relativePath
} | ForEach-Object { $_.relativePath })
$secretCandidates = @(($migrationSecretCandidates + $nonMigrationSecretCandidates) | Sort-Object -Unique)
if ($secretCandidates.Count -gt 0) {
  throw "암호화 보존 승인이 없는 시크릿 파일명 후보가 $($secretCandidates.Count)개 발견되었습니다. 외부 평문 snapshot을 만들지 않고 중단합니다."
}

if ([string]::IsNullOrWhiteSpace($BackupSetName)) {
  $kstNow = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time")
  $BackupSetName = "before-transfer-$($kstNow.ToString('yyyyMMdd-HHmmss'))-$($localScalarBefore.headSha.Substring(0, 12))"
}
if ($BackupSetName -notmatch '^before-transfer-\d{8}-\d{6}-[0-9a-fA-F]{12}$') {
  throw "BackupSetName은 before-transfer-YYYYMMDD-HHMMSS-<12자리 HEAD> 형식이어야 합니다."
}
if (-not $BackupSetName.EndsWith($localScalarBefore.headSha.Substring(0, 12), [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "BackupSetName의 HEAD 접미사가 현재 로컬 HEAD와 다릅니다."
}

$backupSetRoot = Resolve-BackupPath -Path (Join-Path $backupRootFullPath $BackupSetName)
$partialSetRoot = "$backupSetRoot.partial-$PID"
if (-not (Test-BackupPathStrictChild -Candidate $backupSetRoot -Parent $backupRootFullPath)) {
  throw "백업 세트 경로가 BackupRoot의 엄격한 하위가 아닙니다: $backupSetRoot"
}
if ((Test-Path -LiteralPath $backupSetRoot) -or (Test-Path -LiteralPath $partialSetRoot)) {
  throw "기존 final 또는 partial 경로를 재사용·덮어쓰지 않습니다: $backupSetRoot / $partialSetRoot"
}

New-Item -ItemType Directory -Force -Path $backupRootFullPath | Out-Null
New-Item -ItemType Directory -Path $partialSetRoot | Out-Null

$remoteDirectory = Join-Path $partialSetRoot "remote"
$remoteMirrorPath = Join-Path $remoteDirectory "EST-CAMP-AI-Quant.git"
$remoteBundlePath = Join-Path $remoteDirectory "EST-CAMP-AI-Quant-before-transfer.bundle"
$remoteVerifyPath = Join-Path $remoteDirectory "bundle-prerequisite-verification.git"
$remoteRestorePath = Join-Path $remoteDirectory "bundle-restore-verification.git"
$localDirectory = Join-Path $partialSetRoot "local"
$localMirrorPath = Join-Path $localDirectory "local-state.git"
$localBundlePath = Join-Path $localDirectory "local-state-before-transfer.bundle"
$localVerifyPath = Join-Path $localDirectory "bundle-prerequisite-verification.git"
$localRestorePath = Join-Path $localDirectory "bundle-restore-verification.git"
$localGitSnapshotPath = Join-Path $localDirectory "git-common-dir-snapshot"
$snapshotsDirectory = Join-Path $partialSetRoot "snapshots"
$manifestsDirectory = Join-Path $partialSetRoot "manifests"
$workingTreeManifestsDirectory = Join-Path $manifestsDirectory "working-trees"
$lfsDirectory = Join-Path $partialSetRoot "lfs"
foreach ($directory in @($remoteDirectory, $localDirectory, $snapshotsDirectory, $manifestsDirectory, $workingTreeManifestsDirectory, $lfsDirectory)) {
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

try {
  # 원격 Git: GitHub가 광고하는 heads·tags·pull refs 전체를 fresh mirror와 bundle로 보존한다.
  Invoke-BackupGit -Arguments @("clone", "--mirror", $SourceUrl, $remoteMirrorPath) | Out-Null
  Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("fetch", "--force", "origin", "+refs/*:refs/*") | Out-Null
  $remoteMirrorFsck = Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("fsck", "--full", "--strict")
  $remoteLfsFilesResult = Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("lfs", "ls-files", "--all", "--name-only")
  $remoteLfsPointerCount = @($remoteLfsFilesResult.lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
  $remoteLfsFetched = $false
  if ($remoteLfsPointerCount -gt 0) {
    Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("lfs", "fetch", "--all", "origin") | Out-Null
    Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("lfs", "fsck", "--objects", "--pointers") | Out-Null
    $remoteLfsFetched = $true
  }

  $remoteMirrorRefsResult = Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("show-ref")
  $remoteMirrorRefs = ConvertTo-BackupComparableRefs -Lines $remoteMirrorRefsResult.lines
  $remoteMirrorComparison = Compare-BackupStringSets -Reference $remoteBefore.refs -Difference $remoteMirrorRefs
  if (-not $remoteMirrorComparison.exact) {
    throw "fresh remote mirror가 live 원격의 전체 광고 ref와 일치하지 않습니다."
  }

  Invoke-BackupGit -RepositoryPath $remoteMirrorPath -Arguments @("bundle", "create", $remoteBundlePath, "--all") | Out-Null
  Invoke-BackupGit -Arguments @("init", "--bare", $remoteVerifyPath) | Out-Null
  $remoteBundleVerify = Invoke-BackupGit -RepositoryPath $remoteVerifyPath -Arguments @("bundle", "verify", $remoteBundlePath)
  Invoke-BackupGit -Arguments @("clone", "--mirror", "--no-hardlinks", $remoteBundlePath, $remoteRestorePath) | Out-Null
  $remoteRestoreFsck = Invoke-BackupGit -RepositoryPath $remoteRestorePath -Arguments @("fsck", "--full", "--strict")
  $remoteBundleRefsResult = Invoke-BackupGit -Arguments @("bundle", "list-heads", $remoteBundlePath)
  $remoteRestoreRefsResult = Invoke-BackupGit -RepositoryPath $remoteRestorePath -Arguments @("show-ref")
  $remoteBundleRefs = ConvertTo-BackupComparableRefs -Lines $remoteBundleRefsResult.lines
  $remoteRestoreRefs = ConvertTo-BackupComparableRefs -Lines $remoteRestoreRefsResult.lines
  $remoteMirrorBundleComparison = Compare-BackupStringSets -Reference $remoteMirrorRefs -Difference $remoteBundleRefs
  $remoteMirrorRestoreComparison = Compare-BackupStringSets -Reference $remoteMirrorRefs -Difference $remoteRestoreRefs
  if (-not $remoteMirrorBundleComparison.exact) { throw "remote mirror와 bundle ref가 일치하지 않습니다." }
  if (-not $remoteMirrorRestoreComparison.exact) { throw "remote mirror와 bundle restore ref가 일치하지 않습니다." }
  $remoteBundleSha256 = Get-BackupFileSha256 -Path $remoteBundlePath

  # 로컬 Git: local-only branch·remote-tracking·stash·refs/codex를 exact mirror와 raw .git snapshot으로 보존한다.
  $gitCommonBefore = Get-BackupTreeManifest -RootPath $gitCommonDirectory -ExcludeGitEntries $false
  if ($gitCommonBefore.reparsePointCount -ne 0) {
    throw "Git common directory에 reparse point가 있어 무손실 정책을 확정할 수 없습니다."
  }
  Invoke-BackupGit -Arguments @("clone", "--mirror", "--no-hardlinks", $workingTreeFullPath, $localMirrorPath) | Out-Null
  Invoke-BackupGit -RepositoryPath $localMirrorPath -Arguments @("fetch", "--force", "origin", "+refs/*:refs/*") | Out-Null
  $localMirrorFsck = Invoke-BackupGit -RepositoryPath $localMirrorPath -Arguments @("fsck", "--full", "--strict")
  $localMirrorRefs = Get-BackupRefs -RepositoryPath $localMirrorPath
  $localRefComparison = Compare-BackupStringSets `
    -Reference @($localRefsBefore.refs | ForEach-Object { "$($_.refName)`t$($_.objectId)`t$($_.objectType)" }) `
    -Difference @($localMirrorRefs.refs | ForEach-Object { "$($_.refName)`t$($_.objectId)`t$($_.objectType)" })
  if (-not $localRefComparison.exact) {
    throw "local exact mirror에 refs/stash 또는 refs/codex를 포함한 ref 차이가 있습니다."
  }
  foreach ($worktree in @($worktreesBefore.worktrees)) {
    $worktreeHeadProbe = Invoke-BackupGit `
      -RepositoryPath $localMirrorPath `
      -Arguments @("cat-file", "-e", "$($worktree.headSha)^{commit}") `
      -AllowNonZero
    if ($worktreeHeadProbe.exitCode -ne 0) {
      throw "linked worktree HEAD object가 local mirror에 없습니다: $($worktree.sourcePath) / $($worktree.headSha)"
    }
  }

  $bundleCompatibleRefs = New-Object 'System.Collections.Generic.List[object]'
  $bundleExcludedRefs = New-Object 'System.Collections.Generic.List[object]'
  foreach ($ref in @($localMirrorRefs.refs)) {
    $commitProbe = Invoke-BackupGit -RepositoryPath $localMirrorPath -Arguments @("rev-parse", "--verify", "$($ref.refName)^{commit}") -AllowNonZero
    if ($commitProbe.exitCode -eq 0) {
      $bundleCompatibleRefs.Add($ref)
    }
    else {
      $objectProbe = Invoke-BackupGit -RepositoryPath $localMirrorPath -Arguments @("cat-file", "-e", $ref.objectId) -AllowNonZero
      if ($objectProbe.exitCode -ne 0) {
        throw "bundle 비호환 local ref의 object가 mirror에 없습니다: $($ref.refName)"
      }
      $bundleExcludedRefs.Add($ref)
    }
  }
  if ($bundleCompatibleRefs.Count -eq 0) {
    throw "local bundle에 포함할 commit-compatible ref가 없습니다."
  }
  $localBundleArguments = @("bundle", "create", $localBundlePath) + @($bundleCompatibleRefs | ForEach-Object { $_.refName })
  Invoke-BackupGit -RepositoryPath $localMirrorPath -Arguments $localBundleArguments | Out-Null
  Invoke-BackupGit -Arguments @("init", "--bare", $localVerifyPath) | Out-Null
  $localBundleVerify = Invoke-BackupGit -RepositoryPath $localVerifyPath -Arguments @("bundle", "verify", $localBundlePath)
  Invoke-BackupGit -Arguments @("clone", "--mirror", "--no-hardlinks", $localBundlePath, $localRestorePath) | Out-Null
  $localRestoreFsck = Invoke-BackupGit -RepositoryPath $localRestorePath -Arguments @("fsck", "--full", "--strict")
  $localBundleRefsResult = Invoke-BackupGit -Arguments @("bundle", "list-heads", $localBundlePath)
  $localRestoreRefsResult = Invoke-BackupGit -RepositoryPath $localRestorePath -Arguments @("show-ref")
  $expectedLocalBundleRefs = @($bundleCompatibleRefs | ForEach-Object { "$($_.refName)`t$($_.objectId)" } | Sort-Object)
  $localBundleRefs = ConvertTo-BackupComparableRefs -Lines $localBundleRefsResult.lines
  $localRestoreRefs = ConvertTo-BackupComparableRefs -Lines $localRestoreRefsResult.lines
  if (-not (Compare-BackupStringSets -Reference $expectedLocalBundleRefs -Difference $localBundleRefs).exact) {
    throw "local bundle이 commit-compatible local ref와 일치하지 않습니다."
  }
  if (-not (Compare-BackupStringSets -Reference $expectedLocalBundleRefs -Difference $localRestoreRefs).exact) {
    throw "local bundle restore가 commit-compatible local ref와 일치하지 않습니다."
  }
  $localBundleSha256 = Get-BackupFileSha256 -Path $localBundlePath

  Copy-BackupTree -Source $gitCommonDirectory -Destination $localGitSnapshotPath | Out-Null
  $gitCommonSnapshot = Get-BackupTreeManifest -RootPath $localGitSnapshotPath -ExcludeGitEntries $false
  $gitCommonAfter = Get-BackupTreeManifest -RootPath $gitCommonDirectory -ExcludeGitEntries $false
  $gitCommonToSnapshot = Compare-BackupTreeManifests -Reference $gitCommonBefore -Difference $gitCommonSnapshot
  $gitCommonStable = Compare-BackupTreeManifests -Reference $gitCommonBefore -Difference $gitCommonAfter
  Assert-BackupComparisonExact -Comparison $gitCommonToSnapshot -Label "local .git source-before/snapshot"
  Assert-BackupComparisonExact -Comparison $gitCommonStable -Label "local .git source-before/source-after"

  # Working trees: active root에서는 nested linked roots를 제외하고, 각 linked root는 별도 전체 snapshot으로 보존한다.
  $activeWorktree = @($worktreesBefore.worktrees | Where-Object {
    (Resolve-BackupPath -Path $_.sourcePath).Equals($workingTreeFullPath, [System.StringComparison]::OrdinalIgnoreCase)
  })
  if ($activeWorktree.Count -ne 1) {
    throw "활성 root worktree를 유일하게 식별할 수 없습니다."
  }
  $linkedWorktrees = @($worktreesBefore.worktrees | Where-Object {
    -not (Resolve-BackupPath -Path $_.sourcePath).Equals($workingTreeFullPath, [System.StringComparison]::OrdinalIgnoreCase)
  })
  $activeExcludedPaths = @($gitCommonDirectory) + @($linkedWorktrees | ForEach-Object { $_.sourcePath })
  $workingTreeRecords = New-Object 'System.Collections.Generic.List[object]'
  $sourceBeforeById = @{}
  foreach ($worktree in @($worktreesBefore.worktrees)) {
    $isActive = $worktree.sourcePath.Equals($workingTreeFullPath, [System.StringComparison]::OrdinalIgnoreCase)
    $excludedPaths = if ($isActive) { $activeExcludedPaths } else { @() }
    $sourceBefore = Get-BackupTreeManifest -RootPath $worktree.sourcePath -ExcludedPaths $excludedPaths -ExcludeGitEntries $true
    if ($sourceBefore.reparsePointCount -ne 0) {
      throw "worktree에 reparse point가 있습니다: $($worktree.sourcePath)"
    }
    $sourceBeforeById[$worktree.id] = $sourceBefore
    $sourceBeforePath = Join-Path $workingTreeManifestsDirectory "$($worktree.id)-source-before.json"
    Write-BackupJson -Value $sourceBefore -Path $sourceBeforePath
  }

  foreach ($worktree in @($worktreesBefore.worktrees)) {
    $isActive = $worktree.sourcePath.Equals($workingTreeFullPath, [System.StringComparison]::OrdinalIgnoreCase)
    $excludedPaths = if ($isActive) { $activeExcludedPaths } else { @() }
    $snapshotPath = Join-Path $snapshotsDirectory $worktree.id
    Copy-BackupTree -Source $worktree.sourcePath -Destination $snapshotPath -ExcludedDirectoryPaths $excludedPaths | Out-Null
    $snapshotManifest = Get-BackupTreeManifest -RootPath $snapshotPath -ExcludeGitEntries $true
    $sourceAfter = Get-BackupTreeManifest -RootPath $worktree.sourcePath -ExcludedPaths $excludedPaths -ExcludeGitEntries $true
    $sourceBefore = $sourceBeforeById[$worktree.id]
    $sourceToSnapshot = Compare-BackupTreeManifests -Reference $sourceBefore -Difference $snapshotManifest
    $sourceStable = Compare-BackupTreeManifests -Reference $sourceBefore -Difference $sourceAfter
    Assert-BackupComparisonExact -Comparison $sourceToSnapshot -Label "$($worktree.id) source-before/snapshot"
    Assert-BackupComparisonExact -Comparison $sourceStable -Label "$($worktree.id) source-before/source-after"
    $snapshotManifestPath = Join-Path $workingTreeManifestsDirectory "$($worktree.id)-snapshot.json"
    $sourceAfterPath = Join-Path $workingTreeManifestsDirectory "$($worktree.id)-source-after.json"
    Write-BackupJson -Value $snapshotManifest -Path $snapshotManifestPath
    Write-BackupJson -Value $sourceAfter -Path $sourceAfterPath
    $workingTreeRecords.Add([pscustomobject]@{
      id = $worktree.id
      sourcePath = $worktree.sourcePath
      activeRoot = $isActive
      headSha = $worktree.headSha
      branchRef = $worktree.branchRef
      detached = $worktree.detached
      indexSha256 = $worktree.indexSha256
      stagedCount = $worktree.stagedCount
      unstagedCount = $worktree.unstagedCount
      untrackedCount = $worktree.untrackedCount
      ignoredCount = $worktree.ignoredCount
      statusDigest = $worktree.statusDigest
      snapshotPath = "snapshots/$($worktree.id)"
      sourceBeforeManifestPath = "manifests/working-trees/$($worktree.id)-source-before.json"
      snapshotManifestPath = "manifests/working-trees/$($worktree.id)-snapshot.json"
      sourceAfterManifestPath = "manifests/working-trees/$($worktree.id)-source-after.json"
      fileCount = $sourceBefore.fileCount
      sizeBytes = $sourceBefore.sizeBytes
      manifestSha256 = $sourceBefore.fileManifestSha256
      sourceBeforeVsSnapshot = $sourceToSnapshot
      sourceBeforeVsSourceAfter = $sourceStable
    })
  }

  # Local/remote LFS object store는 0개인 경우에도 별도 구조와 manifest로 증명한다.
  $localLfsSourceRoot = Join-Path $gitCommonDirectory "lfs\objects"
  $localLfsSnapshotRoot = Join-Path $lfsDirectory "local-objects"
  $remoteLfsSourceRoot = Join-Path $remoteMirrorPath "lfs\objects"
  $remoteLfsSnapshotRoot = Join-Path $lfsDirectory "remote-objects"
  $localLfs = Copy-LfsBackupObjects -SourceObjectRoot $localLfsSourceRoot -DestinationObjectRoot $localLfsSnapshotRoot
  $remoteLfs = Copy-LfsBackupObjects -SourceObjectRoot $remoteLfsSourceRoot -DestinationObjectRoot $remoteLfsSnapshotRoot

  # 모든 source 상태를 다시 측정한다. 이 시점까지 migration report에는 쓰지 않았다.
  $remoteAfter = Get-RemoteBackupState -RepositoryUrl $SourceUrl
  if ($remoteBefore.refDigest -ne $remoteAfter.refDigest) {
    throw "백업 중 live remote ref가 변경되었습니다. partial을 보존하고 중단합니다."
  }
  $localScalarAfter = Get-LocalScalarState -RepositoryRoot $workingTreeFullPath
  if (-not (Test-LocalScalarStateEqual -Before $localScalarBefore -After $localScalarAfter)) {
    throw "백업 중 활성 root branch/HEAD/origin 상태가 변경되었습니다."
  }
  $localRefsAfter = Get-BackupRefs -RepositoryPath $workingTreeFullPath
  if ($localRefsBefore.digest -ne $localRefsAfter.digest) {
    throw "백업 중 local refs가 변경되었습니다."
  }
  $worktreesAfter = Get-BackupWorktreeInventory -RepositoryRoot $workingTreeFullPath
  if ($worktreesBefore.digest -ne $worktreesAfter.digest) {
    throw "백업 중 linked worktree HEAD/index/status가 변경되었습니다."
  }
  $nonMigrationAfter = Get-BackupTreeManifest `
    -RootPath $workingTreeFullPath `
    -ExcludedPaths @($migrationPath) `
    -ExcludeGitEntries $true
  $nonMigrationStable = Compare-BackupTreeManifests -Reference $nonMigrationBefore -Difference $nonMigrationAfter
  Assert-BackupComparisonExact -Comparison $nonMigrationStable -Label "non-migration 첫 측정/백업 종료"

  # 검증 기준 파일을 외부 세트 안에 기록한다.
  $manifestArtifacts = [ordered]@{}
  $manifestArtifacts["remoteRefsBefore"] = "manifests/remote-refs-source-before.json"
  $manifestArtifacts["remoteRefsMirror"] = "manifests/remote-refs-mirror.json"
  $manifestArtifacts["remoteRefsBundle"] = "manifests/remote-refs-bundle.json"
  $manifestArtifacts["remoteRefsRestore"] = "manifests/remote-refs-restore.json"
  $manifestArtifacts["remoteRefsAfter"] = "manifests/remote-refs-source-after.json"
  $manifestArtifacts["localRefsBefore"] = "manifests/local-refs-source-before.json"
  $manifestArtifacts["localRefsMirror"] = "manifests/local-refs-mirror.json"
  $manifestArtifacts["localRefsAfter"] = "manifests/local-refs-source-after.json"
  $manifestArtifacts["worktreesBefore"] = "manifests/worktrees-source-before.json"
  $manifestArtifacts["worktreesAfter"] = "manifests/worktrees-source-after.json"
  $manifestArtifacts["nonMigrationBefore"] = "manifests/non-migration-source-before.json"
  $manifestArtifacts["nonMigrationAfter"] = "manifests/non-migration-source-after.json"
  $manifestArtifacts["gitCommonBefore"] = "manifests/git-common-source-before.json"
  $manifestArtifacts["gitCommonSnapshot"] = "manifests/git-common-snapshot.json"
  $manifestArtifacts["gitCommonAfter"] = "manifests/git-common-source-after.json"
  $manifestArtifacts["localLfsBefore"] = "manifests/local-lfs-source-before.json"
  $manifestArtifacts["localLfsSnapshot"] = "manifests/local-lfs-snapshot.json"
  $manifestArtifacts["localLfsAfter"] = "manifests/local-lfs-source-after.json"
  $manifestArtifacts["remoteLfsBefore"] = "manifests/remote-lfs-source-before.json"
  $manifestArtifacts["remoteLfsSnapshot"] = "manifests/remote-lfs-snapshot.json"
  $manifestArtifacts["remoteLfsAfter"] = "manifests/remote-lfs-source-after.json"

  $artifactValues = @{
    remoteRefsBefore = $remoteBefore
    remoteRefsMirror = [pscustomobject]@{ refs = $remoteMirrorRefs }
    remoteRefsBundle = [pscustomobject]@{ refs = $remoteBundleRefs }
    remoteRefsRestore = [pscustomobject]@{ refs = $remoteRestoreRefs }
    remoteRefsAfter = $remoteAfter
    localRefsBefore = $localRefsBefore
    localRefsMirror = $localMirrorRefs
    localRefsAfter = $localRefsAfter
    worktreesBefore = $worktreesBefore
    worktreesAfter = $worktreesAfter
    nonMigrationBefore = $nonMigrationBefore
    nonMigrationAfter = $nonMigrationAfter
    gitCommonBefore = $gitCommonBefore
    gitCommonSnapshot = $gitCommonSnapshot
    gitCommonAfter = $gitCommonAfter
    localLfsBefore = $localLfs.sourceBefore
    localLfsSnapshot = $localLfs.snapshot
    localLfsAfter = $localLfs.sourceAfter
    remoteLfsBefore = $remoteLfs.sourceBefore
    remoteLfsSnapshot = $remoteLfs.snapshot
    remoteLfsAfter = $remoteLfs.sourceAfter
  }
  foreach ($key in $manifestArtifacts.Keys) {
    Write-BackupJson -Value $artifactValues[$key] -Path (Join-Path $partialSetRoot $manifestArtifacts[$key])
  }

  $localBranchCount = @($localRefsBefore.refs | Where-Object { $_.refName -match '^refs/heads/' }).Count
  $remoteTrackingRefCount = @($localRefsBefore.refs | Where-Object { $_.refName -match '^refs/remotes/' }).Count
  $localTagCount = @($localRefsBefore.refs | Where-Object { $_.refName -match '^refs/tags/' }).Count
  $stashRefCount = @($localRefsBefore.refs | Where-Object { $_.refName -eq 'refs/stash' }).Count
  $codexRefCount = @($localRefsBefore.refs | Where-Object { $_.refName -match '^refs/codex/' }).Count
  $localLfsFilesResult = Invoke-BackupGit -RepositoryPath $workingTreeFullPath -Arguments @("lfs", "ls-files", "--all", "--name-only")
  $localLfsPointerCount = @($localLfsFilesResult.lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
  $missingTotal = [int](($workingTreeRecords | ForEach-Object { $_.sourceBeforeVsSnapshot.missingFileCount + $_.sourceBeforeVsSnapshot.missingDirectoryCount } | Measure-Object -Sum).Sum)
  $extraTotal = [int](($workingTreeRecords | ForEach-Object { $_.sourceBeforeVsSnapshot.extraFileCount + $_.sourceBeforeVsSnapshot.extraDirectoryCount } | Measure-Object -Sum).Sum)
  $sizeMismatchTotal = [int](($workingTreeRecords | ForEach-Object { $_.sourceBeforeVsSnapshot.sizeMismatchCount } | Measure-Object -Sum).Sum)
  $hashMismatchTotal = [int](($workingTreeRecords | ForEach-Object { $_.sourceBeforeVsSnapshot.hashMismatchCount } | Measure-Object -Sum).Sum)

  $checksumEntries = New-Object 'System.Collections.Generic.List[string]'
  $checksumEntries.Add("manifest.json")
  $checksumEntries.Add("remote/EST-CAMP-AI-Quant-before-transfer.bundle")
  $checksumEntries.Add("local/local-state-before-transfer.bundle")
  foreach ($path in @($manifestArtifacts.Values)) { $checksumEntries.Add([string]$path) }
  foreach ($path in @(Get-ChildItem -LiteralPath $workingTreeManifestsDirectory -File | ForEach-Object {
    Get-BackupRelativePath -Root $partialSetRoot -Path $_.FullName
  })) { $checksumEntries.Add([string]$path) }
  $checksumEntryList = @($checksumEntries | Sort-Object -Unique)

  $capturedAtKst = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time").ToString("o")
  $manifest = [ordered]@{
    schemaVersion = 2
    backupType = "phase1-complete"
    backupSetName = $BackupSetName
    backupSetRoot = $backupSetRoot
    capturedAtKst = $capturedAtKst
    sourceRepository = $SourceRepository
    sourceUrl = ConvertTo-BackupSafeText -Text $SourceUrl
    sourceRepositoryRoot = $workingTreeFullPath
    sourceBranch = $localScalarBefore.branch
    sourceHeadSha = $localScalarBefore.headSha
    sourceIndexSha256 = $activeWorktree[0].indexSha256
    originMainSha = $localScalarBefore.originMainSha
    liveMainSha = $remoteBefore.headSha
    sourceDefaultBranch = $remoteBefore.defaultBranch
    remoteRefDigest = $remoteBefore.refDigest
    remoteRefCount = $remoteBefore.refCount
    remoteBranchCount = $remoteBefore.branchCount
    remoteTagCount = $remoteBefore.tagCount
    remotePullRefCount = $remoteBefore.pullRefCount
    localRefDigest = $localRefsBefore.digest
    localRefCount = $localRefsBefore.refCount
    localBranchCount = $localBranchCount
    remoteTrackingRefCount = $remoteTrackingRefCount
    tagCount = $localTagCount
    stashRefCount = $stashRefCount
    codexRefCount = $codexRefCount
    worktreeCount = $worktreesBefore.worktreeCount
    copyOnly = $true
    sourceGitMutationPerformed = $false
    gitOptionalLocksDisabled = $true
    activeRootPolicy = [ordered]@{
      excluded = @(".git", ".claude/worktrees/<각 linked worktree root: 별도 snapshot>")
      cachesIncluded = $true
      ignoredFilesIncluded = $true
      reparsePointPolicy = "발견 시 중단; 이번 세트 0개"
    }
    secretCandidateCount = $secretCandidates.Count
    secretPreservationStatus = "NOT_REQUIRED"
    secretValuesStoredInReports = $false
    remote = [ordered]@{
      mirrorPath = "remote/EST-CAMP-AI-Quant.git"
      mirrorFsckSucceeded = $remoteMirrorFsck.exitCode -eq 0
      bundlePath = "remote/EST-CAMP-AI-Quant-before-transfer.bundle"
      bundleSha256 = $remoteBundleSha256
      bundleVerifySucceeded = $remoteBundleVerify.exitCode -eq 0
      restorePath = "remote/bundle-restore-verification.git"
      restoreFsckSucceeded = $remoteRestoreFsck.exitCode -eq 0
      mirrorBundleRefsEqual = $remoteMirrorBundleComparison.exact
      mirrorRestoreRefsEqual = $remoteMirrorRestoreComparison.exact
      mirrorLiveRemoteRefsEqual = $remoteMirrorComparison.exact
    }
    local = [ordered]@{
      mirrorPath = "local/local-state.git"
      mirrorFsckSucceeded = $localMirrorFsck.exitCode -eq 0
      rawGitSnapshotPath = "local/git-common-dir-snapshot"
      rawGitSourceBeforeVsSnapshotExact = $gitCommonToSnapshot.exact
      rawGitSourceStable = $gitCommonStable.exact
      bundlePath = "local/local-state-before-transfer.bundle"
      bundleSha256 = $localBundleSha256
      bundleVerifySucceeded = $localBundleVerify.exitCode -eq 0
      restorePath = "local/bundle-restore-verification.git"
      restoreFsckSucceeded = $localRestoreFsck.exitCode -eq 0
      allRefsMirrorExact = $localRefComparison.exact
      worktreeHeadObjectCount = $worktreesBefore.worktreeCount
      allWorktreeHeadObjectsVerified = $true
      bundleCompatibleRefCount = $bundleCompatibleRefs.Count
      bundleExcludedNonCommitRefs = $bundleExcludedRefs.ToArray()
      refsSourceBeforeDigest = $localRefsBefore.digest
      refsMirrorDigest = $localMirrorRefs.digest
      refsSourceAfterDigest = $localRefsAfter.digest
      refsExact = ($localRefsBefore.digest -eq $localMirrorRefs.digest) -and ($localRefsBefore.digest -eq $localRefsAfter.digest)
    }
    worktrees = $workingTreeRecords.ToArray()
    nonMigrationBaseline = [ordered]@{
      expectedManifestSha256 = $ExpectedNonMigrationManifestSha256.ToLowerInvariant()
      sourceBeforeFileCount = $nonMigrationBefore.fileCount
      sourceBeforeSizeBytes = $nonMigrationBefore.sizeBytes
      sourceBeforeManifestSha256 = $nonMigrationBefore.fileManifestSha256
      sourceAfterManifestSha256 = $nonMigrationAfter.fileManifestSha256
      exact = $nonMigrationStable.exact
    }
    lfs = [ordered]@{
      localPointerCount = $localLfsPointerCount
      localObjectCount = $localLfs.sourceBefore.objectCount
      localObjectBytes = $localLfs.sourceBefore.objectBytes
      localOidDigest = $localLfs.sourceBefore.digest
      localObjectsCopiedExact = $localLfs.sourceToSnapshot.exact
      remotePointerCount = $remoteLfsPointerCount
      remoteObjectCount = $remoteLfs.sourceBefore.objectCount
      remoteObjectBytes = $remoteLfs.sourceBefore.objectBytes
      remoteOidDigest = $remoteLfs.sourceBefore.digest
      remoteObjectsFetched = $remoteLfsFetched
      remoteObjectsCopiedExact = $remoteLfs.sourceToSnapshot.exact
    }
    artifacts = $manifestArtifacts
    checksumsPath = "SHA256SUMS.txt"
    requiredChecksumEntries = $checksumEntryList
    verificationSummary = [ordered]@{
      remoteGitVerified = $true
      localRefsVerified = $true
      allWorktreesVerified = $true
      workingTreesVerified = $true
      lfsVerified = $true
      sourceStable = $true
      missingTotal = $missingTotal
      extraTotal = $extraTotal
      sizeMismatchTotal = $sizeMismatchTotal
      hashMismatchTotal = $hashMismatchTotal
    }
    versions = [ordered]@{
      git = (Invoke-BackupGit -Arguments @("--version")).safeText
      gitLfs = $lfsVersionResult.safeText
      powerShell = $PSVersionTable.PSVersion.ToString()
    }
  }

  if (($missingTotal + $extraTotal + $sizeMismatchTotal + $hashMismatchTotal) -ne 0) {
    throw "Working tree mismatch 합계가 0이 아닙니다."
  }
  if (-not $manifest.local.refsExact) { throw "local ref final exact 검증이 실패했습니다." }
  if (-not $manifest.nonMigrationBaseline.exact) { throw "non-migration final exact 검증이 실패했습니다." }

  $manifestPath = Join-Path $partialSetRoot "manifest.json"
  Write-BackupJson -Value $manifest -Path $manifestPath

  $checksumLines = New-Object 'System.Collections.Generic.List[string]'
  foreach ($relativePath in $checksumEntryList) {
    if ([System.IO.Path]::IsPathRooted($relativePath) -or ($relativePath -match '(^|/)\.\.(/|$)')) {
      throw "checksum 상대경로가 안전하지 않습니다: $relativePath"
    }
    $artifactPath = Resolve-BackupPath -Path (Join-Path $partialSetRoot $relativePath)
    if (-not (Test-BackupPathStrictChild -Candidate $artifactPath -Parent $partialSetRoot)) {
      throw "checksum 대상이 backup set 밖입니다: $relativePath"
    }
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
      throw "checksum 필수 파일이 없습니다: $relativePath"
    }
    $checksumLines.Add("$(Get-BackupFileSha256 -Path $artifactPath) *$relativePath")
  }
  $checksumsPath = Join-Path $partialSetRoot "SHA256SUMS.txt"
  $checksumLines | Set-Content -LiteralPath $checksumsPath -Encoding ASCII

  $parsedChecksumEntries = New-Object 'System.Collections.Generic.List[string]'
  foreach ($line in @(Get-Content -LiteralPath $checksumsPath -Encoding ASCII)) {
    if ($line -notmatch '^([0-9a-f]{64}) \*(.+)$') { throw "SHA256SUMS 형식 오류: $line" }
    $expectedHash = $Matches[1]
    $relativePath = $Matches[2].Replace('\', '/')
    if ($parsedChecksumEntries.Contains($relativePath)) { throw "SHA256SUMS 중복 항목: $relativePath" }
    $parsedChecksumEntries.Add($relativePath)
    $artifactPath = Resolve-BackupPath -Path (Join-Path $partialSetRoot $relativePath)
    if ((Get-BackupFileSha256 -Path $artifactPath) -ne $expectedHash) { throw "checksum 생성 직후 불일치: $relativePath" }
  }
  if (-not (Compare-BackupStringSets -Reference $checksumEntryList -Difference $parsedChecksumEntries.ToArray()).exact) {
    throw "SHA256SUMS 필수 엔트리 exact set 검증이 실패했습니다."
  }

  $manifestSha256 = Get-BackupFileSha256 -Path $manifestPath
  $checksumsSha256 = Get-BackupFileSha256 -Path $checksumsPath
  $complete = [ordered]@{
    schemaVersion = 1
    status = "PASS"
    backupType = "phase1-complete"
    backupSetName = $BackupSetName
    completedAtKst = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, "Korea Standard Time").ToString("o")
    sourceHeadSha = $localScalarBefore.headSha
    remoteRefDigest = $remoteBefore.refDigest
    localRefDigest = $localRefsBefore.digest
    manifestSha256 = $manifestSha256
    checksumsSha256 = $checksumsSha256
    checksumsVerified = $true
    requiredArtifactsVerified = $true
    remoteGitVerified = $true
    localRefsVerified = $true
    allWorktreesVerified = $true
    workingTreesVerified = $true
    lfsVerified = $true
    sourceStable = $true
    missingTotal = $missingTotal
    extraTotal = $extraTotal
    sizeMismatchTotal = $sizeMismatchTotal
    hashMismatchTotal = $hashMismatchTotal
  }
  $completePath = Join-Path $partialSetRoot "complete.json"
  Write-BackupJson -Value $complete -Path $completePath

  # complete.json은 세트 내부 마지막 write다. 이후에는 새 partial 디렉터리 이름만 final로 전환한다.
  if (Test-Path -LiteralPath $backupSetRoot) {
    throw "final 경로가 백업 도중 생겼습니다. 기존 경로를 덮어쓰지 않습니다: $backupSetRoot"
  }
  [System.IO.Directory]::Move($partialSetRoot, $backupSetRoot)

  $reportDirectory = Split-Path -Parent $reportFullPath
  New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  $reportLines = @(
    "# 주말 신규 백업 검증",
    "",
    "- 상태: **PASS — Phase 1 현재 상태 완전 외부 백업**",
    "- 완료 시각(KST): $($complete.completedAtKst)",
    "- 백업 세트: ``$backupSetRoot``",
    "- 현재 branch / HEAD: ``$($localScalarBefore.branch)`` / ``$($localScalarBefore.headSha)``",
    "- origin/main / live main: ``$($localScalarBefore.originMainSha)`` / ``$($remoteBefore.headSha)``",
    "- manifest SHA-256: ``$manifestSha256``",
    "- SHA256SUMS SHA-256: ``$checksumsSha256``",
    "- remote bundle SHA-256: ``$remoteBundleSha256``",
    "- local bundle SHA-256: ``$localBundleSha256``",
    "",
    "## Git 백업",
    "",
    "| 항목 | 결과 |",
    "|---|---|",
    "| Remote 전체 광고 ref | $($remoteBefore.refCount)개 (branch $($remoteBefore.branchCount), tag $($remoteBefore.tagCount), pull ref $($remoteBefore.pullRefCount)) |",
    "| Remote mirror fsck / bundle verify / restore fsck | PASS / PASS / PASS |",
    "| Local ref | $($localRefsBefore.refCount)개 (branch $localBranchCount, remote-tracking $remoteTrackingRefCount, stash $stashRefCount, refs/codex $codexRefCount) |",
    "| Local exact mirror / raw .git snapshot / bundle restore | PASS / PASS / PASS |",
    "| Bundle 비호환 non-commit ref | $($bundleExcludedRefs.Count)개 — exact local mirror와 raw .git snapshot에 보존 |",
    "",
    "## Working tree와 자료",
    "",
    "| 항목 | 결과 |",
    "|---|---|",
    "| Worktree | $($worktreesBefore.worktreeCount)개, 각 HEAD/index/status/snapshot 보존 |",
    "| source-before → snapshot | missing $missingTotal / extra $extraTotal / size mismatch $sizeMismatchTotal / hash mismatch $hashMismatchTotal |",
    "| non-migration 기준선 | $($nonMigrationBefore.fileCount)개 / $($nonMigrationBefore.sizeBytes) B / ``$($nonMigrationBefore.fileManifestSha256)`` |",
    "| 첫 측정 → 백업 종료 | exact PASS |",
    "| cache·ignored·checkpoint | 포함 |",
    "| working snapshot 제외 | ``.git``; active root 안 linked worktree 중복(각각 별도 snapshot) |",
    "| reparse point / 시크릿 파일명 후보 | 0 / 0 |",
    "",
    "## Git LFS",
    "",
    "- Local pointer/object: $($manifest.lfs.localPointerCount) / $($manifest.lfs.localObjectCount)",
    "- Remote pointer/object: $($manifest.lfs.remotePointerCount) / $($manifest.lfs.remoteObjectCount)",
    "- 0개인 object store도 별도 빈 구조와 manifest로 검증했다.",
    "",
    "## 범위 준수",
    "",
    "- 활성 저장소의 pull/fetch/checkout/switch/branch/stash/commit/push: 수행하지 않음",
    "- Repository Transfer·새 GitHub 저장소·LFS upload·remote 변경: 수행하지 않음",
    "- 기존 백업·partial·원본 파일 삭제/덮어쓰기: 수행하지 않음",
    "- copy-only source snapshot: PASS",
    "",
    "> Phase 1 PASS 후 자동 진행하지 않는다. Repository Transfer와 Private 저장소/LFS 단계는 여전히 미승인이다."
  )
  $reportLines | Set-Content -LiteralPath $reportFullPath -Encoding UTF8

  Write-Host "Phase 1 완전 백업을 생성하고 내부 검증했습니다: $backupSetRoot"
  Write-Host "검증 보고서: $reportFullPath"
}
catch {
  Write-Warning "백업 생성 또는 검증에 실패했습니다. 새 partial 경로가 존재하면 그대로 보존합니다: $partialSetRoot"
  throw
}
