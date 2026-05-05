import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path
from prismo_parser import load_csv

TEXT_WIDTH = 7.16
ASPECT = 0.62

COLORS = {
    'blue':   '#2166ac',
    'red':    '#b2182b',
    'green':  '#1b7837',
    'orange': '#e08214',
    'purple': '#7b3294',
    'grey':   '#636363',
}

RC_PAPER = {
    'font.family':       'serif',
    'font.size':         8,
    'axes.titlesize':    9,
    'axes.labelsize':    8,
    'xtick.labelsize':   7,
    'ytick.labelsize':   7,
    'legend.fontsize':   7,
    'figure.dpi':        300,
    'savefig.dpi':       300,
    'savefig.bbox':      'tight',
    'savefig.pad_inches': 0.02,
    'axes.linewidth':    0.6,
    'xtick.major.width': 0.5,
    'ytick.major.width': 0.5,
    'lines.linewidth':   1.0,
    'lines.markersize':  3,
    'axes.grid':         True,
    'grid.alpha':        0.25,
    'grid.linewidth':    0.4,
}

OP_STYLES = [
    (0, 'Read',      COLORS['green'],  '-'),
    (1, 'Write',     COLORS['orange'], '--'),
    (2, 'Fsync',     COLORS['blue'],   '-.'),
    (3, 'Fdatasync', COLORS['purple'], ':'),
    (4, 'Nop',       COLORS['grey'],   'dotted'),
]


def _apply_style() -> None:
    plt.rcParams.update(RC_PAPER)


def _fig() -> tuple:
    fig, ax = plt.subplots(figsize=(TEXT_WIDTH, TEXT_WIDTH * ASPECT))
    return fig, ax


def _finish(fig, ax, output: Path, xlabel: str = 'Elapsed time (s)') -> None:
    ax.set_xlabel(xlabel)
    ax.legend(loc='upper right', frameon=True, fancybox=False,
              edgecolor='#cccccc', framealpha=0.9, borderpad=0.4)
    ax.margins(x=0, y=0)
    fig.tight_layout()
    fig.savefig(output)
    fig.savefig(output.with_suffix('.svg'))
    plt.close(fig)


def _prepare(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df['latency_ns'] = df['ets'] - df['sts']
    df['latency_us'] = df['latency_ns'] / 1_000
    df = df.sort_values('timestamp')
    return df


def _resample(series: pd.Series, ts: pd.Series, window: str) -> tuple[np.ndarray, pd.Series]:
    tmp = pd.DataFrame({'ts': ts, 'val': series}).set_index('ts')
    resampled = tmp.resample(window)['val']
    return resampled


# ── Plots ────────────────────────────────────────────────────────────────────

def plot_throughput(df: pd.DataFrame, window: str, output: Path) -> None:
    """Throughput (MB/s) over time per operation type."""
    fig, ax = _fig()

    for code, label, color, ls in OP_STYLES:
        subset = df[df['type'] == code]
        if subset.empty:
            continue
        grouped = subset.set_index('timestamp').resample(window)
        bytes_per_window = grouped['proc'].sum()
        window_seconds = pd.Timedelta(window).total_seconds()
        throughput_mbs = bytes_per_window / window_seconds / (1024 * 1024)
        elapsed = (throughput_mbs.index - throughput_mbs.index[0]).total_seconds()
        ax.plot(elapsed, throughput_mbs.values, color=color, linestyle=ls, label=label)
        ax.fill_between(elapsed, throughput_mbs.values, alpha=0.10, color=color)

    ax.set_ylabel('Throughput (MB/s)')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda x, _: f'{x:.0f}' if x < 1000 else f'{x/1e3:.1f}k'))
    _finish(fig, ax, output)


def plot_iops(df: pd.DataFrame, window: str, output: Path) -> None:
    """IOPS over time per operation type."""
    fig, ax = _fig()

    for code, label, color, ls in OP_STYLES:
        subset = df[df['type'] == code]
        if subset.empty:
            continue
        ops = subset.set_index('timestamp').resample(window).size()
        window_seconds = pd.Timedelta(window).total_seconds()
        iops = ops / window_seconds
        elapsed = (iops.index - iops.index[0]).total_seconds()
        ax.plot(elapsed, iops.values, color=color, linestyle=ls, label=label)
        ax.fill_between(elapsed, iops.values, alpha=0.10, color=color)

    ax.set_ylabel('IOPS')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda x, _: f'{x/1e3:.0f}k' if x >= 1e3 else f'{x:.0f}'))
    _finish(fig, ax, output)


def plot_latency(df: pd.DataFrame, window: str, output: Path) -> None:
    """Average latency (µs) over time per operation type."""
    fig, ax = _fig()

    for code, label, color, ls in OP_STYLES:
        subset = df[df['type'] == code]
        if subset.empty:
            continue
        avg_lat = subset.set_index('timestamp')['latency_us'].resample(window).mean()
        elapsed = (avg_lat.index - avg_lat.index[0]).total_seconds()
        ax.plot(elapsed, avg_lat.values, color=color, linestyle=ls, label=label)
        ax.fill_between(elapsed, avg_lat.values, alpha=0.10, color=color)

    ax.set_ylabel('Avg latency (µs)')
    _finish(fig, ax, output)


def plot_latency_cdf(df: pd.DataFrame, output: Path) -> None:
    """CDF of latency per operation type."""
    fig, ax = _fig()

    for code, label, color, ls in OP_STYLES:
        subset = df[df['type'] == code]
        if subset.empty:
            continue
        sorted_lat = np.sort(subset['latency_us'].values)
        cdf = np.arange(1, len(sorted_lat) + 1) / len(sorted_lat)
        ax.plot(sorted_lat, cdf, color=color, linestyle=ls, label=label)

    p99 = np.percentile(df['latency_us'].values, 99)
    ax.set_xlim(left=0, right=p99 * 1.05)
    ax.set_ylabel('CDF')
    ax.set_ylim(0, 1.02)
    _finish(fig, ax, output, xlabel='Latency (µs)')


def plot_offset_pattern(df: pd.DataFrame, output: Path) -> None:
    """Offset access pattern over time (scatter)."""
    fig, ax = _fig()

    for code, label, color, _ in OP_STYLES:
        subset = df[df['type'] == code]
        if subset.empty:
            continue
        elapsed = (subset['timestamp'] - df['timestamp'].iloc[0]).dt.total_seconds()
        offset_mb = subset['offset'] / (1024 * 1024)
        ax.scatter(elapsed, offset_mb, s=0.3, alpha=0.4, color=color, label=label, rasterized=True)

    ax.set_ylabel('Offset (MB)')
    _finish(fig, ax, output)


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='plots',
        description='Generate publication-quality plots from a prismo CSV',
    )
    parser.add_argument('-i', '--input', required=True, help='prismo CSV file')
    parser.add_argument('-o', '--output-dir', default='assets', help='output directory')
    parser.add_argument('-w', '--window', default='1s', help='time window (default: 1s)')
    args = parser.parse_args()

    _apply_style()
    df = _prepare(load_csv(args.input))
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    plots = [
        (lambda: plot_throughput(df, args.window, out / 'throughput.png'),    'throughput.png'),
        (lambda: plot_iops(df, args.window, out / 'iops.png'),               'iops.png'),
        (lambda: plot_latency(df, args.window, out / 'latency.png'),         'latency.png'),
        (lambda: plot_latency_cdf(df, out / 'latency_cdf.png'),              'latency_cdf.png'),
        (lambda: plot_offset_pattern(df, out / 'offset_pattern.png'),        'offset_pattern.png'),
    ]

    for fn, name in plots:
        fn()
        print(f'Saved {out / name} (+svg)')
