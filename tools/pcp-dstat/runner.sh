#!/usr/bin/env bash
# runner.sh — Run a range of workloads using fio.sh, prismo.sh, or vdbench.sh.
#
# Usage:
#   ./runner.sh -t TOOL -r START-END [options]
#
# Options:
#   -t TOOL     Tool to use: fio, prismo, or vdbench    (required)
#   -r RANGE    Workload range, e.g. 1-15 or 5-10      (required)
#   -b PATH     Override the tool binary path
#   -o DIR      Override the output directory
#   -h          Show this help message
#
# Examples:
#   ./runner.sh -t fio -r 1-15
#   ./runner.sh -t prismo -r 16-30 -b /usr/local/bin/prismo
#   ./runner.sh -t vdbench -r 1-15 -o /tmp/results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
    sed -n '2,/^$/{ s/^# \?//; p }' "$0"
    exit 0
}

TOOL=""
RANGE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) TOOL="$2";  shift 2 ;;
        -r) RANGE="$2"; shift 2 ;;
        -b) EXTRA_ARGS+=("-b" "$2"); shift 2 ;;
        -o) EXTRA_ARGS+=("-o" "$2"); shift 2 ;;
        -h|--help) usage ;;
        *)  echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$TOOL" ]]; then
    echo "error: -t TOOL is required (fio, prismo, vdbench)" >&2
    exit 1
fi

if [[ -z "$RANGE" ]]; then
    echo "error: -r RANGE is required (e.g. 1-15)" >&2
    exit 1
fi

# Validate tool and resolve paths
case "$TOOL" in
    fio)
        TOOL_SCRIPT="${SCRIPT_DIR}/fio.sh"
        WORKLOAD_DIR="${ROOT_DIR}/workloads/fio"
        ;;
    prismo)
        TOOL_SCRIPT="${SCRIPT_DIR}/prismo.sh"
        WORKLOAD_DIR="${ROOT_DIR}/workloads/prismo"
        ;;
    vdbench)
        TOOL_SCRIPT="${SCRIPT_DIR}/vdbench.sh"
        WORKLOAD_DIR="${ROOT_DIR}/workloads/vdbench"
        ;;
    *)
        echo "error: unknown tool '$TOOL' (must be fio, prismo, or vdbench)" >&2
        exit 1
        ;;
esac

# Parse range
if [[ ! "$RANGE" =~ ^[0-9]+-[0-9]+$ ]]; then
    echo "error: invalid range format '$RANGE' (expected START-END, e.g. 1-15)" >&2
    exit 1
fi

START="${RANGE%%-*}"
END="${RANGE##*-}"

if (( START > END )); then
    echo "error: start ($START) must be <= end ($END)" >&2
    exit 1
fi

# Collect workloads in the specified range
WORKLOADS=()
for (( i=START; i<=END; i++ )); do
    prefix=$(printf "%02d" "$i")
    matches=("${WORKLOAD_DIR}/${prefix}_"*)
    if [[ -e "${matches[0]}" ]]; then
        WORKLOADS+=("${matches[@]}")
    else
        echo "warning: no workload found for number ${prefix} in ${WORKLOAD_DIR}" >&2
    fi
done

if (( ${#WORKLOADS[@]} == 0 )); then
    echo "error: no workloads found in range ${START}-${END}" >&2
    exit 1
fi

echo "Tool:      ${TOOL}"
echo "Range:     ${START}-${END}"
echo "Workloads: ${#WORKLOADS[@]} file(s)"
echo "---"

for cfg in "${WORKLOADS[@]}"; do
    echo "- $(basename "$cfg")"
done

exec "$TOOL_SCRIPT" "${EXTRA_ARGS[@]}" "${WORKLOADS[@]}"