"""Windows-local evidence first; RDP mirror failures never stop the solver."""
from pathlib import Path
from datetime import datetime
import ctypes,json,os,shutil,sys,time

def alive(pid):
 k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
 k.GetExitCodeProcess.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_ulong)];k.CloseHandle.argtypes=[ctypes.c_void_p]
 h=k.OpenProcess(0x1000,False,pid)
 if not h:return False
 try:
  code=ctypes.c_ulong();return bool(k.GetExitCodeProcess(h,ctypes.byref(code))) and code.value==259
 finally:k.CloseHandle(h)
def copy_atomic(src,dest):
 dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_name(dest.name+'.sync-tmp');shutil.copyfile(src,tmp);os.replace(tmp,dest)
def main():
 r=Path(sys.argv[1]);mirror=Path(sys.argv[2]);pid=int(sys.argv[3]);limit=time.monotonic()+86400
 while time.monotonic()<limit:
  try:status=json.loads((r/'latest_status.json').read_text(encoding='utf8'))
  except (OSError,ValueError):time.sleep(5);continue
  live=alive(pid);h={'pid':pid,'runner_alive':live,'observed_local':datetime.now().astimezone().isoformat(),'runner_status':status}
  project=status.get('current_project')
  if live and project:
   log=Path(project).with_suffix('')/'Result/Model.log'
   try:h['solver_log_tail']=log.read_text(errors='replace')[-5000:]
   except OSError:pass
  (r/'heartbeat.json').write_text(json.dumps(h,ensure_ascii=False,indent=2),encoding='utf8')
  try:
   for name in ['latest_status.json','RUN_OPTIMIZATION.log','heartbeat.json']:
    if (r/name).exists():copy_atomic(r/name,mirror/name)
   for f in (r/'case_snapshots').glob('*.zip'):
    d=mirror/'case_snapshots'/f.name
    if not d.exists() or d.stat().st_size!=f.stat().st_size:copy_atomic(f,d)
   if not live and (r/'native_snapshot.zip').exists():copy_atomic(r/'native_snapshot.zip',mirror/'native_snapshot.zip')
   complete=len(status.get('completed',[]));snapshots=len(list((r/'case_snapshots').glob('*.zip')))
   if not live and snapshots>=complete:
    # State archives already carry full native evidence; supervisor full snapshot is optional.
    return
  except OSError as e:
   (r/'mirror_retry.json').write_text(json.dumps({'time':h['observed_local'],'error':str(e),'solver_not_interrupted':True},ensure_ascii=False),encoding='utf8')
  time.sleep(15)
if __name__=='__main__':main()
