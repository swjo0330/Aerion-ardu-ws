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

`/Users/swjo/yonsei-ai/aerion/ardu_ws/switch_rangefinders.sh on|fan|off|status`

6개 파일을 한 번에 swap (src + install 양쪽):
1. `models/iris_with_gimbal/model.sdf` — gpu_lidar + ArduPilotPlugin sensor 등록
2. `config/gazebo-iris-gimbal.parm` — RNGFND/PRX/AVOID 파라미터
3. `config/iris_bridge.yaml` — ros_gz_bridge LaserScan 매핑

각 파일별로 `.baseline` / `.rangefinders` / `.front_fan` 세 변형 영구 보관.

## 변형(variant) 종류 — (switch_rangefinders.sh: on|fan|fan3d|fan3d_down|fan3d_av|single|off)

7개 변형. 각 파일별 `.baseline`/`.rangefinders`/`.front_fan`/`.fan3d`/`.fan3d_down`/`.fan3d_av`/`.front_single` 사본 영구 보관(src+install 6파일 swap). front_fan/fan3d/front_single은 2026-06-01, fan3d_down/fan3d_av는 2026-06-02 추가.

**⚠️ 핵심 교훈 (2026-06-08): RNGFND→MAVLink DISTANCE_SENSOR(id=10)가 저쪽 mavros를 SIGBUS 크래시시킴.** SITL 직접 측정으로 확정: ArduPilot은 RNGFND1(전방)에 대해 `DISTANCE_SENSOR id=10 orient=0`을 보냄. 저쪽 mavros C++ distance_sensor 플러그인이 매핑 안 된 id=10에서 죽음(mavros 견고성 버그). **이 id=10은 RNGFND1(fan3d_av의 수평 회피센서)에서 나오는 것이지, 3D PointCloud FOV 변경과 무관** — PointCloud2는 MAVLink로 안 나가므로 FOV가 새 sensor_id를 만들 수 없음(저쪽이 반복해서 FOV 탓했으나 오진). SITL COMMAND_ACK는 정상(result=0) → GUIDED ACK 실패도 SITL 아닌 mavros 쪽. **해결: 회피가 offboard면 fan3d_down(RNGFND off→DISTANCE_SENSOR 미발신)으로 크래시 트리거 원천 제거. 펌웨어 회피 원하면 저쪽이 mavros에 id=10 매핑/패치.** SITL 직접 검증: tcp:127.0.0.1:5763 + pymavlink로 DISTANCE_SENSOR/COMMAND_ACK 확인 가능.

**⚠️ 핵심 교훈 (2026-06-02): 하향 넓은 3D lidar를 ArduPilot proximity(RNGFND/PRX)에 먹이면 안 됨.** -40° 하향 빔이 지상 대기 시 발밑 지면(0.30m)을 봐서 `PreArm: Proximity 0 deg, 0.30m (want > 0.6m)` 차단. ArduPilot proximity/avoidance는 수평면(2D) 개념이라 하향 cone과 미스매치. → 반응제어가 필요하면 **별도 수평 센서**를 RNGFND에 등록(fan3d_av), 3D 센서는 RNGFND 미등록(인지 전용).

- **off (.baseline)**: 거리센서 없음 (원본 iris_with_gimbal)
- **on (.rangefinders)**: 전/좌/우 single-ray 3개 → RNGFND1(F)/2(L,ORIENT6)/3(R,ORIENT2). 좌=270°/-90°, 우=+90° (ArduPilot 시계+ 기준)
- **fan (.front_fan)**: **전방 단일 ±45° 수평 부채꼴 1개**. `rangefinder_front` gpu_lidar `samples=91 min_angle=-0.7854 max_angle=0.7854`(1.0° 간격), vertical samples=1(수평면만). RNGFND1만(ORIENT 0). `/range/front`(LaserScan 91점). YOLO 베어링별 거리 매칭 가능(2D 수평).
- **fan3d (.fan3d) ← 2026-06-01 현재 활성, points-only 최종**: **전방 3D**. 수평 ±45°(91) × **수직 ±15°(16층, 2.0°)** = 91×16=1456 ray. `vertical samples=16 min=-0.2618 max=0.2618`.
  - **ROS2는 `/range/front/points`(PointCloud2, gz.msgs.PointCloudPacked, 1456점)만 발행.** 필드 x,y,z,intensity,**ring**(층0=-15°~층15=+15°). 사용자가 "3D로 통일" 결정 → LaserScan 브리지 제거(중간에 두 토픽 다 발행도 검증해봤고 LaserScan은 수평층 91점 깨끗하게 나왔으나, 최종은 points-only).
  - 검증 ✅: 1456점, H-45~+45°/V-15~+15°, el0°층 정면 3.272m, 하향층이 지면/낮은 물체 잡음(el-15°→0.74m).
  - **⚠️ 하향 ring은 지면(활주로)도 잡음** → 저쪽 PointCloud 처리 시 "전체 cone 최근접"을 그냥 쓰면 nearest가 지면(~0.7m)이 됨. 장애물만 원하면 지면 필터 필수: 수평대역(|el|작게)만 nearest로, 또는 평지 예상 슬랜트거리 `h_AGL/sin(|el|)`보다 확연히 가까운 점만 장애물로 판정.
  - RNGFND1은 gz /range/front(LaserScan, 플러그인 in-process)의 최소거리 → ROS 브리지(points-only)와 무관하게 회피 정상. 단 ROS2엔 LaserScan 데이터 없음.
  - **저쪽 구독 필수**: PointCloud2(`/range/front/points`) 파싱. 2D LaserScan 코드는 데이터 못 받음.
- **fan3d_down (.fan3d_down) ← 현재 활성(2026-06-08).** points-only 3D 인지, RNGFND/PRX/AVOID **off**(→MAVLink DISTANCE_SENSOR 미발신, mavros 크래시 트리거 없음). 수평 ±45°(91) × **수직 -60°~+5°(33층, ~2.03°)** = 91×33=3003 ray. `vertical samples=33 min=-1.0472 max=0.0873`. 마운트 수평 유지(el=0 포함→전방 20m). **왜 -60°:** 5m 고도서 1m 장애물이 -40°론 수평 4.77m 이내 사각 → -60°로 2.3m까지 커버. 검증 ✅(91×33, 고도각 -60°~+5°, DISTANCE_SENSOR 0건). **지면 점 많으니 저쪽 지면 필터 필수.** (이력: 6/2 -40°/28층 → 6/8 -60°/33층 + 크래시 회피용으로 fan3d_av 대신 채택)
- **fan3d_av (.fan3d_av) ← 2026-06-02 추가, 현재 활성. 2026-06-08 수직 -60°로 확대.** **3D 인지 + 펌웨어 반응제어 결합.** 센서 2개:
  - A) 수평 회피센서 `rangefinder_av` (gz `/range/front_av`, H±45°×V0° 1층). 플러그인 index1 등록 → RNGFND1. ROS 미발행(ArduPilot 전용). 수평이라 지상 ARM 안 막힘. parm: RNGFND1=100/PRX1=4/AVOID_ENABLE=7/MARGIN=2.0/DIST_MAX=5.
  - B) 3D 하향센서 `rangefinder_front` (gz `/range/front`, H±45°×**V-60°~+5° 33층**, 91×33=3003 ray). RNGFND **미등록**. ROS2 `/range/front/points`(PointCloud2) → 저쪽 인지.
    - **마운트 수평(pitch 0) 유지, FOV만 하향 확대** → el=0 포함이라 **전방 20m 그대로**(검증: el≈0 유한값 존재). 하향 -60°로 5m 고도서 1m 장애물 수평 2.3m 이내까지 커버(이전 -40°는 4.77m 이내 사각).
    - 월드(iris_runway_des.sdf) 장애물=1m 높이 도형들(box/cylinder/cone/sphere), iris +Y(yaw≈91.6°) 정면. 2m 고도: box top el-16°(slant3.57 vs 지면7.15)로 명확 감지. 5m 고도: -40°였으면 el-49°로 사각이라 -60° 확대함.
  - **저쪽은 `/range/front/points`만 구독**(인지). 반응제어는 ArduPilot이 /range/front_av로 자동 — 저쪽 구독/융합 불필요, 두 레이어 독립. ArduPilot 회피는 저쪽 velocity command 위에 안전망으로 동작.
  - 검증 ✅: gz 2센서, ROS points 91×28, RNGFND1←/range/front_av, PreArm 차단 없음, 회피센서 지상 5.27m.
  - **2026-06-08 현재 활성(fan3d_down에서 복귀).** 3D 센서 수직 -60°~+5°(33층)로 확대됨. yaml에 **`/range/front_av` LaserScan 브리지 추가**(RNGFND 값 ROS 노출, 사용자 요청). mavros도 `/mavros/rangefinder/rangefinder`(Range) 발행.
  - **저쪽 mavros SIGBUS 크래시 분석:** 저쪽은 "FOV -60° → 새 sensor_id 10" 탓했으나 오진. id=10은 proximity/RNGFND에서 나오고 예전(0601 테스트 성공 시)에도 나갔음 → "원래 됐었다"면 id=10은 주범 아님. SITL COMMAND_ACK 정상 검증됨. 크래시 재발 시 mavros 쪽 버그(unmapped sensor_id에 SIGBUS)로 봐야 함 — 저쪽이 mavros 로그+apm_config.yaml distance_sensor 매핑 점검.
- **single (.front_single)**: 전방 단일빔 1개(samples=1, 0°만). `/range/front` 1점. 정면 직선만 측정, 베어링 정보 없음("앞에 X m"). RNGFND1만.

**공통 메커니즘:**
- 같은 gpu_lidar라도 samples=1=단일빔 거리계, h>1=수평 부채꼴, h>1&v>1=3D. 타입명만 lidar.
- 플러그인 RangeCb가 모든 ray의 **최소거리**를 rng_1로 합성(`ArduPilotPlugin.cc:286-303` sample_min) → RNGFND1 = 전방 cone 내 최근접. **어떤 변형이든 플러그인/빌드 수정 불필요.** parm은 fan/fan3d/single 동일(RNGFND1만)이라 status에서 parm은 FAN으로 표시됨(정상).
- 센서 피치=0(수평, pose `0.15 0 0 0 0 0`), base_link 고정 → 기체 pitch 따라감.
- fan 검증 ✅(2026-06-01): ranges=91, -45~+45°, incr 1.0°, 0.1~20m. 실측 정면 3.27m·좌단 5.43m·우단 5.27m.

**베어링 좌표계 주의(저쪽 매칭용):** YOLO bearing은 0~360°·0°=북(나침반 절대·시계+). RNGFND/LaserScan은 body 기준(0=기수). 변환: `rel_cw=wrap180(bearing-drone_heading)`, `±45° 밖이면 스킵`, `laser_angle=-rel_cw`(LaserScan은 CCW+), `idx=round((laser_angle_rad-angle_min)/angle_increment)`, idx±1~2칸 min. angle_increment는 메시지에서 읽기(하드코딩 금지).

## 적용 시 주의

- **eeprom.bin 삭제 필요** (parm 새로 로드시키려고). 백업: `eeprom.bin.before_rangefinders`. SITL이 eeprom 우선 → 새 RNGFND 파라미터 무시될 수 있음
- 토글 후 반드시 `bash stop_sim.sh && bash start_sim.sh` 재시작
- `ardupilot_gazebo` 플러그인 자체에 LoadRangeSensors()/RangeCb() 구현 있음 (line 286, 879, 962, 1941-1957) — JSON 키 rng_1~6 매핑

## 검증 (2026-05-29 로컬 구독 확인 완료 ✅)

**전용 스크립트:** `bash check_rangefinders.sh` — ROS2 3토픽(권위) + gz(참고) 일괄 확인. ros2는 `--no-daemon` 사용(좀비 데몬 회피, [[ros2 좀비 daemon 진단 함정]] 참고).

2026-05-29 실측: `/range/front`=3.27m(정면 장애물), `/range/left`=`.inf`, `/range/right`=`.inf`(열린 활주로). ArduPilot 측 `DISTANCE_SENSOR orient=0 327cm`와 정면값 일치 → gpu_lidar→RNGFND→proximity→avoid 체인 in-process 정상. 좌/우가 inf라 proximity는 전방 섹터만 보고(정상).

```bash
# 권위 검증 (다른 컴도 동일 ROS2 경로로 구독)
bash check_rangefinders.sh
# 개별 — 좀비 daemon 의심 시 --no-daemon 필수
ros2 topic echo /range/front --once --no-daemon | grep -A1 "^ranges:"
# ArduPilot 라이브 거리값 (MAVLink, mavproxy --out 127.0.0.1:14551)
python3 -c "from pymavlink import mavutil as M;m=M.mavlink_connection('udpin:127.0.0.1:14551');m.wait_heartbeat();import time;t=time.time()
while time.time()-t<8:
 x=m.recv_match(type='DISTANCE_SENSOR',blocking=True,timeout=2)
 if x:print(x.orientation,x.current_distance,'cm')"
# 파라미터/플러그인
grep -E "^RNGFND[123]_TYPE\b|^PRX1_TYPE\b" mav.parm
grep "subscribing to /range" /tmp/sim_start.log
```

**주의:** `gz topic -e`(외부 CLI)는 gz transport 디스커버리 한계로 샘플이 안 잡힐 수 있으나, ros_gz_bridge는 in-process로 정상 수신하므로 ROS2엔 데이터가 흐른다 → gz CLI 미수신은 무시 가능.

## 펌웨어 회피 알고리즘 활성 상태

**자동 동작 (별도 코드 불필요):**
- Loiter / AltHold / GUIDED 모드에서 Simple Avoidance ON
- 장애물 `AVOID_MARGIN`(=2m) 이내 진입 시 자동 정지/감속 (AVOID_BEHAVE: 0=Slide, 1=Stop)
- ROS2/MAVLink velocity command도 회피로 보호됨
- 데이터 흐름: Gazebo gpu_lidar → fdm rng_N → AP_RangeFinder → AP_Proximity (8-sector) → AC_Avoidance

**미활성 (필요 시 추가 설정):**
- `OA_TYPE 1` (BendyRuler) / `OA_TYPE 2` (Dijkstra) 미설정 → AUTO 미션에서 우회 경로 자동 계획 안 함, 단순 정지만
- `AVOID_BEHAVE` 명시 안 함 → 기본값 0 (Slide). Stop 원하면 1로

## 이어서 할 일 (2026-06-02 세션 종료 시점)

**현재 활성: fan3d_av** (3D 인지 PointCloud2 + 펌웨어 수평 회피센서). 시뮬 정상, en7=10.130.200.31 / Peer=10.130.200.27(저쪽). 저쪽 cyclonedds Peer는 10.130.200.31로 맞춰야 함.

**저쪽 코드(`RangeListener`, PointCloud2 처리) 남은 작업:**
1. 🔴 **지면 필터(최우선)**: 오늘 실측으로 확정된 핵심 이슈. 평지 호버(고도 2.2m)에서 전체 cone 최근접을 그냥 쓰면 nearest가 **지면(~8m)** 이 됨 → "장애물 거리가 가까이/멀리 무관 항상 ~7.8m"의 정체가 지면이었음. 또 장애물 높이에 따라 3m↔10m 튀던 것도 지면/사각지대 때문. **해결: `_cb_front_pc2`에서 `el<0`인 점은 `r_ground = h_AGL/sin(|el|)` 보다 확연히 가까울 때(`dist < r_ground - 0.5`)만 장애물로 채택, 지면 점 제거.** `h_AGL`은 odometry z(`/odometry`) 구독해서. 그 후 방위 윈도우(±2°) 내 최근접 비지면점 사용.
2. 🔴 **문법 오류**(아직 안 고쳤으면): `self._RANGE_3D_ENABLED = ... == _3D_ENABLED:` → `== 'true'` + `if` 블록 분리. `import os` 상단 확인.
3. 반응제어는 **ArduPilot이 자동**(fan3d_av 수평센서) → 저쪽은 `/range/front_av` 구독 불필요. 저쪽은 `/range/front/points`만. 두 레이어 독립.
- 베어링 변환: YOLO 나침반(0=북,CW+) → body `rel_cw=wrap180(bearing-heading)`, PointCloud azimuth는 CCW+라 `target_az=-radians(rel_cw)`.
- 잘된 점(기존): `math=self._math` 스코프 OK, QoS BEST_EFFORT 적합, `rel_deg=-atan2(y,x)` 부호 OK.

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
