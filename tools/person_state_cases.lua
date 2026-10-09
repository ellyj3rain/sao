local checks=0
local function verify(name,value)if not value then error("PERSON_STATE:"..name)end;checks=checks+1 end
local function copy(v)if type(v)~="table"then return v end;local out={}for k,x in pairs(v)do out[k]=copy(x)end return out end
local function equal(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local now,startYear,startDay,behind=0,1993,19,11
local rec,body,level,missingMoodles,source,awarenessSource
local digest=string.rep("a",64)
SAO.Identity={get=function(id)return id=="person-a" and rec or nil end}
SAO.History.countyHours=function()return now end
SAO.History.ageOf=function()return 33 end
GameTime={getInstance=function()return {getStartYear=function()return 1993 end}end}
SAO.Body={active={},foreign={},get=function(id)return id=="person-a" and body or nil end}
MoodleType={TIRED="tired",DRUNK="drunk",PAIN="pain"}
SAOJavaBridge={countyInstant=function(_,hours)return __countyCalendar(startYear,6,startDay,hours,behind)end,
    isShell=function()return true end,socialState=function()return "i=0;p=0;s=0.2;a=0;m=0.5"end,
    getNeeds=function()return "h=0.1;t=0.1;f=0.1;e=0.9;n=0"end}
SAO.PopulationAdmissions={}
verify("memory_provider",SAO.PersonalMemory.bindInitialProvider(SAO.PopulationAdmissions,function(r)return source end))
verify("awareness_provider",SAO.PersonalAwareness.bindInitialProvider(SAO.PopulationAdmissions,function(r)return awarenessSource end))
local function fresh()
    now=0;startYear=1993;startDay=19;behind=11;level=0;missingMoodles=false;ZAO=nil
    rec={id="person-a",birthYear=1960,bodyOwnerToken="fixture-body",traitEchoes={initiative=.1}}
    body={getModData=function()return {SAOPersonId=rec.id,SAOExternalToken=rec.bodyOwnerToken,
        SAOExternalOwner=rec.bodyOwner,ZAOOwned=rec.bodyOwner=="ZAO"}end,
        getMoodles=function()if missingMoodles then error("native moodles absent")end
            return {getMoodleLevel=function()return level end}end,
        isDead=function()return false end,isExistInTheWorld=function()return true end,
        getVehicle=function()return nil end,getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 1 end}
    SAO.Body.active={['person-a']=body};SAO.Body.foreign={}
    SAO.Controller.agents={['person-a']={rec=rec,state="IDLE"}}
    SAO.Conditions.assert(rec.id,{depression=true,anxiety=true})
    source={schema="sao-personal-memory-initial/1",personId=rec.id,issuerId="initial-cohort:"..digest,
        sourceId="study-definition:"..digest,sourceSha256=digest,definitionSha256=digest,worldId=digest,saveId="save-fixture",
        admissionKey=digest..":"..rec.id..":1",admittedAtHours=0,startDate="1993-07-20",cutoffDate="1993-07-20",birthYear=1960,
        episodes={{id="reading-with-friend",ownerId=rec.id,occurredOn="1993-07-08",acquiredOn="1993-07-08",
            participants={"historical-friend"},subject="leisure",action="reading",description="Read with a friend after work.",
            valence=.8,salience=.75,sourceId="authored-history:fixture",sourceSha256=digest,provenance="authored-synthetic",
            relations={{from="reading",relation="supports",into="comfort",confidence=.7}}}}}
    awarenessSource={schema="sao-personal-awareness-initial/1",personId=rec.id,issuerId="fixture:admissions",
        sourceId="fixture:definition",admissionKey="fixture:person-a",admittedAtHours=0,
        entries={{id="outbreak-account",kind="outbreak",affirmed=true,sourceId="authored-report:fixture",
            sourceAtHours=0,receivedAtHours=0,certainty="reported"}}}
    verify("memory_attached",SAO.PersonalMemory.attachInitial(rec))
    verify("awareness_attached",SAO.PersonalAwareness.attachInitial(rec))
    SAO.Perception.beliefs={}
    SAOJavaBridge.conceptObservations=function()return {schema="sao.concept-observation/1",actorId=rec.id,
        observations={{key="room:A",concept="room",kind="room",buildingId="house:A",roomId="room:A",x=0,y=0,z=1}},
        frontiers={{key="door:A",kind="doorway",buildingId="house:A",roomId="room:A",x=1,y=0,z=1,
            entryX=2,entryY=0,entryZ=1,state="closed"}}}end
    verify("native_concept_observation",SAO.Perception.observeConcepts(rec.id,body,SAO.History.ticks()))
    SAO.Neuro.observeBody(rec,body,now,"controlled-native-body-observation")
end
local function query()return SAO.PersonState.query(rec.id,body,SAO.History.ticks())end
fresh()
rec.weekOne={sourceEvent={kind="reinforcement",source="VBandit.schedule/SpawnGroup",
    cohort="fixture-cohort",age=87,minute=33,variantId=2,count=5,
    brainId=7,born=12.5}}
local baseline=copy(rec)
local value=query()
verify("actual_export_available",value.schema=="sao-person-state/1" and value.status=="available")
verify("actual_current_calendar",value.currentInstant=="1993-07-09T00:00:00" and value.modelView.currentInstant==value.currentInstant
    and value.atTick==SAO.History.ticks() and value.atHours==0)
verify("year_precision_not_birthday",value.modelView.age.nominalAge==33 and value.modelView.age.minimumAge==32
    and value.modelView.age.birthdayKnown==false and value.modelView.age.precision=="birth-year")
local axes={"nerve","discipline","aggression","initiative","selfPreservation","compassion","appetite","talkativeness"}
local actual=SAO.Disposition.traits(rec.id);local axisCount=0
for k,v in pairs(value.modelView.effectiveTraits)do axisCount=axisCount+1 end
verify("actual_eight_traits",axisCount==8)
for _,axis in ipairs(axes)do verify("owned_trait_"..axis,value.modelView.effectiveTraits[axis]==actual[axis])end
verify("audit_has_health_contributions",value.audit.traitEvidence.initiative.condition==-.15
    and value.audit.traitEvidence.nerve.condition==-.1)
verify("weekone_source_provenance_export",type(value.audit.weekOneSource)=="table"
    and value.audit.weekOneSource.cohort=="fixture-cohort"
    and value.modelView.weekOneSource==nil)
value.audit.weekOneSource.cohort="tampered"
verify("weekone_source_provenance_detached",rec.weekOne.sourceEvent.cohort=="fixture-cohort")
verify("model_view_omits_diagnoses",value.modelView.traitEvidence==nil and value.modelView.conditions==nil
    and value.modelView.situation.psychology==nil and value.audit.rawSituation.psychology~=nil)
verify("native_temper_kept_without_health_labels",value.modelView.affect.temperStatus=="native"
    and value.modelView.affect.temper.stress==.2 and value.modelView.affect.temper.morale==.5)
verify("actual_readiness_metadata",value.modelView.cognition.status=="available" and value.modelView.cognition.source=="native-moodles"
    and value.modelView.cognition.attention==1 and value.modelView.cognition.motor==1
    and value.modelView.cognition.brainProjection.source=="event-derived-brain-state"
    and value.modelView.cognition.brainProjection.observedAtHours==0)
verify("source_owned_recall",value.modelView.recall.status=="available" and value.modelView.recall.episodes[1].ageDays==1
    and value.modelView.recall.retentionMetadata.status=="available" and value.modelView.recall.retentionMetadata.ageProjection.nominalAge==33)
verify("actual_situation_schema",value.modelView.situation.schema=="sao-situation-appraisal/1"
    and value.modelView.situation.questions[1].interpretation=="reported"
    and value.modelView.situation.questions[1].evidence[1].sourceId=="authored-report:fixture")
verify("pure_export",equal(rec,baseline))
value.modelView.effectiveTraits.initiative=99;value.modelView.recall.episodes[1].valence=-1
value.audit.retainedMemory.initial.episodes[1].description="tampered"
verify("detached_model_and_audit",query().modelView.effectiveTraits.initiative==actual.initiative
    and query().modelView.recall.episodes[1].valence==.8 and rec.personalMemory.initial.episodes[1].description=="Read with a friend after work.")
fresh();missingMoodles=true
local unknown=query()
verify("missing_health_not_healthy",unknown.status=="unavailable" and unknown.modelView.cognition.status=="unavailable"
    and unknown.modelView.cognition.clarity==nil and unknown.modelView.cognition.reason=="moodles-unavailable")
fresh();rec.brainHealth=nil
verify("missing_brain_history_not_healthy",query().status=="unavailable" and query().modelView.cognition.reason=="brain-observation-unavailable"
    and query().modelView.cognition.clarity==nil and query().modelView.situation.clarity==nil)
fresh();rec.brainHealth.history[#rec.brainHealth.history].atHours=1
verify("future_brain_history_refused",query().status=="unavailable" and query().modelView.cognition.reason=="brain-history-unavailable")
fresh();SandboxVars.SurvivorAwareness.Neuroinflammation=false
verify("disabled_brain_model_explicit",query().status=="unavailable" and query().modelView.cognition.reason=="brain-model-disabled")
SandboxVars.SurvivorAwareness.Neuroinflammation=true
fresh();level=9
verify("invalid_native_health_refused",query().status=="unavailable" and query().modelView.cognition.reason=="moodles-invalid")
fresh();level=0/0
verify("nan_native_health_refused",query().status=="unavailable" and query().modelView.cognition.clarity==nil)
fresh();level=4
verify("known_impairment_is_observed",query().status=="available" and query().modelView.cognition.clarity==0
    and query().modelView.recall.status=="inaccessible" and query().modelView.situation.status=="inaccessible")
fresh();SAO.Body.active={}
verify("missing_active_custody_refused",query().status=="unavailable" and query().modelView.body.status=="unavailable")
fresh();SAO.Body.foreign[rec.id]=body
verify("ambiguous_body_custody_refused",query().status=="unavailable")
fresh();local oldBody=body;body=copy(body)
verify("foreign_body_refused",query().status=="unavailable")
body=oldBody
fresh();rec.dead=true
verify("dead_custody_refused",query().status=="unavailable")
fresh();rec.bodyOwner="ZAO";SAO.Body.active={};SAO.Body.foreign[rec.id]=body
ZAO={Controller={controlled={}},StateStore={read=function()return {terminalState="crossed"}end}}
verify("foreign_controller_binding_refused",query().status=="unavailable")
ZAO.Controller.controlled[rec.id]=body
SAO.Neuro.observeBody(rec,body,now,"controlled-owned-crossed-observation")
verify("owned_crossed_retains_person",query().status=="available" and query().modelView.cognition.clarity>.09
    and query().modelView.cognition.clarity<.11 and #query().modelView.recall.episodes==1)
fresh()
verify("future_query_clock_refused",SAO.PersonState.query(rec.id,body,SAO.History.ticks()+1).status=="unavailable")
verify("foreign_person_refused",SAO.PersonState.query("other",body,SAO.History.ticks()).status=="unavailable")
fresh();now=264
verify("calendar_catchup_not_admission_offset",query().currentInstant=="1993-07-20T00:00:00" and query().modelView.recall.episodes[1].ageDays==12)
fresh();local nativeCalendar=SAOJavaBridge.countyInstant;SAOJavaBridge.countyInstant=function()return "1993-02-30T00:00:00"end
verify("malformed_calendar_refused",query().status=="unavailable" and query().reason=="calendar-age-unavailable")
SAOJavaBridge.countyInstant=nativeCalendar
fresh();local memoryFactor=SAO.Conditions.memoryFactor
SAO.Conditions.memoryFactor=function()return .5,{status="unavailable",reason="missing-calendar-age"}end
verify("unavailable_recall_metadata_refused",query().modelView.recall.status=="unavailable"
    and #query().modelView.recall.episodes==0 and query().modelView.recall.reason=="memory-age-projection-unavailable")
SAO.Conditions.memoryFactor=memoryFactor
fresh();local readiness=SAO.Neuro.physicalReadiness
SAO.Neuro.physicalReadiness=function()return nil,1,{status="available",source="native-moodles"}end
verify("malformed_attention_refused",query().modelView.cognition.status=="unavailable")
SAO.Neuro.physicalReadiness=function()return 1,2,{status="available",source="native-moodles"}end
verify("out_of_range_motor_refused",query().modelView.cognition.status=="unavailable")
SAO.Neuro.physicalReadiness=readiness
fresh();local traitsOwner=SAO.Disposition.traits
SAO.Disposition.traits=function(id)local t=traitsOwner(id);t.nerve=2;return t end
verify("malformed_owned_traits_refused",query().status=="unavailable" and query().reason=="traits-unavailable")
SAO.Disposition.traits=traitsOwner
fresh()
rec.personalMemory=__nativeRoundtrip(rec.personalMemory)
verify("native_reload_keeps_exported_evidence",query().modelView.recall.episodes[1].id=="reading-with-friend")
verify("actual_fixture_emitted",__emitPersonState({context={personState=query()}}))
__result="PASS person state: "..checks.." checks"
