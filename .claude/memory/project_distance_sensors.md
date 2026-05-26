---
name: distance-sensors
description: "iris 드론에 전/좌/우 distance sensor 3개 추가 — ardupilot_gazebo 직결(SITL JSON rng_N) 경로로 구현 완료, switch 스크립트로 토글 가능"
metadata: 
  node_type: memory
  type: project
  originSessionId: 03c0a2c3-833a-4acc-8495-5dc21ccbaccf
---

2026-05-22 구현 완료. ArduCopter SITL + Gazebo Harmonic + ROS2 Humble 환경에서 iris 드론에 전방/좌측/우측 single-ray gpu_lidar 3개를 추가하고, ardupilot_gazebo 플러그인의 RangeSensor 후크를 통해 ArduPilot RNGFND1~3로 직결.

## 데이터 흐름 (검증 완료)

```
Gazebo gpu_lidar → /range/{front,left,right} (gz.msgs.LaserScan)
  ↓ ardupilot_gazebo Plugin RangeCb (ranges[i-1] = sample_min)
  ↓ SITL JSON FDM: "rng_1/2/3" key
ArduPilot SIM_JSON.h:125-130 → state.rng[0..2]
  → SIM_JSON.cpp:348 rangefinder_m[i]
  → AP_RangeFinder Type::SIM(=100) → RNGFND1/2/3
```

ros_gz_bridge로 ROS2 토픽 `/range/{front,left,right}` (sensor_msgs/LaserScan)도 노출됨 — 외부(저쪽 Ubuntu 등)에서 구독 가능.

## 핵심 파라미터 (mav.parm 적용 확인)

- RNGFND1_TYPE=100 ORIENT=0 (Forward), MIN=0.10, MAX=20.0
- RNGFND2_TYPE=100 ORIENT=6 (Left/Yaw270)
- RNGFND3_TYPE=100 ORIENT=2 (Right/Yaw90)
- PRX1_TYPE=4 (RangeFinder backend — 8 sector proximity 자동 합성)
- AVOID_ENABLE=7, AVOID_MARGIN=2.0, AVOID_DIST_MAX=5

## switch 스크립트 (백업/토글)

`/Users/swjo/yonsei-ai/aerion/ardu_ws/switch_rangefinders.sh on|off|status`

6개 파일을 한 번에 swap (src + install 양쪽):
1. `models/iris_with_gimbal/model.sdf` — gpu_lidar 3개 + ArduPilotPlugin sensor 등록
2. `config/gazebo-iris-gimbal.parm` — RNGFND/PRX/AVOID 파라미터
3. `config/iris_bridge.yaml` — ros_gz_bridge LaserScan 3개 매핑

각 파일별로 `.baseline` / `.rangefinders` 두 변형 영구 보관 → 언제든지 ON/OFF.

## 적용 시 주의

- **eeprom.bin 삭제 필요** (parm 새로 로드시키려고). 백업: `eeprom.bin.before_rangefinders`. SITL이 eeprom 우선 → 새 RNGFND 파라미터 무시될 수 있음
- 토글 후 반드시 `bash stop_sim.sh && bash start_sim.sh` 재시작
- `ardupilot_gazebo` 플러그인 자체에 LoadRangeSensors()/RangeCb() 구현 있음 (line 286, 879, 962, 1941-1957) — JSON 키 rng_1~6 매핑

## 검증 명령

```bash
# Gazebo 측
gz topic -e -t /range/front -n 1 | grep ranges:
# ArduPilot 측 (mav.parm dump 확인)
grep -E "^RNGFND[123]_TYPE\b|^PRX1_TYPE\b" mav.parm
# ros2 측
ros2 topic echo /range/front --once | grep -A 1 "^ranges:"
# 플러그인 인식 확인 (sim_start.log)
grep "subscribing to /range" /tmp/sim_start.log
```

## 펌웨어 회피 알고리즘 활성 상태

**자동 동작 (별도 코드 불필요):**
- Loiter / AltHold / GUIDED 모드에서 Simple Avoidance ON
- 장애물 `AVOID_MARGIN`(=2m) 이내 진입 시 자동 정지/감속 (AVOID_BEHAVE: 0=Slide, 1=Stop)
- ROS2/MAVLink velocity command도 회피로 보호됨
- 데이터 흐름: Gazebo gpu_lidar → fdm rng_N → AP_RangeFinder → AP_Proximity (8-sector) → AC_Avoidance

**미활성 (필요 시 추가 설정):**
- `OA_TYPE 1` (BendyRuler) / `OA_TYPE 2` (Dijkstra) 미설정 → AUTO 미션에서 우회 경로 자동 계획 안 함, 단순 정지만
- `AVOID_BEHAVE` 명시 안 함 → 기본값 0 (Slide). Stop 원하면 1로

## 잔여 작업

- [ ] **장애물 spawn 검증** — iris 정면(+Y world, yaw=92°)에 박스 spawn → /range/front 값 확인. iris world pose: x=-2.42, y=70.95, z=0.195, world="map"
- [ ] 회피 동작 실제 비행 검증 (GUIDED 이륙 → 벽 접근 → AVOID_MARGIN=2m 정지)
- [ ] AVOID_ENABLE=7이 모드변경 지연 원인인지 격리 확인 (의심 후보)
- [ ] OA_TYPE 활성화 여부 결정 (path planning이 필요한 use case인지)

## 부수 발견 (rangefinders와 무관)

- `libGstCameraPlugin.dylib` 로드 실패: OpenMP `__tgt_omp_free` 심볼 누락. GStreamer 카메라 스트림 미사용시 무시 가능. 메인 카메라(`/camera/image`)는 정상.

**Why:** ArduPilot 자체 proximity/avoidance에 거리값 입력 + 외부 ROS2 알고리즘(저쪽 Ubuntu)에 거리값 노출, 두 목표 동시 달성.
**How to apply:** 새 세션에서 거리센서 활성화 시 `switch_rangefinders.sh on` → eeprom 백업 후 삭제(필요시) → 재시작.

관련: [[ardu_ws 프로젝트 상태]] [[switch-variants 백업 패턴]]
