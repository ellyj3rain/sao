-- SAO_Absorb - the neighbour framework's people become the county's
-- (DR-022, amended by DR-024; the body law is F-051, the profile
-- schema F-052).
--
-- The operator's ruling: SAO absorbs his survivors completely. On
-- world start every one of his people is taken over - his
-- zombie-backed body removed through HIS OWN teardown functions and
-- an SAO record created that carries the whole person; from then on
-- they are ours entirely. His encounter machinery stays live as
-- events (DR-023): a new profile his code creates is absorbed at
-- birth, so encounters still HAPPEN - what walks out of them is one
-- of ours.
--
-- The law this obeys, from his code and not from memory:
--   * KS.SpawnActor is the ONE body-creation choke point (F-051) -
--     every restore, encounter, spouse, beacon and away-return path
--     goes through it and handles nil gracefully. Wrapping it is the
--     whole respawn defense: without the wrap he re-bodies a missing
--     person within ten in-game minutes.
--   * Removal is NOT death (F-051): his grief, memorials and group
--     loss hang on OnZombieDead, which removeFromWorld never fires.
--     So the handoff detaches and removes - it NEVER kills.
--   * His profile rows are never deleted, by him or by us. The
--     county mirrors position and death back into them so his own
--     surfaces stay truthful about people who are now ours.
--   * SAO writes none of his marker keys, ever - his UI and
--     targeting bind to them (F-051's standing rule).

SAO = SAO or {}
SAO.Absorb = SAO.Absorb or {}
local Ab = SAO.Absorb

local function log(msg) SAO.Log.line("ABSORB", msg) end

-- His profile ids live in the county under the same domain the
-- adoption era used: "ks:" .. profile.id.
local function recIdOf(profileId) return "ks:" .. tostring(profileId) end

Ab.absorbed = Ab.absorbed or {}    -- profile.id -> true, session cache

-- [C20] His caps, neutralized at his own single option seam (F-051:
-- every read goes through KS.GetOption). With everyone absorbed, his
-- living count still sees his rows as alive, so his own caps would
-- strangle his encounter stream at 18 forever - the opposite of
-- DR-023's "his encounters stay live." The county sizes the
-- population; these two dials answer large.
local NEUTRALIZED_OPTIONS = {
    MaxPersistentSurvivors = 1000000,
    MaxNearbySurvivors = 1000000,
}

-- Split "Fore Sur" the way the record renders names ([A24]).
local function splitName(name)
    name = tostring(name or "")
    local fore, sur = name:match("^(%S+)%s+(.+)$")
    if fore then return fore, sur end
    if name ~= "" then return name, "" end
    return "Unnamed", "Survivor"
end

-- His durable inventory ledger -> the county's hibernation pack, so
-- SAO's OWN materialize/awaken machinery dresses and equips the
-- person (F-013's format; the ledger schema is F-052's). Nesting and
-- attachments flatten - the items survive, the bags' internal
-- arrangement does not, stated here rather than discovered.
local function packFromProfile(profile)
    local ledger = profile and profile.durableInventory
    local items = ledger and ledger.items
    if type(items) ~= "table" or #items == 0 then return nil end
    local worn, counts, primary = {}, {}, "-"
    local ordered = {}
    local function eat(record)
        if type(record) ~= "table" or type(record.type) ~= "string" then
            return
        end
        local pct = 100
        pcall(function()
            local script = getScriptManager():getItem(record.type)
            local max = script and script:getConditionMax() or 0
            if max and max > 0 and type(record.condition) == "number" then
                pct = math.max(0, math.min(100,
                    math.floor(record.condition * 100 / max)))
            end
        end)
        local key = record.type .. "@" .. pct
        if not counts[key] then
            counts[key] = 0
            ordered[#ordered + 1] = key
        end
        counts[key] = counts[key] + 1
        if record.wornLocation then worn[#worn + 1] = record.type end
        if record.primary then primary = record.type end
        if type(record.contents) == "table" then
            for _, inner in ipairs(record.contents) do eat(inner) end
        end
        if type(record.attachments) == "table" then
            for _, inner in ipairs(record.attachments) do eat(inner) end
        end
    end
    for _, record in ipairs(items) do eat(record) end
    if #ordered == 0 then return nil end
    local parts = {}
    for _, key in ipairs(ordered) do
        parts[#parts + 1] = key .. "*" .. counts[key]
    end
    return "v2;primary=" .. primary .. ";h=0;t=0;hp=-1;worn="
        .. table.concat(worn, ",") .. ";items=" .. table.concat(parts, ",")
end

-- One person, taken whole. Returns the county record id, or nil with
-- the reason logged - and a failed absorption spawns NOBODY (DR-026):
-- the county works or the county visibly does not, and his way is
-- never the fallback.
function Ab.absorbProfile(ns, profile)
    if type(profile) ~= "table" or not profile.id then return nil end
    if profile.alive == false then return nil end
    local id = recIdOf(profile.id)
    local fore, sur = splitName(profile.name)
    local x = math.floor(tonumber(profile.x) or 0)
    local y = math.floor(tonumber(profile.y) or 0)
    local z = math.floor(tonumber(profile.z) or 0)
    local rec = SAO.Identity.ensure(id, fore, sur, x, y, z)
    if not rec then
        log("ABSORB FAILED for " .. tostring(profile.id)
            .. ": no record could be made - nobody spawns (DR-026)")
        return nil
    end
    SAO.Claims.claim(rec, SAO.Claims.KNOX_SURVIVORS)
    if not rec.absorbedAtHours then
        pcall(function()
            rec.absorbedAtHours = SAO.History.countyHours()
        end)
        rec.absorbedAtHours = rec.absorbedAtHours or 0
        -- His archetype label is kept as HIS assertion, not as the
        -- county's verdict: who somebody was is the census and the
        -- history's to decide (the [C20] gate held this line to it).
        -- The label rides as data for any surface that wants to quote
        -- him; the record's own occupation arrives through the same
        -- machinery as everyone else's.
        if profile.role and rec.ksRole == nil then
            rec.ksRole = tostring(profile.role)
        end
        local pack = packFromProfile(profile)
        if pack then rec.hibernation = pack end
        -- His squad members arrive trusting the player who recruited
        -- them; his world-group members keep their company under the
        -- county's own standing machinery. His leader may differ
        -- from the county's election - stated, not hidden.
        if profile.groupId
            and not tostring(profile.groupId):find("^player:") then
            -- [C67] Their house arrives a member at a time, so
            -- joining each one alone left a roster of one and the
            -- widow release freed them before the next arrived - the
            -- Knox company could never assemble here no matter how
            -- many of it the county adopted. The groupId is kept on
            -- the record (their assertion, stored as theirs) and the
            -- house forms from everyone the county has met of it.
            rec.ksGroup = "ksg:" .. tostring(profile.groupId)
            pcall(function()
                local roster = {}
                for otherId, other in pairs(SAO.Identity.all()) do
                    if other.ksGroup == rec.ksGroup and not other.dead then
                        roster[#roster + 1] = otherId
                    end
                end
                SAO.Standing.formCompany(roster, rec.ksGroup)
            end)
        elseif profile.owner then
            pcall(function()
                local me = getSpecificPlayer(0)
                local pkey = me and SAO.Standing.playerKey(me)
                if pkey then SAO.Standing.adjustTrust(id, pkey, 0.4) end
            end)
        end
    end
    -- The body handoff: HIS teardown, never a kill (F-051).
    pcall(function()
        local actor = ns.GetActor and ns.GetActor(profile.id)
        if actor then
            pcall(function()
                SAO.Identity.updatePosition(rec,
                    actor:getX(), actor:getY(), actor:getZ())
            end)
            local lifecycle = (ns.ActionRuntime and ns.ActionRuntime.Lifecycle
                and ns.ActionRuntime.Lifecycle.PROFILE_REMOVAL)
                or "profile-removal"
            if ns.DetachRuntimeActor then
                ns.DetachRuntimeActor(profile, lifecycle, "sao-absorb")
            end
            if ns.RemoveActorShell then
                ns.RemoveActorShell(actor)
            end
        end
    end)
    Ab.absorbed[tostring(profile.id)] = true
    return id
end

-- The one door, closed (F-051). His SpawnActor is wrapped so an
-- absorbed person can never be re-bodied by any of his paths, and a
-- profile his machinery creates NEW (an encounter, the spouse, a
-- beacon visitor) is absorbed at birth - the event happens, the
-- person is ours.
--
-- When absorption itself fails, NOBODY spawns, and the failure is
-- loud - the console names it and the Ledger's not-everything-is-
-- running header carries it. The operator's rule, overriding the
-- first draft's his-spawn fallback: "I would prefer it fail
-- completely than spawn one of his people, because it's not
-- representative of my mod." His original is captured, never called:
-- either the county works, or the county visibly does not.
-- The next restore pulse retries the absorption on its own.
local function wrapSpawnActor(ns)
    if Ab.spawnWrapped then return end
    local hisSpawnActor = ns.SpawnActor
    if type(hisSpawnActor) ~= "function" then
        log("his SpawnActor is not a function; nothing wrapped")
        return
    end
    Ab.hisSpawnActor = hisSpawnActor   -- kept, never called (DR-026)
    ns.SpawnActor = function(profile)
        local ok, id = pcall(Ab.absorbProfile, ns, profile)
        if not ok or not id then
            log("ABSORB FAILED for "
                .. tostring(profile and profile.id or "?")
                .. (ok and "" or (": " .. tostring(id)))
                .. " - nobody spawns rather than one of his (DR-026);"
                .. " the next restore pulse retries")
            pcall(function()
                SAO.Seams.wentDark("absorption",
                    "a person could not be taken over; they are not in "
                    .. "the world this session")
            end)
        end
        return nil
    end
    Ab.spawnWrapped = true
    log("his spawn seam is held: every arrival is absorbed at birth")
end

local function wrapGetOption(ns)
    if Ab.optionWrapped then return end
    local hisGetOption = ns.GetOption
    if type(hisGetOption) ~= "function" then return end
    ns.GetOption = function(name, fallback)
        local override = NEUTRALIZED_OPTIONS[name]
        if override ~= nil then return override end
        return hisGetOption(name, fallback)
    end
    Ab.optionWrapped = true
end

function Ab.absorbAll(ns)
    local taken, failed = 0, 0
    local okData = pcall(function()
        local data = ns.GetWorldData and ns.GetWorldData()
        local survivors = data and data.survivors
        if type(survivors) ~= "table" then return end
        for _, profile in pairs(survivors) do
            if type(profile) == "table" and profile.alive ~= false then
                if Ab.absorbProfile(ns, profile) then
                    taken = taken + 1
                else
                    failed = failed + 1
                end
            end
        end
    end)
    if not okData then
        log("his world data was unreadable; absorption waits for the "
            .. "spawn seam to bring people one at a time")
    end
    log(taken .. " of his people absorbed at start"
        .. (failed > 0
            and (", " .. failed .. " FAILED - not in the world, "
                .. "retried next pulse (DR-026)")
            or ""))
    if failed > 0 then
        pcall(function()
            SAO.Seams.wentDark("absorption",
                failed .. " of his people could not be taken over")
        end)
    end
end

-- The mirror back (DR-022): his rows are never deleted, so his own
-- surfaces keep rendering these people - and would lie about them
-- unless the county writes the truth back. Position while they live;
-- alive=false once, when they die. His death CEREMONIES do not run
-- (they hang on his actors, which no longer exist) - the county's
-- own grief already carries that weight.
function Ab.mirrorBack(ns)
    local okData, data = pcall(function()
        return ns.GetWorldData and ns.GetWorldData()
    end)
    if not okData or type(data) ~= "table"
        or type(data.survivors) ~= "table" then
        return
    end
    for pid in pairs(Ab.absorbed) do
        local profile = data.survivors[pid]
        local rec = SAO.Identity.get(recIdOf(pid))
        if profile and rec then
            if rec.dead then
                if profile.alive ~= false then
                    profile.alive = false
                    profile.health = 0
                end
            else
                profile.x = rec.x or profile.x
                profile.y = rec.y or profile.y
                profile.z = rec.z or profile.z
                pcall(function()
                    profile.lastSeenAt = SAO.History.countyHours()
                end)
            end
        end
    end
end

-- [C23] The overridden dials are DELETED from the options screen, not
-- greyed - the operator's restatement of DR-023: anything this mod
-- overrides is deleted. The removal lives in SAO_Sandbox.lua at the
-- settings-table seam, so the rows are never built; the ENFORCEMENT
-- stays here, at his one option seam, either way.

-- Boot. His OnGameStart handlers registered first (his files load
-- before this one resolves his global), so his initial restore has
-- already bodied people by the time this runs - which is fine: the
-- start sweep takes bodied and unbodied alike, and the wrap holds
-- the door from then on.
local function namespace()
    -- The [C3] lesson: `KS` is a per-file LOCAL in his tree; the real
    -- global is KnoxSurvivors, with KS accepted when some load order
    -- makes it real. Bare reads, the house idiom.
    local short = KS
    if type(short) == "table" and type(short.SpawnActor) == "function" then
        return short
    end
    local full = KnoxSurvivors
    if type(full) == "table" and type(full.SpawnActor) == "function" then
        return full
    end
    return nil
end

-- [C40] DR-035: this county stands on its own, so taking another
-- mod's people over is something the player asks for and not
-- something that happens because both mods are installed. Off, this
-- file never reads their namespace and never wraps a function of
-- theirs; the county is complete without them.
local function bridgeOpen()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return sv ~= nil and sv.NeighbourBridge == true
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if not bridgeOpen() then
            log("the county stands on its own; nothing is absorbed")
            return
        end
        local ns = namespace()
        if not ns then
            log("the neighbour framework is not installed; nothing to absorb")
            return
        end
        wrapSpawnActor(ns)
        wrapGetOption(ns)
        Ab.absorbAll(ns)
    end)
end

if Events and Events.EveryTenMinutes then
    Events.EveryTenMinutes.Add(function()
        if not bridgeOpen() then return end
        local ns = namespace()
        if ns then pcall(Ab.mirrorBack, ns) end
    end)
end

return Ab
