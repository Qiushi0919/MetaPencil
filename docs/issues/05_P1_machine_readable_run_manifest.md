# P1 — Create a machine-readable run manifest for every result

Labels: `P1`, `reproducibility`, `tooling`

## Goal

Standardize JSON metadata for code commit, dirty state, entrypoint, arguments, radar/metasurface parameters, model level, random seed, environment, normalization and artifact hashes.

## Acceptance

- JSON schema and validator are committed.
- New runs fail or warn when commit/parameter metadata are missing.
- At least one historical baseline and the smoke test are represented.

