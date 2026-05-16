import re
import argparse
import pandas as pd
from tqdm import tqdm # type: ignore

LOG_RE = re.compile(
    r'\[(?P<ts>[\d\-: .]+)\] \[\w+\] \[\w+\] \[(?P<fields>[^\]]+)\]'
)

DTYPES = {
    'type': 'uint32', 'block': 'uint32', 'cpr': 'uint32',
    'sts': 'int64', 'ets': 'int64', 'pid': 'uint32',
    'tid': 'uint64', 'req': 'uint32', 'proc': 'uint32',
    'offset': 'uint64', 'ret': 'int32', 'errno': 'int32',
}


def parse_log(path: str) -> pd.DataFrame:
    total = sum(1 for _ in open(path, 'r'))
    rows = []
    with open(path, 'r') as f:
        for line in tqdm(f, total=total, desc='Parsing', unit='lines'):
            m = LOG_RE.match(line)
            if not m:
                continue
            row = {'timestamp': m.group('ts')}
            for pair in m.group('fields').split():
                k, v = pair.split('=')
                row[k] = int(v, 16) if k == 'block' else int(v)
            rows.append(row)

    df = pd.DataFrame(rows).astype(DTYPES)
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    return df


def load_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path).astype(DTYPES)
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    return df


if __name__ == '__main__':
    p = argparse.ArgumentParser(description='Convert prismo logs to CSV')
    p.add_argument('-i', '--input', required=True, help='prismo log file')
    p.add_argument('-o', '--output', default=None, help='output CSV (default: <input>.csv)')
    args = p.parse_args()

    output = args.output or args.input.rsplit('.', 1)[0] + '.csv'
    df = parse_log(args.input)
    df.to_csv(output, index=False)
    print(f'Wrote {len(df)} rows to {output}')