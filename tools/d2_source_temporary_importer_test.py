"""Qualify real importer installation; reuse exact staged source/native proof by byte identity."""
import argparse,json,hashlib,tempfile
from pathlib import Path
from unittest.mock import patch
import d2_source_package as package
ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';STAGE=ROOT/'_scratch/d2-leisure-01/source-temporary-staging01';LEAF=ROOT/'_scratch/d2-leisure-01/source-temporary-compatibility'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);args=ap.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 mp=MOD/'media/SAOSources/manifest.json';mf=json.loads(mp.read_text());prior=json.loads((LEAF/'before/mod/42.20/media/SAOSources/manifest.json').read_text());paths=['media/lua/'+p for p in package.LIFESTYLE_TEMPORARY_PREIMAGES];vault=MOD/mf['sources']['LifestyleHobbies']['originalRoot'];nativeProof=STAGE/'proof06/receipt.json';native=json.loads(nativeProof.read_text())
 inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',mp,MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',nativeProof,*[MOD/p for p in paths],*[vault/p for p in paths],vault/'provenance/selected-mod.info',*[MOD/s['sentinel'] for s in mf['sources'].values()]]
 pins={str(p):sha(p) for p in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'reuse':'Staged proof06 native GET/SET and causal execution applies to exact identical five production runtime postimages; source/test/authority inputs other than changed BASE preimages remain exact. Historical before source rows explicitly reused as preimages, not claimed current.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save()
 try:
  assert native['status']=='PASS' and native['inputsBefore']==native['inputsAfter']
  reused={}
  for p,h in native['inputsAfter'].items():
   path=Path(p)
   if str(path).startswith(str(ROOT/'mod/42.20/media/lua')):
    relative=path.relative_to(ROOT/'mod/42.20/media/lua');assert sha(LEAF/'before/mod/42.20/media/lua'/relative)==h
   else:assert sha(path)==h;reused[p]=h
  delta=[b['selectedPath'] for a,b in zip(prior['files'],mf['files']) if a!=b];assert len(prior['files'])==len(mf['files'])==89521 and sorted(delta)==sorted(paths)
  assert mf['mergeRequired']==prior['mergeRequired'] and [s for s in mf['sources'] if mf['sources'][s]!=prior['sources'][s]]==['LifestyleHobbies']
  for path in paths:
   short=path[len('media/lua/'):];raw=(vault/path).read_bytes();base,_=package.adapt_lua(raw,'LifestyleHobbies');new,adapt=package.adapt_lifestyle_temporaries(base,path)
   assert base==(LEAF/'before/mod/42.20'/path).read_bytes() and new==(MOD/path).read_bytes()==(STAGE/'proposed'/short).read_bytes()
   try:package.adapt_lifestyle_temporaries(b'changed source',path);raise AssertionError('changed source accepted')
   except ValueError:pass
  with tempfile.TemporaryDirectory(prefix='sao-temporary-importer-') as temp:
   ws=Path(temp)/'workshop';priorSources=package.SOURCES;package.SOURCES={'LifestyleHobbies':priorSources['LifestyleHobbies']}
   try:
    spec=package.SOURCES['LifestyleHobbies'];selected=ws/spec[0]/spec[1]
    for path in paths:
     dest=selected/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((vault/path).read_bytes())
    (selected/'mod.info').write_bytes((vault/'provenance/selected-mod.info').read_bytes())
    _,outputs,collisions=package.build_plan(ws,Path(temp)/'mod');assert not collisions
    for path in paths:assert outputs[path]==(MOD/path).read_bytes()
    real=package.adapt_lifestyle_temporaries
    for target in paths:
     def bypass(raw,path):return (raw,[]) if path==target else real(raw,path)
     with patch.object(package,'adapt_lifestyle_temporaries',bypass):
      _,broken,_=package.build_plan(ws,Path(temp)/'mod');assert broken[target]!=outputs[target]
      for other in paths:
       if other!=target:assert broken[other]==outputs[other]
   finally:package.SOURCES=priorSources
  receipt['inputsAfter']={p:sha(Path(p)) for p in pins};assert receipt['inputsAfter']==pins
  receipt.update(status='PASS',exactNativeSourceReused=True,reusedNativeInputs=reused,actualImporterOmissionControls=5,changedRows=5,unchangedRows=89516,changedFamilySeals=1,registrationFragmentsUnchanged=True);save();print('PASS five exact production/native source joins and five actual importer omission controls')
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
