# Instructions

## Language rules

- **Conversation with the user:** in the language the user writes in.
- **Code:** identifiers, variables, functions, classes, file names — in English.
- **Code comments:** in English.
- **Git commit messages:** in English, Conventional Commits format (feat:, fix:, docs:, etc.).
- **Documentation, log messages, error messages, CLI output:** in English.

## Style

- Keep code idiomatic and clean.
- Keep changes consistent with the structure, naming and patterns of the
  surrounding code.

## Tooling

The image ships a Python development toolchain. Prefer these tools over ad-hoc
alternatives.

- Environments and packages: `uv`. Use `uv venv`, `uv add`, `uv sync`,
  `uv pip`, `uvx` and `uv run`. Never install packages into the system
  interpreter with `pip`; if a script needs an environment, create one with
  `uv`.
- Python versions: `uv python install 3.12` (or another version) and a
  `.python-version` file in the project. The interpreter baked into the image is
  CPython 3.12: OR-Tools ships `cp312` wheels for it and the optimization
  project targets that minor. Do not raise the project's Python requirement
  without checking that OR-Tools publishes a wheel for the new minor.
- Lint and format: `ruff check`, `ruff format`. Types: `mypy`. Tests: `pytest`.
- Hooks: `pre-commit`.
- Profiling: `py-spy` (`py-spy top`, `py-spy record -o profile.svg -- python
model.py`), including native OR-Tools calls.
- Search: `rg` (ripgrep), `fd`, `ast-grep` (also available as `sg`) for
  structural search and rewriting.
- JSON/YAML: `jq`, `yq`.
- Forge: `gh` for GitHub, `glab` for GitLab (issues, MRs, pipelines,
  releases); Forgejo through the REST API.
- Shell scripts: `shellcheck`, `shfmt`.
- Native builds: `gcc`/`g++`, `make`, `pkg-config` and the development headers
  (`libssl-dev`, `libffi-dev`, `zlib1g-dev`, `libsqlite3-dev`) are available for
  C extensions.
- Markdown: the repository CI checks formatting with `prettier`, which is not
  installed here (it needs Node). Keep tables aligned by hand and do not
  reformat whole files.

## OR-Tools

- OR-Tools is a project dependency, not part of the image: add it with
  `uv add ortools` and pin the version in the project. Wheels exist for glibc
  only, which is why the image is Debian-based.
- OR-Tools pins `protobuf<6.34`; do not force a newer protobuf alongside it.
- CP-SAT is CPU- and memory-hungry: give the container enough resources
  (`--cpus`, `--memory`) and tune `num_search_workers` in the solver
  parameters.
- HiGHS (`uv add highspy`), PuLP and Pyomo are project dependencies too; only
  open-source solvers are supported out of the box (CP-SAT, GLOP, SCIP,
  HiGHS).

## Git and forges

- Commits use `GIT_AUTHOR_*` and `GIT_COMMITTER_*` when they are set. Do not
  change the git identity in the repository or in the global config.
- GitHub: git over HTTPS uses the `gh` credential helper, which the entrypoint
  configures from `GH_TOKEN`. Use `gh` for issues, pull requests and releases;
  it reads `GH_TOKEN` from the environment.
- GitLab (optional): when `GITLAB_TOKEN` is set, git over HTTPS to the GitLab
  host (`GITLAB_URL`, default `https://gitlab.com`) is preconfigured by the
  entrypoint. Use `glab` for issues, MRs, pipelines and releases (it reads
  `GITLAB_TOKEN`; pass `--hostname` for self-hosted instances) or the REST API
  with the `PRIVATE-TOKEN` header.
- Forgejo (optional): when `FORGEJO_TOKEN` and `FORGEJO_URL` are set, git over
  HTTPS/HTTP to that instance is preconfigured by the entrypoint. Use the REST
  API (`<FORGEJO_URL>/api/v1/...`) with the `Authorization: token` header.
- Never print, log or commit `GH_TOKEN`, `GITLAB_TOKEN`, `FORGEJO_TOKEN` or
  other credentials.

## Container updates

OpenCode is baked into the image; it cannot update itself inside the
container. Never run `opencode upgrade` or edit the installed binary. Updates
are published by the GitHub Actions workflow, so ask the user to pull a newer
image when a newer OpenCode is needed.

## Models

No model is pinned in the baked config. Until the user connects a provider,
OpenCode serves its free built-in models (provider `opencode`) with no account
or key, and the session starts on one of them.

When the session runs on a free built-in model, mention it once at the start of
the conversation (in the user's language, one or two sentences): the session
runs on a free model that ships with OpenCode, and for other models the user can
connect a provider with the TUI's `/connect` command and then pick a model in
the model picker. The TUI's sidebar already shows the `/connect` hint, so keep
the mention brief.

If the user asks about an environment file instead, offer to create a `.env`
file in the project folder yourself: copy the template
`/home/opencode/.env.example` to `.env` in the working directory (the project is
mounted, so the file lands on the host), and tell the user to fill in
`OPENROUTER_API_KEY` and add `--env-file .env` to the run command (the optional
launcher finds the file on its own).

Offer it once; do not repeat it unless the user asks, and do not push it if the
user is content with the built-in model.

## Secrets

Secrets (provider API keys, the server password, forge tokens, a private
package index URL) are passed at runtime through the environment, or stored
once by the user with `opencode auth login` or the TUI's `/connect` command (a
stored account wins over the matching environment variable, for example over
`OPENROUTER_API_KEY`). The runtime env template is baked into the image at
`/home/opencode/.env.example`. When a required variable is missing or empty,
use the `env-setup` skill to offer the user a copy of the template. Never write
secrets into the repository, print them in output, commit a `.env` file, or run
`opencode auth export`.

## sudo

Passwordless sudo is available inside this container. Use it only to install
software that is missing for the current task.

Allowed:

- `sudo apt-get update && sudo apt-get install -y --no-install-recommends
<package>` after checking the package name with `apt-cache policy <package>`.
- Temporary build dependencies, removed in the same session.

Not allowed:

- Editing, creating, moving or deleting project files through sudo. Container
  root maps to a subuid on the host and would break project file ownership.
  All project changes go through the normal user.
- Running the agent, git, or language tooling as root.
- `apt-get upgrade`, removing base packages, or replacing system runtimes
  (system Python, uv).
- Installing Python packages with sudo: use `uv`, `uvx` or a project virtual
  environment instead.
- Changing `/etc/sudoers*`, `/etc/passwd`, or SSH/GPG configuration.

Rules:

- State the package and the reason before installing, and keep it minimal.
- Runtime installs live in the writable layer and disappear when the container
  exits. If a tool is needed permanently, tell the user so it can be added to
  the Containerfile.
- After installing, verify with `command -v <tool>` and the tool's version.
- Never use sudo to work around a permission error inside the project; fix the
  cause or ask the user.
