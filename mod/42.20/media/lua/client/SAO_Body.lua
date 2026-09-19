-- SAO_Body — world representation (ARCHITECTURE runtime layer 2).
-- ---------------------------------------------------------------------------
-- Persistent person, temporary body. materialize() builds an engine body from a
-- record; release() snapshots position back into the record and removes the
-- body. The record never depends on the body existing.
--
-- Verified surface used here: SurvivorFactory.CreateSurvivor (F-008, shipped
-- usage), SurvivorDesc setForename/setSurname (javap), IsoPlayer(cell, desc,
-- x, y, z) (F-004), setNpc on IsoPlayer / isNpc inherited (F-001), players[]
-- slot table (F-006), removeFromWorld/removeFromSquare (F-008).
-- The constructor call from Lua is the [A3] hypothesis this slice still tests.

SAO = SAO or {}
SAO.Body = SAO.Body or {}
local Body = SAO.Body

-- id -> body. Runtime only; never persisted.
Body.active = Body.active or {}
-- Incomplete restoration/discard retains the engine handle until teardown
-- succeeds. Release snapshots themselves live on the durable record.
Body.failedRestore = Body.failedRestore or {}
Body.discarding = Body.discarding or {}

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("BODY", msg) end

local function localSlotUser()
    local ok, lp = pcall(function() return getSpecificPlayer(0) end)
    return ok and lp or nil
end

-- [C26] Where a body may wake (DR-028). Property lines delineate:
-- the operator watched three strangers stand up in their own kitchen
-- (R-006), and ruled the line - "a person never wakes uninvited
-- inside somebody else's held ground." A person's OWN group's claim
-- is home ground (a settled block populates its own houses), and
-- everything between claims is fair game; only a FOREIGN line pushes
-- a waking body out, through its nearest wall, and a home that
-- predated the claim moves with them. And no two of the county's
-- bodies wake on one square - three did, in that kitchen.
-- Just past the wall: outside the line, still on their street -
-- DR-028's between-ground is fair game, so the push is as small as
-- being out at all.
local WAKE_MARGIN = 2

local function wakeSquareFor(rec)
    local x, y = math.floor(rec.x or 0), math.floor(rec.y or 0)
    local moved = nil
    pcall(function()
        local mine = SAO.Standing.groupOf(rec.id)
        for who, c in pairs(SAO.Standing.allGroupClaims()) do
            if who ~= mine
                and x >= c.minX and x <= c.maxX
                and y >= c.minY and y <= c.maxY then
                local nx = ((x - c.minX) <= (c.maxX - x))
                    and (c.minX - WAKE_MARGIN) or (c.maxX + WAKE_MARGIN)
                local ny = ((y - c.minY) <= (c.maxY - y))
                    and (c.minY - WAKE_MARGIN) or (c.maxY + WAKE_MARGIN)
                -- one axis through the nearer wall is enough
                if math.abs(nx - x) <= math.abs(ny - y) then
                    x = nx
                else
                    y = ny
                end
                moved = who
                break
            end
        end
    end)
    local taken = {}
    for _, b in pairs(Body.active) do
        pcall(function()
            taken[math.floor(b:getX()) .. ":" .. math.floor(b:getY())] = true
        end)
    end
    local ox, oy = x, y
    for _, o in ipairs({ {0,0},{1,0},{-1,0},{0,1},{0,-1},
                         {1,1},{-1,-1},{2,0},{0,2} }) do
        if not taken[(ox + o[1]) .. ":" .. (oy + o[2])] then
            x, y = ox + o[1], oy + o[2]
            break
        end
    end
    return x, y, moved
end

function Body.materialize(rec)
    if not rec or not rec.id then
        log("materialize refused: no record")
        return nil
    end
    if rec.dead then return nil, "dead-record" end
    local recovered, recoveryReason = Body.recover(rec)
    if not recovered then return nil, recoveryReason end
    if Body.active[rec.id] then
        log("materialize refused: body already active for " .. rec.id)
        return Body.active[rec.id]
    end

    local elapsed = 0
    if rec.hibernation then
        local ok, valid = pcall(function()
            return SAOJavaBridge:validateHibernation(rec.hibernation)
        end)
        if not ok or valid ~= true then return nil, "invalid-snapshot" end
        local okTime, now = pcall(SAO.History.countyHours)
        if not okTime or type(now) ~= "number" or now ~= now
            or now == math.huge or now == -math.huge then
            return nil, "clock-unavailable"
        end
        elapsed = math.max(0, now - (rec.releasedAtHours or now))
    end
    local wx, wy, movedBy = wakeSquareFor(rec)
    local slotBefore = localSlotUser()

    -- Construction. Preferred path is the Java agent's shell class: a bare
    -- IsoPlayer that is not a local player is refused by B21's exact-class
    -- render filter (F-009), so only the subclass draws. The bare-Lua path
    -- stays as an explicit fallback (functional but invisible) so the slice
    -- still runs without the agent; the log names which path built the body.
    local body, how
    if SAOJavaBridge then
        local okJ, shell = pcall(function()
            -- [C73] The record's sex goes with its name, so the
            -- body the engine builds is the person the county already
            -- has (DR-039). The descriptor's own sex came from
            -- CreateSurvivor and had nothing to agree with.
            return SAOJavaBridge:spawnShellNamed(rec.forename, rec.surname,
                wx, wy, math.floor(rec.z),
                SAO.Identity.femaleOf(rec), false)
        end)
        if okJ and shell then
            body, how = shell, "java-shell"
        else
            log("java bridge spawn failed (" .. tostring(shell) .. "); falling back to bare IsoPlayer")
        end
    end
    if not body then
        local okDesc, desc = pcall(function() return SurvivorFactory.CreateSurvivor() end)
        if not okDesc or not desc then
            log("FAIL desc for " .. rec.id .. ": " .. tostring(desc))
            return nil
        end
        pcall(function()
            -- [C3] Placeholders never overwrite the engine's generated
            -- name - the same rule the Java path enforces.
            if rec.forename ~= "Unnamed" then desc:setForename(rec.forename) end
            if rec.surname ~= "Survivor" then desc:setSurname(rec.surname) end
        end)
        local okBody, bare = pcall(function()
            return IsoPlayer.new(getCell(), desc, wx, wy, math.floor(rec.z))
        end)
        if not okBody or not bare then
            log("FAIL construct for " .. rec.id .. ": " .. tostring(bare))
            return nil
        end
        body, how = bare, "lua-bare"
    end

    -- The trade rides the descriptor ([A18]): where the census life has
    -- an engine-registered profession (vanilla or modded), the body
    -- WEARS it - anything that reads descriptors sees the truth. Rows
    -- without an engine key (clerks, retirees - most of the county)
    -- stay record-side, honestly.
    if SAOJavaBridge and rec.occupation and SAO.Census then
        local row = SAO.Census.rowOf(rec.occupation)
        if row and row.engineKey then
            pcall(function()
                SAOJavaBridge:setProfession(body, row.engineKey)
            end)
        end
    end

    -- Profession defaults precede restoration; native XP replaces them.
    -- Every caller restores before it can adopt or mutate the record.
    if rec.hibernation then
        local ok, journal = pcall(function()
            return SAOJavaBridge:awaken(body, rec.hibernation, elapsed)
        end)
        if not ok or type(journal) ~= "string"
            or journal:sub(1, 9) ~= "AWAKENED " then
            Body.active[rec.id] = body
            Body.failedRestore[rec.id] = true
            Body.recover(rec)
            log("restore refused for " .. rec.id .. ": " .. tostring(journal))
            return nil, "restore-failed"
        end
        log(rec.id .. " awakens: " .. journal)
    end

    local okFlag = pcall(function() body:setNpc(true) end)
    local okRead, flag = pcall(function() return body:isNpc() end)

    -- Visual initialization. Construction alone yields a body with no loaded
    -- model — it exists, occupies a square, and is invisible ([A3] live run).
    -- dressInRandomOutfit + resetModelNextFrame are the verified pair
    -- (IsoGameCharacter, javap; resetModelNextFrame is shipped-Lua idiom).
    -- Random dress belongs to a FIRST body only; an awakened person wears
    -- what their snapshot restores (F-013/F-015 continuity).
    local okDress, dressErr = true, nil
    if not rec.hibernation then
        okDress, dressErr = pcall(function() body:dressInRandomOutfit() end)
    end
    local okModel, modelErr = pcall(function() body:resetModelNextFrame() end)
    if not okDress then log("visual: dressInRandomOutfit threw: " .. tostring(dressErr)) end
    if not okModel then log("visual: resetModelNextFrame threw: " .. tostring(modelErr)) end

    -- [C26] Verified, not assumed (R-006): dressInRandomOutfit
    -- returned cleanly on two bodies the operator watched stand naked
    -- in a kitchen - "dressed=true" was this log believing the call
    -- instead of the body. The bridge counts what is actually WORN,
    -- retries, falls back to a census outfit, and reports which.
    -- Hibernated people are judged after their pack dresses them at
    -- awaken, not here.
    local wornReport = "pack-pending"
    if not rec.hibernation and SAOJavaBridge then
        local fallback = nil
        pcall(function()
            fallback = SAO.Census and SAO.Census.outfitOf
                and SAO.Census.outfitOf(rec.occupation) or nil
        end)
        local okE, rep = pcall(function()
            return SAOJavaBridge:ensureDressed(body, fallback or "OfficeWorker")
        end)
        wornReport = okE and tostring(rep) or ("threw:" .. tostring(rep))
    end

    -- [C29] The body's size, from the age. The woven advice reads it on
    -- the render path from the next frame; an adult answers 1 and the
    -- call is skipped, so nothing changes for anyone grown. The bridge
    -- reports the value it held, which is what the log carries.
    if SAOJavaBridge and SAO.History and SAO.History.heightScaleOf then
        local okS, scale = pcall(SAO.History.heightScaleOf, rec.id)
        if okS and type(scale) == "number" and math.abs(scale - 1.0) > 0.001 then
            local okB, held = pcall(function()
                return SAOJavaBridge:setBodyScale(body, scale)
            end)
            log(rec.id .. " sized " .. tostring(okB and held
                or ("threw:" .. tostring(held))) .. " (age "
                .. tostring(SAO.History.ageOf(rec.id)) .. ")")
        end
    end

    -- [C30] The pace of the age: short legs and old ones both walk
    -- slower than a grown adult's. The engine's own speed modifier,
    -- read from the age once; an adult answers 1 and nothing is set.
    if SAO.History and SAO.History.speedModOf then
        local okP, pace = pcall(SAO.History.speedModOf, rec.id)
        if okP and type(pace) == "number" and math.abs(pace - 1.0) > 0.001 then
            local okM = pcall(function() body:setSpeedMod(pace) end)
            log(rec.id .. " paced " .. string.format("%.2f", pace)
                .. (okM and "" or " (setSpeedMod threw)"))
        end
    end

    -- [C31] The child's day: the strength and fitness of the age
    -- (Growing Up's birthday floors, CREDITS.md), the kit a child
    -- carries, and the pace they learn at - the last held on the shell
    -- so every grant of experience reads it. Floors and kit belong to
    -- a FIRST body; an awakened child carries what their snapshot
    -- restores. Every accessor is javap-verified (ENGINE_CONTRACT F).
    if SAO.History and SAO.History.perkFloorsOf then
        local okA, age = pcall(SAO.History.ageOf, rec.id)
        if okA and type(age) == "number" and age < 18 then
            local strength, fitness = nil, nil
            pcall(function() strength, fitness = SAO.History.perkFloorsOf(age) end)
            local carried = 0
            if not rec.hibernation then
                if strength then
                    pcall(function()
                        body:setPerkLevelDebug(Perks.Strength, strength)
                        body:setPerkLevelDebug(Perks.Fitness, fitness)
                    end)
                end
                local okK, kit = pcall(SAO.History.kitOf, rec.id)
                if okK and type(kit) == "table" then
                    local inv = nil
                    pcall(function() inv = body:getInventory() end)
                    for _, item in ipairs(kit) do
                        if inv and pcall(function() inv:AddItem(item) end) then
                            carried = carried + 1
                        end
                    end
                end
            end
            local learning = "-"
            if SAOJavaBridge then
                pcall(function()
                    learning = tostring(SAOJavaBridge:setXpScale(
                        body, SAO.History.xpScaleOf(age)))
                end)
            end
            log(rec.id .. " is " .. age .. ": strength " .. tostring(strength)
                .. " fitness " .. tostring(fitness) .. ", carries "
                .. carried .. " things, " .. learning)
        end
    end

    -- [C32] The pace of learning, for everyone: the age's ([C31]) times
    -- the conditions' (SAO_Conditions.learningScale - dyslexia, a
    -- focused or a scattered day). The age module refreshes it each
    -- ten-minute pass, since a focus changes by the day.
    if SAOJavaBridge and SAO.History and SAO.History.xpScaleOf then
        pcall(function()
            local scale = SAO.History.xpScaleOf(SAO.History.ageOf(rec.id))
            if SAO.Conditions and SAO.Conditions.learningScale then
                scale = scale * SAO.Conditions.learningScale(rec.id)
            end
            SAOJavaBridge:setXpScale(body, scale)
        end)
    end

    if movedBy then
        log(rec.id .. " woke outside " .. tostring(movedBy)
            .. "'s line at " .. wx .. "," .. wy .. " (DR-028)")
        pcall(function()
            local c = SAO.Standing.allGroupClaims()[movedBy]
            if c and rec.homeX and rec.homeX >= c.minX
                and rec.homeX <= c.maxX and rec.homeY >= c.minY
                and rec.homeY <= c.maxY then
                rec.homeX, rec.homeY = wx, wy
                log(rec.id .. " re-homed off held ground - the line"
                    .. " stands at all times (DR-028)")
            end
        end)
    end
    pcall(function()
        SAO.Identity.updatePosition(rec, wx, wy, math.floor(rec.z or 0))
    end)

    log("materialized " .. rec.id .. " via " .. tostring(how)
        .. " at " .. rec.x .. "," .. rec.y .. "," .. rec.z
        .. " setNpc=" .. tostring(okFlag) .. " isNpc()=" .. tostring(okRead and flag)
        .. " dressed=" .. tostring(okDress) .. " model=" .. tostring(okModel)
        .. " worn=" .. wornReport)

    if localSlotUser() ~= slotBefore then
        log("SLOT VIOLATION for " .. rec.id .. ": local player slot changed (F-006)")
    end

    -- [C39] And the condition rides the trait, by the same law: what
    -- the record drew is stamped onto the body as the engine's own
    -- character trait (vanilla's where vanilla has one), so anything
    -- that reads a trait sees the truth about this person.
    pcall(function()
        local stamped = SAO.Traits.stamp(rec.id, body)
        if stamped > 0 then
            log(rec.id .. " wears " .. stamped .. " condition(s)")
        end
    end)
    -- [C51] And the habit, by the same law and at the same moment.
    pcall(function()
        local stampedH = SAO.Traits.stampHabits(rec.id, body)
        if stampedH > 0 then
            log(rec.id .. " wears " .. stampedH .. " habit(s)")
        end
    end)

    if SAOJavaBridge and how == "java-shell" then
        SAOJavaBridge:accountShell(body)
    end
    Body.active[rec.id] = body
    -- [C8] The person rides the body's modData. The engine copies this
    -- table onto the corpse at death (IsoDeadBody ctor common tail) and
    -- onto whatever rises (reanimate's copyTable) - F-044 - so this one
    -- write is the whole identity chain through the turn. Key name
    -- RATIFIED by the operator (DR-019); the sibling project reads the
    -- same key verbatim.
    pcall(function() body:getModData().SAOPersonId = rec.id end)
    return body
end

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function removeOwned(body)
    local ok, removed = pcall(function()
        if SAOJavaBridge and SAOJavaBridge:isShell(body) then
            return SAOJavaBridge:removeShell(body) == true
        end
        body:removeFromWorld()
        body:removeFromSquare()
        return true
    end)
    return ok and removed == true
end

local function readyToRemove(body)
    local ok, ready = pcall(function()
        -- The Lua queue can hold its next action before it reaches Java.
        local queue = ISTimedActionQueue and ISTimedActionQueue.queues[body]
        if queue and #queue.queue > 0 then return false end
        -- Treatment is queued on the doctor; transfers can name the target
        -- inventory. These actions also own the departing person's state.
        local inventory = body:getInventory()
        for _, otherQueue in pairs(ISTimedActionQueue and ISTimedActionQueue.queues or {}) do
            for _, action in ipairs(otherQueue.queue or {}) do
                for _, reference in pairs(action) do
                    if reference == body or reference == inventory then return false end
                    if SAOJavaBridge and SAOJavaBridge:isInventoryOf(body, reference) then
                        return false
                    end
                end
            end
        end
        if SAOJavaBridge and SAOJavaBridge:isShell(body) then
            return SAOJavaBridge:canReleaseShell(body)
        end
        return body:getVehicle() == nil and body:getCharacterActions():isEmpty()
    end)
    return ok and ready == true
end

local function dropOwner(rec)
    if SAO.Controller then SAO.Controller.drop(rec.id) end
    Body.active[rec.id] = nil
end

function Body.isTransitioning(rec)
    return rec and (rec.bodyRelease ~= nil or Body.failedRestore[rec.id]
        or Body.discarding[rec.id]) or false
end

function Body.release(rec)
    if not rec or not rec.id then return false, "no-record" end
    if Body.failedRestore[rec.id] or Body.discarding[rec.id] then
        return false, "teardown-pending"
    end
    local body = Body.active[rec.id]
    local pending = rec.bodyRelease
    if not pending then
        if not body then return false, "no-owned-body" end
        if not readyToRemove(body) then return false, "body-busy" end
        -- No durable field changes until the complete current capture has
        -- passed validation. A pending copy survives save/load and is never
        -- recaptured from a partly removed body.
        local ok, captured = pcall(function()
            local packed = SAOJavaBridge:hibernate(body)
            if type(packed) ~= "string" or packed == ""
                or SAOJavaBridge:validateHibernation(packed) ~= true then
                return nil
            end
            local now = SAO.History.countyHours()
            local x, y, z = body:getX(), body:getY(), body:getZ()
            if not finite(now) or not finite(x) or not finite(y) or not finite(z) then
                return nil
            end
            local facts = SAO.Population.captureBodyFacts(rec, body, now)
            return { packed = packed, hours = now, x = x, y = y, z = z,
                facts = facts }
        end)
        if not ok or not captured then return false, "capture-failed" end
        pending = captured
        rec.bodyRelease = pending
    end
    local okPending, validPending = pcall(function()
        return SAOJavaBridge:validateHibernation(pending.packed) == true
            and finite(pending.hours) and finite(pending.x)
            and finite(pending.y) and finite(pending.z)
            and type(pending.facts) == "table"
    end)
    if not okPending or not validPending then return false, "invalid-pending-snapshot" end
    if body and not removeOwned(body) then return false, "teardown-failed" end
    -- No body after reload means the old engine representation is gone.
    -- Commit the saved transition before constructing its replacement.
    rec.hibernation = pending.packed
    rec.releasedAtHours = pending.hours
    rec.x, rec.y, rec.z = pending.x, pending.y, pending.z
    local facts = pending.facts
    rec.woundInfected = facts.woundInfected or nil
    rec.knoxInfected = facts.knoxInfected or nil
    rec.biteDeathAtHours = facts.biteDeathAtHours or nil
    rec.hasRadio = facts.hasRadio == true
    dropOwner(rec)
    rec.bodyRelease = nil
    if facts.newInfection then
        pcall(function()
            SAO.PathogenEvents.emit("infection", rec.id,
                math.floor(pending.hours / 24), { record = rec })
        end)
    end
    log("released " .. rec.id .. " at " .. rec.x .. "," .. rec.y .. "," .. rec.z)
    return true, "released"
end

-- Explicit deletion needs teardown, not a replacement snapshot. The caller
-- removes identity only after this succeeds, and can retry on failure.
function Body.discard(rec)
    if not rec or not rec.id then return false, "no-record" end
    if Body.foreign[rec.id] then return false, "foreign-body" end
    local body = Body.active[rec.id]
    if body then
        if not Body.discarding[rec.id] and not rec.bodyRelease
            and not Body.failedRestore[rec.id] and not readyToRemove(body) then
            return false, "body-busy"
        end
        Body.discarding[rec.id] = true
        if not removeOwned(body) then return false, "teardown-failed" end
    end
    dropOwner(rec)
    Body.discarding[rec.id] = nil
    Body.failedRestore[rec.id] = nil
    rec.bodyRelease = nil
    return true, "discarded"
end

function Body.recover(rec)
    if rec.dead then
        if Body.isTransitioning(rec) then return Body.discard(rec) end
        return true
    end
    if Body.discarding[rec.id] then return false, "discard-pending" end
    if Body.failedRestore[rec.id] then
        local body = Body.active[rec.id]
        if body and not removeOwned(body) then return false, "restore-teardown-failed" end
        Body.active[rec.id], Body.failedRestore[rec.id] = nil, nil
    end
    if rec.bodyRelease then return Body.release(rec) end
    return true
end

-- Bodies another system drives ([A17]): live people resolvable by our
-- id without ever being ours to release or drive. [C81] renamed this
-- off one mod's name; what it holds is the property, and the holder
-- is on the record.
Body.foreign = Body.foreign or {}

function Body.get(id)
    id = tostring(id)
    local rec = SAO.Identity.get(id)
    if Body.isTransitioning(rec) then return nil end
    return Body.active[id] or Body.foreign[id]
end

-- Ownership differs from an available body during an incomplete transition.
-- Dormant simulation must not start while that representation is retained.
function Body.hasRepresentation(id)
    id = tostring(id)
    return Body.active[id] ~= nil or Body.foreign[id] ~= nil
        or Body.isTransitioning(SAO.Identity.get(id))
end

function Body.activeCount()
    local n = 0
    for id in pairs(Body.active) do
        if not Body.isTransitioning(SAO.Identity.get(id)) then n = n + 1 end
    end
    return n
end

function Body.pendingTransitionCount()
    local pending, n = {}, 0
    for id in pairs(Body.failedRestore) do pending[id] = true end
    for id in pairs(Body.discarding) do pending[id] = true end
    for id, rec in pairs(SAO.Identity.all()) do
        if rec.bodyRelease then pending[id] = true end
    end
    for _ in pairs(pending) do n = n + 1 end
    return n
end

-- [B47] The other half of the same question. A Knox inhabitant with a
-- shell is as loaded as one of ours - the player can walk up to them
-- either way - and a count that left them out would say the world was
-- emptier than it is.
function Body.foreignCount()
    local n = 0
    for _ in pairs(Body.foreign) do n = n + 1 end
    return n
end

return Body
