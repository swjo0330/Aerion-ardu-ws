# 세션 재시작·종료 상기 프로토콜 (ardu_ws)

> 장기 프로젝트의 최대 피로원 = 세션 간 맥락 유실. 재시작 시 읽는 순서와 종료 시 남기는 것을 고정한다.
> 이 프로젝트는 **단일 세션 — 전 영역** (설계·구현·시뮬 운용·문서·커밋, CLAUDE.md §0). 세션 유형 분기 없음.

## 재시작 읽기 순서 (세션 시작 직후)

1. **파일 메모리 `project_ardu_ws.md` 최신 절** (`~/.claude/projects/-Users-swjo-yonsei-ai-aerion/memory/`) — 지난 세션이 남긴 "완료한 것 + 다음 재개 지점"
2. **`implementation-notes.md`** — 미결 `[빈칸][가정]`(열려 있는 것부터)과 최근 `[결정][이탈]`
3. **`EXPERIMENTS.md` 진행판** — 검증 트랙 현황과 블로커
4. **(필요 시) 정본 문서**: 작업 대상의 `Docs/specs/` 설계 정본, 환경 문제면 `Docs/setups/`·[Docs/RULES.md](../Docs/RULES.md)

읽기 완료 후 작업 착수 전, 환경은 기억이 아니라 **CLAUDE.md §3 시작 절차(실물 검증)**를 따른다 — 아래 규율 참조.

## 기억 검증 규율

- **기억 = 시점 관찰, 라이브 상태 아님** — 코드 동작·파일:라인 인용은 기록 시점의 것. 사실로 단정하기 전에 **현재 실물로 재검증**한다
- **이 프로젝트 최대 함정: 기록된 IP = 스냅샷** — IP는 DHCP로 매일 변동. 아래 **시작 IP 루프**가 정본.

## 시작 IP 루프 (매 세션 고정 — 유저가 두 IP 통보 시 즉시)

> 유저가 세션 시작에 **내 IP + 저쪽(지능측) IP**를 항상 알려준다(확약 2026-07-14). 받으면 아래를 무조건 태운다. 근거·정책: 파일 메모리 `feedback_startup_ip_methodology.md`. **IP 포함 known-good 샘플·연결 세팅 단계·자원프리 항목명 정본**: [../Docs/setups/2026-07-14-known-good-crossmachine-wifi-sample.md](../Docs/setups/2026-07-14-known-good-crossmachine-wifi-sample.md).

1. `bash sync_and_build.sh <저쪽IP> <내IP>` 실행 — 내IP를 주면 **그 IP 소유 NIC로 직접 바인딩**(멀티호밍·가상NIC 오선택 원천차단). 생략 시 Peer-서브넷 일치 NIC 자동(`ifconfig -l`에서 lo/utun/awdl/llw/bridge/gif/stf/ap/anpi/vlan + Thunderbolt 브리지멤버 배제, 기본라우트 우선 tiebreak) → `cyclonedds.xml` NetworkInterface·Peer 자동 재작성 + 재빌드
2. **교차확인**: 스크립트 출력 `감지된 내 NIC/IP`가 유저가 말한 내 IP와 일치하는가? 다른 /24면 ⚠️ 경고(같은 /16 랩이면 정상, 아니면 도달 불가 → 실물 재확인)
3. `bash start_sim.sh` — 프리플라이트가 바인딩 NIC 생존 확인(죽었으면 활성 목록 출력 + fail-fast, "부재 NIC=노드 사망" 함정 차단)
4. 기동 시그니처 `DDS: Initialization passed` + `AHRS: EKF3 active` 확인
5. **arducopter 교체 검증**: `ps -o pid,etime -p $(pgrep -f arducopter|head -1)` — 새 PID + 초 단위 나이 = fresh 정상 (분 단위 = 미교체 신호). 매 재시작 보고에 `PID 전→후 · 나이` 표기 (근거: 파일 메모리 `feedback_restart_arducopter_verify.md`, 절차 정본: `Docs/RULES.md` 재시작 절차)
- **캐스트 정책(공유 회사망)**: Peer 유니캐스트 **유지** — 디폴트 멀티캐스트로 돌리지 말 것(디스커버리·대형데이터 서브넷 flooding). 근본은 raw를 wire에 안 올리기 [[feedback_dds_raw_lan_flood]]
- IP만으로 NIC 판단 금물 — 위 자동감지가 실물 기준으로 결정한다
- **수치 인용은 '실측 로그' 기준** — 성능치·포트·파라미터 값은 기억이 아니라 측정 시점이 명기된 실측 로그(`logs/`·`Docs/setups/` 기록)에서 인용. 실측 근거가 없으면 재측정이 인용보다 먼저다
- **상태 토글류도 실물 확인** — 현 활성 센서 변형은 기억 대신 `switch_rangefinders.sh status`로 확인
- 기억과 실물이 어긋나면: **실물이 이긴다** → 틀린 기억을 즉시 정정·삭제 ([memory-protocol.md](memory-protocol.md) 실행 원칙 3)

## 세션 종료 배치 기록 체크리스트

- [ ] 이번 세션의 사실①·결정②·마일스톤④ 배치 기록 ([memory-protocol.md](memory-protocol.md) 트리거표)
- [ ] `project_ardu_ws.md` 최신 절 갱신 — "완료한 것 + 다음 재개 지점" 1~2줄
- [ ] `MEMORY.md` 인덱스 동기화 (신규/변경 포인터, <17KB)
- [ ] `implementation-notes.md` 해결 항목 → 아카이브 1줄 이동, 서사는 `Docs/` 정본 문서로 승격
- [ ] 트랙 상태를 바꿨으면 `EXPERIMENTS.md` 진행판 갱신 (바꾼 세션이 책임)
- [ ] **git 사본(`.claude/memory/`) 동기화 — 의미 변화분만** (②→⑤ 복사. IP 등 휘발 정보 커밋 금지, commit은 사용자 승인 — 정책: `.claude/RESTORE.md`, [memory-protocol.md](memory-protocol.md) §0-2)
- [ ] 자기 감사 1회: 사전점검 블록 없이 착수했거나 **`✅ 게이트` 선언 없이 완료 선언한** 대형 작업이 있었나 → 있으면 `[이탈]` 기록 (FABLE5.md §5단계 검증 게이트, [../Docs/reviewer-checklist.md](../Docs/reviewer-checklist.md))
- [ ] 정리 패스: 파편 병합·거짓 기록 삭제·끊긴 포인터 점검 → `🧹 정리:` 1줄
