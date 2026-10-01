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

local STALL_TICKS = 300   -- route ticks without physical or waypoint progress
local PROGRESS_REACH = 0.01

local function finite(value)
    value = tonumber(value)
    return value and value == value and value > -math.huge and value < math.huge
        and value or nil
end

local function routeProgress(job)
    local ok, text = pcall(function() return SAOJavaBridge:moveProgress(job.body) end)
    local index, tx, ty, tz
    if ok then
        index, tx, ty, tz = tostring(text):match("^MOVE_PROGRESS@([^@]+)@([^@]+)@([^@]+)@([^@]+)$")
        index, tx, ty, tz = finite(index), finite(tx), finite(ty), finite(tz)
    end
    if not (index and tx and ty and tz) then
        local retained = job.progress
        if retained then
            index, tx, ty, tz = retained.index, retained.x, retained.y, retained.z
        else
            index, tx, ty, tz = -1, job.goal.x, job.goal.y, job.goal.z
        end
    end
    local x, y, z = finite(job.body:getX()), finite(job.body:getY()), finite(job.body:getZ())
    if not (x and y and z) then return false end
    local distance = math.sqrt((tx - x)^2 + (ty - y)^2 + (tz - z)^2)
    local prior = job.progress
    if not prior or prior.index ~= index or prior.x ~= tx or prior.y ~= ty or prior.z ~= tz then
        job.progress = { index = index, x = tx, y = ty, z = tz, distance = distance }
        return true
    end
    if distance <= prior.distance - PROGRESS_REACH then
        prior.distance = distance
        return true
    end
    return false
end

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("LOCO", msg) end

local function observed(id, stage, job, reason)
    if not SAO.Observation then return end
    local goal = job and job.goal
    local destination = goal and (tostring(goal.x) .. "," .. tostring(goal.y) .. "," .. tostring(goal.z)) or "unavailable"
    pcall(SAO.Observation.record, id, "Locomotion", stage,
        tostring(reason or stage) .. "; destination " .. destination)
end

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
    -- Poor motor steadiness removes sprint pace from an already selected
    -- route; it does not select a different destination or manufacture a new
    -- decision.  Walking remains available.
    if running and SAO.Neuro and SAO.Identity then
        pcall(function()
            local rec = SAO.Identity.get(id)
            if rec and SAO.Neuro.motorSteadiness(rec) < 0.60 then
                running = false
            end
        end)
    end
    -- A known, nearby horse may own a long route. The same native path is
    -- captured as waypoints, while the integrated horse system owns mounting,
    -- collision, stamina, animation, position and dismount outcome.
    if SAO.Animals and SAO.Animals.orderTravel then
        local okHorse, accepted = pcall(SAO.Animals.orderTravel,
            id, body, x, y, z, running)
        if okHorse and accepted then
            Loco.jobs[id] = {
                body = body, goal = { x = x, y = y, z = z }, mode = "horse",
                lastVerdict = "mounting", sameVerdictTicks = 0,
                done = false, result = nil,
            }
            observed(id, "started", Loco.jobs[id], "Horse travel accepted")
            log("horse order " .. tostring(id) .. " -> " .. x .. "," .. y .. "," .. z)
            return true
        end
    end
    local ok, verdict = pcall(function()
        if running then return SAOJavaBridge:moveToPaced(body, x, y, z, true) end
        return SAOJavaBridge:moveTo(body, x, y, z)
    end)
    if not ok or not verdict or not tostring(verdict):find("MOVE_STARTED", 1, true) then
        log("FAIL order " .. tostring(id) .. ": " .. tostring(verdict))
        observed(id, "refused", { goal = { x = x, y = y, z = z } }, verdict)
        return false
    end
    if job and not job.done then observed(id, "replaced", job, "Accepted a different route") end
    Loco.jobs[id] = {
        body = body, goal = { x = x, y = y, z = z },
        lastVerdict = "", sameVerdictTicks = 0,
        done = false, result = nil,
    }
    observed(id, "started", Loco.jobs[id], "Native move accepted")
    log("order " .. tostring(id) .. " -> " .. x .. "," .. y .. "," .. z)
    return true
end

local function tickInner(id)
    local job = Loco.jobs[id]
    if not job or job.done then return end

    if job.mode == "horse" then
        local verdict = SAO.Animals and SAO.Animals.tickTravel
            and SAO.Animals.tickTravel(id) or "failed:horse-owner-unavailable"
        if verdict ~= job.lastVerdict then
            log(tostring(id) .. " horse " .. tostring(verdict))
            job.lastVerdict, job.sameVerdictTicks = verdict, 0
        else job.sameVerdictTicks = job.sameVerdictTicks + 1 end
        if verdict == "arrived" then
            job.done, job.result = true, "arrived"
            observed(id, "arrived", job, "Horse travel completed")
        elseif tostring(verdict):find("failed:", 1, true) == 1 then
            job.done, job.result = true, verdict
            observed(id, "failed", job, verdict)
        end
        return
    end

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
        observed(id, "arrived", job, verdict)
        log(tostring(id) .. " ARRIVED at "
            .. string.format("%.1f,%.1f", job.body:getX(), job.body:getY()))
        return
    end
    if verdict:find("Failed", 1, true) or verdict == "IDLE" or verdict:find("_FAILED", 1, true) then
        job.done, job.result = true, verdict
        observed(id, "failed", job, verdict)
        return
    end
    if routeProgress(job) then
        job.noProgressTicks = 0
    else
        job.noProgressTicks = (job.noProgressTicks or 0) + 1
    end
    if job.noProgressTicks >= STALL_TICKS then
        job.done, job.result = true, "stalled:" .. verdict
        observed(id, "failed", job, job.result)
        pcall(function() SAOJavaBridge:cancelMove(job.body) end)
        log(tostring(id) .. " gave up after " .. STALL_TICKS
            .. " ticks without route progress; " .. verdict)
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
        observed(id, "failed", job, job.result)
        pcall(function() SAOJavaBridge:cancelMove(job.body) end)
        log(tostring(id) .. " disabled after " .. job.faults .. " tick faults")
    end
end

function Loco.expire(id, body, reason)
    local job = Loco.jobs[id]
    if not job or job.body ~= body or job.done or reason ~= "water-approach-expired" then return false end
    job.done, job.result = true, reason
    observed(id, "failed", job, reason)
    pcall(function() SAOJavaBridge:cancelMove(job.body) end)
    return true
end

function Loco.cancel(id)
    local job = Loco.jobs[id]
    if not job then return end
    if job.mode == "horse" and SAO.Animals and SAO.Animals.cancelTravel then
        pcall(SAO.Animals.cancelTravel, id)
    end
    pcall(function() SAOJavaBridge:cancelMove(job.body) end)
    if not job.done then observed(id, "cancelled", job, "Route owner cancelled") end
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
