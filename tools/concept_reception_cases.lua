local K,C=SAO.ConceptKnowledge,SAO.Communication
local records={a={id="a"},b={id="b"},c={id="c"}}
local at=12
SAO.Identity={get=function(id)return records[id]end}
SAO.History={countyHours=function()return at end}
SAO.Standing={sameGroup=function()return true end,trust=function()return 1 end}
local admitted=true
C.canConverse=function(_,_,channel)return admitted,admitted and channel or "cannot-hear-now"end
local observed={}
SAO.Perception={conceptObservation=function(id,key)return observed[id] and observed[id][key]end}
local n=0
local function check(name,v) if not v then error("RECEPTION:"..name)end;n=n+1 end
local function teachSource(id,concept)
 observed[id]={r={key="r",kind="room",concept="room",roomId="R",buildingId="house:A",at=at},
  o={key="o",kind="object",concept=concept,roomId="R",buildingId="house:A",at=at}}
 check("shared_observation",K.observeRelation(id,"r","o")==true)
end
check("common_prior_shared",K.infer("a","house","relief-from-tiredness").status=="expectation")
check("no_private_association_yet",K.infer("b","room","relief-from-exertion").status=="unresolved")
teachSource("a","seat")
check("individual_acquired_prior",K.infer("a","room","relief-from-exertion").status=="expectation")
check("no_ambient_transfer",K.infer("b","room","relief-from-exertion").status=="unresolved")
local seq=records.a.conceptKnowledge.sequence
local offer=K.teachingOffer("a","b")
check("offered_general_not_local",offer and offer.contextId==nil and offer.modal)
check("offer_query_pure",records.a.conceptKnowledge.sequence==seq and records.b.conceptKnowledge==nil)
local forged=C.send("a","b","concept-association",offer);C.deliver(forged)
check("generic_delivery_not_reception",K.receiveAssociation("b",forged)==false)
check("generic_delivery_does_not_teach",records.b.conceptKnowledge==nil)
admitted=false
records.b.conceptKnowledge={schema=1,sequence=1,order={"private-negative"},omitted=0,relations={
 ["private-negative"]={id="private-negative",actorId="b",from="room",relation="typically-contains",into="seat",
 basis="personal-association",sourceId="uncommunicated",acquiredAt=at,affirmed=false}}}
local unseenListenerOffer=K.teachingOffer("a","b")
check("offer_independent_of_listener_belief",unseenListenerOffer and unseenListenerOffer.id==offer.id)
check("unadmitted_offer_does_not_remember",C.deliverConceptAssociation("a","b","spoken")==nil
 and records.a.conceptKnowledge.spokenAssociations==nil)
records.b.conceptKnowledge=nil
check("no_transport_no_teaching",C.deliverConceptAssociation("a","b","spoken")==nil and records.b.conceptKnowledge==nil)
admitted=true
local message,receipt=C.deliverConceptAssociation("a","b","spoken")
check("admitted_reception",message and receipt and receipt.basis=="taught-association")
check("reception_changes_inference",K.infer("b","room","relief-from-exertion").status=="expectation")
check("retains_speaker_channel_source",receipt.speakerId=="a" and receipt.channel=="spoken" and receipt.parentId==offer.id and receipt.acquiredAt==at)
check("taught_does_not_invent_local_fact",receipt.contextId==nil and receipt.x==nil and receipt.modal)
check("receipt_capability_retired",C.conceptReception(message)==nil and K.receiveAssociation("b",message)==false)
check("actual_utterance_remembered",records.a.conceptKnowledge.spokenAssociations and records.a.conceptKnowledge.spokenAssociations[1]
 and records.a.conceptKnowledge.spokenAssociations[1].edgeId==offer.id
 and records.a.conceptKnowledge.spokenAssociations[1].to=="b")
check("generic_delivery_cannot_remember",K.rememberSpokenAssociation("a",forged)==false)
check("no_new_event_on_repeat",C.deliverConceptAssociation("a","b","spoken")==nil)
check("message_custody_released",#C.messages==0)
local original=records.b
local reloaded={id="b",conceptKnowledge={schema=1,sequence=original.conceptKnowledge.sequence,relations={},order={},omitted=0}}
for k,v in pairs(original.conceptKnowledge.relations) do
 local row={}for x,y in pairs(v)do row[x]=y end;reloaded.conceptKnowledge.relations[k]=row end
for i,v in ipairs(original.conceptKnowledge.order)do reloaded.conceptKnowledge.order[i]=v end
records.b=reloaded
check("durable_reload_inference",K.infer("b","room","relief-from-exertion").status=="expectation")
check("third_person_still_uninformed",K.infer("c","room","relief-from-exertion").status=="unresolved")
local second,secondReceipt=C.deliverConceptAssociation("b","c","dormant-encounter")
check("bounded_onward_reception",second and secondReceipt.speakerId=="b" and secondReceipt.channel=="dormant-encounter")
check("dead_receiver_refused",(function()records.c.dead=true;teachSource("a","bed");return K.teachingOffer("a","c")==nil end)())
records.c.dead=false
records.c.conceptKnowledge={schema=1,sequence=1,order={"negative"},omitted=0,relations={negative={
 id="negative",actorId="c",from="room",relation="typically-contains",into="seat",basis="personal-association",
 sourceId="own-contrary-source",acquiredAt=at,affirmed=false}}}
local privateOffer=K.teachingOffer("a","c")
check("listener_contrary_not_teller_knowledge",privateOffer and privateOffer.into=="seat")
local rejected=C.deliverConceptAssociation("a","c","spoken")
check("own_contrary_evidence_preserved",rejected==nil and K.infer("c","room","relief-from-exertion").status~="expectation"
 and records.c.conceptKnowledge.sequence==1 and records.c.conceptKnowledge.relations.negative.affirmed==false)
check("utterance_without_acceptance_remembered",K.teachingOffer("a","c").into=="bed")
local savedSpoken=records.a.conceptKnowledge.spokenAssociations
local sameSource=K.teachingOffer("a","b")
check("next_association_after_actual_speech",sameSource and sameSource.into=="bed")
records.a.conceptKnowledge.spokenAssociations=nil
check("unknown_recipient_prior_does_not_suppress_offer",K.teachingOffer("a","b").id==offer.id)
local beforeKnown=records.b.conceptKnowledge.sequence
check("receiver_owns_duplicate_refusal",C.deliverConceptAssociation("a","b","spoken")==nil
 and records.b.conceptKnowledge.sequence==beforeKnown)
records.a.conceptKnowledge.spokenAssociations=savedSpoken
SAO.Standing.sameGroup=function()return false end;SAO.Standing.trust=function()return 0 end
check("trust_refuses_transfer",C.deliverConceptAssociation("a","c","spoken")==nil)
check("self_teaching_refused",K.teachingOffer("a","a")==nil)
local corrupted=records.b.conceptKnowledge
for _,row in pairs(corrupted.relations)do row.acquiredAt=at+1 end
check("future_dated_prior_refused",K.infer("b","room","relief-from-exertion").status=="unresolved")
-- Canonical observation witnesses can change without making another thing
-- to say. Retain exact message custody and receiver-owned acceptance.
records={a={id="a"},b={id="b"},c={id="c"}};at=20;admitted=true
SAO.Standing.sameGroup=function()return true end
teachSource("a","seat")
local stableOffer=K.teachingOffer("a","b")
local firstMessage=C.deliverConceptAssociation("a","b","spoken")
check("first_association_transmitted",firstMessage and #records.a.conceptKnowledge.spokenAssociations==1)
local stateA=records.a.conceptKnowledge
local receiverSequence=records.b.conceptKnowledge.sequence
local primary=stateA.relations["room|contains|seat|house:A"]
for i=1,6 do
 at=at+1;observed.a.r.at=at
 observed.a.o={key="o:"..i,kind="object",concept="seat",roomId="R",buildingId="house:A",at=at}
 K.observeRelation("a","r","o")
end
check("same_fact_witnesses_do_not_repeat_testimony",K.teachingOffer("a","b")==nil
 and C.deliverConceptAssociation("a","b","spoken")==nil and #stateA.spokenAssociations==1
 and stateA.sequence==2 and records.b.conceptKnowledge.sequence==receiverSequence and #C.messages==0)
local private=stateA.witnesses[primary.id]
check("support_provenance_is_private",#private.rows==7 and private.rows[1].sourceId==primary.sourceId
 and K.teachingOffer("a","c").witnesses==nil)
local neverSpoken=K.teachingOffer("a","c")
neverSpoken.into="fabricated"
check("offer_is_detached_and_does_not_claim_speech",K.teachingOffer("a","c").id==stableOffer.id
 and K.teachingOffer("a","c").into=="seat" and #stateA.spokenAssociations==1)
records.a=__nativeRoundtrip(records.a);records.b=__nativeRoundtrip(records.b)
stateA=records.a.conceptKnowledge
check("native_reload_preserves_witnesses_and_speech",stateA.sequence==2
 and #stateA.witnesses[primary.id].rows==7 and stateA.relations["room|contains|seat|house:A"].acquiredAt==20
 and K.teachingOffer("a","b")==nil and K.teachingOffer("a","c").id==stableOffer.id)
at=at+1;observed.a.r.at=at;observed.a.o.at=at;K.observeRelation("a","r","o")
check("native_reload_refresh_does_not_reutter",stateA.sequence==2
 and C.deliverConceptAssociation("a","b","spoken")==nil and #stateA.spokenAssociations==1)
local thirdMessage=C.deliverConceptAssociation("a","c","spoken")
check("new_recipient_still_receives_association",thirdMessage
 and K.infer("c","room","relief-from-exertion").status=="expectation" and #stateA.spokenAssociations==2)
stateA.witnesses[primary.id]={rows={false,
 {sourceId="future-witness",basis=primary.basis,acquiredAt=at+1,lastObservedAt=at+2},
 {sourceId=primary.sourceId,basis=primary.basis,acquiredAt=at,lastObservedAt=at},
 {sourceId="malformed-time",basis=primary.basis,acquiredAt=20,lastObservedAt="future"}}}
local badSaved=stateA.witnesses[primary.id]
K.teachingOffer("a","b");K.infer("a","room","relief-from-exertion")
check("query_does_not_repair_saved_support",stateA.witnesses[primary.id]==badSaved and #badSaved.rows==4)
local repairOK,repairAccepted=pcall(K.observeRelation,"a","r","o")
check("malformed_saved_support_recovers_on_observation",repairOK and repairAccepted)
local futureAbsent=true
for _,support in ipairs(stateA.witnesses[primary.id].rows) do
 if support.sourceId=="future-witness" or support.sourceId=="malformed-time" then futureAbsent=false end end
check("future_witness_not_observation_authority",futureAbsent
 and stateA.witnesses[primary.id].rows[1].acquiredAt==20 and stateA.sequence==2)
stateA.witnesses="malformed-map"
local mapOK,mapAccepted=pcall(K.observeRelation,"a","r","o")
check("malformed_map_recovers_on_observation",mapOK and mapAccepted and type(stateA.witnesses)=="table"
 and stateA.witnesses[primary.id].rows[1].sourceId==primary.sourceId)
stateA.witnesses[primary.id]={rows={}}
for i=1,40 do stateA.witnesses[primary.id].rows[i]={sourceId="saved-witness:"..i,basis=primary.basis,
 acquiredAt=20,lastObservedAt=at} end
K.observeRelation("a","r","o")
check("loaded_support_capacity_bounded",#stateA.witnesses[primary.id].rows==16
 and stateA.witnesses[primary.id].truncated and stateA.witnesses[primary.id].rows[1].sourceId==primary.sourceId
 and stateA.sequence==2)
-- Existing saved schema-1 people have no witness map. Queries leave that
-- record alone; the next authentic observation retains its original source.
stateA.witnesses=nil
local legacySequence=stateA.sequence
K.infer("a","room","relief-from-exertion");K.teachingOffer("a","c")
check("legacy_query_does_not_create_witnesses",stateA.witnesses==nil)
at=at+1;observed.a.r.at=at;observed.a.o.at=at;K.observeRelation("a","r","o")
check("legacy_observation_preserves_acquisition",stateA.sequence==legacySequence
 and stateA.relations["room|contains|seat|house:A"].sourceId==primary.sourceId
 and stateA.witnesses[primary.id].rows[1].sourceId==primary.sourceId
 and stateA.witnesses[primary.id].rows[1].acquiredAt==20 and K.teachingOffer("a","b")==nil)
for i=1,34 do at=at+1;teachSource("a","fixture-concept:"..i) end
local held,count={},0
for _,row in pairs(stateA.relations)do held[row.id]=true end
local allHeld=true
for relationId,_ in pairs(stateA.witnesses)do count=count+1;if not held[relationId] then allHeld=false end end
check("eviction_retires_private_witness_bucket",allHeld and count==64 and #stateA.order==64
 and stateA.witnesses[primary.id]==nil)
__result="PASS concept reception "..n
