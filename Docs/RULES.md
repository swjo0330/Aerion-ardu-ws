# ardu_ws Project Rules — 상세 레퍼런스

> 필수 규칙은 [`CLAUDE.md`](../CLAUDE.md) 참조. 이 파일은 상세 명령어·표·절차·이력의 **정본**이다.
> (CLAUDE.md는 자동 로드되는 비싼 자리 — 길어지는 예시·명령어·표는 여기로 내린다. CLAUDE.md의 요약과 중복되는 문장도 여기서는 전문 유지.)
> 구 CLAUDE.md(하네스 재구성 이전)의 실측 확정 내용을 유실 없이 이관 (2026-07-09).

---

## sysctl

재부팅 후 반드시 재적용 (커널 파라미터는 재부팅 시 초기화). `sync_and_build.sh`가 완료 시 리마인더를 출력한다.

**이 Mac (macOS) — 3종:**

```bash
sudo sysctl -w net.inet.ip.maxfragsperpacket=8192
sudo sysctl -w net.inet.udp.recvspace=8388608
sudo sysctl -w net.inet.udp.maxdgram=65535
```

**저쪽 Ubuntu — 4종:**

```bash
sudo sysctl -w net.ipv4.ipfrag_high_thresh=26214400
sudo sysctl -w net.ipv4.ipfrag_max_dist=0
sudo sysctl -w net.core.rmem_max=26214400
sudo sysctl -w net.core.rmem_default=26214400
```

배경: `/camera/image` 등 대형 토픽의 fragment 재조립·UDP 수신 버퍼 확보용 ([트러블슈팅](#트러블슈팅), [CycloneDDS 상세](#cyclonedds-상세) 참조).

## IP 변경 4종 세트

저쪽 Ubuntu IP가 바뀌면 **반드시 이 4가지를 한 세트로** 업데이트해야 한다. `sync_and_build.sh [저쪽IP]`가 1~3을 모두 처리. 4는 수동 보정.

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

**sync_and_build.sh 자동 IP 감지 주의:**
- (구버전 함정) 자동 감지가 `10.130.x.x` 첫 매칭을 잡아 en0(Wi-Fi) 등 엉뚱한 NIC IP를 먼저 잡을 수 있었다. DDS 바인딩은 `cyclonedds.xml`의 `NetworkInterface name="en7"`이 강제하므로 통신엔 영향 없지만, 메모리에 기록되는 "내 IP"가 잘못 들어가 사후 보정이 필요했다.
- **2026-06-17 수정 완료**: 자동 감지를 `ipconfig getifaddr en7` 직접 조회로 변경 (en7 미연결 시에만 기존 로직 폴백). 이제 오감지 없이 en7 IP를 잡는다. 단 en7 미연결 상태(집 등)에서는 여전히 폴백 로직이 돌므로 기록값 검증 필요.
- 저쪽 Ubuntu에서도 자기 쪽 cyclonedds Peer를 **이 Mac의 en7 IP**로 갱신해야 양방향 디스커버리가 성립한다 (한쪽만 갱신하면 편도만 붙는다).

## 환경 이동

IP 대역으로 환경 판별: `10.130.200.x` = 랩/유선/**en7**, `192.168.x` = 집. **집 유선 NIC은 en5**(USB-C 이더넷 등), 집 Wi-Fi는 en0 — 장소마다 유선 NIC 이름이 다르다(랩 en7 ≠ 집 en5). 항상 `ipconfig getifaddr <nic>` + `ifconfig`로 실물 확인.

**전환 절차 (랩↔집):**
1. 유선 NIC 실물 확인: 랩=`ipconfig getifaddr en7`, 집=`ipconfig getifaddr en5` (IP만으로 NIC 판단 금물 — DHCP로 같은 IP가 NIC 사이를 오간 실측 있음)
2. `cyclonedds.xml`의 `<NetworkInterface name="..."/>`을 **수동 전환** (en7/en5/en0) — **`sync_and_build.sh`는 NetworkInterface를 처리하지 않는다** (Peer·launch.py만 처리)
3. `bash sync_and_build.sh [저쪽IP]` — 저쪽도 동일 네트워크 대역 IP여야 함

**⚠️ multi-homing 경고 (2026-07-12 실측):** 집 유선을 꽂으면 **en0(Wi-Fi)과 유선 NIC이 같은 서브넷(예 45.x)에 IP를 동시에** 갖는 상황이 생긴다(en0=45.50 + en5=45.146). same-subnet multi-homing은 broadcast 중복·ARP flux·라우팅 비대칭으로 **간헐 마비**를 유발할 수 있다. CycloneDDS는 유선 NIC 이름 바인딩이라 DDS 경로는 맞지만 OS 라우팅은 별개. **유선 단독 운용이면 Wi-Fi를 끄는 게 깔끔**: `sudo ifconfig en0 down` (되돌리기 `sudo ifconfig en0 up`). 또는 둘 중 하나만 45망에 두기. "시뮬 돌리면 내부 Wi-Fi 전체가 죽는다" 증상의 1차 용의자.

**raw 카메라 로컬 격리 (2026-07-12, 랩에서도 유지 확정 2026-07-13):** raw 카메라는 `camera/image_local`(로컬 전용)로 발행 — 표준 `/camera/image`는 발행자 0이라 크로스머신 raw(44Mbps) 물리 차단. 원격 카메라는 `/camera/image/compressed`(멀티: `/drone{N}/…`)가 유일 채널. 환경(집 Wi-Fi) 안전판이라 랩 유선에서도 유지(사용자 결정). 상세: `Docs/specs/2026-07-11-camera-compressed-republish.md`.
- **RViz 카메라 표시**: `iris.rviz`의 Image display Topic = `/camera/image_local` (raw 격리 때문에 표준 `/camera/image`는 발행자 0 → no image였음). RViz Image display는 **raw(`sensor_msgs/Image`)만** 표시 — CompressedImage 불가, RViz는 로컬이라 raw_local이 정답(대역 무관). compressed 스트림 육안 확인은 `rqt_image_view /camera/image/compressed`.

**sim 자동사망 신호 (2026-07-03 관측):** 랩(유선)에서 sim을 돌리다 집으로 이동/en7이 뽑히면, cyclonedds가 죽은 en7 IP에 묶여 로그가 다음으로 도배되며 launch가 자체 종료(exit 0)한다:
- `Exception sending a multicast message: Can't assign requested address`
- `ddsi_udp_conn_write to udp/[내IP]:74xx failed`
- 이때 `path_marker_node`만 고아로 남는다. 대응: en7 실물 확인 → 미연결이면 NetworkInterface en0 전환 + 저쪽 동네트워크 IP 필요, 유선 복귀면 en7 유지 + `sync_and_build.sh [저쪽IP]` 후 `stop_sim.sh`→`start_sim.sh`.

**Wi-Fi DDS 이력 (실측 갱신 2026-07-10):**
- ⚠️ **AP 의존성 결론 정정 (2026-07-11)**: 아래 "ipTIME 0%/38ms 완치" 판정은 **실험 결함** — 측정 시점에 원격 구독자가 없어 raw가 실제로 공중에 실리지 않았음 (DDS는 구독자 있어야 전송). 원격이 구독을 시작하자 ipTIME에서도 불안정 재현. **결론 원상복구: raw 480p(≈44Mbps)+RTPS 재전송은 소비자용 Wi-Fi AP 일반의 한계** — AP 교체가 아니라 **대역 축소(compressed republish)가 정공법**. 교훈: "스트림 가동 중" 측정은 반드시 **원격 구독자 존재를 확인**하고 해야 함 (로컬 발행≠공중 전송).
- ~~🏆 AP 의존성 최종 확정 (2026-07-10, 차등실험 2단)~~ (상기 정정으로 무효)
- (구 기록) 🏆 **AP 의존성 최종 확정 (2026-07-10, 차등실험 2단)**: 동일 맥·동일 raw 스트림에서 통신사 모뎀 AP=손실 45%/RTT 972ms(자기유발 혼잡 붕괴, 유휴 시 1%/21ms) ↔ **ipTIME AP=손실 0%/38ms**. 집에서 붕괴 시 의심 순서: ①양쪽 장소의존 설정(Peer IP·NIC 이름 실측) ②**AP 품질(모뎀 내장 AP 회피, ipTIME류 사용)** ③그 후에야 매체 한계 일반론. compressed 플러그인(ros-humble-compressed-image-transport)은 ros_env에 설치됨 — 대역 완화 필요시 republish 사용.
- ✅ **2026-07-10 집(45망) 크로스머신 성공 (실측)**: 이 Mac en0 192.168.45.50 → 저쪽 맥북 192.168.45.93. 480p raw `/camera/image` **6.5Hz**·`/clock`·camera_info 15초 실측, 송신측 UDP full-buffer drop 증가 0. → **집 Wi-Fi는 raw 480p DDS 단편화 전송을 감당함** (랩 en7 기본 정책은 유지 — 대역·안정 마진).
- 🔍 **2026-05-08 "통신 전무" 미제의 근본원인 (2026-07-10 규명)**: Wi-Fi/라우터가 아니라 **저쪽의 장소 의존 설정 2건** — ①CycloneDDS Peer가 사무실 IP로 stale ②XML 고정 NIC `en4`가 집에 없음 → **노드 생성 자체 사망**. AP isolation/broadcast 차단 의심은 오진. **교훈: 장소 이동 시 양쪽 모두 ①Peer IP ②NIC 이름을 실측으로 갱신** — 존재하지 않는 NIC 지정은 "통신 안 됨"이 아니라 "노드 자체가 안 뜸"으로 나타난다.
- 구조적 한계 (일반론 — 여전히 유효, 단 위 실측처럼 저부하 480p·소수 노드에선 문제 안 될 수 있음): AP가 멀티캐스트를 6-24Mbps basic rate로 강제 → 채널 점유 폭증 / Reliable QoS ACKNACK + 802.11 ARQ 이중 재전송 → self-DoS 발산 / Wi-Fi 드라이버 RX 큐 < fragment 도착 속도 → socket buffer overflow / macOS `kern.ipc.maxsockbuf` 8MB 천장 (16MB까지 상향 가능, 32MB는 "Result too large").
- 완화책 (효과 큰 순): ① image_transport compressed(JPEG q80, ros_gz_bridge는 미지원이라 별도 republisher 필요) ② 카메라 토픽 QoS BEST_EFFORT + KEEP_LAST(1) (송신측 `qos_overrides`) ③ 해상도/rate 축소 ④ zenoh-bridge-ros2dds로 Wi-Fi 구간만 TCP 분리 ⑤ `NackDelay 50ms`·`SocketReceiveBufferSize 10MB`·`AllowMulticast spdp`.
- 2026-06-27 집/Wi-Fi 구성 기록 존재 (en0 192.168.35.158 / Peer 192.168.35.7, 35망) — 그 회차 크로스머신 성공 여부는 미확인 (45망은 상기 성공).

## Distance Sensors

iris에 gpu_lidar 기반 거리센서 → ardupilot_gazebo Plugin `RangeCb` → SITL JSON FDM `rng_1~3` → RNGFND1/2/3 (Type=100 SIM) → PRX1(RangeFinder) → AVOID. ros_gz_bridge로 ROS2 토픽 노출 (외부/저쪽 Ubuntu 구독 가능).

**토글:** `bash switch_rangefinders.sh {on|fan|fan3d|fan3d_down|fan3d_av|single|off|status}`
6개 파일 일괄 swap (src+install 양쪽 × sdf/parm/yaml — 이중 트리 규약 준수). 각 파일별 변형 사본(`.baseline`/`.rangefinders`/`.front_fan`/`.fan3d`/`.fan3d_down`/`.fan3d_av`/`.front_single`) 영구 보관. 현 활성 변형은 `switch_rangefinders.sh status`로 실물 확인.

**변형 6종 상세 (+off):**

| 변형 | 사본 | 구성 | RNGFND | ROS2 토픽 |
|------|------|------|--------|-----------|
| `off` | `.baseline` | 거리센서 없음 (원본 iris_with_gimbal) | — | — |
| `on` | `.rangefinders` | 전/좌/우 single-ray 3개 | RNGFND1(F)/2(L,ORIENT6)/3(R,ORIENT2) | `/range/{front,left,right}` (LaserScan) |
| `fan` | `.front_fan` | 전방 ±45° 수평 부채꼴 1개 (samples=91, 1.0° 간격, 수평 1층) | RNGFND1만 (ORIENT 0) | `/range/front` (LaserScan 91점) |
| `fan3d` | `.fan3d` | 전방 3D: H±45°(91)×V±15°(16층) = 1456 ray | RNGFND1 (gz LaserScan in-process 최소거리) | `/range/front/points` (PointCloud2)만 — points-only 결정 |
| `fan3d_down` | `.fan3d_down` | 전방 3D 인지 전용: H±45°(91)×V-60°~+5°(33층) = 3003 ray, RNGFND/PRX/AVOID **off** | 없음 (→MAVLink DISTANCE_SENSOR 미발신) | `/range/front/points` (PointCloud2) |
| `fan3d_av` | `.fan3d_av` | 센서 2개: A) 수평 회피센서 `rangefinder_av`(H±45°×1층)→RNGFND1, B) 3D 하향센서(H±45°×V-60°~+5° 33층, RNGFND 미등록) | RNGFND1←A만 | B→`/range/front/points`(PointCloud2) + A→`/range/front_av`(LaserScan, 2026-06-08 브리지 추가) |
| `single` | `.front_single` | 전방 단일빔 1개 (samples=1, 0°만) | RNGFND1만 | `/range/front` 1점 |

**공통 메커니즘:** 같은 gpu_lidar라도 samples=1이면 단일빔, h>1이면 수평 부채꼴, h>1&v>1이면 3D. 플러그인 `RangeCb`(ArduPilotPlugin.cc:286-303)가 모든 ray의 **최소거리**를 rng_N으로 합성 → RNGFND = cone 내 최근접. **어떤 변형이든 플러그인/빌드 수정 불필요.** parm은 fan/fan3d/single 동일(RNGFND1만)이라 status에서 parm이 FAN으로 표시되는 것은 정상.

**변형 선택 교훈 (실측 확정):**
- 하향 넓은 3D lidar를 RNGFND/PRX에 먹이면 안 됨 — 지상 대기 시 발밑 지면(0.30m)을 봐서 `PreArm: Proximity 0 deg, 0.30m` 차단 (2026-06-02). 반응제어가 필요하면 별도 수평 센서를 RNGFND에 등록(fan3d_av), 3D 센서는 인지 전용.
- RNGFND→MAVLink `DISTANCE_SENSOR(id=10)`가 저쪽 mavros를 SIGBUS 크래시시킨 이력 (2026-06-08, mavros 견고성 버그). 회피가 offboard면 fan3d_down(DISTANCE_SENSOR 미발신)으로 트리거 원천 제거, 펌웨어 회피 원하면 저쪽이 mavros에 id=10 매핑/패치.
- 3D 변형의 하향 ring은 지면도 잡는다 → 저쪽 PointCloud 처리에 지면 필터 필수 (`el<0`인 점은 `h_AGL/sin(|el|)`보다 확연히 가까울 때만 장애물 판정).

**핵심 파라미터 (mav.parm):** RNGFND*_TYPE=100(SIM), PRX1_TYPE=4(RangeFinder backend), AVOID_ENABLE=7, AVOID_MARGIN=2.0, AVOID_DIST_MAX=5. Loiter/AltHold/GUIDED에서 Simple Avoidance 자동 동작 (AVOID_BEHAVE 기본 0=Slide). OA_TYPE(BendyRuler/Dijkstra)은 미설정 — AUTO 미션 우회 계획 없음, 단순 정지만.

**ON/변형 전환 시 eeprom 주의:** SITL은 **eeprom.bin(실행 cwd) 우선** — parm을 새로 로드시키려면 `eeprom.bin` 백업 후 삭제 권장 (백업: `eeprom.bin.before_rangefinders` 등 5종). 삭제 없이 재시작하면 새 RNGFND 파라미터가 무시될 수 있다. 토글 후 반드시 `bash stop_sim.sh && bash start_sim.sh` 재시작.

**검증 명령 4종:**

```bash
# 플러그인 인식
grep "subscribing to /range" /tmp/sim_start.log
# 파라미터 적용
grep -E "^RNGFND[123]_TYPE\b|^PRX1_TYPE\b" mav.parm
# gz 측
gz topic -e -t /range/front -n 1 | grep ranges:
# ROS2 측 (좀비 daemon 의심 시 --no-daemon)
ros2 topic echo /range/front --once | grep -A 1 "^ranges:"
```

일괄 검증: `bash check_rangefinders.sh` (ROS2 3토픽 권위 + gz 참고, `--no-daemon` 사용). 주의: `gz topic -e`(외부 CLI)는 gz transport 디스커버리 한계로 샘플이 안 잡힐 수 있으나 ros_gz_bridge는 in-process 정상 수신 → gz CLI 미수신은 무시 가능.

상세·이력 전문: `.claude/memory/project_distance_sensors.md` (글로벌 메모리 `project_distance_sensors.md`가 진실원천).

## 트러블슈팅

> 🔗 **재시작·연결·자원프리 IP 포함 known-good 샘플**: [setups/2026-07-14-known-good-crossmachine-wifi-sample.md](setups/2026-07-14-known-good-crossmachine-wifi-sample.md) — 연결 세팅 단계(파일/NIC/Peer/MAVProxy out)·자원프리 항목명·성능 실측 정본.

**대형 토픽(카메라 등) 미수신 진단 순서 (재발 시 이 순서 고정):**

1. `bash check_camera.sh [원격IP]` — 로컬 수신, 시스템 설정, 원격 전송 확인
2. 로컬 OK + 원격 NG → `ros2 topic info /camera/image --verbose`로 subscriber discovery 확인
3. subscriber 발견 + 패킷 안 나감 → RELIABLE QoS ACKNACK 문제 → `sudo tcpdump -i en7 src host <원격IP> and udp -c 20 -n`
4. 패킷 나감 + 저쪽 미수신 → IP fragmentation → `MaxMessageSize`/`FragmentSize` MTU 이하 확인 ([CycloneDDS 상세](#cyclonedds-상세))
5. Wi-Fi 사용 시 → 유선(en7) 강제

**ros2 daemon 함정 (로컬 `ros2 topic` 미표시/멈춤):**
- 거의 항상 **묵은 좀비 `ros2 daemon`이 stale 디스커버리 캐시를 물고 있는 것**이 원인. `ros2 daemon stop`이 좀비를 못 죽이는 경우도 있다.
- 처리: ① `ps aux | grep ros2cli.daemon` (시작 시각이 며칠 전이면 의심) → ② `pkill -9 -f "ros2cli.daemon|_ros2_daemon"` → ③ 조회는 `--no-daemon` (`ros2 topic list --no-daemon`, `ros2 topic echo <t> --once --no-daemon`)
- **핵심 감별**: 저쪽 Ubuntu에서는 잘 보이는데 로컬만 안 보이면 → 센서/네트워크/DDS가 아니라 **로컬 도구부터** 의심. 외부 동작 확인 = 코어 정상 신호. 정상 설정(`start_sim.sh`/`cyclonedds.xml`)을 성급히 바꾸지 말 것.
- 추가 함정: **macOS엔 `timeout` 명령이 없다** — `timeout 12 ros2 topic echo ...`가 exit 127로 빈 출력 → 토픽 미발행으로 오진하기 쉽다. 빈 출력이면 먼저 `which timeout`. 확실한 대안은 rclpy 자체 타이머 구독 스크립트로 1회 수신 검증.

**Fast-DDS SHM 누수 (sim 재시작 반복 시):**
- `/private/tmp/boost_interprocess/`에 `fastrtps_<해시>` 공유메모리 세그먼트가 실행당 ~549KB씩 무한 누적 (2026-07-09 관측 104개/26~54MB).
- 원인: `micro_ros_agent`(XRCE-DDS, Fast-DDS 내장)의 SHM transport 파일을 `stop_sim.sh`의 `pkill -9`(SIGKILL)가 정리 로직 없이 죽여 고아로 남김. 메인 RMW인 CycloneDDS는 이 파일과 무관 — fastrtps_*는 오직 micro_ros_agent 계열.
- **해결: `stop_sim.sh`가 자동 정리** (2026-07-09 통합 — 전 프로세스 종료 후 `fastrtps_*` 제거, `Cleaned N orphaned ...` 출력). 수동 정리(sim 미실행 상태에서만): `rm -f /private/tmp/boost_interprocess/fastrtps_*`
- 진단 신호: "재시작할 때마다 뭐가 남는 것 같다" → `ls /private/tmp/boost_interprocess/ | wc -l`

**카메라 발행률 누적 저하 (장시간 구동 시):**
- 증상: `/camera/image/compressed` 발행률이 시간이 갈수록 서서히 하락 (2026-07-13 실측: clean 재시작 직후 **10.08Hz**(update_rate 상한) → 장시간 켜둔 뒤 **2.2Hz**로 1/5 저하). **RTF는 100% 유지**(CPU·물리는 정상) — 순수 gz Sensors GPU 렌더 스레드의 누적 드리프트로 추정.
- **핵심 감별**: 저쪽 수신 Hz가 낮을 때, 먼저 **시뮬측 `ros2 topic hz /camera/image/compressed`로 발행률 실측**. 발행이 이미 낮으면 네트워크·저쪽 문제가 아니라 이 누적 저하다 (Peer·QoS 만지기 전에 이것부터).
- **해결: clean 재시작** — `stop_sim.sh` → `start_sim.sh`. gz server가 새로 뜨면 10Hz 회복. **실험 런 전에는 반드시 clean 재시작**이 정본(장시간 구동 상태에서 측정 금지).
- 예방: `start_sim.sh`가 기존 sim 감지 시 자동으로 `stop_sim.sh` 선행(2026-07-13 통합 — clean 시작 보증). `stop_sim.sh`는 종료 후 `[자원 프리 검증: 프로세스 0 · 포트 0 · SHM 0]` 리포트 출력.

**드론이 느리게 움직임 = RTF 저하 = 카메라 update_rate (2026-07-15 clean A/B 확정):**
- 증상: 드론 이동·펌웨어 동작이 벽시계 기준 느림. **RTF는 시간 배율** — RTF 0.5면 실제 시간 절반 속도로 재생됨(제어·물리는 sim-time 기준 정상, 펌웨어 문제 아님).
- **원인 1위 = 카메라 `<update_rate>`**. 깨끗한 15초 실효 RTF A/B: **rate 10 → RTF 0.47~0.50, rate 30 → RTF 0.20** (2.5배 차). gz 한 프로세스 안에서 카메라 렌더가 물리 스텝핑 시간을 잠식. **update_rate는 10 유지**(주말 30 변경이 RTF 반토막의 주범이었음, 원복 확정). 위치: `gimbal_small_3d/model.sdf` `<update_rate>` (src+install 양 트리, sed 토글).
- 무죄(실측): 배터리·발열·저전력(AC·미스로틀), compressed(2.3Mbps), 물리설정(1ms/1000Hz/lock_step1), 토픽명 변경. 호스트 앱 경합은 부차적(같은 노트북 집에서도 RTF 0.56~0.93 변동 — 이 sim의 상시 특성).
- 추가 레버(더 올리려면): 카메라 해상도 640×480→320×240(렌더 1/4, 저쪽 전달 화질만↓). RViz·무거운 앱 종료도 소폭 기여.
- ⚠️ 위 "누적 저하(RTF 100% 유지)"와는 **다른 현상** — 이건 update_rate가 RTF 자체를 깎는 것(렌더 부하), 누적 저하는 RTF 정상인데 Hz만 드리프트.

**재시작 절차 (정본 — 자원 프리·누적 제거 통합, 2026-07-13):**
1. `bash stop_sim.sh` — 2단 pkill(11종+`_ros2_daemon`) → 포트 정리(단일·멀티 오프셋 5760/70/80·2019/29/39·14555/65/75) → Fast-DDS SHM(`fastrtps_*`) 제거 → **자원 프리 자체검증 리포트**
2. `bash start_sim.sh` — 기존 sim 잔재 감지 시 stop_sim 자동 선행(clean 보증), 이후 기동. `NO_CLEAN=1`로 선행 생략 가능.
3. 기동 성공 = `DDS: Initialization passed` + `EKF3 active` + (compressed) `image_republisher` 기동 로그.

## CycloneDDS 상세

`cyclonedds.xml` 핵심 설정 (정본은 워크스페이스 루트 파일):

```xml
<NetworkInterface name="en7"/>
<MaxMessageSize>1400B</MaxMessageSize>
<FragmentSize>1344B</FragmentSize>
<Peer address="[저쪽IP]"/>
```

**왜 1400B/1344B인가 (실측 근거):** 기본 `MaxMessageSize=65000B`는 하나의 RTPS fragment가 ~64KB UDP 패킷 → MTU 1500B 네트워크에서 44개 IP fragment로 쪼개짐 → IP fragment 하나라도 유실되면 전체 RTPS fragment 유실 → 6.2MB 카메라 이미지(96 RTPS fragment)가 재조립 실패. MTU 이하(1400B)로 잡으면 RTPS fragment 수는 ~4400개/프레임으로 늘지만 **IP fragmentation 자체를 회피**해 유실 문제를 완전히 우회 (2026-04-10 적용).

**XML 주의 4종 (robostack 0.10.x):**
1. **`Internal` 태그 미지원** — 사용 시 `failed to create domain` 에러로 모든 ROS2 노드 crash
2. **단위 명시 필수** — `MaxMessageSize`/`FragmentSize`에 `B` 붙일 것 (예: `1400B`), 안 하면 deprecated 경고
3. **이 Mac에서 `AllowMulticast=false` 금지** — 같은 머신의 ROS2 노드끼리도 discovery 실패, `/camera/image` 등 브릿지 토픽 소실. 이 Mac은 생략 + Peer 방식. 저쪽 Ubuntu에서는 `AllowMulticast=false` + Peer로 이 Mac IP 지정 OK
4. **`file://` URI로 외부 XML 참조** — `export CYCLONEDDS_URI="file:///path/to/cyclonedds.xml"` (`start_sim.sh`가 사용). XML 문법 오류 시 에러 메시지 없이 domain 생성 실패 → launch 로그에서 `rmw_create_node: failed to create domain` 확인

## 빌드

**gz 관련 패키지 colcon 빌드 시 cmake 옵션 (필수):**

```
-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env
-DPython3_ROOT_DIR=/Users/swjo/anaconda3/envs/ros_env
-DPython3_EXECUTABLE=/Users/swjo/anaconda3/envs/ros_env/bin/python3
-DBUILD_TESTING=OFF
```

- **protobuf 충돌**: homebrew를 conda보다 먼저 탐색해야 protobuf 34(homebrew gz 호환)를 찾는다. conda protobuf 33과 homebrew protobuf 34 혼재 시 **SIGSEGV**. 적용 대상: ardupilot_gazebo, ros_gz_sim, ros_gz_bridge, ros_gz_image, path_marker 등 gz 관련 전부.
- **Micro-XRCE-DDS-Gen PATH**: ardupilot_sitl 빌드는 PATH에 `Micro-XRCE-DDS-Gen/scripts` 필요 (`microxrceddsgen` 호출). 없으면 "Could not find the program"으로 실패. `start_sim.sh`처럼 PATH 설정 후 빌드.

**patches/ 재적용 목록** (업스트림 재클론·리셋 시 다시 적용해야 하는 로컬 패치):

| 패치 | 내용 (diff 실물 확인) |
|------|------|
| `patches/micro_ros_agent.patch` | `micro_ros_agent/cmake/SuperBuild.cmake`에 `-DSPDLOG_FMT_EXTERNAL:BOOL=OFF` 추가 (xrceagent superbuild) |
| `patches/sdformat_urdf.patch` | `sdformat_urdf/CMakeLists.txt`의 `urdfdom_headers 1.0.6` 버전 고정 제거 |

patches/에는 그 외 `ardupilot_gazebo.patch`, `ardupilot_gz.patch`, `ardupilot_sitl_launch.patch`, `spdlog_common.h`, iris 관련 sdf/launch 사본도 존재 — 개별 용도는 미확인 (적용 전 diff 내용 확인 후 사용).

## World 파일

- **기본**: `iris_runway_des.sdf` — 저쪽 Ubuntu 절대경로(`file:///home/clrobur/...`) → `model://` 수정 완료 (2026-04-14). 단 **install만 수정됨, src 파일은 미수정** (잔여 작업).
- **대안**: `iris_runway_des_fire.sdf`, `iris_runway_remove_object.sdf`
- **launch 진입점**: `install/ardupilot_gz_bringup/share/ardupilot_gz_bringup/launch/iris_runway.launch.py` — ~79번째 줄에서 world 파일 주석 전환
- **카메라 해상도 이력**: 1920x1080 (대역폭 과다) → 1280x720 (2026-04-13) → **640x480 rgb8 (2026-05-13, 현재)** — 크로스머신 전송 정상. 토글 위치: `src/ardupilot_gazebo/models/gimbal_small_3d/model.sdf` + `install/.../gimbal_small_3d/model.sdf` **두 파일 모두** (install이 Gazebo가 실제 읽는 파일 — 이중 트리 규약)

## 폐기 이력

재제안·재검토 요청 시 아래 결론부터 인용할 것 (재분석 불필요).

**Zenoh (폐기 — 카메라 전송 실패):**
- `rmw_zenoh_cpp` 직접 사용 시 카메라 이미지(~1-2MB)가 Zenoh TCP fragmentation을 통과하지 못함 — 토픽 목록에는 보이지만 실제 데이터 미수신. batch_size/buffer_size 16MB 설정으로도 해결 안 됨. → 크로스머신 토픽 공유는 CycloneDDS 유니캐스트 Peer 방식으로 확정.
- 설정 파일 2종은 **참고용 존치** (삭제 금지): `zenoh_router.json5`, `zenoh_session.json5` (워크스페이스 루트)
- 재시도 시 참고: 올바른 env var는 `ZENOH_ROUTER_CONFIG_URI`/`ZENOH_SESSION_CONFIG_URI` (`RMW_` 접두사 없음). json5 잘못된 필드: `transport.link.tx.queue.backoff`(존재 안 함), `sequence_number_resolution: 4096`(문자열 필요). **json5 문법 오류 시 모든 ROS2 노드 crash.**
- 단 Wi-Fi 구간 한정 완화책으로 `zenoh-bridge-ros2dds`는 여전히 후보 ([환경 이동](#환경-이동) 완화책 ④) — rmw 전면 교체와는 별개.

**PX4 전환 (보류 — 2026-05-27 분석, ArduPilot 잔류 확정):**
- macOS ARM 네이티브 PX4 풀스택은 사실상 불가 (SITL 빌드는 되나 gz Harmonic GUI 불안정, ROS2 Humble+uXRCE-DDS는 Ubuntu 22.04 전용) → PX4는 저쪽 Ubuntu에서만 현실적.
- **"MAVProxy 자리에 PX4 SITL 바꿔치기"는 불가** — 플러그인(ArduPilotPlugin↔GZBridge)·에이전트(micro_ros_agent↔uXRCE-DDS)·모델(iris↔x500)·GCS(MAVProxy↔QGC)가 한 세트로 전환됨.
- 재개 조건: 저쪽 Ubuntu에서 PX4 공식 예제(`make px4_sitl gz_x500_lidar_2d`) PoC로 실익 증명 후에만 firmware 토글 launch 설계. "PX4로 풀려는 문제를 한 문장으로 못 쓰면 PoC까지만."
- 전문: 글로벌 메모리 `project_px4_eval.md`
