-- Week One actors are people in the SAO registry while BanditsWeekOne owns
-- their loaded proxy bodies. A source-stamped brain, exact native body and
-- server retirement receipt are required before SAO can drive a new shell.
SAO = SAO or {}
SAO.WeekOneContinuity = SAO.WeekOneContinuity or {}
local W = SAO.WeekOneContinuity
local OWNER = "BanditsWeekOne"
-- The action table is replaced on a hot Lua reload, but its sound is still
-- playing on the original body. Keep only the exact emissions we started.
local performanceGeneration = {}
W.performanceSoundOwners = type(W.performanceSoundOwners) == "table"
    and W.performanceSoundOwners or {}
local performanceSoundOwners = W.performanceSoundOwners
local legacySourceScan = { records = nil, iterator = nil, state = nil,
    cursor = nil, done = false }
local MAX_ACTIVE_PERFORMANCES = 64
local function stopOwnedPerformanceSound(task)
    local owner = performanceSoundOwners[task]
    if not owner then return false end
    if owner.occurrence and SAOJavaBridge
        and SAOJavaBridge.revokeWeekOnePerformanceOccurrence then
        pcall(function()
            SAOJavaBridge:revokeWeekOnePerformanceOccurrence(
                owner.body, owner.occurrence.pulseId)
        end)
        owner.occurrence = nil
    end
    local ok, silent = pcall(function()
        local emitter = owner.body:getEmitter()
        if owner.soundHandle then
            if emitter:isPlaying(owner.soundHandle) then
                emitter:stopSound(owner.soundHandle)
            end
            return emitter:isPlaying(owner.soundHandle) == false
        end
        -- A hot reload may still hold a source action from the previous
        -- name-only generation. Retire that old emission before new actions.
        if emitter:isPlaying(owner.sound) then emitter:stopSoundByName(owner.sound) end
        return emitter:isPlaying(owner.sound) == false
    end)
    if ok and silent then
        performanceSoundOwners[task] = nil
    else
        owner.revoked = true
        task.saoCancelled = true
    end
    return ok and silent
end
local function queuedOwnedPerformance(task, owner)
    if not (BanditBrain and type(BanditBrain.Get) == "function") then return false end
    local ok, brain, bodyId, alive = pcall(function()
        return BanditBrain.Get(owner.body),
            owner.body:getPersistentOutfitID(), owner.body:isAlive()
    end)
    if not ok or not alive or brain ~= owner.brain
        or type(brain) ~= "table" or brain.id ~= owner.brainId
        or brain.born ~= owner.born or not (brain.saoWeekOneOrigin == OWNER)
        or bodyId ~= owner.brainId then return false end
    local tasks = brain.tasks
    if type(tasks) ~= "table" or #tasks > 12 then return false end
    for index = 1, #tasks do
        if tasks[index] == task then return true end
    end
    return false
end
function W.stopStalePerformanceSounds()
    local visited = 0
    for task, owner in pairs(performanceSoundOwners) do
        visited = visited + 1
        if visited > MAX_ACTIVE_PERFORMANCES then break end
        if owner.generation ~= performanceGeneration or owner.revoked == true
            or not queuedOwnedPerformance(task, owner) then
            task.saoCancelled = true
            stopOwnedPerformanceSound(task)
        end
    end
end
W.stopStalePerformanceSounds()
local actionPhase
local STORE_KEY = "SurvivorAwareness_WeekOneContinuity"
local staged = {}
local ownerReceipts, ownerQueries = {}, {}
local preparedRemovalBodies, physicalRemovalProofs = {}, {}
-- A bounded diagnostic for native-body retention during Week One handoff.
-- It exposes no body or transfer token and does not traverse durable saves.
function W.physicalRemovalProofCount()
    local count = 0
    for _ in pairs(physicalRemovalProofs) do count = count + 1 end
    return count
end
local SCANS_PER_TICK = 4
local POLL_CACHE_VISITS = 12
local POLL_PERSON_VISITS = 128
local PERFORMANCE_HEARING_VISITS = 128
local MAX_SCAN_QUEUE = 4096
local scanQueue, queued = {}, {}
local scanHead, scanTail, queuedCount = 1, 0, 0
local budgetTick, budgetUsed, draining = nil, 0, false
local grantedPerson = nil
local fastSoundObserved = {}
-- A retained inquiry lives with the SAO person. Exact native body references
-- are current-session authority only and are discarded on world rebind.
local sourceInquiryBodies = {}
-- Already admitted work has its own session-only round robin. Changes to the
-- durable discovery table cannot restart a known person's reconciliation.
-- Nodes hold IDs only; the person's saved inquiry and current body still own
-- every attempt. Discovery and settlement each visit at most sixteen IDs.
local sourceInquiryQueue, sourceInquiryHead, sourceInquiryCount = {}, nil, 0
local function trackSourceInquiry(personId)
    if type(personId) ~= "string" or sourceInquiryQueue[personId] then return end
    local node = { previous = personId, next = personId }
    if sourceInquiryHead then
        local head = sourceInquiryQueue[sourceInquiryHead]
        node.previous, node.next = head.previous, sourceInquiryHead
        sourceInquiryQueue[head.previous].next = personId
        head.previous = personId
    else
        sourceInquiryHead = personId
    end
    sourceInquiryQueue[personId] = node
    sourceInquiryCount = sourceInquiryCount + 1
end
local function forgetSourceInquiry(personId)
    local node = sourceInquiryQueue[personId]
    if not node then return end
    if node.next == personId then
        sourceInquiryHead = nil
    else
        sourceInquiryQueue[node.previous].next = node.next
        sourceInquiryQueue[node.next].previous = node.previous
        if sourceInquiryHead == personId then sourceInquiryHead = node.next end
    end
    sourceInquiryQueue[personId] = nil
    sourceInquiryCount = sourceInquiryCount - 1
end
local function sourceInquiryKeys(limit)
    local keys = {}
    for index = 1, math.min(limit, sourceInquiryCount) do
        local personId = sourceInquiryHead
        keys[index] = personId
        sourceInquiryHead = sourceInquiryQueue[personId].next
    end
    return keys
end
function W.rebindWorld()
    ownerReceipts, ownerQueries = {}, {}
    preparedRemovalBodies, physicalRemovalProofs = {}, {}
    legacySourceScan.records, legacySourceScan.iterator = nil, nil
    legacySourceScan.state, legacySourceScan.cursor = nil, nil
    legacySourceScan.done = false
    scanQueue, queued = {}, {}
    scanHead, scanTail, queuedCount = 1, 0, 0
    budgetTick, budgetUsed, draining, grantedPerson = nil, 0, false, nil
    fastSoundObserved = {}
    sourceInquiryBodies = {}
    sourceInquiryQueue, sourceInquiryHead, sourceInquiryCount = {}, nil, 0
end
-- The bridge holds a bounded Java entry iterator. Lua's pairs() snapshots all
-- Kahlua keys, even when only one result is consumed. Keys are resolved again
-- against the current table before any person or body can be touched.
local function pollKeys(source, stream, limit)
    if type(source) ~= "table" or not (SAOJavaBridge
        and type(SAOJavaBridge.weekOnePollEntries) == "function"
        and type(SAOJavaBridge.weekOnePollReset) == "function") then
        return nil end
    local ok, keys = pcall(function()
        return SAOJavaBridge:weekOnePollEntries(source, stream, limit) end)
    if not ok or type(keys) ~= "table" or #keys > limit then return nil end
    -- A captured pass survives Bandits cache replacement. An empty boundary
    -- consumes no raw entry, so immediately open the next pass on this table.
    if #keys == 0 then
        ok, keys = pcall(function()
            return SAOJavaBridge:weekOnePollEntries(source, stream, limit) end)
        if not ok or type(keys) ~= "table" or #keys > limit then return nil end
    end
    if #keys < limit then
        pcall(function() SAOJavaBridge:weekOnePollReset(stream) end)
    end
    return keys
end

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function now()
    local ok, value = pcall(function() return getGameTime():getWorldAgeHours() end)
    return ok and finite(value) and value or nil
end

local function countyHours()
    local ok, value = pcall(function() return SAO.History.countyHours() end)
    return ok and finite(value) and value >= 0 and value <= 1000000000
        and value or nil
end

-- Native calendar fields anchor the saved world's elapsed age. The imported
-- scheduler's fixed-year calculation is retained separately for existing
-- source-timed bodies and comparison while that scheduler is available.
local WEEK_ONE_START_SHIFTS = { 0, 168, 504, 1848, 8760, 87432 }
local WEEK_ONE_MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local function leapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end
local function nativeCalendarDays(year, month, day)
    if not (finite(year) and year % 1 == 0 and year >= 1
        and finite(month) and month % 1 == 0 and month >= 0 and month <= 11
        and finite(day) and day % 1 == 0 and day >= 0) then return nil end
    local monthDays = WEEK_ONE_MONTH_DAYS[month + 1]
        + (month == 1 and leapYear(year) and 1 or 0)
    if day >= monthDays then return nil end
    local priorYear = year - 1
    local days = priorYear * 365 + math.floor(priorYear / 4)
        - math.floor(priorYear / 100) + math.floor(priorYear / 400) + day
    for m = 1, month do days = days + WEEK_ONE_MONTH_DAYS[m] end
    if month > 1 and leapYear(year) then days = days + 1 end
    return days
end
local function sourceCalendarHours(year, month, day, hour)
    if not (finite(year) and year % 1 == 0 and year >= 0
        and finite(month) and month % 1 == 0 and month >= 0 and month <= 11
        and finite(day) and day % 1 == 0 and day >= 0 and day <= 31
        and finite(hour) and hour >= 0 and hour <= 24) then return nil end
    local hours = year * 365 * 24 + (day - 1) * 24 + hour
    for m = 1, month - 1 do
        hours = hours + WEEK_ONE_MONTH_DAYS[m] * 24
    end
    return finite(hours) and hours or nil
end

local function transitionClock(s)
    local ok, world, mode, startHour, startDay, startMonth, startYear,
        hour, day, month, year, currentTime, worldHours = pcall(function()
        local selected, time = getWorld(), getGameTime()
        return selected:getWorld(), selected:getGameMode(),
            time:getStartTimeOfDay(), time:getStartDay(),
            time:getStartMonth(), time:getStartYear(),
            time:getHour(), time:getDay(), time:getMonth(), time:getYear(),
            time:getTimeOfDay(), time:getWorldAgeHours()
    end)
    if not ok or type(world) ~= "string" or world == ""
        or type(mode) ~= "string" or mode == ""
        or not finite(worldHours) or worldHours < 0 then
        return nil, "native-clock-unavailable" end
    local start = sourceCalendarHours(startYear, startMonth, startDay, startHour)
    local current = sourceCalendarHours(year, month, day, hour)
    local startDays = nativeCalendarDays(startYear, startMonth, startDay)
    local currentDays = nativeCalendarDays(year, month, day)
    if not start or not current or not startDays or not currentDays
        or not finite(currentTime) or currentTime < 0 or currentTime >= 24
        or currentTime + 0.000001 < hour
        or currentTime >= hour + 1.000001 then
        return nil, "native-calendar-invalid" end
    local prior = s.weekOneTransitionClock
    if prior ~= nil and (type(prior) ~= "table"
        or prior.schema ~= "sao-week-one-transition-clock/1"
        or prior.world ~= world or prior.mode ~= mode
        or prior.startHour ~= startHour or prior.startDay ~= startDay
        or prior.startMonth ~= startMonth or prior.startYear ~= startYear) then
        return nil, "save-identity-mismatch" end
    local chosen = SandboxVars and SandboxVars.BanditsWeekOne
        and SandboxVars.BanditsWeekOne.StartTime
    if chosen == nil and prior then chosen = prior.startTimeOption end
    if type(chosen) ~= "number" or chosen % 1 ~= 0
        or not WEEK_ONE_START_SHIFTS[chosen] then
        return nil, "start-time-unavailable" end
    if prior and prior.startTimeOption ~= chosen then
        return nil, "start-time-choice-changed" end
    local shift = WEEK_ONE_START_SHIFTS[chosen]
    if prior and (prior.shiftHours ~= shift
        or not finite(prior.atWorldHours) or not finite(prior.ageHours)
        or not finite(prior.legacyAgeHours)
        or prior.legacyDueObservedAtWorldHours ~= nil
            and (not finite(prior.legacyDueObservedAtWorldHours)
                or prior.legacyDueObservedAtWorldHours < 0
                or prior.legacyDueObservedAtWorldHours > prior.atWorldHours)) then
        return nil, "saved-transition-clock-invalid" end
    local legacyAge = current - start - shift
    local age = (currentDays - startDays) * 24
        + currentTime - startHour - shift
    if not finite(age) or not finite(legacyAge) then
        return nil, "native-calendar-invalid" end
    if prior and (worldHours + 0.000001 < prior.atWorldHours
        or age + 0.000001 < prior.ageHours) then
        return nil, "transition-clock-regression" end
    local sourcePresent = BWOScheduler ~= nil
    local sourceAge = type(BWOScheduler) == "table"
        and tonumber(BWOScheduler.WorldAge) or nil
    if sourcePresent and (not finite(sourceAge)
        or math.abs(sourceAge - legacyAge) > 0.000001) then
        return nil, "source-age-mismatch" end
    local fact = prior or { schema = "sao-week-one-transition-clock/1",
        world = world, mode = mode, startHour = startHour,
        startDay = startDay, startMonth = startMonth, startYear = startYear,
        startTimeOption = chosen, shiftHours = shift }
    fact.atWorldHours, fact.ageHours = worldHours, age
    fact.legacyAgeHours = legacyAge
    fact.sourceCompared = sourceAge ~= nil
    if legacyAge >= 170 and fact.legacyDueObservedAtWorldHours == nil then
        fact.legacyDueObservedAtWorldHours = worldHours
    end
    s.weekOneTransitionClock = fact
    return fact
end

-- Representation is a world choice, while this person's identity and
-- relations are always SAO-owned. An existing record without a mode predates
-- this choice and keeps its saved source handoff timing.
local function selectedBodyMode()
    local selected = SandboxVars and SandboxVars.SurvivorAwareness
        and tonumber(SandboxVars.SurvivorAwareness.WeekOneBodyMode) or 1
    return selected == 2 and "lightweight" or "native"
end

local function store()
    if not ModData or not ModData.getOrCreate then return nil end
    local ok, value = pcall(ModData.getOrCreate, STORE_KEY)
    if not ok or type(value) ~= "table" then return nil end
    value.byBrain = value.byBrain or {}
    value.inactiveBySource = value.inactiveBySource or {}
    value.retiredBySource = value.retiredBySource or {}
    value.pendingPerformanceByPerson = value.pendingPerformanceByPerson or {}
    value.pendingSourceInquiryByPerson = value.pendingSourceInquiryByPerson or {}
    value.nextPerson = value.nextPerson or 1
    value.nextTransfer = value.nextTransfer or 1
    value.nextScanOrdinal = value.nextScanOrdinal or 1
    value.metrics = value.metrics or {}
    for _, key in ipairs({ "scans", "throttled", "scanMillis", "peakScanMillis",
        "budgetDeferred", "failures", "moves", "fallbacks", "scanQueuePeak",
        "scanQueueDropped", "rowsPruned", "activeRefusals" }) do
        if not finite(value.metrics[key]) or value.metrics[key] < 0 then value.metrics[key] = 0 end
    end
    return value
end

function W.weekOneTransitionAge()
    local s = store()
    if not s then return nil, "store-unavailable" end
    local fact, reason = transitionClock(s)
    s.lastTransitionClockRefusal = reason
    return fact and fact.ageHours or nil, reason
end

local function sourceKey(brain)
    if type(brain) ~= "table" or brain.saoWeekOneOrigin ~= OWNER
        or not finite(brain.id) or brain.id % 1 ~= 0
        or not finite(brain.born) then return nil end
    return tostring(brain.id), tostring(brain.born)
end

local function currentBody(brain, body)
    if not body then return false end
    local ok, id, alive = pcall(function()
        return body:getPersistentOutfitID(), body:isAlive()
    end)
    return ok and alive == true and id == brain.id
end

local function markedWeekOneActor(brain, body)
    if type(brain) == "table" and brain.saoWeekOneOrigin == OWNER then
        return true end
    if not body then return false end
    local ok, md = pcall(function() return body:getModData() end)
    return ok and type(md) == "table" and md.SAOWeekOneOrigin == OWNER
end

local function nameParts(brain)
    local full = type(brain.fullname) == "string" and brain.fullname or ""
    local first, last = full:match("^%s*(%S+)%s+(.+)%s*$")
    if not first then first = full:match("^%s*(%S+)%s*$") end
    return first or "Unnamed", last or ""
end

-- The installed source presets do not authorize explosive equipment. Older
-- saved shahidKit receipts remain historical person data; no new item is
-- minted from a source program name.

-- A source spawn can precede OnCreatePlayer. Bind its provenance to the
-- selected character after the native creation receipt exists. This is an
-- arrival in the world, not a biological birth or a relationship.
local function ownerReceiptFor(spawn)
    local ref = type(spawn) == "table" and spawn.eventRef
    if type(ref) ~= "string" or #ref ~= 32
        or ref:match("^[0-9a-f]+$") == nil then return nil end
    local found = ownerReceipts[ref]
    if found then return found end
    local hours = now()
    if not hours or not sendClientCommand then return nil end
    local last = ownerQueries[ref]
    if last and hours >= last and hours - last < 0.25 then return nil end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return nil end
    local ok = pcall(sendClientCommand, player, "SAOWeekOne",
        "QueryOwnerReceipt", {source = spawn.source,
            brainId = spawn.brainId, born = spawn.born,
            eventRef = spawn.eventRef})
    if ok then ownerQueries[ref] = hours end
    return ownerReceipts[ref]
end

local function selectedSourcePlayer(spawn)
    if type(spawn) ~= "table" or not (SAO.Standing
        and SAO.Standing.playerKey and SAO.Standing.playerAccountKey) then return nil end
    local owner = ownerReceiptFor(spawn)
    if not owner or owner.source ~= spawn.source
        or owner.brainId ~= spawn.brainId or owner.born ~= spawn.born
        or owner.eventRef ~= spawn.eventRef then return nil end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return nil end
    local ok, receipt, accountKey, playerKey, descriptorId,
        forename, surname, world, mode = pcall(function()
        if player:isDead() then return nil end
        local md = player:getModData()
        local descriptor = player:getDescriptor()
        local selected = getWorld()
        return md and md.SAOCreationReceipt,
            SAO.Standing.playerAccountKey(player),
            SAO.Standing.playerKey(player), descriptor:getID(),
            descriptor:getForename(), descriptor:getSurname(),
            selected:getWorld(), selected:getGameMode()
    end)
    if not ok or type(receipt) ~= "table"
        or receipt.schema ~= "sao-created-player/1"
        or receipt.newWorld ~= true
        or type(playerKey) ~= "string" or playerKey == ""
        or receipt.playerKey ~= playerKey
        or owner.accountKey ~= accountKey
        or owner.nativeDescriptorId ~= descriptorId
        or owner.forename ~= forename or owner.surname ~= surname
        or owner.world ~= world or owner.gameMode ~= mode
        or owner.playerKey ~= accountKey and owner.playerKey ~= playerKey then return nil end
    return { receipt = receipt, accountKey = accountKey,
        playerKey = playerKey, nativeDescriptorId = descriptorId,
        world = world, gameMode = mode }
end

local function scrubPublicSourceOwner(rec)
    local spawn = rec and rec.weekOne and rec.weekOne.sourceSpawn
    if type(spawn) ~= "table" then return false end
    local changed = false
    for _, field in ipairs({ "accountKey", "playerKey", "nativeDescriptorId",
        "forename", "surname", "world", "gameMode" }) do
        if spawn[field] ~= nil then
            spawn[field] = nil
            changed = true
        end
    end
    return changed
end

-- Older saved starts copied private owner fields into Identity GlobalModData.
-- Snapshot the Kahlua key iterator once per loaded world, then migrate a
-- bounded number of records per poll. The server's save-local owner sidecar
-- and the opaque event reference remain available for a later query.
function W.scrubLegacySourceOwners()
    if not (SAO.Identity and SAO.Identity.all) then return 0 end
    local records = SAO.Identity.all()
    if type(records) ~= "table" then return 0 end
    if legacySourceScan.records ~= records then
        legacySourceScan.records = records
        legacySourceScan.iterator, legacySourceScan.state,
            legacySourceScan.cursor = pairs(records)
        legacySourceScan.done = false
    end
    if legacySourceScan.done then return 0 end
    local changed = 0
    for _ = 1, 128 do
        local ok, key, rec = pcall(legacySourceScan.iterator,
            legacySourceScan.state, legacySourceScan.cursor)
        if not ok then
            legacySourceScan.iterator = nil
            legacySourceScan.done = true
            return changed
        end
        if key == nil then
            legacySourceScan.iterator = nil
            legacySourceScan.done = true
            break
        end
        legacySourceScan.cursor = key
        if scrubPublicSourceOwner(rec) then changed = changed + 1 end
    end
    return changed
end

-- A source-selected start has no lasting owner keys on the public person.
-- Recheck the current character against the private server reply when the
-- operator or a later consumer needs its provenance, even after retirement.
function W.selectedStartProvenance(personId)
    if type(personId) ~= "string" or not (SAO.Identity and SAO.Identity.get)
        then return nil, "person-unavailable" end
    local rec = SAO.Identity.get(personId)
    local phase = rec and rec.weekOne
    local spawn = phase and phase.sourceSpawn
    scrubPublicSourceOwner(rec)
    if not phase or phase.source ~= OWNER or type(spawn) ~= "table"
        or spawn.source ~= "BWOEvents.Start/StartBabe"
        or spawn.brainId ~= phase.brainId or spawn.born ~= phase.born
        or type(spawn.eventRef) ~= "string" or #spawn.eventRef ~= 32
        or spawn.eventRef:match("^[0-9a-f]+$") == nil then
        return nil, "source-start-unavailable" end
    local selected = selectedSourcePlayer(spawn)
    if not selected then return nil, "owner-receipt-pending" end
    if selected.receipt.weekOneStartBabe ~= true then
        return nil, "creator-choice-mismatch" end
    return { schema = "sao.weekone-selected-start-provenance/1",
        personId = personId, source = spawn.source,
        eventRef = spawn.eventRef, brainId = phase.brainId,
        born = phase.born, playerKey = selected.playerKey,
        nativeDescriptorId = selected.nativeDescriptorId,
        world = selected.world, gameMode = selected.gameMode }
end

-- The selected scenario's public person event carries only an opaque reference.
-- Its full owner remains in the server's save-local sidecar. Resolve it for the
-- current character on demand, including after the source brain has retired;
-- never copy account or character keys into the public SAO person record.
function W.selectedScenarioProvenance(personId)
    if type(personId) ~= "string" or not (SAO.Identity and SAO.Identity.get
        and SAO.Standing and SAO.Standing.playerKey
        and SAO.Standing.playerAccountKey) then return nil, "person-unavailable" end
    local rec = SAO.Identity.get(personId)
    local phase = rec and rec.weekOne
    local event = phase and phase.sourceEvent
    if not phase or phase.source ~= OWNER or type(event) ~= "table"
        or event.kind ~= "scenario-arrival"
        or event.source ~= "VBandit.setup/SpawnGroupArea"
        or event.brainId ~= phase.brainId or event.born ~= phase.born
        or type(event.eventRef) ~= "string" or #event.eventRef ~= 32
        or event.eventRef:match("^[0-9a-f]+$") == nil
        or event.variant ~= "Bandits" or not finite(event.variantId)
        or not finite(event.ordinal) or event.ordinal < 1
        or event.ordinal > 24 or event.ordinal % 1 ~= 0
        or event.count ~= 24 then return nil, "scenario-event-unavailable" end
    local owner = ownerReceiptFor(event)
    if not owner then return nil, "owner-receipt-pending" end
    if owner.source ~= event.source or owner.eventRef ~= event.eventRef
        or owner.brainId ~= phase.brainId or owner.born ~= phase.born then
        return nil, "owner-receipt-mismatch" end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return nil, "selected-player-unavailable" end
    local ok, receipt, accountKey, playerKey, descriptorId,
        forename, surname, world, mode = pcall(function()
        if player:isDead() then return nil end
        local md = player:getModData()
        local descriptor = player:getDescriptor()
        local selected = getWorld()
        return md and md.SAOCreationReceipt,
            SAO.Standing.playerAccountKey(player),
            SAO.Standing.playerKey(player), descriptor:getID(),
            descriptor:getForename(), descriptor:getSurname(),
            selected:getWorld(), selected:getGameMode()
    end)
    if not ok or type(accountKey) ~= "string" or accountKey == ""
        or type(playerKey) ~= "string" or playerKey == ""
        or owner.accountKey ~= accountKey
        or owner.nativeDescriptorId ~= descriptorId
        or owner.forename ~= forename or owner.surname ~= surname
        or owner.world ~= world or owner.gameMode ~= mode then
        return nil, "selected-character-mismatch" end
    if receipt ~= nil then
        if type(receipt) ~= "table"
            or receipt.schema ~= "sao-created-player/1"
            or receipt.newWorld ~= true
            or receipt.weekOneVariant ~= event.variantId
            or receipt.playerKey ~= playerKey
            or receipt.nativeDescriptorId ~= descriptorId
            or receipt.world ~= world or receipt.gameMode ~= mode
            or owner.playerKey ~= playerKey
                and owner.playerKey ~= accountKey then
            return nil, "creator-choice-mismatch" end
    elseif owner.playerKey ~= accountKey or playerKey ~= accountKey then
        return nil, "native-character-mismatch" end
    return {schema = "sao.weekone-selected-scenario-provenance/1",
        personId = personId, source = event.source,
        eventRef = event.eventRef, brainId = phase.brainId,
        born = phase.born, variant = event.variant,
        variantId = event.variantId, ordinal = event.ordinal,
        nativeDescriptorId = descriptorId, playerKey = playerKey}
end

-- The imported StartBabe setting is only an optional source encounter. Its
-- unfortunate source names remain at this compatibility border; SAO does not
-- turn them into age, kinship, companionship, group membership or trust.
local function admitSelectedSourceSpawn(brain, rec)
    local spawn = type(brain) == "table" and (brain.saoWeekOneStartEntry
        or brain.saoWeekOneBabeBirth)
    if type(spawn) ~= "table" or spawn.source ~= "BWOEvents.Start/StartBabe"
        or brain.saoWeekOneStartEntry and spawn.selected ~= true
        or spawn.brainId ~= nil and spawn.brainId ~= brain.id
        or spawn.born ~= nil and spawn.born ~= brain.born
        or rec.weekOne.sourceSpawn or rec.weekOne.babeBirth then return end
    local selected = selectedSourcePlayer(spawn)
    if not selected or selected.receipt.weekOneStartBabe ~= true then return end
    rec.weekOne.sourceSpawn = {
        source = spawn.source,
        eventRef = spawn.eventRef,
        sourceProgram = spawn.sourceProgram or "Babe",
        program = spawn.program or (brain.program and brain.program.name),
        brainId = brain.id, born = brain.born,
        arrivedAtHours = now(),
    }
end

-- A fresh creator-selected start has a private server owner receipt in
-- flight. Keep its exact source body until that receipt has been checked
-- against the current character; a public source marker alone grants no tie.
-- Older saved-sandbox starts have no creator receipt and retain their source
-- retirement path as independent people.
local function selectedOwnerReceiptPending(brain, rec)
    local spawn = type(brain) == "table" and brain.saoWeekOneStartEntry
    local ref = type(spawn) == "table" and spawn.eventRef
    return type(spawn) == "table" and brain.saoWeekOneOrigin == OWNER
        and spawn.source == "BWOEvents.Start/StartBabe"
        and spawn.selected == true
        and spawn.selectionSource == "creator-receipt"
        and spawn.brainId == brain.id and spawn.born == brain.born
        and type(ref) == "string" and #ref == 32
        and ref:match("^[0-9a-f]+$") ~= nil
        and rec and rec.weekOne and rec.weekOne.sourceSpawn == nil
end

local function archiveRow(s, id, row, settled)
    local key = id .. "@" .. row.born
    if settled then
        s.retiredBySource[key] = { personId = row.personId, born = row.born,
            status = row.status, source = OWNER }
    else
        s.inactiveBySource[key] = row
    end
    s.byBrain[id] = nil
    s.metrics.rowsPruned = s.metrics.rowsPruned + 1
    -- The removed native body is retained only while its exact proof can
    -- still complete or release a source claim. Clear it after a settled row
    -- has actually left the active crosswalk and its person is no longer
    -- source-owned; an unsettled or pending row keeps its witness.
    if settled and (row.status == "transferred" or row.status == "dead") then
        local rec = SAO.Identity and SAO.Identity.get(row.personId)
        if rec and rec.id == row.personId and rec.weekOne
            and not rec.weekOne.pending
            and (row.status == "transferred"
                and rec.weekOne.status == "transferred"
                or row.status == "dead" and rec.dead == true)
            and SAO.Claims and SAO.Claims.heldBy
            and SAO.Claims.heldBy(rec) ~= OWNER then
            preparedRemovalBodies[rec.id] = nil
            physicalRemovalProofs[rec.id] = nil
        end
    end
end

local function rowFor(brain)
    local id, born = sourceKey(brain)
    if not id then return nil, "source-not-stamped" end
    local s = store()
    if not s then return nil, "store-unavailable" end
    local key = id .. "@" .. born
    if s.retiredBySource[key] then return nil, "source-already-settled" end
    local row = s.byBrain[id]
    if row and row.born ~= born then
        local old = SAO.Identity and SAO.Identity.get(row.personId)
        if old and old.weekOne and (old.weekOne.pending or old.weekOne.stageToken
            or old.weekOne.status == "dormant"
            or old.weekOne.status == "retirement-pending") then
            return nil, "brain-id-reused"
        end
        archiveRow(s, id, row, row.status == "transferred" or row.status == "dead"
            or old and (old.dead == true or old.weekOne
                and old.weekOne.status == "transferred"))
        row = nil
    end
    if not row and s.inactiveBySource[key] then
        row = s.inactiveBySource[key]
        s.inactiveBySource[key] = nil
        s.byBrain[id] = row
    end
    if row then return row end
    if not (SAO.Identity and SAO.Identity.ensure and SAO.Claims) then
        return nil, "identity-unavailable"
    end
    local personId = "bwo-" .. tostring(s.nextPerson)
    if SAO.Identity.get(personId) then return nil, "person-id-collision" end
    row = { personId = personId, brainId = brain.id, born = born,
        source = OWNER, status = "external",
        retirementProtocolEra = "ticketed-v1" }
    s.byBrain[id] = row
    s.nextPerson = s.nextPerson + 1
    return row
end

function W.observeBrain(brain, body)
    if not currentBody(brain, body) then return nil, "body-mismatch" end
    local row, reason = rowFor(brain)
    if not row then return nil, reason end
    local rec = SAO.Identity.get(row.personId)
    if row.status == "transferred" or row.status == "dead" or rec and rec.dead then
        return nil, "source-already-settled"
    end
    if rec and SAO.Claims.heldBy(rec) ~= OWNER then
        return nil, "other-body-owner"
    end
    if SAO.Body and SAO.Body.hasRepresentation
        and SAO.Body.hasRepresentation(row.personId) then
        return nil, "already-represented"
    end
    local okMarker, marker = pcall(function()
        local md = body:getModData()
        return md and not (md.SAOWeekOnePersonId and md.SAOWeekOnePersonId ~= row.personId
            or md.SAOWeekOneBrainId and md.SAOWeekOneBrainId ~= brain.id
            or md.SAOWeekOneBorn and md.SAOWeekOneBorn ~= brain.born
            or md.SAOWeekOneOrigin and md.SAOWeekOneOrigin ~= OWNER)
    end)
    if not okMarker or not marker then return nil, "body-marker-conflict" end
    local ok, x, y, z = pcall(function() return body:getX(), body:getY(), body:getZ() end)
    if not ok or not (finite(x) and finite(y) and finite(z)) then
        return nil, "position-unavailable"
    end
    local newlyAdmitted = rec == nil
    if newlyAdmitted then
        if not (SAO.Identity and type(SAO.Identity.remove) == "function") then
            return nil, "identity-rollback-unavailable"
        end
        local first, last = nameParts(brain)
        rec = SAO.Identity.ensure(row.personId, first, last, x, y, z)
        if not rec then return nil, "identity-admission-failed" end
        rec.female = brain.female == true
        rec.weekOne = { source = OWNER, brainId = brain.id, born = brain.born,
            firstSeenHours = now(), status = "external",
            bodyMode = selectedBodyMode() }
        if SAO.Claims.claim(rec, OWNER) ~= true then
            SAO.Identity.remove(rec.id)
            return nil, "source-claim-failed"
        end
    end
    if not rec.weekOne or rec.weekOne.brainId ~= brain.id
        or tostring(rec.weekOne.born) ~= row.born then
        return nil, "crosswalk-conflict"
    end
    scrubPublicSourceOwner(rec)
    if rec.weekOne.bodyMode == nil then
        rec.weekOne.bodyMode = "legacy-source"
    elseif rec.weekOne.bodyMode ~= "native"
        and rec.weekOne.bodyMode ~= "lightweight"
        and rec.weekOne.bodyMode ~= "legacy-source" then
        return nil, "representation-mode-invalid"
    end
    if not (SAO.History and type(SAO.History.admitExternalAdult) == "function") then
        return nil, "chronology-unavailable"
    end
    local okAge, admitted, ageReason = pcall(SAO.History.admitExternalAdult,
        rec, {source = OWNER, sourceKey = tostring(brain.id) .. "@" .. row.born,
            nativeDefaultScaleBody = true})
    if not okAge or admitted ~= true then
        if newlyAdmitted then
            SAO.Claims.release(rec)
            SAO.Identity.remove(rec.id)
        end
        return nil, okAge and tostring(ageReason) or "chronology-error"
    end
    -- This is an observation marker, not SAO body ownership. The proxy stays
    -- under BanditsWeekOne control until the retirement ticket is acknowledged.
    local okMark, marked = pcall(function()
        local md = body:getModData()
        if not md or md.SAOWeekOnePersonId and md.SAOWeekOnePersonId ~= rec.id
            or md.SAOWeekOneBrainId and md.SAOWeekOneBrainId ~= brain.id
            or md.SAOWeekOneBorn and md.SAOWeekOneBorn ~= brain.born
            or md.SAOWeekOneOrigin and md.SAOWeekOneOrigin ~= OWNER then return false end
        md.SAOWeekOneOrigin = OWNER
        md.SAOWeekOnePersonId = rec.id
        md.SAOWeekOneBrainId = brain.id
        md.SAOWeekOneBorn = brain.born
        md.SAOWeekOneName = (brain.fullname and brain.fullname ~= "")
            and brain.fullname or rec.id
        return true
    end)
    if not okMark or not marked then return nil, "body-marker-conflict" end
-- Public source-event facts and opaque private-owner crosswalk survive
-- the temporary source brain on SAO's person record. The raw cohort and
-- selected-character identity remain in the server save sidecar.
    local reinforcement = brain.saoWeekOneReinforcement
    if type(reinforcement) == "table"
        and reinforcement.source == "VBandit.schedule/SpawnGroup"
        and type(reinforcement.eventRef) == "string"
        and #reinforcement.eventRef == 32
        and reinforcement.eventRef:match("^[0-9a-f]+$")
        and reinforcement.brainId == brain.id
        and reinforcement.born == brain.born
        and finite(reinforcement.age) and finite(reinforcement.minute)
        and finite(reinforcement.variantId) and finite(reinforcement.count)
        and reinforcement.count >= 1
        and not rec.weekOne.sourceEvent then
        rec.weekOne.sourceEvent = {
            kind = "reinforcement", source = reinforcement.source,
            eventRef = reinforcement.eventRef, age = reinforcement.age,
            minute = reinforcement.minute, variantId = reinforcement.variantId,
            count = reinforcement.count, brainId = brain.id,
            born = brain.born }
    end
    local scenario = brain.saoWeekOneScenarioBirth
    if type(scenario) == "table"
        and scenario.source == "VBandit.setup/SpawnGroupArea"
        and type(scenario.eventRef) == "string"
        and #scenario.eventRef == 32
        and scenario.eventRef:match("^[0-9a-f]+$")
        and scenario.brainId == brain.id and scenario.born == brain.born
        and finite(scenario.ordinal) and scenario.ordinal >= 1
        and scenario.ordinal <= 24 and scenario.ordinal % 1 == 0
        and scenario.count == 24 and scenario.variant == "Bandits"
        and finite(scenario.variantId) and not rec.weekOne.sourceEvent then
        rec.weekOne.sourceEvent = {
            kind = "scenario-arrival", source = scenario.source,
            eventRef = scenario.eventRef, variant = scenario.variant,
            variantId = scenario.variantId, ordinal = scenario.ordinal,
            count = scenario.count, brainId = brain.id, born = brain.born,
            arrivedAtHours = now(),
        }
    end
    admitSelectedSourceSpawn(brain, rec)
    if rec.weekOne.sourceFallbackSeen ~= true then
        rec.weekOne.sourceFallbackSeen = true
        rec.weekOne.sourceFallbackProgram = type(brain.programFallback) == "string"
            and brain.programFallback or false
    end
    if not rec.weekOne.pending then
        SAO.Identity.updatePosition(rec, x, y, z)
        rec.weekOne.lastSeenHours = now()
        rec.weekOne.program = brain.program and brain.program.name or nil
    end
    if type(W.reconcilePerformanceOutcomes) == "function" then
        W.reconcilePerformanceOutcomes(row.personId)
    end
    -- A restored person's exact observed body supplies bounded scheduling
    -- admission when native pending-key discovery is unavailable. Inquiry
    -- execution still requires its own current runtime/body authority.
    if type(rec.weekOne.sourceInquiry) == "table" then
        local inquiryStore = store()
        if inquiryStore and type(inquiryStore.pendingSourceInquiryByPerson) == "table" then
            inquiryStore.pendingSourceInquiryByPerson[row.personId] = true
            trackSourceInquiry(row.personId)
        end
    end
    return row.personId
end

-- The mod patch asks this before a bounded safe source-body retirement.
-- It may admit a newly observed person, but never treats the source body ID
-- as their identity or changes a choice already written to that person's
-- record. Existing saves with no mode stay on their earlier timing.
function W.nativeBodyPreferred(brain, body)
    local personId = W.observeBrain(brain, body)
    if not personId then return false end
    local rec = SAO.Identity and SAO.Identity.get(personId)
    local phase = rec and rec.weekOne
    return phase and phase.bodyMode == "native"
        and phase.status == "external" and phase.pending == nil
        and phase.stageToken == nil
        and SAO.Claims.heldBy(rec) == OWNER or false
end

-- Read-only reservation for a source despawn pass delayed by the server
-- handshake. The exact live body and durable pending person keep their place
-- in the source quota without preparing a second transfer.
function W.retirementPending(brain, body)
    local id, born = sourceKey(brain)
    if not id or not currentBody(brain, body)
        or not (ModData and ModData.get and SAO.Identity
            and SAO.Identity.get and SAO.Claims and SAO.Claims.heldBy)
        then return false end
    local okStore, s = pcall(ModData.get, STORE_KEY)
    local row = okStore and type(s) == "table" and type(s.byBrain) == "table"
        and s.byBrain[id]
    if type(row) ~= "table" or row.source ~= OWNER
        or row.brainId ~= brain.id or row.born ~= born
        or row.status ~= "external" then return false end
    local rec = SAO.Identity.get(row.personId)
    local phase = rec and rec.weekOne
    local p = phase and phase.pending
    if not p or rec.dead or phase.source ~= OWNER
        or phase.status ~= "retirement-pending"
        or phase.brainId ~= brain.id or tostring(phase.born) ~= born
        or p.personId ~= rec.id or p.brainId ~= brain.id
        or p.born ~= brain.born or type(p.token) ~= "string"
        or SAO.Claims.heldBy(rec) ~= OWNER then return false end
    local okBody, md = pcall(function() return body:getModData() end)
    return okBody and type(md) == "table"
        and md.SAOWeekOneOrigin == OWNER
        and md.SAOWeekOnePersonId == rec.id
        and md.SAOWeekOneBrainId == brain.id
        and md.SAOWeekOneBorn == brain.born or false
end

-- Resolve a loaded source proxy for shared person-facing observation. This is
-- a read of an existing crosswalk; it never admits, claims or transfers one.
function W.sourceBodyFor(personId)
    if type(personId) ~= "string" or not (SAO.Identity and SAO.Identity.get
        and SAO.Claims and SAO.Claims.heldBy and ModData and ModData.get
        and BanditZombie and type(BanditZombie.GetInstanceById) == "function"
        and BanditBrain and type(BanditBrain.Get) == "function") then return nil end
    local rec = SAO.Identity.get(personId)
    local phase = rec and rec.weekOne
    if not phase or rec.dead or phase.source ~= OWNER
        or phase.status ~= "external" or phase.pending or phase.stageToken
        or not finite(phase.brainId) or not finite(phase.born)
        or SAO.Claims.heldBy(rec) ~= OWNER
        or SAO.Body and SAO.Body.hasRepresentation
            and SAO.Body.hasRepresentation(personId) then return nil end
    local okStore, s = pcall(ModData.get, STORE_KEY)
    local row = okStore and type(s) == "table" and type(s.byBrain) == "table"
        and s.byBrain[tostring(phase.brainId)]
    if type(row) ~= "table" or row.personId ~= personId
        or row.brainId ~= phase.brainId or row.born ~= tostring(phase.born)
        or row.source ~= OWNER or row.status ~= "external" then return nil end
    local ok, body, brain = pcall(function()
        local found = BanditZombie.GetInstanceById(phase.brainId)
        return found, found and BanditBrain.Get(found)
    end)
    if not ok or type(brain) ~= "table"
        or brain.saoWeekOneOrigin ~= OWNER or brain.id ~= phase.brainId
        or brain.born ~= phase.born or not currentBody(brain, body) then
        return nil end
    local marked, exact = pcall(function()
        local md = body:getModData()
        return md and md.SAOWeekOneOrigin == OWNER
            and md.SAOWeekOnePersonId == personId
            and md.SAOWeekOneBrainId == brain.id
            and md.SAOWeekOneBorn == brain.born
    end)
    if not marked or not exact then return nil end
    return body, brain
end

-- The common nearby surface can include exact source proxies without
-- admitting them into SAO body ownership. Inspect every loaded candidate so
-- a cache traversal order cannot hide a nearer person behind the output cap.
function W.loadedPersonIdsNear(player, reach, limit)
    local ids = {}
    if not (player and getSpecificPlayer and getSpecificPlayer(0) == player
        and BanditZombie and type(BanditZombie.CacheLightB) == "table"
        and type(BanditZombie.GetInstanceById) == "function"
        and finite(reach) and reach >= 0 and finite(limit)
        and limit >= 0 and limit % 1 == 0) then return ids, 0 end
    limit = math.min(limit, 128)
    local placed, px, py, pz = pcall(function()
        if player:isDead() then return nil end
        return player:getX(), player:getY(), player:getZ()
    end)
    if not placed or not (finite(px) and finite(py) and finite(pz)) then
        return ids, 0 end
    local found, seen = {}, {}
    for _, light in pairs(BanditZombie.CacheLightB) do
        local source = light and light.brain
        if source and source.saoWeekOneOrigin == OWNER and finite(source.id) then
            local ok, body, x, y, z, personId = pcall(function()
                local current = BanditZombie.GetInstanceById(source.id)
                if not current then return nil end
                local md = current:getModData()
                return current, current:getX(), current:getY(),
                    current:getZ(), md and md.SAOWeekOnePersonId
            end)
            if ok and body and finite(x) and finite(y) and finite(z)
                and math.floor(z) == math.floor(pz)
                and type(personId) == "string" and not seen[personId] then
                local dx, dy = x - px, y - py
                local dist2 = dx * dx + dy * dy
                if dist2 <= reach * reach then
                    local exact, brain = W.sourceBodyFor(personId)
                    if exact == body and brain == source then
                        seen[personId] = true
                        found[#found + 1] = { id = personId, dist2 = dist2 }
                    end
                end
            end
        end
    end
    SAO.Ordering.sort(found, function(a, b)
        if a.dist2 ~= b.dist2 then return a.dist2 < b.dist2 end
        return a.id < b.id
    end)
    for index = 1, math.min(limit, #found) do ids[index] = found[index].id end
    return ids, #found - #ids
end

local function reserveScan(s, rec, brain, body, tick)
    if budgetTick and tick < budgetTick then return false, "scan-clock-rollback" end
    if budgetTick ~= tick then budgetTick, budgetUsed = tick, 0 end
    if (grantedPerson == rec.id or queuedCount == 0)
        and budgetUsed < SCANS_PER_TICK then
        budgetUsed = budgetUsed + 1
        rec.weekOne.scanGrantedAtTick = tick
        rec.weekOne.scanOrdinal = s.nextScanOrdinal
        s.nextScanOrdinal = s.nextScanOrdinal + 1
        return true
    end
    if not queued[rec.id] then
        if queuedCount >= MAX_SCAN_QUEUE then
            s.metrics.scanQueueDropped = s.metrics.scanQueueDropped + 1
            return false, "scan-queue-full"
        end
        scanTail = scanTail + 1
        scanQueue[scanTail] = { personId = rec.id, brain = brain,
            body = body, requestedAtTick = tick }
        queuedCount = queuedCount + 1
        queued[rec.id] = true
        rec.weekOne.scanRequestedAtTick = tick
        s.metrics.budgetDeferred = s.metrics.budgetDeferred + 1
        s.metrics.scanQueuePeak = math.max(s.metrics.scanQueuePeak, queuedCount)
    end
    return false, "scan-budget-deferred"
end

-- A deferred actor gets a fresh exact-body check before its turn. The queue is
-- runtime-only; durable people and scan provenance live in Identity/ModData.
function W.onBudgetTick()
    if not (SAO.History and SAO.History.ticks) then return end
    local ok, tick = pcall(SAO.History.ticks)
    if not ok or not finite(tick) or tick < 0
        or budgetTick and tick < budgetTick then return end
    if budgetTick ~= tick then
        budgetTick, budgetUsed = tick, 0
        fastSoundObserved = {}
    end
    if queuedCount == 0 or draining then return end
    draining = true
    local attempted = 0
    while queuedCount > 0 and budgetUsed < SCANS_PER_TICK
        and attempted < SCANS_PER_TICK * 4 do
        attempted = attempted + 1
        local request = scanQueue[scanHead]
        scanQueue[scanHead] = nil
        scanHead = scanHead + 1
        queuedCount = queuedCount - 1
        if queuedCount == 0 then scanHead, scanTail = 1, 0 end
        queued[request.personId] = nil
        local body
        local okBody = pcall(function()
            body = BanditZombie and BanditZombie.GetInstanceById
                and BanditZombie.GetInstanceById(request.brain.id)
        end)
        if okBody and body == request.body and currentBody(request.brain, body) then
            grantedPerson = request.personId
            W.assessForBandit(request.brain, body)
            grantedPerson = nil
        end
    end
    grantedPerson, draining = nil, false
end

-- BWO remains the sole actuator. This private frame reads only this person's
-- acquired beliefs, standing and disposition, and survives a save/load in the
-- SAO person record. BWO's exact stamped program hook may consume the frame.
local function sampleSourceAudible(personId, brain, body, tick)
    local sampled = fastSoundObserved[personId]
    if (not sampled or sampled.tick ~= tick or sampled.body ~= body
        or sampled.brainId ~= brain.id or sampled.born ~= brain.born)
        and SAO.Perception and SAO.Perception.observeAudible then
        local okSound = pcall(SAO.Perception.observeAudible,
            personId, body, tick, false)
        if okSound then
            fastSoundObserved[personId] = { tick = tick, body = body,
                brainId = brain.id, born = brain.born }
        end
    end
end

function W.assessForBandit(brain, body)
    local sourceId, born = sourceKey(brain)
    if not sourceId or not currentBody(brain, body) then return nil, "source-or-body-mismatch" end
    local s = store()
    local row = s and s.byBrain[sourceId]
    local known = row and row.born == born and SAO.Identity
        and SAO.Identity.get(row.personId)
    local tick
    if SAO.History and SAO.History.ticks then
        local okTick, result = pcall(SAO.History.ticks)
        if okTick and finite(result) and result >= 0 then tick = result end
    end
    if known and tick and not known.dead and known.weekOne
        and not known.weekOne.pending and known.weekOne.status == "external"
        and known.weekOne.appraisal
        and known.weekOne.lastCognitionTick and tick >= known.weekOne.lastCognitionTick
        and tick - known.weekOne.lastCognitionTick < 20
        and SAO.Claims and SAO.Claims.heldBy(known) == OWNER then
        local okMarker, marker = pcall(function()
            local md = body:getModData()
            return md.SAOWeekOneOrigin == OWNER and md.SAOWeekOnePersonId == known.id
                and md.SAOWeekOneBrainId == brain.id and md.SAOWeekOneBorn == brain.born
        end)
        if okMarker and marker then
            -- The source program may revisit the same person many times in
            -- one tick. Keep native sound acquisition current without doing
            -- the full sight/cognition scan or rescanning this exact body in
            -- the same tick. A new body/generation gets its own acquisition.
            sampleSourceAudible(known.id, brain, body, tick)
            s.metrics.throttled = s.metrics.throttled + 1
            return known.weekOne.appraisal
        end
    end
    local personId, reason = W.observeBrain(brain, body)
    if not personId then return nil, reason end
    local rec = SAO.Identity.get(personId)
    if not rec or not rec.weekOne or rec.weekOne.pending
        or SAO.Claims.heldBy(rec) ~= OWNER then return nil, "owner-changed" end
    if not (SAO.History and SAO.History.ticks and SAO.Perception
        and SAO.Perception.observe and SAO.Disposition
        and SAO.Disposition.conflictValues and SAO.Standing) then
        return nil, "private-cognition-unavailable"
    end
    if not (SAOJavaBridge and SAOJavaBridge.perceive) then
        return nil, "native-perception-unavailable"
    end
    if not tick then return nil, "clock-unavailable" end
    local prior = rec.weekOne.lastCognitionTick
    if prior and tick < prior then return nil, "clock-rollback" end
    if prior and tick >= prior and tick - prior < 20 then
        -- A saved person may have been rebound to the exact source body on
        -- this callback, so the earlier fast path lacked its body marker.
        sampleSourceAudible(personId, brain, body, tick)
        return rec.weekOne.appraisal
    end
    local allowed, admission = reserveScan(s, rec, brain, body, tick)
    if not allowed then return nil, admission end
    local started = getTimestampMs and getTimestampMs() or nil
    local okObserve = pcall(SAO.Perception.observe, personId, body, tick, false)
    if not okObserve then
        s.metrics.failures = s.metrics.failures + 1
        return nil, "private-perception-failed"
    end
    fastSoundObserved[personId] = { tick = tick, body = body,
        brainId = brain.id, born = brain.born }
    -- The source proxy's own scan can now yield a native hearing. Retain that
    -- exact private encounter before this person's next assessment; the
    -- source still owns the body and the performance remains someone else's.
    if SAO.Cognition and SAO.Cognition.weekOnePerformanceHearings then
        pcall(SAO.Cognition.weekOnePerformanceHearings, personId)
    end
    s.metrics.scans = s.metrics.scans + 1
    if started and getTimestampMs then
        local elapsed = getTimestampMs() - started
        if finite(elapsed) and elapsed >= 0 and elapsed < 60000 then
            s.metrics.scanMillis = s.metrics.scanMillis + elapsed
            s.metrics.peakScanMillis = math.max(s.metrics.peakScanMillis, elapsed)
        end
    end
    local okValues, values = pcall(SAO.Disposition.conflictValues, personId)
    if not okValues or type(values) ~= "table" or values.actorId ~= personId then
        return nil, "private-values-unavailable"
    end
    local beliefs = SAO.Perception.beliefs and SAO.Perception.beliefs[personId]
    local trusted, hostile = 0, 0
    if beliefs and type(beliefs.people) == "table"
        and SAO.Standing.keyForObserved and SAO.Standing.trust
        and SAO.Standing.isHostileTo then
        for name, seen in pairs(beliefs.people) do
            if type(seen) == "table" and seen.source == "observed"
                and finite(seen.at) and tick >= seen.at and tick - seen.at <= 40 then
                local key = SAO.Standing.keyForObserved(name)
                if key and key ~= personId then
                    local trust = SAO.Standing.trust(personId, key)
                    if finite(trust) and trust > 0 then trusted = trusted + 1 end
                    if SAO.Standing.isHostileTo(personId, key) then hostile = hostile + 1 end
                end
            end
        end
    end
    local okThreat, threats = pcall(SAO.Perception.believedThreatCount,
        personId, tick, 10, rec.x, rec.y)
    if not okThreat or not finite(threats) or threats < 0 then
        return nil, "private-threat-unavailable"
    end
    local hours = now()
    if not hours then return nil, "clock-unavailable" end
    local frame = { actorId = personId, atTick = tick, atHours = hours,
        source = "private-observation", brainId = brain.id, born = brain.born,
        observedThreats = threats, trustedSeen = trusted, hostileSeen = hostile,
        selfPreservation = values.selfPreservation, aggression = values.aggression,
        nerve = values.nerve, discipline = values.discipline,
        preference = threats > 0 and values.selfPreservation > values.aggression
            and "caution" or "continue", actionOwner = OWNER }
    rec.weekOne.appraisal = frame
    rec.weekOne.lastCognitionTick = tick
    return frame
end

local function nativeTarget(body, kind, key)
    if not (SAOJavaBridge and SAOJavaBridge.weekOneObservedTarget) then return nil end
    local ok, packed = pcall(function()
        return SAOJavaBridge:weekOneObservedTarget(body, kind, key)
    end)
    if not ok or type(packed) ~= "string" then return nil end
    local x, y, z, dist = packed:match("^TARGET\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
    x, y, z, dist = tonumber(x), tonumber(y), tonumber(z), tonumber(dist)
    if not (finite(x) and finite(y) and finite(z) and finite(dist))
        or dist <= 0 or dist > 14 then return nil end
    return { x = x, y = y, z = z, dist = dist }
end

local function fallbackTask(frame)
    if not (finite(frame.nerve) and finite(frame.discipline)
        and finite(frame.observedThreats) and finite(frame.hostileSeen)) then
        return nil, nil
    end
    local anim
    if frame.observedThreats > 0 then anim = "WipeBrow"
    elseif frame.hostileSeen > 0 then anim = "WipeHead"
    elseif frame.nerve < 0.35 then anim = "ChewNails"
    elseif frame.discipline >= 0.65 then anim = "ShiftWeight"
    else anim = "PullAtCollar" end
    local caution = math.max(0, math.min(1, 1 - frame.nerve))
    local pressure = math.max(0, math.min(3, frame.observedThreats))
    local duration = math.floor(120 + caution * 100 + pressure * 20)
    return anim, duration
end

-- SAO selects from the actor's own current sight and Standing. The returned
-- scalar plan is consumed once by the selected BWO program callback; this
-- module never mutates BWO task queues or drives the source body directly.
function W.planForBandit(brain, body)
    local frame, reason = W.assessForBandit(brain, body)
    if not frame then return nil, reason end
    local rec = SAO.Identity.get(frame.actorId)
    local phase = rec and rec.weekOne
    if not phase or phase.pending or SAO.Claims.heldBy(rec) ~= OWNER then
        return nil, "owner-changed"
    end
    local okTick, tick = pcall(SAO.History.ticks)
    if not okTick or not finite(tick) or not finite(frame.atTick)
        or tick < frame.atTick or tick - frame.atTick >= 20 then
        return nil, "stale-cognition"
    end
    local observedTick = frame.atTick
    local beliefs = SAO.Perception.beliefs and SAO.Perception.beliefs[frame.actorId]
    if not beliefs or beliefs.lastScanAt ~= observedTick then
        return nil, "stale-private-sight"
    end
    if not SAOJavaBridge or not SAOJavaBridge.weekOneObservedTarget then
        return nil, "native-target-unavailable"
    end
    local candidates = {}
    for _, seen in pairs(beliefs.zombies or {}) do
        if type(seen) == "table" and seen.source == "observed"
            and seen.at == observedTick and type(seen.track) == "string"
            and seen.track ~= "" and finite(seen.x) and finite(seen.y) then
            local dx, dy = seen.x - rec.x, seen.y - rec.y
            candidates[#candidates + 1] = { kind = "zombie", key = seen.track,
                dist = math.sqrt(dx * dx + dy * dy) }
        end
    end
    for name, seen in pairs(beliefs.people or {}) do
        if type(name) == "string" and type(seen) == "table"
            and seen.source == "observed" and seen.at == observedTick
            and finite(seen.x) and finite(seen.y)
            and SAO.Standing.keyForObserved and SAO.Standing.isHostileTo then
            local key = SAO.Standing.keyForObserved(name)
            if key and key ~= frame.actorId and SAO.Standing.isHostileTo(frame.actorId, key) then
                local dx, dy = seen.x - rec.x, seen.y - rec.y
                candidates[#candidates + 1] = { kind = "person", key = name,
                    dist = math.sqrt(dx * dx + dy * dy) }
            end
        end
    end
    SAO.Ordering.sort(candidates, function(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.kind .. a.key < b.kind .. b.key
    end)
    for index = 1, math.min(8, #candidates) do
        local candidate = candidates[index]
        local target = nativeTarget(body, candidate.kind, candidate.key)
        if target then
            local walkType = target.dist > 7
                and frame.aggression + frame.nerve > frame.selfPreservation and "Run"
                or target.dist <= 4 and "WalkAim" or "Walk"
            local plan = { kind = "move", x = target.x, y = target.y, z = target.z,
                dist = target.dist, walkType = walkType,
                targetKind = candidate.kind, source = "sao-observed",
                actorId = frame.actorId, brainId = brain.id, born = brain.born,
                atTick = tick, observedAtTick = observedTick, actionOwner = OWNER }
            phase.decision = { kind = plan.kind, targetKind = candidate.kind,
                targetKey = candidate.key, atTick = tick,
                observedAtTick = observedTick, atHours = frame.atHours,
                walkType = walkType, source = plan.source }
            store().metrics.moves = store().metrics.moves + 1
            return plan
        end
    end
    local anim, duration = fallbackTask(frame)
    if not anim then return nil, "private-appraisal-invalid" end
    local plan = { kind = "fallback", reason = #candidates == 0
        and "no-private-enemy" or "no-current-native-target",
        source = "sao-person-appraisal", anim = anim, duration = duration,
        actorId = frame.actorId, brainId = brain.id, born = brain.born,
        atTick = tick, observedAtTick = observedTick, actionOwner = OWNER }
    phase.decision = { kind = plan.kind, reason = plan.reason,
        atTick = tick, observedAtTick = observedTick,
        atHours = frame.atHours, source = plan.source,
        anim = anim, duration = duration }
    store().metrics.fallbacks = store().metrics.fallbacks + 1
    return plan
end

function W.costMetrics()
    local s = store()
    if not s then return nil end
    local out = {}
    for key, value in pairs(s.metrics) do out[key] = value end
    return out
end

local function activeRefusal(brain, reason, phase)
    local s = store()
    if s then
        s.metrics.activeRefusals = (s.metrics.activeRefusals or 0) + 1
        s.lastActiveRefusal = { reason = reason, brainId = brain and brain.id,
            born = brain and brain.born, atHours = now() }
    end
    if phase then
        phase.lastActiveRefusal = { reason = reason, atHours = now() }
    end
end

local function exactActivePlan(brain, body, plan)
    if not (type(plan) == "table" and currentBody(brain, body)
        and plan.brainId == brain.id and plan.born == brain.born
        and plan.actionOwner == OWNER and finite(plan.atTick)
        and finite(plan.observedAtTick) and plan.observedAtTick <= plan.atTick
        and plan.atTick - plan.observedAtTick < 20) then return nil end
    local ok, md = pcall(function() return body:getModData() end)
    if not ok or type(md) ~= "table" or md.SAOWeekOneOrigin ~= OWNER
        or md.SAOWeekOneBrainId ~= brain.id or md.SAOWeekOneBorn ~= brain.born
        or md.SAOWeekOnePersonId ~= plan.actorId then return nil end
    local rec = SAO.Identity and SAO.Identity.get(plan.actorId)
    if not rec or not rec.weekOne or rec.weekOne.pending
        or SAO.Claims.heldBy(rec) ~= OWNER then return nil end
    local okTick, tick = pcall(SAO.History.ticks)
    if not okTick or tick ~= plan.atTick then return nil end
    return rec.weekOne
end

-- A person may confront one currently seen, Standing-hostile player through
-- the exact physical gate. An older sight frame or uninstalled gate leaves
-- the ordinary observed move as the only task.
local function personCombatTask(brain, body, plan, phase)
    local combat = SAO.WeekOneTargetCombat
    local decision = phase and phase.decision
    if plan and plan.kind == "move" and plan.observedAtTick == plan.atTick
        and phase.appraisal and phase.appraisal.preference == "continue"
        and decision and type(decision.targetKey) == "string"
        and type(W.explosiveTaskForObserved) == "function" then
        local okExplosive, explosive = pcall(W.explosiveTaskForObserved,
            brain, body, plan, phase)
        if okExplosive and type(explosive) == "table"
            and explosive.action == "SAOThrowExplosive" then
            decision.kind = "attack"
            decision.attackMethod = "native-pipe-bomb"
            return explosive
        end
    end
    if not (plan and plan.kind == "move" and plan.targetKind == "person"
        and phase.appraisal and phase.appraisal.preference == "continue"
        and decision and type(decision.targetKey) == "string"
        and plan.observedAtTick == plan.atTick
        and combat and type(combat.ready) == "function"
        and combat.ready() == true
        and type(combat.authorizedTaskForObserved) == "function") then return nil end
    local ok, task = pcall(combat.authorizedTaskForObserved,
        brain, body, plan.actorId, decision.targetKey, plan.observedAtTick)
    if not ok or type(task) ~= "table" or task.action ~= "Smack"
        or type(task.saoWeekOneTargetKey) ~= "string" then return nil end
    decision.kind = "attack"
    decision.attackMethod = "native-melee"
    decision.playerKey = task.saoWeekOneTargetKey
    return task
end

local function originalFallback(phase, brain)
    if phase.sourceFallbackSeen ~= true
        or type(phase.sourceFallbackProgram) ~= "string" then
        return nil, "source-fallback-unpinned"
    end
    local program = phase.sourceFallbackProgram
    if brain.programFallback ~= program then return nil, "source-fallback-changed" end
    if #program > 32 or not program:match("^[A-Za-z]+$")
        or program == "Active" then return nil, "source-fallback-ambiguous" end
    local family = ZombiePrograms and ZombiePrograms[program]
    if type(family) ~= "table" or type(family.Main) ~= "function" then
        return nil, "source-fallback-unavailable"
    end
    return program
end

-- Active.Main is an emergency BWO source stage. Its stamped Week One actor
-- receives an SAO private choice while BWO remains the task actuator.
function W.activeDecision(brain, body)
    if type(brain) ~= "table" or brain.saoWeekOneOrigin ~= OWNER
        or type(brain.program) ~= "table" or brain.program.name ~= "Active" then
        return nil, "source-program-unqualified"
    end
    local plan, reason = W.planForBandit(brain, body)
    if not plan then
        activeRefusal(brain, reason or "private-plan-unavailable")
        return nil, reason
    end
    local phase = exactActivePlan(brain, body, plan)
    if not phase then
        activeRefusal(brain, "source-plan-mismatch")
        return nil, "source-plan-mismatch"
    end
    if plan.kind == "move" and plan.source == "sao-observed"
        and (plan.targetKind == "zombie" or plan.targetKind == "person")
        and finite(plan.x) and finite(plan.y) and finite(plan.z)
        and finite(plan.dist) and plan.dist > 0 and plan.dist <= 14
        and (plan.walkType == "Walk" or plan.walkType == "Run"
            or plan.walkType == "WalkAim")
        and BanditUtils and type(BanditUtils.GetMoveTask) == "function" then
        local attack = personCombatTask(brain, body, plan, phase)
        if attack then
            phase.decision.adapter = "Active.Main"
            return { status = true, next = "Main", tasks = { attack } }
        end
        local ok, task = pcall(BanditUtils.GetMoveTask, 0,
            plan.x, plan.y, plan.z, plan.walkType, plan.dist)
        if ok and task then
            phase.decision.adapter = "Active.Main"
            return { status = true, next = "Main", tasks = { task } }
        end
    elseif plan.kind == "fallback" and plan.source == "sao-person-appraisal"
        and type(plan.reason) == "string" and finite(plan.duration)
        and plan.duration >= 60 and plan.duration <= 400
        and plan.duration % 1 == 0
        and (plan.anim == "ShiftWeight" or plan.anim == "ChewNails"
            or plan.anim == "WipeBrow" or plan.anim == "WipeHead"
            or plan.anim == "PullAtCollar") then
        if plan.reason == "no-private-enemy" and plan.observedAtTick == plan.atTick then
            local program, refusal = originalFallback(phase, brain)
            if program and Bandit and type(Bandit.SetProgram) == "function" then
                local ok = pcall(Bandit.SetProgram, body, program, {})
                if ok and type(brain.program) == "table"
                    and brain.program.name == program then
                    phase.decision = { kind = "resume-program", source = "sao-person-appraisal",
                        adapter = "Active.Main", program = program, atTick = plan.atTick,
                        observedAtTick = plan.observedAtTick, atHours = now() }
                    return { status = true, next = "Main", tasks = {} }
                end
                refusal = "source-program-transition-failed"
            elseif program then
                refusal = "source-program-transition-unavailable"
            end
            activeRefusal(brain, refusal, phase)
            phase.decision.resumeRefusal = refusal
        end
        phase.decision.adapter = "Active.Main"
        return { status = true, next = "Main",
            tasks = {{ action = "Time", anim = plan.anim, time = plan.duration }} }
    end
    activeRefusal(brain, "unsupported-active-plan", phase)
    return nil, "unsupported-active-plan"
end

-- Bandits keeps weapons and some belongings in its brain until death. The
-- native capture materializes the selected source schema into the detached
-- SAO snapshot. An unsupported virtual field holds the BWO actor in place.
local function unsupportedVirtualAssets(brain)
    for _, key in ipairs({ "inventory", "loot" }) do
        local value = brain[key]
        if value ~= nil and type(value) ~= "table" then return key end
        if type(value) == "table" then
            for _ in pairs(value) do return key end
        end
    end
    for _, key in ipairs({ "weapons", "permaInv", "keys" }) do
        local value = brain[key]
        if value ~= nil and type(value) ~= "table" then return key end
    end
    if brain.bag ~= nil and type(brain.bag) ~= "table"
        and brain.bag ~= "Briefcase" then return "bag" end
    return nil
end

local function offCamera(body, player)
    if not player then return false end
    local ok, distant, seen, squareSeen = pcall(function()
        local dx, dy = player:getX() - body:getX(), player:getY() - body:getY()
        local square = body:getSquare()
        return dx * dx + dy * dy > 50 * 50,
            player:CanSee(body), square and square:isCanSee(0)
    end)
    return ok and distant and seen == false and squareSeen == false
end

local function clearStage(rec)
    local token = rec.weekOne and rec.weekOne.stageToken
    if not token then return true end
    if not SAOJavaBridge then return false end
    local body = staged[rec.id]
    if not body then
        local ok, found = pcall(function()
            return SAOJavaBridge:findReturnDestination(rec.id, token)
        end)
        if not ok then return false end
        body = found
    end
    if body and SAOJavaBridge:discardReturnBody(body) ~= true then return false end
    staged[rec.id] = nil
    rec.weekOne.stageToken = nil
    return true
end

-- A compatibility route for older imported saves with source-owned flags.
-- This grants only safe off-camera body retirement, never SAO relationship.
local function legacyCannedSourceFollower(brain)
    return brain.saoWeekOneOrigin == OWNER and brain.permanent == true
        and brain.loyal == true and brain.occupation == "Babe"
        and type(brain.program) == "table" and brain.program.name == "Babe"
end

-- Exact source-start provenance permits a source-marked body to retire even
-- if old source code left a permanent flag behind. The marker is a spawn
-- event, not a person's birth or a permanent follower relationship.
local function selectedStampedSourceStart(brain, rec)
    local spawn = brain.saoWeekOneStartEntry or brain.saoWeekOneBabeBirth
    local admitted = rec.weekOne and (rec.weekOne.sourceSpawn
        or rec.weekOne.babeBirth)
    local program = type(brain.program) == "table" and brain.program.name
    return type(spawn) == "table" and type(admitted) == "table"
        and spawn.source == "BWOEvents.Start/StartBabe"
        and (brain.saoWeekOneStartEntry == nil or spawn.selected == true)
        and (spawn.brainId == nil or spawn.brainId == brain.id)
        and (spawn.born == nil or spawn.born == brain.born)
        and admitted.source == spawn.source
        and (admitted.brainId == nil or admitted.brainId == brain.id)
        and (admitted.born == nil or admitted.born == brain.born)
        and type(spawn.eventRef) == "string"
        and admitted.eventRef == spawn.eventRef
        and (brain.saoWeekOneStartEntry and program == "Walker"
            or brain.saoWeekOneBabeBirth and brain.occupation == "Babe"
                and (program == "Babe" or program == "Walker"))
end

function W.prepareRetire(brain, body, player)
    local personId, reason = W.observeBrain(brain, body)
    if not personId then return false, reason end
    local rec = SAO.Identity.get(personId)
    local phase = rec.weekOne
    if phase.pending then return false, "retirement-awaiting-server" end
    if selectedOwnerReceiptPending(brain, rec) then
        return false, "selected-owner-receipt-pending" end
    if not offCamera(body, player) then return false, "body-in-view" end
    if brain.inVehicle or brain.permanent
        and not (legacyCannedSourceFollower(brain)
            or selectedStampedSourceStart(brain, rec)) then
        return false, "source-body-busy" end
    local asset = unsupportedVirtualAssets(brain)
    if asset then return false, "unsupported-virtual-asset-" .. asset end
    local okHealth, bodyHealth = pcall(function() return body:getHealth() end)
    if not okHealth or not finite(bodyHealth) or bodyHealth <= 0
        or not finite(brain.health) or brain.health <= 0 then
        return false, "source-health-invalid"
    end
    if brain.infection ~= nil and (not finite(brain.infection)
        or brain.infection ~= 0) then
        return false, "source-infection-unrepresented"
    end
    if not SAOJavaBridge or not SAOJavaBridge.captureWeekOne
        or not SAOJavaBridge.createReturnBody then return false, "native-transfer-unavailable" end
    if not clearStage(rec) then return false, "stage-cleanup-pending" end
    local s = store()
    if not s then return false, "store-unavailable" end
    local token = rec.id .. ":" .. tostring(brain.id) .. ":"
        .. tostring(brain.born) .. ":" .. tostring(s.nextTransfer)
    phase.stageToken = token
    local okCreate, stage = pcall(function()
        return SAOJavaBridge:createReturnBody(rec.forename, rec.surname,
            rec.x, rec.y, rec.z, rec.female == true)
    end)
    if not okCreate or not stage then
        phase.stageToken = nil
        return false, "stage-construction-failed"
    end
    staged[rec.id] = stage
    local ok, packed = pcall(function()
        local md = stage:getModData()
        md.SAOPersonId, md.SAOReturnToken = rec.id, token
        if SAOJavaBridge:returnBodyNeedsCleanup(stage) then return nil end
        return SAOJavaBridge:captureWeekOne(body, stage, brain)
    end)
    local valid = ok and packed and SAOJavaBridge:validateHibernation(packed) == true
    if not clearStage(rec) then return false, "stage-cleanup-pending" end
    if not valid then return false, "native-capture-failed" end
    local hours = now()
    if not hours then return false, "clock-unavailable" end
    phase.pending = { token = token, personId = rec.id,
        brainId = brain.id, born = brain.born,
        packed = packed, hours = hours, x = rec.x, y = rec.y, z = rec.z,
        serverRemoved = false }
    phase.retirementOffCamera = true
    phase.status = "retirement-pending"
    s.nextTransfer = s.nextTransfer + 1
    return true, { token = token, personId = rec.id,
        brainId = brain.id, born = brain.born }
end

-- Installed IsoMovingObject.removeFromSquare clears current; installed
-- IsoZombie.removeFromWorld removes this exact object from the cell zombie
-- list. The object's ordinary square field can remain stale, so it is not a
-- removal postcondition. Only a same-session native remove of the prepared
-- object can create this witness; neither a cache miss nor a saved intent can.
local function removedFromNativeCell(body)
    if not body then return false end
    local ok, current, inCell = pcall(function()
        local cell = body:getCell()
        return body:getCurrentSquare(), cell:getZombieList():contains(body)
    end)
    return ok and current == nil and inCell == false
end

local function exactPhysicalRemovalProof(rec, token, brainId, born)
    local proof = physicalRemovalProofs[rec.id]
    return proof and proof.personId == rec.id and proof.token == token
        and proof.brainId == brainId and proof.born == born
        and removedFromNativeCell(proof.body) or false
end

-- The server has durably accepted this exact retirement before the source
-- body is touched. Refresh the detached snapshot at the last safe instant:
-- the source person may have moved, been injured or changed equipment while
-- the acknowledgement was in flight. A lost acknowledgement is replayed by
-- QueryRetired; it never authorizes removal by token shape alone.
function W.confirmPreparedRetire(args, brain, body, player)
    if type(args) ~= "table" or type(brain) ~= "table"
        or not player or not getSpecificPlayer
        or getSpecificPlayer(0) ~= player then return nil, "player-unavailable" end
    local s = store()
    local row = s and s.byBrain[tostring(args.id)]
    local rec = row and SAO.Identity and SAO.Identity.get(row.personId)
    local phase = rec and rec.weekOne
    local p = phase and phase.pending
    if not p or type(args.token) ~= "string" or args.token ~= p.token
        or args.id ~= p.brainId or args.born ~= p.born
        or args.personId ~= rec.id or row.personId ~= rec.id
        or row.brainId ~= brain.id or row.born ~= tostring(brain.born)
        or brain.id ~= p.brainId or brain.born ~= p.born
        or brain.saoWeekOneOrigin ~= OWNER or phase.source ~= OWNER
        or phase.status ~= "retirement-pending"
        or not SAO.Claims or SAO.Claims.heldBy(rec) ~= OWNER
        or not SAOJavaBridge or not SAOJavaBridge.captureWeekOne
        or not SAOJavaBridge.createReturnBody then
        return nil, "prepared-retirement-mismatch"
    end
    -- A transfer prepared by an older client or saved before this guard may
    -- still be in flight. Admission is safe if its delayed reply has arrived;
    -- otherwise keep the live source body and its server preparation intact.
    if selectedOwnerReceiptPending(brain, rec) then
        admitSelectedSourceSpawn(brain, rec)
        if selectedOwnerReceiptPending(brain, rec) then
            return nil, "selected-owner-receipt-pending" end
    end
    local current
    if BanditZombie and type(BanditZombie.GetInstanceById) == "function" then
        local ok, found = pcall(BanditZombie.GetInstanceById, p.brainId)
        if not ok then return nil, "source-body-lookup-failed" end
        current = found
    else
        return nil, "source-body-lookup-unavailable"
    end
    if current == nil then
        if exactPhysicalRemovalProof(rec, p.token, p.brainId, p.born) then
            return "resend" end
        return nil, "physical-removal-proof-unavailable"
    end
    if exactPhysicalRemovalProof(rec, p.token, p.brainId, p.born) then
        if current == physicalRemovalProofs[rec.id].body then return "resend" end
        return nil, "source-body-returned"
    end
    if current ~= body or not currentBody(brain, body)
        or not offCamera(body, player) then return nil, "source-body-not-safe" end
    local okBody, x, y, z, health, vehicle, md = pcall(function()
        return body:getX(), body:getY(), body:getZ(), body:getHealth(),
            body:getVehicle(), body:getModData()
    end)
    if not okBody or not (finite(x) and finite(y) and finite(z)
        and finite(health) and health > 0 and finite(brain.health)
        and brain.health > 0) or vehicle ~= nil or brain.inVehicle
        or brain.permanent and not (legacyCannedSourceFollower(brain)
            or selectedStampedSourceStart(brain, rec))
        or md == nil or md.SAOWeekOnePersonId ~= rec.id
        or md.SAOWeekOneBrainId ~= brain.id
        or md.SAOWeekOneBorn ~= brain.born
        or md.SAOWeekOneOrigin ~= OWNER
        or unsupportedVirtualAssets(brain) ~= nil
        or brain.infection ~= nil and (not finite(brain.infection)
            or brain.infection ~= 0) then
        return nil, "source-state-not-capturable"
    end
    if not clearStage(rec) then return nil, "stage-cleanup-pending" end
    phase.stageToken = p.token
    local okCreate, stage = pcall(function()
        return SAOJavaBridge:createReturnBody(rec.forename, rec.surname,
            x, y, z, rec.female == true)
    end)
    if not okCreate or not stage then
        phase.stageToken = nil
        return nil, "stage-construction-failed"
    end
    staged[rec.id] = stage
    local okCapture, packed = pcall(function()
        local stageData = stage:getModData()
        stageData.SAOPersonId, stageData.SAOReturnToken = rec.id, p.token
        if SAOJavaBridge:returnBodyNeedsCleanup(stage) then return nil end
        return SAOJavaBridge:captureWeekOne(body, stage, brain)
    end)
    local valid = okCapture and packed
        and SAOJavaBridge:validateHibernation(packed) == true
    if not clearStage(rec) then return nil, "stage-cleanup-pending" end
    if not valid then return nil, "native-capture-failed" end
    local hours = now()
    if not hours or not countyHours() then return nil, "clock-unavailable" end
    p.packed, p.hours = packed, hours
    p.x, p.y, p.z = x, y, z
    -- The saved intent records the attempt, not its success. A Prepared
    -- replay after reload must find the exact live body for another attempt.
    p.localRemovalIntent = true
    preparedRemovalBodies[rec.id] = { token = p.token, brainId = p.brainId,
        born = p.born, body = body, personId = rec.id }
    return "remove"
end

function W.recordPhysicalRemoval(args, brain, body, player)
    if type(args) ~= "table" or type(brain) ~= "table" or not body
        or not player or not getSpecificPlayer
        or getSpecificPlayer(0) ~= player then return false end
    local s = store()
    local row = s and s.byBrain[tostring(args.id)]
    local rec = row and SAO.Identity and SAO.Identity.get(row.personId)
    local phase = rec and rec.weekOne
    local p = phase and phase.pending
    local prepared = rec and preparedRemovalBodies[rec.id]
    if not p or not prepared or phase.status ~= "retirement-pending"
        or phase.source ~= OWNER
        or not (SAO.Claims and SAO.Claims.heldBy)
        or SAO.Claims.heldBy(rec) ~= OWNER
        or args.personId ~= rec.id or args.token ~= p.token
        or args.id ~= p.brainId or args.born ~= p.born
        or brain.id ~= p.brainId or brain.born ~= p.born
        or row.brainId ~= p.brainId or row.born ~= tostring(p.born)
        or row.source ~= OWNER or prepared.body ~= body
        or prepared.personId ~= rec.id or prepared.token ~= p.token
        or prepared.brainId ~= p.brainId or prepared.born ~= p.born then
        return false end
    local okBody, bodyId, md = pcall(function()
        return body:getPersistentOutfitID(), body:getModData()
    end)
    if not okBody or bodyId ~= p.brainId or type(md) ~= "table"
        or md.SAOWeekOneOrigin ~= OWNER
        or md.SAOWeekOnePersonId ~= rec.id
        or md.SAOWeekOneBrainId ~= p.brainId
        or md.SAOWeekOneBorn ~= p.born
        or not removedFromNativeCell(body) then return false end
    local removedAtWorldHours, removedAtCountyHours = now(), countyHours()
    if not finite(p.hours) or not removedAtWorldHours
        or removedAtWorldHours + 0.000001 < p.hours
        or not removedAtCountyHours
        or finite(rec.releasedAtHours)
            and removedAtCountyHours + 0.000001 < rec.releasedAtHours then
        return false end
    p.removedAtWorldHours = removedAtWorldHours
    p.removedAtCountyHours = removedAtCountyHours
    p.removalCountyClockSource = "SAO.History.countyHours"
    physicalRemovalProofs[rec.id] = { personId = rec.id,
        token = p.token, brainId = p.brainId, born = p.born, body = body,
        removedAtWorldHours = removedAtWorldHours,
        removedAtCountyHours = removedAtCountyHours }
    preparedRemovalBodies[rec.id] = nil
    return true
end

local function sourceBodyLookupAvailable()
    return BanditZombie
        and type(BanditZombie.GetInstanceById) == "function"
end

local function exactRetirementReceipt(rec, row)
    local phase = rec.weekOne
    local receipt = phase and phase.retirementReceipt
    return phase and phase.retirementProtocol == "server-ticket-v1"
        and type(receipt) == "table"
        and receipt.source == "SAOWeekOne.Retired"
        and receipt.personId == rec.id and receipt.brainId == phase.brainId
        and receipt.born == phase.born
        and receipt.atWorldHours == phase.retiredAtHours
        and type(receipt.token) == "string" and receipt.token ~= ""
        and row and row.personId == rec.id
        and row.brainId == phase.brainId
        and row.born == tostring(phase.born)
        and row.source == OWNER
end

local function complete(rec)
    local phase = rec.weekOne
    local p = phase and phase.pending
    if not p or p.serverRemoved ~= true then return false end
    local s = store()
    local row = s and s.byBrain[tostring(p.brainId)]
    if not row or row.personId ~= rec.id or row.brainId ~= p.brainId
        or row.born ~= tostring(p.born) or row.source ~= OWNER then
        return false end
    if not (SAOJavaBridge and SAOJavaBridge:validateHibernation(p.packed) == true) then
        return false
    end
    local proof = physicalRemovalProofs[rec.id]
    if not exactPhysicalRemovalProof(rec, p.token, p.brainId, p.born) then
        return false end
    if phase.sourceBodyReturnObserved == true then return false end
    if sourceBodyLookupAvailable() then
        local okLookup, body = pcall(BanditZombie.GetInstanceById, p.brainId)
        if not okLookup then return false end
        if body ~= nil and (not proof or body ~= proof.body) then
            phase.sourceBodyReturnObserved = true
            return false end
    end
    -- The source preparation hour is native world time. The saved paired
    -- clocks were sampled when this exact body left the native cell; a
    -- delayed server acknowledgement cannot move that physical boundary.
    local currentWorldHours, currentCountyHours = now(), countyHours()
    if not finite(p.hours) or not finite(p.removedAtWorldHours)
        or not finite(p.removedAtCountyHours)
        or p.removalCountyClockSource ~= "SAO.History.countyHours"
        or p.removedAtWorldHours + 0.000001 < p.hours
        or p.removedAtCountyHours < 0
        or not proof or proof.removedAtWorldHours ~= p.removedAtWorldHours
        or proof.removedAtCountyHours ~= p.removedAtCountyHours
        or not currentWorldHours or not currentCountyHours
        or currentWorldHours + 0.000001 < p.removedAtWorldHours
        or currentCountyHours + 0.000001 < p.removedAtCountyHours then
        return false end
    rec.hibernation, rec.releasedAtHours = p.packed, p.removedAtCountyHours
    rec.x, rec.y, rec.z = p.x, p.y, p.z
    rec.bodyVisual = nil
    phase.pending = nil
    phase.status = "dormant"
    phase.retiredAtHours = p.hours
    phase.sourceRemovedAtCountyHours = p.removedAtCountyHours
    phase.sourceRemovedAtWorldHours = p.removedAtWorldHours
    phase.retirementReceipt = { source = "SAOWeekOne.Retired",
        token = p.token, personId = rec.id, brainId = p.brainId,
        born = p.born, atWorldHours = p.hours,
        removedAtWorldHours = p.removedAtWorldHours,
        removedAtCountyHours = p.removedAtCountyHours,
        countyClockSource = "SAO.History.countyHours" }
    phase.retirementProtocol = "server-ticket-v1"
    row.retirementProtocolEra = "ticketed-v1"
    return true
end

function W.onServerCommand(module, command, args)
    if module ~= "SAOWeekOne" or type(args) ~= "table" then return end
    if command == "OwnerReceipt" then
        local ref = args.eventRef
        if type(ref) ~= "string" or #ref ~= 32
            or ref:match("^[0-9a-f]+$") == nil
            or not finite(args.brainId) or not finite(args.born)
            or args.source ~= "BWOEvents.Start/StartBabe"
                and args.source ~= "VBandit.schedule/SpawnGroup"
                and args.source ~= "VBandit.setup/SpawnGroupArea"
            or not (SAO.Standing and SAO.Standing.playerKey
                and SAO.Standing.playerAccountKey) then return end
        local player = getSpecificPlayer and getSpecificPlayer(0)
        if not player then return end
        local ok, account, key, descriptorId, forename, surname,
            world, mode = pcall(function()
            local descriptor = player:getDescriptor()
            local selected = getWorld()
            return SAO.Standing.playerAccountKey(player),
                SAO.Standing.playerKey(player), descriptor:getID(),
                descriptor:getForename(), descriptor:getSurname(),
                selected:getWorld(), selected:getGameMode()
        end)
        if not ok or args.accountKey ~= account
            or args.nativeDescriptorId ~= descriptorId
            or args.forename ~= forename or args.surname ~= surname
            or args.world ~= world or args.gameMode ~= mode
            or args.playerKey ~= account and args.playerKey ~= key then return end
        ownerReceipts[ref] = args
        ownerQueries[ref] = nil
        return
    end
    if command ~= "Retired" and command ~= "Prepared" then return end
    local s = store()
    local row = s and s.byBrain[tostring(args.id)]
    local rec = row and SAO.Identity.get(row.personId)
    local phase = rec and rec.weekOne
    local p = phase and phase.pending
    if not p then
        -- A replayed server ticket cannot reconstruct a lost local physical
        -- removal witness for a previously completed dormant save.
        return
    end
    if p.token ~= args.token or p.brainId ~= args.id
        or p.born ~= args.born or row.born ~= tostring(args.born) then return end
    if command == "Prepared" then
        if args.personId == rec.id then p.serverPrepared = true end
        return
    end
    if args.personId ~= rec.id then return end
    p.serverPrepared = true
    p.serverRemoved = true
    complete(rec)
end

local function queryPending(p, force)
    local hours = now()
    if not hours then return end
    if p.serverRemoved and sourceBodyLookupAvailable() then return end
    if not force and p.lastQueryHours and hours >= p.lastQueryHours
        and hours - p.lastQueryHours < 0.25 then return end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player or not sendClientCommand then return end
    local ok = pcall(function()
        local command = (p.serverPrepared == true or p.serverRemoved == true
                or p.personId == nil)
            and "QueryRetired"
            or "PrepareRetire"
        sendClientCommand(player, "SAOWeekOne", command,
            { token = p.token, id = p.brainId, born = p.born,
                personId = p.personId })
    end)
    if ok then p.lastQueryHours = hours end
end

local function currentChatStanding(rec, playerKey)
    if not (SAO.Standing and SAO.Standing.trust
        and SAO.Standing.companyStanding and SAO.Standing.isHostileTo
        and SAO.Standing.groupOf) then return false end
    local ok, trust, company, hostile, group = pcall(function()
        return SAO.Standing.trust(rec.id, playerKey),
            SAO.Standing.companyStanding(rec.id, playerKey),
            SAO.Standing.isHostileTo(rec.id, playerKey),
            SAO.Standing.groupOf(rec.id)
    end)
    local options = SandboxVars and SandboxVars.SurvivorAwareness
    local bar = options and tonumber(options.TrustToCompany) or 0.5
    if not finite(bar) then bar = 0.5 end
    return ok and finite(trust) and finite(company)
        and company > bar and hostile == false and group == nil
end

local function transferChatIntent(rec)
    local phase = rec.weekOne
    local accepted = phase and phase.chatCompanion
    if type(accepted) ~= "table" then return nil, "no-accepted-chat" end
    if phase.retirementOffCamera ~= true
        or not finite(phase.retiredAtHours)
        or accepted.source ~= "heard-player-request"
        or type(accepted.playerKey) ~= "string" or accepted.playerKey == ""
        or not finite(accepted.sinceHours)
        or accepted.sinceHours > phase.retiredAtHours
        or phase.chatMode ~= "follow" and phase.chatMode ~= "hold"
            and phase.chatMode ~= "home" then
        return nil, "chat-evidence-unavailable" end
    if rec.playerCompanionIntent ~= nil then
        return nil, "ordinary-intent-already-present" end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    local ok, playerKey = pcall(function()
        if not player or player:isDead() then return nil end
        return SAO.Standing.playerKey(player)
    end)
    if not ok or not playerKey or playerKey ~= accepted.playerKey then
        return nil, "current-player-mismatch" end
    if not currentChatStanding(rec, playerKey) then
        return nil, "current-standing-refused" end
    if phase.chatMode == "home"
        and (not finite(rec.homeX) or not finite(rec.homeY)) then
        return nil, "ordinary-home-unavailable" end
    return { playerKey = playerKey, mode = phase.chatMode,
        origin = "week-one-heard-player-request",
        acceptedAtHours = accepted.sinceHours,
        transferredAtHours = phase.retiredAtHours,
        sourceBrainId = phase.brainId, sourceBorn = phase.born }, "carried"
end

-- A copied request remains ordinary person evidence. Controller rechecks the
-- present player and Standing before applying it to a loaded SAO body.
function W.validTransferredCompanion(rec, player)
    local phase = rec and rec.weekOne
    local intent = rec and rec.playerCompanionIntent
    if not phase or not intent or rec.dead or phase.pending
        or phase.status ~= "transferred" or phase.retirementOffCamera ~= true
        or phase.chatHandoff == nil or phase.chatHandoff.status ~= "carried"
        or not finite(phase.retiredAtHours)
        or intent.transferredAtHours ~= phase.retiredAtHours
        or intent.sourceBrainId ~= phase.brainId
        or intent.sourceBorn ~= phase.born
        or intent.origin ~= "week-one-heard-player-request"
        or intent.mode ~= "follow" and intent.mode ~= "hold"
            and intent.mode ~= "home"
        or intent.mode == "home" and finite(intent.homeArrivedAtHours)
        or not (SAO.Claims and SAO.Claims.heldBy)
        or SAO.Claims.heldBy(rec) ~= nil
        or not player or not getSpecificPlayer
        or getSpecificPlayer(0) ~= player then return nil end
    local ok, playerKey = pcall(function()
        if player:isDead() then return nil end
        return SAO.Standing.playerKey(player)
    end)
    if not ok or playerKey ~= intent.playerKey
        or not currentChatStanding(rec, playerKey) then return nil end
    return intent
end

local function dormantHandoffReady(rec, row, hours)
    local phase = rec.weekOne
    if phase.source ~= OWNER or row.source ~= OWNER
        or row.personId ~= rec.id or row.brainId ~= phase.brainId
        or row.born ~= tostring(phase.born)
        or phase.pending or phase.stageToken
        or phase.retirementOffCamera ~= true
        or not finite(phase.retiredAtHours)
        or not finite(rec.releasedAtHours)
        or not hours or hours + 0.000001 < phase.retiredAtHours
        or not (SAOJavaBridge and SAOJavaBridge.validateHibernation) then
        return false, "retirement-evidence-missing" end
    local okPacked, validPacked = pcall(function()
        return SAOJavaBridge:validateHibernation(rec.hibernation) end)
    if not okPacked or validPacked ~= true then
        return false, "retirement-capture-invalid" end
    local basis
    if exactRetirementReceipt(rec, row) then
        if row.retirementProtocolEra ~= nil
            and row.retirementProtocolEra ~= "ticketed-v1" then
            return false, "retirement-provenance-mismatch" end
        basis = "server-receipt"
    elseif phase.retirementReceipt ~= nil
        or phase.retirementProtocol ~= nil then
        return false, "retirement-receipt-mismatch"
    else
        -- A pre-token dormant save has the old completion fields, including
        -- the released hour and packed body. Stamp its migration provenance;
        -- newly completed transfers carry retirementProtocol even if a later
        -- corruption removes their receipt table. The independent row era
        -- also refuses a newly completed row if both phase fields are lost.
        if row.retirementProtocolEra ~= nil
            and row.retirementProtocolEra ~= "pre-token-v0" then
            return false, "retirement-provenance-mismatch" end
        local prior = phase.preTokenCompletion
        if prior == nil then
            prior = { schema = "sao-week-one-pre-token-completion/1",
                personId = rec.id, brainId = phase.brainId,
                born = phase.born, atWorldHours = phase.retiredAtHours }
            phase.preTokenCompletion = prior
        end
        if type(prior) ~= "table"
            or prior.schema ~= "sao-week-one-pre-token-completion/1"
            or prior.personId ~= rec.id or prior.brainId ~= phase.brainId
            or prior.born ~= phase.born
            or prior.atWorldHours ~= phase.retiredAtHours then
            return false, "retirement-provenance-mismatch" end
        row.retirementProtocolEra = "pre-token-v0"
        basis = "saved-pre-token-completion"
    end
    if basis == "saved-pre-token-completion" then
        -- Its historical fields prove a saved completion claim, not removal
        -- from the native cell. A source cache miss cannot fill that gap.
        if rec.releasedAtHours ~= phase.retiredAtHours then
            return false, "retirement-evidence-missing" end
        return false, "historical-physical-absence-unproven" end
    local receipt = phase.retirementReceipt
    if receipt.countyClockSource == nil
        and receipt.removedAtCountyHours == nil
        and receipt.removedAtWorldHours == nil
        and phase.sourceRemovedAtCountyHours == nil
        and phase.sourceRemovedAtWorldHours == nil then
        -- Old ticketed rows were written with a native releasedAtHours.
        -- Their original county checkpoint cannot be reconstructed.
        return false, "retirement-county-clock-unproven" end
    if receipt.countyClockSource ~= "SAO.History.countyHours"
        or not finite(receipt.removedAtCountyHours)
        or receipt.removedAtCountyHours < 0
        or not finite(receipt.removedAtWorldHours)
        or receipt.removedAtWorldHours + 0.000001 < receipt.atWorldHours
        or phase.sourceRemovedAtCountyHours ~= receipt.removedAtCountyHours
        or phase.sourceRemovedAtWorldHours
            ~= receipt.removedAtWorldHours
        or rec.releasedAtHours ~= receipt.removedAtCountyHours
        or hours + 0.000001 < receipt.removedAtWorldHours then
        return false, "retirement-county-clock-mismatch" end
    local currentCountyHours = countyHours()
    if not currentCountyHours then
        return false, "retirement-county-clock-unavailable" end
    if currentCountyHours + 0.000001 < receipt.removedAtCountyHours then
        return false, "retirement-county-clock-regression" end
    if not exactPhysicalRemovalProof(rec, receipt.token,
        receipt.brainId, receipt.born) then
        return false, "physical-removal-proof-unavailable" end
    if phase.sourceBodyReturnObserved == true then
        return false, "source-body-return-unresolved" end
    if not sourceBodyLookupAvailable() then
        return true, "current-session-native-removal"
    end
    local okBody, sourceBody = pcall(BanditZombie.GetInstanceById,
        phase.brainId)
    if not okBody then return false, "source-body-lookup-failed" end
    if sourceBody ~= nil
        and sourceBody ~= physicalRemovalProofs[rec.id].body then
        phase.sourceBodyReturnObserved = true
        return false, "source-body-still-present" end
    return true, "current-session-native-removal"
end

function W.poll(forceQuery)
    local s = store()
    if not s or not SAO.Identity or not SAO.Claims then return end
    W.scrubLegacySourceOwners()
    W.stopStalePerformanceSounds()
    local performanceKeys = pollKeys(s.pendingPerformanceByPerson,
        "ClientPerformanceRows", 32)
    if performanceKeys then
        for n = 1, #performanceKeys do
            W.reconcilePerformanceOutcomes(performanceKeys[n])
        end
    end
    local cache = BanditZombie and BanditZombie.CacheLightB
    local cacheKeys = pollKeys(cache, "ClientCache", POLL_CACHE_VISITS)
    if cacheKeys then
        for n = 1, #cacheKeys do
            local light = cache[cacheKeys[n]]
            if light and light.brain
                and light.brain.saoWeekOneOrigin == OWNER
                and BanditZombie
                and type(BanditZombie.GetInstanceById) == "function" then
                local ok, body = pcall(BanditZombie.GetInstanceById, light.brain.id)
                if ok and body then W.assessForBandit(light.brain, body) end
            end
        end
    end
    local prune = {}
    local hours = now()
    local transitionFact, transitionReason, transitionChecked
    local rowKeys = pollKeys(s.byBrain, "ClientRows", POLL_PERSON_VISITS)
    if rowKeys then
        for n = 1, #rowKeys do
        local id = rowKeys[n]
        local row = s.byBrain[id]
        if type(row) == "table" then
        local rec = SAO.Identity.get(row.personId)
        if rec and rec.weekOne then
            if rec.dead or rec.weekOne.status ~= "external" then
                fastSoundObserved[rec.id] = nil
            end
            -- Failed staged-body removal retains its token and handle for
            -- retry even after death; settlement alone permits pruning.
            if rec.weekOne.stageToken then clearStage(rec) end
        end
        if rec and rec.weekOne and not rec.dead then
            W.reconcilePerformanceOutcomes(row.personId)
            if rec.weekOne.pending then
                complete(rec)
                if rec.weekOne.pending then queryPending(rec.weekOne.pending, forceQuery == true) end
            end
            if rec.weekOne.status == "dormant"
                and SAO.Claims.heldBy(rec) == OWNER then
                if not transitionChecked then
                    transitionFact, transitionReason = transitionClock(s)
                    transitionChecked = true
                    s.lastTransitionClockRefusal = transitionReason
                end
                local ready, basis = dormantHandoffReady(rec, row, hours)
                s.lastHandoffRefusal = ready and nil or basis
                if ready then
                    local legacyDue = transitionFact
                        and (transitionFact.legacyAgeHours >= 170
                            or finite(transitionFact.legacyDueObservedAtWorldHours)
                                and transitionFact.legacyDueObservedAtWorldHours
                                    <= transitionFact.atWorldHours)
                    if transitionFact and (rec.weekOne.bodyMode == "native"
                        or legacyDue) then
                        local intent, reason = transferChatIntent(rec)
                        if SAO.Claims.release(rec) == true then
                            rec.weekOne.status = "transferred"
                            row.status = "transferred"
                            rec.weekOne.handoffAge = {
                                ageHours = transitionFact.ageHours,
                                legacyAgeHours = transitionFact.legacyAgeHours,
                                legacyDueObservedAtWorldHours =
                                    transitionFact.legacyDueObservedAtWorldHours,
                                atWorldHours = transitionFact.atWorldHours,
                                startTimeOption = transitionFact.startTimeOption,
                                shiftHours = transitionFact.shiftHours,
                                sourceCompared = transitionFact.sourceCompared,
                                retirementBasis = basis }
                            if type(rec.weekOne.chatCompanion) == "table" then
                                rec.weekOne.chatHandoff = {
                                    status = intent and "carried" or "refused",
                                    reason = reason, atHours = rec.weekOne.retiredAtHours }
                            end
                            if intent then rec.playerCompanionIntent = intent end
                        end
                    end
                end
            end
        end
        if rec and rec.weekOne and not rec.weekOne.pending
            and not rec.weekOne.stageToken then
            if rec.dead or rec.weekOne.status == "transferred" then
                row.status = rec.dead and "dead" or "transferred"
                prune[#prune + 1] = { id = id, row = row, settled = true }
            elseif rec.weekOne.status == "external" and hours
                and finite(rec.weekOne.lastSeenHours)
                and hours >= rec.weekOne.lastSeenHours + 1
                and BanditZombie
                and type(BanditZombie.GetInstanceById) == "function" then
                local ok, body = pcall(BanditZombie.GetInstanceById, row.brainId)
                if ok and not body then
                    prune[#prune + 1] = { id = id, row = row, settled = false }
                end
            end
        end
        end
        end
    end
    for _, entry in ipairs(prune) do
        if s.byBrain[entry.id] == entry.row then
            archiveRow(s, entry.id, entry.row, entry.settled)
        end
    end
end

function W.installActiveAdapter()
    local family = ZombiePrograms and ZombiePrograms.Active
    if type(family) ~= "table" or type(family.Main) ~= "function" then
        return false, "active-program-unavailable"
    end
    if W.activeWrapped then
        return family.Main == W.activeWrapped,
            family.Main == W.activeWrapped and nil or "active-program-hook-changed"
    end
    local previous = family.Main
    local wrapped = function(body)
        local brain
        if body and BanditBrain and type(BanditBrain.Get) == "function" then
            local ok, source = pcall(BanditBrain.Get, body)
            if ok then brain = source end
        end
        if type(brain) == "table" and brain.saoWeekOneOrigin == OWNER then
            local ok, result = pcall(W.activeDecision, brain, body)
            if ok and result then return result end
        end
        -- A stamped actor keeps its private decision even when observation or
        -- exact-body admission must wait. Source Active.Main can select an
        -- unobserved target or a global escape on this path.
        if markedWeekOneActor(brain, body) then
            return { status = true, next = "Main", tasks = {} } end
        return previous(body)
    end
    W.activeWrapped = wrapped
    family.Main = wrapped
    return true
end

W.installActiveAdapter()

-- These are the Week One programs and the two Bandits base programs selected
-- by installed Week One scenarios. Source program names identify callbacks;
-- they do not establish SAO occupations, relationships or authority.
-- The source continues to supply the Bandits task actuator. Preparation is a
-- person admission and release of the proxy's stationary pose; it never grants
-- a random possession or faces the local player without an observation.
local WEEK_ONE_PROGRAMS = {
    "Active", "ArmyGuard", "Babe", "Bandit", "BanditSimple", "Companion",
    "CompanionGuard", "Entertainer",
    "Fireman", "Gardener", "Inhabitant", "Janitor", "Medic",
    "Passenger", "Patrol", "Police", "Postal", "RiotPolice",
    "Runner", "Shahid", "Survivor", "Vandal", "Walker",
}
local ownedStages = {
    ArmyGuard = { Main = true },
    Bandit = { Main = true, Escape = true, Surrender = true },
    BanditSimple = { Init = true, Main = true },
    Inhabitant = { Defend = true },
    Police = { Main = true, Escape = true, Follow = true },
    Shahid = { Main = true },
    Active = { Escape = true, Wait = true },
    Medic = { Walk = true },
    Survivor = { Main = true },
}
local ordinaryStages = {
    Babe = { Main = true, Guard = true, Base = true },
    Companion = { Main = true, Guard = true },
    CompanionGuard = { Main = true },
    Entertainer = { Main = true },
    Fireman = { Main = true },
    Gardener = { Main = true },
    Inhabitant = { Main = true },
    Janitor = { Main = true },
    Medic = { Main = true },
    Passenger = { Main = true },
    Patrol = { Main = true },
    Postal = { Main = true },
    RiotPolice = { Main = true },
    Runner = { Main = true },
    Vandal = { Main = true },
    Walker = { Main = true },
}
local programWrapped = W.programWrapped or {}
W.programWrapped = programWrapped

local function sourceStage(brain, body, family, stage)
    return type(brain) == "table" and brain.saoWeekOneOrigin == OWNER
        and type(brain.program) == "table"
        and brain.program.name == family and brain.program.stage == stage
        and currentBody(brain, body)
end

local function stagePerson(brain, body)
    local personId, reason = W.observeBrain(brain, body)
    if not personId then return nil, reason end
    local rec = SAO.Identity.get(personId)
    if not rec or not rec.weekOne or rec.weekOne.pending
        or SAO.Claims.heldBy(rec) ~= OWNER then return nil, "owner-changed" end
    return rec.weekOne
end

local function stageResult(nextStage, tasks)
    return { status = true, next = nextStage, tasks = tasks or {} }
end

function W.prepareProgram(brain, body, family)
    if not sourceStage(brain, body, family, "Prepare") then
        return nil, "source-stage-mismatch" end
    local phase, reason = stagePerson(brain, body)
    if not phase then return nil, reason end
    if not (Bandit and type(Bandit.ForceStationary) == "function") then
        return nil, "source-pose-unavailable" end
    local ok = pcall(Bandit.ForceStationary, body, false)
    if not ok then return nil, "source-pose-failed" end
    phase.decision = { kind = "prepare", adapter = family .. ".Prepare",
        source = "sao-person", atHours = now() }
    return stageResult("Main")
end

local function acceptedStagePlan(brain, body)
    local plan, reason = W.planForBandit(brain, body)
    if not plan then return nil, reason end
    local phase = exactActivePlan(brain, body, plan)
    if not phase then return nil, "source-plan-mismatch" end
    return plan, phase
end

local function planMove(plan)
    if plan.kind ~= "move" or plan.source ~= "sao-observed"
        or (plan.targetKind ~= "zombie" and plan.targetKind ~= "person")
        or not (finite(plan.x) and finite(plan.y) and finite(plan.z)
            and finite(plan.dist) and plan.dist > 0 and plan.dist <= 14)
        or (plan.walkType ~= "Walk" and plan.walkType ~= "Run"
            and plan.walkType ~= "WalkAim")
        or not (BanditUtils and type(BanditUtils.GetMoveTask) == "function") then
        return nil end
    local ok, task = pcall(BanditUtils.GetMoveTask, 0,
        plan.x, plan.y, plan.z, plan.walkType, plan.dist)
    return ok and task or nil
end

local function planRest(plan)
    if plan.kind ~= "fallback" or plan.source ~= "sao-person-appraisal"
        or not (finite(plan.duration) and plan.duration % 1 == 0
            and plan.duration >= 60 and plan.duration <= 400)
        or (plan.anim ~= "ShiftWeight" and plan.anim ~= "ChewNails"
            and plan.anim ~= "WipeBrow" and plan.anim ~= "WipeHead"
            and plan.anim ~= "PullAtCollar") then return nil end
    return { action = "Time", anim = plan.anim, time = plan.duration }
end

local function escapeTask(body, plan)
    if plan.kind ~= "move" or plan.source ~= "sao-observed"
        or not (finite(plan.x) and finite(plan.y) and finite(plan.z))
        or not (BanditUtils and type(BanditUtils.GetMoveTask) == "function")
        or type(getCell) ~= "function" then return nil end
    local ok, x, y, z = pcall(function()
        return body:getX(), body:getY(), body:getZ() end)
    if not ok or not (finite(x) and finite(y) and finite(z)) then return nil end
    local dx, dy = x - plan.x, y - plan.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.1 then return nil end
    local ux, uy = dx / length, dy / length
    local choices = {
        { ux, uy }, { ux - uy * 0.5, uy + ux * 0.5 },
        { ux + uy * 0.5, uy - ux * 0.5 },
    }
    local okCell, cell = pcall(getCell)
    if not okCell or not cell or type(cell.getGridSquare) ~= "function" then
        return nil end
    for _, direction in ipairs(choices) do
        local tx = math.floor(x + direction[1] * 5 + 0.5)
        local ty = math.floor(y + direction[2] * 5 + 0.5)
        local okSquare, square = pcall(function()
            return cell:getGridSquare(tx, ty, z) end)
        local okFree, free = pcall(function()
            return square and square:isFree(false) end)
        if okSquare and square and okFree and free == true then
            local okTask, task = pcall(BanditUtils.GetMoveTask, 0,
                tx, ty, z, "Run", 5, false)
            if okTask and task then return task, tx, ty, z end
        end
    end
    return nil
end

local function visibleFeature(body, square, kind)
    if not (SAOJavaBridge and SAOJavaBridge.weekOneObservedFeature
        and square) then return false end
    local ok, admitted = pcall(function()
        return SAOJavaBridge:weekOneObservedFeature(body, square, kind)
    end)
    return ok and admitted == true
end

-- Role sensing is a bounded local read of loaded physical squares. The native
-- bridge checks source body/world identity, facing, occlusion and feature type
-- at use time. Source global marker tables never select an action target.
local function nearbyFeature(body, kind, radius, minimum)
    local ok, cell, x, y, z = pcall(function()
        return body:getCell(), body:getX(), body:getY(), body:getZ()
    end)
    if not ok or not cell or not (finite(x) and finite(y) and finite(z))
        or radius > 8 or radius < 0 then return nil end
    local bx, by = math.floor(x), math.floor(y)
    local best, bestDistance
    for dx = -radius, radius do
        for dy = -radius, radius do
            local distance = dx * dx + dy * dy
            if distance <= radius * radius and distance >= (minimum or 0) ^ 2
                and (not bestDistance or distance < bestDistance) then
                local square = cell:getGridSquare(bx + dx, by + dy, z)
                if visibleFeature(body, square, kind) then
                    best, bestDistance = square, distance
                end
            end
        end
    end
    return best, bestDistance and math.sqrt(bestDistance) or nil
end

local function featureObject(body, square, kind)
    if not square then return nil end
    local ok, objects = pcall(function() return square:getObjects() end)
    if not ok or not objects or not objects.size or not objects.get then return nil end
    local count = math.min(objects:size(), 24)
    for index = 0, count - 1 do
        local object = objects:get(index)
        if visibleFeature(body, object, kind) then return object end
    end
    return nil
end

local function physicalItem(body, itemType)
    local ok, item = pcall(function()
        local primary = body:getPrimaryHandItem()
        if primary and primary:getFullType() == itemType then return primary end
        local secondary = body:getSecondaryHandItem()
        if secondary and secondary:getFullType() == itemType then return secondary end
        return nil
    end)
    return ok and item or nil
end

local function physicalExtinguisher(body)
    local base = physicalItem(body, "Base.Extinguisher")
    local okBase, amount = pcall(function()
        return base and base:getCurrentUsesFloat() or nil end)
    if okBase and finite(amount) and amount >= 0.1 then return base end
    local bwo = physicalItem(body, "Bandits.Extinguisher")
    local okBwo, condition = pcall(function()
        return bwo and bwo:getCondition() or nil end)
    if okBwo and finite(condition) and condition >= 1 then return bwo end
    return nil
end

local function consumeExtinguisher(item)
    if not item then return false end
    local ok, consumed = pcall(function()
        if item:getFullType() == "Base.Extinguisher" then
            local before = item:getCurrentUsesFloat()
            if not finite(before) or before < 0.1 then return false end
            item:setCurrentUsesFloat(math.max(0, before - 0.1))
            return item:getCurrentUsesFloat() < before
        end
        local before = item:getCondition()
        if not finite(before) or before < 1 then return false end
        item:setCondition(before - 1)
        return item:getCondition() < before
    end)
    return ok and consumed == true
end

local function carriedItem(body, itemType)
    local ok, item = pcall(function()
        return body:getInventory():getItemFromType(itemType)
    end)
    return ok and item or nil
end

-- The selected item is already in this body's hands. A private appraisal
-- chooses whether its physical blast is worth the risk; the source program
-- name, hit callback and saved Shahid fields never choose this action.
local function heldPipeBomb(body)
    local item = physicalItem(body, "Base.PipeBomb")
    local ok, valid, id, radius, reach = pcall(function()
        local inventory = body:getInventory()
        return inventory and inventory:contains(item)
            and item:isInstantExplosion() and item:getFullType() == "Base.PipeBomb",
            item:getID(), item:getExplosionRange(), item:getMaxRange()
    end)
    if not ok or not valid or not finite(id) or id < 0
        or not finite(radius) or radius < 1 or radius > 7
        or not finite(reach) or reach < 9 then return nil end
    return item, id, radius, math.min(reach, 10)
end

local function explosiveItemUsed(phase, itemId)
    return phase.explosiveUse and phase.explosiveUse.itemId == itemId
        or type(phase.explosiveUses) == "table"
            and phase.explosiveUses[tostring(itemId)] ~= nil
end

local function observedBombTarget(brain, body, plan, phase, radius, reach)
    if not (type(plan) == "table" and plan.kind == "move"
        and plan.source == "sao-observed" and plan.targetKind == "zombie"
        and plan.actorId == phase.appraisal.actorId
        and plan.brainId == brain.id and plan.born == brain.born
        and plan.atTick == plan.observedAtTick
        and type(phase.decision) == "table"
        and type(phase.decision.targetKey) == "string"
        and phase.decision.targetKey ~= "") then return nil end
    local beliefs = SAO.Perception and SAO.Perception.beliefs
        and SAO.Perception.beliefs[plan.actorId]
    local seen
    for _, candidate in pairs(beliefs and beliefs.zombies or {}) do
        if type(candidate) == "table"
            and candidate.track == phase.decision.targetKey then
            seen = candidate break end
    end
    if not (beliefs and beliefs.lastScanAt == plan.observedAtTick
        and type(seen) == "table" and seen.source == "observed"
        and seen.at == plan.observedAtTick) then return nil end
    local target = nativeTarget(body, "zombie", phase.decision.targetKey)
    if not target then return nil end
    local ok, x, y, z, cell = pcall(function()
        return body:getX(), body:getY(), body:getZ(), body:getCell() end)
    if not ok or not (finite(x) and finite(y) and finite(z) and cell)
        or math.floor(z) ~= math.floor(target.z) then return nil end
    local distance = math.sqrt((x - target.x)^2 + (y - target.y)^2)
    if distance < radius + 1.5 or distance > reach then return nil end
    local tx, ty, tz = math.floor(target.x), math.floor(target.y),
        math.floor(target.z)
    local square = cell:getGridSquare(tx, ty, tz)
    if not square then return nil end
    for _, person in pairs(beliefs.people or {}) do
        if type(person) == "table" and person.source == "observed"
            and person.at == plan.observedAtTick
            and finite(person.x) and finite(person.y)
            and math.sqrt((person.x - target.x)^2
                + (person.y - target.y)^2) <= radius + 1 then return nil end
    end
    local nearbyThreats = 0
    for _, other in pairs(beliefs.zombies or {}) do
        if type(other) == "table" and other.source == "observed"
            and other.at == plan.observedAtTick
            and finite(other.x) and finite(other.y)
            and math.sqrt((other.x - target.x)^2
                + (other.y - target.y)^2) <= radius then
            nearbyThreats = nearbyThreats + 1
        end
    end
    if nearbyThreats < 2 then return nil end
    return square, { x = tx, y = ty, z = tz,
        targetX = target.x, targetY = target.y, distance = distance }
end

-- Execution checks physical occupancy too. Unloaded squares and unknown or
-- human moving objects make the throw unsafe. This is a bounded hazard check,
-- not a source of person knowledge or a new target for the decision.
local function clearBlastArea(body, square, radius)
    if not instanceof then return false end
    local cell = body:getCell()
    local ordinaryZombies = 0
    for dx = -radius, radius do
        for dy = -radius, radius do
            if dx * dx + dy * dy <= (radius + 0.5)^2 then
                local localSquare = cell:getGridSquare(square:getX() + dx,
                    square:getY() + dy, square:getZ())
                if not localSquare then return false end
                local moving = localSquare:getMovingObjects()
                if not moving or moving:size() > 32 then return false end
                for index = 0, moving:size() - 1 do
                    local actor = moving:get(index)
                    if actor and not instanceof(actor, "IsoZombie") then
                        return false end
                    if actor and instanceof(actor, "IsoZombie") then
                        local ok, md, sourcePerson, knoxPerson, risen = pcall(function()
                            return actor:getModData(),
                                actor:getVariableBoolean("Bandit"),
                                actor:getVariableBoolean("KnoxSurvivor")
                                    or actor:getVariableBoolean("KnoxSurvivorShell"),
                                actor:isReanimatedPlayer()
                        end)
                        if not ok or type(md) ~= "table"
                            or sourcePerson or knoxPerson or risen
                            or md.SAOWeekOneOrigin or md.SAOPersonId
                            or md.KnoxSurvivorId or md.KnoxSurvivorProfileId
                            or md.KnoxSurvivor or md.KnoxSurvivorShell
                            or md.ZAOOwned then
                            return false end
                        ordinaryZombies = ordinaryZombies + 1
                    end
                end
            end
        end
    end
    return ordinaryZombies >= 2
end

function W.explosiveTaskForObserved(brain, body, plan, phase)
    local frame = phase and phase.appraisal
    local rec = type(plan) == "table" and SAO.Identity
        and SAO.Identity.get and SAO.Identity.get(plan.actorId)
    if not (type(plan) == "table" and type(frame) == "table"
        and frame.actorId == plan.actorId
        and frame.brainId == brain.id and frame.born == brain.born
        and frame.atTick == plan.atTick and frame.observedThreats >= 2
        and finite(frame.aggression) and finite(frame.nerve)
        and finite(frame.discipline) and finite(frame.selfPreservation)
        and frame.aggression > frame.selfPreservation
        and frame.nerve > frame.selfPreservation
        and frame.discipline > 0
        and currentBody(brain, body) and phase.status == "external"
        and not phase.pending and not phase.stageToken
        and rec and SAO.Claims and SAO.Claims.heldBy(rec) == OWNER)
        then return nil, "person-decision-unavailable" end
    local item, itemId, radius, reach = heldPipeBomb(body)
    if not item or explosiveItemUsed(phase, itemId) then
        return nil, "physical-item-unavailable" end
    local square, geometry = observedBombTarget(brain, body, plan, phase,
        radius, reach)
    if not square then return nil, "safe-target-unavailable" end
    if not clearBlastArea(body, square, radius) then
        return nil, "blast-area-occupied" end
    return { action = "SAOThrowExplosive", time = 10,
        saoWeekOnePersonId = plan.actorId, saoWeekOneBrainId = brain.id,
        saoWeekOneBorn = brain.born, saoWeekOneAtTick = plan.atTick,
        saoObservedAtTick = plan.observedAtTick,
        saoTargetKind = "zombie", saoTargetKey = phase.decision.targetKey,
        saoItemId = itemId, saoRadius = radius,
        x = geometry.x, y = geometry.y, z = geometry.z }
end

function W.executeExplosiveTask(body, task)
    local phase = actionPhase and actionPhase(body, task)
    if not phase or not (type(task) == "table"
        and task.action == "SAOThrowExplosive"
        and task.saoTargetKind == "zombie"
        and finite(task.saoItemId) and finite(task.saoRadius)
        and phase.decision and phase.decision.kind == "attack"
        and phase.decision.attackMethod == "native-pipe-bomb"
        and phase.decision.targetKey == task.saoTargetKey
        and phase.appraisal and phase.appraisal.atTick == task.saoObservedAtTick)
        then return false, "action-owner-changed" end
    if explosiveItemUsed(phase, task.saoItemId) then
        return false, "item-already-used" end
    local okTick, tick = pcall(SAO.History.ticks)
    if not okTick or not finite(tick) or tick < task.saoWeekOneAtTick
        or tick - task.saoWeekOneAtTick >= 20 then
        return false, "private-sight-stale" end
    local item, itemId, radius, reach = heldPipeBomb(body)
    if not item or itemId ~= task.saoItemId or radius ~= task.saoRadius then
        return false, "item-identity-changed" end
    local brain = BanditBrain.Get(body)
    local square, geometry = observedBombTarget(brain, body,
        { kind = "move", source = "sao-observed", targetKind = "zombie",
          actorId = task.saoWeekOnePersonId, brainId = task.saoWeekOneBrainId,
          born = task.saoWeekOneBorn, atTick = task.saoObservedAtTick,
          observedAtTick = task.saoObservedAtTick }, phase, radius, reach)
    if not square or geometry.x ~= task.x or geometry.y ~= task.y
        or geometry.z ~= task.z or not clearBlastArea(body, square, radius) then
        return false, "safe-target-changed" end
    if not (isClient and isClient() == false
        and IsoTrap and IsoTrap.new) then
        return false, "native-blast-unavailable" end
    local okTrap, trap = pcall(IsoTrap.new, body, item,
        square:getCell(), square)
    if not okTrap or not trap or trap:getHandWeapon() ~= item then
        return false, "native-trap-unavailable" end
    if phase.explosiveUses ~= nil
        and type(phase.explosiveUses) ~= "table" then
        return false, "explosive-history-invalid" end
    -- The durable commit precedes the irreversible inventory removal. A
    -- retry after an exception or reload cannot consume or explode it twice.
    phase.explosiveUse = { schema = "sao-explosive-use/1",
        source = "sao-person-native-trap", personId = task.saoWeekOnePersonId,
        itemId = itemId, itemType = "Base.PipeBomb",
        brainId = brain.id, born = brain.born,
        targetKind = "zombie", targetKey = task.saoTargetKey,
        x = task.x, y = task.y, z = task.z, radius = radius,
        atTick = tick, atHours = now(), status = "committing" }
    phase.explosiveUses = phase.explosiveUses or {}
    phase.explosiveUses[tostring(itemId)] = phase.explosiveUse
    local okRemove = pcall(function()
        body:removeFromHands(item)
        body:getInventory():Remove(item)
    end)
    local inventory = body:getInventory()
    if not okRemove or inventory:contains(item) then
        phase.explosiveUse.status = "removal-unverified"
        return false, "item-removal-unverified" end
    local okPlace = pcall(function() trap:place() end)
    phase.explosiveUse.status = okPlace
        and "native-trap-placed" or "native-call-uncertain"
    return okPlace, phase.explosiveUse.status
end

-- BWOPlayer's exact OnHitZombie closure is transport for a physical hit.
-- A program name, a carried explosive, and being hit supply no decision to
-- detonate. This stores bounded person evidence for later SAO appraisal.
function W.onShahidHit(brain, body, attacker, weapon)
    if type(brain) ~= "table" or not currentBody(brain, body) then
        return false, "source-or-body-mismatch" end
    local personId, reason = W.observeBrain(brain, body)
    if not personId then return false, reason end
    local rec = SAO.Identity and SAO.Identity.get(personId)
    local phase = rec and rec.weekOne
    if not phase or phase.pending or not SAO.Claims
        or SAO.Claims.heldBy(rec) ~= OWNER then
        return false, "owner-changed" end
    local atHours = now()
    local okBody, bx, by, bz = pcall(function()
        return body:getX(), body:getY(), body:getZ() end)
    if not atHours or not okBody
        or not (finite(bx) and finite(by) and finite(bz)) then
        return false, "physical-hit-time-or-body-unavailable" end

    local hitTick
    if SAO.History and SAO.History.ticks then
        local okTick, tick = pcall(SAO.History.ticks)
        if okTick and finite(tick) and tick >= 0 then hitTick = tick end
    end
    local okScan, frame, appraisalReason = pcall(W.assessForBandit, brain, body)
    if not okScan then frame, appraisalReason = nil, "private-scan-error" end
    if type(frame) ~= "table" then frame = nil end
    local beliefs = frame and SAO.Perception
        and SAO.Perception.beliefs
        and SAO.Perception.beliefs[personId]
    local identified, privateScanAtTick
    if frame and frame.actorId == personId and type(beliefs) == "table"
        and beliefs.lastScanAt == frame.atTick
        and SAOJavaBridge
        and SAOJavaBridge.weekOneObservedAttacker then
        privateScanAtTick = frame.atTick
        local function exactSeen(kind, key)
            local ok, same = pcall(function()
                return SAOJavaBridge:weekOneObservedAttacker(
                    body, attacker, kind, key) end)
            return ok and same == true
        end
        for name, seen in pairs(type(beliefs.people) == "table"
            and beliefs.people or {}) do
            if type(name) == "string" and type(seen) == "table"
                and seen.source == "observed"
                and seen.at == frame.atTick
                and exactSeen("person", name) then
                identified = { kind = "person", key = name,
                    source = "private-scan-and-current-native-identity" }
                break
            end
        end
        if not identified then
            for _, seen in pairs(type(beliefs.zombies) == "table"
                and beliefs.zombies or {}) do
                if type(seen) == "table" and seen.source == "observed"
                    and seen.at == frame.atTick
                    and type(seen.track) == "string"
                    and exactSeen("zombie", seen.track) then
                    identified = { kind = "zombie", key = seen.track,
                        source = "private-scan-and-current-native-identity" }
                    break
                end
            end
        end
    end
    local okAttacker, ax, ay, az = pcall(function()
        return attacker:getX(), attacker:getY(), attacker:getZ() end)
    local attackerPosition
    if okAttacker and finite(ax) and finite(ay) and finite(az) then
        attackerPosition = { x = ax, y = ay, z = az } end
    local okWeapon, weaponType = pcall(function()
        return weapon:getFullType() end)
    if not okWeapon or type(weaponType) ~= "string"
        or weaponType == "" then weaponType = nil end

    phase.lastPhysicalHit = {
        source = "native-OnHitZombie",
        transport = "BWOPlayer.onHitZombie",
        brainId = brain.id, born = brain.born,
        atHours = atHours, atTick = hitTick,
        body = { x = bx, y = by, z = bz },
        attacker = identified, attackerPosition = attackerPosition,
        privateScanAtTick = privateScanAtTick,
        privateStatus = identified and "identified"
            or appraisalReason or "attacker-unidentified",
        weaponType = weaponType,
        carriedExplosive = carriedItem(body, "Base.PipeBomb")
            and "Base.PipeBomb" or nil,
        action = "none",
        actionReason = "no-sao-explosive-decision",
    }
    return true, "hit-recorded-no-action"
end

local function physicalBandage(body)
    local ok, bandage = pcall(function()
        local inventory = body:getInventory()
        local items = inventory and inventory:getItems()
        if not items then return nil end
        for index = 0, math.min(items:size(), 128) - 1 do
            local item = items:get(index)
            if item and inventory:contains(item)
                and item:isCanBandage() and item:getBandagePower() > 0
                and not item:isInfected() then return item end
        end
        return nil
    end)
    return ok and bandage or nil
end

local function taskNear(body, square, maxDistance, walkType)
    if not square or not (BanditUtils
        and type(BanditUtils.GetMoveTask) == "function") then return nil end
    local ok, x, y, z = pcall(function()
        return square:getX(), square:getY(), square:getZ() end)
    if not ok or not (finite(x) and finite(y) and finite(z)) then return nil end
    local dx, dy = body:getX() - (x + 0.5), body:getY() - (y + 0.5)
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= maxDistance then return false, distance end
    if distance > 11 then return nil end
    local built, task = pcall(BanditUtils.GetMoveTask, 0,
        x, y, z, walkType or "Walk", distance, false)
    return built and task or nil, distance
end

local function observedCompanion(body, personId, tick)
    local beliefs = SAO.Perception and SAO.Perception.beliefs
        and SAO.Perception.beliefs[personId]
    if not beliefs or beliefs.lastScanAt ~= tick
        or not (SAO.Standing and SAO.Standing.keyForObserved
            and SAO.Standing.trust) then return nil end
    local rec = SAO.Identity and SAO.Identity.get(personId)
    local addressed = rec and rec.weekOne and rec.weekOne.chatCompanion
    local addressedKey = addressed and addressed.playerKey
    local player = addressedKey and getSpecificPlayer and getSpecificPlayer(0)
    if addressedKey and (not player or not SAO.Standing.playerKey
        or SAO.Standing.playerKey(player) ~= addressedKey) then return nil end
    local chosen, best
    for name, seen in pairs(beliefs.people or {}) do
        if type(name) == "string" and type(seen) == "table"
            and seen.source == "observed" and seen.at == tick then
            local key = SAO.Standing.keyForObserved(name)
            local trust = key and SAO.Standing.trust(personId, key)
            local exact = not addressedKey or key == addressedKey
            if exact and addressedKey then
                local ok, same = pcall(function()
                    return SAOJavaBridge:weekOneObservedAttacker(
                        body, player, "person", name)
                end)
                exact = ok and same == true
            end
            if exact and finite(trust) and trust > 0 then
                local target = nativeTarget(body, "person", name)
                if target and (not best or target.dist < best.dist) then
                    chosen, best = { name = name, key = key }, target
                end
            end
        end
    end
    return chosen, best
end

local function observedCare(body, personId, tick)
    local beliefs = SAO.Perception and SAO.Perception.beliefs
        and SAO.Perception.beliefs[personId]
    if not beliefs or beliefs.lastScanAt ~= tick
        or not (SAOJavaBridge and SAOJavaBridge.weekOneObservedCareTarget)
        then return nil end
    local chosen, best
    for name, seen in pairs(beliefs.people or {}) do
        if type(name) == "string" and type(seen) == "table"
            and seen.source == "observed" and seen.at == tick then
            local ok, packed = pcall(function()
                return SAOJavaBridge:weekOneObservedCareTarget(body, name)
            end)
            if ok and type(packed) == "string" then
                local sx, sy, sz, sd, sh = packed:match(
                    "^CARE\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
                local x, y, z, dist, health = tonumber(sx), tonumber(sy),
                    tonumber(sz), tonumber(sd), tonumber(sh)
                if finite(x) and finite(y) and finite(z)
                    and finite(dist) and dist > 0 and dist <= 14
                    and finite(health) and health > 0
                    and (not best or dist < best.dist) then
                    chosen, best = name,
                        { x = x, y = y, z = z, dist = dist, health = health }
                end
            end
        end
    end
    return chosen, best
end

local function unpaintedWall(body, radius)
    local square = nearbyFeature(body, "wall", radius)
    if not square then return nil end
    local wall, direction
    for _, candidate in ipairs({ { true, "N" }, { false, "W" } }) do
        local object = square:getWall(candidate[1])
        if object and visibleFeature(body, object, "wall") then
            wall, direction = object, candidate[2]
            break
        end
    end
    if not wall then return nil end
    local cell = body:getCell()
    for offset = -1, 1 do
        local neighbor = direction == "N"
            and cell:getGridSquare(square:getX() + offset,
                square:getY(), square:getZ())
            or cell:getGridSquare(square:getX(),
                square:getY() + offset, square:getZ())
        if not neighbor or not visibleFeature(body, neighbor, "wall") then
            return nil end
        local section = neighbor:getWall(direction == "N")
        if not section then return nil end
        local attachments = section:getAttachedAnimSprite()
        if attachments then
            for index = 0, math.min(attachments:size(), 24) - 1 do
                local sprite = attachments:get(index)
                local name = sprite and sprite:getName()
                if type(name) == "string" and
                    (name:find("graffiti", 1, true)
                        or name:find("message", 1, true)) then
                    return nil
                end
            end
        end
    end
    return square, direction
end

local function roadTask(body, walkType)
    local ok, cell, x, y, z, forward = pcall(function()
        return body:getCell(), body:getX(), body:getY(), body:getZ(),
            body:getForwardDirection()
    end)
    if not ok or not cell or not forward then return nil end
    local fx, fy = forward:getX(), forward:getY()
    if not (finite(fx) and finite(fy) and finite(x) and finite(y)
        and finite(z)) then return nil end
    local bx, by = math.floor(x), math.floor(y)
    local best, score
    for dx = -6, 6 do
        for dy = -6, 6 do
            local dist2 = dx * dx + dy * dy
            if dist2 >= 9 and dist2 <= 36 then
                local projection = dx * fx + dy * fy
                if projection > 1 and (not score or projection > score) then
                    local square = cell:getGridSquare(bx + dx, by + dy, z)
                    if visibleFeature(body, square, "road") then
                        best, score = square, projection
                    end
                end
            end
        end
    end
    if not best then return nil end
    local task = taskNear(body, best, 1.0, walkType)
    return task, best
end

-- Source program and stage select a compatibility callback. Ordinary action
-- selection belongs to the person and current physical evidence instead.
local PERFORMANCE_INSTRUMENTS = {
    ["Base.GuitarElectric"] = { anim = "InstrumentGuitarBass", sound = "BWOInstrumentBassGuitar1" },
    ["Base.Violin"] = { anim = "InstrumentViolin", sound = "BWOInstrumentViolinPaganini" },
    ["Base.Saxophone"] = { anim = "InstrumentSaxophone", sound = "BWOInstrumentSax1" },
}
local PERFORMANCE_ORDER = { "Base.GuitarElectric", "Base.Violin", "Base.Saxophone" }

-- Only this person's authenticated, performed outcomes inform a repeat
-- attempt. Hearing another person is separate evidence and never becomes an
-- own result here. The latest matching attempt can challenge an earlier one.
local function ownInstrumentAttempts(actorId, atHours)
    local rec = SAO.Identity and SAO.Identity.get(actorId)
    local rows = rec and rec.cognition and rec.cognition.experiences
    local models = SAO.CognitiveModels
    local latest = {}
    if type(rows) ~= "table" or #rows > 256
        or not (models and type(models.acceptsExperience) == "function") then
        return latest end
    for _, row in ipairs(rows) do
        if type(row) == "table" and PERFORMANCE_INSTRUMENTS[row.itemType]
            and (row.kind == "weekone-instrument-performance"
                or row.kind == "instrument-use" or row.kind == "leisure-music")
            and row.actorId == actorId and row.observerId == actorId
            and row.perspective == "performed" and row.status == "completed"
            and finite(row.occurredAtHours) and row.occurredAtHours <= atHours then
            local okEvidence, accepted = pcall(models.acceptsExperience, row)
            if okEvidence and accepted then
            local prior = latest[row.itemType]
            if not prior or row.occurredAtHours > prior.occurredAtHours
                or row.occurredAtHours == prior.occurredAtHours
                    and row.worldHours >= prior.worldHours then
                latest[row.itemType] = row
            end
            end
        end
    end
    return latest
end

local function currentLeisurePressure(actorId, brain, body)
    -- A Week One proxy is an IsoZombie. SAO.Needs reads native SAO shells,
    -- while IsoZombie does not update human fatigue. Bandits2 does update its
    -- own action endurance on source tasks. Read that narrower measured value
    -- only through the exact live person/body/generation crosswalk.
    local exactBody, exactBrain = W.sourceBodyFor(actorId)
    if exactBody ~= body or type(exactBrain) ~= "table"
        or exactBrain.id ~= brain.id or exactBrain.born ~= brain.born
        or not finite(exactBrain.endurance)
        or exactBrain.endurance < 0 or exactBrain.endurance > 1 then
        return nil end
    return { sourceEndurance = exactBrain.endurance,
        source = "Bandits2:action-endurance" }
end

local function choiceRecord(phase, actorId, plan, candidates, views, needs)
    local record = { actorId = actorId, atTick = plan.atTick,
        atHours = views.atHours, selected = views.selected,
        selectedModelId = views.selectedModelId,
        pressure = needs and 1 - needs.sourceEndurance or nil,
        sourceEndurance = needs and needs.sourceEndurance or nil,
        pressureSource = needs and needs.source or nil,
        alternatives = candidates, models = {} }
    for _, model in ipairs(views.models or {}) do
        local ranked = {}
        for _, row in ipairs(model.ranked or {}) do
            ranked[#ranked + 1] = { id = row.id, score = row.score,
                predictions = row.predictions }
        end
        record.models[#record.models + 1] = {
            modelId = model.modelId, selected = model.selected, ranked = ranked }
    end
    if views.heardMusicInterest then
        record.heardMusicInterest = views.heardMusicInterest end
    phase.leisureComparison = record
end

local function ordinaryChoice(brain, body, phase, plan)
    local actorId = phase.appraisal and phase.appraisal.actorId
    if actorId ~= plan.actorId then
        return nil, "person-appraisal-mismatch" end

    if phase.chatCompanion then
        -- This intent exists only after heard speech passed Standing. A
        -- source Companion, Guard or legacy Babe label grants nothing here.
        local mode = phase.chatMode
        if mode == "hold" then return nil, "holding-after-heard-request" end
        if mode == "home" then
            local home = phase.sourceHome
            if not home and type(brain.bornCoords) == "table"
                and finite(brain.bornCoords.x) and finite(brain.bornCoords.y)
                and finite(brain.bornCoords.z) then
                home = { x = brain.bornCoords.x, y = brain.bornCoords.y,
                    z = brain.bornCoords.z, source = "source-lived-origin" }
                phase.sourceHome = home
            end
            if not home then return nil, "source-home-unavailable" end
            local cell = body:getCell()
            local square = cell and cell:getGridSquare(home.x, home.y, home.z)
            if not visibleFeature(body, square, "ground") then
                return nil, "source-home-not-currently-visible" end
            local move = taskNear(body, square, 2.0, "Walk")
            if move then return { move }, "return-visible-home", square end
            if move == false then return nil, "arrived-visible-home", square end
            return nil, "home-route-unavailable"
        end
        if mode ~= "follow" then
            return nil, "no-current-association-request" end
        local companion, target = observedCompanion(body,
            actorId, plan.observedAtTick)
        if not companion or not target then
            return nil, "no-observed-trusted-companion" end
        phase.companion = { key = companion.key, name = companion.name,
            source = "private-sight-and-standing",
            atTick = plan.observedAtTick }
        if target.dist <= 3 then
            return nil, "beside-observed-companion" end
        local ok, task = pcall(BanditUtils.GetMoveTask, 0,
            target.x, target.y, target.z, "Walk", target.dist, false)
        if ok and task then
            return { task }, "follow-trusted-companion",
                { getX = function() return target.x end,
                  getY = function() return target.y end,
                  getZ = function() return target.z end }
        end
        return nil, "companion-route-unavailable"
    end

    -- Each world read is gated by an actual carried or equipped means. The
    -- local search radii and the native visibility check remain bounded.
    if physicalExtinguisher(body) then
        local fire = nearbyFeature(body, "fire", 8)
        if fire then
            if not (AdjacentFreeTileFinder
                and type(AdjacentFreeTileFinder.Find) == "function") then
                return nil, "fire-approach-unavailable" end
            local ok, standing = pcall(AdjacentFreeTileFinder.Find, fire, body)
            if not ok or not visibleFeature(body, standing, "ground") then
                return nil, "no-visible-fire-approach" end
            local move = taskNear(body, standing, 2.5, "Run")
            if move then return { move }, "approach-fire", fire end
            if move == nil then
                return nil, "fire-approach-unavailable" end
            return {{ action = "SAOExtinguishFire", anim = "Extinguish",
                saoSound = "BWOExtinguish", time = 120,
                x = fire:getX(), y = fire:getY(), z = fire:getZ() }},
                "extinguish-visible-fire", fire
        end
    end

    if physicalBandage(body) then
        local name, patient = observedCare(body,
            actorId, plan.observedAtTick)
        if name then
            phase.careNeed = { name = name, health = patient.health,
                atTick = plan.observedAtTick,
                source = "native-visible-patient" }
            if patient.dist > 2.0 then
                local ok, task = pcall(BanditUtils.GetMoveTask, 0,
                    patient.x, patient.y, patient.z, "Walk",
                    patient.dist, false)
                if ok and task then
                    return { task }, "approach-injured-person",
                        { getX = function() return patient.x end,
                          getY = function() return patient.y end,
                          getZ = function() return patient.z end }
                end
                return nil, "care-route-unavailable"
            end
            return {{ action = "SAOBandagePerson", anim = "Loot",
                time = 120, saoPatientName = name, personId = actorId,
                brainId = brain.id, born = brain.born }},
                "bandage-visible-bleeding-person",
                { getX = function() return patient.x end,
                  getY = function() return patient.y end,
                  getZ = function() return patient.z end }
        end
    end

    if physicalItem(body, "Base.Broom") then
        local square = nearbyFeature(body, "trash", 7)
        if square then
            local move = taskNear(body, square, 0.8, "Walk")
            if move then return { move }, "approach-trash", square end
            if move == nil then
                return nil, "trash-approach-unavailable" end
            return {{ action = "SAOCleanTrash", customName = "Trash",
                anim = "Rake", time = 300, x = square:getX(),
                y = square:getY(), z = square:getZ() }},
                "remove-visible-trash", square
        end
    end

    local water = physicalItem(body, "Base.WateredCan")
    local okWater, amount = pcall(function()
        local fluid = water and water:getFluidContainerFromSelfOrWorldItem()
        return fluid and fluid:isWaterOnlySource()
            and fluid:getAmount() or nil
    end)
    if okWater and finite(amount) and amount >= 0.1 then
        local square = nearbyFeature(body, "flowerbed", 7)
        if square then
            local move = taskNear(body, square, 0.8, "Walk")
            if move then
                return { move }, "approach-flowerbed", square end
            if move == nil then
                return nil, "flowerbed-approach-unavailable" end
            return {{ action = "SAOWaterFlowerbed",
                anim = "PourWateringCan", sound = "WaterCrops",
                time = 200, personId = actorId,
                brainId = brain.id, born = brain.born,
                x = square:getX(), y = square:getY(), z = square:getZ() }},
                "tend-visible-flowerbed", square
        end
    end

    if carriedItem(body, "Base.Newspaper") then
        local square = nearbyFeature(body, "mailbox", 8)
        local box = featureObject(body, square, "mailbox")
        if box then
            local okContainer, container = pcall(function()
                return box:getContainer() end)
            if not okContainer or not container then
                return nil, "mailbox-container-unavailable" end
            local move = taskNear(body, square, 0.8, "Walk")
            if move then
                return { move }, "approach-mailbox", square end
            if move == nil then
                return nil, "mailbox-approach-unavailable" end
            -- The retained source action selects the first container here.
            local objects = square:getObjects()
            for index = 0, math.min(objects:size(), 24) - 1 do
                local object = objects:get(index)
                local actual = object and object:getContainer()
                if actual then
                    if object ~= box then
                        return nil, "mailbox-holder-ambiguous" end
                    break
                end
            end
            return {{ action = "PutInContainer",
                itemType = "Base.Newspaper", anim = "Loot",
                x = box:getX(), y = box:getY(), z = box:getZ() }},
                "deliver-physical-newspaper", square
        end
    end

    if physicalItem(body, "Base.SprayPaint")
        and finite(phase.appraisal.aggression)
        and finite(phase.appraisal.discipline)
        and phase.appraisal.aggression > phase.appraisal.discipline then
        local square, direction = unpaintedWall(body, 6)
        if square then
            local move = taskNear(body, square, 0.8, "Walk")
            if move then
                return { move }, "approach-unpainted-wall", square end
            if move == nil then
                return nil, "wall-approach-unavailable" end
            return {{ action = "SAOGraffiti", anim = "Paint",
                dir = direction, time = 300, personId = actorId,
                brainId = brain.id, born = brain.born,
                x = square:getX(), y = square:getY(), z = square:getZ() }},
                "paint-visible-wall", square
        end
    end

    -- Compare only executable current options. A source program name does not
    -- choose music; the selected private model ranks physical means, personal
    -- attempts and current body pressure together with visible rest or travel.
    local candidates, receivers = {}, {}
    local atHours = countyHours()
    local prior = atHours and ownInstrumentAttempts(actorId, atHours) or {}
    local needs = currentLeisurePressure(actorId, brain, body)
    local heldTypes = {}
    for _, itemType in ipairs(PERFORMANCE_ORDER) do
        heldTypes[itemType] = physicalItem(body, itemType) end
    local journalReady = false
    for _, itemType in ipairs(PERFORMANCE_ORDER) do
        if heldTypes[itemType] then
            journalReady = W.performanceJournalReady(phase, actorId)
            break
        end
    end
    if journalReady then
        for _, itemType in ipairs(PERFORMANCE_ORDER) do
            local item = heldTypes[itemType]
            local okItem, itemId = pcall(function()
                return item and item:getID() end)
            if okItem and finite(itemId) and itemId == math.floor(itemId)
                and itemId >= -2147483648 and itemId <= 2147483647 then
                local priorAttempt = prior[itemType]
                local id = "instrument:" .. itemType
                candidates[#candidates + 1] = {
                    id = id, kind = "instrument", itemType = itemType,
                    evidence = 1, continuity = priorAttempt
                        and priorAttempt.succeeded == true and 1 or 0,
                    novelty = priorAttempt and 0 or 1,
                    informationGain = 0,
                    blockers = priorAttempt and priorAttempt.succeeded == false
                        and 1 or 0,
                    evidenceId = priorAttempt and priorAttempt.id or nil }
                receivers[id] = { kind = "instrument", itemType = itemType,
                    itemId = itemId }
            end
        end
    end
    local seat = nearbyFeature(body, "chair", 5)
    if seat then
        local move = taskNear(body, seat, 0.8, "Walk")
        if move ~= nil then
            local task = move or { action = "SitInChair", anim = "SitInChair2",
                facing = "W", x = seat:getX(), y = seat:getY(),
                z = seat:getZ(), time = 100 }
            candidates[#candidates + 1] = { id = "rest:visible-chair",
                kind = "rest", evidence = 1,
                continuity = phase.ordinary and phase.ordinary.purpose
                    == "sit-at-visible-chair" and 1 or 0,
                novelty = 0, informationGain = 0, blockers = 0,
                utility = needs and 1 - needs.sourceEndurance or nil,
                consequences = {{ kind = "rest", category = "body", value = 0.6 }} }
            receivers["rest:visible-chair"] = { kind = "chair", task = task,
                purpose = move and "approach-chair" or "sit-at-visible-chair",
                target = seat }
        end
    end

    -- A personally heard unknown sound can compete with ordinary rest,
    -- travel and performance. Its target is a currently visible exterior
    -- ground square; the sound coordinates never become a movement target.
    local inquiry = SAO.ProceduralPlanning
    local okTick, inquiryTick = pcall(function() return SAO.History.ticks() end)
    if not phase.sourceInquiry and okTick and finite(inquiryTick)
        and inquiry and inquiry.situationInquiryOffer
        and inquiry.planSourceSituationInquiry then
        local okOffer, offer = pcall(inquiry.situationInquiryOffer,
            actorId, body, inquiryTick)
        local approach = okOffer and offer and offer.subject == "unclassified-sound"
            and offer.approach or nil
        if approach and finite(approach.x) and finite(approach.y)
            and finite(approach.z) then
            local okSquare, ground = pcall(function()
                return body:getCell():getGridSquare(
                    approach.x, approach.y, approach.z)
            end)
            if okSquare and ground and visibleFeature(body, ground, "ground") then
                local move = taskNear(body, ground, 0.8, "Walk")
                if move then
                    local key = "inquiry:" .. offer.questionKey
                    candidates[#candidates + 1] = { id = key, kind = "inquiry",
                        evidence = 1, continuity = 0, novelty = 1,
                        informationGain = 1, blockers = 0,
                        utility = offer.utility }
                    receivers[key] = { kind = "inquiry", task = move,
                        target = ground, offer = offer, atTick = inquiryTick,
                        purpose = "investigate-personally-heard-sound" }
                end
            end
        end
    end

    local task, square = roadTask(body, "Walk")
    local routeKind = "road"
    if not task then
        square = nearbyFeature(body, "ground", 6, 3)
        task = square and taskNear(body, square, 1.0, "Walk")
        routeKind = "ground"
    end
    if task then
        candidates[#candidates + 1] = { id = "walk:visible-ground",
            kind = "walk", evidence = 1,
            continuity = phase.ordinary and phase.ordinary.purpose
                == "walk-visible-ground" and 1 or 0,
            novelty = 0, informationGain = 0, blockers = 0,
            utility = needs and needs.sourceEndurance or nil }
        receivers["walk:visible-ground"] = { kind = "walk", task = task,
            purpose = "walk-visible-ground", target = square,
            featureKind = routeKind }
    end
    if #candidates == 0 then return nil, "no-visible-ordinary-action" end
    local cognition = SAO.Cognition
    local okView, views = pcall(function()
        return cognition and cognition.interpretPlans
            and cognition.interpretPlans(actorId, candidates,
                { domain = "leisure-action",
                  pressure = needs and 1 - needs.sourceEndurance or 0 })
    end)
    local rec = SAO.Identity and SAO.Identity.get(actorId)
    if not rec or rec.weekOne ~= phase or SAO.Claims.heldBy(rec) ~= OWNER
        or not currentBody(brain, body) then
        return nil, "owner-changed" end
    local chosen = okView and type(views) == "table" and receivers[views.selected]
    if not chosen or views.selectedModelId ~= "ordinary"
        and views.selectedModelId ~= "associative" then
        -- An older or partial runtime can still carry out a currently visible
        -- chair or walk. It cannot infer a personal music preference.
        local fallback = receivers["rest:visible-chair"]
            or receivers["walk:visible-ground"]
        if fallback and visibleFeature(body, fallback.target,
            fallback.featureKind or "chair") then
            return { fallback.task }, fallback.purpose, fallback.target end
        return nil, "private-leisure-comparison-unavailable" end
    if chosen.kind == "instrument" then
        local current = physicalItem(body, chosen.itemType)
        local okItem, currentId = pcall(function()
            return current and current:getID() end)
        if not okItem or currentId ~= chosen.itemId then
            return nil, "selected-instrument-changed" end
        local instrument = PERFORMANCE_INSTRUMENTS[chosen.itemType]
        choiceRecord(phase, actorId, plan, candidates, views, needs)
        return {{ action = "SAOPerform",
            itemType = chosen.itemType, saoItemId = chosen.itemId,
            anim = instrument.anim, saoSound = instrument.sound, time = 400,
            personId = actorId, brainId = brain.id, born = brain.born }},
            "perform-with-physical-instrument"
    end
    if chosen.kind == "inquiry" then
        local tickOk, currentTick = pcall(function()
            return SAO.History.ticks()
        end)
        local s = store()
        if not tickOk or currentTick ~= chosen.atTick or not s or phase.sourceInquiry
            or not visibleFeature(body, chosen.target, "ground") then
            return nil, "selected-inquiry-changed" end
        local planned, purpose, step = pcall(inquiry.planSourceSituationInquiry,
            actorId, body, chosen.offer, currentTick)
        local sequence = purpose and purpose.inquiry
            and purpose.inquiry.sourceSelection
            and purpose.inquiry.sourceSelection.sequence
        if not planned or not step or not finite(sequence) then
            return nil, "private-inquiry-admission-unavailable" end
        phase.sourceInquiry = { purposeId = purpose.id, sequence = sequence,
            atTick = currentTick, deadlineTick = currentTick + 900,
            questionKey = chosen.offer.questionKey, targetKey = step.target,
            x = step.x, y = step.y, z = step.z,
            brainId = brain.id, born = brain.born,
            decisionAtTick = plan.atTick }
        sourceInquiryBodies[actorId] = { body = body, brain = brain }
        s.pendingSourceInquiryByPerson[actorId] = true
        trackSourceInquiry(actorId)
        choiceRecord(phase, actorId, plan, candidates, views, needs)
        return { chosen.task }, chosen.purpose, chosen.target
    end
    if not visibleFeature(body, chosen.target,
        chosen.featureKind or "chair") then
        return nil, "selected-feature-changed" end
    choiceRecord(phase, actorId, plan, candidates, views, needs)
    return { chosen.task }, chosen.purpose, chosen.target
end

local function personOrdinaryStage(brain, body, family, stage)
    local plan, phase = acceptedStagePlan(brain, body)
    if not plan then return nil, phase end
    local adapter = family .. "." .. stage
    local nextStage = stage == "Main" and "Main" or stage
    local tasks, purpose, target
    if plan.kind == "move" then
        if phase.appraisal and phase.appraisal.preference == "caution" then
            local task = escapeTask(body, plan)
            if task then tasks, purpose = { task }, "avoid-observed-threat" end
        else
            local attack = personCombatTask(brain, body, plan, phase)
            if attack then
                tasks = { attack }
                purpose = attack.action == "SAOThrowExplosive"
                    and "confront-observed-zombie-cluster"
                    or "confront-observed-hostile-player"
            else
                local task = planMove(plan)
                if task then tasks, purpose = { task }, "face-observed-threat" end
            end
        end
        if not tasks then return nil, "threat-route-unavailable" end
    else
        local rest = planRest(plan)
        if not rest then return nil, "private-rest-unavailable" end
        if plan.reason == "no-private-enemy"
            and plan.observedAtTick == plan.atTick then
            tasks, purpose, target = ordinaryChoice(
                brain, body, phase, plan)
        end
        nextStage = nextStage or (stage == "Main" and "Main" or stage)
        if not tasks then
            tasks = { rest }
            purpose = purpose or "private-rest"
        end
    end
    local location
    if target and type(target.getX) == "function"
        and type(target.getY) == "function"
        and type(target.getZ) == "function" then
        local ok, x, y, z = pcall(function()
            return target:getX(), target:getY(), target:getZ() end)
        if ok and finite(x) and finite(y) and finite(z) then
            location = { x = x, y = y, z = z }
        end
    end
    phase.ordinary = { sourceProgram = family, stage = stage,
        purpose = purpose, atTick = plan.atTick,
        observedAtTick = plan.observedAtTick,
        source = "sao-person-and-native-feature", target = location }
    local attackDecision = phase.decision and phase.decision.kind == "attack"
        and phase.decision or nil
    phase.decision = { kind = attackDecision and "attack" or "ordinary",
        adapter = adapter,
        purpose = purpose, atTick = plan.atTick,
        observedAtTick = plan.observedAtTick,
        source = "sao-person-and-native-feature", target = location,
        actionOwner = OWNER,
        attackMethod = attackDecision and attackDecision.attackMethod,
        playerKey = attackDecision and attackDecision.playerKey,
        targetKey = attackDecision and attackDecision.targetKey }
    for _, task in ipairs(tasks) do
        if type(task) == "table" then
            task.saoWeekOnePersonId = plan.actorId
            task.saoWeekOneBrainId = brain.id
            task.saoWeekOneBorn = brain.born
            task.saoWeekOneAtTick = plan.atTick
        end
    end
    return stageResult(nextStage, tasks)
end

function W.ordinaryProgramStage(brain, body, family, stage)
    if not sourceStage(brain, body, family, stage)
        or not (ordinaryStages[family] and ordinaryStages[family][stage]) then
        return nil, "source-stage-mismatch" end
    return personOrdinaryStage(brain, body, family, stage)
end

-- The installed dispatcher may encounter a program or stage added after this
-- file loaded. Its source name remains provenance; the same private person
-- frame and physical task choice govern any such callback.
function W.dynamicProgramStage(brain, body)
    local program = type(brain) == "table" and brain.program
    local family = type(program) == "table" and program.name
    local stage = type(program) == "table" and program.stage
    if type(family) ~= "string" or type(stage) ~= "string"
        or not sourceStage(brain, body, family, stage) then
        return nil, "source-stage-mismatch" end
    if stage == "Prepare" then
        return W.prepareProgram(brain, body, family) end
    return personOrdinaryStage(brain, body, family, stage)
end

-- The source Move/GoTo callbacks do not distinguish arrival from failure or
-- timer completion. Read the exact person's native position and fresh sight
-- on a bounded tick stream, independent of the source queue and scan queue.
function W.observePendingSourceInquiries()
    local s = store()
    local pending = s and s.pendingSourceInquiryByPerson
    if type(pending) ~= "table" then return 0 end
    local okTick, tick = pcall(function() return SAO.History.ticks() end)
    if not okTick or not finite(tick) then return 0 end
    local discovered = pollKeys(pending, "SourceInquiryPersons", 16)
    for _, personId in ipairs(discovered or {}) do
        if pending[personId] == true then trackSourceInquiry(personId) end
    end
    local keys = sourceInquiryKeys(16)
    local settled = 0
    for _, personId in ipairs(keys) do
        local okRecord, rec = pcall(function()
            return SAO.Identity and SAO.Identity.get(personId)
        end)
        if not okRecord then rec = nil end
        local phase = rec and rec.weekOne
        local inquiry = phase and phase.sourceInquiry
        if not inquiry then
            pending[personId] = nil
            sourceInquiryBodies[personId] = nil
            forgetSourceInquiry(personId)
        else
            local result
            local runtime = sourceInquiryBodies[personId]
            local exact, body, brain = pcall(W.sourceBodyFor, personId)
            local decision = phase.decision
            local claimOk, held = pcall(function()
                return SAO.Claims and SAO.Claims.heldBy(rec)
            end)
            if inquiry.terminalResult == "deadline"
                or inquiry.terminalResult == "interrupted" then
                result = inquiry.terminalResult
            elseif not rec or rec.dead or phase.pending or phase.status ~= "external"
                or not claimOk or held ~= OWNER
                or not exact or not body or type(brain) ~= "table"
                or not runtime or runtime.body ~= body or runtime.brain ~= brain
                or brain.id ~= inquiry.brainId or brain.born ~= inquiry.born
                or type(decision) ~= "table"
                or decision.atTick ~= inquiry.decisionAtTick
                or decision.purpose ~= "investigate-personally-heard-sound"
                or not finite(inquiry.atTick) or not finite(inquiry.deadlineTick)
                or inquiry.deadlineTick ~= inquiry.atTick + 900
                or not finite(inquiry.x) or not finite(inquiry.y)
                or not finite(inquiry.z) or tick < inquiry.atTick then
                result = "interrupted"
            elseif tick >= inquiry.deadlineTick then
                result = "deadline"
            else
                local located, x, y, z = pcall(function()
                    return body:getX(), body:getY(), body:getZ()
                end)
                if located and finite(x) and finite(y) and z == inquiry.z then
                    local dx, dy = x - (inquiry.x + .5), y - (inquiry.y + .5)
                    if dx * dx + dy * dy <= 1 then
                        local okSquare, square = pcall(function()
                            return body:getCell():getGridSquare(
                                inquiry.x, inquiry.y, inquiry.z)
                        end)
                        if okSquare and square and visibleFeature(body, square, "ground") then
                            local perception = SAO.Perception
                            local receiptOk, fresh = pcall(function()
                                return perception and perception.conceptObservationReceipt
                                    and perception.conceptObservationReceipt(personId, body, tick)
                            end)
                            fresh = receiptOk and fresh == true
                            if not fresh and inquiry.lastObservationTick ~= tick then
                                local granted = reserveScan(s, rec, brain, body, tick)
                                if granted and perception and perception.observeConcepts then
                                    inquiry.lastObservationTick = tick
                                    local okRead, observed = pcall(perception.observeConcepts,
                                        personId, body, tick)
                                    if okRead and observed == true then
                                        s.metrics.scans = s.metrics.scans + 1
                                    end
                                end
                            end
                            local currentOk, current = pcall(function()
                                return perception and perception.conceptObservationReceipt
                                    and perception.conceptObservationReceipt(personId, body, tick)
                            end)
                            if currentOk and current == true then
                                result = "observed"
                            end
                        end
                    end
                end
            end
            local retryDue = inquiry.status ~= "reconciliation-unavailable"
                or not finite(inquiry.nextRetryTick)
                or tick >= inquiry.nextRetryTick
            if result and inquiry.lastRevisionTick ~= tick and retryDue then
                if result == "deadline" or result == "interrupted" then
                    inquiry.terminalResult = result
                end
                inquiry.lastRevisionTick = tick
                local planner = SAO.ProceduralPlanning
                local ok, recorded = pcall(function()
                    return planner and planner.finishSourceSituationInquiry
                        and planner.finishSourceSituationInquiry(personId,
                            result == "observed" and body or nil,
                            inquiry.purposeId, inquiry.sequence, result, tick)
                end)
                if ok and recorded == true then
                    phase.lastSourceInquiry = { purposeId = inquiry.purposeId,
                        sequence = inquiry.sequence, result = result, atTick = tick,
                        status = "recorded" }
                    phase.sourceInquiry = nil
                    sourceInquiryBodies[personId] = nil
                    pending[personId] = nil
                    forgetSourceInquiry(personId)
                    settled = settled + 1
                elseif result ~= "observed" then
                    local failures = inquiry.reconciliationFailures
                    inquiry.reconciliationFailures =
                        (finite(failures) and failures >= 0 and failures or 0) + 1
                    if inquiry.reconciliationFailures >= 16 then
                        inquiry.status = "reconciliation-unavailable"
                        inquiry.nextRetryTick = tick + 240
                        phase.lastSourceInquiry = {
                            purposeId = inquiry.purposeId,
                            sequence = inquiry.sequence, result = result,
                            atTick = tick, status = inquiry.status }
                    end
                end
            end
        end
    end
    return settled
end

actionPhase = function(body, task)
    if type(task) ~= "table" or type(task.saoWeekOnePersonId) ~= "string"
        or not (BanditBrain and type(BanditBrain.Get) == "function") then
        return nil end
    local ok, brain = pcall(BanditBrain.Get, body)
    if not ok or not currentBody(brain, body)
        or brain.saoWeekOneOrigin ~= OWNER
        or brain.id ~= task.saoWeekOneBrainId
        or brain.born ~= task.saoWeekOneBorn then return nil end
    local rec = SAO.Identity and SAO.Identity.get(task.saoWeekOnePersonId)
    if not rec or not rec.weekOne or rec.weekOne.pending
        or SAO.Claims.heldBy(rec) ~= OWNER then return nil end
    local md = body:getModData()
    if not md or md.SAOWeekOneOrigin ~= OWNER
        or md.SAOWeekOnePersonId ~= rec.id
        or md.SAOWeekOneBrainId ~= brain.id
        or md.SAOWeekOneBorn ~= brain.born
        or not rec.weekOne.decision
        or rec.weekOne.decision.atTick ~= task.saoWeekOneAtTick then
        return nil end
    return rec.weekOne
end

local function recordRoleOutcome(phase, task, result)
    local sequence = phase.nextOrdinaryOutcome or 1
    if not finite(sequence) or sequence < 1 or sequence % 1 ~= 0 then
        return false end
    phase.nextOrdinaryOutcome = sequence + 1
    phase.lastOrdinaryOutcome = { sequence = sequence, result = result,
        purpose = phase.decision and phase.decision.purpose,
        atHours = now(), atTick = task.saoWeekOneAtTick }
    return true, sequence
end

local function performanceItem(body, task)
    local definition = type(task) == "table" and PERFORMANCE_INSTRUMENTS[task.itemType]
    if not definition or task.action ~= "SAOPerform" or task.anim ~= definition.anim
        or task.saoSound ~= definition.sound then return nil end
    local item = physicalItem(body, task.itemType)
    local ok, itemId = pcall(function() return item and item:getID() end)
    if not ok or not finite(itemId) or itemId ~= math.floor(itemId)
        or itemId < -2147483648 or itemId > 2147483647
        or itemId ~= task.saoItemId then return nil end
    return item, itemId
end

-- The source action owns the physical act. The person record retains a small
-- terminal journal so private cognition can authenticate it after reload.
local MAX_PERFORMANCE_JOURNAL = 32
local RETAINED_PERFORMANCE_JOURNAL = 16
local function trimPerformanceJournal(phase)
    local rows = phase.performanceOutcomes
    if type(rows) ~= "table" then return end
    local through = phase.performanceCognitionThrough or 0
    while #rows > RETAINED_PERFORMANCE_JOURNAL
        and type(rows[1]) == "table" and rows[1].sequence <= through do
        table.remove(rows, 1)
    end
end

function W.reconcilePerformanceOutcomes(id)
    if type(id) ~= "string" or not SAO.Identity then return false end
    local rec = SAO.Identity.get(id)
    local phase = rec and rec.weekOne
    local s = store()
    if not s or not phase or phase.source ~= OWNER then return false end
    local rows = phase.performanceOutcomes
    if type(rows) ~= "table" or #rows == 0 then
        s.pendingPerformanceByPerson[id] = nil
        return true
    end
    if #rows > MAX_PERFORMANCE_JOURNAL then return false end
    local through = phase.performanceCognitionThrough or 0
    if not finite(through) or through < 0 or through ~= math.floor(through) then
        return false end
    local previousSequence
    for _, row in ipairs(rows) do
        if type(row) ~= "table" or row.actorId ~= id
            or not finite(row.sequence) or row.sequence <= 0
            or row.sequence ~= math.floor(row.sequence)
            or previousSequence and row.sequence ~= previousSequence + 1 then
            return false end
        previousSequence = row.sequence
        if row.sequence > through then
            local callback = SAO.Cognition and SAO.Cognition.weekOnePerformanceOutcome
            if type(callback) ~= "function" then
                s.pendingPerformanceByPerson[id] = true
                return false end
            local called, accepted, reason = pcall(callback, id, row.sequence)
            if not called or accepted ~= true then
                -- A native cursor can outlive the bounded private event log.
                -- The producer already accepted this exact position earlier.
                local cursor = rec.cognition and rec.cognition.nativeExperienceCursors
                    and rec.cognition.nativeExperienceCursors["weekone-instrument-performance"]
                if not (called and reason == "retired-native-receipt"
                    and finite(cursor) and cursor >= row.sequence) then
                    s.pendingPerformanceByPerson[id] = true
                    return false
                end
            end
            through = row.sequence
            phase.performanceCognitionThrough = through
        end
    end
    s.pendingPerformanceByPerson[id] = nil
    trimPerformanceJournal(phase)
    return true
end

function W.performanceJournalReady(phase, id)
    if type(phase) ~= "table" or type(id) ~= "string" then return false end
    W.reconcilePerformanceOutcomes(id)
    trimPerformanceJournal(phase)
    return type(phase.performanceOutcomes) ~= "table"
        or #phase.performanceOutcomes < MAX_PERFORMANCE_JOURNAL
end

local function recordPerformanceOutcome(phase, task, active, itemId, atHours)
    local sequence = phase.nextPerformanceOutcome or 1
    local decision, ordinary = phase.decision, phase.ordinary
    if not finite(sequence) or sequence < 1 or sequence >= 9007199254740991
        or sequence ~= math.floor(sequence) or not finite(atHours)
        or atHours < active.startedAtHours or not decision or not ordinary
        or type(ordinary.sourceProgram) ~= "string"
        or type(ordinary.stage) ~= "string"
        or decision.kind ~= "ordinary" or decision.actionOwner ~= OWNER
        or decision.purpose ~= "perform-with-physical-instrument"
        or decision.adapter ~= ordinary.sourceProgram .. "." .. ordinary.stage
        or decision.atTick ~= task.saoWeekOneAtTick
        or ordinary.atTick ~= task.saoWeekOneAtTick then return nil end
    local receipt = {
        actorId = task.saoWeekOnePersonId, sequence = sequence,
        sourceId = "BanditsWeekOne:SAOPerform", sourceAction = "SAOPerform",
        claimOwner = OWNER, brainId = task.saoWeekOneBrainId,
        born = task.saoWeekOneBorn, bodyId = active.bodyId,
        decisionAtTick = task.saoWeekOneAtTick,
        sourceProgram = ordinary.sourceProgram, sourceStage = ordinary.stage,
        purpose = decision.purpose, itemId = itemId, itemType = task.itemType,
        soundId = task.saoSound, status = "completed",
        startedAtHours = active.startedAtHours, atHours = atHours,
        countyAtHours = countyHours(),
    }
    phase.performanceOutcomes = type(phase.performanceOutcomes) == "table"
        and phase.performanceOutcomes or {}
    trimPerformanceJournal(phase)
    if #phase.performanceOutcomes >= MAX_PERFORMANCE_JOURNAL then return nil end
    phase.performanceOutcomes[#phase.performanceOutcomes + 1] = receipt
    phase.nextPerformanceOutcome = sequence + 1
    local s = store()
    if s then s.pendingPerformanceByPerson[receipt.actorId] = true end
    return receipt
end

function W.performanceOutcome(id, sequence)
    if type(id) ~= "string" or not finite(sequence) or sequence < 1
        or sequence ~= math.floor(sequence) then return nil end
    local rec = SAO.Identity and SAO.Identity.get(id)
    local phase = rec and rec.weekOne
    if not phase or phase.source ~= OWNER or type(phase.performanceOutcomes) ~= "table" then return nil end
    for _, row in ipairs(phase.performanceOutcomes) do
        if type(row) == "table" and row.actorId == id and row.sequence == sequence
            and row.brainId == phase.brainId and row.born == phase.born then
            local copy = {}
            for _, key in ipairs({ "actorId", "sequence", "sourceId", "sourceAction",
                "claimOwner", "brainId", "born", "bodyId", "decisionAtTick",
                "sourceProgram", "sourceStage", "purpose", "itemId", "itemType",
                "soundId", "status", "startedAtHours", "atHours",
                "countyAtHours" }) do
                copy[key] = row[key]
            end
            return copy
        end
    end
    return nil
end

local function actionSquare(body, task, kind)
    local ok, square = pcall(function()
        return body:getCell():getGridSquare(task.x, task.y, task.z)
    end)
    if ok and visibleFeature(body, square, kind) then return square end
    return nil
end

local function clearSourceMarker(task, kind)
    if not (BWOServer and BWOServer.Commands
        and type(BWOServer.Commands.ObjectRemove) == "function") then
        return false end
    local ok = pcall(BWOServer.Commands.ObjectRemove, nil,
        { x = task.x, y = task.y, z = task.z, otype = kind })
    return ok
end

local previousRoleActions = W.roleActions or {}
-- Runtime custody is keyed by the actual task table. A saved or reconstructed
-- task cannot complete an emission from an earlier process.
local activePerformances = setmetatable({}, { __mode = "k" })

function W.livePerformanceIds()
    local ids, count = {}, 0
    for task, owner in pairs(performanceSoundOwners) do
        count = count + 1
        if count > MAX_ACTIVE_PERFORMANCES then break end
        if owner.generation == performanceGeneration and not owner.revoked
            and type(owner.occurrence) == "table" and activePerformances[task]
            and not task.saoCancelled and not task.saoCompleted
            and type(task.saoWeekOnePersonId) == "string" then
            ids[#ids + 1] = task.saoWeekOnePersonId
        end
    end
    return ids
end

-- Read only the current source-owned action and native occurrence. The
-- listener still needs their own scanner acquisition and native claim.
function W.livePerformance(personId)
    if type(personId) ~= "string" then return nil end
    local body, brain = W.sourceBodyFor(personId)
    if not body or type(brain) ~= "table" then return nil end
    for task, owner in pairs(performanceSoundOwners) do
        local active = activePerformances[task]
        if owner.generation == performanceGeneration and owner.body == body
            and owner.brain == brain and owner.brainId == brain.id
            and owner.born == brain.born and not owner.revoked
            and active and active.body == body and active.phase == actionPhase(body, task)
            and active.soundHandle == owner.soundHandle
            and task.saoWeekOnePersonId == personId and not task.saoCancelled
            and not task.saoCompleted and queuedOwnedPerformance(task, owner)
            and type(owner.occurrence) == "table" then
            local ok, playing = pcall(function()
                return body:getEmitter():isPlaying(owner.soundHandle)
            end)
            if ok and playing == true then
                local occurrence = {}
                for key, value in pairs(owner.occurrence) do
                    if type(value) == "string" or type(value) == "number" then
                        occurrence[key] = value
                    end
                end
                return body, occurrence
            end
        end
    end
    return nil
end

-- A source proxy's private cognition scan is budgeted at twenty county ticks,
-- while its native WorldSound can live for only sixteen engine updates. The
-- existing source cache supplies loaded bodies; the existing Java iterator
-- visits a bounded, advancing slice each OnTick while a performance is live.
-- Perception remains the owner of the resulting person-private hearing.
function W.observeLoadedPerformanceHearings()
    local cache = BanditZombie and BanditZombie.CacheLightB
    local perception = SAO.Perception
    if type(cache) ~= "table" or not perception
        or type(perception.acquireWeekOnePerformanceHearing) ~= "function"
        or not SAOJavaBridge or not SAOJavaBridge.perceiveAudibleSounds then
        return 0 end
    local active, seen = {}, {}
    for _, performerId in ipairs(W.livePerformanceIds()) do
        if not seen[performerId] then
            seen[performerId] = true
            local body = W.livePerformance(performerId)
            if body then
                local ok, x, y = pcall(function()
                    return body:getX(), body:getY()
                end)
                if ok and finite(x) and finite(y) then
                    active[#active + 1] = { id = performerId, x = x, y = y }
                end
            end
        end
    end
    if #active == 0 then return 0 end
    local keys = pollKeys(cache, "source-performance-hearers",
        PERFORMANCE_HEARING_VISITS)
    if not keys then return 0 end
    local heard = 0
    for _, key in ipairs(keys) do
        local light = cache[key]
        local brain = type(light) == "table" and light.brain
        if type(brain) == "table" and brain.saoWeekOneOrigin == OWNER
            and finite(brain.id) then
            local ok, body, id, x, y = pcall(function()
                local found = BanditZombie.GetInstanceById(brain.id)
                local md = found and found:getModData()
                return found, md and md.SAOWeekOnePersonId,
                    found and found:getX(), found and found:getY()
            end)
            if ok and body and type(id) == "string"
                and finite(x) and finite(y) then
                local close = {}
                for _, performance in ipairs(active) do
                    local dx, dy = x - performance.x, y - performance.y
                    -- The native claimant independently checks personal
                    -- hearing, sight, occlusion, live pulse and exact owner.
                    if id ~= performance.id and dx * dx + dy * dy <= 16 * 16 then
                        close[#close + 1] = performance.id
                    end
                end
                if #close > 0 then
                    local exact, actualBrain = W.sourceBodyFor(id)
                    if exact == body and actualBrain == brain then
                        local scanned = pcall(function()
                            return SAOJavaBridge:perceiveAudibleSounds(body)
                        end)
                        if scanned then
                            for _, performerId in ipairs(close) do
                                local qualified, receipt = pcall(
                                    perception.acquireWeekOnePerformanceHearing,
                                    id, body, performerId)
                                if qualified and receipt then
                                    heard = heard + 1
                                    if SAO.Cognition
                                        and SAO.Cognition.weekOnePerformanceHearings then
                                        pcall(SAO.Cognition.weekOnePerformanceHearings, id)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return heard
end
local roleActions = {
    SAOExtinguishFire = {
        onStart = function(body, task)
            if not actionPhase(body, task)
                or not physicalExtinguisher(body)
                or not actionSquare(body, task, "fire") then
                task.saoCancelled = true return true end
            pcall(function()
                local emitter = body:getEmitter()
                if not emitter:isPlaying(task.saoSound) then
                    emitter:playSound(task.saoSound) end
            end)
            return true
        end,
        onWorking = function(body, task)
            if task.saoCancelled or not actionPhase(body, task)
                or not physicalExtinguisher(body)
                or not actionSquare(body, task, "fire") then return true end
            if body:getBumpType() ~= task.anim then
                body:setBumpType(task.anim) end
            return false
        end,
        onComplete = function(body, task)
            if task.saoCompleted then return true end
            task.saoCompleted = true
            pcall(function()
                local emitter = body:getEmitter()
                if emitter:isPlaying(task.saoSound) then
                    emitter:stopSoundByName(task.saoSound) end
            end)
            local phase = not task.saoCancelled and actionPhase(body, task)
            local square = phase and actionSquare(body, task, "fire")
            local tool = phase and physicalExtinguisher(body)
            if square and tool and consumeExtinguisher(tool) then
                local ok = pcall(function() square:stopFire() end)
                if ok then
                    local marker = clearSourceMarker(task, "fire")
                    recordRoleOutcome(phase, task, marker
                        and "physical-fire-extinguished"
                        or "physical-fire-marker-unavailable")
                end
            end
            return true
        end,
    },
    SAOCleanTrash = {
        onStart = function(body, task)
            local square = actionSquare(body, task, "trash")
            if not actionPhase(body, task)
                or not physicalItem(body, "Base.Broom")
                or not featureObject(body, square, "trash") then
                task.saoCancelled = true end
            return true
        end,
        onWorking = function(body, task)
            if task.saoCancelled or not actionPhase(body, task)
                or not physicalItem(body, "Base.Broom") then return true end
            if body:getBumpType() ~= task.anim then
                body:setBumpType(task.anim) end
            return false
        end,
        onComplete = function(body, task)
            if task.saoCompleted then return true end
            task.saoCompleted = true
            local phase = not task.saoCancelled and actionPhase(body, task)
            local square = phase and actionSquare(body, task, "trash")
            local object = square and featureObject(body, square, "trash")
            if phase and object and physicalItem(body, "Base.Broom") then
                local ok = pcall(function()
                    if isClient and isClient() then
                        sledgeDestroy(object)
                    else
                        square:transmitRemoveItemFromSquare(object)
                    end
                end)
                if ok and not visibleFeature(body, object, "trash") then
                    local marker = clearSourceMarker(task, "trash")
                    recordRoleOutcome(phase, task, marker
                        and "physical-trash-cleared"
                        or "physical-trash-marker-unavailable")
                end
            end
            return true
        end,
    },
    SAOBandagePerson = {
        onStart = function(body, task)
            if not actionPhase(body, task) or not physicalBandage(body)
                or type(task.saoPatientName) ~= "string"
                or not (SAOJavaBridge and SAOJavaBridge.weekOneObservedCareTarget)
                then task.saoCancelled = true return true end
            local ok, packed = pcall(function()
                return SAOJavaBridge:weekOneObservedCareTarget(
                    body, task.saoPatientName)
            end)
            local distance = ok and type(packed) == "string"
                and tonumber(packed:match(
                    "^CARE\t[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)\t")) or nil
            if not finite(distance) or distance > 2.25 then
                task.saoCancelled = true end
            return true
        end,
        onWorking = function(body, task)
            if task.saoCancelled or not actionPhase(body, task)
                or not physicalBandage(body) then return true end
            if body:getBumpType() ~= task.anim then
                body:setBumpType(task.anim)
            end
            return false
        end,
        onComplete = function(body, task)
            if task.saoCompleted then return true end
            task.saoCompleted = true
            local phase = not task.saoCancelled and actionPhase(body, task)
            if phase and physicalBandage(body)
                and SAOJavaBridge and SAOJavaBridge.weekOneBandageObservedPatient
                then
                local ok, result = pcall(function()
                    return SAOJavaBridge:weekOneBandageObservedPatient(
                        body, task.saoPatientName)
                end)
                if ok and type(result) == "string"
                    and result:sub(1, 8) == "TREATED\t" then
                    recordRoleOutcome(phase, task, result)
                else
                    phase.lastCareRefusal = { patient = task.saoPatientName,
                        reason = ok and result or "native-action-failed",
                        atTick = task.saoWeekOneAtTick }
                end
            end
            return true
        end,
    },
    SAOPerform = {
        onStart = function(body, task)
            if task.saoCompleted or activePerformances[task] then return true end
            local phase = actionPhase(body, task)
            local item, itemId = performanceItem(body, task)
            local decision = phase and phase.decision
            local startedAtHours = now()
            if not phase or not item or not startedAtHours
                or not W.performanceJournalReady(phase, task.saoWeekOnePersonId)
                or not decision or decision.kind ~= "ordinary"
                or decision.purpose ~= "perform-with-physical-instrument"
                or decision.actionOwner ~= OWNER then
                task.saoCancelled = true return true end
            local count = 0
            for _ in pairs(performanceSoundOwners) do
                count = count + 1
                if count >= MAX_ACTIVE_PERFORMANCES then break end
            end
            if count >= MAX_ACTIVE_PERFORMANCES then
                task.saoCancelled = true return true end
            local okBrain, brain = pcall(BanditBrain.Get, body)
            if not okBrain or type(brain) ~= "table"
                or brain.id ~= task.saoWeekOneBrainId
                or brain.born ~= task.saoWeekOneBorn
                or brain.saoWeekOneOrigin ~= OWNER then
                task.saoCancelled = true return true end
            local ok, soundHandle = pcall(function()
                local emitter = body:getEmitter()
                if emitter:isPlaying(task.saoSound) then return nil end
                local handle = emitter:playSound(task.saoSound)
                if type(handle) ~= "number" or handle <= 0
                    or not emitter:isPlaying(handle) then return nil end
                return handle
            end)
            if not ok or not soundHandle then task.saoCancelled = true return true end
            local occurrence
            local emitted, native = pcall(function()
                local sound = getWorldSoundManager():addSound(body,
                    math.floor(body:getX()), math.floor(body:getY()),
                    math.floor(body:getZ()), 45, 45, false, 0, 1,
                    false, true, false, false, true)
                if not sound then return nil end
                return SAOJavaBridge:bindWeekOnePerformanceOccurrence(
                    body, sound, task.saoWeekOnePersonId,
                    task.saoWeekOneBrainId, task.saoWeekOneBorn,
                    task.saoSound, soundHandle)
            end)
            if emitted and type(native) == "table"
                and native.schema == "sao.weekone-performance-occurrence/1"
                and native.actorId == task.saoWeekOnePersonId
                and native.brainId == task.saoWeekOneBrainId
                and native.born == task.saoWeekOneBorn
                and native.soundId == task.saoSound
                and native.soundHandle == soundHandle then
                occurrence = native
            end
            activePerformances[task] = { body = body, bodyId = task.saoWeekOneBrainId,
                itemId = itemId, phase = phase, startedAtHours = startedAtHours,
                soundHandle = soundHandle }
            performanceSoundOwners[task] = { generation = performanceGeneration,
                body = body, brain = brain, brainId = task.saoWeekOneBrainId,
                born = task.saoWeekOneBorn, sound = task.saoSound,
                soundHandle = soundHandle, occurrence = occurrence }
            return true
        end,
        onWorking = function(body, task)
            local active = activePerformances[task]
            local owner = performanceSoundOwners[task]
            local phase = actionPhase(body, task)
            local _, itemId = performanceItem(body, task)
            if task.saoCancelled or not active or active.body ~= body
                or active.phase ~= phase or active.itemId ~= itemId
                or not owner or owner.soundHandle ~= active.soundHandle then
                task.saoCancelled = true
                if active and owner then owner.soundHandle = active.soundHandle end
                stopOwnedPerformanceSound(task)
                return true end
            if owner and owner.occurrence then
                local good, renewed = pcall(function()
                    return SAOJavaBridge:renewWeekOnePerformanceOccurrence(
                        body, owner.occurrence.pulseId)
                end)
                if not good or renewed ~= true then
                    pcall(function()
                        SAOJavaBridge:revokeWeekOnePerformanceOccurrence(
                            body, owner.occurrence.pulseId)
                    end)
                    owner.occurrence = nil
                end
            end
            if body:getBumpType() ~= task.anim then
                body:setBumpType(task.anim)
            end
            return false
        end,
        onComplete = function(body, task)
            if task.saoCompleted then return true end
            task.saoCompleted = true
            local active = activePerformances[task]
            activePerformances[task] = nil
            local owner = performanceSoundOwners[task]
            if active and owner and owner.soundHandle ~= active.soundHandle then
                task.saoCancelled = true
                owner.soundHandle = active.soundHandle
            end
            local stopped = stopOwnedPerformanceSound(task)
            local phase = not task.saoCancelled and actionPhase(body, task)
            local _, itemId = performanceItem(body, task)
            if active and stopped and active.body == body and phase == active.phase
                and active.body == body and itemId == active.itemId then
                recordRoleOutcome(phase, task, "physical-performance")
                local receipt = recordPerformanceOutcome(phase, task,
                    active, itemId, now())
                if receipt then W.reconcilePerformanceOutcomes(receipt.actorId) end
            end
            return true
        end,
    },
    SAOWaterFlowerbed = {
        onStart = function(body, task)
            local square = body:getCell():getGridSquare(task.x, task.y, task.z)
            local water = physicalItem(body, "Base.WateredCan")
            local ok, amount = pcall(function()
                local fluid = water and water:getFluidContainerFromSelfOrWorldItem()
                return fluid and fluid:isWaterOnlySource()
                    and fluid:getAmount() or nil
            end)
            if not actionPhase(body, task)
                or not visibleFeature(body, square, "flowerbed")
                or not ok or not finite(amount) or amount < 0.1 then
                task.saoCancelled = true end
            return true
        end,
        onWorking = function(body, task)
            if task.saoCancelled or not actionPhase(body, task) then return true end
            if body:getBumpType() ~= task.anim then
                body:setBumpType(task.anim)
            end
            return false
        end,
        onComplete = function(body, task)
            if task.saoCompleted then return true end
            task.saoCompleted = true
            local phase = not task.saoCancelled and actionPhase(body, task)
            local square = body:getCell():getGridSquare(task.x, task.y, task.z)
            local water = physicalItem(body, "Base.WateredCan")
            if phase and visibleFeature(body, square, "flowerbed") and water then
                local ok = pcall(function()
                    local fluid = water:getFluidContainerFromSelfOrWorldItem()
                    if not fluid or not fluid:isWaterOnlySource()
                        or fluid:getAmount() < 0.1 then error("water-gone") end
                    fluid:removeFluid(0.1)
                end)
                if ok then recordRoleOutcome(phase, task,
                    "decorative-flowerbed-tended") end
            end
            return true
        end,
    },
    SAOGraffiti = {
        onStart = function(body, task)
            local square = body:getCell():getGridSquare(task.x, task.y, task.z)
            if not actionPhase(body, task)
                or not physicalItem(body, "Base.SprayPaint")
                or not visibleFeature(body, square, "wall") then
                task.saoCancelled = true end
            return true
        end,
        onWorking = function(body, task)
            if task.saoCancelled or not actionPhase(body, task) then return true end
            if body:getBumpType() ~= task.anim then
                body:setBumpType(task.anim)
            end
            return false
        end,
        onComplete = function(body, task)
            if task.saoCompleted then return true end
            task.saoCompleted = true
            local phase = not task.saoCancelled and actionPhase(body, task)
            local square, direction = unpaintedWall(body, 6)
            local spray = physicalItem(body, "Base.SprayPaint")
            local source = ZombieActions and ZombieActions.Graffiti
            if phase and square and direction == task.dir
                and square:getX() == task.x and square:getY() == task.y
                and square:getZ() == task.z and spray and source
                and type(source.onComplete) == "function" then
                -- Consume the actual held material before irreversible wall
                -- art. A failed item use must never mint a painted surface.
                local consumed = pcall(function() spray:Use() end)
                if consumed then
                    local ok = pcall(source.onComplete, body, task)
                    if ok then recordRoleOutcome(phase, task,
                        "physical-graffiti") end
                end
            end
            return true
        end,
    },
}

roleActions.SAOThrowExplosive = {
    onStart = function(body, task)
        if not actionPhase(body, task) then
            task.saoCancelled = true return true end
        return true
    end,
    onWorking = function(body, task)
        if task.saoCancelled or not actionPhase(body, task) then
            task.saoCancelled = true return true end
        return false
    end,
    onComplete = function(body, task)
        if task.saoCompleted then return true end
        task.saoCompleted = true
        if not task.saoCancelled then
            local ok, result, reason = pcall(W.executeExplosiveTask,
                body, task)
            if not ok then
                local phase = actionPhase(body, task)
                if phase then phase.lastExplosiveRefusal =
                    "native-execution-error" end
            elseif result ~= true then
                local phase = actionPhase(body, task)
                if phase then phase.lastExplosiveRefusal = reason end
            end
        end
        return true
    end,
}

function W.installRoleActions()
    if not ZombieActions then return false, "source-actions-unavailable" end
    for name, action in pairs(roleActions) do
        local existing = ZombieActions[name]
        if existing and existing ~= action
            and existing ~= previousRoleActions[name] then
            return false, "owned-action-conflict:" .. name end
    end
    for name, action in pairs(roleActions) do ZombieActions[name] = action end
    W.roleActions = roleActions
    return true
end

-- A named emergency or combat stage consumes only this person's fresh plan.
-- It cannot fall through to source player proximity, random flight or global
-- zombie density if private admission is deferred or unavailable.
function W.ownedProgramStage(brain, body, family, stage)
    if not sourceStage(brain, body, family, stage) then
        return nil, "source-stage-mismatch" end
    if stage == "Init" or stage == "Wait" or stage == "Walk"
        or stage == "Follow" then
        local phase, reason = stagePerson(brain, body)
        if not phase then return nil, reason end
        phase.decision = { kind = "resume", adapter = family .. "." .. stage,
            source = "sao-person", atHours = now() }
        return stageResult(stage == "Init" and "Prepare" or "Main")
    end
    local plan, phase = acceptedStagePlan(brain, body)
    if not plan then return nil, phase end
    local adapter = family .. "." .. stage
    if family == "Bandit" and stage == "Surrender" then
        local frame = phase.appraisal
        if type(frame) ~= "table" or frame.actorId ~= plan.actorId then
            return nil, "person-appraisal-mismatch" end
        if plan.kind == "fallback" then
            local rest = planRest(plan)
            if not rest or plan.reason ~= "no-private-enemy"
                or plan.observedAtTick ~= plan.atTick then
                return nil, "current-surrender-context-unavailable" end
            phase.decision.adapter = adapter
            return stageResult("Main", { rest })
        end
        if plan.kind == "move" and finite(frame.selfPreservation)
            and finite(frame.aggression)
            and frame.selfPreservation > frame.aggression then
            if plan.targetKind == "person" and plan.dist <= 6
                and frame.hostileSeen > 0
                and plan.observedAtTick == plan.atTick then
                phase.decision = { kind = "surrender", adapter = adapter,
                    source = "sao-private-appraisal", atTick = plan.atTick,
                    observedAtTick = plan.observedAtTick,
                    targetKind = plan.targetKind }
                return stageResult("Surrender", {
                    { action = "Time", anim = "Surrender", time = 40 } })
            end
            local task, x, y, z = escapeTask(body, plan)
            if not task then return nil, "safe-escape-unavailable" end
            phase.decision = { kind = "escape", adapter = adapter,
                source = "sao-observed", targetKind = plan.targetKind,
                atTick = plan.atTick, observedAtTick = plan.observedAtTick,
                x = x, y = y, z = z }
            return stageResult("Escape", { task })
        end
    end
    if stage == "Escape" then
        local task, x, y, z = escapeTask(body, plan)
        if task then
            phase.decision = { kind = "escape", adapter = adapter,
                source = "sao-observed", targetKind = plan.targetKind,
                atTick = plan.atTick, observedAtTick = plan.observedAtTick,
                x = x, y = y, z = z }
            return stageResult("Escape", { task })
        end
        local rest = planRest(plan)
        if rest and plan.reason == "no-private-enemy"
            and plan.observedAtTick == plan.atTick then
            phase.decision.adapter = adapter
            return stageResult("Main", { rest })
        end
        return nil, "safe-escape-unavailable"
    end
    local attack = personCombatTask(brain, body, plan, phase)
    if attack then
        phase.decision.adapter = adapter
        return stageResult(stage == "Defend" and "Defend" or "Main", { attack })
    end
    local move = planMove(plan)
    if move then
        phase.decision.adapter = adapter
        return stageResult(stage == "Defend" and "Defend" or "Main", { move })
    end
    local rest = planRest(plan)
    if not rest then return nil, "source-plan-unsupported" end
    if family == "Police" and stage == "Main"
        and plan.reason == "no-private-enemy"
        and plan.observedAtTick == plan.atTick
        and Bandit and type(Bandit.SetProgram) == "function" then
        local ok = pcall(Bandit.SetProgram, body, "Patrol", {})
        if ok and brain.program.name == "Patrol" then
            phase.decision = { kind = "resume-program", adapter = adapter,
                program = "Patrol", source = "sao-person-appraisal",
                atTick = plan.atTick, observedAtTick = plan.observedAtTick }
            return stageResult("Main")
        end
        return nil, "source-program-transition-failed"
    end
    if family == "Inhabitant" and stage == "Defend"
        and plan.reason == "no-private-enemy"
        and plan.observedAtTick == plan.atTick then
        if Bandit and type(Bandit.SetHostileP) == "function" then
            pcall(Bandit.SetHostileP, body, false)
        end
        phase.decision.adapter = adapter
        return stageResult("Main", { rest })
    end
    phase.decision.adapter = adapter
    return stageResult("Main", { rest })
end

local sourceChatCommands = {
    ["come with me"] = "join", ["follow me"] = "join",
    ["follow my lead"] = "join", ["walk with me"] = "join",
    ["join my team"] = "join", ["join me"] = "join",
    ["come along"] = "join", ["stay with me"] = "join",
    ["be my companion"] = "join", ["lets go"] = "join",
    ["accompany me"] = "join", ["stick with me"] = "join",
    ["team up with me"] = "join", ["tag along"] = "join",
    ["be with me"] = "join", ["follow my path"] = "join",
    ["accompany my journey"] = "join", ["sitck by me"] = "join",
    ["team up together"] = "join", ["walk beside me"] = "join",
    ["stay here"] = "hold", ["stay put"] = "hold",
    ["wait here"] = "hold", ["hold position"] = "hold",
    ["guard this"] = "hold", ["guard that"] = "hold",
    ["stop following me"] = "hold", ["dont follow me"] = "hold",
    ["go away"] = "leave", ["leave me"] = "leave",
    ["leave me alone"] = "leave", ["go home"] = "home",
    ["return home"] = "home", ["head home"] = "home",
}
local sourceThreats = {
    ["i will kill you"] = true, ["i will shoot you"] = true,
    ["i will hit you"] = true, ["i will attack you"] = true,
    ["i will beat you"] = true, ["fuck you"] = true,
    ["asshole"] = true,
}

local function sourceChatIntent(text)
    local words = text:lower():gsub("'", ""):gsub("[^%w%s]", " ")
        :gsub("%s+", " "):match("^%s*(.-)%s*$")
    if sourceChatCommands[words] then return sourceChatCommands[words] end
    if sourceThreats[words] then return "threat" end
    if words == "hello" or words == "hi" or words == "hey"
        or words == "howdy" or words == "greetings" then return "greeting" end
    if words == "sorry" or words == "i apologize"
        or words == "my apologies" then return "apology" end
    return "conversation"
end

local disposableChatMoveFields = {
    action = true, time = true, endurance = true, x = true, y = true,
    z = true, walkType = true, closeSlow = true,
    saoWeekOnePersonId = true, saoWeekOneBrainId = true,
    saoWeekOneBorn = true, saoWeekOneAtTick = true,
}

local function sourceChatQueue(brain, rec)
    local tasks = brain.tasks
    if type(tasks) ~= "table" then return nil end
    local phase = rec.weekOne
    local decision = phase and phase.decision
    local count = #tasks
    if count == 0 then
        for _ in pairs(tasks) do return nil end
        return tasks, {}
    end
    if not decision or decision.kind ~= "ordinary"
        or decision.source ~= "sao-person-and-native-feature"
        or decision.actionOwner ~= OWNER or not finite(decision.atTick) then
        return nil end
    local snapshot = {}
    for key, task in pairs(tasks) do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > count or type(task) ~= "table"
            or task.lock or task.action ~= "Move" and task.action ~= "GoTo"
            or task.saoWeekOnePersonId ~= rec.id
            or task.saoWeekOneBrainId ~= brain.id
            or task.saoWeekOneBorn ~= brain.born
            or task.saoWeekOneAtTick ~= decision.atTick then return nil end
        for field in pairs(task) do
            if not disposableChatMoveFields[field] then return nil end
        end
        snapshot[key] = task
    end
    for index = 1, count do
        if snapshot[index] == nil then return nil end
    end
    return tasks, snapshot
end

local function sourceChatAct(brain, body, rec, intent)
    if not (Bandit and type(Bandit.SetProgram) == "function") then
        return false, "source-actuator-unavailable" end
    local tasks, snapshot = sourceChatQueue(brain, rec)
    if not tasks then return false, "source-task-busy" end
    local program = brain.program
    if type(program) ~= "table" then return false, "source-program-unavailable" end
    local prior = {}
    for key, value in pairs(program) do prior[key] = value end
    local function rollback()
        pcall(function()
            for key in pairs(program) do program[key] = nil end
            for key, value in pairs(prior) do program[key] = value end
            brain.program = program
        end)
    end
    local ok = pcall(function()
        -- All accepted requests use the neutral source task actuator. Follow,
        -- hold, home and leave are SAO person decisions retained in chatMode.
        Bandit.SetProgram(body, "Walker", {})
    end)
    if not ok then
        rollback()
        return false, "source-actuator-failed"
    end
    if not brain.program or brain.program.name ~= "Walker"
        or brain.program.stage ~= "Prepare" then
        rollback()
        return false, "source-actuator-unconfirmed" end
    -- The source setters change only program/stage. Recheck the exact queue
    -- before dropping disposable motion so a concurrent protected task wins.
    local currentTasks, currentSnapshot = sourceChatQueue(brain, rec)
    if currentTasks ~= tasks or not currentSnapshot
        or #currentSnapshot ~= #snapshot then
        rollback()
        return false, "source-task-changed" end
    for index = 1, #snapshot do
        if currentSnapshot[index] ~= snapshot[index] then
            rollback()
            return false, "source-task-changed" end
    end
    local cleared = pcall(function() brain.tasks = {} end)
    if not cleared or type(brain.tasks) ~= "table" or #brain.tasks ~= 0 then
        rollback()
        return false, "source-task-transition-failed" end
    return true
end

-- The selected source chat panel and emotes call BWOChat.Say. For an exact
-- Week One person, only actual player speech that this body can hear enters
-- the person's own Standing decision. Source program setters execute a
-- received, accepted request; they never create a SAO group or loyalty flag.
function W.onSourceChat(brain, body, player, text, quiet, envelope)
    if envelope ~= nil then
        local correlation = type(envelope) == "table"
            and type(envelope.correlationId) == "string"
            and envelope.correlationId:match("^native%-speech%-(.+)$") or nil
        if type(envelope) ~= "table"
            or envelope.source ~= "Mousecat-native-speech"
            or envelope.inputMode ~= "typed" and envelope.inputMode ~= "dictated"
            or type(correlation) ~= "string" or #correlation > 32
            or correlation:find("[%z\1-\31\127]") then
            return false, "invalid-source-envelope" end
        for key in pairs(envelope) do
            if key ~= "source" and key ~= "inputMode"
                and key ~= "correlationId" then
                return false, "invalid-source-envelope" end
        end
    end
    if type(text) ~= "string" or #text == 0 or #text > 512
        or not text:find("%S") or text:find("[%z\1-\31\127]") then
        return false, "invalid-utterance" end
    if not player or not getSpecificPlayer or getSpecificPlayer(0) ~= player
        or not (SAO.Standing and SAO.Standing.playerKey
            and SAO.Standing.companyStanding and SAO.Standing.groupOf
            and SAO.Standing.trust and SAO.Standing.isHostileTo)
        or not (BanditBrain and BanditBrain.Get) then
        return false, "speaker-unavailable" end
    local okBrain, selected = pcall(BanditBrain.Get, body)
    if not okBrain or selected ~= brain then return false, "brain-mismatch" end
    local personId, reason = W.observeBrain(brain, body)
    if not personId then return false, reason end
    local rec = SAO.Identity.get(personId)
    local phase = rec and rec.weekOne
    if not phase or phase.pending or phase.status ~= "external"
        or SAO.Claims.heldBy(rec) ~= OWNER then
        return false, "owner-changed" end
    local playerKey = SAO.Standing.playerKey(player)
    if type(playerKey) ~= "string" or playerKey == "" then
        return false, "player-identity-unavailable" end
    -- The source's quiet Q/horn path does not prove that these exact words
    -- were spoken. Only the normal panel/emote path emits this utterance.
    if quiet == true then return false, "source-quiet-unverified" end
    local emitted = pcall(function() player:Say(text) end)
    if not emitted then return false, "native-speech-unavailable" end
    if not (SAOJavaBridge and SAOJavaBridge.weekOneCanHearPlayer) then
        return false, "native-hearing-unavailable" end
    local okHeard, heard = pcall(function()
        return SAOJavaBridge:weekOneCanHearPlayer(player, body,
            rec.id, brain.id, brain.born)
    end)
    if not okHeard or heard ~= true then return false, "not-heard" end

    local intent = sourceChatIntent(text)
    local decision, response = "heard", nil
    local companion = phase.chatCompanion
    local sameCompanion = type(companion) == "table"
        and companion.playerKey == playerKey
        and companion.source == "heard-player-request"
        and finite(companion.sinceHours)
        and SAO.Standing.isHostileTo(personId, playerKey) ~= true
        and SAO.Standing.groupOf(personId) == nil
    if intent == "join" then
        local actorGroup = SAO.Standing.groupOf(personId)
        local hostile = SAO.Standing.isHostileTo(personId, playerKey)
        local standing = SAO.Standing.companyStanding(personId, playerKey)
        local options = SandboxVars and SandboxVars.SurvivorAwareness
        local bar = options and tonumber(options.TrustToCompany) or 0.5
        if actorGroup then
            decision, response = "refused", "I have my own people."
        elseif not sameCompanion and (hostile or not finite(standing)
            or standing <= bar) then
            decision, response = "refused", "I don't know you well enough."
        else
            local acted = sourceChatAct(brain, body, rec, "join")
            if acted then
                phase.chatCompanion = { playerKey = playerKey,
                    sinceHours = now(), source = "heard-player-request" }
                phase.chatMode = "follow"
                decision, response = "accepted", "I'll come with you."
            else decision, response = "refused", "I can't follow right now." end
        end
    elseif intent == "hold" or intent == "home" or intent == "leave" then
        if not sameCompanion then
            decision, response = "refused", "I'm not following you."
        else
            local acted = sourceChatAct(brain, body, rec, intent)
            if acted then
                if intent == "leave" then
                    phase.chatCompanion, phase.chatMode = nil, nil
                    response = "I'll go my own way."
                elseif intent == "home" then
                    phase.chatMode, response = "home", "I'll head home."
                else phase.chatMode, response = "hold", "I'll wait here." end
                decision = "accepted"
            else decision, response = "refused", "I can't do that now." end
        end
    elseif intent == "threat" then
        if SAO.Standing.adjustTrust and SAO.Disposition
            and SAO.Disposition.hostilityBar and SAO.Standing.setHostile then
            local trust = SAO.Standing.adjustTrust(personId, playerKey, -0.2)
            local bar = SAO.Disposition.hostilityBar(personId)
            if finite(trust) and finite(bar) and trust <= bar then
                SAO.Standing.setHostile(personId, playerKey, true)
            end
        end
        decision, response = "answered", "Back off."
    elseif intent == "greeting" then
        response = SAO.Standing.isHostileTo(personId, playerKey)
            and "Leave me alone." or "Hello."
        decision = "answered"
    elseif intent == "apology" then
        response, decision = "I heard you.", "answered"
    else
        response, decision = "Can you say that another way?", "uninterpreted"
    end
    phase.lastSpeech = { source = envelope and envelope.source
            or "BWOChat.Say/native-player-speech",
        inputMode = envelope and envelope.inputMode or nil,
        correlationId = envelope and envelope.correlationId or nil,
        playerKey = playerKey, utterance = text:sub(1, 160),
        intent = intent, decision = decision, response = response,
        heardAtHours = now() }
    local answered = pcall(function()
        body:addLineChatElement(response, 0.8, 0.9, 0.8)
    end)
    return true, answered and decision or "response-unavailable"
end

function W.installProgramAdapters()
    if not ZombiePrograms then return false, "program-catalog-unavailable" end
    local installed = 0
    local changed
    for _, name in ipairs(WEEK_ONE_PROGRAMS) do
        local family = ZombiePrograms[name]
        if type(family) == "table" then
            local stages = { "Prepare" }
            for stage in pairs(ownedStages[name] or {}) do
                stages[#stages + 1] = stage
            end
            for stage in pairs(ordinaryStages[name] or {}) do
                stages[#stages + 1] = stage
            end
            for _, stage in ipairs(stages) do
                local key = name .. "." .. stage
                local previous = family[stage]
                if type(previous) == "function" then
                    if programWrapped[key] == previous then
                        installed = installed + 1
                    elseif programWrapped[key] then
                        changed = changed or key
                    else
                        local wrapped = function(body)
                            local brain
                            if body and BanditBrain
                                and type(BanditBrain.Get) == "function" then
                                local ok, current = pcall(BanditBrain.Get, body)
                                if ok then brain = current end
                            end
                            local marked = markedWeekOneActor(brain, body)
                            if type(brain) == "table"
                                and brain.saoWeekOneOrigin == OWNER then
                                local ok, result
                                if stage == "Prepare" then
                                    ok, result = pcall(W.prepareProgram,
                                        brain, body, name)
                                elseif ordinaryStages[name]
                                    and ordinaryStages[name][stage] then
                                    ok, result = pcall(W.ordinaryProgramStage,
                                        brain, body, name, stage)
                                else
                                    ok, result = pcall(W.ownedProgramStage,
                                        brain, body, name, stage)
                                end
                                if ok and result then return result end
                                -- Defer this stamped actor until the private
                                -- scan or exact body contract can recover.
                                return stageResult(stage)
                            end
                            if marked then return stageResult(stage) end
                            return previous(body)
                        end
                        programWrapped[key] = wrapped
                        family[stage] = wrapped
                        installed = installed + 1
                    end
                end
            end
        end
    end
    if changed then
        local s = store()
        if s then s.lastProgramHookConflict = changed end
        return false, "program-hook-changed:" .. changed
    end
    return installed > 0, installed
end

-- BanditUpdate resolves every custom callback through Bandit.GetProgram.
-- Route an unwrapped Week One source name/stage through a stable SAO callback
-- without rewriting brain.program, which remains the source provenance and
-- receives the native SetProgramStage writeback.
local DISPATCH_FAMILY = "SAOWeekOnePrivateDispatcher"
function W.installDispatchAdapter()
    if not (Bandit and type(Bandit.GetProgram) == "function") then
        return false, "source-dispatch-unavailable" end
    local existing = ZombiePrograms and ZombiePrograms[DISPATCH_FAMILY]
    if existing and existing ~= W.dispatchFamily then
        return false, "dispatch-family-conflict" end
    if W.dispatchWrapped then
        if Bandit.GetProgram ~= W.dispatchWrapped
            or not W.dispatchFamily
            or W.dispatchFamily.Main ~= W.dispatchStageWrapped
            or ZombiePrograms[DISPATCH_FAMILY] ~= W.dispatchFamily then
            local s = store()
            if s then s.lastProgramHookConflict = "Bandit.GetProgram" end
            return false, "dispatch-hook-changed" end
        return true
    end
    if not ZombiePrograms then return false, "program-catalog-unavailable" end
    local previous = Bandit.GetProgram
    local dispatchStage = function(body)
        local brain
        if body and BanditBrain and type(BanditBrain.Get) == "function" then
            local ok, current = pcall(BanditBrain.Get, body)
            if ok then brain = current end
        end
        local program = type(brain) == "table" and brain.program
        local stage = type(program) == "table" and program.stage
        if type(brain) == "table" and brain.saoWeekOneOrigin == OWNER then
            local ok, result = pcall(W.dynamicProgramStage, brain, body)
            if ok and result then return result end
        end
        return stageResult(type(stage) == "string" and stage or "Main")
    end
    local family = { Main = dispatchStage }
    local wrapped = function(body)
        local brain
        if body and BanditBrain and type(BanditBrain.Get) == "function" then
            local ok, current = pcall(BanditBrain.Get, body)
            if ok then brain = current end
        end
        if markedWeekOneActor(brain, body) then
            local program = type(brain) == "table" and brain.program
            if type(program) ~= "table" then return nil end
            local name, stage = program.name, program.stage
            if type(name) ~= "string" or type(stage) ~= "string" then
                return nil end
            local source = ZombiePrograms[name]
            local callback = type(source) == "table" and source[stage]
            if callback and (programWrapped[name .. "." .. stage] == callback
                or name == "Active" and stage == "Main"
                    and W.activeWrapped == callback) then
                return program end
            return { name = DISPATCH_FAMILY, stage = "Main" }
        end
        return previous(body)
    end
    W.dispatchFamily = family
    W.dispatchStageWrapped = dispatchStage
    W.dispatchWrapped = wrapped
    ZombiePrograms[DISPATCH_FAMILY] = family
    Bandit.GetProgram = wrapped
    return true
end

W.installProgramAdapters()
W.installDispatchAdapter()
W.installRoleActions()
if Events and Events.OnGameBoot then
    if W.onActiveBoot then Events.OnGameBoot.Remove(W.onActiveBoot) end
    W.onActiveBoot = function() W.installActiveAdapter() end
    Events.OnGameBoot.Add(W.onActiveBoot)
    if W.onProgramsBoot then Events.OnGameBoot.Remove(W.onProgramsBoot) end
    W.onProgramsBoot = function() W.installProgramAdapters() end
    Events.OnGameBoot.Add(W.onProgramsBoot)
    if W.onDispatchBoot then Events.OnGameBoot.Remove(W.onDispatchBoot) end
    W.onDispatchBoot = function() W.installDispatchAdapter() end
    Events.OnGameBoot.Add(W.onDispatchBoot)
    if W.onRoleActionsBoot then Events.OnGameBoot.Remove(W.onRoleActionsBoot) end
    W.onRoleActionsBoot = function() W.installRoleActions() end
    Events.OnGameBoot.Add(W.onRoleActionsBoot)
end

if Events and Events.EveryOneMinute then
    if W.onMinute then Events.EveryOneMinute.Remove(W.onMinute) end
    W.onMinute = function() W.poll() end
    Events.EveryOneMinute.Add(W.onMinute)
end
if Events and Events.OnTick then
    if W.onTick then Events.OnTick.Remove(W.onTick) end
    W.onTick = function()
        W.observeLoadedPerformanceHearings()
        W.onBudgetTick()
        W.observePendingSourceInquiries()
    end
    Events.OnTick.Add(W.onTick)
end
if Events and Events.OnServerCommand then
    if W.onServerEvent then Events.OnServerCommand.Remove(W.onServerEvent) end
    W.onServerEvent = function(module, command, args) W.onServerCommand(module, command, args) end
    Events.OnServerCommand.Add(W.onServerEvent)
end
if Events and Events.OnGameStart then
    if W.onStart then Events.OnGameStart.Remove(W.onStart) end
    W.onStart = function()
        W.installActiveAdapter()
        W.installProgramAdapters()
        W.installDispatchAdapter()
        W.installRoleActions()
        W.poll(true)
    end
    Events.OnGameStart.Add(W.onStart)
end
if Events and Events.OnInitGlobalModData then
    if W.onWorldData then Events.OnInitGlobalModData.Remove(W.onWorldData) end
    W.onWorldData = function() W.rebindWorld() end
    Events.OnInitGlobalModData.Add(W.onWorldData)
end

return W
