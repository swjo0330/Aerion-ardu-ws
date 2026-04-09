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

### 공유되는 토픽

| 발행측 | 토픽 | 설명 |
|--------|------|------|
| SITL Mac (.35) | `/camera/image`, `/camera/camera_info` | Gazebo 카메라 |
| SITL Mac (.35) | `/imu`, `/navsat`, `/odometry`, `/air_pressure` | 센서 데이터 |
| SITL Mac (.35) | `/magnetometer`, `/battery` | 추가 센서 |
| SITL Mac (.35) | `/ap/*` | ArduPilot DDS (micro_ros_agent) |
| 원격 PC (.33) | `/mavros/*` | MAVProxy → MAVROS |
| 원격 PC (.33) | `/a2a/*`, `/vision/*`, `/perception/*` | 에이전트/비전 |

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
