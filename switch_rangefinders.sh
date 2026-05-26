#!/usr/bin/env bash
# switch_rangefinders.sh — toggle distance-sensor variant of iris_with_gimbal
#   on     : copy *.rangefinders → active  (enable 3 forward/left/right LIDAR + RNGFND1~3)
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
    for ext in baseline rangefinders; do
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
  on)  apply rangefinders ON  ;;
  off) apply baseline      OFF ;;
  status)
    for f in "${FILES[@]}"; do
      if   cmp -s "$f" "$f.rangefinders" 2>/dev/null; then state="ON  (rangefinders)"
      elif cmp -s "$f" "$f.baseline"     2>/dev/null; then state="OFF (baseline)"
      else                                                  state="UNKNOWN (drifted)"
      fi
      printf "  %s : %s\n" "$state" "${f#$ROOT/}"
    done
    ;;
  *) echo "Usage: $0 {on|off|status}" >&2; exit 2 ;;
esac
