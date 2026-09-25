-- SAO_Coordination - one actor-private response policy for every representation.
--
-- Organization owns durable matters, responses and commitments. Communication
-- owns actual reception and return transport. This module owns only the
-- recipient's current appraisal envelope, so the same policy is callable from
-- a loaded controller, a dormant encounter and a headless county episode.

SAO = SAO or {}
SAO.Coordination = SAO.Coordination or {}
local Coordination = SAO.Coordination

local function destinationKnown(proposal)
    local destination = proposal and proposal.destination or nil
    return type(destination) == "table"
        and tonumber(destination.minX) ~= nil
        and tonumber(destination.minY) ~= nil
        and tonumber(destination.maxX) ~= nil
        and tonumber(destination.maxY) ~= nil
end

-- Build only from facts available to this recipient now. A registered
-- external owner may replace the bounded appraisal fields, but cannot create a
-- response or commitment itself and cannot pass diagnosis/diet/private state
-- through fields the common envelope does not admit.
function Coordination.privateContext(id, agent, body, request, ownerLabel)
    if not (SAO.Organization and SAO.Organization.viewFor
        and SAO.Identity and SAO.Identity.get) then return nil end
    id = tostring(id or "")
    local processId = request and request.processId or request
    local processView = SAO.Organization.viewFor(id, processId, false)
    if not processView then return nil end
    local proposal = processView.proposal and processView.proposal.proposal or {}
    local rec = SAO.Identity.get(id)
    local execution, executionUnavailable = {}, false
    if rec and rec.bodyOwner and SAO.Communication
        and SAO.Communication.actorSnapshot then
        local snapshot = SAO.Communication.actorSnapshot(id)
        if type(snapshot) == "table" then
            execution = snapshot
        else
            executionUnavailable = true
        end
    end

    local ownNeed, ownNeedAvailable = 0, true
    if rec and rec.bodyOwner == "ZAO" then
        if tonumber(execution.competingPressure) then
            ownNeed = tonumber(execution.competingPressure)
        else
            ownNeed, ownNeedAvailable = 0, false
        end
    elseif body and SAO.Needs and SAO.Needs.read then
        local needs = SAO.Needs.read(body)
        ownNeed = needs and tonumber(needs.hunger) or 0
    elseif rec then
        ownNeed = tonumber(rec.hunger) or 0
    end

    local originator = processView.originatorId
    local relationship, hostile = 0, false
    pcall(function() relationship = SAO.Standing.trust(id, originator) end)
    pcall(function() hostile = SAO.Standing.isHostileTo(id, originator) end)
    local activity = execution.currentActivity
        and string.lower(tostring(execution.currentActivity))
        or agent and string.lower(tostring(agent.state or "idle"))
        or "dormant"
    local knowsDestination = destinationKnown(proposal)
    local designation = rec and rec.designation or nil
    local prior = processView.response
    local choice = nil
    if hostile then
        choice = "contest"
    elseif activity ~= "idle" and activity ~= "dormant" then
        choice = "defer"
    elseif not ownNeedAvailable then
        choice = "defer"
    elseif ownNeed >= 0.75 then
        choice = "qualify"
    elseif knowsDestination and (designation == "forager"
        or designation == "quartermaster" or relationship >= 0.30
        or (SAO.Lessons and SAO.Lessons.has
            and SAO.Lessons.has(id, "people-are-worth-it"))) then
        choice = "accept"
    elseif knowsDestination then
        choice = "counter-propose"
    else
        choice = "defer"
    end

    local represented = body ~= nil
    if execution.represented ~= nil then
        represented = execution.represented == true
    end
    local owner = ownerLabel or "Controller.coordination"
    local context = {
        owner = owner,
        executor = execution.executor or (rec and rec.bodyOwner == "ZAO"
            and "ZAO.Driver" or "SAO.Controller"),
        bodyOwner = execution.bodyOwner or (rec and rec.bodyOwner) or "SAO",
        currentActivity = activity,
        canAcquire = not executionUnavailable
            and execution.canAcquire ~= false and not (rec and rec.dead),
        canCarry = not executionUnavailable
            and execution.canCarry ~= false and not (rec and rec.dead),
        canDeliver = not executionUnavailable
            and execution.canDeliver ~= false and not (rec and rec.dead),
        canExecute = not executionUnavailable
            and execution.canExecute ~= false and not (rec and rec.dead),
        incapable = executionUnavailable or execution.incapable == true,
        dead = execution.dead == true or rec and rec.dead or false,
        contest = hostile,
        ownNeed = ownNeed,
        relationship = relationship,
        destinationKnown = knowsDestination,
        choice = choice,
        reconsider = prior and prior.response == "defer"
            and choice ~= "defer" or false,
        interests = { designation = designation,
            ownGroup = SAO.Standing.groupOf(id) },
        constraints = { represented = represented,
            currentActivity = activity,
            executionOwnerAvailable = not executionUnavailable,
            ownNeedAvailable = ownNeedAvailable },
        inputOwners = {
            currentActivity = execution.executor
                or (rec and rec.bodyOwner == "ZAO" and "ZAO.Driver")
                or "SAO.Controller",
            capabilities = execution.executor
                or (rec and rec.bodyOwner == "ZAO" and "ZAO.Driver")
                or "SAO.Controller",
            ownNeed = rec and rec.bodyOwner == "ZAO"
                and (execution.inputOwners
                    and execution.inputOwners.competingPressure
                    or "ZAO.Driver")
                or body and "SAO.Needs" or "SAO.Identity",
            relationship = "SAO.Standing",
            interests = "SAO.Identity+SAO.Standing",
            constraints = ownerLabel or "SAO.Controller",
        },
    }

    if rec and rec.bodyOwner and SAO.Communication
        and SAO.Communication.actorAppraisal then
        local supplied = SAO.Communication.actorAppraisal(id, processView,
            context)
        if type(supplied) == "table" then
            for _, key in ipairs({ "owner", "executor", "bodyOwner",
                    "currentActivity", "canAcquire", "canCarry",
                    "canDeliver", "canExecute", "incapable", "dead",
                    "contest", "ownNeed", "relationship",
                    "destinationKnown", "choice", "reconsider", "terms",
                    "interests", "constraints", "inputOwners" }) do
                if supplied[key] ~= nil then context[key] = supplied[key] end
            end
        end
    end
    return context
end

function Coordination.formResponse(id, processId, body, activity, ownerLabel)
    if not (SAO.Organization and SAO.Organization.appraiseMatter) then
        return nil, "organization-unavailable"
    end
    id, processId = tostring(id or ""), tostring(processId or "")
    if id == "" or processId == "" then return nil, "invalid-appraisal" end
    local agent = activity and { state = tostring(activity) } or nil
    local context = Coordination.privateContext(id, agent, body,
        { processId = processId }, ownerLabel)
    if not context then return nil, "process-unavailable" end
    return SAO.Organization.appraiseMatter(processId, id, context), context
end

function Coordination.appraisePending(id, body, activity, ownerLabel)
    if not (SAO.Organization and SAO.Organization.pendingAppraisals) then
        return 0
    end
    id = tostring(id or "")
    local formed = 0
    for _, request in ipairs(SAO.Organization.pendingAppraisals(id)) do
        if request.processId and request.processRevision then
            local response, context = Coordination.formResponse(id,
                request.processId, body, activity, ownerLabel)
            if response then formed = formed + 1 end
            -- A formed response remains private until an actual return
            -- transport reaches the originator. Retry an earlier response too.
            local processView = SAO.Organization.viewFor(
                id, request.processId, false)
            local originator = processView and processView.originatorId
            if originator and SAO.Communication
                and SAO.Communication.deliverPendingResponses then
                SAO.Communication.deliverPendingResponses(id, originator,
                    nil, { reply = response and "immediate" or "retry",
                        activity = context and context.currentActivity
                            or tostring(activity or "dormant") })
            end
        end
    end
    return formed
end

Coordination.appraise = Coordination.appraisePending

return Coordination
