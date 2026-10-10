-- Actual Planner/Labor/Controller/ResourceProduction and installed construction,
-- plumbing and refill. Source transport and surrounding receivers are controlled.
local checks = {}
local function check(name, value)
    checks[#checks + 1] = name .. '=' .. tostring(value == true)
    __plumbingResults = table.concat(checks, '\n')
end
local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {} for key, member in pairs(value) do out[key] = copy(member) end return out
end
local P, R, Ctl = SAO.ProceduralPlanning, SAO.ResourceProduction, SAO.Controller
local function advanceClock()
    local before = SAO.History.countyHours()
    __hours = before + .002
    return SAO.History.countyHours() > before
end
local function optionFor(f)
    for _, option in ipairs(R.options(f.rec.id, f.body, 'water')) do
        if option.kind == 'build-rain-collector' and option.entityId == 'Base.RainCollector' then return option end
    end
end
local function contextFor(f, option)
    local context = Ctl.resourceContext(f.rec.id, f.agent, f.body, {thirst=.7,hunger=0,fatigue=0}, 'water', .5, true)
    context.productionOptions = {option}
    return context
end
local function acquired(f)
    local selection = f.acquisition
    local row = {actorId=f.rec.id,reservationId=f.rec.worldSourceReservation,purposeId=selection.purposeId,
        purposeStepId=selection.purposeStepId,operation='acquire',status='completed',sourceId=selection.sourceId,
        preRevision=selection.sourceRevision,itemId=selection.itemId,itemType=selection.itemType,
        category=selection.category,measurement='native-item-transfer',observedQuantity=1,at=SAO.History.countyHours()}
    f.sourceResult = row
    local item = f.materialPool[tostring(row.itemId)]
    f.inventory:AddItems({size=function() return 1 end,get=function() return item end})
    f.materialPool[tostring(row.itemId)] = nil
    local accepted = P.consumeSourceResult(row)
    f.rec.worldSourceReservation = nil
    f.agent.state = 'IDLE'
    f.body.x,f.body.y,f.body.z=1.5,.5,0
    f.body.here=f.cell:getGridSquare(1,0,0)
    return accepted, row
end
local function materialBoundary(f, option)
    f.materialPool, f.materialRows = {}, {}
    f.knownMaterials = true
    local privateItems = SAOJavaBridge:privateCarriedItems(f.body)
    local items = {} for i=0,privateItems:size()-1 do items[tostring(privateItems:get(i):getID())] = privateItems:get(i) end
    local categories = {} for _, required in ipairs(option.requirements) do categories[required.inputIndex] = required.category end
    for _, selected in ipairs(option.inputs) do
        if selected.mode == 'consume' then
            local item = items[selected.itemId]
            f.materialPool[selected.itemId] = item
            f.materialRows[#f.materialRows + 1] = {sourceId='C:collector-materials',revision='materials-r1',
                itemId=item:getID(),itemType=item:getFullType(),category=categories[selected.inputIndex],
                sourceX=1,sourceY=0,sourceZ=0}
            f.inventory:Remove(item)
        end
    end
    local knownPlaces = SAO.Perception.knownPlaces
    SAO.Perception.knownPlaces = function(id, includeAnchors)
        local places = knownPlaces(id, includeAnchors)
        if id ~= f.rec.id then return places end
        local belief = places[option.place.id] or places[tostring(option.place.id)]
        belief.sourceFacts['C:collector-materials'] = {id='C:collector-materials',kind='container',state='available',
            revision='materials-r1',fingerprint='collector-materials-fp',x=1,y=0,z=0}
        belief.sourceRevision = belief.sourceRevision .. ',C:collector-materials@materials-r1'
        return places
    end
    local knowsItem, actionOptions, actionOutcome = SAO.WorldSources.privatelyKnowsItem,
        SAO.WorldSources.actionOptions, SAO.WorldSources.actionOutcome
    SAO.WorldSources.privatelyKnowsItem = function(id, source, itemId)
        if source == 'C:collector-materials' then return f.knownMaterials and id == f.rec.id and f.materialPool[tostring(itemId)] ~= nil end
        return knowsItem(id, source, itemId)
    end
    SAO.WorldSources.actionOptions = function(place, category)
        local options = {}
        for _, row in ipairs(f.materialRows) do
            if f.knownMaterials and row.category == category and f.materialPool[tostring(row.itemId)] then options[#options + 1] = {parameters=copy(row)} end
        end
        if #options > 0 then return {options=options} end
        return actionOptions(place, category)
    end
    SAO.WorldSources.actionOutcome = function(reservation, id)
        if f.sourceResult and f.sourceResult.reservationId == reservation and id == f.rec.id then return f.sourceResult end
        return actionOutcome(reservation, id)
    end
    SAO.SourceUse = SAO.SourceUse or {}
    local sequence = 0
    SAO.SourceUse.beginAcquisition = function(id, body, place, category, selected)
        if id ~= f.rec.id or body ~= f.body or f.rec.worldSourceReservation then return false end
        sequence = sequence + 1
        local reservation = 'collector-transfer/' .. id .. '/' .. sequence
        if not P.noteAdmission(id, selected.purposeId, 'SAO.SourceUse', reservation, selected.purposeStepId) then return false end
        f.acquisition = copy(selected);f.acquisition.category = category;f.rec.worldSourceReservation = reservation
        return true
    end
end
local function supply(f)
    -- The companion material proof owns actual native rain and supplier
    -- geometry. Here the world receiver exposes its later positive supply.
    f.collectorAmount,f.supply=4,4
    f.body.x,f.body.y,f.body.z=.5,.5,0
    f.body.here=f.square
    local wrench=__boardingItem('PipeWrench',52,f.inventory)
    function wrench:hasTag(tag) return tag==ItemTag.PIPE_WRENCH end
    function wrench:canStoreWater() return false end
    function wrench:getFluidContainer() return nil end
    function wrench:getFluidContainerFromSelfOrWorldItem() return nil end
    f.inventory:AddItems({size=function() return 1 end,get=function() return wrench end});f.tool=wrench
end
local function finishWater(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    for attempt=1,5 do
        local action=q.current
        if not action then break end
        action:start();action.action.nativeFinished=true
        if action.Type=='SAORefillWaterAction' then action:complete();action:perform()
        else action:perform();if action.Type~='ISInventoryTransferAction' then action:complete() end end
        if q.current==action then error('native water action did not retire') end
    end
    R.tick(f.id,f.body)
end

function __runCollectorControllerCases()
    SAO.Cognition.ensureGameDefaults()
    local f = __rainFixture('collector-controller', 'Base.RainCollector', false)
    for _, item in ipairs(f.materials) do
        function item:getFluidContainerFromSelfOrWorldItem() return nil end
    end
    f.supply=0
    local option = optionFor(f)
    check('collector_native_option_has_exact_four_requirement_slots',option and #option.requirements == 4
        and P.collectorReady(option) and option.sourceId and option.itemId and option.site.z == option.sourceZ+1)
    local forgedSite = copy(option);forgedSite.site.x = forgedSite.site.x+5
    forgedSite.site.key = 'collector-site:'..forgedSite.site.x..':'..forgedSite.site.y..':'..forgedSite.site.z
    local assessment = SAO.Labor.assess(f.rec.id, contextFor(f, forgedSite))
    local acceptsUnseen = false
    for _, alternative in ipairs(assessment.options) do if alternative.kind == 'build-rain-collector' then acceptsUnseen = true end end
    check('unobserved_roof_site_is_not_a_private_construction_alternative',not acceptsUnseen)
    -- control-boundary: unobserved_roof_site_is_not_a_private_construction_alternative
    local partial = copy(option);partial.inputs = {}
    local oneBag = false
    for _, input in ipairs(option.inputs) do
        if input.inputIndex ~= 3 or not oneBag then partial.inputs[#partial.inputs + 1] = copy(input) end
        if input.inputIndex == 3 then oneBag = true end
    end
    check('one_exact_bag_cannot_cover_four_native_recipe_inputs',oneBag and not P.collectorReady(partial))
    -- control-boundary: one_exact_bag_cannot_cover_four_native_recipe_inputs
    local duplicated = copy(option)
    for index, input in ipairs(duplicated.inputs) do
        if input.inputIndex == 3 and duplicated.inputs[index-1].inputIndex == 3 then input.itemId=duplicated.inputs[index-1].itemId end
    end
    check('native_slot_readiness_rejects_reused_input_identity',not P.collectorReady(duplicated))
    materialBoundary(f, option)
    f.knownMaterials=false
    local blocked=Ctl.beginHydrationAcquisition(f.rec.id,f.agent,f.body,90,{thirst=.7,hunger=0,fatigue=0})
    local blockedPurpose=P.resourceDemand(f.rec.id,'water')
    check('unknown_materials_retain_blocked_hydration_without_construction',not blocked and blockedPurpose
        and blockedPurpose.status=='blocked' and blockedPurpose.resourceCategory=='water' and not f.rec.resourceProductionWork)
    f.knownMaterials=true
    local started = Ctl.beginHydrationAcquisition(f.rec.id, f.agent, f.body, 100, {thirst=.7,hunger=0,fatigue=0})
    local purpose, step = P.resourceDemand(f.rec.id, 'water')
    local purposeId = purpose and purpose.id
    check('ordinary_thirst_acquires_exact_collector_material_under_water_purpose',started and purpose and purpose.collector
        and f.agent.state == 'SOURCEWARD' and step.owner == 'SAO.SourceUse' and step.category == 'plank'
        and f.acquisition.purposeId == purposeId and f.acquisition.itemId == step.itemId
        and f.acquisition.sourceRevision == 'materials-r1' and purpose.collector.sourceId == option.sourceId
        and purpose.collector.itemId == option.itemId and purpose.collector.site.key == option.site.key)
    local admission = copy(purpose.admission)
    local clockAdvanced = advanceClock()
    Ctl.beginHydrationAcquisition(f.rec.id, f.agent, f.body, 110, {thirst=.7,hunger=0,fatigue=0})
    P.planResource(f.rec.id, contextFor(f, forgedSite))
    local retained, current = P.resourceDemand(f.rec.id, 'water')
    check('collector_pending_material_admission_is_not_recompiled',retained.id == purposeId and current and current.id == step.id
        and retained.admission.correlationId == admission.correlationId and retained.collector.site.key == option.site.key)
    -- control-boundary: collector_pending_material_admission_is_not_recompiled
    local wrong = {actorId=f.rec.id,reservationId=f.rec.worldSourceReservation,purposeId=purposeId,purposeStepId=step.id,
        operation='acquire',status='completed',sourceId=step.sourceId,preRevision='wrong-material-revision',
        itemId=step.itemId,itemType=step.itemType,category=step.category,measurement='native-item-transfer',
        observedQuantity=1,at=SAO.History.countyHours()}
    f.sourceResult = wrong
    check('wrong_exact_material_source_revision_cannot_advance_collector',not P.consumeSourceResult(wrong) and retained.admission~=nil)
    -- control-boundary: wrong_exact_material_source_revision_cannot_advance_collector
    f.rec = __nativeRoundtrip(f.rec);__records[f.rec.id] = f.rec;f.agent.rec = f.rec
    purpose, step = P.resourceDemand(f.rec.id, 'water')
    check('native_scalar_roundtrip_retains_original_fixture_vessel_site_and_acquisition',purpose.id == purposeId
        and purpose.collector.sourceId == option.sourceId and purpose.collector.itemId == option.itemId
        and purpose.collector.site.key == option.site.key and purpose.admission.correlationId == admission.correlationId)
    local distinct, transfers, prior = {}, 0, nil
    for attempt=1,16 do
        if not f.rec.worldSourceReservation then break end
        clockAdvanced = advanceClock() and clockAdvanced
        local accepted, receipt = acquired(f)
        transfers = transfers+1;distinct[tostring(receipt.itemId)] = true
        if not accepted then error('exact controlled material transfer rejected') end
        f.agent.nextResourceAt = 0
        started = Ctl.advanceResourcePurpose(f.rec.id, f.agent, f.body, 1000+attempt*100, {thirst=.59,hunger=0,fatigue=0})
        if prior and f.rec.worldSourceReservation then
            local before = P.resourceDemand(f.rec.id, 'water')
            local reservation = before.admission.correlationId
            f.sourceResult = prior;P.consumeSourceResult(prior)
            if before.admission.correlationId ~= reservation then error('receipt replay displaced current material admission') end
        end
        prior = receipt
    end
    local identityCount = 0 for _ in pairs(distinct) do identityCount=identityCount+1 end
    local expected = 0 for _, required in ipairs(option.requirements) do if required.mode == 'consume' then expected=expected+required.count end end
    local work = f.rec.resourceProductionWork
    check('every_required_input_is_acquired_once_as_a_distinct_identity',transfers == expected and identityCount == expected
        and work and work.purposeId == purposeId and work.kind == 'build-rain-collector' and P.collectorReady(work))
    check('collector_native_dispatch_retains_original_fixture_and_observed_site',started and f.agent.state == 'RESOURCE'
        and work.sourceId == option.sourceId and work.itemId == option.itemId and work.siteKey == option.site.key
        and work.siteZ == option.site.z and work.sourceZ == option.sourceZ)
    check('collector_admission_has_no_constructed_or_water_credit',work and not work.nativeCredit
        and not P.resourceDemand(f.rec.id,'water').collector.constructedWorkId)
    local forged = copy(work)
    forged.status,forged.workId,forged.nativeOwner,forged.nativeCredit='completed',work.id,'ISBuildAction',work.id
    forged.atHours,forged.endedAt=SAO.History.countyHours(),SAO.History.countyHours()
    forged.nativeAttempted,forged.nativeCompleted,forged.constructed,forged.placed=true,true,true,true
    forged.exactInputs,forged.inputsConsumed,forged.toolRetained=true,true,true
    forged.beforeCollectorAmount,forged.afterCollectorAmount=0,0
    check('caller_forged_placement_cannot_replace_native_canonical_result',not P.consumeProductionResult(f.rec.id, forged)
        and P.resourceDemand(f.rec.id,'water').admission~=nil)
    -- control-boundary: caller_forged_placement_cannot_replace_native_canonical_result
    local placement = SAOJavaBridge.worldCollectorPlacementSquare
    SAOJavaBridge.worldCollectorPlacementSquare = function(self, body, x, y, z, revision)
        local square = placement(self, body, x, y, z, revision)
        if square and body == f.body and f.rec.resourceProductionWork and not f.freshArrivalObservation then
            f.freshArrivalObservation = advanceClock()
                and SAO.Perception.observeCollectorSites(f.rec.id, f.body, SAO.History.countyHours()) == true
        end
        return square
    end
    if work.stage=='approaching' then f.routeArrived=true;R.tick(f.id,f.body) end
    __rainFinish(f)
    local result = f.rec.resourceProductionOutcomes[1]
    purpose = P.resourceDemand(f.rec.id,'water')
    check('native_collector_creation_advances_construction_without_fulfilling_water',result and result.status=='completed'
        and result.constructed and result.placed and result.beforeCollectorAmount==0 and result.afterCollectorAmount==0
        and purpose and purpose.id==purposeId and purpose.status~='completed' and purpose.awaitingReassessment==true
        and purpose.collector.constructedWorkId==result.id)
    -- control-boundary: native_collector_creation_advances_construction_without_fulfilling_water
    check('fresh_same_geometry_observation_preserves_admitted_collector_provenance',clockAdvanced and f.freshArrivalObservation
        and result.status=='completed' and result.siteObservedAtHours < result.atHours)
    local events = #purpose.events
    check('collector_completed_receipt_replay_is_once_only',P.consumeProductionResult(f.rec.id,result)==true
        and #purpose.events==events and purpose.collector.constructedWorkId==result.id)
    resourceOwnerTick(f.rec.id,f.agent,f.body,4000)
    f.agent.nextResourceAt = 0
    started = Ctl.advanceResourcePurpose(f.rec.id,f.agent,f.body,5000,{hunger=.59,thirst=.1,fatigue=0})
    local food = P.resourceDemand(f.rec.id,'food')
    local saved = f.rec.proceduralPlanning.purposes[purposeId]
    check('empty_constructed_supply_allows_higher_food_pressure',food and saved.status~='completed'
        and saved.collector.constructedWorkId==result.id and not saved.admission and f.agent.state~='RESOURCE')
    -- control-boundary: empty_constructed_supply_allows_higher_food_pressure
    f.rec = __nativeRoundtrip(f.rec);__records[f.rec.id] = f.rec;f.agent.rec = f.rec
    saved = f.rec.proceduralPlanning.purposes[purposeId]
    check('saved_empty_collector_wait_preserves_same_water_goal_without_rebuild',saved.collector.constructedWorkId==result.id
        and saved.collector.site.key==option.site.key and saved.status~='completed'
        and P.consumeProductionResult(f.rec.id,result)==true)
    supply(f)
    f.agent.state,f.agent.nextResourceAt='IDLE',0
    started=Ctl.advanceResourcePurpose(f.rec.id,f.agent,f.body,6000,{hunger=.1,thirst=.59,fatigue=0})
    work=f.rec.resourceProductionWork
    check('later_supply_dispatches_original_fixture_plumbing_under_same_water_purpose',started and work
        and work.kind=='plumb-fixture' and work.purposeId==purposeId and work.sourceId==option.sourceId and work.itemId==option.itemId)
    finishWater(f)
    resourceOwnerTick(f.rec.id,f.agent,f.body,7000)
    f.agent.nextResourceAt=0
    started=Ctl.advanceResourcePurpose(f.rec.id,f.agent,f.body,8000,{hunger=.1,thirst=.59,fatigue=0})
    work=f.rec.resourceProductionWork
    check('actual_refill_resumes_original_vessel_and_hydration_purpose',started and work and work.kind=='refill-water'
        and work.purposeId==purposeId and work.itemId==option.itemId)
    finishWater(f)
    resourceOwnerTick(f.rec.id,f.agent,f.body,9000)
    saved=f.rec.proceduralPlanning.purposes[purposeId]
    local water=f.rec.resourceProductionOutcomes[3]
    check('only_actual_clean_held_water_fulfils_original_hydration_goal',water and water.status=='completed'
        and water.nativeGain>0 and water.clean and water.held and saved.status=='completed' and water.purposeId==purposeId)
    f.fluid.getFilledRatio=function() return f.amount/2 end
    f.fluid.isEmpty=function() return f.amount<=0 end
    f.fluid.getProperties=function() return {getHungerChange=function() return 0 end} end
    f.fluid.getCustomDrinkSound=function() return '' end
    f.vessel.getEatType=function() return 'bottle' end
    f.vessel.getWorldItem=function() return nil end
    function f.body:DrinkFluid(item,amount)
        f.drinks=(f.drinks or 0)+1;f.amount=f.amount*(1-amount);self.thirst=math.max(0,(self.thirst or .7)-.3)
    end
    f.body.thirst=.7
    started=Ctl.testThirst(f.id,f.agent,f.body,10000,{thirst=.7,hunger=0,fatigue=0})
    local drink=ISTimedActionQueue.getTimedActionQueue(f.body).current
    local before=f.amount
    if drink and drink.fluidContainer then drink:perform();drink:complete() end
    check('ordinary_thirst_drinks_the_actual_collector_supplied_vessel',started and f.agent.state=='DRINK'
        and drink and drink.item==f.vessel and f.drinks==1 and f.amount<before and f.body.thirst<.7 and saved.id==purposeId)
    __plumbingResults=table.concat(checks,'\n')
end
