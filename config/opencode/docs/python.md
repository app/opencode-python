# Python

## Interpreter

The image is built on CPython 3.12: `python`, `python3` and `python3.12` are
the same interpreter at `/usr/local`. The pin is deliberate:

- The optimization project this image serves targets CPython 3.12.
- OR-Tools publishes `cp312` manylinux wheels (and no source distribution), so
  a project that pins OR-Tools installs from wheels on 3.12.
- OR-Tools 9.15's `cp313`/`cp314` wheels have a known intermittent CP-SAT
  crash (google/or-tools#5025), so do not move the project past 3.12.

A project that needs another ABI declares it in `.python-version` or
`requires-python`; `uv` downloads that interpreter into the state volume on
demand (`uv python install 3.12` pre-installs one). Keep the project on 3.12
unless the user asks otherwise.

## Environments and packages

Use `uv`; never install into the system interpreter with `pip`.

```bash
uv init                        # project files in the current directory
uv add ortools highspy pandas  # add dependencies, update the lockfile
uv sync                        # recreate .venv from the lockfile
uv run python model.py         # run inside .venv
uvx ruff check .               # one-off tool, no project dependency
```

`uv venv` creates the environment explicitly. `uv tool install <tool>` adds a
tool for the current user under `$HOME/.local` (on the state volume), and
`uv tool list` shows those user-installed tools; the baked tools are in
`/opt/uv/bin`.

On macOS the bind mount is slow and an OR-Tools environment is large. Keep the
environment on the state volume instead of the project:

```bash
export UV_PROJECT_ENVIRONMENT=/home/opencode/.local/share/venv
```

The uv cache is already redirected there by the entrypoint.

## Lint, types, tests

```bash
ruff check .
ruff format .
mypy src/
pytest
```

`pre-commit` is installed too. Editor diagnostics come from the baked
language servers; they need no project setup.

## Native builds

`gcc`/`g++`, `make`, `pkg-config`, `libssl-dev`, `libffi-dev`, `zlib1g-dev`
and `libsqlite3-dev` are available, so a source build works when a package has
no wheel. Keep build dependencies to the current session; a permanent one
belongs in the image (ask the user).
