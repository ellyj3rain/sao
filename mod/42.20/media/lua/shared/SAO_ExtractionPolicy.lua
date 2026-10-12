-- Original extraction factory around installed physical actions. ResourceProduction
-- retains the exclusive work claim, execution capsule, outcomes and persistence.
SAO = SAO or {}
SAO.ExtractionPolicy = {}
local P = SAO.ExtractionPolicy
local bags={dirt="Base.Dirtbag",gravel="Base.Gravelbag",sand="Base.Sandbag",clay="Base.Claybag"}
local function plain(value,seen)
    local t=type(value)
    if t=="string" or t=="boolean" then return value end
    if t=="number" then return value==value and value~=math.huge and value~=-math.huge and value or nil end
    if t~="table" or getmetatable(value)~=nil then return nil end
    seen=seen or {};if seen[value] then return nil end;seen[value]=true
    local copy={}
    for k,v in pairs(value) do
        if type(k)~="string" and type(k)~="number" then seen[value]=nil;return nil end
        local x=plain(v,seen);if x==nil then seen[value]=nil;return nil end;copy[k]=x
    end
    seen[value]=nil;return copy
end
local function capture(p)
    local ok,row=pcall(p.observe,p.body,p.object,p.square,p.radius)
    if not ok or type(row)~="table" or not plain(row)
        or row.schema~="sao.person-extraction-observation/1" then return nil,"extraction-observation-unavailable" end
    if row.actorId~=p.purpose.actorId or row.sourceId~=p.purpose.sourceId then
        return nil,"current-extraction-person-source-required"
    end
    if p.baseline and (row.bodyIdentity~=p.baseline.bodyIdentity or row.sourceIdentity~=p.baseline.sourceIdentity
        or row.squareIdentity~=p.baseline.squareIdentity) then return nil,"extraction-native-identity-changed" end
    return row
end
local function current(p)
    local row,why=capture(p);if not row then return nil,why end
    if not row.present or p.object:getSquare()~=p.square then return nil,"extraction-source-no-longer-present" end
    local tool=p.body:getPrimaryHandItem()
    if tool~=p.tool or not tool or tool:isBroken() then return nil,"current-extraction-tool-required" end
    if p.kind=="tree" then
        if not instanceof(p.object,"IsoTree") or not tool:hasTag(ItemTag.CHOP_TREE)
            or not p.body:isEnduranceSufficientForAction() or p.body:isSitting() then
            return nil,"native-tree-means-required"
        end
    else
        if not tool:hasTag(ItemTag.TAKE_DIRT) then return nil,"native-ground-tool-required" end
        local kind,source=ISShovelGroundCursor.GetDirtGravelSand(p.square)
        if kind~=p.kind or source~=p.object then return nil,"native-ground-source-changed" end
        local bag=p.bag
        if not bag or not p.body:getInventory():contains(bag) then return nil,"current-extraction-bag-required" end
        if instanceof(bag,"InventoryContainer") and not bag:getInventory():isEmpty() then
            return nil,"native-empty-bag-required"
        end
        if not bag:hasTag(ItemTag.HOLD_DIRT) and (bag:getFullType()~=bags[p.kind]
            or bag:getCurrentUsesFloat()+bag:getUseDelta()>1) then return nil,"native-bag-capacity-or-kind-required" end
    end
    return row
end
-- Purpose/source/Standing admission belongs to the caller. The exact observation
-- callback is the native observer supplied by the existing bridge/work owner.
function P.describe(kind,body,object,purpose,observe,selection)
    if not body or not object or type(observe)~="function" or type(purpose)~="table" or not plain(purpose)
        or (kind~="tree" and not bags[kind]) then return nil,"extraction-context-required" end
    for _,key in ipairs({"id","actorId","consumerId","sourceId","sourceRevision"}) do
        if type(purpose[key])~="string" or purpose[key]=="" then return nil,"extraction-purpose-"..key.."-required" end
    end
    if not ISChopTreeAction or not ISShovelGroundCursor or not ISShovelGround then
        return nil,"installed-extraction-actions-required"
    end
    local p={kind=kind,body=body,object=object,square=object:getSquare(),purpose=plain(purpose),observe=observe,
        radius=selection and selection.radius or 3,tool=body:getPrimaryHandItem(),bag=selection and selection.bag}
    if not p.square then return nil,"current-extraction-square-required" end
    local ok,row,reason=pcall(current,p)
    if not ok then return nil,"native-extraction-policy-unavailable" end
    if not row then return nil,reason end
    p.baseline=plain(row)
    p.requirements={schema="sao-extraction-policy/1",kind=kind,purpose=plain(purpose),
        sourceId=row.sourceId,sourceRevision=purpose.sourceRevision,source=plain(row),
        nativeAction=kind=="tree" and "ISChopTreeAction" or "ISShovelGround",
        nativeEffectBoundary=kind=="tree" and "ChopTree-animation-event" or "complete",
        toolId=tostring(p.tool:getID()),toolType=p.tool:getFullType(),
        acquisitionRequired=true,standingRequired=true,physicalReachAdmission="owner-required",
        queueAdmission="owner-required",claimAdmission="ResourceProduction-owned",consumerCompletion="owner-required",
        outputAcquisition="owner-required",effect="unmeasured",persistentObjectIdentity=false}
    if p.bag then p.requirements.bagId=tostring(p.bag:getID());p.requirements.bagType=p.bag:getFullType() end
    return p
end
function P.project(p) return p and plain(p.requirements) or nil end
local function indexed(rows)
    local map={};for _,row in ipairs(rows or {}) do map[row.id]=row end;return map
end
local function measured(p,before,after,phase)
    local r={schema="sao-extraction-measurement/1",purposeId=p.purpose.id,actorId=p.purpose.actorId,
        consumerId=p.purpose.consumerId,sourceId=p.purpose.sourceId,sourceRevision=p.purpose.sourceRevision,
        phase=phase,kind=p.kind,observed=after~=nil,stockAcquired=false,consumerCompleted=false,
        damage=0,newDrops={},bagGain=0,sourceRemoved=false,sourceChanged=false}
    if not after then r.status="unobservable";return r end
    r.before=plain(before);r.after=plain(after)
    r.sourceRemoved=before.present==true and after.present==false
    r.sourceChanged=before.sprite~=after.sprite or before.shovelled~=after.shovelled or r.sourceRemoved
    if p.kind=="tree" then
        r.damage=math.max(0,(before.health or 0)-(after.health or 0))
        local old=indexed(before.drops)
        for _,row in ipairs(after.drops) do if not old[row.id] then r.newDrops[#r.newDrops+1]=plain(row) end end
        r.resourceGain=#r.newDrops>0
    else
        local old=indexed(before.held)
        for _,row in ipairs(after.held) do
            if row.type==bags[p.kind] then
                local previous=old[row.id]
                local gain=previous and math.max(0,row.fraction-previous.fraction) or row.fraction
                if gain>0 then r.bagGain=r.bagGain+gain end
            end
        end
        r.resourceGain=r.bagGain>0
    end
    r.effectObserved=r.damage>0 or r.sourceChanged or r.resourceGain
    r.status=r.resourceGain and "native-gain-observed" or (r.effectObserved and "partial" or "no-gain")
    if (before.dropOmitted or 0)>0 or (after.dropOmitted or 0)>0
        or (before.heldOmitted or 0)>0 or (after.heldOmitted or 0)>0 then r.inventoryCoverage="bounded" end
    return r
end
-- current(action, phase) and onResult(plainMeasurement) rejoin the existing work
-- capsule. This factory neither queues actions nor claims/saves world resources.
function P.action(p,owner)
    if not p or type(owner)~="table" or type(owner.current)~="function" or type(owner.onResult)~="function" then
        return nil,"current-extraction-owner-required"
    end
    local row,why=current(p);if not row then return nil,why end
    local action=p.kind=="tree" and ISChopTreeAction:new(p.body,p.object)
        or ISShovelGround:new(p.body,p.bag,p.object,"blends_natural_01_64",bags[p.kind])
    local terminal=false
    local effectSeen,gainSeen,removedByAction=false,false,false
    local function admission(phase)
        if terminal or action.character~=p.body then return nil,"retired-extraction-action" end
        local ok,allowed=pcall(owner.current,action,phase)
        if not ok or allowed~=true then return nil,"extraction-owner-admission-refused" end
        -- These native lifecycle callbacks clean only this admitted action.
        -- A removed tree is the expected result after its owned final hit.
        if phase=="perform" or phase=="stop" or (phase=="complete" and p.kind=="tree" and removedByAction) then
            local observed=capture(p)
            return observed or p.baseline
        end
        return current(p)
    end
    local nativeValid=action.isValid
    action.isValid=function(self)
        local row=admission("isValid")
        return row~=nil and nativeValid(self)==true
    end
    for _,phase in ipairs({"start","serverStart","animEvent","complete","perform","stop"}) do
        local native=action[phase]
        if type(native)=="function" then action[phase]=function(self,...)
            local before,reason=admission(phase)
            if not before then
                if phase=="stop" then terminal=true end
                owner.onResult({schema="sao-extraction-measurement/1",purposeId=p.purpose.id,actorId=p.purpose.actorId,
                    consumerId=p.purpose.consumerId,sourceId=p.purpose.sourceId,sourceRevision=p.purpose.sourceRevision,
                    phase=phase,kind=p.kind,status="refused",reason=reason,observed=false,
                    stockAcquired=false,consumerCompleted=false})
                return false
            end
            local ok,result=pcall(native,self,...)
            local after=capture(p)
            local report=measured(p,before,after,phase)
            report.priorEffectObserved=effectSeen;report.priorGainObserved=gainSeen
            effectSeen=effectSeen or report.effectObserved==true
            gainSeen=gainSeen or report.resourceGain==true
            removedByAction=removedByAction or report.sourceRemoved==true
            report.actionEffectObserved=effectSeen;report.actionGainObserved=gainSeen
            report.nativeReturned=ok and result==true
            report.nativeCallSucceeded=ok
            if not ok then report.nativeError=tostring(result);report.status="native-error" end
            if phase=="complete" or phase=="stop" then
                terminal=true;report.terminal=true
                if phase=="stop" then report.status=effectSeen and "cancelled-after-effect" or "cancelled" end
            end
            owner.onResult(report)
            return ok and result or false
        end end
    end
    return action
end
return P
