# 이미지·PDF·ZIP·CSV·데이터 자료 Inventory와 보존 정책 수정안

> 최신 기준은 2026-07-21 생성한 `material-manifest.json`이다. 아래 기존 표는 7월 20일 참고값이다.

## 2026-07-21 최신 요약

| Git 상태 | 파일 수 | 크기 |
|---|---:|---:|
| tracked | 263 | 30,487,473 B |
| untracked | 3 | 1,083,965 B |
| ignored | 82 | 1,094,191,421 B |
| 합계 | **348** | **1,125,762,859 B** |

- `material-manifest.json` SHA-256: `99ABEA79A9836AF81BB1B0B44BEF70DF85811B53FCBE962929A9676AB7081F47`
- 생성 전후 독립 SHA-256 재검증: 348/348 exact
- 100 MiB 초과: ZIP 1개, PDF 2개
- Private LFS 후보 확장자: 219개, 고유 객체 210개·1,088,997,479 B
- checkpoint 53개는 외부 백업 inventory에 보존하되 GitHub upload 대상에서는 제외

## 2026-07-20 참고 Inventory

## 현재 파일 분류

| 분류 | 파일 수 | 크기 | Git 상태 |
|---|---:|---:|---|
| Tracked notebook | 64 | 16,064,054 B | Git history 포함 |
| Tracked image | 6 | 1,281,060 B | Git history 포함 |
| Tracked 표형 데이터 | 167 | 7,471,612 B | Git history 포함 |
| 기타 tracked data 경로 파일 | 14 | 275,257 B | Git history 포함 |
| 현재 사용자 untracked image | 8 | 3,933,096 B | 원격 백업 미포함 |
| 현재 사용자 untracked notebook | 1 | 569,736 B | 원격 백업 미포함 |
| 현재 사용자 untracked CSV | 1 | 1,748 B | 원격 백업 미포함 |
| Ignore된 PDF | 24 | 572,915,883 B | 로컬 전용 |
| Ignore된 archive | 4 | 504,076,771 B | 로컬 전용 |
| Ignore된 notebook checkpoint | 51 | 14,063,156 B | 로컬 전용 |
| Ignore 전체 | 99 | 1,091,094,164 B(약 1.02 GiB) | 원격 백업 미포함 |

현재 reachable Git history의 최대 blob은 2,523,474 B이고 PDF·ZIP은 없습니다. 즉 교재 원본은 원격 저장소가 아니라 로컬 ignore 파일에만 있습니다.

## 일반 Git push가 불가능한 100 MiB 초과 파일

| 파일 | 크기 |
|---|---:|
| `docs/zip/AI퀀트과정_교재.zip` | 503,495,497 B / 480.17 MiB |
| `docs/book/.../07-3. 투자분석 기초 방법론(기본적 분석).pdf` | 225,432,665 B / 214.99 MiB |
| `docs/book/.../07-4. 투자분석 기초 방법론(기술적 분석).pdf` | 176,871,524 B / 168.68 MiB |

GitHub 일반 Git blob은 100 MiB를 초과하면 차단됩니다. 위 파일은 기술적으로 Git LFS가 필요합니다.

## 사용자 요구 반영 수정안

기존 명세의 “자료를 분리 대상에서 제외”를 다음처럼 수정 제안합니다.

1. 복습·교안 제작에 필요한 이미지·PDF·ZIP·CSV·데이터는 **삭제하거나 누락하지 않고 모두 보존 inventory에 포함**합니다.
2. 다만 “보존”과 “공개 GitHub 게시”는 분리합니다.
3. 직접 작성·재배포 허용 자료는 대상 저장소에 포함합니다.
4. 100 MiB 초과 binary와 반복 변경 가능 binary는 Git LFS 후보로 분류합니다.
5. 강의 PDF·ZIP·강사 원본·라이선스 불명확 이미지·유료/재배포 제한 데이터는 권리 확인 전 공개 저장소에 넣지 않습니다.
6. 권리가 확인되고 GitHub 업로드가 허용되면 **Private source vault 저장소 + Git LFS**를 우선 검토합니다.
7. `.env`, API 키, 개인정보는 “필요 자료”에 포함되더라도 GitHub 업로드 대상에서 영구 제외하고 별도 비밀 저장소를 사용합니다.

대상 Organization은 Free plan이며 현재 GitHub 문서 기준 Git LFS 무료 포함량은 storage 10 GiB, 월 bandwidth 10 GiB입니다. 현재 약 1.02 GiB는 기술적 용량 안에 있지만, 파일이 조금만 바뀌어도 전체 새 버전 크기가 누적되고 다운로드가 bandwidth를 사용합니다. 요금·budget·보관 기간을 승인해야 합니다.

## 현재 차단

- `AGENTS.md` §7과 실행 명세 §0·§17은 PDF·ZIP·교재 커밋을 금지합니다.
- 재배포 권리와 데이터 이용 약관이 확인되지 않았습니다.
- 3개 파일은 일반 Git 한도를 초과합니다.
- 현재 Mirror·Bundle에는 ignore 자료가 포함되지 않습니다.

따라서 이번 단계에서는 `.gitignore`, `AGENTS.md`, 저작권 정책을 변경하지 않았고 자료를 GitHub에 올리지 않았습니다. 정책 변경과 실제 업로드는 별도 Approval Gate로 둡니다.

## 실제 전송 전 필요한 로컬 보호

1. 사용자가 notebook 저장을 잠시 멈춤
2. 외부 새 경로에 working tree 전체 스냅샷 생성(`.git` 제외, `/MIR` 금지)
3. 복사 전후 파일 크기·mtime·SHA256 manifest 비교
4. 암호화·ACL과 백업 위치 확인
5. 그 뒤에만 working tree 정리·commit·전송 검토

## 공식 참고

- GitHub large file limits: https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
- Git LFS: https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage
- Git LFS billing: https://docs.github.com/en/billing/concepts/product-billing/git-lfs
