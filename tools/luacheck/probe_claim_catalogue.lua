-- C75's driven cases over Border 101's stub person.

ClaimCatalogueProbe = {}
local P = ClaimCatalogueProbe

SAO.WorldKnowledge = {
    claimsOf = function(id, atHour)
        if id ~= "p1" then return {} end
        return {
            {
                claimId = "knox-telecommunications-outage-1993-07-02",
                path = "lived",
                acquiredHour = -168,
                carrier = "county",
            },
        }
    end,
}

local function people(reverse)
    local out = {}
    if reverse then
        out.Dana = { x = 120, y = 80, at = 1500,
            source = "observed", condition = "ok" }
        out.Marcus = { dead = true, source = "told", teller = "Dana" }
    else
        out.Marcus = { dead = true, source = "told", teller = "Dana" }
        out.Dana = { x = 120, y = 80, at = 1500,
            source = "observed", condition = "ok" }
    end
    SAO.Perception.beliefs.p1.people = out
end

local function catalogue(snapshotRef, reverse)
    people(reverse == true)
    local result, why = SAO.Knowledge.claimCatalogue(
        "p1", "player:you", 2000, snapshotRef or "event-1")
    if not result then error(why) end
    return result
end

local function direct(snapshotRef, topics)
    return SAO.Knowledge.claimCatalogue(
        "p1", "player:you", 2000, snapshotRef or "event-1", topics)
end

local function entryFor(cat, predicate)
    for _, entry in ipairs(cat.claims) do
        if predicate(entry) then return entry end
    end
    return nil
end

local function selection(cat, entry)
    return {
        snapshotRef = cat.snapshotRef,
        claimRefs = entry and { entry.ref } or {},
    }
end

function P.summary(reverse)
    local cat = catalogue("event-order", reverse)
    local out = {}
    for _, entry in ipairs(cat.claims) do
        out[#out + 1] = table.concat({
            entry.ref,
            entry.topic,
            tostring(entry.fact.fact),
            tostring(entry.fact.name),
            tostring(entry.fact.claimId),
        }, "|")
    end
    return table.concat(out, ";")
end

function P.personCount()
    local count = 0
    for _, entry in ipairs(catalogue().claims) do
        if entry.topic == "person" then count = count + 1 end
    end
    return count
end

function P.worldClaimId()
    local entry = entryFor(catalogue(), function(candidate)
        return candidate.topic == "world"
    end)
    return entry and entry.sourceClaimId or nil
end

function P.uniqueRefs()
    local seen = {}
    for _, entry in ipairs(catalogue().claims) do
        if seen[entry.ref] then return false end
        seen[entry.ref] = true
    end
    return true
end

function P.selectedFenceIsNarrow()
    local cat = catalogue()
    local dana = entryFor(cat, function(entry)
        return entry.topic == "person" and entry.fact.name == "Dana"
    end)
    local flat, why = SAO.Knowledge.flatSelectedClaims(cat,
        selection(cat, dana))
    if not flat then error(why) end
    return string.find(flat, "name=Dana", 1, true) ~= nil
        and string.find(flat, "name=Marcus", 1, true) == nil
        and string.find(flat, "name=Ruth Hall", 1, true) == nil
        and string.find(flat, "claimId=knox", 1, true) == nil
end

function P.emptyFence()
    local cat = catalogue()
    local flat, why = SAO.Knowledge.flatSelectedClaims(cat, selection(cat))
    if flat == nil then error(why) end
    return flat
end

function P.unknownReason()
    local cat = catalogue()
    local _, why = SAO.Knowledge.selectClaims(cat, {
        snapshotRef = cat.snapshotRef,
        claimRefs = { cat.snapshotRef .. "/claim/9999" },
    })
    return why
end

function P.duplicateReason()
    local cat = catalogue()
    local ref = cat.claims[1].ref
    local _, why = SAO.Knowledge.selectClaims(cat, {
        snapshotRef = cat.snapshotRef,
        claimRefs = { ref, ref },
    })
    return why
end

function P.foreignReason()
    local cat = catalogue("event-home")
    local _, why = SAO.Knowledge.selectClaims(cat, {
        snapshotRef = "event-foreign",
        claimRefs = { cat.claims[1].ref },
    })
    return why
end

function P.selectionDetached()
    local cat = catalogue()
    local original = cat.claims[1].fact.fact
    local selected, why = SAO.Knowledge.selectClaims(cat,
        selection(cat, cat.claims[1]))
    if not selected then error(why) end
    selected.claims[1].fact.fact = "changed"
    return cat.claims[1].fact.fact == original
end

function P.catalogueDetached()
    local cat = catalogue()
    SAO.Perception.beliefs.p1.people.Dana.condition = "changed"
    local dana = entryFor(cat, function(entry)
        return entry.topic == "person" and entry.fact.name == "Dana"
    end)
    local unchanged = dana and dana.fact.condition == "ok"
    people(false)
    return unchanged
end

function P.selectionKeepsCatalogueOrder()
    local cat = catalogue()
    local first = cat.claims[1]
    local last = cat.claims[#cat.claims]
    local selected, why = SAO.Knowledge.selectClaims(cat, {
        snapshotRef = cat.snapshotRef,
        claimRefs = { last.ref, first.ref },
    })
    if not selected then error(why) end
    return #selected.claims == 2
        and selected.claims[1].ref == first.ref
        and selected.claims[2].ref == last.ref
end

function P.duplicateTopicReason()
    people(false)
    local _, why = direct("event-topics", { "person", "person" })
    return why
end

function P.cyclicReason()
    people(false)
    local cycle = {}
    cycle.self = cycle
    SAO.Perception.beliefs.p1.people.Dana.attributeMutations = cycle
    local _, why = direct("event-cycle")
    people(false)
    return why
end

function P.nonFiniteReason()
    people(false)
    SAO.Perception.beliefs.p1.people.Dana.at = 0 / 0
    local _, why = direct("event-nan")
    people(false)
    return why
end

function P.deepReason()
    people(false)
    local root, cursor = {}, nil
    cursor = root
    for _ = 1, 20 do
        cursor.next = {}
        cursor = cursor.next
    end
    SAO.Perception.beliefs.p1.people.Dana.attributeMutations = root
    local _, why = direct("event-deep")
    people(false)
    return why
end

function P.totalBudgetReason()
    SAO.Perception.beliefs.p1.people = {}
    for personIndex = 1, 40 do
        local payload = {}
        for fieldIndex = 1, 205 do
            payload["f" .. tostring(fieldIndex)] = fieldIndex
        end
        SAO.Perception.beliefs.p1.people[
            "Person" .. tostring(personIndex)] = {
                source = "observed",
                attributeMutations = payload,
            }
    end
    local _, why = direct("event-budget")
    people(false)
    return why
end

function P.tableWidthReason()
    people(false)
    local payload = {}
    for index = 1, 513 do payload["f" .. tostring(index)] = index end
    SAO.Perception.beliefs.p1.people.Dana.attributeMutations = payload
    local _, why = direct("event-wide")
    people(false)
    return why
end

function P.knownPeopleLimitReason()
    SAO.Perception.beliefs.p1.people = {}
    for index = 1, 513 do
        SAO.Perception.beliefs.p1.people["Person" .. tostring(index)] = {
            source = "observed",
        }
    end
    local _, why = direct("event-people")
    people(false)
    return why
end

function P.claimLimitReason()
    SAO.Perception.beliefs.p1.people = {}
    for index = 1, 260 do
        SAO.Perception.beliefs.p1.people["Person" .. tostring(index)] = {
            dead = true,
            source = "observed",
        }
    end
    local _, why = direct("event-claims")
    people(false)
    return why
end

function P.selectedFenceLimitReason()
    SAO.Perception.beliefs.p1.people = {}
    for index = 1, 100 do
        SAO.Perception.beliefs.p1.people["Person" .. tostring(index)] = {
            at = index,
            source = "source" .. tostring(index),
            teller = "teller" .. tostring(index),
            condition = "condition" .. tostring(index),
            form = "form" .. tostring(index),
            formPerformance = index,
        }
    end
    local cat, why = direct("event-fence")
    if not cat then
        people(false)
        return why
    end
    local refs = {}
    for _, entry in ipairs(cat.claims) do
        if entry.topic == "person" then refs[#refs + 1] = entry.ref end
    end
    local _, fenceWhy = SAO.Knowledge.flatSelectedClaims(cat, {
        snapshotRef = cat.snapshotRef,
        claimRefs = refs,
    })
    people(false)
    return fenceWhy
end

function P.tamperedWorldSourceReason()
    local cat = catalogue()
    local world = entryFor(cat, function(entry)
        return entry.topic == "world"
    end)
    world.sourceClaimId = nil
    local _, why = SAO.Knowledge.selectClaims(cat, selection(cat, world))
    return why
end

function P.missingConditioningReason()
    local cat = catalogue()
    cat.conditioning = nil
    local _, why = SAO.Knowledge.selectClaims(cat,
        selection(cat, cat.claims[1]))
    return why
end
