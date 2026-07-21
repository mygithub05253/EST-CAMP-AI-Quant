# 자료 경로 결합도 및 Private 저장소 매핑 조사

- 조사 시점: 2026-07-21 KST
- 조사 방식: `learning/`, `assignments/`의 노트북 source cell을 읽기 전용으로 분석
- 소스 파일 변경: 없음

## 결론

현재 자료를 Private 저장소로 **복사만 하고 원본 경로를 유지하면 수업 코드에는 영향이 없다.** 반면 원본을 이동하거나 `materials/` 같은 새 루트로 바꾸면 Python import 경로 설정만으로는 해결되지 않는다. `pandas.read_*`, `numpy.load`, `open()`과 노트북의 HTML/Markdown 이미지 경로는 `PYTHONPATH`를 사용하지 않기 때문이다.

내일 수업 안정성을 우선하면 다음 순서를 권장한다.

1. 한 개의 Private materials 저장소에 원본을 복사한다.
2. Private 저장소 내부를 `01/`, `02/`, `03/` 등의 과정 폴더로 구분한다.
3. 현재 저장소의 원본·상대경로·Git 인덱스·`.gitignore`는 유지한다.
4. 수업과 별개인 후속 단계에서 공통 경로 모듈 또는 동일 경로 마운트 방식을 검증한다.

## 경로 결합 수량

| 항목 | 수량 |
|---|---:|
| 경로를 직접 사용하는 노트북 | 35개 |
| 파일 경로 리터럴 사용 | 87회 |
| 데이터 입력 | 66회 |
| HTML/Markdown 이미지 | 12회 |
| 결과 파일 출력 | 9회 |
| 현재 파일 또는 대상이 존재 | 59회 |
| 현재 대상이 없음 | 28회 |
| 이 중 입력 파일이 없음 | 25회 |
| 공통 경로 추상화 (`DATA_DIR`, `MATERIALS_ROOT`, `PYTHONPATH` 등) | 0회 |

이전 조사보다 노트북 1개와 데이터 입력 3회가 늘었다. 새 untracked `assignments/05-time-series/시계열분석_풀이.ipynb`는 `test_1.npy`, `test_2.npy`, `bandwidth.csv`를 노트북 바로 옆에서 찾지만, 실제 tracked 파일은 각각 `data/npy/`와 `data/csv/` 아래에 있다.

## 현재 경로와 Private 복사본 권장 매핑

| 현재 경로 | Private 저장소 내부 권장 경로 | 현재 작업트리 처리 |
|---|---|---|
| `docs/book/**` | `docs/book/**` | 원본 유지, Private에 복사 |
| `docs/pdf/**` | `docs/pdf/**` | 원본 유지, Private에 복사 |
| `docs/zip/**` | `docs/zip/**` | 원본 유지, Private에 복사·LFS 적용 |
| `docs/image/**` | `docs/image/**` | 원본 유지, Private에 복사 |
| `learning/**/data/**` | `learning/**/data/**` | 원본 유지, Private에 복사 |
| `learning/**/image/**` | `learning/**/image/**` | 원본 유지, Private에 복사 |
| `learning/**/pdf/**` | `learning/**/pdf/**` | 원본 유지, Private에 복사 |
| `assignments/**/data/**` | `assignments/**/data/**` | 원본 유지, Private에 복사 |

Private 저장소 안에서도 현재 상대경로 구조를 그대로 보존하면 나중에 경로 표준화 또는 junction/submodule 검증을 하기 쉽다. 저장소를 즉시 `01/02/03` 세 개로 물리적으로 분리하면 인증·clone·LFS pull·동기화 지점도 세 배로 늘어나므로, 초기에는 단일 Private 저장소 내부 폴더 구분이 안전하다.

## 데이터 이동 시 예상 수정 부담

- 새 루트로 직접 이동: 최소 35개 노트북의 87개 경로 지점 검토가 필요하다.
- 공통 Python 경로 함수 도입: 데이터 입출력 75개 지점은 단계적으로 전환할 수 있지만 이미지 12개는 별도 수정이 필요하다.
- 기존 경로에 junction 또는 submodule을 배치: 노트북 수정은 줄지만 Windows junction 설정, Private 인증, 새 clone 초기화 스크립트가 필요하다.
- 단순 `sys.path` 또는 `PYTHONPATH` 변경: 데이터·이미지 파일 경로에는 효과가 없어 채택할 수 없다.

## 복사 후 smoke test 완료 조건

1. Phase 1 외부 백업에서는 `material-manifest.json`의 348개 항목이 파일 수·크기·SHA-256 기준으로 모두 일치한다.
2. Private 업로드에서는 cache·checkpoint·시크릿·개인정보 후보를 제외해 별도로 승인한 업로드 manifest와 clean clone이 exact 일치한다.
3. Git LFS 적용 파일을 새 clone에서 `git lfs pull`한 뒤 포인터만 남은 파일이 0개다.
4. 과정별 대표 노트북에서 첫 데이터 로딩과 이미지 렌더링이 성공한다.
5. 실패 시 현재 원본을 수정하지 않고 Private 복사본만 폐기할 수 있다.

## 현 단계 주의사항

- 100 MiB 초과 파일 3개는 일반 Git blob으로 올릴 수 없으므로 Git LFS가 필요하다.
- 현재 저장소에는 `.gitattributes`와 LFS 추적 파일이 없다.
- manifest에 포함된 notebook checkpoint 53개는 무손실 외부 백업에는 포함하지만 Private GitHub 업로드에서는 제외한다.
- 자료 이동·원본 삭제·submodule 전환은 별도 승인과 수업 중단 시점 확보 후 수행해야 한다.
