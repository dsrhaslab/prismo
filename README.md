<img width="6908" height="2260" alt="prismo2" src="https://github.com/user-attachments/assets/baa77419-e6d5-4e91-b521-f48a4787cec4" />

Prismo is a configurable block-based I/O benchmark tool designed to stress-test storage systems. Each workload is specified in a JSON file and drives a producer–consumer pipeline of I/O packets against a target file. Operations, access patterns, block content, and backend engine are all independently configurable, enabling reproducible experiments across synthetic and trace-driven workloads.

## Toolchain

| Tool                                      | Description                                                                                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| [**Astroide**](tools/astroide/README.md)  | Converts `.blkparse` block traces into the compact binary `.prismo` format used by trace-driven generators                       |
| [**Deltoide**](tools/deltoide/README.md)  | Analyses a dataset and emits compression/deduplication distribution profiles, ready to paste into a workload config              |
| [**Cardoide**](tools/cardoide/README.md)  | Campaign runner, simplifies the execution of multiple workloads by allowing repeated runs and providing configurable filters     |

## Prerequisites

1. Install build tools and system dependencies

```sh
sudo apt update
sudo apt install -y meson ninja-build libaio-dev
```

2. Install [**vcpkg**](https://github.com/microsoft/vcpkg) and the required libraries

```sh
# Clone and bootstrap vcpkg
git clone https://github.com/microsoft/vcpkg
./vcpkg/bootstrap-vcpkg.sh

# Install dependencies
./vcpkg/vcpkg install liburing spdlog eigen3 argparse nlohmann-json boost-pool zstd
```

3. Download and install [**SPDK**](https://github.com/spdk/spdk)

```sh
# Clone the repository
git clone https://github.com/spdk/spdk
cd spdk
git submodule update --init

# Install dependencies
./scripts/pkgdep.sh

# Build
./configure --enable-asan
make

# Run tests
./test/unit/unittest.sh
```

## Building

> [!IMPORTANT]
> To build this project, the Meson Build System must be able to locate a compatible C++ compiler on your system. When using GCC, the required version is 13.4 or newer.

Before compiling, update the paths in [**build.ini**](build.ini) so `spdk_root` and `vcpkg_root` point to the correct locations on your system.

```sh
meson setup builddir --native-file build.ini
meson compile -C builddir
```

The binary is placed at `builddir/prismo`. The tools (`astroide`, `deltoide`) are built alongside it. For convenience, the program can also be installed system-wide, allowing you to run it from any location without specifying the full path.

```sh
meson install -C builddir
```

## Usage

```sh
# Run workload, print report to stdout
prismo -c workload.json

# Write report to file
prismo -c workload.json -o report.json

# Enable debug logging
prismo -c workload.json -l
```

### Options

| Flag              | Description                       | Default       |
|-------------------|-----------------------------------|---------------|
| `-c`, `--config`  | Path to the workload JSON file    | *(required)*  |
| `-o`, `--output`  | Write JSON report to this file    | stdout (`-`)  |
| `-l`, `--logging` | Enable debug logging              | off           |

## Configuration

Workloads are defined using a JSON file divided into six independent sections. Each section can be freely combined, enabling the creation of purely synthetic workloads, trace-driven workloads, or hybrids.

### Job

```json
"job": {
  "name": "my_workload",
  "numjobs": 1,
  "filename": "testfile",
  "block_size": 4096,
  "size": 268435456,
  "metric": "full",
  "termination": {
    "type": "iterations",
    "value": 200000
  }
}
```

| Field         | Description                                                                 | Default       |
|---------------|-----------------------------------------------------------------------------|---------------|
| `name`        | Workload name                                                               | *(required)*  |
| `numjobs`     | Number of parallel producer-consumer pairs                                  | *(required)*  |
| `filename`    | Path of the target file                                                     | *(required)*  |
| `block_size`  | I/O block size in bytes                                                     | *(required)*  |
| `size`       | Maximum file size in bytes                                                  | *(required)*  |
| `metric`      | Granularity of metric collection                                            | *(required)*  |
| `termination` | Termination condition: stop after N operations or after M milliseconds      | *(required)*  |
| `ramp`        | Linear increase or decrease of throughput                                   | *(optional)*  |

The `metric` parameter accepts values `none | base | standard | full`, progressively collecting more metrics and consequently reducing performance. For maximum performance, disable metric collection by selecting `none`.

The `termination` condition can be expressed in two ways: one limits the number of operations to N, while the other limits execution time to M milliseconds.

```json
"termination": {
  "type": "iterations",
  "value": 2e6
}
```

```json
"termination": {
  "type": "runtime",
  "value": 30000
}
```

The `ramp` parameter linearly increases or decreases throughput based on `start_ratio` and `end_ratio`. Throughput begins at `start_ratio` and reaches `end_ratio` after `duration` milliseconds. When `start_ratio < end_ratio`, a speed-up is simulated, otherwise a slow-down occurs.

```json
"ramp": {
  "start_ratio": 0.1,
  "end_ratio": 1.0,
  "duration": 5000
}
```

> [!NOTE]
> This parameter is optional. When not specified, the benchmark runs at maximum throughput for the entire execution.

---

### Operation

Controls which I/O operations are issued by the benchmark. There are currently four operation generators, and they accept `read | write | fsync | fdatasync | nop` in their configurations. In the example below, the benchmark continuously issues `write`, but it could issue any of the listed operations.

```json
"operation": {
  "type": "constant",
  "operation": "write"
}
```

| Type          | Description                                     | Example                                                                                   |
|---------------|-------------------------------------------------|-------------------------------------------------------------------------------------------|
| `constant`    | Repeatedly issues the same `operation`          | [**01_nop_seq_const_posix.json**](/workloads/campaign/01_nop_seq_const_posix.json)        |
| `percentage`  | Operations sampled from a discrete distribution | [**03_rw_random_random_posix.json**](/workloads/campaign/03_rw_random_random_posix.json)  |
| `sequence`    | Repeats a fixed operation pattern               | [**06_zipf_dedup_posix.json**](/workloads/campaign/06_zipf_dedup_posix.json)              |
| `trace`       | Replay operations from a `.prismo` trace        | [**07_trace_all_posix.json**](/workloads/campaign/07_trace_all_posix.json)                |

> [!NOTE]
> Each generator has its own specific configuration. Reviewing the examples is recommended to better understand how they work.

In some workloads, it is useful to force buffered data to be flushed. Barriers provide this behavior by issuing one operation after another operation has been triggered N times. In the example below, an `fsync` is issued every 1024 `write` operations, and an `fdatasync` every 512.

```json
"barrier": [
  {
    "operation": "fsync",
    "trigger": "write",
    "threshold": 1024
  },
  {
    "operation": "fdatasync",
    "trigger": "write",
    "threshold": 512
  }
]
```

---

### Access

Controls which file offset each operation targets. Offsets are bounded by the `limit` parameter defined in [**job**](#job). The available access generators are intentionally simple, but they still model useful behaviors such as hot spots, cache-friendly locality, and production-style trace replay.

```json
"access": {
  "type": "zipfian",
  "skew": 0.8
}
```

| Type          | Description                                     | Example                                                                                   |
|---------------|-------------------------------------------------|-------------------------------------------------------------------------------------------|
| `sequential`  | Monotonically increasing offsets                | [**01_nop_seq_const_posix.json**](/workloads/campaign/01_nop_seq_const_posix.json)        |
| `random`      | Uniformly random offsets                        | [**03_rw_random_random_posix.json**](/workloads/campaign/03_rw_random_random_posix.json)  |
| `zipfian`     | Zipf-distributed offsets (hot-spot skew)        | [**04_rw_zipf_random_posix.json**](/workloads/campaign/04_rw_zipf_random_posix.json)      |
| `trace`       | Replay offsets from a `.prismo` trace           | [**07_trace_all_posix.json**](workloads/campaign/07_trace_all_posix.json)                 |

---

### Content

Defines the contents of the buffers used by `write` operations. If a workload does not issue writes, the content generator is never invoked, which can improve the benchmark's operation rate.

```json
"content": {
  "type": "random",
  "refill": true
},
```

| Type        | Description                                       | Example                                                                                         |
|-------------|---------------------------------------------------|-------------------------------------------------------------------------------------------------|
| `constant`  | Zero-filled buffer                                | [**01_nop_seq_const_posix.json**](/workloads/campaign/01_nop_seq_const_posix.json)              |
| `random`    | Random bytes                                      | [**04_rw_zipf_random_posix.json**](/workloads/campaign/04_rw_zipf_random_posix.json)            |
| `dedup`     | Deduplication and compression profile             | [**16_dedup_heavy_barrier_posix.json**](/workloads/campaign/16_dedup_heavy_barrier_posix.json)  |
| `trace`     | Replay block content from a `.prismo` trace       | [**07_trace_all_posix.json**](/workloads/campaign/07_trace_all_posix.json)                      |

With the exception of `constant`, all content generators use the `refill` field. It controls whether buffers are regenerated from scratch or reuse the same base buffer. For `random`, when `refill == true`, the entire buffer is rewritten with random bytes, otherwise only the buffer header changes, which allows higher throughput.

The properties of generated content are important when evaluating systems, especially those that implement compression and deduplication optimizations. For this reason, generators can optionally include a compression profile that applies different reduction ratios according to a distribution. In the example below, half of the content remains uncompressed, while the other half is compressed by 50%.

```json
"compression": [
  { "percentage": 50, "reduction": 0  },
  { "percentage": 50, "reduction": 50 }
]
```

For the `dedup` generator, you must define a discrete distribution of duplicate groups that determines how many times blocks repeat. In the example below, half of the written blocks are unique (`repeats = 0`), while the remaining half have three duplicates each. In addition, each `repeats` group can define its own compression profile.

> [!TIP]
> Use [**Deltoide**](tools/deltoide/README.md) to derive these distributions from a real dataset.

```json
"content": {
  "type": "dedup",
  "refill": false,
  "distribution": [
    {
      "percentage": 50,
      "repeats": 0,
      "compression": [
        { "percentage": 50, "reduction": 0  },
        { "percentage": 50, "reduction": 50 }
      ]
    },
    {
      "percentage": 50,
      "repeats": 3,
      "compression": [
        { "percentage": 100, "reduction": 80 }
      ]
    }
  ]
}
```

> [!CAUTION]
> Do not combine the top-level compressor with the `dedup` generator, otherwise the compression settings defined for each `repeats` group will be overwritten.

----

### Trace Extension

Controls how a trace is extended after it reaches the end. The goal is to continue generating operations indefinitely while preserving the statistical properties observed in the original data, allowing production-like conditions to be reproduced synthetically.

```json
"extension": "sample",
"memory": 16384
```

While reading the `.prismo` binary file, records are buffered to improve deserialization performance. The `memory` field defines how many bytes are reserved for this buffering step.

| Extension     | Description                                               |
|---------------|-----------------------------------------------------------|
| `repeat`      | Restart from the beginning                                |
| `sample`      | Samples records according to their observed distribution  |
| `regression`  | Extrapolate via multivariate regression                   |

> [!NOTE]
> Trace-based generation is available in [**operation**](#operation), [**access**](#access), and [**content**](#content) generators. This makes hybrid workloads possible, where one generator can replay traces while the others produce synthetic data.

---

### Engine

Defines the backend engine responsible for executing I/O requests. Both synchronous and asynchronous implementations are available. In general, asynchronous engines with polling are recommended for higher throughput because they avoid interruption overhead from blocking system calls.

```json
"engine": {
  "type": "posix",
  "open_flags": ["O_CREAT", "O_RDWR"]
}
```

| Type    | Description                                                                                                 | Example                                                                             |
|---------|-------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| `posix` | Synchronous I/O using the standard POSIX API                                                                | [**01_nop_seq_const_posix.json**](/workloads/campaign/01_nop_seq_const_posix.json)  |
| `uring` | Asynchronous I/O using the Linux [**io_uring**](https://man7.org/linux/man-pages/man7/io_uring.7.html) API  | [**19_nop_seq_const_uring.json**](/workloads/campaign/19_nop_seq_const_uring.json)  |
| `aio`   | POSIX asynchronous I/O using the [**AIO**](https://man7.org/linux/man-pages/man7/aio.7.html) interface      | [**37_nop_seq_const_aio.json**](/workloads/campaign/37_nop_seq_const_aio.json)      |
| `spdk`  | High-performance user-space storage I/O via [**SPDK**](https://github.com/spdk/spdk)                        | [**55_nop_seq_const_spdk.json**](/workloads/campaign/55_nop_seq_const_spdk.json)    |

The `posix`, `uring`, and `aio` engines open the files on which I/O operations are performed, while the `open_flags` field specifies the flags passed to [`open(2)`](https://man7.org/linux/man-pages/man2/open.2.html). The following flags are supported:

```sh
# Core access modes (choose exactly one)
O_RDONLY | O_WRONLY | O_RDWR

# Common write behavior flags
O_APPEND | O_TRUNC | O_CREAT

# Strong consistency / performance flags
O_SYNC | O_DSYNC | O_RSYNC | O_DIRECT
```

> [!WARNING]
> The `aio` interface requires `O_DIRECT` in `open_flags`, because asynchronous behavior is fully effective only with direct I/O.

The `uring` interface supports several configuration flags defined by [`io_uring_setup(2)`](https://man7.org/linux/man-pages/man2/io_uring_setup.2.html). The following subset is currently available:

```sh
# Polling modes
IORING_SETUP_IOPOLL | IORING_SETUP_SQPOLL | IORING_SETUP_HYBRID_IOPOLL

# Thread and CPU control
IORING_SETUP_SQ_AFF | IORING_SETUP_SINGLE_ISSUER

# Queue tuning
IORING_SETUP_CQSIZE | IORING_SETUP_CLAMP

# Safety / semantic guarantees
IORING_FEAT_NODROP
```

> [!WARNING]
> The `IORING_SETUP_SINGLE_ISSUER` flag is available only from Linux kernel `6.0` onward. If this flag is enabled (not commented out in the code), builds targeting older kernels may fail. Upgrading the kernel is recommended.

The `spdk` engine uses the [**bdev**](https://spdk.io/doc/bdev.html) interface, so the target must be a block device. Its configuration is provided through the `json_config_file` parameter, which points to a JSON file containing the bdev configuration. Examples are available in [**spdk**](/workloads/spdk/).

> [!WARNING]
> `reactor_mask` should select at least two CPU cores. Otherwise, request execution may stall, as a single worker thread could remain busy polling and monopolize the only available core.

---

### Logger

The logger captures benchmark activity and writes detailed execution records. These logs are stored in a structured format, which can then be analyzed with the scripts inside [**tools**](/tools/scripts/) to generate plots and run statistical analysis.

Logging detail follows the `metric` level selected in [**job**](#job). As you move from `none` to `full`, records include progressively richer information.

```json
"logger": {
  "type": "spdlog",
  "name": "prismo",
  "queue_size": 8192,
  "thread_count": 1,
  "truncate": true,
  "to_stdout": true,
  "files": [
    "./log1.log",
    "./log2.log",
    "./log3.log"
  ]
}
```

> [!NOTE]
> This component is optional. If your primary goal is maximum throughput, disable logging because it adds measurable overhead.

## Report

The JSON report provides a detailed benchmark summary, with one entry per job and an `all` aggregate when multiple jobs run (`numjobs > 1`). When metric collection is enabled, each job entry includes overall statistics such as total operations, total bytes transferred, runtime, IOPS, and bandwidth, plus per-operation metrics.

```json
{
  "jobs": [
    {
      "job_id": 0,
      "operations": [
        {
          "bandwidth_bytes_per_sec": 1826388175.56,
          "count": 1000000,
          "iops": 445895.55,
          "latency_ns": {
            "avg": 2165,
            "max": 95973,
            "min": 1899
          },
          "operation": "write",
          "percentiles_ns": {
            "p50": 2048,
            "p90": 2048,
            "p95": 2048,
            "p99": 2048,
            "p99_9": 4096,
            "p99_99": 8192
          },
          "total_bytes": 4096000000
        }
      ],
      "overall_bandwidth_bytes_per_sec": 1826388175.56,
      "overall_iops": 445895.55,
      "runtime_sec": 2.24268,
      "total_bytes": 4096000000,
      "total_operations": 1000000
    }
  ]
}
```

## Contributing

Currently there are only a few implementations of the top-level configuration components, which limits the range of workload properties that can be expressed. Adding more generators for [**operation**](#operation), [**access**](#access), [**content**](#content), [**engines**](#engine), and [**extensions**](#trace-extension) would be a valuable contribution.

1. Implement the abstract base class for the desired component.

2. Define a JSON configuration and accept it in the class constructor.

3. Register the constructor in the component's parsing function, found in [**factory.cpp**](/src/factory/factory.cpp).

> [!IMPORTANT]
> [**Logger**](#logger) implementations must be thread-safe, because engines may share the same logger instance.

Any other contributions are also welcome :smiling_face_with_three_hearts:.