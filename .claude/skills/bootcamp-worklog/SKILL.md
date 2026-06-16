---
name: bootcamp-worklog
description: 부트캠프 일일/작업 마감을 한 번에 처리하는 오케스트레이터. 노션 TIL 기록 → 로컬 worklogs 미러 → GitHub 푸시(commit→push→PR→auto merge→main pull)까지 묶어 실행한다. 사용자가 "수업 마무리했어/수업 끝났어/오늘 작업 마감/하루 정리해서 다 올려줘/TIL 기록하고 깃허브까지" 하거나 하루를 마무리할 때 사용한다.
---

# 부트캠프 작업 마감 오케스트레이터

하루 또는 한 작업이 끝났을 때, **기록 → 미러 → 푸시**를 한 흐름으로 처리한다.
개별 단계는 기존 스킬을 조합한다: `til-record`, `dashboard-create`, `github-flow`.

## 전체 흐름
```
[1] 내용 수집 → [2] 노션 TIL 기록 → [3] 로컬 미러 → [4] (선택) 대시보드 → [5] GitHub 푸시
```

### [1] 내용 수집
- 오늘 한 작업(학습/과제/프로젝트)을 사용자와 정리한다.
- 관련 산출물 경로 확인: `learning/<단원>/`, `assignments/`, `projects/`

### [2] 노션 TIL 기록  → `til-record` 스킬
- `til-record`의 절차로 노션 TIL DB에 항목을 추가한다 (양식: 오늘 배운 내용 요약 + 오늘의 회고).
- 노션 연결이 안 돼 있으면([notion-config.md](../til-record/notion-config.md) 미설정) 이 단계는 **건너뛰고** 사용자에게 1회 세팅을 안내한다. 로컬 미러는 계속 진행한다.

### [3] 로컬 미러
- 동일 내용을 `worklogs/YYYY-MM-DD_주제.md`로 저장한다 (`til-record`의 `til-template.md` 사용).

### [4] (선택) 대시보드  → `dashboard-create` 스킬
- 진행률·작업 로그 갱신이 필요하면 오늘 날짜 대시보드를 생성/갱신한다.

### [5] GitHub 푸시  → `github-flow` 스킬
- `study/<주제>` 또는 `chore/worklog-YYYY-MM-DD` 브랜치를 파서 **commit → push → PR → auto merge → main pull** 까지 완료한다.
- 커밋 메시지 예: `study: 2026-06-17 TIL 01단원 정리`
- auto merge 후 로컬 `main` 으로 체크아웃 후 `git pull` 하여 동기화한다.

## 마감 체크리스트
- [ ] 노션 TIL 기록 완료 (또는 미연결 사유 안내)
- [ ] `worklogs/` 로컬 미러 저장
- [ ] 산출물(코드/노트북) 커밋 포함 여부 확인
- [ ] 교재·시크릿 미포함 확인 (`git status`)
- [ ] PR merge 후 main 동기화

## 주의
- 노션은 외부 서비스이므로, 기록 전 현재 DB 스키마를 `notion-fetch`로 확인한다.
- 한 번에 자동 실행하지 말고, 노션 기록 내용과 푸시 직전 변경 목록은 사용자에게 한 번 보여주고 진행한다 (작업 규칙: 보고 후 진행).
- 교재 원문·시크릿은 노션/깃 어디에도 올리지 않는다.
