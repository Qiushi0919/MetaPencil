from pathlib import Path
import json,re,hashlib,sys
from shapely.geometry import Polygon
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102');sys.path.insert(0,str(B/'code'));import prepare_opt_round as g
a={s['state']:s for s in json.loads((B/'code/rlc-vtaper-seven-cases.json').read_text())};b=json.loads((B/'code/rlc-r16-cases.json').read_text());checks=[]
points=g.BASE[0]['geometry_audit']['polygon_nets']['V_L9'];assert Polygon(g.deform(points,'V_L9',0)).equals(Polygon(points))
for delta in [-.969,-.95,-.85,1]:assert Polygon(g.deform(points,'V_L9',delta)).is_valid
for delta in [-.97,-1,1.001]:
 try:g.deform(points,'V_L9',delta)
 except AssertionError:pass
 else:raise AssertionError(('out of range accepted',delta))
for y in b:
 x=a[y['state']];assert x['parts']==y['parts'] and x['frequencies_GHz']==y['frequencies_GHz'];assert len(x['history'])==len(y['history'])
 changes=[t for (t,c),(u,d) in zip(x['history'],y['history']) if (t,c)!=(u,d)];assert len(changes)==1 and 'V_L9' in changes[0],changes
 nets={n for n,v in x['geometry_audit']['polygon_nets'].items() if v!=y['geometry_audit']['polygon_nets'][n]};assert nets=={'V_L9'}
 checks.append({'state':y['state'],'history_changes':changes,'parts_contacts_ground_slots_frequencies_solver_identical':True})
geom=lambda s:[(t,re.sub(r'(?m)^ \.Set[RC] "[^"]+"','',c)) for t,c in s['history']]
assert all(geom(s)==geom(b[0]) for s in b)
out={'passed':True,'parent':'r14r15-vtaperplus','only_changed_net':'V_L9','terminal_change_mm':[-.85,-.95],'range_explicit_extension':{'V_L9':[-.97,1],'lower_exclusive':True,'identity_boundary_and_rejection_pass':True},'minimum_gap_mm':b[0]['geometry_audit']['minimum_gap_mm'],'histories_equal_except_switch_RC':True,'checks':checks,'source_case_sha256':hashlib.sha256((B/'code/rlc-r16-cases.json').read_bytes()).hexdigest()}
(B/'code/r16-incremental-preflight.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
