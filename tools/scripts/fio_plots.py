import argparse
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path
from fio_parser import load_csv
from plot_style import COLORS, apply_style, fig as _fig, finish as _finish


def _prepare(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df['elapsed'] = df['time_ms'] / 1000.0
    df['read_bw_mbs'] = df['read_bw'] / 1024.0
    df['write_bw_mbs'] = df['write_bw'] / 1024.0
    df['total_bw_mbs'] = df['read_bw_mbs'] + df['write_bw_mbs']
    df['total_iops'] = df['read_iops'] + df['write_iops']
    for col in ['read_lat', 'write_lat', 'read_clat', 'write_clat']:
        if col in df.columns:
            df[f'{col}_us'] = df[col] / 1000.0
    return df


# ── Plots ────────────────────────────────────────────────────────────────────

def plot_throughput(df: pd.DataFrame, output: Path) -> None:
    """Throughput (MiB/s) over time, read/write breakdown."""
    fig, ax = _fig()

    if (df['read_bw_mbs'] > 0).any():
        ax.plot(df['elapsed'], df['read_bw_mbs'], color=COLORS['green'],
                linestyle='--', label='Read')
    if (df['write_bw_mbs'] > 0).any():
        ax.plot(df['elapsed'], df['write_bw_mbs'], color=COLORS['orange'],
                linestyle='-.', label='Write')
    ax.plot(df['elapsed'], df['total_bw_mbs'], color=COLORS['blue'], label='Total')
    ax.fill_between(df['elapsed'], df['total_bw_mbs'], alpha=0.08, color=COLORS['blue'])

    ax.set_ylabel('Throughput (MiB/s)')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda x, _: f'{x:.0f}' if x < 1000 else f'{x/1e3:.1f}k'))
    _finish(fig, ax, output)


def plot_iops(df: pd.DataFrame, output: Path) -> None:
    """IOPS over time, read/write breakdown."""
    fig, ax = _fig()

    if (df['read_iops'] > 0).any():
        ax.plot(df['elapsed'], df['read_iops'], color=COLORS['green'],
                linestyle='--', label='Read')
    if (df['write_iops'] > 0).any():
        ax.plot(df['elapsed'], df['write_iops'], color=COLORS['orange'],
                linestyle='-.', label='Write')
    ax.plot(df['elapsed'], df['total_iops'], color=COLORS['blue'], label='Total')
    ax.fill_between(df['elapsed'], df['total_iops'], alpha=0.08, color=COLORS['blue'])

    ax.set_ylabel('IOPS')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda x, _: f'{x/1e3:.0f}k' if x >= 1e3 else f'{x:.0f}'))
    _finish(fig, ax, output)


def plot_latency(df: pd.DataFrame, output: Path) -> None:
    """Total latency (µs) over time."""
    fig, ax = _fig()

    if (df['read_lat_us'] > 0).any():
        ax.plot(df['elapsed'], df['read_lat_us'], color=COLORS['green'],
                linestyle='--', label='Read')
    if (df['write_lat_us'] > 0).any():
        ax.plot(df['elapsed'], df['write_lat_us'], color=COLORS['orange'],
                linestyle='-.', label='Write')

    ax.set_ylabel('Latency (µs)')
    _finish(fig, ax, output)


def plot_clat(df: pd.DataFrame, output: Path) -> None:
    """Completion latency (µs) over time."""
    fig, ax = _fig()

    if (df['read_clat_us'] > 0).any():
        ax.plot(df['elapsed'], df['read_clat_us'], color=COLORS['green'],
                linestyle='--', label='Read')
    if (df['write_clat_us'] > 0).any():
        ax.plot(df['elapsed'], df['write_clat_us'], color=COLORS['orange'],
                linestyle='-.', label='Write')

    ax.set_ylabel('Completion latency (µs)')
    _finish(fig, ax, output)


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='fio_plots',
        description='Generate publication-quality plots from a fio CSV',
    )
    parser.add_argument('-i', '--input', required=True, help='fio CSV file')
    parser.add_argument('-o', '--output-dir', default='assets', help='output directory')
    args = parser.parse_args()

    apply_style()
    df = _prepare(load_csv(args.input))
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    plots = [
        (lambda: plot_throughput(df, out / 'throughput.png'), 'throughput.png'),
        (lambda: plot_iops(df, out / 'iops.png'),             'iops.png'),
        (lambda: plot_latency(df, out / 'latency.png'),       'latency.png'),
        (lambda: plot_clat(df, out / 'clat.png'),             'clat.png'),
    ]

    for fn, name in plots:
        fn()
        print(f'Saved {out / name} (+svg)')
