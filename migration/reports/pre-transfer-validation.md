# 이관 전 검증

- 검증 시각(KST): 2026-07-20T12:56:07.2216677+09:00
- 원격 변경: 수행하지 않음

| 검증 항목 | 상태 | 필수 | 기대값 | 실제값 | 비고 |
|---|---|---:|---|---|---|
| Repository ID | PASS | True | 1270665344 | 1270665344 |  |
| 원본 Admin 권한 | PASS | True | true | True |  |
| 백업 HEAD SHA | PASS | True | e04abb769740c3d0057aac4e6baef022c503930b | e04abb769740c3d0057aac4e6baef022c503930b |  |
| Mirror·Bundle 복원 무결성 | PASS | True | fsck/verify/ref exact/hash 성공 | 성공 |  |
| 현재 working tree clean | FAIL | True | clean | dirty | dirty 파일 본문은 보고서에 저장하지 않음 |
| 대상 Organization owner 권한 | PASS | True | active/admin | active/admin |  |
| 대상 저장소 이름 충돌 | PASS | True | 동일 이름 저장소 없음 | 직접 조회 404 | Organization owner 권한과 함께 판정 |

- 필수 실패: 1
- 필수 미확인: 0
