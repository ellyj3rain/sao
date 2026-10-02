local C,M=SAO.Cognition,SAO.CognitiveModels
local n=0
local function check(name,ok) if not ok then error("EXTENDED:"..name) end n=n+1 end
local function copy(v)
 if type(v)~="table" then return v end
 local out={} for k,x in pairs(v) do out[k]=copy(x) end return out
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end return true
end
local function forbidden(v)
 if type(v)~="table" then return false end
 for k,x in pairs(v) do
  if k=="family" or k=="exposures" or k=="profile" or k=="doseSequence" or k=="efficacy"
    or k=="nativeCredit" or k=="shutdown" then return true end
  if forbidden(x) then return true end
 end return false
end
local function frame(id)
 return {id="frame/"..tostring(hours),actorId=id,worldHours=hours,hunger=.8,thirst=.1,
 fatigue=.1,eatAt=.5,drinkAt=.5,foodAllowed=true,waterAllowed=true,inspectionAllowed=true,
 knownFood=1,knownWater=1,knownPlaces=1,capabilities={cook=true,forage=false,treat=true}}
end
local function dose(id,seq)
 return {actorId=id,sequence=seq,itemId=-12,itemType="Base.Pills",atHours=hours,
 status="completed",consumed=1,family="secret-family",profile={efficacy=1}}
end
local function physical(minute,stats)
 return {kind="physical-change",minute=minute,atHours=minute/60,observedAtHours=hours,
 stats=stats or {PAIN={before=50,after=20},THIRST={before=.6,after=.4}},
 exposures={hiddenFamily=17},family="secret-family",doseSequence=17}
end
local function preparation(id,seq)
 return {id="cooking/"..id.."/"..seq,actorId=id,sequence=seq,itemId=123,itemType="Base.Chicken",
 sourceId="C:fixture:0",startedAt=hours-.2,atHours=hours,status="completed",
 detail="native-food-cooked-and-retrieved",beforeCookingTime=0,afterCookingTime=45,
 heatObserved=true,nativeCredit="cooking/"..id.."/"..seq,retrieved=true,shutdown="off"}
end
local function state(id) return records[id].cognition end
local function last(id) local s=state(id) return s.experiences[#s.experiences] end
local function count(t) local result=0 for _ in pairs(t) do result=result+1 end return result end
local function noGoalCredit(id)
 for _,name in ipairs({"ordinary","associative"}) do
  local s=state(id).models[name]
  for _,action in ipairs({"food","water","inspect","continue"}) do
   if s.beliefs["goal:"..action]~=nil then return false end
  end
 end return true
end

-- Existing durable state comes from the real old module, not a guessed schema.
hours=20
records.invalid={id="invalid"}
local malformed=dose("invalid",1);malformed.itemId=nil
check("invalid_callback_does_not_allocate",not C.medicationUse("invalid",malformed) and records.invalid.cognition==nil)
local legacyBefore=copy(state("legacy"))
local p=M.propose("ordinary",state("legacy").models.ordinary,frame("legacy"))
check("legacy_read_supported",p and p.version=="sao-ordinary/2")
M.summary("associative",state("legacy").models.associative,hours)
check("legacy_reads_inert",equal(legacyBefore,state("legacy")))
check("legacy_event_admitted",C.medicationUse("legacy",dose("legacy",1)))
check("legacy_observation_migrates",state("legacy").models.ordinary.version=="sao-ordinary/2"
 and state("legacy").models.associative.version=="sao-associative/2"
 and state("legacy").models.ordinary.migratedFrom=="sao-ordinary/1")
check("legacy_beliefs_preserved",state("legacy").models.ordinary.beliefs["goal:food"].id
 ==legacyBefore.models.ordinary.beliefs["goal:food"].id
 and state("legacy").models.ordinary.beliefs["goal:food"].support==1)
check("frozen_provenance_preserved",equal(state("legacy").episodes,legacyBefore.episodes)
 and state("legacy").episodes[1].proposals[1].version=="sao-ordinary/1")

local action,episode=C.choose("a",frame("a"));assert(action=="food" and episode)
local frozen=copy(state("a").episodes[1]);local use=dose("a",1)
check("medication_completed",C.medicationUse("a",use))
check("medication_private_projection",not forbidden(last("a")) and last("a").kind=="medication-use"
 and last("a").itemId==-12 and last("a").itemType=="Base.Pills")
check("independent_medication_memory",state("a").models.ordinary.beliefs["direct:medication-use:Base.Pills"]
 and state("a").models.associative.beliefs["relation:convey:medicine:Base.Pills:body"]
 and not state("a").models.ordinary.beliefs["relation:convey:medicine:Base.Pills:body"])
local onlyUseAndContext,observedUse=true,false
for _,h in ipairs(state("a").models.associative.hypotheses) do
 if h.depth==1 then
  if h.relation=="convey" and h.from=="medicine:Base.Pills" and h.into=="body" then observedUse=true
  else onlyUseAndContext=false end
 elseif h.status~="hypothesis" or not string.find(h.key,"/context:",1,true)
  or #h.evidenceIds~=1 or #h.missing==0 then onlyUseAndContext=false end
end
check("dose_is_not_efficacy",noGoalCredit("a") and observedUse and onlyUseAndContext)
check("dose_does_not_settle_episode",equal(frozen,state("a").episodes[1]))
local before=copy(state("a"));hours=20.1
check("dose_repeat_is_inert",C.medicationUse("a",use) and equal(before,state("a")))
local altered=copy(use);altered.itemId=123
check("dose_conflict_rejected",not C.medicationUse("a",altered) and state("a").models.ordinary.revision==1)
for _,field in ipairs({"consumed","status","itemId","itemType"}) do
 local bad=dose("a",2);bad[field]=nil
 check("dose_requires_actual_use_"..field,not C.medicationUse("a",bad))
end
local bad=dose("b",2)
check("dose_foreign_actor_rejected",not C.medicationUse("a",bad))
bad=dose("a",2);bad.consumed=.5
check("dose_fraction_not_completion",not C.medicationUse("a",bad))
bad=dose("a",2);bad.atHours=hours+1
check("dose_future_rejected",not C.medicationUse("a",bad))

local change=physical(60)
check("physical_change_admitted",C.physicalChange("a",change))
check("physical_acquisition_clock",last("a").worldHours==20.1 and last("a").occurredAtHours==1)
check("physical_private_projection",not forbidden(last("a")) and last("a").itemId==nil
 and last("a").itemType==nil and last("a").stats.PAIN.before==50 and last("a").stats.PAIN.after==20)
check("physical_no_goal_or_episode_credit",noGoalCredit("a") and equal(frozen,state("a").episodes[1]))
check("independent_felt_memory",state("a").models.ordinary.beliefs["direct:physical-change:PAIN:decrease"]
 and state("a").models.associative.beliefs["relation:vary:body:felt:PAIN:decrease"])
check("physical_receipts_age_at_acquisition",state("a").models.associative.beliefs["relation:vary:body:felt:PAIN:decrease"].samples[1].hours==20.1)
local hypothesis
for _,h in ipairs(state("a").models.associative.hypotheses) do
 if h.depth==2 and h.relation=="compose" and h.into=="felt:PAIN:decrease" then hypothesis=h end
end
check("separate_events_support_only_conjecture",hypothesis and hypothesis.status=="hypothesis"
 and hypothesis.confidence<.5 and #hypothesis.evidenceIds==2)
local causalGap=false
for _,gap in ipairs(hypothesis.missing) do if string.find(gap,"do not establish an ingestion's cause",1,true) then causalGap=true end end
check("causal_gap_explicit",causalGap)
local painId=state("a").models.associative.beliefs["relation:vary:body:felt:PAIN:decrease"].id
hours=20.2
check("reversal_admitted",C.physicalChange("a",physical(61,{PAIN={before=20,after=30}})))
local pain=state("a").models.associative.beliefs["relation:vary:body:felt:PAIN:decrease"]
check("reversal_refines_same_record",pain.id==painId and pain.against==1 and pain.support==1
 and state("a").models.ordinary.beliefs["direct:physical-change:PAIN:decrease"].against==1)
before=copy(state("a"));local repeatChange=physical(61,{PAIN={before=20,after=30}})
hours=20.3;repeatChange.observedAtHours=hours
check("physical_retry_does_not_reacquire",C.physicalChange("a",repeatChange) and equal(before,state("a")))
repeatChange.stats.PAIN.after=31
check("physical_conflict_rejected",not C.physicalChange("a",repeatChange))
for _,kind in ipairs({"unchanged","unknown","hidden","unmeasured","future","occurrence-future","minute-mismatch"}) do
 local raw=physical(62,{PAIN={before=1,after=2}})
 if kind=="unchanged" then raw.stats.PAIN.after=1
 elseif kind=="unknown" then raw.stats.FAMILY_EFFECT={before=1,after=2}
 elseif kind=="hidden" then raw.stats.PAIN.doseSequence=1
 elseif kind=="unmeasured" then raw.stats={}
 elseif kind=="future" then raw.observedAtHours=hours+1
 elseif kind=="occurrence-future" then raw.atHours=hours+1;raw.minute=raw.atHours*60
 elseif kind=="minute-mismatch" then raw.atHours=1 end
 check("physical_refuses_"..kind,not C.physicalChange("a",raw))
end
local private=copy(last("a"));private.id="physical/63";private.perspective="observed";private.actorId="b"
check("other_body_changes_private",not C.experience("a",private))

local heat=preparation("a",1)
check("preparation_completed",C.preparationOutcome("a",heat))
check("preparation_exact_binding",last("a").kind=="preparation" and last("a").category=="food"
 and last("a").sourceId=="C:fixture:0" and last("a").itemId==123 and not forbidden(last("a")))
check("preparation_is_not_eating",noGoalCredit("a") and equal(frozen,state("a").episodes[1]))
check("independent_preparation_memory",state("a").models.ordinary.beliefs["direct:preparation:C:fixture:0:Base.Chicken"]
 and state("a").models.associative.beliefs["relation:transform:food:thermally-prepared-food"])
for _,kind in ipairs({"credit","item","source","heat","progress","retrieved","completion","actor","sequence"}) do
 local raw=preparation("a",2)
 if kind=="credit" then raw.nativeCredit="different-item-receipt"
 elseif kind=="item" then raw.itemId=nil
 elseif kind=="source" then raw.sourceId=nil
 elseif kind=="heat" then raw.heatObserved=false
 elseif kind=="progress" then raw.afterCookingTime=raw.beforeCookingTime
 elseif kind=="retrieved" then raw.retrieved=false
 elseif kind=="completion" then raw.status="unavailable"
 elseif kind=="actor" then raw.actorId="b"
 elseif kind=="sequence" then raw.id="cooking/a/3";raw.nativeCredit=raw.id end
 check("preparation_refuses_"..kind,not C.preparationOutcome("a",raw))
end
-- Existing object/placement experience makes a new adjacent thermal analogy;
-- repeated preparation by itself does not walk a prewritten technology chain.
records.thermal={id="thermal"}
local firstThermalPaths
for i=1,8 do
 check("repeated_preparation_"..i,C.preparationOutcome("thermal",preparation("thermal",i)))
 if i==1 then
  firstThermalPaths={}
  for _,h in ipairs(state("thermal").models.associative.hypotheses) do firstThermalPaths[h.key]=h.id end
 end
end
local finalThermalPaths={}
for _,h in ipairs(state("thermal").models.associative.hypotheses) do
 check("no_preparation_ladder",h.depth==1 or h.depth==2 and h.status=="hypothesis"
  and string.find(h.key,"/context:",1,true) and #h.missing>0)
 finalThermalPaths[h.key]=h.id
end
check("repeated_preparation_preserves_paths",equal(firstThermalPaths,finalThermalPaths))
check("adjacent_contents_observed",C.experience("thermal",{id="inspect:thermal",actorId="thermal",observerId="thermal",
 worldHours=hours,kind="inspection",category="container",perspective="performed",status="completed",foodPresent=true,waterPresent=false}))
local composed
for _,h in ipairs(state("thermal").models.associative.hypotheses) do
 if h.relation=="compose" and h.into=="thermally-prepared-food" then composed=h end
end
check("actual_preparation_composes",composed and composed.depth==2 and composed.status=="hypothesis"
 and #composed.evidenceIds>=2 and #composed.missing>0)
local oldSummary=M.summary("associative",state("a").models.associative,hours)
before=copy(state("a"));local later=M.summary("associative",state("a").models.associative,hours+48)
for _,name in ipairs({"ordinary","associative"}) do
 local proposal=M.propose(name,state("a").models[name],frame("a"))
 check("only_executable_actions_"..name,count(proposal.predictions)==4 and proposal.predictions.food
  and proposal.predictions.water and proposal.predictions.inspect and proposal.predictions.continue
  and (proposal.actionId=="food" or proposal.actionId=="water" or proposal.actionId=="inspect" or proposal.actionId=="continue"))
end
check("new_evidence_queries_inert",equal(before,state("a")) and later.beliefs[1].confidence<oldSummary.beliefs[1].confidence)
-- Real consumption keeps its existing frozen selected-action outcome path.
local token=C.capture("a","native-use")
check("real_consumption_still_settles",C.publish("a",token,{kind="consume",category="food",status="completed",hungerDelta=.2})
 and state("a").episodes[1].outcome.success and state("a").episodes[1].outcome.eventId==token.id
 and state("a").episodes[1].proposals[1].predictions.food.probability==frozen.proposals[1].predictions.food.probability)

-- A saved /2 ledger includes only three fixed-size producer cursors. Old
-- callbacks cannot get a new acquisition time after history truncation.
state("a").episodes[1].ignoredProbe=nil
for i=1,270 do
 hours=hours+.02
 check("bounded_change_"..i,C.physicalChange("a",physical(100+i,{PAIN={before=i%2,after=(i+1)%2}})))
end
local restored=copy(state("a"));records.a.cognition=restored;C.rebindWorld()
local revision=state("a").models.associative.revision
check("bounded_new_history",#state("a").experiences==256 and count(state("a").nativeExperienceCursors)==3
 and #state("a").models.associative.beliefOrder+#state("a").models.associative.hypotheses<=64)
check("evicted_dose_callback_not_relearned",not C.medicationUse("a",use) and state("a").models.associative.revision==revision)
check("evicted_physical_callback_not_relearned",not C.physicalChange("a",change) and state("a").models.associative.revision==revision)
check("evicted_preparation_callback_not_relearned",not C.preparationOutcome("a",heat) and state("a").models.associative.revision==revision)
records.batch={id="batch"}
local firstBatch
for i=1,300 do
 local raw=physical(500+i,{PAIN={before=50,after=20}})
 check("batch_same_acquisition_"..i,C.physicalChange("batch",raw))
 if i==1 then firstBatch=copy(last("batch")) end
 check("batch_acquisition_unaltered_"..i,last("batch").worldHours==hours)
end
check("batch_retention_bounded",#state("batch").experiences==256 and state("batch").omittedExperiences==44)
for _,name in ipairs({"ordinary","associative"}) do
 local s=copy(state("batch").models[name]);local before=copy(s)
 check("model_old_native_receipt_"..name,string.sub(M.observe(name,s,firstBatch,4),1,8)=="ignored:" and equal(before,s))
end
check("future_variant_rejected",(function()
 local s=copy(state("a").models.ordinary);s.version="sao-ordinary/999"
 return M.propose("ordinary",s,frame("a"))==nil
end)())
-- The actual Labor reader projects current Census skills into every first
-- native admission. Re-delivery keeps the original acquired context even when
-- later skills have changed; a new occurrence receives the new context.
local originalSkillOf=SAO.Census.skillOf
local contextualSkills={}
SAO.Census.skillOf=function(id,perk)
 local own=contextualSkills[id]
 if own then return own[perk] or -1 end
 return originalSkillOf(id,perk)
end
for _,producer in ipairs({"medication","physical","preparation"}) do
 local id="context-"..producer
 records[id]={id=id}
 hours=40
 contextualSkills[id]={Cooking=2,PlantScavenging=-1,Doctor=-1}
 local function receipt(position)
  local value
  if producer=="medication" then value=dose(id,position)
  elseif producer=="physical" then value=physical(position)
  else value=preparation(id,position) end
  -- A producer/God-view claim cannot replace current personal Labor evidence.
  value.capabilities={cook=false,forage=true,treat=true}
  return value
 end
 local function admit(value)
  if producer=="medication" then return C.medicationUse(id,value)
  elseif producer=="physical" then return C.physicalChange(id,value)
  else return C.preparationOutcome(id,value) end
 end
 local first=receipt(1)
 check("context_first_admitted_"..producer,admit(first))
 local initial={cook=true,forage=false,treat=false}
 check("context_first_private_"..producer,equal(last(id).capabilities,initial))
 check("context_first_model_"..producer,equal(state(id).models.associative.capabilities,initial))
 check("context_first_no_goal_credit_"..producer,noGoalCredit(id))
 hours=41
 contextualSkills[id]={Cooking=-1,PlantScavenging=3,Doctor=1}
 local beforeReplay=copy(state(id))
 check("context_repeat_admitted_"..producer,admit(first))
 check("context_repeat_inert_"..producer,equal(beforeReplay,state(id)))
 local second=receipt(2)
 check("context_new_admitted_"..producer,admit(second))
 local current={cook=false,forage=true,treat=true}
 check("context_new_private_"..producer,equal(last(id).capabilities,current))
 check("context_new_model_"..producer,equal(state(id).models.associative.capabilities,current))
 check("context_prior_unchanged_"..producer,equal(state(id).experiences[1].capabilities,initial))
 records[id].cognition=copy(state(id))
 hours=42
 contextualSkills[id]={Cooking=0,PlantScavenging=0,Doctor=0}
 beforeReplay=copy(state(id))
 check("context_restored_replay_admitted_"..producer,admit(first) and admit(second))
 check("context_restored_replay_inert_"..producer,equal(beforeReplay,state(id)))
 local third=receipt(3)
 check("context_zero_skill_admitted_"..producer,admit(third))
 local basic={cook=true,forage=true,treat=true}
 check("context_zero_skill_private_"..producer,equal(last(id).capabilities,basic))
 check("context_zero_skill_model_"..producer,equal(state(id).models.associative.capabilities,basic))
 check("context_zero_skill_prior_preserved_"..producer,equal(state(id).experiences[1].capabilities,initial)
  and equal(state(id).experiences[2].capabilities,current))
end
SAO.Census.skillOf=originalSkillOf
-- Native feeding authenticity belongs to the animal owner; this proof holds
-- the private boundary, independent models and exact retained producer join.
hours=50
records.care={id="care",animalCare={outcomes={}}}
local feed={schema=1,id="animal-care/care/1",actorId="care",position=1,
 worldHours=49,kind="feed",status="completed",nativeToken="feeding/1/1",
 animalId=41,itemId=901,itemType="Base.FeedForCalf",quantityUnit="uses",
 beforeAmount=1,afterAmount=.8,consumedAmount=.2,beforeHunger=.7,
 afterHunger=.5,hungerDelta=.2,reason="native-feed-consumed"}
records.care.animalCare.outcomes[1]=copy(feed)
local forged=copy(feed);forged.consumedAmount=.3
check("animal_owner_authentication",not C.animalCareOutcome("care",forged))
check("animal_completed_admitted",C.animalCareOutcome("care",feed))
local private=copy(last("care"))
check("animal_private_projection",private.kind=="animal-care" and private.category=="animal"
 and private.sourceId=="animal/41" and private.consumedAmount==.2
 and private.beforeHunger==nil and private.afterHunger==nil and private.hungerDelta==nil
 and private.nativeToken==nil and private.animalId==nil and private.reason==nil)
check("animal_no_goal_credit",noGoalCredit("care"))
check("animal_independent_models",state("care").models.ordinary.revision==1
 and state("care").models.associative.revision==1
 and state("care").models.ordinary.beliefs~=state("care").models.associative.beliefs)
local prior=copy(state("care"));hours=51
check("animal_duplicate_admitted",C.animalCareOutcome("care",feed))
check("animal_duplicate_inert",equal(prior,state("care")))
check("animal_foreign_actor_refused",not C.animalCareOutcome("b",feed))
local zero=copy(private);zero.consumedAmount=0
check("animal_zero_consumption_refused",not M.acceptsExperience(zero))
local hidden=copy(private);hidden.beforeHunger=.7
check("animal_hidden_health_refused",not M.acceptsExperience(hidden))
local observed=copy(private);observed.observerId="b";observed.perspective="observed"
check("animal_witness_receipt_refused",not M.acceptsExperience(observed))
records.care.cognition=copy(state("care"));C.rebindWorld()
prior=copy(state("care"));hours=52
check("animal_restored_replay_inert",C.animalCareOutcome("care",feed) and equal(prior,state("care")))
records.care.animalCare.outcomes={}
check("animal_retired_owner_refused",not C.animalCareOutcome("care",feed))
RESULT="PASS extended cognition "..n
