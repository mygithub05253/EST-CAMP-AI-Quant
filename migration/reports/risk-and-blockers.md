# 차단 요소와 위험 요소

> 최신 재평가: 2026-07-21 11:20 KST. 아래의 7월 20일 근거 중 SHA·수량은 역사적 참고값이며, 현재 판정은 이 절을 우선합니다.

## 현재 Gate 판정

| 단계 | 판정 |
|---|---|
| Phase 0 최신 조사 | PASS |
| Gate A 신규 완전 백업 | **PASS — 4차 시도 성공** |
| Phase 1 백업 실행 | **PASS — `before-transfer-20260721-111152-14277f98fb22`** |
| Private 저장소·LFS upload | 별도 B1·B2 미승인 |
| Repository Transfer | Gate B 승인 대기 (기술적 차단 해소) |

## 2026-07-21 해소된 차단 요소

1. **완전 백업 확보 (해소)**
   - 세트 `before-transfer-20260721-111152-14277f98fb22`, HEAD `14277f98fb22`, 1.3 GB.
   - `complete.json` status PASS, 모든 검증 플래그 true, missing/extra/size/hash mismatch 각 0.
   - 독립 검증: 원격·로컬 bundle 모두 `git bundle verify` 통과(`complete history`), 미러의 `main`이 `14277f9`와 일치, 스냅샷에서 실제 파일 내용 판독 성공.
   - working tree 4개, ignored 교재 1.02 GiB(`docs/book` 539M, `docs/zip` 481M), stash, cache 모두 포함.
   - source-before → source-after exact PASS로 백업 중 동시 편집이 없었음을 확인했다.

2. **수업 파일 미추적 상태 (해소)**
   - PR #29로 `시계열분석_풀이.ipynb`와 `docs/image/zoom-web-cam-image.webp`를 `main`에 반영했다.
   - `docs/image/`의 두 파일은 md5가 동일한 중복이었고 실제 포맷이 WebP였으므로 1개로 정리하고 확장자를 정정했다.
   - 수업 자료와 migration 문서는 서로 다른 commit으로 분리했다.
   - 모든 ref의 커밋이 origin에 반영되어 로컬 전용 미푸시 작업은 없다.

3. **개인정보 형식 후보 (해소 — 실제 개인정보 아님)**
   - `assignments/01-python-basic/Day01.ipynb`의 후보 2곳은 문자열 슬라이싱 단원의 교재 예제값(`hong` 변수)이다.
   - `learning/01-python-basic/3. 컬렉션.ipynb`의 후보 1곳은 dict 단원 예제(`{"name": "andy", ...}`)이며 `011`은 폐지된 통신사 식별번호다.
   - 신규 커밋한 `시계열분석_풀이.ipynb`는 주민번호·전화번호·이메일·시크릿·로컬경로 스캔 결과 전부 0건이다.
   - 실제 값은 이 보고서에 저장하지 않았다.

4. **`stash@{0}` (해소 — 고유 작업 없음)**
   - blob 해시가 `main`과 완전 동일(`bcb6c546...`)해 이미 머지된 PR26 내용의 중복임을 확인했다.

## 백업 스크립트에서 수정한 결함

Gate A 재시도 과정에서 이 환경 고유의 결함 3건을 확인하고 수정했다. 모두 스크립트가 이 환경에서 완주한 적이 없어 검증되지 않았던 경로다.

| # | 실패 지점 | 원인 | 조치 |
|---|---|---|---|
| 1 | raw `.git` 재해시 | 303자 `refs/codex/...` 경로를 PowerShell 5.1 일반 경로 API로 처리 | extended-length(`\\?\`) 경로 변환 (이전 세션) |
| 2 | linked worktree 매니페스트 | `if/else`로 `@()`를 할당하면 언롤링되어 `$null`이 되고, PS 5.1은 `$null` 파이프 시 요소 1개를 흘려보냄 | 직접 할당으로 빈 배열 유지 + 소비측에서 빈 값 skip |
| 3 | LFS 오브젝트 매니페스트 | `StrictMode Latest`에서 빈 컬렉션의 `Measure-Object` 결과에 `.Sum`·`.Count` 속성이 없어 예외 | `Get-BackupInt64Sum` 헬퍼로 명시적 누적, 동일 패턴 6곳 일괄 적용 |

2·3번은 같은 계열(0건·빈 값을 정상 상태로 처리하지 못함)이므로, 3번 수정 시 잔여 `Measure-Object` 사용처를 전수 조사해 함께 고쳤다. 회귀 테스트로 빈 입력에서 예외가 없고 정상 입력의 합계·제외 동작이 유지됨을 확인했다.

## 실패 partial 정리 완료

완전 백업의 `SHA256SUMS.txt` 36개 항목을 독립 재검증(일치 36 / 불일치 0 / 누락 0)한 뒤,
사용자 승인을 받아 미완결 partial 4개(약 1.6 GB)를 삭제했다.

삭제 과정에서도 두 가지 Windows 제약을 만나 조치했다.

| 문제 | 조치 |
|---|---|
| `Remove-Item`이 `refs/codex/...` 260자 초과 경로를 삭제하지 못함 | `\\?\` extended-length 경로로 `[System.IO.Directory]::Delete` 사용 |
| git pack `.idx`·`.pack`이 읽기 전용이라 접근 거부 | 삭제 전 ReadOnly 속성 해제(세트당 6개) |

### 현재 보존 중인 백업

| 경로 | 크기 | 상태 |
|---|---|---|
| `before-transfer-20260721-111152-14277f98fb22` | 1,248 MB | **COMPLETE — 현행 기준 백업** |
| `before-transfer-e04abb769740-4c319b33d321` | 40 MB | COMPLETE — 7/20 git 전용 백업(예비) |

삭제 후 기준 백업의 `complete.json` status PASS, bundle verify 통과,
미러 `main`이 `14277f9`와 일치함을 재확인했다.

5. **Organization·LFS 정책 일부 미확인**
   - `admin:org`, `admin:org_hook`, `read:project` 부족으로 조직 정책 일부를 확인하지 못했다.
   - GitHub Organization LFS quota·bandwidth·비용을 실제 upload 전에 다시 확인해야 한다.

6. **저작권·보관 권리와 현 규칙 충돌**
   - 사용자는 모든 필수 자료 보존을 원하지만 `AGENTS.md`는 교재 PDF·ZIP의 Git commit을 금지한다.
   - Private+LFS도 저작권·재배포 권리를 해결하지 않는다. 외부 무손실 백업은 가능하지만 GitHub upload는 권리·범위 승인 전 No-Go다.

7. **경로 결합**
   - 35개 notebook에서 경로 리터럴 87회, 공통 경로 추상화 0건이다.
   - Private 저장소로 즉시 이동하면 import 경로만으로 해결되지 않는다. 먼저 현재 경로를 유지한 복제본으로 검증해야 한다.

## 현재 중요 위험

| 위험 | 대응 |
|---|---|
| 수업 중 동시 저장 | Gate A 동안 20~30분 편집 중단, 시작·종료 hash 불일치 시 즉시 중단 |
| 개인정보 추가 공개 | 후보 마스킹·history scan을 별도 승인 작업으로 수행 |
| Public 담당자 리뷰 단절 | Public 코드 저장소와 웹 가독성을 유지하고 Private 원본 자료에 의존하지 않는 README·sample 유지 |
| 여러 저장소 운영 복잡도 | 초기에는 Private 저장소 1개 안에 `01/02/03/...` 폴더 구성 |
| LFS 비용·clone 실패 | 파일별 allowlist/OID/용량 제시 후 B2 승인, no-smudge clean clone 검증 |
| URL redirect 손실 | 전송 후 구 경로 이름을 재사용하지 않음 |
| 자동화 중단 | Copilot App/Actions/environment 기능을 Transfer 전후 별도 검증 |
| 복구 불가 | copy-before-move, 새 timestamp, `.partial-*` 보존, 활성 루트 덮어쓰기 금지 |

## 이전 2026-07-20 조사 기록

### 당시 Hard Blocker

1. **Root working tree가 dirty**
   - 사용자 수정 notebook 6개
   - 사용자 untracked 10개
   - 이번 migration 산출물도 아직 untracked
   - 명세의 “local 변경이 남은 상태에서 이관 금지” 조건 위반

2. **원격 Mirror·Bundle이 로컬 전체 상태를 포함하지 않음**
   - 로컬 branch 9개 대 원격 branch 7개
   - stash 1개
   - linked worktree 4개와 별도 untracked 상태
   - ignore 자료 약 1.02 GiB
   - dangling object 250개

3. **Organization 정책 일부 미확인**
   - Actions 정책·Rulesets·Organization secret/variable 이름: `admin:org` 필요
   - Projects v2: `read:project` 필요

4. **자료 업로드 정책 충돌**
   - 사용자는 모든 학습 자료 보존·업로드를 원함
   - 현 `AGENTS.md`와 실행 명세는 PDF·ZIP·교재 커밋 금지
   - 권리·민감도·LFS 정책 결정 전 자동 업로드 불가

### 당시 중요 위험

| 위험 | 현재 근거 | 대응 |
|---|---|---|
| Copilot review 중단 | 대상 Organization App 설치 0건, 원본에 Copilot dynamic workflow/environment 존재 | 전송 전 App 설치·승인 계획 확인 |
| 보안 기본값 약화 | 대상 Organization의 신규 repo 보안 기본값 다수가 false | 전송 후 원본 secret scanning·push protection 유지 여부 즉시 비교 |
| Branch 보호 부재 | 원본 7개 branch 모두 unprotected, ruleset 0 | 이관 검증 후 별도 승인으로 ruleset 도입 |
| 2FA 미강제 | 대상 Organization `two_factor_requirement_enabled=false` | 별도 Organization 설정 Approval Gate |
| Pages 단절 | 현재 Pages 미구성이므로 즉시 영향은 없음 | 향후 Pages 생성 시 별도 URL 검증 |
| URL redirect 손실 | 이전 경로 재사용 시 redirect 영구 손실 가능 | `mygithub05253/EST-CAMP-AI-Quant` 이름 재사용 금지 |
| 원격 활동 중 baseline 변동 | 수업 작업이 계속됨 | 짧은 maintenance window와 새 백업 세트 생성 |
| Notebook 개인 경로 노출 | 사용자·Administrator 절대 경로 출력 존재 | 별도 정리 PR |
| 대용량 push 실패 | 100 MiB 초과 PDF·ZIP 3개 | Git LFS 또는 승인된 binary storage |
| 저작권·약관 위반 | 강의 원본·유료 데이터 가능성 | 파일군별 권리 확인 후 공개/Private 결정 |
| 저장소 분리 오해 | 하나의 `.git` remote 변경만으로 다중 repo 분리 불가 | submodule topology 별도 승인 |

### 당시 백업 관련 주의

검증 완료 백업:

`C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-e04abb769740-4c319b33d321`

초기 스크립트 검증 중 ref 문자열 정규화 오류로 완료되지 않은 partial 세트가 하나 남아 있습니다. 자동 삭제하지 않았으며 복구 기준으로 사용하면 안 됩니다.

`C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-e04abb769740-6f7682ed68e3.partial-30556`

사용자 승인 전에는 partial 세트도 삭제하지 않습니다.

### 당시 Notion 확인

캠프 Notion 연결은 OAuth 재인증 필요 오류로 조회하지 못했습니다. 첨부 실행 명세서는 정상 확인했으며 이번 migration 기술 조사에는 충분했지만, 캠프 운영 자료와 충돌 여부는 재인증 후 다시 확인해야 합니다.
