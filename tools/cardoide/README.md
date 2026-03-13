# Cardoide

Campaign orchestrator for [**Prismo**](../../README.md) workloads, discovers workload JSON files, filters them by engine and numeric range, executes each workload for a configurable number of repetitions, stores reports in a timestamped results folder, and prints a concise execution view in the terminal.

> [!TIP]
> Use it when you want to run many workloads consistently without manually invoking `prismo` one file at a time.

## Build

```sh
cargo build --release
```

## Usage

```sh
# Run all workloads once:
cardoide

# Run only `io_uring` workloads, 3 times each:
cardoide --engine uring --repetitions 3

# Run workloads 5 through 10 with a custom binary:
cardoide --prismo ./builddir/prismo --workload-from 5 --workload-to 10
```

### Options

| Flag                    | Description                                                 | Default                     |
|------------------------ |-------------------------------------------------------------|-----------------------------|
| `-p`, `--prismo`        | Path to the prismo binary                                   | `../../builddir/prismo`     |
| `-d`, `--workloads-dir` | Directory containing workload `.json` files                 | `../../workloads/campaign`  |
| `-o`, `--output-dir`    | Base directory for results                                  | `../../workloads/results`   |
| `-e`, `--engine`        | Filter by engine: `posix`, `uring`, `aio`, `spdk`, or `all` | `all`                       |
| `-r`, `--repetitions`   | Number of times each workload is repeated                   | `1`                         |
| `--workload-from`       | Run workloads starting from this number (inclusive)         | `0`                         |
| `--workload-to`         | Run workloads up to this number (inclusive)                 | `inf`                       |

## Results

Each run writes a `.report.json` file to a timestamped subdirectory.

```
results/
└── campaign_20260308_171126/
    ├── 01_nop_seq_const_rep1.report.json
    ├── 01_nop_seq_const_rep2.report.json
    └── ...
```

## Workload discovery

Cardoide scans `--workloads-dir` for `.json` files. Each file is expected to be a prismo workload configuration. Files are sorted and optionally filtered by engine suffix and number prefix.

> [!IMPORTANT]
> Workload names must follow the format `num_something_engine`, bearing in mind that `num` must be padded with leading zeros to preserve order.

Engine is inferred from the filename:
- `*_posix.json` → `posix`
- `*_uring.json` → `uring`
- `*_aio.json` → `aio`
- `*_spdk.json` → `spdk`
