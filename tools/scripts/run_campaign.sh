#!/usr/bin/env bash
# run_campaign.sh — Organized execution of all prismo campaign workloads
#
# Usage:
#   ./run_campaign.sh [OPTIONS]
#
# Options:
#   -b, --binary PATH       Path to prismo binary       (default: builddir/prismo)
#   -o, --output DIR        Results output directory     (default: report/results/campaign_<ts>)
#   -e, --engine ENGINE     Filter by engine: posix | uring | aio | spdk | all  (default: all)
#   -w, --workloads X:Y     Run only workloads numbered X to Y (e.g. 1:18, 55:72)
#   -r, --repetitions N     Repetitions per workload     (default: 1)
#   -n, --dry-run           List workloads without executing
#   -h, --help              Show this help
#
set -uo pipefail

###############################################################################
#  Constants
###############################################################################

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SCRIPTS_DIR="$ROOT_DIR/tools/scripts"
readonly WORKLOAD_DIR="$ROOT_DIR/workloads/campaign"

###############################################################################
#  Terminal colors
###############################################################################

setup_colors() {
    if [[ -t 1 ]]; then
        C_RESET='\033[0m'  C_BOLD='\033[1m'  C_DIM='\033[2m'
        C_RED='\033[31m'   C_GREEN='\033[32m'
        C_YELLOW='\033[33m' C_CYAN='\033[36m'
    else
        C_RESET='' C_BOLD='' C_DIM=''
        C_RED='' C_GREEN='' C_YELLOW='' C_CYAN=''
    fi
}

###############################################################################
#  Logging helpers
###############################################################################

log()      { printf "${C_BOLD}%s${C_RESET}\n" "$*"; }
log_info() { printf "${C_CYAN}:: ${C_RESET}%s\n" "$*"; }
log_ok()   { printf "${C_GREEN} ✓ ${C_RESET}%s\n" "$*"; }
log_fail() { printf "${C_RED} ✗ ${C_RESET}%s\n" "$*"; }
log_warn() { printf "${C_YELLOW} ! ${C_RESET}%s\n" "$*"; }
log_dim()  { printf "${C_DIM}   %s${C_RESET}\n" "$*"; }

###############################################################################
#  Utility functions
###############################################################################

usage() {
    sed -n '2,/^$/s/^# \?//p' "$0"
    exit 0
}

# Format seconds as "Xm YYs" or "Xs".
elapsed_fmt() {
    local s=$1
    if (( s >= 60 )); then printf '%dm%02ds' $((s / 60)) $((s % 60))
    else                    printf '%ds' "$s"
    fi
}

###############################################################################
#  Workload classification
###############################################################################

# Derive the I/O engine from a workload name (suffix convention).
get_engine() {
    case "$1" in
        *_spdk)  echo "spdk"  ;;
        *_aio)   echo "aio"   ;;
        *_uring) echo "uring" ;;
        *)       echo "posix" ;;
    esac
}



###############################################################################
#  Argument parsing
###############################################################################

BINARY="$ROOT_DIR/builddir/prismo"
RESULTS_DIR=""
ENGINE_FILTER="all"
WORKLOAD_FROM=0
WORKLOAD_TO=0
REPETITIONS=1
DRY_RUN=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--binary)      BINARY="$2";         shift 2 ;;
            -o|--output)      RESULTS_DIR="$2";    shift 2 ;;
            -e|--engine)      ENGINE_FILTER="$2";  shift 2 ;;
            -w|--workloads)
                if [[ "$2" =~ ^([0-9]+):([0-9]+)$ ]]; then
                    WORKLOAD_FROM=$((10#${BASH_REMATCH[1]}))
                    WORKLOAD_TO=$((10#${BASH_REMATCH[2]}))
                else
                    log_fail "invalid range '$2' — expected X:Y (e.g. 1:18)"
                    exit 1
                fi
                shift 2 ;;
            -r|--repetitions) REPETITIONS="$2";    shift 2 ;;
            -n|--dry-run)     DRY_RUN=true;        shift   ;;
            -h|--help)        usage ;;
            *)
                log_fail "unknown option: $1"
                usage
                ;;
        esac
    done

    # Default results directory includes a timestamp
    if [[ -z "$RESULTS_DIR" ]]; then
        RESULTS_DIR="$ROOT_DIR/workloads/results/campaign_$(date +%Y%m%d_%H%M%S)"
    fi
}

###############################################################################
#  Validation
###############################################################################

validate_env() {
    if [[ ! -x "$BINARY" ]]; then
        log_fail "binary not found or not executable: $BINARY"
        log_dim "hint: run 'meson compile -C builddir' first"
        exit 1
    fi
}

###############################################################################
#  Workload discovery & filtering
###############################################################################

declare -a CONFIGS=()

discover_workloads() {
    for cfg in "$WORKLOAD_DIR"/*.json; do
        [[ -f "$cfg" ]] || continue

        local name num engine
        name="$(basename "$cfg" .json)"
        num=$((10#${name%%_*}))
        engine="$(get_engine "$name")"

        # Apply engine filter
        [[ "$ENGINE_FILTER" != "all" && "$engine" != "$ENGINE_FILTER" ]] && continue

        # Apply workload range filter
        if (( WORKLOAD_FROM > 0 && WORKLOAD_TO > 0 )); then
            (( num < WORKLOAD_FROM || num > WORKLOAD_TO )) && continue
        fi

        CONFIGS+=("$cfg")
    done

    if [[ ${#CONFIGS[@]} -eq 0 ]]; then
        log_fail "no workloads matched (engine=$ENGINE_FILTER)"
        exit 1
    fi
}

###############################################################################
#  Campaign header
###############################################################################

print_header() {
    local total=$1

    echo ""
    log "╔══════════════════════════════════════════════════════════════════╗"
    log "║                    PRISMO CAMPAIGN RUNNER                      ║"
    log "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Binary:       $BINARY"
    log_info "Workloads:    $WORKLOAD_DIR"
    log_info "Results:      $RESULTS_DIR"
    log_info "Engine:       $ENGINE_FILTER"
    if (( WORKLOAD_FROM > 0 && WORKLOAD_TO > 0 )); then
        log_info "Workloads:    $WORKLOAD_FROM — $WORKLOAD_TO"
    else
        log_info "Workloads:    all"
    fi
    log_info "Repetitions:  $REPETITIONS"
    log_info "Total runs:   $total workload(s) × $REPETITIONS rep(s) = $((total * REPETITIONS))"
    echo ""
}

###############################################################################
#  Section separators (engine grouping)
###############################################################################

print_engine_header() {
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "  Engine: ${1^^}"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

###############################################################################
#  Single-workload execution
###############################################################################

# Run one workload (with optional repetition suffix).
# Updates global PASSED / FAILED / FAILED_NAMES.
run_workload() {
    local name="$1" config="$2" progress="$3"

    for rep in $(seq 1 "$REPETITIONS"); do
        local rep_suffix="" rep_label=""
        if (( REPETITIONS > 1 )); then
            rep_suffix="_rep${rep}"
            rep_label=" (rep $rep/$REPETITIONS)"
        fi

        local out_log="$RESULTS_DIR/${name}${rep_suffix}.raw.log"
        local out_json="$RESULTS_DIR/${name}${rep_suffix}.report.json"

        printf "${C_CYAN}  %s${C_RESET} %-45s%s" "$progress" "$name" "$rep_label"

        local run_start=$SECONDS

        if "$BINARY" -c "$config" > "$out_log" 2>&1; then
            if python3 "$SCRIPTS_DIR/extract_report_json.py" \
                       "$out_log" "$out_json" 2>/dev/null; then
                printf "  ${C_GREEN}OK${C_RESET}   ${C_DIM}(%s)${C_RESET}\n" \
                       "$(elapsed_fmt $(( SECONDS - run_start )))"
                (( ++PASSED ))
            else
                printf "  ${C_YELLOW}WARN${C_RESET} ${C_DIM}(JSON extraction failed — %s)${C_RESET}\n" \
                       "$(elapsed_fmt $(( SECONDS - run_start )))"
                (( ++FAILED ))
                FAILED_NAMES+=("${name}${rep_suffix} (json-extract)")
            fi
        else
            local rc=$?
            printf "  ${C_RED}FAIL${C_RESET} ${C_DIM}(exit %d — %s)${C_RESET}\n" \
                   "$rc" "$(elapsed_fmt $(( SECONDS - run_start )))"
            (( ++FAILED ))
            FAILED_NAMES+=("${name}${rep_suffix} (exit $rc)")
        fi
    done
}

###############################################################################
#  Campaign loop
###############################################################################

PASSED=0
FAILED=0
declare -a FAILED_NAMES=()

run_campaign() {
    local total=${#CONFIGS[@]}
    local counter=0
    local prev_engine=""

    local campaign_start=$SECONDS

    $DRY_RUN && log_info "DRY RUN — listing workloads that would execute:" && echo ""

    for cfg in "${CONFIGS[@]}"; do
        local name engine
        name="$(basename "$cfg" .json)"
        engine="$(get_engine "$name")"

        # Print engine header on transition
        if [[ "$engine" != "$prev_engine" ]]; then
            print_engine_header "$engine"
            prev_engine="$engine"
        fi

        (( ++counter ))
        local progress="[$counter/$total]"

        if $DRY_RUN; then
            log_info "$progress $name  (engine=$engine)"
            continue
        fi

        run_workload "$name" "$cfg" "$progress"
    done

    if $DRY_RUN; then
        echo ""
        log_info "Dry run complete. $total workload(s) would execute."
        return
    fi

    print_summary "$total" $(( SECONDS - campaign_start ))
}

###############################################################################
#  Summary report
###############################################################################

print_summary() {
    local total=$1 elapsed=$2

    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "  SUMMARY"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Generate summary CSV when at least one report succeeded
    local n_reports
    n_reports=$(find "$RESULTS_DIR" -maxdepth 1 -name '*.report.json' | wc -l)
    if (( n_reports > 0 )); then
        if python3 "$SCRIPTS_DIR/summarize_campaign.py" "$RESULTS_DIR" 2>/dev/null; then
            log_info "Summary CSV:  $RESULTS_DIR/summary.csv"
        else
            log_fail "Failed to generate summary CSV"
        fi
    fi

    echo ""
    log_ok   "Passed:   $PASSED"
    if (( FAILED > 0 )); then
        log_fail "Failed:   $FAILED"
        for fn in "${FAILED_NAMES[@]}"; do
            log_dim "· $fn"
        done
    else
        log_info "Failed:   0"
    fi
    log_info "Total:    $((PASSED + FAILED)) / $((total * REPETITIONS))"
    log_info "Elapsed:  $(elapsed_fmt "$elapsed")"
    log_info "Results:  $RESULTS_DIR"
    echo ""
}

###############################################################################
#  Main
###############################################################################

main() {
    setup_colors
    parse_args "$@"
    validate_env
    discover_workloads

    print_header ${#CONFIGS[@]}

    $DRY_RUN || mkdir -p "$RESULTS_DIR"

    run_campaign

    # Non-zero exit when any workload failed
    (( FAILED > 0 )) && exit 1
    exit 0
}

main "$@"
