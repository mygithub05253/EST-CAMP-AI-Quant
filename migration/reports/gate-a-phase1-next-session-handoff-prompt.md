# Gate A · Phase 1 완전 백업 — 다음 세션 핸드오프 프롬프트

Gate A를 승인합니다. 이 메시지를 보낸 시점부터 약 20~30분 동안 `C:\Users\kik32\workspace\EST-Camp-AI-Quant`의 수업 파일 저장·수정을 중단했습니다.

아래 내용을 이 작업의 실행 명세로 사용하세요. 모든 대화·주석·보고서는 한국어로 작성하세요.

## 1. 이번 세션의 유일한 목표

2026-07-21에 완료한 Phase 0을 이어서 **Phase 1 — 현재 상태의 완전한 외부 백업**까지만 수행하세요.

이번 승인으로 허용되는 쓰기 범위는 다음뿐입니다.

1. `migration/scripts/create_backup.ps1`, `migration/scripts/validate_transfer.ps1` 및 필요 최소한의 `migration/` 보조 스크립트 보완
2. `migration/reports/`의 Phase 1 보고서 갱신
3. `C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-<KST timestamp>-<HEAD>`라는 **새 경로**에 copy-only 백업 생성

다음은 승인하지 않습니다.

- Repository Transfer
- 새 GitHub 저장소 또는 Private 자료 저장소 생성
- Organization 설정·OAuth scope·App 설치 변경
- Git LFS tracking·commit·push·upload
- 활성 저장소의 `pull`, `fetch`, checkout, switch, branch 생성, stash 변경, commit, push, PR
- remote URL 변경
- force push, reset, clean, history rewrite
- 기존 백업·`.partial-*`·폴더·파일 삭제 또는 덮어쓰기
- 수업 파일·notebook·이미지·데이터·`.gitignore`·`AGENTS.md` 수정

Phase 1이 PASS해도 다음 단계로 자동 진행하지 말고 결과를 보고한 뒤 멈추세요.

## 2. 반드시 먼저 읽을 파일

다음 파일을 완전히 읽고 상충 시 위에서 아래 순서로 적용하세요.

1. `C:\Users\kik32\Downloads\CODEX_GITHUB_ORG_MIGRATION_PLAN.md`
2. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\AGENTS.md`
3. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-migration-handoff-prompt.md`
4. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-preflight.md`
5. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-preflight.json`
6. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\material-manifest.json`
7. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\material-path-mapping.md`
8. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-backup-verification.md`
9. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\risk-and-blockers.md`
10. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\planned-transfer-commands.md`
11. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\scripts\collect_inventory.ps1`
12. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\scripts\create_backup.ps1`
13. `C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\scripts\validate_transfer.ps1`

저장소에 적용되는 Git/GitHub workflow skill이나 규칙이 있다면 읽되, 일반적인 “작업 전 pull”보다 이 migration의 현 상태 보존 규칙이 우선합니다.

## 3. 직전 세션의 확인값 — 참고 기준

이 값은 hardcode하지 말고 이번 세션 시작 시 다시 측정하세요.

- 기준 시각: 2026-07-21 09:42 KST
- 활성 루트: `C:\Users\kik32\workspace\EST-Camp-AI-Quant`
- branch: `main`
- 로컬 HEAD = `origin/main` = live GitHub `main`:
  `8e3546c83d7dd874fa67cb02d441076d58a2e615`
- origin: `https://github.com/mygithub05253/EST-CAMP-AI-Quant.git`
- tracked diff 0, staged 0
- 로컬 branch 10, 원격 branch 8, tag 0, stash 1, linked worktree 4
- linked worktree 2곳에 `.serena/*` 미추적 도구 파일 존재
- `.gitattributes` 없음, LFS pointer/object 0
- `migration/` 밖 미추적 파일 3개:
  - `assignments/05-time-series/시계열분석_풀이.ipynb`
    - 461,845 B
    - SHA-256 `5207E9F9B254D4B1E5B6C29566952AA8037BA9FD8A3DB81B961A1E5807E38CDF`
  - `docs/image/web-cam-image.jpg`
    - 311,060 B
    - SHA-256 `6A189299ED457513B80FE9936F3AEC01DE90558F04A8623044D1C6B17FCED8AE`
  - `docs/image/zoom-web-cam-image.png`
    - 311,060 B
    - SHA-256 `6A189299ED457513B80FE9936F3AEC01DE90558F04A8623044D1C6B17FCED8AE`
- 자료 manifest:
  - 348개 / 1,125,762,859 B
  - SHA-256 `99ABEA79A9836AF81BB1B0B44BEF70DF85811B53FCBE962929A9676AB7081F47`
  - tracked 263, untracked 3, ignored 82
- root snapshot 예비값: 486개 / 1,126,611,563 B
- C: 여유: 약 185.21 GiB
- Phase 1 추가 사용량 상한: 약 1.45 GB
- 전체 후속 shadow/LFS/clone 포함 상한: 약 9.30 GB

직전 값과 달라도 삭제·되돌리기·pull하지 마세요. 새 세션 전에 사용자가 만든 변경이면 현재 상태로 다시 baseline을 잡아 전부 보호하세요. 다만 첫 측정과 백업 직전 측정 사이에 non-`migration/` 파일의 경로·크기·해시가 계속 변하면 동시 편집으로 판단하고 백업을 실행하지 말고 사용자에게 알리세요.

## 4. 시작 직후 읽기 전용 재확인

활성 루트에서는 `GIT_OPTIONAL_LOCKS=0`과 `git --no-optional-locks`를 사용하세요.

최소한 다음을 다시 확인하세요.

- `git status --porcelain=v2 --branch --untracked-files=all`
- 현재 branch, HEAD, index, `origin/main`, remote URL
- `git ls-remote`로 live `main`
- 모든 local/remote ref, `refs/stash`, `refs/codex/*`, tag
- `git worktree list --porcelain`과 각 worktree의 dirty/untracked/ignored 상태
- 자료 및 non-`migration/` 파일 fingerprint
- `.env`, key, private-key, credential 파일명과 시크릿 후보 존재 여부 — 값은 출력·보고서 저장 금지
- Git LFS 설치/config/pointer/object/cache 상태
- 외부 백업 루트와 C: 여유 공간
- 백업 대상 경로가 workspace 내부가 아닌지, 기존 세트와 충돌하지 않는지

활성 루트에서 `git fetch`, `git pull`, checkout, switch, stash를 먼저 실행하지 마세요. 현재 dirty/untracked/ignored 상태 자체가 백업 대상입니다.

## 5. 기존 백업을 재사용하면 안 되는 이유

기존 검증 세트:

`C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-e04abb769740-4c319b33d321`

이 세트는 `e04abb...` 기준 원격 Git mirror·bundle만 검증됐고 현재 HEAD, working tree, local-only ref, stash, linked worktree, ignored 자료를 포함하지 않습니다. 현재 복구 기준으로 사용하지 마세요.

기존 `.partial-*`도 삭제하거나 덮어쓰지 마세요.

## 6. 백업 스크립트의 현재 GAP — 실행 전에 반드시 보완

현재 `create_backup.ps1`은 원격 fresh mirror, `fsck`, bundle, restore clone, heads/tags ref 비교는 검증됐습니다. 그러나 이 상태로 `-Execute`하면 안 됩니다.

최소한 다음 요구를 코드와 검증에 추가하세요.

1. 세트명은 `before-transfer-<KST timestamp>-<HEAD>-<local-state-digest>`처럼 working state가 바뀌면 절대 재사용되지 않게 합니다.
2. 원격 fresh mirror를 만들고 `git fsck --full --strict`를 통과시킵니다.
3. `git ls-remote`의 모든 광고 ref를 canonical `ref<TAB>sha`로 저장하고 mirror와 exact 비교합니다. heads/tags만 비교하지 않습니다.
4. 활성 저장소의 모든 local ref를 보존합니다.
   - local branch
   - remote-tracking ref
   - tag
   - `refs/stash`
   - `refs/codex/*`
   - 각 linked worktree HEAD
5. local Git archive 또는 full `.git` 안전 복사본을 외부 세트에 추가하여 reflog·worktree metadata·도달 가능한 local 상태를 보존합니다. hardlink에 의존하지 않습니다.
6. local+remote ref bundle을 만들고 빈 restore clone에서 verify·fsck·ref exact를 검사합니다.
7. root working tree와 각 linked worktree의 상태 inventory를 별도로 저장합니다.
8. root snapshot에는 tracked·untracked·ignored 자료와 checkpoint를 포함합니다. `.git`과 `.claude/worktrees` 중복만 root snapshot에서 제외하고, linked worktree별 dirty/untracked 상태는 별도 snapshot으로 보존합니다.
9. source-before → snapshot → source-after의 상대경로·크기·SHA-256을 비교합니다.
   - missing 0
   - extra 0
   - size mismatch 0
   - hash mismatch 0
10. 시크릿 후보가 새로 발견되면 평문 snapshot을 만들지 말고 중단합니다. 발견 사실만 보고하고 암호화 보존 방식에 대한 별도 승인을 요청합니다.
11. local LFS cache가 있으면 별도 복사하고 pointer OID·파일 크기·객체 SHA manifest와 `git lfs fsck --objects --pointers` 결과를 남깁니다. 현재 객체 0개여도 0임을 증명합니다.
12. 실패 세트는 `.partial-*`로 보존하고 자동 삭제하지 않습니다.
13. 모든 필수 검증이 PASS일 때만 `complete.json`을 생성합니다.
14. 활성 루트의 non-`migration/` 파일, branch, HEAD, index, stash, worktree, remote가 시작·종료에 exact임을 확인합니다.

스크립트 자체와 보고서를 `migration/`에서 수정한 뒤 그 상태를 baseline으로 잡으세요. 실제 파일 복사 중에는 source에 보고서를 계속 쓰지 말고, 외부 partial 세트에 로그·manifest를 쓴 뒤 검증 종료 후 최종 보고서만 `migration/reports/`로 복사·갱신하세요. `migration/` 변경은 별도 allowlist diff로 보고하세요.

## 7. 안전 구현 규칙

- Windows PowerShell 5.1에서 parser 오류 0이어야 합니다.
- 모든 스크립트는 기본 dry-run이고 `-Execute`가 있을 때만 외부 백업을 씁니다.
- 경로는 `Resolve-Path`/`GetFullPath`로 정규화하고 외부 백업 대상이 workspace·repo root·drive root가 아님을 확인합니다.
- 복사는 copy-only로 수행하고 `/MIR`, `Move-Item`을 이용한 원본 이동, 재귀 삭제를 사용하지 않습니다.
- partial→final rename이 필요하면 두 경로가 승인된 backup root 내부인지 absolute path로 재검증한 뒤 외부 세트에서만 수행합니다.
- 기존 경로가 있으면 덮어쓰지 말고 새 timestamp를 생성하거나 중단합니다.
- 원본에 대한 restore·overwrite 테스트는 하지 않습니다. 복구 검증은 새 임시 clone/snapshot 비교로만 합니다.
- 로그에 token, secret 값, credential URL, 결제 이메일, 개인정보 후보 값을 저장하지 않습니다.
- 장시간 작업 중 60초 이상 사용자를 방치하지 말고 현재 검증 단계를 짧게 알려 주세요.

## 8. 승인된 실제 실행 흐름

먼저 parser와 dry-run을 검증하세요. 그다음 동일한 `$backupSetName`으로 실제 백업을 한 번만 실행하세요.

```powershell
Set-Location -LiteralPath 'C:\Users\kik32\workspace\EST-Camp-AI-Quant'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$head = (git rev-parse --short=12 HEAD).Trim()
$backupSetName = "before-transfer-$timestamp-$head"
$backupRoot = 'C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration'
$backupScript = 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\scripts\create_backup.ps1'
$reportPath = 'C:\Users\kik32\workspace\EST-Camp-AI-Quant\migration\reports\weekend-backup-verification.md'

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

위 예시의 세트명에 local-state digest가 자동으로 붙도록 스크립트를 보완하거나, 실행 전 digest를 계산해 명시적으로 포함하세요. 명령 예시보다 불변·비충돌 요구가 우선합니다.

백업이 PASS한 경우에만 보완된 `validate_transfer.ps1 -Mode PreTransfer`로 백업 manifest와 현재 fingerprint를 검증하세요. 이 검증은 “working tree가 clean인가”가 아니라 “승인된 baseline과 non-`migration/` 상태가 exact인가”를 판단해야 합니다.

## 9. Phase 1 성공 기준

다음이 모두 PASS여야 “완전 백업 완료”라고 보고할 수 있습니다.

- current remote mirror fsck PASS
- remote advertised refs = mirror refs exact
- local refs·stash·Codex refs·worktree HEAD 보존 exact
- bundle verify·restore clone fsck PASS
- mirror/local archive/bundle/restore ref 비교 PASS
- root와 linked worktree inventory·snapshot 생성 PASS
- source-before = snapshot = source-after: missing/extra/size/hash mismatch 0
- `material-manifest.json`의 현재 승인된 자료가 snapshot과 exact
- LFS pointer/object/cache 상태 증명 PASS
- secret 값 보고서 유입 0
- 활성 루트 non-`migration/` 파일 hash·Git 상태·HEAD·origin 변화 0
- 외부 final 세트에 `manifest.json`과 `complete.json` 존재
- 모든 manifest와 bundle의 SHA-256 기록

하나라도 FAIL·UNKNOWN이면 Transfer는 No-Go이며 “부분 백업”이라고 보고하세요. 성공한 항목만으로 완전 백업이라고 표현하지 마세요.

## 10. 결과 보고서

모든 결과를 한국어로 다음에 저장하세요.

- `migration/reports/weekend-backup-verification.md`
- `migration/reports/weekend-execution-summary.md`
- `migration/reports/risk-and-blockers.md`
- `migration/reports/planned-transfer-commands.md`
- 필요한 machine-readable Phase 1 manifest의 redacted 사본

최종 사용자 보고에는 다음을 포함하세요.

1. 수행 범위
2. Public 저장소와 수업 환경의 변경 여부
3. 새 백업 absolute path
4. backup set·manifest·bundle SHA-256
5. Git refs 및 restore 검증 결과
6. 자료 파일 수·총량과 source/snapshot hash 일치 결과
7. local-only branch·stash·worktree 보존 결과
8. 실패·UNKNOWN·남은 차단 요소
9. 실제 Transfer 가능 여부
10. 다음 단계에서 필요한 단 하나의 승인

## 11. Phase 1 이후 Hard Stop

Phase 1 보고가 끝나면 반드시 멈추세요.

다음은 별도 승인 없이는 하지 않습니다.

- `EST-Bootcamp-AI-Quant/ai-quant-assets-private` 생성
- `.gitattributes` 작성과 LFS tracking
- 자료 staging·commit·push
- Repository Transfer
- origin 변경
- 기존 Public 저장소·자료·폴더 삭제

완전 백업이 PASS한 경우 다음 세션에 요청할 수 있는 승인은 **Approval Gate B1 — 빈 Private 자료 저장소 생성** 한 건뿐입니다. 완전 백업이 실패하면 B1을 요청하지 말고 복구 가능한 상태와 실패 원인만 보고하세요.
