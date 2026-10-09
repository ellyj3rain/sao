"""Exact publisher policy controls; this test neither mutates source nor launches a game."""
import argparse,copy,hashlib,json
from pathlib import Path
from unittest.mock import patch
from scanner_inventory import Inventory,ROOT,sha
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);args=ap.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 tool=ROOT/'tools/source_namespace_contracts.json';data=json.loads(tool.read_text());inventory=Inventory()
 inputs={str(tool):sha(tool.read_bytes()),str(ROOT/'tools/scanner_inventory.py'):sha((ROOT/'tools/scanner_inventory.py').read_bytes())}
 for p,h in data['qualification']['inputs'].items():assert sha((ROOT/p).read_bytes())==h;inputs[str(ROOT/p)]=h
 checks=[]
 for row in data['contracts']:
  path=ROOT/row['path'];inputs[str(path)]=sha(path.read_bytes());inputs[str(inventory.original(path))]=sha(inventory.original(path).read_bytes())
  for kind in row['accesses']:
   assert inventory.qualified_namespace_access(kind,path,row['name']);checks.append(row['name']+' exact '+kind+' '+row['path'])
  assert not inventory.qualified_namespace_access('CALL',path,row['name']);checks.append(row['name']+' foreign opcode refuses')
  assert not inventory.qualified_namespace_access('GET',path,row['name']+'Extra');checks.append(row['name']+' changed name refuses')
 placement=next(row for row in data['contracts']if row['name']=='KAPlacement')
 overlay=next(row for row in data['contracts']if row['name']=='KAWheelOverlay')
 assert not inventory.qualified_namespace_access('GET',ROOT/overlay['path'],'KAPlacement');checks.append('same owned family cannot satisfy another publisher access')
 assert not inventory.qualified_namespace_access('SET',ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua','KAPlacement');checks.append('new canonical write to qualified name refuses')
 optional = [row for row in data['contracts'] if row['classification'] in ('optional-provider', 'engine-guard')]
 for row in optional:
  assert not inventory.qualified_namespace_access('SET',ROOT/row['path'],row['name']);checks.append(row['name']+' read qualification cannot authorize write')
  proof_path=ROOT/row['qualification']['receiptPath'];proof=json.loads(proof_path.read_text())
  inputs[str(proof_path)]=sha(proof_path.read_bytes());inputs.update(proof['inputsAfter'])
 for row in optional:
  for key in ('receiptSha256','checks','restoredControls'):
   broken=copy.deepcopy(data['contracts'])
   target=next(candidate for candidate in broken if candidate['path']==row['path'] and candidate['name']==row['name'])
   target['qualification'][key]='invalid'
   inventory._namespace_contracts=broken
   assert not inventory.qualified_namespace_access('GET',ROOT/row['path'],row['name'])
   checks.append(row['name']+' changed proof '+key+' refuses')
 inventory._namespace_contracts=copy.deepcopy(data['contracts'])
 dependency_controls=[]
 restored_rows=[row for row in data['contracts']if row.get('restoredControl')]
 for row in restored_rows:
  for field,key in [('restoredControl','receiptSha256'),('scopedControlJoin','sha256')]:
   broken=copy.deepcopy(data['contracts']);target=next(c for c in broken if c['path']==row['path'] and c['name']==row['name'])
   target[field][key]='0'*64;inventory._namespace_contracts=broken
   assert not inventory.qualified_namespace_access('GET',ROOT/row['path'],row['name'])
   dependency_controls.append(row['name']+' '+row['path']+' invalid '+field+' refuses')
  del inventory._namespace_contracts
  blocked={Path(row['restoredControl']['receipt']).resolve(),(ROOT/row['scopedControlJoin']['path']).resolve()}
  original_read=Path.read_bytes
  def unavailable(path):
   if path.resolve()in blocked:raise OSError('controlled missing qualification dependency')
   return original_read(path)
  with patch.object(Path,'read_bytes',unavailable):
   assert not inventory.qualified_namespace_access('GET',ROOT/row['path'],row['name'])
  dependency_controls.append(row['name']+' '+row['path']+' missing negative receipt/join refuses')
  del inventory._namespace_contracts
  assert inventory.qualified_namespace_access('GET',ROOT/row['path'],row['name'])
 inputs.update(inventory.namespace_evidence_inputs())
 mutations=['sourceId','sourceSha256','runtimeSha256','lifetime','routine','classification']
 controls=dependency_controls
 for key in mutations:
  broken=copy.deepcopy(data['contracts'])
  for row in broken:
   if row['name']=='KAPlacement':row[key]=''
  inventory._namespace_contracts=broken
  assert not inventory.qualified_namespace_access('GET',ROOT/placement['path'],'KAPlacement')
  controls.append(key+' defect refuses exact access')
 inventory._namespace_contracts=copy.deepcopy(data['contracts'])
 with patch('scanner_inventory.sha',return_value='0'*64):
  assert not inventory.qualified_namespace_access('GET',ROOT/placement['path'],'KAPlacement')
 controls.append('runtime/original byte drift refuses')
 del inventory._namespace_contracts
 with patch('scanner_inventory.sha',return_value='0'*64):
  assert not inventory.qualified_namespace_access('GET',ROOT/placement['path'],'KAPlacement')
 controls.append('qualification input drift refuses')
 del inventory._namespace_contracts
 assert inventory.qualified_namespace_access('GET',ROOT/placement['path'],'KAPlacement')
 # An actual blanket waiver flips the new-file and cross-path refusal verdict.
 with patch.object(Inventory,'qualified_namespace_access',return_value=True):
  assert inventory.qualified_namespace_access('SET',ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua','KAPlacement')
 controls.append('restored blanket waiver detected by canonical-write refusal')
 after={p:sha(Path(p).read_bytes())for p in inputs}
 assert after==inputs
 result={'schema':'sao.source-namespace-contract-controls/1','status':'PASS','checks':len(checks),'controls':controls,'inputsBefore':inputs,'inputsAfter':after,'boundary':'Exact source/byte/kind publisher policy with negative new-caller, cross-path and drift controls. Native behavior qualification is separately pinned at421 checks/37 restored controls; no raw name-prefix or family waiver.'}
 (out/'receipt.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'status':'PASS','checks':len(checks),'controls':len(controls)}))
 return 0
if __name__=='__main__':raise SystemExit(main())
