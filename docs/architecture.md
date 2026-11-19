# Architecture

Repository layout, the image, and the GitHub Actions pipeline.

## Layout

```text
.
├── AGENTS.md                         # entry point for agents on a host: install/run, HTTP API, repository work
├── bin/opencode-py                   # launcher: thin wrapper over podman/docker
├── Containerfile                     # OpenCode + Python/OR-Tools toolchain, built-in non-root user (uid 1000)
├── .env.example                      # runtime env template (copied into the image)
├── versions.json                     # pinned versions (updated by the bot PR)
├── .github/workflows/build.yml       # multi-arch build, publish, smoke test, pin updates
├── scripts/
│   ├── check-docs.sh                 # checks the consumer doc examples and the canonical API block
│   ├── resolve-versions.sh           # resolves OpenCode, OR-Tools, Python and yq
│   └── smoke-ortools.py              # CP-SAT smoke test run by CI
├── config/
│   ├── bin/entrypoint.sh             # git identity, forge credentials, uv cache, cd into the project, exec "$@"
│   ├── gitconfig                     # generic gitconfig for the non-root user
│   ├── sudoers.d/opencode            # passwordless sudo policy (any user in the container)
│   └── opencode/                     # copied to /home/opencode/.config/opencode
│       ├── opencode.jsonc            # permissions, LSP (no model or provider pinned)
│       ├── AGENTS.md                 # in-container agent instructions (public, no personal data)
│       ├── docs/                     # in-container guides: workspace, Python/uv, OR-Tools, troubleshooting
│       └── skills/env-setup/SKILL.md # offers the env template when runtime variables are missing
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── secret.example.yaml
├── docs/                             # reference documentation for container users (host-side examples)
└── README.md
```

## Why Debian and not Alpine

The image is based on `python:<version>-slim` (Debian trixie) rather than on the
upstream Alpine OpenCode image. OR-Tools publishes `manylinux` wheels only, with
no musllinux wheel and no source distribution:

| Package                      | musllinux arm64  | manylinux arm64 |
| ---------------------------- | ---------------- | --------------- |
| numpy, pandas, scipy         | yes              | yes             |
| pyarrow, lxml, pydantic-core | yes              | yes             |
| scikit-learn, torch          | no               | yes             |
| opencv-python                | no               | yes             |
| matplotlib                   | no (aarch64)     | yes             |
| **ortools**                  | **no, no sdist** | yes             |

That is also why Python stays on the 3.12 line OR-Tools supports: there is no
fallback build path.

## Image

The `Containerfile` starts from `python:${PYTHON_VERSION}-slim`, installs the
official OpenCode release asset for the target architecture (checksum-verified,
`opencode` and `opencode2`), the upstream `yq` binary, the Debian toolchain, and
the `uv`-managed development tools. It creates a non-root `opencode` user
(uid/gid 1000 by default, overridable with `--build-arg UID=... --build-arg
GID=...`). The documented run commands make the image's user the caller's:
Podman maps it onto the host user with
`--userns=keep-id:uid=1000,gid=1000`, Docker overrides it with `--user "$(id -u):$(id -g)"`,
so files created by the agent keep host ownership either way. The home and the
uv tool directories are world-writable inside the image so that any user the
container runs as can write to them (the container is a single-user trust
boundary).

The image bakes configuration, not secrets:

- `config/opencode/` → `/home/opencode/.config/opencode/` (autonomous
  permissions, the two Python language servers, the `env-setup` skill, the
  `AGENTS.md` policy; no model or provider is pinned — the session runs on
  OpenCode's free built-in models until the user connects OpenRouter);
- `config/gitconfig` → `/home/opencode/.gitconfig` (generic identity);
- `.env.example` → `/home/opencode/.env.example` (the runtime env template);
- `config/bin/entrypoint.sh` → `/usr/local/bin/entrypoint.sh` (git identity
  from the environment, forge git credentials from `GH_TOKEN`, `GITLAB_TOKEN`,
  `FORGEJO_TOKEN` when set, the uv cache on the state volume, a `cd` into the
  single mounted project, then `exec "$@"`).

The default command is the interactive TUI: `docker run -it ... image` opens a
session with no OpenCode installation on the host, in the mounted project (the
entrypoint `cd`s into it when it is the only project mount). The server
(`opencode serve --hostname 0.0.0.0 --port 4096`) is started explicitly — the
k8s deployment and the CI smoke test pass it as the container command. See
[Usage](usage.md) and [Access](api.md).

## CI pipeline

`.github/workflows/build.yml` runs on push to `main`, on a daily schedule, and
on demand (`workflow_dispatch`):

1. **resolve** — `scripts/resolve-versions.sh` resolves the newest stable
   OpenCode release, the newest OR-Tools release, the newest yq release, and the
   newest `python:3.12.<patch>-slim` tag, after checking that the OR-Tools
   release still ships a `cp312` wheel. The job also runs
   `scripts/check-docs.sh`, which checks the consumer doc examples and keeps
   the canonical API block in `AGENTS.md` and `docs/api.md` identical.
2. **build** — a matrix on native runners (`ubuntu-26.04` for amd64,
   `ubuntu-26.04-arm` for arm64) builds and pushes each architecture by digest,
   with a per-architecture registry cache. Each job pulls its own digest and
   runs the smoke test natively: the default `CMD` must be the TUI, the toolchain
   must answer, OR-Tools must install and solve a CP-SAT model, and the server
   must answer `GET /api/info` with Basic auth and report the built version.
3. **merge** — `docker buildx imagetools create` assembles the digests into the
   multi-arch tags `latest`, `oc-<opencode>-py<python>` and `<YYYYMMDD>`.
4. **update-pins** — compares the resolved versions with `versions.json` and
   opens a pull request (`peter-evans/create-pull-request`) when they differ.

The cache lives in a separate `opencode-python-buildcache` GHCR repository, one
tag per architecture. See [Updating](updating.md) for the version rules.
