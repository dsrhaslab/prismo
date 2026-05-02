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

convert_vdbench_flatfile() {
    local report_dir="$1" csv_out="$2"
    local flatfile="${report_dir}/flatfile.html"
    [[ -f "$flatfile" ]] || return 0
    python3 - "$flatfile" "$csv_out" << 'PYEOF'
import re, sys

flatfile, csv_out = sys.argv[1], sys.argv[2]

lines = []
with open(flatfile) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('*') or line.startswith('<'):
            continue
        lines.append(line)

if len(lines) < 2:
    sys.exit(0)

header = lines[0].split()
col = {name: i for i, name in enumerate(header)}

keep = ['timestamp', 'rate', 'MB/sec', 'read%', 'resp', 'read_resp',
        'write_resp', 'resp_max', 'read_max', 'write_max', 'resp_std',
        'read_std', 'write_std', 'queue_depth']
out_names = ['time', 'rate', 'mbps', 'read_pct', 'resp', 'read_resp',
             'write_resp', 'resp_max', 'read_max', 'write_max', 'resp_std',
             'read_std', 'write_std', 'queue_depth']
indices = [col[k] for k in keep]

rows = []
for line in lines[1:]:
    fields = line.split()
    if len(fields) < len(header):
        continue
    interval = fields[col['Interval']]
    if interval.startswith('avg'):
        continue
    ts = fields[col['timestamp']]
    m = re.match(r'(\d{2})/(\d{2})/(\d{4})-(\d{2}:\d{2}:\d{2})', ts)
    if m:
        fields[col['timestamp']] = f'{m.group(3)}/{m.group(1)}/{m.group(2)} {m.group(4)}'
    rows.append([fields[i] for i in indices])

with open(csv_out, 'w') as f:
    f.write(','.join(out_names) + '\n')
    for row in rows:
        f.write(','.join(row) + '\n')
PYEOF
}

run_workload() {
    local cfg="$1" report="$2"
    local name
    name="$(basename "$cfg")"
    name="${name%.*}"
    "$TOOL_BIN" -f "$cfg" -o "$report" > /dev/null 2>&1
    convert_vdbench_flatfile "$report" "$(dirname "$report")/${name}.flatfile.csv"
}

run_campaign
