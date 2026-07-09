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

sleep 2

# 2차 강제 종료 (잔여 프로세스)
pkill -9 -f "gz sim" 2>/dev/null
pkill -9 -f rviz2 2>/dev/null
pkill -9 -f arducopter 2>/dev/null
pkill -9 -f mavproxy 2>/dev/null
pkill -9 -f parameter_bridge 2>/dev/null
pkill -9 -f robot_state_publisher 2>/dev/null
pkill -9 -f "ros2 launch" 2>/dev/null
pkill -9 -f path_marker_node 2>/dev/null

# 포트 정리
lsof -ti :5760 | xargs kill -9 2>/dev/null
lsof -ti :2019 | xargs kill -9 2>/dev/null
lsof -ti :14555 | xargs kill -9 2>/dev/null

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

echo "All simulation processes stopped."
