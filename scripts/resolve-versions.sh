#!/usr/bin/env bash
#
# Resolve the upstream versions used by the image build.
#
# Prints KEY=VALUE lines to stdout:
#   opencode=<semver>  newest stable OpenCode release
#   ortools=<semver>   newest OR-Tools release (PyPI)
#   python=<semver>    newest CPython that OR-Tools ships wheels for
#   yq=<semver>        newest mikefarah/yq release
#
# OR-Tools publishes manylinux wheels only, without a source distribution, so it
# decides which Python minor the image can use: its wheels are tagged cp3XY
# (plus free-threaded cp3XYt, which is ignored), and for that minor the newest
# python:3.X.Y-slim tag on Docker Hub is used.
#
# Used by the GitHub Actions workflow. The update-pins job compares the result
# against versions.json and opens a pull request when they differ.

set -euo pipefail

GITHUB_API="https://api.github.com"
AUTH=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

# Newest stable tag of a GitHub repository. Prereleases, dev and moving tags
# are filtered out by the semver pattern.
latest_release() {
  local repo="$1" pattern="$2"
  curl -fsS ${AUTH[@]+"${AUTH[@]}"} \
    "${GITHUB_API}/repos/${repo}/releases?per_page=100" |
    jq -r '.[] | select(.prerelease == false) | .tag_name' |
    sed -E 's/^v//' |
    grep -E "$pattern" |
    sort -V |
    tail -n 1 || true
}

# Newest python:3.<minor>.<patch>-slim tag for a given minor version.
newest_python_slim() {
  local minor="$1"
  curl -fsS \
    "https://hub.docker.com/v2/repositories/library/python/tags?page_size=100&name=3.${minor}." |
    jq -r '.results[].name' |
    grep -E "^3\.${minor}\.[0-9]+-slim$" |
    sed -E 's/-slim$//' |
    sort -V |
    tail -n 1 || true
}

OPENCODE="$(latest_release "anomalyco/opencode" '^[0-9]+\.[0-9]+\.[0-9]+$')"
YQ="$(latest_release "mikefarah/yq" '^[0-9]+\.[0-9]+\.[0-9]+$')"

ORTOOLS_JSON="$(curl -fsS "https://pypi.org/pypi/ortools/json")"
ORTOOLS="$(jq -r '.info.version' <<<"$ORTOOLS_JSON")"
# Highest CPython minor that the newest OR-Tools release builds wheels for.
PY_MINOR="$(
  jq -r '
    [.urls[].filename | select(test("-cp3[0-9]+t?-")) | capture("-cp3(?<minor>[0-9]+)t?-").minor | tonumber]
    | max // empty
  ' <<<"$ORTOOLS_JSON"
)"
PYTHON=""
if [[ -n "$PY_MINOR" ]]; then
  PYTHON="$(newest_python_slim "$PY_MINOR")"
fi

fail=0
for pair in "opencode:${OPENCODE}" "ortools:${ORTOOLS}" "python:${PYTHON}" "yq:${YQ}"; do
  name="${pair%%:*}"
  value="${pair#*:}"
  if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Could not resolve ${name} (got '${value}')." >&2
    fail=1
  fi
done
if ((fail)); then
  exit 1
fi

echo "opencode=${OPENCODE}"
echo "ortools=${ORTOOLS}"
echo "python=${PYTHON}"
echo "yq=${YQ}"
