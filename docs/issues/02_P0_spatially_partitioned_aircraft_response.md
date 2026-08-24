# P0 — Partition aircraft scattering response by physical macro-cell

Labels: `P0`, `modeling`, `physics`, `paper-1`

## Problem

Every H_k currently multiplies the full-aircraft complex echo. The code does not assign scatterers or mesh facets to the physical sub-aperture that carries H_k.

## Scope

- Establish macro-cell to point/facet ownership and a boundary rule.
- Generate each partition echo from only its owned scatterers/facets.
- Sum partition echoes coherently at raw-data level.
- Compare uniform fine interleaving, contiguous blocks and irregular layouts.

## Acceptance

- Per-partition scatterer counts and total ownership are machine checked.
- Summing identical unmodulated partitions reconstructs the full-aircraft baseline within tolerance.
- Energy and phase bookkeeping is explicit; no image-domain copying is used.

