import re
import argparse
import pandas as pd
from pathlib import Path
from tqdm import tqdm

FLATFILE_HEADER_RE = re.compile(r'^\s+tod\s+timestamp\s+')
COMMENT_RE = re.compile(r'^\s*(\*|<|Copyright|Vdbench|Link|Run |Copy|$)')

COLUMNS = [
    'tod', 'timestamp', 'run', 'interval', 'reqrate', 'rate', 'MB/sec',
    'bytes/io', 'read%', 'resp', 'read_resp', 'write_resp', 'resp_max',
    'read_max', 'write_max', 'resp_std', 'read_std', 'write_std',
    'xfersize', 'threads', 'rdpct', 'rhpct', 'whpct', 'seekpct',
    'lunsize', 'version', 'compratio', 'dedupratio', 'queue_depth',
    'cpu_used', 'cpu_user', 'cpu_kernel', 'cpu_wait', 'cpu_idle',
]

CSV_COLUMNS = [
    'time', 'rate', 'mbps', 'read_pct', 'resp', 'read_resp', 'write_resp',
    'resp_max', 'read_max', 'write_max', 'resp_std', 'read_std', 'write_std',
    'queue_depth',
]

DTYPES = {
    'rate': 'float64', 'mbps': 'float64', 'read_pct': 'float64',
    'resp': 'float64', 'read_resp': 'float64', 'write_resp': 'float64',
    'resp_max': 'float64', 'read_max': 'float64', 'write_max': 'float64',
    'resp_std': 'float64', 'read_std': 'float64', 'write_std': 'float64',
    'queue_depth': 'float64',
}


def parse_flatfile(path: str) -> pd.DataFrame:
    """Parse a vdbench flatfile.html into a DataFrame."""
    lines = Path(path).read_text().splitlines()
    rows = []
    for line in tqdm(lines, desc='Parsing', unit='lines'):
        if COMMENT_RE.match(line) or FLATFILE_HEADER_RE.match(line):
            continue
        parts = line.split()
        if len(parts) < len(COLUMNS):
            continue
        raw = dict(zip(COLUMNS, parts))
        rows.append({
            'time': raw['timestamp'].replace('-UTC', '').replace('-', ' ', 1).replace('-', '/'),
            'rate': float(raw['rate']),
            'mbps': float(raw['MB/sec']),
            'read_pct': float(raw['read%']),
            'resp': float(raw['resp']),
            'read_resp': float(raw['read_resp']),
            'write_resp': float(raw['write_resp']),
            'resp_max': float(raw['resp_max']),
            'read_max': float(raw['read_max']),
            'write_max': float(raw['write_max']),
            'resp_std': float(raw['resp_std']),
            'read_std': float(raw['read_std']),
            'write_std': float(raw['write_std']),
            'queue_depth': float(raw['queue_depth']),
        })

    df = pd.DataFrame(rows, columns=CSV_COLUMNS).astype(DTYPES)
    return df


def parse_summary(path: str) -> pd.DataFrame:
    """Parse a vdbench summary.html into a DataFrame."""
    lines = Path(path).read_text().splitlines()
    header_line = None
    rows = []

    for i, line in enumerate(lines):
        if 'interval' in line and 'i/o' in line and 'MB/sec' in line:
            header_line = i
            continue
        if header_line is not None and i == header_line + 1:
            continue
        if header_line is not None and line.strip():
            parts = line.split()
            if len(parts) < 15:
                continue

            date_str = parts[0]
            time_str = parts[1]
            interval = parts[2]
            if interval.startswith('avg'):
                continue
            rows.append({
                'time': f'{date_str} {time_str}',
                'interval': int(interval),
                'rate': float(parts[3]),
                'mbps': float(parts[4]),
                'bytes_io': int(parts[5]),
                'read_pct': float(parts[6]),
                'resp': float(parts[7]),
                'read_resp': float(parts[8]),
                'write_resp': float(parts[9]),
                'read_max': float(parts[10]),
                'write_max': float(parts[11]),
                'resp_std': float(parts[12]),
                'queue_depth': float(parts[13]),
                'cpu_used': float(parts[14]),
                'cpu_sys': float(parts[15]),
            })

    return pd.DataFrame(rows)


def load_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path).astype(DTYPES)
    return df


def process_report(report_dir: str, output: str | None = None) -> str:
    """Process a single .report/ directory."""
    report_path = Path(report_dir)
    flatfile = report_path / 'flatfile.html'
    if not flatfile.exists():
        raise FileNotFoundError(f'flatfile.html not found in {report_dir}')

    df = parse_flatfile(str(flatfile))
    if output is None:
        output = str(report_path.parent / f'{report_path.stem}.flatfile.csv')
    df.to_csv(output, index=False)
    return output


if __name__ == '__main__':
    p = argparse.ArgumentParser(description='Convert vdbench reports to CSV')
    p.add_argument(
        '-i', '--input', required=True,
        help='vdbench .report/ directory containing flatfile.html'
    )
    p.add_argument(
        '-o', '--output', default=None,
        help='output CSV file (default: <report_name>.flatfile.csv next to report dir)'
    )
    args = p.parse_args()

    input_path = Path(args.input)
    if not input_path.is_dir():
        print(f'{input_path} is not a valid directory')
        raise SystemExit(1)

    out = process_report(str(input_path), args.output)
    df = load_csv(out)
    print(f'Wrote {len(df)} rows to {out}')
