from pathlib import Path
from datetime import datetime
import json,shutil,hashlib,os,ctypes
r=Path.home()/'Desktop/qiushi-cao-rlc-r11-runtime-v1'
b=Path(__file__).resolve().parents[1]/'Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102/Results_rlc_r11_v1'
status=json.loads((r/'latest_status.json').read_text(encoding='utf8'))
k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
k.GetExitCodeProcess.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_ulong)];k.CloseHandle.argtypes=[ctypes.c_void_p]
h=k.OpenProcess(0x1000,False,status['pid']);live=False
if h:
 c=ctypes.c_ulong();live=bool(k.GetExitCodeProcess(h,ctypes.byref(c))) and c.value==259;k.CloseHandle(h)
report={'observed_local':datetime.now().astimezone().isoformat(),'pid':status['pid'],'runner_alive':live,'runner_status':status,'archives':[]}
for n in ['latest_status.json','RUN_OPTIMIZATION.log']:
 shutil.copyfile(r/n,b/n)
for f in sorted((r/'case_snapshots').glob('*.zip')):
 dest=b/'case_snapshots'/f.name;dest.parent.mkdir(exist_ok=True)
 digest=hashlib.sha256(f.read_bytes()).hexdigest()
 if dest.exists():assert hashlib.sha256(dest.read_bytes()).hexdigest()==digest
 else:
  tmp=dest.with_suffix('.zip.recovering');shutil.copyfile(f,tmp);assert hashlib.sha256(tmp.read_bytes()).hexdigest()==digest;os.replace(tmp,dest)
 report['archives'].append({'name':f.name,'sha256':digest,'bytes':f.stat().st_size})
(b/'recovery_observation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,indent=2))
