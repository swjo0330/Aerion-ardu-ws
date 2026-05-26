# Memory Index

- [ardu_ws 프로젝트 상태](project_ardu_ws.md) — macOS ARM SITL+Gazebo+ROS2, CycloneDDS en5 유선, /camera/image 전송 해결
- [빌드 패치 및 피드백](feedback_build.md) — colcon cmake 옵션, protobuf 충돌, CycloneDDS AllowMulticast 주의
- [DDS 대형 메시지 전송 해결](feedback_dds_large_msg.md) — /camera/image IP fragmentation 문제, MaxMessageSize/FragmentSize 설정, 진단 순서
- [DDS over Wi-Fi 구조적 한계](feedback_dds_wifi.md) — Wi-Fi에서 RTPS 발산 원인, 완화책(QoS BE, compressed, Zenoh), macOS sysctl 천장
- [distance-sensors 구현 상태](project_distance_sensors.md) — iris 전/좌/우 gpu_lidar 3개 → RNGFND1~3 직결, switch 스크립트 토글, 잔여 검증 박스 spawn
- [switch-variants 백업 패턴](feedback_switch_variants.md) — 설정 파일 `.baseline`/`.variant` 사본 + cp swap 토글, src/install 두 트리 양쪽 동시 처리
