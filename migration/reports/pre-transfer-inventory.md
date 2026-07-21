# 이관 전 Inventory

기준 스냅샷: 2026-07-20 KST  
원격 변경: 없음

## 전송 판단 요약

**조건부 가능**입니다. 원본 ADMIN, 대상 Organization active/admin, 저장소 생성 권한, 동일 이름 비충돌, 관찰 가능한 fork 비충돌은 확인했습니다. 그러나 Organization 정책 일부와 Projects v2는 현재 토큰 scope 부족으로 미확인이고, 로컬 working tree가 dirty이므로 실제 전송 조건은 아직 충족하지 않습니다.

## 원본 저장소

| 항목 | 값 |
|---|---|
| 저장소 | `mygithub05253/EST-CAMP-AI-Quant` |
| numeric ID | `1270665344` |
| node ID | `R_kgDOS7zQgA` |
| 공개 범위 | Public |
| 기본 브랜치 | `main` |
| `main` SHA | `e04abb769740c3d0057aac4e6baef022c503930b` |
| API 크기 | 14,027 KB |
| 생성 시각 | 2026-06-15T23:57:10Z |
| 최근 push | 2026-07-17T01:36:29Z |
| 설명 | `[이스트소프트 부트캠프] AI Quant 4기` |
| Fork | 아니요 (`network_count=0`) |
| Pages | 미구성 |
| Wiki | 설정은 활성, Wiki Git 콘텐츠는 조회되지 않음 |
| Projects | 설정 활성, Projects v2 실자산은 scope 부족으로 미확인 |
| Discussions | 비활성 |
| Secret scanning | 활성 |
| Push protection | 활성 |
| Dependabot security updates | 비활성 |
| LFS | 현재 포인터 0개 |

Merge commit·squash·rebase가 모두 허용되고 auto-merge와 merge 후 branch 삭제는 비활성입니다. 현재 7개 원격 branch 모두 보호되지 않았고 repository ruleset은 0개입니다.

## 대상 Organization

| 항목 | 값 |
|---|---|
| Organization | `EST-Bootcamp-AI-Quant` |
| numeric ID | `306939834` |
| node ID | `O_kgDOEkuHug` |
| Plan | GitHub Free for organizations |
| 사용자 | `mygithub05253` |
| Membership | `active/admin` |
| Organization 관리 가능 | 예 |
| 저장소 생성 가능 | 예 |
| 현재 저장소 수 | 0 |
| 동일 이름 저장소 | 직접 REST 404 + Organization 목록 0건 |
| 기본 repository permission | `read` |
| 멤버 생성 유형 | `all` |
| 2FA 강제 | 아니요 |
| Organization GitHub App 설치 | 0건 |

`admin:org` scope가 없어 Organization Actions 정책·기본 workflow 권한·Organization rulesets·Organization Actions secret/variable 이름은 **없음이 아니라 미확인**입니다.

## GitHub 자산

| 자산 | 수량·상태 |
|---|---|
| Branches | 7, 모두 unprotected |
| Tags | 0 |
| Issues(PR 제외) | 0 |
| Pull Requests | 27, 모두 merged, open 0 |
| Releases | 0 |
| Labels | 9 |
| Milestones | 0 |
| Environments | 1 (`copilot`) |
| Actions workflows | 1 (`Copilot`, dynamic workflow, active) |
| Workflow runs | 1, success |
| Actions variables | 0 |
| Actions secrets | 0, 값은 조회·저장하지 않음 |
| Dependabot/Codespaces secrets | 0 |
| Deploy keys | 0 |
| Webhooks | 0 |
| Collaborators | 1 (`mygithub05253`, admin) |
| Repository rulesets | 0 |
| Pages | 미구성 |

원격 `git ls-remote`는 HEAD 1개, branch 7개, tag 0개, PR head ref 27개를 확인했습니다.

## 로컬 Git 상태

| 항목 | 상태 |
|---|---|
| 루트 | `C:\Users\kik32\workspace\EST-Camp-AI-Quant` |
| 현재 branch | `main` |
| HEAD | `e04abb769740c3d0057aac4e6baef022c503930b` |
| 기존 `origin/main` | 동일 SHA |
| live 원격 `main` | 동일 SHA |
| origin | `https://github.com/mygithub05253/EST-CAMP-AI-Quant.git` |
| staged | 0 |
| 사용자 수정 | notebook 6개 |
| 사용자 untracked | 10개(이미지 8, notebook 1, CSV 1) |
| 로컬 branch | 9 |
| 원격 추적 branch | 7 |
| Tags | 0 |
| Stash | 1 |
| Linked worktrees | 4(루트 포함), 별도 2곳에 untracked 도구 파일 존재 |
| `.gitmodules` | 없음 |
| `.gitattributes` | 없음 |
| Git LFS 포인터 | 0 |
| `.github/` | 없음 |
| CODEOWNERS | 없음 |
| Git 객체 | loose 1,410개 / 21.28 MiB |
| `git fsck --full` | 성공, dangling 250개 |

현재 `main`의 사용자 변경과 이번 `migration/` 산출물은 stage·commit하지 않았습니다. `git pull`, checkout, fetch도 수행하지 않았습니다.

## 원격 백업에 포함되지 않는 로컬 상태

- 수정·미추적·ignore 파일
- 로컬 전용 branch와 stash
- linked worktree의 미커밋 상태
- dangling object
- 원본 PDF·ZIP 약 1.02 GiB

따라서 검증된 원격 Mirror·Bundle이 있어도 전체 로컬 자료 무손실 조건은 아직 충족하지 않습니다.

## 미확인 항목

- Organization Actions 정책·Rulesets·조직 secret/variable 이름: `admin:org` 필요
- Projects v2 실자산: `read:project` 필요
- Codex/Copilot GitHub App의 Organization 설치·재승인 계획
- 교재·PDF·ZIP·이미지·데이터의 재배포 권리
- 수업 저장 중단 시점의 일관된 파일시스템 스냅샷
- 캠프 Notion: 연결 재인증 필요로 조회 실패; 첨부 실행 명세서를 기준으로 작업함

## 근거 파일

- `repository-before.json`
- `github-assets-before.json`
- `organization-access-before.json`
- `local-repository-before.json`
- `transfer-validation-baseline.json`

