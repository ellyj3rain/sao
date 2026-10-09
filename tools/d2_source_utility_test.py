"""Two exact packaged source leaves: native Event, fluid receiver and refusal text."""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
import d2_source_package as package

ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';FIX=ROOT/'tools/d2_source_utility_compatibility'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
UTILITY='media/lua/shared/LSUtil.lua';ARCADE='media/lua/client/TimedActions/ProjectArcade_PunchingTimedAction.lua'
CHANGES={
 'capacity':(UTILITY,b'if args[2] then fluidContainer:setCapacity(args[2]); end',b'if arg[2] then fluidContainer:setCapacity(arg[2]); end','supplied_capacity_original_branch'),
 'loop':(UTILITY,b'local function stopLoopedSounds()',b'local stopLoopedSounds = function()','loop_retired'),
 'delay':(UTILITY,b'local function playNextSound()',b'local playNextSound = function()','delay_retired'),
 'text':(ARCADE,b'Say(getText("ContextMenu_ProjectArcade_NotEnoughCoins"))',b'Say(GetText("ContextMenu_ProjectArcade_NotEnoughCoins"))','native_refusal_text_branch'),
}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--out',required=True,type=Path);args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 mp=MOD/'media/SAOSources/manifest.json';current=json.loads(mp.read_text());previous=json.loads((ROOT/'_scratch/d2-leisure-01/source-utility-compatibility/before/mod/42.20/media/SAOSources/manifest.json').read_text())
 originals=[MOD/current['sources'][s]['originalRoot']/p for s,p in [('LifestyleHobbies',UTILITY),('ProjectArcade',ARCADE)]]
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',mp,MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',*[MOD/s['sentinel'] for s in current['sources'].values()],*originals,MOD/UTILITY,MOD/ARCADE,*FIX.iterdir(),*native,GAME/'projectzomboid.jar',GAME/'stdlib.lua',GAME/'media/lua/shared/Translate/EN/ContextMenu.json',MOD/'media/lua/shared/Translate/EN/ContextMenu.json']
 pins={str(p):sha(p) for p in inputs if p.is_file()};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'boundary':'Full original packaged utility and punching action under native Kahlua. Installed native Event dispatch and registration/removal, actual IsoFeedingTrough fluid creation/capacity and empty native ItemContainer/Translator. Lua wrappers expose the exact captured native fluid receiver; sound hardware, actor Say and original base queue/log presentation are controlled. Controlled Event cadence is not rendered game clock or NPC gameplay. Original generic IsoObject/InventoryItem receiver compatibility is not granted.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save()
 try:
  assert len(current['files'])==89521 and sum(a!=b for a,b in zip(previous['files'],current['files']))==2
  assert current['mergeRequired']==previous['mergeRequired']
  assert [s for s in current['sources'] if current['sources'][s]!=previous['sources'][s]]==['LifestyleHobbies','ProjectArcade']
  for source,path,adapter in [('LifestyleHobbies',UTILITY,package.adapt_lifestyle_utility_bindings),('ProjectArcade',ARCADE,package.adapt_arcade_punching_text)]:
   raw=(MOD/current['sources'][source]['originalRoot']/path).read_bytes();base,_=package.adapt_lua(raw,source);new,adaptations=adapter(base,path)
   assert base==(ROOT/'_scratch/d2-leisure-01/source-utility-compatibility/before/mod/42.20'/path).read_bytes() and new==(MOD/path).read_bytes()
   back=new
   for p,good,bad,marker in CHANGES.values():
    if p==path:assert back.count(good)==1;back=back.replace(good,bad,1)
   assert back==base
   try:adapter(base.replace(next(bad for p,good,bad,marker in CHANGES.values() if p==path),b'changed-anchor',1),path);raise AssertionError('tampered anchor accepted')
   except ValueError:pass
  with tempfile.TemporaryDirectory(prefix='sao-utility-') as temp:
   work=Path(temp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=str(GAME/'projectzomboid.jar')
   done=subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(FIX/'UtilityProbe.java')],capture_output=True);(out/'compile.log').write_bytes(done.stdout+done.stderr);assert done.returncode==0,(done.stdout+done.stderr).decode(errors='replace')
   for mode,(path,good,bad,marker) in CHANGES.items():
    restored=out/(mode+'-restored.lua');restored.write_bytes((MOD/path).read_bytes().replace(good,bad,1))
    for variant in ['production','restored']:
     utility=restored if variant=='restored' and path==UTILITY else MOD/UTILITY;arcade=restored if variant=='restored' and path==ARCADE else MOD/ARCADE
     command=[str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'UtilityProbe',str(GAME),str(MOD),mode,str(FIX/'prelude.lua'),*map(str,native),str(utility),str(arcade),str(FIX/'cases.lua')]
     done=subprocess.run(command,capture_output=True,cwd=work,timeout=45);log=out/(mode+'-'+variant+'.log');log.write_bytes(done.stdout+done.stderr);text=log.read_text(errors='replace')
     expected=None if variant=='production' else 'D2_UTILITY:'+marker
     receipt['runs'].append({'mode':mode,'variant':variant,'exit':done.returncode,'expectedFailure':expected,'logSha256':sha(log)});save()
     assert (done.returncode==0 and 'PASS native utility mode='+mode in text) if expected is None else (done.returncode!=0 and expected in text),text
   # Real build_plan must install the exact two adaptations, not a test-only replacement.
   prior=package.SOURCES;package.SOURCES={s:prior[s] for s in ['LifestyleHobbies','ProjectArcade']}
   try:
    workshop=work/'workshop'
    for source,path in [('LifestyleHobbies',UTILITY),('ProjectArcade',ARCADE)]:
     spec=package.SOURCES[source];selected=workshop/spec[0]/spec[1];target=selected/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((MOD/current['sources'][source]['originalRoot']/path).read_bytes());(selected/'mod.info').write_bytes((MOD/current['sources'][source]['originalRoot']/'provenance/selected-mod.info').read_bytes())
    _,outputs,collisions=package.build_plan(workshop,work/'mod');assert not collisions and outputs[UTILITY]==(MOD/UTILITY).read_bytes() and outputs[ARCADE]==(MOD/ARCADE).read_bytes()
    from unittest.mock import patch
    with patch.object(package,'adapt_lifestyle_utility_bindings',lambda raw,path:(raw,[])):
     _,broken,_=package.build_plan(workshop,work/'mod');assert broken[UTILITY]!=(MOD/UTILITY).read_bytes() and broken[ARCADE]==outputs[ARCADE]
    with patch.object(package,'adapt_arcade_punching_text',lambda raw,path:(raw,[])):
     _,broken,_=package.build_plan(workshop,work/'mod');assert broken[ARCADE]!=(MOD/ARCADE).read_bytes() and broken[UTILITY]==outputs[UTILITY]
   finally:package.SOURCES=prior
  receipt['inputsAfter']={p:sha(Path(p)) for p in pins};assert receipt['inputsAfter']==pins
  receipt.update(status='PASS',nativeBranches=4,restoredSourceControls=4,actualImporterCaller=True,restoredImporterControls=2,changedRows=2,unchangedRows=89519,changedFamilySeals=2,registrationFragmentsUnchanged=True,sourceBodiesOtherwiseByteExact=True);save();print('PASS4 native branches/4restored source controls +2 actual importer omission controls')
 except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise
if __name__=='__main__':main()
