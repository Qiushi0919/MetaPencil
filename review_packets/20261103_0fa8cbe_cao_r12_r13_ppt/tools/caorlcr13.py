"""Finite X-band seven-state ideal-SP4T diagnostic; audit structure before curves."""
from pathlib import Path
from datetime import datetime,timedelta
import os,sys,subprocess,json,shutil,hashlib,ctypes,zipfile
D=Path.home()/'Desktop';ROOT=Path(__file__).resolve().parents[1];B=ROOT/'Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102';O=ROOT/'Unitcell-qiushi/文献结构快速复现_20261101';C=ROOT/'Unitcell-qiushi/Cao双SP4T复现_20261102';r=D/'qiushi-cao-rlc-r13-runtime-v1';pr=D/'qiushi-cao-rlc-r13-projects-v1';mirror=B/'Results_rlc_r13_v1'
if len(sys.argv)==1:
 with (D/'qiushi-cao-rlc-r13-runtime-v1.log').open('x',encoding='utf8') as f:p=subprocess.Popen([sys.executable,__file__,'run'],stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NEW_CONSOLE|subprocess.CREATE_NEW_PROCESS_GROUP)
 print('CAO_XBAND_SEVEN_STATE_SUPERVISOR',p.pid);sys.exit(0)
pre=json.loads((B/'code/rlc-r13-preflight.json').read_text());assert pre['status']=='local_geometry_and_circuit_preflight_pass'
assert hashlib.sha256((B/'code/rlc-r13-cases.json').read_bytes()).hexdigest()==pre['case_sha256']
class Mem(ctypes.Structure):_fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(k,ctypes.c_ulonglong) for k in ['total','avail','tp','ap','tv','av','ext']]
m=Mem();m.length=ctypes.sizeof(m);ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m));assert m.avail>8*2**30
r.mkdir(exist_ok=False);pr.mkdir(exist_ok=False);mirror.mkdir(exist_ok=True)
cs=sum([json.loads((B/'code'/f).read_text(encoding='utf8')) for f in ['rlc-r13-cases.json']],[]);assert len(cs)==7; (r/'cases.json').write_text(json.dumps(cs,ensure_ascii=False),encoding='utf8')
for src,name in [(C/'code/resume-worker.py','literature_run.py'),(O/'code/native_modes.py','native_modes.py'),(B/'code/local_first_watch.py','me_match_watch.py')]:shutil.copyfile(src,r/name)
shutil.copyfile(B/'code/native_structure.py',r/'native_structure.py')
worker=r/'literature_run.py'; txt=worker.read_text(encoding='utf8'); assert 'budget=min(420,' in txt; txt=txt.replace('budget=min(420,','budget=min(1500,')
needle='  timer=threading.Timer(budget,abort);timer.daemon=True;timer.start()'
assert needle in txt
watch='''  def memory_watch():
   class M(ctypes.Structure):_fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(k,ctypes.c_ulonglong) for k in ['total','avail','tp','ap','tv','av','ext']]
   while not done.wait(2):
    m=M();m.length=ctypes.sizeof(m);ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
    if m.avail<2.5*2**30:
     save(out/'memory_abort.json',{'available_GiB':m.avail/2**30,'time':now(),'only_this_solver_aborted':True});abort();return
  threading.Thread(target=memory_watch,daemon=True).start()
'''
txt=txt.replace(needle,needle+'\n'+watch)
postneedle='   done.set();timer.cancel();p.save(include_results=True)'
post='''   done.set();timer.cancel();p.save(include_results=True)
   postdir=out/'postsolve_geometry';postdir.mkdir(exist_ok=True)
   shutil.copyfile(folder/'Model/3D/ModelHistory.json',postdir/'ModelHistory.json')
   assert (postdir/'ModelHistory.json').read_bytes()==(out/'ModelHistory.json').read_bytes(),'Actual saved geometry changed during solve'
   native_parts(p,postdir,spec['parts'])
   save(postdir/'verified.json',{'actual_saved_history_unchanged':True,'actual_parts_rechecked':True,'before_curve_export':True,'time':now()})'''
assert postneedle in txt;txt=txt.replace(postneedle,post);txt=txt.replace('import os,sys,json,time,hashlib,threading,traceback,re,shutil,math,ctypes','import os,sys,json,time,hashlib,threading,traceback,re,shutil,math,ctypes,zipfile')
archive='''  dest=B/'case_snapshots';dest.mkdir(exist_ok=True)
  temp=dest/(spec['id']+'.zip.tmp')
  with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as z:
   for f in out.rglob('*'):
    if f.is_file():z.write(f,str(f.relative_to(B)))
  os.replace(temp,dest/(spec['id']+'.zip'))
  return result'''
assert '  return result' in txt;txt=txt.replace('  return result',archive)
txt=txt.replace("from pathlib import Path", "from pathlib import Path\nfrom native_structure import audit_native")
txt=txt.replace("native_parts(p,out,spec['parts']);export_views(p,out,spec)", "native_parts(p,out,spec['parts']);audit_native(out,spec);export_views(p,out,spec)")
txt=txt.replace("native_parts(p,postdir,spec['parts'])", "native_parts(p,postdir,spec['parts']);audit_native(postdir,spec)")
compile(txt,'literature_run.py','exec');txt=txt.replace(', 1600, 1100',', 3975, 1600');worker.write_text(txt,encoding='utf8')
cfg={'evidence_mirror':str(mirror),'cases':'cases.json','projects':str(pr),'original_deadline':(datetime.now().astimezone()+timedelta(minutes=110)).isoformat(),'guards':[str(D/'qiushi-cao-rlc-base-runtime-v1')],'available_memory_GiB':m.avail/2**30,'purpose':'Seven-state 9-10GHz baseline with fixed scaled RLC; native structure checks before and after each solve; no real-device claim','manifest':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in r.iterdir() if f.suffix in ['.py','.json']}};(r/'config.json').write_text(json.dumps(cfg,indent=2))
env=os.environ.copy();env['OMP_NUM_THREADS']='4';env['PYTHONIOENCODING']='utf-8'
with (r/'RUN_OPTIMIZATION.log').open('w',encoding='utf8') as f:p=subprocess.Popen([sys.executable,str(r/'literature_run.py')],cwd=r,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NEW_CONSOLE|subprocess.CREATE_NEW_PROCESS_GROUP)
(mirror/'DEPLOY.json').write_text(json.dumps({'pid':p.pid,'runtime':str(r),'config':cfg},indent=2));subprocess.Popen([sys.executable,str(r/'me_match_watch.py'),str(r),str(mirror),str(p.pid)],cwd=r);p.wait()
with zipfile.ZipFile(r/'native_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
 for f in (r/'runs').rglob('*'):
  if f.is_file():z.write(f,str(f.relative_to(r)))
 for n in ['config.json','latest_status.json','RUN_OPTIMIZATION.log']:z.write(r/n,n)
print((r/'latest_status.json').read_text(encoding='utf8'),flush=True)
