---
name: CycloneDDS 대형 메시지 전송 문제 해결
description: /camera/image 등 대형 ROS2 토픽이 크로스머신 전송 실패 시 진단 및 해결 가이드
type: feedback
---

## 문제

CycloneDDS로 /camera/image (1920x1080 rgb8, 6.2MB/frame, ~8fps) 크로스머신 전송 시:
- 로컬 수신 정상, 소형 토픽(/imu, /ap/* 등) 크로스머신 전송 정상
- 대형 토픽(/camera/image)만 저쪽에서 데이터 0프레임

## 원인

CycloneDDS 기본 `MaxMessageSize=65000B` → 하나의 RTPS fragment가 ~64KB UDP 패킷 → MTU 1500B 네트워크에서 44개 IP fragment로 쪼개짐 → IP fragment 하나라도 유실되면 전체 RTPS fragment 유실 → 96개 RTPS fragment 중 대부분 유실 → 전체 이미지 재조립 불가

## 해결

`cyclonedds.xml`에서 MaxMessageSize와 FragmentSize를 MTU 이하로 설정:

```xml
<MaxMessageSize>1400B</MaxMessageSize>
<FragmentSize>1344B</FragmentSize>
```

이렇게 하면 각 RTPS fragment가 1400B UDP 패킷 → IP fragmentation 없이 전달. 대신 RTPS fragment 수가 ~4400개/프레임으로 늘지만 IP fragment 유실 문제를 완전히 우회.

## 추가 필요한 macOS sysctl 설정

```bash
sudo sysctl -w net.inet.ip.maxfragsperpacket=8192
sudo sysctl -w net.inet.udp.recvspace=8388608
sudo sysctl -w net.inet.udp.maxdgram=65535
```

저쪽(Ubuntu)에서도:
```bash
sudo sysctl -w net.ipv4.ipfrag_high_thresh=26214400
sudo sysctl -w net.ipv4.ipfrag_max_dist=0
sudo sysctl -w net.core.rmem_max=26214400
sudo sysctl -w net.core.rmem_default=26214400
```

## 진단 순서 (같은 문제 재발 시)

1. `bash check_camera.sh [원격IP]` 실행 — 로컬 수신, 시스템 설정, 원격 전송 확인
2. 로컬 수신 정상 + 원격 전송 안 됨 → `ros2 topic info /camera/image --verbose`로 subscriber discovery 확인
3. subscriber 발견됨 + 대형 패킷 안 나감 → RELIABLE QoS ACKNACK 문제 → `sudo tcpdump -i <NIC> src host <원격IP> and udp -c 20 -n`
4. 패킷은 나가는데 저쪽 수신 안 됨 → IP fragmentation 문제 → `MaxMessageSize`/`FragmentSize` MTU 이하로 설정
5. Wi-Fi 사용 시 네트워크 포화 → 유선(en5) 사용 또는 loopback + zenoh bridge

## CycloneDDS XML 주의사항 (robostack 0.10.x)

- `Internal` 태그 지원 안 됨 → 사용 시 `failed to create domain` 에러로 모든 ROS2 노드 crash
- `MaxMessageSize`, `FragmentSize`에 단위 명시 필수 (예: `1400B`), 안 하면 deprecated 경고
- XML 문법 오류 시 에러 메시지 없이 domain 생성 실패 → launch 로그에서 `rmw_create_node: failed to create domain` 확인
- `file://` URI로 외부 XML 참조 가능: `export CYCLONEDDS_URI="file:///path/to/cyclonedds.xml"`

**Why:** 6.2MB 이미지의 IP fragmentation이 네트워크 스위치/라우터에서 재조립 실패 유발.
**How to apply:** 대형 ROS2 토픽 크로스머신 전송 실패 시 cyclonedds.xml의 MaxMessageSize/FragmentSize를 MTU(1400B) 이하로 설정.
