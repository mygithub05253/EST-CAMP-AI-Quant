# 소유자 URL·절대 경로 Inventory

## 2026-07-21 최신 재조사

- 학습·과제·프로젝트의 tracked/ignored 파일에서 구 owner `mygithub05253`와 정확 owner URL은 0건이다.
- 정확 owner URL은 `migration/` 기준 JSON·명령·핸드오프 등 8개 파일에만 있다. 이 값은 이관 전후 비교 기준이므로 일괄 치환하지 않는다.
- bare owner 식별자도 `migration/` 21개 파일에만 있다.
- Windows 사용자 프로필 절대경로는 tracked notebook 6개와 ignored checkpoint 6개에서 확인했다.
- 일반 Windows 절대경로는 tracked notebook source 14개 파일/15곳, output 9개 파일/16곳이다. source는 별도 정리 PR에서 프로젝트 상대경로로 바꾸고 output은 clear/re-run한다.
- `migration/` 보고서의 로컬 절대경로는 복구·검증에는 필요하지만 공개 commit 전 placeholder 치환이 필요하다.

### 개인정보 형식 후보(값 미저장)

| 파일 | 위치 | 유형 | 판단 |
|---|---|---|---|
| `assignments/01-python-basic/Day01.ipynb` | source cell 4 line 6, cell 5 line 1 | 주민등록번호 형식 2곳 | 예제 변수 문맥이나 실제 값 여부 확인 필요 |
| `learning/01-python-basic/3. 컬렉션.ipynb` | source cell 56 line 1 | 전화번호 형식 1곳 | 예제 사전 문맥으로 오탐 가능성이 높지만 예약번호 교체 권고 |
| `.claude/skills/github-flow/SKILL.md` | line 35 | 이메일 형식 1곳 | 협업 예시인지 확인 후 개인 주소라면 제거 |

각 notebook의 ignored checkpoint 복제에도 같은 후보가 있다. GitHub/OpenAI/AWS/Google key, private-key marker, Bearer, credential assignment/URL 정규식 후보와 `.env`·key/cert 파일명 후보는 0건이었다. 이 결과는 binary와 Git history 전체의 부재 증명이 아니므로 실제 Transfer 전에 history scan을 별도로 수행한다.

## 2026-07-20 참고 조사

기준: 2026-07-20 KST  
검색 범위: tracked 파일과 현재 working tree 텍스트  
제외: `.git/`, linked worktree 복사본, 생성 중인 `migration/` 산출물

## 소유자·GitHub URL 검색 결과

| 패턴 | 결과 | 판단 |
|---|---:|---|
| `mygithub05253` | 0 | 기존 코드·문서에는 직접 소유자 참조 없음 |
| `github.com/mygithub05253` | 0 | 교체 대상 없음 |
| `raw.githubusercontent.com` | 0 | 교체 대상 없음 |
| owner-specific `github.io` | 0 | 교체 대상 없음 |
| `EST-CAMP-AI-Quant` | tracked 2, ignored 복사본 1 | URL이 아니라 표시 문자열 |
| generic `github.io` | `.serena/project.yml` 7 | 도구 설명 링크이며 이관 대상 아님 |

저장소 이름 표시 문자열 위치:

- `.claude/skills/dashboard-create/template.html:96`
- `dashboards/2026-06-16/progress_dashboard.html:105`
- `.agents/skills/dashboard-create/template.html:96` — ignore된 복사본

`migration/scripts/*.ps1`의 원본·대상 저장소 문자열은 이관 자동화에 필요한 의도된 기본값입니다.

## 절대 경로 검색 결과

### 수정 필요 가능성이 높은 개인 경로

| 파일 | 줄 | 내용 분류 | 위험 |
|---|---:|---|---|
| `learning/02-preprocessing/2. 판다스_데이터입출력.ipynb` | 69 | `C:\Users\kik32\workspace\...\02-preprocessing-viz\...` | 개인 경로이며 현재 폴더명과도 불일치 |
| `learning/05-time-series/4.분해시계열.ipynb` | 85, 87, 89, 91 | `C:\Users\kik32\AppData\Roaming\Python\...` | 현재 수정 중인 notebook 출력에 사용자 경로 노출 |

### Notebook 출력에 남은 실행 환경 경로

- `learning/02-preprocessing/5. 판다스_데이터프레임응용.ipynb:6019,6268`
- `learning/03-vizualization/1. 데이터시각화_기초.ipynb:636`
- `learning/03-vizualization/3.matplotlib_예제.ipynb:1521,2039,3163,3685`
- `learning/04-math-statistics/1.넘파이_기초.ipynb:3329,3331`

위 항목은 `C:\Users\Administrator\AppData\...`의 temp 또는 Python 설치 경로입니다. 이관 자체를 막지는 않지만 재현성·개인 경로 노출을 줄이기 위해 notebook 출력 정리 또는 상대 경로 전환이 필요합니다.

### 환경 의존 경로

`C:/Windows/Fonts/malgun.ttf`가 여러 tracked notebook과 ignore된 checkpoint에 반복됩니다. Windows 전용 실행 경로이므로 교안 자동화 시 OS별 font fallback 설정이 필요합니다.

### 미발견

- `/Users/...`: 없음
- `/home/...`: 없음
- owner-specific Pages URL: 없음
- submodule URL: `.gitmodules` 자체가 없음
- Actions `uses:` 내부 소유자 경로: `.github/`가 없어 없음
- CODEOWNERS 사용자 참조: 파일 없음

## 결론

Repository Transfer 직후 대규모 owner URL 치환은 현재 필요하지 않습니다. 다만 개인 절대 경로 2종과 notebook 출력 경로는 별도 정리 PR 대상으로 남깁니다. Git commit author나 과거 기록은 rewrite하지 않습니다.

## 재현 명령

```powershell
git grep -n "mygithub05253"
git grep -n "EST-CAMP-AI-Quant"
git grep -n "github.com/mygithub05253"
git grep -n "raw.githubusercontent.com"
git grep -n "github.io"

rg -n -H -uu --hidden `
  -g '!.git/**' `
  -g '!.claude/worktrees/**' `
  -g '!migration/**' `
  'C:\\\\Users\\\\|C:/Users/|C:/Windows/Fonts|/Users/|/home/' .
```
