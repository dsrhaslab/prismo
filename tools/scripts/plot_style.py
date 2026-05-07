import matplotlib.pyplot as plt
from pathlib import Path

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


def apply_style() -> None:
    plt.rcParams.update(RC_PAPER)


def fig() -> tuple:
    f, ax = plt.subplots(figsize=(TEXT_WIDTH, TEXT_WIDTH * ASPECT))
    return f, ax


def finish(f, ax, output: Path, xlabel: str = 'Elapsed time (s)') -> None:
    ax.set_xlabel(xlabel)
    ax.legend(loc='upper right', frameon=True, fancybox=False,
              edgecolor='#cccccc', framealpha=0.9, borderpad=0.4)
    ax.margins(x=0, y=0)
    f.tight_layout()
    f.savefig(output)
    f.savefig(output.with_suffix('.svg'))
    plt.close(f)
