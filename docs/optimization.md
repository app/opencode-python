# Optimization

The image is built for optimization work with Google OR-Tools, whatever runs
the session: the TUI, the web UI or an agent on the host over the HTTP API.
This page covers what is guaranteed and how to size the container; the
in-container workflow is written for the agent
([config/opencode/docs/ortools.md](../config/opencode/docs/ortools.md)).

## What is guaranteed

- OR-Tools is **not** baked into the image; it is a project dependency, so each
  project pins its own version. The image guarantees a compatible runtime and
  verifies it in CI.
- The base is Debian/glibc with native wheels for both architectures. OR-Tools
  publishes `manylinux_2_28` wheels for CPython 3.9 and newer on `x86_64` and
  `aarch64`, and publishes **no musllinux wheel and no source distribution**, so
  an Alpine image could not install it at all.
- The Python minor is fixed at 3.12, the interpreter the optimization project
  targets: `resolve-versions.sh` builds the image on the newest
  `python:3.12.Y-slim` and verifies that the newest `ortools` still publishes a
  `cp312` wheel (OR-Tools has no source distribution). The 3.13/3.14 wheels are
  not used: OR-Tools 9.15 crashes intermittently in multi-threaded CP-SAT there
  ([google/or-tools#5025](https://github.com/google/or-tools/issues/5025)).
- The CI smoke test installs OR-Tools in a throwaway environment and solves a
  small CP-SAT model on `linux/amd64` **and** `linux/arm64`, which is exactly
  what Apple Silicon users get.

## Solvers

| Solver      | Package                | Notes                                                  |
| ----------- | ---------------------- | ------------------------------------------------------ |
| CP-SAT      | `ortools`              | constraint programming / MIP, the main OR-Tools solver |
| GLOP        | `ortools`              | linear programming                                     |
| SCIP        | `ortools` (`pywraplp`) | mixed-integer programming, bundled with OR-Tools       |
| HiGHS       | `highspy`              | fast open-source LP/MIP, separate package              |
| PuLP, Pyomo | `pulp`, `pyomo`        | modeling layers over the solvers above                 |

All of these install from wheels on both architectures. Commercial solvers
(Gurobi, CPLEX) are not part of the image; they need their own licences and are
installed per project if you have them.

## Resources

CP-SAT uses all visible cores by default and keeps a search tree in memory.
Give the container room (run from the project directory):

```bash
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 \
  --cpus 4 --memory 8g \
  --name "opencode-$$" \
  -v "$PWD:/home/opencode/projects/$(basename "$PWD")" \
  -v opencode-python-state-$(id -un):/home/opencode/.local \
  --detach-keys="ctrl-],ctrl-q" \
  ghcr.io/app/opencode-python:latest
```

- Cap the search with `solver.parameters.num_search_workers = N` when the
  container has fewer CPUs than the host.
- `solver.parameters.max_time_in_seconds` keeps exploratory runs bounded.
- Docker Desktop and Podman machine default to a small VM; raise the VM memory
  (8 GB is a comfortable default) rather than only the container limit.
- With the [launcher](installation.md#the-launcher-optional), the same is
  `OPENCODE_PY_RUN_ARGS="--cpus 4 --memory 8g" opencode-py`.

## Notes

- OR-Tools pins `protobuf<6.34`; do not force a newer protobuf alongside it.
- Solver output goes to stdout/stderr inside the container; keep
  `num_search_workers` reasonable when running in server mode so the TUI stays
  responsive.
- Kernels and notebooks are not baked in. Ask the agent to add `jupyterlab` to
  the project and publish the port as in [Usage](usage.md) if you want them.
