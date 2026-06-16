# Notion 연동 설정 (til-record / bootcamp-worklog 공용)

> ⚠️ 이 파일은 노션 연동에 필요한 **링크·ID만** 적습니다. 토큰·시크릿은 적지 않습니다.

## 연결 상태
- [ ] TIL 개인 공간 페이지에 Notion MCP integration 커넥션 연결 완료
- [ ] TIL 데이터베이스 URL/ID 확인 완료

## 설정값 (확보 후 채우기)
| 항목 | 값 | 비고 |
|------|----|----|
| TIL 개인 공간 페이지 URL | `(미설정)` | 본인 개인 공간 |
| TIL 데이터베이스 URL/ID | `(미설정)` | `notion-create-pages`의 parent |
| 데이터 소스(collection) URL | `(미설정)` | `notion-fetch`로 DB 조회 시 표시 |

## 캠프 양식 참고
- 샘플 페이지: `(Sample) 홍길동 (1)` (TIL 개인 공간 내)
- 공개 캠프 홈: https://oreumi.notion.site/4-AI-35febaa8982b80e2b5c5d3cd155162e2
- TIL DB 컬럼: `날짜`(Date) · `Subject`(Select) · `title`(Title) · `피드백 요청`(Checkbox) · `멘토 피드백`(Text)

## 메모
- 게스트 권한으로 커넥션 연결이 막히면 운영진에 integration 연결 허용 요청.
- DB 스키마(컬럼)는 운영진이 바꿀 수 있으니, 기록 전 `notion-fetch`로 현재 스키마를 먼저 확인한다.
