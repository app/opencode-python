#!/usr/bin/env python3
"""Smoke test: OR-Tools installs and solves a model inside the published image.

Run by the CI smoke step on every architecture, in a throwaway virtual
environment built by uv. It proves that the image ships an interpreter and
runtime libraries that the OR-Tools wheels work with.
"""

import sys
from importlib.metadata import version

from ortools.sat.python import cp_model


def main() -> None:
    model = cp_model.CpModel()
    x = model.NewIntVar(0, 10, "x")
    y = model.NewIntVar(0, 10, "y")
    model.Add(x + 2 * y <= 14)
    model.Maximize(3 * x + 2 * y)

    solver = cp_model.CpSolver()
    solver.parameters.num_search_workers = 1
    status = solver.Solve(model)
    if status != cp_model.OPTIMAL:
        raise SystemExit(f"unexpected solver status: {solver.StatusName(status)}")

    values = (solver.Value(x), solver.Value(y))
    if values != (10, 2):
        raise SystemExit(f"unexpected solution: x={values[0]} y={values[1]}")

    objective = solver.ObjectiveValue()
    if objective != 34:
        raise SystemExit(f"unexpected objective: {objective}")

    print(
        f"python {sys.version.split()[0]}, ortools {version('ortools')}, "
        f"cp-sat ok: x={values[0]} y={values[1]} objective={objective:.0f}"
    )


if __name__ == "__main__":
    main()
