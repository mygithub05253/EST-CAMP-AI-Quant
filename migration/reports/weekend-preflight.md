# 주말 이관 Phase 0 최신 사전점검

- 기준 시각: 2026-07-21 09:33 KST
- 실행 명세: `CODEX_GITHUB_ORG_MIGRATION_PLAN.md`의 “22. Codex 첫 실행 작업” 및 `weekend-migration-handoff-prompt.md`
- 현재 판정: **Phase 0 PASS / 신규 완전 백업은 Gate A 승인 대기 / 실제 Transfer는 No-Go**

## 이번 단계에서 한 일과 하지 않은 일

로컬·GitHub 상태를 읽기 전용으로 다시 조사하고 최신 JSON, 자료 manifest, 경로 매핑, 위험·명령 보고서를 작성했다. `collect_inventory.ps1`은 결제 이메일을 저장하지 않도록 보고서 보안만 보완했다.

다음 작업은 수행하지 않았다.

- `git pull`, `fetch`, checkout, switch, stash, commit, push
- Repository Transfer, 새 저장소 생성, Organization 설정 변경
- Git LFS tracking·upload, remote URL 변경
- force push, history rewrite, 폴더 이동·삭제
- 새 외부 백업 생성

따라서 Public 저장소와 활성 수업 파일의 내용·HEAD·origin은 변하지 않았다. 변경은 사전 선언된 `migration/` allowlist 보고서와 수집 스크립트의 개인정보 제외 처리뿐이다.

## 7월 20일 참고값과 달라진 점

| 항목 | 7월 20일 | 현재 | 의미 |
|---|---:|---:|---|
| `main` SHA | `e04abb769740...` | `8e3546c83d7d...` | 수업 작업 병합·동기화 반영 |
| GitHub API 크기 | 14,027 KB | 17,817 KB | 이력·자료 증가 |
| 원격 branch | 7 | 8 | 시계열 과제 branch 추가 |
| 전체 PR | 27 | 28 | PR #28 병합 |
| tracked 자료 | 251개 | 263개 | 12개 증가 |
| untracked 자료 | 10개 | 3개 | 이전 작업 다수 반영, 현재 3개 보호 필요 |
| ignored 핵심 자료 | 79개 | 82개 | archive 1개·checkpoint 2개 증가 |
| 직접 경로 사용 notebook | 34개/84회 | 35개/87회 | 새 풀이 notebook의 입력 3회 증가 |

기존 검증 백업은 `e04abb...` 기준 Git 원격 이력만 포함하므로 현재 복구 기준으로 사용할 수 없다.

## 원본 저장소와 대상 Organization

| 항목 | 확인 결과 |
|---|---|
| 원본 | `mygithub05253/EST-CAMP-AI-Quant`, Public, Repository ID `1270665344` |
| 기본 branch | `main` / `8e3546c83d7dd874fa67cb02d441076d58a2e615` |
| 로컬 정합성 | 로컬 HEAD = `origin/main` = live GitHub `main`, ahead/behind `0/0` |
| 원본 권한 | authenticated user가 admin/push/pull 보유 |
| 대상 Organization | `EST-Bootcamp-AI-Quant`, membership `active/admin` |
| 생성 권한 | Public·Private 저장소 생성 및 visibility 변경 가능 |
| 이름 충돌 | Organization 저장소 0개, 대상 이름 API 404로 충돌 없음 |

현재 OAuth scope는 `gist`, `read:org`, `repo`, `workflow`다. 따라서 Organization Actions 정책·기본 workflow 권한·rulesets·Actions secret/variable 이름은 `admin:org`, Organization webhook은 `admin:org_hook`, Projects v2는 `read:project`가 없어 **없음이 아니라 미확인**이다.

## GitHub 자산 Inventory

| 자산 | 최신 상태 |
|---|---|
| Branches | 8개, 모두 unprotected |
| Tags | 0 |
| Issues(PR 제외) | open 0 |
| Pull Requests | 전체 28, open 0 |
| Releases | 0 |
| Labels / milestones | 9 / 0 |
| Environments | `copilot` 1개 |
| Actions | Copilot dynamic workflow 1개, Actions 활성 |
| 저장소 수준 Actions/Dependabot/Codespaces secret 이름 | 0, 값은 조회하지 않음 |
| 저장소 수준 Actions variable 이름 | 0, 값은 저장하지 않음 |
| Deploy keys / webhooks / forks | 0 / 0 / 0 |
| Collaborators | `mygithub05253` 1명, admin |
| Repository rulesets / main protection | 0 / 미구성 |
| Pages | 미구성 |

## 로컬 Git과 작업 중 파일

| 항목 | 상태 |
|---|---|
| 현재 branch / HEAD | `main` / `8e3546c...` |
| tracked·staged 변경 | 0 / 0 |
| 로컬 / 원격 branch | 10 / 8 |
| Tag / stash | 0 / 1 |
| Linked worktree | 4개, 별도 2곳에 `.serena/*` 미추적 도구 파일 |
| `.gitmodules` / `.gitattributes` | 없음 / 없음 |
| Git LFS pointer / local object | 0 / 0 |
| `git fsck --full` | 성공, dangling 객체는 있으나 오류 아님 |

현재 `migration/` 밖 미추적 파일은 다음 3개다.

| 파일 | 크기 | SHA-256 |
|---|---:|---|
| `assignments/05-time-series/시계열분석_풀이.ipynb` | 461,845 B | `5207E9F...E38CDF` |
| `docs/image/web-cam-image.jpg` | 311,060 B | `6A189299...ED8AE` |
| `docs/image/zoom-web-cam-image.png` | 311,060 B | `6A189299...ED8AE` |

풀이 notebook은 09:08 KST에 생성된 최신 수업 파일이다. 이 파일을 포함한 세 자료의 경로·크기와 `main` HEAD는 조사 시작·종료에 동일했으며, 자료 manifest는 생성 전후 독립 재해시까지 일치했다.

## 자료 Inventory와 해시

`material-manifest.json`은 348개 파일의 상대경로·크기·SHA-256·Git 상태·분류를 담는다.

| Git 상태 | 파일 수 | 크기 |
|---|---:|---:|
| tracked | 263 | 30,487,473 B |
| untracked | 3 | 1,083,965 B |
| ignored | 82 | 1,094,191,421 B |
| 합계 | **348** | **1,125,762,859 B (약 1.048 GiB)** |

- manifest SHA-256: `99ABEA79A9836AF81BB1B0B44BEF70DF85811B53FCBE962929A9676AB7081F47`
- 생성 전 2-pass와 생성 후 독립 재해시: 348/348 exact, 오류 0
- 100 MiB 초과 파일: ZIP 1개, PDF 2개
- notebook checkpoint 53개는 외부 무손실 백업 inventory에는 남기되 Private GitHub 업로드에서는 제외한다.

## 구 소유자 URL·절대경로·개인정보 후보

- 학습·과제·프로젝트 파일에서 `mygithub05253`와 구 owner URL은 0건이다.
- 구 owner 참조는 이관 기준값과 명령을 담는 `migration/` 파일에만 있으므로 일괄 치환하면 안 된다.
- Windows 사용자 프로필 절대경로는 tracked notebook 6개와 checkpoint 복제 6개에서 확인됐다.
- 더 넓은 Windows 절대경로는 tracked notebook source 14개 파일, output 9개 파일에 있다. source는 상대경로화하고 output은 별도 정리 PR에서 clear/re-run한다.
- 시크릿 키·Bearer·credential 정규식 후보와 `.env`/key 파일명 후보는 0건이다. 이는 Git history와 binary 내부까지 안전하다는 증명은 아니다.
- tracked notebook source에서 주민등록번호 형식 후보 2곳과 전화번호 형식 후보 1곳이 검출됐다. 값은 보고서에 저장하지 않았다. 예제 데이터일 가능성이 있지만 실제 전송·추가 공개 전에 마스킹·history 검사가 필요하다.

## 자료 경로 결합과 저장소 분리 판단

35개 notebook에서 파일 경로 리터럴 87회가 확인됐다. 입력 66회, 이미지 12회, 출력 9회이며 현재 대상이 없는 참조는 28회다. 공통 `MATERIALS_ROOT` 같은 추상화는 0건이다.

따라서 `PYTHONPATH`나 import 경로만 바꾸는 것으로 데이터·이미지 경로를 해결할 수 없다. 초기에는 **한 개의 Private 자료 저장소 내부에 과정별 `01/02/03/...` 폴더를 두고, 현재 Public 작업트리의 원본 경로는 유지한 채 Private에 복사**하는 구성이 가장 안전하다. 실제 이동·submodule·bootstrap clone 전환은 수업 smoke test 후 별도 승인으로 진행한다.

새 풀이 notebook은 `test_1.npy`, `test_2.npy`, `bandwidth.csv`를 notebook 옆에서 찾지만 실제 파일은 `data/npy/`, `data/csv/` 아래에 있어 현재 기준 입력 3개가 부재한다. 이는 이관이 만든 문제가 아니라 현재 코드의 사전 존재 경로 문제다.

## Git LFS와 용량

- Git LFS 3.5.1과 filter는 사용 가능하지만 `.gitattributes`, tracking pattern, pointer, object는 모두 0이다.
- 이미지·PDF·ZIP·표형 데이터 등 LFS 후보는 219개, 논리 1,090,034,949 B다.
- 중복을 제거한 고유 SHA-256 객체는 210개, 1,088,997,479 B다.
- 100 MiB를 넘는 3개 파일은 일반 Git으로 push할 수 없으므로 업로드가 승인되면 LFS가 필수다.
- Private+LFS도 저작권·재배포 권리를 해결하지 않는다. Organization LFS quota·bandwidth·비용도 실제 업로드 전에 재확인해야 한다.

## 백업 준비도와 디스크

09:42 KST 최종 재측정 기준 C: 여유는 198,867,787,776 B(185.21 GiB)다. `.git`과 linked worktree 중복을 제외하고 cache까지 보존하는 root snapshot 예비 측정값은 486개·1,126,611,563 B다. 보고서가 생성되는 동안 수치는 조금 늘 수 있으므로 Gate A 시작 직전에 다시 고정한다.

- Phase 1 fresh mirror·local archive·bundle·restore·working snapshot 상한: 약 1.45 GB
- 이후 shadow·LFS cache·clean clone·post-upload backup까지 동시 보존하는 상한: 약 9.30 GB
- 현재 공간은 충분하나 Gate A 직전 다시 측정한다.

기존 `create_backup.ps1`의 원격 mirror·bundle·restore·ref 검증은 PASS다. 그러나 local-only branch, stash, `refs/codex/*`, linked worktree, working-tree source-before/snapshot/source-after SHA exact, secret 분리, LFS cache manifest는 아직 GAP이다. 이 보완 전 새 백업 실행은 No-Go다.

## Go / No-Go

| 단계 | 판정 | 이유 |
|---|---|---|
| Phase 0 최신 조사 | **PASS** | 최신 상태와 자료 hash가 수집됨 |
| Gate A 진입 | **승인 요청 가능** | 20~30분 편집 중단과 외부 백업 쓰기 승인 필요 |
| Phase 1 완전 백업 | **현재 No-Go** | 승인 후 스크립트 보완·dry-run·exact 검증 필요 |
| Private 저장소 생성·LFS upload | **미승인 / No-Go** | B1·B2 별도 승인 필요 |
| Repository Transfer | **No-Go** | fresh 완전 백업·정책/개인정보 검증·Phase 2가 선행되지 않음 |

## Approval Gate A에서 요청할 한 가지 승인

지금부터 약 20~30분 동안 수업 파일 저장·수정을 멈추고, `C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-<KST timestamp>-8e3546c83d7d`에 새 완전 백업을 만드는 것을 승인받아야 한다.

승인 범위는 다음뿐이다.

1. `migration/scripts/create_backup.ps1`과 검증 스크립트를 위 GAP에 맞게 보완하고 parser·dry-run 검증
2. 외부 새 timestamp 경로에 copy-only mirror·bundle·local ref archive·working snapshot 생성
3. 원본 전후 SHA exact와 restore 검증
4. `migration/reports/weekend-backup-verification.md` 작성

활성 루트의 branch, HEAD, index, stash, remote, 기존 파일은 변경하지 않는다. 실패하면 `.partial-*`를 보존하고 즉시 중단하며, 덮어쓰기·reset·force push·삭제는 사용하지 않는다.
