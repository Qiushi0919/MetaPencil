from pathlib import Path
import json,re,hashlib
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102')
import sys
sys.path.insert(0,str(B/'code'));import prepare_opt_round as g
points=g.BASE[0]['geometry_audit']['polygon_nets']['V_common'];assert g.change_common_taper(points,'V_common',0)==points
for d in [-.25,.25,.45]:g.change_common_taper(points,'V_common',d)
for name,d in [('V_common',-.251),('V_common',.451),('H_common',.251)]:
 try:g.change_common_taper(g.BASE[0]['geometry_audit']['polygon_nets'][name],name,d)
 except AssertionError:pass
 else:raise AssertionError(('out of range accepted',name,d))
a={s['state']:s for s in json.loads((B/'code/rlc-v9trim-seven-cases.json').read_text())};b=json.loads((B/'code/rlc-r19-cases.json').read_text());checks=[]
for y in b:
 x=a[y['state']];assert x['parts']==y['parts'] and x['frequencies_GHz']==y['frequencies_GHz'];assert len(x['history'])==len(y['history'])
 changes=[t for (t,c),(u,d) in zip(x['history'],y['history']) if (t,c)!=(u,d)];assert len(changes)==1 and 'V_common' in changes[0],changes
 nets={n for n,v in x['geometry_audit']['polygon_nets'].items() if v!=y['geometry_audit']['polygon_nets'][n]};assert nets=={'V_common'}
 old=x['geometry_audit']['polygon_nets']['V_common'];new=y['geometry_audit']['polygon_nets']['V_common'];assert len(old)==len(new)
 changed=[(i,p,q) for i,(p,q) in enumerate(zip(old,new)) if p!=q];assert len(changed)==2
 for i,p,q in changed:assert p[0]==q[0] and abs(q[1]-p[1]+.15)<1e-10
 checks.append({'state':y['state'],'history_changes':changes,'changed_vertices':changed,'parts_contacts_ground_slots_frequencies_solver_identical':True})
geom=lambda s:[(t,re.sub(r'(?m)^ \.Set[RC] "[^"]+"','',c)) for t,c in s['history']]
assert all(geom(s)==geom(b[0]) for s in b)
out={'passed':True,'V_taper_range_mm':[-.25,.45],'H_taper_range_unchanged_mm':[-.25,.25],'identity_boundaries_and_rejection_pass':True,'parent':'r16r17-v9trim','only_changed_net':'V_common','only_change':'Two wide taper shoulders y-0.15mm (total+0.10); stem width and narrow pad fixed','minimum_gap_mm':b[0]['geometry_audit']['minimum_gap_mm'],'histories_equal_except_switch_RC':True,'checks':checks,'source_case_sha256':hashlib.sha256((B/'code/rlc-r19-cases.json').read_bytes()).hexdigest()}
(B/'code/r19-incremental-preflight.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
