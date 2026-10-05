-- Person-owned dated episodes and a separate, pure recall projection.
-- Admissions owns source custody. Neuro owns present cognitive clarity.
SAO = SAO or {}
SAO.PersonalMemory = SAO.PersonalMemory or {}
local M = SAO.PersonalMemory
local provider, issuer
local MAX_EPISODES, MAX_PARTICIPANTS, MAX_RELATIONS = 64, 16, 16
local RELATIONS = { ["typically-contains"]=true, ["may-contain"]=true, contains=true,
    affords=true, supports=true, ["is-a"]=true, enables=true, ["may-cause"]=true }
-- Explicit uncalibrated recall coefficients. They confer no assessed mastery.
local MIN_HORIZON_DAYS, SALIENCE_HORIZON_DAYS, RECALL_THRESHOLD = 365, 7300, 0.15
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function text(v,maximum)
    if type(v)~="string" or #v==0 or #v>maximum then return false end
    -- Literal control matching preserves Java UTF-16 text units.
    for control=0,31 do if v:find(string.char(control),1,true) then return false end end
    return v:find(string.char(127),1,true)==nil
end
local function word(v)
    if not text(v,96) then return false end
    for index=1,#v do
        local code=string.byte(v,index)
        if not (code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122
            or code==95 or code==58 or code==45 or code==46) then return false end
    end
    return true
end
local function hash(v)
    if type(v)~="string" or #v~=64 then return false end
    for index=1,64 do
        local code=string.byte(v,index)
        if not (code>=48 and code<=57 or code>=97 and code<=102) then return false end
    end
    return true
end
local function fields(v,required,optional)
    if type(v)~="table" then return false end
    local allowed={}
    for _,key in ipairs(required) do allowed[key]=true;if v[key]==nil then return false end end
    for _,key in ipairs(optional or {}) do allowed[key]=true end
    for key in pairs(v) do if not allowed[key] then return false end end
    return true
end
local function array(v,maximum)
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
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function date(v)
    if type(v)~="string" then return nil end
    local ys,ms,ds=v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not ys then return nil end
    local y,m,d=tonumber(ys),tonumber(ms),tonumber(ds)
    if not y or not m or not d or y<1 or m<1 or m>12 then return nil end
    local leap=y%4==0 and (y%100~=0 or y%400==0)
    local lengths={31,leap and 29 or 28,31,30,31,30,31,31,30,31,30,31}
    if d<1 or d>lengths[m] then return nil end
    local prior=y-1
    local ordinal=365*prior+math.floor(prior/4)-math.floor(prior/100)+math.floor(prior/400)+d
    for month=1,m-1 do ordinal=ordinal+lengths[month] end
    return ordinal,y
end
local function record(id)
    if not text(id,128) then return nil end
    local ok,rec=pcall(function() return SAO.Identity.get(id) end)
    return ok and type(rec)=="table" and rec.id==id and rec or nil
end
local function clock()
    local ok,now=pcall(function() return SAO.History.countyHours() end)
    return ok and finite(now) and now>=0 and now or nil
end
local function calendar(now)
    local ok,instant=pcall(function() return SAO.History.countyInstant(now) end)
    if not ok or type(instant)~="string" or #instant~=19 then return nil end
    local day,hs,ms,ss=instant:match("^(%d%d%d%d%-%d%d%-%d%d)T(%d%d):(%d%d):(%d%d)$")
    local ordinal=day and date(day)
    local h,m,s=tonumber(hs),tonumber(ms),tonumber(ss)
    if not ordinal or not h or not m or not s or h>23 or m>59 or s>59 then return nil end
    return ordinal+(h*3600+m*60+s)/86400,instant
end
local function episodeValid(row,id,birthYear,cutoff)
    if not fields(row,{"id","ownerId","occurredOn","acquiredOn","participants","subject","action",
        "description","valence","salience","sourceId","sourceSha256","provenance"},{"relations"})
        or not text(row.id,128) or row.ownerId~=id or not word(row.subject) or not word(row.action)
        or not text(row.description,2048) or not text(row.sourceId,512) or not hash(row.sourceSha256)
        or (row.provenance~="real" and row.provenance~="authored-synthetic")
        or not finite(row.valence) or row.valence< -1 or row.valence>1
        or not finite(row.salience) or row.salience<0 or row.salience>1
        or not array(row.participants,MAX_PARTICIPANTS) then return false end
    local occurred,year=date(row.occurredOn)
    local acquired=date(row.acquiredOn)
    if not occurred or not acquired or year<birthYear or acquired<occurred or acquired>cutoff then return false end
    local ids={}
    for _,participant in ipairs(row.participants) do
        if not text(participant,128) or ids[participant] then return false end;ids[participant]=true
    end
    if row.relations~=nil then
        if not array(row.relations,MAX_RELATIONS) then return false end
        local seen={}
        for _,edge in ipairs(row.relations) do
            if not fields(edge,{"from","relation","into","confidence"},{"affirmed"})
                or not word(edge.from) or not word(edge.into) or not RELATIONS[edge.relation]
                or not finite(edge.confidence) or edge.confidence<0 or edge.confidence>1
                or (edge.affirmed~=nil and type(edge.affirmed)~="boolean") then return false end
            local key=edge.from.."|"..edge.relation.."|"..edge.into
            if seen[key] then return false end;seen[key]=true
        end
    end
    return true
end
local function initialValid(value,rec,now)
    if not fields(value,{"schema","personId","issuerId","sourceId","sourceSha256","definitionSha256",
        "worldId","saveId","admissionKey","admittedAtHours","startDate","cutoffDate","birthYear","episodes"})
        or value.schema~="sao-personal-memory-initial/1" or value.personId~=rec.id
        or not hash(value.definitionSha256) or value.sourceSha256~=value.definitionSha256
        or value.worldId~=value.definitionSha256 or value.sourceId~="study-definition:"..value.definitionSha256
        or value.issuerId~="initial-cohort:"..value.definitionSha256
        or not text(value.saveId,128) or not text(value.admissionKey,256)
        or not finite(value.admittedAtHours) or value.admittedAtHours<0 or value.admittedAtHours>now
        or not finite(value.birthYear) or value.birthYear%1~=0 or value.birthYear<1
        or not array(value.episodes,MAX_EPISODES) then return false end
    local start,year=date(value.startDate)
    local cutoff=date(value.cutoffDate)
    if not start or not cutoff or year>=1994 or value.cutoffDate~=value.startDate
        or value.birthYear>year or (rec.birthYear~=nil and rec.birthYear~=value.birthYear) then return false end
    local ids={}
    for _,episode in ipairs(value.episodes) do
        if not episodeValid(episode,rec.id,value.birthYear,cutoff) or ids[episode.id] then return false end
        ids[episode.id]=true
    end
    return true
end
local function currentInitial(rec,now)
    if not provider or issuer~=SAO.PopulationAdmissions then return false,nil end
    local ok,value=pcall(provider,rec)
    if not ok then return false,nil end
    if value==nil then return true,nil end
    return initialValid(value,rec,now),value
end
-- Pure validation is also used by Admissions before generated identity exists.
-- Validation alone grants no source custody and never attaches a person.
function M.validateInitial(value,rec,now)
    return type(rec)=="table" and text(rec.id,128) and finite(now) and now>=0
        and initialValid(value,rec,now) or false
end
function M.validStartDate(value)
    local ordinal,year=date(value)
    return ordinal~=nil and year<1994
end
local function stateValid(value,rec,now)
    return fields(value,{"schemaVersion","actorId","initial"}) and value.schemaVersion==1
        and value.actorId==rec.id and initialValid(value.initial,rec,now)
end
local function heldState(rec,now)
    local state=rec.personalMemory
    if not stateValid(state,rec,now) then return nil,"memory-invalid-state" end
    local ok,initial=currentInitial(rec,now)
    if not ok or initial==nil or not equal(initial,state.initial) then return nil,"memory-source-unavailable" end
    return state
end
function M.bindInitialProvider(owner,reader)
    if provider or not owner or owner~=SAO.PopulationAdmissions or type(reader)~="function" then return false end
    issuer,provider=owner,reader;return true
end
function M.attachInitial(rec)
    local now=clock()
    if type(rec)~="table" or not now or record(rec.id)~=rec then return false,"memory-person-binding" end
    if rec.personalMemory~=nil then
        local state,why=heldState(rec,now)
        return state~=nil,why or "memory-retained"
    end
    if not provider then return true,"memory-unconfigured" end
    local ok,initial=currentInitial(rec,now)
    if not ok then return false,"memory-initial-binding" end
    if initial==nil then return true,"memory-unconfigured" end
    rec.personalMemory={schemaVersion=1,actorId=rec.id,initial=copy(initial)}
    return true,"memory-attached"
end
function M.snapshot(id)
    local rec,now=record(id),clock()
    if not rec or not now then return nil,"memory-person-unavailable" end
    local state,why=heldState(rec,now)
    return state and copy(state) or nil,why or "memory-retained"
end
local function unavailable(id,reason)
    return {actorId=id,status="unavailable",reason=reason,configured=true,episodes={},retainedCount=0,inaccessibleCount=0,notYetAcquiredCount=0}
end
function M.query(id,subject)
    local rec,now=record(id),clock()
    if not rec or not now then return unavailable(id,"memory-person-unavailable") end
    if subject~=nil and not word(subject) then return unavailable(id,"memory-invalid-cue") end
    if rec.personalMemory==nil then
        if provider then
            local ok,initial=currentInitial(rec,now)
            if not ok or initial~=nil then return unavailable(id,"memory-not-attached") end
        end
        return {actorId=id,status="unconfigured",configured=false,episodes={},retainedCount=0,inaccessibleCount=0,notYetAcquiredCount=0}
    end
    local state,why=heldState(rec,now)
    if not state then return unavailable(id,why) end
    local currentDay,currentInstant=calendar(now)
    if not currentDay then return unavailable(id,"memory-calendar-unavailable") end
    local ok,clarity=pcall(function() return SAO.Neuro.clarityOf(rec) end)
    if not ok or not finite(clarity) or clarity<0 or clarity>1 then return unavailable(id,"memory-clarity-unavailable") end
    local episodes,inaccessible,notYetAcquired={},0,0
    local retention,retentionSource=math.max(0.2,clarity),"neuro"
    local retentionMetadata
    if SAO.Conditions~=nil then
        local valid,factor,metadata=pcall(function() return SAO.Conditions.memoryFactor(id,"autobiographical") end)
        if not valid or not finite(factor) or factor<=0 then return unavailable(id,"memory-retention-unavailable") end
        if metadata~=nil then
            if type(metadata)~="table" or metadata.status=="unavailable" then
                return unavailable(id,"memory-age-projection-unavailable")
            end
            retentionMetadata=copy(metadata)
        end
        retention,retentionSource=factor,"conditions"
    end
    for _,episode in ipairs(state.initial.episodes) do
        local ageDays=currentDay-date(episode.acquiredOn)
        local horizon=(MIN_HORIZON_DAYS+SALIENCE_HORIZON_DAYS*episode.salience)*retention
        local retained=1/(1+ageDays/horizon)
        local accessibility=retained*clarity
        local matches=subject==nil or subject==episode.subject
        for _,edge in ipairs(episode.relations or {}) do
            if edge.from==subject or edge.into==subject then matches=true end
        end
        if matches then
            if ageDays<0 then notYetAcquired=notYetAcquired+1
            elseif retained>=RECALL_THRESHOLD and clarity>0 then
                local row=copy(episode)
                row.episodeId=episode.id;row.actorId=id;row.ageDays=ageDays
                row.retainedStrength=retained;row.accessibility=accessibility;row.accessible=true
                row.basis="personal-episode-recall";row.mastery="unassessed";row.assent="not-established"
                episodes[#episodes+1]=row
            else inaccessible=inaccessible+1 end
        end
    end
    return {actorId=id,configured=true,status=#episodes>0 and "available" or inaccessible>0 and "inaccessible"
            or notYetAcquired>0 and "not-yet-acquired" or "empty",
        episodes=episodes,retainedCount=#state.initial.episodes,inaccessibleCount=inaccessible,notYetAcquiredCount=notYetAcquired,
        currentInstant=currentInstant,
        clarity=clarity,retentionFactor=retention,retentionSource=retentionSource,retentionMetadata=retentionMetadata,
        atHours=now,sourceId=state.initial.sourceId,
        sourceSha256=state.initial.sourceSha256,admissionKey=state.initial.admissionKey,
        coefficients="uncalibrated-recall-v1"}
end
function M.relations(id)
    local recall=M.query(id)
    if recall.status=="unavailable" or recall.status=="unconfigured" then return {},recall.status,0 end
    local rec=record(id)
    local edges,total={},0
    for _,episode in ipairs(recall.episodes) do total=total+#(episode.relations or {}) end
    for _,episode in ipairs(recall.episodes) do
        for index,relation in ipairs(episode.relations or {}) do
            if #edges>=64 then return edges,"truncated",total-#edges end
            edges[#edges+1]={id="autobiography/"..id.."/"..episode.id.."/"..index,actorId=id,
                from=relation.from,relation=relation.relation,into=relation.into,affirmed=relation.affirmed~=false,
                confidence=relation.confidence*episode.accessibility,basis="autobiographical-association",modal=true,
                sourceId=episode.sourceId,sourceSha256=episode.sourceSha256,provenance=episode.provenance,
                acquiredAt=rec.personalMemory.initial.admittedAtHours,occurredOn=episode.occurredOn,acquiredOn=episode.acquiredOn,
                parentId=episode.id,episodeId=episode.id,valence=episode.valence,salience=episode.salience,
                retainedStrength=episode.retainedStrength,accessibility=episode.accessibility,
                retention="modeled",mastery="unassessed",assent="not-established"}
        end
    end
    return edges,recall.status,0
end
return M
