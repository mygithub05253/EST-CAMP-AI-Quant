# CLAUDE.md — Claude Code 작업 규칙 (이 프로젝트)

> 이 프로젝트의 모든 작업 규칙은 [`AGENTS.md`](AGENTS.md)를 **단일 진실 원천**으로 따릅니다.
> 아래는 Claude Code 특화 사항만 추가로 정리합니다. 규칙 변경은 항상 `AGENTS.md`를 먼저 수정하세요.

---

## 0. 규칙 우선순위

1. 사용자의 글로벌 규칙 (`~/.claude/CLAUDE.md`)
2. **이 프로젝트의 [`AGENTS.md`](AGENTS.md)** ← 협업·작업·대시보드 규칙의 본문
3. 본 CLAUDE.md (Claude/MCP 특화 보강)

---

## 1. 핵심 규칙 요약 (전문은 AGENTS.md)

- **GitHub**: `pull → branch → commit → push → PR → auto-merge` (최초 세팅만 main 직커밋 예외)
- **작업 진행**: 한 작업 완료 → 대시보드 기록 → 보고 → 확인 → 다음. 막히면 질문.
- **대시보드**: `dashboards/YYYY-MM-DD/progress_dashboard.html` 날짜별 생성.
- **언어/스타일**: 한국어 · 2 spaces · KST 기준.
- **금지**: 교재·시크릿·데이터원본 커밋.

---

## 2. MCP 활용 가이드 (Claude 전용)

이 프로젝트에서 연결된 MCP를 적극 활용합니다.

| 작업 | 사용할 MCP | 비고 |
|------|-----------|------|
| 노션 자료 확인 | **Notion MCP** | 작업 전 AI퀀트 4기 노션 자료 확인 |
| GitHub PR/merge | **GitHub MCP** | PR 생성·auto-merge 자동화 |
| 금융 데이터 | korea-stock-mcp, pykrx-mcp | 공시·시세·재무 (퀀트 실습/프로젝트) |
| 웹 벤치마킹 | firecrawl, tavily, WebSearch | 실무 사례·폴더구조·스킬 조사 |
| RAG | local-faiss | 문서 임베딩·검색 (필요 시) |

---

## 3. 작업 시작 전 체크리스트

1. `AGENTS.md` 규칙 재확인
2. `git pull` 로 최신화 → 작업 브랜치 생성
3. 관련 노션/첨부 자료 확인
4. 작업 → 검증 → 대시보드 기록 → 보고

---

## 4. 스킬

작업별 커스텀 스킬은 `.claude/skills/`에 둡니다. 실무 사례(Stars 높은 레포 등)를 벤치마킹해
대시보드 생성·GitHub 플로우·학습노트 작성 등을 스킬화합니다. (Task 3 후속 단계)
