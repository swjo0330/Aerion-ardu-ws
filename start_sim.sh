#!/usr/bin/env bash
# Start ArduPilot SITL + Gazebo Harmonic + ROS2 Humble

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# clean 시작 보증: 기존 sim이 떠 있으면 먼저 정리 (누적 방지 — 좀비 SITL·장시간 구동 시
# 카메라 발행률 저하 현상 대응. 재기동 전 반드시 이전 인스턴스를 죽이고 시작).
# stop_sim이 좀비 arducopter/gz까지 집요 제거(3회 루프). NO_CLEAN=1로 건너뛸 수 있음.
# ⚠️ 중복 기동 주의: start_sim을 `&`로 거의 동시에 여러 번 던지면 race로 SITL이 중복
#    누적돼 fps가 급락한다(6개 실측). 재시작은 한 번에 하나씩만(정식 백그라운드 1개).
if [ "${NO_CLEAN:-0}" != "1" ] && pgrep -f "arducopter|gz sim" >/dev/null 2>&1; then
    echo "[start_sim] 기존 sim 감지 — clean 시작 위해 stop_sim 선행"
    bash "${SCRIPT_DIR}/stop_sim.sh" >/dev/null 2>&1
fi

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

# 프리플라이트: DDS가 바인딩한 NIC가 실제로 살아있는지 확인.
# 죽은/부재 NIC 바인딩은 "failed to create domain"으로 노드가 조용히 죽는 반복 함정 →
# 여기서 fail-fast + 해결법 안내(장소 이동으로 en5→en0 등 NIC명이 바뀌면 재발).
if [ ! -f "${SCRIPT_DIR}/cyclonedds.xml" ]; then
    echo "❌ [start_sim] cyclonedds.xml 부재 — DDS 설정 없이 기동 불가. sync_and_build.sh 먼저 실행하세요. 중단."
    exit 1
fi
BOUND_NIC=$(grep -oE '<NetworkInterface name="[^"]*"' "${SCRIPT_DIR}/cyclonedds.xml" | sed -E 's/.*name="([^"]*)".*/\1/')
if [ -n "$BOUND_NIC" ]; then
    BOUND_IP=$(ipconfig getifaddr "$BOUND_NIC" 2>/dev/null)
    if [ -z "$BOUND_IP" ]; then
        echo "❌ [start_sim] cyclonedds.xml 바인딩 NIC '${BOUND_NIC}' 가 비활성/부재 — DDS 노드 생성 실패합니다. 중단."
        echo "   현재 활성 인터페이스:"
        for ifc in $(ifconfig -l); do
            ip=$(ipconfig getifaddr "$ifc" 2>/dev/null); [ -n "$ip" ] && echo "     $ifc = $ip"
        done
        echo "   해결: bash sync_and_build.sh <저쪽IP>  (Peer 서브넷의 NIC로 자동 재바인딩)"
        exit 1
    fi
    # Peer와 다른 /24면 경고 (크로스머신 도달 안 될 수 있음 — 같은 /16 랩이면 무시 가능)
    PEER_IP=$(grep -oE '<Peer address="[0-9.]*"' "${SCRIPT_DIR}/cyclonedds.xml" | sed -E 's/.*"([0-9.]*)".*/\1/')
    if [ -n "$PEER_IP" ] && [ "$(echo "$BOUND_IP"|cut -d. -f1-3)" != "$(echo "$PEER_IP"|cut -d. -f1-3)" ]; then
        echo "⚠️ [start_sim] 바인딩(${BOUND_IP})과 Peer(${PEER_IP})가 다른 /24 — 크로스머신 도달 안 될 수 있음. sync_and_build 재실행 권장"
    fi
    echo "[start_sim] DDS 바인딩 확인: ${BOUND_NIC} = ${BOUND_IP} (Peer ${PEER_IP:-?})"
fi

source "${SCRIPT_DIR}/install/setup.bash"

# path_marker_node: /replan_path_enu (nav_msgs/Path, ENU) → Gazebo /marker LINE_STRIP (재계획 경로 표출)
# 백그라운드 기동. /marker(gz sim)·/replan_path_enu(저쪽)가 아직 없어도 idle 대기, 데이터 오면 그림.
ros2 run path_marker path_marker_node &
echo "Launched path_marker_node (pid $!)"

# 카메라 compressed 재발행: 집 Wi-Fi에서 raw(≈44Mbps, 조각 ~670개/frame)는 조각손실로 붕괴 —
# Wi-Fi엔 JPEG(~1/20 대역)만 건너가게 송신측에서 재발행 (2026-07-11, 지능측 요청·이중구독 기구현).
# raw(/camera/image)는 로컬 소비용으로 그대로 발행됨. 끄려면 CAMERA_COMPRESS=0 bash start_sim.sh
if [ "${CAMERA_COMPRESS:-1}" != "0" ]; then
    # raw는 로컬 전용(/camera/image_local)이라 크로스머신 미노출 — compressed만 송출 (2026-07-12)
    ros2 run image_transport republish raw compressed \
        --ros-args -r in:=/camera/image_local -r out/compressed:=/camera/image/compressed \
        -r __node:=image_republisher &
    echo "Launched image_republisher (raw→/camera/image/compressed, pid $!)  [끄려면 CAMERA_COMPRESS=0]"
fi

# Launch
LAUNCH=${1:-iris_runway.launch.py}
echo "Launching: $LAUNCH"
ros2 launch ardupilot_gz_bringup "$LAUNCH"
