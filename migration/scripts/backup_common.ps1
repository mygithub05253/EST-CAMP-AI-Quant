Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-BackupSafeText {
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
  return $safeText.Trim()
}

function Invoke-BackupNative {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [switch]$AllowNonZero
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $outputLines = @(& $Command @Arguments 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $rawText = ($outputLines -join [Environment]::NewLine).Trim()
  if (($exitCode -ne 0) -and (-not $AllowNonZero)) {
    $safeArguments = ConvertTo-BackupSafeText -Text ($Arguments -join " ")
    $safeOutput = ConvertTo-BackupSafeText -Text $rawText
    throw "명령 실행 실패(exit=$exitCode): $Command $safeArguments`n$safeOutput"
  }

  return [pscustomobject]@{
    exitCode = $exitCode
    lines = $outputLines
    rawText = $rawText
    safeText = ConvertTo-BackupSafeText -Text $rawText
  }
}

function Invoke-BackupGit {
  param(
    [string]$RepositoryPath = "",
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [switch]$AllowNonZero
  )

  $gitArguments = @("--no-optional-locks")
  if (-not [string]::IsNullOrWhiteSpace($RepositoryPath)) {
    $gitArguments += @("-C", $RepositoryPath)
  }
  $gitArguments += $Arguments
  return Invoke-BackupNative -Command "git" -Arguments $gitArguments -AllowNonZero:$AllowNonZero
}

function Resolve-BackupPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
  }
  else {
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
  }

  $pathRoot = [System.IO.Path]::GetPathRoot($fullPath)
  if ($fullPath.Length -gt $pathRoot.Length) {
    return $fullPath.TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar,
      [System.IO.Path]::AltDirectorySeparatorChar
    )
  }
  return $fullPath
}

function ConvertTo-BackupExtendedPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $fullPath = Resolve-BackupPath -Path $Path
  if ($fullPath.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
    return $fullPath
  }
  if ($fullPath.StartsWith('\\', [System.StringComparison]::Ordinal)) {
    return '\\?\UNC\' + $fullPath.Substring(2)
  }
  return '\\?\' + $fullPath
}

function ConvertFrom-BackupExtendedPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  if ($Path.StartsWith('\\?\UNC\', [System.StringComparison]::OrdinalIgnoreCase)) {
    return '\\' + $Path.Substring(8)
  }
  if ($Path.StartsWith('\\?\', [System.StringComparison]::OrdinalIgnoreCase)) {
    return $Path.Substring(4)
  }
  return $Path
}

function Test-BackupPathSameOrChild {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [Parameter(Mandatory = $true)][string]$Parent
  )

  $candidatePath = Resolve-BackupPath -Path $Candidate
  $parentPath = Resolve-BackupPath -Path $Parent
  if ($candidatePath.Equals($parentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $true
  }
  $parentPrefix = $parentPath + [System.IO.Path]::DirectorySeparatorChar
  return $candidatePath.StartsWith($parentPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-BackupPathStrictChild {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [Parameter(Mandatory = $true)][string]$Parent
  )

  $candidatePath = Resolve-BackupPath -Path $Candidate
  $parentPath = Resolve-BackupPath -Path $Parent
  if ($candidatePath.Equals($parentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $false
  }
  return Test-BackupPathSameOrChild -Candidate $candidatePath -Parent $parentPath
}

function Get-BackupTextSha256 {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

  $encoding = New-Object System.Text.UTF8Encoding($false)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $encoding.GetBytes($Text)
    return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
  }
  finally {
    $sha256.Dispose()
  }
}

function Get-BackupFileSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)

  $stream = $null
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $stream = [System.IO.File]::OpenRead((ConvertTo-BackupExtendedPath -Path $Path))
    return ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace '-', '').ToLowerInvariant()
  }
  finally {
    if ($null -ne $stream) {
      $stream.Dispose()
    }
    $sha256.Dispose()
  }
}

function Write-BackupJson {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-BackupRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $rootPath = Resolve-BackupPath -Path $Root
  $fullPath = Resolve-BackupPath -Path $Path
  if (-not (Test-BackupPathSameOrChild -Candidate $fullPath -Parent $rootPath)) {
    throw "상대경로 대상이 기준 경로 밖에 있습니다: $fullPath"
  }
  if ($fullPath.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return ""
  }
  return $fullPath.Substring($rootPath.Length).TrimStart('\', '/').Replace('\', '/')
}

function Test-BackupPathExcluded {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [string[]]$ExcludedPaths = @()
  )

  foreach ($excludedPath in @($ExcludedPaths)) {
    if ([string]::IsNullOrWhiteSpace($excludedPath)) {
      continue
    }
    if (Test-BackupPathSameOrChild -Candidate $Candidate -Parent $excludedPath) {
      return $true
    }
  }
  return $false
}

function Get-BackupTreeManifest {
  param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [string[]]$ExcludedPaths = @(),
    [bool]$ExcludeGitEntries = $true
  )

  $root = Resolve-BackupPath -Path $RootPath
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Manifest 대상 디렉터리가 없습니다: $root"
  }

  $normalizedExclusions = @($ExcludedPaths | ForEach-Object { Resolve-BackupPath -Path $_ })
  $directories = New-Object 'System.Collections.Generic.List[string]'
  $files = New-Object 'System.Collections.Generic.List[object]'
  $reparsePoints = New-Object 'System.Collections.Generic.List[object]'
  $stack = New-Object 'System.Collections.Generic.Stack[string]'
  $stack.Push($root)

  while ($stack.Count -gt 0) {
    $directory = $stack.Pop()
    $enumerationPath = ConvertTo-BackupExtendedPath -Path $directory
    foreach ($childDirectory in @(Get-ChildItem -LiteralPath $enumerationPath -Force -Directory -ErrorAction Stop)) {
      $childPath = Resolve-BackupPath -Path (ConvertFrom-BackupExtendedPath -Path $childDirectory.FullName)
      if ($ExcludeGitEntries -and ($childDirectory.Name -eq ".git")) {
        continue
      }
      if (Test-BackupPathExcluded -Candidate $childPath -ExcludedPaths $normalizedExclusions) {
        continue
      }

      $relativePath = Get-BackupRelativePath -Root $root -Path $childPath
      if (($childDirectory.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $targetProperty = $childDirectory.PSObject.Properties["Target"]
        $reparsePoints.Add([pscustomobject]@{
          relativePath = $relativePath
          itemType = "directory"
          target = if ($null -eq $targetProperty) { "" } else { [string]$targetProperty.Value }
        })
        continue
      }

      $directories.Add($relativePath)
      $stack.Push($childPath)
    }

    foreach ($file in @(Get-ChildItem -LiteralPath $enumerationPath -Force -File -ErrorAction Stop)) {
      $filePath = Resolve-BackupPath -Path (ConvertFrom-BackupExtendedPath -Path $file.FullName)
      if ($ExcludeGitEntries -and ($file.Name -eq ".git")) {
        continue
      }
      if (Test-BackupPathExcluded -Candidate $filePath -ExcludedPaths $normalizedExclusions) {
        continue
      }

      $relativePath = Get-BackupRelativePath -Root $root -Path $filePath
      if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $targetProperty = $file.PSObject.Properties["Target"]
        $reparsePoints.Add([pscustomobject]@{
          relativePath = $relativePath
          itemType = "file"
          target = if ($null -eq $targetProperty) { "" } else { [string]$targetProperty.Value }
        })
        continue
      }

      $files.Add([pscustomobject]@{
        relativePath = $relativePath
        sizeBytes = [int64]$file.Length
        sha256 = Get-BackupFileSha256 -Path $filePath
      })
    }
  }

  $orderedDirectories = @($directories | Sort-Object)
  $orderedFiles = @($files | Sort-Object relativePath)
  $directoryLines = @($orderedDirectories | ForEach-Object { "D`t$_" })
  $fileLines = @($orderedFiles | ForEach-Object { "F`t$($_.relativePath)`t$($_.sizeBytes)`t$($_.sha256)" })
  $fileOnlyLines = @($orderedFiles | ForEach-Object { "$($_.relativePath)`t$($_.sizeBytes)`t$($_.sha256)" })
  $treeText = if (($directoryLines.Count + $fileLines.Count) -gt 0) {
    (($directoryLines + $fileLines) -join "`n") + "`n"
  }
  else {
    ""
  }
  $fileText = if ($fileOnlyLines.Count -gt 0) {
    ($fileOnlyLines -join "`n") + "`n"
  }
  else {
    ""
  }

  return [pscustomobject]@{
    schemaVersion = 1
    rootPath = $root
    excludedPaths = $normalizedExclusions
    excludeGitEntries = $ExcludeGitEntries
    directoryCount = $orderedDirectories.Count
    fileCount = $orderedFiles.Count
    sizeBytes = [int64](($orderedFiles | Measure-Object sizeBytes -Sum).Sum)
    treeSha256 = Get-BackupTextSha256 -Text $treeText
    fileManifestSha256 = Get-BackupTextSha256 -Text $fileText
    reparsePointCount = $reparsePoints.Count
    reparsePoints = @($reparsePoints | Sort-Object relativePath)
    directories = $orderedDirectories
    files = $orderedFiles
  }
}

function Compare-BackupTreeManifests {
  param(
    [Parameter(Mandatory = $true)]$Reference,
    [Parameter(Mandatory = $true)]$Difference
  )

  $referenceDirectories = @{}
  foreach ($path in @($Reference.directories)) {
    $referenceDirectories[[string]$path.ToLowerInvariant()] = [string]$path
  }
  $differenceDirectories = @{}
  foreach ($path in @($Difference.directories)) {
    $differenceDirectories[[string]$path.ToLowerInvariant()] = [string]$path
  }

  $missingDirectories = @($referenceDirectories.Keys | Where-Object { -not $differenceDirectories.ContainsKey($_) } | ForEach-Object { $referenceDirectories[$_] } | Sort-Object)
  $extraDirectories = @($differenceDirectories.Keys | Where-Object { -not $referenceDirectories.ContainsKey($_) } | ForEach-Object { $differenceDirectories[$_] } | Sort-Object)

  $referenceFiles = @{}
  foreach ($file in @($Reference.files)) {
    $referenceFiles[[string]$file.relativePath.ToLowerInvariant()] = $file
  }
  $differenceFiles = @{}
  foreach ($file in @($Difference.files)) {
    $differenceFiles[[string]$file.relativePath.ToLowerInvariant()] = $file
  }

  $missingFiles = New-Object 'System.Collections.Generic.List[string]'
  $extraFiles = New-Object 'System.Collections.Generic.List[string]'
  $sizeMismatches = New-Object 'System.Collections.Generic.List[object]'
  $hashMismatches = New-Object 'System.Collections.Generic.List[object]'
  foreach ($key in $referenceFiles.Keys) {
    if (-not $differenceFiles.ContainsKey($key)) {
      $missingFiles.Add([string]$referenceFiles[$key].relativePath)
      continue
    }
    $left = $referenceFiles[$key]
    $right = $differenceFiles[$key]
    if ([int64]$left.sizeBytes -ne [int64]$right.sizeBytes) {
      $sizeMismatches.Add([pscustomobject]@{
        relativePath = $left.relativePath
        expected = [int64]$left.sizeBytes
        actual = [int64]$right.sizeBytes
      })
    }
    if ([string]$left.sha256 -ne [string]$right.sha256) {
      $hashMismatches.Add([pscustomobject]@{
        relativePath = $left.relativePath
        expected = [string]$left.sha256
        actual = [string]$right.sha256
      })
    }
  }
  foreach ($key in $differenceFiles.Keys) {
    if (-not $referenceFiles.ContainsKey($key)) {
      $extraFiles.Add([string]$differenceFiles[$key].relativePath)
    }
  }

  $missingFilesOrdered = @($missingFiles | Sort-Object)
  $extraFilesOrdered = @($extraFiles | Sort-Object)
  $sizeMismatchesOrdered = @($sizeMismatches | Sort-Object relativePath)
  $hashMismatchesOrdered = @($hashMismatches | Sort-Object relativePath)
  $exact = (
    ($missingDirectories.Count -eq 0) -and
    ($extraDirectories.Count -eq 0) -and
    ($missingFilesOrdered.Count -eq 0) -and
    ($extraFilesOrdered.Count -eq 0) -and
    ($sizeMismatchesOrdered.Count -eq 0) -and
    ($hashMismatchesOrdered.Count -eq 0) -and
    ([string]$Reference.treeSha256 -eq [string]$Difference.treeSha256)
  )

  return [pscustomobject]@{
    exact = $exact
    missingDirectoryCount = $missingDirectories.Count
    extraDirectoryCount = $extraDirectories.Count
    missingFileCount = $missingFilesOrdered.Count
    extraFileCount = $extraFilesOrdered.Count
    sizeMismatchCount = $sizeMismatchesOrdered.Count
    hashMismatchCount = $hashMismatchesOrdered.Count
    missingDirectories = $missingDirectories
    extraDirectories = $extraDirectories
    missingFiles = $missingFilesOrdered
    extraFiles = $extraFilesOrdered
    sizeMismatches = $sizeMismatchesOrdered
    hashMismatches = $hashMismatchesOrdered
  }
}

function Copy-BackupTree {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string[]]$ExcludedDirectoryPaths = @()
  )

  if ($null -eq (Get-Command -Name "robocopy" -ErrorAction SilentlyContinue)) {
    throw "copy-only snapshot에 필요한 robocopy를 찾을 수 없습니다."
  }
  if (Test-Path -LiteralPath $Destination) {
    throw "새 snapshot 대상 경로가 이미 존재합니다: $Destination"
  }

  $arguments = @(
    $Source,
    $Destination,
    "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:1", "/XJ",
    "/NFL", "/NDL", "/NJH", "/NJS", "/NP",
    "/XF", ".git"
  )
  $usableExclusions = @($ExcludedDirectoryPaths | Where-Object {
    (Test-Path -LiteralPath $_ -PathType Container) -and
    (Test-BackupPathSameOrChild -Candidate $_ -Parent $Source)
  })
  if ($usableExclusions.Count -gt 0) {
    $arguments += "/XD"
    $arguments += $usableExclusions
  }

  $result = Invoke-BackupNative -Command "robocopy" -Arguments $arguments -AllowNonZero
  if ($result.exitCode -gt 7) {
    throw "robocopy snapshot 실패(exit=$($result.exitCode)): $($result.safeText)"
  }
  return $result
}

function Get-BackupRefs {
  param([Parameter(Mandatory = $true)][string]$RepositoryPath)

  $result = Invoke-BackupGit -RepositoryPath $RepositoryPath -Arguments @(
    "for-each-ref",
    "--format=%(refname)%09%(objectname)%09%(objecttype)",
    "refs"
  )
  $refs = New-Object 'System.Collections.Generic.List[object]'
  foreach ($line in @($result.lines)) {
    if ($line -match '^(refs/\S+)\t([0-9a-fA-F]{40,64})\t(\S+)$') {
      $refs.Add([pscustomobject]@{
        refName = $Matches[1]
        objectId = $Matches[2].ToLowerInvariant()
        objectType = $Matches[3]
      })
    }
  }
  $ordered = @($refs | Sort-Object refName)
  $lines = @($ordered | ForEach-Object { "$($_.refName)`t$($_.objectId)`t$($_.objectType)" })
  $text = if ($lines.Count -gt 0) { ($lines -join "`n") + "`n" } else { "" }
  return [pscustomobject]@{
    refs = $ordered
    refCount = $ordered.Count
    digest = Get-BackupTextSha256 -Text $text
  }
}

function ConvertTo-BackupComparableRefs {
  param([Parameter(Mandatory = $true)][string[]]$Lines)

  $refs = New-Object 'System.Collections.Generic.List[string]'
  foreach ($line in @($Lines)) {
    if (($line -notmatch '\^\{\}$') -and ($line -match '^([0-9a-fA-F]{40,64})\s+(refs/\S+)$')) {
      $refs.Add("$($Matches[2])`t$($Matches[1].ToLowerInvariant())")
    }
  }
  return @($refs | Sort-Object -Unique)
}

function Compare-BackupStringSets {
  param(
    [Parameter(Mandatory = $true)][string[]]$Reference,
    [Parameter(Mandatory = $true)][string[]]$Difference
  )

  $changes = @(Compare-Object -ReferenceObject @($Reference) -DifferenceObject @($Difference))
  return [pscustomobject]@{
    exact = $changes.Count -eq 0
    differenceCount = $changes.Count
    differences = $changes
  }
}

function Get-BackupWorktreeInventory {
  param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

  $listResult = Invoke-BackupGit -RepositoryPath $RepositoryRoot -Arguments @("worktree", "list", "--porcelain")
  $blocks = New-Object 'System.Collections.Generic.List[object]'
  $current = [ordered]@{}
  foreach ($line in @($listResult.lines + "")) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      if ($current.Contains("worktree")) {
        $blocks.Add([pscustomobject]$current)
      }
      $current = [ordered]@{}
      continue
    }
    if ($line -match '^worktree\s+(.+)$') { $current.worktree = $Matches[1]; continue }
    if ($line -match '^HEAD\s+(.+)$') { $current.head = $Matches[1]; continue }
    if ($line -match '^branch\s+(.+)$') { $current.branchRef = $Matches[1]; continue }
    if ($line -eq "detached") { $current.detached = $true; continue }
    if ($line -eq "bare") { $current.bare = $true; continue }
    if ($line -match '^locked(?:\s+(.*))?$') { $current.locked = $true; $current.lockReason = [string]$Matches[1]; continue }
    if ($line -match '^prunable(?:\s+(.*))?$') { $current.prunable = $true; $current.prunableReason = [string]$Matches[1]; continue }
  }

  $worktrees = New-Object 'System.Collections.Generic.List[object]'
  $ordinal = 0
  foreach ($block in $blocks.ToArray()) {
    $ordinal++
    $worktreePath = Resolve-BackupPath -Path $block.worktree
    $statusResult = Invoke-BackupGit -RepositoryPath $worktreePath -Arguments @(
      "status", "--porcelain=v2", "--branch", "--untracked-files=all", "--ignored=matching"
    )
    $records = @($statusResult.lines | Where-Object { $_ -notmatch '^# ' })
    $trackedRecords = @($records | Where-Object { $_ -match '^[12u] ' })
    $untrackedRecords = @($records | Where-Object { $_ -match '^\? ' })
    $ignoredRecords = @($records | Where-Object { $_ -match '^! ' })
    $stagedCount = 0
    $unstagedCount = 0
    foreach ($record in $trackedRecords) {
      if ($record.Length -ge 4) {
        $xy = $record.Substring(2, 2)
        if ($xy[0] -ne '.') { $stagedCount++ }
        if ($xy[1] -ne '.') { $unstagedCount++ }
      }
    }

    $indexPathResult = Invoke-BackupGit -RepositoryPath $worktreePath -Arguments @("rev-parse", "--git-path", "index")
    $indexPathRaw = [string]($indexPathResult.lines | Select-Object -First 1)
    $indexPath = if ([System.IO.Path]::IsPathRooted($indexPathRaw)) {
      Resolve-BackupPath -Path $indexPathRaw
    }
    else {
      Resolve-BackupPath -Path (Join-Path $worktreePath $indexPathRaw)
    }
    $indexItem = Get-Item -LiteralPath $indexPath -ErrorAction Stop
    $gitDirectoryResult = Invoke-BackupGit -RepositoryPath $worktreePath -Arguments @("rev-parse", "--git-dir")
    $gitDirectoryRaw = [string]($gitDirectoryResult.lines | Select-Object -First 1)
    $gitDirectory = if ([System.IO.Path]::IsPathRooted($gitDirectoryRaw)) {
      Resolve-BackupPath -Path $gitDirectoryRaw
    }
    else {
      Resolve-BackupPath -Path (Join-Path $worktreePath $gitDirectoryRaw)
    }
    $gitMarkerPath = Join-Path $worktreePath ".git"
    $gitMarkerText = if (Test-Path -LiteralPath $gitMarkerPath -PathType Leaf) {
      Get-Content -LiteralPath $gitMarkerPath -Raw -Encoding UTF8
    }
    else {
      ""
    }
    $safeLeaf = ((Split-Path -Leaf $worktreePath) -replace '[^A-Za-z0-9._-]', '_')
    $id = "{0:D2}-{1}" -f $ordinal, $safeLeaf
    $branchProperty = $block.PSObject.Properties["branchRef"]
    $detachedProperty = $block.PSObject.Properties["detached"]
    $lockedProperty = $block.PSObject.Properties["locked"]
    $lockReasonProperty = $block.PSObject.Properties["lockReason"]
    $prunableProperty = $block.PSObject.Properties["prunable"]
    $prunableReasonProperty = $block.PSObject.Properties["prunableReason"]

    $statusText = if ($statusResult.lines.Count -gt 0) {
      ($statusResult.lines -join "`n") + "`n"
    }
    else {
      ""
    }
    $worktrees.Add([pscustomobject]@{
      id = $id
      sourcePath = $worktreePath
      headSha = [string]$block.head
      branchRef = if ($null -eq $branchProperty) { "" } else { [string]$branchProperty.Value }
      detached = if ($null -eq $detachedProperty) { $false } else { [bool]$detachedProperty.Value }
      locked = if ($null -eq $lockedProperty) { $false } else { [bool]$lockedProperty.Value }
      lockReason = if ($null -eq $lockReasonProperty) { "" } else { [string]$lockReasonProperty.Value }
      prunable = if ($null -eq $prunableProperty) { $false } else { [bool]$prunableProperty.Value }
      prunableReason = if ($null -eq $prunableReasonProperty) { "" } else { [string]$prunableReasonProperty.Value }
      gitDirectory = $gitDirectory
      gitMarkerText = $gitMarkerText.Trim()
      indexPath = $indexPath
      indexSizeBytes = [int64]$indexItem.Length
      indexSha256 = Get-BackupFileSha256 -Path $indexPath
      stagedCount = $stagedCount
      unstagedCount = $unstagedCount
      trackedChangeCount = $trackedRecords.Count
      untrackedCount = $untrackedRecords.Count
      ignoredCount = $ignoredRecords.Count
      statusDigest = Get-BackupTextSha256 -Text $statusText
      statusLines = @($statusResult.lines)
    })
  }

  $digestLines = @($worktrees | ForEach-Object {
    "$($_.id)`t$($_.sourcePath)`t$($_.headSha)`t$($_.branchRef)`t$($_.detached)`t$($_.indexSha256)`t$($_.statusDigest)"
  })
  $digestText = if ($digestLines.Count -gt 0) { ($digestLines -join "`n") + "`n" } else { "" }
  return [pscustomobject]@{
    schemaVersion = 1
    worktreeCount = $worktrees.Count
    digest = Get-BackupTextSha256 -Text $digestText
    worktrees = $worktrees.ToArray()
  }
}

function Test-BackupSecretRelativePath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)

  $leaf = (Split-Path -Leaf $RelativePath).ToLowerInvariant()
  if (($leaf -eq ".env") -or $leaf.StartsWith(".env.")) { return $true }
  if ($leaf -in @("id_rsa", "id_ed25519", "credentials.json", "secrets.json")) { return $true }
  $extension = [System.IO.Path]::GetExtension($leaf)
  return $extension -in @(".pem", ".key", ".pfx", ".p12")
}

function Get-BackupLfsObjectManifest {
  param([Parameter(Mandatory = $true)][string]$ObjectRoot)

  $root = Resolve-BackupPath -Path $ObjectRoot
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    return [pscustomobject]@{
      schemaVersion = 1
      objectRoot = $root
      objectCount = 0
      objectBytes = [int64]0
      oidCount = 0
      invalidOidPathCount = 0
      oidHashMismatchCount = 0
      digest = Get-BackupTextSha256 -Text ""
      objects = @()
    }
  }

  $objects = New-Object 'System.Collections.Generic.List[object]'
  foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction Stop)) {
    $relativePath = Get-BackupRelativePath -Root $root -Path $file.FullName
    $sha256 = Get-BackupFileSha256 -Path $file.FullName
    $leaf = $file.Name.ToLowerInvariant()
    $oid = if ($leaf -match '^[0-9a-f]{64}$') { $leaf } else { "" }
    $objects.Add([pscustomobject]@{
      relativePath = $relativePath
      sizeBytes = [int64]$file.Length
      sha256 = $sha256
      oid = $oid
      oidMatchesContent = if ([string]::IsNullOrWhiteSpace($oid)) { $false } else { $oid -eq $sha256 }
    })
  }
  $ordered = @($objects | Sort-Object relativePath)
  $lines = @($ordered | ForEach-Object { "$($_.relativePath)`t$($_.sizeBytes)`t$($_.sha256)`t$($_.oid)" })
  $text = if ($lines.Count -gt 0) { ($lines -join "`n") + "`n" } else { "" }
  return [pscustomobject]@{
    schemaVersion = 1
    objectRoot = $root
    objectCount = $ordered.Count
    objectBytes = [int64](($ordered | Measure-Object sizeBytes -Sum).Sum)
    oidCount = @($ordered | Where-Object { -not [string]::IsNullOrWhiteSpace($_.oid) }).Count
    invalidOidPathCount = @($ordered | Where-Object { [string]::IsNullOrWhiteSpace($_.oid) }).Count
    oidHashMismatchCount = @($ordered | Where-Object { (-not [string]::IsNullOrWhiteSpace($_.oid)) -and (-not $_.oidMatchesContent) }).Count
    digest = Get-BackupTextSha256 -Text $text
    objects = $ordered
  }
}
