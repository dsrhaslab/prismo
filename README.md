<img width="1727" height="565" alt="prismo1" src="https://github.com/user-attachments/assets/5ff36010-987f-49ee-9621-3948897c2fed" />

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
sudo apt install -y liburing-dev libspdlog-dev libeigen3-dev nlohmann-json3-dev libboost-pool-dev
```

2. Download and install [SPDK](https://github.com/spdk/spdk)

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

3. Download and install [argparse](https://github.com/p-ranav/argparse)

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

Workloads are JSON files with five top-level sections. Fields in `job` are merged into `engine`, `access`, and `generator` as defaults, so common values (e.g. `block_size`) only need to appear once.

### `job`

```json
"job": {
  "name":       "my_workload",
  "numjobs":    1,
  "filename":   "testfile",
  "block_size": 4096,
  "limit":      268435456,
  "metric":     "full",
  "termination": { "type": "iterations", "value": 200000 }
}
```

| Field | Description |
|-------|-------------|
| `numjobs` | Number of parallel producer–consumer pairs (each writes to `filename_worker_N`) |
| `filename` | Base path of the target file |
| `block_size` | I/O block size in bytes |
| `limit` | Maximum file size in bytes |
| `metric` | `"base"` (aggregate only) or `"full"` (per-operation breakdown) |
| `termination` | `{ "type": "iterations", "value": N }` — stop after N operations; or `{ "type": "runtime", "value": Ms }` — stop after Ms milliseconds |

Optional throttling ramp:

```json
"ramp": { "start_ratio": 0.1, "end_ratio": 1.0, "duration": 5000 }
```

Linearly scales I/O throughput from `start_ratio` (10%) to `end_ratio` (100%) over `duration` milliseconds.

---

### `operation`

Controls which I/O operations are issued.

| `type` | Description | Extra fields |
|--------|-------------|--------------|
| `"constant"` | Always the same operation | `"operation": "read"\|"write"\|"nop"\|"fsync"\|"fdatasync"` |
| `"percentage"` | Probabilistic mix | `"percentages": { "read": 50, "write": 40, "fsync": 10 }` |
| `"sequence"` | Fixed repeating sequence | `"operations": ["write", "read", "write", "fsync"]` |
| `"trace"` | Replay operations from a `.prismo` trace | `"trace": "path.prismo"` + `"extension"` + `"memory"` |

**Barriers** (optional, works with `sequence`/`percentage`) — inject a sync operation after every N triggers of a specific operation:

```json
"barrier": [
  { "operation": "fsync",     "trigger": "write", "threshold": 1024 },
  { "operation": "fdatasync", "trigger": "write", "threshold": 512  }
]
```

---

### `access`

Controls which file offset each operation targets.

| `type` | Description | Extra fields |
|--------|-------------|--------------|
| `"sequential"` | Monotonically increasing offsets (wraps at `limit`) | — |
| `"random"` | Uniformly random offsets | — |
| `"zipfian"` | Zipf-distributed offsets (hot-spot skew) | `"skew": 0.8` |
| `"trace"` | Replay offsets from a `.prismo` trace | `"trace": "path.prismo"` + `"extension"` + `"memory"` |

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
"generator": {
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
