-- Actual installed machinery/reading actions + actual Java generator/items/fluid/power.
-- Actor, animation dispatch, nested-container routing, UI/network are controlled.
Perks.Electricity='Electricity';Fluid={Petrol='Petrol'};SkillBook={}
CharacterActionAnims={Read='Read'}
ItemContainer={floatingPointCorrection=function(v) return v end}
ItemTag.UNINTERESTING='Uninteresting';ItemTag.FAST_READ='FastRead';ItemTag.BOOK='Book'
CharacterTrait.ILLITERATE='Illiterate';CharacterTrait.FAST_READER='FastReader';CharacterTrait.SLOW_READER='SlowReader'
CharacterTrait.HERBALIST='Herbalist';CharacterTrait.HERBALIST_PROF='HerbalistProf'
ItemBodyLocation={EYES='Eyes'};CharacterStat={BOREDOM='Boredom',UNHAPPINESS='Unhappiness',STRESS='Stress'}
Metabolics.UsingTools='UsingTools';Metabolics.HeavyDomestic='HeavyDomestic';Metabolics.SeatedRest='SeatedRest'
SAO.History.ticks=function() return math.floor(__hours*9000) end
SAO.History.literacyOf=function() return 'full' end
SAO.Conditions={readingTime=function() return 1 end};SAO.Census={JOB_PERK={}}
SAO.Needs.ownsRecoveryBody=function(id,body)
    local r=__records[id];return r and not r.dead and SAO.Body.get(id)==body and not r.zaoTransferPending
        and body:getModData().SAOExternalToken==r.bodyOwnerToken
end
SAO.Needs.workAvailable=function(body) return not SAO.Needs.busy(body) end
function getSandboxOptions() return {getOptionByName=function() return {getValue=function() return 1 end} end} end
function getGameTime() return {getMinutesPerDay=function() return 1440 end,getMultiplier=function() return 1 end} end
function sendServerCommand() end
function sendSyncPlayerFields() end
function syncItemFields() end
function addXp(body,perk,amount) body.xp=(body.xp or 0)+amount end
function addXpMultiplier() end
local random
function ZombRand(n) return random~=nil and random or 1 end
IsoGenerator={isPoweringSquare=function() return __generatorNative('get','covered') end}
local underlyingInstance=instanceof
function instanceof(o,kind) return underlyingInstance(o,kind) or type(o)=='table' and kind=='Literature' and o.fullType=='Base.ElectronicsMag4' end
local checks={}
local function check(name,value) checks[#checks+1]=name;print('CHECK '..name..'='..tostring(value==true)) end
local function square(f,x,y)
    local sq={x=x,y=y,z=0,outside=true}
    function sq:getX() return self.x end;function sq:getY() return self.y end;function sq:getZ() return self.z end
    function sq:isOutside() return self.outside end;function sq:getRoom() return nil end
    function sq:TreatAsSolidFloor() return true end;function sq:isSolid() return false end;function sq:isSolidTrans() return false end
    function sq:isBlockedTo() return false end;function sq:isWindowTo() return false end;function sq:HasStairs() return false end
    function sq:getTotalWeightOfItemsOnFloor() return 0 end
    f.cell.squares[x..':'..y..':0']=sq;return sq
end
local function position(f,x,y)
    f.body.x,f.body.y=x+.5,y+.5;f.body.here=f.cell.squares[x..':'..y..':0'] or square(f,x,y)
    __generatorNative('position',x,y)
end
local function item(f,kind)
    local id=__generatorNative('new-item','Base.'..kind)
    local i=__boardingItem(kind,id,f.inventory)
    function i:getFluidContainer()
        if kind~='PetrolCan' then return nil end
        return f.fuelFluid
    end
    function i:getNumberOfPages() return kind=='ElectronicsMag4' and __generatorNative('item',id,'pages') or 0 end
    function i:getSkillTrained() return nil end
    function i:getReadType() return nil end
    function i:canBeWrite() return false end
    function i:hasTag(tag) return tag==ItemTag.FAST_READ or kind=='ElectronicsMag4' and tag=='Magazine' end
    function i:getLearnedRecipes() return {contains=function(_,name) return name=='Generator' and __generatorNative('item',id,'manual') end,isEmpty=function() return false end} end
    function i:hasModData() return false end
    function i:getModData() return {} end
    function i:getAlreadyReadPages() return 0 end
    function i:setAlreadyReadPages() end
    function i:setJobDelta(v) self.jobDelta=v end
    function i:getStaticModel() return kind end
    function i:getUnequippedWeight() return 1 end
    function i:isOnGroundOrInsideBagOnSquare() return false end
    function i:syncItemFields() end
    f.inventory.items[#f.inventory.items+1]=i
    return i
end
local function privateFact(f,prefix)
    for _,place in pairs(SAO.Perception.knownPlaces(f.id,true) or {}) do for _,raw in pairs(place.sourceFacts or {}) do
        local id=raw.sourceId or raw.id
        if id:sub(1,2)==prefix then local out={} for k,v in pairs(raw) do out[k]=v end;out.sourceId=id;return out end
    end end
end
local function fixture(id,variant,condition,fuel,skill,uninspected,initialState)
    local f=__plumbingFixture(id,false)
    f.rec.claim={minX=0,minY=0,maxX=30,maxY=30,z=0};f.inventory.items={};f.rec.bodyOwnerToken=nil;f.body.md.SAOExternalToken=nil
    f.body.shell=true;f.body.dead=false
    __generatorNative('reset',variant or 'Base.Generator',id,condition or 40,fuel or 0,skill or 4)
    position(f,11,20);f.genSquare=square(f,10,20);f.consumerSquare=square(f,14,20)
    f.generator={kind='IsoGenerator'}
    function f.generator:getSquare() return f.genSquare end
    function f.generator:getObjectIndex() return f.replaced and -1 or __generatorNative('get','index') end
    function f.generator:getCondition() return __generatorNative('get','condition') end
    function f.generator:setCondition(v) __generatorNative('set','condition',v) end
    function f.generator:getFuel() return __generatorNative('get','fuel') end
    function f.generator:getMaxFuel() return __generatorNative('get','maxFuel') end
    function f.generator:getFuelPercentage() return self:getFuel()/self:getMaxFuel()*100 end
    function f.generator:setFuel(v) __generatorNative('set','fuel',v) end
    function f.generator:isConnected() return __generatorNative('get','connected') end
    function f.generator:setConnected(v) __generatorNative('set','connected',v) end
    function f.generator:isActivated() return __generatorNative('get','active') end
    function f.generator:setActivated(v) __generatorNative('set','active',v) end
    function f.generator:failToStart() __generatorNative('fail-start') end
    function f.generator:sync() f.syncs=(f.syncs or 0)+1 end
    f.consumer={kind='IsoObject',getSquare=function() return f.consumerSquare end}
    function f.body:getPerkLevel() return __generatorNative('get','skill') end
    function f.body:SetVariable(key,value) self[key]=value end
    f.body.setVariable=f.body.SetVariable
    function f.body:isRecipeActuallyKnown(name) return name=='Generator' and __generatorNative('get','known') end
    function f.body:removeFromHands(value) if self.primary==value then self.primary=nil end;if self.secondary==value then self.secondary=nil end end
    function f.body:isPrimaryHandItem(value) return self.primary==value end
    function f.body:hasTrait() return false end
    function f.body:tooDarkToRead() return false end
    function f.body:getAlreadyReadPages() return 0 end
    function f.body:setAlreadyReadPages() end
    function f.body:getWornItems() return {getItem=function() return nil end} end
    function f.body:isSitting() return false end
    function f.body:getStats() return {get=function() return 0 end} end
    function f.body:setReading(value) self.reading=value end
    function f.body:isReading() return self.reading==true end
    function f.body:getAlreadyReadBook() return {add=function() end} end
    function f.body:ReadLiterature(value) __generatorNative('read',value:getID()) end
    function f.body:learnRecipe(name) return __generatorNative('learn',name) end
    function f.body:getOnlineID() return 0 end
    f.scrap=item(f,'ElectronicsScrap');f.petrol=item(f,'PetrolCan');f.manual=item(f,'ElectronicsMag4')
    f.fuelFluid={getAmount=function() return __generatorNative('item',f.petrol:getID(),'amount') end,
        getCapacity=function() return __generatorNative('item',f.petrol:getID(),'capacity') end,
        contains=function(_,fluid) return fluid==Fluid.Petrol and __generatorNative('item',f.petrol:getID(),'petrol') end,
        adjustAmount=function(_,amount) __generatorNative('drain',f.petrol:getID(),amount) end}
    local remove=f.inventory.Remove
    function f.inventory:getEffectiveCapacity() return 50 end
    function f.inventory:getPutSound() return nil end
    function f.inventory:Remove(value) remove(self,value);__generatorNative('remove',value:getID()) end
    function f.inventory:containsTypeRecurse(kind) return self:getFirstTypeRecurse(kind)~=nil end
    local function nativePosition(body) assert(body==f.body);__generatorNative('position',math.floor(body:getX()),math.floor(body:getY())) end
    SAOJavaBridge.worldGeneratorCandidates=function(_,body) nativePosition(body);return __generatorNative('wire-generators') end
    SAOJavaBridge.worldGeneratorConsumer=function(_,body,object) nativePosition(body);return object==f.consumer and __generatorNative('wire-consumer') or '' end
    SAOJavaBridge.worldGeneratorTarget=function(_,body,id,fp,rev,x,y,z,op) nativePosition(body);return __generatorNative('target',id,fp,rev,op) end
    SAOJavaBridge.worldGeneratorObject=function(_,body,id,fp,rev,x,y,z,op)
        nativePosition(body);return not f.replaced and __generatorNative('object',id,fp,rev,op) and f.generator or nil
    end
    SAOJavaBridge.worldGeneratorValid=function(_,body,object,id,fp,x,y,z,op)
        nativePosition(body);return object==f.generator and not f.replaced and __generatorNative('valid',id,fp,op)
    end
    SAOJavaBridge.worldGeneratorConsumerTarget=function(_,body,id,fp,rev,x,y,z)
        nativePosition(body);return __generatorNative('consumer-target',id,fp,rev)
    end
    SAOJavaBridge.worldGeneratorConsumerObject=function(_,body,id,fp,rev,x,y,z)
        nativePosition(body);return __generatorNative('consumer-object',id,fp,rev) and f.consumer or nil
    end
    SAOJavaBridge.worldGeneratorConsumerPowered=function(_,body,object,id,fp,x,y,z)
        nativePosition(body);return object==f.generator and __generatorNative('consumer-power',id,fp)
    end
    SAO.Locomotion.order=function(id,body,x,y,z)
        local job={body=body,x=x,y=y,z=z,done=false};SAO.Locomotion.jobs[id]=job;return true
    end
    SAO.Locomotion.tick=function(id) local job=SAO.Locomotion.jobs[id];position(f,job.x,job.y);job.done=true;job.result='arrived' end
    position(f,13,20);assert(SAO.Perception.rememberGeneratorConsumer(id,f.body,f.consumer));f.consumerFact=privateFact(f,'E:')
    position(f,uninspected and 6 or 11,20);assert(SAO.Perception.observeGenerators(id,f.body,SAO.History.ticks()));f.generatorFact=privateFact(f,'J:')
    f.intent={consumer=f.consumerFact,requestingPurposeId='meal:'..id,requestingActivity='cook exact food',foodItemId='77'}
    f.agent.state=initialState or 'RESOURCE';return f
end
local function plan(f,operation)
    local G,P=SAO.Generator,SAO.ProceduralPlanning
    local options=G.options(f.id,f.body,f.intent)
    if operation then local out={} for _,o in ipairs(options) do if o.operation==operation then out[#out+1]=o end end;options=out end
    local p,s=P.planGenerator(f.id,{intent=f.intent,options=options,sources={},pressure=.8,atHours=__hours})
    f.purpose,f.step=p,s;return p,s
end
local function begin(f,operation)
    local p,s=plan(f,operation)
    if not p or type(s)~='table' then print('PLAN_REFUSED '..f.id..' '..tostring(s));return false end
    if s.owner=='SAO.Study' then return SAO.Study.beginGenerator(f.id,f.body,f.manual,p.id,s.id) end
    local accepted=SAO.Generator.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
    if not accepted then print('BEGIN_REFUSED '..f.id..' status='..tostring(s.status)..' op='..tostring(s.operation)..' input='..tostring(s.inputItemId)
        ..' target='..tostring(SAO.WorldSources.generatorTarget(f.body,s.generator,s.operation))..' work='..tostring(f.rec.resourceProductionWork~=nil)
        ..' admission='..tostring(p.admission~=nil)) end
    return accepted
end
local function current(f) return ISTimedActionQueue.getTimedActionQueue(f.body).current end
local function finish(f)
    local n=0
    while current(f) do n=n+1;if n>4 then error('unexpected continuation') end
        local a=current(f);a:start();a.action.nativeFinished=true;a.action.jobDelta=1
        if a.readingKind=='generator-reading' then
            f.rec.studyWork.progress=1;f.rec.studyWork.phase='executing';a:complete();a:perform()
        else a:perform();if a.complete then a:complete() end end
    end
end
local function row(f) return SAO.Generator.outcome(f.id,f.rec.generatorSequence) end
local function pendingCase()
    local f=fixture('pending');assert(begin(f));local a=current(f);a:start();f.body.holdCancellation=true
    local pending=SAO.Generator.interrupt(f.id,f.body,'threat')==false and f.rec.resourceProductionWork~=nil
        and f.purpose.admission~=nil and current(f)==a and f.generator:getCondition()==40
    f.body.holdCancellation=false
    return pending and SAO.Generator.interrupt(f.id,f.body,'threat')==true and row(f).status=='interrupted'
        and not f.purpose.admission and f.inventory:contains(f.scrap) and not row(f).nativeCredit
end
local function paymentCase()
    local f=fixture('changed-payment');assert(begin(f,'repair'));local a=current(f);a:start();a.action.nativeFinished=true;a:perform()
    local other=item(f,'ElectronicsScrap');table.insert(f.inventory.items,1,table.remove(f.inventory.items))
    a:complete();SAO.Generator.interrupt(f.id,f.body,'payment-changed')
    return f.generator:getCondition()==40 and f.inventory:contains(f.scrap) and f.inventory:contains(other) and row(f).status=='interrupted'
end
local function consumerCase()
    local f=fixture('return',nil,100,1,4);__generatorNative('set','connected',true);__generatorNative('set','active',true)
    assert(SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks()))
    local admitted=begin(f,'verify-power')
    local retained=admitted and f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage=='approaching' and not row(f)
    if admitted then SAO.Generator.tick(f.id,f.body) end
    local outcome=row(f)
    return retained and outcome and outcome.status=='completed' and outcome.sourceCovered and outcome.consumerPowered
        and outcome.consumerAfter.powered and math.floor(f.body:getX())==13 and not f.purpose.admission
end
local function readingCase()
    local f=fixture('reading',nil,40,0,0)
    local options=SAO.Generator.options(f.id,f.body,f.intent)
    local eligible=options[1] and options[1].knowledgeRequired and options[1].materialCategory=='generator-manual'
        and options[1].inputItemId==tostring(f.manual:getID()) and not f.body:isRecipeActuallyKnown('Generator')
    local admitted=begin(f,'repair');if admitted then finish(f) end
    local r=f.rec.studyWork and SAO.Study.generatorOutcome(f.id,f.rec.studyWork.id)
    return eligible and admitted and r and r.status=='completed' and r.nativeCompleted and r.recipeKnown
        and f.body:isRecipeActuallyKnown('Generator') and not f.purpose.admission
end
local function savedCase()
    local f=fixture('reload');assert(begin(f));local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.agent.rec=saved
    saved.zaoTransferPending={reason='owned transfer'};SAO.Controller.agents[f.id]=nil;f.body.holdCancellation=true
    __reloadGeneratorOwner('generator.lua');local retained=SAO.Generator.reconcileSaved(f.id,f.body)==false and saved.resourceProductionWork~=nil
    f.body.holdCancellation=false;local reconciled=SAO.Generator.reconcileSaved(f.id,f.body)
    local outcome=SAO.Generator.outcome(f.id,1)
    return reconciled and retained and not saved.resourceProductionWork and not saved.proceduralPlanning.purposes[f.purpose.id].admission
        and outcome and outcome.status=='interrupted' and f.generator:getCondition()==40 and f.inventory:contains(f.scrap)
end
function __runGeneratorCases()
    for i,type in ipairs({'Base.Generator','Base.Generator_Yellow','Base.Generator_Blue','Base.Generator_Old'}) do
        local f=fixture('variant-'..i,type,40,0,4)
        check('native_variant_registered_'..i,f.generatorFact.inspected and f.generatorFact.condition==40 and f.generatorFact.fuel==0)
        check('repair_admitted_without_effect_'..i,begin(f,'repair') and f.generator:getCondition()==40 and f.inventory:contains(f.scrap) and not row(f))
        local a=current(f);finish(f);local repair=row(f)
        check('native_one_scrap_repair_'..i,repair and repair.status=='completed' and repair.inputConsumed and f.generator:getCondition()==46
            and not f.inventory:contains(f.scrap) and not __generatorNative('item',f.scrap:getID(),'held') and f.body.xp==5 and not current(f))
        if i==1 then
            local cognition=f.rec.cognition
            check('actual_generator_fact_both_models',cognition and #cognition.experiences==1
                and cognition.experiences[1].kind=='generator-operation' and cognition.experiences[1].actionKind=='repair'
                and cognition.experiences[1].sourceId==repair.sourceId and cognition.experiences[1].consumerId==repair.consumerId
                and cognition.models.ordinary.revision==1 and cognition.models.associative.revision==1)
            local before=cognition and #cognition.experiences or 0
            local canonical=SAO.Generator.outcome(f.id,repair.id)
            SAO.Generator.onOutcome(f.id,canonical)
            check('canonical_generator_fact_once_saved',cognition and #cognition.experiences==before
                and __nativeRoundtrip(f.rec).cognition.experiences[1].id==cognition.experiences[1].id)
            check('generic_generator_fact_denied',SAO.Cognition.experience(f.id,{id=repair.id,actorId=f.id,observerId=f.id,
                worldHours=__hours,occurredAtHours=__hours,kind='generator-operation',category='utilities',perspective='performed',
                status='completed',sourceId=repair.sourceId,consumerId=repair.consumerId,actionKind='repair',succeeded=true,
                itemId=tonumber(repair.inputItemId),itemType=repair.inputItemType,beforeValue=40,afterValue=46})==false)
        end
        local cursor=f.rec.proceduralPlanning.outcomeCursor;local count=#f.rec.generatorOutcomes
        a:complete();check('native_callback_once_'..i,#f.rec.generatorOutcomes==count and f.generator:getCondition()==46 and cursor==f.rec.proceduralPlanning.outcomeCursor)
        -- Move condition above the native owner's preferred repair pressure; this is explicit fixture setup.
        __generatorNative('set','condition',100);SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks())
        check('native_fuel_admitted_'..i,begin(f,'fuel'));finish(f);local fuelRow=row(f)
        check('native_fuel_mass_balance_'..i,fuelRow.status=='completed' and fuelRow.inputRetained and fuelRow.afterFuel>0
            and math.abs(fuelRow.afterFuel-fuelRow.beforeFuel-(fuelRow.beforeInputAmount-fuelRow.afterInputAmount))<.0001)
        check('native_connect_admitted_'..i,begin(f,'connect'));finish(f);local connected=row(f)
        check('native_connection_measured_'..i,connected.status=='completed' and not connected.beforeConnected and connected.afterConnected)
        check('native_activation_admitted_'..i,begin(f,'activate'));finish(f);local active=row(f)
        check('native_activation_power_'..i,active.status=='completed' and active.afterActive and __generatorNative('get','powered'))
        check('native_variant_saved_'..i,__nativeRoundtrip(f.rec).generatorOutcomes[4].nativeCredit==active.id)
    end
    check('changed_native_payment_refused',paymentCase())
    check('pending_native_ack_retained',pendingCase())
    check('return_to_reached_consumer',consumerCase())
    check('native_manual_learns_generator',readingCase())
    local f=fixture('failed-start',nil,40,1,0);__generatorNative('set','connected',true);SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks())
    local offered=false;for _,o in ipairs(SAO.Generator.options(f.id,f.body,f.intent)) do if o.operation=='activate' and not o.knowledgeRequired then offered=true end end
    random=0;local admitted=begin(f,'activate');if admitted then finish(f) end;random=nil
    local failed=row(f)
    check('native_low_condition_failed_start',offered and admitted and failed and failed.status=='failed' and failed.nativeAttempted
        and failed.nativeCompleted and not failed.afterActive and not failed.nativeCredit and not __generatorNative('get','powered'))
    check('saved_generator_interrupt_no_replay',savedCase())
    f=fixture('death');assert(begin(f));local a=current(f);a:start();f.rec.dead=true;f.body.dead=true
    check('death_native_cancellation',SAO.Generator.interrupt(f.id,f.body,'death') and row(f).status=='interrupted' and f.generator:getCondition()==40)
    f=fixture('malformed',nil,100,0,4);assert(begin(f,'fuel'));finish(f)
    local original=f.rec.generatorOutcomes[1].afterInputAmount;f.rec.generatorOutcomes[1].afterInputAmount=nil
    local ok,value=pcall(SAO.Generator.outcome,f.id,1)
    check('malformed_saved_fuel_refused',ok and value==nil);f.rec.generatorOutcomes[1].afterInputAmount=original
    local canonical=SAO.Generator.outcome(f.id,1);canonical.afterFuel=999
    check('forged_generator_fact_refused',SAO.Cognition.generatorOutcome(f.id,canonical)==false)
    f=fixture('inspect',nil,40,0,4,true)
    SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks())
    local partial=privateFact(f,'J:');local admitted=begin(f,'inspect')
    if admitted then SAO.Generator.tick(f.id,f.body);finish(f) end
    local inspected=row(f)
    check('native_inspection_routes_and_measures',partial and not partial.inspected and partial.condition==nil
        and admitted and inspected and inspected.status=='completed' and inspected.generatorAfter.inspected
        and inspected.generatorAfter.condition==40 and inspected.nativeOwner=='ISGeneratorInfoAction/SAO.Generator')
    f=fixture('nested-fuel',nil,100,0,4)
    local bag={items={f.petrol}};__boardingInventory(bag,f.inventory)
    function bag:contains(i) return self.items[1]==i end
    function bag:Remove(i) if self.items[1]==i then self.items={};i.container=nil end end
    for j,v in ipairs(f.inventory.items) do if v==f.petrol then table.remove(f.inventory.items,j);break end end
    f.inventory.nested=bag;f.petrol.container=bag
    admitted=begin(f,'fuel');if admitted then finish(f) end
    local nested=row(f)
    check('nested_exact_fuel_native_preparation',admitted and nested and nested.status=='completed' and #bag.items==0
        and f.petrol:getContainer()==f.inventory and f.body:getPrimaryHandItem()==f.petrol and nested.inputRetained)
    f=fixture('token-change');assert(begin(f));a=current(f);a:start();f.body.md.SAOExternalToken='replacement';a.action.nativeFinished=true
    local refused=a:perform()==false and f.generator:getCondition()==40
    check('changed_body_token_refused',refused and SAO.Generator.interrupt(f.id,f.body,'body-changed') and row(f).status=='interrupted')
    f=fixture('reading-reload',nil,40,0,0);assert(begin(f,'repair'));a=current(f);a:start()
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.agent.rec=saved;saved.zaoTransferPending={reason='transfer'}
    SAO.Controller.agents[f.id]=nil;f.body.holdCancellation=true;__reloadGeneratorOwner('study.lua')
    local retained=SAO.Study.reconcileGeneratorReading(f.id,f.body)==false and saved.studyWork.status=='reading'
    f.body.holdCancellation=false;local reconciled=SAO.Study.reconcileGeneratorReading(f.id,f.body)
    local reading=SAO.Study.generatorOutcome(f.id,saved.studyWork.id)
    check('saved_reading_native_ack_no_learning',retained and reconciled and reading and reading.status=='interrupted'
        and not reading.recipeKnown and not f.body:isRecipeActuallyKnown('Generator')
        and not saved.proceduralPlanning.purposes[f.purpose.id].admission)
    print('PASS generator native '..#checks)
end
function __runGeneratorControl(name)
    local value
    if name=='changed_native_payment_refused' then value=paymentCase()
    elseif name=='pending_native_ack_retained' then value=pendingCase()
    elseif name=='return_to_reached_consumer' then value=consumerCase()
    elseif name=='native_manual_learns_generator' then value=readingCase()
    elseif name=='saved_generator_interrupt_no_replay' then value=savedCase()
    else error('unknown control '..name) end
    check(name,value)
end
__generatorFixture=fixture;__generatorFinish=finish;__generatorBegin=begin;__generatorCurrent=current

-- Focused first-review correction: actual Controller dispatch and its ordinary
-- Study/IDLE gate, using the real native reading owner instead of a receipt stub.
local function readingControllerCase(kind)
    local f=fixture('controller-read-'..kind,nil,40,0,0,false,'IDLE')
    f.inventory:Remove(f.petrol)
    f.rec.cookingPowerDemand=f.intent
    local tick=SAO.History.ticks()
    __generatorOrdinaryTick(f.id,f.agent,f.body,tick,{hunger=.8,fatigue=.1})
    local purpose=SAO.ProceduralPlanning.generatorPurpose(f.id)
    local reading=f.rec.studyWork;local a=current(f)
    if not purpose or not reading or reading.kind~='generator-reading' or not a then return false end
    local originalPurpose=purpose.id
    if kind=='completion' then
        finish(f)
        local row=SAO.Study.generatorOutcome(f.id,reading.id)
        __hours=__hours+.1
        __generatorOrdinaryTick(f.id,f.agent,f.body,SAO.History.ticks(),{hunger=.8,fatigue=.1})
        local nextWork=f.rec.resourceProductionWork
        return row and row.status=='completed' and row.recipeKnown and f.body:isRecipeActuallyKnown('Generator')
            and nextWork and nextWork.operation=='repair' and nextWork.purposeId==originalPurpose
            and f.agent.state=='RESOURCE' and current(f) and current(f).generator==f.generator
    elseif kind=='pending' then
        a:start();f.body.holdCancellation=true;f.rec.zaoTransferPending={reason='transfer'}
        __hours=__hours+.1
        __generatorOrdinaryTick(f.id,f.agent,f.body,SAO.History.ticks(),{hunger=.8,fatigue=.1})
        local retained=f.rec.studyWork.status=='reading' and purpose.admission~=nil and current(f)==a
            and not f.rec.resourceProductionWork and f.agent.state=='IDLE'
        f.body.holdCancellation=false
        return retained and SAO.Study.interrupt(f.id,f.body,'transfer') and not purpose.admission
            and not f.body:isRecipeActuallyKnown('Generator')
    elseif kind=='replacement' then
        a:start();f.body.holdCancellation=true
        local successor={character=f.body,kept=true};local old=ISTimedActionQueue.queues[f.body]
        local replacement={current=successor,queue={successor}}
        function replacement:indexOf(action) return action==successor and 1 or -1 end
        function replacement:removeFromQueue(action) if action==successor then self.queue={} end end
        ISTimedActionQueue.queues[f.body]=replacement
        __hours=__hours+.1
        __generatorOrdinaryTick(f.id,f.agent,f.body,SAO.History.ticks(),{hunger=.8,fatigue=.1})
        local retained=f.rec.studyWork.status=='reading' and purpose.admission~=nil and not f.rec.resourceProductionWork
            and (f.body.stopRequests or 0)>0
        f.body.holdCancellation=false
        a:stop()
        return retained and replacement.current==successor and #replacement.queue==1 and successor.kept
            and old:indexOf(a)==-1 and not purpose.admission and f.agent.state=='IDLE'
            and not f.body:isRecipeActuallyKnown('Generator')
    end
end
function __runGeneratorReadingControllerCases()
    check('controller_native_reading_resumes_same_utility',readingControllerCase('completion'))
    check('controller_pending_reading_ack_keeps_claim',readingControllerCase('pending'))
    check('controller_replacement_queue_preserves_successor',readingControllerCase('replacement'))
    print('PASS generator reading Controller 3')
end
function __runGeneratorReadingControllerControl(name)
    local ok,value=pcall(readingControllerCase,'completion')
    check(name,ok and value)
end

-- PR147 corrections reuse the installed native producers above. Additional
-- machinery facts below are obtained from actual created objects and personal
-- observation; ordering is an explicit persistence-iteration receiver.
local function readingQueueCase(kind)
    local f=fixture('review-reading-'..kind,nil,40,0,0)
    local verified=SAO.Needs.queueVerified
    local successor,oldQueue,replacement
    if kind=='refused' or kind=='refused-other' then
        SAO.Needs.queueVerified=function(action)
            if kind=='refused-other' then
                successor={character=f.body,kept=true};replacement={current=successor,queue={successor}}
                function replacement:indexOf(a) return a==successor and 1 or -1 end
                function replacement:removeFromQueue(a) if a==successor then self.queue={} end end
                ISTimedActionQueue.queues[f.body]=replacement
            end
            return false
        end
    elseif kind=='queued-refused' then
        f.body.holdCancellation=true
        SAO.Needs.queueVerified=function(action) verified(action);return false end
    end
    local admitted=begin(f,'repair');SAO.Needs.queueVerified=verified
    local w=f.rec.studyWork;local p=f.purpose
    if not w or not p then return false end
    if kind=='refused' or kind=='refused-other' then
        local result=SAO.Study.generatorOutcome(f.id,w.id)
        return not admitted and w.status=='interrupted' and not p.admission and result and result.status=='interrupted'
            and not result.nativeStarted and not result.nativeCompleted and not result.recipeKnown
            and not f.body:isRecipeActuallyKnown('Generator')
            and (kind=='refused' or replacement.current==successor and replacement.queue[1]==successor and successor.kept)
    end
    local a=current(f)
    if not a or kind~='queued-refused' and not admitted or kind=='queued-refused' and admitted then return false end
    if kind~='queued-refused' then a:start();f.body.holdCancellation=true end
    oldQueue=ISTimedActionQueue.queues[f.body]
    if kind=='disappeared' then oldQueue.queue={};oldQueue.current=nil
    elseif kind=='changed' then
        successor={character=f.body,kept=true};replacement={current=successor,queue={successor}}
        function replacement:indexOf(action) return action==successor and 1 or -1 end
        function replacement:removeFromQueue(action) if action==successor then self.queue={} end end
        ISTimedActionQueue.queues[f.body]=replacement
    end
    local active=SAO.Study.active(f.id,f.body)
    local retained=active and w.status=='reading' and p.admission~=nil and (f.body.stopRequests or 0)>0
        and not f.body:isRecipeActuallyKnown('Generator') and not a:complete()
    f.body.holdCancellation=false
    local retired=SAO.Study.active(f.id,f.body)==false
    local result=SAO.Study.generatorOutcome(f.id,w.id)
    return retained and retired and result and result.status=='interrupted' and not result.recipeKnown and not p.admission
        and oldQueue:indexOf(a)==-1 and oldQueue.current~=a
        and (kind~='changed' or replacement.current==successor and #replacement.queue==1 and successor.kept)
end
local function retainedCapCase(rejectOthers)
    local f=fixture('review-cap',nil,100,0,4)
    if not rejectOthers then f.intent.generator=f.generatorFact end
    for index=1,rejectOthers and 32 or 35 do
        local x=2+((index-1)%7)*4;local y=10+math.floor((index-1)/7)*4
        __generatorNative('extra-generator',x,y);position(f,x+1,y)
        SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks())
    end
    if rejectOthers then
        local rejected={}
        for _,place in pairs(SAO.Perception.knownPlaces(f.id,true)) do for _,row in pairs(place.sourceFacts or {}) do
            local id=row.sourceId or row.id
            if id:sub(1,2)=='J:' and id~=f.generatorFact.sourceId then rejected[id]=row.fingerprint end
        end end
        f.intent.rejectedGenerators=__nativeRoundtrip(rejected)
    end
    local originalPairs=pairs
    local function orderedOptions(reverse)
        local known=SAO.Perception.knownPlaces(f.id,true);local keys={};local count=0
        for key,place in originalPairs(known) do
            local retained=false;for _,row in originalPairs(place.sourceFacts or {}) do
                if (row.sourceId or row.id)==f.generatorFact.sourceId then retained=true end
                if (row.sourceId or row.id):sub(1,2)=='J:' then count=count+1 end
            end
            keys[#keys+1]={key=key,retained=retained}
        end
        table.sort(keys,function(a,b) if a.retained~=b.retained then return not a.retained end
            return reverse and tostring(a.key)>tostring(b.key) or not reverse and tostring(a.key)<tostring(b.key) end)
        pairs=function(value)
            if value~=known then return originalPairs(value) end
            local index=0;return function() index=index+1;local row=keys[index];if row then return row.key,known[row.key] end end
        end
        local options=SAO.Generator.options(f.id,f.body,f.intent);pairs=originalPairs
        return count>32 and #options==1 and options[1].generator.sourceId==f.generatorFact.sourceId
            and options[1].generator.fingerprint==f.generatorFact.fingerprint
    end
    local before=orderedOptions(false)
    SAO.Perception.beliefs[f.id]=__nativeRoundtrip(SAO.Perception.beliefs[f.id])
    return before and orderedOptions(true)
end
local function driftCase(kind)
    local f=fixture('review-drift-'..kind,nil,100,kind=='fuel' and 0 or 1,4)
    if kind~='fuel' then __generatorNative('set','connected',true);__generatorNative('set','active',true)
        SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks()) end
    local p,s=plan(f,kind=='fuel' and 'fuel' or 'verify-power')
    if not p or type(s)~='table' then return false end
    local purposeId=p.id;f.intent.generator=s.generator
    if kind=='during-return' then
        local admitted=SAO.Generator.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
        if not admitted or not f.rec.resourceProductionWork or f.rec.resourceProductionWork.stage~='approaching' then return false end
        __generatorNative('set','fuel',0);__generatorNative('set','active',false)
        SAO.Generator.tick(f.id,f.body)
        if not f.rec.resourceProductionWork or f.rec.resourceProductionWork.stage~='approaching' then return false end
        SAO.Generator.tick(f.id,f.body)
    else
        position(f,22,20)
        if kind=='fuel' then __generatorNative('set','fuel',2)
        else __generatorNative('set','fuel',0);__generatorNative('set','active',false) end
        SAO.Perception.beliefs[f.id]=__nativeRoundtrip(SAO.Perception.beliefs[f.id]);__generatorNative('reset-bindings')
        local admitted=SAO.Generator.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
        if not admitted or not f.rec.resourceProductionWork or f.rec.resourceProductionWork.stage~='approaching' then return false end
        SAO.Generator.tick(f.id,f.body)
    end
    local interrupted=row(f);local after=privateFact(f,'J:')
    local expected=kind=='fuel' and 'connect' or 'fuel'
    local observed=interrupted and interrupted.status=='interrupted' and interrupted.detail=='generator-state-reassessed'
        and not interrupted.nativeAttempted and not interrupted.nativeCompleted and not interrupted.nativeCredit
        and interrupted.generatorAfter and interrupted.generatorAfter.revision~=s.generator.revision
        and after.sourceId==s.generator.sourceId and not p.admission and not f.rec.resourceProductionWork
        and f.inventory:contains(f.scrap) and __generatorNative('item',f.petrol:getID(),'amount')==10
        and not f.body:isRecipeActuallyKnown('Generator')
    if not observed then return false end
    local nextPurpose,nextStep=plan(f,expected)
    if not nextPurpose or type(nextStep)~='table' or nextPurpose.id~=purposeId or nextStep.operation~=expected
        or nextStep.consumer.sourceId~=s.consumer.sourceId then return false end
    local admitted=SAO.Generator.begin(f.id,f.body,nextStep,{purposeId=nextPurpose.id,purposeStepId=nextStep.id})
    if not admitted then return false end
    finish(f);local effect=row(f)
    return effect and effect.status=='completed' and effect.operation==expected and effect.purposeId==purposeId
end
local reviewCases={
    unqueued_reading_refusal_retires=function() return readingQueueCase('refused') end,
    queued_reading_refusal_waits_ack=function() return readingQueueCase('queued-refused') end,
    disappeared_reading_waits_native_ack=function() return readingQueueCase('disappeared') end,
    changed_reading_queue_preserves_successor=function() return readingQueueCase('changed') end,
    unqueued_reading_refusal_preserves_other_queue=function() return readingQueueCase('refused-other') end,
    retained_native_generator_survives_cap_and_save_order=retainedCapCase,
    saved_fuel_drift_reobserves_and_replans=function() return driftCase('fuel') end,
    shutdown_verify_reacquires_generator=function() return driftCase('shutdown') end,
    shutdown_during_consumer_return_reacquires=function() return driftCase('during-return') end,
}
function __runGeneratorReviewCases()
    for _,name in ipairs({'unqueued_reading_refusal_retires','queued_reading_refusal_waits_ack',
        'disappeared_reading_waits_native_ack','changed_reading_queue_preserves_successor',
        'unqueued_reading_refusal_preserves_other_queue','retained_native_generator_survives_cap_and_save_order',
        'saved_fuel_drift_reobserves_and_replans','shutdown_verify_reacquires_generator',
        'shutdown_during_consumer_return_reacquires'}) do check(name,reviewCases[name]()) end
    print('PASS generator review 9')
end
function __runGeneratorReviewControl(name) check(name,reviewCases[name]()) end

local function indoorCase(uninspected)
    local f=fixture('selection-indoor-'..tostring(uninspected),nil,40,0,4,uninspected)
    __generatorNative('set','outside',false);f.genSquare.outside=false
    SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks())
    if uninspected then
        local admitted=begin(f,'inspect')
        if not admitted then return false end
        SAO.Generator.tick(f.id,f.body);finish(f)
        local inspected=row(f)
        if not inspected or inspected.status~='completed' or inspected.generatorAfter.outside~=false then return false end
    end
    local current=privateFact(f,'J:')
    return current and current.inspected and current.outside==false
        and #SAO.Generator.options(f.id,f.body,f.intent)==0 and not f.rec.resourceProductionWork
        and f.generator:getCondition()==40 and f.inventory:contains(f.scrap)
end
local function optionalStageCase(operation)
    local f=fixture('selection-required-'..operation,nil,40,operation=='fuel' and 0 or 1,operation=='activate' and 0 or 4)
    f.inventory:Remove(f.scrap)
    if operation=='activate' then f.inventory:Remove(f.manual);__generatorNative('set','connected',true) end
    SAO.Perception.observeGenerators(f.id,f.body,SAO.History.ticks())
    local options=SAO.Generator.options(f.id,f.body,f.intent)
    local required,repair
    for _,o in ipairs(options) do if o.operation==operation then required=o elseif o.operation=='repair' then repair=o end end
    if not required or not repair or required.knowledgeRequired then return false end
    if operation=='fuel' and (required.materialCategory~='petrol' or required.inputItemId~=tostring(f.petrol:getID())) then return false end
    local p,s=plan(f)
    if not p or type(s)~='table' or s.operation~=operation or s.status~='available' then return false end
    local admitted=SAO.Generator.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
    if not admitted then return false end
    finish(f);local result=row(f)
    return result and result.status=='completed' and result.operation==operation and result.nativeCredit==result.id
        and f.generator:getCondition()==40 and not f.inventory:contains(f.scrap)
        and (operation~='activate' or f.generator:isActivated() and not f.body:isRecipeActuallyKnown('Generator'))
end
local function rejectionCase()
    local f=fixture('selection-rejected',nil,100,0,4)
    f.intent.generator=f.generatorFact
    f.intent.rejectedGenerators=__nativeRoundtrip({[f.generatorFact.sourceId]=f.generatorFact.fingerprint})
    local denied=#SAO.Generator.options(f.id,f.body,f.intent)==0 and not f.rec.resourceProductionWork and not row(f)
    -- A different actual observed fingerprint does not reject this J identity.
    f.intent.rejectedGenerators[f.generatorFact.sourceId]=f.consumerFact.fingerprint
    local options=SAO.Generator.options(f.id,f.body,f.intent)
    return denied and #options==1 and options[1].generator.sourceId==f.generatorFact.sourceId
        and options[1].generator.fingerprint==f.generatorFact.fingerprint
end
local selectionCases={
    inspected_indoor_generator_excluded=function() return indoorCase(false) end,
    indoor_unknown_inspects_then_excludes=function() return indoorCase(true) end,
    optional_repair_does_not_block_fuel=function() return optionalStageCase('fuel') end,
    optional_repair_does_not_block_connect=function() return optionalStageCase('connect') end,
    optional_repair_does_not_block_native_activation=function() return optionalStageCase('activate') end,
    exact_rejected_generator_skipped=rejectionCase,
    rejected_generators_filtered_before_cap=function() return retainedCapCase(true) end,
}
function __runGeneratorSelectionCases()
    for _,name in ipairs({'inspected_indoor_generator_excluded','indoor_unknown_inspects_then_excludes',
        'optional_repair_does_not_block_fuel','optional_repair_does_not_block_connect',
        'optional_repair_does_not_block_native_activation','exact_rejected_generator_skipped',
        'rejected_generators_filtered_before_cap'}) do check(name,selectionCases[name]()) end
    print('PASS generator selection 7')
end
function __runGeneratorSelectionControl(name) check(name,selectionCases[name]()) end
