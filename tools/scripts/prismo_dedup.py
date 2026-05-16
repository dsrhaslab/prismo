import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path
from dataclasses import dataclass
from tabulate import tabulate # type: ignore
from prismo_parser import load_csv
from plot_style import COLORS, apply_style, fig as _fig, finish as _finish


# ── Data structures ──────────────────────────────────────────────────────────

@dataclass
class CompressionStatsEntry:
    reduction: int
    percentage: float

    def __str__(self) -> str:
        return f'{self.percentage:.2f}% → {self.reduction}'


@dataclass
class DedupStatsEntry:
    repeats: int
    unique_blocks: int
    percentage_unique: float
    operations: int
    percentage_global: float
    compression_entries: list[CompressionStatsEntry]

    def to_tuple(self) -> tuple[int, int, float, int, float, str]:
        return (
            self.repeats,
            self.unique_blocks,
            self.percentage_unique,
            self.operations,
            self.percentage_global,
            ' '.join(
                str(e) for e in sorted(
                    self.compression_entries,
                    key=lambda e: e.reduction
                ) if e.percentage > 0.0
            )
        )


@dataclass
class DedupStatistics:
    entries: list[DedupStatsEntry]
    total_operations: int
    write_operations: int
    unique_blocks: int


# ── Analysis ─────────────────────────────────────────────────────────────────

def compute_statistics(df: pd.DataFrame) -> DedupStatistics:
    df_writes = df[df['type'] == 1].copy()
    repetitions = df_writes.groupby('block').size().rename('repeats')
    df_writes = df_writes.join(repetitions, on='block')

    total_operations = len(df)
    write_operations = len(df_writes)
    unique_blocks = df_writes['block'].nunique()

    entries: list[DedupStatsEntry] = []

    for repeats, group in df_writes.groupby('repeats'):
        unique_count = group['block'].nunique()
        ops = repeats * unique_count
        pct_unique = unique_count / unique_blocks * 100
        pct_global = ops / write_operations * 100

        cpr_counts = group['cpr'].value_counts()
        cpr_entries = [
            CompressionStatsEntry(
                reduction=int(reduction),
                percentage=float(count / len(group) * 100)
            )
            for reduction, count in cpr_counts.items()
        ]

        entries.append(DedupStatsEntry(
            repeats=repeats - 1,
            unique_blocks=unique_count,
            percentage_unique=round(pct_unique, 2),
            operations=ops,
            percentage_global=round(pct_global, 2),
            compression_entries=cpr_entries,
        ))

    entries.sort(key=lambda x: x.repeats)

    return DedupStatistics(
        entries=entries,
        total_operations=total_operations,
        write_operations=write_operations,
        unique_blocks=unique_blocks,
    )


def show_table(stats: DedupStatistics, input_file: str) -> None:
    headers = [
        'Repeats', 'Unique blocks', '% unique',
        'Operations', '% global', 'Compression distribution',
    ]
    table_data = [e.to_tuple() for e in stats.entries]
    avg_access = stats.write_operations / stats.unique_blocks

    print(tabulate(table_data, headers=headers, tablefmt='rounded_outline'))
    print(f'\nSummary: {input_file}')
    print(f'  {"Total operations":<28}: {stats.total_operations}')
    print(f'  {"Total writes":<28}: {stats.write_operations}')
    print(f'  {"Unique blocks":<28}: {stats.unique_blocks}')
    print(f'  {"Avg accesses per block":<28}: {avg_access:.3f}')


# ── Plots ────────────────────────────────────────────────────────────────────

def plot_dedup(stats: DedupStatistics, output: Path) -> None:
    repeats = [e.repeats for e in stats.entries]
    operations = [e.operations for e in stats.entries]
    unique_blocks = [e.unique_blocks for e in stats.entries]

    x = np.arange(len(repeats))
    fig, ax = _fig()

    ax.bar(x, operations, color=COLORS['blue'], alpha=0.8, label='Operations')
    ax.set_ylabel('Operations')
    ax.set_xticks(x)
    ax.set_xticklabels(repeats)

    ax2 = ax.twinx()
    ax2.plot(x, unique_blocks, color=COLORS['red'], marker='o', label='Unique blocks')
    ax2.set_ylabel('Unique blocks')

    lines1, labels1 = ax.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax.legend(lines1 + lines2, labels1 + labels2,
              loc='upper right', frameon=True, fancybox=False,
              edgecolor='#cccccc', framealpha=0.9, borderpad=0.4)

    ax.set_xlabel('Number of repeats')
    ax.margins(x=0.02, y=0)
    fig.tight_layout()
    fig.savefig(output)
    fig.savefig(output.with_suffix('.svg'))
    plt.close(fig)


def plot_block_reuse_cdf(df_writes: pd.DataFrame, output: Path) -> None:
    counts = df_writes.groupby('block').size().values
    sorted_counts = np.sort(counts)
    cdf = np.arange(1, len(sorted_counts) + 1) / len(sorted_counts)

    fig, ax = _fig()
    ax.plot(sorted_counts, cdf, color=COLORS['blue'], linewidth=1.2, label='Block reuse')
    ax.fill_between(sorted_counts, cdf, alpha=0.12, color=COLORS['blue'])
    ax.set_ylabel('CDF (fraction of unique blocks)')
    ax.set_ylim(0, 1.02)
    _finish(fig, ax, output, xlabel='Accesses per block')


def plot_dedup_savings(df_writes: pd.DataFrame, output: Path) -> None:
    counts = df_writes.groupby('block').size().sort_values(ascending=False)
    duplicated_ops = (counts - 1).values
    cumulative_saved = np.cumsum(duplicated_ops)
    total_writes = len(df_writes)
    pct_saved = cumulative_saved / total_writes * 100
    x = np.arange(1, len(pct_saved) + 1) / len(pct_saved) * 100

    fig, ax = _fig()
    ax.plot(x, pct_saved, color=COLORS['green'], linewidth=1.2, label='Writes saved')
    ax.fill_between(x, pct_saved, alpha=0.12, color=COLORS['green'])
    ax.set_ylabel('Cumulative writes saved (%)')
    ax.set_ylim(bottom=0)
    _finish(fig, ax, output, xlabel='Unique blocks considered (%)')


def plot_compression_distribution(df_writes: pd.DataFrame, output: Path) -> None:
    counts = df_writes['cpr'].value_counts().sort_index()
    pct = counts / counts.sum() * 100

    fig, ax = _fig()
    ax.bar(pct.index.astype(str), pct.values, color=COLORS['purple'], alpha=0.8, label='Writes')
    ax.set_ylabel('Fraction of writes (%)')
    _finish(fig, ax, output, xlabel='Compression ratio (%)')


def plot_data_reduction(df_writes: pd.DataFrame, output: Path) -> None:
    total_bytes = df_writes['proc'].sum()

    first_writes = df_writes.drop_duplicates(subset='block', keep='first')
    dedup_bytes = first_writes['proc'].sum()
    compressed_bytes = (first_writes['req'] * (1 - first_writes['cpr'] / 100)).clip(lower=0).sum()

    labels = ['Original', 'After dedup', 'After dedup\n+ compression']
    values = np.array([total_bytes, dedup_bytes, compressed_bytes]) / (1024 * 1024)
    colors = [COLORS['grey'], COLORS['blue'], COLORS['green']]

    fig, ax = _fig()
    bars = ax.bar(labels, values, color=colors, alpha=0.8)

    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                f'{val:.1f} MB', ha='center', va='bottom', fontsize=7)

    ax.set_ylabel('Data volume (MB)')
    ax.set_ylim(bottom=0)
    ax.margins(x=0, y=0)
    fig.tight_layout()
    fig.savefig(output)
    fig.savefig(output.with_suffix('.svg'))
    plt.close(fig)


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    p = argparse.ArgumentParser(
        prog='dedup',
        description='Deduplication and compression analysis from prismo CSV',
    )
    p.add_argument('-i', '--input', required=True, help='prismo CSV file')
    p.add_argument('-o', '--output-dir', default='assets', help='output directory')
    args = p.parse_args()

    apply_style()
    df = load_csv(args.input)
    df_writes = df[df['type'] == 1]

    stats = compute_statistics(df)
    show_table(stats, args.input)

    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    plots = [
        (lambda: plot_dedup(stats, out / 'dedup.png'),                           'dedup.png'),
        (lambda: plot_block_reuse_cdf(df_writes, out / 'block_reuse_cdf.png'),   'block_reuse_cdf.png'),
        (lambda: plot_dedup_savings(df_writes, out / 'dedup_savings.png'),        'dedup_savings.png'),
        (lambda: plot_compression_distribution(df_writes, out / 'cpr_dist.png'), 'cpr_dist.png'),
        (lambda: plot_data_reduction(df_writes, out / 'data_reduction.png'),     'data_reduction.png'),
    ]

    for fn, name in plots:
        fn()
        print(f'Saved {out / name} (+svg)')
