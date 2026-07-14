# implementation-notes.md — 구현 기록

> **역할**: 구현 작업 중 발생하는 것들을 **그 자리에서 1줄씩 기록**하는 리스트. 계획에 없던 빈칸, 검증 안 된 가정, 즉석 결정, 설계에서 벗어난 구현, 게이트 결과 — 나중에 "왜 이렇게 돼 있지?"의 답이 여기 남는다.
> **형식**: `- [유형] YYYY-MM-DD | <대상> | <내용 1~2줄> | (근거/포인터)` — 최신이 위.
> **유형 5종**:
> - `[빈칸]` 구현 중 드러난 미해결 TBD·보류
> - `[가정]` 검증 안 된 전제 — 근거 + 위험도(낮/중/높) 명기, 실측 확정 시 닫음
> - `[결정]` 설계 선택과 근거 — 가역적 소결정은 기록 후 진행, 비가역·아키텍처 영향은 기록 후 사용자 질문
> - `[이탈]` 정본 설계·계획과 다르게 구현한 것 — 이유·위험도·가역 여부
> - `[테스트]` 게이트·실측 결과 요지 (수치 정본은 EXPERIMENTS.md)
> **운영**: 해결·확정된 항목은 하단 아카이브로 1줄 이동. 서사 정본화(세션 문서·메모리·registry)는 AKC 자연 경계 기록이 담당 — 여기는 구현 시점의 원본 기록.

---

## 기록 (최신 위)

- [테스트] 2026-07-14 | 저쪽 프레임 **처리율 60~80fps 도달**(매우 양호) — 단 전달률 아님 | 구성 동일(양단 집 Wi-Fi, 내 en0 45.50 ↔ 저쪽 45.93). 저쪽 처리 FPS 60~80(사용자 확인). ⚠️ **소스 gz 렌더 ~22Hz이므로 60~80은 카메라 프레임 전달률(≤22Hz)이 아니라 저쪽 처리/검출 루프 처리량** — 입력을 고속 재처리. 의미: 파이프라인이 저쪽 처리를 병목 없이 충분히 공급. 2026-07-13 "30~40 증언"과 같은 계열(처리/검출 루프 혼동). 기록 정본: `Docs/setups/2026-07-14-known-good-crossmachine-wifi-sample.md` | (사용자 확인 2026-07-14)
- [테스트] 2026-07-14 | 크로스머신 compressed over Wi-Fi **18~25fps 양호 수신** — fps는 브리지 하드상한 아니라 **호스트부하 민감(정정)** | 구성: 내 en0(**Wi-Fi** 45.50) ↔ 저쪽(**Wi-Fi** 45.93), `/camera/image/compressed`(JPEG) 저쪽 실측 **18~25fps**(사용자 확인, 기대치 적합). gz 소스 렌더 22Hz. **로컬 4Hz는 측정 아티팩트**(동시 hz/bw/gz 프로브 + Cursor/Chrome/Claude로 load 19.7·RTF 0.566). 부하 정상 시 브리지가 소스 22Hz 근접 → 2026-07-13 "8~12Hz 상한"은 부하조건값이지 **하드상한 아님**. compressed는 Wi-Fi로 18~25 안정 = **저대역 파이프라인 검증(양쪽 Wi-Fi)**. ⚠️ raw-over-Wi-Fi "불가" 단정 금지 — 과거 불안정 주원인은 설정(Peer stale·부재/오NIC·멀티호밍·소비자AP)으로 규명, 매체 한계 아님(480p raw 성공 반례). compressed는 저대역 안전 기본값. 토픽명 변경은 지연 무관(DDS 라벨), republisher 홉은 latency만 소폭·fps 무영향(raw=compressed). 저쪽 새 토픽(`/camera/image/compressed`) 구독 확인됨 | (실측 2026-07-14)
- [결정] 2026-07-14 | 시작 IP 방법론 + NIC 자동바인딩을 하네스에 반영 | 유저가 매 시작 내IP+저쪽IP 통보 → `sync_and_build <저쪽IP> <내IP>`가 그 IP 소유 NIC 직접 바인딩(멀티호밍·가상NIC 오선택 차단), 생략 시 Peer 서브넷 일치 자동+기본라우트 tiebreak. cyclonedds NetworkInterface·Peer 자동 재작성, start_sim 프리플라이트(죽은 NIC fail-fast+서브넷 경고). 검증 워크플로우(5에이전트)로 D1(anpi·브리지멤버 배제)·D2(Peer sed 공백변형 `[^"]*`)·D3(서브넷경고)·D5(IP부재 중단) 경화, D4(/24→/16 경고만) 유보. CLAUDE §3/§4·session-restart-protocol·feedback_startup_ip_methodology 동기화. ⚠️ D2가 §1 sed계약 라인 수정(의도 불변) | (실측: 양경로 en0 선택·en1/en4/anpi 배제)
- [테스트] 2026-07-13 | 카메라 주기 차등실험 4런 — 병목=ros_gz_bridge 이미지 경로(8~12Hz 상한), 압축·republisher 무죄 | update_rate 10→30 적용(이중트리, 가역): gz 렌더 24.8~28.4Hz 도달·RTF 100~107%. 그러나 ROS단(bridge 이후)은 구독자 수 불문 8~12Hz 요동(구독1=8.5/구독2=12.0/구독3=8.9 — 팬아웃 단조관계 없음, 런간 편차). compressed=raw 동률 일관(재발행 손실 0). '이 노트북에서 30-40 수신' 증언은 현 증거로 설명 불가(미확인 — 유력: 저쪽 detect_frame 42Hz 자체루프와 혼동. GstCameraPlugin은 127.0.0.1 설정+로드실패라 배제). 도메인에러 6건은 en7 사망(집 이동)이 원인 — en0 전환 해소 | (차등 4런 실측 2026-07-13)
- [결정] 2026-07-13 | update_rate 30 유지 | gz 렌더 여유(RTF 100%) 확인, bridge가 상한이라 실효 8~12Hz — 30 유지 시 누적저하 헤드룸 확보. 되돌리기: sed 10, 이중트리 | (가역)

- [결정] 2026-07-13 | RViz 카메라 토픽 → /camera/image_local + raw 격리 유지 확정 | RViz Image display가 표준 /camera/image(발행자 0, raw 격리) 구독해 no image → iris.rviz Topic Value를 /camera/image_local로(install+src). RViz Image display는 raw(sensor_msgs/Image)만 표시 가능(CompressedImage 불가), RViz는 로컬이라 raw_local 봐도 대역 무관. raw 격리는 환경(집 Wi-Fi) 안전판이라 랩에서도 유지(사용자 결정 "그냥 두자"). compressed로 보려면 rqt_image_view. 현 구성 정상 동작 확정: clean 재시작 시 crossmachine compressed 10Hz·RViz image_local 표시·재시작 절차 자원프리 검증 | (iris.rviz, 사용자 확정 2026-07-13)

- [테스트] 2026-07-13 | 카메라 발행률 누적 저하 규명 + 재시작 절차 강화 | 증상: compressed가 켜둘수록 10.08Hz(clean)→2.2Hz 저하, RTF 100% 유지(GPU 렌더 드리프트 추정). 해결=clean 재시작(gz server 신규 기동→10Hz 회복). stop_sim 보강(_ros2_daemon pkill·멀티 오프셋 포트·자원프리 검증리포트), start_sim에 기존sim 감지→stop 자동선행(NO_CLEAN=1로 생략). Peer/네트워크 아님(시뮬 발행 자체 저하 — 저쪽 Hz 낮으면 시뮬측 hz부터 실측). RULES 트러블슈팅+재시작절차 기록 | (2026-07-13 실측, stop_sim.sh·start_sim.sh)

- [테스트] 2026-07-12 | raw 카메라 로컬 격리 — 크로스머신 raw 원천 차단 | bridge raw ROS명 camera/image→camera/image_local(이중트리)+republisher in-remap(단일 start_sim·멀티 launch). 실기동: 표준 /camera/image Pub 0(rviz 구독만·데이터 0)·image_local republisher 1구독·compressed 8.7Hz. 저쪽이 raw 구독해도 발행자 없어 44Mbps 불가. 단일·멀티 both | (실측 2026-07-12)
- [결정] 2026-07-12 | 네트워크 마비 근본원인 = ①raw 표준노출(해소:격리) ②en0+en5 same-subnet multi-homing | 실측: 저쪽 미접속 시 크로스머신 0. 마비는 저쪽 raw구독 or multi-homing broadcast. 유선단독이면 Wi-Fi off 권장(sudo ifconfig en0 down) — RULES 경고 추가. 집 유선=en5(랩 en7과 다름) | (nettop·route·ifconfig 실측)

- [결정] 2026-07-11 | D10 개정 — 카메라 3기 전부 복원, 원격 전송은 compressed 전용 | 사용자 결정(3대 카메라 독립 채널). gen: nocam 제거·브리지 camera 보존(range만 d2/d3 제거), launch: 전 인스턴스 republisher. 3채널 합 ≈660KB/s 설계치. 워크플로우 코드에이전트 성공/문서에이전트 미완→문서는 인라인 마감. 규격서·D10·compressed 스펙 갱신 후 integration push(194b9b3) | (Docs/specs 2종, gen_multi_assets.sh)
- [테스트] 2026-07-11 | 3기 compressed ×3 실기동 게이트 **통과** | EKF3 3/3, RTF≈40%(카메라 ×3 부하에도 유지), 도메인별 hz: d1 4.45/d2 4.62/d3 4.56, d1↔drone2 교차오염 0. 3채널 합 ≈390KB/s(wall) | (실측 로그 2026-07-11)

- [테스트] 2026-07-11 | 카메라 compressed 재발행 파이프라인 통합·검증 완료 | 단일: start_sim(CAMERA_COMPRESS 토글, 기본 ON)+stop_sim pkill 통합, 재기동 실측 **7.7Hz·29KB/frame·~220KB/s (raw 900KB 대비 1/31)**. 멀티: drone_multi.launch.py instance 0 조건부 Node(문법·배포 grep 통과, 실기동은 T4). 규격서 B표에 compressed 행+raw Wi-Fi 구독금지 명시. 워크플로우는 org 한도로 spawn 실패 → 인라인 수행 | (Docs/specs/2026-07-11-camera-compressed-republish.md, 실측 로그)
- [결정] 2026-07-11 | "ipTIME 완치" 판정 철회 — 실험 결함(측정 시 원격 구독자 부재, 로컬 발행≠공중 전송) | 원격 구독 후 ipTIME도 불안정 재현 → raw 44Mbps는 소비자 Wi-Fi 일반 한계, 해법=compressed. ② 게이트에 "원격 구독자 존재 확인 후 측정" 교훈 반영 대상 | (RULES·메모리 정정됨)

- [테스트] 2026-07-10 | 집 Wi-Fi 크로스머신 480p 실측 성공 + 2026-05-08 미제 근본원인 규명 | 이 Mac(en0 45.50)→저쪽 맥북(45.93): /camera/image 6.5Hz·/clock·camera_info 15s 실측, 구독자 발견 1, 송신 UDP full-buffer drop 증가 0. 원인=저쪽 장소의존 설정 2건(Peer stale + 부재 NIC en4→노드 사망) — AP isolation 의심은 오진, Wi-Fi 물리 결백(사용자 가설 적중). 정정 반영: CLAUDE §4·RULES Wi-Fi 이력·글로벌 dds_wifi 메모·project_ardu_ws | (실측 로그, 저쪽 15s 리포트)
- [가정] 2026-07-10 | 랩 유선 vs 집 Wi-Fi 성능 동급 | 병목=sim RTF라 매체 차이 체감 없을 것 — 랩 단일모드 크로스머신 hz 동일조건 실측 없어 미확정. 랩 복귀 시 1회 실측로 닫기. 위험도 낮 | (network 전달률 ~100% 실측)

- [테스트] 2026-07-10 | 문서·하네스 전체 정합성 감사 — stale 4건 수정 | ①CLAUDE 구조블록에 신규파일(reviewer-checklist·multi_src·멀티스크립트) 추가 ②README en0→en7 오기·옛IP(.33/.35) 예시화·멀티모드 링크 추가 ③AGENTS §4 표에 20m삼각 스폰행+cwd multi/ 정정 ④EXPERIMENTS T5 간트·날짜. 메모리(project_ardu_ws 최종대형/게이트/연동 + MEMORY.md 인덱스) 갱신. 재grep 잔여 0·게이트 배선 유지 확인 | (grep 실측)

- [결정] 2026-07-10 | 5단계 검증 게이트 + 리뷰어 체크리스트 하네스 도입 | 이미지 5단계(범위→근거→풀기→검증→보고)를 품질 게이트로 명문화. ①③은 기존(사전점검·최소diff) 매핑, ②④⑤ 게이트 신설. 자가체크(L1)+적대검증 서브(L2). 배치: FABLE5.md §게이트 절 + Docs/reviewer-checklist.md + CLAUDE §1.5 배선 + restart-protocol 자기감사. 이 프로젝트 한정 | (설계정본 Docs/specs/2026-07-10-five-stage-gate-design.md, 사용자 승인·brainstorming Q1~Q3)
- [테스트] 2026-07-10 | 게이트 자체 검증(도그푸딩) 통과 | ④ placeholder 0·배선 체인 8링크 전부 실재. 리트로: 세션 실패 3건(navsat 이중계산→②-4, lock_step 스톨→④ sim time, ros2 list 플레이크→④ 도구의심) 모두 체크리스트가 커버 확인 | (grep 실측)

- [테스트] 2026-07-09 | T4 로컬 3기 게이트 통과 — 최종 목표(3 SITL) 달성 | arducopter×3·DDS 3/3·EKF3 3/3·RTF≈40%·3도메인 독립(오염 0)·d2/d3 /ap/time 실데이터·본기 카메라 4.5Hz. 함정: ros2 topic list의 /ap 열거 플레이크(echo로 판정할 것). 잔여=저쪽 3인스턴스 수신(저쪽 관할) | (EXPERIMENTS.md T4)

- [테스트] 2026-07-09 | T3 2기 수직 슬라이스 게이트 1~3 통과 | G1 arducopter×2 / G2 도메인 완전독립(d1=drone1 15+ap 17, d2=drone2 15+ap 17, 교차오염 0) / G3 EKF3 active×2 + DDS passed×2 / 카메라 d1 ~1.9Hz 흐름 확인. 잔여: 단일 회귀 게이트(§4.1)·3기 확장 | (logs/multi_i0·i1.log)
- [결정] 2026-07-09 | 멀티 모델은 lock_step=0 | lock_step=1은 온라인 기체 servo 대기 직렬화+미접속 기체 폴링으로 sim time 붕괴(실측 RTF 0.2%→0으로 수렴, 링크 다운). 0 전환 후 RTF 20%·부팅 성공. 단일 모드(lock_step=1)는 불변 | (gen_multi_assets.sh, ArduPilotPlugin.cc:1194-1203)
- [결정] 2026-07-09 | leaf 기체(d2/d3)는 무카메라 — gimbal_small_3d_nocam 사본 참조 + 브리지에서 camera·range 4항목 제거 | 사용자 확정: 카메라·YOLO는 본기(d1) 1대만 정본. S-5 집단감독은 NATS swarm.state.* 1Hz 상태 스트림 기반, leaf는 vision 없는 경량 상태발행기(rule_only). 유의: 본기 장애물 조우는 본기 카메라 시야에서 일어나야 함(leaf 장애물은 상태 이상으로만 감독에 잡힘) | (사용자 확정 2026-07-09, gen_multi_assets.sh A1b)
- [결정] 2026-07-09 | 아키텍처 정정: 도메인 1/2/3 = 드론별 **체화지능** 3개 (감독지능은 별도 도메인 아님) | 사용자 정정: 드론마다 체화지능이 있고(1/2/3), 감독지능은 체화 내부 **비동기 루프**로 NATS swarm.state.* 소비(DDS 무관). 이전 "감독←d3" 매핑 폐기. DDS 도메인은 순수 체화 3개 기준 | (사용자 확정 2026-07-09, AGENTS.md §5.1·규격서)
- [결정] 2026-07-09 | 멀티 SITL 분리축 = DDS 도메인 d=i+1 | 근거: `/ap/*` 토픽명이 펌웨어 고정이라 네임스페이스 분리 불가 → 도메인 분리 채택 | (AGENTS.md §5.1)
- [결정] 2026-07-09 | 실험 registry 미도입 | 검증 트랙은 EXPERIMENTS.md 대시보드만 운용 — 과잉 방지. 수치 트랙 생기면 재검토 | (EXPERIMENTS.md)
- [결정] 2026-07-09 | 멀티는 start_multi_sim.sh 신규 병행 | 단일 인스턴스 파이프라인(start_sim.sh/stop_sim.sh) 불변 — 기존 오염 금지 | (CLAUDE.md §6)
- [빈칸] 2026-07-09 | 저쪽 Ubuntu mavros 3인스턴스·ROS_DOMAIN_ID 설정 | 저쪽 관할 — 이쪽은 인터페이스만 AGENTS.md 정본으로 유지 | (AGENTS.md §4 포트·도메인 할당표)
- [빈칸] 2026-07-09 | XRCE agent 동일 키 2클라이언트 충돌의 정확한 실패 양상 | agent 코어 소스 부재로 미확인 — 인스턴스별 agent 필수 판단의 근거 보강 필요 | (CLAUDE.md §6)
- [빈칸] 2026-07-09 | path_marker 동기→비동기 전환 | (구 CLAUDE.md "남은 작업" 2026-05-07 기준 → 이관)
- [빈칸] 2026-07-09 | Aerion-Foundation 서브모듈 등록 — 저쪽 push 대기 | (구 CLAUDE.md "남은 작업" 이관)
- [빈칸] 2026-07-09 | `iris_runway_des.sdf` src측도 `model://` 수정 — install만 수정된 상태, src/install 이중 트리 규약 위반 잔존 | (구 CLAUDE.md "남은 작업" 이관)
- [빈칸] 2026-07-09 | Distance sensor 회피 동작 실비행 검증 — GUIDED 이륙 → 벽 접근 → AVOID_MARGIN=2m 정지 | (구 CLAUDE.md "남은 작업" 이관)
- [빈칸] 2026-07-09 | 박스 spawn 검증 — `gz service /world/map/create`로 iris 정면 박스 → /range/front 값 확인 | (구 CLAUDE.md "남은 작업" 이관)
- [빈칸] 2026-07-09 | AVOID_ENABLE=7 모드변경 지연 원인 격리 확인 — 의심 후보 | (구 CLAUDE.md "남은 작업" 이관)

## 아카이브 (닫힌 항목)

- [가정→해소] 2026-07-09 | 카메라 3기 대역폭 → 설계 변경으로 무의미화: leaf 무카메라 확정(사용자), 카메라는 d1 1대만 | (위 [결정] leaf 무카메라)
