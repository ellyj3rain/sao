-- Exact source-issued Lifestyle AddXP requests on an owned native SP NPC.
-- LSservercommands:AddXP calls addXp(player,Perks[name],amount), then SyncXp.
-- Installed GlobalObject.addXp's SP branch uses that body's normal XP.AddXP;
-- SyncXp is a no-op outside client mode. The engine retains all XP multipliers.
SAO = SAO or {}
SAO.LeisureSkill = SAO.LeisureSkill or {}
local S = SAO.LeisureSkill
local inFlight = {}
local PROVIDERS = { ["SAO.Leisure"]="Leisure", ["SAO.LeisureArt"]="LeisureArt", ["SAO.LeisureMusic"]="LeisureMusic", ["SAO.LeisureExercise"]="LeisureExercise",["SAO.LeisureRadio"]="LeisureRadio",["SAO.LeisureLifestyle"]="LeisureLifestyle" }
local RECEIVER_REVISION = "fa33de3b2136a068070e690d0ebabc81126740b80b4bf0977d6f536d24a0afc0"
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1000000000 end
local function integer(n) return finite(n) and n>=1 and n==math.floor(n) end
local function text(v,max) return type(v)=="string" and #v>0 and #v<=max end
local function copy(v,depth)
    if type(v)~="table" then return v end
    depth=depth or 0;if depth>=6 then return nil end
    local out={} for k,x in pairs(v) do
        if type(k)=="string" or type(k)=="number" then
            if type(x)=="table" then out[k]=copy(x,depth+1)
            elseif type(x)=="string" or type(x)=="boolean" or finite(x) then out[k]=x end
        end
    end return out
end
local function person(id) return SAO.Identity and SAO.Identity.get(id) end
local function hours() return SAO.History and SAO.History.countyHours() end
local function provider(name) return PROVIDERS[name] and SAO[PROVIDERS[name]] end
local function live(id,body)
    local r=person(id)
    return r and not r.dead and body and SAO.Body and SAO.Body.get(id)==body
        and SAO.Needs and SAO.Needs.ownsRecoveryBody(id,body)==true
        and body:isExistInTheWorld() and not body:isDead() and not body:isAsleep()
end
local function state(id,create)
    local r=person(id);if not r then return nil end
    if r.leisureSkill==nil and create then r.leisureSkill={schema=1,actorId=id,cursors={},receipts={},order={}} end
    local s=r.leisureSkill
    return type(s)=="table" and s.schema==1 and s.actorId==id and type(s.cursors)=="table"
        and type(s.receipts)=="table" and type(s.order)=="table" and s or nil
end
local function key(name,workSequence,sequence) return name.."/"..workSequence.."/"..sequence end
local function binding(id,body,name,workSequence,sequence)
    local owner=provider(name)
    if not owner or type(owner.skillRequest)~="function" or type(owner.work)~="function"
        or not integer(workSequence) or not integer(sequence) or not live(id,body) then return nil,"source-owner-unavailable" end
    local request=owner.skillRequest(id,workSequence,sequence)
    local work=owner.work(id)
    local at=hours()
    if type(request)~="table" or type(work)~="table" or not finite(at)
        or request.status~="requested" or request.actorId~=id or request.workSequence~=workSequence
        or request.sequence~=sequence or work.actorId~=id or work.sequence~=workSequence
        or work.status~="active" or not text(work.workId,160) or request.workId~=work.workId
        or not text(work.purposeId,160) or request.purposeId~=work.purposeId
        or not text(work.sourceId,160) or request.sourceId~=work.sourceId
        or not text(work.revision,160) or request.revision~=work.revision
        or not finite(work.admittedAtHours) or work.admittedAtHours>at
        or not finite(request.atHours) or request.atHours<work.admittedAtHours or request.atHours>at
        or not text(request.perkName,96) or not finite(request.amount) or request.amount<=0
        or type(work.bodyGenerationKnown)~="boolean" then return nil,"source-request-unavailable" end
    local token=body:getModData().SAOExternalToken
    if work.bodyGenerationKnown~=(type(token)=="string" and #token>0)
        or work.bodyToken~=token or token~=nil and not text(token,160) then return nil,"body-generation-changed" end
    local progress=request.nativeProgress
    if type(progress)~="table" or progress.actionStarted~=true
        or (progress.sourceCallback~="update" and progress.sourceCallback~="perform")
        or not integer(progress.sourceInvocationSequence) or not finite(progress.jobDelta)
        or progress.jobDelta<0 or progress.jobDelta>1 then return nil,"source-progress-unavailable" end
    local P=SAO.ProceduralPlanning
    local admission=P and P.hobbyAdmission and P.hobbyAdmission(id,work.purposeId,work.workId)
    if type(admission)~="table" or admission.ownerName~=name then return nil,"typed-admission-unavailable" end
    for _,field in ipairs({"actorId","sequence","workId","purposeId","sourceId","revision",
        "bodyGenerationKnown","bodyToken","admittedAtHours"}) do
        if admission[field]~=work[field] then return nil,"typed-admission-mismatch" end
    end
    return copy(request),work
end
function S.receipt(id,name,workSequence,sequence)
    if not PROVIDERS[name] or not integer(workSequence) or not integer(sequence) then return nil end
    local s=state(id,false);local r=s and s.receipts[key(name,workSequence,sequence)]
    return r and r.actorId==id and copy(r) or nil
end
function S.consume(id,body,name,workSequence,sequence)
    if isClient() or isServer() then return false,"multiplayer-native-authority-unverified" end
    if inFlight[id] then return false,"native-application-active" end
    local request,work=binding(id,body,name,workSequence,sequence)
    if not request then return false,work end
    local s=state(id,true)
    if not s then return false,"skill-state-invalid" end
    local cursor=s.cursors[name]
    if cursor~=nil and (type(cursor)~="table" or not integer(cursor.workSequence)
        or not integer(cursor.sequence)) then return false,"skill-cursor-invalid" end
    if cursor and (workSequence<cursor.workSequence or sequence<=cursor.sequence) then
        return false,S.receipt(id,name,workSequence,sequence) or "request-already-consumed"
    end
    local expected=cursor and cursor.sequence+1 or 1
    if sequence~=expected then return false,"request-sequence-gap" end
    local r=copy(request);r.providerName=name;r.bodyToken=work.bodyToken;r.bodyGenerationKnown=work.bodyGenerationKnown
    r.status="applying";r.nativeOwner="LuaManager.GlobalObject.addXp:SP"
    r.requestedAtHours=request.atHours
    r.receiverSourceId=name=="SAO.LeisureRadio" and "native:ISRadioInteractions:doSkill"
        or "LifestyleHobbies:LSservercommands:AddXP"
    r.receiverRevision=RECEIVER_REVISION
    local identity=key(name,workSequence,sequence)
    -- Reserve before native AddXP, including failed/zero-effect calls. Reload
    -- cannot replay an attempt whose exact native application became unknown.
    s.cursors[name]={workSequence=workSequence,sequence=sequence}
    s.receipts[identity]=r;s.order[#s.order+1]=identity
    if #s.order>96 then s.receipts[table.remove(s.order,1)]=nil end
    local perk=Perks and Perks[request.perkName]
    local ok,before=pcall(function()return perk and perk:getId()==request.perkName and body:getXp():getXP(perk)end)
    if not perk or not ok or not finite(before) or type(addXp)~="function" or type(SyncXp)~="function" then
        r.status="unsupported";r.reason="native-perk-or-receiver-unavailable";r.atHours=hours()
        return false,copy(r)
    end
    r.beforeXP=before
    inFlight[id]=true
    local called=pcall(function()
        addXp(body,perk,request.amount)
        SyncXp(body)
    end)
    inFlight[id]=nil
    local measured,after=pcall(function()return body:getXp():getXP(perk)end)
    if not measured or not finite(after) then
        r.status="unobservable";r.reason="native-XP-postcondition-unavailable"
    else
        r.afterXP=after;r.appliedDelta=after-before
        if called and after>before then r.status="applied"
        elseif after==before then r.status="noeffect";r.reason="native-XP-unchanged"
        else r.status="interrupted";r.reason="native-application-failed-or-partial" end
    end
    r.atHours=hours();r.requestedAtHours=request.atHours
    return r.status=="applied",copy(r)
end
