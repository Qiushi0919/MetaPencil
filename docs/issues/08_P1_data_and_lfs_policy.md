# P1 — Operationalize data retention and Git LFS policy

Labels: `P1`, `data`, `repository`

## Goal

Install Git LFS where available, classify required large assets and document external storage for reproducible but unsuitable intermediates.

## Acceptance

- No committed file exceeds GitHub limits.
- Required large immutable assets have license, checksum, provenance and LFS/external location.
- Recomputable MAT/FIG intermediates have manifests rather than silent omission.
- A fresh clone can obtain all required test inputs.

