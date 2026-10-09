-- A nearby player's bounded request to a represented SAO person.
-- The marked square is only a chosen destination. Organization owns the
-- proposal, answer and durable procedure; Controller owns native execution.
SAO = SAO or {}
SAO.PlayerObjectives = SAO.PlayerObjectives or {}
local O = SAO.PlayerObjectives
O.marks = O.marks or {}

local OBJECTIVE = "player-marked-watch-return"
local MAX_DISTANCE = 32

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function pointOf(square)
    if not square then return nil end
    local ok, x, y, z = pcall(function()
        return square:getX(), square:getY(), square:getZ()
    end)
    if not ok or not finite(x) or not finite(y) or not finite(z) then
        return nil
    end
    return { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
end

local function place(point)
    return "square " .. point.x .. "," .. point.y .. "," .. point.z
end

local function playerBody(playerObj)
    if not playerObj or not (SAO.Standing and SAO.Standing.playerKey
        and SAO.Communication and SAO.Communication.bodyFor) then
        return nil
    end
    local key = SAO.Standing.playerKey(playerObj)
    if type(key) ~= "string" or key == ""
        or SAO.Communication.bodyFor(key) ~= playerObj then return nil end
    local ok, dead, square = pcall(function()
        return playerObj:isDead(), playerObj:getCurrentSquare()
    end)
    if not ok or dead or not pointOf(square) then return nil end
    return key, pointOf(square)
end

local function recipientBody(id)
    id = tostring(id or "")
    local identity = SAO.Identity and SAO.Identity.get
    local bodies = SAO.Body
    local agents = SAO.Controller and SAO.Controller.agents
    if id == "" or not (identity and bodies and bodies.get and agents) then
        return nil
    end
    local rec = identity(id)
    local body = rec and bodies.get(id)
    local agent = agents[id]
    if not rec or rec.id ~= id or rec.dead or rec.bodyOwner ~= nil
        or not body or not agent or agent.rec ~= rec
        or not bodies.active or bodies.active[id] ~= body
        or bodies.foreign and bodies.foreign[id] ~= nil then return nil end
    local ok, dead, square = pcall(function()
        return body:isDead(), body:getCurrentSquare()
    end)
    if not ok or dead or not pointOf(square) then return nil end
    return body, pointOf(square)
end

local function nearby(playerObj, id)
    local key, at = playerBody(playerObj)
    local body, there = recipientBody(id)
    if not key or not body or at.z ~= there.z then return nil end
    local dx, dy = at.x - there.x, at.y - there.y
    if dx * dx + dy * dy > 25 then return nil end
    if not (SAO.Communication.canConverse
        and SAO.Communication.canConverse(key, id) == true) then return nil end
    return key, at, body, there
end

local function markFor(key)
    local mark = key and O.marks[key]
    if type(mark) ~= "table" or not finite(mark.x)
        or not finite(mark.y) or not finite(mark.z) then return nil end
    return { x = mark.x, y = mark.y, z = mark.z }
end

function O.mark(playerObj, square)
    local key = playerBody(playerObj)
    local point = pointOf(square)
    if not key or not point then return nil, "player-or-square-unavailable" end
    O.marks[key] = point
    return place(point), "marked"
end

function O.markedPlace(playerObj)
    local key = playerBody(playerObj)
    local mark = markFor(key)
    return mark and place(mark) or nil
end

local function objectiveProcess(key, id, openOnly, expectedId,
                                expectedRevision)
    local organization = SAO.Organization
    if not (organization and organization.processes
        and organization.processOrder) then return nil end
    for index = #organization.processOrder, 1, -1 do
        local process = organization.processes[organization.processOrder[index]]
        local revision = process and process.revisions
            and process.revisions[tostring(process.revision)]
        local proposal = revision and revision.proposal
        local scope = proposal and proposal.scope
        if process and process.originatorId == key
            and process.kind == "cooperative-action"
            and proposal and proposal.objective == OBJECTIVE
            and scope and scope.recipientId == id
            and (not expectedId or process.id == expectedId)
            and (not expectedRevision
                or process.revision == expectedRevision)
            and (not openOnly or process.status == "open") then
            return process
        end
    end
    return nil
end

local function offerReady(mark, from, recipient)
    if mark.z ~= from.z or mark.z ~= recipient.z then
        return false, "different-floor"
    end
    local pX, pY = mark.x - from.x, mark.y - from.y
    local rX, rY = mark.x - recipient.x, mark.y - recipient.y
    local playerDistance = pX * pX + pY * pY
    local recipientDistance = rX * rX + rY * rY
    if playerDistance < 64 or recipientDistance < 36 then
        return false, "place-too-near"
    end
    if playerDistance > MAX_DISTANCE * MAX_DISTANCE
        or recipientDistance > MAX_DISTANCE * MAX_DISTANCE then
        return false, "place-too-far"
    end
    return true
end

local function watchDirection(mark, from)
    local function sign(value)
        return value > 0 and 1 or value < 0 and -1 or 0
    end
    return { x = mark.x + 4 * sign(mark.x - from.x),
        y = mark.y + 4 * sign(mark.y - from.y), z = mark.z }
end

local function proposalFor(id, mark, from)
    local dest = { x = mark.x, y = mark.y, z = mark.z }
    local back = { x = from.x, y = from.y, z = from.z }
    return {
        objective = OBJECTIVE,
        continuityOwner = true,
        destination = { minX = mark.x, maxX = mark.x,
            minY = mark.y, maxY = mark.y, z = mark.z },
        scope = { recipientId = id, objective = OBJECTIVE,
            markedPlace = place(mark), returnPlace = place(from),
            returnX = from.x, returnY = from.y, returnZ = from.z },
        procedure = {
            { id = "outbound", verb = "move", capability = "move",
                domain = "movement", role = "helper",
                owner = "SAO.Controller", assignedTo = id,
                target = dest, completesOn = "route:travelling" },
            { id = "watch", verb = "watch", capability = "watch",
                domain = "posture", role = "helper",
                owner = "SAO.Posture", assignedTo = id,
                sameActorAs = "outbound", dependsOn = { "outbound" },
                target = watchDirection(mark, from), posture = "watch",
                durationSeconds = 3,
                completesOn = "posture:maintained" },
            { id = "return", verb = "move", capability = "move",
                domain = "movement", role = "helper",
                owner = "SAO.Controller", assignedTo = id,
                sameActorAs = "watch", dependsOn = { "watch" },
                target = back, completesOn = "route:travelling" },
        },
    }
end

function O.ask(playerObj, id)
    id = tostring(id or "")
    local key, from, body, recipient = nearby(playerObj, id)
    if not key then return nil, "no-current-conversation" end
    local organization = SAO.Organization
    local communication = SAO.Communication
    local coordination = SAO.Coordination
    if not (organization and organization.viewFor and coordination
        and coordination.proposeCooperation and communication
        and communication.exchangeProcesses) then
        return nil, "coordination-unavailable"
    end
    local process = objectiveProcess(key, id, true)
    if process then
        local exchanged = communication.exchangeProcesses(key, id,
            "spoken", { source = "SAO.PlayerObjectives", retry = true })
        return process.id, exchanged and "retried" or "answer-or-transport-pending"
    end
    local mark = markFor(key)
    if not mark then return nil, "no-marked-place" end
    local ready, reason = offerReady(mark, from, recipient)
    if not ready then return nil, reason end
    local proposal = proposalFor(id, mark, from)
    process, reason = coordination.proposeCooperation(key,
        "cooperative-action", proposal, { id }, {
            owner = "SAO.PlayerObjectives", playerOrigin = key,
            markedPlace = place(mark), returnPlace = place(from),
            recipientId = id,
        })
    if not process then return nil, reason or "proposal-refused" end
    -- The first send may be heard without a returned answer. The regular
    -- exchange asks the person's own appraisal owner to respond and retries
    -- the return while current native conversation is still present.
    communication.exchangeProcesses(key, id, "spoken", {
        source = "SAO.PlayerObjectives", processId = process.id })
    return process.id, "recorded"
end

local function completion(process, commitment, stepId)
    local procedure = process.procedures
        and process.procedures[tostring(commitment.revision)]
    local step = procedure and procedure.steps and procedure.steps[stepId]
    local contribution = step and step.contributions
        and step.contributions[commitment.actorId]
    return step and step.status == "completed" and contribution
        and contribution.receiptId or nil
end

-- Inspection projects the returned answer and native attempt evidence. It
-- does not deliver a new work report or record that the player reviewed it.
function O.review(playerObj, id, expectedProcessId, expectedRevision)
    id = tostring(id or "")
    local key = nearby(playerObj, id)
    if not key then return nil, "no-current-conversation" end
    local process = objectiveProcess(key, id, false,
        expectedProcessId, expectedRevision)
    if not process then return nil, "no-objective" end
    local view = SAO.Organization.viewFor(key, process.id, false)
    if not view then return nil, "objective-unavailable" end
    local response = view.responses and view.responses[id]
    local scope = view.proposal and view.proposal.proposal
        and view.proposal.proposal.scope or {}
    local report = SAO.Organization.objectiveReportFor
        and SAO.Organization.objectiveReportFor(process.id, id, key)
    local evidence = SAO.Organization.objectiveAttemptEvidence
        and SAO.Organization.objectiveAttemptEvidence(process.id, id, key)
    local playerReview = SAO.Organization.objectivePlayerReviewFor
        and SAO.Organization.objectivePlayerReviewFor(process.id, id, key)
    return { processId = process.id,
        revision = process.revision,
        markedPlace = scope.markedPlace, returnPlace = scope.returnPlace,
        response = response and response.response or "unanswered",
        answerDelivered = response and response.delivered == true or false,
        workReportDelivered = report ~= nil,
        workReportStatus = report and report.status or nil,
        workOutcome = evidence and evidence.workOutcome or nil,
        commitmentStatus = evidence and evidence.commitmentStatus or nil,
        watchStatus = evidence and evidence.watchStatus or nil,
        attempts = evidence and evidence.attempts or {},
        playerReviewRecorded = playerReview ~= nil,
        withPlayerNow = true }, "inspected"
end

-- The native Review selection is an explicit in-person act. The same current
-- conversation must admit the spoken report and the exact player inspection.
function O.reviewAction(playerObj, id, expectedProcessId, expectedRevision)
    id = tostring(id or "")
    local first, reason = O.review(playerObj, id,
        expectedProcessId, expectedRevision)
    if not first then return nil, reason end
    local key = nearby(playerObj, id)
    if not key then return nil, "no-current-conversation" end
    if not first.workReportDelivered
        and SAO.Communication.deliverObjectiveWorkReport then
        SAO.Communication.deliverObjectiveWorkReport(id, key,
            first.processId)
    end
    local current, why = O.review(playerObj, id,
        first.processId, first.revision)
    if not current then return nil, why end
    if not current.workReportDelivered then
        return current, "work-report-pending"
    end
    local report = SAO.Organization.objectiveReportFor(first.processId,
        id, key)
    if not report then return current, "work-report-unavailable" end
    local recorded, status = SAO.Organization.recordObjectivePlayerReview(
        first.processId, id, key, report.returnReceiptId, playerObj)
    if not recorded then return current, status end
    return O.review(playerObj, id, first.processId, first.revision), status
end

-- Internal outcome inspection uses Organization's originator outcome view.
-- It is never rendered by the person menu as a returned work report.
function O.instrumentedWork(playerObj, id)
    id = tostring(id or "")
    local key = playerBody(playerObj)
    if not key then return nil, "player-unavailable" end
    local process = objectiveProcess(key, id, false)
    if not process then return nil, "no-objective" end
    local view = SAO.Organization.viewFor(key, process.id, true)
    if not view then return nil, "objective-unavailable" end
    local commitment = nil
    for _, candidate in pairs(view.commitments or {}) do
        if candidate.actorId == id and candidate.revision == view.revision then
            commitment = candidate
            break
        end
    end
    local scope = view.proposal and view.proposal.proposal
        and view.proposal.proposal.scope or {}
    local result = { processId = process.id, status = process.status,
        markedPlace = scope.markedPlace, returnPlace = scope.returnPlace,
        commitmentId = commitment and commitment.id,
        commitmentStatus = commitment and commitment.status,
        workPhase = commitment and commitment.work and commitment.work.phase,
        steps = {}, returnedToPlace = false, withPlayerNow = false }
    if commitment then
        for _, stepId in ipairs({ "outbound", "watch", "return" }) do
            result.steps[stepId] = completion(process, commitment, stepId)
        end
        local receiptId = result.steps["return"]
        if receiptId then
            for _, route in ipairs(commitment.work
                    and commitment.work.routeAttempts or {}) do
                if route.id == receiptId and route.status == "arrived"
                    and route.x == scope.returnX
                    and route.y == scope.returnY
                    and route.z == scope.returnZ then
                    result.returnedToPlace = true
                    break
                end
            end
        end
    end
    if result.returnedToPlace then
        result.withPlayerNow = nearby(playerObj, id) ~= nil
    end
    return result, "instrumented"
end

local function attemptDescription(result)
    local parts = {}
    for _, stepId in ipairs({ "outbound", "return" }) do
        local counts = { failed = 0, interrupted = 0,
            arrived = 0, pending = 0 }
        for _, attempt in ipairs(result.attempts or {}) do
            if attempt.stepId == stepId and counts[attempt.status] then
                counts[attempt.status] = counts[attempt.status] + 1
            end
        end
        local statuses = {}
        for _, status in ipairs({ "failed", "interrupted",
                "arrived", "pending" }) do
            if counts[status] > 0 then
                statuses[#statuses + 1] = tostring(counts[status])
                    .. " " .. status
            end
        end
        if #statuses > 0 then
            parts[#parts + 1] = stepId .. ": "
                .. table.concat(statuses, ", ")
        end
    end
    if result.watchStatus == "completed" then
        parts[#parts + 1] = "watch completed"
    end
    return table.concat(parts, "; ")
end

function O.describe(result)
    if not result then return "No recorded objective." end
    local placeName = result.markedPlace or "the marked place"
    local attempts = attemptDescription(result)
    local detail = attempts ~= "" and "; " .. attempts or ""
    if result.workReportDelivered and result.workReportStatus == "completed" then
        return "Returned from " .. placeName
            .. detail .. "; work report delivered"
            .. (result.playerReviewRecorded
                and "; player review recorded." or ".")
    end
    if result.response == "unanswered" then
        return "Request for " .. placeName .. ": no answer has returned."
    end
    if not result.answerDelivered then
        return "Request for " .. placeName .. ": answer has not returned."
    end
    if result.response ~= "accept" then
        return "Request for " .. placeName .. ": "
            .. tostring(result.response) .. "."
    end
    return "Accepted request for " .. placeName
        .. detail .. "; no work report has returned."
end

function O.withdraw(playerObj, id)
    local key = nearby(playerObj, tostring(id or ""))
    local process = key and objectiveProcess(key, tostring(id or ""), true)
    if not process or not (SAO.Organization and SAO.Organization.withdrawMatter)
        then return false, "no-open-objective" end
    return SAO.Organization.withdrawMatter(process.id, key,
        "player-withdrew-objective", { owner = "SAO.PlayerObjectives" })
end

function O.addPersonOptions(menu, playerObj, id)
    if not menu or type(menu.addOption) ~= "function" then return false end
    id = tostring(id or "")
    local key = nearby(playerObj, id)
    if not key then return false end
    local current = objectiveProcess(key, id, true)
    local latest = current or objectiveProcess(key, id, false)
    if current then
        local view = SAO.Organization.viewFor(key, current.id, true)
        local response = view and view.responses and view.responses[id]
        if not (response and response.response == "accept"
            and response.delivered == true) then
            menu:addOption("Repeat marked-place request", nil, function()
                local _, reason = O.ask(playerObj, id)
                O.notify(playerObj, tostring(reason))
            end)
        end
        menu:addOption("Withdraw marked-place request", nil, function()
            local ok, reason = O.withdraw(playerObj, id)
            O.notify(playerObj, ok and "Request withdrawn."
                or tostring(reason))
        end)
    else
        local mark = markFor(key)
        local _, from, _, at = nearby(playerObj, id)
        if mark and from and offerReady(mark, from, at) then
            menu:addOption("Ask them to watch the marked place and return",
                nil, function()
                    local processId, reason = O.ask(playerObj, id)
                    local review = processId and O.review(playerObj, id)
                    O.notify(playerObj, review and O.describe(review)
                        or tostring(reason))
                end)
        end
    end
    if latest then
        local selectedId, selectedRevision = latest.id, latest.revision
        menu:addOption("Review marked-place request", nil, function()
            local review, reason = O.reviewAction(playerObj, id,
                selectedId, selectedRevision)
            O.notify(playerObj, review and O.describe(review)
                or tostring(reason))
        end)
    end
    return true
end

function O.notify(playerObj, message)
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(HaloTextHelper.addText, playerObj, message)
    end
    if SAO.Log and SAO.Log.line then
        SAO.Log.line("OBJECTIVE", tostring(message))
    end
end

function O.resetMarks() O.marks = {} end
for _, eventName in ipairs({ "OnLoad", "OnNewGame", "OnGameStart" }) do
    if Events and Events[eventName] then
        Events[eventName].Remove(O.resetMarks)
        Events[eventName].Add(O.resetMarks)
    end
end

return O
