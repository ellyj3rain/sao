-- Pure person-state export. Model inputs and private source audit are distinct.
SAO = SAO or {}
SAO.PersonState = SAO.PersonState or {}
local P = SAO.PersonState
local AXES={"nerve","discipline","aggression","initiative","selfPreservation","compassion","appetite","talkativeness"}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function unit(v) return finite(v) and v>=0 and v<=1 end
local function copy(v)
    if type(v)~="table" then return v end
    local out={};for key,value in pairs(v) do out[key]=copy(value) end;return out
end
local function ownedBody(rec,body)
    if rec.dead or body==nil or not SAO.Body or type(SAO.Body.get)~="function" then return false end
    local ok,held=pcall(function()
        local data=body:getModData()
        if type(data)~="table" or SAO.Body.get(rec.id)~=body or data.SAOPersonId~=rec.id
            or data.SAOExternalToken~=rec.bodyOwnerToken then return false end
        if rec.bodyOwner==nil then
            return SAO.Body.active[rec.id]==body and SAO.Body.foreign[rec.id]==nil
                and data.SAOExternalOwner==nil and data.ZAOOwned~=true
        elseif rec.bodyOwner=="ZAO" then
            return SAO.Body.foreign[rec.id]==body and SAO.Body.active[rec.id]==nil
                and data.SAOExternalOwner=="ZAO" and data.ZAOOwned==true
                and ZAO and ZAO.Controller and ZAO.Controller.controlled[rec.id]==body
        end
        return false
    end)
    return ok and held==true
end
local function safe(owner,key,...)
    if not owner or type(owner[key])~="function" then return nil end
    local ok,value=pcall(owner[key],...)
    return ok and type(value)=="table" and copy(value) or nil
end
function P.query(id,body,tick)
    local out={schema="sao-person-state/1",actorId=id,atTick=tick,status="unavailable"}
    local rec
    pcall(function() rec=SAO.Identity.get(id) end)
    if type(rec)~="table" or rec.id~=id or not finite(tick) or tick<0 or tick%1~=0 then out.reason="person-unavailable";return out end
    local now,currentTick
    pcall(function() now=SAO.History.countyHours();currentTick=SAO.History.ticks() end)
    if not finite(now) or now<0 or tick~=currentTick then out.reason="clock-unavailable";return out end
    out.atHours=now
    local age=safe(SAO.History,"calendarAgeOf",id)
    if not age or age.actorId~=id or age.status~="available" then out.reason="calendar-age-unavailable";return out end
    out.currentInstant=age.currentInstant
    local bound=ownedBody(rec,body)
    local bodyView={status=bound and "available" or "unavailable",incarnationKnown=false}
    if rec.bodyOwner~=nil then bodyView.owner=rec.bodyOwner end
    local traits=safe(SAO.Disposition,"traits",id)
    local effective={}
    if not traits then out.reason="traits-unavailable";return out end
    for _,axis in ipairs(AXES) do
        if not finite(traits[axis]) or traits[axis]<0 or traits[axis]>1 then out.reason="traits-unavailable";return out end
        effective[axis]=traits[axis]
    end
    local cognitive={status="unavailable",reason="body-unavailable"}
    if bound and SAO.Neuro and type(SAO.Neuro.physicalReadiness)=="function" then
        local ok,attention,motor,receipt=pcall(SAO.Neuro.physicalReadiness,rec)
        local brain=safe(SAO.Neuro,"projectionEvidence",rec)
        if ok and type(receipt)=="table" and receipt.status=="available" and receipt.source=="native-moodles"
            and unit(attention) and unit(motor) and brain and brain.status=="available" then
            local values,clarity,volatility=pcall(function()
                return SAO.Neuro.clarityOf(rec),SAO.Neuro.affectiveVolatility(rec)
            end)
            if values and unit(clarity) and unit(volatility) then
                cognitive={status="available",clarity=clarity,volatility=volatility,
                    attention=attention,motor= motor,source=receipt.source,brainProjection=brain}
            else cognitive.reason="projection-unavailable" end
        else cognitive.reason=brain and brain.status~="available" and brain.reason
            or ok and receipt and receipt.reason or "readiness-unavailable" end
    end
    local recall=safe(SAO.PersonalMemory,"query",id)
        or {actorId=id,status="unavailable",reason="memory-owner-unavailable",episodes={}}
    local situation=bound and safe(SAO.SituationAppraisal,"query",id,body,tick)
        or {actorId=id,status="unavailable",reason="body-unavailable",questions={}}
    local audit={traitEvidence=safe(SAO.Disposition,"traitEvidence",id),
        retainedMemory=safe(SAO.PersonalMemory,"snapshot",id),rawSituation=copy(situation)}
    local affect={}
    if type(situation.psychology)=="table" then
        local psychology=situation.psychology
        affect.fear=finite(psychology.fear) and psychology.fear or nil
        affect.temperStatus="unavailable"
        if psychology.temperStatus=="native" and type(psychology.temper)=="table" then
            local temper,valid={},true
            for _,key in ipairs({"drunk","pain","stress","anger","morale"}) do
                local value=psychology.temper[key]
                if not finite(value) or value<0 or value>1 then valid=false;break end
                temper[key]=value
            end
            if valid then affect.temper=temper;affect.temperStatus="native" end
        end
    end
    situation.psychology=nil
    if cognitive.status~="available" then
        situation.clarity=nil
        situation.cognitionStatus="unavailable"
    end
    out.modelView={actorId=id,atTick=tick,atHours=now,currentInstant=age.currentInstant,
        body=bodyView,age=age,recall=recall,effectiveTraits=effective,
        cognition=cognitive,affect=affect,situation=situation}
    out.audit=audit
    out.status=bound and cognitive.status=="available" and "available" or "unavailable"
    if out.status=="unavailable" then out.reason=cognitive.reason or "body-unavailable" end
    return out
end
return P
