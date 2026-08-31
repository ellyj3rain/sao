-- SAO_Identity — the Identity layer (ARCHITECTURE runtime layer 1).
-- ---------------------------------------------------------------------------
-- The record is the authoritative person (DR-002). Bodies are temporary and are
-- never the save entity. Records live in global ModData under one key and are
-- plain Lua tables, so engine save/load carries them with no custom IO.
--
-- A record carries: name, position, stamps, origin region, home address
-- (homeX/Y/Z), kitGranted, death (dead/diedAt/diedAtHours), the hibernation
-- snapshot + releasedAtHours ([A11]), and dormant-life fields (dayGoal*,
-- nextDormantMoveAt, [A11]). All plain values; engine save/load carries
-- them with no custom IO.

SAO = SAO or {}
SAO.Identity = SAO.Identity or {}
local Identity = SAO.Identity

local STORE_KEY = "SurvivorAwareness_Records"

-- Name index ([A22]): idByName sits inside per-belief hot loops; at
-- county scale a full-record walk per call is real cost. Lazy index,
-- invalidated by every mutator that can change the name->id mapping.
local nameIndex = nil
local function dropNameIndex() nameIndex = nil end

-- [B47] One door out. `log` is what happened once; `tally` is
-- what happens once per person, counted rather than printed.
local function log(msg) SAO.Log.line("IDENTITY", msg) end
local function tally(kind) SAO.Log.tally("IDENTITY", kind) end

local function store()
    -- ModData.getOrCreate: shipped idiom (forageClient.lua:7).
    local ok, s = pcall(function() return ModData.getOrCreate(STORE_KEY) end)
    if not ok or type(s) ~= "table" then
        log("FAIL store: ModData.getOrCreate -> " .. tostring(s))
        return nil
    end
    s.records = s.records or {}
    s.nextId = s.nextId or 1
    return s
end

function Identity.create(forename, surname, x, y, z)
    local s = store()
    if not s then return nil end
    dropNameIndex()
    local id = "sao-" .. tostring(s.nextId)
    s.nextId = s.nextId + 1
    local rec = {
        id = id,
        forename = tostring(forename or "Unnamed"),
        surname = tostring(surname or "Survivor"),
        x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0,
        createdAt = tostring(getGameTime() and getGameTime():getCalender():getTimeInMillis() or 0),
        updatedAt = 0,
    }
    s.records[id] = rec
    -- [B47] Once per person, and there were 234 of these in the
    -- operator's log. The name is what turns one fact into a flood.
    tally("created")
    return rec
end

-- Adopt an identity under a FIXED id (the inhabitation edge): creates
-- only when absent, never overwrites a living record.
function Identity.ensure(id, forename, surname, x, y, z)
    local s = store()
    if not s then return nil end
    dropNameIndex()
    id = tostring(id)
    if s.records[id] then return s.records[id] end
    local rec = {
        id = id,
        forename = tostring(forename or "Unnamed"),
        surname = tostring(surname or ""),
        x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0,
        createdAt = 0, updatedAt = 0,
    }
    s.records[id] = rec
    log("adopted " .. id .. " (" .. rec.forename .. ")")
    return rec
end

-- Rekey a record in place ([A19] migration): the record BECOMES the
-- new id - history, lessons, and all. No-op when the target exists.
function Identity.rekey(oldId, newId)
    local s = store()
    if not s then return false end
    dropNameIndex()
    oldId, newId = tostring(oldId), tostring(newId)
    local rec = s.records[oldId]
    if not rec or s.records[newId] then return false end
    rec.id = newId
    s.records[newId] = rec
    s.records[oldId] = nil
    log("rekeyed " .. oldId .. " -> " .. newId)
    return true
end

function Identity.get(id)
    local s = store()
    return s and s.records[tostring(id)] or nil
end

function Identity.all()
    local s = store()
    return s and s.records or {}
end

function Identity.updatePosition(rec, x, y, z)
    if not rec then return false end
    rec.x, rec.y, rec.z = tonumber(x) or rec.x, tonumber(y) or rec.y, tonumber(z) or rec.z
    rec.updatedAt = (rec.updatedAt or 0) + 1
    return true
end

function Identity.remove(id)
    local s = store()
    if not s then return false end
    dropNameIndex()
    id = tostring(id)
    if s.records[id] then
        s.records[id] = nil
        log("removed " .. id)
        return true
    end
    return false
end

function Identity.count()
    local n = 0
    for _ in pairs(Identity.all()) do n = n + 1 end
    return n
end

-- Death is durable: the record stays (a person existed and died there), the
-- body's corpse belongs to the engine, and the world does not refill the
-- loss immediately.
function Identity.markDead(rec, tick, cause)
    if not rec or rec.dead then return false end
    rec.dead = true
    -- [B41] `rec.diedAt = tick` used to live here. `tickCounter`
    -- starts at zero every load, so a tick written into a PERSISTED
    -- record stops meaning anything the moment the world reopens -
    -- and nothing read it, which is the only reason it never lied to
    -- anybody. `diedAtHours` below is the durable one and is what all
    -- four readers use (SAO_Harness:1740, SAO_Population:470-471,
    -- SAO_UI:83). The parameter stays: callers pass a tick and this
    -- may want it again, but not in the save.
    rec.deathCause = tostring(cause or "unknown")
    local okH, h = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
    rec.diedAtHours = okH and h or 0
    -- [B38] Every death path funnels here, so the instrument goes
    -- here too rather than on the one call site that prompted it.
    if SAO.Telemetry and SAO.Telemetry.died then
        pcall(SAO.Telemetry.died, rec.id, rec.deathCause)
    end
    -- Every death path funnels here - the wire learns of all of them.
    if SAO.Standing and SAO.Standing.pushRadioNews then
        SAO.Standing.pushRadioNews({ kind = "death", id = rec.id })
    end
    if SAO.Standing and SAO.Standing.forgetSoloListener then
        SAO.Standing.forgetSoloListener(rec.id)
    end
    -- [B51] The county remembers its dead on purpose. Nothing else
    -- was told to forget them.
    --
    -- `Perception.forget` and `Voice.forget` were WRITTEN for exactly
    -- this and called from one place: the harness tearing down a test
    -- id. So every survivor who ever died left their beliefs about
    -- the world and their last spoken line in memory for the session,
    -- and the two pair-keyed cooldowns - one meeting clock, one
    -- doctrine clock - kept an entry for every pair they had ever met
    -- or argued with, entries nothing would read again.
    --
    -- This is the funnel every death path already reaches, which is
    -- why `forgetSoloListener` and the promise lapse above are here
    -- and not on the call sites that prompted them. The rest belong
    -- here for the same reason.
    --
    -- Guarded individually: this module is shared and three of the
    -- four live on the client, so on a server-side load they are
    -- simply absent rather than an error.
    if SAO.Perception and SAO.Perception.forget then
        pcall(SAO.Perception.forget, rec.id)
    end
    if SAO.Voice and SAO.Voice.forget then
        pcall(SAO.Voice.forget, rec.id)
    end
    if SAO.Population and SAO.Population.forgetPairs then
        pcall(SAO.Population.forgetPairs, rec.id)
    end
    if SAO.Standing and SAO.Standing.forgetPolitics then
        pcall(SAO.Standing.forgetPolitics, rec.id)
    end
    -- A queued move outlives the walker: `Loco.cancel` is reached only
    -- from `Ctl.drop`, and death clears the agent registry inline
    -- without going through it. So a dead survivor's job stayed, and
    -- with it a reference to their corpse.
    if SAO.Locomotion and SAO.Locomotion.cancel then
        pcall(SAO.Locomotion.cancel, rec.id)
    end
    if SAO.Controller and SAO.Controller.forget then
        pcall(SAO.Controller.forget, rec.id)
    end
    -- A dead keeper's promises lapse ([B3]) - nobody else inherits an
    -- ask that was made to a face.
    pcall(function()
        local sP = ModData.getOrCreate("SurvivorAwareness_Standing")
        if sP and sP.promises then
            for bittenId, keeperId in pairs(sP.promises) do
                if keeperId == tostring(rec.id) then
                    sP.promises[bittenId] = nil
                end
            end
        end
    end)
    log(rec.id .. " (" .. rec.forename .. " " .. rec.surname .. ") died at "
        .. rec.x .. "," .. rec.y)
    return true
end

function Identity.livingCount()
    local n = 0
    for _, rec in pairs(Identity.all()) do
        if not rec.dead then n = n + 1 end
    end
    return n
end

-- Reverse lookup: the record whose forename matches this observed name.
-- Forenames double as usernames at spawn; collisions take the first match
-- (known limit - a stored unique username per record is the future fix).
-- The one way a record renders as a belief-name ([A24]): forename
-- plus surname when one exists. Every emitter and comparer uses this.
function Identity.displayName(rec)
    if not rec then return nil end
    local surname = rec.surname
    if surname and surname ~= "" and surname ~= "Survivor" then
        return tostring(rec.forename) .. " " .. tostring(surname)
    end
    return tostring(rec.forename)
end

-- [B42] What may be SHOWN to a player, as opposed to what a record
-- renders as internally.
--
-- `displayName` above must keep rendering the sentinel: beliefs are
-- keyed by it (`b.people[name]`) and `idByName` indexes it, so a record
-- that stopped rendering would stop being findable. But "Unnamed" is
-- the ABSENCE of a name, not a name - `backfillName` reads names off
-- the engine shell, so it needs a body, and a survivor the county has
-- never materialised has the sentinel by design.
--
-- `idByName` has always known this (it refuses the sentinel outright);
-- `SAO_Radio` and three sites in `SAO_Controller` each re-spell it.
-- This is that rule with one name, returning nil so the CALLER decides
-- what to say - "Somebody", "them", a count - rather than this
-- function guessing on their behalf.
function Identity.knownName(rec)
    if not rec then return nil end
    local fore = rec.forename
    if not fore or fore == "" or fore == "Unnamed" then return nil end
    return Identity.displayName(rec)
end

function Identity.idByName(name)
    if not name or name == "" or name == "Unnamed" then return nil end
    if not nameIndex then
        nameIndex = {}
        for id, rec in pairs(Identity.all()) do
            -- Full names first-class ([A24]); bare forenames kept as
            -- fallback for player-typed and legacy surfaces. Collisions
            -- resolve lexically-least, deterministic across rebuilds.
            for _, key in ipairs({ Identity.displayName(rec), rec.forename }) do
                if key and key ~= "" then
                    local existing = nameIndex[key]
                    if not existing or id < existing then
                        nameIndex[key] = id
                    end
                end
            end
        end
    end
    return nameIndex[name]
end

-- Name backfill happens outside the mutators (materialize writes
-- rec.forename directly); callers that rename a record must drop the
-- index themselves.
function Identity.noteRenamed() dropNameIndex() end

return Identity
