# Workload Campaign

72 workloads organized across 4 I/O engines (posix, io_uring, libaio, SPDK). Each engine runs the same 18 base workloads, enabling direct engine-to-engine comparisons.

## Base workloads (posix, 01–18)

| #  | Name                        | Description                                                  |
|----|-----------------------------|--------------------------------------------------------------|
| 01 | `nop_seq_const`             | NOP overhead baseline (sequential, constant content)         |
| 02 | `write_seq_const`           | Sequential write throughput ceiling                          |
| 03 | `rw_random_random`          | 70/30 R/W, random access, random content                    |
| 04 | `rw_zipf_random`            | 50/50 R/W, Zipf(0.8), random content                        |
| 05 | `seq_barrier_fsync`         | Sequence + fsync barrier(1024), random access                |
| 06 | `zipf_dedup`                | Zipf(0.9) + dedup 3 tiers, compression mix                  |
| 07 | `trace_all`                 | Trace-driven operation, access and content                   |
| 08 | `read_seq_const`            | Sequential read throughput ceiling                           |
| 09 | `read_random_random`        | Random read with random content                              |
| 10 | `write_heavy_seq`           | 90/10 W/R, sequential access, random content                 |
| 11 | `read_heavy_zipf`           | 90/10 R/W, Zipf(0.6), constant content                      |
| 12 | `write_seq_large_block`     | Sequential write, 64 KiB blocks (throughput)                 |
| 13 | `rw_random_multijob`        | 4 parallel jobs, balanced R/W, random access                 |
| 14 | `fdatasync_barrier_zipf`    | Sequence + fdatasync barrier(512), Zipf(0.7)                 |
| 15 | `all_ops_random`            | All 5 op types in sequence, random access                    |
| 16 | `dedup_heavy_barrier`       | High dedup(5 repeats) + dual barriers + Zipf(0.95)           |
| 17 | `runtime_mixed_random`      | Runtime-based (30s), percentage mix with fsync, 16 KiB blocks|
| 18 | `multijob_dedup_barrier`    | 4 jobs + full sequence + dedup + barriers + Zipf(0.9)        |

## Engine mirrors

Each base workload is replicated for three additional engines with the same configuration (only the engine section differs):

| Engine   | Range  | Suffix   | Notes                    |
|----------|--------|----------|--------------------------|
| posix    | 01–18  | *(none)* | Default engine           |
| io_uring | 19–36  | `_uring` | 1:1 mirror of posix      |
| libaio   | 37–54  | `_aio`   | 1:1 mirror, `O_DIRECT`   |
| SPDK     | 55–72  | `_spdk`  | 1:1 mirror, requires bdev|

## Usage

```bash
# Run all 72 workloads
./tools/scripts/run_campaign.sh

# Run only posix workloads
./tools/scripts/run_campaign.sh -e posix

# Run with 5 repetitions
./tools/scripts/run_campaign.sh -r 5

# Preview what would run (no execution)
./tools/scripts/run_campaign.sh -n

# Custom binary and output directory
./tools/scripts/run_campaign.sh -b /path/to/prismo -o /path/to/results
```

### Options

| Flag                 | Description                                     | Default                              |
|----------------------|-------------------------------------------------|--------------------------------------|
| `-b, --binary PATH`  | Path to prismo binary                           | `builddir/prismo`                    |
| `-o, --output DIR`   | Results output directory                        | `report/results/campaign_<timestamp>`|
| `-e, --engine ENGINE`| Filter by engine: `posix`, `uring`, `aio`, `spdk`, `all` | `all`                    |
| `-r, --repetitions N`| Repetitions per workload                        | `1`                                  |
| `-n, --dry-run`      | List workloads without executing                |                                      |
| `-h, --help`         | Show help                                       |                                      |

### Outputs

- `<name>.raw.log` — full execution output per workload
- `<name>.report.json` — extracted JSON report per workload
- `summary.csv` — aggregated metrics table

## Suggested article methodology

- Run each workload with at least 5 repetitions (`-r 5`).
- Report median and interquartile range for:
  - overall IOPS
  - overall bandwidth
  - weighted average latency
  - weighted p99 latency
- Keep hardware/software setup fixed across all runs.
- Compare engines using the 1:1 mirror workloads.

## Suggested factors for extended experiments

- `numjobs`: 1, 2, 4, 8
- `block_size`: 4 KiB, 16 KiB, 64 KiB
- `operation.percentages`: read-heavy, balanced, write-heavy
- `access.skew` for Zipf: 0.6, 0.8, 0.95
- Dedup distributions (higher/lower repeats)
