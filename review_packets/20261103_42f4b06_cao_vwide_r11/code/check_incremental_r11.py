from pathlib import Path
import json,re,sys
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102');sys.path.insert(0,str(B/'code'));import prepare_opt_round as g
old=json.loads((B/'code/rlc-vwide-seven-cases.json').read_text());new=json.loads((B/'code/rlc-r11-cases.json').read_text());checks=[]
# Only equivalent numeric string formatting (9 versus9.0 etc.) is ignored.
norm=lambda c:re.sub(r'"(-?\d+(?:\.\d+)?)"',lambda m:'"'+format(float(m[1]),'.12g')+'"',c)
for a,b in zip(old,new):
 assert a['state']==b['state'] and a['parts']==b['parts'] and a['frequencies_GHz']==b['frequencies_GHz']
 diff=[t for (t,c),(u,d) in zip(a['history'],b['history']) if norm(c)!=norm(d)];assert len(diff)==1 and 'V_common' in diff[0],diff
 for n,p in a['geometry_audit']['polygon_nets'].items():
  if n!='V_common':assert p==b['geometry_audit']['polygon_nets'][n]
 checks.append({'state':a['state'],'changed_history':diff,'fixed_parts':True,'frequency_and_solver_unchanged_semantically':True})
base=g.BASE[0]['geometry_audit']['polygon_nets']['V_common'];assert g.change_common_width(base,'V_common',1)==base
for factor in [.65,1,1.35,1.7]:g.change_common_width(base,'V_common',factor)
for factor in [.64,1.71]:
 try:g.change_common_width(base,'V_common',factor)
 except AssertionError:pass
 else:raise AssertionError('width bounds not enforced')
# all7 identical geometry histories after removing state-dependent switch R/C lines
geom=lambda s:[(t,re.sub(r'(?m)^ \.Set[RC] "[^"]+"','',c)) for t,c in s['history']]
assert all(geom(s)==geom(new[0]) for s in new)
out={'passed':True,'only_change':'V_common width1.35->1.70, 7 wide vertices','width_mm':1.1*g.k*1.7,'minimum_gap_mm':new[0]['geometry_audit']['minimum_gap_mm'],'width_identity_and_bounds_tested':True,'seven_histories_equal_except_switch_RC':True,'checks':checks,'numeric_history_format_only':'9->9.0,10->10.0 sample strings normalize to identical values'}
(B/'code/r11-incremental-preflight.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
