#!/usr/bin/env bash
#
# Resolve the upstream versions used by the image build.
#
# Prints KEY=VALUE lines to stdout:
#   opencode=<semver>  newest stable OpenCode release
#   ortools=<semver>   newest OR-Tools release (PyPI)
#   python=<semver>    newest CPython 3.12 patch release
#   yq=<semver>        newest mikefarah/yq release
#
# The Python minor is fixed at 3.12, the interpreter of the optimization
# project this image serves (PyCharm virtual environment). OR-Tools publishes
# manylinux wheels only, without a source distribution, so the newest OR-Tools
# release must still ship a cp312 wheel; the script fails otherwise. The newer
# cp313/cp314 wheels are not used: OR-Tools 9.15 has a known intermittent
# CP-SAT crash there (google/or-tools#5025), and the project targets 3.12. For
# the fixed minor the newest python:3.12.Y-slim tag on Docker Hub is used.
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
# The project targets CPython 3.12; only the patch release moves.
PY_MINOR=12
PYTHON=""
# OR-Tools must still build a wheel for that minor: there is no source
# distribution to fall back to.
if jq -e --arg tag "-cp3${PY_MINOR}-" \
  '[.urls[].filename | select(contains($tag))] | length > 0' \
  <<<"$ORTOOLS_JSON" >/dev/null; then
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
