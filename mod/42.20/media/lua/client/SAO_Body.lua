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

function Body.materialize(rec)
    if not rec or not rec.id then
        log("materialize refused: no record")
        return nil
    end
    if Body.active[rec.id] then
        log("materialize refused: body already active for " .. rec.id)
        return Body.active[rec.id]
    end

    local slotBefore = localSlotUser()

    -- Construction. Preferred path is the Java agent's shell class: a bare
    -- IsoPlayer that is not a local player is refused by B21's exact-class
    -- render filter (F-009), so only the subclass draws. The bare-Lua path
    -- stays as an explicit fallback (functional but invisible) so the slice
    -- still runs without the agent; the log names which path built the body.
    local body, how
    if SAOJavaBridge then
        local okJ, shell = pcall(function()
            return SAOJavaBridge:spawnShellNamed(rec.forename, rec.surname,
                math.floor(rec.x), math.floor(rec.y), math.floor(rec.z))
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
            desc:setForename(rec.forename)
            desc:setSurname(rec.surname)
        end)
        local okBody, bare = pcall(function()
            return IsoPlayer.new(getCell(), desc, math.floor(rec.x), math.floor(rec.y), math.floor(rec.z))
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

    log("materialized " .. rec.id .. " via " .. tostring(how)
        .. " at " .. rec.x .. "," .. rec.y .. "," .. rec.z
        .. " setNpc=" .. tostring(okFlag) .. " isNpc()=" .. tostring(okRead and flag)
        .. " dressed=" .. tostring(okDress) .. " model=" .. tostring(okModel))

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

    Body.active[rec.id] = body
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
            rec.releasedAtHours = GameTime.getInstance():getWorldAgeHours()
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
