import argparse
import pandas as pd
from pathlib import Path
from tqdm import tqdm

LOG_COLS = ['time_ms', 'value', 'direction', 'bs', 'offset']

DTYPES = {
    'time_ms': 'int64', 'value': 'float64',
    'direction': 'int32', 'bs': 'int64', 'offset': 'int64',
}

CSV_COLUMNS = [
    'time_ms', 'read_bw', 'write_bw', 'read_iops', 'write_iops',
    'read_lat', 'write_lat', 'read_clat', 'write_clat',
    'read_slat', 'write_slat',
]


def _read_log(path: Path) -> pd.DataFrame:
    """Read a single fio log file."""
    df = pd.read_csv(path, header=None, names=LOG_COLS, skipinitialspace=True)
    return df.astype(DTYPES)


def _aggregate_metric(directory: Path, prefix: str, metric: str) -> pd.DataFrame:
    """Aggregate a metric across all job log files, grouped by time and direction."""
    pattern = f'{prefix}_{metric}.*.log'
    files = sorted(directory.glob(pattern))
    if not files:
        return pd.DataFrame(columns=['time_ms', 'direction', 'value'])

    frames = []
    for f in files:
        frames.append(_read_log(f))

    df = pd.concat(frames, ignore_index=True)
    df['time_ms'] = ((df['time_ms'] + 500) // 1000) * 1000

    if metric in ('bw', 'iops'):
        agg = df.groupby(['time_ms', 'direction'])['value'].sum().reset_index()
    else:
        agg = df.groupby(['time_ms', 'direction'])['value'].mean().reset_index()

    return agg


def parse_campaign(directory: str, prefix: str | None = None) -> pd.DataFrame:
    """Parse fio logs from a campaign directory into a single DataFrame."""
    dirpath = Path(directory)

    if prefix is None:
        bw_logs = sorted(dirpath.glob('*_bw.*.log'))
        if not bw_logs:
            raise FileNotFoundError(f'No fio log files found in {directory}')
        name = bw_logs[0].name
        prefix = name.rsplit('_bw.', 1)[0]

    metrics = ['bw', 'iops', 'lat', 'clat', 'slat']
    result = None

    for metric in tqdm(metrics, desc='Parsing metrics'):
        agg = _aggregate_metric(dirpath, prefix, metric)
        if agg.empty:
            continue

        read_df = agg[agg['direction'] == 0][['time_ms', 'value']].rename(
            columns={'value': f'read_{metric}'})
        write_df = agg[agg['direction'] == 1][['time_ms', 'value']].rename(
            columns={'value': f'write_{metric}'})

        if result is None:
            result = read_df.merge(write_df, on='time_ms', how='outer')
        else:
            result = result.merge(read_df, on='time_ms', how='outer')
            result = result.merge(write_df, on='time_ms', how='outer')

    if result is None:
        raise FileNotFoundError(f'No fio log files found in {directory}')

    result = result.sort_values('time_ms').reset_index(drop=True)
    result = result.fillna(0)
    return result


def load_csv(path: str) -> pd.DataFrame:
    return pd.read_csv(path)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description='Convert fio logs to CSV')
    p.add_argument('-i', '--input', required=True,
                   help='fio campaign directory containing log files')
    p.add_argument('-o', '--output', default=None,
                   help='output CSV file (default: <dir_name>.csv next to input dir)')
    args = p.parse_args()

    input_path = Path(args.input)
    if not input_path.is_dir():
        print(f'{input_path} is not a valid directory')
        raise SystemExit(1)

    output = args.output or str(input_path.parent / f'{input_path.name}.csv')
    df = parse_campaign(str(input_path))
    df.to_csv(output, index=False)
    print(f'Wrote {len(df)} rows to {output}')
