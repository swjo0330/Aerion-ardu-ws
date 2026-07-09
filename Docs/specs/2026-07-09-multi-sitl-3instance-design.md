# 멀티 SITL 3인스턴스 + DDS 도메인 분리 — 설계 정본

> 작성 2026-07-09 · 상태: 설계 확정(구현 전) · 아키텍처 요지·포트표 정본 = [AGENTS.md](../../AGENTS.md) §4·§5.1 · 검증 트랙 = [EXPERIMENTS.md](../../EXPERIMENTS.md) T3·T4
> **목표**: 한 Gazebo 월드에 SITL 3기(iris_d1/d2/d3)를 띄우고 DDS 도메인(d1/d2/d3)으로 분리하여, 저쪽 **드론별 체화지능 3개**(d1=본기, d2·d3=leaf)가 기체별 토픽을 독립 수신한다. 감독지능은 체화 내부 비동기 루프(NATS 소비, 별도 도메인 아님 — D7). **단일 인스턴스 파이프라인은 불변 병행.**

## 1. 확정 사실 (소스 근거 — 2026-07-09 분석)

| # | 사실 | 근거 |
|---|---|---|
| F1 | `--instance N` = 기본 포트 전부 +10N (5760/5501/9002/9003…) — 명시 지정한 포트엔 미적용 | `src/ardupilot/libraries/AP_HAL_SITL/SITL_cmdline.cpp:88,224-237,402-419` |
| F2 | `DDS_DOMAIN_ID` parm 실존 (기본 0, 0-232, RebootRequired) → XRCE participant 도메인 직접 지정 | `libraries/AP_DDS/AP_DDS_Client.cpp:136-143,1329` |
| F3 | `DDS_UDP_PORT`는 --instance 오프셋 **비대상** — 인스턴스별 parm으로 명시 필수 | F1의 오프셋 목록에 없음 + `dds_udp.parm:2` |
| F4 | XRCE 세션 키 고정 `0xAAAABBBB` → **agent 1개 공유 불가**, 인스턴스별 agent 필수 | `libraries/AP_DDS/AP_DDS_Client.h:296-297` |
| F5 | micro_ros_agent는 클라이언트가 요청한 도메인을 따름 (agent 자체 도메인 인자 없음) | `src/micro_ros_agent/.../Agent.cpp:46,62,80` |
| F6 | `/ap/*` 토픽명은 펌웨어 고정 (네임스페이스 파라미터 없음) → **도메인이 유일한 분리축** | `libraries/AP_DDS/AP_DDS_Topic_Table.h` |
| F7 | eeprom.bin은 **실행 cwd 상대경로** — instance가 분리해주지 않음 → 인스턴스별 cwd 필수 | `libraries/AP_HAL_SITL/Storage.cpp:20,91` |
| F8 | SYSID는 instance에서 자동 유도 안 됨 → `sysid`(=`SYSID_THISMAV`) 명시 (관례 i+1) | `SITL_cmdline.cpp:513-521`, `sim_vehicle.py:845-852` |
| F9 | ArduPilotPlugin은 SDF `<fdm_port_in>`에 bind (정적) → 모델 사본별 9002+10i 수정 필수 | `src/ardupilot_gazebo/src/ArduPilotPlugin.cc:1259-1276`, `models/iris_with_gimbal/model.sdf:213-214` |
| F10 | gz 절대 토픽 충돌 2군: `/gimbal/cmd_*` (SDF:314-372) · `/range/front_av`,`/range/front` (SDF:344-406, 플러그인이 무가공 구독 `ArduPilotPlugin.cc:962`) → 사본별 개명 필수 | 좌기 |
| F11 | 스코프드 토픽(`/world/map/model/<이름>/...` — imu·camera 등)은 모델명만 다르면 자동 분리 | `ArduPilotPlugin.cc:1155-1156` |
| F12 | 현 eeprom에 `DDS_DOMAIN_ID 0`·`DDS_IP0~3`·`DDS_UDP_PORT 2019` 기재재 — parm 파일보다 eeprom 우선 | `mav.parm:239-247` (실측 덤프) |
| F13 | ardupilot_sitl launch는 instance/sysid/base_port/sim_port 등 이미 인자화, **cwd 인자만 없음** | `Tools/ros2/ardupilot_sitl/src/ardupilot_sitl/launch.py:488-493,539-651` |
| F14 | MAVProxy `--out 127.0.0.1:14551`은 cmd 문자열 고정 (인자화 안 됨 — 로컬 out 중복은 무해하나 인지) | 상동 `:307-308` |
| F15 | 호스트 = 10코어(P-core 4)/24GB → 단일 gz 서버 + GUI·RViz 각 1개 강제 | `sysctl hw.*` 실측 |
| F16 | 저쪽은 mavros+A2A(`/a2a/drone1/*` — droneN 확장 슬롯 내장)+vision 스택 | `TOPICS.md` |

## 2. 아키텍처 결정

- **D1. 분리축 = DDS 도메인, d = i+1** (F6). domain 0은 단일 모드 전용 보존 → 멀티·단일 혼동 차단.
- **D2. 단일 gz 서버 + 한 월드 3모델** (F15, GZ_PARTITION 미사용). 신규 월드 `iris_runway_multi.sdf` — 기존 월드 불변.
- **D2b. 멀티 모델은 `lock_step=0`** (2026-07-09 실측 확정): lock_step=1은 온라인 기체의 servo 대기 루프 직렬화 + 미접속 기체 폴링으로 sim time 붕괴(RTF 0.2%, 링크 다운 실측 — `ArduPilotPlugin.cc:1194-1203` while 루프). 0 전환 후 2기 RTF 20%·정상 부팅. 단일 모드는 lock_step=1 불변.
- **D10. leaf 기체(d2/d3) 무카메라** (사용자 확정 2026-07-09): 카메라·YOLO는 본기 d1 1대만 정본 — S-5 집단감독은 NATS `swarm.state.*` 1Hz 상태 스트림에서 지표 산출, leaf는 vision 없는 경량 상태발행기(rule_only). 구현: `gimbal_small_3d_nocam` 사본 참조 + d2/d3 브리지에서 camera·range 4항목 제거. **유의**: 본기 장애물 조우 시나리오는 본기 카메라 시야에서 발생해야 함(leaf 쪽 장애물은 상태 이상으로만 감독에 잡힘).
- **D3. 기체별 수직 스택 동일 도메인 상주**: SITL_i + agent_i + MAVProxy_i + bridge_i + rsp_i → domain i+1.
- **D4. `/clock`은 도메인당 1개** — 각 bridge_i가 자기 도메인에 전역 `/clock` 발행 (도메인 내 유일하므로 중복 아님. 소비자(저쪽 인스턴스)도 sim time 필요).
- **D5. 인스턴스 작업 디렉토리 `multi/i{0,1,2}/`** — eeprom 분리 (F7). `ros2 launch`를 해당 cwd에서 실행하면 ExecuteProcess가 상속.
- **D6. MAVProxy out은 launch 인자로 주입** (`[저쪽IP]:14555+10i`) — sync_and_build sed 의존 제거 (멀티 경로에서만).
- **D7. 수신 매핑 (정정 2026-07-09)**: 도메인 1/2/3 ↔ **드론별 체화지능 1/2/3** (1:1, d1=본기·d2·d3=leaf). **감독지능은 별도 도메인/인스턴스가 아니라 체화 내부 비동기 루프** — NATS `swarm.state.*` 상태 스트림 소비(DDS 무관). 따라서 domain_bridge 불필요.
- **D8. path_marker_node는 d1 소속** 초기 배치 (`[가정]` 경로 시각화 주 소비자=drone1 — 필요 시 인스턴스화).
- **D9. 스폰 대형·GPS 이격 (최종 확정 2026-07-09 실측)**: 기체 i를 gz **북(+Y) 30m·i**에 스폰(`SPAWN_NORTH_M={0,30,60}`). **home GPS는 셋 다 공유**(`37.39447652,126.6381927`) — `navsat = home + gz_pos`라 gz 30m 스폰만으로 navsat이 30m 간격이 됨(실측: d1/d2/d3 = +0/+30/+60m). ⚠️ home도 오프셋하면 이중계산(60m)되므로 **home 오프셋 금지**. (초기안의 y=+20i·home 동반 오프셋은 폐기 — GPS 실측으로 정정.)

## 3. 신규/수정 산출물 목록 (구현 시 이 순서)

**전부 신규 파일 — 기존 파일 수정 0건** (불가침: CLAUDE.md §1·§6)

| # | 산출물 | 내용 |
|---|---|---|
| A1 | `models/iris_with_gimbal_d{1,2,3}/` (src+install) | 활성 model.sdf 사본 3벌: `fdm_port_in` 9002/9012/9022 (F9), `/drone{N}/gimbal/cmd_*`·`/drone{N}/range/*` 개명 (F10, 플러그인 `<sensor><topic>`도 동일 개명) |
| A2 | `worlds/iris_runway_multi.sdf` (src+install) | 기존 `iris_runway_des.sdf` 기반, include 3개 (iris_d1@y0 / iris_d2@y20 / iris_d3@y40, `<name>iris_d{N}</name>`) |
| A3 | `config/iris_bridge_d{1,2,3}.yaml` (src+install) | gz 경로 `iris`→`iris_d{N}` 치환 + range 토픽 `/drone{N}/range/...` + `/clock` 브리지 포함 (D4) |
| A4 | `config/default_params/dds_udp_d{1,2,3}.parm` | `DDS_ENABLE 1` / `DDS_UDP_PORT 2019+10i` (F3) / `DDS_DOMAIN_ID N` (F2) / `SYSID_THISMAV N` (F8) |
| A5 | `launch/robots/drone_multi.launch.py` | iris.launch.py의 인자화판: `instance`·`domain`·`ns`·`out_ip` 받아 포트 계산(5760+10i 등), bridge/rsp에 `namespace=/drone{N}` + `additional_env ROS_DOMAIN_ID` |
| A6 | `launch/iris_runway_multi.launch.py` | gz 서버(월드 A2) + GUI 1개 (+RViz d1 옵션) — 기체 launch는 포함하지 않음 (도메인 env 분리 위해 A7이 담당) |
| A7 | `start_multi_sim.sh` | 오케스트레이터: 환경 준비(단일과 동일) → A6 기동 → i∈{0,1,2}: `cd multi/i{i} && ROS_DOMAIN_ID=$((i+1)) ros2 launch drone_multi.launch.py instance:={i} out:=[저쪽IP]:$((14555+10*i)) &` → 부팅 시그니처 3중 확인 |
| A8 | `stop_multi_sim.sh` | `stop_sim.sh` 재사용 호출 (전역 pkill이 3기 전부 커버) + `multi/i*/eeprom.bin` 존치(파라미터 보존) |
| A9 | `multi/i{0,1,2}/` 디렉토리 | 인스턴스 cwd (eeprom.bin 자동 생성) |

- A1·A2·A3의 src/install 이중 트리 규약 준수 (CLAUDE.md §1). A1은 `switch_rangefinders.sh` 변형과 독립 사본 — 현 활성 변형(model.sdf)을 복사 시점에 흡수. `[빈칸]` 변형 전환 시 멀티 사본 재생성 절차는 T3 통과 후 문서화.
- 저쪽(Ubuntu) 요구 통지 사항: ①mavros 3개 (udp 14555/14565/14575 수신) ②지능 인스턴스별 `ROS_DOMAIN_ID` 1/2/3 ③cyclonedds Peer=이 Mac en7 IP (기존 동일) ④`/a2a/drone{2,3}/*` 확장.

## 4. 검증 계획 (EXPERIMENTS T3·T4 게이트)

1. **G-회귀**: `start_sim.sh` 단일 모드 기존 시그니처 무결 (`DDS: Initialization passed`+`EKF3 active`)
2. **G-2기** (T3, 최소 슬라이스): i0+i1만 기동 → ①gz에 iris_d1·iris_d2 물리 스텝 ②`ROS_DOMAIN_ID=1 ros2 topic list`에 `/ap/*`+`/drone1/*`만, `=2`에 `/drone2/*`만 (교차 오염 0) ③EKF3 active ×2 ④`ROS_DOMAIN_ID=1 ros2 topic hz /drone1/camera/image` 실측
3. **G-3기** (T4): 3기 확장 + RTF 실측(gz stats) + 카메라 3스트림 en7 대역폭 실측 → F15 자원 한계 판정
4. **G-크로스머신** (T4): 저쪽 3인스턴스 도메인별 수신 + `/a2a/drone{N}` 응답 (저쪽 협업)

## 5. 리스크·완화

| 리스크 | 완화 |
|---|---|
| ~~lock_step=1 스톨~~ | ✅ 해소(2026-07-09): D2b lock_step=0 확정 — RTF 0.2%→20% 실측 |
| gpu_lidar ×3 GPU 부하 (fan3d 계열) | 2기 RTF 20% 실측 — 3기에서 재실측, 필요 시 leaf 라이다 축소 검토 |
| ~~카메라 ×3 대역폭~~ | ✅ 해소(2026-07-09): D10 leaf 무카메라 확정 — 카메라는 d1 1대만 |
| eeprom 첫 부팅 시 parm 미반영 (F12 함정) | 인스턴스 cwd가 신규라 eeprom 없음 → defaults 체인이 최초 기록 (문제 없음). 단 parm 수정 후엔 해당 `multi/i*/eeprom.bin` 삭제 필요 — RULES 트러블슈팅에 등재 |
| stop 전역 pkill이 단일·멀티 구분 못 함 | 확정: 동시 운용 금지 (단일 XOR 멀티) — start_multi가 기동 전 stop_sim 선행 |
| 도메인 분리로 로컬 진단 번거로움 | `ROS_DOMAIN_ID=N` 프리픽스 관례를 RULES에 명문화, check 스크립트는 T3 후 멀티 대응 |
