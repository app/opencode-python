# Toolchain

The image ships a Python development toolchain with an optimization focus:
Python, `uv`, the lint/type/test tools, the language servers, and the C
toolchain for building extensions. This page is a reference for everyone who
runs the image; the agent's usage guide is baked with the configuration
([config/opencode/docs/python.md](../config/opencode/docs/python.md)).

| Area      | Tools                                                                                                      |
| --------- | ---------------------------------------------------------------------------------------------------------- |
| Python    | CPython (`python`, `python3`, `python3.12`), `uv`                                                          |
| Quality   | `ruff` (lint and format), `basedpyright`, `mypy`, `pytest`, `pre-commit`                                   |
| Profiling | `py-spy`                                                                                                   |
| Search    | `rg` (ripgrep), `fd`, `ast-grep` (`sg`)                                                                    |
| Data      | `jq`, `yq`                                                                                                 |
| Git       | `git`, `openssh-client`, `gh`, `glab`                                                                      |
| Build     | `gcc`/`g++`, `make`, `pkg-config`, `libssl-dev`, `libffi-dev`, `zlib1g-dev`, `libsqlite3-dev`              |
| Shell     | `bash`, `shellcheck`, `shfmt`, GNU userland (`coreutils`, `findutils`, `grep`, `sed`, `gawk`, `diffutils`) |
| Misc      | `less`, `file`, `tree`, `curl`, `xz`, `unzip`, `zip`, `tzdata`, `procps`                                   |

The base is Debian (`python:<version>-slim`), not Alpine, because OR-Tools and
most of the numerical Python ecosystem publish `manylinux` wheels only — see
[Optimization](optimization.md).

## Python

The image is built on the official `python:<version>-slim` image, so the
interpreter is the Debian-friendly upstream CPython build at `/usr/local`, and
`python`, `python3` and `python3.12` point at it.

The pinned version is CPython 3.12, the minor the optimization project targets
and the one OR-Tools ships `cp312` wheels for (recorded in `versions.json` and
in the image labels). A project that needs another version declares it in
`.python-version` (or `requires-python`, which `uv` honors); `uv` downloads that
interpreter into the state volume on demand.

## uv and the tools

`uv` is installed from PyPI at build time (Debian trixie does not package it)
and owns environments and packages: the agent runs `uv init`, `uv add`,
`uv sync`, `uv run` and `uvx` inside the project, never `pip` into the system
interpreter. `uv` keeps its cache on the state volume, so large wheels such as
OR-Tools are not downloaded again on every run.

`ruff`, `basedpyright`, `mypy`, `pytest`, `pre-commit` and `py-spy` are
installed as isolated `uv tool` environments at build time, with their
executables in `/opt/uv/bin` (on the `PATH`), so they run without a project
environment. `uv tool install <tool>` adds a tool for the current user under
`$HOME/.local`.

The language servers are wired into OpenCode through the baked configuration:
`basedpyright-langserver --stdio` for types and navigation, and `ruff server`
for lint and format diagnostics, both covering `.py` and `.pyi`.

## Native builds

`gcc`/`g++`, `make`, `pkg-config` and the common development headers are
installed, so source builds of Python packages work when no wheel exists. The
agent can add extra Debian packages with the passwordless sudo for the current
session; a permanent dependency belongs in the `Containerfile`.
