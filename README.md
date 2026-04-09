# Aerion-ardu-ws

ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble simulation stack, ported to **macOS ARM (Apple Silicon)**.

Ubuntu 22.04 환경의 시뮬레이션을 M1/M2/M3 Mac에서 네이티브로 실행하기 위한 설정 및 패치 모음입니다.

---

## 구성

```
Aerion-ardu-ws/
├── start_sim.sh          # 시뮬레이션 실행
├── stop_sim.sh           # 시뮬레이션 종료
├── sync_and_build.sh     # IP 동기화 + 재빌드
├── setup_mac.sh          # 환경 변수 설정 (source용)
├── ardu_ws.repos         # 외부 패키지 선언 (vcs import)
├── zenoh_router.json5    # Zenoh 라우터 설정 (참고용)
├── zenoh_session.json5   # Zenoh 세션 설정 (참고용)
├── patches/              # macOS ARM 호환성 패치 모음
└── SETUP_MAC_ARM.md      # 새 Mac 재현 가이드
```

---

## 실행 환경

| 항목 | 내용 |
|------|------|
| OS | macOS ARM (Apple Silicon) |
| 시뮬레이터 | Gazebo Harmonic (gz-sim 8.11.0) |
| ROS2 | Humble (robostack conda) |
| 비행체 | ArduCopter SITL (arm64 네이티브) |
| RMW | CycloneDDS (rmw_cyclonedds_cpp) |
| Python | 3.12 (conda ros_env) |

---

## 빠른 시작

### 1. 의존성 설치

```bash
# Homebrew
brew tap osrf/simulation
brew install osrf/simulation/gz-harmonic cmake openjdk gpsd protobuf

# conda 환경
conda create -n ros_env python=3.12
conda activate ros_env
mamba install -c robostack-humble ros-humble-desktop
conda install -c robostack-humble \
  ros-humble-actuator-msgs ros-humble-vision-msgs \
  ros-humble-gps-msgs ros-humble-topic-tools
conda install -c conda-forge colcon-common-extensions vcstool
pip install mavproxy future pexpect
```

### 2. 소스 클론 및 패치 적용

```bash
mkdir -p ~/ardu_ws/src
cd ~/ardu_ws

# 이 repo 클론
git clone https://github.com/swjo0330/Aerion-ardu-ws.git .

# 외부 패키지 클론
vcs import --input ardu_ws.repos src --skip-existing

# 패치 적용
cd src/ardupilot       && git apply ../../patches/ardupilot_sitl_launch.patch && cd ../..
cd src/ardupilot_gazebo && git apply ../../patches/ardupilot_gazebo.patch && cd ../..
cd src/ardupilot_gz    && git apply ../../patches/ardupilot_gz.patch && cd ../..
cd src/micro_ros_agent && git apply ../../patches/micro_ros_agent.patch && cd ../..
cd src/sdformat_urdf   && git apply ../../patches/sdformat_urdf.patch && cd ../..

# 새 SDF 월드 파일 복사
cp patches/iris_runway_des.sdf         src/ardupilot_gz/ardupilot_gz_gazebo/worlds/
cp patches/iris_runway_des_fire.sdf    src/ardupilot_gz/ardupilot_gz_gazebo/worlds/
cp patches/iris_runway_remove_object.sdf src/ardupilot_gz/ardupilot_gz_gazebo/worlds/
cp patches/iris.launch2.py             src/ardupilot_gz/ardupilot_gz_bringup/launch/robots/
```

### 3. ArduCopter SITL 빌드

```bash
cd ~/ardu_ws/src/ardupilot
conda run -n ros_env bash -c "./waf configure --board sitl && ./waf copter"
```

### 4. IP 동기화 및 빌드

```bash
cd ~/ardu_ws
bash sync_and_build.sh [MAVLink_out_target_ip]
```

> **참고**: PATH에 `Micro-XRCE-DDS-Gen/scripts`가 포함되어야 합니다. `start_sim.sh`가 자동 설정합니다.

### 5. 실행 / 종료

```bash
bash start_sim.sh               # iris_runway (기본)
bash start_sim.sh iris_maze.launch.py   # iris_maze
bash stop_sim.sh                # 종료
```

---

## 네트워크 설정

### MAVLink UDP out

`sync_and_build.sh`로 대상 IP 변경 및 재빌드:

```bash
bash sync_and_build.sh 10.130.200.33
```

### 크로스머신 ROS2 토픽 공유 (CycloneDDS 유니캐스트)

이 Mac과 원격 PC 간 CycloneDDS 유니캐스트 피어 방식으로 토픽을 공유합니다.

**이 Mac (SITL PC, .35) — `start_sim.sh`에 자동 적용:**

```xml
<CycloneDDS><Domain>
  <General>
    <Interfaces><NetworkInterface name="en0"/></Interfaces>
  </General>
  <Discovery>
    <Peers><Peer address="10.130.200.33"/></Peers>
  </Discovery>
</Domain></CycloneDDS>
```

- 멀티캐스트 유지 (로컬 노드 discovery 정상) + 원격 피어 추가

**원격 PC (.33) — 해당 터미널에서 export:**

```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><AllowMulticast>false</AllowMulticast></General><Discovery><Peers><Peer address="10.130.200.35"/></Peers></Discovery></Domain></CycloneDDS>'
```

> **주의**: 이 Mac에서 `AllowMulticast=false`를 설정하면 로컬 노드끼리 discovery 실패합니다. 절대 추가하지 마세요.

### 토픽 목록

전체 토픽 목록은 [TOPICS.md](TOPICS.md) 참고

---

_아래는 README 내 요약 (상세는 TOPICS.md)_

### SITL Mac (.35) 발행 토픽

ArduPilot SITL + Gazebo + ros_gz_bridge에서 생성하는 토픽:

**ArduPilot DDS (micro_ros_agent)**
| 토픽 | 타입 | 설명 |
|------|------|------|
| `/ap/airspeed` | | 대기속도 |
| `/ap/battery` | | 배터리 상태 |
| `/ap/clock` | | ArduPilot 시계 |
| `/ap/cmd_gps_pose` | | GPS 위치 명령 (구독) |
| `/ap/cmd_vel` | | 속도 명령 (구독) |
| `/ap/geopose/filtered` | | 필터링된 지오포즈 |
| `/ap/goal_lla` | | 목표 위경도고도 (구독) |
| `/ap/gps_global_origin/filtered` | | GPS 원점 |
| `/ap/imu/experimental/data` | | IMU 데이터 |
| `/ap/joy` | | 조이스틱 (구독) |
| `/ap/navsat` | | GPS NavSat |
| `/ap/pose/filtered` | | 필터링된 포즈 |
| `/ap/status` | | 비행 상태 |
| `/ap/tf` | | TF |
| `/ap/tf_static` | | 정적 TF |
| `/ap/time` | | 시간 |
| `/ap/twist/filtered` | | 필터링된 속도 |

**ros_gz_bridge (Gazebo → ROS2)**
| 토픽 | 타입 | 설명 |
|------|------|------|
| `/camera/image` | `sensor_msgs/Image` | 짐벌 카메라 영상 |
| `/camera/camera_info` | `sensor_msgs/CameraInfo` | 카메라 정보 |
| `/imu` | `sensor_msgs/Imu` | IMU 센서 |
| `/navsat` | `sensor_msgs/NavSatFix` | GPS |
| `/odometry` | `nav_msgs/Odometry` | 오도메트리 |
| `/air_pressure` | `sensor_msgs/FluidPressure` | 기압 |
| `/magnetometer` | `sensor_msgs/MagneticField` | 지자기 |
| `/battery` | `sensor_msgs/BatteryState` | 배터리 |
| `/clock` | `rosgraph_msgs/Clock` | 시뮬레이션 시계 |
| `/joint_states` | `sensor_msgs/JointState` | 관절 상태 |
| `/gz/tf` | `tf2_msgs/TFMessage` | Gazebo TF |
| `/gz/tf_static` | `tf2_msgs/TFMessage` | Gazebo 정적 TF |

**기타 (robot_state_publisher, relay, rviz2)**
| 토픽 | 설명 |
|------|------|
| `/robot_description` | URDF 모델 |
| `/tf`, `/tf_static` | ROS TF 트리 |

### 전체 토픽 리스트 (양쪽 합산)

양쪽 CycloneDDS 연결 시 보이는 전체 토픽 (2026-04-09 확인):

<details>
<summary>토픽 전체 목록 (펼치기)</summary>

```
/a2a/drone1/decision
/a2a/drone1/mission_command
/air_pressure
/ap/airspeed
/ap/battery
/ap/clock
/ap/cmd_gps_pose
/ap/cmd_vel
/ap/geopose/filtered
/ap/goal_lla
/ap/gps_global_origin/filtered
/ap/imu/experimental/data
/ap/joy
/ap/navsat
/ap/pose/filtered
/ap/status
/ap/tf
/ap/tf_static
/ap/time
/ap/twist/filtered
/battery
/camera/camera_info
/camera/image
/clicked_point
/clock
/diagnostics
/goal_pose
/gz/tf
/gz/tf_static
/imu
/initialpose
/joint_states
/magnetometer
/mavros/adsb/send
/mavros/adsb/vehicle
/mavros/battery
/mavros/cam_imu_sync/cam_imu_stamp
/mavros/camera/image_captured
/mavros/cellular_status/status
/mavros/companion_process/status
/mavros/esc_status/info
/mavros/esc_status/status
/mavros/esc_telemetry/telemetry
/mavros/estimator_status
/mavros/extended_state
/mavros/fake_gps/mocap/pose
/mavros/geofence/fences
/mavros/gimbal_control/device/attitude_status
/mavros/gimbal_control/device/info
/mavros/gimbal_control/device/set_attitude
/mavros/gimbal_control/manager/info
/mavros/gimbal_control/manager/set_attitude
/mavros/gimbal_control/manager/set_manual_control
/mavros/gimbal_control/manager/set_pitchyaw
/mavros/gimbal_control/manager/status
/mavros/global_position/compass_hdg
/mavros/global_position/global
/mavros/global_position/gp_lp_offset
/mavros/global_position/gp_origin
/mavros/global_position/local
/mavros/global_position/raw/fix
/mavros/global_position/raw/gps_vel
/mavros/global_position/raw/satellites
/mavros/global_position/rel_alt
/mavros/global_position/set_gp_origin
/mavros/gps_input/gps_input
/mavros/gps_rtk/rtk_baseline
/mavros/gps_rtk/send_rtcm
/mavros/gpsstatus/gps1/raw
/mavros/gpsstatus/gps1/rtk
/mavros/gpsstatus/gps2/raw
/mavros/gpsstatus/gps2/rtk
/mavros/home_position/home
/mavros/home_position/set
/mavros/imu/data
/mavros/imu/data_raw
/mavros/imu/diff_pressure
/mavros/imu/mag
/mavros/imu/static_pressure
/mavros/imu/temperature_baro
/mavros/imu/temperature_imu
/mavros/landing_target/lt_marker
/mavros/landing_target/pose
/mavros/landing_target/pose_in
/mavros/local_position/accel
/mavros/local_position/odom
/mavros/local_position/pose
/mavros/local_position/pose_cov
/mavros/local_position/velocity_body
/mavros/local_position/velocity_body_cov
/mavros/local_position/velocity_local
/mavros/log_transfer/raw/log_data
/mavros/log_transfer/raw/log_entry
/mavros/mag_calibration/report
/mavros/mag_calibration/status
/mavros/manual_control/control
/mavros/manual_control/send
/mavros/mission/reached
/mavros/mission/waypoints
/mavros/mocap/pose
/mavros/mocap/tf
/mavros/mount_control/command
/mavros/mount_control/orientation
/mavros/mount_control/status
/mavros/nav_controller_output/output
/mavros/obstacle/send
/mavros/odometry/in
/mavros/odometry/out
/mavros/onboard_computer/status
/mavros/optical_flow/ground_distance
/mavros/optical_flow/raw/optical_flow
/mavros/optical_flow/raw/send
/mavros/param/event
/mavros/play_tune
/mavros/radio_status
/mavros/rallypoint/rallypoints
/mavros/rangefinder/rangefinder
/mavros/rangefinder_pub
/mavros/rangefinder_sub
/mavros/rc/in
/mavros/rc/out
/mavros/rc/override
/mavros/setpoint_accel/accel
/mavros/setpoint_attitude/cmd_vel
/mavros/setpoint_attitude/thrust
/mavros/setpoint_position/global
/mavros/setpoint_position/global_to_local
/mavros/setpoint_position/local
/mavros/setpoint_raw/attitude
/mavros/setpoint_raw/global
/mavros/setpoint_raw/local
/mavros/setpoint_raw/target_attitude
/mavros/setpoint_raw/target_global
/mavros/setpoint_raw/target_local
/mavros/setpoint_trajectory/desired
/mavros/setpoint_trajectory/local
/mavros/setpoint_velocity/cmd_vel
/mavros/setpoint_velocity/cmd_vel_unstamped
/mavros/state
/mavros/status_event
/mavros/statustext/recv
/mavros/statustext/send
/mavros/sys_status
/mavros/terrain/report
/mavros/time_reference
/mavros/timesync_status
/mavros/trajectory/desired
/mavros/trajectory/generated
/mavros/trajectory/path
/mavros/tunnel/in
/mavros/tunnel/out
/mavros/vfr_hud
/mavros/vision_pose/pose
/mavros/vision_pose/pose_cov
/mavros/vision_speed/speed_twist
/mavros/vision_speed/speed_twist_cov
/mavros/vision_speed/speed_vector
/mavros/wind_estimation
/move_base_simple/goal
/navsat
/odometry
/parameter_events
/perception/state
/replan_waypoints
/robot_description
/rosout
/tf
/tf_static
/uas1/mavlink_sink
/uas1/mavlink_source
/vision/detect_frame
/vision/detect_information
/vision/detect_target
/vision/target_data
```

</details>

---

## 빌드 주의사항

### colcon cmake 옵션 (gz 관련 패키지)

```bash
colcon build --packages-select <패키지> \
  --cmake-args \
    -DCMAKE_PREFIX_PATH='/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env' \
    -DPython3_ROOT_DIR='/Users/swjo/anaconda3/envs/ros_env' \
    -DPython3_EXECUTABLE='/Users/swjo/anaconda3/envs/ros_env/bin/python3' \
    -DBUILD_TESTING=OFF
```

- homebrew protobuf 34가 conda protobuf 33보다 먼저 탐색되어야 함
- 혼재 시 `parameter_bridge` SIGSEGV 발생

---

## Zenoh RMW (참고)

rmw_zenoh_cpp를 시도했으나 카메라 이미지(~1-2MB) 전송 실패로 CycloneDDS로 복귀했습니다.

- `zenoh_router.json5` — 로컬 zenohd 라우터 설정 (batch_size 16MB)
- `zenoh_session.json5` — ROS2 노드 세션 설정 (client 모드)
- 올바른 환경변수: `ZENOH_ROUTER_CONFIG_URI`, `ZENOH_SESSION_CONFIG_URI` (`RMW_` 접두사 없음)

---

## 상세 가이드

[SETUP_MAC_ARM.md](SETUP_MAC_ARM.md) 참고
