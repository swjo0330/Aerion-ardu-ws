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

sleep 2

# 2차 강제 종료 (잔여 프로세스)
pkill -9 -f "gz sim" 2>/dev/null
pkill -9 -f rviz2 2>/dev/null
pkill -9 -f arducopter 2>/dev/null
pkill -9 -f mavproxy 2>/dev/null
pkill -9 -f parameter_bridge 2>/dev/null
pkill -9 -f robot_state_publisher 2>/dev/null
pkill -9 -f "ros2 launch" 2>/dev/null

# 포트 정리
lsof -ti :5760 | xargs kill -9 2>/dev/null
lsof -ti :2019 | xargs kill -9 2>/dev/null
lsof -ti :14555 | xargs kill -9 2>/dev/null

sleep 1

echo "All simulation processes stopped."
