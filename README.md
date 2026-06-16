# EST-Camp-AI-Quant

> 이스트소프트 **AI 퀀트 4기** (2026-06-16 ~ 2026-11-11) 학습·과제·프로젝트 통합 레포지토리

부트캠프 6개월 전 과정의 **학습 기록 + 과제 + 프로젝트 코드**를 한 곳에서 관리하는 모노레포입니다.
폴더 구조는 데이터사이언스 업계 표준([Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/))과
국내 부트캠프 TIL 관례를 벤치마킹해 설계했습니다.

---

## 📂 폴더 구조

| 폴더 | 용도 | 비고 |
|------|------|------|
| [`learning/`](learning/) | 📚 학습 기록 (커리큘럼 단위) | 교재 목차 1:1 정렬 |
| [`assignments/`](assignments/) | ✏️ 과제 (제출물·요구사항·기한) | 과제별 폴더 |
| [`projects/`](projects/) | 🚀 프로젝트 코드 | Cookiecutter DS 구조 |
| [`dashboards/`](dashboards/) | 📊 작업 진행 대시보드 | 날짜별 버전관리 |
| [`docs/`](docs/) | 📁 교재·자료 | **git 제외** (로컬 전용) |
| `.claude/skills/` | 🤖 커스텀 작업 스킬 | GitHub·대시보드 자동화 |

---

## 🗓️ 커리큘럼 (교재 목차 기준)

| # | 단원 | 폴더 |
|---|------|------|
| 01 | Python 프로그래밍 | [`learning/01-python-basic`](learning/01-python-basic/) |
| 02 | Python 전처리 및 시각화 | [`learning/02-preprocessing-viz`](learning/02-preprocessing-viz/) |
| 03 | AI·퀀트 기초 수학·통계 | [`learning/03-math-statistics`](learning/03-math-statistics/) |
| 04 | 시계열 데이터 분석 | [`learning/04-time-series`](learning/04-time-series/) |
| 05 | 데이터 크롤링 | [`learning/05-data-crawling`](learning/05-data-crawling/) |
| 06 | 머신러닝과 딥러닝 | [`learning/06-ml-dl`](learning/06-ml-dl/) |
| 07 | 투자분석 기초 방법론 | [`learning/07-investment-analysis`](learning/07-investment-analysis/) |
| 08 | 퀀트를 위한 금융 필수 지식 | [`learning/08-finance-essentials`](learning/08-finance-essentials/) |
| 09 | 데이터 활용 퀀트 모델링 | [`learning/09-quant-modeling`](learning/09-quant-modeling/) |

---

## 📊 진행 현황

> 최신 대시보드: [`dashboards/`](dashboards/) 폴더의 가장 최근 날짜 폴더 참고

- **현재 단계**: 기초 세팅 (폴더 구조 정립 + 협업 규칙 수립)
- **시작일**: 2026-06-16
- **종료 예정**: 2026-11-11

---

## 🔗 링크

- 노션 (AI 퀀트 4기): https://oreumi.notion.site/4-AI-35febaa8982b80e2b5c5d3cd155162e2
- 노션 (이스트캠프 커뮤니티): https://oreumi.notion.site/EST-CAMP-hello-world-14eebaa8982b80d58306f69f5581ceaf

---

## 🤝 작업 규칙

- Claude 작업 규칙: [`CLAUDE.md`](CLAUDE.md)
- Codex 작업 규칙: [`AGENTS.md`](AGENTS.md)
- 모든 작업은 **브랜치 생성 → commit → push → PR → merge** 흐름을 따릅니다.
