#!/usr/bin/env bash
# fio.sh — Run fio workloads with per-workload pcp-dstat metric collection.
#
# Usage:
#   ./fio.sh [options] workload1.fio workload2.fio ...
#
# Options:
#   -b PATH     Path to the fio binary                  (default: fio)
#   -o DIR      Output directory for results            (default: workloads/results)
#   -h          Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TOOL_BIN="fio"
OUTPUT_DIR="${ROOT_DIR}/workloads/results"

parse_common_args "$@"
validate_common

run_workload() (
    local cfg report abs_cfg name
    cfg="$1"; report="$2"
    abs_cfg="$(realpath "$cfg")"
    name="$(basename "$cfg" .fio)"

    cd "$RESULTS_DIR"
    "$TOOL_BIN" "$abs_cfg" \
        --output-format=json \
        --output="$report" \
        --write_bw_log="${name}" \
        --write_lat_log="${name}" \
        --write_iops_log="${name}" \
        --log_avg_msec=1000
)

run_campaign
