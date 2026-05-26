---
name: switch-variants
description: "설정 파일을 `.baseline` / `.rangefinders` 등 변형 사본으로 영구 보관하고 활성 파일을 cp swap으로 토글하는 패턴 — 사용자가 명시적으로 요청한 방식"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 03c0a2c3-833a-4acc-8495-5dc21ccbaccf
---

설정 파일 변형을 swap하는 토글 스크립트 패턴. 사용자가 명시적으로 "백업파일은 유지 잘하고 스위칭"이라 요청한 디자인.

**구조:**
```
config_file              ← 활성 (런타임이 읽음)
config_file.baseline     ← 원본 영구 백업
config_file.<variant>    ← 변형 영구 보관 (rangefinders, fire_world 등)
```

활성 파일은 `.baseline` 또는 `.variant`의 단순 복사본. 스위치 스크립트는 cp swap만 수행.

**Why:** 사용자가 자주 토글하고 싶어함. 원본을 보존하면서 한 명령으로 ON/OFF. PR/git 없이 빠르게 실험. 비파괴적 — 잘못돼도 `.baseline` 그대로 보존.

**How to apply:**
- ardu_ws 같이 src/install 두 트리가 있으면 FILES 배열에 양쪽 모두 포함 (6개 파일 → 3쌍 동시 swap)
- 스크립트는 status/on/off 3개 서브커맨드 표준화
- status는 cmp -s로 활성 파일이 어느 변형과 같은지 식별 → drift 감지 ("UNKNOWN" 표시)
- on/off 후 사용자가 즉시 재시작할 수 있게 "Restart sim: ..." 명령 echo
- 새 변형 추가 시 `.variant` 사본 만들고 FILES 배열에 같은 패턴으로 추가

**참고 예시:** `/Users/swjo/yonsei-ai/aerion/ardu_ws/switch_rangefinders.sh` — distance sensor 3개 토글, 6개 파일 일괄 swap.

**대안 검토 결과 비기각:**
- 별도 모델 디렉토리 (iris_with_gimbal_rangefinders/): 격리는 좋지만 launch에서 모델 선택 logic 필요 → 더 복잡
- git branch 전환: 시뮬 작업 흐름에 안 맞음 (uncommitted 상태 자주)
- 단순 timestamp 백업 (`*.bak.20260522`): 토글 어려움
→ "변형 사본 + cp swap" 패턴이 사용자 워크플로우에 가장 적합

관련: [[distance-sensors 구현 상태]]
