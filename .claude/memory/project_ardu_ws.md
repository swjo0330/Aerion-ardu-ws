---
name: ardu_ws 프로젝트 상태
description: ArduPilot SITL + Gazebo Harmonic + ROS2 Humble macOS ARM 마이그레이션 현황
type: project
originSessionId: 0f25ce71-2532-4c5e-a8d2-8e3b166edae7
---
macOS ARM (Apple Silicon) 에서 ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble 시뮬레이션 구축 완료.

**워크스페이스 경로:** `/Users/swjo/yonsei-ai/aerion/ardu_ws`

**⚠️ git 구조 함정 (2026-07-09):** `src/ardupilot*`·`src/ardupilot_gz`·`src/ros_gz` 등은 `.repos`로 관리되는 **중첩 git repo**(각자 .git) + `.gitignore`로 제외됨 → 그 안에 손수 파일 넣어도 부모(Aerion-ardu-ws)가 추적 못 함(`git add -f`도 실패). **멀티 SITL 손수 launch 정본은 `multi_src/launch/`(추적 가능)에 두고 `gen_multi_assets.sh`가 src·install 양 트리로 배포**한다. clean clone 재현 = `.repos` 복원 → `gen_multi_assets.sh` 1회. (모델/월드/브리지/parm은 gen이 단일모드 파일에서 파생하니 추적 불필요, launch 2개만 정본 추적.) 두 GitHub repo: 내부=`swjo0330/Aerion-ardu-ws`(gh 계정 seongwon-jo, collaborator push OK), 공유=`swjo0330/Aerion-integration`(팀 문서 허브, `docs/sim/gazebo/`에 연동 규격 push함, CONTRIBUTING: 담당폴더 직push+pull --rebase).

**현재 상태 (2026-07-10, 집/Wi-Fi):** 이 Mac **en0 192.168.45.50**, 저쪽 맥북 Peer **192.168.45.93**. **NetworkInterface=en0으로 수동 전환됨** — ⚠️ 랩 복귀 시 en7 복원 + `sync_and_build.sh [랩 저쪽IP]` 필수 (sync 스크립트는 인터페이스 안 건드림). sysctl 유지. 크로스머신 480p 6.5Hz 실측 성공(아래 집 환경 절). Tailscale류 VPN 인터페이스(100.122.97.10) 존재 — sync 스크립트 IP 자동감지가 이걸 잡을 수 있으니 감지값 무시하고 en0/en7 실측 기준.

**하네스 도입 완료 (2026-07-09):** ardu_ws 루트에 파일 하네스 배치 — CLAUDE.md(§구조 재작성, 구본은 git HEAD)·AGENTS.md(아키텍처 정본, 구본은 .pre-harness.bak)·FABLE5.md·EXPERIMENTS.md(검증 트랙 T1~T4)·implementation-notes.md(5태그 원장)·Docs/RULES.md(상세 규칙 하강)·memory/ 2종(AKC v3 병합, 5-저장소 토폴로지). 세션 재시작 읽기 순서와 종료 체크리스트는 ardu_ws/memory/session-restart-protocol.md 정본.

**멀티 SITL 3인스턴스 (2026-07-09, T3 완료):** 설계 정본 `Docs/specs/2026-07-09-multi-sitl-3instance-design.md` (F1~F16 근거·D1~D10 결정·A1~A9 산출물). **2기 수직 슬라이스 전 게이트 통과**: DDS 도메인 d=i+1 분리 실증 — d1={/drone1/* + /ap/*}, d2={/drone2/* + /ap/*}, 교차 오염 0, EKF3×2. 신규 파이프라인: `gen_multi_assets.sh`(모델/월드/브리지/parm 파생 — 변형 전환 후 재실행) → `start_multi_sim.sh [기수]` / `stop_multi_sim.sh`. 인스턴스 cwd=multi/i{0,1,2}(eeprom 분리). **핵심 함정 3개**: ①멀티 모델은 lock_step=0 필수(1이면 RTF 0.2% 스톨 실측) ②RTF 저하로 EKF 부팅에 wall 수 분 — 시그니처 대기 60s로는 부족 ③`ros2 topic list`의 /ap 열거는 도메인별 플레이크 있음 — 판정은 `ros2 topic echo` 실데이터 기준. **leaf(d2/d3) 무카메라 확정**(사용자): 카메라·YOLO=본기 d1만, S-5 감독은 NATS 상태 스트림 기반. **✅ 3기 실기동 검증 완료(2026-07-09)**: DDS 3/3·EKF3 3/3·RTF≈40%·3도메인 독립(오염 0)·d2/d3 /ap/time 실데이터. 잔여: 저쪽 3인스턴스(mavros×3, ROS_DOMAIN_ID 1/2/3) 수신 검증(저쪽 관할).

**RViz 카메라 표시 (2026-07-13):** RViz Image display Topic = `/camera/image_local`(raw 격리로 표준 /camera/image 발행자 0 → no image였음). RViz는 raw(sensor_msgs/Image)만 표시·로컬이라 raw_local 정답, compressed 육안은 rqt_image_view. raw 격리는 집 Wi-Fi 안전판이라 랩에서도 유지(사용자 "그냥 두자"). 현 구성 정상 동작 확정.

**카메라 발행률 누적 저하 + 재시작 절차 (2026-07-13):** `/camera/image/compressed`가 **장시간 구동 시 서서히 저하**(clean 재시작 10.08Hz → 켜둔 뒤 2.2Hz, RTF는 100% 유지 = GPU 렌더 드리프트 추정). **저쪽 수신 Hz 낮으면 Peer·QoS 만지기 전에 시뮬측 `ros2 topic hz /camera/image/compressed` 발행률부터 실측** — 발행 낮으면 이 누적 저하고 해결=clean 재시작(gz server 신규 기동→10Hz 회복). **실험 런 전 반드시 clean 재시작.** 재시작 절차 강화(2026-07-13): stop_sim에 `_ros2_daemon` pkill·멀티 오프셋 포트·자원프리 검증리포트(`[자원 프리 검증: 프로세스 0·포트 0·SHM 0]`), start_sim이 기존 sim 감지 시 stop 자동선행(clean 보증, NO_CLEAN=1로 생략). 상세: Docs/RULES.md 트러블슈팅·재시작 절차.

**네트워크 보호 (2026-07-12):** ①**raw 카메라 로컬 격리** — raw ROS명 camera/image_local, 표준 /camera/image는 발행자 0 → 저쪽이 raw 구독해도 44Mbps 크로스머신 불가. 원격 카메라 유일 채널=/camera/image/compressed(멀티 /drone{N}/…). 단일·멀티 both. ②**집 유선=en5**(랩은 en7 — 장소마다 유선 NIC 이름 다름). ③**multi-homing 함정**: 집 유선 꽂으면 en0(Wi-Fi 45.50)+en5(유선 45.146)가 같은 45서브넷 동시 → broadcast·ARP 혼란 간헐 마비. 유선 단독이면 `sudo ifconfig en0 down` 권장. "시뮬 돌리면 내부 Wi-Fi 다 죽는다"의 1차 용의자. ④compressed republisher는 start_sim 기본 ON(CAMERA_COMPRESS=0으로 끔). 상세: Docs/RULES.md 환경이동·Docs/specs/2026-07-11-camera-compressed-republish.md.

**최종 대형·연동·게이트 (2026-07-10):**
- **스폰 대형 = 20m 등변 삼각 (최종)**: d1 출발지 고정(gz 0,0), d2(−10,−17.32)·d3(+10,−17.32). navsat 실측 쌍간 ≈19.8/20.1/20.2m(전 쌍>10m → 저쪽 규칙#11 SWARM_SAFETY_RADIUS_M=10 오탐 없음). 대형 진화 이력: 60m(이중계산 실수)→30m선형→2.5m→30m삼각→**20m삼각**. 저쪽(.29) 결정=안전반경 10m 불변, 대형으로 해결. **핵심 함정: navsat=home+gz_pos** → home은 공유, gz 오프셋만 준다(home 동반 오프셋 시 이중계산). OFFSET 정본: `gen_multi_assets.sh`.
- **저쪽 연동 repo**: `swjo0330/Aerion-integration`(팀 문서 허브, gh 계정 seongwon-jo collaborator). `docs/sim/gazebo/`에 토픽 인터페이스 규격+멀티설계 push함(전수 매핑표·GPS실측·front_av휴면·방화벽 7650/7900/8150). CONTRIBUTING: 담당폴더 직push+pull --rebase.
- **5단계 검증 게이트 하네스 (T5, 이 프로젝트 한정)**: 이미지 5단계(범위→근거→풀기→검증→보고)를 품질 게이트로 명문화. ②근거·④검증·⑤보고 신설(①③은 기존 매핑). 정본: `FABLE5.md §5단계 검증 게이트` + `Docs/reviewer-checklist.md`(L1 자가체크+표준 증거 카탈로그+L2 적대검증 서브). CLAUDE §1.5 발동. 대형 작업은 완료 선언 전 자가체크→말미 `✅ 게이트` 1줄.

**⚠️ 환경 이동 시 sim 자동사망 신호 (2026-07-03 관측):** 랩(유선)에서 sim 돌리다 집(Wi-Fi 192.168.45.x)으로 이동/en7 뽑히면, cyclonedds가 죽은 en7 IP에 묶여 `Exception sending a multicast message: Can't assign requested address` + `ddsi_udp_conn_write to udp/[내IP]:74xx failed`로 도배되며 launch가 자체 종료(exit 0), path_marker_node만 고아로 남음. 대응: `ipconfig getifaddr en7`로 유선 확인 → 미연결이면 NetworkInterface en0 전환+저쪽 동네트워크 IP 필요, 유선 복귀면 en7 유지+`sync_and_build.sh [저쪽IP]`.

**이전 상태 (2026-07-02, 랩/유선):** en7 10.130.200.30, Peer 10.130.200.36.

**환경 전환 교훈:** IP 대역으로 환경 판별 — `10.130.200.x`=랩/유선/en7, `192.168.x`=집/Wi-Fi/en0. 환경 바뀌면 ① `ipconfig getifaddr en7`로 유선 연결 여부 확인 ② cyclonedds.xml NetworkInterface 수동 전환(en7↔en0, sync_and_build 미처리) ③ `sync_and_build.sh [저쪽IP]`. Wi-Fi는 크로스머신 토픽 실패 이력 있음([[dds-wifi]]).

**이전 상태 (2026-06-27, 집/Wi-Fi):** en0 192.168.35.158, Peer 192.168.35.7. (2026-06-25 랩: en7 10.130.200.31/Peer .36, 카메라 640x480, 짐벌 -20° NEUTRAL.)
- 내 en7 IP 이력: .31(6/2)→.30(6/4·5)→.23(6/8)→.38(6/9)→.31(6/10·11)→.30(6/17)→.31(6/25). 저쪽: .32(6/5)→.22(6/8)→.39(6/9)→.32(6/10)→.39(6/11)→.32(6/17)→.36(6/25). (IP 매일 변동, en7 이름 바인딩이라 내 쪽 무관, 저쪽 바뀌면 sync_and_build [저쪽IP])
- ✅ **2026-06-17 수정:** sync_and_build.sh의 IP 자동감지를 `ipconfig getifaddr en7` 직접 조회로 변경(en7 미연결 시에만 기존 로직 폴백). 이제 다른 NIC(.29 등) 오감지 없이 정확히 en7 IP를 잡음 → 사후 보정 불필요. (이전 함정: 자동감지가 .21/.31/.29 등 엉뚱한 NIC 잡았음. DDS는 en7 이름 바인딩이라 통신엔 무관했으나 기록값이 틀렸었음.)
- cyclonedds는 en7 이름 바인딩 + Peer는 저쪽IP. 저쪽 IP 바뀌면 `sync_and_build.sh [저쪽IP]` 필요(오늘 실행함). 단 **저쪽도 자기 Peer를 내 en7 IP(10.130.200.30)로** 갱신해야 양방향 성립.
- ⚠️ sync_and_build.sh 자동 IP 감지가 en0 등 다른 NIC의 .22를 먼저 잡음 — 실제 en7은 .23. DDS는 NetworkInterface en7로 강제되니 통신 무관, 메모리만 .23으로 사후 보정.
- ⚠️ 저쪽(.32)에서도 자기 cyclonedds Peer를 이 Mac en7 IP인 **10.130.200.30**으로 설정해야 양방향 디스커버리 성립.
- 관측: ROS2 그래프에 `/fmu/in|out/*`(PX4 uXRCE-DDS) 토픽이 보임 → 저쪽이 PX4 SITL을 돌리는 중. 우리 ArduPilot은 `/range`, `/camera` 등.
- sync_and_build.sh 자동 IP 감지가 또 다른 인터페이스(.31)를 잡았음 — 결과적으로 메모리에 잘못 기록될 수 있으니 en7 실제 IP로 사후 보정. DDS 바인딩 자체는 en7로 강제됨.

**집 환경 Wi-Fi 결론 (⚠️ 2026-07-11 정정):** "ipTIME으로 완치(0%/38ms)"는 **실험 결함**이었음 — 그 측정 때 원격 구독자가 없어 raw가 공중에 안 실렸음(DDS는 구독자 있어야 전송, 로컬 발행≠공중 전송). 원격 구독 시작 후 ipTIME에서도 불안정 재현. **확정: raw 480p(≈44Mbps)+RTPS 재전송은 소비자용 Wi-Fi AP 일반 한계 → 해법=compressed republish(플러그인 설치됨, /camera/image/compressed 발행 확인)**. **✅ 2026-07-11 파이프라인 통합 완료**: start_sim이 image_republisher 자동 기동(CAMERA_COMPRESS=0으로 끔)·stop_sim이 정리, 실측 7.7Hz·29KB/frame·~220KB/s(raw 대비 1/31). 멀티는 drone_multi.launch.py instance 0 조건부(D10). 원격은 Wi-Fi에서 compressed만 구독(raw 구독 금지 — 공중 44Mbps 재유발). 정본: Docs/specs/2026-07-11-camera-compressed-republish.md. 집 최신망: ipTIME 이 Mac en0 192.168.0.4 ↔ 저쪽 0.5. "스트림 중" 측정 시 반드시 원격 구독자 존재부터 확인할 것.

**(구 기록, 무효) 집 환경 AP 의존성 (2026-07-10):** 집은 AP가 관건 — **통신사 모뎀 내장 Wi-Fi는 raw 카메라(≈44Mbps UDP)에서 자기유발 혼잡으로 붕괴**(스트림 중 1400B 손실 45%·RTT 972ms ↔ 유휴 시 1%·21ms 차등실험으로 확정), **ipTIME AP는 동일 스트림에서 손실 0%·38ms로 완벽**. 현재 집 구성: ipTIME망 이 Mac en0 **192.168.0.47** ↔ 저쪽 맥북 **192.168.0.48**. compressed republisher는 불요해져 중단(플러그인 ros-humble-compressed-image-transport는 ros_env에 설치돼 있음 — 향후 대역 완화 필요시 사용 가능). 교훈: "Wi-Fi에서 붕괴"는 ①장소의존 설정(Peer·NIC) ②AP 품질(모뎀AP 금지, ipTIME류 사용) 순으로 의심 — 맥·매체 일반론 탓 아님.

**집 환경 (2026-07-10 1차 성공·원인 규명, 45망=모뎀AP):** en0(Wi-Fi), 이 Mac **192.168.45.50** ↔ 저쪽 맥북 **192.168.45.93**. 크로스머신 480p raw 카메라 **6.5Hz** + /clock + camera_info 15초 실측 성공 (송신측 UDP drop 증가 0, 구독자 발견 정상). **2026-05-08 "통신 전무" 미제의 근본원인 = 저쪽의 장소 의존 설정 2건**: ①CycloneDDS Peer가 사무실 IP로 stale ②XML 고정 NIC `en4`가 집에 없음 → **노드 생성 자체가 죽었던 것** (AP isolation/broadcast 차단 의심은 오진 — 라우터·Wi-Fi 물리 성능 문제 아님, 사용자 가설 적중). 집 이동 시 체크: 양쪽 모두 ①Peer IP 갱신 ②NIC 이름 실측(`ipconfig getifaddr`/`ip a`) — IP·NIC 둘 다 장소 의존값.
- stop_sim.sh: 1차 pkill → 2초 대기 → 2차 강제 kill(-9) + 포트 정리로 개선 (잔여 프로세스로 기체 미동작 문제 해결). **2026-07-09: Fast-DDS SHM 정리 단계 추가** — `/private/tmp/boost_interprocess/fastrtps_*` 고아 세그먼트 제거([[feedback_fastdds_shm_leak]]).
- sync_and_build.sh: 완료 시 sysctl 리마인더 출력 추가. 자동 IP 감지가 en0(Wi-Fi)을 먼저 잡을 수 있으니 주의 — DDS 바인딩은 cyclonedds.xml의 en7로 강제됨
- Gazebo Harmonic + RViz2 + ArduCopter SITL 정상 동작
- MAVProxy → UDP out: 10.130.200.32:14555
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

**path_marker 패키지 (2026-06-10 작성·빌드 완료):** `src/path_marker/` — `/replan_path_enu`(nav_msgs/Path, ENU map) 구독 → Gazebo `/marker` 서비스로 LINE_STRIP(주황, ns="replan_path" id=1) 실시간 표출. 새 경로 교체, 빈 Path면 DELETE, lifetime 5s 자동소멸. C++ ament_cmake, **gz-transport13 + gz-msgs10**(Harmonic, msgs9 아님). ros_gz_bridge는 Marker 미지원이라 gz-transport 직접 Request. 빌드: `colcon build --packages-select path_marker --cmake-args "-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env"`. **재시작 파이프라인에 통합됨(2026-06-10): `start_sim.sh`가 `ros2 run path_marker path_marker_node &`로 자동 기동, `stop_sim.sh`가 pkill path_marker_node로 종료.** 수동 실행도 가능(`ros2 run path_marker path_marker_node`, 안 잡히면 묵은 ros2 daemon kill — [[ros2-daemon]]). `/marker` 서비스·노드 기동 검증 완료. **선결조건: 저쪽이 `/replan_path_enu`(nav_msgs/Path, ENU, 원점=gz world원점=iris스폰) 발행해야 그릴 게 생김 — 2026-06-11 발행 시작 확인, 50pt 경로 수신·표출 검증 완료.** frame 원점 어긋나면 테스트마커로 오프셋 확인.
**⚠️ 거짓 WARN (2026-06-11 진단):** 노드 로그의 `gz /marker Request 실패 (executed=0)`는 거짓 경고 — gz `/marker` 서비스 응답이 ~1.5s 걸려 노드의 1000ms 동기 타임아웃을 넘길 뿐, **마커는 실제 등록·표출됨**(`/marker/list`로 확인). 미수정 잔여 개선: `path_marker_node.cpp:77` 동기 Request(1s, 콜백 블로킹) → 비동기 Request로 교체하면 거짓 WARN+블로킹 제거.

**남은 작업:**
- ~~저쪽 `/replan_path_enu` 발행 시작 → path_marker_node로 실시간 표출 검증~~ ✅ 2026-06-11 완료
- path_marker_node 동기 Request → 비동기 전환 (거짓 WARN 제거, 사용자 승인 시)
- Aerion-Foundation 서브모듈 등록 (저쪽 push 대기)
- `iris_runway_des.sdf` src 파일도 동일하게 model:// 수정 필요 (install만 수정됨)

**Why:** Ubuntu 22.04 ROS2 Humble 환경을 macOS ARM으로 마이그레이션.
**How to apply:** 재부팅 후 → IP 확인 → sync_and_build.sh [저쪽IP] → sysctl 설정 → start_sim.sh.
