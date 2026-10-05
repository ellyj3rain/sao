-- Person-private outbreak interpretation. Physical contacts remain Perception's inputs.
SAO = SAO or {}
SAO.PersonalAwareness = SAO.PersonalAwareness or {}
local A = SAO.PersonalAwareness
local provider, issuer = nil, nil
local LIMIT = 32
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function text(v) return type(v)=="string" and #v>0 and #v<=128 and not v:find("[%c]") end
local function fields(v, keys)
    if type(v)~="table" then return false end
    local allowed={};for _,key in ipairs(keys) do allowed[key]=true;if v[key]==nil then return false end end
    for key in pairs(v) do if not allowed[key] then return false end end
    return true
end
local function array(v, maximum)
    if type(v)~="table" then return false end
    local count=0
    for key in pairs(v) do
        if type(key)~="number" or key%1~=0 or key<1 or key>maximum then return false end
        count=count+1
    end
    return count==#v and count<=maximum
end
local function copy(v)
    if type(v)~="table" then return v end
    local out={};for key,value in pairs(v) do out[key]=copy(value) end;return out
end
local function record(id)
    local ok,rec=pcall(function() return SAO.Identity.get(id) end)
    return ok and type(rec)=="table" and rec.id==id and rec or nil
end
local function clock()
    local ok,now=pcall(function() return SAO.History.countyHours() end)
    return ok and finite(now) and now>=0 and now or nil
end
local function entryValid(row, now)
    return fields(row,{"id","kind","affirmed","sourceId","sourceAtHours","receivedAtHours","certainty"})
        and text(row.id) and (row.kind=="outbreak" or row.kind=="turned")
        and type(row.affirmed)=="boolean" and text(row.sourceId)
        and finite(row.sourceAtHours) and finite(row.receivedAtHours)
        and row.sourceAtHours>=0 and row.sourceAtHours<=row.receivedAtHours and row.receivedAtHours<=now
        and (row.certainty=="reported" or row.certainty=="witnessed")
end
local function initialValid(value,id,now)
    if not fields(value,{"schema","personId","issuerId","sourceId","admissionKey","admittedAtHours","entries"})
        or value.schema~="sao-personal-awareness-initial/1" or value.personId~=id
        or not text(value.issuerId) or not text(value.sourceId) or not text(value.admissionKey)
        or not finite(value.admittedAtHours) or value.admittedAtHours<0 or value.admittedAtHours>now
        or not array(value.entries,8) then return false end
    local ids={}
    for _,row in ipairs(value.entries) do
        if not entryValid(row,value.admittedAtHours) or ids[row.id] then return false end
        ids[row.id]=true
    end
    return true
end
local function stateValid(value,id,now)
    if not fields(value,{"schemaVersion","actorId","initial","observations","omittedObservations"})
        or value.schemaVersion~=1 or value.actorId~=id or not initialValid(value.initial,id,now)
        or not array(value.observations,LIMIT) or not finite(value.omittedObservations)
        or value.omittedObservations<0 or value.omittedObservations%1~=0 then return false end
    local ids={}
    for _,row in ipairs(value.observations) do
        if not entryValid(row,now) or ids[row.id] then return false end;ids[row.id]=true
    end
    return true
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function currentInitial(rec,now)
    if not provider then return true,nil end
    if issuer~=SAO.PopulationAdmissions then return false,nil end
    local ok,value=pcall(provider,rec)
    if not ok then return false,nil end
    if value==nil then return true,nil end
    return initialValid(value,rec.id,now),value
end
local function currentCustody(rec,state,now)
    if not provider then return true end
    local ok,value=currentInitial(rec,now)
    return ok and value~=nil and equal(value,state.initial)
end
-- Admissions owns the private provider and its exact current native admission context.
-- The reader accepts no caller-supplied initial payload or culture/age inference.
function A.bindInitialProvider(owner, reader)
    if provider or not owner or owner~=SAO.PopulationAdmissions or type(reader)~="function" then return false end
    issuer,provider=owner,reader;return true
end
function A.attachInitial(rec)
    local now=clock()
    if type(rec)~="table" or not now or record(rec.id)~=rec then return false,"awareness-person-binding" end
    if rec.personalAwareness~=nil then
        return stateValid(rec.personalAwareness,rec.id,now) and currentCustody(rec,rec.personalAwareness,now),"awareness-retained"
    end
    if not provider then return true,"awareness-unconfigured" end
    local ok,value=currentInitial(rec,now)
    if not ok then return false,"awareness-initial-binding" end
    if value==nil then return true,"awareness-unconfigured" end
    rec.personalAwareness={schemaVersion=1,actorId=rec.id,initial=copy(value),observations={},omittedObservations=0}
    return true,"awareness-attached"
end
function A.query(id)
    local rec,now=record(id),clock()
    if not rec or not now then return nil,"awareness-person-unavailable" end
    if rec.personalAwareness==nil then
        local ok,value=currentInitial(rec,now)
        if not ok or value~=nil then
            return {actorId=id,configured=true,status="unavailable",possible=false,evidence={}}
        end
        return {actorId=id,configured=false,status="legacy-unconfigured",possible=true,evidence={}}
    end
    local state=rec.personalAwareness
    if not stateValid(state,id,now) or not currentCustody(rec,state,now) then
        return {actorId=id,configured=true,status="unavailable",possible=false,evidence={}}
    end
    local evidence={}
    for _,row in ipairs(state.initial.entries) do evidence[#evidence+1]=copy(row) end
    for _,row in ipairs(state.observations) do evidence[#evidence+1]=copy(row) end
    local ok,receipts=pcall(function() return SAO.Perception.radioReceptions(id,true) end)
    if ok and type(receipts)=="table" then
        for index,receipt in ipairs(receipts) do
            if index>64 then break end
            if text(receipt.broadcastId) and text(receipt.sourceId) and finite(receipt.receivedAt)
                and receipt.receivedAt>=0 and receipt.receivedAt<=now and array(receipt.claims,64) then
                local seen={}
                for _,claim in ipairs(receipt.claims) do
                    if (claim.kind=="outbreak" or claim.kind=="turned") and not seen[claim.kind] then
                        seen[claim.kind]=true
                        evidence[#evidence+1]={id=receipt.broadcastId,kind=claim.kind,affirmed=true,
                            sourceId=receipt.sourceId,sourceAtHours=receipt.receivedAt,receivedAtHours=receipt.receivedAt,
                            certainty="reported",basis="personal-radio-reception"}
                    end
                end
            end
        end
    end
    local propositions,positive={},false
    for _,kind in ipairs({"outbreak","turned"}) do
        local yes,no,witnessed=false,false,false
        for _,row in ipairs(evidence) do
            if row.kind==kind then
                if row.affirmed then yes=true;witnessed=witnessed or row.certainty=="witnessed" else no=true end
            end
        end
        propositions[kind]=yes and no and "challenged" or yes and (witnessed and "witnessed-association" or "reported")
            or no and "denied" or "unknown"
        positive=positive or yes and not no
    end
    return {actorId=id,configured=true,status=positive and "possible-association" or "unresolved",
        possible=positive,propositions=propositions,evidence=evidence,
        omittedObservations=state.omittedObservations}
end

-- Perception alone retains this writer. A radio report is never a native witness.
if SAO.Perception and SAO.Perception.bindAwarenessReceiver then
    SAO.Perception.bindAwarenessReceiver(A,function(id,body,subjectId,tick)
        local rec,now=record(id),clock()
        if not rec or not now or not stateValid(rec.personalAwareness,id,now) or not currentCustody(rec,rec.personalAwareness,now) or not text(subjectId)
            or not finite(tick) or rec.dead==true then return false end
        local ok,held=pcall(function()
            local data=body:getModData()
            return SAO.Body.get(id)==body and SAO.Body.active[id]==body and not SAO.Body.foreign[id]
                and data.SAOPersonId==id and data.SAOExternalToken==rec.bodyOwnerToken
                and SAO.History.ticks()==tick
        end)
        if not ok or not held then return false end
        local state=rec.personalAwareness
        local eventId="changed:"..subjectId
        local sourceId="native-perception:"..subjectId
        if not text(eventId) or not text(sourceId) then return false end
        for _,row in ipairs(state.observations) do if row.id==eventId then return true end end
        if #state.observations>=LIMIT then state.omittedObservations=state.omittedObservations+1;return false end
        state.observations[#state.observations+1]={id=eventId,kind="turned",affirmed=true,
            sourceId=sourceId,sourceAtHours=now,receivedAtHours=now,certainty="witnessed"}
        return true
    end)
end
return A
