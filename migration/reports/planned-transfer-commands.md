# 실제 실행 예정 명령

아래 명령은 **아직 실행하지 않았습니다**. 사용자 승인과 required check 충족 후 사용합니다.

## 0. 현재 승인 상태와 Gate A 다음 명령

- 승인됨: Phase 0 읽기 전용 조사와 `migration/` 보고서 작성
- 미승인: 신규 외부 백업, Private 저장소 생성, LFS upload, Repository Transfer, origin 변경, 삭제
- 현재 실제 Transfer: **No-Go**

Gate A에서 사용자가 20~30분 편집 중단과 신규 외부 백업을 승인한 경우에만 먼저 `create_backup.ps1`을 local refs·stash·worktree·SHA exact 요구에 맞게 보완하고 parser·dry-run을 통과시킨다. 그 뒤 다음 명령을 실행한다.

```powershell
Set-Location -LiteralPath 'C:\Users\kik32\workspace\EST-Camp-AI-Quant'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$head = (git rev-parse --short=12 HEAD).Trim()
$backupSetName = "before-transfer-$timestamp-$head"
$backupRoot = 'C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration'
$backupScript = 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\scripts\create_backup.ps1'
$reportPath = 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-backup-verification.md'

# 보완된 동작의 dry-run: 외부 쓰기와 Git 변경 없음
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $backupScript `
  -SourceRepository 'mygithub05253/EST-CAMP-AI-Quant' `
  -SourceUrl 'https://github.com/mygithub05253/EST-CAMP-AI-Quant.git' `
  -WorkingTreePath 'C:\Users\kik32\workspace\EST-Camp-AI-Quant' `
  -BackupRoot $backupRoot `
  -BackupSetName $backupSetName `
  -IncludeWorkingTreeSnapshot `
  -ReportPath $reportPath

if ($LASTEXITCODE -ne 0) {
  throw "백업 dry-run 실패: exit=$LASTEXITCODE"
}

# Gate A 승인과 편집 중단 확인 뒤 copy-only 완전 백업
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $backupScript `
  -SourceRepository 'mygithub05253/EST-CAMP-AI-Quant' `
  -SourceUrl 'https://github.com/mygithub05253/EST-CAMP-AI-Quant.git' `
  -WorkingTreePath 'C:\Users\kik32\workspace\EST-Camp-AI-Quant' `
  -BackupRoot $backupRoot `
  -BackupSetName $backupSetName `
  -IncludeWorkingTreeSnapshot `
  -ReportPath $reportPath `
  -Execute

if ($LASTEXITCODE -ne 0) {
  throw "완전 백업 실패: exit=$LASTEXITCODE. .partial-*를 보존하고 중단합니다."
}
```

이 명령은 활성 루트의 branch, HEAD, index, stash, remote, 파일 내용을 바꾸지 않는다. 외부 backup 디렉터리와 `migration/reports/`에만 쓰며, 실패 시 기존 백업이나 `.partial-*`를 삭제하지 않는다.

## Phase 1 백업 완료 뒤 PreTransfer 검증 예정 명령

```powershell
$backupManifest = Join-Path (Join-Path $backupRoot $backupSetName) 'manifest.json'

& powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\scripts\validate_transfer.ps1' `
  -Mode PreTransfer `
  -SourceRepository 'mygithub05253/EST-CAMP-AI-Quant' `
  -TargetRepository 'EST-Bootcamp-AI-Quant/EST-CAMP-AI-Quant' `
  -RepositoryRoot 'C:\Users\kik32\workspace\EST-Camp-AI-Quant' `
  -BeforeRepositoryPath 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-current\repository-before.json' `
  -BackupManifestPath $backupManifest `
  -OutputDirectory 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-current' `
  -Execute

if ($LASTEXITCODE -ne 0) {
  throw "이관 전 검증 실패: exit=$LASTEXITCODE. Transfer는 No-Go입니다."
}
```

아래 1~7절은 **더 나중의 별도 승인 단계**를 위한 참고 명령이다. Gate A 승인으로 실행하지 않는다.

## 1. 누락 권한을 승인받아 읽기 전용 재조사

이 명령은 GitHub CLI token scope를 확장하므로 사용자 승인·브라우저 인증이 필요합니다.

```powershell
gh auth refresh -h github.com -s admin:org -s read:project

gh api orgs/EST-Bootcamp-AI-Quant/actions/permissions
gh api orgs/EST-Bootcamp-AI-Quant/actions/permissions/workflow
gh api orgs/EST-Bootcamp-AI-Quant/rulesets
gh api orgs/EST-Bootcamp-AI-Quant/actions/secrets
gh api orgs/EST-Bootcamp-AI-Quant/actions/variables
```

Secret은 이름만 확인하고 값은 조회·저장하지 않습니다.

## 2. 짧은 maintenance window에서 로컬 상태 확정

```powershell
$env:GIT_OPTIONAL_LOCKS = "0"
git --no-optional-locks status --short --branch --untracked-files=all
git worktree list --porcelain
git stash list
git branch --all
git tag --list
git rev-parse HEAD
git ls-remote https://github.com/mygithub05253/EST-CAMP-AI-Quant.git refs/heads/main
```

사용자 수업 변경을 먼저 안전한 개인 branch에 commit/push하거나 별도 스냅샷으로 보존해야 합니다. 이번 migration 파일과 수업 파일을 한 commit에 섞지 않습니다.

## 3. Inventory·백업·이관 전 검증 재실행

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\migration\scripts\collect_inventory.ps1 `
  -Execute

powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\migration\scripts\create_backup.ps1 `
  -BackupRoot "C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration" `
  -Execute

powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\migration\scripts\validate_transfer.ps1 `
  -Mode PreTransfer `
  -BackupManifestPath "<새 불변 백업 세트>\manifest.json" `
  -Execute
```

`PreTransfer` 결과의 필수 FAIL·UNKNOWN이 0이어야 합니다.

## 4. 권장 실제 Transfer 방식: GitHub UI

```text
mygithub05253/EST-CAMP-AI-Quant
→ Settings
→ General
→ Danger Zone
→ Transfer

New owner: EST-Bootcamp-AI-Quant
Repository name: EST-CAMP-AI-Quant
Confirmation: EST-CAMP-AI-Quant
```

전송하면서 이름을 바꾸지 않습니다.

## 5. 사용자가 CLI/API 방식을 별도로 승인한 경우만 실행

```powershell
gh api `
  --method POST `
  -H "Accept: application/vnd.github+json" `
  -H "X-GitHub-Api-Version: 2022-11-28" `
  repos/mygithub05253/EST-CAMP-AI-Quant/transfer `
  -f new_owner="EST-Bootcamp-AI-Quant" `
  -f new_name="EST-CAMP-AI-Quant"
```

`202 Accepted`를 완료로 간주하지 않고 재전송도 자동 시도하지 않습니다.

## 6. 이관 직후 읽기 전용 검증

```powershell
gh api repos/EST-Bootcamp-AI-Quant/EST-CAMP-AI-Quant
git ls-remote https://github.com/EST-Bootcamp-AI-Quant/EST-CAMP-AI-Quant.git

powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\migration\scripts\validate_transfer.ps1 `
  -Mode PostTransfer `
  -Execute
```

검증 기준:

- numeric Repository ID exact
- 기본 branch와 `main` SHA exact
- 모든 branch/tag ref→SHA exact
- issue/PR/release/label/milestone/workflow/environment/secret 이름/deploy key/webhook/ruleset/collaborator stable key exact
- Pages·Actions·App·security policy 별도 기능 점검

## 7. 전송 검증 통과 후에만 로컬 origin 변경

```powershell
git remote set-url origin `
  https://github.com/EST-Bootcamp-AI-Quant/EST-CAMP-AI-Quant.git

git remote -v
git fetch origin --prune --tags
git status
git pull --ff-only origin main
```

이 단계도 working tree clean과 사용자 승인 후 실행합니다.

## 명시적으로 실행하지 않을 명령

```text
git push --force
git reset --hard
git filter-repo (일상 working tree에서)
기존 폴더 삭제
기존 저장소 rename/archive
새 분리 저장소 생성·push
Organization Ruleset·Actions 설정 변경
```
