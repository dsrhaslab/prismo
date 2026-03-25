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

run_workload() {
    local cfg="$1" report="$2"
    "$TOOL_BIN" "$cfg" --output-format=json --output="$report" > /dev/null 2>&1
}

run_campaign
