# MetaPencil Git initialization review

## Outcome

Imported the byte-verified 2026-08-24 handoff as an immutable baseline, added private-repository policy, AI collaboration context, test tooling, actual MATLAB smoke artifacts, Issue/PR templates and a minimal Python CI workflow. No core MATLAB algorithm or historical baseline result was changed.

## Most important audit findings

1. `tile_map` positions do not currently enter the simulated aperture; only per-channel counts and area weights are used.
2. Every H_k currently multiplies an area-weighted full-aircraft complex response; scatterers are not owned by physical macro-cells.

These are documented as P0 Issues #1 and #2, not silently corrected in this initialization.

## Remote caveat

The repository is private and remote main contains commits through the recorded MATLAB smoke output. The CI commit remains local because the current OAuth token lacks GitHub's `workflow` scope. The complete state is preserved in the verified Git bundle.

