# Workload Campaign

72 workloads organized across 4 I/O engines (posix, io_uring, libaio, SPDK). Each engine runs the same 18 base workloads, enabling direct engine-to-engine comparisons.

## Base Workloads

| #     | Name                          | Description                                                       |
|-------|-------------------------------|-------------------------------------------------------------------|
<!-- workloads muito simplistas -->

| 01    | `nop_seq_const`               | Constant nop, sequential access, constant content                 |
| 02    | `read_seq_const`              | Constant read, sequential access, constant content                |
| 03    | `write_seq_const`             | Constant write, sequential access, constant content               |
| 04    | `read_random_random`          | Constant read, random access, random content                      |

<!-- oowrkloads que já exploram propriedade de localidade -->
| 05    | `rw_rand_rand`                | 50/50 R/W, random access, random content                          |
| 06    | `rw_rand_rand_multijob`       | 50/50 R/W, random access, random content, 4 parallel jobs         |
| 07    | `write_heavy_seq_rand`        | 90/10 W/R, sequential access, random content                      |
| 08    | `read_heavy_zipf_const`       | 90/10 R/W, Zipf(0.8), constant content                            |
| 09    | `rw_zipf_rand`                | 50/50 R/W, Zipf(0.8), random content                              |

<!-- tamanho de bloco diferente -->
| 10    | `write_seq_rand_large_block`  | Constant write, sequentail access, random content, 64 KiB blocks  |

<!-- com sincronização -->
| 11    | `seq_barrier_fsync`           | Sequence + fsync barrier(1024), random access, random content     |
| 12    | `seq_all_ops_random`          | All 5 op types in sequence, random access                    |
| 13    | `fdatasync_barrier_zipf`      | Sequence + fdatasync barrier(512), Zipf(0.7)                 |

<!-- # workloads de dedup e compressão-->
| 14    | `zipf_dedup`                  | Zipf(0.9) + dedup 3 tiers, compression mix                  |
| 15    | `dedup_heavy_barrier`         | High dedup(5 repeats) + dual barriers + Zipf(0.95)           |
| 16    | `multijob_dedup_barrier`      | 4 jobs + full sequence + dedup + barriers + Zipf(0.9)        |

<!-- workloads para traces -->


<!-- pedir ao fdp do codex para ajeitar os json -->


## Engine Mirrors

Each base workload is replicated to four engines with the same configuration (only the engine section differs):

| Engine   | Range  | Suffix   | Notes                    |
|----------|--------|----------|--------------------------|
| posix    | 01–18  | `_posix` | Default engine           |
| io_uring | 19–36  | `_uring` | 1:1 mirror of posix      |
| libaio   | 37–54  | `_aio`   | 1:1 mirror, `O_DIRECT`   |
| SPDK     | 55–72  | `_spdk`  | 1:1 mirror, requires bdev|