-- Existing SourceUse transport receivers are controlled; its ledger and Planner run.
local A,P,W=SAO.LeisureAcquisition,SAO.ProceduralPlanning,SAO.WorldSources
local checks=0
local function check(name,value) assert(value,"D2_ACQUISITION:"..name);checks=checks+1;print("CASE "..name) end
local function copy(v)if type(v)~="table"then return v end;local o={}for k,x in pairs(v)do o[k]=copy(x)end;return o end
local requirement={owner="SAO.LeisureGames",family="games",activity="draw-card",sourceId="native:RecipeCodeOnCreate.drawRandomCard",
    revision=string.rep("a",64),requirementId="Base.DrawRandomCard:input:0",role="playable-item",itemType="Base.CardDeck"}
local place={id=42,cx=8,cy=8,z=0,minX=8,minY=8,maxX=16,maxY=16}
local body,purpose,row
local function reset(ground)
    __hours=10;__stores={};__records={a={id="a"},b={id="b"}};__known={};__places={[42]=place}
    body=__newBody(8,8);__bodies={a=body,b=__newBody(8,8)};SAO.Body.active=__bodies
    body.getModData=function()return {SAOPersonId="a"}end
    __bodies.b.getModData=function()return {SAOPersonId="b"}end
    SAO.Needs.ownsRecoveryBody=function(id,b)return __bodies[id]==b and b:getModData().SAOPersonId==id end
    SAO.Needs.workAvailable=function()return not __busy end
    SAO.History.countyHours=function()return __hours end;SAO.History.ticks=function()return 600 end
    SAO.Standing.mayAttemptBelieved=function()return __standingAllowed end
    SAOJavaBridge.leisureMaterialRequirements=function(_,b,t)
        if b~=body or t~="Base.CardDeck"then return {}end;return {copy(requirement)}end
    SAOJavaBridge.privateCarriedItems=function()return {size=function()return __carriedItem and 1 or 0 end,
        get=function()return __carriedItem end}end
    SAOJavaBridge.carriedWorldTransferItem=function()return __transfer end
    SAO.Controller.agents={a={rec=__records.a,state="IDLE"}}
    SAO.LeisureGames={}
    __busy=false;__standingAllowed=true;__queueReject=false;__routeAllowed=true
    __sourceItem={getID=function()return 11 end,getFullType=function()return "Base.CardDeck"end}
    __sourceContainer={};__permissionContainer={};__worldItem={};__carriedItem=nil
    __targetAnswer="READY:8:8:0:8:8:0";__bindAnswer="BOUND:8:8:0"
    local before=ground and __groundBefore or __before
    __observeText=before;__transfer=ground and __groundTransfer or __containerTransfer
    assert(W.applySnapshot(W.parse(before)))
    local p=ground and {id="source:G:cards",sourceId="G:cards",cx=8,cy=8,z=0,minX=8,minY=8,maxX=9,maxY=9} or place
    local facts,quantities,revision
    if ground then facts={ ["G:cards"]=W.beliefFact("G:cards","visible-ground") };quantities={["leisure-material"]=true};revision="G:cards@r1"
    else quantities,revision,_,facts=W.beliefSnapshot(p)end
    __known.a={[p.id]={cx=p.cx,cy=p.cy,z=0,sourceId=p.sourceId,minX=p.minX,minY=p.minY,maxX=p.maxX,maxY=p.maxY,
        sources=quantities,sourceFacts=facts,sourceRevision=revision}}
    SAO.Perception.learnInspectedSource=function()return true end
    return p
end
for _,ground in ipairs({false,true})do
    local p=reset(ground);local rows=A.offers("a",body);row=rows[1]
    check("exact_private_"..tostring(ground),#rows==1 and row.itemType=="Base.CardDeck" and row.option.parameters.itemId==11)
    check("foreign_mind_"..tostring(ground),#A.offers("b",__bodies.b)==0)
    check("comparison_no_admission_"..tostring(ground),__records.a.proceduralPlanning==nil and not __records.a.worldSourceReservation)
    check("selected_source_admitted_"..tostring(ground),A.begin("a",body,row)==true)
    local reservation=W.pendingActionFor("a");purpose=__records.a.proceduralPlanning.purposes[reservation.purposeId]
    check("pickup_not_activity_"..tostring(ground),purpose.cursor==1 and not purpose.leisure and not purpose.hobby)
    check("existing_transfer_owner_"..tostring(ground),SAO.SourceUse.onMovementDone("a",body,"arrived")=="using"
        and __queued.kind==(ground and "grab"or"transfer"))
    __carriedItem=__sourceItem;__busy=false;__observeText=ground and __groundAfter or __after
    local status=SAO.SourceUse.tick("a",body);local receipt=W.actionOutcome(reservation.id,"a")
    check("exact_custody_receipt_"..tostring(ground),status=="completed" and receipt.status=="completed" and receipt.operation=="acquire"
        and receipt.measurement=="native-item-transfer" and receipt.observedQuantity==1 and receipt.itemId==11)
    check("same_purpose_after_transfer_"..tostring(ground),P.consumeSourceResult(receipt) and purpose.cursor==2 and purpose.leisureAcquisition.resultId==receipt.reservationId)
    local events=#purpose.events
    check("receipt_replay_"..tostring(ground),P.consumeSourceResult(receipt) and purpose.cursor==2 and #purpose.events==events)
    local offer={itemId=11,itemType="Base.CardDeck",itemKey="item:Base.CardDeck:11",activity="draw-card"}
    check("original_hobby_requery_"..tostring(ground),A.acquiredPurpose("a",body,"SAO.LeisureGames",offer).id==purpose.id)
    local wrong=copy(offer);wrong.itemId=12;wrong.itemKey="item:Base.CardDeck:12"
    check("replacement_item_refused_"..tostring(ground),A.acquiredPurpose("a",body,"SAO.LeisureGames",wrong)==nil)
    check("replacement_owner_refused_"..tostring(ground),A.acquiredPurpose("a",body,"SAO.LeisureArt",offer)==nil)
    local bound=P.planLeisure("a",{activity="draw-card",activityKey="games:draw-card:11",owner="SAO.LeisureGames",itemKey=offer.itemKey,
        acquiredPurposeId=purpose.id,affordance=requirement.sourceId,atLocation=true,locationKey="8:8:0"})
    check("native_hobby_retains_original_purpose_"..tostring(ground),bound==purpose and purpose.steps[1].id=="acquire-leisure-item"
        and purpose.steps[1].status=="completed" and purpose.steps[purpose.cursor].id=="perform-activity" and not purpose.hobby)
end
do
    reset(false);row=A.offers("a",body)[1];__standingAllowed=false
    check("permission_refuses_no_custody",not A.begin("a",body,row) and not __records.a.worldSourceReservation)
    __standingAllowed=true;__bindAnswer="REVISION_CHANGED"
    local started=A.begin("a",body,row)
    check("changed_source_refuses_exact_transfer",started and SAO.SourceUse.onMovementDone("a",body,"arrived")=="failed" and __carriedItem==nil)
end
do
    reset(false);row=A.offers("a",body)[1]
    check("foreign_body_refused",not A.begin("a",__bodies.b,row))
    check("forged_requirement_refused",P.planLeisureAcquisition("a",body,row.option,{owner="SAO.LeisureGames",activity="invented"},row.place)==nil)
    assert(A.begin("a",body,row));local reservation=W.pendingActionFor("a");purpose=__records.a.proceduralPlanning.purposes[reservation.purposeId]
    SAO.SourceUse.onMovementDone("a",body,"arrived");SAO.SourceUse.interrupt("a",body,"urgent-need")
    local receipt=W.actionOutcome(reservation.id,"a")
    check("partial_interruption_retains_prerequisite",P.consumeSourceResult(receipt) and not purpose.leisureAcquisition.resultId and purpose.cursor==1)
    check("interruption_does_not_invent_hobby",not purpose.leisure and not purpose.hobby and __carriedItem==nil)
    __hours=11;__busy=false
    local retry=A.offers("a",body)[1]
    check("interrupted_acquisition_resumes_same_purpose",retry and A.begin("a",body,retry) and W.pendingActionFor("a").purposeId==purpose.id)
end
do
    reset(true);local fact=__known.a["source:G:cards"].sourceFacts["G:cards"]
    check("ground_has_no_hidden_uses",fact.visibleItem.type=="Base.CardDeck" and fact.candidates["leisure-material"].uses==nil)
    requirement.role="material"
    check("station_material_needs_acquired_context",#A.offers("a",body)==0)
    SAO.LeisureGames.materialRequirementAvailable=function()return true end
    check("acquired_station_admits_its_material",#A.offers("a",body)==1)
    requirement.role="playable-item"
end
do
    reset(false);requirement.itemType="Base.Dice"
    check("preview_type_cannot_substitute_known_item",#A.requirements("a",body,"Base.CardDeck")==0)
    requirement.itemType="Base.CardDeck"
    assert(W.applySnapshot(W.parse(__changedBefore)))
    check("changed_private_revision_refused",#A.offers("a",body)==0)
end
do
    reset(false);local stale=assert(A.offers("a",body)[1]);local saved=requirement.revision
    requirement.revision=string.rep("b",64)
    check("selected_requirement_revision_cannot_change",not A.begin("a",body,stale) and not __records.a.worldSourceReservation)
    requirement.revision=saved
    assert(W.applySnapshot(W.parse(__changedBefore)))
    local q,r,_,facts=W.beliefSnapshot(place)
    __known.a[42].sources=q;__known.a[42].sourceRevision=r;__known.a[42].sourceFacts=facts
    check("selected_source_revision_cannot_change",#A.offers("a",body)==1 and not A.begin("a",body,stale)
        and not __records.a.worldSourceReservation)
end
do
    reset(false);requirement.role="material";SAO.LeisureGames.materialRequirementAvailable=function()return true end
    row=A.offers("a",body)[1];assert(A.begin("a",body,row));local first=W.pendingActionFor("a")
    purpose=__records.a.proceduralPlanning.purposes[first.purposeId]
    SAO.SourceUse.onMovementDone("a",body,"arrived");__carriedItem=__sourceItem;__busy=false;__observeText=__after
    assert(SAO.SourceUse.tick("a",body)=="completed");assert(P.consumeSourceResult(W.actionOutcome(first.id,"a")))
    local quantities,revision,_,facts=W.beliefSnapshot(place)
    __known.a[42].sources=quantities;__known.a[42].sourceRevision=revision;__known.a[42].sourceFacts=facts
    requirement.itemType="Base.Dice";requirement.requirementId="second-source-material"
    SAOJavaBridge.leisureMaterialRequirements=function(_,b,t)return b==body and t==requirement.itemType and {copy(requirement)}or{}end
    __sourceItem={getID=function()return 12 end,getFullType=function()return "Base.Dice"end};__carriedItem=nil
    __transfer="T|operation=acquire|source=C:cards:0|id=12|type=Base.Dice|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material"
    local nextRow=A.offers("a",body)[1];assert(nextRow and A.begin("a",body,nextRow))
    local second=W.pendingActionFor("a")
    check("station_materials_share_original_purpose",second.purposeId==first.purposeId and #__records.a.proceduralPlanning.order==1
        and #purpose.leisureAcquisitions==1 and purpose.leisureAcquisitions[1].resultId==first.id)
    SAO.SourceUse.onMovementDone("a",body,"arrived");SAO.SourceUse.interrupt("a",body,"urgent-need")
    local failed=W.actionOutcome(second.id,"a");assert(P.consumeSourceResult(failed))
    check("second_material_failure_preserves_original_supply",failed.status~="completed" and not purpose.leisureAcquisition.resultId
        and purpose.leisureAcquisitions[1].resultId==first.id and purpose.steps[1].status=="completed")
    __busy=false
    check("second_material_failure_obeys_retry_delay",#A.offers("a",body)==0)
    __hours=11;nextRow=A.offers("a",body)[1];assert(nextRow and A.begin("a",body,nextRow))
    second=W.pendingActionFor("a")
    check("second_material_retry_retains_original_chain",second.purposeId==first.purposeId and #__records.a.proceduralPlanning.order==1
        and #purpose.leisureAcquisitions==1 and W.actionOutcome(failed.reservationId,"a").status~="completed")
    SAO.SourceUse.onMovementDone("a",body,"arrived");__carriedItem=__sourceItem;__busy=false;__observeText=__afterBoth
    assert(SAO.SourceUse.tick("a",body)=="completed");assert(P.consumeSourceResult(W.actionOutcome(second.id,"a")))
    check("station_materials_preserve_exact_receipts",purpose.leisureAcquisition.resultId==second.id and purpose.cursor==3
        and purpose.steps[1].status=="completed" and purpose.steps[2].status=="completed")
    local offer={activity="draw-card",materials={one={id="11",itemType="Base.CardDeck"},two={id="12",itemType="Base.Dice"}}}
    local acquired=A.acquiredPurpose("a",body,"SAO.LeisureGames",offer)
    local bound=P.planLeisure("a",{activity="draw-card",activityKey="station:exact",owner="SAO.LeisureGames",
        acquiredPurposeId=acquired.id,affordance=requirement.sourceId,atLocation=true,locationKey="8:8:0"})
    check("station_use_retains_all_completed_prerequisites",bound==purpose and purpose.steps[1].status=="completed"
        and purpose.steps[2].status=="completed" and purpose.steps[purpose.cursor].id=="perform-activity" and not purpose.hobby)
    requirement.role="playable-item";requirement.itemType="Base.CardDeck"
end
do
    reset(false)
    requirement.role="material";requirement.activity="arcade-ArcadeStreetFighter"
    requirement.sourceId="ProjectArcade:ProjectArcade_PlayArcadeTimedAction:ArcadeStreetFighter"
    requirement.requirementId="arcade-currency:ArcadeStreetFighter";requirement.itemType="Base.SilverCoin"
    local carried=0
    SAO.LeisureGames.materialRequirementAvailable=function(_,_,r)
        return r.activity==requirement.activity and carried<2
    end
    SAOJavaBridge.leisureMaterialRequirements=function(_,b,t)
        return b==body and t=="Base.SilverCoin" and {copy(requirement)} or {}
    end
    __observeText=__arcadeBefore
    assert(W.applySnapshot(W.parse(__arcadeBefore)),"arcade snapshot")
    local function refreshBelief()
        local quantities,revision,_,facts=W.beliefSnapshot(place)
        __known.a[42].sources=quantities;__known.a[42].sourceRevision=revision;__known.a[42].sourceFacts=facts
    end
    refreshBelief()
    local coin1={getID=function()return 21 end,getFullType=function()return "Base.SilverCoin" end}
    __sourceItem=coin1;__transfer=__arcadeTransferFirst
    local firstRow
    for _,option in ipairs(A.offers("a",body))do if option.option.parameters.itemId==21 then firstRow=option end end
    check("arcade_first_personal_coin_selected",firstRow and firstRow.activity=="arcade-ArcadeStreetFighter")
    assert(A.begin("a",body,firstRow),"arcade first begin");local first=W.pendingActionFor("a")
    purpose=__records.a.proceduralPlanning.purposes[first.purposeId]
    local firstMovement=SAO.SourceUse.onMovementDone("a",body,"arrived")
    assert(firstMovement=="using","arcade first using:"..tostring(firstMovement))
    __carriedItem=coin1
    __busy=false;__observeText=__arcadeAfterFirst;carried=1
    assert(SAO.SourceUse.tick("a",body)=="completed","arcade first transfer")
    local firstReceipt=W.actionOutcome(first.id,"a");assert(P.consumeSourceResult(firstReceipt),"arcade first consume")
    refreshBelief()
    local secondRow
    for _,option in ipairs(A.offers("a",body))do if option.option.parameters.itemId==22 then secondRow=option end end
    check("arcade_cost_two_retains_deficit",secondRow and purpose.cursor==2 and not purpose.leisure)
    local coin2={getID=function()return 22 end,getFullType=function()return "Base.SilverCoin" end}
    __sourceItem=coin2;__transfer=__arcadeTransferSecond
    assert(A.begin("a",body,secondRow),"arcade second begin");local second=W.pendingActionFor("a")
    check("arcade_second_coin_same_purpose",second.purposeId==first.purposeId and #__records.a.proceduralPlanning.order==1)
    assert(SAO.SourceUse.onMovementDone("a",body,"arrived")=="using","arcade second using")
    __carriedItem=coin2
    __busy=false;__observeText=__arcadeAfterBoth;carried=2
    assert(SAO.SourceUse.tick("a",body)=="completed","arcade second transfer")
    local secondReceipt=W.actionOutcome(second.id,"a");assert(P.consumeSourceResult(secondReceipt),"arcade second consume")
    refreshBelief()
    check("arcade_cost_two_need_satisfied",#A.offers("a",body)==0 and purpose.cursor==3
        and purpose.leisureAcquisitions[1].resultId==first.id and purpose.leisureAcquisition.resultId==second.id)
    SAOJavaBridge.privateCarriedItems=function()return {size=function()return 2 end,
        get=function(_,index)return index==0 and coin1 or coin2 end}end
    local arcadeOffer={activity="arcade-ArcadeStreetFighter",materials={
        {id="21",itemType="Base.SilverCoin"},{id="22",itemType="Base.SilverCoin"}}}
    local acquired=A.acquiredPurpose("a",body,"SAO.LeisureGames",arcadeOffer)
    local bound=acquired and P.planLeisure("a",{activity=arcadeOffer.activity,
        activityKey="games:arcade-ArcadeStreetFighter:observed",owner="SAO.LeisureGames",
        acquiredPurposeId=acquired.id,affordance=requirement.sourceId,atLocation=true,locationKey="8:8:0"})
    check("arcade_exact_activity_uses_two_receipts",bound==purpose and purpose.steps[1].status=="completed"
        and purpose.steps[2].status=="completed" and purpose.steps[purpose.cursor].id=="perform-activity")
    local wrong=copy(arcadeOffer);wrong.activity="arcade-ArcadePacman"
    check("arcade_other_machine_cannot_claim_receipt",A.acquiredPurpose("a",body,"SAO.LeisureGames",wrong)==nil)
end
print("PASS D2 acquisition "..checks)
__acquisitionResults="PASS D2 acquisition "..checks
