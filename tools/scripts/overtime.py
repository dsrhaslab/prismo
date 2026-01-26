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
    linestyle: str
    marker: str


def plot_operations_overtime(
    df: pd.DataFrame,
    operations: list['OperationType'],
    time_window: str = '1s',
    output_file: str = 'png/operations_overtime.png'
) -> None:
    df = df.copy()
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df = df.sort_values('timestamp')

    plt.figure(figsize=(14, 6))

    for operation in operations:
        df_op = df[df['type'] == operation.code]
        ops_per_window = df_op.set_index('timestamp').resample(time_window).size()

        plt.plot(
            ops_per_window.index,
            ops_per_window.values,
            linewidth=1.5,
            marker=operation.marker,
            linestyle=operation.linestyle,
            label=operation.name
        )

    plt.xlabel('Time')
    plt.ylabel('Number of Operations')
    plt.title(f'Operations Over Time (Window: {time_window})')
    plt.grid(alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()


def plot_interarrival_overtime(
    df: pd.DataFrame,
    operations: list['OperationType'],
    time_window: str = '1s',
    output_file: str = 'png/interarrival_overtime.png',
) -> None:
    df = df.copy()
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df = df.sort_values('timestamp')

    plt.figure(figsize=(14, 6))

    for operation in operations:
        df_op = df[df['type'] == operation.code]
        delta_t = df_op['sts'].diff().dropna()
        df_op = df_op.iloc[1:].copy()
        df_op['delta_t'] = delta_t

        avg_delta_t = df_op.set_index('timestamp').resample(time_window)['delta_t'].mean()

        plt.plot(
            avg_delta_t.index,
            avg_delta_t.values,
            linewidth=2,
            alpha=0.8,
            marker=operation.marker,
            linestyle=operation.linestyle,
            label=operation.name
        )

    plt.xlabel('Time')
    plt.ylabel(f'Average Inter-arrival Time (ns)')
    plt.title(f'Average Inter-arrival Time Over Time by Operation (Window: {time_window})')
    plt.grid(alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()


def plot_latency_overtime(
    df: pd.DataFrame,
    operations: list[OperationType],
    time_window: str = '1s',
    output_file: str = 'png/latency_over_time.png'
) -> None:
    df = df.copy()
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['latency'] = df['ets'] - df['sts']
    df = df.sort_values('timestamp')

    plt.figure(figsize=(14, 6))

    for operation in operations:
        df_op = df[df['type'] == operation.code]

        avg_latency = (
            df_op
            .set_index('timestamp')['latency']
            .resample(time_window)
            .mean()
        )

        plt.plot(
            avg_latency.index,
            avg_latency.values,
            linewidth=2,
            marker=operation.marker,
            linestyle=operation.linestyle,
            label=operation.name
        )

    avg_all = (
        df
        .set_index('timestamp')['latency']
        .resample(time_window)
        .mean()
    )

    plt.plot(
        avg_all.index,
        avg_all.values,
        color='black',
        linestyle='--',
        linewidth=2,
        label=f'all ops avg'
    )

    plt.xlabel('Time')
    plt.ylabel('Latency (ns)')
    plt.title(f'Latency Over Time by Operation ({time_window} avg)')
    plt.grid(alpha=0.3)
    plt.legend()
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
        OperationType(code=0, name='read', linestyle='-', marker='v'),
        OperationType(code=1, name='write', linestyle='--', marker='h'),
        OperationType(code=2, name='fsync', linestyle=':', marker='s'),
        OperationType(code=3, name='fdatasync', linestyle='-.', marker='+'),
        OperationType(code=4, name='nop', linestyle='dotted', marker='>'),
    ]

    output_file = 'png/latency_overtime.png'
    plot_latency_overtime(df, operations, output_file=output_file)
    print(f'Saved latency overtime to {output_file}')

    output_file = 'png/interarrival_overtime.png'
    plot_interarrival_overtime(df, operations, output_file=output_file)
    print(f'Saved interarrival overtime to {output_file}')

    output_file = 'png/operations_overtime.png'
    plot_operations_overtime(df, operations, output_file=output_file)
    print(f'Saved operations overtime to {output_file}')