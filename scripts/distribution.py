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
    plot_offset_distribution(df, args.bins)