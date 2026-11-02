"""A disconnected mirror must preserve local evidence and retry on recovery."""
import importlib.util,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
s=importlib.util.spec_from_file_location('watch',Path(__file__).with_name('local_first_watch.py'))
w=importlib.util.module_from_spec(s);s.loader.exec_module(w)
class MirrorTest(unittest.TestCase):
 def test_denied_then_recovered(self):
  with tempfile.TemporaryDirectory() as td:
   base=Path(td);r=base/'runtime';r.mkdir();dest=base/'mirror';(r/'case_snapshots').mkdir()
   (r/'latest_status.json').write_text(json.dumps({'completed':['state1'],'status':'comparison_complete_requires_audit'}))
   source=r/'case_snapshots/state1.zip';source.write_bytes(b'frozen local evidence')
   original=w.copy_atomic;attempts=[]
   def copy(src,dst):
    attempts.append(str(dst))
    if len(attempts)==1:raise PermissionError('simulated disconnected RDP mirror')
    original(src,dst)
   with patch.object(w,'alive',return_value=False),patch.object(w,'copy_atomic',side_effect=copy),patch.object(w.time,'sleep'),patch.object(w.sys,'argv',['watch',str(r),str(dest),'123']):w.main()
   self.assertEqual(source.read_bytes(),b'frozen local evidence')
   self.assertEqual((dest/'case_snapshots/state1.zip').read_bytes(),source.read_bytes())
   self.assertTrue(json.loads((r/'mirror_retry.json').read_text())['solver_not_interrupted'])
   self.assertFalse(list(dest.rglob('*.sync-tmp')))
   self.assertGreaterEqual(len(attempts),4)
if __name__=='__main__':unittest.main()
