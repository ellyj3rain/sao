local C,S,M=SAO.Cognition,SAO.Study,SAO.CognitiveModels
local count=0
local function check(name,value)
    assert(value,'D2_READING:'..name);count=count+1;print('CASE '..name)
end
local function deep(v)
    if type(v)~='table' then return v end
    local out={} for k,x in pairs(v) do out[k]=deep(x) end return out
end
local function fresh()
    __records={a={id='a'},b={id='b'}};__stores={};__hours=10
    ISTimedActionQueue.queues={};ISTimedActionQueue.accept=true
    SAO.Study=S;SAO.PersonState=nil
    check('settings_'..count,C.configure(0,12,3))
    local body,book=fixture('a');book.domain=nil;book.fullType='Base.Book'
    local mood={bored=40,unhappy=30,stress=.6}
    function body:getStats()return {get=function(_,k)return mood[k]end,set=function(_,k,v)mood[k]=v end}end
    function body:ReadLiterature()self.literatureEffects=(self.literatureEffects or 0)+1;mood.bored=mood.bored-10;mood.unhappy=mood.unhappy-5;mood.stress=mood.stress-.1 end
    return body,book,mood
end
local function read(body,book,delta,finish)
    local admitted=S.beginLeisure('a',body,book)
    local eligible,why=S.readingEligibility('a',body,book,'leisure')
    assert(admitted,'begin read helper seq '..tostring(__records.a.studySequence)..' '..tostring(why))
    local action=ISTimedActionQueue.queues[body].action
    native(action,delta);action:update()
    if finish then assert(action:complete(),'complete read helper');action:perform() else S.interrupt('a',body,'observed danger') end
    return action
end
local function candidates(kind)
    return {{id='reading',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0,
        consequences={{kind=kind or 'recreate',category='leisure',sourceId='native:literature:ISReadABook',itemType='Base.Book',condition=kind and 'BOREDOM' or nil,value=1}}},
        {id='neutral',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0}}
end
local function views(kind)return C.interpretPlans('a',candidates(kind),{atHours=10,pressure=0,domain='leisure'})end
do
    local body,book=fresh()
    assert(S.beginLeisure('a',body,book),'initial begin')
    check('admission_is_not_experience',__records.a.leisureReadingOutcomes==nil and __records.a.cognition==nil)
    local action=ISTimedActionQueue.queues[body].action;native(action,.4);action:update();S.interrupt('a',body,'observed danger')
    local r=S.leisureOutcome('a',1)
    check('partial_pages_are_attempted_not_completed',r and r.status=='interrupted' and r.pagesAfter==40 and r.progress==.4 and not r.nativeCompleted and r.mood==nil)
    local partialViews=views()
    check('partial_attempt_changes_actual_comparison',partialViews.selected=='neutral'
        and partialViews.models[1].ranked[2].predictions[1].probability<.5
        and partialViews.models[1].ranked[2].predictions[1].basis=='exact-experience'
        and __records.a.cognition.experiences[1].succeeded==false)
    read(body,book,1,true)
    r=S.leisureOutcome('a',2)
    check('completed_native_pages_are_exact',r.status=='completed' and r.pagesBefore==40 and r.pagesAfter==100 and r.nativeOwner=='ISReadABook.complete' and r.custodyVerified)
    check('measured_completion_mood_is_exact',r.mood.BOREDOM.before==40 and r.mood.BOREDOM.after==30 and r.mood.UNHAPPINESS.after==25 and r.moodMeasurement=='immediate-native-completion')
    check('no_content_or_skill_claim',__records.a.cognition.experiences[2].actionKind=='read-book' and body.level==0 and body.multiplier==0 and r.meaning=='native-reading; comprehension-unassessed')
    local revision=__records.a.cognition.models.ordinary.revision
    check('duplicate_no_relearning',C.leisureReadingOutcome('a',2) and __records.a.cognition.models.ordinary.revision==revision and #__records.a.cognition.experiences==2)
    r.mood.BOREDOM.after=999
    check('receipt_getter_is_detached',S.leisureOutcome('a',2).mood.BOREDOM.after==30)
    check('measured_relief_changes_actual_comparison',views('reading-relief').selected=='reading' and views('reading-relief').models[1].ranked[1].predictions[1].basis=='exact-experience')
    check('foreign_person_cannot_acquire',not C.leisureReadingOutcome('b',2) and __records.b.cognition==nil)
    local good=deep(__records.a.cognition.experiences[2]);good.id='leisure-reading/a/3';good.occurredAtHours=10
    check('generic_authority_refused',not C.experience('a',good))
    good.mastery=true;check('model_refuses_unsupported_mastery',not M.acceptsExperience(good));good.mastery=nil
    good.sourceId='native:literature:forged';check('model_refuses_wrong_source',not M.acceptsExperience(good))
    local previous=__records.a.cognition.models.ordinary.revision
    __records.a=__nativeRoundtrip(__records.a)
    check('native_reload_preserves_exact_once',C.leisureReadingOutcome('a',2) and __records.a.cognition.models.ordinary.revision==previous and S.leisureOutcome('a',2).mood.BOREDOM.after==30)
    local exact=deep(__records.a.leisureReadingOutcomes[2])
    local invalid={
        {'foreign_actor','actorId','b'}, {'foreign_sequence','sequence',99}, {'forged_work','workId','forged'},
        {'missing_purpose','purposeId',false}, {'missing_body','bodyToken',false}, {'future_time','atHours',11},
        {'stale_time','beganAt',-1}, {'no_started','nativeStarted',false}, {'no_custody','custodyVerified',false},
        {'no_progress','progress',0}, {'partial_completed_pages','pagesAfter',99}, {'forged_owner','nativeOwner','forged'},
        {'fractional_item','itemId','7.5'}, {'unmeasured_mood','moodMeasurement','elapsed-time'} }
    for _,bad in ipairs(invalid)do
        local row=deep(exact);row.sequence=3;row.workId='study/3';row[bad[2]]=bad[3]
        __records.a.leisureReadingOutcomes[3]=row
        check('refuses_'..bad[1],not C.leisureReadingOutcome('a',3))
    end
    __records.a.leisureReadingOutcomes[3]=nil
    check('forged_plan_source_refused',M.planPrediction('ordinary',
        {id='forged',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0,
            consequences={{kind='recreate',category='leisure',sourceId='forged',itemType='Base.Book',value=1}}},
        __records.a.cognition.models.ordinary,{actorId='a',atHours=10,pressure=0})==nil)
end
do
    local body,book=fresh();local action=read(body,book,1,true)
    local v=views();check('completion_changes_actual_comparison',v.selected=='reading')
    for index=1,3 do body.pages=0;book.pages=0;book.id=book.id+1;read(body,book,.2,false) end
    check('contrary_outcomes_change_actual_comparison',views().selected=='neutral')
    check('interruption_does_not_manufacture_mood',S.leisureOutcome('a',4).mood==nil and __records.a.cognition.experiences[4].stats==nil)
    -- Independent admitted sessions exercise the outcome cap; this does not
    -- test retention or retirement of a person's bounded purpose collection.
    for index=1,34 do __records.a.proceduralPlanning=nil;body.pages=0;book.pages=0;book.id=book.id+1;read(body,book,.1,false) end
    check('bounded_owner_ledger',#__records.a.leisureReadingOutcomes==32 and S.leisureOutcome('a',1)==nil)
    check('retired_owner_receipt_refused',not C.leisureReadingOutcome('a',1))
    action:complete();check('late_native_call_cannot_change_current_work',#__records.a.leisureReadingOutcomes==32 and __records.a.studyWork.sequence==38)
end
do
    local body,book=fresh();assert(S.beginLeisure('a',body,book));local action=ISTimedActionQueue.queues[body].action
    native(action,.25);action:update();__records.a=__nativeRoundtrip(__records.a)
    __reloadStudy();local interrupted=S.interrupt('a',body,'reload');local reloaded=S.leisureOutcome('a',1)
    check('runtime_reload_closes_attempt',interrupted and reloaded and reloaded.status=='interrupted' and not reloaded.custodyVerified)
    local replayOk,replayReason=C.leisureReadingOutcome('a',1)
    assert(replayOk,'reload outcome '..tostring(replayReason)..' '..tostring(S.leisureOutcome('a',1).pagesAfter))
    check('runtime_reload_keeps_attempted_pages',S.leisureOutcome('a',1).pagesAfter==25 and __records.a.cognition.experiences[1].succeeded==false)
end
do
    local body,book=fresh();book.notes={'Existing personal message.'}
    function book:canBeWrite()return true end
    function book:isEmptyPages()return false end
    function book:getCustomPages()return {size=function()return #book.notes end}end
    function book:seePage(i)return self.notes[i]end
    assert(S.beginLeisure('a',body,book));local action=ISTimedActionQueue.queues[body].action
    native(action,1);action:update();action:perform();assert(action:complete())
    local r=S.leisureOutcome('a',1)
    check('note_exposure_is_native_typed',r.actionKind=='read-note' and r.contentBytes==26 and r.contentPages==1 and r.contentBinding=='study/1')
    check('note_exposure_is_not_book_or_mood',r.pagesAfter==nil and r.mood==nil and body.literatureEffects==nil and __records.a.cognition.experiences[1].stats==nil)
    check('note_comprehension_remains_unknown',r.meaning=='text-exposure; comprehension-unassessed' and body.multiplier==0)
    local row=__records.a.leisureReadingOutcomes[1];row.mood={BOREDOM={before=20,after=10}}
    check('note_mood_cannot_be_forged',not C.leisureReadingOutcome('a',1))
end
do
    local body,book=fresh();local captured
    SAO.History.ticks=function()return 100 end
    SAO.PersonState={query=function(id,_,tick)
        captured={schema='sao-person-state/1',actorId=id,atTick=tick,atHours=10,status='unavailable',reason='controlled-field-unavailable'}
        return captured
    end}
    local v=views();check('plan_freezes_owned_person_state',v and v.decisionPersonState and v.decisionPersonState.personState.reason=='controlled-field-unavailable')
    captured.reason='changed';check('plan_snapshot_is_detached',v.decisionPersonState.personState.reason=='controlled-field-unavailable')
    SAO.PersonState.query=function()return {schema='sao-person-state/1',actorId='b',atTick=100,status='unavailable',reason='foreign'}end
    check('foreign_person_state_is_unavailable',views().decisionPersonState.reason=='person-state-binding-unavailable')
end
__result='PASS D2 reading experience '..count
