-- SAO_Driving — thin Lua face over the bridge's driving loop ([C114]).
-- ---------------------------------------------------------------------------
-- The same discipline SAO_Locomotion holds for walks: the hot path
-- (boarding, the lawful engine start, the steering writes, the stop)
-- lives Java-side in SAODriver, and Lua orders, ticks for a one-line
-- verdict, and logs. Every refusal the engine can name — no car, a
-- taken seat, an engine that will not start, a wall the wheels will
-- not cross — comes back as a DRIVE_* verdict, and the CALLER falls
-- back to the ordinary walk. Nothing here holds an engine object
-- other than the body handle it passes through.

SAO = SAO or {}
SAO.Driving = SAO.Driving or {}
local Drv = SAO.Driving

-- id -> { body, car, goal, lastVerdict, sameVerdictTicks, done, result, faults }
Drv.jobs = Drv.jobs or {}

local STALL_TICKS = 600   -- identical verdict for this long = something is wrong

local function log(msg) SAO.Log.line("DRIVE", msg) end

-- The claim radius the motor pool itself appraises inside ([B19]):
-- the car is re-found by name inside the same circle the claim was
-- made in.
local CLAIM_RADIUS = 15

-- [C114] A goer's drive. Returns true when the trip was ACCEPTED
-- (DRIVE_STARTED); false for every refusal, which the caller answers
-- with the ordinary walk — the honest fallback, not an error.
function Drv.order(id, body, carName, gx, gy)
    if not SAOJavaBridge then
        log("FAIL order " .. tostring(id) .. ": no java bridge")
        return false
    end
    local ok, verdict = pcall(function()
        return SAOJavaBridge:driveBegin(body, CLAIM_RADIUS,
            tostring(carName or ""), gx, gy)
    end)
    if not ok or not tostring(verdict):find("DRIVE_STARTED", 1, true) then
        log("declined " .. tostring(id) .. ": " .. tostring(verdict))
        return false
    end
    Drv.jobs[id] = {
        body = body, car = tostring(carName or ""),
        goal = { x = gx, y = gy },
        lastVerdict = "", sameVerdictTicks = 0,
        done = false, result = nil,
    }
    log("order " .. tostring(id) .. " -> " .. tostring(verdict))
    return true
end

-- [C114] Company boards the car ([B19]'s seat cap made real): the
-- rider walks to the claimed car and takes a passenger seat. Their
-- destination is the driver's — company is where they are going.
function Drv.orderRide(id, body, carName)
    if not SAOJavaBridge then return false end
    local ok, verdict = pcall(function()
        return SAOJavaBridge:rideBegin(body, CLAIM_RADIUS,
            tostring(carName or ""))
    end)
    if not ok or not tostring(verdict):find("RIDE_STARTED", 1, true) then
        log("ride declined " .. tostring(id) .. ": " .. tostring(verdict))
        return false
    end
    Drv.jobs[id] = {
        body = body, car = tostring(carName or ""),
        goal = nil,
        lastVerdict = "", sameVerdictTicks = 0,
        done = false, result = nil,
    }
    log("ride " .. tostring(id) .. " -> " .. tostring(verdict))
    return true
end

-- [C114] The party is known only once people answer the call, so the
-- driver's hold-for-seats count is told AFTER the join decision.
function Drv.holdFor(id, body, seats)
    if not SAOJavaBridge then return end
    pcall(function()
        SAOJavaBridge:driveWaitSeats(body, seats)
    end)
end

local function tickInner(id)
    local job = Drv.jobs[id]
    if not job or job.done then return end

    local ok, verdict = pcall(function()
        return SAOJavaBridge:tickDrive(job.body)
    end)
    if not ok then error(verdict) end
    verdict = tostring(verdict)

    if verdict == job.lastVerdict then
        job.sameVerdictTicks = job.sameVerdictTicks + 1
    else
        log(tostring(id) .. " " .. verdict)
        job.lastVerdict = verdict
        job.sameVerdictTicks = 0
    end

    if verdict == "Succeeded" then
        job.done, job.result = true, "arrived"
        log(tostring(id) .. " PARKED at "
            .. string.format("%.1f,%.1f", job.body:getX(), job.body:getY()))
        return
    end
    if verdict == "IDLE" or verdict:find("DRIVE_", 1, true)
        or verdict:find("RIDE_", 1, true) then
        job.done, job.result = true, verdict
        return
    end
    if job.sameVerdictTicks >= STALL_TICKS then
        job.done, job.result = true, "stalled:" .. verdict
        pcall(function() SAOJavaBridge:cancelDrive(job.body) end)
        log(tostring(id) .. " gave up after " .. STALL_TICKS
            .. " unchanged ticks of " .. verdict)
    end
end

function Drv.tick(id)
    local ok, err = pcall(tickInner, id)
    if ok then return end
    local job = Drv.jobs[id]
    if not job then return end
    job.faults = (job.faults or 0) + 1
    if job.faults == 1 then
        log(tostring(id) .. " tick fault: " .. tostring(err))
    end
    if job.faults >= 3 then
        job.done, job.result = true, "tick-fault"
        pcall(function() SAOJavaBridge:cancelDrive(job.body) end)
        log(tostring(id) .. " disabled after " .. job.faults
            .. " tick faults")
    end
end

function Drv.cancel(id)
    local job = Drv.jobs[id]
    if not job then return end
    pcall(function() SAOJavaBridge:cancelDrive(job.body) end)
    Drv.jobs[id] = nil
    log("cancelled " .. tostring(id))
end

function Drv.status(id)
    local job = Drv.jobs[id]
    if not job then return "none" end
    if job.done then return "done:" .. tostring(job.result) end
    return tostring(job.lastVerdict) .. " x" .. tostring(job.sameVerdictTicks)
end

return Drv