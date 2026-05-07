---
name: ardu_ws 프로젝트 상태
description: ArduPilot SITL + Gazebo Harmonic + ROS2 Humble macOS ARM 마이그레이션 현황
type: project
originSessionId: 0f25ce71-2532-4c5e-a8d2-8e3b166edae7
---
macOS ARM (Apple Silicon) 에서 ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble 시뮬레이션 구축 완료.

**워크스페이스 경로:** `/Users/swjo/yonsei-ai/aerion/ardu_ws`

**현재 상태 (2026-05-07):** 이 Mac en7(유선) 200.40, 저쪽 Ubuntu 200.38 (DHCP — 매일 변동). en0(Wi-Fi)는 200.39지만 DDS 금지.
- stop_sim.sh: 1차 pkill → 2초 대기 → 2차 강제 kill(-9) + 포트 정리로 개선 (잔여 프로세스로 기체 미동작 문제 해결)
- sync_and_build.sh: 완료 시 sysctl 리마인더 출력 추가. 자동 IP 감지가 en0(Wi-Fi)을 먼저 잡을 수 있으니 주의 — DDS 바인딩은 cyclonedds.xml의 en7로 강제됨
- Gazebo Harmonic + RViz2 + ArduCopter SITL 정상 동작
- MAVProxy → UDP out: 200.38:14555
- RMW: rmw_cyclonedds_cpp
- CycloneDDS 설정: `cyclonedds.xml` (en7 유선, FragmentSize 1344B)
- `/camera/image` 1280x720 rgb8 크로스머신 전송 정상
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
- 카메라 해상도 1920x1080 → 1280x720 (2026-04-13)
- CycloneDDS FragmentSize 1344B — IP fragmentation 제거 (2026-04-10)

**GitHub:** https://github.com/swjo0330/Aerion-ardu-ws

**남은 작업:**
- Gazebo 마커/경로 표출 검토 (gz transport `/sensors/marker`)
- Aerion-Foundation 서브모듈 등록 (저쪽 push 대기)
- `iris_runway_des.sdf` src 파일도 동일하게 model:// 수정 필요 (install만 수정됨)

**Why:** Ubuntu 22.04 ROS2 Humble 환경을 macOS ARM으로 마이그레이션.
**How to apply:** 재부팅 후 → IP 확인 → sync_and_build.sh [저쪽IP] → sysctl 설정 → start_sim.sh.
