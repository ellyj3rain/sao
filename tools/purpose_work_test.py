#!/usr/bin/env python3
"""Border 215: private prerequisites drive native acquisition and practical work.

Production Lua runs in installed Kahlua. Bridge responses, movement and source
transfers are controlled; installed study and appliance actions remain covered
by Borders 214/202. No renderer, gameplay prevalence or dataset admission is
claimed here. Native item/holder acceptance is exercised by PurposeWorkProbe.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

import source_use_test as source_fixture

ROOT = Path(__file__).resolve().parent.parent
GAME = source_fixture.PZ_DIR
JDK = source_fixture.JDK
LUA = ROOT / 'mod/42.20/media/lua'
FILES = {
    'world': LUA / 'shared/SAO_WorldSources.lua',
    'planner': LUA / 'shared/SAO_ProceduralPlanning.lua',
    'source': LUA / 'client/SAO_SourceUse.lua',
    'study': LUA / 'client/SAO_Study.lua',
    'cooking': LUA / 'client/SAO_Cooking.lua',
    'experience': LUA / 'client/SAO_CapabilityExperience.lua',
    'controller': LUA / 'client/SAO_Controller.lua',
    'provisioning': LUA / 'shared/SAO_Provisioning.lua',
}
SOURCE = source_fixture.snapshot(1, 1, 's1', [{
    'id': 'C:book:0', 'fp': 'books', 'rev': 'r1', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'reading': 2, 'tools': 1},
    'items': [{'id': 11, 'type': 'Base.Book', 'amount': 0, 'cats': 'reading'},
              {'id': 12, 'type': 'Base.BookCooking1', 'amount': 0, 'cats': 'reading'},
              {'id': 13, 'type': 'Base.Hammer', 'amount': 0, 'cats': 'tools'}],
}])
POST = source_fixture.snapshot(1, 1, 's2', [{
    'id': 'C:book:0', 'fp': 'books', 'rev': 'r2', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'reading': 1, 'tools': 1},
    'items': [{'id': 11, 'type': 'Base.Book', 'amount': 0, 'cats': 'reading'},
              {'id': 13, 'type': 'Base.Hammer', 'amount': 0, 'cats': 'tools'}],
}])

SETUP = r'''
require=function() end
CharacterTrait={ILLITERATE='illiterate'}
SkillBook={Cooking={perk={getId=function() return 'Cooking' end}}}
SAO.History.literacyOf=function() return 'reads' end
SAO.Census={JOB_PERK={cook='Cooking'},bookSkillFor=function(p) return p end}
SAO.Controller={}
SAO.Pharmacology={}
SAO.Cognition={capture=function() end,sourceResult=function() end,
    preparationOutcome=function() __cognitive=(__cognitive or 0)+1 return true end}
function getScriptManager() return {getItem=function(_,fullType)
    if fullType=='Base.Book' then return nil end
    local first=fullType=='Base.BookCooking3' and 5 or 1
    return {getSkillTrained=function() return 'Cooking' end,
        getNumberOfPages=function() return 100 end,
        getLevelSkillTrained=function() return first end,
        getNumLevelsTrained=function() return 2 end,
        getMaxLevelTrained=function() return first+1 end}
end} end
SAOStudyAction={}
ISReadABook={derive=function() return {} end}
'''

ACQUISITION = r'''
local checks={}
local function check(name, value) checks[#checks+1]=name..'='..tostring(value==true) end
local p={id=42,cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16}
local function reset()
    __stores={} __records={a={id='a',designation='cook'},b={id='b'}}
    __known={} __places={[42]=p} __bodies={a=__newBody(8,8),b=__newBody(8,8)}
    SAO.Body.active=__bodies
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__before))
    local quantities,revision,access,facts=SAO.WorldSources.beliefSnapshot(p)
    -- Real Perception building memory is keyed by id; the value has no id.
    __known.a={[42]={cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16,
        sources=quantities,sourceRevision=revision,sourceAccess=access,sourceFacts=facts}}
    local body=__bodies.a
    body.getPerkLevel=function() return body.level or 0 end
    body.hasTrait=function() return false end
    body.getAlreadyReadPages=function() return 0 end
    body.isDead=function() return false end
    body.isExistInTheWorld=function() return true end
    SAOJavaBridge.privateCarriedItems=function() return {size=function() return 0 end} end
    __targetAnswer='READY:8:8:0:8:8:0' __bindAnswer='BOUND:8:8:0'
    __observeText=__before __routeAllowed=true __standingAllowed=true
    __sourceItem={exact=true} __sourceContainer={} __permissionContainer={}
    __carriedItem=nil __queueReject=false __busy=false __queued=nil
    SAOJavaBridge.carriedWorldTransferItem=function()
        return 'T|operation=acquire|source=C:book:0|id=12|type=Base.BookCooking1|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=reading'
    end
    SAO.Provisioning=nil
    __records.a.provisioningCreditOrder=0
    return body
end
local body=reset()
local P=SAO.ProceduralPlanning
local purpose=P.planStudy('a','cook',{bookNearby=true,literacy='reads'})
local offer=SAO.WorldSources.actionOptions(p,'reading','a',body,1,'standing','acquire')
check('inspected_revision_offers_second_manual',offer~=nil and #offer.options==2)
check('uninspected_actor_has_no_acquisition',SAO.WorldSources.actionOptions(p,'reading','b',__bodies.b,1,'standing','acquire')==nil)
check('book_and_tool_never_enter_consume',SAO.WorldSources.actionOptions(p,'reading','a',body,1,'standing')==nil
    and SAO.WorldSources.actionOptions(p,'tools','a',body,1,'standing')==nil)
check('tools_have_exact_acquisition_owner',SAO.WorldSources.actionOptions(p,'tools','a',body,1,'standing','acquire')~=nil)
offer.context={sourceId='C:book:0',itemId=12,itemType='Base.BookCooking1',sourceRevision='r1'}
check('retained_source_selects_exact_item',SAO.SourceUse.chooseOption(offer)==offer.options[2])
offer.context.sourceId='another-source'
check('retained_source_cannot_substitute_another_container',SAO.SourceUse.chooseOption(offer)==nil)
offer.context.sourceId='C:book:0';offer.context.itemId=999
check('retained_source_cannot_substitute_another_item',SAO.SourceUse.chooseOption(offer)==nil)
offer.context.itemId=12;offer.context.itemType='Base.Book'
check('retained_source_requires_matching_type',SAO.SourceUse.chooseOption(offer)==nil)
offer.context.itemType='Base.BookCooking1';offer.context.sourceRevision='r0'
check('retained_source_requires_matching_revision',SAO.SourceUse.chooseOption(offer)==nil)
offer.context.sourceRevision='r1';offer.context.acceptItem=function() return false end
check('retained_source_preserves_item_consent',SAO.SourceUse.chooseOption(offer)==nil)
check('unknown_category_refused',SAO.WorldSources.actionOptions(p,'invented','a',body,1,'standing','acquire')==nil)
check('native_skill_range_filters_books',SAO.Study.usefulType(body,'Base.BookCooking1','Cooking')
    and not SAO.Study.usefulType(body,'Base.BookCooking3','Cooking')
    and not SAO.Study.usefulType(body,'Base.BookCooking1','Woodwork'))
body.level=2
check('script_metadata_uses_native_inclusive_book_boundary',not SAO.Study.usefulType(body,'Base.BookCooking1','Cooking'))
body.level=0
local ok,r=SAO.SourceUse.beginAcquisition('a',body,p,'reading',{
    purposeId=purpose.id,purposeStepId='acquire-book',acceptItem=function(t) return t=='Base.BookCooking1' end})
check('goal_binds_exact_selected_item',ok==true and r and r.itemId==12 and r.operation=='acquire'
    and purpose.admission.correlationId==r.id and purpose.cursor==1)
check('native_transfer_admitted_without_progress',r.phase=='approaching-source'
    and SAO.SourceUse.onMovementDone('a',body,'arrived')=='using' and purpose.cursor==1)
__carriedItem=__sourceItem __busy=false __observeText=__after
local terminal=SAO.SourceUse.tick('a',body)
local receipt=r and SAO.WorldSources.actionOutcome(r.id,'a')
check('acquisition_finishes_without_eating',terminal=='completed' and receipt and receipt.measurement=='native-item-transfer'
    and receipt.observedQuantity==1 and __queued.kind=='transfer')
check('native_acquisition_advances_same_purpose',receipt and P.consumeSourceResult(receipt)==true
    and purpose.cursor==2 and purpose.steps[2].verb=='read')
check('receipt_replay_does_not_advance_reading',P.consumeSourceResult(receipt)==true and purpose.cursor==2)
local retained=P.planStudy('a','cook',{purposeId=purpose.id,bookOwned=true,literacy='reads'})
check('carried_study_keeps_original_goal',retained==purpose and P.studyPurpose('a','Cooking')==purpose
    and purpose.steps[purpose.cursor].verb=='read' and #__records.a.proceduralPlanning.order==1)

body=reset() purpose=P.planStudy('a','cook',{bookNearby=true,literacy='reads'})
ok,r=SAO.SourceUse.beginAcquisition('a',body,p,'reading',{
    purposeId=purpose.id,purposeStepId='acquire-book',acceptItem=function(t) return t=='Base.BookCooking1' end})
SAO.WorldSources.failAction(r.id,'a','permission-changed')
receipt=SAO.WorldSources.actionOutcome(r.id,'a')
check('terminal_failure_enters_existing_result_stream',#SAO.WorldSources.completedResults('provisioning')==1)
check('failure_retains_prerequisite',P.consumeSourceResult(receipt)==true
    and purpose.cursor==1 and purpose.status=='interrupted')
local events=#purpose.events
check('failure_delivery_is_exact_once',P.consumeSourceResult(receipt)==true and #purpose.events==events)
check('terminal_failure_can_be_acknowledged',SAO.WorldSources.acknowledgeResult(r.id,'provisioning','purpose-delivered')==true)

body=reset() purpose=P.planStudy('a','cook',{bookNearby=true,literacy='reads'})
ok,r=SAO.SourceUse.beginAcquisition('a',body,p,'reading',{
    purposeId=purpose.id,purposeStepId='acquire-book',acceptItem=function(t) return t=='Base.BookCooking1' end})
SAO.WorldSources.failAction(r.id,'a','route-refused') receipt=SAO.WorldSources.actionOutcome(r.id,'a')
P.planStudy('a','cook',{purposeId=purpose.id,literacy='reads'})
check('route_failure_after_replan_does_not_pin_ledger',P.consumeSourceResult(receipt)==true
    and purpose.cursor==1 and purpose.steps[1].verb=='inspect'
    and SAO.WorldSources.acknowledgeResult(r.id,'provisioning','superseded-purpose')==true)
P.planStudy('a','cook',{purposeId=purpose.id,bookOwned=true,literacy='reads'})
P.noteAdmission('a',purpose.id,'SAONeeds','later-reading','read-session')
check('late_source_receipt_never_advances_new_read_admission',P.consumeSourceResult(receipt)==true
    and purpose.steps[purpose.cursor].verb=='read' and purpose.admission.correlationId=='later-reading')

body=reset()
SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__after))
check('newer_world_revision_does_not_fill_private_memory',SAO.WorldSources.actionOptions(p,'reading','a',body,1,'standing','acquire')==nil)
check('other_actor_never_receives_observed_stock',not SAO.WorldSources.privatelyKnowsItem('b','C:book:0',13))

body=reset() purpose=P.planStudy('a','cook',{literacy='reads'})
local agent={state='IDLE',rec=__records.a}
check('real_building_memory_drives_acquisition',SAO.Controller.advancePersonalPurpose('a',agent,body,100,{fatigue=0})==true
    and agent.state=='SOURCEWARD' and SAO.WorldSources.pendingActionFor('a').itemId==12)
check('purpose_search_preserves_actor_memory',__known.a[42].id==nil)
body=reset() purpose=P.planStudy('a','cook',{literacy='reads'})
local book={getSkillTrained=function() return 'Cooking' end,getNumberOfPages=function() return 100 end,
    getLvlSkillTrained=function() return 1 end,getMaxLevelTrained=function() return 2 end,
    getFullType=function() return 'Base.BookCooking1' end,getID=function() return 12 end}
instanceof=function(_,kind) return kind=='Literature' end
SAOJavaBridge.privateCarriedItems=function() return {size=function() return 1 end,get=function() return book end} end
agent={state='IDLE',rec=__records.a,nextStudyAt=10000}
check('owned_manual_waits_without_search_or_duplicate',SAO.Controller.advancePersonalPurpose('a',agent,body,100,{fatigue=0})==false
    and purpose.access=='owned' and purpose.steps[purpose.cursor].verb=='read'
    and not SAO.WorldSources.pendingActionFor('a'))
local other={}
for key,value in pairs(book) do other[key]=value end
other.getSkillTrained=function() return 'Woodwork' end
other.getFullType=function() return 'Base.BookCarpentry1' end
SkillBook.Woodwork={perk={getId=function() return 'Woodwork' end}}
__records.a.studyWork={status='interrupted',fullType='Base.BookCarpentry1'}
SAOJavaBridge.privateCarriedItems=function() return {size=function() return 2 end,
    get=function(_,i) return i==0 and other or book end} end
agent.nextPurposeAt=0
check('interrupted_other_subject_cannot_hide_owned_requirement',SAO.Controller.advancePersonalPurpose('a',agent,body,200,{fatigue=0})==false
    and purpose.access=='owned' and not SAO.WorldSources.pendingActionFor('a'))
body=reset() purpose=P.planStudy('a','cook',{bookNearby=true,literacy='reads'})
ok,r=SAO.SourceUse.beginAcquisition('a',body,p,'reading',{
    purposeId=purpose.id,purposeStepId='acquire-book',acceptItem=function(t) return t=='Base.BookCooking1' end})
SAO.WorldSources.failAction(r.id,'a','changed-permission') receipt=SAO.WorldSources.actionOutcome(r.id,'a')
P.planStudy('a','cook',{purposeId=purpose.id,bookNearby=true,literacy='reads'})
local again,newAttempt=SAO.SourceUse.beginAcquisition('a',body,p,'reading',{
    purposeId=purpose.id,purposeStepId='acquire-book',acceptItem=function(t) return t=='Base.BookCooking1' end})
check('old_failure_cannot_damage_replacement_admission',again==true and P.consumeSourceResult(receipt)==true
    and purpose.admission.correlationId==newAttempt.id and purpose.cursor==1)
__purposeResults=table.concat(checks,'\n')
'''

PRACTICE = r'''
local P=SAO.ProceduralPlanning
local function fixturePractice()
    newFixture() SAO.ProceduralPlanning=P
    SAO.History.literacyOf=function() return 'reads' end
    SAO.Census={JOB_PERK={cook='Cooking'},bookSkillFor=function(p) return p end}
    local purpose=P.planStudy(F.rec.id,'cook',{bookOwned=true,literacy='reads'})
    assert(P.recordResult(F.rec.id,purpose.id,{owner='SAONeeds',token='reading:progressed',status='completed'}))
    return purpose
end
case('goal_drives_undesignated_native_practice',function()
    local purpose=fixturePractice()
    local agent=SAO.Controller.agents[F.rec.id]
    local ctl=__personalOwner
    return ctl.advancePersonalPurpose(F.rec.id,agent,F.body,100,{fatigue=0})==true
        and agent.state=='COOK' and F.rec.cookingWork.purposeId==purpose.id
        and purpose.cursor==2
end)
case('completed_cooking_validates_retained_practice_once',function()
    local purpose=fixturePractice() heatSetup() nativeCooked() tickCooking()
    settleTransfer() completeToggle() tickCooking()
    P.reconcileCooking(F.rec.id)
    local count=F.rec.proceduralPlanning.practice.Cooking.completed
    P.reconcileCooking(F.rec.id)
    return purpose.status=='completed' and count==1 and F.rec.proceduralPlanning.practice.Cooking.completed==1
        and F.rec.proceduralPlanning.practice.Cooking.readingSessions==1
end)
case('interrupted_preparation_retains_goal_without_practice_credit',function()
    local purpose=fixturePractice() beginCooking()
    SAO.Cooking.interrupt(F.rec.id,F.body,'needs water') P.reconcileCooking(F.rec.id)
    local events=#purpose.events P.reconcileCooking(F.rec.id)
    return purpose.status=='interrupted' and purpose.cursor==2 and #purpose.events==events
        and F.rec.proceduralPlanning.practice.Cooking.completed==0
end)
case('queue_or_cooked_flag_never_awards_practice',function()
    local purpose=fixturePractice() heatSetup() F.food.cooked=true tickCooking()
    P.reconcileCooking(F.rec.id)
    return purpose.status~='completed' and F.rec.proceduralPlanning.practice.Cooking.completed==0
end)
case('receipt_requires_exact_native_credit',function()
    local purpose=fixturePractice() beginCooking() local work=F.rec.cookingWork
    local receipt={id=work.id,actorId=F.rec.id,purposeId=purpose.id,purposeStepId='practice',status='completed',
        retrieved=true,heatObserved=true,shutdown='off',nativeCredit='other-work'}
    F.rec.cookingOutcomes={receipt}
    return P.consumeCookingResult(F.rec.id,receipt)==false and purpose.cursor==2
end)
case('food_preparation_goal_survives_native_interruption',function()
    newFixture() SAO.ProceduralPlanning=P
    beginCooking() local goalId=F.rec.cookingWork.purposeId
    SAO.Cooking.interrupt(F.rec.id,F.body,'needs water') P.reconcileCooking(F.rec.id)
    local purpose=P.pending(F.rec.id,'produce','Cooking')
    local held=purpose and purpose.id==goalId and purpose.status=='interrupted'
    beginCooking()
    return held and F.rec.cookingWork.purposeId==goalId
        and #F.rec.proceduralPlanning.order==1
end)
case('source_outcomes_preserve_cognitive_and_shared_consumers',function()
    local purpose=fixturePractice()
    local cognitive,shared=0,0
    SAO.Cognition={preparationOutcome=function() cognitive=cognitive+1 end}
    SAO.Organization={consumeProcedureResult=function() shared=shared+1 end}
    heatSetup() F.rec.cookingWork.commitmentId='existing-cooperation'
    nativeCooked() tickCooking() settleTransfer() completeToggle() tickCooking()
    return cognitive==1 and shared==1 and purpose.status=='completed'
end)
__purposeResults=table.concat(__cookingCases,'\n')
'''

CONTROLS = [
    ('source', 'context.sourceId == nil or tostring(parameters.sourceId) == tostring(context.sourceId)',
     'true', 'retained_source_cannot_substitute_another_container', 'acquisition'),
    ('source', 'context.itemId == nil or tostring(parameters.itemId) == tostring(context.itemId)',
     'true', 'retained_source_cannot_substitute_another_item', 'acquisition'),
    ('source', 'context.itemType == nil or parameters.itemType == context.itemType',
     'true', 'retained_source_requires_matching_type', 'acquisition'),
    ('source', 'context.sourceRevision == nil or tostring(parameters.revision) == tostring(context.sourceRevision)',
     'true', 'retained_source_requires_matching_revision', 'acquisition'),
    ('study', 'item:getLevelSkillTrained() + item:getNumLevelsTrained() - 1 >= level',
     'item:getLevelSkillTrained() + item:getNumLevelsTrained() >= level',
     'script_metadata_uses_native_inclusive_book_boundary', 'acquisition'),
    ('world', 'physical.revision == source.revision', 'true', 'newer_world_revision_does_not_fill_private_memory', 'acquisition'),
    ('source', 'reservation.purposeId, reservation.purposeStepId = context.purposeId, context.purposeStepId',
     'reservation.purposeId, reservation.purposeStepId = nil, nil', 'native_acquisition_advances_same_purpose', 'acquisition'),
    ('planner', 'if key == receiptKey then return true end', 'if false then return true end', 'failure_delivery_is_exact_once', 'acquisition'),
    ('planner', 'canonical.nativeCredit ~= canonical.id', 'false', 'receipt_requires_exact_native_credit', 'practice'),
    ('cooking', 'SAO.ProceduralPlanning and not SAO.ProceduralPlanning.admitCooking(id, rec.cookingWork)',
     'false', 'goal_drives_undesignated_native_practice', 'practice'),
]

def main():
    texts = {name: path.read_text(encoding='utf-8-sig') for name, path in FILES.items()}
    if not (GAME/'projectzomboid.jar').is_file():
        print('Border 215 SKIPPED: installed engine unavailable'); return 0
    try:
        with tempfile.TemporaryDirectory(prefix='sao-purpose-work-') as directory:
            work=Path(directory)
            shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
            subprocess.run([str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar'),'-d',str(work),
                            str(ROOT/'tools/luacheck/LuaRun.java')],check=True,capture_output=True,text=True)
            def run(kind, changed=None):
                code=dict(texts); code.update(changed or {})
                controller=code['controller'].split('function Ctl.advancePersonalPurpose',1)[1].split('-- Each decision phase',1)[0]
                code['controller']='local Ctl=SAO.Controller\nlocal setState=function(agent,id,state) agent.state=state return true end\n'
                code['controller']+='local beginContainerInspection=function() return false end\nfunction Ctl.advancePersonalPurpose'+controller+'\n__personalOwner=Ctl\n'
                paths=[]
                def add(name, text):
                    path=work/(kind+'-'+name+'.lua');path.write_text(text,encoding='utf-8');paths.append(path)
                if kind=='acquisition':
                    add('prelude',source_fixture.ACTION_PRELUDE)
                    add('setup',SETUP+'\n__before='+repr(SOURCE).replace("'",'"')+'\n__after='+repr(POST).replace("'",'"'))
                    for name in ['world','planner','source','study','controller']: add(name,code[name])
                    add('cases',ACQUISITION)
                else:
                    paths=[ROOT/'tools/cooking_checks/prelude.lua', GAME/'media/lua/shared/ISBaseObject.lua',
                           GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
                           GAME/'media/lua/shared/TimedActions/ISToggleStoveAction.lua']
                    add('initial','SAO={} SAO.Controller={} SAO.Pharmacology={} SAO.ResourceProduction={} require=function() end\n')
                    for name in ['planner','cooking','experience','controller']: add(name,code[name])
                    add('cases',PRACTICE)
                done=subprocess.run([str(JDK/'java.exe'),'-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(GAME/'projectzomboid.jar'),
                    'LuaRun',*map(str,paths),'--','__purposeResults'],cwd=work,capture_output=True,text=True,timeout=60)
                expected=set(re.findall(r"(?:check\('|case\(')([a-z0-9_]+)'",ACQUISITION if kind=='acquisition' else PRACTICE))
                checks=dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',done.stdout.replace('VALUE ',''),re.M))
                if done.returncode or set(checks)!=expected: raise RuntimeError(kind+': '+done.stdout[-7000:]+done.stderr[-1000:])
                return checks
            count=0
            for kind in ['acquisition','practice']:
                checks=run(kind); count+=len(checks)
                failures=[name for name,value in checks.items() if value!='true']
                if failures: raise RuntimeError(kind+' failures: '+', '.join(failures))
            for name,before,after,target,kind in CONTROLS:
                if texts[name].count(before)!=1: raise RuntimeError(target+': mutation anchor differs')
                checks=run(kind,{name:texts[name].replace(before,after,1)})
                if checks[target]!='false': raise RuntimeError(target+': mutation survived')
            jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
            cp=os.pathsep.join(map(str,jars))
            sources=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
                     ROOT/'tools/cognition_checks/CognitionUseProbe.java',ROOT/'tools/javacheck/PurposeWorkProbe.java']
            build=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(work),*map(str,sources)],
                                 capture_output=True,text=True,timeout=60)
            if build.returncode: raise RuntimeError('native compile: '+build.stderr[-3000:])
            command=[str(JDK/'java.exe'),'-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                     '-cp',str(work)+os.pathsep+cp,'PurposeWorkProbe',str(GAME)]
            native=subprocess.run(command,cwd=work,capture_output=True,text=True,timeout=60)
            if native.returncode or 'PURPOSE_WORK_NATIVE_OK' not in native.stdout:
                raise RuntimeError('native acquisition: '+native.stdout[-3000:]+native.stderr[-2000:])
            native_count=len(re.findall(r'^CHECK .+=true$',native.stdout,re.M))
            java=(ROOT/'java/src/com/sao/engine/SAOWorldSources.java').read_text(encoding='utf-8')
            anchor='if (row.categories.isEmpty()) {'
            if java.count(anchor)!=1: raise RuntimeError('native category control anchor differs')
            mutant=work/'SAOWorldSources.java'
            mutant.write_text(java.replace(anchor,'if (!(row.categories.contains("food") || row.categories.contains("water"))) {'),encoding='utf-8')
            build=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(work),str(mutant)],
                                 capture_output=True,text=True,timeout=60)
            if build.returncode: raise RuntimeError('native category control compile: '+build.stderr[-3000:])
            native=subprocess.run(command,cwd=work,capture_output=True,text=True,timeout=60)
            if not native.returncode or 'CHECK native_acquire_BookCooking1=false' not in native.stdout:
                raise RuntimeError('food-only native transfer control survived: '+native.stdout[-2000:])
            print(f'Border 215 PASS: {count} Kahlua cases, {native_count} installed native acquisition checks; {len(CONTROLS)+1} named controls')
            return 0
    except Exception as error:
        print('FAULT Border 215:',error); return 1

if __name__=='__main__': raise SystemExit(main())
