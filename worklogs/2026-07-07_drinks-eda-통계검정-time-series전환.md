# Drinks EDA 마무리 · math-statistics 시험 · time-series 전환 — 2026-07-07

> 날짜: 2026-07-07 · Subject: 수학·통계 → 시계열 분석 · title: Drinks EDA 마무리 + T-test·ANOVA·카이제곱검정 시험으로 math-statistics 마감, time-series 단원 전환 · 피드백 요청: 아니오

## 📝 오늘 배운 내용 요약

1. **국가별 음주 데이터 EDA 마무리 (Drinks)** — 국가·대륙 단위 데이터를 바탕으로 상관관계와 집계 분석을 수행.
    - `drinks.csv`를 불러와 `beer_servings`, `spirit_servings`, `wine_servings`, `total_litres_of_pure_alcohol`, `continent` 컬럼을 확인.
    - 결측치 시각화와 `continent` 결측값 대체를 통해 분석 전 데이터 정제 과정을 정리.
    - 수치형 변수의 피어슨 상관계수를 계산하고, 히트맵과 산점도로 관계를 확인.
    - 대륙별 평균 알코올 소비량을 막대그래프로 비교하고, 전 세계 순수 알코올 소비량 상위 10개 국가를 정렬해 확인.

2. **T-test (6.T-test.ipynb)** — Golf_test 데이터(`TypeA/B/C_before/after`)로 두 종류의 t검정을 비교.
    - `stats.ttest_rel()`로 같은 개체를 반복 측정한 TypeA·TypeB·TypeC의 전후 비교(대응표본 t검정) 수행.
    - `stats.ttest_ind()`로 서로 다른 집단을 비교하는 독립표본 t검정을 실습하고, 두 검정 방식의 전제 조건과 함수 차이(`ttest_ind` vs `ttest_rel`)를 정리.

3. **ANOVA (7.ANOVA.ipynb)** — 세 집단 이상의 평균 비교를 위한 분산분석.
    - 요인이 하나인 일원분산분석(one-way ANOVA)과 요인이 여러 개인 이원·N원분산분석의 차이를 정리.
    - `stats.f_oneway()`로 TypeA·TypeB·TypeC before 값의 평균 차이를 검정하고, `statsmodels`의 `ols` + ANOVA 테이블로 동일한 결과를 재확인.
    - ANOVA 결과만으로는 어떤 집단끼리 차이가 나는지 알 수 없다는 한계도 함께 정리.

4. **카이제곱검정(교차분석, 8.카이제곱검정(교차분석).ipynb)** — 범주형 변수 간 연관성 분석.
    - `smoker.csv`로 `sex`·`smoke` 교차표(`pd.crosstab`)를 만들고 막대그래프로 시각화.
    - `chi2_contingency()`로 두 범주형 변수 간 연관성을 검정하고, 상관분석과 달리 연관성의 정도를 수치(상관계수)로 표현할 수 없다는 점을 확인.

5. **math-statistics 단원 마무리 → time-series 전환** — 시험을 통해 04-math-statistics 단원을 마감하고 다음 단원으로 이동.
    - Drinks EDA + T-test/ANOVA/카이제곱검정 시험을 끝으로 `04-math-statistics` 단원 학습을 마무리.
    - `05-time-series` 단원으로 넘어가 `1.탐색적데이터분석(기온데이터)`를 간단히 소개(서울 기온 데이터 `seoul.csv` 활용 예정).
    - 기온데이터 EDA는 과제로 부여되어 다음 수업 전까지 직접 진행하기로 함.

## 💭 오늘의 회고

1. **배운 점**
    - 대응표본과 독립표본 t검정은 "같은 대상을 반복 측정했는가"가 선택 기준이라는 점이 명확해졌다.
    - ANOVA는 집단이 3개 이상일 때 t검정을 반복하면 신뢰도가 떨어지는 문제를 해결하기 위한 방법이라는 점을 이해했다.
    - 카이제곱검정은 상관계수처럼 연관성 강도를 수치로 주지 않고, 유의성 여부만 판단한다는 차이를 확인했다.

2. **어려운 점/개선할 점**
    - 어떤 상황에 t검정·ANOVA·카이제곱검정 중 무엇을 써야 하는지 변수 유형(연속형/범주형)과 집단 수를 기준으로 빠르게 판단하는 연습이 더 필요하다.
    - 시험 문제를 풀 때 가설(귀무/대립)을 먼저 명확히 세우지 않고 코드부터 작성하는 습관이 있어, 검정 전에 가설을 문장으로 적는 순서를 지켜야 한다.

3. **액션 플랜**
    - Golf_test·smoker 노트북의 검정 코드를 다시 실행하며 각 검정의 가설과 결론을 스스로 말로 설명해 보기.
    - 과제로 받은 `1.탐색적데이터분석(기온데이터)`(`seoul.csv`)를 다음 수업 전까지 미리 진행해 보기.

4. **함께 나누고 싶은 점**
    - EDA로 데이터를 감으로 파악한 뒤, T-test·ANOVA·카이제곱검정으로 그 차이를 통계적으로 확인하는 흐름이 하나로 연결되면서 math-statistics 단원이 마무리되는 느낌을 받았다.

## 📚 참고자료

- 학습 노트북: `learning/04-math-statistics/5.탐색적데이터분석_drinks.ipynb`
- 강사님 노트북: `learning/04-math-statistics/5.탐색적데이터분석_drinks_강사님.ipynb`
- 학습 노트북: `learning/04-math-statistics/6.T-test.ipynb`
- 학습 노트북: `learning/04-math-statistics/7.ANOVA.ipynb`
- 학습 노트북: `learning/04-math-statistics/8.카이제곱검정(교차분석).ipynb`
- 시험 노트북: `assignments/04-math-statistics/math-statistics-test.ipynb`
- 시험 해설: `assignments/04-math-statistics/수학_통계_test_해설.ipynb`
- 데이터 파일: `learning/04-math-statistics/data/csv/drinks.csv`, `Golf_test.csv`, `smoker.csv`
- (과제로 소개) `learning/05-time-series/1.탐색적데이터분석(기온데이터).ipynb`, 데이터: `learning/05-time-series/data/csv/seoul.csv`

## 🔍 내일 학습 예정

- (과제) `1.탐색적데이터분석(기온데이터)` 마무리
- `2.탐색적데이터분석(관광데이터)` 진행
- 본격적인 시계열 분석(시간 시각화, 시계열 분해, 미래예측) 준비

---
- 노션 동기화: 미연결 (사용자가 직접 붙여넣기)
- 멘토 피드백: (멘토가 노션에서 작성)
