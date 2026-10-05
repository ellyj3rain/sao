-- Production Controller/Cognition/Models/Needs with controlled native receivers.
local checks=0
local function check(name, value)
    if not value then error("PURPOSE:"..name) end
    checks=checks+1
end
local hours=12
local rec, agent, body, manual, traits, needs, commitments, study, ready
local admitted, interrupted, owned, permission, bleeding, threat, hungerAfter, dark
local cancellationRefused, practice
local foodCarried, waterCarried, foodRefused, studyRefused, admittedCommitment
local stores={}
ModData={get=function(k)return stores[k]end,getOrCreate=function(k)
    stores[k]=stores[k] or {};return stores[k]end}
SAO.Hash={unit=function()return 0.2 end}
SAO.History.countyHours=function()return hours end
SAO.History.literacyOf=function()return "fluent"end
SAO.Identity={get=function(id)return id=="runner" and rec or nil end}
SAO.Disposition.traits=function()return traits end
SAO.Disposition.drinkAt=function()return 0.5 end
SAO.Disposition.eatAt=function()return 0.5 end
SAO.Labor={capabilityOf=function()return {}end}
SAO.Body.get=function()return body end
SAO.Perception.believedThreatCount=function()return threat and 1 or 0 end
SAO.Standing.insideClaim=function()return permission end
SAO.Standing.mayEnterBelieved=function()return permission end
SAO.Standing.mayAttemptBelieved=function()return permission end
SAO.Needs.busy=function()return study or owned end
SAO.Needs.bleeding=function()return bleeding and 1 or 0 end
SAO.Needs.cold=function()return 0 end
SAO.Needs.read=function()return needs end
SAO.Needs.workAvailable=function()return not owned end
SAO.Needs.beginRecovery=function(_,_,kind)admitted=kind;return true end
SAO.Needs.eatCarried=function()if foodRefused then return false end;admitted="food";return true end
SAO.Needs.drinkCarried=function()admitted="water";return true end
SAOJavaBridge.isShell=function()return true end
SAOJavaBridge.findCarriedDrink=function()return waterCarried and manual end
SAOJavaBridge.findCarriedFood=function()return foodCarried and manual end
SAOJavaBridge.sickness=function()return 0 end
-- Native visible-placement admission is controlled independently of choice.
SAOJavaBridge.recoveryPlaces=function()return {actorId="runner",status="available",
    places={{key="fixture-ground",kind="ground",x=0,y=0,z=0,available=true}}}end
SAOJavaBridge.cookingOffers=function()return {appliances={{sourceX=0,sourceY=0}},foods={{carried=true}}}end
SAO.Standing.mayTakeCurrent=function()return true end
SAO.Organization={activeCommitments=function()return commitments end,
    workPlan=function(_,id)return {proposal={cooperative=true},intendedStepId="step",
        privateProcedure={beliefs={step={id="step",verb="prepare"}}}}end,
    routeRetryReady=function()return ready end,
    noteWorkAdmission=function()return true end}
SAO.Cooking={begin=function(_,_,options)admitted="commitment";admittedCommitment=options.commitmentId;return true,{id="cook/1"}end}
SAO.ProceduralPlanning={studyDemand=function()return rec.demand end,
    resourceDemand=function()return nil end,pending=function()return practice,
        practice and {id="practice-step",owner="Cooking",verb="practice",target="Cooking"}end,
    interrupt=function()end}
SAO.Study={offer=function()return manual end,active=function()return study end,
    begin=function()if dark or studyRefused then return false end;study=true;admitted="study";return true end,
    interrupt=function()if cancellationRefused then return false end
        interrupted=true;study=false;return true end}
ISTimedActionQueue={queues={},hasAction=function(action)return study and action~=nil end}
SAO.Voice={onEvent=function()end}
SAO.Gesture={standUp=function()end}
SAO.Locomotion={jobs={},cancel=function()end}
local function reset()
    hours=12;admitted=nil;interrupted=false;owned=false;permission=true;bleeding=false;threat=false;dark=false
    stores={};study=false;commitments={};ready=true;cancellationRefused=false;practice=nil
    foodCarried=true;waterCarried=false;foodRefused=false;studyRefused=false;admittedCommitment=nil
    traits={initiative=.5,discipline=.5,compassion=.5,selfPreservation=.5}
    needs={hunger=.1,thirst=.1,fatigue=.5,endurance=.8}
    rec={id="runner",bodyOwnerToken="token"}
    agent={rec=rec,state="IDLE",nextPillAt=9999}
    body={getModData=function()return {SAOPersonId="runner",SAOExternalToken="token"}end,
        getVehicle=function()return nil end,
        getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end,
        isExistInTheWorld=function()return true end,isDead=function()return false end,
        isAsleep=function()return false end,tooDarkToRead=function()return dark end}
    manual={getSkillTrained=function()return "Cooking"end,getFullType=function()return "Base.BookCooking1"end}
    SAO.Body.active={runner=body};SAO.Body.foreign={};SAO.Controller.agents={runner=agent}
    SAO.Perception.beliefs={runner={known={},people={}}}
    ISTimedActionQueue.queues={}
    SAO.Cognition.configure(0,12,3)
end
local function choose()
    return SAO.Controller.chooseOrdinaryPurpose("runner",agent,body,100,needs)
end
local function act()
    local kind, offer=choose()
    if kind then SAO.Controller.dispatchOrdinaryPurpose("runner",agent,body,100,needs,kind,offer) end
    return kind
end
local function commitment()
    commitments={{id="c/1",actorId="runner",acceptedAt=11,status="accepted",matter="cooperative-action",work={}}}
end
reset()
check("personal_study_dispatched",act()=="study" and admitted=="study")
check("choice_is_not_completion",rec.ordinaryPurposeDecision.status=="admitted" and rec.cognition==nil)
check("study_prediction_honestly_unknown",rec.ordinaryPurposeDecision.interpretations.models[1].ranked[1].predictions[1].basis=="unknown")
reset();needs.fatigue=.82;traits.initiative=.15;traits.discipline=.15
check("less_valued_study_yields_to_body",act()=="recovery" and admitted=="sleep")
reset();needs.fatigue=.82;traits.initiative=.85;traits.discipline=.85
check("person_value_changes_actual_dispatch",act()=="study" and admitted=="study")
reset();needs.fatigue=.82;traits.initiative=.85;traits.discipline=.85
check("actual_controller_uses_shared_choice",SAO.Controller.__playerProbeDecide("runner",agent,body,100,needs)==true and admitted=="study")
reset();needs.fatigue=.82;traits.initiative=.85;traits.discipline=.85
SAO.Controller.__fleeProbeDecide("runner",agent,body)
check("live_caller_preserves_chosen_study",admitted=="study" and study and not interrupted)
reset();commitment();traits.compassion=.85
check("accepted_ready_responsibility_dispatched",act()=="commitment" and admitted=="commitment")
reset();commitment();commitments[1].actorId="other"
check("foreign_assent_cannot_compete",act()=="study")
reset();commitment();commitments[1].acceptedAt=13
check("future_assent_cannot_compete",act()=="study")
reset();commitment();ready=false
check("unready_commitment_cannot_displace_study",act()=="study")
reset();commitment();commitments[1].work.owner="foreign"
check("foreign_execution_owner_cannot_compete",act()=="study")
reset();needs.hunger=.65
local selected=choose()
check("ordinary_need_changes_intent",selected=="food")
check("actual_need_dispatch_uses_selected_intent",SAO.Controller.__playerProbeDecide("runner",agent,body,100,needs)==true and admitted=="food")
check("food_dispatch_records_admission",rec.ordinaryPurposeDecision.status=="admitted")
reset();needs.hunger=.65;needs.thirst=.55;foodCarried=false;waterCarried=true;agent.nextForageAt=1000
SAO.Controller.__fleeProbeDecide("runner",agent,body)
check("deferred_food_does_not_hide_carried_water",admitted=="water" and rec.ordinaryPurposeDecision.selected=="water")
reset();needs.hunger=.65;needs.thirst=.55;foodCarried=false;waterCarried=false;agent.nextForageAt=1000
check("water_keeps_independent_retry_clock",choose()=="water")
reset();needs.hunger=.65;needs.thirst=.55;foodRefused=true;waterCarried=true;agent.nextForageAt=1000
SAO.Controller.__fleeProbeDecide("runner",agent,body)
check("failed_food_reconsiders_carried_water",admitted=="water" and rec.ordinaryPurposeDecision.selected=="water"
    and rec.ordinaryPurposeDecision.unavailable[1]=="food")
reset();needs.fatigue=.8;studyRefused=true
SAO.Controller.__fleeProbeDecide("runner",agent,body)
check("failed_study_reconsiders_recovery",admitted=="sleep" and rec.ordinaryPurposeDecision.unavailable[1]=="study")
reset();needs.hunger=.9
check("urgent_need_keeps_existing_owner",choose()==nil)
reset();needs.fatigue=.99
check("extreme_recovery_keeps_existing_owner",choose()==nil)
reset();bleeding=true
check("medical_need_keeps_existing_owner",choose()==nil)
reset();threat=true
check("threat_keeps_existing_owner",choose()==nil)
reset();owned=true
check("native_work_is_not_preempted",choose()==nil)
reset();SAO.Body.foreign.runner=body
check("foreign_body_cannot_choose",choose()==nil)
reset();SAO.Body.active.runner={}
check("replacement_body_cannot_choose",choose()==nil)
reset();rec.demand={id="study-purpose",bookSkill="Cooking",status="maintained"}
study=true
check("selected_study_keeps_unfinished_purpose",act()=="study" and not interrupted and rec.demand.status=="maintained")
local saved=rec;SAO.Controller.agents={};agent={rec=saved,state="IDLE"};SAO.Controller.agents.runner=agent;study=false
check("reload_reconsiders_same_unfinished_purpose",act()=="study" and rec.demand.id=="study-purpose")
local function readingWithCommitment()
    reset();commitment();traits.compassion=.85;study=true
    rec.demand={id="unfinished-study",bookSkill="Cooking",status="maintained"}
    rec.studyWork={id="reading-1",purposeId="unfinished-study",status="reading"}
    ISTimedActionQueue.queues[body]={queue={{workId="reading-1",personId="runner"}}}
end
readingWithCommitment()
check("chosen_responsibility_releases_owned_study",act()=="commitment" and interrupted and admitted=="commitment"
    and rec.demand.status=="maintained" and rec.demand.id=="unfinished-study")
readingWithCommitment();cancellationRefused=true
check("refused_study_cancellation_holds_owner",act()=="commitment" and admitted==nil and study
    and agent.studyCancellationPending~=nil and rec.ordinaryPurposeDecision.status=="awaiting-release")
readingWithCommitment();cancellationRefused=true
commitments[2]={id="c/2",actorId="runner",acceptedAt=11,status="in-progress",matter="cooperative-action",work={}}
act()
check("pending_cancellation_retains_selected_identity",agent.studyCancellationPending.commitmentId=="c/2")
cancellationRefused=false;study=false
check("delayed_release_dispatches_selected_not_first",SAO.Controller.preemptStudyForCoordination("runner",agent,body)
    and admittedCommitment=="c/2" and rec.ordinaryPurposeDecision.status=="admitted")
readingWithCommitment();cancellationRefused=true;act();commitments={};study=false;cancellationRefused=false
check("removed_delayed_commitment_is_not_replaced",SAO.Controller.preemptStudyForCoordination("runner",agent,body)
    and admitted==nil and rec.ordinaryPurposeDecision.status=="unavailable")
readingWithCommitment();ISTimedActionQueue.queues[body].queue[2]={foreign=true}
check("foreign_queued_action_is_not_cancelled",act()=="commitment" and not interrupted and study and admitted==nil
    and rec.ordinaryPurposeDecision.status=="unavailable")
reset();manual=nil;practice={id="my-practice",status="maintained"}
check("retained_practice_reaches_native_owner",act()=="practice" and agent.state=="COOK" and practice.status=="maintained")
reset();manual=nil;practice={id="old-practice",status="maintained"}
local kind, offer=choose();practice={id="replacement-practice",status="maintained"}
check("changed_practice_does_not_inherit_selection",not SAO.Controller.dispatchOrdinaryPurpose("runner",agent,body,100,needs,kind,offer)
    and admitted==nil and rec.ordinaryPurposeDecision.status=="unavailable")
reset();manual=nil;permission=false
local kind, offer=choose()
check("continue_does_not_hold_idle",kind=="continue" and not SAO.Controller.dispatchOrdinaryPurpose("runner",agent,body,100,needs,kind,offer))
reset();local kind, offer=choose();dark=true
check("failed_admission_is_unavailable",not SAO.Controller.dispatchOrdinaryPurpose("runner",agent,body,100,needs,kind,offer)
    and rec.ordinaryPurposeDecision.status=="unavailable")
reset();needs.fatigue=.87;traits.initiative=.5;traits.discipline=.5
local before=choose()
-- Needs owns these controlled measured receipts. Cognition rereads its owner;
-- native production of the measurements remains covered by loaded_recovery_test.
rec.recoveryExperiences={}
for i=1,6 do
    local receipt={actorId="runner",kind="recovery-outcome",sequence=i,atHours=hours,
        actionKind="sleep",beforeValue=.9,afterValue=.9,durationHours=.2,succeeded=false}
    rec.recoveryExperiences[i]=receipt
    check("owner_receipt_admitted_"..i,SAO.Cognition.behaviorOutcome("runner",receipt)==true)
end
local after=act()
check("contrary_recovery_changes_actual_dispatch",before=="recovery" and after=="study" and admitted=="study")
__result="PASS ordinary purpose "..checks
