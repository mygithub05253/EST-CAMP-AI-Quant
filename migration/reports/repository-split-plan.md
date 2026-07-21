# 저장소 분리 수정안

이번 세션에서는 저장소를 분리하거나 새 원격을 만들지 않았습니다.

## Stage A: Organization Transfer

1차 Native Transfer는 현재 실제 폴더를 그대로 유지할 수 있습니다. 전송 후 검증이 끝난 다음 로컬 `.git`의 `origin` URL만 새 소유자 경로로 변경합니다.

```text
C:\Users\kik32\workspace\EST-Camp-AI-Quant
└── 기존 working tree 유지
    └── .git/config의 origin만 승인 후 변경
```

## Stage C: 여러 독립 Repository로 분리

여러 독립 저장소는 하나의 `.git` remote URL만 바꾸는 것으로 만들 수 없습니다. 저장소마다 독립 Git metadata가 필요합니다.

| 방식 | 같은 최상위 폴더 유지 | 독립 history | 판단 |
|---|---:|---:|---|
| 기존 모노레포 + 여러 remote | 예 | 아니요 | 저장소 분리가 아님 |
| 기존 경로를 submodule로 전환 | 예 | 예 | 권장 후보 |
| parent에서 ignore한 nested repo | 예 | 예 | Git 도구 혼동 위험, 비권장 |
| workspace의 sibling clone | 아니요 | 예 | 사용자가 원하지 않음 |

사용자 요구를 가장 가깝게 만족하는 후보는 기존 루트를 `bootcamp-hub`로 유지하고 `learning/`, `assignments/`, 각 `projects/.../`를 해당 신규 저장소의 submodule working tree로 두는 방식입니다. 각 하위 경로에는 독립 `.git` 파일이 생기며 실제 자료는 지금 최상위 폴더 안에 계속 보입니다.

단, submodule 전환은 parent index에서 기존 tracked 파일을 gitlink로 바꾸는 대규모 변경입니다. 새 저장소 생성·history 검증·파일 해시 비교가 끝난 뒤 별도 승인과 PR로만 수행해야 합니다.

## 자료 보존 반영

- 이미지·CSV·notebook: 권리·민감도·크기 검사 후 해당 저장소에 포함
- PDF·ZIP·강의 원본: 누락·삭제하지 않고 source inventory에 유지
- 업로드 허용 자료 중 large binary: Private Git LFS 후보
- 공개 금지 또는 cloud 업로드 금지 자료: 암호화된 로컬/승인 저장소와 hash manifest로 참조
- 시크릿·개인정보: GitHub 업로드 금지

## Approval Gate 5에서 결정할 항목

1. submodule 방식 승인 여부
2. 원본 자료를 저장할 Private source vault 저장소 허용 여부
3. Git LFS budget·보관 정책
4. 파일군별 재배포 권리
5. 기존 모노레포와 신규 저장소 병행 기간
6. parent에서 기존 tracked 폴더를 gitlink로 바꾸는 시점

