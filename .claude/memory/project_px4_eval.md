---
name: px4
description: "ArduPilot→PX4 교체 가능성 심층분석(2026-05-27) — 보류 결정, ArduPilot 잔류. macOS 제약과 병행 토글 경로 정리"
metadata: 
  node_type: memory
  type: project
  originSessionId: 03c0a2c3-833a-4acc-8495-5dc21ccbaccf
---

2026-05-27 ArduPilot→PX4 교체 가능성을 5개 에이전트(구조분석/macOS가능성/거리센서·모델·회피/설계/비판검토)로 심층분석. **결론: 보류, ArduPilot 잔류.**

## 사용자 진짜 동기
"둘 다 테스트해야 함" — 전면 교체가 아니라 **ArduPilot ↔ PX4 펌웨어 토글 환경**을 원함. (switch_rangefinders.sh의 펌웨어 버전 개념)

## 핵심 기술 사실 (다음에 또 물으면 재분석 불필요)

1. **macOS ARM 네이티브 PX4 풀스택 = 사실상 불가**
   - PX4 SITL 빌드는 됨(clang, ulimit -n 2048). 하지만 gz Harmonic GUI가 macOS 불안정(공식), Homebrew gz Apple Silicon 미문서화, protobuf/boost ABI 충돌(이 머신서 ArduPilot 때 이미 겪음), **ROS2 Humble+uXRCE-DDS는 Ubuntu 22.04 전용**
   - → PX4는 **저쪽 Ubuntu(현재 .32)에서만** 현실적. 이 Mac은 GCS/RViz/ROS2 구독만

2. **"MAVProxy 자리에 PX4 SITL 바꿔치기"는 불가** — 펌웨어가 한 세트로 전환됨:
   - ArduPilot: 외부 ardupilot_gazebo 플러그인(ArduPilotPlugin, UDP JSON FDM, control채널 모터) + micro_ros_agent(/ap/*) + MAVProxy
   - PX4: 펌웨어 내장 GZBridge가 gz transport 직접 구독 + gz-sim-multicopter-motor-model + uXRCE-DDS Agent(/fmu/*) + QGroundControl(MAVProxy 미사용)
   - 모델도 iris(ArduPilot 종속) → x500(PX4) 교체 필요

3. **재사용 가능(펌웨어 중립):** world SDF, gpu_lidar 센서 SDF 블록(rangefinders_link), ros_gz_bridge yaml의 range/* 항목, cyclonedds 일반 설정, gps_umd/ros_gz/sdformat_urdf
   - **폐기:** src/ardupilot, ardupilot_gazebo(ArduPilotPlugin), ardupilot_gz(launch), parm(RNGFND/PRX/AVOID), micro_ros_agent
   - 단, DDS fragmentation/sysctl/QoS 튜닝 자산은 uXRCE-DDS에서 재검증 필요(그대로 못 옮김)

4. **PX4 거리센서/회피:** 공식 `gz_x500_lidar_2d/front/down` 예제 보유 → GZBridge가 LaserScan 직접 소비(36섹터 obstacle_distance). 우리 3×single-ray보다 270° 2D 1개 통합이 PX4 관용. 회피는 CP_DIST(≈ArduPilot AVOID, 정지/감속, Position 모드 한정). **PX4-Avoidance(3DVFH* 경로재계획)는 2024-08 아카이브 → PX4 ROS2 회피 생태계 오히려 약화**

## 권고 (검토 에이전트 + 합의)
전면 교체 ❌. **저쪽 Ubuntu에서 PX4 공식 예제(`make px4_sitl gz_x500_lidar_2d`)를 이식 없이 PoC로 먼저 띄워 실익 증명 → 그 뒤에만 firmware:=apm|px4 토글 launch 설계.**

Go/No-Go 기본값: "PX4로 풀려는 문제를 한 문장으로 못 쓰면 PoC까지만."

## 현재 상태
사용자 결정: **"일단 ArduPilot에 집중"** — PX4 보류. 거리센서 검증/회피 등 ArduPilot 작업 우선.

관련: [[distance-sensors 구현 상태]] [[switch-variants 백업 패턴]] [[ardu_ws 프로젝트 상태]]
