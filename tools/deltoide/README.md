# Deltoide

Deltoide analyses a dataset (file, directory, or block device) and produces compression and deduplication distribution profiles, the output is JSON suitable for configuring [**prismo**](../../README.md) content generators.

## Building

From the project root, Deltoide is built alongside [**prismo**](../../README.md) using Meson (requires **libzstd**).

```
meson setup builddir --buildtype=release -Dpkg_config_path=/path/to/spdk/build/lib/pkgconfig/
meson compile -C builddir deltoide
```

The binary is placed in `builddir/tools/deltoide`.

## Usage

```
# Analyse a directory for both compression and deduplication distributions
deltoide -i /mnt/dataset -b 4096 -c -d

# Analyse a block device with 8K blocks for compression distribution
deltoide -i /dev/sdb -b 8192 -c
```

### Options

| Flag                    | Description                                                       | Default       |
|-------------------------|-------------------------------------------------------------------|---------------|
| `-i`, `--input`         | File, directory, or block device to analyse                       | *(required)*  |
| `-b`, `--block-size`    | Block size in bytes                                               | `4096`        |
| `-c`, `--compression`   | Print the compression ratio distribution                          | off           |
| `-d`, `--duplication`   | Print the deduplication distribution (with per-group compression) | off           |

## Output

> [!NOTE]
> At least one of `-c` or `-d` should be specified to produce output.

### Compression (`-c`)

A JSON array of `{ reduction, percentage }` entries:

```json
[
  { "reduction": 0,  "percentage": 12 },
  { "reduction": 45, "percentage": 35 },
  { "reduction": 90, "percentage": 53 }
]
```

- **reduction** — compression ratio achieved by zstd (0% = incompressible, 100% = fully compressed away)
- **percentage** — share of blocks at that reduction level

### Deduplication (`-d`)

A JSON array of `{ repeats, percentage, compression }` entries:

```json
[
  {
    "repeats": 0,
    "percentage": 70,
    "compression": [
      { "reduction": 30, "percentage": 60 },
      { "reduction": 85, "percentage": 40 }
    ]
  },
  {
    "repeats": 3,
    "percentage": 30,
    "compression": [
      { "reduction": 95, "percentage": 100 }
    ]
  }
]
```

- **repeats** — how many additional copies of this block exist (0 = unique)
- **percentage** — share of data in this duplication group
- **compression** — compression distribution within the group