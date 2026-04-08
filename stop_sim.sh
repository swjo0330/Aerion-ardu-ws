#!/usr/bin/env bash
# Stop all ArduPilot SITL + Gazebo + ROS2 processes

pkill -f "gz sim" 2>/dev/null
pkill -f rviz2 2>/dev/null
pkill -f arducopter 2>/dev/null
pkill -f mavproxy 2>/dev/null
pkill -f micro_ros_agent 2>/dev/null
pkill -f parameter_bridge 2>/dev/null
pkill -f robot_state_publisher 2>/dev/null
pkill -f relay 2>/dev/null

sleep 2

lsof -ti :5760 | xargs kill -9 2>/dev/null
lsof -ti :2019 | xargs kill -9 2>/dev/null

echo "All simulation processes stopped."
