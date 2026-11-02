"""Audit independent geometry pairs; never combine them into a 2-bit candidate."""
from pathlib import Path
import sys,json,zipfile,re,hashlib
import numpy as np
B=Path(__file__).resolve().parents[1];roundname=sys.argv[1];assert re.fullmatch(r'r[0-9]{2,3}[a-z]?',roundname)
sys.path.insert(0,str(B.parent/'Wang两PIN_9至10GHz优化_20261102/code'))
from analyze import audit_one,wrap
from native_structure import audit_native
read=lambda p:json.loads(p.read_text());specs=read(B/'code'/f'rlc-{roundname}-cases.json');R=B/f'Results_rlc_{roundname}_v1';O=B/f'analysis_{roundname}';O.mkdir(exist_ok=True)
base=read(B/'analysis_rlc_base_v1/seven_state_diagnostic.json');groups={s['candidate']:[] for s in specs};pending=[]
for s in specs:
 zpath=R/'case_snapshots'/(s['id']+'.zip')
 if not zpath.exists():pending.append(s['id']);continue
 with zipfile.ZipFile(zpath) as z:
  for n in z.namelist():
   assert n.startswith('runs/'+s['id']+'/') and '..' not in Path(n).parts
   d=O/'native'/n;data=z.read(n)
   if d.exists():
    if d.name=='native_structure_audit.json' and d.read_bytes()!=data:
     assert json.loads(d.read_bytes())==json.loads(data),'Audit report content changed';d.write_bytes(data)
    assert d.read_bytes()==data
   else:d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(data)
 d=O/'native/runs'/s['id'];before=audit_native(d,s,write_report=False);after=audit_native(d/'postsolve_geometry',s,write_report=False);assert before==after
 assert (d/'ModelHistory.json').read_bytes()==(d/'postsolve_geometry/ModelHistory.json').read_bytes()
 gate=read(d/'postsolve_geometry/verified.json');assert all(gate[k] for k in ['actual_saved_history_unchanged','actual_parts_rechecked','before_curve_export'])
 S,E,Z,a=audit_one(d,s);a.update(geometry=after,archive_sha256=hashlib.sha256(zpath.read_bytes()).hexdigest());groups[s['candidate']].append((s,S,E,Z,a))
records=[]
for name,rows in groups.items():
 # A partially finished multi-state batch is not a declared pair.
 if len(rows)!=2 or sum(s['candidate']==name for s in specs)!=2:continue
 rows.sort(key=lambda row:row[0]['state']!='H1V1');s0,S0,E0,Z0,a0=rows[0];s1,S1,E1,Z1,a1=rows[1]
 assert s0['state']=='H1V1' and s1['state'] in ['H2V1','H1V2']
 geom=lambda s:[(t,re.sub(r'(?m)^ \.Set[RC] "[^"]+"','',c)) for t,c in s['history']]
 assert geom(s0)==geom(s1);assert np.allclose(E0,E1,atol=1e-5,rtol=1e-5) and np.allclose(Z0,Z1,atol=1e-5,rtol=1e-5)
 ch=0 if s1['state']=='H2V1' else 1;pol='HV'[ch];freq=s0['frequencies_GHz'];assert freq==s1['frequencies_GHz'];ix=[next((i for i,x in enumerate(base['frequency_GHz']) if abs(x-f)<1e-8),None) for f in freq]
 pair=wrap(np.angle(S1[:,ch,ch]/S0[:,ch,ch],deg=True));prior=np.array([base['metrics'][pol]['relative_phase_deg'][1][i] if i is not None else np.nan for i in ix])
 amp=20*np.log10(np.abs(np.array([S0[:,ch,ch],S1[:,ch,ch]])))
 record=dict(candidate=name,polarization=pol,states=[s0['state'],s1['state']],frequency_GHz=freq,terminal_delta_mm=s0['optimization']['branch_terminal_delta_mm'],pair_relative_deg=pair.tolist(),pair_error_deg=wrap(pair+90).tolist(),baseline_pair_relative_deg=[float(x) if np.isfinite(x) else None for x in prior],change_from_baseline_deg=[float(x) if np.isfinite(x) else None for x in wrap(pair-prior)],baseline_comparison_exact_common_frequencies_only=True,amplitude_dB=amp.tolist(),minimum_amplitude_dB=amp.min(axis=0).tolist(),native_phase_deg=np.angle(np.array([S0[:,ch,ch],S1[:,ch,ch]]),deg=True).tolist(),audits=[a0,a1],complete_two_state_pair=True,two_bit_certified=False,model='fixed scaled RLC; coarse sensitivity only')
 record['launch_change']=s0['optimization'].get('launch_change')
 record['common_width_factor']=s0['optimization'].get('common_width_factor')
 records.append(record);print(name,pol,'errors',np.round(record['pair_error_deg'],2),'change',np.round(np.array(record['change_from_baseline_deg'],dtype=float),2),'minamp',np.round(record['minimum_amplitude_dB'],2))
(O/'pair_sensitivity.json').write_text(json.dumps({'round':roundname,'pairs':records,'completed_case_audits':[row[4] for rows in groups.values() for row in rows],'pending_cases':pending,'cannot_combine_different_geometries':True},ensure_ascii=False,indent=2)+'\n')
