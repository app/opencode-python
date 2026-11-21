#!/usr/bin/env bash
#
# Container entrypoint: prepares the runtime for OpenCode, starts in the
# mounted project when there is exactly one, then execs the requested
# command (default: the interactive TUI).
#
# Secrets are passed in through the environment (--env-file or a Kubernetes
# Secret). This script never reads or writes a .env file; the runtime env
# template is baked into the image at /home/opencode/.env.example for the
# env-setup agent skill.

set -euo pipefail

# Keep the uv cache on the state volume: OR-Tools-sized wheels are otherwise
# downloaded again on every fresh container. An explicit UV_CACHE_DIR wins.
export UV_CACHE_DIR="${UV_CACHE_DIR:-${HOME:-/home/opencode}/.local/share/uv-cache}"

# Git identity: environment variables take precedence over the gitconfig
# baked into the image, so each user can set their own committer.
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-opencode-agent}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-agent@localhost}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-opencode-agent}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-agent@localhost}"

# Forge git authentication (GH_TOKEN/GITHUB_TOKEN, GITLAB_TOKEN, FORGEJO_TOKEN)
# is handled by the git credential helpers installed in /usr/local/bin and
# enabled in the baked gitconfig; they read the tokens from the environment at
# request time, so nothing is written to disk.

# OpenCode works in the current directory. When exactly one project is
# mounted under /home/opencode/projects, start inside it so the TUI opens the
# project directly. With zero or several mounts the workspace stays the
# projects root; open a specific project by passing the directory to opencode,
# for example `opencode /home/opencode/projects/frontend`.
shopt -s nullglob
projects=("/home/opencode/projects"/*)
shopt -u nullglob
if [[ ${#projects[@]} -eq 1 && -d "${projects[0]}" ]]; then
  cd "${projects[0]}"
fi

exec "$@"
