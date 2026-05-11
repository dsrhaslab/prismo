#!/usr/bin/env bash
# common.sh — Shared library for workload runners with pcp-dstat metric collection.
#
# Sourced by tool-specific runners (prismo.sh, fio.sh, vdbench.sh, …).
# The caller must define before calling run_campaign:
#   TOOL_BIN    — path or command name of the binary to run
#   OUTPUT_DIR  — base output directory for results
#   REPORT_EXT  — report file extension (default: .report.json)
#   WORKLOADS   — array of workload file paths
#   run_workload(cfg, report) — execute one workload; return 0 on success.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

parse_common_args() {
    WORKLOADS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b) TOOL_BIN="$2";    shift 2 ;;
            -o) OUTPUT_DIR="$2";  shift 2 ;;
            -h|--help)
                sed -n '2,/^$/{ s/^# \?//; p }' "$0"
                exit 0 ;;
            -*) echo "unknown option: $1" >&2; exit 1 ;;
            *)  WORKLOADS+=("$1"); shift ;;
        esac
    done
}

validate_common() {
    if [[ -f "$TOOL_BIN" ]]; then
        if [[ ! -x "$TOOL_BIN" ]]; then
            echo "error: binary not executable: $TOOL_BIN" >&2
            exit 1
        fi
    elif ! command -v "$TOOL_BIN" &>/dev/null; then
        echo "error: binary not found: $TOOL_BIN" >&2
        exit 1
    fi
    if ! command -v pcp &>/dev/null; then
        echo "error: pcp dstat not found" >&2
        exit 1
    fi
    if (( ${#WORKLOADS[@]} == 0 )); then
        echo "error: no workload files provided" >&2
        exit 1
    fi
    for cfg in "${WORKLOADS[@]}"; do
        if [[ ! -f "$cfg" ]]; then
            echo "error: workload file not found: $cfg" >&2
            exit 1
        fi
    done
}

start_dstat() {
    local csv="$1"
    pcp dstat --time --cpu --mem --disk --io --net --page --sys \
            --output "$csv" > /dev/null 2>&1 &
    echo $!
}

stop_dstat() {
    local pid="$1"
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null || true
}

cleanup_dstat_csv() {
    local csv="$1"
    if [[ -f "$csv" ]]; then
        local year
        year=$(date +%Y)
        tail -n +6 "$csv" | sed '1s/"//g; 2d' \
            | awk -v y="$year" 'BEGIN{FS=OFS=","} NR>1{
                split($1,a," "); split(a[1],d,"-");
                $1=y"/"d[2]"/"d[1]" "a[2]
              } {print}' > "${csv}.tmp" \
            && mv "${csv}.tmp" "$csv"
    fi
}

drop_caches_and_wait() {
    sync
    echo "Dropping caches and waiting 5 minutes..."
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    sleep 300
}

run_campaign() {
    local TOTAL=${#WORKLOADS[@]}
    local REPORT_EXT="${REPORT_EXT:-.report.json}"
    local RESULTS_DIR="${OUTPUT_DIR}/campaign_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$RESULTS_DIR"

    for (( i=0; i<TOTAL; i++ )); do
        local cfg="${WORKLOADS[$i]}"
        local name
        name="$(basename "$cfg")"
        name="${name%.*}"

        local report="${RESULTS_DIR}/${name}${REPORT_EXT}"
        local csv="${RESULTS_DIR}/${name}.dstat.csv"

        drop_caches_and_wait
        echo "Running workload $((i+1))/${TOTAL}: ${cfg}"

        local pcp_dstat_pid
        pcp_dstat_pid=$(start_dstat "$csv")
        sleep 1

        run_workload "$cfg" "$report"

        stop_dstat "$pcp_dstat_pid"
        cleanup_dstat_csv "$csv"
    done

    echo "Results saved in: ${RESULTS_DIR}"
}
