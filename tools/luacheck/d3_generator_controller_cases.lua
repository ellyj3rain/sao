-- Actual P/Labor/both interpreters/Cooking and extracted Controller functions.
-- G/Study/SourceUse publish controlled exact canonical rows. Actor/map/thermal
-- receivers are controlled; this instrument does not claim native generator,
-- manual-learning physics, world routing, or loaded-game acceptance.
local P,Labor,Ctl,Models,Cognition,Cooking = SAO.ProceduralPlanning,SAO.Labor,SAO.Controller,
    SAO.CognitiveModels,SAO.Cognition,SAO.Cooking
local results={}
local function check(name,fn)
    local ok,value=pcall(fn)
    results[#results+1]=name.."="..tostring(ok and value==true)
    if not ok then results[#results+1]="CASE_ERROR "..name..": "..tostring(value) end
end
local function copy(value)
    if type(value)~="table" then return value end
    local out={} for k,v in pairs(value) do out[k]=copy(v) end return out
end
local function list(values)
    return {values=values,size=function(self)return #self.values end,
        get=function(self,i)return self.values[i+1]end}
end
local function held(id)
    for _,item in ipairs(F.inventory.items.values) do if tostring(item.id)==tostring(id) then return item end end
end
local function newItem(id,fullType)
    return {id=id,fullType=fullType,getID=function(self)return self.id end,
        getFullType=function(self)return self.fullType end,
        getContainer=function(self)return self.container end,
        getFluidContainerFromSelfOrWorldItem=function()return nil end}
end
local function setup()
    newFixture()
    SAO.ProceduralPlanning,SAO.Labor,SAO.Controller,SAO.CognitiveModels,SAO.Cognition=P,Labor,Ctl,Models,Cognition
    Ctl.agents={[F.rec.id]={rec=F.rec,state="IDLE"}}
    F.agent=Ctl.agents[F.rec.id]
    F.tick=1000 F.recipeKnown=false F.genSequence=0 F.readSequence=0 F.sourceSequence=0
    F.generatorRows={} F.readingRows={} F.sourceRows={} F.genBegins=0 F.readBegins=0 F.acquireBegins=0
    F.stove.powered=false F.rec.homeX=1 F.rec.homeY=2 F.rec.homeZ=0
    F.rec.occupation="Electrician" -- Prior life alone never supplies knowledge.
    F.generator={sourceId="J:generator",fingerprint="generator-fp",revision="gen-r1",x=8,y=8,z=0,
        inspected=false,condition=48,fuel=0,maxFuel=10,connected=false,active=false,outside=true}
    F.consumer={sourceId="E:stove",fingerprint="stove-fp",revision="stove-r1",x=1,y=2,z=0,powered=false}
    F.belief={id="room",cx=5,cy=5,z=0,minX=0,minY=0,maxX=12,maxY=12,sourceFacts={}}
    F.belief.sourceFacts[F.generator.sourceId]=copy(F.generator)
    F.belief.sourceFacts[F.consumer.sourceId]=copy(F.consumer)
    F.sources={
        ["generator-manual"]={item=newItem(91,"Base.ElectronicsMag4"),sourceId="C:manual",revision="manual-r1"},
        ["electronics-scrap"]={item=newItem(92,"Base.ElectronicsScrap"),sourceId="C:scrap",revision="scrap-r1"},
        petrol={item=newItem(93,"Base.PetrolCan"),sourceId="C:petrol",revision="petrol-r1"}}
    for _,source in pairs(F.sources) do
        F.belief.sourceFacts[source.sourceId]={revision=source.revision,x=3,y=4,z=0}
    end
    F.food.isRotten=function()return false end F.food.getPoisonPower=function()return 0 end
    F.food.getHungChange=function()return -.3 end F.food.getFluidContainerFromSelfOrWorldItem=function()return nil end
    F.body.getX=function()return F.x or 1 end F.body.getY=function()return F.y or 2 end F.body.getZ=function()return 0 end
    F.body.getPerkLevel=function()return 0 end
    SAO.History.ticks=function()return F.tick end
    SAO.Needs.ownsRecoveryBody=function(id,body)return id==F.rec.id and body==F.body and not F.body.dead end
    SAO.Disposition={eatAt=function()return .4 end,wouldGiveToStranger=function()return false end}
    SAO.Census={skillOf=function()return 0 end}
    SAO.Hash={unit=function()return .2 end}
    SandboxVars={SurvivorAwareness={}}
    SAO.Perception={knownPlaces=function(id)return id==F.rec.id and {room=F.belief} or {} end,
        knownPeople=function()return {} end,knownAidRequests=function()return {} end,
        believedThreatCount=function()return 0 end,nearestBelievedThreat=function()return nil end,
        rememberGeneratorConsumer=function(id,body,object)
            if id==F.rec.id and body==F.body and object==F.stove and F.applianceReachable then
                F.belief.sourceFacts[F.consumer.sourceId]=copy(F.consumer) return true end
        end,
        observeGenerators=function(id,body,tick)
            F.observedGeneratorTick=tick return id==F.rec.id and body==F.body and tick==F.tick end}
    local oldActionOutcome=SAO.WorldSources.actionOutcome
    SAO.WorldSources.actionOutcome=function(reservation,id)
        local row=F.sourceRows[reservation]
        if row and id==F.rec.id then return copy(row) end
        return oldActionOutcome(reservation,id)
    end
    SAO.WorldSources.generatorConsumer=function(body,object)
        if body~=F.body or object~=F.stove or not F.applianceReachable then return nil end
        local row=copy(F.consumer) row.powered=F.stove.powered return row
    end
    SAO.WorldSources.generatorConsumerObject=function(body,consumer)
        if body==F.body and consumer.sourceId==F.consumer.sourceId and consumer.fingerprint==F.consumer.fingerprint
            and math.abs(body:getX()-F.consumer.x)<=2 and math.abs(body:getY()-F.consumer.y)<=2 then return F.stove end
    end
    SAO.WorldSources.generatorConsumerTarget=function(body,consumer)
        if body==F.body and consumer.sourceId==F.consumer.sourceId and consumer.fingerprint==F.consumer.fingerprint then
            return "READY:"..F.consumer.x..":"..F.consumer.y..":"..F.consumer.z end
        return "REFUSED"
    end
    SAO.Standing.mayAttemptBelieved=function()return F.allowed end
    SAO.WorldSources.privatelyKnowsItem=function(id,sourceId,itemId)
        if id~=F.rec.id then return false end
        for _,source in pairs(F.sources) do
            if not source.unknown and source.sourceId==sourceId and source.item.id==itemId then return true end
        end
        return false
    end
    SAO.WorldSources.actionOptions=function(place,category,id,body)
        local source=F.sources[category]
        if not source or source.unknown or source.taken or id~=F.rec.id or body~=F.body then return {options={}} end
        return {options={{parameters={sourceId=source.sourceId,revision=source.revision,
            itemId=source.item.id,itemType=source.item.fullType,sourceX=3,sourceY=4,sourceZ=0}}}}
    end
    SAOJavaBridge.privateCarriedItems=function()return F.inventory.items end
    instanceof=function(item,kind)return kind=="Food" and item==F.food end
    SAO.SourceUse.beginAcquisition=function(id,body,place,category,context)
        local source=F.sources[category]
        if F.busy or not source or source.unknown or source.taken or not F.allowed
            or source.sourceId~=context.sourceId or source.revision~=context.sourceRevision
            or source.item.id~=context.itemId or source.item.fullType~=context.itemType then return false end
        F.sourceSequence=F.sourceSequence+1
        local reservation="source/"..id.."/"..F.sourceSequence
        if not P.noteAdmission(id,context.purposeId,"SAO.SourceUse",reservation,context.purposeStepId) then return false end
        F.acquisition={id=reservation,category=category,context=copy(context),place=copy(place),source=source}
        F.acquireBegins=F.acquireBegins+1 F.rec.worldSourceReservation=reservation F.busy=true
        return true,{id=reservation}
    end
    SAO.Study={beginGenerator=function(id,body,item,purposeId,stepId)
        if F.busy or not held(item.id) then return false end
        F.readSequence=F.readSequence+1
        local work={id="generator-reading/"..id.."/"..F.readSequence,actorId=id,sequence=F.readSequence,
            purposeId=purposeId,purposeStepId=stepId,itemId=tostring(item.id),itemType=item.fullType,
            operation="learn-generator",token="utility:generator-known",startedAt=F.at}
        if not P.admitGeneratorReading(id,work) then return false end
        F.rec.studyWork=work F.readBegins=F.readBegins+1 F.busy=true return true,work
    end,generatorOutcome=function(id,outcomeId)
        return id==F.rec.id and F.readingRows[outcomeId] and copy(F.readingRows[outcomeId]) or nil
    end}
    SAO.Generator={options=function(id,body,intent)
        if F.noGenerator or id~=F.rec.id or body~=F.body then return {} end
        local gen=copy(F.generator)
        local operation,category
        if not gen.inspected then operation="inspect"
        elseif gen.condition<50 then operation="repair" category="electronics-scrap"
        elseif gen.fuel<=0 then operation="fuel" category="petrol"
        elseif not gen.connected then operation="connect"
        elseif not gen.active then operation="activate"
        else operation="verify-power" end
        if (operation=="repair" or operation=="connect") and not F.recipeKnown then category="generator-manual" end
        local source=category and F.sources[category]
        local item=source and held(source.item.id)
        return {{generator=gen,consumer=copy(F.consumer),operation=operation,materialCategory=category,
            inputItemId=item and tostring(item.id),inputItemType=item and item.fullType}}
    end,begin=function(id,body,step,context)
        if F.busy or not F.allowed or F.beginRefused then return false end
        F.genSequence=F.genSequence+1
        local work=copy(step)
        work.id="generator/"..id.."/"..F.genSequence work.sequence=F.genSequence work.actorId=id
        work.purposeId=context.purposeId work.purposeStepId=context.purposeStepId work.startedAt=F.at
        if not P.admitGenerator(id,work) then return false end
        F.rec.resourceProductionWork=work F.genBegins=F.genBegins+1 F.busy=true return true,work
    end,outcome=function(id,sequence)
        F.generatorRequeries=(F.generatorRequeries or 0)+1
        return id==F.rec.id and F.generatorRows[sequence] and copy(F.generatorRows[sequence]) or nil
    end}
    Cooking.onOutcome=function(id,row)return P.consumeCookingResult(id,row) end
    Ctl.advanceResourcePurpose=function()__ordinaryResourceTurns=(__ordinaryResourceTurns or 0)+1;return false end
    __ordinaryResourceTurns=0
    return F
end
local function foodPurpose()
    local context=Ctl.resourceContext(F.rec.id,F.agent,F.body,{hunger=.5,fatigue=0},"food",.8)
    local purpose,step=P.planResource(F.rec.id,context)
    assert(purpose and step and step.owner=="Cooking" and step.acquiredItemId==71,"actual food plan unavailable")
    F.foodPurpose=purpose F.foodStep=step return purpose,step
end
local function idle()
    F.tick=F.tick+601 F.at=F.at+.01 F.agent.state="IDLE" F.busy=false
    Ctl.testUtilityIdle(F.rec.id,F.agent,F.body,F.tick,{hunger=.5,fatigue=0})
    return P.generatorPurpose(F.rec.id)
end
local function startMealFailure()
    local purpose,step=foodPurpose()
    assert(Cooking.begin(F.rec.id,F.body,{purposeId=purpose.id,purposeStepId=step.id,acquiredItemId=71,privateFood=true}))
    assert(Cooking.tick(F.rec.id,F.body)=="no-effect","unpowered meal did not stop")
    return purpose,step
end
local function acquired(changes,move)
    local acquisition=assert(F.acquisition,"missing source admission")
    local context,source=acquisition.context,acquisition.source
    F.at=F.at+.01
    local row={reservationId=acquisition.id,actorId=F.rec.id,purposeId=context.purposeId,
        purposeStepId=context.purposeStepId,sourceId=context.sourceId,preRevision=context.sourceRevision,
        itemId=context.itemId,itemType=context.itemType,category=acquisition.category,operation="acquire",
        status="completed",measurement="native-item-transfer",observedQuantity=1,at=F.at}
    for k,v in pairs(changes or {}) do row[k]=v end
    F.sourceRows[acquisition.id]=row
    local accepted=P.consumeSourceResult(row)
    if accepted and move~=false then
        source.item.container=F.inventory F.inventory.items.values[#F.inventory.items.values+1]=source.item
        source.taken=true F.x=3 F.y=4 F.rec.worldSourceReservation=nil F.busy=false
    end
    return accepted,row
end
local function generatorRow(changes,status)
    local work=assert(F.rec.resourceProductionWork,"no native generator admission")
    F.at=F.at+.01
    local row=copy(work)
    row.workId=row.id row.status=status or "completed" row.atHours=F.at row.endedAt=F.at
    row.nativeAttempted=work.operation~="inspect" and work.operation~="verify-power"
    row.nativeCompleted=true row.nativeCredit=row.id row.nativeOwner="controlled-native-generator-"..work.operation
    local after=copy(F.generator)
    after.revision="gen-r"..tostring(F.genSequence+1)
    if work.operation=="inspect" then after.inspected=true
    elseif work.operation=="repair" then row.beforeCondition=after.condition;after.condition=54;row.afterCondition=54;row.inputConsumed=true
    elseif work.operation=="fuel" then row.beforeFuel=after.fuel;after.fuel=1;row.afterFuel=1;row.maxFuel=10
        row.beforeInputAmount=1;row.afterInputAmount=0;row.inputRetained=true
    elseif work.operation=="connect" then row.beforeConnected=false;row.afterConnected=true;after.connected=true
    elseif work.operation=="activate" then row.beforeActive=false;row.afterActive=true;row.outside=true;after.active=true
    elseif work.operation=="verify-power" then row.sourceCovered=true;row.consumerPowered=true end
    row.generatorAfter=after row.consumerAfter=copy(F.consumer)
    if work.operation=="verify-power" then row.consumerAfter.powered=true;row.consumerAfter.revision="stove-r2" end
    for k,v in pairs(changes or {}) do row[k]=v end
    return row
end
local function completeGenerator(changes,status)
    local row=generatorRow(changes,status)
    F.generatorRows[row.sequence]=row
    local accepted=P.consumeGeneratorOutcome(F.rec.id,row.sequence)
    if accepted then
        if row.status=="completed" then
            F.generator=copy(row.generatorAfter) F.consumer=copy(row.consumerAfter)
            F.belief.sourceFacts[F.generator.sourceId]=copy(F.generator)
            F.belief.sourceFacts[F.consumer.sourceId]=copy(F.consumer)
            if row.operation=="verify-power" then F.stove.powered=true end
        end
        F.rec.resourceProductionWork=nil F.busy=false
    end
    return accepted,row
end
local function readComplete(known)
    local work=assert(F.rec.studyWork,"no reading admission")
    F.at=F.at+.01
    local row=copy(work)
    row.workId=row.id row.outcomeId=row.id row.atHours=F.at row.endedAt=F.at row.status="completed"
    row.nativeOwner="ISReadABook.complete" row.nativeStarted=true row.nativeCompleted=true row.progress=1 row.recipeKnown=known
    F.readingRows[row.id]=row
    local accepted=P.consumeGeneratorReading(F.rec.id,row.id)
    if accepted then F.rec.studyWork=nil F.busy=false F.recipeKnown=known end
    return accepted,row
end
local function inspected()
    foodPurpose() idle()
    assert(F.rec.resourceProductionWork and F.rec.resourceProductionWork.operation=="inspect","inspect not dispatched")
    assert(completeGenerator(),"canonical inspect refused")
end
local function manualReading()
    inspected() idle() assert(F.acquisition and F.acquisition.category=="generator-manual","manual not acquired")
    assert(acquired(),"manual receipt refused") idle()
    assert(F.agent.state=="IDLE" and F.rec.studyWork,"owned reading not dispatched")
end
local function stage(operation)
    local purpose=P.generatorPurpose(F.rec.id)
    for _=1,12 do
        idle()
        if F.rec.resourceProductionWork then
            if F.rec.resourceProductionWork.operation==operation then return purpose or P.generatorPurpose(F.rec.id) end
            assert(completeGenerator(),"earlier canonical stage refused")
        elseif F.rec.studyWork then assert(readComplete(true),"canonical reading refused")
        elseif F.rec.worldSourceReservation then assert(acquired(),"exact acquisition refused")
        else error("retained utility did not progress toward "..operation) end
    end
    error("bounded stage continuation exhausted")
end

check("no_intended_meal_has_no_compulsory_generator_task",function()
    setup();idle();return P.generatorPurpose(F.rec.id)==nil and F.genBegins==0 and __ordinaryResourceTurns>0
end)
check("distant_consumer_allows_ordinary_cooking_approach",function()
    setup();local p,s=foodPurpose();F.applianceReachable=false;idle()
    return P.generatorPurpose(F.rec.id)==nil and Cooking.begin(F.rec.id,F.body,{purposeId=p.id,purposeStepId=s.id,acquiredItemId=71,privateFood=true})
        and Cooking.tick(F.rec.id,F.body)=="travelling" and F.routeCalls==1
end)
check("unknown_generator_retains_private_goal_and_allows_needs",function()
    setup();foodPurpose();F.noGenerator=true;idle();local p=P.generatorPurpose(F.rec.id)
    return p and p.status=="blocked" and p.generatorPower.consumer.sourceId=="E:stove" and F.genBegins==0 and __ordinaryResourceTurns>0
end)
check("current_standing_refusal_does_not_admit_utility",function()
    setup();foodPurpose();F.allowed=false;idle();return P.generatorPurpose(F.rec.id)==nil and F.genBegins==0
end)
check("actual_unpowered_cooking_retains_original_food_and_retry",function()
    setup();local p,s=startMealFailure();local failure=p.routeFailures and p.routeFailures[1]
    return p.status=="blocked" and s.status=="failed" and failure and failure.reason=="appliance-unpowered"
        and failure.retryAt>F.at and F.food.container==F.inventory and F.transferCalls==0 and F.xp==0
        and F.rec.cookingPowerDemand.requestingPurposeId==p.id
end)
check("both_private_models_compare_utility_consequence",function()
    setup();foodPurpose();idle();local p=P.generatorPurpose(F.rec.id)
    return p and p.interpretations and #p.interpretations.models==2
        and p.interpretations.models[1].modelId~=p.interpretations.models[2].modelId
        and p.alternatives[1].consequences[1].kind=="power" and p.alternatives[1].consequences[1].category=="utilities"
end)
check("native_length_anchors_preserve_both_model_views_and_admission",function()
    setup()
    F.generator.sourceId="J:12345678-1234-1234-1234-123456789abc"
    F.generator.fingerprint=string.rep("a",64) F.generator.revision=string.rep("b",64)
    F.consumer.sourceId="E:87654321-4321-4321-4321-cba987654321"
    F.consumer.fingerprint=string.rep("c",64) F.consumer.revision=string.rep("d",64)
    F.belief.sourceFacts={}
    F.belief.sourceFacts[F.generator.sourceId]=copy(F.generator)
    F.belief.sourceFacts[F.consumer.sourceId]=copy(F.consumer)
    foodPurpose();idle()
    local p=P.generatorPurpose(F.rec.id)
    local views=p and p.interpretations
    local work=F.rec.resourceProductionWork
    return #F.generator.sourceId==38 and #F.consumer.sourceId==38 and views and #views.models==2
        and views.models[1].modelId=="ordinary" and views.models[2].modelId=="associative"
        and views.models[1].selected==p.selectedStrategy and views.models[2].selected==p.selectedStrategy
        and type(views.selected)=="string" and #views.selected<=128
        and p.admission and p.admission.owner=="SAO.Generator" and work and work.operation=="inspect"
        and work.generator.sourceId==F.generator.sourceId and work.generator.revision==F.generator.revision
        and work.generator.fingerprint==F.generator.fingerprint and work.consumer.sourceId==F.consumer.sourceId
        and work.consumer.revision==F.consumer.revision and work.consumer.fingerprint==F.consumer.fingerprint
end)
check("exact_known_manual_dispatch_retains_generator_consumer_purpose",function()
    setup();inspected();local p=idle();local a=F.acquisition
    return p and a and F.agent.state=="SOURCEWARD" and a.category=="generator-manual" and a.context.sourceId=="C:manual"
        and a.context.sourceRevision=="manual-r1" and a.context.itemId==91 and a.context.itemType=="Base.ElectronicsMag4"
        and a.context.purposeId==p.id and p.generatorPower.generator.sourceId=="J:generator"
        and p.generatorPower.requestingPurposeId==F.foodPurpose.id and F.readBegins==0
end)
check("pending_acquisition_is_not_recompiled_or_bypassed",function()
    setup();inspected();local p=idle();local step=p.steps[p.cursor];local id=p.admission.correlationId
    local pending=P.planGenerator(F.rec.id,{intent={consumer=copy(F.consumer)},options={},sources={},atHours=F.at})
    F.agent.state="IDLE" F.busy=false F.tick=F.tick+601
    local heldPending=Ctl.advanceGeneratorPurpose(F.rec.id,F.agent,F.body,F.tick,{hunger=.9})
    return heldPending and pending==p and p.steps[p.cursor]==step and p.admission.correlationId==id and F.acquireBegins==1
end)
check("wrong_source_revision_cannot_acquire",function()
    setup();inspected();local p=idle();local cursor=p.cursor
    return not acquired({preRevision="stale"},false) and p.cursor==cursor and p.admission~=nil and not held(91)
end)
check("acquisition_advances_only_exact_reading_prerequisite",function()
    setup();inspected();local p=idle();local id=p.id;assert(acquired());idle()
    return F.agent.state=="IDLE" and F.rec.studyWork.purposeId==id and F.generator.condition==48 and not F.generator.active
        and F.xp==0 and F.creditCalls==0 and not F.food.cooked
end)
check("reading_without_native_recipe_cannot_advance",function()
    setup();manualReading();local p=P.generatorPurpose(F.rec.id);local cursor=p.cursor
    return not readComplete(false) and p.cursor==cursor and p.admission~=nil and F.rec.studyWork~=nil and not F.recipeKnown
end)
check("canonical_manual_learning_keeps_same_utility_purpose",function()
    setup();manualReading();local p=P.generatorPurpose(F.rec.id);local id=p.id;assert(readComplete(true));idle()
    return P.generatorPurpose(F.rec.id).id==id and F.recipeKnown and F.agent.state=="SOURCEWARD"
        and F.acquisition.category=="electronics-scrap" and not F.generator.connected
end)
check("exact_scrap_acquisition_returns_to_same_generator_stage",function()
    setup();foodPurpose();stage("repair");local p=P.generatorPurpose(F.rec.id);local work=F.rec.resourceProductionWork
    return F.x==3 and F.y==4 and F.agent.state=="RESOURCE" and work.purposeId==p.id and work.generator.x==8 and work.generator.y==8
        and work.inputItemId=="92" and work.inputItemType=="Base.ElectronicsScrap" and work.consumer.sourceId=="E:stove"
end)
check("native_admission_alone_gives_no_effect_credit",function()
    setup();foodPurpose();stage("repair");local p=P.generatorPurpose(F.rec.id)
    return p.admission~=nil and p.status~="completed" and F.generator.condition==48 and F.food.container==F.inventory
        and not F.food.cooked and F.xp==0 and F.creditCalls==0
end)
check("query_inspection_without_native_attempt_advances_and_releases",function()
    setup();foodPurpose();idle();local p=P.generatorPurpose(F.rec.id);local accepted,row=completeGenerator()
    return accepted and row.nativeAttempted==false and p.admission==nil and p.awaitingReassessment==true
        and p.generatorPower.generator.inspected==true and p.status=="maintained"
end)
check("measured_repair_refreshes_own_revision_without_replacing_goal",function()
    setup();foodPurpose();stage("repair");local p=P.generatorPurpose(F.rec.id);local before=p.id
    assert(completeGenerator());idle()
    return p.id==before and F.generator.condition==54 and p.generatorPower.generator.revision==F.generator.revision
        and F.acquisition.category=="petrol" and not F.generator.active
end)
check("finite_fuel_gain_is_separate_from_hydration_and_meal",function()
    setup();foodPurpose();stage("fuel");local p=P.generatorPurpose(F.rec.id);local accepted,row=completeGenerator()
    return accepted and row.afterInputAmount<row.beforeInputAmount and row.inputRetained==true and held(93)~=nil
        and p.status=="maintained" and F.generator.fuel==1 and F.generator.maxFuel==10
        and row.beforeInputAmount==1 and row.afterInputAmount==0 and F.foodPurpose.status~="completed" and F.xp==0
end)
check("activation_does_not_close_consumer_power_or_cooking",function()
    setup();foodPurpose();stage("activate");local p=P.generatorPurpose(F.rec.id);assert(completeGenerator())
    return p.status=="maintained" and F.generator.active and not F.consumer.powered and P.poweredMeal(F.rec.id)==nil
        and F.foodPurpose.status~="completed" and not F.food.cooked
end)
check("consumer_power_without_source_coverage_cannot_close",function()
    setup();foodPurpose();stage("verify-power");local p=P.generatorPurpose(F.rec.id)
    return not completeGenerator({sourceCovered=false}) and p.status~="completed" and p.admission~=nil
        and P.poweredMeal(F.rec.id)==nil and not F.stove.powered
end)
check("replaced_generator_receipt_cannot_advance",function()
    setup();foodPurpose();stage("repair");local p=P.generatorPurpose(F.rec.id);local row=generatorRow()
    row.generator.fingerprint="replacement" F.generatorRows[row.sequence]=row
    return not P.consumeGeneratorOutcome(F.rec.id,row.sequence) and p.admission~=nil and F.generator.condition==48
end)
check("caller_completion_cannot_advance_generator",function()
    setup();foodPurpose();idle();local p=P.generatorPurpose(F.rec.id);local s=p.steps[p.cursor]
    return not P.recordResult(F.rec.id,p.id,{owner=s.owner,token=s.token,status="completed",correlationId=p.admission.correlationId,atHours=F.at})
        and p.cursor==1 and not F.generator.inspected
end)
check("interrupted_saved_admission_retires_without_effect_and_retains_goal",function()
    setup();foodPurpose();stage("repair");local p=P.generatorPurpose(F.rec.id);local id=p.id
    F.rec.proceduralPlanning=copy(F.rec.proceduralPlanning) F.rec.resourceProductionWork=copy(F.rec.resourceProductionWork)
    assert(completeGenerator(nil,"interrupted"));local retained=P.generatorPurpose(F.rec.id)
    return retained.id==id and retained.status=="interrupted" and retained.admission==nil and F.generator.condition==48
        and retained.generatorPower.consumer.sourceId=="E:stove" and F.foodPurpose.status~="completed" and F.xp==0
end)
check("canonical_result_replay_is_once_only_and_requery_bound",function()
    setup();foodPurpose();idle();local p=P.generatorPurpose(F.rec.id);local accepted,row=completeGenerator()
    local count=#p.resultReceipts local cursor=p.cursor
    F.rec.proceduralPlanning=copy(F.rec.proceduralPlanning)
    local saved=P.generatorPurpose(F.rec.id)
    return accepted and P.consumeGeneratorOutcome(F.rec.id,row.sequence) and saved.cursor==cursor and #saved.resultReceipts==count
        and F.generatorRequeries>=2 and saved.admission==nil and not P.consumeGeneratorOutcome(F.rec.id,999)
end)
check("final_power_resumes_exact_original_meal_without_backoff",function()
    setup();local food,step=startMealFailure();F.agent.nextResourceAt=F.tick+99999;F.agent.nextCookAt=F.tick+99999
    stage("verify-power");local utility=P.generatorPurpose(F.rec.id);local accepted,row=completeGenerator()
    assert(accepted,"actual coverage receipt refused")
    local marker=P.poweredMeal(F.rec.id)
    local unprepared=not F.food.cooked and F.xp==0 and F.transferCalls==0 and food.status~="completed"
    idle()
    local work=F.rec.cookingWork
    return utility.status=="completed" and row.nativeAttempted==false and marker and marker.purposeId==food.id
        and marker.foodItemId==71 and unprepared and F.agent.state=="COOK" and work and work.purposeId==food.id
        and work.purposeStepId==step.id and work.itemId==71 and work.sourceId=="oven-1"
        and F.agent.nextResourceAt==0 and F.agent.nextCookAt==0 and F.rec.poweredMealReady==nil
        and food.routeFailures[1].retryAt<=F.at and food.routeFailures[1].resolvedByUtility==row.id
end)
local function poweredMealReady()
    local food,step=startMealFailure()
    stage("verify-power")
    local utility=P.generatorPurpose(F.rec.id)
    assert(completeGenerator(),"coverage receipt refused")
    assert(P.poweredMeal(F.rec.id),"original meal not ready")
    return food,step,utility
end
local function finishOriginalCooking()
    assert(Cooking.tick(F.rec.id,F.body)=="transfer","original deposit not dispatched")
    assert(settleTransfer()=="switching-appliance","original heat activation not dispatched")
    assert(completeToggle(),"original stove activation refused")
    assert(Cooking.tick(F.rec.id,F.body)=="heating","original meal not heating")
    -- Existing controlled thermal receiver supplies measured progression;
    -- actual Cooking owns credit, retrieval, shutdown, and its canonical row.
    nativeCooked()
    assert(Cooking.tick(F.rec.id,F.body)=="transfer","original retrieval not dispatched")
    assert(settleTransfer()=="switching-appliance","original shutdown not dispatched")
    assert(completeToggle(),"original shutdown refused")
    assert(Cooking.tick(F.rec.id,F.body)=="completed","original Cooking did not complete")
    return lastOutcome()
end
check("completed_original_meal_does_not_reopen_stale_power_goal",function()
    setup();local food,step,utility=poweredMealReady()
    local utilityCount=F.rec.proceduralPlanning.nextPurpose
    idle();local cleared=F.rec.cookingPowerDemand==nil
    local row=finishOriginalCooking()
    local begins=F.genBegins
    idle()
    return cleared and food.status=="completed" and row.status=="completed" and row.purposeId==food.id
        and row.purposeStepId==step.id and row.nativeCredit==row.id and row.heatObserved and row.retrieved
        and F.food.cooked and F.food.container==F.inventory and utility.status=="completed"
        and F.genBegins==begins and F.rec.proceduralPlanning.nextPurpose==utilityCount
        and P.generatorPurpose(F.rec.id)==nil and F.agent.state=="IDLE" and __ordinaryResourceTurns>0
end)
check("original_meal_resume_preserves_newer_unmet_power_request",function()
    setup();local food,step=poweredMealReady()
    local newer=assert(P.admitResourceOutcome(F.rec.id,{id="next-meal",revision=1,category="food",target=2,
        unit="usable-food-item",sourceDefinition=string.rep("e",64),issuer="controlled newer request"}))
    local context=Ctl.resourceContext(F.rec.id,F.agent,F.body,{hunger=.5},"food",.8)
    context.purposeId=newer.id
    local planned,newStep=P.planResource(F.rec.id,context)
    assert(planned==newer and newStep and newStep.owner=="Cooking","newer live meal not planned")
    local otherStove=copy(F.stove) otherStove.powered=false
    local otherContainer={items=list({}),getItems=function(self)return self.items end}
    local other={object=otherStove,container=otherContainer,sourceId="oven-2",kind="stove",
        sourceX=9,sourceY=2,sourceZ=0,approachX=9,approachY=2,approachZ=0}
    local otherConsumer={sourceId="E:other-stove",fingerprint="other-stove-fp",revision="other-stove-r1",
        x=9,y=2,z=0,powered=false}
    local inspect=SAOJavaBridge.inspectCookingAppliance
    SAOJavaBridge.inspectCookingAppliance=function(self,body,object,container)
        if object==otherStove and container==otherContainer then return {sourceId="oven-2",kind="stove",active=false,powered=false} end
        return inspect(self,body,object,container)
    end
    SAOJavaBridge.cookingOffers=function()return {appliances={F.appliance,other},foods={F.foodOffer}} end
    local consumer=SAO.WorldSources.generatorConsumer
    SAO.WorldSources.generatorConsumer=function(body,object)
        if body==F.body and object==otherStove then return copy(otherConsumer) end
        return consumer(body,object)
    end
    local demand=Cooking.powerDemand(F.rec.id,F.body,{purposeId=newer.id,acquiredItemId=71,
        privateFood=true,expectedSourceId="oven-2"})
    assert(demand and demand.consumer.sourceId=="E:other-stove","newer observed power request absent")
    local retained=F.rec.cookingPowerDemand
    idle()
    return F.rec.cookingWork and F.rec.cookingWork.purposeId==food.id and F.rec.cookingWork.purposeStepId==step.id
        and F.rec.cookingPowerDemand==retained and retained.requestingPurposeId==newer.id
        and retained.applianceSourceId=="oven-2" and retained.consumer.sourceId=="E:other-stove"
        and newer.status~="completed" and newer.admission==nil and otherStove.powered==false
end)
check("unavailable_original_cooking_begin_preserves_power_request",function()
    setup();local food=poweredMealReady()
    local demand=F.rec.cookingPowerDemand
    F.allowed=false F.tick=F.tick+601 F.agent.state="IDLE"
    return not Ctl.resumePoweredMeal(F.rec.id,F.agent,F.body,F.tick) and F.rec.cookingPowerDemand==demand
        and F.rec.poweredMealReady~=nil and F.rec.cookingWork==nil and food.admission==nil
        and food.status~="completed" and F.transferCalls==0
end)
check("displaced_powered_meal_returns_before_exact_cooking",function()
    setup();local food,step=poweredMealReady()
    local ready=copy(F.rec.poweredMealReady)
    F.x,F.y=60,60
    local offers=SAOJavaBridge.cookingOffers
    SAOJavaBridge.cookingOffers=function(self,body,radius)
        if body:getX()>20 then return {appliances={},foods={F.foodOffer}} end
        return offers(self,body,radius)
    end
    idle()
    local returned=F.agent.state=="TRAVEL" and F.routeCalls==1 and F.rec.cookingWork==nil
        and F.rec.poweredMealReady.utilityWorkId==ready.utilityWorkId and food.admission==nil
    F.x,F.y=F.consumer.x,F.consumer.y
    SAO.Locomotion.jobs[F.rec.id].done=true
    idle()
    return returned and F.agent.state=="COOK" and F.rec.cookingWork.purposeId==food.id
        and F.rec.cookingWork.purposeStepId==step.id and F.rec.poweredMealReady==nil
end)
check("powered_meal_return_refusal_preserves_exact_ready_goal",function()
    setup();local food=poweredMealReady()
    local ready=F.rec.poweredMealReady
    F.x,F.y=60,60 F.allowed=false
    idle()
    return F.agent.state=="IDLE" and F.routeCalls==0 and F.rec.poweredMealReady==ready
        and F.rec.cookingWork==nil and food.admission==nil and food.status~="completed"
end)
check("coverage_rejection_releases_pinned_generator_in_context",function()
    setup();startMealFailure();stage("verify-power")
    local utility=P.generatorPurpose(F.rec.id)
    assert(completeGenerator({sourceCovered=false,consumerPowered=false,nativeCompleted=false,nativeCredit=false,
        detail="native-consumer-power-checked"},"failed"))
    local seen
    SAO.Generator.options=function(id,body,intent)seen=copy(intent);return {} end
    idle()
    return seen and seen.generator==nil and seen.rejectedGenerators
        and seen.rejectedGenerators[F.generator.sourceId]==F.generator.fingerprint
        and P.generatorPurpose(F.rec.id).id==utility.id and F.rec.poweredMealReady==nil
end)
check("newer_same_consumer_meal_rebinds_retained_utility_and_resumes",function()
    setup();local oldFood=startMealFailure();stage("activate");assert(completeGenerator())
    local utility=P.generatorPurpose(F.rec.id)
    oldFood.status="abandoned"
    local oldItem=F.food
    F.food={} for key,value in pairs(oldItem) do F.food[key]=value end
    F.food.id=72 F.food.fullType="Base.PorkChop"
    for index,item in ipairs(F.inventory.items.values) do if item==oldItem then F.inventory.items.values[index]=F.food end end
    F.foodOffer.item,F.foodOffer.itemId,F.foodOffer.itemType=F.food,72,F.food.fullType
    local newer=assert(P.admitResourceOutcome(F.rec.id,{id="replacement-meal",revision=1,category="food",target=1,
        unit="usable-food-item",sourceDefinition=string.rep("f",64),issuer="controlled current request"}))
    local context=Ctl.resourceContext(F.rec.id,F.agent,F.body,{hunger=.5},"food",.8)
    context.purposeId=newer.id
    local planned,newStep=P.planResource(F.rec.id,context)
    assert(planned==newer and newStep and newStep.acquiredItemId==72)
    idle()
    local request=utility.generatorPower
    local rebound=P.generatorPurpose(F.rec.id)==utility and request.requestingPurposeId==newer.id
        and tostring(request.foodItemId)=="72" and request.foodItemType==F.food.fullType
        and request.applianceSourceId==F.appliance.sourceId and request.consumer.sourceId==F.consumer.sourceId
    assert(completeGenerator())
    local ready=P.poweredMeal(F.rec.id)
    if not ready then return false end
    idle()
    return rebound and ready.purposeId==newer.id and tostring(ready.foodItemId)=="72"
        and F.agent.state=="COOK" and F.rec.cookingWork.purposeId==newer.id
        and F.rec.cookingWork.purposeStepId==newStep.id and F.rec.cookingWork.itemId==72
        and oldFood.status=="abandoned" and F.rec.cookingPowerDemand==nil
end)
check("admitted_utility_keeps_request_until_current_attempt_retires",function()
    setup();local oldFood=startMealFailure();stage("verify-power")
    local utility,current=P.generatorPurpose(F.rec.id)
    local intent=copy(utility.generatorPower)
    intent.requestingPurposeId="new-meal" intent.foodItemId=72 intent.foodItemType="Base.PorkChop"
    local p,s=P.planGenerator(F.rec.id,Ctl.generatorContext(F.rec.id,F.agent,F.body,F.tick,{hunger=.5},intent))
    return p==utility and s==current and utility.admission~=nil
        and utility.generatorPower.requestingPurposeId==oldFood.id and tostring(utility.generatorPower.foodItemId)=="71"
end)
__generatorControllerResults=table.concat(results,"\n")
