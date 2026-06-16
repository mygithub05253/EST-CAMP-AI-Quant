---
name: dashboard-create
description: EST-Camp-AI-Quant 작업 진행 대시보드(progress_dashboard.html)를 날짜별로 생성·갱신한다. 사용자가 "대시보드 만들어/갱신해", "오늘 작업 기록", "진행 현황 정리"를 요청하거나, 한 작업(과제/프로젝트/학습)이 끝나 기록이 필요할 때 사용한다.
---

# 작업 진행 대시보드 생성 스킬

`dashboards/YYYY-MM-DD/progress_dashboard.html`을 일관된 포맷으로 생성·갱신한다.
규칙 원천은 루트 `AGENTS.md`의 "작업 대시보드 규칙"이다.

## 사용 시점
- 한 작업(과제/프로젝트/학습) 완료 직후 기록할 때
- 사용자가 진행 현황 정리·갱신을 요청할 때

## 절차
1. **오늘 날짜(KST)** 폴더 `dashboards/YYYY-MM-DD/`를 확인/생성한다.
2. 같은 날짜 대시보드가 이미 있으면 **갱신**(진행률·작업카드·로그 추가), 없으면 [`template.html`](template.html)을 복사해 새로 만든다.
3. 아래 4대 필수 요소를 채운다.
4. (선택) 코드 변경이므로 `AGENTS.md` GitHub 규칙에 따라 브랜치→PR로 반영. 단순 기록성 갱신은 사용자 합의에 따른다.

## 대시보드 필수 요소 (작업 대시보드 규칙)
1. **무슨 작업**인지 — 유형(과제/프로젝트/학습/기획) 명시
2. **규칙·요구사항·기한** — 운영진·강사 지침이 있으면 반드시 포함
3. **진행률(%)** — 전체 + 작업별 막대 차트
4. **작업 유형에 맞는 포맷** — 기획/개발/과제별로 강조점 조정

## 템플릿 채우는 법 ([template.html](template.html))
플레이스홀더를 실제 값으로 치환한다:
- `{{DATE}}` — 기준일 `YYYY-MM-DD`
- `{{WORK_TYPE}}` — 작업 유형 (예: 학습·과제·개발·기획)
- `{{TITLE}}` / `{{LEDE}}` — 제목 / 한 줄 요약
- `{{OVERALL_PCT}}` — 전체 진행률 숫자
- `{{TASK_CARDS}}` — 작업 카드 묶음 (아래 스니펫 반복)
- `{{RULES}}` — 규칙·요구사항·기한 블록
- `{{WORK_LOG}}` — 시간순 작업 로그 항목

### 작업 카드 스니펫 (상태: done/now/todo)
```html
<article class="task-card done">   <!-- done | now | todo -->
  <div class="task-head">
    <span class="task-title">작업명</span>
    <span class="task-pct">100%</span>
  </div>
  <span class="badge done">완료</span>   <!-- 완료 | 진행중 | 대기 -->
  <ul><li>세부 항목</li></ul>
</article>
```

### 로그 항목 스니펫
```html
<div class="log-item">
  <div class="log-rail"><div class="log-dot">✓</div><div class="log-line"></div></div>
  <div class="log-body"><h3>제목</h3><p>설명</p></div>
</div>
```

## 참고
- 막대형 진행률·루브릭 시각화 심화 예시: `stock-agent-project`의 `progress_dashboard.html`
- 이전 날짜 대시보드는 **보존**(스냅샷)해 추이를 남긴다.
