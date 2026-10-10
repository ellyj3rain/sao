-- Installed plumbing/equipment/transfer/water actions and queue, actual SAO
-- planner, perception, source ledger and private cognition. Map/actor/fluid,
-- native dispatch, sounds and network receivers are controlled explicitly.
ItemTag.PIPE_WRENCH='PipeWrench';IsoObjectChange.USES_EXTERNAL_WATER_SOURCE='external'
Metabolics.MediumWork='MediumWork';ZomboidGlobals={EquippedOrWornEncumbranceMultiplier=.3}
function sendItemStats() end
function removeItemTransaction() end
ISInventoryPage.dirtyUI=function() end
SAO.Controller={agents={}};SAO.Locomotion={jobs={}}
SAO.Cooking={};SAO.Pharmacology={};SAO.Log={line=function() end}
SAO.Observation={record=function() end}
local stores={SurvivorAwareness_Cognition={settings={enabled=true,opponentShare=.5,opportunitiesPerHour=12,maxDepth=3}}}
ModData={get=function(k) return stores[k] end,getOrCreate=function(k) stores[k]=stores[k] or {};return stores[k] end}
SAO.Disposition.eatAt=function() return .6 end
SAO.Disposition.drinkAt=function() return .6 end
SAO.Needs.read=function(body) return {hunger=body.hunger or .1,thirst=body.thirst or .7,fatigue=.1} end
SAO.Needs.bleeding=function(body) return body.bleeding or 0 end
SAO.Needs.busy=function(body) local q=ISTimedActionQueue.getTimedActionQueue(body);return q.current~=nil or #q.queue>0 end
SAO.Needs.portableWaterItem=function(item)
    local fluid=item:getFluidContainer()
    return fluid and fluid:getAmount()>0 and fluid:isWaterSource() and not fluid:isPoisonous() and not fluid:isTainted() or false
end
SAO.Standing.mayTakeCurrent=function(id) return not __records[id].permissionDenied end
SAO.Standing.mayAttemptBelieved=SAO.Standing.mayTakeCurrent
SAOJavaBridge.privateCarriedItems=function(_,body)
    local out={}
    for _,inv in ipairs({body:getInventory(),body:getInventory().nested}) do
        for _,item in ipairs(inv.items) do out[#out+1]=item end
    end
    return {size=function() return #out end,get=function(_,i) return out[i+1] end}
end
SAOJavaBridge.findCarriedDrink=function(_,body)
    for _,item in ipairs(body:getInventory().items) do if SAO.Needs.portableWaterItem(item) then return item end end
end
SAOJavaBridge.findCarriedFood=function() return nil end
local originalTimed=LuaTimedActionNew.new
local nativeTransferPerform=ISInventoryTransferAction.perform
ISInventoryTransferAction.perform=function(self)
    local ok,result=pcall(nativeTransferPerform,self)
    if not ok then print('native transfer error '..tostring(result));error(result) end
    return result
end
LuaTimedActionNew.new=function(action,body)
    local a=originalTimed(action,body)
    function a:setOverrideHandModels() end
    function a:setOverrideHandModelsObject() end
    function a:setAnimVariable() end
    function a:stopTimedActionAnim() end
    return a
end
local function fixture(id,nested,fixed)
    local f=__boardingFixture(id,false)
    f.inventory.items={};f.rec.bodyOwnerToken=nil;f.body.md.SAOExternalToken=nil
    f.amount,f.supply,f.revision,f.observeCalls=0,4,'r1',0
    f.sourceId,f.fingerprint='F:'..id,'fixture:'..id
    f.item=__boardingItem('WaterBottle',51,f.inventory)
    f.tool=__boardingItem('PipeWrench',52,f.inventory)
    function f.tool:hasTag(tag) return tag==ItemTag.PIPE_WRENCH end
    function f.tool:getFluidContainer() return nil end
    function f.tool:canStoreWater() return false end
    f.fluid={getAmount=function() return f.amount end,getCapacity=function() return 2 end,
        isWaterSource=function() return f.amount>0 end,isPoisonous=function() return f.poison==true end,
        isTainted=function() return f.tainted==true end}
    function f.item:getFluidContainer() return f.fluid end
    function f.item:getFluidContainerFromSelfOrWorldItem() return f.fluid end
    function f.item:canStoreWater() return true end
    function f.item:isEquipped() return false end
    function f.item:syncItemFields() end
    function f.item:setBeingFilled(v) self.beingFilled=v end
    function f.item:getFillFromTapSound() return nil end
    function f.item:getPourType() return 'bottle' end
    function f.item:getStaticModel() return 'WaterBottle' end
    f.inventory.items={f.item,f.tool}
    if nested then
        local bag={items={f.tool}};__boardingInventory(bag,f.inventory)
        function bag:contains(item) return self.items[1]==item end
        function bag:Remove(item) if self.items[1]==item then self.items={};item.container=nil end end
        f.inventory.items={f.item};f.inventory.nested=bag;f.tool.container=bag
    end
    f.fixture={md={canBeWaterPiped=fixed and nil or true},external=false,fixed=fixed,sq=f.square,changes=0}
    -- Lua's and/or would replace nil with true; preserve an actual fixed sink.
    if fixed then f.fixture.md.canBeWaterPiped=nil end
    function f.fixture:getModData() return self.md end
    function f.fixture:getSquare() return self.sq end
    function f.fixture:getUsesExternalWaterSource() return self.external end
    function f.fixture:setUsesExternalWaterSource(v) self.external=v end
    function f.fixture:transmitModData() self.changes=self.changes+1;f.revision='r2' end
    function f.fixture:sendObjectChange(kind,args) self.changeKind=kind;self.changeValue=args.value end
    function f.fixture:getProperties() return nil end
    function f.fixture:getFluidAmount() return self.external and f.supply or 0 end
    function f.fixture:hasFluid() return self:getFluidAmount()>0 end
    function f.fixture:transferFluidTo(fluid,amount)
        f.transferCalls=(f.transferCalls or 0)+1
        if f.noTransfer then return end
        local gain=math.min(amount,f.supply,2-f.amount)
        f.amount,f.supply=f.amount+gain,f.supply-gain;f.revision='r3'
    end
    function f.body:isEquipped(item) return self.primary==item or self.secondary==item end
    function f.body:isSecondaryHandItem(item) return self.secondary==item end
    function f.body:getVehicle() return nil end
    function f.body:isAttacking() return false end
    function f.body:isAiming() return false end
    function f.body:isClimbing() return false end
    function f.body:isClimbingRope() return false end
    function f.body:playSound(sound) return f.emitter:playSound(sound) end
    function f.body:stopOrTriggerSound(sound) f.emitter:stopOrTriggerSound(sound) end
    function f.body:hasFullInventory() return false end
    function f.body:getFreeInventoryCapacity() return 10 end
    function f.body:getBodyDamage() return {getOverallBodyHealth=function() return 100 end,
        getBodyPart=function() return {getPain=function() return 0 end} end} end
    SAO.Controller.agents[id]=f.agent
    function f:physical(body,sourceId,fp,x,y,z)
        return body==self.body and sourceId==self.sourceId and fp==self.fingerprint and x==0 and y==0 and z==0
            and not self.replaced and self.fixture.sq==self.square
    end
    SAOJavaBridge.worldPlumbTarget=function(_,body,sourceId,fp,rev,x,y,z)
        return f:physical(body,sourceId,fp,x,y,z) and rev==f.revision and f.supply>0
            and not f.fixture.external and (f.fixture.md.canBeWaterPiped==true or f.fixture.fixed)
            and 'READY:0:0:0' or 'NO_NATIVE_SUPPLY'
    end
    SAOJavaBridge.worldPlumbObject=function(_,body,sourceId,fp,rev,x,y,z)
        return f.reachable~=false and SAOJavaBridge:worldPlumbTarget(body,sourceId,fp,rev,x,y,z):sub(1,6)=='READY:' and f.fixture or nil
    end
    SAOJavaBridge.worldPlumbValid=function(_,body,target,sourceId,fp,x,y,z,completed)
        if target~=f.fixture or f.reachable==false or not f:physical(body,sourceId,fp,x,y,z) then return false end
        if completed then return target.external and target.md.canBeWaterPiped==false end
        return not target.external and f.supply>0 and (target.md.canBeWaterPiped==true or target.fixed)
    end
    SAOJavaBridge.worldRefillTarget=function(_,body,sourceId,fp,rev,x,y,z)
        return f:physical(body,sourceId,fp,x,y,z) and rev==f.revision and f.fixture.external and f.supply>0
            and not f.poison and 'READY:0:0:0' or 'NO_CLEAN_WATER'
    end
    SAOJavaBridge.worldRefillObject=function(_,body,sourceId,fp,rev,x,y,z)
        return SAOJavaBridge:worldRefillTarget(body,sourceId,fp,rev,x,y,z):sub(1,6)=='READY:' and f.fixture or nil
    end
    SAOJavaBridge.worldRefillValid=function(_,body,target,sourceId,fp,x,y,z)
        return target==f.fixture and f:physical(body,sourceId,fp,x,y,z) and target.external and f.supply>0 and not f.poison
    end
    SAOJavaBridge.cancelMove=function() return f.routeCancelRefused and 'CANCEL_FAILED' or 'MOVE_CANCELLED' end
    SAOJavaBridge.observeWorldChunk=function()
        f.observeCalls=f.observeCalls+1
        if f.observeUnavailable then return 'H|protocol=SAOWS1|status=UNAVAILABLE|cx=0|cy=0|sources=0\nE' end
        local amount=f.fixture:getFluidAmount()
        local state=amount>0 and not f.poison and 'available' or 'spent'
        return 'H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=0|cy=0|sources=1\n'
            ..'S|id='..f.sourceId..'|fp='..f.fingerprint..'|rev='..f.revision
            ..'|kind=fluid|x=0|y=0|z=0|building=1|explored=1|state='..state
            ..'|access=unknown|container=sink|plumbing='..(f.fixture.external and 'connected' or 'unconnected')
            ..'|q:water='..(f.poison and 0 or amount)..'\n'
            ..'I|source='..f.sourceId..'|id=0|type=|uses=0|amount='..amount
            ..'|fluid=Water|poison='..(f.poison and '1' or '0')..'|rotten=0|cats=water\nE'
    end
    local W,M=SAO.WorldSources,SAO.Perception
    assert(W.observeChunk(0,0))
    f.belief={id=1,cx=.5,cy=.5,z=0,minX=0,maxX=2,minY=0,maxY=2,sources={},
        sourceRevision=f.sourceId..'@r1',sourceFacts={[f.sourceId]=W.beliefFact(f.sourceId)}}
    f.peer={id=1,cx=.5,cy=.5,z=0,minX=0,maxX=2,minY=0,maxY=2,sources={},
        sourceRevision=f.sourceId..'@r1',sourceFacts={[f.sourceId]=W.beliefFact(f.sourceId)}}
    M.beliefs[id]={known={[1]=f.belief}};M.beliefs['peer:'..id]={known={[1]=f.peer}}
    return f
end
local function plan(f)
    local P,R=SAO.ProceduralPlanning,SAO.ResourceProduction
    local context={category='water',pressure=.7,atHours=__hours,needs={fatigue=.1,health=1},
        carriedWater=f.amount,carriedReady=0,carriedRaw=0,sources={},productionOptions=R.options(f.id,f.body,'water')}
    local p,s=P.planResource(f.id,context)
    f.purpose,f.step=p,s
    return p,s
end
local function begin(f)
    local p,s=plan(f)
    return p and type(s)=='table' and SAO.ResourceProduction.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id}) or false
end
local function current(f) return ISTimedActionQueue.getTimedActionQueue(f.body).current end
local function finish(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local n=0
    while q.current do
        n=n+1;if n>4 then error('native preparation loop') end
        local a=q.current
        if a.Type=='ISInventoryTransferAction' then a.getNotFullFloorSquare=function() return nil end;a.playTransferCompleteSound=function() end end
        a:start();a.action.nativeFinished=true
        if a.Type=='SAORefillWaterAction' then a:complete();a:perform()
        else a:perform();if a.Type~='ISInventoryTransferAction' then a:complete() end end
        if q.current==a then error('native queue remained '..a.Type) end
    end
    SAO.ResourceProduction.tick(f.id,f.body)
    return f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
end
local function check(name,value) print(name..'='..tostring(value==true)) end
local function forgedFact(f)
    return {id='resource-production/'..f.id..'/1',actorId=f.id,observerId=f.id,perspective='performed',
        worldHours=__hours,occurredAtHours=__hours,kind='plumbing',category='construction',status='completed',
        sourceId=f.sourceId,itemId=52,itemType='Base.PipeWrench'}
end
local function saved(f)
    local r=__nativeRoundtrip(f.rec);__records[f.id]=r;f.rec=r;f.agent.rec=r
    f.purpose=r.proceduralPlanning.purposes[f.purpose.id];f.step=f.purpose.steps[f.purpose.cursor]
end
function __runPlumbingControl(name)
    local R,C=SAO.ResourceProduction,SAO.Cognition
    local f=fixture('control-'..name)
    if name=='raw-record' then
        assert(begin(f));saved(f);local rec=f.rec;R.interrupt(f.id,f.body,'retire-original')
        __records[f.id]=rec;__reloadProduction();SAO.Controller.agents[f.id]=nil
        local ok=R.reconcileSaved(f.id,f.body)
        check('saved_missing_agent_retirement',ok==true and rec.resourceProductionWork==nil and f.purpose.admission==nil)
    elseif name=='generic-fact' then
        check('generic_plumbing_fact_denied',C.experience(f.id,forgedFact(f))==false)
    else
        f.body.primary=f.tool;assert(begin(f));local a=current(f);a:start()
        if name=='pending-ack' then
            f.body.holdCancellation=true
            check('pending_native_plumb_ack_retained',R.interrupt(f.id,f.body,'pending')==false and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil)
        elseif name=='complete-custody' then
            a.action.nativeFinished=true;a:perform();f.inventory:Remove(f.tool)
            check('changed_tool_before_complete_refuses',a:complete()==false and not f.fixture.external and f.fixture.changes==0)
        else
            local row=finish(f)
            if name=='native-completion' then
                check('native_connection_transition_measured',row and row.status=='completed' and f.fixture.external and f.fixture.changes==1)
            elseif name=='private-refresh' then
                check('handled_connection_private_refresh',row and row.sourceObservation.status=='confirmed'
                    and f.belief.sourceFacts[f.sourceId].plumbing=='connected' and f.peer.sourceFacts[f.sourceId].plumbing=='unconnected')
            end
        end
    end
end
function __runPlumbingCases()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults()
    local f=fixture('flow')
    local options=R.options(f.id,f.body,'water')
    check('dry_observed_local_affordance_offers_no_roof_quantity',#options==1 and options[1].kind=='plumb-fixture'
        and options[1].token=='resource:plumbed' and f.belief.sourceFacts[f.sourceId].quantities.water==0)
    assert(begin(f));local pid=f.purpose.id
    check('admission_neither_connection_nor_water_credit',not f.fixture.external and f.amount==0 and f.purpose.admission~=nil and not f.rec.cognition)
    check('plumbing_preserves_motivating_thirst',R.servesNeed(f.id,f.body,'water') and not R.needInterruption(f.id,f.body,{hunger=.1,thirst=.7,fatigue=.1}))
    local row=finish(f)
    check('native_connection_transition_measured',row and row.status=='completed' and row.nativeOwner=='ISPlumbItem'
        and row.beforePlumbingEligible and row.beforeCanBeWaterPiped and not row.beforeUsesExternalWaterSource
        and row.afterUsesExternalWaterSource and not row.afterCanBeWaterPiped and row.connected and row.toolRetained
        and row.nativeCredit==row.id and f.fixture.changes==1 and f.square.construction)
    check('connection_keeps_same_hydration_purpose',f.purpose.id==pid and f.purpose.status=='maintained'
        and f.purpose.awaitingReassessment and not f.purpose.admission and row.purposeDelivered and f.amount==0)
    check('handled_connection_private_refresh',row.sourceObservation.status=='confirmed'
        and f.belief.sourceFacts[f.sourceId].revision=='r2' and f.belief.sourceFacts[f.sourceId].plumbing=='connected'
        and f.peer.sourceFacts[f.sourceId].revision=='r1' and f.peer.sourceFacts[f.sourceId].plumbing=='unconnected')
    local x=f.rec.cognition and f.rec.cognition.experiences[1]
    check('connection_fact_is_performed_without_water_or_relief',x and x.kind=='plumbing' and x.category=='construction'
        and x.id==row.id and x.thirstDelta==nil and x.hungerDelta==nil and #f.rec.cognition.experiences==1
        and f.rec.cognition.models.ordinary.revision==1 and f.rec.cognition.models.associative.revision==1)
    local canonical=R.outcome(f.id,row.id)
    check('canonical_connection_delivery_once',C.plumbingOutcome(f.id,canonical) and R.onOutcome(f.id,canonical)
        and #f.rec.cognition.experiences==1 and f.rec.cognition.models.ordinary.revision==1)
    local forged=__nativeRoundtrip(canonical);forged.toolItemId='foreign'
    check('forged_connection_receipt_denied',C.plumbingOutcome(f.id,forged)==false and C.plumbingOutcome('other',canonical)==false)
    check('generic_plumbing_fact_denied',C.experience(f.id,forgedFact(f))==false)
    assert(begin(f));check('same_purpose_uses_refreshed_source_for_refill',f.purpose.id==pid and f.step.token=='resource:filled' and f.step.sourceRevision=='r2')
    row=finish(f)
    check('native_refill_completes_same_water_goal',row.kind=='refill-water' and row.nativeGain==2 and row.held and row.clean
        and row.nativeCredit==row.id and f.purpose.id==pid and f.purpose.status=='completed' and f.amount==2 and f.transferCalls==1)
    check('native_refill_adds_separate_private_acquisition',#f.rec.cognition.experiences==2
        and f.rec.cognition.experiences[2].kind=='acquire' and f.rec.cognition.experiences[2].category=='water'
        and f.rec.cognition.experiences[2].thirstDelta==nil and f.rec.cognition.models.ordinary.revision==2
        and f.rec.cognition.models.associative.revision==2)
    saved(f);R.reconcileSaved(f.id,f.body)
    check('saved_canonical_connection_and_refill_no_replay',#f.rec.resourceProductionOutcomes==2
        and #f.rec.cognition.experiences==2 and f.amount==2 and f.fixture.changes==1)
    f=fixture('fixed-sink',false,true);assert(begin(f));row=finish(f)
    check('native_fixed_sink_nil_md_connects',row.status=='completed' and row.beforeCanBeWaterPiped==false
        and row.beforePlumbingEligible and f.fixture.external and f.fixture.md.canBeWaterPiped==false)
    f=fixture('nested',true);assert(begin(f));row=finish(f)
    check('exact_nested_wrench_native_preparation',row.status=='completed' and f.tool:getContainer()==f.inventory
        and not f.inventory.nested:contains(f.tool) and f.body.primary==f.tool and f.inventory:contains(f.item))
    f=fixture('removed-tool');f.body.primary=f.tool;assert(begin(f));local a=current(f);a:start();a.action.nativeFinished=true;a:perform();f.inventory:Remove(f.tool)
    check('changed_tool_before_complete_refuses',a:complete()==false and not f.fixture.external and f.fixture.changes==0)
    R.interrupt(f.id,f.body,'finish-refusal')
    f=fixture('replaced-fixture');f.body.primary=f.tool;assert(begin(f));a=current(f);a:start();a.action.nativeFinished=true;a:perform();f.replaced=true
    check('replaced_fixture_before_complete_refuses',a:complete()==false and not f.fixture.external)
    R.interrupt(f.id,f.body,'finish-refusal')
    f=fixture('synchronous-stop');assert(begin(f));a=current(f);a:start()
    check('synchronous_native_plumb_acknowledged',R.interrupt(f.id,f.body,'danger')==true and not f.rec.resourceProductionWork
        and not f.purpose.admission and not f.fixture.external and f.amount==0)
    f=fixture('pending-stop');f.body.primary=f.tool;assert(begin(f));a=current(f);a:start();f.body.holdCancellation=true
    check('pending_native_plumb_ack_retained',R.interrupt(f.id,f.body,'transfer')==false and f.rec.resourceProductionWork~=nil
        and f.purpose.admission~=nil and current(f)==a and not f.fixture.external)
    f.body.holdCancellation=false;a:stop()
    check('pending_stop_native_ack_releases_claim',not f.rec.resourceProductionWork and not f.purpose.admission and not f.fixture.external)
    f=fixture('death');assert(begin(f));a=current(f);a:start();f.rec.dead=true;f.body.dead=true
    check('death_retirement_cancels_exact_native_action',R.detach(f.id,f.body,'death')==true and not f.fixture.external
        and not f.rec.resourceProductionWork and not f.purpose.admission)
    f=fixture('changed-token');f.body.primary=f.tool;assert(begin(f));a=current(f);a:start();f.body.md.SAOExternalToken='foreign';a.action.nativeFinished=true
    check('changed_body_token_refuses_native_effect',a:perform()==false and not f.fixture.external)
    f.body.md.SAOExternalToken=nil;R.interrupt(f.id,f.body,'finish-refusal')
    f=fixture('duplicate');f.body.primary=f.tool;assert(begin(f));a=current(f);row=finish(f);a:complete();a:perform()
    check('duplicate_native_callbacks_are_inert',f.fixture.changes==1 and #f.rec.resourceProductionOutcomes==1 and #f.rec.cognition.experiences==1)
    f=fixture('no-supply');f.supply=0
    check('private_affordance_does_not_invent_native_supplier',#R.options(f.id,f.body,'water')==1 and begin(f)==false and not f.fixture.external)
    f=fixture('empty-after-connection');assert(begin(f));row=finish(f);f.supply=0
    check('connection_custody_independent_of_empty_supply',SAOJavaBridge:worldPlumbValid(f.body,f.fixture,f.sourceId,f.fingerprint,0,0,0,true)==true
        and row.status=='completed' and SAOJavaBridge:worldRefillTarget(f.body,f.sourceId,f.fingerprint,'r2',0,0,0)=='NO_CLEAN_WATER')
    f=fixture('poison-after-connection');assert(begin(f));row=finish(f);f.poison=true
    check('connected_fixture_does_not_authorize_poison_refill',row.status=='completed'
        and SAOJavaBridge:worldRefillTarget(f.body,f.sourceId,f.fingerprint,'r2',0,0,0)=='NO_CLEAN_WATER')
    f=fixture('private-denial');SAO.Perception.beliefs[f.id].known={}
    check('foreign_fixture_fact_never_becomes_actor_option',#R.options(f.id,f.body,'water')==0)
    f=fixture('reload');f.body.primary=f.tool;assert(begin(f));a=current(f);a:start();saved(f);f.body.holdCancellation=true;__reloadProduction()
    check('saved_pending_native_owner_keeps_custody',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil)
    f.body.holdCancellation=false;SAO.Controller.agents[f.id]=nil
    check('saved_missing_agent_retirement',R.reconcileSaved(f.id,f.body)==true and not f.rec.resourceProductionWork
        and not f.purpose.admission and not f.fixture.external and f.amount==0
        and f.rec.resourceProductionOutcomes[1].nativeObservability=='runtime-unavailable')
    f=fixture('stale-admission');assert(begin(f));saved(f);__reloadProduction();f.purpose.admission.correlationId='foreign'
    check('saved_stale_admission_refuses_retirement',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil and not f.fixture.external)
end
