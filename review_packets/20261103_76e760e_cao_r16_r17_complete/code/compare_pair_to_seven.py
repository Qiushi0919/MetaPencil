"""Compare an audited declared two-state screen to matching rows of a seven-state reference.
Usage: compare_pair_to_seven.py ROUND REFERENCE_ANALYSIS OUTPUT_JSON
All direct frequencies must match. This never certifies full four-state performance.
"""
from pathlib import Path
import sys,json,hashlib
import numpy as np
B=Path(__file__).resolve().parents[1]
def compare(roundname,reference):
 pp=B/f'analysis_{roundname}/pair_sensitivity.json';rp=B/reference/'seven_state_diagnostic.json'
 p=json.loads(pp.read_text());a=json.loads(rp.read_text());assert not p['pending_cases'] and len(p['pairs'])==1
 q=p['pairs'][0];assert len(q['audits'])==2 and all(x['native_audit_pass'] for x in q['audits']);assert len(a['audits'])==7
 assert q['frequency_GHz']==a['frequency_GHz'],'Exact complete frequency grid required'
 m=a['metrics'][q['polarization']];indices=[m['states'].index(s) for s in q['states']];assert indices==[0,1]
 f=np.array(q['frequency_GHz']);old=np.array(m['phase_error_deg'][1]);new=np.array(q['pair_error_deg']);oldamp=np.array(m['amplitude_dB'][:2]);newamp=np.array(q['amplitude_dB'])
 d={'candidate':q['candidate'],'round':roundname,'reference':reference,'frequency_GHz':f.tolist(),'all_direct_points_identical':True,'interpolation':False,'source_sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in [pp,rp]},'pair_error_deg':new.tolist(),'reference_pair_error_deg':old.tolist(),'change_relative_deg':((new-old+180)%360-180).tolist(),'worst_error_deg':float(abs(new).max()),'reference_worst_error_deg':float(abs(old).max()),'min_amp_dB':float(newamp.min()),'reference_min_amp_dB':float(oldamp.min()),'amplitude_dB':newamp.tolist(),'reference_amplitude_dB':oldamp.tolist(),'signed_endpoint_change_deg_per_GHz':float((new[-1]-new[0])/(f[-1]-f[0])),'reference_signed_endpoint_change_deg_per_GHz':float((old[-1]-old[0])/(f[-1]-f[0])),'local_error_slopes_deg_per_GHz':(np.diff(new)/np.diff(f)).tolist(),'reference_local_error_slopes_deg_per_GHz':(np.diff(old)/np.diff(f)).tolist(),'pair_pass_samples_GHz':f[abs(new)<=20].tolist(),'audits':[{'state':s['state'],'native_audit_pass':s['native_audit_pass'],'last_two_deltaS':s['deltaS'][-2:],'last_two_below_003':len(s['deltaS'])>=2 and all(v<.03 for v in s['deltaS'][-2:])} for s in q['audits']],'two_bit_certified':False,'convergence_scope_GHz':[9.5],'entire_band_convergence_verified':False}
 d['center_converged_states']=sum(s['last_two_below_003'] for s in d['audits']);return d
if __name__=='__main__':
 out=Path(sys.argv[3]);assert not out.exists(),'Choose new output to preserve prior evidence'
 d=compare(sys.argv[1],sys.argv[2]);out.write_text(json.dumps(d,indent=2)+'\n');print({k:d[k] for k in ['worst_error_deg','reference_worst_error_deg','min_amp_dB','reference_min_amp_dB','center_converged_states']})
