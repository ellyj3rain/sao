require "SAO_HouseholdService"
require "SAO_ElectricalService"
-- Native generator operations for a person's retained use of known machinery.
SAO=SAO or {};SAO.Generator=SAO.Generator or {}
local G=SAO.Generator
local E=SAO.ElectricalService
local runtime,seal={},{}
local sampled
local tokens={inspect="utility:generator-inspected",repair="utility:generator-repaired",fuel="utility:generator-fuelled",
    connect="utility:generator-connected",activate="utility:generator-activated",["verify-power"]="utility:consumer-powered",plumb="utility:generator-plumbed"}
local nativeOwners={inspect="ISGeneratorInfoAction/SAO.Generator",repair="ISFixGenerator",fuel="ISAddFuel",
    connect="ISPlugGenerator",activate="ISActivateGenerator",["verify-power"]="SAO.Generator/NativePower",plumb="SAO.Generator/ConnectSupply"}
for op,token in pairs(E.tokens)do tokens[op]=token;nativeOwners[op]="SAO.Generator/ElectricalService"end
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function text(v) return type(v)=="string" and #v>0 and #v<=256 end
local function clock() local v=SAO.History.countyHours();return finite(v) and v>=0 and v or nil end
local function copy(v,depth)
    if type(v)=="table" then
        if getmetatable(v) or (depth or 0)>4 then return nil end
        local out,n={},0
        for k,x in pairs(v) do
            n=n+1;if n>96 or type(k)~="string" and type(k)~="number" then return nil end
            local y=copy(x,(depth or 0)+1);if y==nil then return nil end;out[k]=y
        end
        return out
    end
    if type(v)=="string" then return #v<=512 and v or nil end
    if type(v)=="boolean" or finite(v) then return v end
end
local function record(id) return SAO.Identity.get(id) end
local function owner(id,body)
    local r=record(id);local a=SAO.Controller and SAO.Controller.agents[id]
    if not r or r.dead or r.bodyOwner or r.zaoTransferPending or r.crossedTransferPending or not body
        or SAO.Body.get(id)~=body or SAO.Body.active[id]~=body or SAO.Body.foreign[id] or not a or a.rec~=r or a.passive
        or a.state=="PASSIVE" or not body:isExistInTheWorld() or body:isDead() or body:isAsleep() or not body:getCurrentSquare()
        or SAOJavaBridge:isShell(body)~=true or body:getVehicle() or body:isAttacking() or body:isAiming() or body:isClimbing() or body:isClimbingRope() then return nil end
    local md=body:getModData()
    return tostring(md.SAOPersonId or "")==tostring(id) and md.SAOExternalToken==r.bodyOwnerToken
        and not md.SAOExternalOwner and md.ZAOOwned~=true and r or nil
end
local function fact(f,prefix)
    return type(f)=="table" and not getmetatable(f) and text(f.sourceId) and f.sourceId:sub(1,2)==prefix
        and text(f.fingerprint) and text(f.revision) and finite(f.x) and f.x%1==0 and finite(f.y) and f.y%1==0
        and finite(f.z) and f.z%1==0
end
local function sameFact(a,b,revision)
    return type(a)=="table" and type(b)=="table" and a.sourceId==b.sourceId and a.fingerprint==b.fingerprint and a.x==b.x and a.y==b.y and a.z==b.z
        and (not revision or a.revision==b.revision)
end
local function private(id,f)
    for _,place in pairs(SAO.Perception.knownPlaces(id,true) or {}) do
        for key,row in pairs(place.sourceFacts or {}) do
            if type(row)=="table" and tostring(key)==f.sourceId and (row.sourceId or row.id)==f.sourceId and row.fingerprint==f.fingerprint
                and row.revision==f.revision and row.x==f.x and row.y==f.y and row.z==f.z then return true end
        end
    end
    return false
end
local function permitted(id,f) return SAO.Standing.mayTakeCurrent(id,f.x,f.y,"standing")==true end
local function knowledge(body) return body:getPerkLevel(Perks.Electricity)>=3 or body:isRecipeActuallyKnown("Generator") end
local function carried(body,id,fullType)
    local out,items=nil,SAOJavaBridge:privateCarriedItems(body)
    if items:size()>512 then return nil end
    for i=0,items:size()-1 do local item=items:get(i)
        if tostring(item:getID())==tostring(id) then if out or item:getFullType()~=fullType then return nil end;out=item end
    end
    return out
end
local function owned(body,item)
    local container=item and item:getContainer()
    return container and container:getOutermostContainer()==body:getInventory() and container:contains(item) or false
end
local function inputEligible(item,operation)
    if not item or item:getIsCraftingConsumed() then return false end
    if operation=="repair" then return item:getType()=="ElectronicsScrap" end
    if operation=="plumb" then return not item:isBroken() and (item:getType()=="PipeWrench" or item:hasTag(ItemTag.PIPE_WRENCH)) end
    local fluid=item:getFluidContainer()
    return operation=="fuel" and fluid and finite(fluid:getAmount()) and fluid:getAmount()>=.099 and fluid:contains(Fluid.Petrol)
end
local function install()
    local ok=pcall(function()
        require "TimedActions/ISFixGenerator";require "TimedActions/ISAddFuel";require "TimedActions/ISPlugGenerator"
        require "TimedActions/ISActivateGenerator";require "TimedActions/ISGeneratorInfoAction"
        require "TimedActions/ISInventoryTransferAction";require "TimedActions/ISEquipWeaponAction"
    end)
    return ok and not isClient() and not isServer() and ISFixGenerator and ISAddFuel and ISPlugGenerator and ISActivateGenerator
end
local function plumbInstall()
    require "TimedActions/ISPlumbItem"
    local h=SAO.HouseholdService
    if not h or not h.available()or not ISBaseTimedAction then return false end
    if not G.plumbingAction then
        local action=ISPlumbItem:derive("SAOConnectGeneratorSupply")
        local function eligible(self)
            return self.generator and self.generator:getObjectIndex()~=-1 and self.generator:isConnected()
                and not self.generator:isActivated()and self.character:isEquipped(self.wrench)
                and h.canPlumbGenerator(self.generator:getX(),self.generator:getY(),self.generator:getZ())
                and not h.isGeneratorPlumbed(self.generator)and not h.isForeignGenerator(self.generator)
        end
        action.isValid=eligible
        function action:waitToStart()self.character:faceThisObject(self.generator);return self.character:shouldBeTurning()end
        function action:complete()return eligible(self)and h.connectGenerator(self.generator,self.character,self.wrench)==true end
        function action:new(character,generator,wrench)
            local value=ISPlumbItem.new(self,character,generator,wrench)
            value.generator=generator
            value.stopOnWalk,value.stopOnRun=true,true;return value
        end
        G.plumbingAction=action
    end
    return true
end
-- The owning source observer binds private source identity/revision and current
-- native tool/generator/service eligibility; it performs no installation.
local function plumbingCurrent(rt,pre)
    local ws=SAO.WorldSources
    if not ws or not ws.generatorPlumbingCurrent or not plumbInstall() then return false end
    local ok,value=pcall(ws.generatorPlumbingCurrent,rt.id,rt.body,rt.object,rt.generatorFact,rt.consumerFact,rt.input,rt.work,pre)
    return ok and value==true
end
local function ledger(r)
    if not r or not finite(r.generatorSequence or 0) or (r.generatorSequence or 0)%1~=0 then return false end
    local rows=r.generatorOutcomes or {};if type(rows)~="table" or getmetatable(rows) or #rows>32 then return false end
    local previous=0
    for _,row in ipairs(rows) do
        if type(row)~="table" or getmetatable(row) or row.actorId~=r.id or not finite(row.sequence) or row.sequence%1~=0 or row.sequence<=previous
            or row.sequence>r.generatorSequence or row.id~="generator/"..r.id.."/"..row.sequence then return false end
        previous=row.sequence
    end
    return true
end
local function identity(id,w)
    return type(w)=="table" and not getmetatable(w) and w.kind=="generator-operation" and w.owner=="SAO.Generator"
        and w.actorId==id and finite(w.sequence) and w.sequence%1==0 and w.sequence>0 and w.id=="generator/"..id.."/"..w.sequence
        and tokens[w.operation]~=nil and tokens[w.operation]==w.token and fact(w.generator,"J:") and fact(w.consumer,"E:")
        and w.sourceId==w.generator.sourceId and w.consumerId==w.consumer.sourceId and text(w.purposeId) and text(w.purposeStepId)
        and finite(w.startedAt) and w.startedAt>=0 and text(w.world) and (w.bodyToken==nil or text(w.bodyToken))
end
local function purpose(r,w)
    local state=r and r.proceduralPlanning;local p=state and state.purposes[w.purposeId]
    local s=p and p.steps[p.cursor];local a=p and p.admission
    local valid=p and p.generatorPower and p.status~="completed" and p.status~="abandoned" and s and a
        and s.id==w.purposeStepId and s.owner=="SAO.Generator" and s.operation==w.operation and s.token==w.token
        and sameFact(s.generator,w.generator,true) and sameFact(s.consumer,w.consumer,true)
        and tostring(s.inputItemId or "")==tostring(w.inputItemId or "") and s.inputItemType==w.inputItemType
        and a.owner==s.owner and a.stepId==s.id and a.target==s.target and a.correlationId==w.id
        and finite(a.at) and a.at>=w.startedAt
    if valid then return p,s end
end
function G.options(id,body,intent)
    local out={}
    if not owner(id,body) or not install() or type(intent)~="table" or not fact(intent.consumer,"E:") or not private(id,intent.consumer)
        or intent.generator and not fact(intent.generator,"J:") then return out end
    SAO.Perception.observeGenerators(id,body,SAO.History.ticks and SAO.History.ticks() or math.floor((clock() or 0)*9000))
    local candidates={}
    local rejected=type(intent.rejectedGenerators)=="table" and not getmetatable(intent.rejectedGenerators) and intent.rejectedGenerators or {}
    for _,place in pairs(SAO.Perception.knownPlaces(id,true) or {}) do for _,row in pairs(place.sourceFacts or {}) do
        local source=type(row)=="table" and (row.sourceId or row.id)
        local retained=not intent.generator or source==intent.generator.sourceId and row.fingerprint==intent.generator.fingerprint
            and row.x==intent.generator.x and row.y==intent.generator.y and row.z==intent.generator.z
        if text(source) and source:sub(1,2)=="J:" and retained and rejected[source]~=row.fingerprint
            and (row.inspected~=true or row.outside==true) then
            local f=copy(row);if f then f.sourceId=source;candidates[#candidates+1]=f end
        end
    end end
    local items=SAOJavaBridge:privateCarriedItems(body)
    for index,known in ipairs(candidates) do
        if index>32 then break end
        if fact(known,"J:") and (known.inspected~=true or finite(known.condition) and finite(known.fuel)
            and type(known.active)=="boolean" and type(known.connected)=="boolean") and (not intent.generator or sameFact(intent.generator,known,false))
            and SAO.Standing.mayAttemptBelieved(id,known.x,known.y,"standing")==true then
            local operation=known.inspected~=true and "inspect"
                or intent.fuelService==true and known.serviceKnowledgeRequired==true and "inspect"
                or intent.fuelService==true and known.plumbed==false and known.fuelServiceEligible==true
                    and (not known.connected and "connect" or "plumb")
                or known.active and "verify-power" or known.condition<=50 and "repair"
                or known.fuel<=0 and "fuel" or not known.connected and "connect" or "activate"
            if intent.managedElectrical==true and known.inspected then
                local sample=sampled(id,known,intent.consumer)
                if not sample then operation="inspect-load"
                elseif sample.loadOwner=="external-writer-unresolved"then operation=known.active and "verify-power"or operation
                elseif sample.breakerOpen and known.connected and known.fuel>0 then operation="breaker-reset"
                elseif known.active then operation=E.operations[intent.electricalOperation]and intent.electricalOperation or "verify-service"end
            end
            if operation=="activate"then
                local native=SAO.WorldSources.generatorObject(body,known,"inspect")
                if native and E.breakerOpen(native)then operation="breaker-reset"end
            end
            local function offer(op)
                local item
                if op=="repair" or op=="fuel" or op=="plumb" then for i=0,math.min(items:size(),512)-1 do
                    if inputEligible(items:get(i),op) then item=items:get(i);break end
                end end
                local option={owner="SAO.Generator",kind="generator-operation",operation=op,token=tokens[op],
                    generator=known,consumer=copy(intent.consumer),inputItemId=item and tostring(item:getID()) or nil,
                    inputItemType=item and item:getFullType() or nil,materialCategory=op=="repair" and "electronics-scrap" or op=="fuel" and "petrol" or op=="plumb" and "pipe-wrench" or nil,
                    knowledgeRequired=(op=="repair" or op=="connect") and not knowledge(body),
                    requestingPurposeId=intent.requestingPurposeId,requestingActivity=intent.requestingActivity,foodItemId=intent.foodItemId}
                if option.knowledgeRequired then
                    option.materialCategory="generator-manual";option.inputItemId,option.inputItemType=nil,nil
                    for i=0,math.min(items:size(),512)-1 do local manual=items:get(i)
                        if instanceof(manual,"Literature") and not manual:getIsCraftingConsumed() and manual:getLearnedRecipes()
                            and manual:getLearnedRecipes():contains("Generator") then
                            option.inputItemId,option.inputItemType=tostring(manual:getID()),manual:getFullType();break
                        end
                    end
                end
                return option
            end
            out[#out+1]=offer(operation)
            if known.inspected and not known.active and known.condition>0 and known.condition<=50 and #out<8 then
                local required=known.fuel<=0 and "fuel" or not known.connected and "connect" or "activate"
                out[#out+1]=offer(required)
            end
            if #out>=8 then return out end
        end
    end
    return out
end
sampled=function(id,generator,consumer)
    local r=record(id)
    for i=#(r and r.generatorOutcomes or{}),1,-1 do
        local row=G.outcome(id,r.generatorOutcomes[i].id)
        if row and row.electricalService and row.status=="completed"and row.purposeDelivered
            and sameFact(row.generator,generator,false)and sameFact(row.consumer,consumer,false)
            and clock()-row.atHours<=.25 then return row.electricalService.after end
    end
end
local function snapshot(object)
    return {condition=object:getCondition(),fuel=object:getFuel(),maxFuel=object:getMaxFuel(),connected=object:isConnected(),
        active=object:isActivated(),outside=object:getSquare():isOutside(),plumbed=SAO.HouseholdService.isGeneratorPlumbed(object)==true}
end
local function sameAnchors(rt,w)
    return identity(rt.id,w) and w.id==rt.workId and w.startedAt==rt.startedAt and w.world==rt.world and w.bodyToken==rt.token
        and sameFact(w.generator,rt.generatorFact,true) and sameFact(w.consumer,rt.consumerFact,true)
        and w.inputItemId==rt.inputId and w.inputItemType==rt.inputType and w.operation==rt.operation
end
local function bound(rt,pre)
    local r=owner(rt.id,rt.body);local p,s=purpose(r,rt.work);local world=getWorld()
    if rt.closed or rt.cancelling or not p or runtime[rt.id]~=rt or r~=rt.record or r.resourceProductionWork~=rt.work
        or not sameAnchors(rt,rt.work) or not ledger(r) or p~=rt.purpose or s~=rt.step or not clock() or clock()<rt.startedAt
        or not world or world:getWorld()~=rt.world or world:getCell()~=rt.cell or rt.body:getCell()~=rt.cell
        or rt.body:getInventory()~=rt.inventory or ISTimedActionQueue.getTimedActionQueue(rt.body)~=rt.queue
        or rt.body:getModData().SAOExternalToken~=rt.token or not permitted(rt.id,rt.generatorFact) or not permitted(rt.id,rt.consumerFact) then return false end
    if (p.generatorPower.requestingActivity=="hydration"or p.generatorPower.managedElectrical==true
        and p.generatorPower.requestingPurposeId~=nil)and(not SAO.ProceduralPlanning
        or not SAO.ProceduralPlanning.generatorRequestCurrent
        or SAO.ProceduralPlanning.generatorRequestCurrent(rt.id,rt.work)~=true) then return false end
    if rt.square and (rt.body:getCurrentSquare()~=rt.square or math.abs(rt.body:getX()-rt.x)>.01 or math.abs(rt.body:getY()-rt.y)>.01) then return false end
    if rt.object and not E.operations[rt.operation]and not SAO.WorldSources.generatorValid(rt.body,rt.object,rt.generatorFact,
        rt.operation=="verify-power" and "verify-power" or rt.operation=="plumb" and "inspect" or pre and rt.operation or "inspect") then return false end
    if pre and (rt.operation=="repair" or rt.operation=="connect") and not knowledge(rt.body) then return false end
    if rt.object and (rt.operation=="activate"or rt.operation=="verify-power"or rt.operation=="breaker-reset"or rt.operation=="verify-service") and not rt.object:getSquare():isOutside() then return false end
    if pre and rt.input and (carried(rt.body,rt.inputId,rt.inputType)~=rt.input or not owned(rt.body,rt.input) or not inputEligible(rt.input,rt.operation)
        or rt.operation=="fuel" and rt.input:getFluidContainer()~=rt.fluid) then return false end
    if rt.operation=="plumb" and rt.object and (not plumbingCurrent(rt,pre) or not rt.input or not inputEligible(rt.input,"plumb")
        or carried(rt.body,rt.inputId,rt.inputType)~=rt.input or not owned(rt.body,rt.input)) then return false end
    if rt.before then
        local w,b=rt.work,rt.before
        if w.beforeCondition~=b.condition or w.beforeFuel~=b.fuel or w.maxFuel~=b.maxFuel or w.beforeConnected~=b.connected
            or w.beforeActive~=b.active or w.beforeInputAmount~=rt.beforeInputAmount
            or rt.operation=="plumb" and w.beforePlumbed~=b.plumbed then return false end
        if pre and rt.operation~="verify-power" then
            local current=snapshot(rt.object)
            if (not E.operations[rt.operation]and(current.condition~=b.condition or current.fuel~=b.fuel))
                or current.connected~=b.connected or current.active~=b.active
                or rt.operation=="fuel" and rt.fluid:getAmount()~=rt.beforeInputAmount
                or rt.operation=="plumb" and (current.plumbed~=b.plumbed or rt.input:getCondition()~=rt.beforeInputCondition or rt.input:getCurrentUses()~=rt.beforeInputUses) then return false end
        end
    end
    if E.operations[rt.operation]and rt.object then
        local pair=SAO.WorldSources.electricalServiceObjects(rt.body,rt.generatorFact,rt.consumerFact,rt.operation,pre)
        if not pair or pair.generator~=rt.object or pair.consumer~=rt.consumerObject then return false end
        if not permitted(rt.id,rt.consumerFact)then return false end
        if pre and rt.electricalBefore then
            local observed=E.measure(rt.body,rt.object,rt.consumerObject,rt.consumerFact,rt.operation,rt.generatorFact)
            if not E.sameMeasurement(rt.electricalBefore,observed)then return false end
        end
    end
    if pre and rt.operation=="activate"and E.breakerOpen(rt.object)then return false end
    return not pre or not rt.nativeAttempted
end
local function capsule(a) return a and type(a._SAOGeneratorBinding)=="function" and a._SAOGeneratorBinding(seal) or nil end
local function current(c)
    local rt=c.rt
    return capsule(c.action)==c and runtime[rt.id]==rt and rt.current==c and ISTimedActionQueue.queues[rt.body]==rt.queue
        and rt.queue.current==c.action and rt.queue.queue[1]==c.action and rt.queue:indexOf(c.action)==1
end
local function retired(rt)
    if rt.route and not rt.route.done then return false end
    for _,c in ipairs(rt.actions) do if rt.queue:indexOf(c.action)~=-1 or rt.queue.current==c.action or c.action.action and not c.ack then return false end end
    return true
end
local function refuse(rt,reason)
    if rt.closed or not rt.record then return false end
    rt.cancelling,rt.reason=true,rt.reason or reason
    if rt.record.resourceProductionWork==rt.work then rt.work.status="cancelling" end
    return false
end
local function refresh(rt)
    if rt.consumerObject then
        SAO.Perception.rememberGeneratorConsumer(rt.id,rt.body,rt.consumerObject,SAO.History.ticks and SAO.History.ticks() or math.floor(clock()*9000))
    end
    SAO.Perception.observeGenerators(rt.id,rt.body,SAO.History.ticks and SAO.History.ticks() or math.floor(clock()*9000))
    local generatorAfter,consumerAfter
    for _,place in pairs(SAO.Perception.knownPlaces(rt.id,true) or {}) do for _,raw in pairs(place.sourceFacts or {}) do
        local f=copy(raw)
        if f then f.sourceId=f.sourceId or f.id
            if sameFact(f,rt.generatorFact,false) then generatorAfter=f end
            if sameFact(f,rt.consumerFact,false) then consumerAfter=f end
        end
    end end
    return generatorAfter,consumerAfter
end
function G.outcome(id,position)
    local r,t=record(id),clock()
    if not ledger(r) then return nil end
    for _,row in ipairs(r.generatorOutcomes or {}) do if row.id==position or row.sequence==position then
        if not identity(id,row) or row.workId~=row.id or (row.nativeOwner~=nativeOwners[row.operation]and not(row.operation=="plumb"and row.nativeOwner=="LGEEPlumbGeneratorAction")) or row.sequence>r.generatorSequence
            or not t or not finite(row.atHours) or row.atHours<row.startedAt or row.atHours>t or row.endedAt~=row.atHours
            or row.status~="completed" and row.status~="failed" and row.status~="interrupted"
            or type(row.nativeAttempted)~="boolean" or type(row.nativeCompleted)~="boolean" then return nil end
        if row.status=="completed" then
            if row.nativeCredit~=row.id or not row.nativeCompleted or not sameFact(row.generatorAfter,row.generator,false) then return nil end
            local op=row.operation
            for _,key in ipairs({"beforeCondition","afterCondition","beforeFuel","afterFuel","maxFuel"}) do
                if not finite(row[key]) or row[key]<0 then return nil end
            end
            if row.afterCondition>100 or row.beforeCondition>100 or row.afterFuel>row.maxFuel or row.beforeFuel>row.maxFuel
                or type(row.beforeActive)~="boolean" or type(row.afterActive)~="boolean"
                or type(row.beforeConnected)~="boolean" or type(row.afterConnected)~="boolean" or type(row.outside)~="boolean" then return nil end
            if (op=="repair" or op=="fuel" or op=="plumb") and (not text(row.inputItemId) or not text(row.inputItemType)
                or not finite(row.beforeInputAmount) or not finite(row.afterInputAmount) or row.beforeInputAmount<0 or row.afterInputAmount<0) then return nil end
            if E.operations[op]and not E.receipt(row)then return nil end
            if op=="inspect" and row.generatorAfter.inspected~=true
                or op=="repair" and (not row.nativeAttempted or not row.inputConsumed or not finite(row.afterCondition) or row.afterCondition<=row.beforeCondition or row.afterCondition>100)
                or op=="fuel" and (not row.nativeAttempted or not row.inputRetained or row.afterFuel<=row.beforeFuel
                    or math.abs(row.afterFuel-row.beforeFuel-(row.beforeInputAmount-row.afterInputAmount))>.0001)
                or op=="plumb" and (not row.nativeAttempted or row.beforePlumbed~=false or row.afterPlumbed~=true or not row.inputRetained
                    or not row.afterConnected or not finite(row.beforeInputCondition)or not finite(row.afterInputCondition)
                    or not finite(row.beforeInputUses)or not finite(row.afterInputUses)
                    or row.afterInputCondition~=row.beforeInputCondition or row.afterInputUses~=row.beforeInputUses)
                or op=="connect" and (not row.nativeAttempted or row.beforeConnected or not row.afterConnected)
                or op=="activate" and (not row.nativeAttempted or row.beforeActive or not row.afterActive or not row.outside)
                or op=="verify-power" and (not row.sourceCovered or not row.consumerPowered or not row.afterActive or not row.outside) then return nil end
        elseif row.nativeCredit~=nil then return nil end
        return copy(row)
    end end
end
local function flush(id)
    local r=record(id)
    if not ledger(r) then return end
    for _,row in ipairs(r and r.generatorOutcomes or {}) do
        local canonical=G.outcome(id,row.sequence)
        if canonical then
            if not row.purposeDelivered and SAO.ProceduralPlanning.consumeGeneratorOutcome(id,row.sequence)==true then row.purposeDelivered=true end
            if not row.experienceDelivered and G.onOutcome then
                local ok,accepted=pcall(G.onOutcome,id,G.outcome(id,row.sequence))
                if ok and accepted==true then row.experienceDelivered=true end
            end
        end
    end
end
local function dispose(rt)
    for _,c in ipairs(rt.actions) do c.action._SAOGeneratorBinding=function() return nil end;c.action._SAOGeneratorRetireSaved=nil end
    if runtime[rt.id]==rt then runtime[rt.id]=nil end
    rt.body,rt.record,rt.object,rt.input,rt.fluid,rt.current,rt.route=nil,nil,nil,nil,nil,nil,nil
end
local function finish(rt,status,reason)
    if rt.closed then return true end
    local r,w,t=record(rt.id),rt.work,clock()
    if not retired(rt) or r~=rt.record or r.resourceProductionWork~=w or not purpose(r,w) or not ledger(r)
        or not sameAnchors(rt,w) or not t or t<rt.startedAt then return false end
    local rows=r.generatorOutcomes or {}
    if #rows>=32 and not rows[1].purposeDelivered then return false end
    local row=copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.status,row.detail,row.nativeOwner,row.atHours,row.endedAt=w.id,status,reason,nativeOwners[rt.operation],t,t
    row.nativeAttempted,row.nativeCompleted=rt.nativeAttempted==true,rt.nativeCompleted==true
    if rt.object then local after=snapshot(rt.object)
        row.afterCondition,row.afterFuel,row.afterConnected,row.afterActive,row.outside=after.condition,after.fuel,after.connected,after.active,after.outside
        row.afterPlumbed=after.plumbed;row.generatorAfter,row.consumerAfter=refresh(rt)
    end
    row.inputConsumed=rt.operation=="repair" and rt.nativeCompleted==true and carried(rt.body,rt.inputId,rt.inputType)==nil
    row.inputRetained=rt.input and carried(rt.body,rt.inputId,rt.inputType)==rt.input and owned(rt.body,rt.input) or false
    row.afterInputAmount=rt.operation=="fuel" and rt.fluid:getAmount() or (rt.operation=="repair" or rt.operation=="plumb") and (row.inputRetained and 1 or 0) or nil
    if rt.operation=="plumb" then row.afterInputCondition=rt.input and rt.input:getCondition();row.afterInputUses=rt.input and rt.input:getCurrentUses() end
    row.sourceCovered,row.consumerPowered=rt.sourceCovered==true,rt.consumerPowered==true
    if E.operations[rt.operation]then
        row.electricalService={schema="sao-electrical-service/1",sourceId=row.sourceId,consumerId=row.consumerId,consumerCompleted=false,
            before=copy(rt.electricalBefore),after=E.measure(rt.body,rt.object,rt.consumerObject,rt.consumerFact,rt.operation,rt.generatorFact)}
    end
    local op=rt.operation
    local effect=rt.nativeCompleted and (E.operations[op]and E.receipt(row)or op=="inspect" and row.generatorAfter and row.generatorAfter.inspected
        or op=="repair" and row.inputConsumed and row.afterCondition>row.beforeCondition
        or op=="fuel" and row.inputRetained and row.afterFuel>row.beforeFuel and math.abs(row.afterFuel-row.beforeFuel-(row.beforeInputAmount-row.afterInputAmount))<=.0001
        or op=="plumb" and row.beforePlumbed==false and row.afterPlumbed==true and row.afterConnected and row.inputRetained
            and row.beforeInputCondition==row.afterInputCondition and row.beforeInputUses==row.afterInputUses
        or op=="connect" and not row.beforeConnected and row.afterConnected
        or op=="activate" and not row.beforeActive and row.afterActive
        or op=="verify-power" and row.sourceCovered and row.consumerPowered and row.afterActive and row.outside)
    if status=="completed" and (not effect or not bound(rt,false)) then row.status,row.detail="failed","native-generator-no-effect" end
    row.nativeCredit=row.status=="completed" and row.id or nil
    rows[#rows+1]=row;r.generatorOutcomes=rows
    if #rows>32 then table.remove(rows,1) end
    if not G.outcome(rt.id,row.id) then table.remove(rows);return false end
    r.resourceProductionWork=nil;rt.closed=true;dispose(rt);flush(rt.id);return true
end
local enqueue
local function guard(rt,a,kind,item)
    local c={rt=rt,action=a,kind=kind,item=item,source=item and item:getContainer()}
    a._SAOGeneratorBinding=function(key) if key==seal then return c end end
    a.actorId,a.workId,a.bodyToken=rt.id,rt.workId,rt.token
    local valid,start,perform,complete,create=a.isValid,a.start,a.perform,a.complete,a.create
    local function nativeExact()
        local ok,owned=pcall(function()return c.native~=nil and a.action==c.native and c.native:getTable()==a end)
        return ok and owned==true
    end
    local function exact()
        return capsule(a)==c and a.character==rt.body and a.actorId==rt.id and a.workId==rt.workId and a.bodyToken==rt.token
            and (kind=="transfer" and a.item==item and a.srcContainer==c.source and a.destContainer==rt.inventory
                or kind=="equip" and a.item==item and a.primary
                or kind=="native"and(E.operations[rt.operation]and E.actionCurrent(a,rt.body,rt.object,rt.consumerObject,rt.operation)
                    or not E.operations[rt.operation]and(rt.operation=="inspect"and a.object==rt.object
                    or a.generator==rt.object and(rt.operation~="fuel"or a.petrol==rt.input and a.fluidCont==rt.fluid)
                    and(rt.operation~="plumb"or a.wrench==rt.input))))
    end
    function a:create()
        if self~=a then return false end
        if c.native or c.ack or rt.closed or not current(c)or not exact()then return false end
        local ok,result=pcall(create,self)
        if not ok then refuse(rt,"native-generator-create-failed");error(result)end
        c.native=self.action
        if not nativeExact()then return refuse(rt,"generator-native-created-instance-changed")end
        return result
    end
    function a:isValidStart()
        if self~=a then return false end
        return not c.done and exact() and bound(rt,true) and valid(self)==true and exact() or false
    end
    function a:isValid() if self~=a then return false end;return self:isValidStart() end
    function a:start()
        if self~=a then return false end
        if not current(c) or not self:isValid() then return refuse(rt,"generator-start-owner-changed") end
        if not nativeExact()then return refuse(rt,"generator-native-start-instance-changed")end
        local ok,result=pcall(start,self)
        if not ok or result==false then refuse(rt,"native-generator-start-failed");if not ok then error(result)end;return false end
        c.started=true;return result
    end
    function a:perform()
        if self~=a then return false end
        local ended=c.native and c.native:isStarted() and (c.native:finished() or c.native:isForceComplete())
        if c.performed or c.done or c.ack or rt.closed then return false end
        if not c.started or not nativeExact()or not current(c) or not ended or not self:isValid() then return refuse(rt,"generator-perform-owner-changed") end
        if kind=="transfer" and (not self.queueList or #self.queueList~=1 or #self.queueList[1].items~=1 or self.queueList[1].items[1]~=item) then return refuse(rt,"generator-transfer-input-changed") end
        c.performed=true
        if rt.operation=="inspect" and kind=="native" then
            ISBaseTimedAction.perform(self);c.done,c.ack=true,true;rt.nativeCompleted=true
            return finish(rt,"completed","native-generator-inspected")
        end
        local ok,result=pcall(perform,self)
        if not ok then return refuse(rt,"native-generator-perform-failed") end
        if kind=="transfer" then
            c.done,c.ack=true,true
            if item:getContainer()~=rt.inventory or c.source:contains(item) or rt.queue:indexOf(self)~=-1 or rt.queue.current==self or not bound(rt,true) then return refuse(rt,"generator-transfer-unconfirmed") end
            return enqueue(rt,c.position+1)
        end
        return result
    end
    function a:complete()
        if self~=a then return false end
        if c.done or rt.closed then return false end
        if kind=="transfer" or rt.operation=="inspect" and kind=="native" then return false end
        if c.done or not c.started or not c.performed or not nativeExact()or not exact() or not bound(rt,true) or valid(self)~=true or not exact()
            or rt.queue:indexOf(self)~=-1 or rt.queue.current or #rt.queue.queue>0 then return refuse(rt,"generator-complete-owner-changed") end
        if kind=="native" and rt.operation=="repair" and rt.inventory:getFirstTypeRecurse("ElectronicsScrap")~=rt.input then return refuse(rt,"generator-native-payment-changed") end
        c.done,c.ack=true,true
        if kind=="native"and E.operations[rt.operation]then
            rt.electricalBefore=E.measure(rt.body,rt.object,rt.consumerObject,rt.consumerFact,rt.operation,rt.generatorFact)
            if not rt.electricalBefore then return refuse(rt,"electrical-pre-mutation-unavailable")end
        end
        if kind=="native" then rt.nativeAttempted=true end
        local ok,result=pcall(complete,self)
        if kind=="equip" then
            if not ok or result~=true or rt.body:getPrimaryHandItem()~=item then return refuse(rt,"generator-equip-unconfirmed") end
            return enqueue(rt,c.position+1)
        end
        rt.nativeCompleted=ok and result==true
        if rt.nativeCompleted and E.operations[rt.operation]then
            rt.nativeCompleted=E.commit(rt.object,rt.operation)==true
        end
        return finish(rt,rt.nativeCompleted and "completed" or "failed","native-generator-stage-ended")
    end
    function a:stop()
        if self~=a then return false end
        if c.ack or rt.closed or capsule(self)~=c or c.native and not nativeExact()then return false end
        local active=current(c);refuse(rt,"native-generator-stopped")
        if active and current(c) then
            if kind=="transfer" then
                pcall(function() self:playSourceContainerCloseSound();self:playDestContainerCloseSound();self:stopLoopingSound() end)
                item:setJobDelta(0);if self.action then self.action:setLoopedAction(false) end
                pcall(function() removeItemTransaction(self.transactionId,true) end);self.started=false
            elseif kind=="equip" then
                if self.sound then rt.body:getEmitter():stopSound(self.sound);self.sound=nil end
                item:setJobDelta(0);self:restoreWeaponType()
            else
                if self.sound then rt.body:stopOrTriggerSound(self.sound) end
                if rt.operation=="fuel" then rt.input:setJobDelta(0) end
            end
            c.ack=true;rt.body:setIsFarming(false);rt.queue:onCompleted(self)
        else c.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end end
        finish(rt,"interrupted",rt.reason);return true
    end
    function a:forceCancel()
        if self~=a then return false end
        if c.ack or rt.closed or capsule(self)~=c or c.native and not nativeExact()then return false end
        refuse(rt,"native-generator-force-cancel")
        if not self.action then c.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end
        elseif c.native and nativeExact()and not c.started then
            local ok,absent=pcall(function()return not c.native:isStarted()and not rt.body:getCharacterActions():contains(c.native)end)
            if ok and absent then
                c.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end
                finish(rt,"interrupted",rt.reason);return true
            end
        end
        return false
    end
    a.canMergeAction=function() return false end
    a._SAOGeneratorRetireSaved=function(r,w)
        if capsule(a)~=c or record(rt.id)~=r or not sameAnchors(rt,w) or not purpose(r,w) then return false end
        -- A module reload replaces public G methods while this native action
        -- still owns its old private capsule. Retire that captured owner.
        refuse(rt,"generator-runtime-unavailable")
        if rt.route and not rt.route.done then
            local ok,ack=pcall(function() return SAOJavaBridge:cancelMove(rt.body) end)
            if not ok or ack~="MOVE_CANCELLED" then return false end;rt.route.done=true
        end
        for _,child in ipairs(rt.actions) do if not child.ack then
            if child.action.action then
                if child.native and child.action.action==child.native and child.native:getTable()==child.action then
                    pcall(function()child.native:forceStop()end)
                end
            else child.action:forceCancel() end
        end end
        if not retired(rt) then return false end
        if r.resourceProductionWork~=rt.work then dispose(rt);return true end
        return rt.closed==true or finish(rt,"interrupted",rt.reason)
    end
    c.position=#rt.actions+1;rt.actions[c.position]=c
    return a
end
enqueue=function(rt,index)
    local c=rt.actions[index]
    if not c or not bound(rt,true) or rt.queue.current or #rt.queue.queue>0 then return refuse(rt,"generator-queue-owner-changed") end
    if c.kind=="native" and rt.operation=="repair" then
        local values=rt.inventory:getItems();local position=values:indexOf(rt.input)
        if position<0 then return refuse(rt,"generator-scrap-not-root-held") end
        if position>0 then local first=values:get(0);values:set(0,rt.input);values:set(position,first) end
    end
    rt.current,rt.action=c,c.action;rt.work.stage=c.kind=="native" and "operating" or "preparing"
    return SAO.Needs.queueVerified(c.action)==true or rt.closed==true or refuse(rt,"native-generator-queue-refused")
end
local function queue(rt)
    local verification=rt.operation=="verify-power" and rt.approachKind~="generator"
    local pair=E.operations[rt.operation]and SAO.WorldSources.electricalServiceObjects(rt.body,rt.generatorFact,rt.consumerFact,rt.operation,true)
    local object=E.operations[rt.operation]and pair and pair.generator
        or not E.operations[rt.operation]and SAO.WorldSources.generatorObject(rt.body,rt.generatorFact,verification and "verify-power" or "inspect")
    if not object and verification and #rt.actions==0 then
        local target=SAO.WorldSources.generatorTarget(rt.body,rt.generatorFact,"inspect")
        local x,y,z=tostring(target):match("^READY:(%-?%d+):(%-?%d+):(%-?%d+)$")
        if x and SAO.Standing.mayAttemptBelieved(rt.id,tonumber(x),tonumber(y),"standing")==true
            and SAO.Locomotion.order(rt.id,rt.body,tonumber(x),tonumber(y),tonumber(z)) then
            rt.route=SAO.Locomotion.jobs[rt.id];rt.approachKind="generator";rt.work.stage="approaching"
            return rt.route and rt.route.body==rt.body
        end
    end
    if not object then return false end
    rt.object,rt.square,rt.x,rt.y=object,rt.body:getCurrentSquare(),rt.body:getX(),rt.body:getY()
    local before=snapshot(object);local w=rt.work
    rt.before=copy(before)
    w.beforeCondition,w.beforeFuel,w.maxFuel,w.beforeConnected,w.beforeActive,w.outside=before.condition,before.fuel,before.maxFuel,before.connected,before.active,before.outside
    if rt.input then w.beforeInputAmount=rt.operation=="fuel" and rt.fluid:getAmount() or 1;rt.beforeInputAmount=w.beforeInputAmount end
    if rt.operation=="plumb" then
        if not plumbInstall() or before.plumbed or not before.connected then return false end
        w.beforePlumbed=before.plumbed;rt.beforeInputCondition=rt.input:getCondition();rt.beforeInputUses=rt.input:getCurrentUses()
        w.beforeInputCondition,w.beforeInputUses=rt.beforeInputCondition,rt.beforeInputUses
    end
    if not verification and not E.atConsumer(rt.operation)then
        local observed=refresh(rt)
        if not observed or rt.operation~="inspect" and (not sameFact(observed,rt.generatorFact,true)
            or rt.operation=="verify-power" or SAO.WorldSources.generatorObject(rt.body,rt.generatorFact,rt.operation=="plumb" and "inspect" or rt.operation)~=object) then
            return finish(rt,"interrupted","generator-state-reassessed")
        end
    end
    if E.operations[rt.operation]then
        rt.consumerObject=pair and pair.consumer
        if not rt.consumerObject then return false end
        rt.electricalBefore=E.measure(rt.body,object,rt.consumerObject,rt.consumerFact,rt.operation,rt.generatorFact)
        if not rt.electricalBefore or rt.operation~="inspect-load"and rt.electricalBefore.loadOwner~="native-IsoGenerator"then return false end
    end
    if not bound(rt,true) then return false end
    if rt.operation=="verify-power" then
        rt.consumerObject=SAO.WorldSources.generatorConsumerObject(rt.body,rt.consumerFact)
        if not rt.consumerObject then return false end
        SAO.Perception.rememberGeneratorConsumer(rt.id,rt.body,rt.consumerObject,SAO.History.ticks and SAO.History.ticks() or math.floor(clock()*9000))
        rt.sourceCovered=IsoGenerator.isPoweringSquare(rt.generatorFact.x,rt.generatorFact.y,rt.generatorFact.z,rt.consumerFact.x,rt.consumerFact.y,rt.consumerFact.z)
        rt.consumerPowered=SAO.WorldSources.generatorConsumerPowered(rt.body,object,rt.consumerFact)==true
        rt.nativeCompleted=rt.sourceCovered and rt.consumerPowered
        return finish(rt,rt.nativeCompleted and "completed" or "failed","native-consumer-power-checked")
    end
    if rt.input and rt.input:getContainer()~=rt.inventory then guard(rt,ISInventoryTransferAction:new(rt.body,rt.input,rt.input:getContainer(),rt.inventory),"transfer",rt.input) end
    if (rt.operation=="fuel" or rt.operation=="plumb") and rt.body:getPrimaryHandItem()~=rt.input then guard(rt,ISEquipWeaponAction:new(rt.body,rt.input,50,true,false),"equip",rt.input) end
    local a
    if E.operations[rt.operation]then a=E.action(rt.body,object,rt.consumerObject,rt.operation)
    else a=rt.operation=="inspect" and ISGeneratorInfoAction:new(rt.body,object)
        or rt.operation=="repair" and ISFixGenerator:new(rt.body,object)
        or rt.operation=="fuel" and ISAddFuel:new(rt.body,object,rt.input)
        or rt.operation=="plumb" and G.plumbingAction:new(rt.body,object,rt.input)
        or rt.operation=="connect" and ISPlugGenerator:new(rt.body,object,true)
        or ISActivateGenerator:new(rt.body,object,true)end
    if not a then return false end
    if rt.operation=="repair" then a.continueFixing=function() end end
    guard(rt,a,"native",rt.input)
    return enqueue(rt,1)
end
function G.begin(id,body,step,context)
    context=context or {};local r,t=owner(id,body),clock()
    if type(step)~="table" or not r or not t or not install() or not ledger(r) or not tokens[step.operation] or step.owner~="SAO.Generator"
        or step.token~=tokens[step.operation] or not fact(step.generator,"J:") or not fact(step.consumer,"E:")
        or not private(id,step.generator) or not private(id,step.consumer) or r.resourceProductionWork or r.worldSourceReservation or r.cookingWork
        or r.studyWork and r.studyWork.status=="reading" or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) then return false end
    local input=step.inputItemId and carried(body,step.inputItemId,step.inputItemType)
    if (step.operation=="repair" or step.operation=="fuel" or step.operation=="plumb") and not inputEligible(input,step.operation) then return false end
    if step.operation=="plumb" and not plumbInstall() then return false end
    local verification=step.operation=="verify-power" and SAO.WorldSources.generatorObject(body,step.generator,"verify-power")~=nil
    local consumerEndpoint=E.atConsumer(step.operation)or verification
    local target=consumerEndpoint and SAO.WorldSources.generatorConsumerTarget(body,step.consumer)
        or SAO.WorldSources.generatorTarget(body,step.generator,"inspect")
    local x,y,z=tostring(target):match("^READY:(%-?%d+):(%-?%d+):(%-?%d+)$");if not x then return false end
    local route=SAO.Locomotion.jobs[id];if route and not route.done then return false end
    local seq=(r.generatorSequence or 0)+1;local world=getWorld()
    if not world or world:getCell()~=body:getCell() then return false end
    local needs=SAO.Needs.read(body) or {};local ok,health=pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    local w={id="generator/"..id.."/"..seq,sequence=seq,actorId=id,kind="generator-operation",owner="SAO.Generator",operation=step.operation,token=step.token,
        generator=copy(step.generator),consumer=copy(step.consumer),sourceId=step.generator.sourceId,consumerId=step.consumer.sourceId,
        inputItemId=input and tostring(input:getID()) or nil,inputItemType=input and input:getFullType() or nil,materialCategory=step.materialCategory,
        purposeId=context.purposeId,purposeStepId=context.purposeStepId,requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,
        startedAt=t,world=world:getWorld(),bodyToken=r.bodyOwnerToken,status="operating",stage="approaching",
        admittedNeeds={hunger=needs.hunger,thirst=needs.thirst,fatigue=needs.fatigue},admittedHealth=ok and health or nil}
    if not identity(id,w) then return false end
    local rt={id=id,body=body,record=r,work=w,workId=w.id,startedAt=t,world=w.world,token=w.bodyToken,cell=body:getCell(),inventory=body:getInventory(),
        queue=ISTimedActionQueue.getTimedActionQueue(body),operation=w.operation,generatorFact=copy(w.generator),consumerFact=copy(w.consumer),
        input=input,inputId=w.inputItemId,inputType=w.inputItemType,fluid=input and input:getFluidContainer(),actions={},
        approachKind=consumerEndpoint and "consumer" or "generator"}
    r.generatorSequence,r.resourceProductionWork,runtime[id]=seq,w,rt
    if SAO.ProceduralPlanning.admitGenerator(id,w)~=true then r.resourceProductionWork=nil;dispose(rt);return false end
    rt.purpose,rt.step=purpose(r,w)
    if E.operations[rt.operation]and SAO.WorldSources.electricalServiceObjects(body,w.generator,w.consumer,rt.operation,true)
        or not E.operations[rt.operation]and SAO.WorldSources.generatorObject(body,w.generator,verification and w.operation or "inspect")
        and(not verification or SAO.WorldSources.generatorConsumerObject(body,w.consumer))then
        if queue(rt) then return true end
    elseif SAO.Standing.mayAttemptBelieved(id,tonumber(x),tonumber(y),"standing")==true and SAO.Locomotion.order(id,body,tonumber(x),tonumber(y),tonumber(z)) then
        rt.route=SAO.Locomotion.jobs[id];if rt.route and rt.route.body==body then return true end
    end
    G.interrupt(id,body,"generator-admission-refused");return false
end
function G.interrupt(id,body,reason)
    local rt=runtime[id]
    if not rt then return G.reconcileSaved(id,body) end
    if body and rt.body~=body then return false end
    if rt.nativeCompleted and retired(rt) and not rt.cancelling then return finish(rt,"completed","generator-completed-before-interruption") end
    refuse(rt,reason or "higher-priority-work")
    if rt.route and not rt.route.done then
        local ok,ack=pcall(function() return SAOJavaBridge:cancelMove(rt.body) end)
        if not ok or ack~="MOVE_CANCELLED" then return false end;rt.route.done=true
    end
    for _,c in ipairs(rt.actions) do if not c.ack then
        if c.action.action then
            if c.native and c.action.action==c.native and c.native:getTable()==c.action then pcall(function()c.native:forceStop()end)end
        else c.action:forceCancel() end
    end end
    return rt.closed==true or finish(rt,"interrupted",rt.reason)
end
function G.detach(id,body,reason) return G.interrupt(id,body,reason or "body-retired") end
function G.reconcileSaved(id,body)
    flush(id);local r=record(id);local w=r and r.resourceProductionWork
    if not w or w.kind~="generator-operation" then return true end
    if runtime[id] then return G.interrupt(id,body,"generator-owner-reconciled") end
    local t=clock();local world=getWorld()
    if not ledger(r) or not identity(id,w) or not purpose(r,w) or w.sequence>r.generatorSequence or not t or t<w.startedAt
        or not body or tostring(body:getModData().SAOPersonId or "")~=tostring(id) or body:getModData().SAOExternalToken~=w.bodyToken
        or not world or world:getWorld()~=w.world then return false end
    for _,q in pairs(ISTimedActionQueue.queues) do
        local pending={};for _,a in ipairs(q.queue) do pending[#pending+1]=a end
        if q.current and q:indexOf(q.current)==-1 then pending[#pending+1]=q.current end
        for _,a in ipairs(pending) do if a.actorId==id and a.workId==w.id and a.bodyToken==w.bodyToken then
            if type(a._SAOGeneratorRetireSaved)~="function" then return false end
            local ok,ack=pcall(a._SAOGeneratorRetireSaved,r,w);if not ok or not ack then return false end
        end end
    end
    if not r.resourceProductionWork then return true end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if SAOJavaBridge:hasPendingActions(body) or q.current or #q.queue>0 then return false end
    local rows=r.generatorOutcomes or {};if #rows>=32 and not rows[1].purposeDelivered then return false end
    local row=copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.status,row.detail,row.nativeOwner,row.atHours,row.endedAt=w.id,"interrupted","generator-runtime-unavailable",nativeOwners[w.operation],t,t
    row.nativeAttempted,row.nativeCompleted,row.inputConsumed,row.inputRetained,row.sourceCovered,row.consumerPowered=false,false,false,false,false,false
    row.nativeObservability="runtime-unavailable"
    rows[#rows+1]=row;r.generatorOutcomes=rows;if #rows>32 then table.remove(rows,1) end
    if not G.outcome(id,row.id) then table.remove(rows);return false end
    r.resourceProductionWork=nil;flush(id);return true
end
function G.tick(id,body)
    flush(id);local rt=runtime[id]
    if not rt then return G.reconcileSaved(id,body) and "idle" or "cancelling" end
    if rt.cancelling or rt.body~=body or not bound(rt,not rt.nativeAttempted) or not clock() or clock()-rt.startedAt>.5 then
        return G.interrupt(id,rt.body,rt.reason or "generator-owner-changed") and "interrupted" or "cancelling"
    end
    if rt.work.stage=="approaching" then
        if not rt.route or SAO.Locomotion.jobs[id]~=rt.route then return G.interrupt(id,body,"generator-route-owner-lost") and "interrupted" or "cancelling" end
        SAO.Locomotion.tick(id);if not rt.route.done then return "moving" end
        if rt.route.result=="arrived" and queue(rt) then return "operating" end
        return G.interrupt(id,body,"native-generator-approach-refused") and "interrupted" or "cancelling"
    end
    if rt.action and ISTimedActionQueue.hasAction(rt.action) then return rt.work.stage end
    return G.interrupt(id,body,"generator-native-acknowledgement-missing") and "interrupted" or "cancelling"
end
function G.reset() for id,rt in pairs(runtime) do G.interrupt(id,rt.body,"world-reset") end end
function G.retryCancellations()
    local n=0;for id,rt in pairs(runtime) do if rt.cancelling then G.interrupt(id,rt.body,rt.reason);n=n+1;if n>=32 then return end end end
end
if Events and Events.OnTick then Events.OnTick.Add(G.retryCancellations) end
return G
