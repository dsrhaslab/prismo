import argparse
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from parser import get_prismo_entries


def plot_offset_distribution(
    df: pd.DataFrame,
    bins: int,
    output_file: str = 'png/offset_dist.png'
) -> None:
    sns.histplot(
        df['offset'],
        bins=bins,
        stat="density",
        kde=True,
        kde_kws={"bw_adjust": 1.5}
    )

    plt.xlabel("Offset")
    plt.ylabel("Density")
    plt.title("Offsets Distribution")
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()


def plot_column_distribution(
    df: pd.DataFrame,
    column: str,
    output_file: str = 'png/column_dist.png'
) -> None:
    counts = df[column].value_counts().sort_index()

    plt.figure(figsize=(10, 5))
    sns.barplot(x=counts.index.astype(str), y=counts.values)
    plt.xlabel(f'{column.upper()} Code')
    plt.ylabel('Frequency')
    plt.title(f'Frequency of {column.upper()} Codes')
    plt.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        prog='distribution',
        description='Distribution analysis',
    )

    parser.add_argument(
        '-i',
        '--input',
        type=str,
        required=True,
        help='prismo log file path'
    )

    parser.add_argument(
        '-b',
        '--bins',
        type=int,
        default=10,
        required=False,
        help='number of bins in offset distribution'
    )

    args = parser.parse_args()
    df = get_prismo_entries(args.input)

    columns: list[str] = [
        'pid',
        'tid',
        'req',
        'proc',
        'offset',
        'ret',
        'errno',
        'type'
    ]

    output_file = 'png/offset_dist.png'
    plot_offset_distribution(df, args.bins)
    print(f'Saved offset distribution plot to {output_file}')

    for column in columns:
        output_file = f'png/{column}_dist.png'
        plot_column_distribution(df, column, output_file=output_file)
        print(f'Saved {column} frequency plot to {output_file}')