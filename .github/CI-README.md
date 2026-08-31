# Continuous integration

SAO runs the same discipline as CAO, adapted to this repository's Project
Zomboid and governed-history contracts.

| Check | Contract |
|---|---|
| `ci-verify` | Checks committed diff hygiene, runs the full border gate (`tools/check.sh`), and proves every mirror in `tools/` is wired into the gate. Borders that read the installed game report SKIPPED rather than passing. |
| `codeql-python` | Advisory code scanning over `tools/` on pull requests, `main`, and the weekly schedule. |

`ci-verify` is the required merge gate on `main` and is also the pre-commit
hook's content. CodeQL is an additional signal; a service delay in it does not
move the repository's deterministic merge boundary.

There is no dependency scan because there is no dependency graph to scan:
the mod ships Lua and a self-built Java jar, and `tools/` runs on the Python
standard library alone. If a dependency manifest ever enters the tree, this
note is wrong by construction and the workflow is added with it.

CI never deploys into the operator's Project Zomboid installation, launches
the game, edits a save, or claims play acceptance.
