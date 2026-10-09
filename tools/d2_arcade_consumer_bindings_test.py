"""Lazy exact Arcade consumer owners; full native source-inactive/tabletop qualification."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,re,subprocess,sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1];LEAF=ROOT/'_scratch/d2-leisure-01/arcade-consumer-bindings-20261006';FIX=ROOT/'tools/d2_arcade_consumer_bindings'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin');BASE=ROOT/'tools/d2_leisure_games';ART=ROOT/'tools/d2_leisure_art/fixture.lua';RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java';OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureGames.lua'
SOURCE=ROOT/'_scratch/d2-leisure-01/residual-music-arcade-20261006';POLICY=SOURCE/'proposed/shared/ProjectArcade_SoundPolicy.lua';AMBIENT=ROOT/'mod/42.20/media/lua/client/ProjectArcade_ArcadeAmbientSound.lua'
PRIVATE_JAR=ROOT/'_scratch/d2-leisure-01/private-build21/SAOAgent.jar'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);args=ap.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 stage=json.loads((LEAF/'stage-receipt.json').read_text());native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'];inputs=[Path(__file__),*FIX.iterdir(),LEAF/'before.lua',LEAF/'proposed.lua',LEAF/'stage-receipt.json',RUNNER,ROOT/'tools/luacheck/LuaGlobals.java',ART,BASE/'fixture.lua',BASE/'source_profile.py',*native,POLICY,AMBIENT,GAME/'projectzomboid.jar',GAME/'stdlib.lua']
 receipt={'schema':'sao.arcade-consumer-bindings/1','status':'INCOMPLETE','inputsBefore':{str(p):sha(p)for p in inputs if p.is_file()},'runs':[],'controls':[],'boundary':'Complete SAO Lua owner through installed Kahlua and native ISBaseObject/ISBaseTimedAction; existing native tabletop harness. The focused Arcade source loader, UI/object/body/queue/acoustic emitter and ambient Event receivers are controlled. Actual source modules execute lazily through a cached controlled require. No rendered/audio perception or native MP session claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(label,cmd):
  r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=120);p=out/(label+'.log');p.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':label,'exitCode':r.returncode,'logSha256':sha(p)});save();return r.returncode,p.read_text(errors='replace')
 save()
 try:
  assert sha(LEAF/'proposed.lua')==stage['postimageSha256'];assert sha(OWNER)==stage['preimageSha256'];(out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());classes=out/'classes';classes.mkdir();cp=str(GAME/'projectzomboid.jar');code,log=run('compile-host',[JDK/'javac.exe','-cp',cp,'-d',classes,RUNNER,ROOT/'tools/luacheck/LuaGlobals.java']);assert code==0,log;cp=str(classes)+os.pathsep+cp
  code,log=run('full-source-globals',[JDK/'java.exe','-cp',cp,'LuaGlobals',LEAF/'proposed.lua']);assert code==0,log;assert not re.search(r'^GET ArcadeAmbientSound ',log,re.M)
  factories=out/'factories.lua';factories.write_text('__helperFactories={}\n__helperFactories.ProjectArcade_SoundPolicy=function()\n'+POLICY.read_text()+'\nend\n__helperFactories.ProjectArcade_ArcadeAmbientSound=function()\n'+AMBIENT.read_text()+'\nend\n')
  before=(LEAF/'before.lua').read_bytes();proposed=(LEAF/'proposed.lua').read_bytes();delta=stage['edits'];variants=[('proposed',proposed,None)]
  for label,i,marker in [('duration-original-restored',0,'actual_update_bound_duration_module'),('ambient-original-restored',1,'foreign_ambient_consulted')]:
   old=delta[i]['after'].encode();replacement=delta[i]['before'].encode();assert proposed.count(old)==1;variants.append((label,proposed.replace(old,replacement,1),marker))
  eager=delta[0]['after'].encode();new=b'local getLoopDurationMs = (require "ProjectArcade_SoundPolicy").getLoopDurationMs';assert proposed.count(eager)==1;variants.append(('eager-duration-restored',proposed.replace(eager,new,1),'inactive_eager_module_ProjectArcade_SoundPolicy'))
  eagerAmbient=proposed.replace(delta[1]['after'].encode(),delta[1]['before'].encode(),1);eagerAmbient=b'local ArcadeAmbientSound = require "ProjectArcade_ArcadeAmbientSound"\n'+eagerAmbient;variants.append(('eager-ambient-restored',eagerAmbient,'inactive_eager_module_ProjectArcade_ArcadeAmbientSound'))
  for label,raw,marker in variants:
   owner=out/(label+'.lua');owner.write_bytes(raw);paths=[ART,*native,BASE/'fixture.lua',factories,FIX/'setup.lua',owner,FIX/'cases.lua'];code,log=run(label,[JDK/'java.exe','-cp',cp,'PhysicalMeansLuaProbe',*paths,'--','__result'])
   if marker:assert code!=0 and 'ARCADE_BINDING:'+marker in log,(label,log);receipt['controls'].append({'name':label,'expectedFailure':marker})
   else:assert code==0 and 'PASS Arcade consumer bindings 'in log,log;receipt['checks']=int(re.search(r'PASS Arcade consumer bindings (\d+)',log)[1])
  # Run the unchanged complete native tabletop baseline against the lazy proposal.
  modulePath=BASE/'tabletop_test.py';spec=importlib.util.spec_from_file_location('arcade_bindings_tabletop',modulePath);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.OWNER=LEAF/'proposed.lua';module.CONTROLS=[]
  historical=json.loads((ROOT/'_scratch/d2-leisure-01/games/tabletop-proof-24/receipt.json').read_text());jar=next(Path(p)for p in historical['inputsBefore']if p.endswith('SAOAgent.jar'));assert sha(jar)==historical['inputsBefore'][str(jar)]
  oldargs=sys.argv;sys.argv=[str(modulePath),'--output',str(out/'source-inactive-native-tabletop'),'--jar',str(jar)]
  try:code=module.main()
  finally:sys.argv=oldargs
  assert code==0,'source-inactive tabletop baseline';table=json.loads((out/'source-inactive-native-tabletop/receipt.json').read_text());assert table['status']=='PASS';receipt['nativeTabletopChecks']=table['checks'];receipt['nativeTabletopReceiptSha256']=sha(out/'source-inactive-native-tabletop/receipt.json')
  # Original profiles remain exact, apart from the two explicit source owner bindings.
  sys.path.insert(0,str(BASE));profile=importlib.import_module('source_profile');originalArcade=profile.arcade();expected=originalArcade
  for edit in delta:
   old=edit['before'].replace('\r\n','\n');new=edit['after'].replace('\r\n','\n');assert expected.count(old)==1;expected=expected.replace(old,new,1)
  text=proposed.decode().replace('\r\n','\n');assert '-- BEGIN INSTALLED SOURCE ProjectArcade/play\n'+expected+'-- END INSTALLED SOURCE ProjectArcade/play\n'in text
  receipt['sourceProfileQualification']={'exactOriginalProfileSha256':hashlib.sha256(originalArcade.encode()).hexdigest(),'exactDerivedProfileSha256':hashlib.sha256(expected.encode()).hexdigest(),'explicitTransformations':2,'allBroadConsumerSuffixUnchanged':before[before.index(b'local function sourceActive(mod)'):]==proposed[proposed.index(b'local function sourceActive(mod)'):]}
  assert receipt['sourceProfileQualification']['allBroadConsumerSuffixUnchanged'];receipt['inputsAfter']={p:sha(p)for p in receipt['inputsBefore']};assert receipt['inputsBefore']==receipt['inputsAfter'];assert sha(OWNER)==stage['preimageSha256'];receipt.update(status='PASS',productionUnchanged=True);save();print('PASS',receipt['checks'],'focused checks',receipt['nativeTabletopChecks'],'native tabletop checks',len(receipt['controls']),'controls')
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
