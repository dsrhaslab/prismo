#!/usr/bin/env bash
# campaign.sh — Run prismo workloads with per-workload pcp-dstat metric collection.
#
# Usage:
#   ./campaign.sh [options] workload1.json workload2.json ...
#
# Options:
#   -p PATH     Path to the prismo binary               (default: ../../builddir/prismo)
#   -o DIR      Output directory for results            (default: ../../workloads/results)
#   -h          Show this help message

set -euo pipefail

# ── defaults ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRISMO="${SCRIPT_DIR}/../../builddir/prismo"
OUTPUT_DIR="${SCRIPT_DIR}/../../workloads/results"

# ── colors ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    C_CYAN=$'\033[36m'  C_GREEN=$'\033[32m'  C_RED=$'\033[31m'
    C_DIM=$'\033[2m'    C_RST=$'\033[0m'
else
    C_CYAN=""  C_GREEN=""  C_RED=""  C_DIM=""  C_RST=""
fi

# ── argument parsing ──────────────────────────────────────────────────
WORKLOADS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p) PRISMO="$2";     shift 2 ;;
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^$/{ s/^# \?//; p }' "$0"
            exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 1 ;;
        *)  WORKLOADS+=("$1"); shift ;;
    esac
done

# ── validation ────────────────────────────────────────────────────────
if [[ ! -x "$PRISMO" ]]; then
    echo "error: prismo binary not found or not executable: $PRISMO" >&2
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

TOTAL=${#WORKLOADS[@]}

# ── results directory ─────────────────────────────────────────────────
RESULTS_DIR="${OUTPUT_DIR}/campaign_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# ── header ────────────────────────────────────────────────────────────
banner() { echo "${C_CYAN}══ $1 ══${C_RST}"; }

banner "CONFIGURATION"
printf "${C_CYAN}::${C_RST} %-20s %s\n" \
    "Binary"         "$PRISMO" \
    "Results"        "$RESULTS_DIR" \
    "Total runs"     "$TOTAL workload(s) = $((TOTAL))"

# ── helpers ───────────────────────────────────────────────────────────
elapsed_fmt() {
    local s=$1
    if (( s >= 60 )); then
        printf "%dm%02ds" $((s / 60)) $((s % 60))
    else
        printf "%ds" "$s"
    fi
}

# ── execution ─────────────────────────────────────────────────────────
banner "EXECUTION"

PASSED=0
FAILED=0
CAMPAIGN_START=$SECONDS

for (( i=0; i<TOTAL; i++ )); do
    cfg="${WORKLOADS[$i]}"
    name="$(basename "$cfg" .json)"
    progress="[$(( i + 1 ))/$TOTAL]"

    report="${RESULTS_DIR}/${name}.report.json"
    csv="${RESULTS_DIR}/${name}.dstat.csv"

    printf "%s %-30s" "${C_CYAN}${progress}${C_RST}" "$name"

    # start pcp dstat
    pcp dstat --time --cpu --mem --disk --io --net \
            --output "$csv" > /dev/null 2>&1 &
    pcp_dstat_pid=$!

    # let dstat initialise
    sleep 1

    # run prismo
    start=$SECONDS
    if "$PRISMO" -c "$cfg" -o "$report" > /dev/null 2>&1; then
        elapsed=$(( SECONDS - start ))
        printf " %s ${C_GREEN}OK${C_RST} ${C_DIM}(%s)${C_RST}\n" \
                "$(elapsed_fmt $elapsed)"
        (( PASSED++ )) || true
    else
        code=$?
        elapsed=$(( SECONDS - start ))
        printf " %s ${C_RED}FAIL${C_RST} ${C_DIM}(exit %d — %s)${C_RST}\n" \
                "$code" "$(elapsed_fmt $elapsed)"
        (( FAILED++ )) || true
    fi

    # stop pcp dstat
    kill "$pcp_dstat_pid" 2>/dev/null
    wait "$pcp_dstat_pid" 2>/dev/null || true

    # pcp-dstat CSV has 5 non-data header lines and an incomplete first
    # sample row — strip them to produce a valid, tool-friendly CSV.
    if [[ -f "$csv" ]]; then
        tail -n +6 "$csv" | sed '1s/"//g; 2d' > "${csv}.tmp" \
            && mv "${csv}.tmp" "$csv"
    fi

    # cooldown between runs
    if (( i < TOTAL - 1 )); then
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
        sleep 5
    fi
done

# ── summary ───────────────────────────────────────────────────────────
TOTAL_ELAPSED=$(( SECONDS - CAMPAIGN_START ))
banner "SUMMARY"
printf "${C_CYAN}::${C_RST} %-20s %s\n" \
    "Passed"  "$PASSED" \
    "Failed"  "$FAILED" \
    "Total"   "$(( PASSED + FAILED )) / $(( TOTAL ))" \
    "Elapsed" "$(elapsed_fmt $TOTAL_ELAPSED)" \
    "Results" "$RESULTS_DIR"
