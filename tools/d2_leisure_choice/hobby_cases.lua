-- The source producer is a controlled canonical receiver here. Native body,
-- Planner/Cognition/Models and the Controller lifecycle execute as installed.
local Ctl,P,C,M=SAO.Controller,SAO.ProceduralPlanning,SAO.Cognition,SAO.CognitiveModels
local count=0
local function check(name,v)assert(v,'D2_HOBBY_JOIN:'..name);count=count+1;print('CASE '..name)end
local function copy(v)if type(v)~='table'then return v end;local o={}for k,x in pairs(v)do o[k]=copy(x)end;return o end
local function empty(t)for _ in pairs(t)do return false end;return true end
local definitions={
    {name='SAO.Leisure',module='Leisure',field='leisureWork',activity='meditate',source='LifestyleHobbies'},
    {name='SAO.LeisureExercise',module='LeisureExercise',field='exerciseLeisureWork',activity='squats',source='native:ISFitnessAction'},
    {name='SAO.LeisureArt',module='LeisureArt',field='artLeisureWork',activity='paint-canvas',source='LifestyleHobbies:paint-canvas'},
    {name='SAO.LeisureMusic',module='LeisureMusic',field='leisureMusicWork',activity='practice-instrument',source='LifestyleHobbies'},
    {name='SAO.LeisureGames',module='LeisureGames',field='gamesWork',activity='play-computer-game',source='ComputerModkum:PZSnakeGame'},
    {name='SAO.LeisureRadio',module='LeisureRadio',field='leisureRadioWork',activity='listen-native-radio',source='native:ISRadioInteractions'},
    {name='SAO.LeisureLifestyle',module='LeisureLifestyle',field='leisureLifestyleWork',activity='dj-performance',source='LifestyleHobbies'},
}
local results,advances,interrupts={},{},{}
local function fresh()
    __hours=10;__records={person={id='person'},foreign={id='foreign'}};__stores={};__dispatch={}
    results={};advances={};interrupts={}
    __body:getModData().SAOPersonId='person';__body:getModData().SAOExternalOwner=nil
    __body:getModData().SAOExternalToken=nil;__body:getModData().ZAOOwned=nil
    __body:setAsleep(false);__body:getCharacterActions():clear()
    __body:getStats():set(CharacterStat.BOREDOM,20)
    SAO.Body.active.person=__body;SAO.Body.foreign.person=nil
    SAO.Disposition.eatAt=function()return .3 end;SAO.Disposition.drinkAt=function()return .3 end
    SAO.ConflictResponse=nil;SAO.PersonState=nil
    assert(C.configure(0,12,3))
    local rec=__records.person;local agent={rec=rec,state='IDLE'};Ctl.agents.person=agent
    for _,d in ipairs(definitions)do
        results[d.name]={};advances[d.name]=0;interrupts[d.name]=0
        SAO[d.module]={work=function(id)return copy(__records[id] and __records[id][d.field])end,
            outcome=function(id,seq)return id=='person' and copy(results[d.name][seq])end,
            advance=function()advances[d.name]=advances[d.name]+1;return true end,
            interrupt=function(id,body,reason)
                if id~='person' or body~=__body then return false end
                local w=rec[d.field];if not w then return false end
                w.status='interrupted';w.reason=reason;w.atHours=10
                results[d.name][w.sequence]=copy(w);rec[d.field]=nil;interrupts[d.name]=interrupts[d.name]+1
                return P.consumeHobbyOutcome(id,w.sequence,d.name)
            end}
    end
    return rec,agent
end
local function prepare(rec,d,seq)
    local purpose=P.planLeisure('person',{activity=d.activity,activityKey=d.module,nativeVerb=d.activity,
        owner=d.name,affordance=d.source,atLocation=true,locationKey='10:20:0'})
    if not purpose then return nil,nil end
    local w={actorId='person',sequence=seq or 1,workId=d.module..'/person/'..(seq or 1),
        purposeId=purpose.id,family=d.module,activity=d.activity,sourceId=d.source,revision=string.rep('a',64),
        bodyGenerationKnown=false,admittedAtHours=10,status='active',nativeOwner='controlled:source-owner',
        nativeProgress={observedUpdates=1,delta=.5}}
    rec[d.field]=w
    return w,purpose
end
local function terminal(rec,d,w,status)
    w.status=status;w.atHours=10;w.nativeProgress.delta=status=='completed' and 1 or .5
    results[d.name][w.sequence]=copy(w);rec[d.field]=nil
    return P.consumeHobbyOutcome('person',w.sequence,d.name)
end
local function predictions(d)
    return C.interpretPlans('person',{{id='hobby',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0,
        consequences={{kind='hobby',category='leisure',sourceId=d.source,condition=d.activity,value=1}}},
        {id='neutral',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0,consequences={}}},
        {domain='leisure',atHours=10,pressure=0})
end
do
    local rec,agent=fresh();local d=definitions[7];local w,purpose=prepare(rec,d)
    assert(P.admitHobbyWork('person',purpose.id,1,d.name))
    check('native_lifestyle_field_reaches_controller',Ctl.advanceLeisure('person',agent,__body,10000,
        {hunger=0,thirst=0,endurance=1,fatigue=0}) and advances[d.name]==1)
    local before=interrupts[d.name]
    check('foreign_body_cannot_retire_lifestyle',not Ctl.retireLeisureWork('person',agent,__other,'foreign')
        and rec.leisureLifestyleWork==w and interrupts[d.name]==before)
    check('exact_body_retires_lifestyle_before_detach',Ctl.retireLeisureWork('person',agent,__body,'controller-drop')
        and rec.leisureLifestyleWork==nil and interrupts[d.name]==before+1)
end
do
    local rec,agent=fresh()
    for _,d in ipairs(definitions)do
        local w,purpose=prepare(rec,d)
        check('typed_admission_'..d.module,P.admitHobbyWork('person',purpose.id,w.sequence,d.name))
        check('admission_does_not_teach_'..d.module,rec.cognition==nil or #rec.cognition.experiences==_ - 1)
        check('terminal_owner_consumed_'..d.module,terminal(rec,d,w,'completed'))
        check('independent_provider_cursor_'..d.module,#rec.cognition.experiences==_)
        local before=rec.cognition.models.ordinary.revision
        check('duplicate_is_idempotent_'..d.module,P.consumeHobbyOutcome('person',1,d.name)
            and rec.cognition.models.ordinary.revision==before)
        check('source_condition_prediction_'..d.module,predictions(d).selected=='hobby')
        check('no_skill_or_shared_credit_'..d.module,empty(rec.proceduralPlanning.practice)
            and purpose.steps[3].status=='not-required' and purpose.status=='completed')
        local candidate=copy(rec.cognition.experiences[#rec.cognition.experiences]);candidate.id=candidate.id..'0'
        check('generic_caller_cannot_publish_hobby',not C.experience('person',candidate))
    end
    local d=definitions[1];local w,purpose=prepare(rec,d,2)
    check('repeat_session_gets_new_purpose',purpose and purpose.id~=results[d.name][1].purposeId
        and P.admitHobbyWork('person',purpose.id,2,d.name))
end
do
    local rec,agent=fresh();local d=definitions[2];local w,purpose=prepare(rec,d)
    assert(P.admitHobbyWork('person',purpose.id,1,d.name))
    local unconsumed=copy(w);unconsumed.status='completed';unconsumed.atHours=10
    results[d.name][1]=unconsumed
    check('unconsumed_outcome_cannot_teach',not C.hobbyOutcome('person',d.name,1) and rec.cognition==nil)
    check('unselected_family_cannot_consume',not P.consumeHobbyOutcome('person',1,'SAO.LeisureArt'))
    check('foreign_person_cannot_acquire',not C.hobbyOutcome('foreign',d.name,1))
    check('interrupted_attempt_consumed',terminal(rec,d,w,'interrupted'))
    local views=predictions(d)
    check('interruption_changes_later_prediction',views and views.selected=='neutral'
        and rec.cognition.experiences[1].succeeded==false)
    check('no_pleasure_inference_from_attempt',rec.cognition.experiences[1].stats==nil)
end
do
    local rec,agent=fresh();local d=definitions[1];local w,purpose=prepare(rec,d)
    assert(P.admitHobbyWork('person',purpose.id,1,d.name))
    purpose.status='abandoned'
    local r=copy(w);r.status='interrupted';r.atHours=10;results[d.name][1]=r
    check('retired_purpose_cannot_be_revived',not P.consumeHobbyOutcome('person',1,d.name)
        and purpose.status=='abandoned' and rec.cognition==nil)
    check('retired_active_admission_unavailable',P.hobbyAdmission('person',purpose.id,w.workId)==nil)
end
do
    local rec,agent=fresh();local d=definitions[3];local w,purpose=prepare(rec,d)
    assert(P.admitHobbyWork('person',purpose.id,1,d.name))
    local needs={hunger=0,thirst=0,fatigue=.1,endurance=1}
    check('active_hobby_holds_own_body',Ctl.advanceLeisure('person',agent,__body,100,needs)
        and advances[d.name]==1 and agent.pressure.owner==d.name)
    check('foreign_body_cannot_interrupt_work',not Ctl.interruptLeisure('person',agent,__other,'foreign'))
    needs.thirst=.5
    check('native_need_interrupts_current_hobby',not Ctl.advanceLeisure('person',agent,__body,101,needs)
        and interrupts[d.name]==1 and rec.artLeisureWork==nil and purpose.status=='interrupted')
    check('interruption_preserves_native_mood',__body:getStats():get(CharacterStat.BOREDOM)==20)
end
do
    local rec,agent=fresh();local d=definitions[4];local w,purpose=prepare(rec,d)
    assert(P.admitHobbyWork('person',purpose.id,1,d.name))
    check('threat_closes_exact_owner',Ctl.interruptLeisure('person',agent,__body,'threat response')
        and interrupts[d.name]==1 and results[d.name][1].reason=='threat response')
end
do
    local rec,agent=fresh();local d=definitions[5];local w,purpose=prepare(rec,d)
    assert(P.admitHobbyWork('person',purpose.id,1,d.name))
    check('native_games_field_reaches_controller',Ctl.advanceLeisure('person',agent,__body,10000,
        {hunger=0,thirst=0,endurance=1,fatigue=0}) and advances[d.name]==1)
    local before=interrupts[d.name]
    check('foreign_body_cannot_retire_hobby',not Ctl.retireLeisureWork('person',agent,__other,'foreign')
        and rec.gamesWork==w and interrupts[d.name]==before)
    check('exact_body_retires_before_detach',Ctl.retireLeisureWork('person',agent,__body,'controller-drop')
        and rec.gamesWork==nil and interrupts[d.name]==before+1)
end
do
    local rec,agent=fresh()
    check('unloaded_idle_controller_can_retire',Ctl.retireLeisureWork('person',agent,nil,'unloaded-idle'))
    rec.gamesWork={status='active'}
    check('unloaded_active_work_requires_body',not Ctl.retireLeisureWork('person',agent,nil,'unloaded-active'))
end
print('PASS D2 hobby join '..count)
