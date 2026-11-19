# Troubleshooting

In-container problems and their fixes. Host-side problems are in the
repository's `docs/troubleshooting.md`.

## OR-Tools

- `No matching distribution found for ortools`: the environment is not
  glibc-based, or its Python has no OR-Tools wheel. This image is Debian with
  CPython 3.12; do not switch the base to Alpine and do not raise Python.
- `ImportError: libgomp.so.1` (or `libatomic.so.1`, `libstdc++.so.6`): a
  runtime library is missing. The published image installs `libgomp1`,
  `libatomic1` and `libstdc++6`; a custom image needs them.
- A protobuf conflict: OR-Tools pins `protobuf<6.34`; do not add a newer
  protobuf to the same environment.
- An intermittent CP-SAT crash with `Check failed:
heuristics.fixed_search != nullptr` under OR-Tools 9.15.6755: known upstream
  (google/or-tools#5025), affects multi-worker solves, fixed only on main.
  Keep Python 3.12, reduce `num_search_workers` for exploratory runs, and
  report it to the user; do not work around it by changing the interpreter.

## Python environments

- `uv sync` recreates or updates `.venv` in the project. There is nothing to
  activate: use `uv run` or `.venv/bin/python`. Do not install into the system
  interpreter with `pip`.
- The venv or the uv cache is slow on macOS: the bind mount is the bottleneck.
  Export `UV_PROJECT_ENVIRONMENT=/home/opencode/.local/share/venv` (the cache
  is already on the state volume).
- A project requesting another Python version: `uv` downloads it on demand into
  the state volume. `uv python list` shows what is installed and available.
- `command not found: ruff` (or `mypy`, `py-spy`, ...): the baked tools live in
  `/opt/uv/bin`, user-installed ones in `$HOME/.local/bin`. `uv tool list`
  shows only the user-installed tools; `uv tool install <tool>` adds one.
