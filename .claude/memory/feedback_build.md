---
name: ardu_ws 빌드 패치 및 피드백
description: macOS ARM colcon 빌드, CycloneDDS/Zenoh 설정 주의사항
type: feedback
originSessionId: 0f25ce71-2532-4c5e-a8d2-8e3b166edae7
---
colcon 빌드 시 반드시 다음 cmake 옵션 사용:
```
-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env
-DPython3_ROOT_DIR=/Users/swjo/anaconda3/envs/ros_env
-DPython3_EXECUTABLE=/Users/swjo/anaconda3/envs/ros_env/bin/python3
-DBUILD_TESTING=OFF
```

**Why:** homebrew를 conda보다 먼저 탐색해야 protobuf 34 (homebrew gz 호환)를 올바르게 찾음. conda protobuf 33과 homebrew protobuf 34 혼재 시 SIGSEGV 발생.

**How to apply:** ardupilot_gazebo, ros_gz_sim, ros_gz_bridge, ros_gz_image 등 gz 관련 패키지 빌드 시 항상 이 옵션 사용.

---

CYCLONEDDS_URI에서 `AllowMulticast=false`를 이 Mac에 넣으면 로컬 토픽 discovery 깨짐.

**Why:** AllowMulticast=false 설정 시 같은 머신의 ROS2 노드끼리도 못 찾음. `/camera/image` 등 브릿지 토픽이 사라짐.

**How to apply:** 이 Mac(현재 .35) start_sim.sh에서는 AllowMulticast 생략 + `NetworkInterface name="en7"` + Peer 추가 방식 사용. 저쪽 Ubuntu(현재 .33)에서는 AllowMulticast=false + Peer로 이 Mac IP 지정. (IP는 DHCP라 매일 변동 — 역할은 고정, 숫자는 변동)

---

rmw_zenoh_cpp 직접 사용 시 카메라 이미지 전송 실패.

**Why:** 카메라 이미지 ~1-2MB가 Zenoh TCP fragmentation을 통과하지 못함. 토픽 목록에는 보이지만 실제 데이터 미수신. batch_size/buffer_size 16MB 설정해도 해결 안 됨.

**How to apply:** 크로스머신 토픽 공유는 CycloneDDS 유니캐스트 피어 방식 사용. rmw_zenoh_cpp/zenoh-bridge-ros2dds는 대안이지만 이미지 전송 이슈 있음.

---

sync_and_build.sh 실행 시 PATH에 Micro-XRCE-DDS-Gen/scripts 필요.

**Why:** ardupilot_sitl 빌드가 `microxrceddsgen`을 찾지 못하면 "Could not find the program" 오류로 실패.

**How to apply:** 빌드 전 PATH에 포함하거나, start_sim.sh처럼 PATH 설정 후 빌드.

---

Zenoh 참고 (현재 미사용):
- 올바른 env var: `ZENOH_ROUTER_CONFIG_URI`, `ZENOH_SESSION_CONFIG_URI` (`RMW_` 접두사 없음)
- json5 잘못된 필드: `transport.link.tx.queue.backoff` (존재 안 함), `sequence_number_resolution: 4096` (문자열 필요)
- json5 문법 오류 시 모든 ROS2 노드 crash
