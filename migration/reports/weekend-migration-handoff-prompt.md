# 주말 GitHub Organization 이관·자료 분리 핸드오프 프롬프트

아래 지시를 이 작업의 **최신 실행 명세**로 사용하세요. Codex 또는 Claude 어느 환경에서 시작하더라도 이전 대화의 기억에 의존하지 말고, 지정된 파일과 실제 로컬·GitHub 상태를 직접 다시 확인하세요.

## 1. 역할과 목표

Windows/PowerShell 환경의 다음 저장소를 데이터 손실 없이 GitHub Organization으로 이관하고, 담당자 피드백용 Public 코드와 Private 원본 자료를 분리하는 작업입니다.

- 현재 로컬 루트: `C:\Users\kik32\workspace\EST-Camp-AI-Quant`
- 원본 GitHub 저장소: `mygithub05253/EST-CAMP-AI-Quant`
- 대상 Organization: `EST-Bootcamp-AI-Quant`
- 원본 실행 명세: `C:\Users\kik32\Downloads\CODEX_GITHUB_ORG_MIGRATION_PLAN.md`
- 기존 조사·스크립트: 로컬 루트의 `migration/`
- 문서·보고·커밋 언어: 한국어
- 기준 시간대: KST

최종 운영 방향은 다음과 같습니다.

1. 담당자가 웹에서 계속 볼 수 있는 Public 코드·노트북·TIL·과제 저장소를 유지합니다.
2. 담당자는 Organization의 Private 저장소에 초대될 수 없으며, 코드를 clone하거나 실행하지 않고 GitHub 웹에서만 검토합니다.
3. PDF·ZIP·대형/원본 데이터 등 필요한 자료는 Organization의 **단일 Private 자료 저장소**에 모두 보존합니다.
4. Private 자료 저장소 내부를 `01`, `02`, `03` 등 과정별 폴더와 `shared/`로 구분합니다. 초기부터 과정별로 여러 저장소를 만들지 않습니다.
5. 로컬의 활성 자료 저장소는 별도 workspace sibling이 아니라 현재 프로젝트 루트 내부(예: `private_sources/ai-quant-assets-private/`)에 둘 수 있어야 합니다.
6. 초기 연결 방식은 Private submodule보다 **parent에서 ignore한 bootstrap clone + commit/hash lock**을 우선 검토합니다.
7. 기존 Public 저장소 이력에 이미 들어간 CSV·NPY·이미지는 사용자가 문제 삼지 않기로 했습니다. history rewrite나 force push로 정화하지 않습니다.
8. 기존 Public 저장소는 Organization 이관과 저장소 분리가 완전히 검증된 뒤 최종적으로 제거할 예정이지만, 삭제는 가장 마지막의 별도 승인 작업입니다.

운영 원본(source of truth)은 다음처럼 구분합니다.

- Public 코드 저장소: 코드·노트북·TIL·과제·웹 피드백의 운영 원본
- Private 자료 저장소: 원본 교재·데이터·대형 binary의 운영 원본
- 외부 검증 snapshot: 장애 복구용 원본이며 일상 수정 대상이 아님

동일 자료를 Public working tree와 Private working tree에서 각각 수정하지 마세요. Public에 필요한 데이터는 공개 가능한 sample/synthetic 또는 검증된 파생물로 명확히 분류합니다.

## 2. 반드시 먼저 읽을 파일

작업 전에 다음 파일을 끝까지 읽고 충돌하는 규칙을 정리하세요.

1. 루트 `AGENTS.md`와 `CLAUDE.md`
2. `C:\Users\kik32\Downloads\CODEX_GITHUB_ORG_MIGRATION_PLAN.md`
3. `migration/README.md`
4. `migration/MIGRATION_CHECKLIST.md`
5. `migration/reports/`의 모든 Markdown·JSON 보고서
6. `migration/scripts/collect_inventory.ps1`
7. `migration/scripts/create_backup.ps1`
8. `migration/scripts/validate_transfer.ps1`

원본 명세의 “PDF·ZIP·원본 자료를 업로드하지 않는다”는 정책은 최신 사용자 결정에 의해 다음처럼 수정됩니다.

- 필요한 자료는 누락·삭제하지 않고 모두 inventory와 백업에 포함합니다.
- 시크릿·API 키·`.env`·개인정보·cache·checkpoint는 업로드 대상에서 제외합니다.
- 재배포·클라우드 보관 권한이 불명확한 교재·강사 원본은 Public에 올리지 않고, 권한 확인 및 사용자 승인 후 Private 저장소에만 올립니다.
- Private 저장소와 Git LFS는 공개 범위·저작권 자체를 해결하지 않으므로 권리 확인 결과를 보고서에 남깁니다.

## 3. 이전 세션의 참고 기준값

아래 값은 2026-07-20 KST 당시의 참고값일 뿐입니다. 주말에는 수업 작업으로 달라졌을 수 있으므로 **절대 그대로 믿지 말고 재수집**하세요.

- 당시 현재 브랜치: `main`
- 당시 로컬 HEAD와 `origin/main`: `8e3546c83d7dd874fa67cb02d441076d58a2e615`
- 당시 원격: `https://github.com/mygithub05253/EST-CAMP-AI-Quant.git`
- 당시 tracked 변경: 없음
- 당시 untracked: `docs/image/`, `migration/`
- Git LFS: `3.5.1` 설치됨
- 당시 `.gitattributes`: 없음
- 당시 LFS pointer/object: 없음
- 당시 원본 저장소 공개 범위: Public
- 대상 Organization: Free plan, 사용자는 active/admin 멤버로 조사됨, 저장소 생성 권한 있음
- 권한 조사 당시 일부 CLI scope(`admin:org`, `read:project`) 보강 필요 가능성이 보고됨

자료 규모 역시 재조사해야 하지만, 당시 대략 다음과 같았습니다.

- Git 추적 자료: 약 12MB
- `.gitignore`로 제외된 PDF·ZIP: 약 1.077GB
- 100MiB 초과 파일: 3개
- 최대 파일: 약 503MB ZIP
- GitHub 일반 Git blob 한도를 넘는 파일은 Git LFS 필요
- 노트북 34개에서 데이터·이미지·출력 경로가 약 84회 직접 사용됨
- 공통 `DATA_DIR`/`MATERIALS_ROOT` 경로 추상화는 확인되지 않음
- 여러 노트북이 `./data/...`에 직접 의존하며 실행 CWD에 따라 일부 기존 경로도 불일치 가능

기존 검증 백업:

- 정상 백업: `C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-e04abb769740-4c319b33d321`
- 정상 백업은 과거 SHA `e04abb...` 기준이며 현재 자료·미추적·ignore 파일과 Git LFS 실물을 포함하지 않음
- 부분 실패 백업: `C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-e04abb769740-6f7682ed68e3.partial-30556`
- 부분 실패 백업을 자동 삭제하거나 덮어쓰지 말 것

## 4. 절대 안전 원칙

1. **이 프롬프트는 Repository Transfer, 새 원격 저장소 생성, 공개 범위 변경, LFS 업로드, Organization 설정 변경, 폴더 삭제에 대한 승인이 아닙니다.** 각 외부 변경 직전에 사용자에게 정확한 대상·명령·영향·롤백 방법을 보여 주고 별도 승인을 받으세요.
2. 사용자가 수업 파일 수정을 계속하는 동안 활성 working tree를 이동·정리·재배치하지 마세요.
3. 해시 inventory와 최종 전환 직전에는 사용자에게 짧은 수정 중단 시간을 요청하세요. 수집 중 원본 해시가 바뀌면 결과를 폐기하고 다시 시작하세요.
4. 모든 자료는 **이동보다 복사**를 먼저 수행하고, 경로·파일 수·크기·SHA-256 전수 일치가 확인되기 전에는 원본을 건드리지 마세요.
5. 검증된 새 원격 clone이 생겨도 기존 원본 파일과 저장소는 최소 한 차례 실제 수업 확인 전까지 유지하세요.
6. 현재 Public 저장소의 `HEAD`, branch, remote와 **기존 사용자 파일**의 status/hash fingerprint는 Shadow Migration 전후 동일해야 합니다. `migration/reports/`와 승인된 `migration/scripts/` 변경만 사전 선언된 allowlist로 별도 기록합니다.
7. 여러 독립 저장소가 하나의 working tree 경로를 동시에 소유하도록 구성하지 마세요.
8. Private 자료가 없는 사용자도 Public 저장소를 정상 clone하고 GitHub 웹에서 README·노트북·공개 이미지를 볼 수 있어야 합니다.
9. 담당자는 실행하지 않으므로 Public 저장소의 전체 원본 데이터 재현보다 웹 리뷰 가독성과 Private 자료 비노출을 우선합니다.
10. Private 원본 자료 저장소의 승인된 자료 확장자(CSV·TSV 포함)는 기본적으로 Git LFS 대상으로 분류합니다. Public 저장소에 남기는 공개 가능한 작은 sample/synthetic CSV·TSV만 일반 Git을 허용합니다. 정확한 LFS pattern과 예외는 파일별 manifest를 제시한 뒤 승인받으세요.

다음 명령·행위는 명시적 최종 승인 없이 금지합니다.

- `git push --force`, `--force-with-lease`
- `git reset --hard`, 기존 파일에 대한 `git checkout --`
- `git clean`의 모든 변형
- 활성 루트에 대한 `Remove-Item -Recurse`
- 활성 자료에 대한 `Move-Item`
- `robocopy /MIR` 또는 삭제를 전파하는 동기화
- `git lfs migrate import --everything` 등 history rewrite
- 현재 Public 원격에 PDF·ZIP·원본 자료 push
- 검증 전 `.gitignore` 해제로 약 1.1GB 자료 노출
- 검증 전 기존 폴더·저장소·브랜치·백업 삭제
- Transfer와 저장소 분리, LFS 전환, rename/archive를 한 번에 수행

## 5. 주말 작업의 단계와 승인 게이트

항상 한 단계만 수행하고 보고한 뒤 다음 승인을 기다리세요. 한 단계가 실패해도 현재 수업 환경이 그대로 작동해야 합니다.

### Phase 0 — 최신 상태 재조사

읽기 전용으로 다음을 다시 수집합니다.

- 필수 실행 도구(`git`, `gh`, `git-lfs`, PowerShell, 안전한 복사 도구)와 지정 파일의 존재 여부
- source·snapshot·LFS cache·clean clone·post-upload backup을 모두 감당할 예상 최대 디스크 사용량과 현재 여유 공간
- `git status --short --branch`
- 현재 branch, HEAD, `origin/main`, remote URL
- 로컬·원격 branch/tag/stash/worktree
- 열린 PR·Issue, Actions, Pages, Releases, Webhooks, Rulesets 등 GitHub 자산
- Organization 멤버십·역할·저장소 생성/transfer 권한·이름 충돌
- 추적·미추적·ignore 자료의 상대경로, 크기, SHA-256, Git 상태
- 시크릿·개인정보·절대경로·구 소유자 URL
- 기존 notebook/code의 데이터·이미지 경로 결합
- Git LFS 설치·config·tracking·pointer·object·quota 상태

필수 도구나 파일이 없으면 설치·업그레이드·대체 도구 실행을 임의로 하지 말고 중단하여 보고하세요. 이 migration preflight에서는 루트 `AGENTS.md`의 일반 작업 시작 절차와 달리 활성 루트에서 `pull`, `checkout`, `switch`, `stash`를 먼저 실행하지 않습니다. 현재 상태를 그대로 채증한 뒤, migration 문서를 commit해야 할 경우 fresh backup 후 승인된 별도 branch/worktree에서 처리합니다.

결과를 `migration/reports/weekend-preflight.md`와 machine-readable JSON에 저장합니다. 상태가 이전 참고값과 다르면 차이를 먼저 보고합니다.

### Approval Gate A — 수정 중단·신규 백업 승인

사용자에게 다음을 보고하고 승인을 기다립니다.

- 현재 작업 중인 파일 유무
- 백업 대상 파일 수·총 크기
- 예상 백업 위치
- 백업·shadow·LFS cache·검증 clone을 포함한 예상 디스크 최대 사용량과 여유 공간
- 수업 파일 수정 중단이 필요한 구간
- 백업 명령과 활성 루트에 미치는 영향

### Phase 1 — 현재 상태의 완전한 외부 백업

승인 후 다음을 수행합니다.

1. 현재 원격의 fresh Mirror 생성 및 `git fsck` 검증
2. 현재 모든 원격·로컬 ref의 Bundle 생성 및 restore clone 검증
3. local-only branch·stash·linked worktree·각 dirty/untracked 상태를 별도 inventory와 snapshot으로 보존
4. `.git`과 cache 제외 정책을 명시한 working-tree snapshot 생성
5. 추적·미추적·ignore 자료를 포함한 SHA-256 manifest 생성
6. `.env`·키·시크릿은 GitHub 업로드 대상에서는 제외하되 데이터 손실 방지를 위해 사용자 승인 하에 암호화된 로컬 백업 또는 지정 secret vault에 별도 보존하고 위치가 아닌 보존 여부만 보고
7. 향후 LFS object store를 별도 보존할 구조 준비
8. 원본과 snapshot의 상대경로·파일 수·크기·SHA-256 exact 비교
9. 백업은 새 timestamp 경로에 생성하고 기존 백업을 덮어쓰지 않음

성공 조건은 Git ref 검증과 working-tree 자료 해시 검증이 모두 PASS인 것입니다. Bundle만 성공했다고 완전 백업으로 보고하지 마세요.

### Approval Gate B1 — 빈 Private 자료 저장소 생성 승인

다음을 사용자에게 제시한 뒤 별도 승인을 기다립니다.

- 제안 저장소명(예: `EST-Bootcamp-AI-Quant/ai-quant-assets-private`)
- `PRIVATE` visibility
- 허용 collaborator/team의 정확한 allowlist와 권한
- Pages 비활성, 별도 승인 전 Actions·workflow·secret 없음
- 빈 저장소 생성에 사용할 정확한 명령과 롤백 한계

승인 후에는 빈 저장소만 만들고 API에서 repository ID·visibility·default branch·권한을 다시 검증합니다. 이 승인으로 자료 업로드를 진행하지 마세요.

### Approval Gate B2 — Private Git LFS 자료 업로드 승인

Gate B1 검증 후 다음을 사용자에게 제시하고 다시 승인받습니다.

- 과정별 target tree
- 파일별 source path → target path 매핑
- 일반 Git 대상과 LFS 대상
- 정확한 LFS OID 수·파일 수·총 byte·LFS 예상 저장량과 bandwidth 정책
- `.gitattributes` 제안
- 업로드·검증 명령
- 실패 시 중단·보존 방법

### Phase 2 — Copy-only Private LFS Shadow Migration

Gate B1에서 생성·검증된 Private 저장소와 Gate B2의 업로드 승인을 모두 확인한 경우에만, 활성 자료를 이동하지 말고 외부 shadow copy에서 작업합니다.

권장 target 구조 예시:

```text
ai-quant-assets-private/
├── 01-python-basic/
├── 02-preprocessing/
├── 03-visualization/
├── 04-math-statistics/
├── 05-time-series/
├── shared/
├── manifests/
└── README.md
```

구조를 임의로 확정하지 말고 현재 파일 경로와 향후 코드 참조를 분석해 mapping 보고서를 먼저 만드세요. canonical target path는 파일당 하나만 승인하며, 원래 상대경로는 manifest metadata로 보존합니다. 같은 실물을 `source-tree/` 등에 중복 업로드하지 말고 중복과 누락을 모두 탐지하세요.

검증 조건:

- GitHub API 기준 visibility가 `PRIVATE`
- 원본 manifest와 원격 clean clone의 상대경로·파일 수·크기·SHA-256 일치
- extra/missing/hash mismatch 0개
- 모든 LFS 대상이 canonical pointer이고 OID가 원본 SHA-256과 일치
- 100MiB 초과 일반 Git blob 0개
- `git lfs fsck --objects --pointers` 성공
- no-smudge clean clone → `git lfs fetch --all` → checkout 성공
- LFS pointer text만 남은 실물 파일 0개
- 시크릿·개인정보·`.git`·cache·checkpoint 유입 0개
- 승인된 collaborator/team만 exact allowlist와 일치, 권한 보유 계정 clone 성공, 무권한 콘텐츠 접근 불가
- Pages 비활성, 별도 승인되지 않은 Actions·workflow·secret 없음
- 활성 Public 저장소의 pre/post HEAD·origin과 기존 사용자 파일의 status/hash 동일; 선언된 `migration/` allowlist 변경만 별도 diff로 존재
- 업로드 직후 새 Private 원격 Mirror에서 `git lfs fetch --all`, LFS object OID/SHA-256 manifest, `git lfs fsck`를 검증하고 외부 post-upload backup 생성
- Bundle에는 LFS 실물이 포함되지 않는다는 점과 Mirror/LFS object store를 함께 사용한 복구 절차 기록

이 단계가 완료되어도 기존 자료는 삭제하지 않습니다. 결과를 “Private 검증 복제본 완료”라고 표현하고 “운영 경로 전환 완료”라고 표현하지 마세요.

### Phase 2 Hard Stop

Phase 2 검증 보고서를 사용자에게 전달한 뒤 자동으로 Transfer·경로 전환·저장소 분리를 계속하지 마세요. 다음 단계는 최소한 다음 조건을 만족한 별도 maintenance 단계입니다.

- Phase 2 보고서가 최종 PASS
- 사용자가 보고서와 정확한 명령을 검토함
- 활성 수업 환경을 계속 사용할 수 있는 rollback 경로가 확인됨
- Gate C에 대해 새로운 명시 승인을 받음

Private 자료 경로로의 운영 전환과 기존 파일 정리는 최소 한 차례 대표 수업 smoke test 후에만 수행합니다.

### Approval Gate C — 현재 Repository의 Native Transfer 승인

Private 자료 복제와 별개의 작업으로 취급합니다. Transfer 직전에 다음을 다시 제시하고 승인을 기다립니다.

- source/target owner와 repository 이름
- 최신 HEAD와 모든 ref
- 열린 PR·Issue 및 GitHub 자산 inventory
- Organization 권한과 이름 충돌
- fresh backup PASS 근거
- 실제 transfer 명령
- 예상 URL redirect와 remote 변경 시점
- transfer 후 검증 및 중단 기준

승인 전에는 Transfer API/UI 작업, Organization 설정 변경, local remote 변경을 하지 마세요.

Transfer 후에도 즉시 rename·archive·분리·삭제하지 말고, 저장소 ID·HEAD·refs·PR·Issue·Actions·Pages·Release·LFS 등 모든 자산이 baseline과 일치하는지 먼저 검증하세요. local `origin`은 새 URL clone/fetch가 검증된 다음 별도 승인으로 변경합니다.

### Approval Gate D — 코드 저장소 분리·로컬 연결 방식 승인

원본 명세의 Stage C 후보는 다음과 같습니다.

```text
EST-Bootcamp-AI-Quant/
├── .github
├── bootcamp-hub
├── ai-quant-textbook
├── ai-quant-assignments
└── quant-project-*
```

단, 수업 중에는 담당자가 보던 Public 코드 저장소의 연속성을 우선합니다. 각 신규 저장소가 안정화되고 링크·README·웹 렌더링·history·파일 hash가 검증되기 전에는 기존 저장소와 폴더를 제거하지 마세요.

Private 자료의 로컬 연결은 다음 순서로 검토합니다.

1. parent에서 ignore한 `private_sources/ai-quant-assets-private/` bootstrap clone
2. 정확한 private commit과 manifest SHA를 기록한 `materials.lock.json`
3. 필요한 과정만 선택적으로 받는 Git LFS pull
4. 모든 저장소 상태를 함께 확인하는 PowerShell status/sync 스크립트
5. submodule은 exact gitlink pinning이 반드시 필요한 경우에만 후속 검토

데이터 접근은 Python import 경로가 아니라 중앙 파일 경로 resolver로 구현합니다.

- 환경변수 예: `EST_CAMP_MATERIALS_ROOT`
- 기본값 예: `<project-root>/private_sources/ai-quant-assets-private`
- `C:\Users\...` 절대경로를 commit하지 않음
- notebook의 `pd.read_csv`, `read_excel`, `np.load`, Markdown/HTML 이미지, 출력 경로를 모두 별도로 검사
- 자료 미설치 시 명확한 안내를 제공하되 GitHub 웹 렌더링은 깨지지 않게 함

Public PR/fork CI에는 Private 저장소 token·PAT·GitHub App credential을 절대 제공하지 않습니다. Private 자료 검증은 별도의 trusted/manual workflow 또는 Private 저장소 내부에서만 수행합니다. GitHub Pages는 LFS 실물 제공 경로로 사용하지 않으며, Public 웹에는 공개 가능한 생성물·sample만 일반 Git 또는 승인된 안전한 build artifact로 제공합니다.

### Approval Gate E — 기존 저장소·폴더 제거

가장 마지막 단계입니다. 다음을 모두 만족해도 삭제 명령을 먼저 제시하고 별도 승인을 기다리세요.

- 신규 Public 저장소가 담당자 피드백 경로로 정상 동작
- 신규 Private 자료 저장소 clean clone·LFS·hash 검증 PASS
- 신규 저장소별 default branch·PR·CI·README·링크 검증 PASS
- 최소 한 차례 실제 수업에서 새 로컬 구조 확인
- 외부 backup restore 검증 PASS
- 기존 Public 저장소와 폴더 없이도 필요한 파일이 모두 복구 가능

사용자는 최종적으로 기존 Public 저장소 삭제를 허용할 의향이 있지만, 이는 사전 승인이 아닙니다. archive/redirect 대안과 삭제 후 복구 한계를 함께 제시하세요. 승인 전에는 삭제·rename·archive하지 마세요.

## 6. 내일 수업을 지키기 위한 No-Go 기준

다음 중 하나라도 발생하면 실제 전환을 중단하고 기존 Public 저장소와 현재 파일 경로를 계속 운영 기준으로 사용하세요.

- 사용자가 파일을 수정 중이거나 inventory 도중 source hash가 변함
- 현재 HEAD·origin·status가 예상 밖으로 변함
- fresh working-tree backup이 없음
- 원본과 snapshot/clone 사이 누락·추가·hash mismatch 발생
- Git LFS pointer/fsck/fetch/checkout 실패
- 새 자료 저장소 visibility가 Private가 아님
- 무권한 URL에서 Private 콘텐츠 접근 가능
- 시크릿·개인정보 발견
- 디스크 또는 LFS quota/bandwidth 위험
- Public 웹 화면이 Private 자료에 의존해 README·notebook·이미지를 표시하지 못함
- 대표 notebook의 데이터/이미지 경로 smoke test 실패
- Organization 권한·저장소명·transfer 조건이 불명확

실패한 shadow/backup은 `.partial-*`로 보존하고 자동 삭제하지 마세요. Public main을 잘못 변경한 경우 reset/force push가 아니라 별도 revert PR을 사용하세요.

Phase별 rollback 원칙:

- Backup/Shadow 실패: 활성 원본을 계속 운영 기준으로 사용하고 실패 산출물을 `.partial-*`로 보존
- Private upload 실패: 자동 재시도·삭제·재생성하지 않고 remote ID·업로드 OID·로그를 기록한 뒤 승인 대기
- Transfer 실패: repository ID로 source/target 상태를 조회하고 API 호출을 자동 반복하지 않음
- Public 통합 실패: reset/force push가 아니라 별도 revert PR
- 로컬 복원: 검증 snapshot에서 사용자 확인 후 파일 단위로만 복원

## 7. 보고서와 사용자 소통

모든 결과는 한국어로 `migration/reports/`에 저장하세요. 최소 산출물은 다음과 같습니다.

- `weekend-preflight.md`
- 최신 machine-readable inventory JSON
- `material-manifest.json`
- `material-path-mapping.md`
- `weekend-backup-verification.md`
- `private-lfs-verification.md`(실제 승인·수행한 경우)
- `transfer-validation-weekend.md`(실제 승인·수행한 경우)
- `weekend-execution-summary.md`
- 갱신된 `risk-and-blockers.md`
- 갱신된 `planned-transfer-commands.md`

위 `migration/` 산출물은 사전 선언된 migration allowlist입니다. 각 파일의 생성·수정 내역은 별도 status/diff로 보고하며, 그 밖의 기존 사용자 파일이 변하면 즉시 No-Go로 판정합니다.

사용자를 60초 넘게 기다리게 하지 말고, 진행 중에는 현재 단계·검증 결과·중단 여부를 짧게 알려 주세요. 한 작업 단위가 끝나면 다음 내용을 보고하고 승인을 기다리세요.

1. 지금 수행한 범위
2. 현재 Public 저장소와 수업 환경이 변했는지
3. 생성된 백업과 경로·SHA-256
4. 자료 파일 수·총량·해시 일치 여부
5. Private LFS 검증 결과(수행한 경우)
6. 전송 가능 여부
7. 남은 차단 요소와 위험
8. 다음 단계의 정확한 실행 명령과 롤백 방법
9. 사용자에게 필요한 단 하나의 다음 승인

## 8. 첫 응답에서 해야 할 일

이 프롬프트를 받은 즉시 실제 변경을 시작하지 마세요.

1. 위 지정 파일을 읽습니다.
2. 로컬과 GitHub 상태를 읽기 전용으로 재검증합니다.
3. 이전 참고값과 달라진 점을 요약합니다.
4. 현재 단계의 Go/No-Go를 판단합니다.
5. 첫 번째로 필요한 승인 하나만 요청합니다.

사용자가 “주말이니 전부 진행해 주세요”라고 해도 모든 승인 게이트가 자동 승인된 것으로 간주하지 마세요. 데이터 손실·공개 범위·외부 저장소 생성·Transfer·삭제는 각각 별도 승인으로 분리합니다.
