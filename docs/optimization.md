# Optimization

The image is built for Python developers who work on optimization with Google
OR-Tools. This page covers what is guaranteed, how to start a project, how to
size the container, and what to do when a solver run needs more.

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

## Quick start

```bash
cd /home/opencode/projects/<your-project>
uv init
uv add ortools
uv run python - <<'PY'
from ortools.sat.python import cp_model

model = cp_model.CpModel()
x = model.NewIntVar(0, 10, "x")
y = model.NewIntVar(0, 10, "y")
model.Add(x + 2 * y <= 14)
model.Maximize(3 * x + 2 * y)

solver = cp_model.CpSolver()
solver.parameters.num_search_workers = 4
print(solver.Solve(model), solver.Value(x), solver.Value(y))
PY
```

A CP-SAT model over real data usually wants `pandas` (and `matplotlib` for
plots); add them the same way:

```bash
uv add pandas matplotlib
```

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
Give the container room:

```bash
podman run -it --rm --cpus 4 --memory 8g \
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

## Virtual environments

`uv` creates `.venv` in the project by default. A virtual environment with
OR-Tools is roughly 300 MB across thousands of files, which is slow on the
bind mount of a macOS VM. On Apple Silicon, keep it on the state volume
instead:

```bash
export UV_PROJECT_ENVIRONMENT=/home/opencode/.local/share/venv
```

The environment then lives next to the uv cache and survives container
restarts. The trade-off is that host-side tooling cannot reuse it (`.pinned`
and the lockfile in the project still define it).

## Profiling

`py-spy` profiles native frames, including OR-Tools solver calls, without
changing the code:

```bash
py-spy top -- uv run python model.py
py-spy record -o profile.svg -- uv run python model.py
```

## Notes

- OR-Tools pins `protobuf<6.34`; do not force a newer protobuf alongside it.
- Solver output goes to stdout/stderr inside the container; keep
  `num_search_workers` reasonable when running in server mode so the TUI stays
  responsive.
- Kernels and notebooks are not baked in. Add `jupyterlab` to the project
  (`uv add jupyterlab`, then `uv run jupyter lab --ip=0.0.0.0 --no-browser`) if
  you want them; publishing the port works the same way as the server mode in
  [Usage](usage.md).
