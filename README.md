<img width="6908" height="2260" alt="prismo2" src="https://github.com/user-attachments/assets/baa77419-e6d5-4e91-b521-f48a4787cec4" />

Prismo is a configurable block-based I/O benchmark tool designed to stress-test storage systems. Each workload is specified in a JSON file and drives a producer–consumer pipeline of I/O packets against a target file. Operations, access patterns, block content, and engine are all independently configurable, enabling reproducible experiments across synthetic and trace-driven workloads.

## Toolchain

| Tool                                      | Description                                                                                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| [**Astroide**](tools/astroide/README.md)  | Converts `.blkparse` block traces into the compact binary `.prismo` format used by trace-driven generators                       |
| [**Deltoide**](tools/deltoide/README.md)  | Analyses a dataset or device and emits compression/deduplication distribution profiles, ready to paste into a workload config    |
| [**Cardoide**](tools/cardoide/README.md)  | Campaign runner, simplifies the execution of multiple workloads by allowing repeated runs and providing configurable filters     |

## Prerequisites

1. Install dependencies

```sh
sudo apt update
sudo apt install -y meson ninja-build
sudo apt install -y liburing-dev libspdlog-dev libeigen3-dev nlohmann-json3-dev libboost-all-dev libzstd-dev
```

2. Download and install [**SPDK**](https://github.com/spdk/spdk)

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

3. Download and install [**argparse**](https://github.com/p-ranav/argparse)

```sh
# Clone the repository
git clone https://github.com/p-ranav/argparse
cd argparse

# Build the tests
mkdir build
cd build
cmake -DARGPARSE_BUILD_SAMPLES=on -DARGPARSE_BUILD_TESTS=on ..
make

# Run tests
./test/tests

# Install the library
sudo make install
```

## Building

> [!IMPORTANT]
> To build this project, the Meson Build System must be able to locate a compatible C++ compiler on your system. When using GCC, the required version is 13.4 or newer.

Before compiling, Meson needs to know where to find the [**SPDK**](https://github.com/spdk/spdk) libraries. Update the `spdk_root` variable in [meson.build](meson.build) so it points to the SPDK repository path you installed earlier.

```sh
meson setup builddir --buildtype=release -Dpkg_config_path=/path/to/spdk/build/lib/pkgconfig/
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
  "limit": 268435456,
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
| `filename`    | Base path of the target file                                                | *(required)*  |
| `block_size`  | I/O block size in bytes                                                     | *(required)*  |
| `limit`       | Maximum file size in bytes                                                  | *(required)*  |
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

The `ramp` parameter linearly increases or decreases throughput based on `start_ratio` and `end_ratio`. Throughput begins at `start_ratio` and reaches `end_ratio` after `duration` milliseconds. When `start_ratio < end_ratio`, a speed-up is simulated; otherwise, a slow-down occurs.

```json
"ramp": {
  "start_ratio": 0.1,
  "end_ratio": 1.0,
  "duration": 5000
}
```

> [!NOTE]
> This parameter is optional. When not specified, the benchmark runs at maximum throughput for the entire execution duration.

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

Controls which file offset each operation targets. Offsets are bounded by the `limit` parameter defined in [**Job**](#job). The available access generators are intentionally simple, but they still model useful behaviors such as hot spots, cache-friendly locality, and production-style trace replay.

```json
"access": {
  "type": "zipfian",
  "skew": 0.8
}
```

| Type          | Description                                   | Example                                                                                   |
|---------------|-----------------------------------------------|-------------------------------------------------------------------------------------------|
| `sequential`  | Monotonically increasing offsets              | [**01_nop_seq_const_posix.json**](/workloads/campaign/01_nop_seq_const_posix.json)        |
| `random`      | Uniformly random offsets                      | [**03_rw_random_random_posix.json**](/workloads/campaign/03_rw_random_random_posix.json)  |
| `zipfian`     | Zipf-distributed offsets (hot-spot skew)      | [**04_rw_zipf_random_posix.json**](/workloads/campaign/04_rw_zipf_random_posix.json)      |
| `trace`       | Replay offsets from a `.prismo` trace         | [**07_trace_all_posix.json**](workloads/campaign/07_trace_all_posix.json)                 |

---

### `generator`

Controls the content of write buffers.

| `type` | Description | Extra fields |
|--------|-------------|--------------|
| `"constant"` | Zero-filled buffer | — |
| `"random"` | Random bytes | `"refill": true\|false` (refill each block or reuse) |
| `"dedup"` | Deduplication + compression profile | see below |
| `"trace"` | Replay block content from a `.prismo` trace | `"trace": "path.prismo"` + `"extension"` + `"memory"` |

**Dedup content generator** — specify a distribution of duplication groups, each with its own compression profile:

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

`repeats` is the number of duplicate copies (0 = unique). Use [Deltoide](tools/deltoide/README.md) to derive these distributions from a real dataset.

**Trace extension** (for all `"trace"` types) — controls how the trace is replayed when it ends:

| `extension` | Description |
|-------------|-------------|
| `"repeat"` | Restart from the beginning |
| `"sample"` | Randomly sample from the recorded values |
| `"regression"` | Extrapolate via linear regression |

```json
"extension": "sample",
"memory": 16384
```

`memory` is the number of trace records to keep in memory for sampling/regression.

---

### `engine`

Selects the I/O backend.

**posix**
```json
"engine": { "type": "posix", "open_flags": ["O_CREAT", "O_RDWR"] }
```

**io_uring**
```json
"engine": {
  "type": "uring",
  "open_flags": ["O_CREAT", "O_RDWR"],
  "entries": 128,
  "params": {
    "cq_entries": 256,
    "sq_thread_cpu": 0,
    "sq_thread_idle": 0,
    "flags": []
  }
}
```

**libaio** (requires `O_DIRECT`)
```json
"engine": {
  "type": "aio",
  "open_flags": ["O_CREAT", "O_RDWR", "O_DIRECT"],
  "entries": 128
}
```

**SPDK** (requires a configured bdev)
```json
"engine": {
  "type": "spdk",
  "open_flags": [],
  "bdev_name": "Malloc0",
  "reactor_mask": "0x3",
  "json_config_file": "/path/to/bdev.json",
  "spdk_threads": 2
}
```

Supported `open_flags`: `O_CREAT`, `O_TRUNC`, `O_RDONLY`, `O_WRONLY`, `O_RDWR`, `O_SYNC`, `O_DSYNC`, `O_DIRECT`, `O_APPEND`.

---

## Report format

The JSON report contains one entry per job plus an `"all"` aggregate (when `numjobs > 1`):

```json
{
  "jobs": [
    {
      "job_id": 0,
      "total_operations": 200000,
      "total_bytes": 819200000,
      "runtime_sec": 1.23456,
      "overall_iops": 162000,
      "overall_bandwidth_bytes_per_sec": 6.64e8,
      "operations": [
        {
          "operation": "write",
          "total_ops": 100000,
          "total_bytes": 409600000,
          "iops": 81000,
          "bandwidth_bytes_per_sec": 3.32e8,
          "latency_ns": {
            "min": 1200, "avg": 6100, "max": 980000,
            "p50": 5800, "p95": 12000, "p99": 45000, "p999": 210000
          }
        }
      ]
    }
  ]
}
```
