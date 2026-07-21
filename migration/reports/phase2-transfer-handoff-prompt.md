# Phase 2 (Organization Transfer) 인수인계 프롬프트

> 작성: 2026-07-21 11:25 KST. Phase 1 완료 직후 기준.
> 새 세션에서 이어갈 때 아래 "붙여넣을 프롬프트"를 그대로 사용하세요.

---

## 현재 상태 요약

### 완료된 것

| 항목 | 상태 |
|---|---|
| 수업 자료 원격 반영 | PR #29 머지 (`시계열분석_풀이.ipynb`, `docs/image/zoom-web-cam-image.webp`) |
| 백업 스크립트 결함 수정 | PR #30 머지 (빈 컬렉션 처리 3건) |
| **Gate A 완전 백업** | **PASS** — `before-transfer-20260721-111152-14277f98fb22` (1.3 GB) |
| 현재 `main` | `1896396` (백업 시점은 `14277f9`) |
| working tree | clean, 모든 ref가 origin에 반영됨 |

### 백업 세트 위치

```
C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-20260721-111152-14277f98fb22
```

- `complete.json` status PASS, 전 검증 플래그 true, mismatch 0
- 독립 검증 완료: bundle verify 통과, 미러 `main` 일치, 파일 내용 판독 성공
- 포함: worktree 4개 + ignored 교재 1.02 GiB + stash + cache

> 주의: 백업은 `14277f9` 시점이다. 이후 PR #30(`1896396`)은 `migration/` 문서·스크립트 변경뿐이며
> 원격에 모두 푸시되어 있으므로 복구 위험은 없다.

### Transfer 사전 점검 결과

| 항목 | 값 | 판단 |
|---|---|---|
| 대상 조직 | `EST-Bootcamp-AI-Quant` | 기존 레포 **0개**, 이름 충돌 없음 |
| 내 역할 | `admin` (active) | Transfer 권한 있음 |
| 조직 플랜 | free | 공개 레포 무제한 / LFS 1GB 제한 |
| 현재 레포 | `mygithub05253/EST-CAMP-AI-Quant`, PUBLIC, 약 17MB | — |
| 토큰 스코프 | `gist, read:org, repo, workflow` | `admin:org` 없음 — Transfer 실패 시 재인증 필요 |

---

## 사용자가 확정한 방침

1. **강사 배포 코드는 public 커밋 가능** — 부트캠프 담당자가 확인해야 하므로.
2. **Private 이관 대상 = 데이터 + 교재 PDF·ZIP** — 공개 레포에는 올리지 않되,
   조직 내 Private 보관 레포로는 이관한다. (이전 문서의 "업로드 금지" 기재는 오기였음, 2026-07-21 정정)
3. **최종 목표**: 조직으로 레포 이관 → 내부 폴더들을 별도 레포로 분리 보관.
4. **작업 단위마다 보고 후 세션 계속/이동을 사용자가 선택**한다.

---

## 다음 단계 (Phase 2)

### Stage A: Organization Transfer

- Native Transfer는 서버 사이드 작업이며 **로컬 파일을 건드리지 않는다**.
- 전송 후 검증이 끝난 다음 로컬 `.git/config`의 `origin` URL만 변경한다.
- GitHub가 구 경로 → 신 경로 redirect를 자동 설정한다.
- 전송 후 구 경로 이름을 재사용하지 않는다.

### Stage C: 폴더별 저장소 분리

`migration/reports/repository-split-plan.md` 참조. 권장 후보는 루트를 `bootcamp-hub`로 유지하고
`learning/`, `assignments/`, 각 `projects/.../`를 submodule working tree로 두는 방식이다.
단, parent index의 tracked 파일을 gitlink로 바꾸는 대규모 변경이므로 **별도 승인과 PR로만** 수행한다.

---

## 미해결 항목

1. **`admin:org` 스코프 부재** — Transfer 실패 시 재인증 필요.
2. **경로 결합** — 35개 notebook에 경로 리터럴 87회. 분리 전 현재 경로 유지 복제본으로 검증 필요.
3. **저작권** — 교재 PDF·ZIP은 Private+LFS로도 재배포 권리가 해결되지 않는다.

> 실패 partial 4개(약 1.6 GB)는 완전 백업 체크섬 36개 독립 재검증 후 삭제 완료.
> 현재 백업 디렉터리에는 완결 백업 2개(1,248 MB + 40 MB)만 남아 있다.

---

## 붙여넣을 프롬프트

```
EST-Camp-AI-Quant 조직 이관 작업을 이어서 진행합니다.

현재 상태:
- Phase 1 (Gate A 완전 백업) PASS 완료
  백업 세트: C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-20260721-111152-14277f98fb22
- PR #29(수업 자료), PR #30(백업 스크립트 결함 수정) 머지 완료
- main = 1896396, working tree clean, 모든 ref origin 반영됨

목표:
https://github.com/mygithub05253/EST-CAMP-AI-Quant 를
https://github.com/EST-Bootcamp-AI-Quant 조직으로 이관한 뒤,
내부 폴더들을 별도 레포로 분리해 보관하는 구조로 만들기.

방침:
- 강사 배포 코드는 public 커밋 OK (담당자 확인 필요)
- Private 이관 대상은 데이터뿐, 교재 PDF·ZIP은 GitHub 업로드 금지
- 작업 단위마다 보고하고, 세션 계속/이동은 내가 선택

먼저 migration/reports/phase2-transfer-handoff-prompt.md 와
migration/reports/risk-and-blockers.md 를 읽고 현재 상태를 파악한 뒤,
Stage A (Organization Transfer) 부터 진행해주세요.
진행하다가 필요하면 질문해주세요.
```
