"""Prepare an immutable terminal-length/common-taper screen from the fixed RLC baseline.
Usage: python prepare_opt_round.py plan.json. No CST invocation happens here.
Positive terminal deltas extend an open end; negative deltas trim it.
Common-taper deltas move the wide shoulder only; pads and RLC stay fixed.
"""
from pathlib import Path
import json,copy,re,hashlib,sys
from shapely.geometry import Polygon,Point
B=Path(__file__).resolve().parents[1];ROOT=B.parents[1];k=3.6/9.5
BASE=json.loads((B/'code/rlc-base-cases.json').read_text())
# axis, outward sign, terminal coordinate, deformable end span, optional y floor
END={'H_L4':(1,1,2.4*k,.30,None),'H_L5':(0,1,10.9*k,1.,None),
     'H_L3':(1,-1,-6.55*k,.60,None),'H_L2':(0,-1,1.3*k,1.,2.6),
     'V_L10':(0,1,1.35*k,.10,None),'V_L9':(0,1,10.35*k,1.,None),
     'V_L8':(0,-1,-13.85*k,1.,None),'V_L7':(1,1,-7.95*k,1.,None)}
def deform(points,name,delta):
 axis,sign,tip,span,yfloor=END[name];anchor=sign*tip-span
 assert -span*.9<delta<=1.,(name,'terminal movement exceeds initial safe range')
 def active(p):return yfloor is None or p[1]>yfloor
 def move(p):
  p=list(p)
  if active(p):p[axis]+=sign*delta*max(0.,(sign*p[axis]-anchor)/span)
  return p
 out=[]
 for a,b in zip(points,points[1:]):
  out.append(move(a));qa,qb=sign*a[axis]-anchor,sign*b[axis]-anchor
  if qa*qb<0:
   t=-qa/(qb-qa);p=[a[j]+t*(b[j]-a[j]) for j in range(2)]
   if active(p):out.append(move(p))
 out.append(out[0]);p=Polygon(out)
 assert p.is_valid and not p.interiors and p.area>0
 return [list(x) for x in p.exterior.coords]

def change_common_taper(points,name,delta):
 # Move only the wide-line/taper shoulder. Pads, switch contacts and
 # the far feed end remain fixed. Positive delta lengthens the taper.
 axis,shoulder,direction={'H_common':(0,2*k,-1),'V_common':(1,-11.7*k,1)}[name]
 assert abs(delta)<=.25,'Common taper shoulder movement limited to0.25mm'
 out=copy.deepcopy(points);count=0
 for p in out:
  if abs(p[axis]-shoulder)<1e-9:
   p[axis]+=direction*delta;count+=1
 assert count==2,(name,'Unexpected shoulder topology',count)
 poly=Polygon(out);assert poly.is_valid and not poly.interiors and poly.area>0
 return out

def change_common_width(points,name,factor):
 # Change the wide feed stem/shoulder only. Keep narrow chip pad, launch
 # tip, coupling-stub free end and all component contacts fixed.
 assert name=='V_common','Only V stem width is implemented'
 assert .65<=factor<=1.90  # r13: explicit range extension; geometry/contact gates still apply
 out=copy.deepcopy(points);count=0;halfwidth=.55*k
 for p in out:
  if abs(abs(p[0])-halfwidth)<1e-9:
   p[0]*=factor;count+=1
 assert count==7,('Unexpected V wide-stem vertices',count)
 poly=Polygon(out);assert poly.is_valid and not poly.interiors and poly.area>0
 return out

def main(planpath):
 plan=json.loads(Path(planpath).read_text());name=plan['name'];assert re.fullmatch(r'r[0-9]{2,3}[a-z]?',name)
 freq=plan.get('frequencies_GHz',[9,9.1,9.2,9.3,9.4,9.5,9.625,9.75,9.875,10]);assert freq==sorted(set(freq)) and 9.5 in freq and min(freq)>=9 and max(freq)<=10
 adaptive=plan.get('adaptive_GHz',[9.5]);assert adaptive and set(adaptive)<=set(freq)
 minutes=plan.get('budget_minutes',30);assert 10<=minutes<=360
 state_seconds=plan.get('case_budget_seconds',900);assert 300<=state_seconds<=3600
 passes=plan.get('max_passes',3);assert 3<=passes<=8
 cases=[]
 for cand in plan['candidates']:
  tag=cand['name'];assert re.fullmatch(r'[a-z0-9_]+',tag)
  deltas=cand.get('terminal_delta_mm',{});assert set(deltas)<=set(END)
  launch=cand.get('common_taper_delta_mm',{});assert set(launch)<={'H_common','V_common'}
  width=cand.get('common_width_factor',{});assert set(width)<={'V_common'}
  nets=copy.deepcopy(BASE[0]['geometry_audit']['polygon_nets'])
  for n,v in deltas.items():nets[n]=deform(nets[n],n,float(v))
  for n,v in launch.items():nets[n]=change_common_taper(nets[n],n,float(v))
  for n,v in width.items():nets[n]=change_common_width(nets[n],n,float(v))
  polys={n:Polygon(p) for n,p in nets.items()};gaps=[];half=BASE[0]['config']['P']/2
  for n,p in polys.items():
   assert p.is_valid and all(abs(c)<half for xy in nets[n] for c in xy)
   for m,q in polys.items():
    if n<m:
     assert p.disjoint(q),(n,m,'short');gaps.append((p.distance(q),n,m))
  assert min(gaps)[0]>=.01,('mesh gap too small',min(gaps))
  selected=cand.get('states',[s['state'] for s in BASE]);assert len(selected)==len(set(selected))
  for state in selected:
   s=copy.deepcopy(next(s for s in BASE if s['state']==state))
   s.update(id=f'caoxrlc-{name}-{tag}-{state}',candidate=tag,frequencies_GHz=freq)
   for p in s['parts']:
    n=p['name'].split(':')[1];assert polys[n].contains(Point(p['p2' if p['name'].startswith('SP4T:') else 'p1'][:2]))
    if p['name'].startswith('SP4T:'):assert polys[n[0]+'_common'].contains(Point(p['p1'][:2]))
   hist=[]
   for t,c in s['history']:
    if 'With Extrude' in c and '.Component "RF"' in c:
     n=re.search(r'\.Name "([^"]+)"',c).group(1)[:-1]
     if n in deltas or n in launch or n in width:
      prefix=c[:c.index(' .Point')]
      c=prefix+''.join(' .'+('Point' if i==0 else 'LineTo')+f' "{x:.12g}", "{y:.12g}"\n' for i,(x,y) in enumerate(nets[n]))+' .Create\nEnd With'
    if 'With FDSolver' in c:
     c=re.sub(r'(?m)^\s*\.AddSampleInterval[^\n]*\n','',c)
     samples='\n'.join(f' .AddSampleInterval "{f}", "{f}", "1", "Single", "'+('True' if f in adaptive else 'False')+'"' for f in freq)
     c=c.replace(' .ResetSampleIntervals "all"',' .ResetSampleIntervals "all"\n'+samples)
     c=c.replace('.MaxPasses "3"',f'.MaxPasses "{passes}"');t='Fixed-order RLC optimization direct samples'
    hist.append([t,c])
   s['history']=hist;s['geometry_audit'].update(polygon_nets=nets,minimum_gap_mm=min(gaps))
   s['optimization']={'round':name,'branch_terminal_delta_mm':deltas,'launch_change':launch or None,'common_width_factor':width or None,'switch_model_fixed':True,'baseline':'rlc-base-cases.json'}
   s['config_nominal_baseline']=s['config'].copy()
   for n,v in deltas.items():s['config'][n.split('_')[1]]+=v
   s['assumptions'].append('Terminal changes are relative to the uniform RLC baseline. Partial state screens cannot certify 2-bit; final candidate requires all seven states with identical geometry.')
   assert s['parts']==next(q['parts'] for q in BASE if q['state']==state)
   cases.append(s)
 assert cases and len({s['id'] for s in cases})==len(cases)
 f=B/'code'/f'rlc-{name}-cases.json';assert not f.exists(),'Frozen round exists; choose a new round name'
 f.write_text(json.dumps(cases,ensure_ascii=False,indent=2))
 pre={'status':'local_geometry_and_circuit_preflight_pass','case_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'cases':len(cases),'plan':plan,'all_RLC_and_contacts_unchanged':True}
 (B/'code'/f'rlc-{name}-preflight.json').write_text(json.dumps(pre,ensure_ascii=False,indent=2))
 s=(ROOT/'tools/caorlctemplate.py').read_text().replace('qiushi-cao-rlc-base-runtime-v1',f'qiushi-cao-rlc-{name}-runtime-v1').replace('qiushi-cao-rlc-base-projects-v1',f'qiushi-cao-rlc-{name}-projects-v1').replace('Results_rlc_base_v1',f'Results_rlc_{name}_v1').replace('rlc-base-cases.json',f'rlc-{name}-cases.json').replace('rlc-base-preflight.json',f'rlc-{name}-preflight.json')
 s=s.replace('assert len(cs)==7',f'assert len(cs)=={len(cases)}').replace('timedelta(minutes=120)',f'timedelta(minutes={minutes})').replace("str(D/'qiushi-cao-xband-cause-runtime-v1')","str(D/'qiushi-cao-rlc-base-runtime-v1')")
 s=s.replace("'budget=min(900,'",f"'budget=min({state_seconds},'")
 compile(s,'launcher','exec');(ROOT/'tools'/f'caorlc{name}.py').write_text(s)
 (ROOT/'tools'/f'caorlc{name}.cmd').write_text((ROOT/'tools/caorlcbase.cmd').read_text().replace('caorlcbase.py',f'caorlc{name}.py'))
 print(json.dumps(pre,ensure_ascii=False,indent=2))
if __name__=='__main__':main(sys.argv[1])
