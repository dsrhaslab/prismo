import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path
from vdbench_parser import load_csv
from plot_style import COLORS, apply_style, fig as _fig, finish as _finish


def _prepare(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df['time'] = pd.to_datetime(df['time'])
    df['elapsed'] = (df['time'] - df['time'].iloc[0]).dt.total_seconds()
    return df


# ── Plots ────────────────────────────────────────────────────────────────────

def plot_throughput(df: pd.DataFrame, output: Path) -> None:
    """Throughput (MB/s) over time."""
    fig, ax = _fig()
    ax.plot(df['elapsed'], df['mbps'], color=COLORS['blue'], label='Throughput')
    ax.fill_between(df['elapsed'], df['mbps'], alpha=0.10, color=COLORS['blue'])
    ax.set_ylabel('Throughput (MB/s)')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda x, _: f'{x:.0f}' if x < 1000 else f'{x/1e3:.1f}k'))
    _finish(fig, ax, output)


def plot_iops(df: pd.DataFrame, output: Path) -> None:
    """IOPS over time."""
    fig, ax = _fig()
    ax.plot(df['elapsed'], df['rate'], color=COLORS['green'], label='IOPS')
    ax.fill_between(df['elapsed'], df['rate'], alpha=0.10, color=COLORS['green'])
    ax.set_ylabel('IOPS')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda x, _: f'{x/1e3:.0f}k' if x >= 1e3 else f'{x:.0f}'))
    _finish(fig, ax, output)


def plot_latency(df: pd.DataFrame, output: Path) -> None:
    """Average response time (ms) over time, with read/write breakdown."""
    fig, ax = _fig()

    ax.plot(df['elapsed'], df['resp'], color=COLORS['blue'], label='Avg resp')
    if (df['read_resp'] > 0).any():
        ax.plot(df['elapsed'], df['read_resp'], color=COLORS['green'],
                linestyle='--', label='Read resp')
    if (df['write_resp'] > 0).any():
        ax.plot(df['elapsed'], df['write_resp'], color=COLORS['orange'],
                linestyle='-.', label='Write resp')

    ax.set_ylabel('Response time (ms)')
    _finish(fig, ax, output)


def plot_latency_max(df: pd.DataFrame, output: Path) -> None:
    """Max response time (ms) over time."""
    fig, ax = _fig()

    if (df['read_max'] > 0).any():
        ax.plot(df['elapsed'], df['read_max'], color=COLORS['green'],
                linestyle='--', label='Read max')
    if (df['write_max'] > 0).any():
        ax.plot(df['elapsed'], df['write_max'], color=COLORS['orange'],
                linestyle='-.', label='Write max')

    ax.set_ylabel('Max response time (ms)')
    _finish(fig, ax, output)


def plot_latency_stddev(df: pd.DataFrame, output: Path) -> None:
    """Response time standard deviation over time."""
    fig, ax = _fig()

    ax.plot(df['elapsed'], df['resp_std'], color=COLORS['blue'], label='Resp stddev')
    if (df['read_std'] > 0).any():
        ax.plot(df['elapsed'], df['read_std'], color=COLORS['green'],
                linestyle='--', label='Read stddev')
    if (df['write_std'] > 0).any():
        ax.plot(df['elapsed'], df['write_std'], color=COLORS['orange'],
                linestyle='-.', label='Write stddev')

    ax.set_ylabel('Response time stddev (ms)')
    _finish(fig, ax, output)


def plot_queue_depth(df: pd.DataFrame, output: Path) -> None:
    """Queue depth over time."""
    fig, ax = _fig()
    ax.plot(df['elapsed'], df['queue_depth'], color=COLORS['purple'], label='Queue depth')
    ax.fill_between(df['elapsed'], df['queue_depth'], alpha=0.10, color=COLORS['purple'])
    ax.set_ylabel('Queue depth')
    _finish(fig, ax, output)


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='vdbench_plots',
        description='Generate publication-quality plots from a vdbench CSV',
    )
    parser.add_argument('-i', '--input', required=True, help='vdbench CSV file')
    parser.add_argument('-o', '--output-dir', default='assets', help='output directory')
    args = parser.parse_args()

    apply_style()
    df = _prepare(load_csv(args.input))
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    plots = [
        (lambda: plot_throughput(df, out / 'throughput.png'),      'throughput.png'),
        (lambda: plot_iops(df, out / 'iops.png'),                  'iops.png'),
        (lambda: plot_latency(df, out / 'latency.png'),            'latency.png'),
        (lambda: plot_latency_max(df, out / 'latency_max.png'),    'latency_max.png'),
        (lambda: plot_latency_stddev(df, out / 'latency_std.png'), 'latency_std.png'),
        (lambda: plot_queue_depth(df, out / 'queue_depth.png'),    'queue_depth.png'),
    ]

    for fn, name in plots:
        fn()
        print(f'Saved {out / name} (+svg)')
