# ArduPilot GZ SITL — macOS ARM (Apple Silicon) 셋업 가이드

이 문서는 `ardu_ws`를 새 M1/M2/M3 Mac에서 처음부터 재현하기 위한 완전한 절차입니다.

---

## 0. 전제 조건

- macOS (Apple Silicon, arm64)
- Homebrew 설치됨 (`/opt/homebrew`)
- Anaconda 또는 Miniconda 설치됨 (`~/anaconda3` 또는 `~/miniconda3`)
- Xcode Command Line Tools: `xcode-select --install`

---

## 1. Homebrew 의존성 설치

```bash
# Gazebo Harmonic
brew tap osrf/simulation
brew install osrf/simulation/gz-harmonic

# 기타 의존성
brew install cmake openjdk gpsd protobuf
```

> **주의**: gz-harmonic은 `protobuf 34.x`를 사용합니다. conda의 protobuf(33.x)와 버전이 다르지만,
> colcon 빌드 시 `-DCMAKE_PREFIX_PATH=/opt/homebrew;...` 로 homebrew를 우선 탐색하여 해결합니다.

---

## 2. conda 환경 생성 (ros_env)

```bash
conda create -n ros_env python=3.12
conda activate ros_env

# ROS2 Humble (robostack)
conda install mamba -c conda-forge
mamba install -c robostack-humble ros-humble-desktop

# 추가 ROS 패키지
conda install -c robostack-humble \
  ros-humble-actuator-msgs \
  ros-humble-vision-msgs \
  ros-humble-gps-msgs \
  ros-humble-topic-tools

# 빌드 도구
conda install -c conda-forge colcon-common-extensions vcstool

# Python 유틸
pip install mavproxy future pexpect
```

---

## 3. 워크스페이스 소스 준비

```bash
mkdir -p ~/ardu_ws/src
cd ~/ardu_ws

# ardupilot_gz repos
vcs import --input src/ardupilot_gz/ros2_gz_macos.repos src --skip-existing
```

> `src/` 디렉토리를 통째로 복사해온 경우 이 단계는 생략.

---

## 4. ArduCopter SITL 빌드 (macOS arm64)

```bash
cd ~/ardu_ws/src/ardupilot

# 기존 Linux/CubeBlack 빌드 캐시 제거
rm -rf build/CubeBlack build/MatekH743
rm -f c4che/CubeBlack_cache.py c4che/MatekH743_cache.py 2>/dev/null

# macOS용 SITL 빌드
conda run -n ros_env bash -c "
  cd ~/ardu_ws/src/ardupilot
  ./waf configure --board sitl
  ./waf copter
"
```

빌드 결과: `build/sitl/bin/arducopter` (Mach-O 64-bit executable arm64)

---

## 5. 필수 패치 적용

### 5-1. rosidl_generator_py — Python 경로 고정

```bash
ROSIDL_CMAKE=~/anaconda3/envs/ros_env/share/rosidl_generator_py/cmake/rosidl_generator_py_generate_interfaces.cmake
```

`find_package(PythonExtra REQUIRED)` 다음 `find_package(Python ...)` 호출 직전(else 블록 안)에 아래 두 줄 추가:

```cmake
set(Python_ROOT_DIR "$ENV{HOME}/anaconda3/envs/ros_env" CACHE PATH "" FORCE)
set(Python_EXECUTABLE "$ENV{HOME}/anaconda3/envs/ros_env/bin/python3" CACHE FILEPATH "" FORCE)
```

> cmake가 Homebrew Python을 잘못 찾는 문제 해결. 경로는 실제 conda 설치 위치에 맞게 수정.

### 5-2. gz-msgs10 — TINYXML2 cmake 타겟 수정

```bash
TARGETS_FILE=/opt/homebrew/lib/cmake/gz-msgs10/gz-msgs10-targets.cmake
```

`INTERFACE_LINK_LIBRARIES` 에서 `TINYXML2::TINYXML2` → `/opt/homebrew/lib/libtinyxml2.dylib` 로 교체:

```cmake
# 변경 전
INTERFACE_LINK_LIBRARIES "gz-math7::gz-math7;TINYXML2::TINYXML2;protobuf::libprotobuf"
# 변경 후
INTERFACE_LINK_LIBRARIES "gz-math7::gz-math7;/opt/homebrew/lib/libtinyxml2.dylib;protobuf::libprotobuf"
```

### 5-3. sdformat_urdf — urdfdom_headers 버전 제약 제거

`src/sdformat_urdf/sdformat_urdf/CMakeLists.txt`:

```cmake
# 변경 전
find_package(urdfdom_headers 1.0.6 REQUIRED)
# 변경 후
find_package(urdfdom_headers REQUIRED)
```

### 5-4. iris_runway_des_fire.sdf — 하드코딩된 Ubuntu 경로 수정

`src/ardupilot_gz/ardupilot_gz_gazebo/worlds/iris_runway_des_fire.sdf`:

```xml
<!-- 변경 전 -->
<uri>file:///home/clrobur/ardu_ws/install/ardupilot_gazebo/share/ardupilot_gazebo/models/runway</uri>
<uri>file:///home/clrobur/ardu_ws/install/ardupilot_gazebo/share/ardupilot_gazebo/models/iris_with_gimbal</uri>

<!-- 변경 후 -->
<uri>model://runway</uri>
<uri>model://iris_with_gimbal</uri>
```

`tethys_equipped` include 블록은 주석 처리 (해당 모델 없음).

---

## 6. colcon 빌드

```bash
cd ~/ardu_ws

# WORKSPACE를 실제 경로로 치환
WORKSPACE=$HOME/ardu_ws
PYTHON=$HOME/anaconda3/envs/ros_env/bin/python3

conda run -n ros_env bash -c "
export GZ_VERSION=harmonic
export PKG_CONFIG_PATH=/opt/homebrew/lib/pkgconfig:\$PKG_CONFIG_PATH
export PATH=/opt/homebrew/opt/openjdk/bin:$WORKSPACE/Micro-XRCE-DDS-Gen/scripts:/opt/homebrew/bin:\$PATH

cd $WORKSPACE
colcon build \
  --cmake-args \
    -DGZ_VERSION=harmonic \
    -DPython3_EXECUTABLE=$PYTHON \
    -DPYTHON_EXECUTABLE=$PYTHON \
    -DPython3_ROOT_DIR=$HOME/anaconda3/envs/ros_env \
    '-DCMAKE_PREFIX_PATH=/opt/homebrew;$HOME/anaconda3/envs/ros_env' \
    -DBUILD_TESTING=OFF \
  --packages-skip ardupilot ros_ign_interfaces ros_ign_gazebo \
  2>&1
"
```

> 빌드 완료 후 `install/` 디렉토리 생성됨.

---

## 7. micro_ros_agent spdlog 패치

빌드 완료 후 spdlog가 fmt 12와 호환되지 않는 문제를 패치:

`install/micro_ros_agent/include/spdlog/common.h` 의 `is_convertible_to_basic_format_string` 구조체에서
`std::is_same<remove_cvref_t<T>, fmt::basic_runtime<Char>>::value` 조건 제거:

```cpp
// 변경 후
template<class T, class Char = char>
struct is_convertible_to_basic_format_string
    : std::integral_constant<bool,
          std::is_convertible<T, fmt::basic_string_view<Char>>::value>
{};
```

---

## 8. 실행

```bash
# 환경 설정 + 실행
bash ~/ardu_ws/start_sim.sh

# 또는 maze 월드
bash ~/ardu_ws/start_sim.sh iris_maze.launch.py

# 종료
bash ~/ardu_ws/stop_sim.sh
```

---

## 트러블슈팅 요약

| 증상 | 원인 | 해결 |
|------|------|------|
| `Could NOT find Python` (cmake) | cmake가 Homebrew Python 탐색 | rosidl_generator_py cmake 패치 (§5-1) |
| `TINYXML2::TINYXML2` not found | gz-msgs10 cmake 타겟 없음 | gz-msgs10-targets.cmake 패치 (§5-2) |
| `urdfdom_headers 1.0.6` not found | 시스템에 2.1.0 설치됨 | CMakeLists.txt 버전 제약 제거 (§5-3) |
| `create` / `parameter_bridge` SIGSEGV | protobuf 33 vs 34 충돌 | `CMAKE_PREFIX_PATH=/opt/homebrew` 우선 빌드 |
| Gazebo server SIGSEGV | ardupilot_gazebo 플러그인이 protobuf 33 로드 | ardupilot_gazebo 재빌드 (homebrew prefix) |
| `Unable to find uri[file:///home/clrobur/...]` | SDF에 Ubuntu 절대경로 하드코딩 | model:// URI로 교체 (§5-4) |
| `fmt::basic_runtime` 컴파일 에러 | fmt 12에서 제거된 API | spdlog/common.h 패치 (§7) |
| `address already in use` (port 5760/2019) | 이전 프로세스 잔류 | `stop_sim.sh` 실행 |
