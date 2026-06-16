---
name: github-flow
description: EST-Camp-AI-Quant의 GitHub 협업 플로우(pull → branch → commit → push → PR → merge)를 일관되게 수행한다. 사용자가 "이거 깃허브에 올려/PR 만들어/머지해/작업 시작" 하거나, 코드·문서 변경을 원격에 반영해야 할 때 사용한다.
---

# GitHub 협업 플로우 스킬

규칙 원천은 루트 `AGENTS.md`의 "GitHub 협업 규칙"이다. 이 스킬은 그 흐름을 단계별 명령으로 정리한다.

## 작업 시작 (작업 전)
```powershell
git switch main
git pull --ff-only                       # 항상 최신화
git switch -c <type>/<short-description>  # 새 브랜치 생성
```
- 브랜치 `type`: `feat` · `fix` · `docs` · `chore` · `study` · `assignment`
- 예: `study/04-time-series`, `assignment/02-backtest`, `feat/skill-xxx`

## 작업 후 (반영)
```powershell
git add <변경파일>
git commit -m "<type>: 한국어 요약"      # Conventional Commits + 한국어
git push -u origin <브랜치명>
```
커밋 푸터에 다음을 붙인다:
```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## PR 생성 → 머지
```powershell
gh pr create --base main --head <브랜치명> --title "<type>: 제목" --body "<본문>"
gh pr merge <번호> --merge --delete-branch
git switch main; git pull --ff-only       # 로컬 동기화
```
- PR 본문 끝에 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- GitHub MCP가 연결돼 있으면 PR 생성·머지에 MCP를 우선 활용해도 된다.

## 체크리스트
- [ ] 작업 전 `git pull` 했는가
- [ ] 새 브랜치에서 작업 중인가 (main 직접 작업 금지)
- [ ] 커밋 메시지가 `type: 한국어` 형식인가
- [ ] 교재·시크릿·데이터 원본이 스테이징에 없는가 (`git status` 확인)
- [ ] 머지 후 main을 pull로 동기화했는가

## 주의
- 최초 레포 세팅만 main 직커밋이 허용됐다. 이후 모든 작업은 브랜치→PR.
- 파괴적 명령(force push, reset --hard)은 사용자 확인 후에만.
- push 전 항상 `git status --short`로 의도치 않은 파일 포함 여부 확인.
