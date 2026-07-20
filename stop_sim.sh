#!/usr/bin/env bash
# Stop all ArduPilot SITL + Gazebo + ROS2 processes

# 1차 종료
pkill -f "gz sim" 2>/dev/null
pkill -f rviz2 2>/dev/null
pkill -f arducopter 2>/dev/null
pkill -f mavproxy 2>/dev/null
pkill -f micro_ros_agent 2>/dev/null
pkill -f parameter_bridge 2>/dev/null
pkill -f robot_state_publisher 2>/dev/null
pkill -f relay 2>/dev/null
pkill -f rmw_zenohd 2>/dev/null
pkill -f "ros2 launch" 2>/dev/null
pkill -f ardupilot_sitl 2>/dev/null
pkill -f path_marker_node 2>/dev/null
pkill -f "image_transport/republish" 2>/dev/null
pkill -f _ros2_daemon 2>/dev/null   # 묵은 ros2 daemon 캐시 제거 (토픽 미표시/멈춤 함정 예방)

sleep 2

# 2차 강제 종료 (잔여 프로세스)
pkill -9 -f "gz sim" 2>/dev/null
pkill -9 -f rviz2 2>/dev/null
pkill -9 -f arducopter 2>/dev/null
pkill -9 -f mavproxy 2>/dev/null
pkill -9 -f micro_ros_agent 2>/dev/null   # XRCE agent 잔존 시 세션 키 충돌·SHM 재누적 (2026-07-16 보강)
pkill -9 -f parameter_bridge 2>/dev/null
pkill -9 -f robot_state_publisher 2>/dev/null
pkill -9 -f relay 2>/dev/null
pkill -9 -f rmw_zenohd 2>/dev/null
pkill -9 -f "ros2 launch" 2>/dev/null
pkill -9 -f ardupilot_sitl 2>/dev/null
pkill -9 -f path_marker_node 2>/dev/null
pkill -9 -f "image_transport/republish" 2>/dev/null
pkill -9 -f _ros2_daemon 2>/dev/null

# arducopter/gz 좀비 집요 제거 (재시작 반복·중복 기동 시 SIGKILL 회피분 누적 방지 — 2026-07-14)
# SITL 좀비 여러 개가 남으면 gz 물리·카메라 렌더를 경쟁해 fps가 뚝 떨어진다(6개 누적 실측).
for _ in 1 2 3; do
    ZN=$(pgrep -f "arducopter|gz sim" 2>/dev/null | wc -l | tr -d ' ')
    [ "$ZN" -eq 0 ] && break
    pkill -9 -f arducopter 2>/dev/null
    pkill -9 -f "gz sim" 2>/dev/null
    sleep 1
done

# 포트 정리 (멀티 인스턴스 오프셋 포트 포함 — 5760/5770/5780, 2019/2029/2039, 14555/65/75)
for p in 5760 5770 5780 2019 2029 2039 14555 14565 14575 14551; do
    lsof -ti :$p 2>/dev/null | xargs kill -9 2>/dev/null
done

sleep 1

# Fast-DDS 공유메모리 세그먼트 정리 (micro_ros_agent XRCE-DDS)
# SIGKILL로 죽인 프로세스는 자기 SHM을 못 지워 /private/tmp/boost_interprocess/에
# fastrtps_* (실행당 ~549KB) 가 무한 누적됨. 위에서 모든 관련 프로세스를 종료했으므로
# 여기 남은 fastrtps_* 는 전부 고아 → 안전하게 제거.
SHM_DIR=/private/tmp/boost_interprocess
if [ -d "$SHM_DIR" ]; then
    SHM_CNT=$(ls -1 "$SHM_DIR"/fastrtps_* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$SHM_CNT" -gt 0 ]; then
        rm -f "$SHM_DIR"/fastrtps_* 2>/dev/null
        echo "Cleaned ${SHM_CNT} orphaned Fast-DDS SHM segment(s)."
    fi
fi

# 종료 후 자체 검증 (누적·잔여 0 확인 — 남으면 경고)
LEFT=$(pgrep -f "arducopter|gz sim|ruby.*gz|mavproxy|micro_ros_agent|path_marker|parameter_bridge|rviz2|robot_state|ros_gz|image_transport/republish|_ros2_daemon|relay|rmw_zenohd" 2>/dev/null | wc -l | tr -d ' ')
ARDU=$(pgrep -f arducopter 2>/dev/null | wc -l | tr -d ' ')   # SITL 좀비 명시 카운트 (fps 저하 주범)
PORT=$(lsof -nP -iTCP:5760 -iTCP:5770 -iTCP:5780 2>/dev/null | grep -c LISTEN)
SHM_LEFT=$(ls -1 "$SHM_DIR"/fastrtps_* 2>/dev/null | wc -l | tr -d ' ')
if [ "$LEFT" -eq 0 ] && [ "$PORT" -eq 0 ] && [ "$SHM_LEFT" -eq 0 ]; then
    echo "All simulation processes stopped. [자원 프리 검증: 프로세스 0 · arducopter 0 · 포트 0 · SHM 0]"
else
    echo "⚠️ All simulation processes stopped. 잔여: 프로세스 ${LEFT}(arducopter ${ARDU}) · SITL포트 ${PORT} · SHM ${SHM_LEFT} — 재확인 필요"
fi
