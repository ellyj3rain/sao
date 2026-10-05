local C,P,D=SAO.Cognition,SAO.ProceduralPlanning,SAO.Disposition
local checks=0
local function check(name,condition)
    if not condition then error("CONFLICT:"..name) end
    checks=checks+1;print("CHECK "..name)
end
local function clone(value)
    if type(value)~="table" then return value end
    local out={} for k,v in pairs(value) do out[k]=clone(v) end return out
end
local function person(id,values)
    records[id]={id=id,traitEchoes={},lessonEchoes={},conditionEchoes={}}
    for k,v in pairs(values or {}) do records[id].traitEchoes[k]=v-.5 end
end
local timid={selfPreservation=.85,aggression=.15,nerve=.15,discipline=.5,compassion=.5}
local bold={selfPreservation=.15,aggression=.85,nerve=.85,discipline=.5,compassion=.5}
local function frame(id)
    return {actorId=id,atHours=clock,threat={kind="zombie",key="seen:z1",distance=2,count=1,source="observed",at=100},
        values=D.conflictValues(id),fear=0,overwhelmed=false,escapeBlocked=false}
end
local function offers()
    return {
        {id="withdraw",kind="withdraw",available=true,reason="observed route available",effects={"break-contact"},objections={},routeKey="west"},
        {id="defend",kind="defend",available=true,reason="native shove available",effects={"create-space"},objections={},nativeMode="shove",targetKey="seen:z1"},
        {id="engage",kind="engage",available=true,reason="native close action available",effects={"stop-threat"},objections={},nativeMode="melee",targetKey="seen:z1"},
        {id="watch",kind="watch",available=true,reason="can keep watch",effects={},objections={}},
    }
end
person("timid",timid);person("bold",bold)
local a=C.appraiseConflict("timid",frame("timid"),offers())
local b=C.appraiseConflict("bold",frame("bold"),offers())
check("personal_values_change_choice",a.selected=="withdraw" and b.selected=="engage")
check("priors_before_success_receipts",records.bold.cognition==nil and records.bold.conceptKnowledge==nil and b.selected=="engage")
check("appraisal_is_pure",records.bold.proceduralPlanning==nil)
local values=D.conflictValues("bold")
check("trait_provenance_retained",values.actorId=="bold" and values.provenance.aggression.base==.5
    and values.provenance.aggression.history==.35 and values.provenance.aggression.effective==values.aggression)
local f=frame("timid");f.escapeBlocked=true
local blockedOffers=offers();blockedOffers[1].available=false
local blocked=C.appraiseConflict("timid",f,blockedOffers)
check("blocked_escape_allows_unarmed_defense",blocked.selected=="defend")
check("one_failed_exit_does_not_discredit_an_available_exit",C.appraiseConflict("timid",f,offers()).selected=="withdraw")
f=frame("bold");f.overwhelmed=true;f.fear=.9
check("costly_resistance_not_categorically_excluded",C.appraiseConflict("bold",f,offers()).selected=="engage")
person("keeper",{selfPreservation=.8,aggression=.2,nerve=.3,compassion=.85,discipline=.85})
f=frame("keeper");f.commitment={key="protect-ally",kind="protect",accepted=false,protectOther=true}
check("unaccepted_protection_does_not_bind",C.appraiseConflict("keeper",f,offers()).selected=="withdraw")
f.commitment.accepted=true
check("accepted_protection_changes_costly_choice",C.appraiseConflict("keeper",f,offers()).selected=="engage")
-- Controlled personal contradiction exercises a supported representation;
-- this fixture does not claim a live producer of negative learning.
local denial={id="concept/bold/1",actorId="bold",from="force",relation="supports",into="stop-threat",
    contextId="seen:z1",affirmed=false,basis="personal-association",sourceId="fixture-premise",acquiredAt=clock}
records.bold.conceptKnowledge={schema=1,sequence=1,relations={denial=denial},order={"denial"}}
check("causal_premise_changes_choice_at_fixed_values",C.appraiseConflict("bold",frame("bold"),offers()).selected=="defend")
person("other",bold)
check("private_contradiction_does_not_cross_actors",C.appraiseConflict("other",frame("other"),offers()).selected=="engage")
f=frame("bold");f.threat.key="seen:z2"
check("local_exception_not_global_erasure",C.appraiseConflict("bold",f,offers()).selected=="engage")
records.bold.conceptKnowledge=nil
local unavailable=offers()
for i=1,3 do unavailable[i].available=false end
f=frame("bold");f.threat={kind="unknown",source="heard",count=0}
local unknown=C.appraiseConflict("bold",f,unavailable)
check("unknown_contact_admits_watch_only",unknown.selected=="watch")
check("watch_claims_no_prevention",unknown.reason:find("does not prevent harm",1,true)~=nil)
f=frame("bold");f.actorId="timid"
check("foreign_actor_frame_refused",C.appraiseConflict("bold",f,offers())==nil)
f=frame("bold");f.values=D.conflictValues("other")
check("foreign_values_refused",C.appraiseConflict("bold",f,offers())==nil)
f=frame("bold");f.values.aggression=.1
check("forged_personal_values_refused",C.appraiseConflict("bold",f,offers())==nil)
f=frame("bold");f.atHours=clock+1
check("future_frame_refused",C.appraiseConflict("bold",f,offers())==nil)
local invalid=offers();invalid[3].nativeMode=nil
check("fictional_combat_offer_refused",C.appraiseConflict("bold",frame("bold"),invalid)==nil)
invalid=offers();invalid[1].foreignPrivateMemory={secret=true}
check("foreign_offer_fields_refused",C.appraiseConflict("bold",frame("bold"),invalid)==nil)
invalid=offers();invalid[1].effects[1]=invalid
check("cyclic_input_refused",C.appraiseConflict("bold",frame("bold"),invalid)==nil)
invalid=offers();for i=5,17 do invalid[i]=clone(invalid[4]);invalid[i].id="watch"..i end
check("offer_budget_enforced",C.appraiseConflict("bold",frame("bold"),invalid)==nil)
local social={{id="talk",kind="communicate",available=true,reason="actual channel available",
    effects={"possible-agreement"},objections={"response-unconfirmed"}}}
local talk=C.appraiseConflict("timid",frame("timid"),social)
check("communication_retains_other_agency",talk.reason:find("other person still chooses",1,true)~=nil
    and talk.alternatives[1].expectedEffects[1].status=="possible")
social[1].kind="coordinate";social[1].effects={"mutual-support"}
check("cooperation_is_not_assent",C.appraiseConflict("timid",frame("timid"),social).reason:find("participation still need",1,true)~=nil)
social[1].kind="concede";social[1].effects={"possible-agreement"};social[1].objections={"loss-of-supplies"}
check("concession_does_not_promise_safety",C.appraiseConflict("timid",frame("timid"),social).reason:find("does not guarantee",1,true)~=nil)
social[1].kind="communicate";social[1].effects={"imposed-compliance"}
check("coercion_does_not_grant_compliance",C.appraiseConflict("bold",frame("bold"),social).reason:find("refuse or resist",1,true)~=nil)

person("route",timid)
local route=P.planConflict("route",frame("route"),offers())
local token={owner="Locomotion",id="route-1"}
check("purpose_without_admission_grants_nothing",route.selected=="withdraw" and P.conflictSnapshot("route").admission==nil
    and P.conflictSnapshot("route").lastOutcome==nil)
check("native_owner_kind_checked",not P.conflictAdmission("route",route.purposeId,{owner="SAO.Combat",id="route-1"},route.selected))
check("exact_admission_recorded",P.conflictAdmission("route",route.purposeId,token,route.selected))
check("admission_cannot_be_replaced",not P.conflictAdmission("route",route.purposeId,{owner="Locomotion",id="route-2"},route.selected))
local continuing=offers();continuing[1].continuing=true
f=frame("route");f.threat.distance=2.8;f.threat.at=999
local refreshed=P.planConflict("route",f,continuing)
check("progressing_route_survives_clock_and_distance_refresh",refreshed.continuing and refreshed.selected=="withdraw"
    and P.conflictSnapshot("route").admission.id=="route-1")
f=frame("route");f.escapeBlocked=true
local changedOffers=clone(continuing);changedOffers[1].available=false
local changed=P.planConflict("route",f,changedOffers)
check("material_change_reappraises_but_keeps_native_custody",changed.selected=="defend"
    and P.conflictSnapshot("route").admission.id=="route-1")
check("wrong_native_result_token_refused",not P.conflictResult("route",route.purposeId,{owner="Locomotion",id="route-2"},{status="failed",reason="blocked"}))
check("foreign_owner_result_refused",not P.conflictResult("route",route.purposeId,{owner="SAO.Combat",id="route-1"},{status="failed",reason="blocked"}))
check("unrelated_route_failure_refused",not P.conflictResult("route",route.purposeId,token,{status="failed",reason="blocked",routeKey="east"}))
check("native_failure_is_exact_once",P.conflictResult("route",route.purposeId,token,{status="failed",reason="native blocked",routeKey="west"})
    and not P.conflictResult("route",route.purposeId,token,{status="failed",reason="native blocked",routeKey="west"}))
check("route_failure_private_and_relevant",P.conflictRouteBlocked("route","west",clock)
    and not P.conflictRouteBlocked("bold","west",clock))
check("failed_route_changes_next_choice",P.planConflict("route",frame("route"),offers()).selected=="defend")
check("failed_attempt_not_threat_resolution",P.conflictSnapshot("route").status=="maintained"
    and P.conflictSnapshot("route").lastOutcome.status=="failed")
local detached=P.conflictSnapshot("route");detached.lastOutcome.status="completed"
check("snapshot_is_detached",P.conflictSnapshot("route").lastOutcome.status=="failed")
clock=clock+.051
check("route_refusal_expires_without_query_mutation",not P.conflictRouteBlocked("route","west",clock)
    and P.planConflict("route",frame("route"),offers()).selected=="withdraw")
check("retired_token_cannot_be_readmitted",not P.conflictAdmission("route",route.purposeId,token,"withdraw"))

person("refused",bold)
local selected=P.planConflict("refused",frame("refused"),offers())
check("stale_refusal_revision_refused",not P.conflictRefusal("refused",selected.purposeId,selected.selected,{frameId="old",reason="target vanished"}))
check("refusal_without_false_admission",P.conflictRefusal("refused",selected.purposeId,selected.selected,{frameId=selected.frameId,reason="target vanished"})
    and P.conflictSnapshot("refused").admission==nil and P.conflictSnapshot("refused").lastOutcome.admitted==false)
check("native_combat_refusal_changes_next_choice",P.planConflict("refused",frame("refused"),offers()).selected=="defend")
check("old_selected_offer_cannot_receive_refusal",not P.conflictRefusal("refused",selected.purposeId,selected.selected,{frameId=selected.frameId,reason="late"}))
check("generic_receipt_cannot_complete_conflict",not P.recordResult("refused",selected.purposeId,{owner="SAO.Combat",token="combat:done",status="completed"}))

person("done",bold)
selected=P.planConflict("done",frame("done"),offers())
token={owner="SAO.Combat",id="combat-1"}
P.conflictAdmission("done",selected.purposeId,token,selected.selected)
check("native_attempt_completion_keeps_larger_purpose",P.conflictResult("done",selected.purposeId,token,{status="completed",reason="native cycle finished"})
    and P.conflictSnapshot("done").status=="maintained" and P.conflictSnapshot("done").lastOutcome.status=="completed")
check("replayed_completion_rejected",not P.conflictResult("done",selected.purposeId,token,{status="completed",reason="native cycle finished"}))
local nextDecision=P.planConflict("done",frame("done"),offers())
check("terminal_attempt_requires_new_appraisal_identity",nextDecision.frameId~=selected.frameId and not nextDecision.continuing)
token={owner="SAO.Combat",id="combat-2"};P.conflictAdmission("done",nextDecision.purposeId,token,nextDecision.selected)
clock=clock+2.1
check("expired_completion_refused",not P.conflictResult("done",nextDecision.purposeId,token,{status="completed",reason="late"}))
check("expired_exact_owner_can_release",P.conflictResult("done",nextDecision.purposeId,token,{status="cancelled",reason="owner released expired attempt"}))
check("old_save_has_no_fabricated_snapshot",P.conflictSnapshot("other")==nil)
local sample=C.appraiseConflict("bold",frame("bold"),offers())
check("thought_reason_contains_no_score_narration",not sample.reason:find("score",1,true) and not sample.reason:find("utility",1,true)
    and not sample.reason:find("%d"))
local argument
for _,alternative in ipairs(sample.alternatives) do
    if alternative.id=="engage" then
        for _,row in ipairs(alternative.arguments) do if row.effect=="stop-threat" then argument=row end end
    end
end
check("argument_links_effect_premise_and_personal_concern",argument and argument.polarity=="supports"
    and argument.concern=="resist-threat" and argument.premises[2].from=="force"
    and argument.premises[2].links[1].basis=="declared-ordinary-life-prior"
    and argument.valueBasis.actorId=="bold" and argument.expectedStatus=="possible")
f=frame("keeper");f.commitment={key="protect-ally",kind="protect",accepted=true,protectOther=true}
sample=C.appraiseConflict("keeper",f,offers())
argument=nil
for _,alternative in ipairs(sample.alternatives) do
    if alternative.id==sample.selected then
        for _,row in ipairs(alternative.arguments) do if row.concern=="honor-accepted-protection" then argument=row end end
    end
end
check("argument_links_accepted_obligation",argument and argument.premises[3].kind=="accepted-commitment"
    and argument.premises[3].key=="protect-ally")
f=frame("bold");f.threat.kind="person";f.threat.key="A Person With Spaces"
check("human_name_does_not_erase_general_priors",C.appraiseConflict("bold",f,offers()).selected=="engage")
person("departed",bold)
local departed=P.planConflict("departed",frame("departed"),offers())
local departedToken={owner="SAO.Combat",id="departed-1"}
P.conflictAdmission("departed",departed.purposeId,departedToken,departed.selected)
records.departed.dead=true
check("death_preserves_owned_attempt_evidence",P.conflictSnapshot("departed").admission.id=="departed-1")
check("death_refuses_new_appraisal",P.planConflict("departed",frame("departed"),offers())==nil)
check("death_settles_only_exact_existing_attempt",not P.conflictResult("departed",departed.purposeId,{owner="SAO.Combat",id="foreign"},
    {status="cancelled",reason="death"}) and P.conflictResult("departed",departed.purposeId,departedToken,{status="cancelled",reason="death"})
    and P.conflictSnapshot("departed").lastOutcome.status=="cancelled")
person("reloaded",bold)
local resumed=P.planConflict("reloaded",frame("reloaded"),offers())
P.conflictAdmission("reloaded",resumed.purposeId,{owner="SAO.Combat",id="reload-1"},resumed.selected)
clock=clock+3
check("lost_owner_reconciles_expired_admission_without_success",P.reconcileConflict("reloaded","body adopted without its previous runtime owner")
    and P.conflictSnapshot("reloaded").admission==nil and P.conflictSnapshot("reloaded").lastOutcome.status=="cancelled"
    and P.conflictSnapshot("reloaded").lastOutcome.observability=="runtime-owner-lost")

-- Same person, priors and distant contact; the native offer owns feasibility.
-- A ranged shot does not require the contact that an unavailable melee action
-- would require. This changes evaluated arguments, not coefficients or intent.
person("careful-shot",{selfPreservation=.5,aggression=.75,nerve=.7,discipline=.5,compassion=.5})
local shotFrame=frame("careful-shot");shotFrame.threat.distance=14
local shotOffers=offers()
shotOffers[1].objections={"exposure"}
shotOffers[2].available=false;shotOffers[2].objections={"bodily-harm"}
shotOffers[3].available=false;shotOffers[3].objections={"bodily-harm","exposure"}
shotOffers[4].objections={"exposure"}
local beforeShot=C.appraiseConflict("careful-shot",shotFrame,shotOffers)
check("distant_unavailable_contact_keeps_watch",beforeShot.selected=="watch")
shotOffers[3].nativeMode="ranged";shotOffers[3].available=true
shotOffers[3].reason="native ranged action available against this observed contact"
local afterShot=C.appraiseConflict("careful-shot",shotFrame,shotOffers)
check("native_range_changes_applicable_choice",afterShot.selected=="engage")
local function shotArgument(view)
    for _,option in ipairs(view.alternatives) do
        if option.id=="engage" then
            for _,value in ipairs(option.arguments) do
                if value.effect=="bodily-harm" and value.concern=="preserve-own-life" then return value,option end
            end
        end
    end
end
local shotRisk,shotAlternative=shotArgument(afterShot)
check("ranged_contact_requirement_is_not_invented",shotRisk and shotRisk.polarity=="unresolved"
    and shotRisk.premises[3].kind=="native-execution" and shotRisk.premises[3].mode=="ranged"
    and shotRisk.premises[3].contactRequired==false and shotRisk.premises[3].closeBelief==false)
local retainedObjection=false
for _,value in ipairs(shotAlternative.arguments) do
    if value.concern=="resolve-an-executor-objection" and value.effect=="exposure"
        and value.polarity=="opposes" then retainedObjection=true end
end
check("ranged_attempt_retains_risk_and_uncertainty",retainedObjection
    and shotRisk.reason:find("retaliate remains unresolved",1,true)
    and shotAlternative.expectedEffects[1].status=="possible")
shotFrame.threat.distance=2
local nearbyShot=C.appraiseConflict("careful-shot",shotFrame,shotOffers)
shotRisk=shotArgument(nearbyShot)
check("nearby_threat_still_exposes_ranged_actor",shotRisk and shotRisk.polarity=="opposes"
    and shotRisk.premises[3].contactRequired==false and shotRisk.premises[3].closeBelief==true
    and shotRisk.reason:find("nearby threat",1,true))
shotFrame.threat.distance=14;shotOffers[3].available=false
check("native_range_refusal_cannot_be_overruled",C.appraiseConflict("careful-shot",shotFrame,shotOffers).selected=="watch")

person('recognizer',{selfPreservation=.8,aggression=.2,nerve=.3,discipline=.7,compassion=.3})
local riskFrame=frame('recognizer');riskFrame.threat.distance=14;riskFrame.fear=.1
local riskOffers=offers();riskOffers[2].available=false;riskOffers[3].available=false
riskOffers[1].objections={'exposure'};riskOffers[4].objections={'exposure'};riskOffers[4].continuing=true
local beforeRisk=C.appraiseConflict('recognizer',riskFrame,riskOffers)
check('ordinary_distant_watch_unchanged',beforeRisk.selected=='watch')
local originalDistance=D.fleeDistance
D.fleeDistance=function()return 8 end
riskFrame.threat.form='recognized-form';riskFrame.threat.formPerformance=1
riskFrame.threat.attributeMutations={a=1,b=1,c=1,d=1}
local afterRisk=C.appraiseConflict('recognizer',riskFrame,riskOffers)
check('recognized_risk_changes_watch_judgment',afterRisk and afterRisk.selected=='withdraw')
local premise
for _,option in ipairs(afterRisk.alternatives) do
    for _,argument in ipairs(option.arguments) do
        for _,value in ipairs(argument.premises) do
            if value.kind=='personally-appraised-danger' then premise=value end
        end
    end
end
check('recognized_risk_retains_private_provenance',premise and premise.actorId=='recognizer'
    and premise.contactKey==riskFrame.threat.key and premise.provenance.knowledgeOwner=='recognizer'
    and premise.provenance.observationSource=='observed' and premise.withinConcern and premise.elevated)
check('recognized_appraisal_acquires_no_encounter',records.recognizer.mutationKnowledge==nil)
local learned={weight=1,source='lived',lastDay=4}
records.recognizer.mutationKnowledge={['recognized-form']=learned}
local learnedView=C.appraiseConflict('recognizer',riskFrame,riskOffers)
check('own_experience_changes_risk_premise',learnedView.selected=='watch' and records.recognizer.mutationKnowledge['recognized-form']==learned)
local priorKey=learnedView.evidenceKey
riskFrame.priorAction={id='watch',kind='watch',evidenceKey=priorKey}
check('same_private_risk_retains_continuity',C.appraiseConflict('recognizer',riskFrame,riskOffers).continuing)
records.recognizer.mutationKnowledge=nil
local reopened=C.appraiseConflict('recognizer',riskFrame,riskOffers)
check('own_changed_experience_reopens_choice',not reopened.continuing and reopened.evidenceKey~=priorKey
    and reopened.selected=='withdraw')
local riskOwner=SAO.PathogenPressure.appraise
for _,field in ipairs({'actorId','contactKey','source'}) do
    SAO.PathogenPressure.appraise=function(id,threat)local out=riskOwner(id,threat);out[field]='foreign';return out end
    local label=field=='actorId' and 'owner' or field=='contactKey' and 'contact' or 'source'
    check('foreign_risk_'..label..'_refused',C.appraiseConflict('recognizer',riskFrame,riskOffers)==nil)
end
SAO.PathogenPressure.appraise=riskOwner
local malformed=clone(riskFrame);malformed.threat.formPerformance=0/0
check('malformed_recognized_performance_refused',C.appraiseConflict('recognizer',malformed,riskOffers)==nil)
malformed=clone(riskFrame);malformed.threat.attributeMutations.a={private='object'}
check('malformed_recognized_attribute_refused',C.appraiseConflict('recognizer',malformed,riskOffers)==nil)
malformed=clone(riskFrame);malformed.threat.source='heard'
check('anonymous_sound_cannot_supply_recognized_form',C.appraiseConflict('recognizer',malformed,riskOffers)==nil)
malformed=clone(riskFrame);malformed.risk={actorId='recognizer',multiplier=100}
check('caller_cannot_author_risk',C.appraiseConflict('recognizer',malformed,riskOffers)==nil)
records.recognizer.mutationKnowledge={['recognized-form']=true}
check('malformed_saved_knowledge_stays_unfamiliar',C.appraiseConflict('recognizer',riskFrame,riskOffers).selected=='withdraw'
    and records.recognizer.mutationKnowledge['recognized-form']==true)
check('malformed_saved_knowledge_safe_in_loaded_distance',SAO.PathogenPressure.fleeDistance('recognizer',riskFrame.threat)>14)
records.recognizer.mutationKnowledge={['recognized-form']={weight=0/0,source={},lastDay={}}}
check('malformed_saved_knowledge_fields_do_not_supply_experience',C.appraiseConflict('recognizer',riskFrame,riskOffers).selected=='withdraw')
records.recognizer.mutationKnowledge={['recognized-form']={weight=1,source='lived'}}
person('stranger');riskFrame.threat.id='stranger'
check('explicit_actor_owns_pathogen_adjustment',SAO.PathogenPressure.multiplier(riskFrame.threat,'recognizer')<1
    and SAO.PathogenPressure.multiplier(riskFrame.threat)>1 and records.stranger.mutationKnowledge==nil)
D.fleeDistance=originalDistance
__result="PASS conflict reasoning "..checks.." checks"
