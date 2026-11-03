"""Compare two audited seven-state diagnostics at identical direct frequencies."""
import sys,json,hashlib
from pathlib import Path
import numpy as np

def compare(reference,candidate):
 a_path=Path(reference).resolve();b_path=Path(candidate).resolve()
 assert a_path!=b_path,'Reference and candidate must be distinct files'
 a=json.loads(a_path.read_text());b=json.loads(b_path.read_text())
 assert a['frequency_GHz']==b['frequency_GHz']
 assert len(a['audits'])==len(b['audits'])==7
 out={'reference':str(a_path),'candidate':str(b_path),'source_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [a_path,b_path]},'frequency_GHz':b['frequency_GHz'],'same_direct_points':True,'interpolation':False,'convergence_scope_GHz':[9.5],'entire_band_convergence_verified':False,'metrics':{}}
 for pol in ['H','V']:
  x,y=a['metrics'][pol],b['metrics'][pol];assert x['states']==y['states']
  delta=lambda key:(np.array(y[key])-np.array(x[key])).tolist()
  phase=(np.array(y['relative_phase_deg'])-np.array(x['relative_phase_deg'])+180)%360-180
  out['metrics'][pol]={'states':y['states'],'reference_worst_relative_deg':max(x['max_relative_error_deg']),'worst_relative_deg':max(y['max_relative_error_deg']),'reference_worst_cyclic_deg':max(x['max_cyclic_adjacent_error_deg']),'worst_cyclic_deg':max(y['max_cyclic_adjacent_error_deg']),'reference_min_amp_dB':min(x['minimum_amplitude_dB']),'min_amp_dB':min(y['minimum_amplitude_dB']),'delta_relative_deg':phase.tolist(),'max_abs_relative_change_deg':float(abs(phase).max()),'delta_amplitude_dB':delta('amplitude_dB'),'phase_error_deg':y['phase_error_deg'],'cyclic_adjacent_error_deg':y['cyclic_adjacent_error_deg'],'both_phase_pass_samples_GHz':[f for i,f in enumerate(b['frequency_GHz']) if y['max_relative_error_deg'][i]<=20 and y['max_cyclic_adjacent_error_deg'][i]<=20]}
 out['common_pass_samples_GHz']=sorted(set(out['metrics']['H']['both_phase_pass_samples_GHz'])&set(out['metrics']['V']['both_phase_pass_samples_GHz']))
 out['center_converged_states']=sum(s['converged_last_two_deltaS'] for s in b['audits'])
 return out
if __name__=='__main__':
 out=Path(sys.argv[3]);assert not out.exists(),'Use a new output path to preserve prior evidence'
 d=compare(sys.argv[1],sys.argv[2]);out.write_text(json.dumps(d,indent=2)+'\n')
 print(json.dumps({k:v for k,v in d.items() if k!='metrics'},indent=2))
