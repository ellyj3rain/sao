"""Native authored item -> ordinary source acquisition -> exact text exposure ->
distinct response -> current private retention -> inquiry and claim catalogue.

Real installed Literature/Item.Load/initialiseItem/addPage, source snapshot,
inventory transfer, timed-action callbacks and native item/Kahlua save/load.
Controlled actors, isolated source container, queue/time, route arrival and
presentation/audio/network receivers. Literal/arithmetic cognition is a bounded
production responder; explicit test substitutions are synthetic, not learned
general-policy or trained ML proof. No live game, save or rendered acceptance.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess
import d2_leisure_acquisition_native_test as old
ROOT=Path(__file__).resolve().parents[1];LUA=ROOT/'mod/42.20/media/lua';GAME=old.GAME;JDK=old.JDK
FILES={
 'sources':LUA/'shared/SAO_StudySources.lua','study':LUA/'client/SAO_Study.lua',
 'concept':LUA/'shared/SAO_ConceptKnowledge.lua','plan':LUA/'shared/SAO_ProceduralPlanning.lua',
 'models':LUA/'shared/SAO_CognitiveModels.lua','cognition':LUA/'shared/SAO_Cognition.lua',
 'knowledge':LUA/'shared/SAO_Knowledge.lua','education':LUA/'shared/SAO_Education.lua',
 'communication':LUA/'shared/SAO_Communication.lua',
 'perception':LUA/'shared/SAO_Perception.lua',
 'controller':LUA/'client/SAO_Controller.lua','loot':LUA/'server/Items/SAO_LiteratureLoot.lua'}
CONTROLS=[
 ('remove-passage','sources','A room may contain a quiet room.','A room may contain a vacant room.','source_bound_literal_response'),
 ('reverse-assessed-relation','sources','{from="quiet-room",relation="supports",into="privacy"}','{from="quiet-room",relation="supports",into="public-exposure"}','source_bound_literal_response'),
 ('skip-actual-exposure','study','row.status~="completed" or row.nativeOwner~="SAONoteReadAction/ISBaseTimedAction"','false or row.nativeOwner~="SAONoteReadAction/ISBaseTimedAction"','incomplete_native_exposure_refused'),
 ('allow-foreign-source','concept','row.actorId~=id or not finite(row.sequence)','false or not finite(row.sequence)','foreign_assessment_receipt_rejected'),
 ('ignore-retention-age','concept','return math.exp(-math.log(2)*age/halfLife)','return 1','old_memory_is_unavailable'),
 ('ignore-current-health','concept','multiplier=math.max(.1,1-.5*current.fatigue-.3*current.pain-.3*current.drunk)','multiplier=1','current_health_changes_retrieval'),
 ('ignore-person-attributes','concept','local discipline=condition and condition.discipline or .5','local discipline=.5','attributes_change_formation_retention'),
 ('ignore-purpose-interest','concept','local interest=K.assessmentInterest(id,d.topic)','local interest=.2','purpose_interest_changes_retention'),
 ('ignore-actual-use','concept','row.lastUsedAt=at;row.usageCount=math.min(64,row.usageCount+1);used=true','used=true','actual_plan_use_refreshes_once'),
 ('ignore-aging-maintenance','study','or memory.ageChanged and "retrieval"','or false and "retrieval"','aging_makes_retrieval_due'),
 ('skip-rubric','sources','status=correct and "passed" or "failed"','status="passed"','incorrect_explicit_response_fails'),
 ('skip-ordinary-dispatch','controller','elseif receiver.kind=="reading-assessment" then','elseif receiver.kind=="disabled-reading-assessment" then','ordinary_assessment_dispatch'),
 ('permit-stale-catalogue','knowledge','if not matching then return nil,"literature-claim-no-longer-current" end','if false then return nil,"literature-claim-no-longer-current" end','forgotten_cached_claim_refused'),
 ('keep-received-capability','communication','conceptReceptions[message]=nil','-- capability improperly retained','received_teaching_capability_retired'),
 ('omit-native-transfer',None,'destContainer:AddItem(item)','do end','ordinary_native_acquisition_custody'),
 ('remove-military-room-join','concept','                out[#out+1]=e\n','                if not (e.from=="room" and e.into=="alternate-route") then out[#out+1]=e end\n','native_military_ordinary_inquiry'),
 ('make-received-literature-permanent','concept','if memory and memory.retained then','if memory then','received_literature_expires_without_rehearsal'),
 ('depend-on-teacher-current-memory','concept','and source.hasRelation(l.sourceId,l.revision,l.textHash,row)','and source.hasRelation(l.sourceId,l.revision,l.textHash,row) and #K.assessedRelations(l.assessmentActorId)>0','recipient_memory_independent_of_teacher_forgetting'),
 ('drop-received-source-provenance','concept','literature=origin,policy=K.assessmentPolicy(id,origin.sourceId)','literature=nil,policy=K.assessmentPolicy(id,origin.sourceId)','received_source_and_actor_provenance'),
 ('forget-received-ledger-after-reading-store','concept',
  '    for _,ledger in ipairs({l and l.useReceipts or {},conceptState.receivedUseReceipts or {}}) do\n        for _,old in ipairs(ledger) do if old==receipt then return true end end\n    end',
  '    for _,old in ipairs(l and l.useReceipts or conceptState.receivedUseReceipts or {}) do if old==receipt then return true end end',
  'received_use_replay_after_actual_reading_store_is_inert'),
 ('forget-disposable-learning-cache','study','    learningRuntime[id] = nil\n    local active = runtime[id]',
  '    learningRuntime[id] = learningRuntime[id]\n    local active = runtime[id]', 'terminal_learning_cache_dropped_by_death'),
]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--variants',nargs='+');ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--cases',type=Path,default=ROOT/'tools/literature_learning_cases.lua');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
  GAME/'media/lua/shared/TimedActions/ISTransferAction.lua',GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',GAME/'media/lua/shared/TimedActions/ISReadABook.lua']
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 fixture=ROOT/'tools/literature_learning_fixture.java';acquisition=ROOT/'tools/d2_leisure_acquisition_native_fixture.java'
 cases=args.cases.resolve();jar=args.jar.resolve();needs=LUA/'client/SAO_Needs.lua'
 world=LUA/'shared/SAO_WorldSources.lua';use=LUA/'client/SAO_SourceUse.lua';itemScript=ROOT/'mod/42.20/media/scripts/items_SAO_literature.txt'
 identity=LUA/'shared/SAO_Identity.lua'
 inputs=[*FILES.values(),*native,*helpers,fixture,acquisition,probe,cases,Path(__file__),Path(old.__file__),itemScript,needs,world,use,jar,
  GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',GAME/'media/lua/server/Items/ProceduralDistributions.lua',
  ROOT/'tools/d2_leisure_games/tabletop_prelude.lua',JDK/'java.exe',JDK/'javac.exe']
 deathCase=cases==ROOT/'tools/literature_death_cache_cases.lua'
 if deathCase:inputs.extend([identity,ROOT/'tools/lua_read.py'])
 digest=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 receipt={'schema':'sao-literature-learning-proof/1','status':'INCOMPLETE','boundary':__doc__,'caseFile':str(cases),'sourcePins':{str(p):digest(p)for p in inputs},'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd):
  r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  row={'name':name,'command':list(map(str,cmd)),'cwd':str(out),'exitCode':r.returncode,'log':str(log),'logSha256':digest(log)}
  receipt['runs'].append(row);save();return r.returncode,log.read_text(encoding='utf-8',errors='replace'),row
 replayControl='forget-received-ledger-after-reading-store'
 replayCase=cases==ROOT/'tools/literature_maintenance_replay_cases.lua'
 defaultControls=['forget-disposable-learning-cache'] if deathCase else [r[0]for r in CONTROLS if r[0]!='forget-disposable-learning-cache' and (r[0]==replayControl)==replayCase]
 selected=args.variants or ['production',*defaultControls]
 assert set(selected)<={'production',*[r[0]for r in CONTROLS]}
 try:
  (out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
  text=probe.read_text().replace('public final class InstrumentProbe','public final class LiteratureLearningProbe')
  # The native OnCreate call must fail loudly if its callback throws.
  text=text.replace('LuaManager.caller=new LuaCaller(LuaManager.converterManager);','''LuaManager.caller=new LuaCaller(LuaManager.converterManager){
   @Override public Object[] pcall(KahluaThread vm,Object function,Object argument){var result=super.pcall(vm,function,argument);
    if(!Boolean.TRUE.equals(result[0]))throw new AssertionError("Native callback failed: "+java.util.Arrays.deepToString(result));return result;}};''')
  start=text.index('        var dc=Class.forName(');end=text.index('        env.rawset("__body",body);',start)
  text=text[:start]+'''        LiteratureFixture.install(env,body,other,thread,Path.of(System.getProperty("sao.source"),"mod/42.20/media/scripts/items_SAO_literature.txt"));
        AcquisitionFixture.install(env,body);
'''+text[end:]
  text=text.replace('InventoryItem.class,zombie.inventory.ItemContainer.class,','InventoryItem.class,zombie.inventory.types.Literature.class,zombie.inventory.ItemContainer.class,zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.ItemBodyLocation.class,zombie.characters.CharacterActionAnims.class,zombie.characters.WornItems.WornItems.class,zombie.vehicles.BaseVehicle.class,')
  text=text.replace('ArrayList.class,java.util.List.class,','zombie.core.Core.class,zombie.GameTime.class,java.util.HashMap.class,ArrayList.class,java.util.List.class,')
  generated=out/'LiteratureLearningProbe.java';generated.write_text(text,encoding='utf-8')
  cp=os.pathsep.join(map(str,[jar,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']))
  code,log,_=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',out,*helpers,fixture,acquisition,generated]);assert code==0,log
  preludeSource=ROOT/'tools/d2_leisure_games/tabletop_prelude.lua'
  preludePrefix=preludeSource.read_text(encoding='utf-8-sig')
  prelude=out/'prelude.lua';prelude.write_text(preludePrefix+'''\n
Events.OnTick={Add=function()end};Events.OnInitGlobalModData={Add=function()end};__stores={}
ModData={get=function(k)return __stores[k]end,getOrCreate=function(k)__stores[k]=__stores[k]or{};return __stores[k]end}
SAO.Log={line=function()end};SAO.Hash={of=function()return 1 end,unit=function()return .5 end}
SAO.Disposition={traits=function(id)return {initiative=.7,discipline=__records[id].discipline or .85,compassion=.5,talkativeness=.5,curiosity=.5}end}
SAO.History.literacyOf=function()return "reads" end;SAO.History.ageOf=function(id)return __records[id].testAge end
SAO.History.TICKS_PER_HOUR=9000;SAO.Census={JOB_PERK={},bookSkillFor=function(x)return x end}
SAO.Conditions={readingTime=function()return 1 end,words=function()return {}end};SAO.Habits={words=function()return {}end}
__owned=SAO.Needs.ownsRecoveryBody;__available=SAO.Needs.workAvailable;__queueVerified=SAO.Needs.queueVerified
ISTimedActionQueue.getTimedActionQueue=function()return {queue={},indexOf=function()return -1 end,onCompleted=function(_,a)if __queue==a then __queue=nil end end,removeFromQueue=function(_,a)if __queue==a then __queue=nil end end,resetQueue=function()__queue=nil end}end
getGameTime=function()return {getYear=function()return __year or 1993 end,getMinutesPerDay=function()return 60 end}end
getSandboxOptions=function()return {getOptionByName=function()return {getValue=function()return 2 end}end}end
getCore=function()return Core.getInstance()end
SkillBook={};getPlayerData=function()return nil end;getPlayerLoot=function()return nil end;getTimestampMs=function()return __hours*3600000 end
removeItemTransaction=function()end;sendRemoveItemFromContainer=function()end;sendAddItemToContainer=function()end
triggerEvent=function()end;ISInventoryPage={};ISInventoryPaneContextMenu={};ItemPicker={updateOverlaySprite=function()end};ISInventoryTransferAction.soundDelay=0
'''.replace('ISInventoryTransferAction.soundDelay=0',''),encoding='utf-8')
  receipt['executedPrelude']={'source':str(preludeSource),'sourceSha256':digest(preludeSource),
   'prefixUtf8Sha256':hashlib.sha256(preludePrefix.encode()).hexdigest(),'executed':str(prelude),'executedSha256':digest(prelude),
   'prefixMatches':prelude.read_text(encoding='utf-8').startswith(preludePrefix)}
  assert receipt['executedPrelude']['prefixMatches'];save()
  restore=out/'restore.lua';restore.write_text('''SAO.Needs.ownsRecoveryBody=__owned;SAO.Needs.workAvailable=__available
ISTimedActionQueue.getTimedActionQueue=function(body)
 local q=ISTimedActionQueue.queues[body]
 if not q then
  q={queue={}};ISTimedActionQueue.queues[body]=q
  function q:indexOf(a)for i,row in ipairs(self.queue)do if row==a then return i end end return -1 end
  function q:removeFromQueue(a)for i=#self.queue,1,-1 do if self.queue[i]==a then table.remove(self.queue,i)end end;if self.current==a then self.current=nil end;if __queue==a then __queue=nil end end
  function q:onCompleted(a)self:removeFromQueue(a)end
  function q:resetQueue()self.queue={};self.current=nil;__queue=nil end
 end
 return q
end
SAO.Needs.queueVerified=function(a)
 local q=ISTimedActionQueue.getTimedActionQueue(a.character);q.queue[#q.queue+1]=a;q.current=a
 return __queueVerified(a)
end
''',encoding='utf-8')
  with restore.open('a',encoding='utf-8')as f:
   f.write('__sourcesPath='+json.dumps(str(out/'sources.lua'))+';__studyPath='+json.dumps(str(out/'study.lua'))+';__conceptPath='+json.dumps(str(out/'concept.lua'))+'\n')
  source={k:p.read_text(encoding='utf-8-sig')for k,p in FILES.items()}
  distribution=(GAME/'media/lua/server/Items/ProceduralDistributions.lua').read_text(encoding='utf-8-sig')
  pools='ProceduralDistributions={list={}}\n'
  for name in ['BookstoreBooks','LibraryBooks']:
   match=re.search(r'\b'+name+r'\s*=\s*\{',distribution);begin=match.end()-1;depth=1;end=begin+1
   while depth:
    depth+= (distribution[end]=='{')-(distribution[end]=='}');end+=1
   pools+='ProceduralDistributions.list.'+name+'='+distribution[begin:end]+'\n'
  (out/'pools.lua').write_text(pools,encoding='utf-8')
  for name in selected:
   texts=dict(source);target=None;transfer=native[2]
   if name!='production':
    _,owner,before,after,target=next(r for r in CONTROLS if r[0]==name)
    if owner:
     assert texts[owner].count(before)==1,(name,texts[owner].count(before));texts[owner]=texts[owner].replace(before,after,1)
     if name=='remove-passage':
      # A revised passage receives its honest revised hash. The downstream
      # literal/rubric failure must still detect loss of the required meaning.
      for m in re.finditer(r'\["pages"\]=\{(.*?)\n\}',texts['sources'],re.S):
       pages=[json.loads(v)for v in re.findall(r'"(?:\\.|[^"\\])*"',m.group(1))]
       part=texts['sources'][:m.start()];h=list(re.finditer(r'\["textHash"\]="([a-f0-9]{64})"',part))[-1]
       newHash=hashlib.sha256('\n'.join(pages).encode()).hexdigest()
       texts['sources']=texts['sources'].replace(h.group(1),newHash,1)
    else:
     transferText=transfer.read_text();assert before in transferText,name+': transfer mutation anchor absent'
     (out/'transfer-control.lua').write_text(transferText.replace(before,after),encoding='utf-8');transfer=out/'transfer-control.lua'
   for key,text in texts.items():
    if key=='study' and deathCase:
     assert text.count('\nreturn S\n')==1
     text=text.replace('\nreturn S\n','\nfunction S.__deathCacheProbe(id) return learningRuntime[id] end\nreturn S\n')
    if key=='controller':
     text='SAO.Controller=SAO.Controller or {agents={}}\nlocal Ctl=SAO.Controller\nlocal setState=function(a,id,state)a.state=state;return true end\n'+text[text.index('function Ctl.leisureReasons('):text.index('local LEISURE_WORK_OWNERS')]+'\n'+text[text.index('function Ctl.beginConceptInquiry('):text.index('function Ctl.finishConceptInquiryMovement(')]
    (out/(key+'.lua')).write_text(text,encoding='utf-8')
   paths=[prelude,*native[:2],transfer,*native[3:],needs,restore,world,out/'plan.lua',use,out/'sources.lua',out/'study.lua',out/'concept.lua',out/'models.lua',out/'cognition.lua',out/'knowledge.lua',out/'education.lua',out/'communication.lua',out/'perception.lua',out/'controller.lua',out/'pools.lua',out/'loot.lua']
   if deathCase:
    from lua_read import function_body
    body=function_body(identity.read_text(encoding='utf-8'),'Identity.markDead');assert body is not None
    funnel=out/'death-funnel.lua';funnel.write_text('local Identity=SAO.Identity\nlocal log=function()end\nfunction Identity.markDead('+body+'\nend\n',encoding='utf-8')
    paths.append(funnel)
    receipt['deathTestExposure']={'source':'private copied Study cache accessor; no production probe API',
     'funnel':'exact production Identity.markDead body; identity lookup and logging receivers controlled','funnelSha256':digest(funnel)}
   paths.append(cases)
   code,log,row=run(name,[JDK/'java.exe','-Duser.home='+str(out),'-Dsao.source='+str(ROOT),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(out)+os.pathsep+cp,'LiteratureLearningProbe',GAME,*paths])
   checks=dict(re.findall(r'LITERATURE ([a-z0-9_]+)=(true|false)',log));row['checks']=checks;row['expectedFalse']=target;save()
   if target:assert code!=0 and checks.get(target)=='false' and 'LITERATURE_FAILED:'+target in log,(name,log[-6000:])
   else:assert code==0 and 'PASS literature learning 'in log and all(v=='true'for v in checks.values()),log[-9000:]
   print(name+': PASS '+str(len(checks)),flush=True)
  receipt['inputsAfter']={str(p):digest(p)for p in inputs};assert receipt['sourcePins']==receipt['inputsAfter'],'input drift'
  receipt['status']='PASS';save();return 0
 except Exception as e:receipt['error']=str(e);save();print('FAIL literature learning',e);return 1
if __name__=='__main__':raise SystemExit(main())
