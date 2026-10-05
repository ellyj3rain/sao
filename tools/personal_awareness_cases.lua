local checks=0
local function check(name,value) if not value then error('PERSONAL_AWARENESS:'..name) end;checks=checks+1 end
local F=__awarenessFixture
local pending=nil
SAO.PopulationAdmissions={}
check('foreign_issuer_cannot_bind',not SAO.PersonalAwareness.bindInitialProvider({},function()return pending end))
check('canonical_issuer_binds_once',SAO.PersonalAwareness.bindInitialProvider(SAO.PopulationAdmissions,function(rec)
    return pending and pending.personId==rec.id and pending or nil
end))
check('issuer_cannot_replace_reader',not SAO.PersonalAwareness.bindInitialProvider(SAO.PopulationAdmissions,function()return{}end))
local function bundle(entries)
    return {schema='sao-personal-awareness-initial/1',personId='runner',issuerId='native-admission:fixture',
        sourceId='reviewed-definition:fixture',admissionKey='runner:native:1',admittedAtHours=2,entries=entries or {}}
end
local function entry(kind,affirmed,certainty)
    return {id='prior:'..kind,kind=kind,affirmed=affirmed,sourceId='authored-history:fixture',
        sourceAtHours=1,receivedAtHours=1,certainty=certainty or 'reported'}
end
local function fresh(entries)
    local a,b,t=F.fresh();pending=bundle(entries)
    SAO.Perception.beliefs.runner={zombies={},people={},factions={},places={},lastScanAt=0,scanCount=0}
    SAO.History.ticks=function()return 18000 end
    check('canonical_initial_attaches',SAO.PersonalAwareness.attachInitial(a.rec))
    return a,b,t
end
local function query()return SAO.Knowledge.outbreakAwareness('runner')end
local function radio(id,at,kind)
    return SAO.Perception.recordRadioReception(id,'broadcast:'..id..':'..kind,'source:actual-radio',90000,at,
        {representation='loaded',deviceItemId=12,deviceType='Base.RadioBlack',channel=90000,power=1},{{kind=kind}})
end
local a,b,t=F.fresh();pending=nil
check('omitted_initial_preserves_legacy',SAO.PersonalAwareness.attachInitial(a.rec) and query().possible and not query().configured)
check('pure_legacy_query_does_not_allocate',query().possible and a.rec.personalAwareness==nil)
a,b,t=fresh()
check('empty_initial_is_naive',query().configured and not query().possible and query().propositions.turned=='unknown')
a.rec.birthYear=1940;a.rec.culture='experienced-apocalypse';a.rec.age=80
check('age_and_culture_do_not_grant_awareness',not query().possible)
local ordinary=SAO.ConceptKnowledge.infer('runner','defense','create-space')
check('naive_preserves_ordinary_defense_knowledge',ordinary and ordinary.paths and #ordinary.paths>0)
local foreign={id='runner'}
check('foreign_record_refused',not SAO.PersonalAwareness.attachInitial(foreign) and foreign.personalAwareness==nil)
local initial=a.rec.personalAwareness
pending=bundle({entry('outbreak',true)})
check('pure_query_withholds_rebound_admission',query().status=='unavailable' and not query().possible and a.rec.personalAwareness==initial)
check('initial_never_overwrites_private_state',not SAO.PersonalAwareness.attachInitial(a.rec) and a.rec.personalAwareness==initial and query().status=='unavailable')
pending=bundle();check('restored_current_binding_restores_private_state',SAO.PersonalAwareness.attachInitial(a.rec) and a.rec.personalAwareness==initial and not query().possible)
pending={personId='runner'};check('failed_authored_admission_is_not_legacy',query().configured and query().status=='unavailable' and not query().possible)
pending=bundle()

a,b,t=F.fresh();pending=bundle();pending.admittedAtHours=3
check('future_initial_refused',not SAO.PersonalAwareness.attachInitial(a.rec) and a.rec.personalAwareness==nil)
check('unattached_authored_person_is_not_legacy',query().configured and not query().possible and a.rec.personalAwareness==nil)
pending=bundle();pending.personId='other'
-- The issuer has no current admission for this person: it returns no authored state.
check('nonadmitted_person_not_initialized',SAO.PersonalAwareness.attachInitial(a.rec) and a.rec.personalAwareness==nil)
pending=bundle({entry('turned',true)});pending.entries[1].receivedAtHours=3
check('future_initial_evidence_refused',not SAO.PersonalAwareness.attachInitial(a.rec))
pending=bundle({entry('turned',true)});pending.entries[1].extra=true
check('unknown_initial_field_refused',not SAO.PersonalAwareness.attachInitial(a.rec))
pending=bundle({entry('turned',true),entry('turned',true)})
check('duplicate_initial_evidence_refused',not SAO.PersonalAwareness.attachInitial(a.rec))

a,b,t=fresh()
check('actual_private_radio_report_admitted',radio('runner',2,'turned'))
local heard=query()
check('radio_is_report_not_confirmation',heard.possible and heard.propositions.turned=='reported'
    and heard.evidence[1].certainty=='reported' and heard.evidence[1].sourceId=='source:actual-radio')
heard.evidence[1].certainty='witnessed';heard.possible=false
check('queries_are_detached',query().possible and query().evidence[1].certainty=='reported')
check('future_radio_admission_refused',not radio('runner',3,'outbreak'))
local copy=__nativeRoundtrip(a.rec.personalAwareness)
a.rec.personalAwareness=copy;pending=bundle()
check('native_reload_preserves_private_initial',query().configured and query().propositions.turned=='reported'
    and SAO.PersonalAwareness.attachInitial(a.rec) and a.rec.personalAwareness==copy)

a,b,t=fresh();F.record('other',{id='other'})
check('other_person_radio_admitted',radio('other',2,'turned'))
check('foreign_radio_does_not_grant_my_awareness',not query().possible)
SAO.Perception.beliefs.runner.radioReceptions={future={broadcastId='future',sourceId='source:radio',frequency=90000,
    receivedAt=3,representation='loaded',deviceItemId=12,deviceType='Base.RadioBlack',channel=90000,power=1,claims={{kind='turned'}}}}
check('future_saved_radio_withheld',not query().possible)
local state=a.rec.personalAwareness;state.actorId='other'
check('foreign_saved_state_withheld',query().status=='unavailable' and not query().possible)
state.actorId='runner'

a,b,t=fresh({entry('turned',false)})
radio('runner',2,'turned')
check('contrary_evidence_retained',query().propositions.turned=='challenged' and not query().possible and #query().evidence==2)

local function scan(a,b,source,asleep,foreignToken,futureTick)
    SAO.Perception.beliefs.runner.people.Familiar=source and {source=source,at=17900,x=1,y=1} or nil
    F.record('known',{id='known',dead=true})
    SAO.Identity.resolveBodyTag=function(tag)
        if tag=='known' then return 'known',SAO.Identity.get('known'),'Familiar' end
    end
    SAOJavaBridge.perceive=function()return 'Z:1:1:1:known:track:actual-contact:floor:0' end
    if foreignToken then b.data.SAOExternalToken='foreign-token' end
    SAO.Perception.observe('runner',b,futureTick and 18001 or 18000,asleep)
end
a,b,t=fresh();scan(a,b,nil,false)
check('stranger_native_z_does_not_grant_awareness',not query().possible)
check('physical_contact_survives_naive_interpretation',SAO.Perception.nearestBelievedZombie('runner',18000,0,0).recognition.kind=='unidentified-contact')
a,b,t=fresh();scan(a,b,'told',false)
check('told_person_memory_does_not_confirm_turn',not query().possible)
a,b,t=fresh();scan(a,b,'observed',true)
check('sleeping_person_does_not_gain_witness',not query().possible)
a,b,t=fresh();scan(a,b,'observed',false,true)
check('foreign_body_token_cannot_gain_witness',not query().possible)
a,b,t=fresh();scan(a,b,'observed',false,false,true)
check('future_scan_cannot_gain_witness',not query().possible)
a,b,t=fresh();scan(a,b,'observed',false)
check('awake_familiar_change_supplies_narrow_association',query().possible
    and query().propositions.turned=='witnessed-association' and query().propositions.outbreak=='unknown')
local learned=__nativeRoundtrip(a.rec.personalAwareness)
a.rec.personalAwareness=learned;pending=bundle()
check('native_reload_keeps_acquired_association',SAO.PersonalAwareness.attachInitial(a.rec)
    and a.rec.personalAwareness==learned and query().propositions.turned=='witnessed-association')

a,b,t=fresh()
SAOJavaBridge.perceive=function()return 'S:2:3:2' end
SAO.Perception.observe('runner',b,18000,false)
local soundCount=0;for _ in pairs(SAO.Perception.beliefs.runner.sounds) do soundCount=soundCount+1 end
check('unknown_sound_never_grants_cause_or_zombie',not query().possible and soundCount>0
    and SAO.Perception.nearestBelievedZombie('runner',18000,0,0)==nil)

-- Fixed physiology, dispositions and native offers; only acquired private awareness differs.
local function choice(aware,near)
    local a,b,t=fresh(aware and {entry('turned',true)} or {})
    SAO.Disposition.conflictValues=function(id)return {actorId=id,selfPreservation=.3,aggression=.3,nerve=.5,discipline=.8,compassion=.3} end
    SAO.Disposition.fear=function()return 0 end
    F.offers(near and '' or 'MOVE\t1\t0\t0',near and 'AVAILABLE\tshove\t1\t1.5' or 'AVAILABLE\tranged\t5.5\t20')
    if near then t.dist=1;t.x=-.5 end
    check('actual_conflict_dispatch',F.decide(a,b,t))
    return SAO.ProceduralPlanning.conflictSnapshot('runner'),a
end
local defended,defender=choice(false,true)
check('naive_still_physically_defends',defended.kind=='defend' and defender.conflictCombat~=nil)
local naive,naiveAgent=choice(false,false)
local aware,awareAgent=choice(true,false)
check('private_awareness_changes_actual_shared_choice',naive.kind~=aware.kind and naive.kind=='defend' and aware.kind=='engage')
local found=false
for _,row in ipairs(naive.alternatives or {}) do if row.id=='engage' then
    for _,objection in ipairs(row.objections or {}) do if objection=='unanswered' then found=true end end
end end
check('private_recognition_supplies_actual_objection',found)
__result='PASS personal awareness '..checks..' checks; inherited '..__awarenessInherited
