from pathlib import Path
import zipfile,posixpath as pp,re,hashlib,json
from lxml import etree as E
B=Path(__file__).resolve().parent
NSR='http://schemas.openxmlformats.org/package/2006/relationships';NSP='http://schemas.openxmlformats.org/presentationml/2006/main';NSO='http://schemas.openxmlformats.org/officeDocument/2006/relationships';NSC='http://schemas.openxmlformats.org/package/2006/content-types'
relpath=lambda n:pp.join(pp.dirname(n),'_rels',pp.basename(n)+'.rels')
with zipfile.ZipFile(B/'source.pptx') as z:src={n:z.read(n) for n in z.namelist()}
with zipfile.ZipFile(B/'../output/Cao双SP4T结构与结果汇报_宋体三线表_v9.pptx') as z:new={n:z.read(n) for n in z.namelist()}
# Preserve the original 38 slides, charts, embedded workbooks, layouts and notes byte for byte.
out=dict(src);mapping={};todo=['ppt/slides/slide%d.xml'%i for i in range(1,13)]
def target(n,t):return pp.normpath(t.lstrip('/') if t.startswith('/') else pp.join(pp.dirname(n),t))
def mapped(n):
 if n not in mapping:mapping[n]=pp.join(pp.dirname(n),'cao20261102_'+pp.basename(n))
 return mapping[n]
while todo:
 n=todo.pop()
 if n in mapping:continue
 mapped(n)
 if relpath(n) in new:
  rels=E.fromstring(new[relpath(n)])
  for r in rels:
   if r.get('TargetMode')!='External':
    q=target(n,r.get('Target'))
    if q not in mapping:todo.append(q)
for n,nn in mapping.items():
 out[nn]=new[n]
 rp=relpath(n)
 if rp in new:
  rr=E.fromstring(new[rp])
  for r in rr:
   if r.get('TargetMode')!='External':r.set('Target','/'+mapping[target(n,r.get('Target'))])
  out[relpath(nn)]=E.tostring(rr,xml_declaration=True,encoding='UTF-8')
ct=E.fromstring(src['[Content_Types].xml']);nct=E.fromstring(new['[Content_Types].xml']);defs={v.get('Extension') for v in ct if v.tag.endswith('Default')}
for e in nct:
 if e.tag.endswith('Override') and e.get('PartName').lstrip('/') in mapping:
  q=E.SubElement(ct,'{'+NSC+'}Override');q.set('PartName','/'+mapping[e.get('PartName').lstrip('/')]);q.set('ContentType',e.get('ContentType'))
 elif e.tag.endswith('Default') and e.get('Extension') not in defs:ct.append(e);defs.add(e.get('Extension'))
out['[Content_Types].xml']=E.tostring(ct,xml_declaration=True,encoding='UTF-8')
pr=E.fromstring(src['ppt/_rels/presentation.xml.rels']);px=E.fromstring(src['ppt/presentation.xml']);sl=px.find('{'+NSP+'}sldIdLst')
# Remove the old Cao section from the presentation order; retain its original parts as historical orphan evidence.
removed={e.get('{'+NSO+'}id') for e in list(sl)[38:]}
for e in list(sl)[38:]:sl.remove(e)
for e in list(pr):
 if e.get('Id') in removed:pr.remove(e)
last=max(int(e.get('id')) for e in sl)
for i in range(1,13):
 rid='rIdCao20261102Add'+str(i);E.SubElement(pr,'{'+NSR+'}Relationship',Id=rid,Type=NSO+'/slide',Target='/'+mapping['ppt/slides/slide%d.xml'%i]);e=E.SubElement(sl,'{'+NSP+'}sldId',id=str(last+i));e.set('{'+NSO+'}id',rid)
ml=px.find('{'+NSP+'}sldMasterIdLst');maxid=max([int(e.get('id')) for e in ml]+[2147483647])
for k,n in enumerate(n for n in mapping if re.fullmatch(r'ppt/slideMasters/[^/]+\.xml',n)):
 rid='rIdCao20261102Master'+str(k);E.SubElement(pr,'{'+NSR+'}Relationship',Id=rid,Type=NSO+'/slideMaster',Target='/'+mapping[n]);e=E.SubElement(ml,'{'+NSP+'}sldMasterId',id=str(maxid+k+1));e.set('{'+NSO+'}id',rid)
out['ppt/_rels/presentation.xml.rels']=E.tostring(pr,xml_declaration=True,encoding='UTF-8');out['ppt/presentation.xml']=E.tostring(px,xml_declaration=True,encoding='UTF-8')
if 'docProps/app.xml' in out:
 ax=E.fromstring(out['docProps/app.xml'])
 for e in ax.iter():
  if E.QName(e).localname=='Slides':e.text='50'
 out['docProps/app.xml']=E.tostring(ax,xml_declaration=True,encoding='UTF-8')
with zipfile.ZipFile(B/'preserved-candidate.pptx','w',zipfile.ZIP_DEFLATED) as z:
 for n,v in out.items():z.writestr(n,v)
changed=[n for n,v in src.items() if out[n]!=v];assert set(changed)<=set(['[Content_Types].xml','ppt/_rels/presentation.xml.rels','ppt/presentation.xml','docProps/app.xml'])
report={'original_parts':len(src),'original_parts_byte_identical':len(src)-len(changed),'modified_container_parts':changed,'appended_dependency_parts':len(mapping),'all_original_slide_chart_workbook_parts_unchanged':True}
(B/'preservation.json').write_text(json.dumps(report,indent=2));print(report)
