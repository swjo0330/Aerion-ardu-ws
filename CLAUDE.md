# ardu_ws (AERION 시뮬 레이어) — Claude Code 프로젝트 규칙

> 세션 시작 시 자동 로드. 모든 작업에 적용되는 필수 규칙.
> **왜 이 구조인가**: 자동 로드되지 않는 절차 파일은 사문화된다 — 항시 규칙은 이 파일에, 구현 시점 기록은 `implementation-notes.md`에, 착수 사고 프로토콜은 `FABLE5.md`(이 파일 §1.5가 발동)로 수렴한 실증 구조.
> ArduPilot Copter SITL + Gazebo Harmonic + ROS2 Humble 시뮬레이션 워크스페이스 (macOS ARM). 다른 머신에서 clone해도 이 하네스로 작업을 이어갈 수 있게 유지한다.

## 참조 문서
- **상세 규칙**: [Docs/RULES.md](Docs/RULES.md) — IP 변경 4종 세트·빌드 옵션·센서 변형·트러블슈팅 전체
- **아키텍처**: [AGENTS.md](AGENTS.md) — 2-머신 계층 도식·컴포넌트·인터페이스 정본·설계 확정 이력
- **검증 총괄**: [EXPERIMENTS.md](EXPERIMENTS.md) — 멀티 SITL 등 검증 트랙 대시보드
- **구현 기록**: [implementation-notes.md](implementation-notes.md) — 구현 중 빈칸·가정·결정·이탈·테스트
- **착수 사고 프로토콜**: [FABLE5.md](FABLE5.md) — 사전점검 블록 (§1.5가 발동)
- **세션 재시작·종료 프로토콜**: [memory/session-restart-protocol.md](memory/session-restart-protocol.md) — 재시작 읽기 순서 정본 + 종료 배치 기록 체크리스트
- **TODO**: `Docs/TODO/`

---

## 0. 세션 체계

**단일 세션 — 전 영역** (설계·구현·시뮬 운용·문서·커밋). 재시작 시 읽기 순서 정본 = [memory/session-restart-protocol.md](memory/session-restart-protocol.md).
이 프로젝트 최대 함정 = **기록된 IP는 스냅샷**: 세션 시작 시 §3 절차로 실물 재검증부터.

## 1. 코드 작업

- git 커밋은 **사용자 요청 시에만** 수행 (자동 커밋 금지)
- **불가침 규약** — 변경 시 사용자 승인 필수:
  - **src/·install/ 이중 트리 규약**: 같은 파일이 두 트리에 존재(launch.py, model.sdf, parm, yaml). 수정은 **양쪽 동시** 또는 src 수정 후 `colcon build --packages-select`. install만 고치고 끝내는 것 금지 (`sync_and_build.sh`·`switch_rangefinders.sh`가 이 규약 전제)
  - **`sync_and_build.sh`의 sed 계약**: launch.py `default_value="...:14555"` / cyclonedds.xml `<Peer address=".."/>` 문자열 패턴을 스크립트가 치환한다 — 이 패턴을 깨는 리팩터 금지
  - 재시작 파이프라인 (`start_sim.sh`/`stop_sim.sh`) 인터페이스
- destructive 명령 (`git reset --hard`, `rm -rf install/ build/`, force-push) 사용자 확인 필수
- README.md 등 문서 자동 생성 금지

## 1.5 구현 기록 (implementation-notes.md)

- **⚡발동 규칙: 대형 작업(신규 구현·실험 설계/실행·문서 제작·아키텍처 결정·다파일 수정) 지시를 받으면 [FABLE5.md](FABLE5.md)의 "🧠 사전점검 블록"을 응답 첫 부분에 출력하고 시작한다** — 블록이 안 보이면 프로토콜 미이행. 중형=축약 1~3줄, 소형=생략 가능
- **구현 전 Blind Spot Pass**: ①놓치고 있을 것·위험한 가정은? ②먼저 확인할 기존 파일·영향 인터페이스는? ③성급 구현 시 깨질 것은? ④최소 수직 슬라이스는? — 위험한 가정은 `[가정]`(근거+위험도)으로 선기록
- **구현 중 기록**: 드러난 빈칸·즉석 결정·설계 이탈·게이트 결과를 `implementation-notes.md`에 1줄씩 — `[빈칸][가정][결정][이탈][테스트]`
- **가역성 규칙**: 되돌릴 수 있는 작은 결정 = 기록 후 진행 / 되돌리기 어렵거나 불가침 규약(§1)·재시작 파이프라인·크로스머신 인터페이스 영향 = 기록 후 사용자 질문
- 새 스크립트/러너 신설 직후: `harness_template/prompts/harden-new-harness.md`로 결함 선제 제거

## 2. 문서화

- 모든 서사형 문서: `Docs/` 하위, `YYYY-MM-DD-<키워드>.md` 형식
  - `specs/` — 설계 스펙, 구현 계획 (예: 멀티 SITL 설계 정본)
  - `setups/` — 환경 셋업, 빌드, 테스트 명령어
  - `TODO/` — 작업 계획, 네이밍: `YYYY-MM-DD-TODO-<키워드>.md`
- 단계별 md 문서화 필수. 기억 유실·환경 파악 문제 시 과거 문서를 먼저 재독
- 기존 최상위 문서 존치: `README.md`(GitHub 공개용), `SETUP_MAC_ARM.md`(재현 가이드), `TOPICS.md`(토픽 스냅샷 — 갱신 시점 명기)

## 3. 환경·세션 시작 절차 (실측 확정)

- **환경**: macOS ARM / conda `ros_env`(Python 3.12) / Gazebo Harmonic(`GZ_VERSION=harmonic`) / RMW=`rmw_cyclonedds_cpp` (Zenoh 폐기 — 카메라 전송 실패)
- **매 세션 시작 (순서 고정)**:
  1. 저쪽 Ubuntu IP 확인 + `ipconfig getifaddr en7`로 내 유선 IP 실물 확인 (IP만으로 NIC 판단 금물 — DHCP로 en0↔en7 이동 실측)
  2. `bash sync_and_build.sh [저쪽IP]` — cyclonedds.xml + launch.py 동기화 + 재빌드
  3. 재부팅 후라면 sysctl 3종 (상세: [Docs/RULES.md](Docs/RULES.md#sysctl))
  4. `bash start_sim.sh`
- **주요 스크립트**: `start_sim.sh`(기동) / `stop_sim.sh`(2단 pkill+포트+Fast-DDS SHM 정리) / `sync_and_build.sh [IP]`(IP 동기화+재빌드) / `check_camera.sh [IP]`·`check_rangefinders.sh`(진단) / `switch_rangefinders.sh <변형>`(센서 토글)
- 기동 성공 시그니처: `DDS: Initialization passed` + `AHRS: EKF3 active` (+ 바인딩 에러 0건)

## 4. 네트워크·DDS (실측 확정)

- 이 Mac은 **en7(유선) 필수** — Wi-Fi(en0) DDS **금지** (RTPS 발산·크로스머신 토픽 유실 실증). en7 미연결(집) 시에만 en0 전환 — 절차·리스크: [Docs/RULES.md](Docs/RULES.md#환경-이동)
- IP는 DHCP로 **매일 변동** — 저쪽 IP 변경 시 반드시 **4종 세트** 갱신 (`sync_and_build.sh`가 1~3 처리, 표: [Docs/RULES.md](Docs/RULES.md#ip-변경-4종-세트))
- CycloneDDS 핵심 (`cyclonedds.xml`): `NetworkInterface en7` / `MaxMessageSize 1400B`·`FragmentSize 1344B` (IP fragmentation 회피 — 근거: RULES) / `Peer [저쪽IP]` 유니캐스트
- **금지**: 이 Mac에서 `AllowMulticast=false` (로컬 discovery 붕괴) / `Internal` 태그 (robostack 0.10.x domain 생성 실패)
- 저쪽도 자기 Peer를 **내 en7 IP**로 갱신해야 양방향 성립
- 멀티 SITL 도메인 분리 시 크로스머신은 **도메인별 ROS_DOMAIN_ID 일치** 필요 (설계 정본: `Docs/specs/` 멀티 SITL 스펙)

## 5. 시뮬 운용 (실측 확정)

- SITL은 **eeprom.bin(실행 cwd) 우선** — parm 새로 반영하려면 eeprom 백업 후 삭제 (기존 백업 5종: `eeprom.bin.before_*`)
- 잔여 프로세스가 기체 미동작 유발 → 재시작은 반드시 `stop_sim.sh` 경유 (Fast-DDS 고아 SHM `/private/tmp/boost_interprocess/fastrtps_*`도 자동 정리)
- 로컬 `ros2 topic` 미표시/멈춤 = 묵은 ros2 daemon 캐시 의심 → `--no-daemon` + pkill (외부는 동작하는데 로컬만 안 보이면 도구부터 의심)
- 센서 변형(rangefinder 6종)·월드 전환·검증 명령: [Docs/RULES.md](Docs/RULES.md#distance-sensors) — 현 활성 변형은 `switch_rangefinders.sh status`로 실물 확인
- 대형 토픽(카메라) 미수신 진단 순서: [Docs/RULES.md](Docs/RULES.md#트러블슈팅)

## 6. 멀티 SITL (3인스턴스 — 진행 중 트랙)

- **목표**: 한 Gazebo 월드에 SITL 3기 + DDS 도메인 분리 → 저쪽 **드론별 체화지능 3개**(d1 본기·d2·d3 leaf)가 기체별 수신. 감독지능은 체화 내부 비동기 루프(NATS, 별도 도메인 아님)
- 설계 정본: `Docs/specs/2026-07-09-multi-sitl-3instance-design.md` / 검증 현황: [EXPERIMENTS.md](EXPERIMENTS.md)
- 핵심 확정 사실 (file:line 근거는 설계 정본에): `--instance N`=기본 포트 +10N (**단 DDS_UDP_PORT는 오프셋 비대상 — parm 명시 필수**) / `DDS_DOMAIN_ID` parm 실존 / XRCE 세션 키 고정 → **인스턴스별 agent 필수** / eeprom cwd 상대 → **인스턴스별 작업 디렉토리 필수** / gz 절대 토픽(`/gimbal/*`,`/range/*`)은 모델 사본별 개명 필수
- 단일 인스턴스 파이프라인(§3·§5)은 **불변 기본값** — 멀티는 별도 스크립트·설정으로 병행 (기존 오염 금지)

## 프로젝트 구조

```
ardu_ws/
├── CLAUDE.md               ← 이 파일 (필수 규칙, 자동 로드 정점)
├── FABLE5.md               ← 착수 사고 프로토콜 (§1.5가 발동)
├── implementation-notes.md ← 구현 기록 (빈칸·가정·결정·이탈·테스트)
├── EXPERIMENTS.md          ← 검증 총괄 대시보드
├── AGENTS.md               ← 아키텍처 문서 (인터페이스 정본)
├── Docs/                   ← 문서 루트
│   ├── RULES.md            ← 상세 규칙 레퍼런스
│   ├── specs/ setups/ TODO/
├── memory/                 ← 기억 프로토콜 2종 (memory-protocol·session-restart-protocol)
├── harness_template/       ← 원본 템플릿 (참조용 — 수정 금지)
├── src/ · install/ · build/ ← colcon 이중 트리 (§1 규약)
├── *.sh                    ← 재시작·진단·토글 파이프라인
└── cyclonedds.xml          ← DDS 설정 정본
```

## 7. 자율 지식 축적 (AKC — 자율 기억)

> 유저 지시 없이도 작업 중 발견되는 룰·맥락·결정·함정을 **알아서 판단해 기록**한다. 인지 부하 0 지향. 상세: [memory/memory-protocol.md](memory/memory-protocol.md)

- **6 트리거** — ①도메인 진실 정정/확정 ②설계 결정 확정 ③함정/근본원인 발견 ④단계/마일스톤 완료 ⑤유저 선호/금지 ⑥환경/IP 변경
- **자연 경계 배치** — 즉시 기록은 ③함정·⑤선호·⑥환경만, 나머지는 마일스톤·세션 종료에 배치. 사실당 **정본 1곳 전문 + 나머지 1줄 포인터**. MEMORY.md는 순수 인덱스(<17KB)
- **저장소 라우팅 (5곳 — 확정 결정 2026-06-16, 재제안 금지)**:
  ①CLAUDE.md=불변 규칙 ②**파일 메모리(`~/.claude/projects/-Users-swjo-yonsei-ai-aerion/memory/`)=진실원천** (기존 접두사 유지: `project_*`/`feedback_*`/`reference_*`/`user_*`) ③memoir=보조 회상 채널(병행 ON, 일원화 금지) ④Docs=서사·스펙 ⑤**git 사본 `.claude/memory/`=이식용 스냅샷** — 의미 변화 시 ②→⑤ 동기화(휘발 정보(IP 등) 커밋 금지, 정책: `.claude/RESTORE.md`)
- **자율성 경계** — ②④⑤ 기록은 말없이 자동(가역; ③memoir는 자동 캡처 전용 — 능동 기록처 아님); CLAUDE.md 규칙 신설/코드 수정은 먼저 통지·승인
- **투명성** — 기록한 턴은 응답 말미 `🧠 기억: <slug> — <훅>` 1줄. "지워/기억하지마"는 즉시 이행
- **중복 방지** — 생성 전 MEMORY.md 인덱스 확인 → 기존 갱신 우선. 정정된 거짓 기록은 삭제
- **세션 종료 시** — [memory/session-restart-protocol.md](memory/session-restart-protocol.md)의 종료 배치 체크리스트 수행 (git 사본 ⑤ 동기화 포함)
