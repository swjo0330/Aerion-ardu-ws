# Memory Index

- [페이블5 수준 작업 자율성 기대](feedback_fable_autonomy.md) — 시키지 않아도 메모리·문서·가이드를 스스로 작성·동기화. 단 과잉 엔지니어링 금지
- [AKC 자율 메모리 프로토콜 v3](feedback_auto_memory_protocol.md) — settings.json 후크 기반 자동 발동(TRIGGER→DETECT→WRITE→SYNC); 현재 구조 완성(hooks만 활성화 필요)
- [ardu_ws 프로젝트 상태](project_ardu_ws.md) — macOS ARM SITL+Gazebo+ROS2, en7 유선; 하네스 도입(CLAUDE/FABLE5/게이트)·멀티SITL 3기(20m삼각·도메인분리)·Aerion-integration 연동 규격·5단계 검증 게이트
- [빌드 패치 및 피드백](feedback_build.md) — colcon cmake 옵션, protobuf 충돌, CycloneDDS AllowMulticast 주의
- [DDS 대형 메시지 전송 해결](feedback_dds_large_msg.md) — /camera/image IP fragmentation 문제, MaxMessageSize/FragmentSize 설정, 진단 순서
- [DDS over Wi-Fi 구조적 한계](feedback_dds_wifi.md) — 고부하 한계·완화책 + ⚠️실측 반례(집 480p 6.5Hz 성공): 안 되면 매체 탓 전에 Peer IP·NIC 실측(부재 NIC=노드 사망)
- [distance-sensors 구현 상태](project_distance_sensors.md) — iris 전/좌/우 gpu_lidar 3개 → RNGFND1~3 직결, switch 스크립트 토글, 잔여 검증 박스 spawn
- [switch-variants 백업 패턴](feedback_switch_variants.md) — 설정 파일 `.baseline`/`.variant` 사본 + cp swap 토글, src/install 두 트리 양쪽 동시 처리
- [ros2 좀비 daemon 진단 함정](feedback_ros2_daemon_trap.md) — 로컬 ros2 topic 미표시/멈춤은 묵은 데몬 캐시 의심, --no-daemon + pkill, 외부 동작하면 로컬 도구부터 의심
- [Fast-DDS SHM 세그먼트 누수](feedback_fastdds_shm_leak.md) — 재시작 반복 시 /private/tmp/boost_interprocess/fastrtps_* 무한 누적(micro_ros_agent), stop_sim.sh에 정리 통합(2026-07-09)
- [PX4 전환 검토 결론](project_px4_eval.md) — ArduPilot→PX4 분석, 보류 결정. macOS 네이티브 불가, PX4는 저쪽 Ubuntu만. SITL 바꿔치기 불가(한 세트 전환)
- [Claude Code 환경 + Opus 4.8](reference_claude_code_env.md) — native installer 2.1.156, Opus 4.8(2026-05-28) 모델 ID `claude-opus-4-8`, 활성화 방법, 4.7 자아의 cutoff 함정 경고
