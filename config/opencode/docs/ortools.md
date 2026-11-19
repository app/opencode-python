# OR-Tools

OR-Tools is a project dependency, not part of the image: each project pins its
own version and the image guarantees a compatible runtime.

## Install

```bash
uv add ortools
```

The project lockfile is the source of truth; do not install OR-Tools into the
system interpreter. Wheels exist for glibc only (`manylinux`), which is why the
image is Debian-based.

## Versions and Python

OR-Tools publishes `manylinux` wheels for CPython 3.9 and newer, without a
source distribution. The image runs CPython 3.12, which OR-Tools 9.15 supports
with `cp312` wheels. Stay on 3.12: the `cp313`/`cp314` wheels of OR-Tools
9.15.6755 have a known intermittent CP-SAT crash
([google/or-tools#5025](https://github.com/google/or-tools/issues/5025)) that is
fixed only on main, not in any 9.15 patch release.

OR-Tools pins `protobuf<6.34`; do not force a newer protobuf into the same
environment.

## CP-SAT

CP-SAT uses all visible cores and keeps a search tree in memory. The user gives
the container room with `--cpus` and `--memory`; cap the search when needed:

- `solver.parameters.num_search_workers = N` when the container has fewer CPU
  cores than the host.
- `solver.parameters.max_time_in_seconds` keeps exploratory runs bounded.

Solver output goes to stdout/stderr; keep `num_search_workers` reasonable in
server mode so the session stays responsive.

## Other solvers

`ortools` bundles GLOP, CP-SAT and SCIP (`pywraplp`); HiGHS is the separate
`highspy` package (`uv add highspy`). PuLP and Pyomo are modeling layers over
them. Commercial solvers are not part of the image.

## Profiling

`py-spy` profiles native frames, including OR-Tools calls:

```bash
py-spy top -- uv run python model.py
py-spy record -o profile.svg -- uv run python model.py
```
