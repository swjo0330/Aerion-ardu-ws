# ardu_ws — Claude Code 작업 컨텍스트

ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble 시뮬레이션 워크스페이스 (macOS ARM 환경).
이 파일은 Claude Code가 자동 로드하는 프로젝트 컨텍스트. 세션이 바뀌거나 다른 머신에서 clone해도
이 정보로 작업을 이어갈 수 있도록 작성됨.

원본 사용자 메모리는 `.claude/memory/`에 보존되어 있음 (다른 머신에서 메모리 시스템으로 복원하려면
`.claude/RESTORE.md` 참고).

---

## 환경

- **OS:** macOS ARM (Apple Silicon)
- **Conda env:** `ros_env` (Python 3.12)
- **빌드:** colcon (homebrew protobuf 34 사용 — conda protobuf 33과 혼재 시 SIGSEGV)
- **Gazebo:** Harmonic (`GZ_VERSION=harmonic`)
- **RMW:** `rmw_cyclonedds_cpp` (Zenoh 비추천 — 카메라 이미지 전송 실패)
- **GitHub:** https://github.com/swjo0330/Aerion-ardu-ws

## 네트워크 (DHCP — 매일 변동)

- 이 Mac: **en7(유선)** 사용 필수 — DDS 통신
- Wi-Fi(`en0`)는 DDS 금지 (네트워크 포화로 대형 토픽 유실)
- 저쪽 Ubuntu IP는 매일 확인 필요 (`ip a` 또는 인자로 전달)

## 매 세션 시작 절차

1. 저쪽 Ubuntu IP 확인
2. `bash sync_and_build.sh [저쪽IP]` — cyclonedds.xml + launch.py 동기화 + 재빌드
3. 재부팅 후라면 sysctl 3종 적용 (아래)
4. `bash start_sim.sh`

```bash
sudo sysctl -w net.inet.ip.maxfragsperpacket=8192
sudo sysctl -w net.inet.udp.recvspace=8388608
sudo sysctl -w net.inet.udp.maxdgram=65535
```

저쪽(Ubuntu)에서도:
```bash
sudo sysctl -w net.ipv4.ipfrag_high_thresh=26214400
sudo sysctl -w net.ipv4.ipfrag_max_dist=0
sudo sysctl -w net.core.rmem_max=26214400
sudo sysctl -w net.core.rmem_default=26214400
```

## 주요 스크립트

- `start_sim.sh` — `CYCLONEDDS_URI=file://cyclonedds.xml`로 launch
- `stop_sim.sh` — 1차 pkill → 2초 대기 → 2차 SIGKILL + 포트 정리
- `sync_and_build.sh [IP]` — 양쪽 IP 자동 갱신 + ardupilot_sitl 재빌드
- `check_camera.sh [IP]` — `/camera/image` 전송 진단

## IP 변경 시 함께 갱신해야 하는 파일 (세트)

저쪽 Ubuntu IP가 바뀌면 **반드시 이 4가지를 한 세트로** 업데이트해야 함. `sync_and_build.sh [저쪽IP]`가 1~3을 모두 처리. 4는 수동 보정.

| # | 대상 | 변경 내용 | 비고 |
|---|------|----------|------|
| 1 | `cyclonedds.xml` | `<Peer address="[저쪽IP]"/>` | DDS 디스커버리 피어 |
| 2 | `src/ardupilot/Tools/ros2/ardupilot_sitl/src/ardupilot_sitl/launch.py` | `default_value="[저쪽IP]:14555"` | MAVProxy `--out` 기본값 (소스) |
| 3 | `install/ardupilot_sitl/lib/python3.12/site-packages/ardupilot_sitl/launch.py` | 동일 | 런타임이 읽는 파일 — `colcon build --packages-select ardupilot_sitl`로 갱신 |
| 4 | `.claude/memory/project_ardu_ws.md`, 글로벌 메모리 | `이 Mac` / `저쪽 Ubuntu` IP, `MAVProxy → UDP out: ...:14555` | 다음 세션 컨텍스트 보존용 |

**수동 업데이트 (스크립트 안 쓸 때):**
```bash
sed -i '' "s|<Peer address=\"[0-9.]*\"/>|<Peer address=\"$REMOTE_IP\"/>|" cyclonedds.xml
sed -i '' "s|default_value=\".*:14555\",|default_value=\"$REMOTE_IP:14555\",|" \
  src/ardupilot/Tools/ros2/ardupilot_sitl/src/ardupilot_sitl/launch.py
colcon build --packages-select ardupilot_sitl --cmake-args \
  "-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env" \
  -DPython3_EXECUTABLE=/Users/swjo/anaconda3/envs/ros_env/bin/python3
```

**주의:**
- `sync_and_build.sh`의 자동 IP 감지는 `10.130.x.x` 첫 매칭을 잡아서 en0(Wi-Fi)을 먼저 잡을 수 있음. DDS 바인딩은 `cyclonedds.xml`의 `NetworkInterface name="en7"`이 강제하므로 통신엔 영향 없지만, 메모리에 기록되는 "내 IP"가 Wi-Fi로 잘못 들어갈 수 있음 → 사후 보정
- 저쪽 Ubuntu에서도 자기 쪽 cyclonedds Peer를 **이 Mac의 en7 IP**로 갱신해야 양방향 디스커버리 성립

## CycloneDDS 핵심 설정 (`cyclonedds.xml`)

```xml
<NetworkInterface name="en7"/>
<MaxMessageSize>1400B</MaxMessageSize>
<FragmentSize>1344B</FragmentSize>
<Peer address="[저쪽IP]"/>
```

**왜 1400B/1344B?** 기본 `MaxMessageSize=65000B`는 MTU 1500B 네트워크에서 IP fragmentation을
유발 → 6.2MB 카메라 이미지가 재조립 실패. MTU 이하로 잡으면 RTPS fragment 수는 늘지만
IP fragmentation 자체를 회피.

**주의:**
- `Internal` 태그 robostack 0.10.x에서 미지원 (사용 시 domain 생성 실패 → 모든 노드 crash)
- `MaxMessageSize`/`FragmentSize`에 단위(`B`) 명시 필수
- 이 Mac에서 `AllowMulticast=false` 넣으면 로컬 노드 discovery 깨짐 — 생략 + Peer 방식 사용
- 저쪽 Ubuntu에서는 `AllowMulticast=false` + Peer로 이 Mac IP 지정 OK

## 빌드 cmake 옵션 (gz 관련 패키지)

```
-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env
-DPython3_ROOT_DIR=/Users/swjo/anaconda3/envs/ros_env
-DPython3_EXECUTABLE=/Users/swjo/anaconda3/envs/ros_env/bin/python3
-DBUILD_TESTING=OFF
```

homebrew를 conda보다 먼저 탐색해야 protobuf 34 호환. ardupilot_sitl 빌드는
PATH에 `Micro-XRCE-DDS-Gen/scripts` 필요 (`microxrceddsgen` 호출).

## World 파일

- 기본: `iris_runway_des.sdf` (저쪽 Ubuntu 절대경로 → `model://` 수정 완료)
- 대안: `iris_runway_des_fire.sdf`, `iris_runway_remove_object.sdf`
- 카메라: 1280x720 rgb8 (1920x1080은 대역폭 과다)
- launch 진입점: `install/ardupilot_gz_bringup/share/ardupilot_gz_bringup/launch/iris_runway.launch.py` (~79번째 줄에서 world 주석 전환)

## 트러블슈팅 진단 순서 (대형 토픽 미수신 재발 시)

1. `bash check_camera.sh [원격IP]` — 로컬 수신, 시스템 설정, 원격 전송 확인
2. 로컬 OK + 원격 NG → `ros2 topic info /camera/image --verbose`로 subscriber discovery 확인
3. subscriber 발견 + 패킷 안 나감 → RELIABLE QoS ACKNACK 문제 → `sudo tcpdump -i en7 src host <원격IP> and udp -c 20 -n`
4. 패킷 나감 + 저쪽 미수신 → IP fragmentation → `MaxMessageSize`/`FragmentSize` MTU 이하 확인
5. Wi-Fi 사용 시 → 유선(en7) 강제

## 남은 작업 (2026-05-07 기준)

- Gazebo 마커/경로 표출 검토 (`gz transport /sensors/marker`)
- Aerion-Foundation 서브모듈 등록 (저쪽 push 대기)
- `iris_runway_des.sdf` src 파일도 `model://` 수정 (install만 수정됨)

---

## Claude Code 작업 시 주의

- **메모리 동기화:** 이 파일과 `.claude/memory/`는 사용자 글로벌 메모리(`~/.claude/projects/-Users-swjo-yonsei-ai-aerion/memory/`)의 사본. 어느 쪽을 수정하든 다른 쪽도 갱신 필요
- **IP는 매일 변동:** 메모리 파일에 적힌 IP는 스냅샷일 뿐 — 실제 작업 전 `ifconfig en7`로 확인
- **destructive 명령 주의:** `git reset --hard`, `rm -rf install/build`, force-push 등은 사용자 확인 필수
