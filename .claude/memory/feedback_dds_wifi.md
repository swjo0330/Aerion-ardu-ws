---
name: DDS over Wi-Fi 구조적 한계
description: ROS2 + CycloneDDS를 Wi-Fi로 운용 시 RTT 폭증 / packet drop 흔한 이유와 완화책 요지
type: feedback
originSessionId: e13f8d67-cbbb-491e-8553-db77f490f788
---
Wi-Fi에서 RTPS 기반 DDS(Cyclone/Fast/Connext)는 구조적으로 발산 경향. 유선에서 잘 돌면 DDS 튜닝 문제 아니고 매체 한계.

**증상이 원래 그런 이유:**
- AP가 멀티캐스트를 6-24Mbps basic rate로 강제 → 채널 점유 폭증
- Reliable QoS ACKNACK + 802.11 ARQ 이중 재전송 → self-DoS 발산
- Wi-Fi 드라이버 RX 큐 처리 < fragment 도착 속도 → socket buffer overflow
- macOS `kern.ipc.maxsockbuf` 8MB 천장 (Linux 64MB 대비 작음)

**Why:** ROS Discourse / eProsima / Cyclone GitHub issues 다수 합의. 유선 LAN을 전제로 설계됨.

**How to apply (효과 큰 순):**
1. `image_transport compressed` (JPEG q80) — 60Mbps→2-6Mbps. 단, `ros_gz_bridge`는 image_transport 미지원이라 별도 republisher 노드 필요.
2. **카메라 토픽 QoS BEST_EFFORT + KEEP_LAST(1)** — NACK 폭주 차단. ros_gz_bridge yaml의 `qos_overrides`로 송신측에서 바꾸는 게 안전 (양쪽 reader/writer 협상 매칭).
3. 카메라 해상도/Rate 추가 축소 (Gazebo SDF의 `<image>`, `<update_rate>`).
4. `zenoh-bridge-ros2dds`로 Wi-Fi 너머 토픽만 Zenoh TCP로 분리 — 가장 강한 완화책. 양쪽 LAN만 RTPS.
5. cyclonedds.xml: `NackDelay 50ms`, `SocketReceiveBufferSize 10MB`, `AllowMulticast spdp`.

**macOS sysctl 천장:**
- `kern.ipc.maxsockbuf` 기본 8MB → `sudo sysctl -w kern.ipc.maxsockbuf=16777216` (16MB가 macOS Apple Silicon 한계로 보임, 32MB는 "Result too large")
- `net.inet.udp.recvspace`도 같이 16MB로 올릴 것

**진단 1차 신호:**
- `netstat -s -p udp | grep buffer` → `dropped due to full socket buffers` 카운터 증가 = 우리쪽 RX 포화
- `ping <peer>` RTT 200ms+ on LAN = Wi-Fi 매체 문제 (DDS 무관)
- `wdutil info`로 RSSI/CCA 확인 (CCA 60%+면 채널 혼잡)
