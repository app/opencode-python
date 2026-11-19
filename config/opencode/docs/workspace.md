# Workspace

You run inside the container; the user works on the host, in the same project
directory.

## The project

- The project is mounted read-write from the host at
  `/home/opencode/projects/<name>` (the name is the host directory name) and is
  the working directory when it is the only project mount.
- Edits, new files and commits made there land directly on the host, so the
  user sees them in their editor. Do not copy the project somewhere else to
  work on it.
- Sibling projects may be mounted read-only under `/home/opencode/projects/`;
  treat them as reference material.

## State

- `/home/opencode/.local` is the `opencode-python-state-<user>` volume. It
  keeps credentials, the session database, the uv cache and any interpreters
  downloaded by `uv python install`. It survives container restarts; the rest
  of the container filesystem does not.
- `/home/opencode/.config/opencode` is baked into the image (instructions,
  skills, OpenCode configuration). Do not edit it: changes disappear when the
  container restarts and are overwritten by the next image.
- The runtime environment template is `/home/opencode/.env.example`. When a
  variable is missing, use the `env-setup` skill to copy the template into the
  project.

## Commands and packages

- The image is Debian-based and runs as a non-root user with passwordless
  sudo; `sudo apt-get install` is allowed only for packages missing for the
  current task (rules in `AGENTS.md`).
- Python tooling is `uv`; baked tools are under `/opt/uv/bin`, user-installed
  ones in `$HOME/.local/bin`. See
  `/home/opencode/.config/opencode/docs/python.md`.
