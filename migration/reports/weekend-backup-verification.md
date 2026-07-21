# 주말 신규 백업 검증

- 상태: **PASS — Phase 1 현재 상태 완전 외부 백업**
- 완료 시각(KST): 2026-07-21T11:13:32.7707391+09:00
- 백업 세트: `C:\Users\kik32\Backups\EST-CAMP-AI-Quant-Migration\before-transfer-20260721-111152-14277f98fb22`
- 현재 branch / HEAD: `main` / `14277f98fb221a7dd1740ca9975ea866e3692ecf`
- origin/main / live main: `14277f98fb221a7dd1740ca9975ea866e3692ecf` / `14277f98fb221a7dd1740ca9975ea866e3692ecf`
- manifest SHA-256: `992eeb909adb0336165c0798f00a447d1b117a9d200da747e9db2501e000575c`
- SHA256SUMS SHA-256: `59f054e527e29f92014dd767fbe9c4aea1d4745bbf62d73b9be1e197903174d8`
- remote bundle SHA-256: `e8b12121c41d71fc6434e524d85d02f7c4eb27fc19bac37992b27cf0d4c7c9d2`
- local bundle SHA-256: `e40dbbdf841af5b12a9ce6bbc242e00d3c58ae408e46d1786e76a88e895491cd`

## Git 백업

| 항목 | 결과 |
|---|---|
| Remote 전체 광고 ref | 37개 (branch 8, tag 0, pull ref 29) |
| Remote mirror fsck / bundle verify / restore fsck | PASS / PASS / PASS |
| Local ref | 21개 (branch 11, remote-tracking 9, stash 1, refs/codex 0) |
| Local exact mirror / raw .git snapshot / bundle restore | PASS / PASS / PASS |
| Bundle 비호환 non-commit ref | 0개 — exact local mirror와 raw .git snapshot에 보존 |

## Working tree와 자료

| 항목 | 결과 |
|---|---|
| Worktree | 4개, 각 HEAD/index/status/snapshot 보존 |
| source-before → snapshot | missing 0 / extra 0 / size mismatch 0 / hash mismatch 0 |
| non-migration 기준선 | 904개 / 1163153821 B / `257dbd1b2668ea427fb5d8fc6033e5b6225d2bf5228b92770418af19bd3745fc` |
| 첫 측정 → 백업 종료 | exact PASS |
| cache·ignored·checkpoint | 포함 |
| working snapshot 제외 | `.git`; active root 안 linked worktree 중복(각각 별도 snapshot) |
| reparse point / 시크릿 파일명 후보 | 0 / 0 |

## Git LFS

- Local pointer/object: 0 / 0
- Remote pointer/object: 0 / 0
- 0개인 object store도 별도 빈 구조와 manifest로 검증했다.

## 범위 준수

- 활성 저장소의 pull/fetch/checkout/switch/branch/stash/commit/push: 수행하지 않음
- Repository Transfer·새 GitHub 저장소·LFS upload·remote 변경: 수행하지 않음
- 기존 백업·partial·원본 파일 삭제/덮어쓰기: 수행하지 않음
- copy-only source snapshot: PASS

> Phase 1 PASS 후 자동 진행하지 않는다. Repository Transfer와 Private 저장소/LFS 단계는 여전히 미승인이다.
