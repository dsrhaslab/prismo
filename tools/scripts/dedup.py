import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt # type: ignore
from tabulate import tabulate # type: ignore
from dataclasses import dataclass
from parser import get_prismo_entries

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
                str(cpr_entry)
                for cpr_entry in sorted(
                    self.compression_entries,
                    key=lambda cpr_entry: cpr_entry.reduction
                )
                if cpr_entry.percentage > 0.0
            )
        )


@dataclass
class Statistics:
    entries: list[DedupStatsEntry]
    total_operations: int
    unique_blocks: int


def compute_statistics(
    df: pd.DataFrame
) -> Statistics:
    df_writes = df[df['type'] == 1].copy()
    repetitions = df_writes.groupby('block').size().rename('repeats')
    df_writes = df_writes.join(repetitions, on='block')

    total_operations = len(df)
    unique_blocks = df_writes['block'].nunique()

    stats_entries: list[DedupStatsEntry] = []

    for repeats, group in df_writes.groupby('repeats'):
        unique_blocks_count = group['block'].nunique()
        ops = repeats * unique_blocks_count
        percentage_unique = unique_blocks_count / unique_blocks * 100
        percentage_global = ops / total_operations * 100

        compression_counter = group['cpr'].value_counts()
        compression_entries = [
            CompressionStatsEntry(
                reduction=int(reduction),
                percentage=float(count / len(group) * 100)
            )
            for reduction, count in compression_counter.items()
        ]

        stats_entries.append(DedupStatsEntry(
            repeats=repeats - 1,
            unique_blocks=unique_blocks_count,
            percentage_unique=round(percentage_unique, 2),
            operations=ops,
            percentage_global=round(percentage_global, 2),
            compression_entries=compression_entries
        ))

    stats_entries.sort(key=lambda x: x.repeats)

    return Statistics(
        entries=stats_entries,
        total_operations=total_operations,
        unique_blocks=unique_blocks
    )


def show_statistics_table(
    stats: Statistics,
    input_file: str
) -> None:
    headers = [
        'Repeats',
        'Unique blocks',
        'Percentage unique',
        'Operations',
        'Percentage global',
        'Compression distribution',
    ]

    table_data = [entry.to_tuple() for entry in stats.entries]
    avg_access = stats.total_operations / stats.unique_blocks

    print(tabulate(table_data, headers=headers, tablefmt='rounded_outline'))
    print(f'\nSummary: {input_file}')
    print(f'  {'Total operations (log lines)':<30}: {stats.total_operations}')
    print(f'  {'Total writes':<30}: {sum(e.operations for e in stats.entries)}')
    print(f'  {'Unique blocks':<30}: {stats.unique_blocks}')
    print(f'  {'Average accesses per block':<30}: {avg_access:.3f}')


def plot_operations_vs_repeats(
    stats: Statistics,
    output_file: str = 'assets/operations_vs_repeats.png'
) -> None:
    repeats = [entry.repeats for entry in stats.entries]
    operations = [entry.operations for entry in stats.entries]
    unique_blocks_list = [entry.unique_blocks for entry in stats.entries]

    x = np.arange(len(repeats))
    fig, ax1 = plt.subplots(figsize=(10,6))

    ax1.bar(x, operations, color='skyblue', label='Operations')
    ax1.set_xlabel('Number of Repeats')
    ax1.set_ylabel('Operations', color='black')
    ax1.tick_params(axis='y', labelcolor='black')
    ax1.set_xticks(x)
    ax1.set_xticklabels(repeats)
    ax1.grid(axis='y', linestyle='--', alpha=0.7)

    ax2 = ax1.twinx()
    ax2.plot(x, unique_blocks_list, color='brown', marker='o', label='Unique Blocks')
    ax2.set_ylabel('Unique Blocks', color='black')
    ax2.tick_params(axis='y', labelcolor='black')

    fig.tight_layout()
    fig.legend(loc='upper right', bbox_to_anchor=(1,1), bbox_transform=ax1.transAxes)
    plt.title('Operations and Unique Blocks vs Repeats')
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='dedup',
        description='Deduplication and compression distribution analysis',
    )

    parser.add_argument(
        '-i',
        '--input',
        type=str,
        required=True,
        help='prismo log file path'
    )

    args = parser.parse_args()
    df = get_prismo_entries(args.input)
    stats = compute_statistics(df)

    show_statistics_table(stats, args.input)

    output_file = 'assets/operations_vs_repeats.png'
    plot_operations_vs_repeats(stats)
    print(f'Saved operations vs repeats to {output_file}')