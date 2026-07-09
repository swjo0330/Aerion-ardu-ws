# AERION 시뮬 레이어 (ardu_ws)

> macOS ARM에서 ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble로 비행체를 시뮬레이션하고, 크로스머신 DDS/MAVLink로 Ubuntu 지능 레이어에 실시간 공급하는 시뮬레이션 워크스페이스.
> **궁극 업무목표를 항상 인지하고 작업한다**: 한 Gazebo 월드에 SITL 3기를 DDS 도메인 분리로 띄워, 저쪽 **드론별 체화지능 3개**(d1=본기, d2·d3=leaf)가 각자의 기체 토픽을 독립 수신하는 멀티 에이전트 시뮬 기반을 완성한다. **감독지능은 별도 인스턴스가 아니라 체화 내부의 비동기 루프**(NATS `swarm.state.*` 소비, DDS 아님).

---

## 1. 전체 아키텍처

```
[Ubuntu 지능 레이어 (10.130.200.x — DHCP 매일 변동)]
  체화지능#1(본기)   체화지능#2(leaf)  체화지능#3(leaf)   ┌─ 감독지능: 체화 내부 비동기 루프
  (ROS_DOMAIN_ID=1)  (2)              (3)               │   (NATS swarm.state.* 구독, DDS 아님)
  mavros ×기체별 │ /a2a/drone{i}/* │ /vision/*(d1만) │ /perception/state │ /replan_waypoints
   ▲ MAVLink UDP (14555+10i)      ▲ DDS RTPS 유니캐스트 (CycloneDDS Peer, en7 유선만)
   │                              │
[Mac 시뮬 레이어 (이 워크스페이스)]
  인스턴스 i ∈ {0,1,2}:
  MAVProxy_i ──tcp 5760+10i──▶ SITL_i (arducopter --instance i, sysid i+1, cwd 분리)
  micro_ros_agent_i (udp4 2019+10i) ◀──XRCE-DDS── SITL_i (DDS_DOMAIN_ID=d(i+1), DDS_UDP_PORT=2019+10i)
  ros_gz_bridge_i (ROS_DOMAIN_ID=d(i+1), ns=/drone{i+1}) ◀──gz-transport──┐
   │ JSON lock-step UDP (fdm_port_in 9002+10i)                            │
[Gazebo Harmonic — 단일 서버, world 'map']                                 │
  iris_d1 · iris_d2 · iris_d3 (ArduPilotPlugin + gpu_lidar + camera + gimbal)
  + path_marker_node (gz /marker 서비스)
```

- 단일 인스턴스 모드(현행 기본)는 위에서 i=0 한 줄만 존재하는 특수형 — 포트·토픽 전부 무접미 원값.
- 왜 단일 gz 서버 + 3모델인가: 호스트 P-core 4개/24GB 실측 + GZ_PARTITION 미사용 구조 → 월드 3개 병렬은 자원·토픽 충돌 리스크 (2026-07-09 분석 확정).

## 2. 컴포넌트

| 컴포넌트 | 역할 | 입출력 | 상태 |
|---|---|---|---|
| Gazebo 서버 (`gz sim -s`) | 물리·센서 시뮬 (world `map`) | SDF → gz 토픽 | ✅ 단일 / 📌 3모델 |
| ArduPilotPlugin (기체별) | gz↔SITL lock-step 브리지 | gz 물리 ↔ JSON UDP 9002+10i | ✅ 1기 / 📌 3기 |
| arducopter SITL_i | 비행 펌웨어 | JSON ↔ MAVLink(5760+10i) ↔ XRCE(2019+10i) | ✅ 1기 / 📌 3기 |
| micro_ros_agent_i | XRCE→DDS 게이트 | udp4 2019+10i → domain d(i+1) `/ap/*` | ✅ 1개 / 📌 3개 |
| MAVProxy_i | MAVLink 라우팅 | tcp 5760+10i → UDP out 14555+10i(저쪽)·14551+10i(로컬) | ✅ 1개 / 📌 3개 |
| ros_gz_bridge_i | gz→ROS2 토픽 변환 | iris_bridge yaml → ns=/drone{i+1} | ✅ 1개(무ns) / 📌 3개 |
| robot_state_publisher_i | URDF·TF | model.sdf → /drone{i+1}/tf | ✅ 1개 / 📌 3개 |
| path_marker_node | 경로 시각화 | /replan_path_enu → gz /marker | ✅ (도메인 소속 §5.1) |
| RViz2 + gz GUI | 시각화 (자원상 각 1개 고정) | — | ✅ |
| 저쪽 체화지능 ×3 | 드론별 지능 소비자 (d1 본기=vision有, d2·d3 leaf=rule_only) | 14555+10i / domain d | (저쪽 관할) |
| 저쪽 감독지능 | 체화 내부 비동기 루프 (별도 도메인 아님) | NATS swarm.state.* 구독 | (저쪽 관할) |

## 3. 데이터 흐름

1. **물리→지능(인지)**: Gazebo 센서(camera 640x480·gpu_lidar) → gz-transport → bridge_i → `/drone{i}/camera/image`·`/drone{i}/range/front/points` (domain d) → 저쪽 지능 인스턴스
2. **펌웨어→지능(상태)**: SITL_i → XRCE → agent_i → `/ap/*` (domain d — AP 토픽명은 펌웨어 고정이라 도메인이 유일한 분리축) + MAVLink → mavros
3. **지능→펌웨어(제어)**: 저쪽 `/ap/cmd_vel`·mavros setpoint → SITL_i → JSON → Gazebo 물리
4. **시각화 루프백**: 저쪽 `/replan_path_enu` → path_marker_node → gz /marker

## 4. 인터페이스 스키마 (정본)

### 포트·도메인 할당표 (Mac 시뮬 레이어 → 전 소비자)

| 항목 | 공식 | inst 0 | inst 1 | inst 2 | 근거 |
|---|---|---|---|---|---|
| SERIAL0 (MAVProxy master) | 5760+10i | 5760 | 5770 | 5780 | SITL_cmdline.cpp:402-419 |
| RC in / FDM | 5501+10i / 9002+10i | 5501/9002 | 5511/9012 | 5521/9022 | 상동 + ArduPilotPlugin.cc:1276 |
| XRCE agent (DDS_UDP_PORT) | 2019+10i | 2019 | 2029 | 2039 | --instance 오프셋 **비대상** — parm으로 명시 |
| MAVLink out(저쪽/로컬) | 14555+10i / 14551+10i | 14555/14551 | 14565/14561 | 14575/14571 | sim_vehicle.py 관례 준용 |
| SYSID_THISMAV | i+1 | 1 | 2 | 3 | --instance는 sysid 자동 유도 안 함 |
| DDS 도메인 d | i+1 | **1** | **2** | **3** | §5.1 확정 |
| ROS 네임스페이스 | /drone{i+1} | /drone1 | /drone2 | /drone3 | 저쪽 /a2a/drone1/* 기존 컨벤션 정합 |
| SITL cwd | sitl_ws/i{i}/ | i0/ | i1/ | i2/ | eeprom.bin cwd 상대 (Storage.cpp:91) |

### /ap/* (SITL_i → 지능, domain d 내)
펌웨어 고정 토픽명 (`AP_DDS_Topic_Table.h`) — `/ap/pose/filtered`, `/ap/navsat`, `/ap/battery`, `/ap/cmd_vel`(구독) 등 17종. **네임스페이스 불가 → 도메인으로만 분리.**

### /drone{i}/* (bridge_i → 지능, domain d 내)
`camera/image`(sensor_msgs/Image rgb8), `camera/camera_info`, `range/front/points`(PointCloud2 — fan3d 계열), `imu`, `odometry`, `battery`, `navsat`, `tf` 등 — gz 쪽 원경로는 `/world/map/model/iris_d{i+1}/...`.

### /replan_path_enu (지능 → path_marker_node)
`nav_msgs/Path`, frame=ENU map, 원점=gz world 원점=기체 스폰점. 빈 Path=DELETE, lifetime 5s.

## 5.1 멀티 SITL 도메인 분리 설계 확정 (2026-07-09)

### 배경
단일 인스턴스 파이프라인은 23개 하드코딩 싱글턴(포트 5760/9002/2019/14555, 모델명 `iris`, 무네임스페이스 토픽, 단일 eeprom·cwd)으로 봉인되어 launch 인자만으론 2기째가 불가. 한편 `/ap/*` 토픽명은 펌웨어 고정이라 같은 도메인에 3기를 두면 상태·제어 토픽이 뒤섞인다(오제어 위험). XRCE 세션 키도 고정(0xAAAABBBB)이라 agent 공유 불가.

### 확정 구조
- **분리축 = DDS 도메인**: 기체 i → domain i+1 (d1/d2/d3). 로컬 운용 도구(RViz·진단)는 필요 도메인을 골라 접속. domain 0은 단일 인스턴스 모드 전용으로 보존.
- **수신 매핑 (정정 2026-07-09)**: 도메인 1/2/3 ↔ **드론별 체화지능 1/2/3** (1:1). d1=본기(카메라/vision), d2·d3=leaf(rule_only, 무카메라). **감독지능은 별도 도메인/인스턴스가 아님** — 체화 내부(주로 본기)의 비동기 루프로 NATS `swarm.state.*` 상태 스트림을 소비(DDS 무관). 따라서 DDS 도메인은 순수 체화 3개 기준.
- **기체별 수직 스택**: SITL_i + agent_i + MAVProxy_i + bridge_i + rsp_i가 한 세트로 같은 도메인에 상주. `/clock` 브리지는 **도메인당 1개** — 각 bridge_i가 자기 도메인에 전역 `/clock` 발행 (도메인 내 유일하므로 중복 아님; 저쪽 소비자도 sim time 필요 — 설계 정본 D4).
- **gz 레이어**: 단일 월드 `map`에 모델 사본 3종 `iris_d1/d2/d3` — 사본별 fdm_port_in(9002+10i)·절대 토픽 개명(`/drone{i}/gimbal/cmd_*`, `/drone{i}/range/*`). 멀티용 월드 SDF는 신규 파일로 (기존 `iris_runway_des.sdf` 불변).
- **기존 파이프라인 불변**: `start_sim.sh`/단일 모드는 그대로. 멀티는 `start_multi_sim.sh`(신규) 병행.

### 역할 재정의
- MAVProxy: 단일 GCS 중계 → 기체별 3중계 (out 14555+10i — 저쪽 mavros도 기체별 3개 필요, 저쪽 관할)
- ros_gz_bridge: 전역 무네임스페이스 → 기체별 ns 부여자
- stop_sim.sh: 전역 pkill 유지(전체 정지 전용) — 인스턴스 선별 정지는 비지원(확정: 단순성 우선)

## 네이밍 컨벤션

- gz 모델: `iris_d{N}` (N=도메인 번호) / ROS ns: `/drone{N}` / 저쪽 에이전트: `/a2a/drone{N}/*` (기존 drone1 컨벤션 계승)
- 인스턴스 파생 파일: `<원본이름>_d{N}.<확장자}` (예: `iris_bridge_d2.yaml`, `dds_udp_d2.parm`)
- 검증·설계 문서: `Docs/specs/YYYY-MM-DD-<키워드>.md`

## 로드맵·구현 현황 (2026-07-09 스냅샷)

| 단계 | 내용 | 상태 |
|---|---|---|
| Phase 0 | 단일 SITL+Gazebo+ROS2 파이프라인 (센서 변형 6종, 크로스머신 DDS) | ✅ |
| Phase 1 | 하네스 도입 (CLAUDE/AGENTS/EXPERIMENTS/notes/Docs/memory) | 🟡 진행 중 |
| Phase 2 | 멀티 SITL 설계 정본 (`Docs/specs/2026-07-09-multi-sitl-3instance-design.md`) | 🟡 |
| Phase 3 | 2기 수직 슬라이스 (i0+i1, 도메인 분리 실측) | 📌 |
| Phase 4 | 3기 확장 + 저쪽 3인스턴스 수신 검증 | 📌 |
