"""Staged exact source temporaries: native compiler and meaningful controlled source callers."""
import argparse,hashlib,json,os,runpy,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];STAGE=ROOT/'_scratch/d2-leisure-01/source-temporary-staging01';FIX=ROOT/'tools/d2_source_temporary'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin');BASE=ROOT/'mod/42.20/media/lua';VAULT=ROOT/'mod/42.20/media/SAOSources/LifestyleHobbies/media/lua'
MODES={'vanilla':'client/Instruments/VanillaInstrumentsContextMenu.lua','new':'client/Instruments/NewInstrumentsContextMenu.lua','dj':'client/DJBoothContextMenu.lua','danceTime':'shared/TimedActions/PlayerIsDancingToMusic.lua','danceHands':'shared/TimedActions/PlayerIsDancingToMusic.lua','server':'server/LSservercommands.lua'}
CATALOGUES=['PlayBanjoTracks','PlayFluteTracks','PlayHarmonicaTracks','PlayDJBoothTracks','PlayerVoiceTracks','PlayerDanceMoves']
NAMES={MODES['vanilla']:{'Type','Length','contextMenu','randomNumber','randomTrack'},MODES['new']:{'Length','contextMenu','randomNumber','randomTrack'},MODES['dj']:{'contextMenu1','contextMenu2','contextMenu3','contextMenu4','description','descriptionM','descriptionF'},MODES['server']:{'objSpriteName','Jukebox','spriteName'},MODES['danceTime']:{'AnimTime','handItemP'}}
CONTROLS={
 'vanilla':('vanilla',None,None,'actor_A_original_callback_payload'),
 'new':('new',None,None,'actor_A_original_callback_payload'),
 'dj':('dj',None,None,'DJ_per_call_refusal_label_not_global'),
 'danceTime':('danceTime',b'elseif self.AnimTime ~= 0 then',b'elseif AnimTime ~= 0 then','dance_per_actor_delay'),
 'danceHands':('danceHands',b'not self.character:isItemInBothHands(self.handItemP) then',b'not self.character:isItemInBothHands(handItemP) then','dance_owned_primary_argument'),
 'serverLookup':('server',b'local objSpriteName = objSprite.getName',b'objSpriteName = objSprite.getName','lookup_name_not_global'),
 'serverJuke':('server',b'\tlocal Jukebox, spriteName\r\n',b'','missing_second_source_cannot_borrow_first_jukebox')}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);args=ap.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 adapt=runpy.run_path(str(STAGE/'adaptation.py'))['adapt'];paths=list(NAMES);native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'];compiler=ROOT/'tools/luacheck/LuaGlobals.java'
 inputs=[Path(__file__),STAGE/'adaptation.py',STAGE/'before-pins.json',compiler,GAME/'projectzomboid.jar',GAME/'stdlib.lua',*native,*FIX.iterdir(),*[BASE/p for p in paths],*[STAGE/'before'/p for p in paths],*[STAGE/'proposed'/p for p in paths],*[VAULT/'client/TimedActions'/(p+'.lua') for p in CATALOGUES]]
 pins={str(p):sha(p) for p in inputs if p.is_file()};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'boundary':'Actual installed Kahlua bytecode GET/SET and execution of full original-derived source modules/catalogues; original native Event OnClientCommand Add/trigger reaches server dispatch. Actor inventory/learned lists/menus, original onAction downstream native-action constructor sink, scene geometry/removal, sound/rendering and action clock are controlled hosts. Reentrant menu callback is an explicit controlled interleaving, not game scheduling prevalence. Dance uses original start/update/perform with controlled bodies, no native loop/gameplay/XP closure. Intentional global publishers and JukeboxLightOn preserved and remain separately unqualified.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save()
 try:
  for path in paths:assert adapt((BASE/path).read_bytes(),path)[0]==(STAGE/'proposed'/path).read_bytes()
  with tempfile.TemporaryDirectory(prefix='sao-temporary-') as temp:
   work=Path(temp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=str(work)+os.pathsep+str(GAME/'projectzomboid.jar')
   compile=subprocess.run([str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar'),'-d',str(work),str(FIX/'NamespaceProbe.java'),str(compiler)],capture_output=True);(out/'compile.log').write_bytes(compile.stdout+compile.stderr);assert compile.returncode==0
   compiled={}
   for variant,folder in [('before',STAGE/'before'),('proposed',STAGE/'proposed')]:
    proc=subprocess.run([str(JDK/'java.exe'),'-cp',cp,'LuaGlobals',*[str(folder/p) for p in paths]],capture_output=True,cwd=work);log=out/(variant+'-globals.log');log.write_bytes(proc.stdout+proc.stderr);assert proc.returncode==0;compiled[variant]=log.read_text().splitlines()
   for path,names in NAMES.items():
    before={tuple(x.split(' ',2)[:2]) for x in compiled['before'] if x.endswith(str(STAGE/'before'/path))};after={tuple(x.split(' ',2)[:2]) for x in compiled['proposed'] if x.endswith(str(STAGE/'proposed'/path))}
    assert all(name not in names for op,name in after),('target globals retained',path,after)
    assert {x for x in before if x[1] not in names}==after,('unrelated native global contract changed',path)
    if path==MODES['server']:assert ('SET','JukeboxLightOn') in after
   cats=['catalogue:TimedActions/'+p+'='+str(VAULT/'client/TimedActions'/(p+'.lua')) for p in CATALOGUES]
   def run(mode,path,variant,expected=None):
    command=[str(JDK/'java.exe'),'-cp',cp,'NamespaceProbe',mode,str(FIX/'prelude.lua'),*map(str,native),*cats,str(path),str(FIX/'cases.lua')]
    done=subprocess.run(command,capture_output=True,cwd=work,timeout=45);log=out/(variant+'.log');log.write_bytes(done.stdout+done.stderr);text=log.read_text(errors='replace');receipt['runs'].append({'mode':mode,'variant':variant,'exit':done.returncode,'expectedFailure':expected,'logSha256':sha(log)});save();assert (done.returncode==0 and 'PASS namespace mode='+mode in text) if expected is None else (done.returncode!=0 and 'D2_TEMP:'+expected in text),text
   for mode,path in MODES.items():run(mode,STAGE/'proposed'/path,mode+'-production')
   for name,(mode,good,bad,marker) in CONTROLS.items():
    path=MODES[mode];raw=(STAGE/'proposed'/path).read_bytes()
    if good is None:raw=(STAGE/'before'/path).read_bytes()
    else:assert raw.count(good)==1;raw=raw.replace(good,bad,1)
    target=out/(name+'-restored.lua');target.write_bytes(raw);run(mode,target,name+'-restored',marker)
  receipt['inputsAfter']={p:sha(Path(p)) for p in pins};assert receipt['inputsAfter']==pins
  receipt.update(status='PASS',nativeCompilerFiles=5,causalSourceBranches=6,restoredControls=7,canonicalRuntimeUnchanged=True,unrelatedNativeGlobalsPreserved=True);save();print('PASS five staged files/native GET-SET/six original source branches/seven restored controls')
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
