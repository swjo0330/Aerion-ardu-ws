---
name: ros2-daemon
description: ros2 topic list가 로컬에서 토픽을 못 보거나 멈추면 → 묵은 ros2 daemon 캐시 의심 (--no-daemon으로 우회)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 88bfe48f-e1c5-41f1-9306-b7b8fbecf1fc
---

`ardu_ws`에서 로컬 `ros2 topic list`에 `/range/*` 등 토픽이 안 보이거나 명령이 멈출 때(2026-05-29 발생), 거의 항상 **오래 살아남은 좀비 `ros2 daemon` 프로세스가 stale 디스커버리 캐시를 물고 있는 것**이 원인이다. `ros2 daemon stop`이 이 좀비를 못 죽이는 경우도 있다(며칠 전 떠 있던 PID가 그대로 생존).

**진단/처리 순서:**
1. `ps aux | grep ros2cli.daemon` — 오래된 데몬 PID 확인 (시작 시각이 며칠 전이면 의심)
2. `pkill -9 -f "ros2cli.daemon|_ros2_daemon"` 로 강제 종료
3. 조회는 `ros2 topic list --no-daemon`, `ros2 topic echo <t> --once --no-daemon` 으로 — 매 호출 fresh 디스커버리라 좀비 데몬 무관

**핵심 감별:** 다른 컴(저쪽 Ubuntu)에서는 토픽이 잘 보이는데 **로컬에서만** 안 보이면 → 센서/네트워크/DDS 문제가 아니라 로컬 ros2 도구(데몬) 문제다. 외부에서 동작이 확인되면 로컬 검증 실패는 **로컬 환경/도구부터** 의심할 것.

**추가 함정 (2026-06-01): macOS에 `timeout` 명령 없음.** `timeout 12 ros2 topic echo ...` 류가 전부 exit 127(command not found)로 **빈 출력** → 이걸 토픽 미발행/디스커버리 문제로 오진하기 쉬움. 검증이 빈 출력이면 먼저 `which timeout` 확인. 대안: `timeout` 빼고 자체 타이머가 있는 rclpy 구독 스크립트(`spin_once` + `time.time()` 루프)로 1회 수신해 검증하는 게 가장 확실(CLI 디스커버리 변동 무관). LaserScan 부채꼴 검증도 이 방식으로 성공.

**Why:** 작동 중인 시스템을 "고장났다"고 단정하고 `start_sim.sh`/`cyclonedds.xml` 같은 정상 설정을 성급히 바꾸려다 사용자 제지를 받았음. 외부 동작 확인 = 코어 정상 신호. CLI 빈 출력 ≠ 시스템 고장 (timeout 부재/좀비 데몬부터 의심).
**How to apply:** 로컬 ros2 토픽 미표시/멈춤 → 먼저 `--no-daemon` + 좀비 데몬 kill. 설정 변경은 그 다음.

관련: [[distance-sensors 구현 상태]] [[ardu_ws 프로젝트 상태]]
