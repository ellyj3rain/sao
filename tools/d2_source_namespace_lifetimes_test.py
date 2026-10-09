"""Exact imported call locals and lazy provider lifetimes, native compilation/event."""
import argparse,hashlib,json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];LEAF=ROOT/'_scratch/d2-leisure-01/namespace-continuation-20261006';FIX=ROOT/'tools/d2_source_namespace_lifetimes';MOD=ROOT/'mod/42.20/media/lua'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
MODES={'perfume':'client/Hygiene/PerfumeContextMenu.lua','sheet':'client/Instruments/MusicSheetBookContextMenu.lua','ghost':'client/ui/shared/slots/NMSlotGhostOverlay.lua','plush':'client/ISAmbt/LSPlushies.lua','piano':'client/Instruments/InstrumentPianoContextMenu.lua','hour':'client/LSEffects/LSPerHour.lua','interaction':'client/MPSocial/InteractionManager.lua','helper':'client/Helper/ContextHelper.lua','shower':'client/Hygiene/ShowerContextMenu.lua','bath':'client/Hygiene/BathContextMenu.lua','cabinet':'client/Hygiene/CabinetContextMenu.lua','mirror':'client/Hygiene/MirrorContextMenu.lua','yoga':'shared/TimedActions/LSYogaAction.lua','jukebox':'client/JukeboxContextMenuAux.lua','sculpt':'client/Painting/Sculpting/SculptingWorkContextMenu.lua','explorer':'client/ISAmbt/LSExplorer.lua'}
PROVIDERS={'aquarium-placement':['client/KA_Placement.lua'],'aquarium-overlay':['client/KA_Radial.lua'],'computer-event':['client/ComputerMod_UI_State.lua'],'globalmusic':['TCMusicDefenitions.lua','shared/TCMusicDefenitions.lua','shared/contracts/NMMediaContract.lua','shared/music/NMAlbumPackBuilder.lua'],'recmedia':['shared/RecordedMedia/LSVHS.lua']}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);ap.add_argument('--current',action='store_true');a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);staged=MOD if a.current else LEAF/'proposed'
 stage=json.loads((LEAF/'stage-receipt.json').read_text(encoding='utf-8'));stage['files'].extend(json.loads((LEAF/'explorer-stage-receipt.json').read_text())['files']);base=GAME/'media/lua/shared/ISBaseObject.lua';jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))];compiler=ROOT/'tools/luacheck/LuaGlobals.java';nativeMedia=GAME/'media/lua/shared/RecordedMedia/recorded_media.lua';nativeMap=GAME/'media/lua/client/ISUI/Maps/ISWorldMap.lua'
 nativeAction=GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'
 inputs=[Path(__file__),*sorted(p for p in FIX.iterdir()if p.is_file()),LEAF/'stage-receipt.json',LEAF/'explorer-stage-receipt.json',compiler,base,nativeAction,nativeMedia,nativeMap,GAME/'stdlib.lua',*jars,*[staged/r['path']for r in stage['files']],*[LEAF/'before'/r['path']for r in stage['files']],*[MOD/p for ps in PROVIDERS.values()for p in ps]]
 pins={str(p):sha(p)for p in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'controls':[],'boundary':'Native Kahlua complete source modules and GETGLOBAL/SETGLOBAL; actual Event.OnPlayerUpdate and installed ISWorldMap Lua. UI/class base availability/allocation, scene/body/queue/dependencies and source-name/line-native-local closure access controlled. No rendering, game-frame, save/MP or autonomous-use claim. Branch-local bytecode qualified for all transformed symbols; representative actual branch behavior in all16 changed modules.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd):
  r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=90);p=out/(name+'.log');p.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':sha(p)});save();return r.returncode,p.read_text(encoding='utf-8',errors='replace')
 save()
 try:
  (out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
  classes=out/'classes';classes.mkdir();cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-cp',cp,'-d',classes,FIX/'NamespaceLifetimeProbe.java',compiler]);assert code==0,log
  cp=str(classes)+os.pathsep+cp
  def globalsFor(name,file):
   code,log=run(name,[JDK/'java.exe','-cp',cp,'LuaGlobals',file]);assert code==0,log;return log
  for row in stage['files']:
   path=row['path'];proposed=staged/path;assert sha(proposed)==row['postimageSha256'];log=globalsFor('globals-'+Path(path).stem,proposed)
   names={x['symbol']for x in row['changes']}
   kind='SET' if path.endswith('LSExplorer.lua') else '(GET|SET)'
   assert not any(re.match(kind+r' ('+'|'.join(map(re.escape,names))+r') ',line)for line in log.splitlines()),(path,log)
   old=globalsFor('restored-'+Path(path).stem,LEAF/'before'/path)
   assert any(re.match(r'SET ('+'|'.join(map(re.escape,names))+r') ',line)for line in old.splitlines()),path
   receipt['controls'].append({'name':'original-native-global-'+path,'symbols':sorted(names),'type':'motivating-original-SET-restored'})
  def behavior(mode,paths,label):
   args=[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',cp,'NamespaceLifetimeProbe',mode,FIX/'prelude.lua',base]
   if mode=='recmedia':args.append(nativeMedia)
   if mode=='yoga':args.append(nativeAction)
   args.append(FIX/'setup.lua')
   if mode=='explorer':args.append(nativeMap)
   args.extend([*['module='+str(p)for p in paths],FIX/'cases.lua']);return run(label,args)
  checks={}
  for mode,path in MODES.items():
   code,log=behavior(mode,[staged/path],mode+'-source');assert code==0,log
   checks[mode]=int(float(re.search(r'checks=([\d.]+)',log)[1]))
   code,log=behavior(mode,[LEAF/'before'/path],mode+'-original-restored');assert code!=0 and 'D2_NAMESPACE:'in log,(mode,log)
   receipt['controls'].append({'name':mode+'-original-restored','type':'actual-source-behavior-defect'})
  for mode,paths in PROVIDERS.items():
   code,log=behavior(mode,[MOD/p for p in paths],mode+'-source');assert code==0,log
   checks[mode]=int(float(re.search(r'checks=([\d.]+)',log)[1]))
  for mode,old,new,marker in [
   ('aquarium-placement',b'if KAPlacement then return KAPlacement end',b'if false then return KAPlacement end','placement_exact_memoized_publisher'),
   ('aquarium-overlay',b'if KAWheelOverlay then return KAWheelOverlay end',b'if false then return KAWheelOverlay end','overlay_exact_memoized_publisher'),
   ('computer-event',b'not ComputerModGameMoodEventInstalledV2',b'true','reload_rebinds_handler_without_duplicate_event'),
   ('globalmusic',b'if type(GlobalMusic) ~= "table" then',b'if true then','source_music_registry_identity'),
   ('recmedia',b'RecMedia = RecMedia or {}',b'RecMedia = {}','engine_recording_registry_identity')]:
   paths=[MOD/p for p in PROVIDERS[mode]];raw=paths[0].read_bytes();assert raw.count(old)==1;mutated=out/(mode+'-restored.lua');mutated.write_bytes(raw.replace(old,new,1));paths[0]=mutated
   code,log=behavior(mode,paths,mode+'-guard-restored');assert code!=0 and 'D2_NAMESPACE:'+marker in log,(mode,log)
   receipt['controls'].append({'name':mode+'-guard-restored','expectedFailure':marker,'type':'exact-source-guard-mutation'})
  receipt['inputsAfter']={p:sha(Path(p))for p in pins};assert pins==receipt['inputsAfter'];receipt.update(status='PASS',nativeCompilerFiles=16,localSymbolLifetimes=23,checksByMode=checks,checks=sum(checks.values()),productionUnchanged=True);save();print(receipt['status'],receipt['checks'],'checks',len(receipt['controls']),'controls')
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
