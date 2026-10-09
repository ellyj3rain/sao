-- Source actions own participation and effects; this owner retains measured attempts.
SAO = SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end
SAO.Leisure = SAO.Leisure or {}
local L = SAO.Leisure
if L.reset then L.reset("module-reload") end
local runtime = {}
local SOURCE = "LifestyleHobbies"
local REVISION = "a0aea45b7d13286ad5efeff9f215fd5280d4d9fc799cdcb6929688ebb323a610"
local UTILITY_REVISION = "4e6b73720eefcafd828773067327664aa854228a6080705cf948c9cecc149ddb"
local MENU_REVISION = "8510da30c9c59ddc6e7275e6d23019d78fe7cf42d6608dfc7c77bfad01daa2f6"
local INIT_REVISION = "7fd07315ac820143f47db01ac8f3c4fc8f5f7b80241ddb4da47c69a362ac8eee"
local MOODLES_REVISION = "092a1418bc9f5b48e692ccaaeb8cd1d43f324047891cbf11b18978fcc9aea919"
local REVISION_AUTHORITY = "actor-local sealed action/utility/voice; shared helper loaded-byte-seal-unavailable"
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function plain(value, depth)
    depth = depth or 0
    if type(value) == "string" or type(value) == "boolean" then return value end
    if type(value) == "number" then return finite(value) and value or nil end
    if type(value) ~= "table" or depth >= 6 then return nil end
    local copy = {}
    for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then copy[k] = plain(v, depth + 1) end
    end
    return copy
end
local function person(id) return SAO.Identity and SAO.Identity.get(id) end
local function hours() return SAO.History.countyHours() end
local function live(id, body)
    return person(id) and SAO.Needs and SAO.Needs.ownsRecoveryBody(id, body) == true
end
local SOURCE_TEXT_PINS = {
    ["shared/TimedActions/LSMeditateAction.lua"] = {665979715,1470881503,429},
    ["shared/LSUtil.lua"] = {1541193869,1686604880,2388},
    ["client/TimedActions/PlayerVoiceTracks.lua"] = {1647777782,736065194,145},
}
local VOICE_REVISION = "4b5dd1871c51b68514922f804d2c10d4fe6775f72532c0c3e376a0a0bc3c732c"
local function sourceChunk(env,path)
    local pin=SOURCE_TEXT_PINS[path]
    if not pin or not (SAO.SourceIntegration and SAO.SourceIntegration.reader) or not loadstring or not setfenv then error("source-loader-unavailable") end
    local reader=SAO.SourceIntegration.reader(SOURCE,"media/lua/"..path)
    if not reader then error("source-file-unavailable") end
    local lines,h1,h2,count={},0,0,0
    local ok,why=pcall(function()
        while true do
            local line=reader:readLine();if line==nil then break end
            line=tostring(line);count=count+#line+1;if count>1048576 then error("source-file-too-large") end
            lines[#lines+1]=line
            for n=1,#line do local b=string.byte(line,n);h1=(h1*31+b)%2147483647;h2=(h2*131+b)%2147483647 end
            h1=(h1*31+10)%2147483647;h2=(h2*131+10)%2147483647
        end
    end)
    reader:close();if not ok then error(why) end
    if h1~=pin[1] or h2~=pin[2] or #lines~=pin[3] then error("source-revision-changed:"..path) end
    local fn,err=loadstring(table.concat(lines,"\n").."\n",SOURCE..":"..path)
    if not fn then error(err) end
    setfenv(fn,env);return fn()
end
local function maintained(id,body)
    local rec=person(id);local work=rec and rec.leisureWork;local active=runtime[id]
    if not work or work.status~="active" or not active or active.body~=body or not live(id,body)
        or work.bodyToken~=body:getModData().SAOExternalToken then return false end
    local P=SAO.ProceduralPlanning
    local admission=P and P.hobbyAdmission and P.hobbyAdmission(id,work.purposeId,work.workId)
    return admission and admission.ownerName=="SAO.Leisure" and admission.sequence==work.sequence
end
local function isolatedSource(id,body)
    local env=setmetatable({},{__index=_G});env._G=env
    env.ISBaseTimedAction=setmetatable({},{__index=ISBaseTimedAction})
    env.ISBaseTimedAction.stop=function(action)
        local queue=ISTimedActionQueue.getTimedActionQueue(body)
        if queue.current==action then queue:onCompleted(action)else queue:removeFromQueue(action)end
        body:setIsFarming(false)
    end
    env.require=function(name)
        if name=="TimedActions/ISBaseTimedAction" then return env.ISBaseTimedAction end
        if name=="TimedActions/PlayerVoiceTracks" then
            if not env.voiceTracks then env.voiceTracks=sourceChunk(env,"client/TimedActions/PlayerVoiceTracks.lua") end
            return env.voiceTracks
        end
        return require(name)
    end
    env.sendClientCommand=function(actor,module,command,args)
        local rec=person(id);local work=rec and rec.leisureWork;local active=runtime[id]
        if actor~=body or module~="LS" or command~="AddXP" or not maintained(id,body)
            or not active.started or (active.sourceCallback~="update" and active.sourceCallback~="perform")
            or not finite(args[2]) or args[2]<0 then error("unbound-source-skill-request") end
        if args[2]==0 then return end -- Authentic mastery issues no native XP operation.
        rec.leisureSkillRequestSequence=(rec.leisureSkillRequestSequence or 0)+1
        local request={actorId=id,workId=work.workId,purposeId=work.purposeId,workSequence=work.sequence,
            sequence=rec.leisureSkillRequestSequence,perkName=args[1],amount=args[2],atHours=hours(),
            sourceId=SOURCE,revision=REVISION,status="requested",nativeProgress={sourceCallback=active.sourceCallback,
                sourceInvocationSequence=active.sourceInvocationSequence,actionStarted=true,jobDelta=active.action:getJobDelta()}}
        active.skillRequests=active.skillRequests or {};active.skillRequests[request.sequence]=plain(request)
        rec.leisureSkillRequests=rec.leisureSkillRequests or {};rec.leisureSkillRequests[#rec.leisureSkillRequests+1]=plain(request)
        if #rec.leisureSkillRequests>64 then table.remove(rec.leisureSkillRequests,1) end
        if SAO.LeisureSkill and SAO.LeisureSkill.consume then
            SAO.LeisureSkill.consume(id,body,"SAO.Leisure",work.sequence,request.sequence)
        end
    end
    sourceChunk(env,"shared/LSUtil.lua")
    for _,name in ipairs({"changeCharacterMood","changeCharacterMoodGroup","addPainBodyPart"}) do
        local native=env.LSUtil[name]
        if native then env.LSUtil[name]=function(actor,...)
            if actor~=body or not maintained(id,body) then error("source-effect-owner-lost") end
            return native(actor,...)
        end end
    end
    sourceChunk(env,"shared/TimedActions/LSMeditateAction.lua")
    return env.LSMeditateAction,env
end
local function source()
    if not (SAO.SourceIntegration and SAO.SourceIntegration.available(SOURCE)) then return nil, "source-not-active" end
    if isClient() or isServer() then return nil, "npc-source-command-binding-unverified" end
    if not LSMeditateAction then pcall(require, "TimedActions/LSMeditateAction") end
    if not LSMeditateAction or not LSUtil or not LSUtil.getCharacterMood
        or not Perks.Meditation or not GTLSCheck or not SandboxVars.Meditation
        or not SandboxVars.LSMeditation then return nil, "source-runtime-unavailable" end
    return LSMeditateAction
end
local function knowledge(id)
    local K = SAO.ConceptKnowledge
    if not K or not K.infer then return nil end
    for _, effect in ipairs({ "recreation", "relief-from-stress" }) do
        local view = K.infer(id, "meditation", effect)
        local path = view and view.actorId == id and view.paths and view.paths[1]
        if path and path.status == "expectation" and type(path.id) == "string"
            and type(path.evidenceIds) == "table" and #path.evidenceIds > 0 then
            return { id = path.id, evidenceIds = plain(path.evidenceIds), basis = path.basis,
                expectedEffect = effect, modal = true }
        end
    end
end
local function held(body, item)
    if not item then return true end
    local items = SAOJavaBridge:privateCarriedItems(body)
    for i = 0, items:size() - 1 do if items:get(i) == item then return true end end
    return false
end
local function physical(body, continuing)
    if body:isAsleep() or body:getVehicle() or body:isAiming() or not body:isSitOnGround()
        or body:isSittingOnFurniture() or body:getModData().IsSittingOnSeat then return false, "meditation-posture-unavailable" end
    if not continuing and not SAO.Needs.workAvailable(body) then return false, "native-work-busy" end
    local data = body:getModData()
    if data.IsMeditationDisturbed then return false, "meditation-disturbed" end
    if type(data.LSMoodles) ~= "table" or type(data.LSMoodles.MindfulState) ~= "table"
        or not finite(data.LSMoodles.MindfulState.Value)
        or type(data.LSMoodles.WasTaughtSkill) ~= "table" or not finite(data.LSMoodles.WasTaughtSkill.Value) then
        return false, "source-person-state-unavailable"
    end
    if not continuing and LSUtil.getCharacterMood(body, "Boredom") > 30 then return false, "source-meditation-boredom-refusal" end
    for _, item in ipairs({ body:getPrimaryHandItem() or false, body:getSecondaryHandItem() or false }) do
        if item and (item:isForceDropHeavyItem() or not held(body, item)) then return false, "meditation-hand-preparation-required" end
    end
    if body:getPerkLevel(Perks.Meditation) < 3 and not SandboxVars.Meditation.KeepBags then
        local worn = body:getWornItems()
        for i = 0, worn:size() - 1 do
            if instanceof(worn:get(i):getItem(), "InventoryContainer") then return false, "meditation-bag-preparation-required" end
        end
    end
    return true
end
local function snapshot(body)
    local values = {}
    for _, name in ipairs({ "Boredom", "Stress", "Unhappiness", "Endurance", "Fatigue", "Pain" }) do
        local v = LSUtil.getCharacterMood(body, name)
        if not finite(v) then return nil end
        values[name] = v
    end
    local pain = body:getBodyDamage():getBodyPart(BodyPartType.Neck):getAdditionalPain()
    if not finite(pain) then return nil end
    values.NeckAdditionalPain = pain
    return values
end
function L.prepareActor(id, body)
    local ok, prepared, reason = pcall(function()
        if not live(id, body) then return false, "body-unavailable" end
        local owner, why = source()
        if not owner then return false, why end
        -- The source's public per-character initializer only supplies its real
        -- moodle defaults. Its player-selected UI lifecycle is never invoked.
        if not LSMoodleManager or type(LSMoodleManager.init) ~= "function" then
            return false, "source-person-initializer-unavailable"
        end
        LSMoodleManager.init(body)
        local data = body:getModData()
        if not data.LSMoodles or not data.LSMoodles.MindfulState or not data.LSMoodles.WasTaughtSkill then
            return false, "source-person-initialization-incomplete"
        end
        person(id).leisureSourceInitialization = { actorId = id, sourceId = SOURCE,
            nativeOwner = "LSMoodleManager.init", revision = INIT_REVISION,
            propertiesRevision = MOODLES_REVISION, bodyToken = data.SAOExternalToken,
            bodyGenerationKnown = data.SAOExternalToken ~= nil, atHours = hours() }
        return true
    end)
    if not ok then return false, "source-person-initialization-failed" end
    return prepared, reason
end
function L.offers(id, body)
    local ok, offers, reason = pcall(function()
        if not live(id, body) then return {}, "body-unavailable" end
        local owner, why = source()
        if not owner then return {}, why end
        local active = runtime[id]
        if active then return {}, "leisure-attempt-active" end
        local ready, refusal = physical(body, false)
        if not ready then return {}, refusal end
        local evidence = knowledge(id)
        if not evidence then return {}, "meditation-not-personally-understood" end
        if not snapshot(body) then return {}, "native-measurement-unavailable" end
        return {{ id = "leisure:" .. id .. ":meditation", actorId = id, family = "wellness",
            sourceId = SOURCE, revision = REVISION, utilityRevision = UTILITY_REVISION,
            menuRevision = MENU_REVISION, revisionAuthority = REVISION_AUTHORITY,
            activity = "meditate", itemKey = "body:meditation", evidence = evidence,
            afterSequence = person(id).leisureSequence or 0, bodyToken = body:getModData().SAOExternalToken,
            bodyGenerationKnown = body:getModData().SAOExternalToken ~= nil,
            prerequisites = { posture = "native-seated-ground", sourcePersonState = true,
                handCustody = true, bagPreparation = true, multiplayerBinding = "unverified" } }}
    end)
    if not ok then return {}, "leisure-source-observation-unavailable" end
    return offers, reason
end
function L.intentOffers(id, body)
    local ok, offers, reason = pcall(function()
        if not live(id, body) then return {}, "body-unavailable" end
        local owner, why = source()
        if not owner then return {}, why end
        if runtime[id] or not SAO.Needs.workAvailable(body) then return {}, "native-work-busy" end
        local evidence = knowledge(id)
        if not evidence then return {}, "meditation-not-personally-understood" end
        if body:isAsleep() or body:getVehicle() or body:isAiming() or body:isSittingOnFurniture()
            or body:getModData().IsSittingOnSeat then return {}, "meditation-body-unavailable" end
        if LSUtil.getCharacterMood(body, "Boredom") > 30 then return {}, "source-meditation-boredom-refusal" end
        local data = body:getModData()
        local ready = type(data.LSMoodles) == "table" and type(data.LSMoodles.MindfulState) == "table"
            and finite(data.LSMoodles.MindfulState.Value) and type(data.LSMoodles.WasTaughtSkill) == "table"
            and finite(data.LSMoodles.WasTaughtSkill.Value)
        local hand, bag = false, false
        for _, item in ipairs({ body:getPrimaryHandItem() or false, body:getSecondaryHandItem() or false }) do
            if item and (item:isForceDropHeavyItem() or not held(body, item)) then hand = true end
        end
        if body:getPerkLevel(Perks.Meditation) < 3 and not SandboxVars.Meditation.KeepBags then
            local worn = body:getWornItems()
            for i = 0, worn:size() - 1 do
                if instanceof(worn:get(i):getItem(), "InventoryContainer") then bag = true end
            end
        end
        return {{ id = "leisure:" .. id .. ":meditation", actorId = id, family = "wellness",
            sourceId = SOURCE, revision = REVISION, utilityRevision = UTILITY_REVISION, menuRevision = MENU_REVISION,
            revisionAuthority = REVISION_AUTHORITY, activity = "meditate",
            itemKey = "body:meditation", evidence = evidence, afterSequence = person(id).leisureSequence or 0,
            bodyToken = data.SAOExternalToken, bodyGenerationKnown = data.SAOExternalToken ~= nil,
            requiresPreparation = { sourceInitialization = not ready, sitOnGround = not body:isSitOnGround(),
                handCustody = hand, bagRemoval = bag }, preparationBlocked = hand or bag,
            prerequisites = { posture = "native-seated-ground", sourcePersonState = true,
                handCustody = true, bagPreparation = true, multiplayerBinding = "unverified" } }}
    end)
    if not ok then return {}, "leisure-source-observation-unavailable" end
    return offers, reason
end
local function equivalent(a, b, depth)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    depth = depth or 0
    if depth > 6 then return false end
    for key, value in pairs(a) do if not equivalent(value, b[key], depth + 1) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function purposeFor(id, purposeId, offer)
    local rec = person(id)
    local planning = rec and rec.proceduralPlanning
    local p = planning and planning.purposes and planning.purposes[purposeId]
    local step = p and p.steps and p.steps[p.cursor]
    if not p or p.domain ~= "leisure" or p.status == "completed" or p.status == "abandoned"
        or not p.leisure or p.leisure.activity ~= offer.activity or p.leisure.itemKey ~= offer.itemKey
        or not step or step.id ~= "perform-activity" or step.owner ~= "SAO.Leisure"
        or step.status ~= "available" then return nil end
    return p
end
local function bound(action)
    local rec = person(action.personId)
    local work = rec and rec.leisureWork
    local active = runtime[action.personId]
    return work and work.status == "active" and active and active.action == action
        and active.body == action.character and work.id == action.workId
        and work.sequence == action.sequence and live(action.personId, action.character)
        and action.character:getModData().SAOExternalToken == work.bodyToken
end
local function finish(id, status, reason)
    local rec = person(id)
    local work = rec and rec.leisureWork
    if not work or work.status ~= "active" then return false end
    local active = runtime[id]
    local valid = active and bound(active.action)
    local measured = valid and snapshot(active.body) or nil
    if status == "completed" and (not valid or not active.performed or not active.started
        or not finite(work.progress) or work.progress <= 0) then status, reason = "interrupted", "native-participation-unproven" end
    work.status, work.reason, work.endedAt = status, reason, hours()
    work.after = measured or work.lastMeasured
    work.afterCurrent = measured ~= nil
    local row = plain(work)
    row.actorId, row.workId, row.atHours, row.nativeOwner = id, work.id, work.endedAt, "LSMeditateAction"
    row.token = status == "completed" and "leisure:performed" or "leisure:interrupted"
    row.measurementAuthority = "native-source-action-interval; concurrent-effects-not-isolated"
    row.skillCredit = "source-requests-issued; canonical-LeisureSkill-receipts-own-native-credit"
    row.cleanupSucceeded = active and (active.stopped == true or active.performSucceeded == true) or false
    rec.leisureOutcomes = rec.leisureOutcomes or {}
    rec.leisureOutcomes[#rec.leisureOutcomes + 1] = row
    if #rec.leisureOutcomes > 32 then table.remove(rec.leisureOutcomes, 1) end
    runtime[id] = nil
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeHobbyOutcome then
        SAO.ProceduralPlanning.consumeHobbyOutcome(id, work.sequence)
    end
    return true
end
-- Values are the installed ZenWellnessContextMenu's level table. Effects remain
-- entirely in the source action/LSUtil; these constructor values grant no reward.
local function makeAction(body, owner)
    local level = body:getPerkLevel(Perks.Meditation)
    local values = {
        { 0, "Bob_meditatingBeginnerC", 9, 2000, 0, 0.1, 20, "defaultsound" },
        { 2, "Bob_meditatingInterC", 14, 2800, 3, 0.3, 12, "defaultsound" },
        { 4, "Bob_meditatingC", 36, 8000, 6, 0.5, 6, "defaultsound" },
        { 6, "Bob_meditatingC", 54, 12000, 8, 1, 0, "defaultsound" },
        { 8, "Bob_meditatingAdvanced", 99, 20000, 12, 1.5, 0, "Advanced" },
        { 10, "Bob_meditatingMaster", 0, 30000, 15, 2, 0, "master" },
    }
    local chosen = values[1]
    for _, row in ipairs(values) do if level >= row[1] then chosen = row end end
    local anim, sound = chosen[2], chosen[8]
    if SandboxVars.LSMeditation.RemoveLevitation and level >= 8 then anim, sound = "Bob_meditatingC", "defaultsound" end
    local mult = ({ [1] = 0.2, [2] = 1, [3] = 3 })[SandboxVars.Meditation.StrengthMultiplier or 2] or 1
    return owner:new(body, sound, chosen[4], level, chosen[3], chosen[5], chosen[6] * mult, chosen[7], anim)
end
function L.begin(id, body, offer, purposeId)
    local offers, why = L.offers(id, body)
    local current = offers[1]
    if not current or not equivalent(current, offer) then return false, why or "stale-or-foreign-leisure-offer" end
    if not purposeFor(id, purposeId, current) then return false, "leisure-purpose-not-owned" end
    local rec = person(id)
    local prior = rec.leisureWork
    if prior and prior.status == "active" then finish(id, "interrupted", "runtime-owner-lost") end
    local sourceOwner = source()
    local made,owner,env=pcall(isolatedSource,id,body)
    if not made then return false,"native-source-construction-failed:"..tostring(owner) end
    local action = makeAction(body, owner)
    rec.leisureSequence = (rec.leisureSequence or 0) + 1
    local sequence = rec.leisureSequence
    rec.leisureWork = { id = "leisure:" .. id .. ":" .. sequence, workId = "leisure:" .. id .. ":" .. sequence,
        sequence = sequence, purposeId = purposeId, family = "wellness", nativeOwner = "LSMeditateAction",
        actorId = id, activity = current.activity, itemKey = current.itemKey, sourceId = SOURCE,
        revision = REVISION, utilityRevision = UTILITY_REVISION, menuRevision = MENU_REVISION,
        revisionAuthority = current.revisionAuthority, evidence = plain(current.evidence),
        bodyToken = current.bodyToken, bodyGenerationKnown = current.bodyGenerationKnown,
        beganAt = hours(), admittedAtHours = hours(), before = snapshot(body), status = "active",
        phase = "prepared", progress = 0, nativeProgress = { delta = 0, observedUpdates = 0 } }
    action.personId, action.workId, action.sequence = id, rec.leisureWork.id, sequence
    local active = { body = body, action = action, work=rec.leisureWork,emitter=body:getEmitter(),
        source = sourceOwner, sourceClass = owner, environment=env }
    runtime[id] = active
    local native = { start = owner.start, update = owner.update, perform = owner.perform,
        stop = owner.stop, valid = owner.isValid }
    action.isValid = function(self)
        local ready = source() == sourceOwner and bound(self) and maintained(id,body) and physical(body, true)
        return ready and held(body, self.handItemLeft) and held(body, self.handItemRight) and native.valid(self)
    end
    action.start = function(self)
        if not self:isValid() then self:forceStop(); return end
        local ok = pcall(native.start, self)
        if not ok then active.failureReason = "native-source-start-failed"; self:stop(); self:forceStop(); return end
        active.started = true
        rec.leisureWork.startedAt = hours()
    end
    action.update = function(self)
        if not self:isValid() then self:forceStop(); return end
        if not active.started then return end
        rec.leisureSourceInvocationSequence=(rec.leisureSourceInvocationSequence or 0)+1
        active.sourceCallback,active.sourceInvocationSequence="update",rec.leisureSourceInvocationSequence
        local ok = pcall(native.update, self)
        active.sourceCallback=nil
        if not ok then active.failureReason = "native-source-update-failed"; self:stop(); self:forceStop(); return end
        if not bound(self) then return end
        local delta = self:getJobDelta()
        if finite(delta) and delta > rec.leisureWork.progress and delta <= 1 then
            rec.leisureWork.progress, rec.leisureWork.phase = delta, "executing"
            rec.leisureWork.nativeProgress.delta = delta
            rec.leisureWork.nativeProgress.observedUpdates = rec.leisureWork.nativeProgress.observedUpdates + 1
            rec.leisureWork.lastProgressAt = hours()
            rec.leisureWork.lastMeasured = snapshot(body)
        end
    end
    action.perform = function(self)
        if active.performed or not self:isValid() or not active.started
            or rec.leisureWork.progress <= 0 or self:getJobDelta() < 1
            or not ISTimedActionQueue.hasAction(self) then return end
        active.performed = true
        rec.leisureSourceInvocationSequence=(rec.leisureSourceInvocationSequence or 0)+1
        active.sourceCallback,active.sourceInvocationSequence="perform",rec.leisureSourceInvocationSequence
        local ok = pcall(native.perform, self)
        active.sourceCallback=nil
        active.performSucceeded = ok
        finish(id, ok and "completed" or "interrupted", not ok and "native-source-perform-failed" or nil)
    end
    action.stop = function(self)
        if not bound(self) then return end
        if live(id, body) and ISTimedActionQueue.hasAction(self) then
            -- A lost former hand item is not re-equipped by source cleanup.
            if not held(body, self.handItemLeft) then self.handItemLeft = nil end
            if not held(body, self.handItemRight) then self.handItemRight = nil end
            active.stopped = pcall(native.stop, self)
        end
        finish(id, "interrupted", active.failureReason or "native-source-stopped")
    end
    action.forceCancel = function(self) if bound(self) then finish(id, "interrupted", "native-source-cancelled") end end
    local planner = SAO.ProceduralPlanning
    if not planner or not planner.admitHobbyWork or not planner.admitHobbyWork(id, purposeId, sequence) then
        finish(id, "interrupted", "leisure-planner-admission-refused")
        return false, "leisure-planner-admission-refused"
    end
    local ok = pcall(ISTimedActionQueue.add, action)
    if not ok or not ISTimedActionQueue.hasAction(action) then
        finish(id, "interrupted", "native-source-queue-refused")
        return false, "native-source-queue-refused"
    end
    return true, plain(rec.leisureWork)
end
function L.work(id)
    local active = runtime[id]
    if not active or not bound(active.action) then return nil end
    return plain(person(id).leisureWork)
end
function L.advance(id, body)
    local rec = person(id)
    local work = rec and rec.leisureWork
    if not work then return false, "leisure-work-unavailable" end
    if work.status ~= "active" then return false, work.status end
    local active = runtime[id]
    if not active then finish(id, "interrupted", "runtime-owner-lost"); return false, "runtime-owner-lost" end
    if active.body ~= body then return false, "foreign-body" end
    if not bound(active.action) or not ISTimedActionQueue.hasAction(active.action) then
        finish(id, "interrupted", "native-source-owner-lost"); return false, "native-source-owner-lost"
    end
    return true, plain(work)
end
function L.outcome(id, sequence)
    local rec = person(id)
    for _, row in ipairs(rec and rec.leisureOutcomes or {}) do
        if row.actorId == id and row.sequence == sequence then return plain(row) end
    end
end
function L.skillRequest(id,workSequence,sequence)
    local active=runtime[id]
    if not active or not bound(active.action) or active.action.sequence~=workSequence or not active.started
        or not maintained(id,active.body) or not active.action:isValid()
        or not ISTimedActionQueue.hasAction(active.action) then return nil end
    local row=active.skillRequests and active.skillRequests[sequence]
    return row and row.actorId==id and row.workSequence==workSequence and plain(row) or nil
end
function L.detach(id,body,reason)
    local active=runtime[id]
    if not active then return L.interrupt(id,body,reason)end
    if active.body~=body then return false end
    if live(id,body) then
        L.interrupt(id,body,reason)
    end
    local action=active.action
    if active.emitter and action.GameSound then pcall(function()active.emitter:stopSound(action.GameSound)end)end
    local data=body:getModData()
    if data.SAOPersonId==id and data.SAOExternalToken==active.work.bodyToken then
        data.IsMeditating=false
    end
    if ISTimedActionQueue.hasAction(action)then
        if action.action then pcall(function()action.action:forceStop()end)end
        local queue=ISTimedActionQueue.getTimedActionQueue(body)
        if queue.current==action then queue:onCompleted(action)else queue:removeFromQueue(action)end
    end
    local rec=person(id)
    if rec and rec.leisureWork==active.work then finish(id,"interrupted",reason or "native-body-owner-ended")
    else runtime[id]=nil end
    return true
end
function L.interrupt(id, body, reason)
    local active = runtime[id]
    local rec = person(id)
    if not rec or not rec.leisureWork or rec.leisureWork.status ~= "active" then return false end
    if active and active.body ~= body then return false end
    if not live(id, body) then return false end
    if active and bound(active.action) and ISTimedActionQueue.hasAction(active.action) and active.action.action then
        local nativeAction = active.action.action
        active.failureReason = reason or "interrupted"
        active.action:stop()
        nativeAction:forceStop()
    end
    local finished=finish(id, "interrupted", reason or "interrupted")
    return active~=nil or finished
end
function L.reset(reason)
    local pending = {}
    for id in pairs(runtime) do pending[#pending + 1] = id end
    for _, id in ipairs(pending) do
        local active = runtime[id]
        if bound(active.action) and ISTimedActionQueue.hasAction(active.action) and active.action.action then
            local nativeAction = active.action.action
            active.failureReason = reason or "runtime-owner-lost"
            active.action:stop()
            nativeAction:forceStop()
        end
        finish(id, "interrupted", reason or "runtime-owner-lost")
    end
end
function L.compatibility(family)
    local gaps = { yoga = "source-fitnessBonus-mutates-global-exercises",
        painting = "source-perform-requires-player-note-presentation",
        sculpture = "source-perform-requires-player-note-presentation",
        appraisal = "source-result-only-reaches-player-note-presentation",
        music = "source-start-stop-mutate-operator-music-volume",
        dance = "source-start-opens-player-note-and-partner-stop-scans-player-slots" }
    return gaps[family] or "source-family-not-admitted"
end
