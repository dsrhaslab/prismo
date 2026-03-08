# Astroide

Astroide converts `.blkparse` trace files into [prismo](../../README.md) compact binary trace format (`.prismo`).

## Building

From the project root, Astroide is built alongside [prismo](../../README.md) via Meson.

```
meson setup builddir --buildtype=release -Dpkg_config_path=/path/to/spdk/build/lib/pkgconfig/
meson compile -C builddir astroide
```

The binary is placed in `builddir/tools/astroide`.

## Usage

```
# Parse `homes.blkparse` into `homes.prismo` with a block size of 512 bytes
astroide -i traces/homes.blkparse -o traces/homes.prismo -b 512
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-i`, `--input` | Path to the `.blkparse` input file | *(required)* |
| `-o`, `--output` | Path to the output binary file | *(required)* |
| `-b`, `--block-size` | Block size in bytes used to scale offsets and sizes | `512` |

## Input format

Each line of the `.blkparse` file must contain the following whitespace-separated fields:

```
<timestamp> <pid> <process> <offset> <size> <operation> <major> <minor> <block_id>
```

Lines that are empty or fail to parse are skipped with a warning on stderr.

## Output format

The output is a sequence of `Trace::Record` structs written as raw binary:

```c
struct Record {
    uint64_t timestamp;
    uint32_t pid;
    uint64_t process;    // komihash of process name
    uint64_t offset;     // scaled by block_size
    uint32_t size;       // scaled by block_size
    uint32_t major;
    uint32_t minor;
    uint64_t block_id;`  // komihash of block
    OperationType operation;
};
```