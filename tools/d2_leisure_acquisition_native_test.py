"""Installed material definition/recipe -> native source -> transfer -> original hobby.

Native shells, exact native objects, original source snapshot encoding, transfer
actions and game recipes execute. Snapshot selection is limited to isolated test
objects; route arrival, native callback scheduling, UI/network and audio hardware
are controlled. No live save or rendered gameplay is claimed.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];HERE=ROOT/'tools'
GAME=Path(os.environ.get('PZ_GAME_DIR',os.environ.get('PZ_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
LUA=ROOT/'mod/42.20/media/lua'
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--required',action='store_true');args=ap.parse_args()
 jar=args.jar.resolve()
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=HERE/'instrument_checks/InstrumentProbe.java'
 fixtures=[HERE/'d2_leisure_games/tabletop_fixture.java',HERE/'d2_leisure_acquisition_native_fixture.java']
 helpers=[HERE/'luacheck/MovementCrossingProbe.java',HERE/'luacheck/ResourceApproachProbe.java',HERE/'cognition_checks/CognitionUseProbe.java']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
   GAME/'media/lua/shared/TimedActions/ISTransferAction.lua',GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
   GAME/'media/lua/client/TimedActions/ISGrabItemAction.lua',GAME/'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua']
 owners=[LUA/'client/SAO_Needs.lua',LUA/'shared/SAO_WorldSources.lua',LUA/'shared/SAO_ProceduralPlanning.lua',
   LUA/'client/SAO_SourceUse.lua',LUA/'client/SAO_LeisureGames.lua',LUA/'client/SAO_LeisureAcquisition.lua']
 cognitive=[LUA/'shared/SAO_CognitiveModels.lua',LUA/'shared/SAO_Cognition.lua'];controller=LUA/'client/SAO_Controller.lua'
 originalItems=[GAME/'media/scripts/generated/items/normal.txt',GAME/'media/scripts/generated/recipes/recipes_cardsAndDice.txt',GAME/'media/scripts/generated/timedactions.txt']
 owned=[Path(__file__),HERE/'native_proof_preflight.py',probe,*fixtures,*helpers,*owners,*cognitive,controller,HERE/'d2_leisure_games/tabletop_prelude.lua',HERE/'d2_leisure_acquisition_native_cases.lua',jar]
 installed=[*native,*originalItems,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe']
 helper=HERE/'native_proof_preflight.py'
 if not helper.is_file():print('FAILED D2 native acquisition: owned proof inputs absent: '+str(helper));return 1
 from native_proof_preflight import presence
 preflight=presence(owned,installed,args.required,'D2 native acquisition')
 if preflight is not None:return preflight
 inputs=owned+installed
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,wd):
  r=subprocess.run(list(map(str,cmd)),cwd=wd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':sha(log)});save();return r.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-native-material-')as tmp:
   work=Path(tmp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   text=probe.read_text().replace('public final class InstrumentProbe','public final class D2AcquisitionProbe')
   text=text.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','zombie.core.Core.class,zombie.GameTime.class,zombie.iso.objects.IsoWorldInventoryObject.class,zombie.iso.sprite.IsoSprite.class,IsoCell.class,zombie.iso.IsoGridSquare.class')
   text=text.replace('env.rawset("__body",body);','TabletopFixture.install(env,exposer,body,other,Path.of(args[0]));AcquisitionFixture.install(env,body);env.rawset("__body",body);')
   generated=out/'D2AcquisitionProbe.java';generated.write_text(text,encoding='utf-8')
   cp=os.pathsep.join(map(str,[jar,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']))
   status,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,*fixtures,generated],work);assert status==0,log
   prelude=out/'prelude.lua';prelude.write_text((HERE/'d2_leisure_games/tabletop_prelude.lua').read_text()+'''\n
Events.OnTick={Add=function()end};__stores={}
SAO.Log={line=function()end}
SAO.Hash={of=function()return 1 end,unit=function()return .5 end};SAO.Disposition={traits=function()return {initiative=.5,discipline=.5}end}
Events.OnInitGlobalModData={Add=function()end};ModData={get=function(k)return __stores[k]end,getOrCreate=function(k)__stores[k]=__stores[k]or{};return __stores[k]end}
__proofOwned=SAO.Needs.ownsRecoveryBody;__proofQueue=SAO.Needs.queueVerified;__proofAvailable=SAO.Needs.workAvailable
ISTimedActionQueue.getTimedActionQueue=function()return {queue={},indexOf=function()return -1 end,onCompleted=function(_,a)if __queue==a then __queue=nil end end,removeFromQueue=function(_,a)if __queue==a then __queue=nil end end,resetQueue=function()__queue=nil end}end
getPlayerData=function()return nil end;getPlayerLoot=function()return nil end
getTimestampMs=function()return __hours*3600000 end;getCore=function()return Core.getInstance()end;getGameTime=function()return GameTime.getInstance()end
removeItemTransaction=function()end;sendRemoveItemFromContainer=function()end;sendAddItemToContainer=function()end
triggerEvent=function()end;ISInventoryPage={};ISInventoryPaneContextMenu={};ItemPicker={updateOverlaySprite=function()end}
''',encoding='utf-8')
   restore=out/'restore.lua';restore.write_text('SAO.Needs.ownsRecoveryBody=__proofOwned;SAO.Needs.queueVerified=__proofQueue;SAO.Needs.workAvailable=__proofAvailable\n',encoding='utf-8')
   ctl=controller.read_text(encoding='utf-8-sig');ctl=ctl[ctl.index('function Ctl.leisureReasons('):ctl.index('local LEISURE_WORK_OWNERS')]
   dispatcher=out/'controller.lua';dispatcher.write_text('SAO.Controller=SAO.Controller or {agents={}}\nlocal Ctl=SAO.Controller\nlocal setState=function(a,id,state)a.state=state;return true end\n'+ctl,encoding='utf-8')
   receipt['controls']=[]
   controls=[('omit-container-move',native[2],'destContainer:AddItem(item)','do end','original_native_transfer_custody_CardDeckfalse'),
     ('omit-ground-move',native[4],'self.destContainer:AddItem(inventoryItem);','do end','original_native_transfer_custody_CardDecktrue'),
     ('forget-original-purpose',owners[2],'local purpose = acquired or leisurePurpose','local purpose = leisurePurpose','same_purpose_native_hobby_admission_CardDeckfalse'),
     ('ignore-owned-generation',owners[-1],'SAO.Needs.ownsRecoveryBody(id,body)','true','changed_body_generation_refused_CardDeckfalse')]
   for name,target,before,after,marker in [('baseline',None,None,None,None),*controls]:
    paths=[prelude,*native,owners[0],restore,*owners[1:],*cognitive,dispatcher,HERE/'d2_leisure_acquisition_native_cases.lua']
    if target:
     source=target.read_text(encoding='utf-8-sig');assert before in source,(name,before)
     changed=out/(name+'.lua');changed.write_text(source.replace(before,after),encoding='utf-8');paths=[changed if p==target else p for p in paths]
    status,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2AcquisitionProbe',GAME,*paths],work)
    if marker:assert status!=0 and 'D2_NATIVE_ACQUISITION:'+marker in log,(name,log[-8500:]);receipt['controls'].append({'name':name,'failedCheck':marker})
    else:assert status==0 and 'PASS D2 native acquisition 'in log,log[-8500:];receipt['checks']=int(log.split('PASS D2 native acquisition ')[1].splitlines()[0])
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS D2 native acquisition',receipt['checks']);return 0
if __name__=='__main__':raise SystemExit(main())
