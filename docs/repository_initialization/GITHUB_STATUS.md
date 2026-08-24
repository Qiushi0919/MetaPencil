# GitHub initialization status

## Remote

- URL: `https://github.com/Qiushi0919/MetaPencil`
- Visibility: **PUBLIC**（按项目负责人明确要求变更）
- Default branch: `main`
- Remote main: synchronized with local `main` at final handoff; resolve with `git rev-parse origin/main`.
- Baseline tag pushed: `handoff-v1.0-20260824`
- Git-ready tag pushed: `handoff-v1.1-git-ready`
- Release: `https://github.com/Qiushi0919/MetaPencil/releases/tag/handoff-v1.1-git-ready`
- CI: `Repository checks` PASS on commit `125676b`.

## Created collaboration objects

- 8 open Issues: #1–#8.
- Milestones: `Paper-1 Core`, `Spatial Model v2`, `Prototype v0.1`.
- Priority/model/reproducibility/hardware/data labels.

## Resolved workflow-push event

The first repository-creation push refused the commit that introduced `.github/workflows/repository-checks.yml`. The repository was then initialized non-destructively through the preceding verified commit. A later ordinary fast-forward push of full `main` and the Git-ready tag succeeded; no force push, tag rewrite or history rewrite was used. There is no remaining sync blocker.

Normal future synchronization is:

```bash
git push origin main
git push origin --tags
```

Do not paste a token into project files or terminal history.

## Force-push protection

After the explicit Public visibility change, the stored protection payload was successfully applied to `main`: `allow_force_pushes=false` and `allow_deletions=false`. Required reviews/status checks remain unset so ordinary authorized fast-forward maintenance is still possible.

Public visibility does not create an open-source license. See `LICENSE_PENDING.md`; third-party literature, presentations and models still require permission review.
