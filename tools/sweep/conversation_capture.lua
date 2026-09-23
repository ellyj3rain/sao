-- Offline authored conversation evidence over current production owners.
-- The result is serialized before returning; no live record escapes.
SAOConversationCapture = {}
local C = SAOConversationCapture

local function required(value, message)
    if not value then C.failureReason = message; error(message) end
    return value
end

local function text(value)
    return type(value) == "string" and value ~= ""
end

function C.take(request)
    C.failureReason = nil
    required(type(request) == "table" and request.inputOrigin == "authored",
        "authored conversation input required")
    for _, key in ipairs({ "runId", "county", "eventId", "personId", "listenerRef", "utterance" }) do
        required(text(request[key]), "conversation field required: " .. key)
    end
    required(request.personId ~= request.listenerRef, "distinct listener required")
    local encode = SAODecisionCapture.encode
    local person = required(SAO.Identity.get(request.personId), "person missing")
    local listener = required(SAO.Identity.get(request.listenerRef), "listener missing")
    required(person.id == request.personId and listener.id == request.listenerRef,
        "participant identity differs")
    required(not person.dead and not listener.dead, "living participants required")
    required(not SAO.Body.get(person.id) and not SAO.Body.get(listener.id),
        "capture host requires bodyless participants")
    local hour = SAO.History.countyHours()
    local tick = SAO.History.ticks()
    required(type(hour) == "number" and type(tick) == "number"
        and tick == SAO.History.ticksFromHours(hour), "clock binding differs")
    local instant = required(SAO.History.countyInstant(hour), "calendar unavailable")
    local origin = required(SAO.History.countyInstant(0), "calendar anchor unavailable")
    local beliefs = required(SAO.Perception.beliefs[person.id], "private beliefs unavailable")
    local world = required(person.worldKnowledge, "world knowledge unavailable")
    required(world.schemaVersion == 2 and type(world.presence) == "table"
        and type(world.acquisitions) == "table" and not world.pendingPresence,
        "world knowledge unsupported")
    local readOwners = required(SAOConversationHost and SAOConversationHost.readOwners,
        "owner snapshot reader unavailable")
    local before = encode(readOwners())
    local revision = SAO.Perception.beliefVersion
    local snapshotRef = request.runId .. "/" .. request.county .. "/" .. request.eventId
    local catalogue, coverage = SAO.Knowledge.catalogueEvidence(person.id,
        listener.id, tick, snapshotRef)
    if not catalogue then
        return encode({ schema = "sao-conversation-capture-refusal", schemaVersion = 1,
            coverage = coverage, eventId = request.eventId })
    end
    coverage.unavailableInputs = {}
    if not SAO.Body.get(person.id) then
        coverage.unavailableInputs = { "loaded-controller-pressure", "native-current-needs",
            "native-current-bite" }
    end
    local context = { personId = person.id, listenerRef = listener.id,
        atTick = tick, utterance = request.utterance,
        situation = { kind = "authored-conversation", atHour = hour,
            personPosition = { x = person.x, y = person.y, z = person.z },
            listenerPosition = { x = listener.x, y = listener.y, z = listener.z } } }
    local value = { schema = "sao-conversation-observation", schemaVersion = 1,
        snapshotRef = snapshotRef,
        namespace = { runId = request.runId, county = request.county,
            eventId = request.eventId, personId = person.id, hour = hour },
        inputOrigin = "authored", catalogue = catalogue, context = context,
        calendar = { owner = "SAO.History", atHour = hour, atInstant = instant,
            anchorHour = 0, anchorInstant = origin, ticksPerHour = SAO.History.TICKS_PER_HOUR },
        coverage = coverage,
        sourceState = { person = person, listener = listener, beliefs = beliefs,
            worldRetention = SAO.WorldKnowledge.observe(person.id, hour),
            ownerStateBytes = before },
        ownerRevisions = { perception = revision, personUpdateCounter = person.updatedAt,
            listenerUpdateCounter = listener.updatedAt },
        standing = "captured-authored-input", trainingEligible = false }
    if request.includeBehavior then
        local behavior, why = SAO.Knowledge.behaviorEvidence(person.id, listener.id, tick)
        required(behavior, why or "behavior unavailable")
        value.schemaVersion = 2
        value.behavior = behavior
    end
    local frozen = encode(value)
    required(SAO.History.countyHours() == hour and SAO.History.ticks() == tick
        and SAO.Perception.beliefVersion == revision
        and SAO.Identity.get(request.personId) == person
        and SAO.Identity.get(request.listenerRef) == listener
        and SAO.Perception.beliefs[request.personId] == beliefs
        and encode(readOwners()) == before,
        "source changed during capture")
    return frozen
end

return C
