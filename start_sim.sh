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

# Zenoh RMW 설정
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ZENOH_ROUTER_URI=tcp/10.130.200.29:7447

source "${SCRIPT_DIR}/install/setup.bash"

# Launch
LAUNCH=${1:-iris_runway.launch.py}
echo "Launching: $LAUNCH"
ros2 launch ardupilot_gz_bringup "$LAUNCH"
