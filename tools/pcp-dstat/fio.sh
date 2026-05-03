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
    merge_fio_logs "$name"
}

# Merge per-job FIO log files into a single file per metric.
# For bw and iops: sum values across jobs at each timestamp.
# For latency (clat, slat, lat): average values across jobs at each timestamp.
merge_fio_logs() {
    local name="$1"
    WORKLOAD_NAME="$name" RESULTS_DIR="$RESULTS_DIR" \
    python3 - << 'PYEOF'
import glob, os, csv
from collections import defaultdict

resdir = os.environ['RESULTS_DIR']
name   = os.environ['WORKLOAD_NAME']

SUM_METRICS = ('bw', 'iops')
AVG_METRICS = ('clat', 'slat', 'lat')

for metric in SUM_METRICS + AVG_METRICS:
    pattern = os.path.join(resdir, f'{name}_{metric}.*.log')
    job_files = sorted(glob.glob(pattern))
    if len(job_files) <= 1:
        continue

    data = defaultdict(list)
    header = None
    for jf in job_files:
        with open(jf) as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                if not row:
                    continue
                data[row[0]].append((float(row[1]), row[2:]))

    merged_path = os.path.join(resdir, f'{name}_{metric}.log')
    with open(merged_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for ts in sorted(data.keys()):
            entries = data[ts]
            if metric in SUM_METRICS:
                merged_val = sum(v for v, _ in entries)
            else:
                merged_val = sum(v for v, _ in entries) / len(entries)
            writer.writerow([ts, int(merged_val)] + entries[0][1])
PYEOF
}

run_campaign
