# Test results

## Import

- ZIP SHA-256: `f7a78ff62f1031dfd6aa97440375067b25849f72bee7a2430bb7f4cb16e4f923`
- ZIP integrity: PASS
- Baseline checksums: PASS, 872/872

## Python

- `python3 tests/validate_repository.py --full`: PASS
- `python3 -m unittest tests/test_harmonic_model.py -v`: PASS, 4/4
- `python3 tests/scan_secrets.py`: PASS, high-confidence findings 0

## MATLAB R2025a

- Command: `python3 tests/run_local_matlab_smoke.py`
- Status: PASS
- `|C+1| = 0.900316316157`
- `|S+1| = 0.823639103546`
- `|S-3| = 1.963e-16`
- `|S+5| = 9.211e-16`
- `|A(+1,+1)| = 0.549875229298` (`-5.195 dB` amplitude ratio)
- Artifacts: `outputs/smoke_test/`

The test is L0 coefficient/area/frequency mapping validation, not a full 700-point SAR recomputation.

