# Known-Good 크로스머신 구성 샘플 (Wi-Fi · compressed) — 2026-07-14

> **목적**: 실제로 저쪽이 이미지를 잘 받은 정상 구성을 **IP까지 포함한 구체 샘플**로 박제. 다음에 그대로 재현하는 템플릿.
> **⚠️ IP는 2026-07-14 DHCP 스냅샷(예시값)** — 실제 재현 시 그날의 IP로 `sync_and_build`가 자동 갱신. 아래 45.50/45.93은 "이런 형태"를 보여주는 샘플.

## 1. 검증된 결과 (2026-07-14 실측)

- **매체: 양쪽 다 집 Wi-Fi** — 내 **en0 192.168.45.50 (Wi-Fi)** ↔ 저쪽 **192.168.45.93 (Wi-Fi)**. 유선 아님, 양단 무선.
- **저쪽 수신 카메라 전달률: 18~25 fps** — `/camera/image/compressed` (JPEG). gz 소스 렌더 ~22Hz에 근접(전달률 상한 = 소스 렌더율).
- **저쪽 프레임 처리율(FPS): 60~80** (사용자 확인, 매우 양호). ⚠️ **소스 렌더가 ~22Hz이므로 이 60~80은 카메라 프레임 전달률(≤22Hz)이 아니라 저쪽의 처리/검출 루프 처리량**(입력 프레임을 재사용·고속 반복 처리). 의미: 파이프라인이 저쪽 처리를 **병목 없이 충분히 먹인다**는 좋은 신호. (과거 "30~40 fps" 증언도 이 처리/검출 루프와 혼동됐던 것과 같은 계열 — [[project_ardu_ws]])
- **compressed는 집 Wi-Fi 양단에서 안정** → 저대역 파이프라인 검증.
- **⚠️ "raw는 Wi-Fi 불가"로 단정 금지**: raw-over-Wi-Fi가 과거 불안정했던 주원인은 **설정 문제**(Peer stale·부재/오NIC 바인딩·en0+en5 멀티호밍·소비자AP 품질)로 규명됨 — 인내적 매체 한계로 확정된 것 아님(집 480p 6.5Hz raw 성공 사례 있음, [[feedback_dds_wifi]]). compressed는 저대역·안전 **기본 선택**이지, raw 불능 증명이 아님. raw가 필요하면 설정 정리 후 재시도 가능.
- gz 소스 렌더 22Hz. fps는 **호스트 부하 민감**(부하 정상=소스 근접, load 19.7일 땐 4Hz로 급락) — 하드상한 아님.

## 2. 토폴로지 샘플 (IP 포함)

| 역할 | 값 (2026-07-14 샘플) | 비고 |
|---|---|---|
| 내 Mac IP / NIC | **192.168.45.50 / en0 (Wi-Fi)** | sync_and_build이 자동 감지·바인딩 |
| 저쪽(지능측) IP | **192.168.45.93** | MAVLink out 대상 = DDS Peer |
| 서브넷 | 192.168.45.0/24 | 양측 동일 서브넷(크로스머신 유니캐스트 도달 조건) |
| MAVLink out | 192.168.45.93:14555 | |

## 3. 연결 세팅 단계 (파일·명령 단위 명세)

재현:
```bash
bash sync_and_build.sh 192.168.45.93 192.168.45.50   # <저쪽IP> <내IP>
bash start_sim.sh
```

### 3-1. `sync_and_build.sh <저쪽IP> <내IP>`가 자동 갱신하는 항목 (수동 시 각 파일 직접)

| # | 파일 | 항목(문자열) | 값(샘플) |
|---|---|---|---|
| ① | `cyclonedds.xml` | `<NetworkInterface name="…"/>` | `en0` (내 45.50 **소유 NIC 자동 선택**) |
| ② | `cyclonedds.xml` | `<Peer address="…"/>` | `192.168.45.93` (유니캐스트) |
| ③ | `cyclonedds.xml` | `<MaxMessageSize>`·`<FragmentSize>` | `1400B`·`1344B` (불변 — IP fragmentation 회피) |
| ④ | `src/ardupilot/Tools/ros2/ardupilot_sitl/src/ardupilot_sitl/launch.py` | MAVProxy out `default_value="…:14555"` (→ `--out`) | `192.168.45.93:14555` |
| ⑤ | (재빌드) | `colcon build --packages-select ardupilot_sitl` | install/ 트리 재생성 |
| ⑥ | 메모리 파일 | `이 Mac IP` / `MAVLink UDP out 대상` | 45.50 / 45.93:14555 |

### 3-2. `start_sim.sh`가 세팅하는 런타임 항목

| 항목 | 값 |
|---|---|
| `RMW_IMPLEMENTATION` | `rmw_cyclonedds_cpp` (Zenoh 폐기 — 카메라 전송 실패) |
| `CYCLONEDDS_URI` | `file://<repo>/cyclonedds.xml` |
| 프리플라이트 | 바인딩 NIC 생존 확인 → `DDS 바인딩 확인: en0 = 192.168.45.50 (Peer 192.168.45.93)`, 죽으면 활성목록 출력 + fail-fast |
| MAVProxy out (명령줄) | `--out 192.168.45.93:14555` (launch.py ④ 값) — FCU 텔레메트리를 저쪽으로 |
| 성공 시그니처 | `DDS: Initialization passed` + `AHRS: EKF3 active` + 바인딩에러 0 |

### 3-3. 재부팅 직후 1회 (sysctl 3종)
```bash
sudo sysctl -w net.inet.ip.maxfragsperpacket=8192
sudo sysctl -w net.inet.udp.recvspace=8388608
sudo sysctl -w net.inet.udp.maxdgram=65535
```

### 3-4. 교차확인
- 스크립트 출력 `감지된 내 NIC/IP`가 내가 말한 IP(45.50)와 일치하는가 (다른 /24면 ⚠️ 경고)
- **저쪽도 자기 Peer를 내 IP(192.168.45.50)로** 맞춰야 양방향 성립 (저쪽 미접속이면 크로스머신 0)

## 4. 결과 cyclonedds.xml 상태 (샘플)

```xml
<NetworkInterface name="en0"/>          <!-- sync_and_build이 내 45.50 소유 NIC로 자동 설정 -->
<MaxMessageSize>1400B</MaxMessageSize>   <!-- IP fragmentation 회피 -->
<FragmentSize>1344B</FragmentSize>
<Peer address="192.168.45.93"/>          <!-- 유니캐스트(공유망 flooding 방지) -->
```

## 5. 카메라 파이프라인 (토픽명 — 주말 개명 반영)

```
gz raw → ros_gz_bridge → /camera/image_local (raw, 로컬 전용, ~22Hz 소스)
                              └→ image_transport republish(JPEG) → /camera/image/compressed (크로스머신, 저쪽 구독)
```

- 저쪽 구독 토픽 = **`/camera/image/compressed`** (raw `/camera/image`는 발행자 0 — 개명됨. 옛 이름 구독 시 빈 화면)
- RViz 로컬 표시 = `/camera/image_local` (raw)

## 6. 주의점 (engrave)

1. **재시작은 저쪽 비행 중 금지** — FCU 부팅배너 재출현 = 미션 소실·호버 고착. freeze 창 합의 후.
2. **fps는 호스트 부하 민감** — Cursor/Chrome/다수 Claude + 동시 측정 프로브가 load를 올리면 4Hz로 급락. 측정·운용 시 부하 관리. (내 측정 프로브 자체가 fps를 떨어뜨렸던 함정)
3. **토픽명 변경은 지연 원인 아님**(DDS 라벨). 지연 본체 = 브리지 단일스레드 + 부하. republisher 홉은 latency만 소폭.
4. **공유 회사망**: Peer 유니캐스트 유지(디폴트 멀티캐스트 금지), raw는 `/camera/image_local` 로컬만 — wire 유출 금지(raw가 원격 구독되면 80→300Mbps 포화).
5. **NIC 드리프트**: en5(유선)↔en0(Wi-Fi) 등 이동마다 NIC명·IP 변동 → 항상 `sync_and_build <저쪽IP> <내IP>`로 자동 재바인딩. 죽은 NIC면 start_sim 프리플라이트가 fail-fast.
6. **로컬 `ros2 topic info/hz` 멈춤** = 묵은 daemon → `--no-daemon` + `pkill -f _ros2_daemon`.
7. **양측 서브넷 불일치 경고(⚠️)** 뜨면 크로스머신 도달 재확인(같은 /16 랩이면 정상).

## 7. 자원프리 항목 (stop_sim.sh 명세 — 재시작 시 정리 대상)

재시작·종료는 `bash stop_sim.sh` 경유 **필수**. 정리 항목(프로세스명 그대로):

**① 프로세스 종료 (1차 pkill → 2초 → 2차 `kill -9`):**
`gz sim` · `rviz2` · `arducopter` · `mavproxy` · `micro_ros_agent` · `parameter_bridge` · `robot_state_publisher` · `relay` · `rmw_zenohd` · `ros2 launch` · `ardupilot_sitl` · `path_marker_node` · `image_transport/republish` · `_ros2_daemon`(묵은 daemon 캐시)

**② 좀비 집요 제거 (3회 재확인 kill -9):** `arducopter` · `gz sim` — SIGKILL 회피분 누적 방지(좀비 다수 시 fps 급락 실측)

**③ 포트 정리 (`lsof -ti :PORT | kill -9`):** `5760 5770 5780`(SITL 오프셋) · `2019 2029 2039` · `14555 14565 14575` · `14551`

**④ Fast-DDS 고아 SHM:** `/private/tmp/boost_interprocess/fastrtps_*` (SIGKILL로 못 지운 세그먼트 누수 제거)

**⑤ 완료 시그니처 (필수 확인):** `[자원 프리 검증: 프로세스 0 · arducopter 0 · 포트 0 · SHM 0]` — 0 아니면 재실행

주의: 재시작은 **한 번에 하나씩**(`&` 남발 시 SITL 중복 누적) · **저쪽 비행 중 재시작 금지**(FCU 부팅=미션 소실).

## 관련 (링크)
- **재시작·종료 절차 정본**: [../RULES.md](../RULES.md) (재시작 절차·트러블슈팅) · `stop_sim.sh` / `start_sim.sh`
- **세션 재시작 읽기순서·시작/자원프리 루프**: [../../memory/session-restart-protocol.md](../../memory/session-restart-protocol.md) · CLAUDE.md §3
- 방법론 근거(파일 메모리): `feedback_startup_ip_methodology.md`
- 회사망 포화 규명: `feedback_dds_raw_lan_flood.md`
- 카메라 compressed 파이프라인: `Docs/specs/2026-07-11-camera-compressed-republish.md`
- ↔ **역링크**: 위 두 정본(RULES.md 재시작 절차·session-restart-protocol.md)에서 이 문서를 "IP 포함 known-good 샘플"로 참조. CLAUDE.md §3에서도 이 문서를 지목.
