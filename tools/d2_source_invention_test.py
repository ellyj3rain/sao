"""Three exact source bindings: actual native Lua/visual/moddata and original callers."""
import argparse,json,hashlib,os,subprocess,tempfile
from pathlib import Path
from unittest.mock import patch
import d2_source_package as package
ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';FIX=ROOT/'tools/d2_source_invention_compatibility';BEFORE=ROOT/'_scratch/d2-leisure-01/source-invention-compatibility/before'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
CHANGES={
'activate':('media/lua/shared/Inventions/inventions_func.lua',b'\tlocal data = item:getModData().movableData\r\n',b'','item_local_activation'),
'press':('media/lua/shared/TimedActions/LSInvNeuralHatPress.lua',b'LSUtil.playSoundCharacter(self.character, "Gadget_WOOSH"',b'LSUtil.playSoundCharacter(character, "Gadget_WOOSH"','action_owned_character_sound'),
'melt':('media/lua/client/Painting/Sculpting/IceObjs.lua',b'\t\tsqr:RemoveTileObject(object)\r\n',b'\t\tsqr:RemoveTileObject(obj)\r\n','exact_supplied_sculpture_removed')}
DEPS=['media/lua/shared/LSUtil.lua','media/lua/shared/Inventions/inventions_func.lua','media/lua/shared/Inventions/inventions_net.lua','media/lua/shared/TimedActions/LSInvNeuralHatPress.lua','media/lua/client/Inventions/NeuralHat.lua','media/lua/client/Helper/InteractiveObjs.lua','media/lua/client/Painting/Sculpting/IceObjs.lua']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);args=ap.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 mp=MOD/'media/SAOSources/manifest.json';mf=json.loads(mp.read_text());prior=json.loads((BEFORE/'mod/42.20/media/SAOSources/manifest.json').read_text());orig=MOD/mf['sources']['LifestyleHobbies']['originalRoot']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',mp,MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',*[MOD/s['sentinel'] for s in mf['sources'].values()],*FIX.iterdir(),*native,GAME/'projectzomboid.jar',GAME/'stdlib.lua',*[MOD/p for p in DEPS],*[orig/p for p in DEPS],orig/'provenance/selected-mod.info',MOD/'media/scripts/Lifestyle_items.txt',MOD/'media/lua/client/SAO_LeisureMusic.lua',MOD/'media/lua/client/SAO_LeisureLifestyle.lua']
 pins={str(p):sha(p) for p in inputs if p.is_file()};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'boundary':'Installed Kahlua compiler/runtime, actual ItemVisual texture-choice and IsoObject moddata. Full current original-derived modules; original NeuralHat menu to Press constructor to source utility/native visual completion; LSrefreshIO original list/name/close/on-square predicates to SculptureIce to local melt callback. Actor/clothing, queue/action timing, geometry/square removal, audio/model rendering and network synchronization hosts are controlled. No native owned-body or rendered gameplay claim. OnActivateNeuralHat qualified as public entry only: no current source or item-script caller found. Private Music/Lifestyle inventories do not include these three modules.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save()
 try:
  assert len(mf['files'])==len(prior['files'])==89521
  delta=[b['selectedPath'] for a,b in zip(prior['files'],mf['files']) if a!=b];assert sorted(delta)==sorted(x[0] for x in CHANGES.values())
  assert mf['mergeRequired']==prior['mergeRequired'] and [s for s in mf['sources'] if mf['sources'][s]!=prior['sources'][s]]==['LifestyleHobbies']
  for mode,(path,good,bad,marker) in CHANGES.items():
   raw=(orig/path).read_bytes();base,_=package.adapt_lua(raw,'LifestyleHobbies');new,adapt=package.adapt_lifestyle_invention_bindings(base,path)
   assert base==(BEFORE/'mod/42.20'/path).read_bytes() and new==(MOD/path).read_bytes() and new.count(good)==1 and new.replace(good,bad,1)==base
   try:package.adapt_lifestyle_invention_bindings(b'changed anchor',path);raise AssertionError('changed source accepted')
   except ValueError:pass
  with tempfile.TemporaryDirectory(prefix='sao-invention-') as temp:
   work=Path(temp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=str(GAME/'projectzomboid.jar')
   done=subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(FIX/'InventionProbe.java')],capture_output=True);(out/'compile.log').write_bytes(done.stdout+done.stderr);assert done.returncode==0,(done.stdout+done.stderr).decode(errors='replace')
   for mode,(path,good,bad,marker) in CHANGES.items():
    restored=out/(mode+'-restored.lua');restored.write_bytes((MOD/path).read_bytes().replace(good,bad,1))
    for variant in ['production','restored']:
     sources=[restored if variant=='restored' and p==path else MOD/p for p in DEPS]
     cmd=[str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'InventionProbe',mode,str(FIX/'prelude.lua'),*map(str,native),*map(str,sources),str(FIX/'cases.lua')]
     run=subprocess.run(cmd,capture_output=True,cwd=work,timeout=45);log=out/(mode+'-'+variant+'.log');log.write_bytes(run.stdout+run.stderr);text=log.read_text(errors='replace');expected=None if variant=='production' else 'D2_INVENTION:'+marker
     receipt['runs'].append({'mode':mode,'variant':variant,'exit':run.returncode,'expectedFailure':expected,'logSha256':sha(log)});save()
     assert (run.returncode==0 and 'PASS native source mode='+mode in text) if expected is None else (run.returncode!=0 and expected in text),text
   oldSources=package.SOURCES;package.SOURCES={'LifestyleHobbies':oldSources['LifestyleHobbies']}
   try:
    ws=work/'workshop';spec=package.SOURCES['LifestyleHobbies'];selected=ws/spec[0]/spec[1]
    for path,good,bad,marker in CHANGES.values():
     dest=selected/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((orig/path).read_bytes())
    (selected/'mod.info').write_bytes((orig/'provenance/selected-mod.info').read_bytes())
    _,outputs,conflicts=package.build_plan(ws,work/'mod');assert not conflicts
    for path,good,bad,marker in CHANGES.values():assert outputs[path]==(MOD/path).read_bytes()
    realAdapter=package.adapt_lifestyle_invention_bindings
    for selectedPath,good,bad,marker in CHANGES.values():
     def bypass(raw,path):return (raw,[]) if path==selectedPath else realAdapter(raw,path)
     with patch.object(package,'adapt_lifestyle_invention_bindings',bypass):
      _,broken,_=package.build_plan(ws,work/'mod');assert broken[selectedPath]!=(MOD/selectedPath).read_bytes()
      for other,good,bad,marker in CHANGES.values():
       if other!=selectedPath:assert broken[other]==outputs[other]
   finally:package.SOURCES=oldSources
  receipt['inputsAfter']={p:sha(Path(p)) for p in pins};assert receipt['inputsAfter']==pins
  receipt.update(status='PASS',changedRows=3,unchangedRows=89518,changedFamilySeals=1,restoredSourceControls=3,actualImporterCaller=True,restoredImporterControls=3,registrationFragmentsUnchanged=True,sourceBodiesOtherwiseByteExact=True);save();print('PASS3 source routes/3restored source controls+3real importer omission controls')
 except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise
if __name__=='__main__':main()
