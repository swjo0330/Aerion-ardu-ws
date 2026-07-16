#!/usr/bin/env bash
# ============================================================
# gen_multi_assets.sh — 멀티 SITL 파생 자산 생성기 (설계 정본 A1~A4)
#
# 현재 활성 단일 자산(install 트리 = 런타임 진실)에서 인스턴스별 사본을 파생:
#   A1 models/iris_with_gimbal_d{1,2,3}  — fdm_port_in 9002+10i, /drone{N}/gimbal|range 토픽 개명
#   A2 worlds/iris_runway_multi.sdf      — iris include 1개 → iris_d{1,2,3} 3개 (y +20m 간격, D9)
#   A3 config/iris_bridge_d{1,2,3}.yaml  — gz 경로 iris→iris_d{N}, /clock 절대명, range 개명
#   A4 default_params/dds_udp_d{1,2,3}.parm — DDS_UDP_PORT/DOMAIN_ID/SYSID 차등
# + 신규 launch 2종(src) → install 동기화
#
# 재실행 안전(멱등). switch_rangefinders.sh 로 변형 전환 후엔 이 스크립트를 재실행해
# 멀티 사본을 현 활성 변형과 재동기화할 것.
# src/install 이중 트리 규약(CLAUDE.md §1) 준수 — 양쪽 모두 기록.
# ============================================================
set -euo pipefail
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GZ_INSTALL="${WS}/install/ardupilot_gazebo/share/ardupilot_gazebo"
GZ_SRC="${WS}/src/ardupilot_gazebo"
WORLD_INSTALL="${WS}/install/ardupilot_gz_gazebo/share/ardupilot_gz_gazebo/worlds"
WORLD_SRC="${WS}/src/ardupilot_gz/ardupilot_gz_gazebo/worlds"
BRINGUP_INSTALL="${WS}/install/ardupilot_gz_bringup/share/ardupilot_gz_bringup"
BRINGUP_SRC="${WS}/src/ardupilot_gz/ardupilot_gz_bringup"
SITL_PARM_INSTALL="${WS}/install/ardupilot_sitl/share/ardupilot_sitl/config/default_params"
SITL_PARM_SRC="${WS}/src/ardupilot/Tools/ros2/ardupilot_sitl/config/default_params"

# ---------- A1: 모델 사본 3벌 ----------
gen_model() {
    local N=$1 I=$((N-1)) FDM=$((9002+10*(N-1)))
    for BASE in "${GZ_INSTALL}/models" "${GZ_SRC}/models"; do
        local SRC_DIR="${BASE}/iris_with_gimbal" DST_DIR="${BASE}/iris_with_gimbal_d${N}"
        [ -d "$SRC_DIR" ] || { echo "skip(원본 없음): $SRC_DIR"; continue; }
        rm -rf "$DST_DIR"; cp -R "$SRC_DIR" "$DST_DIR"
        local SDF="${DST_DIR}/model.sdf"
        sed -i '' "s|<fdm_port_in>9002</fdm_port_in>|<fdm_port_in>${FDM}</fdm_port_in>|" "$SDF"
        # 멀티 기체: lock_step 해제 — lock_step=1은 온라인 기체의 servo 대기 루프가 직렬화되고
        # 미접속 기체(예: 2기 모드의 d3) 폴링까지 겹쳐 sim time이 기어감 (2026-07-09 실측 RTF≈0.2%)
        sed -i '' "s|<lock_step>1</lock_step>|<lock_step>0</lock_step>|" "$SDF"
        sed -i '' "s|/gimbal/cmd_roll|/drone${N}/gimbal/cmd_roll|g;s|/gimbal/cmd_pitch|/drone${N}/gimbal/cmd_pitch|g;s|/gimbal/cmd_yaw|/drone${N}/gimbal/cmd_yaw|g" "$SDF"
        sed -i '' "s|/range/front_av|/drone${N}/range/front_av|g" "$SDF"
        sed -i '' "s|<topic>/range/front</topic>|<topic>/drone${N}/range/front</topic>|" "$SDF"
        [ -f "${DST_DIR}/model.config" ] && sed -i '' "s|<name>Iris with Gimbal</name>|<name>Iris with Gimbal d${N}</name>|" "${DST_DIR}/model.config"
        echo "A1 모델: $DST_DIR (fdm ${FDM})"
    done
}

# ---------- A2: 멀티 월드 ----------
gen_world() {
    python3 - "$WORLD_INSTALL/iris_runway_des.sdf" <<'PYEOF'
import re, sys
src = sys.argv[1]
with open(src) as f: txt = f.read()
# iris include 블록 추출
m = re.search(r"( *)<include>\s*<uri>model://iris_with_gimbal</uri>\s*<name>iris</name>\s*<pose>([^<]+)</pose>\s*</include>\n", txt)
assert m, "iris include 블록을 찾지 못함 — 월드 형식 변경됨?"
indent, pose = m.group(1), m.group(2).split()
# 20m 등변 삼각형 (지능측 .29 결정 2026-07-09 확정): 안전반경 10m 불변, 대형으로 규칙 #11 해결.
# d1(본기)은 출발지(0,0) 고정, d2·d3만 좌우로 벌리며 뒤로(남 −17.32m=−10√3, ±10m) → d1이 정점.
# 쌍간 ≈20m 등변(d1↔d2=d1↔d3=√(10²+17.32²)=20, d2↔d3=20) → 정상 편대 오탐 0,
# <10m 진입 시에만 #11 발화(조기 수렴 감지 여유 10m 보존). home GPS 공유(drone_multi.launch.py).
OFFSET = {1: (0.0, 0.0), 2: (-10.0, -17.32), 3: (10.0, -17.32)}   # (dx=동/우, dy=북/전) — d1 고정·20m 등변
blocks = []
for n in (1, 2, 3):
    dx, dy = OFFSET[n]
    p = pose[:]; p[0] = str(float(p[0]) + dx); p[1] = str(float(p[1]) + dy)   # 북 30m 선형 (D9)
    blocks.append(f"{indent}<include>\n{indent}  <uri>model://iris_with_gimbal_d{n}</uri>\n{indent}  <name>iris_d{n}</name>\n{indent}  <pose>{' '.join(p)}</pose>\n{indent}</include>\n")
out = txt[:m.start()] + "".join(blocks) + txt[m.end():]
import os
for dst_dir in [os.path.dirname(src), os.environ.get("WORLD_SRC_DIR", "")]:
    if dst_dir and os.path.isdir(dst_dir):
        dst = os.path.join(dst_dir, "iris_runway_multi.sdf")
        with open(dst, "w") as f: f.write(out)
        print(f"A2 월드: {dst}")
PYEOF
}

# ---------- A3: 브리지 yaml 3벌 ----------
gen_bridge() {
    local N=$1
    for BASE in "${BRINGUP_INSTALL}/config" "${BRINGUP_SRC}/config"; do
        local SRC_Y="${BASE}/iris_bridge.yaml" DST_Y="${BASE}/iris_bridge_d${N}.yaml"
        [ -f "$SRC_Y" ] || { echo "skip(원본 없음): $SRC_Y"; continue; }
        sed -e "s|model/iris/|model/iris_d${N}/|g" \
            -e "s|gz_topic_name: \"/range/|gz_topic_name: \"/drone${N}/range/|g" \
            -e "s|ros_topic_name: \"clock\"|ros_topic_name: \"/clock\"|" \
            "$SRC_Y" > "$DST_Y"
        # leaf 기체(d2/d3): 인지(range) 브리지만 제거 — 카메라 브리지는 보존
        # (D10 개정 2026-07-11 — 카메라 3대 복원·전송은 compressed 전용, 인지(range)는 d1만 유지)
        if [ "$N" -ge 2 ]; then
            python3 - "$DST_Y" <<'PYBR'
import re, sys
p = sys.argv[1]
with open(p) as f: t = f.read()
out, n = re.subn(r'- ros_topic_name: "[^"]*range[^"]*"\n(?:  .*\n?)*', '', t)
open(p, "w").write(out)
print(f"  range 브리지 {n}개 제거: {p}")
PYBR
        fi
        echo "A3 브리지: $DST_Y"
    done
}

# ---------- A4: parm 3벌 ----------
gen_parm() {
    local N=$1 I=$((N-1))
    for BASE in "$SITL_PARM_INSTALL" "$SITL_PARM_SRC"; do
        [ -d "$BASE" ] || { echo "skip(디렉토리 없음): $BASE"; continue; }
        cat > "${BASE}/dds_udp_d${N}.parm" <<EOF
# 멀티 SITL 인스턴스 ${I} (도메인 d${N}) — gen_multi_assets.sh 생성
DDS_ENABLE 1
DDS_UDP_PORT $((2019+10*I))
DDS_DOMAIN_ID ${N}
SYSID_THISMAV ${N}
EOF
        echo "A4 parm: ${BASE}/dds_udp_d${N}.parm"
    done
}

# ---------- launch 동기화 (src → install) ----------
# 손수 작성 launch 정본은 추적 가능한 multi_src/launch/에 둔다 (src/ardupilot_gz는 .repos 중첩
# git repo라 추적 불가 → clean clone 재현성 확보). 여기서 src·install 두 외부 트리로 배포.
sync_launch() {
    local LSRC="${WS}/multi_src/launch"
    for TREE in "${BRINGUP_SRC}" "${BRINGUP_INSTALL}"; do
        mkdir -p "${TREE}/launch/robots"
        cp "${LSRC}/robots/drone_multi.launch.py" "${TREE}/launch/robots/"
        cp "${LSRC}/iris_runway_multi.launch.py" "${TREE}/launch/"
    done
    echo "launch 배포: multi_src/launch → src·install 두 트리"
}

for N in 1 2 3; do gen_model "$N"; gen_bridge "$N"; gen_parm "$N"; done
export WORLD_SRC_DIR="$WORLD_SRC"
gen_world
sync_launch
mkdir -p "${WS}/multi/i0" "${WS}/multi/i1" "${WS}/multi/i2" "${WS}/logs"
echo ""
echo "============================================"
echo " 멀티 자산 생성 완료 — start_multi_sim.sh [기수] 로 기동"
echo "============================================"
