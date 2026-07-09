# 멀티 SITL 전환에 따른 토픽 인터페이스 변경 규격 (저쪽 Ubuntu 전달용)

> 발행: 2026-07-09 · 발신: Mac 시뮬 레이어 (ardu_ws) · 수신: Ubuntu 지능 레이어 (드론별 체화지능 ×3 — 감독지능은 체화 내부 비동기 루프)
> 배경: Gazebo 1월드에 SITL 3기(iris_d1/d2/d3)를 **DDS 도메인 분리**(d1/d2/d3)로 기동하는 멀티 모드가 추가됨. 로컬 3기 검증 완료(2026-07-09 실측: DDS 3/3·EKF3 3/3·도메인 교차 오염 0·실데이터 수신).
> **단일 모드는 불변** — 기존 규격 그대로 병행 운용 (아래 §5). 어느 모드가 떠 있는지는 Mac 쪽이 공지.

---

## 1. 핵심 변경 요약 (기존 → 멀티)

| 항목 | 기존 (단일) | 멀티 (3기) |
|---|---|---|
| ROS 도메인 | 0 (전부) | **기체별 분리: drone1=1, drone2=2, drone3=3** |
| `/ap/*` (펌웨어 상태·제어) | domain 0에 1세트 | **각 도메인에 자기 기체 것만 1세트** (토픽명 동일 — 이름은 펌웨어 고정이라 도메인이 유일한 분리축) |
| 센서 토픽 | 무네임스페이스 (`/camera/image` 등) | **`/drone{N}/` 네임스페이스** (`/drone1/camera/image` 등) |
| 카메라 | `/camera/image` 1개 | **`/drone1/camera/image` — 본기(d1)만** (스펙 동일 유지: 640x480 rgb8). d2/d3는 카메라 센서 없음 |
| 인지(3D) | `/range/front/points` | **`/drone1/range/front/points` — 본기(d1)만**. d2/d3는 인지 토픽 없음 (leaf) |
| MAVLink 수신 포트 | UDP 14555 | **drone1=14555 / drone2=14565 / drone3=14575** |
| MAV SYSID | 1 | **drone1=1 / drone2=2 / drone3=3** |
| `/clock` (sim time) | domain 0 | **각 도메인에 전역 `/clock` 1개씩** (use_sim_time 그대로 사용 가능) |
| `/replan_path_enu` (경로 시각화 입력) | domain 0 | **domain 1** (path_marker_node가 d1 소속) |

## 1.5 토픽 전수 매핑표 (단일 → 멀티, 1:1)

> 저쪽 구독/발행 리매핑용 정본. `{N}`=기체 번호(1/2/3), 각 토픽은 **domain N**에 존재. 타입은 `ros_gz_bridge` 설정 정본(iris_bridge.yaml) 기준.

### A. ArduPilot DDS `/ap/*` — 이름·타입 **불변**, 도메인만 분리 (17종)

| 단일 (domain 0) | 멀티 | 방향 | 비고 |
|---|---|---|---|
| `/ap/pose/filtered` · `/ap/twist/filtered` · `/ap/geopose/filtered` · `/ap/navsat` · `/ap/gps_global_origin/filtered` · `/ap/battery` · `/ap/status` · `/ap/clock` · `/ap/time` · `/ap/imu/experimental/data` · `/ap/airspeed` · `/ap/tf` · `/ap/tf_static` | **동일 이름** (domain N) | Mac→저쪽 (발행) | 펌웨어 고정명 — 네임스페이스 불가, **도메인이 유일한 분리축** |
| `/ap/cmd_vel` · `/ap/cmd_gps_pose` · `/ap/goal_lla` · `/ap/joy` | **동일 이름** (domain N) | 저쪽→Mac (구독) | 제어 입력 — 해당 기체 도메인에 발행해야 그 기체가 받음 |

→ 리매핑 규칙: **`/ap/*`는 토픽명 그대로 두고 프로세스의 `ROS_DOMAIN_ID`만 N으로.** (기체 구분 = 도메인)

### B. ros_gz_bridge 센서 — `/drone{N}/` 네임스페이스 부여

| 단일 | 멀티 | 타입 | 존재 기체 |
|---|---|---|---|
| `/camera/image` | `/drone{N}/camera/image` | `sensor_msgs/Image` | **d1만** (640x480 rgb8) |
| `/camera/camera_info` | `/drone{N}/camera/camera_info` | `sensor_msgs/CameraInfo` | **d1만** |
| `/range/front/points` | `/drone{N}/range/front/points` | `sensor_msgs/PointCloud2` | **d1만** |
| `/range/front_av` | `/drone{N}/range/front_av` | `sensor_msgs/LaserScan` | **d1만** — ⚠️ **지능측 소비 없음(휴면 폴백)**: 저쪽은 `RANGE_3D_ENABLED=true` 운용이라 2D LaserScan 폴백은 미사용(2026-07-09 저쪽 확인) |
| `/imu` | `/drone{N}/imu` | `sensor_msgs/Imu` | d1·d2·d3 |
| `/navsat` | `/drone{N}/navsat` | `sensor_msgs/NavSatFix` | d1·d2·d3 |
| `/odometry` | `/drone{N}/odometry` | `nav_msgs/Odometry` | d1·d2·d3 |
| `/air_pressure` | `/drone{N}/air_pressure` | `sensor_msgs/FluidPressure` | d1·d2·d3 |
| `/magnetometer` | `/drone{N}/magnetometer` | `sensor_msgs/MagneticField` | d1·d2·d3 |
| `/battery` | `/drone{N}/battery` | `sensor_msgs/BatteryState` | d1·d2·d3 |
| `/joint_states` | `/drone{N}/joint_states` | `sensor_msgs/JointState` | d1·d2·d3 |

### C. TF·기술(description)·시계

| 단일 | 멀티 | 타입 | 비고 |
|---|---|---|---|
| `/gz/tf` | `/drone{N}/gz/tf` | `tf2_msgs/TFMessage` | gz 원본 |
| `/gz/tf_static` | `/drone{N}/gz/tf_static` | `tf2_msgs/TFMessage` | gz 원본 |
| `/tf` | `/drone{N}/tf` | `tf2_msgs/TFMessage` | relay(`/drone{N}/gz/tf`→`/drone{N}/tf`) + rsp. frame_prefix=`drone{N}/` |
| `/tf_static` | `/drone{N}/tf_static` | `tf2_msgs/TFMessage` | rsp static TF |
| `/robot_description` | `/drone{N}/robot_description` | `std_msgs/String` | URDF |
| `/clock` | `/clock` (**이름 불변, 도메인별 1개**) | `rosgraph_msgs/Clock` | sim time — 각 도메인에 전역 발행 |

### D. 경로 시각화·MAVLink

| 단일 | 멀티 | 비고 |
|---|---|---|
| `/replan_path_enu` (저쪽→Mac 구독) | `/replan_path_enu` (**domain 1**, 이름·frame 불변) | path_marker_node가 d1 소속 |
| MAVLink UDP out `14555` | `14555`(d1) / `14565`(d2) / `14575`(d3) | mavros `fcu_url` 포트. `/mavros/*` 네임스페이스는 저쪽 체화 관할 |

> **주의**: TF는 기체별 `frame_prefix=drone{N}/`로 프레임명도 분리됨 — 저쪽에서 TF 트리를 합칠 경우 prefix 충돌 없음. 단 `/tf`·`/tf_static`은 도메인 경계로 이미 분리되므로 네임스페이스는 보조 수단.

## 2. 도메인별 토픽 명세 (멀티 모드 실측 기준)

### domain 1 — 본기 drone1 (체화지능#1 담당)

```
/ap/*                       ← 17종 전부 (pose/twist/geopose/navsat/battery/status/clock/time/
                               imu/airspeed/gps_global_origin + 구독: cmd_vel/cmd_gps_pose/goal_lla/joy)
/drone1/camera/image        ← sensor_msgs/Image, 640x480 rgb8 (기존 스펙 유지)
/drone1/camera/camera_info
/drone1/range/front/points  ← sensor_msgs/PointCloud2 (fan3d 3D 인지 — 기존 /range/front/points)
/drone1/range/front_av      ← sensor_msgs/LaserScan (RNGFND 값 확인용)
/drone1/{imu,odometry,battery,navsat,air_pressure,magnetometer,joint_states}
/drone1/{tf,gz/tf,robot_description}   ← TF frame_prefix "drone1/"
/clock
/replan_path_enu            ← (저쪽→Mac 구독) nav_msgs/Path ENU — 규격 기존과 동일
```

### domain 2 — leaf drone2 (체화지능#2 담당) / domain 3 — leaf drone3 (체화지능#3 담당)

```
/ap/*                       ← 17종 전부 (자기 기체 것만)
/drone{2,3}/{imu,odometry,battery,navsat,air_pressure,magnetometer,joint_states}
/drone{2,3}/{tf,gz/tf,robot_description}
/clock
```
- **카메라·range 없음** (leaf는 vision/인지 파이프라인 없음 — S-5 설계 확정. leaf 기체 장애물은 상태 이상으로만 감독에 잡힘. 본기 장애물 조우 시나리오는 본기 카메라 시야에서 발생시킬 것)

### MAVLink (mavros용)

| 기체 | Mac→Ubuntu UDP | SYSID | 대응 지능 |
|---|---|---|---|
| drone1 | `0.0.0.0:14555` 수신 | 1 | 체화지능#1 (본기 — 카메라/vision, **감독지능 비동기 루프 내장**) |
| drone2 | `0.0.0.0:14565` 수신 | 2 | 체화지능#2 (leaf, rule_only) |
| drone3 | `0.0.0.0:14575` 수신 | 3 | 체화지능#3 (leaf, rule_only) |

> **아키텍처 주의**: 감독지능은 **별도 DDS 도메인/인스턴스가 아니다.** 도메인 1/2/3은 전부 드론별 **체화지능**이고, 감독지능은 체화 내부(주로 본기 d1)의 **비동기 루프**로 동작하며 NATS `swarm.state.*` 상태 스트림을 소비한다(DDS 아님). 즉 이 규격서의 도메인↔토픽 매핑은 순수 체화지능 3개 기준이다.

## 3. 저쪽에서 해야 할 설정

1. **인스턴스별 `ROS_DOMAIN_ID`**: 체화지능#1 프로세스는 `ROS_DOMAIN_ID=1`, 체화#2는 `2`, 체화#3은 `3`으로 기동 (드론별 체화 1:1 매핑). 같은 도메인끼리만 통신됨 — 다른 도메인 토픽은 보이지 않는 것이 정상. 감독지능은 별도 도메인이 아니라 체화 내부 비동기 루프이므로 자체 `ROS_DOMAIN_ID` 설정 대상이 아님(NATS 구독)
2. **mavros 3개**: 위 표의 포트로 기체별 기동 (`fcu_url:=udp://0.0.0.0:{포트}@`), `tgt_system`=SYSID 권장.
   - ⚠️ **경계**: Mac은 **MAVLink UDP 스트림(포트별 14555/14565/14575)만 제공**한다. mavros 노드의 네임스페이스·토픽 리매핑(`/mavros/*` → `/drone{N}/mavros/*` 등)은 **각 체화지능이 자기 규칙대로** 설정하는 영역이며, Mac이 강제하거나 규정하지 않는다. 이 규격서의 `/mavros/*` 예시는 참고일 뿐, 최종 네이밍은 저쪽 체화 관할.
3. **cyclonedds Peer = Mac en7 IP** (기존과 동일 — IP는 매일 변동, 별도 공지 채널 유지). 도메인이 달라도 XML의 Peer/NetworkInterface 설정은 전 도메인 공통 적용됨
4. **토픽명 변경 반영**: 기존 `/camera/image` → `/drone1/camera/image`, `/range/front/points` → `/drone1/range/front/points` 구독 리매핑
5. `/a2a/drone1/*` 컨벤션의 `/a2a/drone{2,3}/*` 확장 (저쪽 관할)
6. `/replan_path_enu` 발행 노드는 **domain 1**에서 발행 (규격·frame 기존 동일)

## 4. 수신 검증 명령 (저쪽에서)

```bash
# 도메인별 발견 확인 (--no-daemon 필수 — 데몬 캐시가 도메인 섞음)
ROS_DOMAIN_ID=1 ros2 topic list --no-daemon | grep -E "^/(ap|drone1)"
ROS_DOMAIN_ID=2 ros2 topic list --no-daemon | grep -E "^/(ap|drone2)"
ROS_DOMAIN_ID=3 ros2 topic list --no-daemon | grep -E "^/(ap|drone3)"
# 실데이터 판정 (list는 /ap 열거 플레이크 있음 — echo가 판정 기준)
ROS_DOMAIN_ID=2 ros2 topic echo /ap/time --once
ROS_DOMAIN_ID=1 ros2 topic hz /drone1/camera/image
```

## 5. 단일 모드 병행 (불변)

Mac이 `start_sim.sh`(단일)로 띄우면 **기존 규격 그대로**: domain 0, `/camera/image`·`/range/front/points` 무네임스페이스, MAVLink 14555, SYSID 1. 멀티(`start_multi_sim.sh`)와 동시 운용은 하지 않음 — 전환 시 Mac 쪽이 공지.

## 6. 실측 토픽 인벤토리 (2026-07-09, 3기 동시 기동 · `ros2 topic list --no-daemon` 실측)

### domain 1 — drone1 (본기) : 총 /ap 17 + /drone1 15 + /clock + /replan_path_enu

```
/ap/airspeed  /ap/battery  /ap/clock  /ap/geopose/filtered  /ap/gps_global_origin/filtered
/ap/imu/experimental/data  /ap/navsat  /ap/pose/filtered  /ap/status  /ap/tf  /ap/tf_static
/ap/time  /ap/twist/filtered                                   ← 발행(펌웨어 상태)
/ap/cmd_vel  /ap/cmd_gps_pose  /ap/goal_lla  /ap/joy           ← 구독(제어 입력)
/drone1/camera/image  /drone1/camera/camera_info               ← 본기만 (640x480 rgb8)
/drone1/range/front/points (PointCloud2)  /drone1/range/front_av (LaserScan)  ← 본기만
/drone1/imu  /drone1/odometry  /drone1/battery  /drone1/navsat
/drone1/air_pressure  /drone1/magnetometer  /drone1/joint_states
/drone1/tf  /drone1/gz/tf  /drone1/gz/tf_static  /drone1/robot_description
/clock  /replan_path_enu(저쪽→Mac)
```

### domain 2·3 — drone2·drone3 (leaf) : 총 /ap 17 + /drone{N} 11 + /clock

```
/ap/* (17종 — domain 1과 동일 구성, 자기 기체 것)
/drone{N}/imu  /drone{N}/odometry  /drone{N}/battery  /drone{N}/navsat
/drone{N}/air_pressure  /drone{N}/magnetometer  /drone{N}/joint_states
/drone{N}/tf  /drone{N}/gz/tf  /drone{N}/gz/tf_static  /drone{N}/robot_description
/clock
```
→ **카메라·range 없음** (leaf, D10). drone1(15) − drone{2,3}(11) = camera 2 + range 2.

### 실측 발행 주기 (3기 동시, RTF≈16~40% 상태 — **wall-clock 기준. sim-time 환산 시 ÷RTF**)

| 토픽 | 실측 Hz (wall) | 비고 |
|---|---|---|
| `/drone1/camera/image` | ~1.6 | 본기만. sim-time 환산 시 ~10Hz(SDF update_rate) 근방 |
| `/drone1/range/front/points` | ~3.0 | 본기만 |
| `/ap/pose/filtered` | ~4.6 | 상태 추정 |
| `/drone{N}/imu` | ~195 | 고빈도 — 대역 주의 |
| `/ap/navsat` | ~0.9 | GPS |

> **주의**: 위 Hz는 3기 동시 + macOS ARM(P-core 4) RTF 저하가 반영된 **wall-clock 실측**이다. 저쪽에서 실제 관측되는 주기도 동일 RTF에 종속되므로, 레이트 검사·타임아웃은 **sim-time(`/clock`) 기준**으로 짜는 것을 권장. 단일 모드(1기)에서는 RTF가 높아 Hz가 더 올라간다.

## 7. 스폰 대형·GPS 이격 (확정 — 2026-07-09 실측)

- **홈 간격 확정값**: home GPS는 **셋 다 공유**(`37.39447652, 126.6381927`), 물리·GPS 이격은 **gz 스폰 북(+Y) 선형 30m·i**(`SPAWN_NORTH_M={0,30,60}`)로 생성. 저쪽 env 슬롯 흡수값 = **30m 간격, 북 {0,30,60}**.
- **GPS 실측 (요청 검증)**: 3기 기동 후 도메인별 `/ap/navsat` 위도 실측 —
  `d1=37.39447784` · `d2=37.39474487`(**+30m**) · `d3=37.39501953`(**+60m**). 소비스 간격 30m·총 60m, 모든 쌍 >10m → 규칙 #11(`SWARM_SAFETY_RADIUS_M=10`) 오탐 없음. **gz 물리 오프셋이 GPS navsat에 정상 반영됨**(우려 케이스 배제 완료).
  - ⚠️ 구현 노트: `navsat = home + gz_pos`이므로 **home은 오프셋하지 않는다**(gz 30m만). home도 함께 밀면 이중계산(60m 간격)됨 — 초기 시행착오에서 실측 확인.
- **RTF**: 3기 동시 ≈ 16~40%(부하 변동) → sim time이 wall보다 느림. 레이트/타임아웃은 **sim time(`/clock`) 기준** 권장.
- **방화벽**: 도메인별 DDS 디스커버리 포트가 표준 오프셋 `7400+250×d`(d∈{1,2,3})로 이동 → **7650 / 7900 / 8150** 대역 개방 필요 (domain 3 = 8150 포함).
- **진단**: `ros2 topic list`가 `/ap/*`를 도메인별로 가끔 누락(디스커버리 플레이크) — **판정은 `ros2 topic echo`/`hz` 실데이터 기준** (list 0개여도 echo는 정상인 사례 실측).
