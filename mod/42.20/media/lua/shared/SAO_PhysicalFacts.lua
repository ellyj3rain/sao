-- PhysicalFacts - observations committed at physical interval boundaries.

SAO = SAO or {}
SAO.PhysicalFacts = SAO.PhysicalFacts or {}
local F = SAO.PhysicalFacts
-- [C11] The sandbox mortality window in hours, mirrored from
-- BodyDamage.pickMortalityDuration (javap, F-047): 1 Instant -> 0;
-- 2 -> 0-30 seconds; 3 -> 0.5-1 minute; 4 -> 3-12 hours; 5 -> 2-3
-- DAYS (48-72h, the Apocalypse default); 6 -> 1-2 weeks; 7 Never ->
-- no window (the engine marks those fake-infected, so biteHoursLeft
-- never reports them and this mirror is unreached). Used ONLY when a
-- body went dark infected before the engine stamped its own clock;
-- the trait scaling (Resilient x1.25, Prone to Illness x0.75) is
-- omitted here and stated in the batch record.
local function biteWindowHours()
    local m = 5
    pcall(function() m = SandboxVars.ZombieLore.Mortality or 5 end)
    if m == 1 then return 0 end
    if m == 2 then return SAO.Rand.int(30) / 3600 end
    if m == 3 then return (0.5 + SAO.Rand.int(50) / 100) / 60 end
    if m == 4 then return 3 + SAO.Rand.int(900) / 100 end
    if m == 6 then return 168 + SAO.Rand.int(16800) / 100 end
    return 48 + SAO.Rand.int(2400) / 100
end

-- Physical facts are staged with the body snapshot; readers never see a
-- partly committed handoff. The prior unpicked-clock policy is unchanged.
function F.captureBodyFacts(rec, body, now)
    local inf = SAOJavaBridge:woundInfection(body)
    local left = SAOJavaBridge:biteHoursLeft(body)
    local infected = left ~= nil and left ~= ""
    local deadline = false
    if infected then
        if left == "unpicked" then
            -- Re-reading an unpicked native clock must not move an already
            -- observed deadline forward on every health pass.
            deadline = rec.knoxInfected and rec.biteDeathAtHours
                or now + biteWindowHours()
        else
            local remaining = tonumber(left)
            if not remaining or remaining ~= remaining
                or remaining == math.huge or remaining == -math.huge then
                error("invalid infection clock")
            end
            deadline = now + remaining
        end
    end
    return { woundInfected = inf ~= nil and inf > 0,
        hasRadio = SAO.Standing.ownsRadio(rec.id, body) == true,
        knoxInfected = infected, biteDeathAtHours = deadline,
        newInfection = infected and rec.knoxInfected ~= true }
end

-- Commit one physical observation as one causal interval boundary.  The
-- native clock provides the deadline; the first observation supplies the
-- durable start.  Later observations may refine the deadline without moving
-- the start, and recovery clears the live window while Neuro retains history.
function F.commitBodyFacts(rec, facts, now)
    if not rec or type(facts) ~= "table" then return false end
    now = tonumber(now)
    if not now or now ~= now or now == math.huge or now == -math.huge then
        return false
    end
    local wasInfected = rec.knoxInfected == true
    local infected = facts.knoxInfected == true
    local firstObservation = infected and (facts.newInfection == true
        or not wasInfected or tonumber(rec.infectionStartedAtHours) == nil)
    rec.woundInfected = facts.woundInfected or nil
    rec.knoxInfected = infected or nil
    rec.biteDeathAtHours = facts.biteDeathAtHours or nil
    rec.hasRadio = facts.hasRadio == true
    if firstObservation then
        rec.infectionStartedAtHours = now
        local deadline = tonumber(rec.biteDeathAtHours)
        rec.infectionSpanHours = deadline and deadline > now
            and (deadline - now) or nil
    elseif not infected then
        rec.infectionStartedAtHours = nil
        rec.infectionSpanHours = nil
    end
    -- The physical observation is also the causal boundary for brain health.
    -- This matters when a body leaves the loaded health cadence before the
    -- next ten-minute pass: hibernation/checkpoint still records when sepsis,
    -- toxin clearance, or the Knox window first became the durable facts.
    if SAO.Neuro and SAO.Neuro.observe then
        pcall(SAO.Neuro.observe, rec, now, "body-facts")
    end
    return true
end

-- A loaded body remains the physical owner of wounds and native Knox state.
-- Commit those observations while it is alive rather than waiting for body
-- hibernation.  The pathogen event is emitted only on the false -> true edge.
function F.refreshBodyFacts(rec, body, now)
    if not rec or not body or not SAOJavaBridge then return false end
    now = tonumber(now)
    if not now then
        local ok, value = pcall(SAO.History.countyHours)
        if not ok or type(value) ~= "number" then return false end
        now = value
    end
    local facts = F.captureBodyFacts(rec, body, now)
    if not F.commitBodyFacts(rec, facts, now) then return false end
    if facts.newInfection and SAO.PathogenEvents then
        pcall(function()
            SAO.PathogenEvents.emit("infection", rec.id,
                math.floor(now / 24.0), { record = rec, atHours = now })
        end)
    end
    return true, facts
end

F.biteWindowHours = biteWindowHours
return F
