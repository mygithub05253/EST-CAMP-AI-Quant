# AGENTS.md — AI 에이전트 작업 규칙

> 이 파일은 모든 AI 코딩 에이전트(Codex, Cursor, Copilot, Claude 등)를 위한 **단일 진실 원천(source of truth)**입니다.
> Claude는 [`CLAUDE.md`](CLAUDE.md)에서 이 파일을 참조합니다. 규칙이 바뀌면 **이 파일을 먼저** 갱신하세요.

---

## 1. 프로젝트 개요

- **무엇**: 이스트소프트 AI 퀀트 4기(2026-06-16 ~ 2026-11-11) 학습·과제·프로젝트 통합 모노레포
- **목표**: 부트캠프 6개월 전 과정의 자료를 실무 표준으로 관리하고 포트폴리오로 발전
- **언어**: 모든 대화·주석·커밋·문서는 **한국어** (변수/함수명은 영어 camelCase / PascalCase / UPPER_SNAKE_CASE)
- **환경**: Windows · PowerShell · 들여쓰기 2 spaces · 날짜·시간은 **KST 기준**

---

## 2. 폴더 구조

| 폴더 | 용도 |
|------|------|
| `learning/` | 학습 기록 (교재 목차 9단원 단위) |
| `assignments/` | 과제 (요구사항·기한 포함) |
| `projects/` | 프로젝트 코드 ([Cookiecutter DS](https://cookiecutter-data-science.drivendata.org/) 표준, `_template/` 복사) |
| `dashboards/` | 작업 진행 대시보드 (날짜별 폴더) |
| `docs/` | 교재·자료 (**git 제외** — 저작권) |
| `.claude/skills/` | 커스텀 작업 스킬 |

상세는 각 폴더의 `README.md` 참고. 구조 변경 시 루트 [`README.md`](README.md)도 갱신.

---

## 3. GitHub 협업 규칙 ★

모든 작업은 아래 흐름을 따릅니다. (최초 레포 세팅만 예외적으로 main 직커밋했고, 이후 모든 작업에 적용)

1. **작업 전 항상 `git pull`** 로 최신화한다.
2. **새 브랜치를 파서** 작업한다 (버전 관리·오류 복원용).
   - 브랜치 네이밍(실무 관례): `type/short-description`
   - `type` 예시: `feat`(기능) · `docs`(문서) · `chore`(설정·잡일) · `fix`(버그) · `study`(학습기록) · `assignment`(과제)
   - 예: `study/01-python-basic`, `assignment/01-eda`, `docs/agent-rules`
3. 작업 후 **`commit` → `push` → `PR`** 순으로 진행한다.
   - 커밋 메시지: [Conventional Commits](https://www.conventionalcommits.org/) `type: 한국어 요약`
   - 예: `study: 01단원 Python 기초 정리`, `feat: 백테스트 모듈 추가`
   - **브랜치 ↔ PR 정합(중요)**: 나중에 되돌리기·추적이 헷갈리지 않도록 **브랜치명과 PR 제목의 `type`·주제를 반드시 일치**시킨다.
     - 브랜치 `feat/til-template-tips` ↔ PR 제목 `feat: TIL 템플릿 팁 추가` (같은 `type`, 같은 주제)
     - 자동 생성된 워크트리 브랜치(예: `claude/xxx`)로 작업했다면, **PR 생성 전 규칙명으로 새 브랜치를 만들거나 리네임**해서 `type/주제`를 맞춘다.
4. PR 생성 후 **auto-merge** 를 수행한다 (GitHub MCP 활용 권장). merge 후 로컬 `main`을 pull로 동기화.

> ⚠️ 커밋 메시지에 시크릿·교재 원문을 포함하지 않는다. `.gitignore` 적용 범위를 항상 확인한다.

---

## 4. 작업 진행 규칙 ★

1. **노션(AI 퀀트 4기) 자료 확인**: 작업 전 노션 주소의 자료를 직접 확인하거나, 사용자가 `@`로 지정/첨부한 자료를 참고한다.
   - 노션: https://oreumi.notion.site/4-AI-35febaa8982b80e2b5c5d3cd155162e2
2. **작업 단위로 대시보드 기록** (아래 5번 규칙).
3. **한 작업 단위로 진행**: 한 작업이 끝나면 → 대시보드에 기록 → 사용자에게 보고 → 확인 → 다음 진행. 자동 모드라도 한 번에 전부 처리하지 않는다.
4. **막히면 질문**: 작업 중 결정이 필요하거나 모호하면 멈추고 사용자에게 질문한 뒤 진행한다.
5. **노션 TIL 기록 (작업 마감 시)**: 학습·과제·프로젝트 작업이 끝나면 캠프 TIL 양식에 맞춰 노션에 기록하고, `worklogs/`에 로컬 미러를 남긴 뒤 GitHub에 푸시한다.
   - 흐름: 노션 TIL 기록 → 로컬 미러 → GitHub 푸시 (스킬: `bootcamp-worklog` = `til-record` + `github-flow` 조합)
   - 노션 양식·연결 1회 세팅은 `.claude/skills/til-record/`(SKILL.md, notion-config.md) 참조.
   - 이 규칙은 강의 시작 후 적용 (OT 기간은 준비만).

---

## 5. 작업 대시보드 규칙 ★

`dashboards/YYYY-MM-DD/progress_dashboard.html` 형태로 날짜별 생성·버전 관리한다.

대시보드에 반드시 담을 내용:
1. **무슨 작업**을 진행했는지 (과제/프로젝트/학습 등 유형 명시)
2. 운영진·강사가 준 **규칙·요구사항·기한**
3. **진행률(%)** — 막대형 진행 현황 시각화 (참고: `stock-agent-project`의 `progress_dashboard.html`)
4. 작업 유형(기획/개발/과제 등)에 맞는 포맷 — 실무 사례 벤치마킹해 발전

---

## 6. 코드·문서 스타일

- **언어**: 한국어 (복잡한 비즈니스 로직엔 한국어 주석 필수)
- **들여쓰기**: 2 spaces
- **네이밍**: 변수/함수 `camelCase` · 클래스/컴포넌트 `PascalCase` · 상수 `UPPER_SNAKE_CASE`
- **Python**: PEP 8 기반, 타입 힌트 권장
- **노트북**: `NN_주제.ipynb` (번호 + 주제) — Cookiecutter DS 관례
- **에러 처리**: try-except에서 단순 로그가 아닌 적절한 처리·복구

---

## 7. 보안·주의사항

- **교재·저작권 자료**(`docs/book`, `docs/pdf`, `docs/zip`, `*.pdf`, `*.zip`)는 절대 커밋하지 않는다 (`.gitignore` 적용).
- **시크릿**(`.env`, API 키 등)은 커밋 금지.
- 데이터 원본(`data/raw` 등)과 모델 아티팩트는 git 제외, 구조만 `.gitkeep`으로 추적.
- 파괴적 git 작업(force push, reset --hard 등)은 사용자 확인 후에만.
