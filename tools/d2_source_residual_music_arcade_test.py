"""Qualify staged full-source NewMusic/Arcade namespace contracts in native Kahlua."""
import argparse,hashlib,json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];LEAF=ROOT/'_scratch/d2-leisure-01/residual-music-arcade-20261006';FIX=ROOT/'tools/d2_source_residual_music_arcade';MOD=ROOT/'mod/42.20/media/lua'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
NB=Path('C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3536052310/mods/Neat_Building/42.15')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
TARGETS={
 'ledger':'server/zombies/NMServerZombieVisualTargetPublisher.lua','media':'client/ui/shared/slots/NMMediaSlotLogic.lua','radial':'client/ui/NMGamepadRadial.lua','time':'client/ui/shared/host/NMDeviceUiTime.lua',
 'contextdrag':'client/ui/shared/slots/NMSlotHostContextCache.lua','framedrag':'client/ui/shared/slots/NMSlotHostFrameBuilder.lua','battery':'client/ui/shared/slots/NMBatterySlotLogic.lua',
 'ambient':'client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua','worldsounds':'client/ProjectArcade_WorldSoundsClient.lua','punch':'client/ProjectArcade_PunchingMachine.lua','menu':'client/ProjectArcade_PAMPlayGameMenu.lua',
 'nb':'server/ProjectArcade_RecipeBridge.lua','nbcompat':'server/ProjectArcade_NB_Compat.lua','tetris':'client/InventoryTetris/DataPacks/Mods/TetrisDataPack_ProjectArcade.lua','server':'server/ProjectArcade_PunchingServer.lua'}
DEPENDENCIES=['shared/zombies/NMZombieVisualTargetLedger.lua','client/ui/walkman/NMWalkmanWindowHelpers.lua','client/ui/cdplayer/NMCDPlayerWindowConstants.lua','client/ui/cdplayer/NMCDPlayerWindowHelpers.lua','client/ui/shared/slots/NMSlotActionCommon.lua','client/TimedActions/ProjectArcade_PunchingTimedAction.lua','client/ProjectArcade_ArcadeAmbientSound.lua','server/Items/ProjectArcade_WorldFiller.lua']
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 stage=json.loads((LEAF/'stage-receipt.json').read_text());staged=LEAF/'proposed';jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))];base=GAME/'media/lua/shared/ISBaseObject.lua';actionBase=GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua';compiler=ROOT/'tools/luacheck/LuaGlobals.java'
 inputs=[Path(__file__),*sorted(FIX.iterdir()),LEAF/'stage-receipt.json',compiler,base,actionBase,GAME/'stdlib.lua',*jars,*[staged/r['path']for r in stage['files']],*[LEAF/'before'/r['path']for r in stage['files']],*[MOD/p for p in DEPENDENCIES],*[staged/r['path']for r in stage['newFiles']],LEAF/'root-proposed'/stage['rootOwnedProposal']['path'],NB/'mod.info',NB/'media/lua/server/buildrecipecode/nb_buildrecipecode.lua',GAME/'media/lua/server/Items/WorldFiller.lua',GAME/'media/lua/server/Items/ApplianceOverlays.lua']
 pins={str(p):sha(p)for p in inputs if p.is_file()};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'controls':[],'boundary':'Complete source modules, actual installed Kahlua compiler/Event/ISBaseObject/ISBaseTimedAction/time APIs/server predicate and external Neat_Building complete Lua module. UI/context/inventory, acoustic emitters, recipe square absence and source-private lexical exposure are controlled. No rendered/acoustic perception/native MP session or building incorporation claim. Tetris complete provider method host is synthetic; actual provider absent.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,args):
  r=subprocess.run(list(map(str,args)),cwd=out,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':sha(log)});save();return r.returncode,log.read_text(errors='replace')
 save()
 try:
  (out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());classes=out/'classes';classes.mkdir();cp=os.pathsep.join(map(str,jars));code,log=run('compile-host',[JDK/'javac.exe','-cp',cp,'-d',classes,FIX/'ResidualMusicArcadeProbe.java',compiler]);assert code==0,log;cp=str(classes)+os.pathsep+cp
  globalsByPath={};forbidden={
   TARGETS['ledger']:['NMServerZombieVisualTargetLedger'],TARGETS['media']:['NMUI'],TARGETS['radial']:['getLoopPolicy','playWalkmanTransportSound','playCDPlayerTransportSound','playCDPlayerRandomBeep','playCDPlayerManualPlaySound'],TARGETS['time']:['getNowMs'],TARGETS['contextdrag']:['resolveDraggedInventoryItemsSnapshot'],TARGETS['framedrag']:['resolveDraggedInventoryItemsSnapshot'],TARGETS['battery']:['timed'],TARGETS['ambient']:['ArcadeAmbientSound'],TARGETS['worldsounds']:['getLoopDurationMs'],TARGETS['punch']:['PA_PlayOneShotAtCharacter'],TARGETS['menu']:['safeGetText'],TARGETS['server']:['isSinglePlayer']}
  for row in stage['files']:
   path=row['path'];assert sha(staged/path)==row['postimageSha256'];code,log=run('globals-'+Path(path).stem,[JDK/'java.exe','-cp',cp,'LuaGlobals',staged/path]);assert code==0,log
   for name in forbidden.get(path,[]):assert not re.search(r'^GET '+re.escape(name)+r' ',log,re.M),(path,name,log)
   globalsByPath[path]=log
  for row in stage['newFiles']+[stage['rootOwnedProposal']]:
   path=row['path'];file=staged/path if row in stage['newFiles']else LEAF/'root-proposed'/path;code,log=run('globals-'+Path(path).stem,[JDK/'java.exe','-cp',cp,'LuaGlobals',file]);assert code==0,log
  def module(path):return(staged/path if(staged/path).exists()else MOD/path)
  def key(path):return re.sub(r'^(client|shared|server)/','',path).removesuffix('.lua')
  def exposure(path,file,label):
   raw=file.read_bytes()
   if path==TARGETS['framedrag']:
    old=b'return function(NMSlotHostLifecycle)';assert raw.count(old)==1;raw=raw.replace(old,b'D2_TEST_LOCAL = resolveDraggedItemsSnapshot\n'+old,1)
   elif path=='client/ProjectArcade_ArcadeAmbientSound.lua':
    old=b'return ArcadeAmbientSound';assert raw.count(old)==1;raw=raw.replace(old,b'D2_AMBIENT_LAST = lastPlayedAt\n'+old,1)
   else:return file
   target=out/(label+'-'+Path(path).name);target.write_bytes(raw);return target
  def behavior(mode,label,restore=None):
   specs={
    'ledger':['shared/zombies/NMZombieVisualTargetLedger.lua',TARGETS['ledger']], 'media':[TARGETS['media']], 'radial':['client/ui/walkman/NMWalkmanWindowHelpers.lua','client/ui/cdplayer/NMCDPlayerWindowConstants.lua','client/ui/cdplayer/NMCDPlayerWindowHelpers.lua',TARGETS['radial']], 'time':[TARGETS['time']],
    'contextdrag':['client/ui/shared/slots/NMSlotActionCommon.lua',TARGETS['contextdrag']], 'framedrag':['client/ui/shared/slots/NMSlotActionCommon.lua',TARGETS['framedrag']], 'battery':[TARGETS['battery']],
    'policy':['shared/ProjectArcade_SoundPolicy.lua'], 'worldsounds':['shared/ProjectArcade_SoundPolicy.lua',TARGETS['worldsounds']], 'punch':[TARGETS['punch']], 'punchsp':['client/TimedActions/ProjectArcade_PunchingTimedAction.lua'],
    'nb':[TARGETS['nb'],TARGETS['nbcompat']], 'tetris':[TARGETS['tetris']], 'server':[TARGETS['server']],
    'ambient':['client/ProjectArcade_ArcadeAmbientSound.lua','shared/ProjectArcade_SoundPolicy.lua',TARGETS['ambient']], 'menu':[TARGETS['menu']],
    'tiletrue':['server/Items/ProjectArcade_WorldFiller.lua'],'tilefalse':['server/Items/ProjectArcade_WorldFiller.lua'],'tilenil':['server/Items/ProjectArcade_WorldFiller.lua']}
   args=[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',cp,'ResidualMusicArcadeProbe',mode,FIX/'prelude.lua',base,actionBase]
   for path in specs[mode]:
    file=restore[1]if restore and restore[0]==path else module(path);file=exposure(path,file,label)
    args.append('module='+key(path)+'='+str(file))
   args.append(FIX/'cases.lua');return run(label,args)
  checks={}
  for mode in ['time','ledger','media','radial','contextdrag','framedrag','battery','policy','worldsounds','punch','punchsp','nb','tetris','server','ambient','menu','tiletrue','tilefalse','tilenil']:
   code,log=behavior(mode,mode+'-proposed');assert code==0,log;checks[mode]=int(float(re.search(r'checks=([\d.]+)',log)[1]))
  for label,path in TARGETS.items():
   mode='nb'if label=='nbcompat'else label;code,log=behavior(mode,label+'-original-restored',(path,LEAF/'before'/path));assert code!=0 and 'D2_RESIDUAL:'in log,(label,log)
   receipt['controls'].append({'name':label+'-original-restored','path':path,'type':'actual-original-source-behavior'})
  raw=(MOD/'server/Items/ProjectArcade_WorldFiller.lua').read_bytes();assert raw.count(b'if not TILEZED then')==1;mutated=out/'tile-unguarded-restored.lua';mutated.write_bytes(raw.replace(b'if not TILEZED then',b'if true then',1));code,log=behavior('tiletrue','tile-unguarded-restored',('server/Items/ProjectArcade_WorldFiller.lua',mutated));assert code!=0 and 'D2_RESIDUAL:exact_native_editor_guard_'in log;receipt['controls'].append({'name':'tile-unguarded-restored','type':'actual-source-guard-restored'})
  for mode in ['native-tiletrue','native-tilefalse','native-tilenil']:
   files=[GAME/'media/lua/server/Items/WorldFiller.lua',GAME/'media/lua/server/Items/ApplianceOverlays.lua'];args=[JDK/'java.exe','-cp',cp,'ResidualMusicArcadeProbe',mode,FIX/'prelude.lua',base]
   args.extend('module=native'+str(i)+'='+str(file)for i,file in enumerate(files));args.append(FIX/'cases.lua');code,log=run(mode,args);assert code==0,log;checks[mode]=int(float(re.search(r'checks=([\d.]+)',log)[1]))
  assert 'id=Neat_Building' in(NB/'mod.info').read_text()
  for order in ['first','later']:
   before=out/('nb-'+order+'-before.lua');before.write_text("MOD_ID='Neat_Building'\n"+("nativeEmit('OnGameBoot');check(ProjectArcade_NBCompatPatched==nil,'actual_late_provider_admission_not_consumed')\n"if order=='later'else ''))
   paths=[NB/'media/lua/server/buildrecipecode/nb_buildrecipecode.lua',module(TARGETS['nb']),module(TARGETS['nbcompat'])];args=[JDK/'java.exe','-cp',cp,'ResidualMusicArcadeProbe','nb-actual',FIX/'prelude.lua',base]
   if order=='first':args.extend('module=nb'+str(i)+'='+str(p)for i,p in enumerate(paths));args.append(before)
   else:
    args.extend('module=nb'+str(i)+'='+str(p)for i,p in enumerate(paths[1:]));args.append(before);args.append('module=actualProvider='+str(paths[0]))
   cases=out/('nb-'+order+'-cases.lua');cases.write_text("local original=NB_BuildRecipeCode.Floors.OnCreate;check(type(original)=='function','actual_complete_provider_method');nativeEmit('OnGameStart');local wrapped=NB_BuildRecipeCode.Floors.OnCreate;check(wrapped~=original and ProjectArcade_NBCompatPatched==true,'actual_provider_admitted');nativeEmit('OnGameBoot');nativeEmit('OnGameStart');check(NB_BuildRecipeCode.Floors.OnCreate==wrapped,'actual_provider_exactly_once');check(ProjectArcade.RecipeBridge.Floors.OnCreate(nil)==nil and NATIVE_BUILD==nil,'actual_provider_nil_square_return_preserved');PROVEN=true\n")
   args.append(cases);code,log=run('nb-actual-'+order,args);assert code==0,log;checks['nb-actual-'+order]=int(float(re.search(r'checks=([\d.]+)',log)[1]))
  receipt['inputsAfter']={p:sha(p)for p in pins};assert pins==receipt['inputsAfter'];receipt.update(status='PASS',checksByMode=checks,checks=sum(checks.values()),nativeCompilerFiles=17,productionUnchanged=all(sha(MOD/r['path'])==r['preimageSha256']for r in stage['files']));assert receipt['productionUnchanged'];save();print('PASS',receipt['checks'],'checks',len(receipt['controls']),'controls')
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
