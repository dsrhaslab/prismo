import re
import pandas as pd
from tqdm import tqdm # type: ignore
from datetime import datetime
from typing import Iterator

LOG_RE = re.compile(
    r'\[(?P<timestamp>.*?)\] '
    r'\[(?P<module>.*?)\] '
    r'\[(?P<level>.*?)\] '
    r'\[(?P<fields>.*)\]'
)

DTYPES = {
    'type': 'uint32',
    'block': 'uint32',
    'cpr': 'uint32',
    'sts': 'int64',
    'ets': 'int64',
    'pid': 'uint32',
    'tid': 'uint64',
    'req': 'uint32',
    'proc': 'uint32',
    'offset': 'uint64',
    'ret': 'int32',
    'errno': 'int32',
}


def iter_prismo_rows(log_filename: str) -> Iterator[dict]:
    total_lines = sum(1 for _ in open(log_filename, 'r'))

    with open(log_filename, 'r') as f:
        for line in tqdm(f, total=total_lines, desc=f'Reading {log_filename}', unit='lines'):
            line = line.strip()
            if not line:
                continue

            m = LOG_RE.match(line)
            if not m:
                continue

            row = {
                'timestamp': datetime.strptime(
                    m.group('timestamp'),
                    '%Y-%m-%d %H:%M:%S.%f'
                ),
                'module': m.group('module'),
                'level': m.group('level'),
            }

            for part in m.group('fields').split():
                k, v = part.split('=')
                row[k] = int(v)

            yield row


def get_prismo_entries(
    log_filename: str,
    chunk_size: int = 100_000
) -> pd.DataFrame:
    chunks = []
    batch = []

    for row in iter_prismo_rows(log_filename):
        batch.append(row)
        if len(batch) == chunk_size:
            chunks.append(pd.DataFrame(batch))
            batch.clear()

    if batch:
        chunks.append(pd.DataFrame(batch))

    df = pd.concat(chunks, ignore_index=True)
    df = df.astype(DTYPES)
    df['timestamp'] = pd.to_datetime(df['timestamp'])

    return df