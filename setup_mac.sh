#!/usr/bin/env bash
# ============================================================
# ArduPilot SITL + Gazebo Harmonic + ROS2 Humble
# macOS ARM environment setup script
# ============================================================

# ------------------------------------
# 1. Activate conda ros_env
# ------------------------------------
if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
    source "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
else
    echo "[WARN] Could not locate conda.sh — assuming conda is already on PATH"
fi

conda activate ros_env

# ------------------------------------
# 2. Environment variables
# ------------------------------------

# Gazebo version
export GZ_VERSION=harmonic

# pkg-config path (Homebrew libs)
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:${PKG_CONFIG_PATH}"

# PATH: OpenJDK, microXRCE-DDS-Gen, Homebrew, existing PATH
export PATH="/opt/homebrew/opt/openjdk/bin:\
/Users/swjo/yonsei-ai/aerion/ardu_ws/Micro-XRCE-DDS-Gen/scripts:\
/opt/homebrew/bin:\
/opt/homebrew/sbin:\
${PATH}"

# Gazebo system plugin path — ardupilot_gazebo plugin
export GZ_SIM_SYSTEM_PLUGIN_PATH="\
/Users/swjo/yonsei-ai/aerion/ardu_ws/install/ardupilot_gazebo/lib:\
${GZ_SIM_SYSTEM_PLUGIN_PATH}"

# Gazebo resource path — SDF models + worlds
export GZ_SIM_RESOURCE_PATH="\
/Users/swjo/yonsei-ai/aerion/ardu_ws/install/ardupilot_gazebo/share/ardupilot_gazebo/models:\
/Users/swjo/yonsei-ai/aerion/ardu_ws/install/ardupilot_gz_description/share:\
/Users/swjo/yonsei-ai/aerion/ardu_ws/install/ardupilot_gazebo/share/ardupilot_gazebo/worlds:\
/opt/homebrew/share/gz:\
${GZ_SIM_RESOURCE_PATH}"

# ------------------------------------
# 3. Source the ROS2 workspace
# ------------------------------------
WORKSPACE_SETUP="/Users/swjo/yonsei-ai/aerion/ardu_ws/install/setup.zsh"
if [ -f "${WORKSPACE_SETUP}" ]; then
    source "${WORKSPACE_SETUP}"
else
    echo "[WARN] Workspace setup not found: ${WORKSPACE_SETUP}"
    echo "       Run 'colcon build' in /Users/swjo/yonsei-ai/aerion/ardu_ws/ first."
fi

# ------------------------------------
# 4. Done
# ------------------------------------
echo ""
echo "============================================"
echo " Environment ready!"
echo "============================================"
echo ""
echo " GZ_VERSION              : ${GZ_VERSION}"
echo " GZ_SIM_SYSTEM_PLUGIN_PATH:"
echo "   ${GZ_SIM_SYSTEM_PLUGIN_PATH}"
echo " GZ_SIM_RESOURCE_PATH    :"
echo "   ${GZ_SIM_RESOURCE_PATH}"
echo ""
echo " Launch commands:"
echo "   ros2 launch ardupilot_gz_bringup iris_runway.launch.py"
echo "   ros2 launch ardupilot_gz_bringup iris_maze.launch.py"
echo ""
