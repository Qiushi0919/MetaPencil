from pathlib import Path
import json,re,hashlib
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102');read=lambda p:json.loads(p.read_text())
a=read(B/'code/rlc-r16-cases.json');b=read(B/'code/rlc-r17-cases.json');base={s['state']:s for s in read(B/'code/rlc-base-cases.json')}
order=['H1V1','H2V1','H3V1','H4V1','H1V2','H1V3','H1V4'];allcases={s['state']:s for s in a+b};assert len(allcases)==7 and len(a+b)==7
geom=lambda s:[(t,re.sub(r'(?m)^ \.Set[RC] "[^"]+"','',c)) for t,c in s['history']]
for s in allcases.values():
 assert geom(s)==geom(a[0])
 assert s['geometry_audit']==a[0]['geometry_audit']
 assert s['frequencies_GHz']==a[0]['frequencies_GHz']
 assert s['parts']==base[s['state']]['parts']
merged=[allcases[s] for s in order];f=B/'code/rlc-v9trim-seven-cases.json';assert not f.exists();f.write_text(json.dumps(merged,ensure_ascii=False,indent=2)+'\n')
sources=[]
for s in merged:
 roundname=s['optimization']['round'];archive=B/f'Results_rlc_{roundname}_v1/case_snapshots'/f"{s['id']}.zip"
 sources.append({'id':s['id'],'state':s['state'],'archive':str(archive),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest() if archive.exists() else None})
manifest={'status':'prepared_r17_missing5','samegeometry_history_equal_except_switch_RC':True,'all_parts_match_fixed_RLC_baseline':True,'identical_frequency_and_solver_history':True,'minimum_gap_mm':a[0]['geometry_audit']['minimum_gap_mm'],'reuse_completed_r16_states':[s['state'] for s in a],'solve_only_r17_states':[s['state'] for s in b],'sources':sources,'merged_cases_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'results_destination':'Results_v9trim_seven_merged','analysis_destination':'analysis_v9trim_seven','r16_V2_last_two_deltaS':[.03169,.0128972],'all_state_center_convergence_not_yet_met':True}
for name in ['v9trim-seven-merge-manifest.json','r17-incremental-preflight.json']:(B/'code'/name).write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k!='sources'},indent=2))
