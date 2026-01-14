import argparse
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from dataclasses import dataclass
from parser import get_prismo_entries

@dataclass
class OperationType:
    code: int
    name: str


def plot_operations_over_time(
    df: pd.DataFrame,
    operation: OperationType,
    time_window: str = '1s',
    output_file: str = 'png/overtime.png'
) -> None:
    df = df.copy()
    df['timestamp'] = pd.to_datetime(df['timestamp'])

    if operation.name != 'all':
        df = df[df['type'] == operation.code]

    operations_per_window = df.set_index('timestamp').resample(time_window).size()

    if operations_per_window.empty or operations_per_window.nunique() <= 1:
        print(f'Not enough {operation.name} data to plot over time.')
        return

    plt.figure(figsize=(12, 5))
    operations_per_window.plot()
    plt.xlabel('Time')
    plt.ylabel(f'Number of {operation.name.capitalize()}s')
    plt.title(f'Number of {operation.name.capitalize()}s Over Time (Window: {time_window})')
    plt.grid(alpha=0.3)

    if operations_per_window.index.nunique() == 1:
        single_time = operations_per_window.index[0]
        plt.xlim(single_time - pd.Timedelta(seconds=1), single_time + pd.Timedelta(seconds=1))

    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()


def plot_interarrival_times(
    df: pd.DataFrame,
    operation: OperationType,
    bins: int = 100,
    output_file: str = 'png/interarrival.png',
) -> None:
    df = df.copy()
    df['timestamp'] = pd.to_datetime(df['timestamp'])

    if operation.name != 'all':
        df = df[df['type'] == operation.code]

    df = df.sort_values('timestamp')

    if len(df) < 2:
        print(f'Not enough {operation.name} entries to compute inter-arrival times.')
        return

    delta_t = df['timestamp'].diff().dt.total_seconds().dropna()

    if delta_t.empty:
        print(f'No inter-arrival times for {operation.name}. Skipping.')
        return

    plt.figure(figsize=(12, 5))
    sns.histplot(delta_t, bins=bins, kde=True)
    plt.xlabel('Inter-arrival Time (seconds)')
    plt.ylabel('Frequency')
    plt.title(f'Histogram of Inter-arrival Times for {operation.name.capitalize()}')
    plt.grid(alpha=0.3)

    if delta_t.nunique() == 1:
        val = delta_t.iloc[0]
        plt.xlim(val - 0.1, val + 0.1)

    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        prog='overtime',
        description='Overtime analysis',
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
    df_writes = df[df['type'] == 1].copy()

    operations: list[OperationType] = [
        OperationType(code=0, name='read'),
        OperationType(code=1, name='write'),
        OperationType(code=2, name='fsync'),
        OperationType(code=3, name='fdatasync'),
        OperationType(code=4, name='nop'),
        OperationType(code=5, name='all'),
    ]

    for operation in operations:
        output_file = f'png/{operation.name}_overtime.png'
        plot_operations_over_time(df, operation, output_file=output_file)
        print(f'Saved {operation.name} overtime to {output_file}')

        output_file = f'png/{operation.name}_interarrival.png'
        plot_interarrival_times(df, operation, output_file=output_file)
        print(f'Saved {operation.name} interarrival to {output_file}')