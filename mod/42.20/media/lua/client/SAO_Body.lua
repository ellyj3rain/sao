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
    if Body.active[rec.id] then
        log("materialize refused: body already active for " .. rec.id)
        return Body.active[rec.id]
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
                SAO.Identity.femaleOf(rec))
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

function Body.release(rec)
    if not rec or not rec.id then return false end
    local body = Body.active[rec.id]
    if not body then
        log("release: no active body for " .. tostring(rec.id))
        return false
    end
    -- Snapshot back into the record BEFORE removal (persistent person,
    -- temporary body): position, and everything the body carries and is
    -- (F-013 - inventory, hand, vitals pack into one record string).
    pcall(function()
        SAO.Identity.updatePosition(rec, body:getX(), body:getY(), body:getZ())
    end)
    pcall(function()
        local packed = SAOJavaBridge:hibernate(body)
        if type(packed) == "string" and packed ~= "" then
            rec.hibernation = packed
            rec.releasedAtHours = SAO.History.countyHours()
        end
    end)
    -- Java-shell bodies need the full teardown (ModelManager.Remove + intent
    -- clear) which lives bridge-side; bare bodies use the Lua pair.
    local okW, okS
    if SAOJavaBridge and pcall(function() return SAOJavaBridge:isShell(body) end)
        and SAOJavaBridge:isShell(body) then
        okW = pcall(function() return SAOJavaBridge:removeShell(body) end)
        okS = okW
    else
        okW = pcall(function() body:removeFromWorld() end)
        okS = pcall(function() body:removeFromSquare() end)
    end
    Body.active[rec.id] = nil
    log("released " .. rec.id .. " ok=" .. tostring(okW and okS)
        .. " rec now at " .. rec.x .. "," .. rec.y .. "," .. rec.z)
    return okW and okS
end

-- Knox bodies ([A17]): live legacy people resolvable by our id without
-- ever being ours to release or drive.
Body.knox = Body.knox or {}

function Body.get(id)
    id = tostring(id)
    return Body.active[id] or Body.knox[id]
end

function Body.activeCount()
    local n = 0
    for _ in pairs(Body.active) do n = n + 1 end
    return n
end

-- [B47] The other half of the same question. A Knox inhabitant with a
-- shell is as loaded as one of ours - the player can walk up to them
-- either way - and a count that left them out would say the world was
-- emptier than it is.
function Body.knoxCount()
    local n = 0
    for _ in pairs(Body.knox) do n = n + 1 end
    return n
end

return Body
