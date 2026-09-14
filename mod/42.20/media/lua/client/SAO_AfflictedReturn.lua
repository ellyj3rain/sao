-- SAO_AfflictedReturn.lua - the reverted come back ([C116]).
--
-- The afflicted are the county's own mid-course people ([MUTATION.md]):
-- a body the pathogen was turning that drew back out of the turn, the
-- form's residue riding what capability survived it. The sister's
-- pathogen already reverts them (terminalState "afflicted", the
-- retained ability scaling the residue) - and until this pass the
-- county they came from never took them back: the record stayed a
-- death record, the body stayed the risen corpse the sister drives,
-- and a person who came back was nobody's.
--
-- This pass is the return, and it is a fact-reading, not a decision:
-- the pathogen's own draw licensed the reversion, and the adoption
-- follows the state. Once per county day, for every person the sister
-- holds whose state says afflicted:
--
--   - a live body is minted where their risen corpse stands (or at
--     their last ground, if the corpse is out of the world), through
--     the same materialize every awakening uses.
--   - the record's death flag turns - not an undoing of the death
--     (diedAtHours and deathCause stay; the person DID die - out
--     there, and it is still true) but the county's present-tense
--     judgment that they are gone, which the reversion overturned.
--     Everything markDead's funnel dropped stays dropped: they come
--     back with no beliefs, no voice, no company, a stranger to their
--     own house, which is what coming back from that is. The flags
--     turn only after the mint succeeded - a refused materialize
--     leaves the record exactly as it was and the next county day
--     tries again.
--   - the pathogen's own form marks are stamped on the live body's
--     modData, so what the scanner reports about them is what they
--     carry - the ghoul shape is visible, and what survivors do with
--     what they see is the pressure chain's business, not ours.
--
-- The risen corpse itself is the sister's body to lay down: ZAO owns
-- the turned body, and its release of a reverted body this county has
-- re-adopted is named in both repos' records as the sister's half.
-- Until it lands, the corpse and the returned person can share a
-- county, and the county's reunions and fears will be honest about
-- both.
--
-- The house argument, the cast-out and the gather are NOT here: those
-- are standing's questions, and standing gets its own batch.

SAO = SAO or {}
SAO.AfflictedReturn = SAO.AfflictedReturn or {}
local Return = SAO.AfflictedReturn

local function log(msg) SAO.Log.line("PATH", msg) end

-- Where the risen corpse stands, if the sister has it in the world.
local function corpseOf(personId)
    local controlled = ZAO and ZAO.Controller
        and ZAO.Controller.controlled or nil
    return controlled and controlled[personId] or nil
end

-- Whether this person's return is this pass's to mint: the state said
-- afflicted, the record says they went through the county's death, no
-- live body exists, and no earlier return is already standing.
local function owed(rec, personId, state)
    if not (rec and rec.id) then return false end
    if not rec.dead then return false end
    if rec.afflictedReturn then return false end
    if state.terminalState ~= "afflicted" then return false end
    if SAO.Body.get(personId) then return false end
    return true
end

function Return.adopt(day)
    if not (ZAO and ZAO.Controller and ZAO.StateStore
        and SAO.Identity and SAO.Body) then
        return false
    end

    local hours = 0
    pcall(function() hours = SAO.History.countyHours() end)

    local adopted = 0
    for personId, _ in pairs(ZAO.Controller.controlled) do
        personId = tostring(personId)
        local okState, state = pcall(function()
            return ZAO.StateStore.read(personId)
        end)
        local rec = nil
        pcall(function() rec = SAO.Identity.get(personId) end)

        if okState and state and owed(rec, personId, state) then
            -- Where they come back: at their risen corpse if it is in
            -- the world, else at their last ground. The corpse is the
            -- sister's to lay down; the position is a fact either way.
            local x, y, z = nil, nil, nil
            local corpse = corpseOf(personId)
            if corpse then
                pcall(function()
                    x, y, z = corpse:getX(), corpse:getY(), corpse:getZ()
                end)
            end
            if not (x and y) then
                x, y = tonumber(rec.x), tonumber(rec.y)
                z = tonumber(rec.z)
            end

            if x and y then
                if not z then z = 0 end
                -- The mint runs first, on the record as it stands; the
                -- flags that say "returned" turn only on success, so a
                -- refused materialize leaves a death record a death
                -- record and the next county day tries again.
                rec.x, rec.y, rec.z = x, y, z
                local body = nil
                pcall(function() body = SAO.Body.materialize(rec) end)

                if body then
                    rec.dead = false
                    rec.turnedDormant = false
                    rec.afflictedReturn = true
                    rec.returnedAtHours = hours

                    -- The form's residue, as marks on the live body:
                    -- the scanner appends what the modData holds, and
                    -- the belief layer already reads it. What
                    -- survivors do with a person shaped like that is
                    -- their pressure chain's business.
                    pcall(function()
                        local data = body:getModData()
                        if type(data) == "table" then
                            data.ZAOForm = state.currentForm or "none"
                            data.ZAOFormPerformance =
                                tonumber(state.formPerformance) or 0.0
                            data.ZAOAttributes = ZAO.Pathogen
                                and ZAO.Pathogen.attributeString(state)
                                or ""
                        end
                    end)

                    adopted = adopted + 1
                    -- The return's own statement reads its hour back:
                    -- how long they were gone is the fact the return
                    -- establishes, and the county log states it beside
                    -- the death's own durable hour, which stays.
                    local gone = ""
                    pcall(function()
                        local returnedAt =
                            tonumber(rec.returnedAtHours)
                        local diedAt = tonumber(rec.diedAtHours)
                        if returnedAt and diedAt
                            and returnedAt >= diedAt then
                            gone = " - gone "
                                .. tostring(math.floor(
                                    (returnedAt - diedAt) / 24.0))
                                .. " days"
                        end
                    end)
                    log(rec.id .. " came back out there" .. gone .. " - "
                        .. tostring(ZAO.Pathogen and ZAO.Pathogen.describe
                            and ZAO.Pathogen.describe(personId)
                            or "afflicted"))
                else
                    log(rec.id .. " could not be minted back - the"
                        .. " next county day tries again")
                end
            end
        end
    end

    return adopted > 0
end

-- [C116] The marks on every live afflicted body, once per county day.
-- The afflicted are not only the returned: a live infected person the
-- pathogen's recovery branch flipped to afflicted never died and
-- needs no adoption - but their live shell carries no marks, and a
-- body without marks reads as a body with nothing on it. The stamp
-- is the pathogen's own state read back onto the body that carries
-- it, on the same cadence the marks decay, so what the scanner
-- reports about a formed person is the form they have TODAY.
function Return.stampLive(day)
    if not (ZAO and ZAO.StateStore and SAO.Body) then
        return false
    end

    local stamped = 0
    for id, body in pairs(SAO.Body.active) do
        id = tostring(id)
        local okState, state = pcall(function()
            return ZAO.StateStore.read(id)
        end)
        if okState and state
            and state.terminalState == "afflicted"
            and body then
            local ok = pcall(function()
                local data = body:getModData()
                if type(data) == "table" then
                    data.ZAOForm = state.currentForm or "none"
                    data.ZAOFormPerformance =
                        tonumber(state.formPerformance) or 0.0
                    data.ZAOAttributes = ZAO.Pathogen
                        and ZAO.Pathogen.attributeString(state) or ""
                end
            end)
            if ok then stamped = stamped + 1 end
        end
    end

    return stamped > 0
end

return SAO.AfflictedReturn