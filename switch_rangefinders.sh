#!/usr/bin/env bash
# switch_rangefinders.sh — toggle distance-sensor variant of iris_with_gimbal
#   on     : copy *.rangefinders → active  (enable 3 forward/left/right single-ray + RNGFND1~3)
#   fan    : copy *.front_fan    → active  (front ±45° horizontal fan, 91 samples + RNGFND1 only)
#   fan3d  : copy *.fan3d        → active  (front H±45°×V±15°, 91×16 rays → PointCloud2 + RNGFND1)
#   fan3d_down: copy *.fan3d_down → active (front H±45°×V-40°~+15° 하향확대, 91×28 → PointCloud2, 회피 OFF)
#   fan3d_av: copy *.fan3d_av    → active  (fan3d_down 인지 + 수평 회피센서 추가 → PointCloud2 + ArduPilot 반응제어)
#   single : copy *.front_single → active  (front single beam, 0° only + RNGFND1 only)
#   off    : copy *.baseline     → active  (revert to original iris_with_gimbal)
#   status : show which variant each active file currently matches

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

FILES=(
  "$ROOT/src/ardupilot_gazebo/models/iris_with_gimbal/model.sdf"
  "$ROOT/install/ardupilot_gazebo/share/ardupilot_gazebo/models/iris_with_gimbal/model.sdf"
  "$ROOT/src/ardupilot_gazebo/config/gazebo-iris-gimbal.parm"
  "$ROOT/install/ardupilot_gazebo/share/ardupilot_gazebo/config/gazebo-iris-gimbal.parm"
  "$ROOT/src/ardupilot_gz/ardupilot_gz_bringup/config/iris_bridge.yaml"
  "$ROOT/install/ardupilot_gz_bringup/share/ardupilot_gz_bringup/config/iris_bridge.yaml"
)

require_variants() {
  for f in "${FILES[@]}"; do
    for ext in baseline rangefinders front_fan fan3d fan3d_down fan3d_av front_single; do
      [[ -f "$f.$ext" ]] || { echo "ERROR: missing $f.$ext" >&2; exit 1; }
    done
  done
}

apply() {
  local suffix="$1" label="$2"
  require_variants
  for f in "${FILES[@]}"; do
    cp "$f.$suffix" "$f"
    echo "  ${label}: $(basename "$(dirname "$f")")/$(basename "$f") ← .${suffix}"
  done
  echo
  echo "✅ Variant '${label}' applied. Restart sim:"
  echo "     bash stop_sim.sh && bash start_sim.sh"
}

case "${1:-status}" in
  on)     apply rangefinders ON     ;;
  fan)    apply front_fan     FAN    ;;
  fan3d)  apply fan3d         FAN3D  ;;
  fan3d_down) apply fan3d_down FAN3D_DOWN ;;
  fan3d_av) apply fan3d_av    FAN3D_AV ;;
  single) apply front_single  SINGLE ;;
  off)    apply baseline      OFF    ;;
  status)
    for f in "${FILES[@]}"; do
      if   cmp -s "$f" "$f.rangefinders" 2>/dev/null; then state="ON     (rangefinders 3개)"
      elif cmp -s "$f" "$f.front_fan"    2>/dev/null; then state="FAN    (front ±45° 부채꼴 2D)"
      elif cmp -s "$f" "$f.fan3d_av"     2>/dev/null; then state="FAN3D_AV (3D 인지+수평 회피)"
      elif cmp -s "$f" "$f.fan3d_down"   2>/dev/null; then state="FAN3D_DOWN (V-40°~+15° 하향)"
      elif cmp -s "$f" "$f.fan3d"        2>/dev/null; then state="FAN3D  (front H±45°×V±15° 3D)"
      elif cmp -s "$f" "$f.front_single" 2>/dev/null; then state="SINGLE (front 단일빔 0°)"
      elif cmp -s "$f" "$f.baseline"     2>/dev/null; then state="OFF    (baseline)"
      else                                                  state="UNKNOWN (drifted)"
      fi
      printf "  %s : %s\n" "$state" "${f#$ROOT/}"
    done
    ;;
  *) echo "Usage: $0 {on|fan|fan3d|fan3d_down|fan3d_av|single|off|status}" >&2; exit 2 ;;
esac
