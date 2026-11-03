from pathlib import Path
import hashlib,json,shutil,zipfile,re
from datetime import datetime
B=Path('/Users/qiushi/Doctor/MetaPencil/Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102');W=B/'report/.build';U=B.parent
for i in range(1,39):assert (W/f'merged-v9-renders/slide-{i}.png').read_bytes()==(W/f'merged-v10-renders/slide-{i}.png').read_bytes(),i
for i in range(1,13):assert (W/f'final-v10-renders/slide-{i}.png').read_bytes()==(W/f'merged-v10-renders/slide-{i+38}.png').read_bytes(),i
for i in range(1,11):assert (W/f'final-v9-renders/slide-{i}.png').read_bytes()==(W/f'final-v10-renders/slide-{i}.png').read_bytes(),i
items=[('Cao双SP4T结构与结果汇报_宋体三线表_v10.pptx','Cao双SP4T结构与结果汇报.pptx',12,'final-fonts-v10-validation.json'),('文献单元快速复现与混合结构粗算_Cao更新_v10.pptx','文献单元快速复现与混合结构粗算.pptx',50,'merged-v10-validation.json')];out=[]
for src,dst,count,rec in items:
 p=B/'report/output'/src;sha=hashlib.sha256(p.read_bytes()).hexdigest();assert json.loads((W/rec).read_text())['finalSha256']==sha
 with zipfile.ZipFile(p) as z:
  if count==12:
   charts=[n for n in z.namelist() if re.fullmatch(r'ppt/slides/charts/chart\d+\.xml',n)];assert len(charts)==8
   assert sum(z.read(n).count(b'<a:tbl>') for n in z.namelist() if re.fullmatch(r'ppt/slides/slide\d+\.xml',n))==5
 shutil.copyfile(p,U/dst);assert hashlib.sha256((U/dst).read_bytes()).hexdigest()==sha
 out.append({'path':str(U/dst),'versioned_source':str(p),'sha256':sha,'slides':count,'validation':str(W/rec)})
receipt={'version':'v10','time':datetime.now().astimezone().isoformat(),'optimization_status':'stopped_by_user','automation_deleted':True,'selected_complete_candidate':'r16r17-v9trim','selection_unchanged':True,'original_merged_first38_render_bytes_unchanged':True,'cao_first10_render_bytes_unchanged':True,'cao_all12_match_merged39to50':True,'changed_slides_inspected_full_size':[11,12],'native_charts':8,'native_three_line_tables':5,'files':out}
(W/'delivery-v10.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');(W/'delivery.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');print(json.dumps(receipt,ensure_ascii=False,indent=2))
