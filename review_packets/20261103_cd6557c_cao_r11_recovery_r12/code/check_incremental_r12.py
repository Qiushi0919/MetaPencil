from pathlib import Path
import json,re
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102')
a=json.loads((B/'code/rlc-r11-cases.json').read_text());b=json.loads((B/'code/rlc-r12-cases.json').read_text());expected={'H_L2','H_L5','V_L7'};checks=[]
for x,y in zip(a,b):
 assert x['state']==y['state'] and x['parts']==y['parts'] and x['frequencies_GHz']==y['frequencies_GHz']
 diff=[t for (t,c),(u,d) in zip(x['history'],y['history']) if c!=d]
 assert len(diff)==3 and all(any(n in t for t in diff) for n in expected),diff
 nets={n for n,v in x['geometry_audit']['polygon_nets'].items() if v!=y['geometry_audit']['polygon_nets'][n]};assert nets==expected
 checks.append({'state':x['state'],'changed_history':diff,'changed_nets':sorted(nets),'parts_and_frequencies_identical':True})
geom=lambda s:[(t,re.sub(r'(?m)^ \.Set[RC] "[^"]+"','',c)) for t,c in s['history']]
assert all(geom(s)==geom(b[0]) for s in b)
out={'passed':True,'only_changed_nets':sorted(expected),'seven_histories_equal_except_switch_RC':True,'common_width_and_taper_fixed':True,'minimum_gap_mm':b[0]['geometry_audit']['minimum_gap_mm'],'checks':checks}
(B/'code/r12-incremental-preflight.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
