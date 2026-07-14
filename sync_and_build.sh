#!/usr/bin/env bash
# ============================================================
# sync_and_build.sh
# 현재 Mac IP 및 MAVLink out 대상 IP를 확인/동기화 후 재빌드
# 사용법: bash sync_and_build.sh <저쪽IP> [내IP]
#   내IP를 주면(권장) 그 IP를 소유한 NIC로 직접 바인딩 → 멀티호밍·가상NIC 오선택 제거
# ============================================================

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_PY="${WORKSPACE}/src/ardupilot/Tools/ros2/ardupilot_sitl/src/ardupilot_sitl/launch.py"
PYTHON=/Users/swjo/anaconda3/envs/ros_env/bin/python3

# ------------------------------------
# 1. MAVLink out(=DDS Peer) 대상 IP 결정 (먼저 — 내 NIC 감지가 이 서브넷에 의존)
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
# 2. 내 NIC/IP 결정 — 방법론: "Peer와 같은 서브넷의 로컬 NIC로 바인딩"
#    유저가 내 IP를 2번째 인자로 주면(권장) 그 IP 소유 NIC로 직접 바인딩 →
#      멀티호밍(en5+en0 동시 45.x)·가상NIC(anpi 핫스팟·Thunderbolt 브리지멤버) 오선택 원천차단.
#    안 주면 Peer 서브넷 일치 NIC 자동 선택(기본 라우트 NIC 우선 tiebreak, 가상/브리지멤버 배제).
#    IP·NIC명이 장소마다 바뀌어도(en7 랩 / en5 유선 / en0 Wi-Fi / DHCP) 자가치유.
# ------------------------------------
PEER_PREFIX=$(echo "$OUT_IP" | cut -d. -f1-3)
DEFAULT_NIC=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
MY_IP_ARG="$2"
MY_NIC=""; MY_IP=""

# 가상·비대상 NIC 판별 (lo/utun(tailscale·VPN)/awdl/llw/bridge/gif/stf/ap/anpi(핫스팟)/vlan + Thunderbolt 브리지멤버)
is_virtual_nic() {
    case "$1" in lo*|utun*|awdl*|llw*|bridge*|gif*|stf*|ap*|anpi*|vlan*) return 0;; esac
    ifconfig bridge0 2>/dev/null | grep -q "member: $1" && return 0
    return 1
}

if [ -n "$MY_IP_ARG" ]; then
    # (권장) 유저가 준 내 IP를 소유한 활성 NIC를 직접 특정 — 오선택 불가
    for ifc in $(ifconfig -l); do
        [ "$(ipconfig getifaddr "$ifc" 2>/dev/null)" = "$MY_IP_ARG" ] && { MY_NIC="$ifc"; MY_IP="$MY_IP_ARG"; break; }
    done
    [ -z "$MY_NIC" ] && { echo "❌ 지정한 내 IP(${MY_IP_ARG})를 가진 활성 NIC 없음 — IP 오타/미연결 확인. 중단."; exit 1; }
else
    # 자동: Peer 서브넷 일치 NIC (기본 라우트 NIC를 맨 앞에 둬 멀티호밍 tiebreak)
    for ifc in $DEFAULT_NIC $(ifconfig -l); do
        is_virtual_nic "$ifc" && continue
        ip=$(ipconfig getifaddr "$ifc" 2>/dev/null); [ -z "$ip" ] && continue
        if [ "$(echo "$ip" | cut -d. -f1-3)" = "$PEER_PREFIX" ]; then MY_NIC="$ifc"; MY_IP="$ip"; break; fi
    done
    if [ -z "$MY_NIC" ]; then
        MY_NIC="$DEFAULT_NIC"; MY_IP=$(ipconfig getifaddr "$MY_NIC" 2>/dev/null)
        echo "⚠️ Peer(${OUT_IP}) 서브넷 일치 NIC 없음 — 기본 라우트 NIC(${MY_NIC}) 폴백"
    fi
fi

# 결과 검증: IP 없으면 중단(네트워크 부재). Peer와 /24 다르면 경고(같은 /16 랩은 정상 → 중단 안 함)
{ [ -z "$MY_NIC" ] || [ -z "$MY_IP" ]; } && { echo "❌ 바인딩할 활성 NIC/IP 없음 — 네트워크 연결 확인. 중단."; exit 1; }
if [ "$(echo "$MY_IP" | cut -d. -f1-3)" != "$PEER_PREFIX" ]; then
    echo "⚠️⚠️ 내 IP(${MY_IP})와 Peer(${OUT_IP})가 다른 /24 — 같은 /16 이하면 정상, 아니면 크로스머신 도달 불가. 양측 확인 요망"
fi
echo "감지된 내 NIC/IP: ${MY_NIC} / ${MY_IP}"

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
# 4. cyclonedds.xml Peer 주소 업데이트
# ------------------------------------
CYCLONE_XML="${WORKSPACE}/cyclonedds.xml"
if [ -f "${CYCLONE_XML}" ]; then
    sed -i '' "s|<Peer address=\"[^\"]*\" */>|<Peer address=\"${OUT_IP}\"/>|" "${CYCLONE_XML}"
    echo "cyclonedds.xml Peer 업데이트: ${OUT_IP}"
    # NetworkInterface도 감지된 NIC로 자동 갱신 (죽은 NIC 바인딩 → 노드 사망 함정 예방)
    if [ -n "${MY_NIC}" ]; then
        sed -i '' "s|<NetworkInterface name=\"[^\"]*\"/>|<NetworkInterface name=\"${MY_NIC}\"/>|" "${CYCLONE_XML}"
        echo "cyclonedds.xml NetworkInterface 업데이트: ${MY_NIC}"
    fi
fi

# ------------------------------------
# 5. 메모리 파일 IP 업데이트
# ------------------------------------
MEMORY_FILE="${HOME}/.claude/projects/-Users-swjo-yonsei-ai-aerion/memory/project_ardu_ws.md"
if [ -f "${MEMORY_FILE}" ]; then
    sed -i '' "s|이 Mac IP: [0-9.]*|이 Mac IP: ${MY_IP}|" "${MEMORY_FILE}"
    sed -i '' "s|MAVLink UDP out 대상: [0-9.]*:14555|MAVLink UDP out 대상: ${OUT_TARGET}|" "${MEMORY_FILE}"
    echo "메모리 파일 IP 업데이트 완료"
fi

# ------------------------------------
# 6. 재빌드
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
export PATH="/opt/homebrew/opt/openjdk/bin:${WORKSPACE}/Micro-XRCE-DDS-Gen/scripts:/opt/homebrew/bin:${PATH}"

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
echo "============================================"
echo " 재부팅 후 필수 sysctl 설정 (아직 안 했다면):"
echo "============================================"
echo "  sudo sysctl -w net.inet.ip.maxfragsperpacket=8192"
echo "  sudo sysctl -w net.inet.udp.recvspace=8388608"
echo "  sudo sysctl -w net.inet.udp.maxdgram=65535"
echo ""
echo "이제 실행하세요: bash start_sim.sh"
