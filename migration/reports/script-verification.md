# 스크립트 검증 결과

## 2026-07-21 재검토

| 항목 | 결과 |
|---|---|
| PowerShell 3개 parser 재검사 | 오류 0 |
| `collect_inventory.ps1 -Execute` 최신 읽기 전용 수집 | 성공, `weekend-current/` JSON 4개와 상태 보고서 생성 |
| Organization 결제 이메일 제외 보완 | 적용, 보고서 저장 0건 |
| `create_backup.ps1` 원격 mirror·bundle·restore 기능 | 이전 실행 검증 PASS 유지 |
| Phase 1 완전 로컬 상태 백업 | **GAP — 실행하지 않음** |
| `validate_transfer.ps1` 실제 Transfer 검증 | 대상 미생성 상태이므로 실행하지 않음 |

현재 `create_backup.ps1`은 local-only branch, stash, `refs/codex/*`, linked worktree, working snapshot의 파일별 source-before/snapshot/source-after SHA-256 exact, secret 분리, LFS cache/OID manifest를 모두 증명하지 못한다. 따라서 Gate A 승인 후 이 항목을 보완하고 dry-run을 통과하기 전에는 `-Execute`를 사용하지 않는다.

## 2026-07-20 검증 기록

## 환경

- Windows PowerShell 5.1.26100.8875
- Git 2.45.2.windows.1
- GitHub CLI 2.88.1
- Git LFS 3.5.1

## 정적 검증

세 PowerShell 파일을 UTF-8 BOM으로 저장하고 PowerShell 5.1 Parser로 검사했습니다.

| 파일 | Parser 오류 |
|---|---:|
| `collect_inventory.ps1` | 0 |
| `create_backup.ps1` | 0 |
| `validate_transfer.ps1` | 0 |

## Dry-run 검증

세 스크립트 모두 `-Execute` 없이 exit 0이며 조회·백업·검증을 수행하지 않고 예정 작업만 출력했습니다.

## 실행 검증

| 검증 | 결과 |
|---|---|
| Inventory 실제 수집 | 성공 |
| Secret 값 미저장 | 확인 |
| Actions variable 값 미저장 | 확인 |
| Webhook endpoint 미저장 | 확인 |
| Mirror clone | 성공 |
| Mirror `fsck --full --strict` | 성공 |
| Bundle 생성 | 성공 |
| 빈 bare repo에서 Bundle verify | 성공 |
| Bundle 별도 mirror 복원 clone | 성공 |
| 복원 clone fsck | 성공 |
| Mirror/Bundle/복원/원격 branch·tag ref exact | 성공 |
| Bundle SHA256 | 성공 |
| 동일 HEAD·ref 세트 재실행 | 기존 불변 세트 재검증 성공 |
| PreTransfer | 의도대로 dirty working tree 1건 FAIL |
| PostTransfer 사전 시험 | 대상 미존재·원본 존재를 UNKNOWN으로 보고, exit 9 |

초기 실행에서는 Mirror와 원격의 ref 문자열 구분자(tab/space)를 정규화하지 않은 구현 오류를 발견했습니다. partial 세트를 완료 처리하지 않고 보존했으며, canonical `ref<TAB>sha` 비교로 수정한 뒤 새 불변 세트에서 전체 검증을 통과했습니다.
