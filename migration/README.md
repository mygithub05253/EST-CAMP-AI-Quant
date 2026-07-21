# GitHub Organization 이관 작업

이 디렉터리는 `CODEX_GITHUB_ORG_MIGRATION_PLAN.md`의 **22. Codex 첫 실행 작업** 범위만 수행한 결과입니다.

## 현재 결론

- 전송 상태: **조건부 가능**
- 실제 Repository Transfer: 수행하지 않음
- Organization 설정 변경: 수행하지 않음
- 새 원격 저장소 생성: 수행하지 않음
- 로컬 remote 변경: 수행하지 않음
- force push·기록 재작성·기존 폴더 삭제: 수행하지 않음
- 현재 수업 파일: 수정·stage·commit·checkout·pull하지 않음

## 주요 산출물

- `reports/execution-summary.md`: 첫 실행 최종 보고
- `reports/pre-transfer-inventory.md`: 저장소·Organization·GitHub 자산 inventory
- `reports/owner-reference-inventory.md`: 소유자 URL·절대 경로 검색
- `reports/material-inventory.md`: 이미지·PDF·ZIP·CSV 등 자료 inventory와 보존 정책 수정안
- `reports/risk-and-blockers.md`: 차단 요소와 위험
- `reports/planned-transfer-commands.md`: 승인 후 실제 실행 예정 명령
- `scripts/collect_inventory.ps1`: 읽기 전용 inventory 수집
- `scripts/create_backup.ps1`: 외부 Mirror·Bundle 불변 백업 및 복원 검증
- `scripts/validate_transfer.ps1`: 이관 전·후 검증

## 백업 경계

검증 완료된 Mirror·Bundle은 원격 Git ref와 객체를 보존합니다. 현재 미커밋·미추적·ignore 파일, 로컬 전용 branch, stash, linked worktree 상태는 포함하지 않습니다. 이 항목은 실제 전송 전 별도 외부 스냅샷과 로컬 ref 백업이 필요합니다.

## 다음 단계

`reports/execution-summary.md`와 `reports/risk-and-blockers.md`를 검토한 뒤 사용자 승인을 기다립니다. 승인 전에는 전송 명령을 실행하지 않습니다.

## 참고

- GitHub Repository Transfer: https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository
- Git repository limits: https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits
- Git LFS billing: https://docs.github.com/en/billing/concepts/product-billing/git-lfs
- Git bundle: https://git-scm.com/docs/git-bundle

