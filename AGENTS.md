# Agent instructions for this repository

This repository is the home of a container image that runs
[OpenCode](https://opencode.ai) for Python development, tuned for optimization
work with Google OR-Tools. GitHub Actions builds and publishes the image to GHCR
for `linux/amd64` and `linux/arm64` on every push to `main`, on a schedule, and
on demand. Read [docs/architecture.md](docs/architecture.md) for the layout and
the pipeline, and [docs/updating.md](docs/updating.md) for versioning.

## Environment limits

- Docker and Podman are not available in the default working environment. The
  image is built only by the GitHub Actions workflow, so validate changes
  statically and let CI build them.
- The base is Debian (`python:<version>-slim`), not Alpine. Python wheels are
  `manylinux`, and OR-Tools is the reason: it publishes no musllinux wheel and
  no source distribution.
- Run the static checks below after touching the corresponding file types; they
  must pass before committing.

| File types                         | Check                                                                       |
| ---------------------------------- | --------------------------------------------------------------------------- |
| `*.sh`                             | `shellcheck` and `shfmt -i 2 -d` (must print no diff)                       |
| `*.md`                             | `prettier --check --prose-wrap preserve --embedded-language-formatting off` |
| `*.yml`, `*.yaml` (workflows, k8s) | `yq -e . file`                                                              |
| `*.json`, `*.jsonc`                | `jq -e .` (strip `//` comment lines from `jsonc` first)                     |
| `*.py`                             | `python3 -m py_compile file`                                                |

Format changed Markdown with
`prettier --write --prose-wrap preserve --embedded-language-formatting off`
before committing; it pads tables so they stay aligned in a terminal.

## Rules

- **Versions are never hardcoded** in the `Containerfile` or the workflow.
  `scripts/resolve-versions.sh` resolves OpenCode, OR-Tools, CPython 3.12, and
  yq at CI time; `versions.json` is the pinned record and is updated only by the
  `update-pins` bot PR.
- **Python is fixed at 3.12.** That is the interpreter of the optimization
  project (PyCharm virtual environment), and the script only verifies that the
  newest `ortools` still ships a `cp312` wheel: there is no sdist to fall back
  to. Do not follow the newest minor OR-Tools supports, because its 3.13/3.14
  wheels have a known intermittent CP-SAT crash (google/or-tools#5025).
- **Secrets are host-side only.** Never commit a `.env` file, never print or
  echo tokens. `.env.example` is the template; it is baked into the image at
  `/home/opencode/.env.example` for the `env-setup` agent skill.
- **Documentation:** English, in `docs/` as short single-topic pages; link every
  page from the README index and cross-link related pages. Keep `README.md` at
  100 lines or fewer. Update the affected docs in the same change as behavior,
  configuration, or setup.
- **Commits:** English, Conventional Commits (`feat:`, `fix:`, `docs:`,
  `chore:`, ...). Commit after each logical change, not one giant commit.
- **Two AGENTS.md files are different things.** The root file is for agents
  working on this repository. `config/opencode/AGENTS.md` is baked into the
  image and instructs the agent that runs inside it, for Python work. Do not mix
  their concerns.

## After pushing

The push to `main` triggers the `Build` workflow. Watch the run (GitHub Actions
or `gh run list` / `gh run watch`), and on failure read the logs
(`gh run view <id> --log`) before changing anything. The smoke test runs per
architecture: it checks the image default, starts the server and answers
`GET /api/info` with Basic auth, and installs OR-Tools in a throwaway venv to
solve a small CP-SAT model.

The workflow also maintains the `status` branch: a single commit holding
`status.json`, the data behind the README's last-build badge. It is written by
CI only; never edit or merge that branch.
