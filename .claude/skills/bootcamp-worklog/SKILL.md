---
name: bootcamp-worklog
description: 부트캠프 일일/작업 마감을 한 번에 처리하는 오케스트레이터. TIL 본문을 worklogs/에 일자별 저장(노션은 사용자가 직접 붙여넣음) → 대시보드 갱신 → GitHub 푸시(commit→push→PR→auto merge→main pull)까지 묶어 실행한다. 사용자가 "수업 마무리했어/수업 끝났어/오늘 작업 마감/하루 정리해서 다 올려줘/TIL 기록하고 깃허브까지" 하거나 하루를 마무리할 때 사용한다.
---

# 부트캠프 작업 마감 오케스트레이터

하루 또는 한 작업이 끝났을 때, **기록 → 미러 → 푸시**를 한 흐름으로 처리한다.
개별 단계는 기존 스킬을 조합한다: `til-record`, `dashboard-create`, `github-flow`.

## 전체 흐름
```
[1] 내용 수집 → [2] TIL 일자별 저장(+노션 붙여넣기 안내) → [3] 대시보드 갱신 → [4] GitHub 푸시
```

### [1] 내용 수집
- 오늘 한 작업(학습/과제/프로젝트)을 사용자와 정리한다.
- 관련 산출물 경로 확인: `learning/<단원>/`, `assignments/`, `projects/`

### [2] TIL 일자별 저장 + 노션 붙여넣기 안내  → `til-record` 스킬
- `til-record`의 절차로 캠프 양식 본문을 작성해 `worklogs/YYYY-MM-DD_주제.md`에 **일자별로 저장**한다.
- **노션은 사용자가 직접 붙여넣는다.** Claude는 Notion MCP로 자동 기록하지 않고, 저장한 본문을 보여주며 붙여넣기를 안내한다. (개인 공간 MCP 접근 불가)

### [3] 대시보드 갱신 (중요)  → `dashboard-create` 스킬
- 오늘 날짜 `dashboards/YYYY-MM-DD/progress_dashboard.html`에 오늘 작업·진행률을 기록/갱신한다.
- TIL 저장과 대시보드 갱신은 마감 시 **둘 다 필수**로 수행한다.

### [4] GitHub 푸시  → `github-flow` 스킬
- `study/<주제>` 또는 `chore/worklog-YYYY-MM-DD` 브랜치를 파서 **commit → push → PR → auto merge → main pull** 까지 완료한다.
- 커밋 메시지 예: `study: 2026-06-17 TIL 01단원 정리`
- auto merge 후 로컬 `main` 으로 체크아웃 후 `git pull` 하여 동기화한다.

## 마감 체크리스트
- [ ] `worklogs/YYYY-MM-DD_주제.md` 일자별 저장 (TIL 본문 — 노션 붙여넣기용)
- [ ] 사용자에게 노션 붙여넣기 안내 완료
- [ ] `dashboards/YYYY-MM-DD/progress_dashboard.html` 갱신
- [ ] 산출물(코드/노트북) 커밋 포함 여부 확인
- [ ] 교재·시크릿 미포함 확인 (`git status`)
- [ ] PR merge 후 main 동기화

## 주의
- **노션은 사용자가 직접 입력한다.** Notion MCP 자동 기록을 시도하지 않는다 (개인 공간 접근 불가). Claude는 붙여넣기용 본문만 일자별로 저장한다.
- 한 번에 자동 실행하지 말고, 저장한 TIL 본문과 푸시 직전 변경 목록은 사용자에게 한 번 보여주고 진행한다 (작업 규칙: 보고 후 진행).
- 교재 원문·시크릿은 깃·노션 어디에도 올리지 않는다.
