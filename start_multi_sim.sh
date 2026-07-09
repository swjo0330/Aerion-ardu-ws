#!/usr/bin/env bash
# ============================================================
# start_multi_sim.sh [기수(1~3, 기본 3)] — 멀티 SITL 오케스트레이터 (설계 정본 A7)
#
# 구조 (D1~D6): 단일 gz 서버 + 기체별 수직 스택을 도메인 d=i+1 로 분리 기동.
#   - eeprom 분리: 인스턴스별 cwd multi/i{i}/ 에서 ros2 launch (F7)
#   - 도메인 분리: ROS_DOMAIN_ID=i+1 환경변수 (bridge/agent/rsp 상속)
#   - MAVProxy out: cyclonedds.xml Peer(저쪽IP) : 14555+10i (D6 — sed 의존 없음)
# 단일 모드와 동시 운용 금지 — 기동 전 stop_sim.sh 선행 (리스크표).
# 선행 1회: bash gen_multi_assets.sh (모델/월드/브리지/parm 사본 생성)
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUM=${1:-3}

# ---- 선행 조건 ----
if [ ! -d "${SCRIPT_DIR}/install/ardupilot_gazebo/share/ardupilot_gazebo/models/iris_with_gimbal_d1" ]; then
    echo "멀티 자산 없음 — 먼저 실행: bash gen_multi_assets.sh"; exit 1
fi
REMOTE_IP=$(grep -oE '<Peer address="[0-9.]+"' "${SCRIPT_DIR}/cyclonedds.xml" | grep -oE '[0-9.]+')
[ -z "$REMOTE_IP" ] && { echo "cyclonedds.xml에서 Peer IP 파싱 실패"; exit 1; }
echo "저쪽 IP (cyclonedds.xml Peer): ${REMOTE_IP} / 기수: ${NUM}"

# 동시 운용 금지 — 잔여 정리
bash "${SCRIPT_DIR}/stop_sim.sh" >/dev/null 2>&1

# ---- 환경 (start_sim.sh 와 동일) ----
if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi
conda activate ros_env

export GZ_VERSION=harmonic
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:${PKG_CONFIG_PATH}"
export PATH="/opt/homebrew/opt/openjdk/bin:${SCRIPT_DIR}/Micro-XRCE-DDS-Gen/scripts:/opt/homebrew/bin:${PATH}"
export GZ_SIM_SYSTEM_PLUGIN_PATH="${SCRIPT_DIR}/install/ardupilot_gazebo/lib:${GZ_SIM_SYSTEM_PLUGIN_PATH}"
export GZ_SIM_RESOURCE_PATH="\
${SCRIPT_DIR}/install/ardupilot_gazebo/share/ardupilot_gazebo/models:\
${SCRIPT_DIR}/install/ardupilot_gz_description/share:\
${SCRIPT_DIR}/install/ardupilot_gazebo/share/ardupilot_gazebo/worlds:\
/opt/homebrew/share/gz:\
${GZ_SIM_RESOURCE_PATH}"
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="file://${SCRIPT_DIR}/cyclonedds.xml"

source "${SCRIPT_DIR}/install/setup.bash"
mkdir -p "${SCRIPT_DIR}/logs" "${SCRIPT_DIR}/multi/i0" "${SCRIPT_DIR}/multi/i1" "${SCRIPT_DIR}/multi/i2"

# ---- 1) gz 서버 + GUI (도메인 무관 — gz-transport) ----
ros2 launch ardupilot_gz_bringup iris_runway_multi.launch.py \
    > "${SCRIPT_DIR}/logs/multi_world.log" 2>&1 &
echo "gz 월드 기동 (pid $!) → logs/multi_world.log"

# gz 서버 대기 (world 서비스 노출까지)
for t in $(seq 1 30); do
    gz service -l 2>/dev/null | grep -q "/world/map/" && break
    sleep 1
done
gz service -l 2>/dev/null | grep -q "/world/map/" \
    && echo "gz 서버 준비 완료 (${t}s)" || echo "⚠️ gz 서버 미확인 — 계속 진행 (logs/multi_world.log 확인)"

# ---- 2) 기체별 수직 스택 (도메인·cwd 분리) ----
for i in $(seq 0 $((NUM-1))); do
    N=$((i+1))
    OUT_PORT=$((14555+10*i))
    (
        cd "${SCRIPT_DIR}/multi/i${i}" || exit 1
        ROS_DOMAIN_ID=${N} ros2 launch ardupilot_gz_bringup drone_multi.launch.py \
            instance:=${i} out:="${REMOTE_IP}:${OUT_PORT}" \
            > "${SCRIPT_DIR}/logs/multi_i${i}.log" 2>&1 &
        echo "drone${N} 기동 (domain ${N}, out ${REMOTE_IP}:${OUT_PORT}, pid $!) → logs/multi_i${i}.log"
    )
    sleep 3   # SITL↔플러그인 lock-step 접속 순차화 (동시 폭주 방지)
done

# ---- 3) path_marker_node (d1 소속 — D8) ----
ROS_DOMAIN_ID=1 ros2 run path_marker path_marker_node \
    > "${SCRIPT_DIR}/logs/multi_path_marker.log" 2>&1 &
echo "path_marker_node 기동 (domain 1, pid $!)"

# ---- 4) 부팅 시그니처 대기 ----
echo ""
echo "부팅 시그니처 대기 (기체당 최대 60s)..."
PASS=0
for i in $(seq 0 $((NUM-1))); do
    LOG="${SCRIPT_DIR}/logs/multi_i${i}.log"
    for t in $(seq 1 60); do
        grep -q "EKF3 active" "$LOG" 2>/dev/null && break
        sleep 1
    done
    if grep -q "DDS: Initialization passed" "$LOG" 2>/dev/null && grep -q "EKF3 active" "$LOG" 2>/dev/null; then
        echo "  ✅ drone$((i+1)): DDS passed + EKF3 active"
        PASS=$((PASS+1))
    else
        echo "  ❌ drone$((i+1)): 시그니처 미검출 — ${LOG} 확인"
    fi
done

echo ""
echo "============================================"
echo " 멀티 SITL: ${PASS}/${NUM} 기 준비 완료"
echo " 도메인 확인: ROS_DOMAIN_ID=N ros2 topic list --no-daemon"
echo " 종료:       bash stop_multi_sim.sh"
echo "============================================"
