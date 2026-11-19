# Updating

How versions are chosen and how image releases work.

## Rolling latest

The image always builds with the current upstream versions — there is nothing
to update on the host:

- **OpenCode**: the newest non-prerelease release tag of `anomalyco/opencode`
  from the GitHub releases API.
- **OR-Tools**: the newest release on PyPI.
- **Python**: the newest `python:3.12.<patch>-slim` tag on Docker Hub. The
  minor is fixed at 3.12, the interpreter the optimization project targets
  (PyCharm virtual environment); the script verifies that the newest OR-Tools
  release still publishes a `cp312` wheel, because OR-Tools ships no source
  distribution. The 3.13/3.14 wheels are not used: OR-Tools 9.15 has a known
  intermittent CP-SAT crash there
  ([google/or-tools#5025](https://github.com/google/or-tools/issues/5025)).
- **yq**: the newest mikefarah/yq release, downloaded from GitHub for the target
  architecture.
- **uv and the Debian packages** (`ruff` comes from `uv tool`, `gh`, `glab`,
  `ripgrep`, ...) are whatever the distribution or PyPI publishes on build day.
  Debian trixie does not package `uv`, so the image installs the current `uv`
  from PyPI during the build.

The workflow resolves them on every run (push to `main`, the daily schedule at
06:17 UTC, or `workflow_dispatch`) and rebuilds the image. The scheduled run is
also the version watch: it always rebuilds with whatever upstream published, and
the final job compares the resolved versions with `versions.json`, opening the
pin update pull request only when something moved.

## The last-build badge

The README's second badge shows the date, time and versions of the last build.
The `status` job runs at the end of every `main` build (successful or not) and
force-pushes a single-file branch, `status`, whose `status.json` follows the
[shields.io endpoint](https://shields.io/badges/endpoint-badge) schema. The
branch is written by CI only; do not edit it by hand.

## Image tags

| Tag                                        | Meaning                                |
| ------------------------------------------ | -------------------------------------- |
| `latest`                                   | the newest published build, multi-arch |
| `oc-<opencode-version>-py<python-version>` | the exact combination, for pinning     |
| `<YYYYMMDD>`                               | the build date                         |

Run the version that was current when you read the docs, or pin:

```bash
docker pull ghcr.io/app/opencode-python:oc-2.3.2-py3.12.16
```

`docker image inspect` prints the pinned versions from the image labels
(`org.opencode-python.opencode`, `org.opencode-python.python`,
`org.opencode-python.yq`).

## Pin updates in the repository

`versions.json` records the last resolved combination (OpenCode, OR-Tools,
Python, yq). The `update-pins` job opens a pull request (branch
`chore/update-pinned-versions`) whenever the resolved versions differ from the
file. Merging the PR rebuilds and republishes the image; the schedule keeps
looking for newer versions on its own.

## Building locally

For a one-off build with specific upstream versions (both architectures need a
matching builder; the CI matrix uses native runners):

```bash
docker build \
  --build-arg OPENCODE_VERSION=2.3.2 \
  --build-arg PYTHON_VERSION=3.12.16 \
  --build-arg YQ_VERSION=4.54.3 \
  -t opencode-python:local .
```

The `Containerfile` never hardcodes versions, so the workflow remains the
source of truth.
