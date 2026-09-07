-- SAO_Locomotion — thin Lua face over the bridge's transplanted movement loop.
-- ---------------------------------------------------------------------------
-- Every walk failure across sao-5..sao-9 was Lua touching engine objects that
-- Kahlua cannot handle (component maps, PathNode fields). The entire hot path
-- — request, route capture, node drive, door/diagonal transitions, arrival —
-- now lives Java-side (SAOMovement, a faithful transplant of the reference
-- loop). Lua orders, ticks for a verdict string, and logs. Nothing here holds
-- an engine object other than the body handle it passes through.

SAO = SAO or {}
SAO.Locomotion = SAO.Locomotion or {}
local Loco = SAO.Locomotion

-- id -> { body, goal, lastVerdict, sameVerdictTicks, done, result, faults }
Loco.jobs = Loco.jobs or {}

local STALL_TICKS = 300   -- identical verdict with no arrival for this long = give up

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("LOCO", msg) end

-- [C18] How far a goal must move before a LIVE route is worth
-- restarting. Under a tile is the same errand; a re-path costs the
-- whole route and any transition in flight.
local RETARGET_REACH = 2.0

function Loco.order(id, body, x, y, z, running)
    if not SAOJavaBridge then
        log("FAIL order " .. tostring(id) .. ": no java bridge")
        return false
    end
    -- [C18] Never restart a route that is already running to this goal.
    --
    -- The controller re-decides on its own cadence, and every decision
    -- re-issued the destination whether or not the last one was still
    -- being walked. Each order recomputes the path from scratch, so the
    -- body advanced about half a tile per re-order and an in-progress
    -- window or fence climb ([C4]) was cancelled mid-transition and
    -- started over - `TURNING_TO_FENCE -> STARTED_FENCE_CLIMB ->
    -- TURNING_TO_FENCE` forever. The route eventually reported Failed,
    -- which returned the survivor to IDLE, where the same believed
    -- threat sent them straight back to FLEE.
    --
    -- The operator's first session on this build: 292 FLEE -> IDLE and
    -- 292 IDLE -> FLEE, and a crowd standing in a yard going nowhere
    -- (F-049). Holding the live route is what lets a walk finish.
    local job = Loco.jobs[id]
    if job and not job.done and job.body == body and job.goal then
        local dx = (job.goal.x or 0) - x
        local dy = (job.goal.y or 0) - y
        if (job.goal.z or 0) == z
            and dx * dx + dy * dy <= RETARGET_REACH * RETARGET_REACH then
            return true
        end
    end
    local ok, verdict = pcall(function()
        if running then return SAOJavaBridge:moveToPaced(body, x, y, z, true) end
        return SAOJavaBridge:moveTo(body, x, y, z)
    end)
    if not ok or not verdict or not tostring(verdict):find("MOVE_STARTED", 1, true) then
        log("FAIL order " .. tostring(id) .. ": " .. tostring(verdict))
        return false
    end
    Loco.jobs[id] = {
        body = body, goal = { x = x, y = y, z = z },
        lastVerdict = "", sameVerdictTicks = 0,
        done = false, result = nil,
    }
    log("order " .. tostring(id) .. " -> " .. x .. "," .. y .. "," .. z)
    return true
end

local function tickInner(id)
    local job = Loco.jobs[id]
    if not job or job.done then return end

    local ok, verdict = pcall(function() return SAOJavaBridge:tickMove(job.body) end)
    if not ok then error(verdict) end
    verdict = tostring(verdict)

    if verdict == job.lastVerdict then
        job.sameVerdictTicks = job.sameVerdictTicks + 1
    else
        log(tostring(id) .. " " .. verdict
            .. " at " .. string.format("%.1f,%.1f", job.body:getX(), job.body:getY()))
        job.lastVerdict = verdict
        job.sameVerdictTicks = 0
    end

    if verdict == "Succeeded" then
        job.done, job.result = true, "arrived"
        log(tostring(id) .. " ARRIVED at "
            .. string.format("%.1f,%.1f", job.body:getX(), job.body:getY()))
        return
    end
    if verdict:find("Failed", 1, true) or verdict == "IDLE" or verdict:find("_FAILED", 1, true) then
        job.done, job.result = true, verdict
        return
    end
    if job.sameVerdictTicks >= STALL_TICKS then
        job.done, job.result = true, "stalled:" .. verdict
        pcall(function() SAOJavaBridge:cancelMove(job.body) end)
        log(tostring(id) .. " gave up after " .. STALL_TICKS
            .. " unchanged ticks of " .. verdict)
    end
end

function Loco.tick(id)
    local ok, err = pcall(tickInner, id)
    if ok then return end
    local job = Loco.jobs[id]
    if not job then return end
    job.faults = (job.faults or 0) + 1
    if job.faults == 1 then
        log(tostring(id) .. " tick fault: " .. tostring(err))
    end
    if job.faults >= 3 then
        job.done, job.result = true, "tick-fault"
        pcall(function() SAOJavaBridge:cancelMove(job.body) end)
        log(tostring(id) .. " disabled after " .. job.faults .. " tick faults")
    end
end

function Loco.cancel(id)
    local job = Loco.jobs[id]
    if not job then return end
    pcall(function() SAOJavaBridge:cancelMove(job.body) end)
    Loco.jobs[id] = nil
    log("cancelled " .. tostring(id))
end

function Loco.status(id)
    local job = Loco.jobs[id]
    if not job then return "none" end
    if job.done then return "done:" .. tostring(job.result) end
    return tostring(job.lastVerdict) .. " x" .. tostring(job.sameVerdictTicks)
end

return Loco
