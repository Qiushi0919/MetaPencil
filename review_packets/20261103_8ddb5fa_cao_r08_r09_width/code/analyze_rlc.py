"""Audit saved geometry before interpreting the fixed-order seven-state X-band screen."""
from pathlib import Path
import csv, hashlib, json, re, sys, zipfile
import numpy as np
from shapely.geometry import Polygon, Point

B = Path(__file__).resolve().parents[1]
R = Path(sys.argv[2]).resolve() if len(sys.argv)>2 else B/'Results_rlc_base_v1'
OUT = Path(sys.argv[3]).resolve() if len(sys.argv)>3 else B/'analysis_rlc_base_v1'
OUT.mkdir(exist_ok=True)
sys.path.insert(0, str(B.parent / 'Wang两PIN_9至10GHz优化_20261102/code'))
from analyze import audit_one, wrap

read = lambda p: json.loads(p.read_text())
specs = read(Path(sys.argv[1])) if len(sys.argv)>1 else read(B/'code/rlc-base-cases.json')
assert len(specs) == 7
freq = np.array(specs[0]['frequencies_GHz'])
geom = lambda s: [(t, re.sub(r'(?m)^ \.Set[RC] "[^"]+"', '', c)) for t, c in s['history']]
assert all(geom(s) == geom(specs[0]) for s in specs)

from native_structure import audit_native

def geometry_audit(p,spec):
    post=p/'postsolve_geometry';gate=read(post/'verified.json')
    assert all(gate[k] for k in ['actual_saved_history_unchanged','actual_parts_rechecked','before_curve_export'])
    assert read(p/'native_structure_audit.json')['passed'] and read(post/'native_structure_audit.json')['passed']
    assert (post/'ModelHistory.json').read_bytes()==(p/'ModelHistory.json').read_bytes()
    assert (post/'native_parts.csv').read_bytes()==(p/'native_parts.csv').read_bytes()
    before=audit_native(p,spec,write_report=False);after=audit_native(post,spec,write_report=False);assert before==after
    return after

vals, audits, archives = {}, [], []
basis = zref = None
for spec in specs:
    root = R
    archive = root / 'case_snapshots' / (spec['id'] + '.zip')
    if len(sys.argv)==1 and not archive.exists():
        root = B/'Results_rlc_base_v1r1'
        archive = root/'case_snapshots'/(spec['id']+'.zip')
    archives.append({'path': str(archive), 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()})
    with zipfile.ZipFile(archive) as z:
        for n in z.namelist():
            assert n.startswith('runs/' + spec['id'] + '/') and '..' not in Path(n).parts
            target = OUT / 'native' / n
            data = z.read(n)
            if target.exists():
                if target.name=='native_structure_audit.json' and target.read_bytes()!=data:
                    assert json.loads(target.read_bytes())==json.loads(data),'Audit report content changed';target.write_bytes(data)
                assert target.read_bytes()==data
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
    p = OUT / 'native/runs' / spec['id']
    ga = geometry_audit(p, spec)
    S, E, Z, audit = audit_one(p, spec)
    if basis is None: basis, zref = E, Z
    assert np.allclose(E, basis, atol=1e-5, rtol=1e-5)
    assert np.allclose(Z, zref, atol=1e-5, rtol=1e-5)
    vals[spec['state']] = S
    audit.update(geometry=ga, converged_last_two_deltaS=len(audit['deltaS']) >= 2 and max(audit['deltaS'][-2:]) < .03)
    audits.append(audit)

metrics, rows = {}, []
for pol, ids, ch in [('H', [f'H{i}V1' for i in range(1, 5)], 0), ('V', [f'H1V{i}' for i in range(1, 5)], 1)]:
    co = np.array([vals[s][:, ch, ch] for s in ids])
    phase = np.angle(co, deg=True)
    amp = 20 * np.log10(abs(co))
    rel = wrap(np.angle(co / co[0], deg=True))
    err = wrap(rel + 90 * np.arange(4)[:, None])
    step = np.angle(np.roll(co, -1, axis=0) / co, deg=True)
    adjerr = wrap(step + 90)
    score = np.maximum(abs(err).max(axis=0), abs(adjerr).max(axis=0))
    ctrl = np.array([vals[s][:, 1-ch, 1-ch] for s in ids])
    metrics[pol] = dict(states=ids, phase_deg=phase.tolist(), amplitude_dB=amp.tolist(), relative_phase_deg=rel.tolist(),
                        phase_error_deg=err.tolist(), cyclic_adjacent_phase_deg=step.tolist(), cyclic_adjacent_error_deg=adjerr.tolist(),
                        max_relative_error_deg=abs(err).max(axis=0).tolist(), max_cyclic_adjacent_error_deg=abs(adjerr).max(axis=0).tolist(),
                        max_combined_error_deg=score.tolist(), minimum_amplitude_dB=amp.min(axis=0).tolist(),
                        paper_adjacent20_pass_frequencies_GHz=freq[abs(adjerr).max(axis=0) <= 20].tolist(),
                        paper_minus1dB_pass_frequencies_GHz=freq[amp.min(axis=0) >= -1].tolist(),
                        fixed_other_phase_drift_deg=wrap(np.angle(ctrl / ctrl[0], deg=True)).tolist(),
                        fixed_other_amplitude_drift_dB=(20*np.log10(abs(ctrl) / abs(ctrl[0]))).tolist())
    for i, s in enumerate(ids):
        for j, f in enumerate(freq):
            rows.append(dict(polarization=pol, state=s, frequency_GHz=f, amplitude_dB=amp[i,j], phase_deg=phase[i,j],
                             relative_phase_deg=rel[i,j], phase_error_deg=err[i,j], cyclic_next_phase_deg=step[i,j],
                             cyclic_adjacent_error_deg=adjerr[i,j]))

# The ideal fixed physical order must yield zero in both error definitions.
ideal = np.exp(-1j*np.arange(4)*np.pi/2)
assert np.max(abs(wrap(np.angle(ideal / ideal[0], deg=True) + 90*np.arange(4)))) < 1e-10
assert np.max(abs(wrap(np.angle(np.roll(ideal, -1)/ideal, deg=True) + 90))) < 1e-10
out = dict(frequency_GHz=freq.tolist(), completed=list(vals), audits=audits, metrics=metrics, archives=archives,
           normalization='Native positive-real-impedance power-wave S; amplitude = 20 log10 |S|; no amplitude renormalization',
           phase_definition='Relative arg(S_s/S_1); ideal [0,-90,-180,+90] deg; error wrap(relative+90s); cyclic error wrap(arg(S_next/S_s)+90)',
           no_state_sort_or_fit_or_conjugation=True, model_level='Periodic full-wave fixed scaled-RLC screen; not hardware validation',
           seven_states_only_not_full_16_combination_independence=True,
           entire_band_certified=False, convergence_certified=all(a['converged_last_two_deltaS'] for a in audits),
           assumptions=specs[0]['assumptions'], migration=specs[0]['migration'])
(OUT / 'seven_state_diagnostic.json').write_text(json.dumps(out, ensure_ascii=False, indent=2))
with (OUT / 'seven_state_data.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
colors = ['#1976d2','#ef6c00','#00897b','#8e24aa']
fig, axes = plt.subplots(2, 3, figsize=(15, 8), constrained_layout=True)
for r, (pol, m) in enumerate(metrics.items()):
    for i, state in enumerate(m['states']):
        axes[r,0].plot(freq, m['amplitude_dB'][i], 'o-', color=colors[i], label=state)
        axes[r,1].plot(freq, m['phase_deg'][i], 'o-', color=colors[i], label=state)
    axes[r,0].set(title=f'{pol}: co-polar amplitude', ylabel='20 log10 |S| (dB)')
    axes[r,1].set(title=f'{pol}: native wrapped phase', ylabel='Phase (deg)', ylim=(-185,185))
    axes[r,2].plot(freq,m['max_relative_error_deg'],'o-',label='Max relative error')
    axes[r,2].plot(freq,m['max_cyclic_adjacent_error_deg'],'s-',label='Max cyclic adjacent error')
    axes[r,2].axhline(20,color='red',ls='--',lw=1,label='20 deg adjacent tolerance')
    axes[r,2].set(title=f'{pol}: fixed-order phase error',ylabel='Error (deg)')
    for ax in axes[r]:ax.set_xlabel('Frequency (GHz)');ax.grid(alpha=.25);ax.legend(fontsize=8)
fig.suptitle(f'Cao X-band {specs[0].get("candidate", "baseline")} | fixed scaled RLC | {len(freq)} direct samples | coarse mesh',fontsize=15)
fig.savefig(OUT/'xband_amplitude_phase_errors.png',dpi=170);plt.close(fig)

fig, axs = plt.subplots(1, 2, figsize=(11,7), subplot_kw={'projection':'polar'})
fi=list(freq).index(9.5)
for ax,(pol,m) in zip(axs,metrics.items()):
    ax.set_theta_zero_location('E');ax.set_ylim(0,1.08);ax.set_yticks([.25,.5,.75,1]);ax.grid(alpha=.3)
    for i,st in enumerate(m['states']):
        phase=m['relative_phase_deg'][i][fi];amp=m['amplitude_dB'][i][fi];theta=np.deg2rad(phase);rad=10**(amp/20)
        ax.plot([theta,theta],[0,rad],color=colors[i],lw=2)
        ax.plot(theta,rad,'o',color=colors[i],label=f'{st}: {phase:.1f} deg, {amp:.2f} dB')
        ideal=np.deg2rad(-90*i);ax.plot([ideal,ideal],[0,1],ls=':',color='#777',lw=.8,zorder=0)
    ax.set_title(f'{pol} at 9.5 GHz\nmax adjacent error {m["max_cyclic_adjacent_error_deg"][fi]:.1f} deg',pad=20)
    ax.legend(loc='lower center',bbox_to_anchor=(.5,-.5),fontsize=8,frameon=False)
fig.suptitle('Cao X-band seven-state coarse diagnostic | fixed scaled RLC',fontsize=13,y=.97)
fig.subplots_adjust(bottom=.30,top=.73,wspace=.4)
fig.savefig(OUT/'xband_phasors_9p5GHz.png',dpi=180);plt.close(fig)
print(json.dumps({'audits':[{k:a[k] for k in ['state','deltaS','converged_last_two_deltaS']} for a in audits],
                  'metrics':{p:{k:m[k] for k in ['max_relative_error_deg','max_cyclic_adjacent_error_deg','minimum_amplitude_dB','paper_adjacent20_pass_frequencies_GHz']} for p,m in metrics.items()}},indent=2))
