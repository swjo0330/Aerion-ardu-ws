#!/usr/bin/env bash
# stop_multi_sim.sh — 멀티 SITL 전체 종료 (설계 정본 A8)
# stop_sim.sh 의 전역 pkill 이 3기 전부 커버 (프로세스명 패턴 동일) + Fast-DDS SHM 정리 포함.
# multi/i*/eeprom.bin 은 존치 (인스턴스 파라미터 보존 — parm 재반영 필요 시에만 수동 삭제).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/stop_sim.sh"
