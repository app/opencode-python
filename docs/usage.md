# Usage

Running the container: the TUI, the server mode, mounts, resources, secrets and
other commands.

## Open the TUI (default)

The default command is the interactive TUI inside the container. From the
project directory:

Podman:

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  ghcr.io/app/opencode-python:latest
```

Docker (the same, with `--user` instead of `--userns`):

```bash
docker run -it --rm --user "$(id -u):$(id -g)" \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  ghcr.io/app/opencode-python:latest
```

No server, no published port, and nothing installed on the host. The project
directory is mounted read-write at `/home/opencode/projects/<name>`; when it
is the only project mount, OpenCode starts inside it, so the TUI opens your
project directly. If you have a `.env` file (see
[More models](installation.md#more-models-optional)), add `--env-file .env`
to the command. The optional
[launcher](installation.md#the-launcher-optional) wraps exactly this.

## Terminal

The TUI is a full-screen app, so copying between the TUI and the host
clipboard goes through your terminal. Standard terminals (GNOME Terminal on
Ubuntu, Terminal.app on macOS) work, but copying is limited. For full
two-way clipboard access, install:

- **kitty** on Linux — the clipboard works out of the box.
- **iTerm2** on macOS — enable _Settings → General → Selection →
  "Applications in terminal may access clipboard"_.

## Start the server (web UI, HTTP API)

Server mode is an explicit command on top of the same image:

```bash
podman run -d \
  --name "opencode-$$" \
  --userns=keep-id:uid=1000,gid=1000 -p 4096:4096 \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --env-file .env \
  ghcr.io/app/opencode-python:latest \
  opencode serve --hostname 0.0.0.0 --port 4096
```

The same works with Docker (with `--user "$(id -u):$(id -g)"` instead of
`--userns`); drop `-d` and add `-it` for a foreground run. The
[launcher](installation.md#the-launcher-optional) equivalent is
`OPENCODE_PY_RUN_ARGS="-p 4096:4096" opencode-py serve --hostname 0.0.0.0
--port 4096`.

To open the [web UI](api.md#web-ui), create a pairing link from inside the
running container:

```bash
name="$(podman ps --format '{{.Names}}' | grep '^opencode-' | head -n1)"
podman exec -it --detach-keys="ctrl-],ctrl-q" "$name" opencode pair
```

Open the printed link in a browser. The [HTTP API](api.md#http-api-agents) is
available under Basic auth on the same port.

## Mounts

| Host path                             | Container path                   | Purpose                                                                          |
| ------------------------------------- | -------------------------------- | -------------------------------------------------------------------------------- |
| your project directory                | `/home/opencode/projects/<name>` | the agent's working project; OpenCode starts inside it when it is the only mount |
| `opencode-python-state-<user>` volume | `/home/opencode/.local`          | credentials, the session database, the uv cache and extra Pythons, per user      |

- User mapping: `--userns=keep-id:uid=1000,gid=1000` (Podman) runs the agent
  as the image's built-in user, uid/gid 1000, mapped onto your host user, so
  files it creates — in the project and on the state volume — are uid 1000 in
  the container and yours on the host. Docker has no user mapping, so its
  commands pass `--user "$(id -u):$(id -g)"` instead, which runs the agent as
  your host UID with the same ownership outcome.
- `--detach-keys="ctrl-],ctrl-q"` (in every command above) moves the
  engine's detach sequence off the default `ctrl-p ctrl-q`, which would
  swallow the TUI's `ctrl-p` command palette key.
- `--name "opencode-$$"` (in every command in this repository) names the
  container after the PID of the shell that ran it, so parallel sessions in
  different terminals do not collide and `podman ps` stays readable.
- Mount sibling projects read-only with extra `-v` mounts under
  `/home/opencode/projects/`, for example
  `-v ../other-model:/home/opencode/projects/other-model:ro` (the launcher's
  `-r` flag wraps this). With several project mounts, OpenCode starts at
  the projects root; open a specific one by appending its directory to the
  run command: `opencode /home/opencode/projects/other-model`.
- For Kubernetes, see [Kubernetes](kubernetes.md) instead.

## Resources

Solver runs are CPU- and memory-hungry, and the language servers plus the TUI
need headroom. Pass engine limits on the run command (or through
`OPENCODE_PY_RUN_ARGS` with the launcher):

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --cpus 4 --memory 8g \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  ghcr.io/app/opencode-python:latest
```

CP-SAT uses all apparent cores by default; set
`solver.parameters.num_search_workers` in the model when you want to cap it.
See [Optimization](optimization.md) for solver-specific advice.

## Passing secrets

Secrets are never baked into the image; they are passed at runtime, as a file
with one `NAME=value` line per variable:

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  --env-file .env \
  ghcr.io/app/opencode-python:latest
```

For a single variable, replace `--env-file .env` with `-e NAME=value`.

The OpenRouter key is optional (the free built-in models need no key); to
connect, use the TUI's `/connect` command (see
[Installation](installation.md#more-models-optional)) — the stored account
wins over the environment.

By convention the file lives in the project directory (`.env`); the optional
[launcher](installation.md#the-launcher-optional) finds it on its own. The
template documenting every variable lives in the repository root
(`.env.example`) and inside the image at `/home/opencode/.env.example`.
Variable reference:

| Variable                                     | Required         | Purpose                                                              |
| -------------------------------------------- | ---------------- | -------------------------------------------------------------------- |
| `OPENROUTER_API_KEY`                         | no               | API key for OpenRouter models; the free built-in models need no key  |
| `OPENCODE_PASSWORD`                          | no (server mode) | server password; when empty, one is generated and printed to the log |
| `GH_TOKEN`                                   | no               | GitHub token for git over HTTPS and the `gh` CLI                     |
| `GITLAB_TOKEN`                               | no               | GitLab token for git, the `glab` CLI and the API                     |
| `GITLAB_URL`                                 | no               | self-hosted GitLab host (default `https://gitlab.com`)               |
| `FORGEJO_URL`                                | no               | Forgejo/Gitea instance URL, required for `FORGEJO_TOKEN`             |
| `FORGEJO_TOKEN`                              | no               | Forgejo token for git and the REST API                               |
| `UV_INDEX_URL`                               | no               | private Python package index for `uv` (token may be in the URL)      |
| `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL`       | no               | author identity for commits                                          |
| `GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL` | no               | committer identity for commits                                       |

When the agent is already running and a token or another variable is missing,
it can offer to copy the template into the working folder (the `env-setup`
skill). Never commit or print secrets; see [Security notes](security.md).

## Other commands

The entrypoint execs the command you pass, so any other opencode command or a
shell works — append it to the run command:

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  --detach-keys="ctrl-],ctrl-q" \
  ghcr.io/app/opencode-python:latest \
  opencode run "Explain this repository"
```

That is a one-shot prompt with no server. For a shell inside the container,
replace the command with `bash`; `uv`, `ruff` and the rest are on the `PATH`.

## Logs

The container name (and its published ports) is shown by:

```bash
podman ps --format "table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Ports}}" | grep opencode
```

The log is read with:

```bash
name="$(podman ps --format '{{.Names}}' | grep '^opencode-' | head -n1)"
podman logs -f "$name"
```

In server mode, the generated server password (when `OPENCODE_PASSWORD` is
empty) is printed there on start.
