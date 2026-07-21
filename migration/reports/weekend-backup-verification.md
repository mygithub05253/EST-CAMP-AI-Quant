# 주말 신규 백업 검증

- 상태: **FAIL — Phase 1 완전 백업 미완료**
- 실행 시각(KST): 2026-07-21 10:34
- 실패 확인 시각(KST): 2026-07-21 10:36
- 기준 branch / HEAD: `main` / `8e3546c83d7dd874fa67cb02d441076d58a2e615`
- 보존한 incomplete 세트: `C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-20260721-103429-8e3546c83d7d.partial-48692`

이번 시도는 `complete.json`과 `manifest.json`을 만들기 전에 중단됐다. 따라서 위 partial은 **완전 백업이나 복구 기준으로 판정하지 않는다**. 기존 백업과 기존·신규 `.partial-*`는 삭제하거나 덮어쓰지 않았다.

## 실행 직전 기준선

| 항목 | 측정값 |
|---|---|
| branch / HEAD / `origin/main` / live `main` | `main` / 모두 `8e3546c83d7dd874fa67cb02d441076d58a2e615` |
| tracked / staged / unstaged | 0 / 0 / 0 |
| index SHA-256 | `a7b445ca1e7c778cd804172a092d2d05e5654508172bca49af0ce9bd368c7ed2` |
| local ref | 20개, digest `319d3b2acaeec1c693e148b822ff9f16391ee868443c3c5128dad1c45fd09c78` |
| linked worktree | 4개, digest `dadfaaaba8c8e91fc7d501abb7b3cb975fba07a478a3fecdeb01addfca752602` |
| non-`migration/` 파일 | 890개 / 1,157,817,261 B |
| non-`migration/` manifest SHA-256 | `a78eb3b883a0bb5098c95f6e1a4a0ab8da3da9d0343166045d0377f4aaee8a8a` |
| 자료 manifest 파일 SHA-256 | `99abea79a9836af81bb1b0b44bef70df85811b53fcbe962929a9676ab7081f47` |
| reparse point / 시크릿 파일명 후보 | 0 / 0 |
| C: 여유 공간 | 198,091,862,016 B |

첫 측정과 실행 직전 non-`migration/` 경로·크기·해시는 exact 일치했다.

## 실패 원인

원격 mirror·bundle·restore와 로컬 mirror·bundle·restore를 만든 뒤 raw `.git` snapshot을 재해시하는 단계에서 Windows PowerShell 5.1의 일반 Win32 경로 한계에 걸렸다.

- 실패 경로 길이: 303자
- 실제 경로: raw `.git` snapshot 아래 `refs/codex/turn-diffs/checkpoints/...`
- 일반 경로 API 결과: 경로 없음
- extended-length(`\\?\`) API 결과: 경로 존재
- 삭제·복원·우회 복사는 수행하지 않고 즉시 중단

보존한 partial 현황은 3,221개 파일·650개 디렉터리·138,616,952 B다. Remote/Local mirror와 bundle, raw `.git` snapshot은 존재하지만 전체 working-tree snapshot·최종 manifest·`complete.json`이 없으므로 부분 산출물일 뿐이다.

## 실패 후 원본 불변 확인

실패 뒤 다시 측정한 결과 다음 값이 실행 직전과 동일했다.

- branch, HEAD, `origin/main`, origin URL
- index SHA-256와 tracked/staged/unstaged 0
- local ref 20개와 ref digest
- linked worktree 4개와 worktree digest
- non-`migration/` 890개·1,157,817,261 B·manifest SHA-256

활성 원본 Git 상태나 수업 파일은 변경하지 않았다.

## 보완과 읽기 전용 확인

`backup_common.ps1`의 파일 해시·트리 열거를 extended-length 경로에 대응하도록 보완했고, `validate_transfer.ps1`의 백업 재귀 열거도 같은 정책으로 맞췄다.

보존한 partial의 raw `.git` snapshot을 수정 없이 다시 읽어 원본과 비교한 결과:

| 항목 | 원본 | snapshot | 결과 |
|---|---:|---:|---|
| 파일 | 1,593 | 1,593 | exact |
| 디렉터리 | 334 | 334 | exact |
| 크기 | 24,348,046 B | 24,348,046 B | exact |
| tree SHA-256 | `a1ba01ce435727bb05b6e4028a60ecb18f6698adf44c79f6af40937fa308a4c1` | 동일 | exact |
| missing / extra / hash mismatch | 0 | 0 | PASS |

보완 후 PowerShell 5.1 parser와 dry-run은 통과했다. 그러나 실패 규칙과 기존 partial 불변 원칙에 따라 같은 세트 재사용이나 새 세트 자동 재시도는 하지 않았다.

## 범위 준수와 다음 조건

- 활성 저장소 `pull`, `fetch`, checkout, switch, branch 생성, stash 변경, commit, push, PR: 수행하지 않음
- Repository Transfer·새 GitHub 저장소·LFS tracking/upload·remote 변경: 수행하지 않음
- 기존 백업·기존/신규 partial·원본 파일 삭제 또는 덮어쓰기: 수행하지 않음
- Phase 1 판정: **FAIL / 재시도 승인 전 중단**

다음 시도는 사용자가 다시 수업 파일 저장을 멈춘 뒤, 새 KST timestamp 경로를 승인한 경우에만 실행한다. 위 partial은 그대로 보존하며 재사용하지 않는다.
