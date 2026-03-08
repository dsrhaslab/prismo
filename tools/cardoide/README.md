# Cardoide

Campaign orchestrator for [prismo](../../README.md) workloads, discovers workload JSON files, filters them by engine and numeric range, executes each workload for a configurable number of repetitions, stores reports in a timestamped results folder, and prints a concise execution view in the terminal.

> [!TIP]
> Use it when you want to run many workloads consistently without manually invoking `prismo` one file at a time.

## Build

```sh
cargo build --release
```

## Usage

```
cardoide [OPTIONS]
```

### Options

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--prismo` | `-p` | `../../builddir/prismo` | Path to the prismo binary |
| `--workloads-dir` | `-d` | `../../workloads/campaign` | Directory containing workload `.json` files |
| `--output-dir` | `-o` | `../../workloads/results` | Base directory for results |
| `--engine` | `-e` | `all` | Filter by engine: `posix`, `uring`, `aio`, `spdk`, or `all` |
| `--workload-from` | | `0` | Run workloads starting from this number (inclusive) |
| `--workload-to` | | `max` | Run workloads up to this number (inclusive) |
| `--repetitions` | `-r` | `1` | Number of times each workload is repeated |

### Examples

Run all workloads once:
```sh
cardoide
```

Run only `io_uring` workloads, 3 times each:
```sh
cardoide --engine uring --repetitions 3
```

Run workloads 5 through 10 with a custom binary:
```sh
cardoide --prismo ./builddir/prismo --workload-from 5 --workload-to 10
```

## Results

Each run writes a `.report.json` file to a timestamped subdirectory.

```
results/campaign_20260308_171126/
  01_nop_seq_const_rep1.report.json
  01_nop_seq_const_rep2.report.json
  ...
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
