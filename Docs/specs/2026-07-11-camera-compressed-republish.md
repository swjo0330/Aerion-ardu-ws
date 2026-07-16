# 카메라 compressed 재발행 — 설계·통합 정본

> 작성 2026-07-11 · 상태: 구현·단일 검증 완료 · 발단: 지능측 요청(집 Wi-Fi raw 붕괴) · 3대 멀티 버전 포함

## 배경 (근거)

- 집 Wi-Fi에서 raw 480p `/camera/image`(≈900KB/frame ≈ UDP 조각 ~670개, ≈44Mbps)가 **조각 손실로 0~1Hz 붕괴** — 지능측 실측 손실 최대 29%, 시뮬측 차등실험 스트림 중 45%/972ms ↔ 유휴 1%/21ms [실측로그]. 소형 토픽(/clock·camera_info·MAVLink)은 전부 정상.
- "ipTIME 교체로 완치(0%/38ms)" 판정은 **실험 결함으로 정정(2026-07-11)** — 그 측정 시 원격 구독자 부재로 raw가 공중에 실리지 않았음(DDS는 구독자 있어야 전송, **로컬 발행≠공중 전송**). 원격 구독 후 ipTIME에서도 불안정 재현 → 소비자용 Wi-Fi AP 일반 한계로 결론.
- 해법 = **송신측 대역 축소**: republish(raw→JPEG compressed, ~187KB/frame ≈ 조각 ~140개, 대역 ~1/20). 지능측 vision은 raw·compressed **이중구독 기구현**(그쪽 코드 확인) — 수신측 변경 0.

## 설계

| 항목 | 단일 모드 | 멀티 3기 모드 |
|---|---|---|
| 토픽 | `/camera/image/compressed` (`sensor_msgs/CompressedImage`) | `/drone{N}/camera/image/compressed` — **3기 전부** (D10 개정 2026-07-11), 도메인별 독립 채널, 합 ≈660KB/s |
| 실행 주체 | `start_sim.sh`가 백그라운드 기동 (path_marker 패턴 동일) | `drone_multi.launch.py` 전 인스턴스 Node |
| 토글 | `CAMERA_COMPRESS=0 bash start_sim.sh` 로 끔 (기본 ON) | 상시 (전 기체) |
| 종료 | `stop_sim.sh` pkill `image_transport/republish` (1차+2차 -9) | 동일 (전역 pkill이 커버) |
| raw | 로컬 소비용 그대로 발행 — **원격은 raw 구독 금지**(구독하면 공중 44Mbps 재유발) | 동일 |
| 도메인 | 0 | 각 기체 자기 도메인 N (호출 셸 `ROS_DOMAIN_ID=N` 상속) — 독립 채널 |

- 플러그인: `ros-humble-compressed-image-transport` (robostack, 2026-07-10 ros_env 설치) [사용자확정 설치]
- 리맵 문법 `-r in:=… -r out/compressed:=…` 은 실기동으로 검증됨 (`ros2 node info /image_republisher` 발행 목록 실측 2026-07-11)
- 멀티 3기 대역 [계산 — 단일 compressed bw 실측(수백KB/s, 2026-07-11) 외삽]: **≈220KB/s × 3기 ≈ 660KB/s (≈5.3Mbps)** — raw 3기(≈44Mbps×3=132Mbps) 대비 ~1/200. 3기 동시 실측치는 T4 게이트에서 확정.
- 멀티 배선 [코드확인]: `drone_multi.launch.py:144-157` — republish Node를 인스턴스 조건 없이 전 기체 append (i==0 조건부 아님)

## raw 로컬 격리 (2026-07-12 — 네트워크 원천 보호)

raw 카메라 ROS 토픽명을 **`camera/image_local`(로컬 전용)**로 변경 (bridge yaml `ros_topic_name`, 이중 트리). 효과: 크로스머신 도메인에서 표준 `/camera/image`는 **발행자 0**(rviz가 구독만 시도해도 데이터 없음) → 저쪽이 raw를 구독해도 44Mbps가 물리적으로 나갈 수 없음. republish `in`을 `camera/image_local`로 remap해 로컬 raw→compressed 변환은 유지. **실기동 검증(2026-07-12)**: `/camera/image` Pub 0 · `/camera/image_local` republisher 1구독 · `/camera/image/compressed` 8.7Hz. 멀티도 `/drone{N}/camera/image_local` 동일 패턴(gen 상속). rviz의 `/camera/image` 구독 잔재는 발행자 0이라 무해(원하면 rviz config를 image_local로).

## 검증 게이트

- **단일 (✅ 2026-07-11)**: 정적 — bash -n·py_compile·배선 grep·pkill 패턴 정밀성(매칭=republish 실체만) 통과. 런타임 — 재시작 후 `/camera/image/compressed` hz(≈raw hz)·bw(수백KB/s) 실측 + stop 왕복(고아 없음).
- **멀티 (📌 T4에 묶음)**: 정적(py_compile+install 배포 grep) 통과. 실기동(3기 전부 각자 도메인에서 `/drone{N}/camera/image/compressed` 발행 확인 — D10 개정 2026-07-11 반영)은 다음 멀티 기동 시.

## 저쪽(지능측) 소비 규약

- Wi-Fi 환경: **compressed만 구독** (`/camera/image/compressed`, 멀티에선 각 도메인의 `/drone{N}/…` — 3기 전부, D10 개정 2026-07-11). raw 구독 금지.
- 유선/랩 환경: raw 직구독 가능 (기존 규격 유지) — compressed는 병행 발행되므로 어느 쪽이든 무중단.
