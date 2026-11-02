"""No third-party dependency: audit saved CST geometry and read-back RLC contacts."""
from pathlib import Path
import json, re, math, hashlib

def inside(p, poly):
    x,y=p;hit=False
    for (ax,ay),(bx,by) in zip(poly,poly[1:]+poly[:1]):
        if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:hit=not hit
    return hit

def audit_native(folder, spec, write_report=True):
    folder=Path(folder);raw=(folder/'ModelHistory.json').read_bytes();hist=json.loads(raw)['history']
    norm=lambda c:re.sub(r'\s+','',c)
    assert len(hist)==len(spec['history'])
    assert all(h['caption']==t and norm('\n'.join(h['code']))==norm(c) for h,(t,c) in zip(hist,spec['history']))
    nets={};cuts=[];ground=None;ground_z=None
    for h in hist:
        c='\n'.join(h['code'])
        if 'With Extrude' not in c:continue
        pts=[list(map(float,p)) for p in re.findall(r'\.(?:Point|LineTo) "([^"]+)", "([^"]+)"',c)]
        name=re.search(r'\.Name "([^"]+)"',c).group(1)
        if '.Component "RF"' in c:
            assert '.Height "0"' in c
            z=float(re.search(r'\.Origin "[^"]+", "[^"]+", "([^"]+)"',c).group(1))
            assert abs(z-spec['parts'][0]['p1'][2])<1e-8
            nets[name[:-1]]=pts
        if '.Component "Cutters"' in c:cuts.append(pts)
        if '.Component "Metal"' in c and name=='ground':
            ground=pts;ground_z=float(re.search(r'\.Origin "[^"]+", "[^"]+", "([^"]+)"',c).group(1))
    expected=spec['geometry_audit']['polygon_nets'];assert set(nets)==set(expected) and len(nets)==10
    for n,p in nets.items():
        q=expected[n];assert len(p)==len(q)
        assert all(math.dist(a,b)<1e-8 for a,b in zip(p,q)),n
    rows=[r.split(',') for r in (folder/'native_parts.csv').read_text().splitlines()]
    assert len(rows)==len(spec['parts'])==16
    on=[];series=shunts=0
    for row,p in zip(rows,spec['parts']):
        assert row[:2]==[p['name'],'RLCSerial']
        values=list(map(float,row[2:]));reference=p['RLC']+p['p1']+p['p2'];assert len(values)==len(reference)
        assert all(abs(a-b)<=max(1e-16,abs(b)*1e-7) for a,b in zip(values,reference))
        R,L,C=values[:3];p1,p2=values[3:6],values[6:9];n=p['name'].split(':')[1]
        if p['name'].startswith('SP4T:'):
            series+=1;assert inside(p1[:2],nets[n[0]+'_common']) and inside(p2[:2],nets[n])
            assert abs(p1[2]-p2[2])<1e-8
            if R>0:on.append(n)
        else:
            shunts+=1;assert p['name'].startswith('SHUNT:') and inside(p1[:2],nets[n])
            assert abs(p2[2]-ground_z)<1e-8 and inside(p2[:2],ground)
            assert not any(inside(p2[:2],cut) for cut in cuts),'Ground contact falls in an aperture'
            assert R==0 and L==0 and C>0
    assert series==shunts==8
    assert sorted(on)==sorted([spec['phase_order_H'][spec['H_state']-1],spec['phase_order_V'][spec['V_state']-1]])
    result={'passed':True,'native_history_sha256':hashlib.sha256(raw).hexdigest(),'RF_nets':10,'series_RLC':series,'ground_shunts':shunts,'on_branches':on,'actual_polygons_match_preflight':True,'all_contacts_inside_actual_metal':True,'all_shunts_on_unslotted_ground':True,'paper_geometry_certified':False}
    if write_report:(folder/'native_structure_audit.json').write_text(json.dumps(result,indent=2))
    return result
