# 🚀 projects — 프로젝트 코드

미니 프로젝트·팀 프로젝트·최종 프로젝트 코드를 관리합니다. 각 프로젝트는
[Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/) 표준 구조를 따릅니다.

## 새 프로젝트 시작하기

[`_template/`](_template/) 폴더를 복사해 `NN_프로젝트명/`으로 만듭니다.

```powershell
Copy-Item -Recurse projects/_template projects/01_my-project
```

## 표준 구조 (Cookiecutter DS)

```
프로젝트명/
├── README.md
├── data/
│   ├── raw/         # 원본 데이터 (불변, git 제외)
│   ├── interim/     # 중간 가공 데이터 (git 제외)
│   ├── processed/   # 모델 입력용 최종 데이터 (git 제외)
│   └── external/    # 외부 데이터 (git 제외)
├── notebooks/       # 탐색·분석 노트북 (NN_주제.ipynb)
├── src/             # production 코드 (재사용 모듈)
├── models/          # 학습된 모델 (git 제외)
├── reports/
│   └── figures/     # 분석 결과 그래프·이미지
└── references/      # 데이터 사전·참고 자료
```

## 원칙
- **데이터 불변성**: `data/raw`는 절대 수정하지 않음
- **탐색과 production 분리**: 실험은 `notebooks/`, 재사용 코드는 `src/`
- 데이터·모델 원본은 `.gitignore` 처리 (구조만 `.gitkeep`으로 추적)

## 프로젝트 목록
> 아직 없음

| # | 프로젝트 | 설명 | 상태 |
|---|----------|------|------|
| - | - | - | - |
