# P0 — Implement position-aware outer tile aperture model

Labels: `P0`, `modeling`, `physics`, `paper-1`

## Problem

`compilePhysicalResponse` only uses `histcounts(tile_map(:))`; tile row/column positions do not enter propagation or aperture phase. Equal channel counts therefore produce identical responses regardless of spatial arrangement.

## Scope

- Define physical coordinates and dimensions for every outer macro-cell.
- Map macro-cell coordinates to the illuminated aircraft/metasurface aperture.
- Include local path, aperture phase and observation direction in the complex response.
- Preserve the current count-only model as an explicit fine-interleaving limiting baseline.

## Acceptance

- Two maps with equal counts but different layouts can produce different finite-aperture responses.
- A convergence test shows when increasingly fine interleaving approaches the count-only baseline.
- Axes, phase sign, units and normalization are documented and tested.

