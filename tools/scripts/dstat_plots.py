import argparse
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.ticker as ticker
from pathlib import Path

COLUMN_WIDTH = 3.5
TEXT_WIDTH = 7.16
ASPECT = 0.62

COLORS = {
    'blue':   '#2166ac',
    'red':    '#b2182b',
    'green':  '#1b7837',
    'orange': '#e08214',
    'purple': '#7b3294',
    'grey':   '#636363',
    'yellow': '#dfc27d',
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


def _apply_style() -> None:
    plt.rcParams.update(RC_PAPER)


def _fig(width: float = TEXT_WIDTH) -> tuple:
    fig, ax = plt.subplots(figsize=(width, width * ASPECT))
    return fig, ax


def _elapsed_seconds(df: pd.DataFrame) -> pd.Series:
    t0 = df['time'].iloc[0]
    return (df['time'] - t0).dt.total_seconds()


def _finish(fig, ax, output: Path, xlabel: str = 'Elapsed time (s)') -> None:
    ax.set_xlabel(xlabel)
    ax.legend(loc='upper right', frameon=True, fancybox=False,
              edgecolor='#cccccc', framealpha=0.9, borderpad=0.4)
    # ax.spines['top'].set_visible(False)
    # ax.spines['right'].set_visible(False)
    ax.margins(x=0, y=0)
    fig.tight_layout()
    fig.savefig(output)
    fig.savefig(output.with_suffix('.svg'))
    plt.close(fig)


def load_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df['time'] = pd.to_datetime(df['time'], format='%Y/%m/%d %H:%M:%S')
    return df


def plot_cpu_usage(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)

    series = [
        ('total usage:usr', 'User',     COLORS['blue'],   '-'),
        ('total usage:sys', 'System',   COLORS['red'],    '--'),
        ('total usage:wai', 'I/O wait', COLORS['orange'], '-.'),
        ('total usage:stl', 'Steal',    COLORS['purple'], ':'),
        ('total usage:idl', 'Idle',     COLORS['grey'],   '-'),
    ]

    for col, label, color, ls in series:
        y = df[col]
        ax.plot(elapsed, y, color=color, linestyle=ls, label=label)
        ax.fill_between(elapsed, y, alpha=0.12, color=color)

    ax.set_ylim(0, 100)
    ax.set_ylabel('CPU utilization (%)')
    _finish(fig, ax, output)


def plot_cpu_events(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)

    ax.plot(elapsed, df['int'], color=COLORS['purple'], label='Interrupts')
    ax.fill_between(elapsed, df['int'], alpha=0.12, color=COLORS['purple'])
    ax.plot(elapsed, df['csw'], color=COLORS['orange'], linestyle='--', label='Context switches')
    ax.fill_between(elapsed, df['csw'], alpha=0.12, color=COLORS['orange'])

    ax.set_ylabel('Events per second')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{x/1e3:.0f}k' if x >= 1e3 else f'{x:.0f}'))
    _finish(fig, ax, output)


def plot_memory_usage(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)
    mib = 1024

    series = [
        ('used', 'Used',    COLORS['red'],    '-'),
        ('buf',  'Buffers', COLORS['blue'],   '--'),
        ('cach', 'Cached',  COLORS['yellow'], '-.'),
        ('free', 'Free',    COLORS['green'],  ':'),
    ]

    for col, label, color, ls in series:
        y = df[col] / mib
        ax.plot(elapsed, y, color=color, linestyle=ls, label=label)
        ax.fill_between(elapsed, y, alpha=0.12, color=color)

    ax.set_ylim(bottom=0)
    ax.set_ylabel('Memory (MiB)')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{x/1e3:.1f}k' if x >= 1e3 else f'{x:.0f}'))
    _finish(fig, ax, output)


def plot_disk_throughput(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)

    y_read = df['dsk/total:read'] / 1024
    y_write = df['dsk/total:writ'] / 1024
    ax.plot(elapsed, y_read, color=COLORS['green'],  label='Read')
    ax.fill_between(elapsed, y_read, alpha=0.12, color=COLORS['green'])
    ax.plot(elapsed, y_write, color=COLORS['orange'], linestyle='--', label='Write')
    ax.fill_between(elapsed, y_write, alpha=0.12, color=COLORS['orange'])

    ax.set_ylabel('Throughput (MB/s)')
    _finish(fig, ax, output)


def plot_disk_iops(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)

    ax.plot(elapsed, df['read'], color=COLORS['green'],  label='Read')
    ax.fill_between(elapsed, df['read'], alpha=0.12, color=COLORS['green'])
    ax.plot(elapsed, df['writ'], color=COLORS['orange'], linestyle='--', label='Write')
    ax.fill_between(elapsed, df['writ'], alpha=0.12, color=COLORS['orange'])

    ax.set_ylabel('IOPS')
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{x/1e3:.0f}k' if x >= 1e3 else f'{x:.0f}'))
    _finish(fig, ax, output)


def plot_disk_paging(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)

    ax.plot(elapsed, df['in'],  color=COLORS['blue'],   label='Page in')
    ax.fill_between(elapsed, df['in'], alpha=0.12, color=COLORS['blue'])
    ax.plot(elapsed, df['out'], color=COLORS['purple'], linestyle='--', label='Page out')
    ax.fill_between(elapsed, df['out'], alpha=0.12, color=COLORS['purple'])

    ax.set_ylabel('Paging (KB/s)')
    _finish(fig, ax, output)


def plot_network_throughput(df: pd.DataFrame, output: Path) -> None:
    fig, ax = _fig()
    elapsed = _elapsed_seconds(df)

    y_recv = df['net/total:recv'] / 1024
    y_send = df['net/total:send'] / 1024
    ax.plot(elapsed, y_recv, color=COLORS['green'], label='Recv')
    ax.fill_between(elapsed, y_recv, alpha=0.12, color=COLORS['green'])
    ax.plot(elapsed, y_send, color=COLORS['blue'],  linestyle='--', label='Send')
    ax.fill_between(elapsed, y_send, alpha=0.12, color=COLORS['blue'])

    ax.set_ylabel('Throughput (MB/s)')
    _finish(fig, ax, output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='campaign',
        description='Generate publication-quality plots from a dstat CSV file',
    )

    parser.add_argument(
        '-i', '--input',
        type=str,
        required=True,
        help='path to the .dstat.csv file',
    )

    parser.add_argument(
        '-o', '--output-dir',
        type=str,
        default='assets',
        help='directory to save plots (default: assets)',
    )

    args = parser.parse_args()
    _apply_style()
    df = load_csv(args.input)

    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    plots = [
        (plot_cpu_usage,          'cpu_usage.png'),
        (plot_cpu_events,         'cpu_events.png'),
        (plot_memory_usage,       'memory_usage.png'),
        (plot_disk_throughput,    'disk_throughput.png'),
        (plot_disk_iops,          'disk_iops.png'),
        (plot_disk_paging,        'disk_paging.png'),
        (plot_network_throughput, 'network_throughput.png'),
    ]

    for fn, name in plots:
        path = out / name
        fn(df, path)
        print(f'Saved {path} (+svg)')
