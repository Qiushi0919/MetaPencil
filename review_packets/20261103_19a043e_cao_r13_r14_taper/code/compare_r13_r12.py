from pathlib import Path
import json,numpy as np
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102')
a=json.loads((B/'analysis_r13/seven_state_diagnostic.json').read_text());b=json.loads((B/'analysis_r13/seven_state_diagnostic.json').read_text());assert a['frequency_GHz']==b['frequency_GHz']
out={'reference':'r12-edgecomp','candidate':'r13-uppercomp','frequency_GHz':b['frequency_GHz'],'same_direct_points':True,'interpolation':False,'convergence_scope_GHz':[9.5],'entire_band_convergence_verified':False,'metrics':{}}
for pol in ['H','V']:
 x,y=a['metrics'][pol],b['metrics'][pol];assert x['states']==y['states']
 delta=lambda key:(np.array(y[key])-np.array(x[key])).tolist()
 phase=(np.array(y['relative_phase_deg'])-np.array(x['relative_phase_deg'])+180)%360-180
 out['metrics'][pol]={'states':y['states'],'reference_worst_relative_deg':max(x['max_relative_error_deg']),'worst_relative_deg':max(y['max_relative_error_deg']),'reference_worst_cyclic_deg':max(x['max_cyclic_adjacent_error_deg']),'worst_cyclic_deg':max(y['max_cyclic_adjacent_error_deg']),'reference_min_amp_dB':min(x['minimum_amplitude_dB']),'min_amp_dB':min(y['minimum_amplitude_dB']),'delta_relative_deg':phase.tolist(),'max_abs_relative_change_deg':float(abs(phase).max()),'delta_amplitude_dB':delta('amplitude_dB'),'phase_error_deg':y['phase_error_deg'],'cyclic_adjacent_error_deg':y['cyclic_adjacent_error_deg'],'both_phase_pass_samples_GHz':[f for i,f in enumerate(b['frequency_GHz']) if y['max_relative_error_deg'][i]<=20 and y['max_cyclic_adjacent_error_deg'][i]<=20]}
out['common_pass_samples_GHz']=sorted(set(out['metrics']['H']['both_phase_pass_samples_GHz'])&set(out['metrics']['V']['both_phase_pass_samples_GHz']))
out['center_converged_states']=sum(s['converged_last_two_deltaS'] for s in b['audits'])
out['conclusion']='Eight common direct samples pass; H worst29.81deg/minamp-1.186dB, V worst37.30deg/minamp-1.039dB. Overall minimax worse than r12 despite amplitude improvements. Seven states converge at9.5GHz only; not whole-band2bit. Joint changes not individual sensitivity.'
(B/'analysis_r13/versus_r12.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='metrics'},indent=2))
