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

### 5. 실행 / 종료

```bash
bash start_sim.sh               # iris_runway (기본)
bash start_sim.sh iris_maze.launch.py   # iris_maze
bash stop_sim.sh                # 종료
```

---

## 네트워크 설정

- **MAVLink UDP out**: `sync_and_build.sh`로 대상 IP 변경 및 재빌드
- **ROS2 외부 구독자** (CycloneDDS): 구독자 측에 아래 설정 적용
  ```bash
  export CYCLONEDDS_URI='<CycloneDDS><Domain><General><AllowMulticast>false</AllowMulticast></General><Discovery><Peers><Peer address="[이 Mac IP]"/></Peers></Discovery></Domain></CycloneDDS>'
  ```

---

## 상세 가이드

[SETUP_MAC_ARM.md](SETUP_MAC_ARM.md) 참고
