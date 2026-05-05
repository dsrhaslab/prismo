#!/usr/bin/env bash
# prismo.sh — Run prismo workloads with per-workload pcp-dstat metric collection.
#
# Usage:
#   ./prismo.sh [options] workload1.json workload2.json ...
#
# Options:
#   -b PATH     Path to the prismo binary               (default: builddir/prismo)
#   -o DIR      Output directory for results            (default: workloads/results)
#   -h          Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TOOL_BIN="${ROOT_DIR}/builddir/prismo"
OUTPUT_DIR="${ROOT_DIR}/workloads/results"

parse_common_args "$@"
validate_common

run_workload() {
    local cfg="$1" report="$2"
    "$TOOL_BIN" -c "$cfg" -o "$report" -l
}

run_campaign
