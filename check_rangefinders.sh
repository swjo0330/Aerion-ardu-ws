#!/usr/bin/env bash
# check_rangefinders.sh — 전/좌/우 거리센서 3개 토픽이 로컬에서 나오는지 검증
#
# 다른 컴(저쪽 Ubuntu)은 ROS2(ros2 topic, DDS over en7)로 구독하므로 ROS2 경로가
# 권위 있는 검증 대상이다. gz transport(gz topic) 확인은 참고용(informational).
#
# 주의:
#   - set -u 금지 — ROS2 setup.bash가 미정의 변수를 참조해 조용히 종료됨
#   - ros2 명령은 --no-daemon 사용 — 묵은 좀비 ros2 daemon이 캐시를 물고 조회를
#     막는 사고가 있었음(2026-05-29). --no-daemon은 매 호출 fresh 디스커버리.
#
# 사용법: bash check_rangefinders.sh   (start_sim.sh 가 떠 있는 상태에서)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi
conda activate ros_env 2>/dev/null

export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="file://${SCRIPT_DIR}/cyclonedds.xml"
source "${SCRIPT_DIR}/install/setup.bash" 2>/dev/null

SIDES=(front left right)
ROS_TIMEOUT=8
GZ_TIMEOUT=5
pass=0; fail=0

hr() { printf '%s\n' "------------------------------------------------------------"; }

# 한 번에 한 메시지만 받아서 ranges[0] 추출 (.inf 포함). 백그라운드+kill로 확실히 종료.
ros_echo_once() {
    local t="$1"
    ( ros2 topic echo "$t" --once --no-daemon 2>/dev/null & local p=$!
      sleep "$ROS_TIMEOUT"; kill -9 "$p" 2>/dev/null ) \
      | awk '/^ranges:/{f=1;next} f&&/^- /{gsub(/^- /,"");print;exit}'
}

# ─────────────────────────────────────────────────────────────
# 1) ROS2 (권위 검증) — 다른 컴이 구독하는 경로
# ─────────────────────────────────────────────────────────────
echo
echo "### 1) ROS2  /range/{front,left,right}  (다른 컴 구독 경로)"
hr
ROS_LIST="$(ros2 topic list --no-daemon 2>/dev/null)"
for s in "${SIDES[@]}"; do
    t="/range/$s"
    if ! grep -qx "$t" <<<"$ROS_LIST"; then
        printf "  [FAIL] %-13s : 토픽 목록에 없음\n" "$t"; fail=$((fail+1)); continue
    fi
    v="$(ros_echo_once "$t")"
    if [ -n "$v" ]; then
        printf "  [ OK ] %-13s : ranges[0] = %s m\n" "$t" "$v"; pass=$((pass+1))
    else
        printf "  [FAIL] %-13s : 토픽은 있으나 %ss 내 메시지 없음\n" "$t" "$ROS_TIMEOUT"; fail=$((fail+1))
    fi
done

# ─────────────────────────────────────────────────────────────
# 2) Gazebo gz transport (참고용) — 실패해도 ROS2 정상이면 무방
# ─────────────────────────────────────────────────────────────
echo
echo "### 2) Gazebo gz topic  (참고용 — gz CLI 디스커버리 한계로 안 잡혀도 무방)"
hr
GZ_LIST="$(gz topic -l 2>/dev/null)"
for s in "${SIDES[@]}"; do
    t="/range/$s"
    if grep -qx "$t" <<<"$GZ_LIST"; then
        v="$(timeout "$GZ_TIMEOUT" gz topic -e -t "$t" -n 1 2>/dev/null | awk '/ranges:/{getline; gsub(/[^0-9.eEinf+-]/,""); print; exit}')"
        [ -n "$v" ] && printf "  [info] %-13s : sample=%s\n" "$t" "$v" \
                    || printf "  [info] %-13s : advertised (gz CLI로 샘플 미수신 — 정상일 수 있음)\n" "$t"
    else
        printf "  [info] %-13s : gz 토픽 목록에 없음\n" "$t"
    fi
done

echo
hr
echo "ROS2 결과: 통과 ${pass} / 실패 ${fail}   (기대: 통과 3)"
hr
[ "$pass" -eq 3 ] && { echo "✅ 세 거리센서 토픽 로컬 구독 정상 (다른 컴도 동일 경로)"; exit 0; } \
                  || { echo "❌ 일부 토픽 미수신 — 좀비 ros2 daemon 여부 확인: pkill -9 -f ros2cli.daemon"; exit 1; }
