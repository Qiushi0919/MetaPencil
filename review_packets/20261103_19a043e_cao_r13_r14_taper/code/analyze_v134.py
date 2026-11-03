"""Compare audited V1/V3/V4 at identical direct points; never certify four states.

Run analyze_pairs.py ROUND first, then this script with ROUND REFERENCE_ANALYSIS.
The reference must be a complete seven-state diagnostic from one geometry.
"""
from pathlib import Path
import hashlib
import json
import re
import sys
import numpy as np
from native_structure import audit_native

B = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(B.parent / 'Wang两PIN_9至10GHz优化_20261102/code'))
from analyze import audit_one, wrap


def compare(roundname, reference):
    assert re.fullmatch(r'r[0-9]{2,3}[a-z]?', roundname)
    read = lambda p: json.loads(p.read_text())
    specs = read(B / 'code' / f'rlc-{roundname}-cases.json')
    states = ['H1V1', 'H1V3', 'H1V4']
    selected = [next(s for s in specs if s['state'] == state) for state in states]
    assert len({s['candidate'] for s in selected}) == 1
    geom = lambda s: [(t, re.sub(r'(?m)^ \.Set[RC] "[^"]+"', '', c)) for t, c in s['history']]
    assert all(geom(s) == geom(selected[0]) for s in selected)
    prior = read(B / reference / 'seven_state_diagnostic.json')
    assert len(prior['audits']) == 7
    assert prior['metrics']['V']['states'] == ['H1V1', 'H1V2', 'H1V3', 'H1V4']
    freq = selected[0]['frequencies_GHz']
    assert freq == prior['frequency_GHz']
    outdir = B / f'analysis_{roundname}'
    rows, audits = [], []
    E0 = Z0 = None
    for s in selected:
        assert s['frequencies_GHz'] == freq
        d = outdir / 'native/runs' / s['id']
        assert audit_native(d, s, write_report=False) == audit_native(d / 'postsolve_geometry', s, write_report=False)
        assert (d / 'ModelHistory.json').read_bytes() == (d / 'postsolve_geometry/ModelHistory.json').read_bytes()
        gate = read(d / 'postsolve_geometry/verified.json')
        assert all(gate[k] for k in ['actual_saved_history_unchanged', 'actual_parts_rechecked', 'before_curve_export'])
        S, E, Z, a = audit_one(d, s)
        if E0 is None:
            E0, Z0 = E, Z
        assert np.allclose(E, E0, atol=1e-5, rtol=1e-5)
        assert np.allclose(Z, Z0, atol=1e-5, rtol=1e-5)
        rows.append(S[:, 1, 1])
        a['converged_last_two_deltaS_at_9_5GHz'] = len(a['deltaS']) >= 2 and all(v < .03 for v in a['deltaS'][-2:])
        audits.append(a)
    rows = np.array(rows)
    relative = wrap(np.angle(rows / rows[0], deg=True))
    ideal = np.array([0., -180., 90.])[:, None]
    error = wrap(relative - ideal)
    amp = 20 * np.log10(np.abs(rows))
    prev = prior['metrics']['V']
    ix = [prev['states'].index(s) for s in states]
    prevrelative = np.array(prev['relative_phase_deg'])[ix]
    prevamp = np.array(prev['amplitude_dB'])[ix]
    result = {
        'round': roundname, 'reference': reference, 'states': states,
        'frequency_GHz': freq, 'same_direct_points': True, 'interpolation': False,
        'ideal_relative_deg': ideal[:, 0].tolist(), 'relative_phase_deg': relative.tolist(),
        'phase_error_deg': error.tolist(), 'amplitude_dB': amp.tolist(),
        'delta_relative_deg': wrap(relative - prevrelative).tolist(),
        'delta_amplitude_dB': (amp - prevamp).tolist(),
        'worst_relative_error_deg': float(abs(error).max()),
        'reference_worst_relative_error_deg': float(abs(wrap(prevrelative - ideal)).max()),
        'minimum_amplitude_dB': float(amp.min()), 'reference_minimum_amplitude_dB': float(prevamp.min()),
        'V3_to_V4_adjacent_error_deg': wrap(relative[2] - relative[1] + 90).tolist(),
        'V4_to_V1_adjacent_error_deg': wrap(-relative[2] + 90).tolist(),
        'convergence_scope_GHz': [9.5], 'audits': audits,
        'case_sha256': hashlib.sha256((B / 'code' / f'rlc-{roundname}-cases.json').read_bytes()).hexdigest(),
        'complete_four_state_phase_checked': False, 'two_bit_certified': False,
        'limitation': 'V2 and H2/H3/H4 not evaluated in this subset; no full cyclic or whole-band certification. Fixed scaled diagnostic RLC, native power-wave S,20log10|S|.'
    }
    output = outdir / f'v134_vs_{reference}.json'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(output)
    return result


if __name__ == '__main__':
    compare(sys.argv[1], sys.argv[2])
