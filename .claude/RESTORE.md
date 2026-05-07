# 다른 머신에서 메모리 복원

이 디렉토리(`.claude/memory/`)는 사용자 글로벌 Claude 메모리의 사본. 다른 머신에서
이 repo를 clone한 뒤 동일한 세션 기억을 이어받으려면 두 가지 방법이 있음.

## 방법 1: CLAUDE.md만 활용 (간단, 권장)

`ardu_ws/CLAUDE.md`는 Claude Code가 작업 디렉토리에서 자동 로드함.
**아무 설정 없이 ardu_ws에서 Claude를 띄우면 핵심 컨텍스트가 이미 주입됨.**
대부분의 경우 이걸로 충분.

## 방법 2: 글로벌 메모리 시스템으로 복원

Claude의 "memory" 시스템 자체로 복원하려면 사용자 디렉토리로 복사:

```bash
# 매핑되는 글로벌 메모리 경로 (호스트 사용자명에 맞게 수정)
TARGET="$HOME/.claude/projects/-Users-$USER-yonsei-ai-aerion/memory"
mkdir -p "$TARGET"
cp .claude/memory/*.md "$TARGET/"
```

**주의:** 글로벌 메모리 경로는 워크스페이스 절대경로를 인코딩해서 만들어짐
(`/Users/swjo/yonsei-ai/aerion` → `-Users-swjo-yonsei-ai-aerion`).
사용자명/경로가 다르면 폴더 이름도 달라지므로 위 `$USER` 치환만으로 안 맞을 수 있음.
실제 경로는 Claude Code 첫 실행 시 자동 생성되니, 한번 띄운 뒤 그 경로를 확인하는 게 확실함.

## 메모리 ↔ repo 동기화 정책

- 글로벌 메모리(`~/.claude/.../memory/`)가 **원본(source of truth)**.
- `.claude/memory/`는 git tracking용 사본 — 의미 있는 변화 발생 시 commit해서 다른 머신과 공유.
- IP 같은 매일 변동 정보는 commit 가치 없음. 워크플로우/구조/트러블슈팅처럼 재발 시 다시 알아내야
  하는 정보만 commit.

## 파일 구조

```
.claude/
├── RESTORE.md                       # 이 파일
└── memory/
    ├── MEMORY.md                    # 인덱스
    ├── project_ardu_ws.md           # 프로젝트 현황 (project memory)
    ├── feedback_build.md            # 빌드 패치 노하우 (feedback memory)
    └── feedback_dds_large_msg.md    # 대형 토픽 전송 진단 (feedback memory)
```
