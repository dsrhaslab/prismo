#!/usr/bin/env bash
# vdbench.sh — Run vdbench workloads with per-workload pcp-dstat metric collection.
#
# Usage:
#   ./vdbench.sh [options] workload1.vdbench workload2.vdbench ...
#
# Options:
#   -b PATH     Path to the vdbench binary              (default: vdbench)
#   -o DIR      Output directory for results            (default: workloads/results)
#   -h          Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TOOL_BIN="vdbench"
OUTPUT_DIR="${ROOT_DIR}/workloads/results"
REPORT_EXT=".report"

parse_common_args "$@"
validate_common

run_workload() {
    local cfg="$1" report="$2"
    "$TOOL_BIN" -f "$cfg" -o "$report" > /dev/null 2>&1
}

run_campaign
