# Fresh-clone validation

Validation date: 2026-08-24

## Source

- Mode: clone from verified Git bundle
- Validated commit: `0a49749deeab7153b3e2f768a873e8bca8f5df8a`
- Branch: `main`
- Initial worktree: clean

The bundle route was deliberately used to validate offline recovery independently of GitHub. During the first clone run the GitHub remote was temporarily behind because the initial workflow-containing push was refused; the later ordinary fast-forward sync succeeded, and remote `main` now contains the validated commit.

## Checks

| Check | Result |
|---|---|
| README exists and is readable | PASS |
| `PROJECT_STATE.json` parses | PASS |
| Required repository structure | PASS |
| Imported baseline SHA-256 | PASS, 872/872 |
| Python ideal harmonic tests | PASS, 4/4 |
| High-confidence credential scan | PASS, 0 findings |
| Required Git LFS pointers | 0 |
| MATLAB R2025a smoke test | PASS |
| Smoke output directory writable | PASS |

MATLAB reproduced `|C+1|=0.900316316157`, `|S+1|=0.823639103546`, `|S-3|=1.963e-16`, `|S+5|=9.211e-16` and `|A(+1,+1)|=0.549875229298`.

The smoke test intentionally updates tracked test artifacts. After verifying those outputs, the five generated modifications were restored inside the disposable clone; final clone status was clean. No user data were altered.
