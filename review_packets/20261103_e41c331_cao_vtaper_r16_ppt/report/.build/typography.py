from pathlib import Path
import zipfile,copy,re,json
from lxml import etree as E
B=Path(__file__).resolve().parent
A='http://schemas.openxmlformats.org/drawingml/2006/main';ns={'a':A};q=lambda n:'{'+A+'}'+n
with zipfile.ZipFile(B/'draft.pptx') as z:d={n:z.read(n) for n in z.namelist()}
counts={'split_text_runs':0,'three_line_tables':0}
for n,v in list(d.items()):
 if not n.endswith('.xml') or not n.startswith('ppt/'):continue
 try:r=E.fromstring(v)
 except:continue
 # Explicit script fonts in all rich/default text properties.
 for pr in r.xpath('//a:rPr|//a:defRPr|//a:endParaRPr',namespaces=ns):
  if '/charts/' in n:
   for e in list(pr):
    if E.QName(e).localname in ['solidFill','noFill','gradFill']:pr.remove(e)
   f=E.Element(q('solidFill'));pr.insert(1 if pr.find(q('ln')) is not None else 0,f);E.SubElement(f,q('srgbClr'),val='000000')
  for tag,font in [('latin','Times New Roman'),('ea','SimSun'),('cs','Times New Roman')]:
   el=pr.find(q(tag))
   if el is None:el=E.SubElement(pr,q(tag))
   el.set('typeface',font)
 for run in list(r.xpath('//a:r',namespaces=ns)):
  t=run.find(q('t'))
  if t is None or not t.text:continue
  parts=re.findall(r'[\u2e80-\u9fff\uf900-\ufaff\uff00-\uffef]+|[^\u2e80-\u9fff\uf900-\ufaff\uff00-\uffef]+',t.text)
  par=run.getparent();idx=par.index(run)
  for i,part in enumerate(parts):
   rr=copy.deepcopy(run);rr.find(q('t')).text=part;pr=rr.find(q('rPr'))
   if pr is None:pr=E.Element(q('rPr'));rr.insert(0,pr)
   font='SimSun' if re.match(r'[\u2e80-\u9fff\uf900-\ufaff\uff00-\uffef]',part) else 'Times New Roman'
   for tag in ['latin','ea','cs']:
    e=pr.find(q(tag))
    if e is None:e=E.SubElement(pr,q(tag))
    e.set('typeface',font)
   par.insert(idx+i,rr)
  par.remove(run);counts['split_text_runs']+=1
 for tbl in r.xpath('//a:tbl',namespaces=ns):
  rows=tbl.findall(q('tr'));counts['three_line_tables']+=1
  for ri,row in enumerate(rows):
   for cell in row.findall(q('tc')):
    cp=cell.find(q('tcPr'))
    if cp is None:cp=E.SubElement(cell,q('tcPr'))
    for e in list(cp):
     if E.QName(e).localname in ['lnL','lnR','lnT','lnB','lnTlToBr','lnBlToTr','solidFill','noFill','gradFill']:cp.remove(e)
    for side in ['L','R','T','B']:
     line=E.SubElement(cp,q('ln'+side));width=2 if (side=='T' and ri==0) or (side=='B' and ri==len(rows)-1) else 1 if side=='B' and ri==0 else 0
     if width:
      line.set('w',str(width*12700));f=E.SubElement(line,q('solidFill'));E.SubElement(f,q('srgbClr'),val='000000');E.SubElement(line,q('prstDash'),val='solid')
     else:E.SubElement(line,q('noFill'))
    f=E.SubElement(cp,q('solidFill'));E.SubElement(f,q('srgbClr'),val='FFFFFF')
 # Theme scripts used by chart labels and fallback.
 for e in r.xpath('//a:majorFont/a:latin|//a:minorFont/a:latin',namespaces=ns):e.set('typeface','Times New Roman')
 for e in r.xpath('//a:majorFont/a:ea|//a:minorFont/a:ea',namespaces=ns):e.set('typeface','SimSun')
 d[n]=E.tostring(r,encoding='UTF-8',xml_declaration=True)
with zipfile.ZipFile(B/'styled-draft.pptx','w',zipfile.ZIP_DEFLATED) as z:
 for n,v in d.items():z.writestr(n,v)
(B/'typography-audit.json').write_text(json.dumps(counts,indent=2));print(counts)
