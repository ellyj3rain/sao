"""Exact source state lifetimes on native Event/light/moddata/WornItems receivers."""
import argparse,json,hashlib,os,subprocess,tempfile,re
from unittest.mock import patch
from pathlib import Path
import d2_source_package as package
ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';LEAF=ROOT/'_scratch/d2-leisure-01/source-state-lifetimes';FIX=ROOT/'tools/d2_source_state_lifetimes';GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
MODES={'juke':'server/LSservercommands.lua','mirror':'client/ISUI/LSMirrorMenu.lua','tub':'shared/TimedActions/LSUseTub.lua'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);ap.add_argument('--current',action='store_true');a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);folder=MOD/'media/lua' if a.current else LEAF/'proposed'
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'];jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))];compiler=ROOT/'tools/luacheck/LuaGlobals.java'
 mf=json.loads((MOD/'media/SAOSources/manifest.json').read_text());vault=MOD/mf['sources']['LifestyleHobbies']['originalRoot']
 bath=MOD/'media/lua/client/Hygiene/BathContextMenu.lua'
 inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',compiler,*FIX.iterdir(),*native,*jars,GAME/'stdlib.lua',*[folder/p for p in MODES.values()],*[LEAF/'before/mod/42.20/media/lua'/p for p in MODES.values()],*[vault/'media/lua'/p for p in MODES.values()],vault/'provenance/selected-mod.info',bath]
 pins={str(p):sha(p) for p in inputs if p.is_file()};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'controls':[],'boundary':'Native Kahlua full original-derived modules; actual Event OnClientCommand, IsoCell add/remove lamp stack and IsoLightSource life, IsoObject moddata native save/load dropping userdata, actual WornItems/InventoryItem receiver snapshots. IsoCell allocation/lamppost initialization, geometric discovery/overlay renderer, body/queue, mirror UI private arrays/closure exposure and reentrant scheduling controlled. No rendered/gameplay/engine-frame or MP assertion. Dormant JukeTurnedOn public receiver, not live source producer.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);p=out/(name+'.log');p.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':sha(p)});save();return r.returncode,p.read_text(errors='replace')
 save()
 try:
  for path in MODES.values():
   content=package.adapt_lifestyle_state_lifetimes((LEAF/'before/mod/42.20/media/lua'/path).read_bytes(),path)[0]
   if a.current:content=package.adapt_source_namespace_lifetimes(content,'LifestyleHobbies','media/lua/'+path)[0]
   assert content==(folder/path).read_bytes()
  with tempfile.TemporaryDirectory(prefix='sao-lifetimes-importer-')as temp:
   ws=Path(temp)/'workshop';allSources=package.SOURCES;package.SOURCES={'LifestyleHobbies':allSources['LifestyleHobbies']}
   try:
    spec=package.SOURCES['LifestyleHobbies'];selected=ws/spec[0]/spec[1]
    for path in MODES.values():
     dest=selected/'media/lua'/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((vault/'media/lua'/path).read_bytes())
    (selected/'mod.info').write_bytes((vault/'provenance/selected-mod.info').read_bytes())
    _,outputs,collisions=package.build_plan(ws,Path(temp)/'mod');assert not collisions
    for path in MODES.values():assert outputs['media/lua/'+path]==(folder/path).read_bytes()
    actual=package.adapt_lifestyle_state_lifetimes
    for path in MODES.values():
     def bypass(raw,p):return (raw,[]) if p=='media/lua/'+path else actual(raw,p)
     with patch.object(package,'adapt_lifestyle_state_lifetimes',bypass):
      if a.current and path!='server/LSservercommands.lua':
       # Later exact preimage guards refuse an omitted earlier lifetime seam.
       try:package.build_plan(ws,Path(temp)/'mod')
       except ValueError as error:assert 'Source namespace lifetime preimage changed' in str(error)
       else:raise AssertionError('later adapter accepted omitted lifetime seam: '+path)
      else:
       _,broken,_=package.build_plan(ws,Path(temp)/'mod');assert broken['media/lua/'+path]!=outputs['media/lua/'+path]
       for other in MODES.values():
        if other!=path:assert broken['media/lua/'+other]==outputs['media/lua/'+other]
    receipt['actualImporterOmissionControls']=3
   finally:package.SOURCES=allSources
  with tempfile.TemporaryDirectory(prefix='sao-state-lifetimes-')as temp:
   work=Path(temp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-cp',cp,'-d',work,FIX/'StateProbe.java',compiler],work);assert code==0,log
   code,log=run('native-globals',[JDK/'java.exe','-cp',str(work)+os.pathsep+cp,'LuaGlobals',*[folder/p for p in MODES.values()]],work);assert code==0,log
   for op,name in [('GET','JukeboxLightOn'),('SET','JukeboxLightOn'),('SET','previousMakeUp'),('GET','resetPlayerModel'),('SET','resetPlayerModel'),('SET','overlayDirtSpriteSub2'),('SET','overlayDirtSpriteSub3')]:assert not any(line.startswith(op+' '+name+' ') for line in log.splitlines()),(op,name)
   checks={}
   for mode,path in MODES.items():
    marker={'juke':'distinct_object_native_light_lifetimes','mirror':'preview_transaction_does_not_publish_foreign_state','tub':'constructor_owns_both_dirt_fields'}[mode]
    for variant in ['production','original-restored']:
     src=folder/path if variant=='production' else LEAF/'before/mod/42.20/media/lua'/path
     code,log=run(mode+'-'+variant,[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'StateProbe',mode,FIX/'prelude.lua',*native,src,*([bath] if mode=='tub' else []),FIX/'cases.lua'],work)
     if variant=='production':assert code==0 and 'PASS state mode='+mode in log,log[-9000:];checks[mode]=int(float(re.search('checks=([0-9.]+)',log)[1]))
     else:assert code!=0 and 'D2_STATE:'+marker in log,(mode,log[-8000:]);receipt['controls'].append({'mode':mode,'expectedFailure':marker})
   controls=[('current-cell-membership','juke','local currentLamp = mainLight and mainLight ~= 0 and JukeboxCell:getLamppostPositions():contains(mainLight)','local currentLamp = mainLight and mainLight ~= 0','stale_native_cell_handles_require_current_membership'),
    ('tub-second-field-restored','tub','o.overlayDirtSpriteSub3 = false','overlayDirtSpriteSub3 = false','constructor_owns_both_dirt_fields')]
   for name,mode,good,bad,marker in controls:
    raw=(folder/MODES[mode]).read_bytes();assert raw.count(good.encode())==1;target=out/(name+'.lua');target.write_bytes(raw.replace(good.encode(),bad.encode(),1))
    code,log=run(name,[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'StateProbe',mode,FIX/'prelude.lua',*native,target,*([bath] if mode=='tub' else []),FIX/'cases.lua'],work)
    assert code!=0 and 'D2_STATE:'+marker in log,(name,log[-6000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
   raw=(folder/MODES['mirror']).read_bytes();good=b'local makeupItem, idxStart, idxEnd, previousMakeup, resetPlayerModel';bad=b'local makeupItem, idxStart, idxEnd, previousMakeup';assert raw.count(good)==1
   target=out/'mirror-reset-global-bytecode.lua';target.write_bytes(raw.replace(good,bad,1))
   code,log=run('mirror-reset-global-bytecode',[JDK/'java.exe','-cp',str(work)+os.pathsep+cp,'LuaGlobals',target],work)
   assert code==0 and any(line.startswith('GET resetPlayerModel ') for line in log.splitlines()) and any(line.startswith('SET resetPlayerModel ') for line in log.splitlines())
   receipt['nativeExposureCounterfactuals']=1
  receipt['inputsAfter']={p:sha(Path(p)) for p in pins};assert pins==receipt['inputsAfter'];receipt.update(status='PASS',checksByMode=checks,checks=sum(checks.values()),nativeCompilerFiles=3);save();print('PASS source lifetimes',receipt['checks'],len(receipt['controls']))
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
