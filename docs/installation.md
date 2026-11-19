# Installation

How to open the first session. There is nothing to install: the image is
pulled automatically on the first run, and the TUI runs inside the container,
so no OpenCode client is needed on the host.

## Requirements

- [Docker](https://www.docker.com/) or [rootless Podman](https://podman.io/).
  For Podman, enable subuid mappings so the
  `--userns=keep-id:uid=1000,gid=1000` flag works (`subuid`/`subgid` entries
  in `/etc/subuid` and `/etc/subgid`).
- Nothing else: OpenCode's free built-in models work without any account or
  key. An [OpenRouter](https://openrouter.ai/) API key is optional — see
  [More models](#more-models-optional).
- On Apple Silicon the image runs natively: it is published for
  `linux/arm64` as well as `linux/amd64`, so no emulation is involved. Use a
  current Docker Desktop or Podman; see [Apple Silicon](#apple-silicon).

## Open the first session

From the project directory you want the agent to work in:

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

`--userns=keep-id:uid=1000,gid=1000` (Podman) maps the image's built-in user
(uid 1000) onto your host user, so files the agent creates are uid 1000 in the
container and yours on the host; the Docker command passes `--user
"$(id -u):$(id -g)"` instead, running the agent as your host UID directly.

The TUI opens inside the container; the project is mounted read-write at
`/home/opencode/projects/<name>` and OpenCode starts inside it, so the session
opens your project directly. The `opencode-python-state-<user>` volume (one per
user) keeps credentials, the session database, the uv cache and any extra
Python versions across runs. The session starts on OpenCode's free built-in
model — start typing right away, no key needed; the sidebar's `/connect` hint
leads to other models (see [More models](#more-models-optional)).

## Apple Silicon

The image is a multi-arch manifest, so Docker and Podman select `linux/arm64`
on an M-series Mac automatically; do not pass `--platform`. Python wheels,
including OR-Tools, are native `manylinux` aarch64 builds — nothing runs under
Rosetta or QEMU.

- Podman on macOS runs an arm64 Linux VM (`podman machine`). Docker Desktop
  needs a recent version; an old release may pull the amd64 image and emulate
  it, which is much slower.
- Give the VM enough memory: CP-SAT is memory hungry and the language servers
  add up. 8 GB for the VM is a comfortable default, see
  [Optimization](optimization.md#resources).
- Enable virtiofs file sharing (Podman's default on current releases, Docker
  Desktop's "Virtualization framework" option). A Python virtual environment
  with OR-Tools is large, so bind-mount performance matters; the agent keeps
  the environment on the state volume when the project needs it.

## More models (optional)

The free built-in models need no key. To use OpenRouter models, connect
OpenRouter once; two ways, and when both are present, the stored account wins.

### Option 1: connect in the TUI (`/connect`)

With the TUI open, type `/connect`, pick OpenRouter, and enter the API key.
The credential is stored in your `opencode-python-state-<user>` volume, so every
later run has the models. The same credential can be stored from the host
without the TUI:

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --name "opencode-$$" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  ghcr.io/app/opencode-python:latest opencode auth login openrouter
```

The same works with Docker (with `--user "$(id -u):$(id -g)"` instead of
`--userns`). Remove the stored key the same way, with `opencode auth logout
openrouter` in place of `auth login openrouter`.

### Option 2: environment file

Keep the key on the host — copy the template into the project folder and keep
it private:

```bash
curl -fsSL https://raw.githubusercontent.com/app/opencode-python/main/.env.example -o .env
chmod 600 .env
```

Fill in `OPENROUTER_API_KEY`, add `.env` to `.gitignore`, and pass the file on
the run command:

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  --env-file .env \
  ghcr.io/app/opencode-python:latest
```

The same works with Docker (with `--user "$(id -u):$(id -g)"` instead of
`--userns`). See [Security notes](security.md) for how secrets are handled.

Either way, the OpenRouter models then appear in the TUI's model picker — pick
the one you want to work with; the pick is remembered on the
`opencode-python-state-<user>` volume and used on later runs.

## The launcher (optional)

The repository ships `bin/opencode-py`, a thin wrapper over podman/docker for
people who prefer a shorter command: it resolves the engine (Podman first,
override with `OPENCODE_PY_ENGINE`), mounts the current project and the
`opencode-python-state-<user>` volume, finds the env file on its own
(`OPENCODE_PY_ENV_FILE` → `./.env` → `~/.config/opencode-python/env`), and
passes all remaining arguments to opencode unchanged. Fetch the single file
from the repository and install it:

```bash
curl -fsSL https://raw.githubusercontent.com/app/opencode-python/main/bin/opencode-py \
  -o /tmp/opencode-py
install -m755 /tmp/opencode-py "$HOME/.local/bin/opencode-py"
```

Then run `opencode-py` from the project directory (`opencode-py -r
../other-model` mounts a sibling read-only, `OPENCODE_PY_RUN_ARGS="--cpus 4
--memory 8g"` gives CP-SAT room to work, `OPENCODE_PY_RUN_ARGS="-p 4096:4096"`
publishes the port in server mode). It is optional: every launcher flag has a
plain `run` equivalent shown in [Usage](usage.md).

## Image tags

The image is published to GHCR by the GitHub Actions workflow. Tags:
`latest`, `oc-<opencode-version>-py<python-version>` (the exact toolchain
combination, for example `oc-2.3.2-py3.12.16`) and `<YYYYMMDD>` (build date).
See [Updating](updating.md) for how versions are chosen.

## Uninstall

Remove the image and the state volume:

```bash
podman rmi ghcr.io/app/opencode-python:latest
podman volume rm opencode-python-state-$(id -un)
```
