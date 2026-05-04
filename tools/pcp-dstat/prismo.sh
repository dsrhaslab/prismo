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

convert_prismo_logs() {
    local name="$1" block_size="$2"
    WORKLOAD_NAME="$name" RESULTS_DIR="$RESULTS_DIR" BLOCK_SIZE="$block_size" \
    python3 - << 'PYEOF'
import re, os, glob, csv
from collections import defaultdict

resdir     = os.environ['RESULTS_DIR']
name       = os.environ['WORKLOAD_NAME']
block_size = int(os.environ['BLOCK_SIZE'])

log_files = sorted(glob.glob(os.path.join(resdir, f'{name}-job*')))
if not log_files:
    exit(0)

# data[timestamp][op_type] = [processed_bytes, ...]
data = defaultdict(lambda: defaultdict(list))

line_re = re.compile(
    r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d+\].*'
    r'type=(\d+).*?proc=(\d+)')

for lf in log_files:
    with open(lf) as f:
        for line in f:
            m = line_re.search(line)
            if not m:
                continue
            ts = m.group(1).replace('-', '/')
            op = int(m.group(2))
            proc = int(m.group(3))
            data[ts][op].append(proc)

csv_path = os.path.join(resdir, f'{name}.prismo.csv')
with open(csv_path, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['time', 'read_bw', 'write_bw', 'read_iops', 'write_iops',
                      'fsync_iops', 'fdatasync_iops', 'nop_iops'])
    for ts in sorted(data.keys()):
        read_bw  = sum(data[ts].get(0, []))
        write_bw = sum(data[ts].get(1, []))
        read_iops      = read_bw  // block_size
        write_iops     = write_bw // block_size
        fsync_iops     = len(data[ts].get(2, []))
        fdatasync_iops = len(data[ts].get(3, []))
        nop_iops       = len(data[ts].get(4, []))
        writer.writerow([ts, read_bw, write_bw, read_iops, write_iops,
                          fsync_iops, fdatasync_iops, nop_iops])
PYEOF
}

run_workload() {
    local cfg="$1" report="$2"
    local name
    name="$(basename "$cfg" .json)"

    # Redirect prismo log files to the campaign results directory
    local patched_cfg="${RESULTS_DIR}/${name}.json"
    RESULTS_DIR="$RESULTS_DIR" WORKLOAD_NAME="$name" \
    python3 -c "
import json, os
cfg = '$cfg'
with open(cfg) as f:
    config = json.load(f)
config.setdefault('logger', {})['files'] = [os.path.join(os.environ['RESULTS_DIR'], os.environ['WORKLOAD_NAME'])]
with open('${patched_cfg}', 'w') as f:
    json.dump(config, f, indent=2)
"

    local block_size
    block_size=$(python3 -c "import json; print(json.load(open('$patched_cfg'))['job']['block_size'])")

    "$TOOL_BIN" -c "$patched_cfg" -o "$report" -l
    convert_prismo_logs "$name" "$block_size"
}

run_campaign
