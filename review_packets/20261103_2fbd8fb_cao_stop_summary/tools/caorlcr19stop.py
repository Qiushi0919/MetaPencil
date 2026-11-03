"""User-requested cancellation, restricted to the verified r19 runner process tree."""
import subprocess,json,datetime,time
from pathlib import Path
R=Path(__file__).resolve().parents[1];B=R/'Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102';out=B/'Results_rlc_r19_v1'
ps='Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress'
def inventory():
 x=subprocess.run(['powershell','-NoProfile','-Command',ps],capture_output=True,text=True,check=True);return json.loads(x.stdout)
a=inventory();root=next((x for x in a if x['ProcessId']==47156),None)
report={'user_request':'Stop optimizing; update and summarize PPT only','time':datetime.datetime.now().astimezone().isoformat(),'runner_pid':47156,'scope':'Only verified r19 runner and its descendants; preserve existing projects and unrelated CST sessions','tree_before':[]}
if root:
 assert 'qiushi-cao-rlc-r19-runtime-v1' in (root['CommandLine'] or '').lower() and 'literature_run.py' in root['CommandLine'].lower(),root
 ids={47156}
 while True:
  new=ids|{x['ProcessId'] for x in a if x['ParentProcessId'] in ids}
  if new==ids:break
  ids=new
 report['tree_before']=[x for x in a if x['ProcessId'] in ids]
 (out/'user_stop_request.json').write_text(json.dumps(report,indent=2),encoding='utf8')
 p=subprocess.run(['taskkill','/PID','47156','/T','/F'],capture_output=True,text=True);report.update(taskkill_returncode=p.returncode,taskkill_stdout=p.stdout,taskkill_stderr=p.stderr)
 time.sleep(2)
 after=inventory();report['remaining_tree_pids']=[x['ProcessId'] for x in after if x['ProcessId'] in ids]
 assert not report['remaining_tree_pids'],report
else:report.update(runner_already_exited=True,remaining_tree_pids=[])
report['verified_stopped']=True
(out/'user_stop_receipt.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report,indent=2))
