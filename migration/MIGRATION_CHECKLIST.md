# GitHub Organization 이관 체크리스트

기준일: 2026-07-20 KST

## 첫 실행 범위

- [x] 원본 저장소 Admin 권한 확인
- [x] 대상 Organization membership·owner 권한 확인
- [x] 대상 Organization 저장소 생성 가능 여부 확인
- [x] 동일 이름 저장소·관찰 가능한 fork 충돌 확인
- [x] working tree·remote·HEAD 조사
- [x] 저장소 메타데이터와 GitHub 자산 inventory 생성
- [x] owner URL·절대 경로 검색
- [x] Mirror·Bundle 백업 생성
- [x] Mirror fsck·Bundle verify·복원 clone·ref exact·SHA256 검증
- [x] 이관 전·후 검증 스크립트 작성 및 시험
- [x] 차단 요소·위험·실행 예정 명령 보고
- [ ] `admin:org` scope로 Organization Actions 정책·Rulesets 재조회
- [ ] `read:project` scope로 Projects v2 자산 재조회
- [ ] 수업 저장을 잠시 멈춘 일관된 working tree·ignore 자료 외부 스냅샷
- [ ] 로컬 전용 branch·stash·linked worktree ref 백업
- [ ] 모든 required check 통과
- [ ] 사용자 Repository Transfer 명시 승인

## Approval Gate 2 상태

- 원격 Git Mirror·Bundle 백업: 통과
- 전체 로컬 자료 무손실 백업: 미완료
- 이관 전 검증: `working tree clean` 실패
- 결론: 실제 Transfer 실행 금지

## 금지 상태 유지

- [x] Transfer 미실행
- [x] Organization 설정 미변경
- [x] 새 원격 저장소 미생성
- [x] force push 미실행
- [x] 기록 재작성 미실행
- [x] 기존 폴더 삭제·이동 미실행
- [x] remote URL 미변경

