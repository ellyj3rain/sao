-- SAO_Isolation - the live social-contact spectrum.
--
-- This is a state surface, not a behaviour. It reads the facts the county
-- already holds and reports them as one isolation reading; nothing here
-- writes a relation, a belief, a group, or a body. The two halves are kept
-- separate on purpose: `appetite` is who somebody is, and `isolation` is
-- where they are right now. A loner alone is not the same fact as a house
-- person alone.

SAO = SAO or {}
SAO.Isolation = SAO.Isolation or {}
local I = SAO.Isolation

-- The band circle's own cap is the saturation point. Three living social
-- signals are enough to say the person is not isolated; a larger tolerated
-- circle does not change the fact that company has arrived.
local CONTACT_SATURATION = 3

-- A recent person is one seen, heard, or told about inside one county day.
-- The day is the county's own clock unit, and no new sandbox dial is added.
local RECENT_HOURS = 24

local function numberOr(value, fallback)
    if type(value) ~= "number" then return fallback end
    return value
end

function I.of(id)
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    if not rec or rec.dead then return nil end

    local appetite, circle, capacity = 0.5, "house", 999
    pcall(function()
        appetite = SAO.History.contactFactor(id)
    end)
    appetite = numberOr(appetite, 0.5)
    pcall(function()
        circle = SAO.Disposition.circle(id)
        capacity = SAO.Disposition.circleCap(id)
    end)
    capacity = numberOr(capacity, 999)

    local groupSize = 0
    pcall(function()
        local group = SAO.Standing.groupOf(id)
        if group then
            local fellows = SAO.Standing.fellowsOf(id)
            groupSize = #fellows + 1
        end
    end)

    local nowHours = nil
    pcall(function() nowHours = SAO.History.countyHours() end)

    local knownPeople, recentPeople = 0, 0
    local lastPersonHours = nil
    local b = SAO.Perception.beliefs[id]
    if b and b.people then
        for key, pb in pairs(b.people) do
            local otherId = pb.id or SAO.Identity.idByName(key)
            local other = otherId and SAO.Identity.get(otherId) or nil
            if other and not other.dead and otherId ~= id then
                knownPeople = knownPeople + 1
                local at = numberOr(pb.atHours, 0)
                if at > 0 and nowHours and nowHours - at <= RECENT_HOURS then
                    recentPeople = recentPeople + 1
                end
                if at > 0 and (not lastPersonHours or at > lastPersonHours) then
                    lastPersonHours = at
                end
            end
        end
    end

    local companyAt = 0.5
    pcall(function()
        local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
        companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
    end)

    local trustedPeople = 0
    local lastTrustHours = nil
    pcall(function()
        for otherKey, r in pairs(SAO.Standing.relationsOf(id)) do
            local other = SAO.Identity.get(otherKey) or nil
            if other and not other.dead and otherKey ~= id
                and numberOr(r.trust, 0) >= companyAt then
                trustedPeople = trustedPeople + 1
            end
            local at = numberOr(r.atHours, 0)
            if at > 0 and (not lastTrustHours or at > lastTrustHours) then
                lastTrustHours = at
            end
        end
    end)

    local lastContactHours = nil
    if groupSize > 1 then
        lastContactHours = nowHours or 0
    elseif lastPersonHours or lastTrustHours then
        lastContactHours = math.max(numberOr(lastPersonHours, 0),
            numberOr(lastTrustHours, 0))
    end

    local hoursSinceContact = nil
    if lastContactHours and nowHours then
        hoursSinceContact = math.max(0, nowHours - lastContactHours)
    end

    local contact = math.min(1,
        (groupSize + trustedPeople + recentPeople) / CONTACT_SATURATION)
    local isolation = 1 - contact

    return {
        appetite = appetite,
        circle = circle,
        capacity = capacity,
        groupSize = groupSize,
        knownPeople = knownPeople,
        trustedPeople = trustedPeople,
        recentPeople = recentPeople,
        lastContactHours = lastContactHours,
        hoursSinceContact = hoursSinceContact,
        contact = contact,
        isolation = isolation,
    }
end

SAO.Log.line("ISOLATION", "isolation module loaded")
return I
