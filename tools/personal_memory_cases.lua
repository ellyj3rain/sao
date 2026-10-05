local checks=0
local function check(name,value)
    if not value then error('PERSONAL_MEMORY:'..name) end
    checks=checks+1
end
local function clone(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=clone(x) end;return out
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local records,receipts,now,readiness,ages={},{},2,{},{}
local calendarStartDay0,calendarBehind=8,0
local digest=string.rep('a',64)
SAO.Identity={get=function(id)return records[id]end}
-- The actual History calendar reader and actual compiled SAORecord date
-- arithmetic execute. The bridge's native start/behind receivers are controlled.
SAO.History.countyHours=function()return now end
SAO.History.ageOf=function(id)return ages[id] or 34 end
SAOJavaBridge={countyInstant=function(_,hours)
    return __countyCalendar(1993,6,calendarStartDay0,hours,calendarBehind)
end}
SAO.PopulationAdmissions={}
MoodleType={TIRED='tired',DRUNK='drunk',PAIN='pain'}
SAO.Body={get=function(id)
    return {getMoodles=function()return {getMoodleLevel=function(_,kind)return readiness[id] and readiness[id][kind] or 0 end}end}
end}
local function reader(rec)return receipts[rec.id]end
local function episode(id)
    return {id=id or 'outing-1',ownerId='person-a',occurredOn='1992-06-20',acquiredOn='1992-06-20',
        participants={'historical-friend'},subject='leisure',action='reading',description='Read with a friend after work.',
        valence=.8,salience=.75,sourceId='authored-history:fixture',sourceSha256=digest,provenance='authored-synthetic',
        relations={{from='reading',relation='supports',into='comfort',confidence=.7}}}
end
local function initial(episodes,id)
    return {schema='sao-personal-memory-initial/1',personId=id or 'person-a',issuerId='initial-cohort:'..digest,
        sourceId='study-definition:'..digest,sourceSha256=digest,definitionSha256=digest,worldId=digest,
        saveId='save-fixture',admissionKey=digest..':'..(id or 'person-a')..':1',admittedAtHours=2,
        startDate='1993-07-09',cutoffDate='1993-07-09',birthYear=1960,episodes=episodes or {episode()}}
end
local function fresh(episodes,id)
    id=id or 'person-a';now=2;calendarStartDay0=8;calendarBehind=0
    readiness[id]=nil;ages[id]=34;SAO.Conditions.assert(id,{})
    local rec={id=id,birthYear=1960};records[id]=rec;receipts[id]=initial(episodes,id)
    return rec
end
local function attach(episodes)
    local rec=fresh(episodes)
    check('valid_initial_attaches',SAO.PersonalMemory.attachInitial(rec))
    return rec
end
local function query(id,cue)return SAO.PersonalMemory.query(id or 'person-a',cue)end
check('foreign_issuer_cannot_bind',not SAO.PersonalMemory.bindInitialProvider({},reader))
check('canonical_issuer_binds',SAO.PersonalMemory.bindInitialProvider(SAO.PopulationAdmissions,reader))
check('issuer_cannot_replace_reader',not SAO.PersonalMemory.bindInitialProvider(SAO.PopulationAdmissions,reader))
local rec=fresh();receipts[rec.id]=nil
check('unconfigured_is_explicit',SAO.PersonalMemory.attachInitial(rec) and query().status=='unconfigured')
check('unconfigured_read_is_pure',rec.personalMemory==nil and query().retainedCount==0)
rec=fresh()
check('pending_source_is_unavailable',query().status=='unavailable' and rec.personalMemory==nil)
check('foreign_record_refused',not SAO.PersonalMemory.attachInitial({id=rec.id}))
rec=attach({})
check('empty_differs_from_unconfigured',query().status=='empty' and query().configured)
rec=attach();local state=rec.personalMemory;local before=clone(state)
local first=query()
check('pure_query_preserves_actual_history',equal(state,before) and first.episodes[1].acquiredOn=='1992-06-20')
check('generic_dated_episode_recalled',first.status=='available' and first.episodes[1].subject=='leisure')
check('attachment_history_not_current_assent',query().episodes[1].valence==.8 and query().episodes[1].assent=='not-established'
    and rec.relationships==nil and rec.skills==nil)
local snapshot=SAO.PersonalMemory.snapshot(rec.id);snapshot.initial.episodes[1].description='tampered'
local view=query();view.episodes[1].participants[1]='tampered';view.episodes[1].relations[1].confidence=0
check('snapshot_and_recall_detached',state.initial.episodes[1].description=='Read with a friend after work.'
    and query().episodes[1].participants[1]=='historical-friend' and query().episodes[1].relations[1].confidence==.7)
check('exact_once_source_admission',SAO.PersonalMemory.attachInitial(rec) and rec.personalMemory==state and #state.initial.episodes==1)
receipts[rec.id].episodes[1].description='replacement'
check('historical_source_never_replaced',not SAO.PersonalMemory.attachInitial(rec) and rec.personalMemory==state)
check('rebound_source_query_withheld',query().status=='unavailable' and #query().episodes==0)
receipts[rec.id]=clone(state.initial)
check('restored_custody_recalls_original',query().episodes[1].description=='Read with a friend after work.')
receipts[rec.id].saveId='foreign-save'
check('foreign_save_withheld',query().status=='unavailable')
receipts[rec.id]=clone(state.initial);receipts[rec.id].worldId=string.rep('b',64)
check('foreign_world_refused',query().status=='unavailable')
receipts[rec.id]=clone(state.initial);receipts[rec.id].sourceSha256=string.rep('b',64)
check('source_digest_mismatch_withheld',query().status=='unavailable')
receipts[rec.id]=clone(state.initial)
rec.personalMemory.actorId='person-b'
check('foreign_saved_state_refused',query().status=='unavailable')
rec.personalMemory.actorId=rec.id
local other=fresh({},'person-b');check('other_empty_source_attaches',SAO.PersonalMemory.attachInitial(other))
check('foreign_person_cannot_gain_episode',query('person-b').status=='empty' and #query('person-b').episodes==0)
check('missing_person_not_empty',query('missing').status=='unavailable')
local dates={
    {'invalid_gregorian_leap','1991-02-29',false},
    {'valid_gregorian_leap','1992-02-29',true},
    {'invalid_century_leap','1900-02-29',false},
    {'valid_century_leap','1600-02-29',true},
    {'invalid_month','1992-13-01',false},
    {'invalid_month_day','1992-04-31',false},
    {'invalid_zero_day','1992-06-00',false},
    {'invalid_date_format','1992-6-20',false},
    {'future_episode_refused','1993-07-10',false},
    {'prebirth_episode_refused','1959-12-31',false},
}
for _,case in ipairs(dates) do
    rec=fresh();local e=receipts[rec.id].episodes[1]
    e.occurredOn=case[2];e.acquiredOn=case[2]
    if case[1]=='valid_century_leap' then rec.birthYear=1500;receipts[rec.id].birthYear=1500 end
    if case[1]=='invalid_century_leap' then rec.birthYear=1800;receipts[rec.id].birthYear=1800 end
    local result=SAO.PersonalMemory.attachInitial(rec)
    check(case[1],result==case[3] and (result or rec.personalMemory==nil))
end
local invalid={
    {'acquisition_before_occurrence',function(v)v.episodes[1].acquiredOn='1991-06-20'end},
    {'future_acquisition_refused',function(v)v.episodes[1].acquiredOn='1993-07-10'end},
    {'future_initial_refused',function(v)v.admittedAtHours=3 end},
    {'future_start_calendar_refused',function(v)v.startDate='1994-01-01';v.cutoffDate=v.startDate end},
    {'invalid_cutoff_calendar_refused',function(v)v.cutoffDate='1993-07-10'end},
    {'registered_birth_mismatch_refused',function(v)v.birthYear=1961 end},
    {'foreign_episode_owner_refused',function(v)v.episodes[1].ownerId='person-b'end},
    {'duplicate_episode_refused',function(v)v.episodes[2]=clone(v.episodes[1])end},
    {'sparse_episode_array_refused',function(v)v.episodes[3]=clone(v.episodes[1])end},
    {'duplicate_participant_refused',function(v)v.episodes[1].participants[2]='historical-friend'end},
    {'unknown_provenance_refused',function(v)v.episodes[1].provenance='objective-world'end},
    {'unknown_field_refused',function(v)v.episodes[1].diagnosis='test'end},
    {'unsupported_relation_refused',function(v)v.episodes[1].relations[1].relation='confirms-local-fact'end},
    {'nonfinite_salience_refused',function(v)v.episodes[1].salience=0/0 end},
    {'relation_overconfidence_refused',function(v)v.episodes[1].relations[1].confidence=1.1 end},
    {'invalid_hash_refused',function(v)v.episodes[1].sourceSha256='bad'end},
    {'initial_source_digest_mismatch_refused',function(v)v.sourceSha256=string.rep('b',64)end},
    {'unicode_hash_lookalike_refused',function(v)v.episodes[1].sourceSha256=string.rep(string.char(353),64)end},
    {'unicode_concept_lookalike_refused',function(v)v.episodes[1].subject=string.char(353)end},
    {'text_control_refused',function(v)v.episodes[1].description='read'..string.char(0)..'note'end},
    {'duplicate_relation_refused',function(v)v.episodes[1].relations[2]=clone(v.episodes[1].relations[1])end},
    {'too_many_participants_refused',function(v)for i=1,17 do v.episodes[1].participants[i]='historical-person-'..i end end},
    {'too_many_relations_refused',function(v)for i=1,17 do v.episodes[1].relations[i]={from='reading-'..i,relation='supports',into='comfort',confidence=.7}end end},
    {'cycle_refused',function(v)v.episodes[1].description=v.episodes[1]end},
}
for _,case in ipairs(invalid) do
    rec=fresh();case[2](receipts[rec.id])
    check(case[1],not SAO.PersonalMemory.attachInitial(rec) and rec.personalMemory==nil)
end
rec=fresh();receipts[rec.id].episodes={}
for i=1,64 do receipts[rec.id].episodes[i]=episode('episode-'..i) end
check('bounded_64_episodes_admitted',SAO.PersonalMemory.attachInitial(rec) and query().retainedCount==64)
rec=fresh();receipts[rec.id].episodes={}
for i=1,64 do
    local e=episode('episode-'..i);e.relations={}
    for j=1,16 do e.relations[j]={from='reading-'..j,relation='supports',into='comfort',confidence=.7}end
    receipts[rec.id].episodes[i]=e
end
check('max_relational_source_attaches',SAO.PersonalMemory.attachInitial(rec))
local boundedEdges,boundedStatus,omittedEdges=SAO.PersonalMemory.relations(rec.id)
check('exact_source_relation_omissions',#boundedEdges==64 and boundedStatus=='truncated' and omittedEdges==960)
rec=fresh();receipts[rec.id].episodes={}
for i=1,65 do receipts[rec.id].episodes[i]=episode('episode-'..i) end
check('episode_overflow_refused',not SAO.PersonalMemory.attachInitial(rec))
check('pure_public_validation_refuses_invalid_calendar',not SAO.PersonalMemory.validStartDate('1994-01-01')
    and not SAO.PersonalMemory.validStartDate('1993-02-29') and SAO.PersonalMemory.validStartDate('1992-02-29'))
rec=fresh()
check('public_validation_does_not_attach',SAO.PersonalMemory.validateInitial(receipts[rec.id],rec,now)
    and rec.personalMemory==nil and not SAO.PersonalMemory.validateInitial(receipts[rec.id],rec,nil))
local astral=string.char(55357,56832)
rec=fresh();receipts[rec.id].episodes[1].description=string.rep(astral,1024)
check('kahlua_astral_utf16_length',#astral==2 and string.byte(astral,1)==55357 and string.byte(astral,2)==56832)
check('astral_description_exact_boundary',SAO.PersonalMemory.attachInitial(rec))
rec=fresh();receipts[rec.id].episodes[1].description=string.rep(astral,1025)
check('astral_description_overflow_refused',not SAO.PersonalMemory.attachInitial(rec))
rec=attach();state=clone(rec.personalMemory)
local edges,status=SAO.PersonalMemory.relations(rec.id)
check('modal_relations_preserve_provenance',status=='available' and #edges==1 and edges[1].modal==true
    and edges[1].actorId==rec.id and edges[1].basis=='autobiographical-association'
    and edges[1].episodeId=='outing-1' and edges[1].sourceSha256==digest
    and edges[1].occurredOn=='1992-06-20' and edges[1].acquiredAt==2 and edges[1].mastery=='unassessed')
edges[1].from='tampered';check('relations_are_detached',SAO.PersonalMemory.relations(rec.id)[1].from=='reading')
check('candidate_linked_subject_recall',#query(rec.id,'leisure').episodes==1)
check('candidate_linked_relational_recall',#query(rec.id,'comfort').episodes==1)
check('unrelated_candidate_is_empty',query(rec.id,'other').status=='empty' and query().retainedCount==1)
check('invalid_cue_unavailable',query(rec.id,{}).status=='unavailable')
local healthy=query().episodes[1]
check('existing_conditions_owns_retention',query().retentionSource=='conditions' and query().retentionFactor==1)
SAO.Conditions.assert(rec.id,{dementia=true})
local memoryCondition=query()
check('health_condition_changes_retained_evidence',memoryCondition.retentionFactor==.5
    and memoryCondition.episodes[1].retainedStrength<healthy.retainedStrength)
check('health_condition_does_not_rewrite_history',equal(rec.personalMemory,state))
SAO.Conditions.assert(rec.id,{})
ages[rec.id]=75
check('existing_age_memory_projection_composes',query().retentionFactor==.8 and query().episodes[1].retainedStrength<healthy.retainedStrength)
ages[rec.id]=34;SAO.Conditions.assert(rec.id,{dyslexia=true,ptsd=true})
check('other_health_traits_do_not_invent_autobiographical_impairment',query().retentionFactor==1)
SAO.Conditions.assert(rec.id,{})
local conditions=SAO.Conditions;SAO.Conditions=nil
check('absent_conditions_uses_explicit_neuro_fallback',query().retentionSource=='neuro' and query().retentionFactor==1)
SAO.Conditions={memoryFactor=function()return 0/0 end}
check('invalid_retention_owner_is_unavailable',query().status=='unavailable')
SAO.Conditions=conditions
now=26;local aged=query().episodes[1]
check('county_elapsed_days_affect_recall',aged.ageDays==healthy.ageDays+1 and aged.retainedStrength<healthy.retainedStrength)
now=2
rec.neuroinflammation=.8;SAO.Neuro.observe(rec,now,'fixture-existing-brain-input')
local impaired=query().episodes[1]
check('actual_neuro_projection_affects_evidence',impaired and impaired.accessibility<healthy.accessibility
    and impaired.retainedStrength<healthy.retainedStrength and query().clarity<.21)
check('recall_does_not_mutate_neuro_or_history',equal(rec.personalMemory,state) and rec.brainHealth.atHours==now)
SAO.Neuro.observe(rec,now+240,'fixture-clearance',{wound=false,toxin=0,withdrawal=false,clearance=1})
now=242;local recovered=query().episodes[1]
check('neuro_clearance_restores_accessibility',recovered and recovered.accessibility>impaired.accessibility)
rec=attach();rec.brainHealth=nil;ZAO={StateStore={read=function()return {terminalState='crossed'}end}}
local crossed=query();local crossedEdges=SAO.PersonalMemory.relations(rec.id)
check('crossed_retains_prior_person_episode',crossed.status=='available' and #crossed.episodes==1 and #crossedEdges==1
    and crossed.clarity>.09 and crossed.clarity<.11 and crossed.episodes[1].accessibility<.1)
ZAO=nil
readiness[rec.id]={tired=4}
check('zero_native_readiness_withholds_recall',query().status=='inaccessible' and #query().episodes==0)
check('zero_readiness_retains_original_evidence',SAO.PersonalMemory.snapshot(rec.id).initial.episodes[1].valence==.8)
readiness[rec.id]=nil
check('readiness_recovery_recalls_same_source',query().episodes[1].id=='outing-1')
rec=attach();receipts[rec.id].episodes[1].salience=0;rec.personalMemory=nil
check('low_salience_source_attaches',SAO.PersonalMemory.attachInitial(rec))
now=24*365*20
local oldRecall=query()
check('deterministic_aging_limits_recall',oldRecall.status=='inaccessible' and oldRecall.retainedCount==1)
local kept=SAO.PersonalMemory.snapshot(rec.id)
check('aging_keeps_history',kept and kept.initial.episodes[1].id=='outing-1'
    and kept.initial.episodes[1].valence==.8)
rec=attach();local retained=__nativeRoundtrip(rec.personalMemory);rec.personalMemory=retained
check('native_roundtrip_preserves_history',SAO.PersonalMemory.attachInitial(rec) and query().episodes[1].id=='outing-1'
    and rec.personalMemory==retained)
-- A July 20 start owes eleven county days. County hour zero is July 9.
rec=fresh();now=0;calendarStartDay0=19;calendarBehind=11
local staged=receipts[rec.id];staged.startDate='1993-07-20';staged.cutoffDate=staged.startDate;staged.admittedAtHours=0
staged.episodes[1].occurredOn='1993-07-18';staged.episodes[1].acquiredOn='1993-07-18'
check('future_to_replay_source_stages_without_recall',SAO.PersonalMemory.attachInitial(rec))
local early=query()
check('catchup_no_future_knowledge',early.currentInstant=='1993-07-09T00:00:00'
    and early.status=='not-yet-acquired' and #early.episodes==0 and early.notYetAcquiredCount==1 and early.inaccessibleCount==0)
local noEdges,noEdgeStatus,noOmitted=SAO.PersonalMemory.relations(rec.id)
check('future_acquisition_grants_no_relational_premise',#noEdges==0 and noEdgeStatus=='not-yet-acquired' and noOmitted==0)
check('future_acquisition_keeps_staged_source',SAO.PersonalMemory.snapshot(rec.id).initial.episodes[1].acquiredOn=='1993-07-18')
now=216;local acquired=query()
check('acquisition_activates_on_owned_calendar',acquired.currentInstant=='1993-07-18T00:00:00'
    and acquired.status=='available' and acquired.notYetAcquiredCount==0 and acquired.episodes[1].ageDays==0)
now=264;local atStart=query()
check('native_start_has_no_duplicate_history_offset',atStart.currentInstant=='1993-07-20T00:00:00'
    and atStart.episodes[1].ageDays==2)
rec.personalMemory=nil;staged.admittedAtHours=240;now=240
check('later_admission_attaches_same_dated_source',SAO.PersonalMemory.attachInitial(rec))
check('admission_time_does_not_reset_episode_age',query().episodes[1].ageDays==1)
local calendarReader=SAOJavaBridge.countyInstant
for _,bad in ipairs({'','1993-02-30T12:00:00','1993-07-18T24:00:00','1993-07-18T12:60:00','1993-07-18T12:00:60','not-a-date'}) do
    SAOJavaBridge.countyInstant=function()return bad end
    check('invalid_calendar_withholds_configured_recall',query().status=='unavailable' and query().reason=='memory-calendar-unavailable')
end
SAOJavaBridge.countyInstant=function()return nil end
check('missing_calendar_withholds_configured_recall',query().status=='unavailable')
SAOJavaBridge.countyInstant=calendarReader
check('calendar_restoration_preserves_same_history',query().episodes[1].id=='outing-1')
rec=attach()
__memoryFixture={check=check,reader=reader,rec=rec,receipts=receipts,
    result=function()return 'PASS personal memory: '..checks..' checks'end}
__result=__memoryFixture.result()
