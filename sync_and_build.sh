#!/usr/bin/env bash
# ============================================================
# sync_and_build.sh
# 현재 Mac IP 및 MAVLink out 대상 IP를 확인/동기화 후 재빌드
# 사용법: bash sync_and_build.sh [out_target_ip]
# ============================================================

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_PY="${WORKSPACE}/src/ardupilot/Tools/ros2/ardupilot_sitl/src/ardupilot_sitl/launch.py"
PYTHON=/Users/swjo/anaconda3/envs/ros_env/bin/python3

# ------------------------------------
# 1. 현재 Mac IP 자동 감지 (10.130.x.x 우선)
# ------------------------------------
MY_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | grep "10.130" | awk '{print $2}' | head -1)

if [ -z "$MY_IP" ]; then
    MY_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
fi

echo "감지된 내 IP: ${MY_IP}"

# ------------------------------------
# 2. MAVLink out 대상 IP 결정
# ------------------------------------
CURRENT_OUT_IP=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' "${LAUNCH_PY}" | grep "14555" | head -1)
echo "현재 out 설정: ${CURRENT_OUT_IP}"

if [ -n "$1" ]; then
    # 인자로 받은 IP 사용
    OUT_IP="$1"
else
    # 대화형 입력
    read -p "MAVLink out 대상 IP를 입력하세요 [현재: ${CURRENT_OUT_IP}]: " INPUT_IP
    OUT_IP="${INPUT_IP:-${CURRENT_OUT_IP%:*}}"
fi

OUT_TARGET="${OUT_IP}:14555"
echo "설정할 out 대상: ${OUT_TARGET}"

# ------------------------------------
# 3. launch.py 업데이트
# ------------------------------------
CURRENT_LINE=$(grep "default_value=.*14555" "${LAUNCH_PY}")
NEW_LINE="                default_value=\"${OUT_TARGET}\","

if [ "${CURRENT_LINE}" = "${NEW_LINE}" ]; then
    echo "launch.py 변경 없음 (이미 ${OUT_TARGET})"
else
    sed -i '' "s|default_value=\".*:14555\",|default_value=\"${OUT_TARGET}\",|" "${LAUNCH_PY}"
    echo "launch.py 업데이트: ${OUT_TARGET}"
fi

# ------------------------------------
# 4. 메모리 파일 IP 업데이트
# ------------------------------------
MEMORY_FILE="${HOME}/.claude/projects/-Users-swjo-yonsei-ai-aerion/memory/project_ardu_ws.md"
if [ -f "${MEMORY_FILE}" ]; then
    sed -i '' "s|이 Mac IP: [0-9.]*|이 Mac IP: ${MY_IP}|" "${MEMORY_FILE}"
    sed -i '' "s|MAVLink UDP out 대상: [0-9.]*:14555|MAVLink UDP out 대상: ${OUT_TARGET}|" "${MEMORY_FILE}"
    echo "메모리 파일 IP 업데이트 완료"
fi

# ------------------------------------
# 5. 재빌드
# ------------------------------------
echo ""
echo "ardupilot_sitl 재빌드 중..."

if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi
conda activate ros_env

export GZ_VERSION=harmonic
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:${PKG_CONFIG_PATH}"
export PATH="/opt/homebrew/opt/openjdk/bin:/opt/homebrew/bin:${PATH}"

cd "${WORKSPACE}"
colcon build \
    --packages-select ardupilot_sitl \
    --cmake-args \
        -DPython3_EXECUTABLE=${PYTHON} \
        -DPYTHON_EXECUTABLE=${PYTHON} \
        -DPython3_ROOT_DIR=/Users/swjo/anaconda3/envs/ros_env \
        "-DCMAKE_PREFIX_PATH=/opt/homebrew;/Users/swjo/anaconda3/envs/ros_env" \
    2>&1 | tail -5

echo ""
echo "============================================"
echo " 동기화 완료"
echo " 내 IP    : ${MY_IP}"
echo " out 대상 : ${OUT_TARGET}"
echo "============================================"
echo ""
echo "이제 실행하세요: bash start_sim.sh"
