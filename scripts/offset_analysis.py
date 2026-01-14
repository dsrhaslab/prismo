import argparse
import pandas as pd
import seaborn as sns # type: ignore
import matplotlib.pyplot as plt # type: ignore
from dataclasses import dataclass
from prismo_entry import get_prismo_entries

@dataclass
class OffsetAnalysisArgs:
    input: str
    output: str
    bins: int


def plot_offset_distribution(df: pd.DataFrame, bins: int, output: str) -> None:
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
    plt.savefig(output, dpi=300, bbox_inches='tight')
    plt.close()


def offset_analysis(args: OffsetAnalysisArgs) -> None:
    df = get_prismo_entries(args.input)
    plot_offset_distribution(df, bins=args.bins, output=args.output)

if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        prog='offset_analysis',
        description='Offset distribution analysis',
    )

    parser.add_argument(
        '-i',
        '--input',
        type=str,
        required=True,
        help='prismo log file path'
    )

    parser.add_argument(
        '-o',
        '--output',
        type=str,
        required=True,
        help='png output file path'
    )

    parser.add_argument(
        '-b',
        '--bins',
        type=int,
        default=10,
        required=False,
        help='number of bins'
    )

    args = parser.parse_args()
    args = OffsetAnalysisArgs(
        input=args.input,
        output=args.output,
        bins=args.bins
    )

    offset_analysis(args)