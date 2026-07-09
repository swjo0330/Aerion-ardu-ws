#!/usr/bin/env bash
# Start ArduPilot SITL + Gazebo Harmonic + ROS2 Humble

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate conda
if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi
conda activate ros_env

# Environment
export GZ_VERSION=harmonic
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:${PKG_CONFIG_PATH}"
export PATH="/opt/homebrew/opt/openjdk/bin:/Users/swjo/yonsei-ai/aerion/ardu_ws/Micro-XRCE-DDS-Gen/scripts:/opt/homebrew/bin:${PATH}"
export GZ_SIM_SYSTEM_PLUGIN_PATH="${SCRIPT_DIR}/install/ardupilot_gazebo/lib:${GZ_SIM_SYSTEM_PLUGIN_PATH}"
export GZ_SIM_RESOURCE_PATH="\
${SCRIPT_DIR}/install/ardupilot_gazebo/share/ardupilot_gazebo/models:\
${SCRIPT_DIR}/install/ardupilot_gz_description/share:\
${SCRIPT_DIR}/install/ardupilot_gazebo/share/ardupilot_gazebo/worlds:\
/opt/homebrew/share/gz:\
${GZ_SIM_RESOURCE_PATH}"

# RMW 설정 (CycloneDDS + 원격 피어)
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="file://${SCRIPT_DIR}/cyclonedds.xml"

source "${SCRIPT_DIR}/install/setup.bash"

# path_marker_node: /replan_path_enu (nav_msgs/Path, ENU) → Gazebo /marker LINE_STRIP (재계획 경로 표출)
# 백그라운드 기동. /marker(gz sim)·/replan_path_enu(저쪽)가 아직 없어도 idle 대기, 데이터 오면 그림.
ros2 run path_marker path_marker_node &
echo "Launched path_marker_node (pid $!)"

# Launch
LAUNCH=${1:-iris_runway.launch.py}
echo "Launching: $LAUNCH"
ros2 launch ardupilot_gz_bringup "$LAUNCH"
