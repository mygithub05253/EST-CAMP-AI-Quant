---
name: study-note
description: 강의·교재 학습 내용을 learning/ 커리큘럼 단원에 일관된 TIL 포맷으로 정리한다. 사용자가 "오늘 배운 거 정리/학습노트 작성/N단원 정리" 하거나 강의 내용을 기록할 때 사용한다.
---

# 학습노트(TIL) 작성 스킬

부트캠프 강의·교재 내용을 `learning/<단원>/` 아래에 표준 포맷으로 정리한다.

## 단원 매핑 (교재 목차)
| # | 단원 | 폴더 |
|---|------|------|
| 01 | Python 프로그래밍 | `learning/01-python-basic/` |
| 02 | 전처리 및 시각화 | `learning/02-preprocessing-viz/` |
| 03 | 기초 수학·통계 | `learning/03-math-statistics/` |
| 04 | 시계열 데이터 분석 | `learning/04-time-series/` |
| 05 | 데이터 크롤링 | `learning/05-data-crawling/` |
| 06 | 머신러닝·딥러닝 | `learning/06-ml-dl/` |
| 07 | 투자분석 방법론 | `learning/07-investment-analysis/` |
| 08 | 금융 필수 지식 | `learning/08-finance-essentials/` |
| 09 | 퀀트 모델링 | `learning/09-quant-modeling/` |

## 절차
1. 주제에 맞는 단원 폴더를 고른다 (위 표).
2. 노트 파일을 만든다: `YYYY-MM-DD_주제.md` (날짜는 KST)
3. 아래 템플릿으로 작성한다.
4. 실습 코드는 같은 폴더에 `NN_주제.ipynb` 또는 `.py`로 둔다.
5. 해당 단원 `README.md`의 인덱스에 링크를 추가한다 (있으면).
6. `github-flow` 스킬로 `study/<단원>` 브랜치를 파서 반영한다.

## 노트 템플릿
```markdown
# {주제} — {YYYY-MM-DD}

> 단원: {NN 단원명} · 강사: {이름}

## 핵심 요약 (3줄)
- ...

## 배운 내용
### {소주제}
- 개념:
- 예시/코드:

## 실습
- 파일: `NN_주제.ipynb`
- 결과/메모:

## 어려웠던 점 · 질문
- ...

## 더 볼 것 (TODO)
- [ ] ...
```

## 작성 원칙 (TIL 관례)
- **작은 단위로 자주** 커밋한다 (커밋: `study: NN단원 주제 정리`).
- input 나열이 아니라 **자기 언어로 요약** + 다시 볼 키워드를 남긴다.
- 교재 원문을 그대로 복사하지 않는다 (저작권). 직접 작성한 요약·메모만 기록.
