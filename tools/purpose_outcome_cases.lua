-- Appended to ordinary_purpose_cases.lua: same actual Controller dispatch and
-- deterministic private records, with native owner production checked separately.
local studyReceipts, cookReceipts, workReceipts = {}, {}, {}
SAO.Study.outcome=function(id,seq)
    local r=studyReceipts[seq]; return r and r.actorId==id and r or nil
end
SAO.Cooking.outcome=function(id,seq)
    local r=cookReceipts[seq]; return r and r.actorId==id and r or nil
end
SAO.Organization.fulfilledWorkOutcome=function(id,seq)
    local r=workReceipts[seq]; return r and r.actorId==id and r or nil
end
local function readReceipt(domain,book)
    local r={actorId="runner",sequence=1,workId="study/1",status="completed",
        nativeOwner="ISReadABook.complete",token="reading:progressed",itemId=7,
        itemType=book or "Base.BookCooking1",bookSkill=domain or "Cooking",
        pagesBefore=0,pagesAfter=100,totalPages=100,beganAt=11,atHours=12}
    studyReceipts[1]=r; return r
end
local function studyChoice()
    reset();studyReceipts={};cookReceipts={};workReceipts={}
    needs.fatigue=.85;traits.initiative=.49
    manual.getFullType=function()return "Base.BookCooking2"end
    SAO.Cognition.configure(1,12,3)
end
local function prediction(kind)
    for _,model in ipairs(rec.ordinaryPurposeDecision.interpretations.models) do
        if model.modelId==rec.ordinaryPurposeDecision.interpretations.selectedModelId then
            for _,row in ipairs(model.ranked) do
                for _,p in ipairs(row.predictions) do if p.kind==kind then return p end end
            end
        end
    end
end
studyChoice();local before=choose();local receipt=readReceipt()
local learned,why=SAO.Cognition.studyOutcome("runner",receipt);local after=act()
if before~="recovery" or after~="study" or not learned then error("PURPOSE:study_receipt_changes_real_later_choice "..tostring(before).." -> "..tostring(after).." "..tostring(learned).." "..tostring(why)) end
check("study_receipt_changes_real_later_choice",learned==true
    and before=="recovery" and after=="study" and admitted=="study")
local p=prediction("study")
check("study_transfer_retains_measured_provenance",p and p.basis=="related-experience"
    and p.evidenceIds[1]=="study/runner/1" and p.sourceId=="manual:Cooking"
    and p.itemType=="Base.BookCooking2" and p.probability>.5)
check("study_page_fact_does_not_grant_competence",not rec.proceduralPlanning
    and rec.cognition.experiences[1].afterValue==100 and rec.cognition.experiences[1].skill==nil)
rec=__nativeRoundtrip(rec);agent={rec=rec,state="IDLE"};SAO.Controller.agents.runner=agent;study=false
check("native_reload_retains_actual_study_choice",act()=="study" and admitted=="study")
local n=#rec.cognition.experiences;hours=13
check("study_replay_preserves_acquisition_time",SAO.Cognition.studyOutcome("runner",receipt)==true
    and #rec.cognition.experiences==n and rec.cognition.experiences[1].worldHours==12)
studyChoice();receipt=readReceipt("Woodwork","Base.BookCarpentry1")
check("unrelated_reading_does_not_change_choice",SAO.Cognition.studyOutcome("runner",receipt)==true and act()=="recovery")
studyChoice();receipt=readReceipt();SAO.Cognition.configure(0,12,3)
check("ordinary_model_retains_exact_title_boundary",SAO.Cognition.studyOutcome("runner",receipt)==true and act()=="recovery")
studyChoice();receipt=readReceipt();receipt.actorId="other"
check("other_person_pages_cannot_change_choice",not SAO.Cognition.studyOutcome("runner",receipt) and act()=="recovery")
studyChoice();receipt=readReceipt();studyReceipts={}
check("unowned_reading_receipt_refused",not SAO.Cognition.studyOutcome("runner",receipt) and rec.cognition==nil)
studyChoice();receipt=readReceipt();local forged={};for k,v in pairs(receipt)do forged[k]=v end;forged.pagesAfter=101
check("changed_reading_receipt_refused",not SAO.Cognition.studyOutcome("runner",forged) and rec.cognition==nil)
studyChoice();receipt=readReceipt();receipt.status="interrupted"
check("interrupted_reading_is_not_success",not SAO.Cognition.studyOutcome("runner",receipt) and act()=="recovery")
studyChoice();receipt=readReceipt();receipt.atHours=13
check("future_reading_cannot_change_choice",not SAO.Cognition.studyOutcome("runner",receipt) and act()=="recovery")
studyChoice();receipt=readReceipt();receipt.pagesBefore=100
check("unchanged_pages_are_not_completed_learning",not SAO.Cognition.studyOutcome("runner",receipt))
studyChoice();SAO.Cognition.studyOutcome("runner",readReceipt());local fact=rec.cognition.experiences[1]
rec.cognition=nil
check("generic_ledger_cannot_forge_reading",not SAO.Cognition.experience("runner",fact) and rec.cognition==nil)

local means={sourceId="oven-1",itemId=71,itemType="Base.MuttonChop"}
SAO.Cooking.expectationOffer=function()return means end
local capturedOptions
SAO.Cooking.begin=function(_,_,options)capturedOptions=options;admitted="practice";return true,{id="cook/1"}end
local function practiceChoice()
    reset();manual=nil;studyReceipts={};cookReceipts={};workReceipts={}
    practice={id="retained-practice",status="maintained"};needs.fatigue=.86;traits.initiative=.36
    SAO.Cognition.configure(1,12,3);capturedOptions=nil
end
local function prepared(source)
    local r={id="cooking/runner/1",sequence=1,actorId="runner",itemId=71,itemType="Base.MuttonChop",
        sourceId=source or "oven-1",startedAt=11,atHours=12,status="completed",
        detail="native-food-cooked-and-retrieved",nativeCredit="cooking/runner/1",
        retrieved=true,heatObserved=true,beforeCookingTime=0,afterCookingTime=51}
    cookReceipts[1]=r;return r
end
practiceChoice();before=choose()
check("native_preparation_changes_actual_practice",SAO.Cognition.preparationOutcome("runner",prepared())==true
    and before=="recovery" and act()=="practice" and admitted=="practice")
check("practice_dispatch_revalidates_selected_means",capturedOptions and capturedOptions.expectedSourceId=="oven-1"
    and capturedOptions.acquiredItemId==71 and practice.status=="maintained")
p=prediction("prepare")
check("practice_uses_physical_food_outcome",p and p.sourceId=="oven-1" and p.itemType=="Base.MuttonChop"
    and p.evidenceIds[1]=="cooking/runner/1" and p.basis=="exact-experience")
practiceChoice();receipt=prepared();cookReceipts={}
check("unowned_preparation_cannot_teach",not SAO.Cognition.preparationOutcome("runner",receipt) and rec.cognition==nil)
practiceChoice();receipt=prepared();receipt.retrieved=false
check("cooked_flag_without_retrieval_cannot_teach",not SAO.Cognition.preparationOutcome("runner",receipt) and act()=="recovery")
practiceChoice();SAO.Cognition.preparationOutcome("runner",prepared())
local forgedPreparation=__nativeRoundtrip(rec.cognition.experiences[1])
rec.cognition=nil;cookReceipts={}
local forgedAccepted=SAO.Cognition.experience("runner",forgedPreparation)
local forgedChoice=act()
check("generic_preparation_cannot_change_actual_choice",not forgedAccepted and rec.cognition==nil
    and forgedChoice=="recovery" and admitted=="sleep")

local function workChoice()
    reset();studyReceipts={};cookReceipts={};workReceipts={};commitment()
    traits.compassion=.15;traits.initiative=.5;SAO.Cognition.configure(1,12,3)
end
local function performed(kind)
    local r={actorId="runner",sequence=1,commitmentId="prior-accepted-work",workKind=kind or "prepare",
        nativeReceiptId="native/prior/1",acceptedAt=11,atHours=12,status="completed"}
    workReceipts[1]=r;return r
end
workChoice();before=choose()
check("own_performed_responsibility_changes_dispatch",SAO.Cognition.commitmentOutcome("runner",performed())==true
    and before=="study" and act()=="commitment" and capturedOptions.commitmentId=="c/1")
p=prediction("commitment")
check("responsibility_prediction_is_kind_scoped",p and p.condition=="prepare" and p.basis=="related-experience"
    and p.evidenceIds[1]=="commitment/runner/1")
rec=__nativeRoundtrip(rec);agent={rec=rec,state="IDLE"};SAO.Controller.agents.runner=agent
check("performed_responsibility_survives_native_reload",act()=="commitment" and capturedOptions.commitmentId=="c/1")
workChoice();receipt=performed("deliver")
check("delivery_success_does_not_teach_preparation",SAO.Cognition.commitmentOutcome("runner",receipt)==true and act()=="study")
workChoice();receipt=performed();receipt.actorId="other"
check("foreign_completed_work_does_not_teach",not SAO.Cognition.commitmentOutcome("runner",receipt) and act()=="study")
workChoice();receipt=performed();workReceipts={}
check("unowned_completed_work_does_not_teach",not SAO.Cognition.commitmentOutcome("runner",receipt) and rec.cognition==nil)
workChoice();receipt=performed();receipt.acceptedAt=13
check("future_assent_cannot_authenticate_past_work",not SAO.Cognition.commitmentOutcome("runner",receipt) and act()=="study")
workChoice();SAO.Cognition.commitmentOutcome("runner",performed());fact=rec.cognition.experiences[1];rec.cognition=nil
check("generic_ledger_cannot_forge_fulfilled_work",not SAO.Cognition.experience("runner",fact) and rec.cognition==nil)
__result="PASS purpose outcomes "..checks
