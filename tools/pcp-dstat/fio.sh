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

# Convert fio log files from relative time_ms to absolute datetime timestamps.
# This makes them compatible with the Grafana infinity CSV datasource.
# Output format: time,value,direction,bs,offset
convert_fio_logs() {
    local report="$1" name="$2"
    REPORT_PATH="$report" WORKLOAD_NAME="$name" RESULTS_DIR="$RESULTS_DIR" \
    python3 - << 'PYEOF'
import json, datetime, glob, os

report  = os.environ['REPORT_PATH']
resdir  = os.environ['RESULTS_DIR']
name    = os.environ['WORKLOAD_NAME']

with open(report) as f:
    data = json.load(f)

job_start = data['jobs'][0]['job_start']  # ms since epoch

for log_path in sorted(glob.glob(os.path.join(resdir, f'{name}_*.log'))):
    rows = []
    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(',')]
            if len(parts) < 5:
                continue
            t_ms = int(parts[0])
            dt = datetime.datetime.fromtimestamp((job_start + t_ms) / 1000.0)
            parts[0] = dt.strftime('%Y/%m/%d %H:%M:%S')
            rows.append(','.join(parts))
    if rows:
        with open(log_path, 'w') as f:
            f.write('time,value,direction,bs,offset\n')
            f.write('\n'.join(rows) + '\n')
PYEOF
}

run_workload() {
    local cfg report abs_cfg name
    cfg="$1"; report="$2"
    abs_cfg="$(realpath "$cfg")"
    name="$(basename "$cfg" .fio)"
    (cd "$RESULTS_DIR" && "$TOOL_BIN" "$abs_cfg" \
        --output-format=json --output="$report" \
        --write_bw_log="${name}" \
        --write_lat_log="${name}" \
        --write_iops_log="${name}" \
        --log_avg_msec=1000)
    convert_fio_logs "$report" "$name"
}

run_campaign
