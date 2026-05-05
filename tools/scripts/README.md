# Prismo Scripts (uv)

This directory uses [uv](https://docs.astral.sh/uv/) for dependency management and script execution.

## Setup

From this directory:

```sh
uv sync
```

## Run scripts

```sh
uv run dedup.py -i /path/to/prismo.log
uv run distribution.py -i /path/to/prismo.log -b 20
uv run overtime.py -i /path/to/prismo.log
```

Generated plots are written to `assets/` by default.
