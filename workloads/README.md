# Workload Campaign

60 workloads organized across 4 I/O engines (posix, io_uring, libaio, SPDK). Each engine runs the same 15 base workloads, enabling direct engine-to-engine comparisons.

## Design Rationale

Each workload isolates **exactly one dimension** relative to the previous, making results easy to compare and discuss. The set covers: sequential vs random access, read vs write paths, mixed ratios, access locality, block size, durability barriers, parallelism, data reduction, hybrid trace/synthetic generation, and full trace replay.

## Base Workloads

| #  | Name                     | Dimension Isolated                        | Key Parameters                                                    |
|----|--------------------------|-------------------------------------------|-------------------------------------------------------------------|
| 01 | `seq_write`              | Baseline sequential throughput            | Write, sequential, constant                                       |
| 02 | `seq_read`               | Read path vs write (W01)                  | Read, sequential, constant                                        |
| 03 | `seq_write_large_block`  | Block size + bandwidth ceiling            | Write, sequential, 64 KiB                                         |
| 04 | `rand_read`              | Random access (IOPS)                      | Read, random, random content                                      |
| 05 | `rw_rand_mixed`          | Mixed R/W contention                      | 50/50 R/W, random, random content                                 |
| 06 | `rw_zipf`                | Access locality (Zipfian)                 | 50/50 R/W, Zipf(0.9), random content                              |
| 07 | `write_heavy_seq`        | Asymmetric ratio                          | 90/10 W/R, sequential, random content                             |
| 08 | `barrier_fsync`          | Durability overhead                       | Sequence W/R/W/W + fsync every 1024 writes                        |
| 09 | `rw_rand_multijob`       | Parallelism (3 jobs)                      | 50/50 R/W, random, 3 jobs                                         |
| 10 | `compress_zipf`          | Compression only (no dedup)               | Sequence R/W/nop/W, Zipf(0.9), 3-tier compress (0/50/75%)         |
| 11 | `dedup_zipf`             | Dedup + compression (full reduction)      | Sequence R/W/nop/W, Zipf(0.9), 3-tier dedup+compress              |
| 12 | `hybrid_trace_access`    | Real access locality + synthetic ops      | 70/30 R/W synthetic, trace access (homes), random content         |
| 13 | `hybrid_trace_ops`       | Real operation mix + synthetic access     | Trace ops (cheetah), Zipf(0.9) access, random content             |
| 14 | `trace_homes`            | Full trace - fileserver workload          | Trace ops/access/content (homes), repeat extension                |
| 15 | `trace_webmail`          | Full trace - webmail workload             | Trace ops/access/content (webmail), sample+regression extension   |

## Engine Mirrors

Each base workload is replicated to four engines with the same configuration (only the engine section differs):

| Engine    | Range     | Suffix    | Notes                      |
|-----------|-----------|-----------|----------------------------|
| posix     | 01–15     | `_posix`  | Default engine             |
| io_uring  | 16–30     | `_uring`  | 1:1 mirror of posix        |
| libaio    | 31–45     | `_aio`    | 1:1 mirror, `O_DIRECT`     |
| SPDK      | 46–60     | `_spdk`   | 1:1 mirror, requires bdev  |