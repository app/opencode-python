# Toolchain

The image is built for Python agent work with an optimization focus: Python,
`uv`, the lint/type/test tools, the language servers, and the C toolchain for
building extensions.

| Area      | Tools                                                                                                      |
| --------- | ---------------------------------------------------------------------------------------------------------- |
| Python    | CPython (`python`, `python3`, `python3.14`), `uv`                                                          |
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
`python`, `python3` and `python3.14` point at it:

```bash
python -V                    # the CPython pinned at build time
uv --version
```

The pinned version is the newest CPython that OR-Tools ships wheels for
(recorded in `versions.json` and in the image labels). A project that needs
another version declares it in `.python-version` (or `requires-python`, which
`uv` honors); `uv` downloads that interpreter into the state volume on demand:

```bash
uv python install 3.12
uv venv --python 3.12
```

## uv

`uv` is installed from PyPI at build time (Debian trixie does not package it).
It owns environments and packages; do not install into the system interpreter:

```bash
uv init
uv add ortools highspy pandas matplotlib
uv run python model.py
uvx ruff check .
```

- `uv sync` / `uv add` use `.venv` in the project by default. See
  [Optimization](optimization.md#virtual-environments) for the macOS-friendly
  alternative.
- The uv cache is redirected to `$HOME/.local/share/uv-cache` by the
  entrypoint, which sits on the state volume, so large wheels such as OR-Tools
  are not downloaded again on every run.
- `uv tool install <tool>` adds a tool for the current user under
  `$HOME/.local` (also on the state volume) and puts it first on the `PATH`.
  `uv tool list` shows those user-installed tools; the baked tools are in
  `/opt/uv/tools` and their executables in `/opt/uv/bin`.

## Lint, types, tests

`ruff`, `basedpyright`, `mypy`, `pytest`, `pre-commit` and `py-spy` are
installed as isolated `uv tool` environments at build time, with their
executables in `/opt/uv/bin` (on the `PATH`), so they run without a project
environment:

```bash
ruff check .
ruff format .
mypy src/
pytest
py-spy record -o profile.svg -- python model.py
```

The language servers are wired into OpenCode through the baked configuration:
`basedpyright-langserver --stdio` for types and navigation, and `ruff server`
for lint and format diagnostics, both covering `.py` and `.pyi`.

## Installing extra packages

The user the container runs as has passwordless sudo (the policy matches any
user), so the agent can install Debian packages when a task needs them:

```bash
sudo apt-get update && sudo apt-get install -y --no-install-recommends <package>
```

Runtime installs are not persisted: they disappear with the container. Add the
package to the `Containerfile` for a permanent tool. The usage policy is
defined in the baked `AGENTS.md`; see [Security notes](security.md).

## Building C extensions

`gcc`/`g++`, `make`, `pkg-config` and the common development headers are
installed, so source builds of Python packages work when no wheel exists. Build
dependencies that a specific package needs (for example database client
libraries) can be added with apt for the session; for a permanent one, add
them to the `Containerfile`.
