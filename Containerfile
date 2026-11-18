# OpenCode image for Python development, tuned for OR-Tools optimization work.
#
# The OpenCode, CPython and yq versions are resolved by the GitHub Actions
# workflow on every run and passed as build args. Do not hardcode versions
# here: versions.json in the repository is the pinned record, and the workflow
# is the source of truth for what gets built.
#
# The base is Debian, not Alpine: OR-Tools publishes manylinux wheels only
# (no musllinux wheel and no source distribution), so a glibc Python is
# mandatory, and so are the manylinux wheels of the rest of the Python
# ecosystem.
#
# Secrets are never baked in. The runtime env template is copied to
# /home/opencode/.env.example for the env-setup agent skill.
ARG OPENCODE_VERSION
ARG PYTHON_VERSION
ARG YQ_VERSION

FROM python:${PYTHON_VERSION}-slim

ARG UID=1000
ARG GID=1000
ARG OPENCODE_VERSION
ARG PYTHON_VERSION
ARG YQ_VERSION

# Recorded in the image for `docker image inspect` and troubleshooting.
LABEL org.opencode-python.opencode="${OPENCODE_VERSION}" \
      org.opencode-python.python="${PYTHON_VERSION}" \
      org.opencode-python.yq="${YQ_VERSION}"

# Toolchain for a Python developer: GNU userland, git and the forge CLIs,
# search tools, JSON/YAML, the C toolchain and headers needed to build Python
# extensions, and the GNU runtime libraries OR-Tools loads. `passwd` provides
# useradd/groupadd; fd is packaged as fdfind. debconf stays noninteractive.
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      passwd \
      ca-certificates \
      curl \
      git \
      openssh-client \
      jq \
      ripgrep \
      fd-find \
      tree \
      less \
      file \
      xz-utils \
      zip \
      unzip \
      tzdata \
      procps \
      sudo \
      gh \
      glab \
      shellcheck \
      shfmt \
      build-essential \
      pkg-config \
      libssl-dev \
      libffi-dev \
      zlib1g-dev \
      libsqlite3-dev \
      libstdc++6 \
      libgomp1 \
      libatomic1 \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# uv is not packaged for Debian trixie (it exists only in testing/unstable), so
# take the current release from PyPI at build time. It owns project
# environments, tool environments and extra Python versions.
RUN set -eux; \
    python -m pip install --no-cache-dir --disable-pip-version-check uv; \
    rm -rf /root/.cache/pip; \
    uv --version; \
    uvx --help >/dev/null

# OpenCode itself: the glibc release asset, verified against the published
# checksums. The archive contains a single `opencode` binary at its root.
# Running the binary during the build catches missing runtime libraries.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) asset="x64" ;; \
      arm64) asset="arm64" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}"; \
    curl -fsSL -o /tmp/opencode.tar.gz "$base/opencode-linux-${asset}.tar.gz"; \
    curl -fsSL -o /tmp/opencode-sums "$base/SHA256SUMS"; \
    (cd /tmp && grep " opencode-linux-${asset}.tar.gz\$" opencode-sums | sha256sum -c -); \
    tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin opencode; \
    rm -f /tmp/opencode.tar.gz /tmp/opencode-sums; \
    ln -sf opencode /usr/local/bin/opencode2; \
    opencode --version

# yq is not packaged by Debian (the `yq` package there is a different tool);
# install the upstream static binary, also checksum-verified.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) asset="amd64" ;; \
      arm64) asset="arm64" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}"; \
    curl -fsSL -o /tmp/yq "$base/yq_linux_${asset}"; \
    curl -fsSL -o /tmp/yq-sums "$base/checksums"; \
    (cd /tmp && grep " yq_linux_${asset}\$" yq-sums | sha256sum -c -); \
    install -m 0755 /tmp/yq /usr/local/bin/yq; \
    rm -f /tmp/yq /tmp/yq-sums; \
    yq --version

# Non-root user, the directories the agent writes to, and a git safe.directory
# entry: the mounted project belongs to the host user, which is not necessarily
# the image user.
RUN set -eux; \
    groupadd -g "${GID}" opencode; \
    useradd -u "${UID}" -g opencode -d /home/opencode -m -s /bin/bash opencode; \
    mkdir -p /home/opencode/projects \
             /home/opencode/.cache \
             /home/opencode/.config \
             /home/opencode/.local/share/opencode \
             /home/opencode/.local/state/opencode \
             /opt/uv/tools \
             /opt/uv/bin; \
    chown -R "${UID}:${GID}" /home/opencode /opt/uv; \
    git config --system --add safe.directory '*'

# Passwordless sudo lets the agent install Debian packages for the current
# session, whatever UID the container runs as (run commands pass --user or
# --userns=keep-id:uid=1000,gid=1000). The usage policy lives in
# config/opencode/AGENTS.md.
COPY config/sudoers.d/opencode /etc/sudoers.d/opencode
RUN chmod 0440 /etc/sudoers.d/opencode && visudo -cf /etc/sudoers

USER ${UID}:${GID}
ENV HOME=/home/opencode \
    SHELL=/bin/bash \
    PATH=/home/opencode/.local/bin:/opt/uv/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    UV_LINK_MODE=copy

# Development tooling at the versions published on build day. The tools are
# installed into isolated environments under /opt/uv/tools, with their
# executables in /opt/uv/bin (both writable by the container user, so runtime
# `uv tool` calls work too). The uv cache is removed: it lives outside the
# mounted state volume and would only bloat the image.
RUN set -eux; \
    for tool in ruff basedpyright mypy pytest pre-commit py-spy ast-grep-cli; do \
      UV_TOOL_DIR=/opt/uv/tools UV_TOOL_BIN_DIR=/opt/uv/bin \
        uv tool install --python /usr/local/bin/python3.14 "$tool"; \
    done; \
    [ -x /opt/uv/bin/sg ] || ln -s ast-grep /opt/uv/bin/sg; \
    uv tool list; \
    rm -rf /home/opencode/.cache/uv

# Bake the OpenCode configuration into the image. Secrets are not stored here:
# they are passed at runtime through environment variables.
USER 0
COPY --chown=${UID}:${GID} config/opencode/ /home/opencode/.config/opencode/
COPY --chown=${UID}:${GID} config/gitconfig /home/opencode/.gitconfig
COPY --chown=${UID}:${GID} .env.example /home/opencode/.env.example
COPY --chown=root:root config/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# Run commands make the image's user the host user (Podman:
# --userns=keep-id:uid=1000,gid=1000, Docker: --user $(id -u):$(id -g)), so
# files created by the agent keep host ownership. Whatever UID the container
# runs as must therefore be able to write everywhere the agent writes: the
# home directory (baked config, the state volume initialization source,
# caches) and the uv tool directories are world-writable. The container is a
# single-user trust boundary, so this does not widen the real exposure.
RUN chmod -R a+rwX /home/opencode /opt/uv

USER ${UID}:${GID}
WORKDIR /home/opencode/projects

# The default command is the interactive TUI, so a plain
# `docker run -it ... image` opens a session with no OpenCode installation on
# the host. Run the server explicitly for the web UI and the HTTP API:
# `docker run ... image opencode serve --hostname 0.0.0.0 --port 4096`.
# Any other command works too, for example
# `docker run ... image opencode run "Explain this repository"`.
EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["opencode"]
