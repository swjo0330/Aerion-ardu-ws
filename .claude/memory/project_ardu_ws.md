---
name: ardu_ws 프로젝트 상태
description: ArduPilot SITL + Gazebo Harmonic + ROS2 Humble macOS ARM 마이그레이션 현황
type: project
originSessionId: 0f25ce71-2532-4c5e-a8d2-8e3b166edae7
---
macOS ARM (Apple Silicon) 에서 ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble 시뮬레이션 구축 완료.

**워크스페이스 경로:** `/Users/swjo/yonsei-ai/aerion/ardu_ws`

**현재 상태 (2026-06-11):** 이 Mac en7(유선) **10.130.200.31**, 저쪽 Ubuntu **10.130.200.39**(오늘 .32→.39 변경). NetworkInterface=en7. cyclonedds Peer/launch.py out 모두 .39로 sync_and_build 완료. 카메라 640x480, 짐벌 -20° NEUTRAL.
- 내 en7 IP 이력: .31(6/2)→.30(6/4·5)→.23(6/8)→.38(6/9)→.31(6/10·11). 저쪽: .32(6/5)→.22(6/8)→.39(6/9)→.32(6/10)→.39(6/11). (IP 매일 변동, en7 이름 바인딩이라 내 쪽 무관, 저쪽 바뀌면 sync_and_build [저쪽IP])
- ⚠️ sync_and_build.sh 자동 IP 감지가 매번 다른 NIC(.21/.31 등) 잡음 — 실제 en7 IP를 ipconfig getifaddr en7로 확인해 사후 보정. DDS는 en7 이름 바인딩이라 통신 무관.
- cyclonedds는 en7 이름 바인딩 + Peer는 저쪽IP. 저쪽 IP 바뀌면 `sync_and_build.sh [저쪽IP]` 필요(오늘 실행함). 단 **저쪽도 자기 Peer를 내 en7 IP(10.130.200.30)로** 갱신해야 양방향 성립.
- ⚠️ sync_and_build.sh 자동 IP 감지가 en0 등 다른 NIC의 .22를 먼저 잡음 — 실제 en7은 .23. DDS는 NetworkInterface en7로 강제되니 통신 무관, 메모리만 .23으로 사후 보정.
- ⚠️ 저쪽(.27)에서도 자기 cyclonedds Peer를 이 Mac en7 IP인 **10.130.200.23**으로 설정해야 양방향 디스커버리 성립.
- 관측: ROS2 그래프에 `/fmu/in|out/*`(PX4 uXRCE-DDS) 토픽이 보임 → 저쪽이 PX4 SITL을 돌리는 중. 우리 ArduPilot은 `/range`, `/camera` 등.
- sync_and_build.sh 자동 IP 감지가 또 다른 인터페이스(.31)를 잡았음 — 결과적으로 메모리에 잘못 기록될 수 있으니 en7 실제 IP로 사후 보정. DDS 바인딩 자체는 en7로 강제됨.

**집 환경 시도 이력 (2026-05-08):** en0(Wi-Fi) + 192.168.45.50/45.93 조합으로 띄움. SITL/Gazebo/MAVProxy는 정상 기동(EKF3 init, DDS init passed)했지만 실사용 시 양쪽 통신 안 됨. 원인 미확인 — Wi-Fi 라우터 broadcast 차단/AP isolation 의심. 추후 집에서 재시도하려면 NIC/방화벽/라우터 격리 설정 점검 필요.
- stop_sim.sh: 1차 pkill → 2초 대기 → 2차 강제 kill(-9) + 포트 정리로 개선 (잔여 프로세스로 기체 미동작 문제 해결)
- sync_and_build.sh: 완료 시 sysctl 리마인더 출력 추가. 자동 IP 감지가 en0(Wi-Fi)을 먼저 잡을 수 있으니 주의 — DDS 바인딩은 cyclonedds.xml의 en7로 강제됨
- Gazebo Harmonic + RViz2 + ArduCopter SITL 정상 동작
- MAVProxy → UDP out: 10.130.200.27:14555
- RMW: rmw_cyclonedds_cpp
- CycloneDDS 설정: `cyclonedds.xml` (en7 유선, FragmentSize 1344B)
- `/camera/image` 640x480 rgb8 (2026-05-13 변경, 이전 1280x720) 크로스머신 전송 정상
- World: `iris_runway_des.sdf` (기본, 저쪽 Ubuntu 절대경로 → model:// 수정 완료)
- World 대안: `iris_runway_des_fire.sdf`, `iris_runway_remove_object.sdf`

**네트워크 (DHCP, 매일 변동):**
- 이 Mac: en7(유선) 사용 필수 — DDS 통신
- Wi-Fi(en0)는 DDS 금지 (네트워크 포화)
- 저쪽 IP는 매일 확인 필요 (`ip a` 또는 `sync_and_build.sh [저쪽IP]`)

**시작 전 필수 (재부팅 시 재설정):**
```bash
sudo sysctl -w net.inet.ip.maxfragsperpacket=8192
sudo sysctl -w net.inet.udp.recvspace=8388608
sudo sysctl -w net.inet.udp.maxdgram=65535
```

**IP 변경 시 — sync_and_build.sh 사용:**
```bash
bash sync_and_build.sh [저쪽IP]
```
이 스크립트가 한 번에 처리:
1. `cyclonedds.xml` Peer address 업데이트
2. `install/ardupilot_sitl/.../launch.py` MAVProxy out IP:14555 업데이트
3. 메모리 파일 업데이트
4. ardupilot_sitl 재빌드

**수동 업데이트 시:**
1. `cyclonedds.xml` → `<Peer address="[저쪽IP]"/>`
2. `install/ardupilot_sitl/lib/python3.12/site-packages/ardupilot_sitl/launch.py` → `default_value="[저쪽IP]:14555"`

**CycloneDDS 설정 (`cyclonedds.xml`):**
```xml
<NetworkInterface name="en7"/>
<MaxMessageSize>1400B</MaxMessageSize>
<FragmentSize>1344B</FragmentSize>
<Peer address="[저쪽IP]"/>
```

**주요 스크립트:**
- `start_sim.sh` — CYCLONEDDS_URI=file://cyclonedds.xml + launch
- `stop_sim.sh` — 전체 종료
- `sync_and_build.sh [IP]` — IP 동기화 (cyclonedds.xml + launch.py) + 재빌드
- `check_camera.sh [IP]` — /camera/image 전송 진단

**World 파일 경로:**
`install/ardupilot_gz_bringup/share/ardupilot_gz_bringup/launch/iris_runway.launch.py`
(79번째 줄 근처에서 world 파일 주석 전환)

**수정 이력:**
- `iris_runway_des.sdf` — 저쪽 Ubuntu 절대경로(`file:///home/clrobur/...`) → `model://` 수정 완료 (2026-04-14)
- 카메라 해상도 1920x1080 → 1280x720 (2026-04-13) → 640x480 (2026-05-13). 토글 위치: `src/ardupilot_gazebo/models/gimbal_small_3d/model.sdf` + `install/...gimbal_small_3d/model.sdf` 두 파일 모두 — install이 가제보가 실제 읽는 파일
- CycloneDDS FragmentSize 1344B — IP fragmentation 제거 (2026-04-10)

**GitHub:** https://github.com/swjo0330/Aerion-ardu-ws

**path_marker 패키지 (2026-06-10 작성·빌드 완료):** `src/path_marker/` — `/replan_path_enu`(nav_msgs/Path, ENU map) 구독 → Gazebo `/marker` 서비스로 LINE_STRIP(주황, ns="replan_path" id=1) 실시간 표출. 새 경로 교체, 빈 Path면 DELETE, lifetime 5s 자동소멸. C++ ament_cmake, **gz-transport13 + gz-msgs10**(Harmonic, msgs9 아님). ros_gz_bridge는 Marker 미지원이라 gz-transport 직접 Request. 빌드: `colcon build --packages-select path_marker --cmake-args "-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env"`. **재시작 파이프라인에 통합됨(2026-06-10): `start_sim.sh`가 `ros2 run path_marker path_marker_node &`로 자동 기동, `stop_sim.sh`가 pkill path_marker_node로 종료.** 수동 실행도 가능(`ros2 run path_marker path_marker_node`, 안 잡히면 묵은 ros2 daemon kill — [[ros2-daemon]]). `/marker` 서비스·노드 기동 검증 완료. **선결조건: 저쪽이 `/replan_path_enu`(nav_msgs/Path, ENU, 원점=gz world원점=iris스폰) 발행해야 그릴 게 생김 — 현재 미발행(`/replan_waypoints`는 ec_edge_msgs 커스텀이라 .31서 구독 불가).** frame 원점 어긋나면 테스트마커로 오프셋 확인.

**남은 작업:**
- 저쪽 `/replan_path_enu` 발행 시작 → path_marker_node로 실시간 표출 검증 (시뮬+sim 띄운 상태)
- Aerion-Foundation 서브모듈 등록 (저쪽 push 대기)
- `iris_runway_des.sdf` src 파일도 동일하게 model:// 수정 필요 (install만 수정됨)

**Why:** Ubuntu 22.04 ROS2 Humble 환경을 macOS ARM으로 마이그레이션.
**How to apply:** 재부팅 후 → IP 확인 → sync_and_build.sh [저쪽IP] → sysctl 설정 → start_sim.sh.
