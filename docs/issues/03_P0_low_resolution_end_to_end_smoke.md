# P0 — Add low-resolution end-to-end complex SAR smoke test

Labels: `P0`, `testing`, `reproducibility`

## Goal

Add a deterministic, small point-scatterer/LFM/RD run that exercises the real raw-echo and focusing chain in minutes suitable for local validation.

## Acceptance

- Fixed seed/geometry and a machine-readable run manifest.
- Checks expected target displacement, peak tolerance and image dimensions.
- Records MATLAB version, commit, duration and output hashes.
- Does not replace the existing L0 harmonic smoke test.

