-- Native skill-book study over the person's existing maintained purpose.
require "TimedActions/ISReadABook"

SAO = SAO or {}
SAO.Study = SAO.Study or {}
local S = SAO.Study
local runtime = {}

local function rec(id)
    return SAO.Identity and SAO.Identity.get(id) or nil
end
local function hours()
    return SAO.History.countyHours()
end
local function live(id, body)
    local person = rec(id)
    return person and body and not person.dead and not body:isDead()
        and SAO.Body.get(id) == body and body:isExistInTheWorld()
end
local function held(body, item)
    local items = SAOJavaBridge:privateCarriedItems(body)
    for i = 0, items:size() - 1 do
        if items:get(i) == item then return true end
    end
    return false
end
local function readable(body, item)
    local domain = item:getSkillTrained()
    local book = domain and SkillBook[domain]
    if not book or item:getNumberOfPages() <= 0 then return false end
    local level = body:getPerkLevel(book.perk) + 1
    return not body:hasTrait(CharacterTrait.ILLITERATE)
        and item:getLvlSkillTrained() <= level and item:getMaxLevelTrained() >= level
end
local function eligible(body, item)
    return readable(body, item)
        and body:getAlreadyReadPages(item:getFullType()) < item:getNumberOfPages()
end

-- Script metadata checks a privately observed type without creating an item
-- or claiming that the survivor knows the contents of an uninspected holder.
function S.usefulType(body, fullType, desired)
    local ok, result = pcall(function()
        local item = getScriptManager():getItem(fullType)
        if not item then return false end
        local domain = item:getSkillTrained()
        local definition = domain and SkillBook[domain]
        if not definition or domain ~= desired or item:getNumberOfPages() <= 0 then return false end
        local level = body:getPerkLevel(definition.perk) + 1
        return not body:hasTrait(CharacterTrait.ILLITERATE)
            and item:getLevelSkillTrained() <= level
            and item:getLevelSkillTrained() + item:getNumLevelsTrained() - 1 >= level
            and body:getAlreadyReadPages(fullType) < item:getNumberOfPages()
    end)
    return ok and result == true
end
local function bound(action)
    local person = rec(action.personId)
    local work = person and person.studyWork
    local active = runtime[action.personId]
    return work and work.status == "reading" and active and active.action == action
        and work.id == action.workId and work.purposeId == action.purposeId
        and live(action.personId, action.character)
        and action.character:getModData().SAOExternalToken == action.bodyToken
        and tostring(action.item:getID()) == work.itemId
        and held(action.character, action.item)
end
local function close(action, status, reason)
    local person = rec(action.personId)
    local work = person and person.studyWork
    if not work or work.id ~= action.workId or work.status ~= "reading" then return false end
    local valid = bound(action)
    local pages = valid and action.character:getAlreadyReadPages(work.fullType) or work.pagesBefore
    work.pagesAfter, work.endedAt = pages, hours()
    if status == "completed" and (not valid or pages <= work.pagesBefore
        or pages < work.totalPages) then
        status, reason = "interrupted", "native-reading-not-proven"
    end
    work.status, work.reason = status, reason
    runtime[action.personId] = nil
    if status == "completed" then
        return SAO.ProceduralPlanning.recordResult(action.personId, work.purposeId, {
            owner = "SAONeeds", token = "reading:progressed", status = "completed",
            correlationId = work.id, atHours = work.endedAt,
        })
    end
    SAO.ProceduralPlanning.interrupt(action.personId, work.purposeId, reason, work.endedAt)
    return true
end

SAOStudyAction = ISReadABook:derive("SAOStudyAction")
function SAOStudyAction:isValid()
    return bound(self) and readable(self.character, self.item)
        and ISReadABook.isValid(self)
end
function SAOStudyAction:complete()
    -- Native completion owns pages and the XP multiplier. The receipt only
    -- observes that result, and neither changes a skill nor completes practice.
    if not bound(self) or not readable(self.character, self.item) then
        close(self, "interrupted", "study-owner-or-book-changed")
        return false
    end
    local result = ISReadABook.complete(self)
    if result == true then close(self, "completed") end
    return result
end
function SAOStudyAction:stop()
    close(self, "interrupted", "native-reading-stopped")
    ISReadABook.stop(self)
end
function SAOStudyAction:forceCancel()
    close(self, "interrupted", "native-reading-cancelled")
end

local function queued(action)
    return ISTimedActionQueue and ISTimedActionQueue.hasAction(action) == true
end
function S.interrupt(id, body, reason)
    local person = rec(id)
    local work, active = person and person.studyWork, runtime[id]
    if not work or work.status ~= "reading" then return true end
    if active and active.action.character == body then
        close(active.action, "interrupted", reason or "higher-priority-work")
        -- Clear only the queue containing this owner's exact action.
        if queued(active.action) then ISTimedActionQueue.clear(body) end
    else
        if live(id, body) then work.pagesAfter = body:getAlreadyReadPages(work.fullType) end
        work.status, work.reason, work.endedAt = "interrupted", "study-runtime-unavailable", hours()
        SAO.ProceduralPlanning.interrupt(id, work.purposeId, work.reason, work.endedAt)
        runtime[id] = nil
    end
    return true
end
function S.active(id, body)
    local person = rec(id)
    local work, active = person and person.studyWork, runtime[id]
    if not work or work.status ~= "reading" then return false end
    if active and bound(active.action) and queued(active.action) then return true end
    S.interrupt(id, body, "native-reading-queue-lost")
    return false
end
function S.forget(id)
    local active = runtime[id]
    S.interrupt(id, active and active.action.character, "death")
    runtime[id] = nil
end
function S.beforeQueue(action)
    local body = action and action.character
    if not body then return end
    local id = body:getModData().SAOPersonId
    local active = id and runtime[id]
    if active and active.action ~= action and active.action.character == body then
        S.interrupt(id, body, "different native work")
    end
end

function S.offer(id, body, requiredDomain)
    if not live(id, body) or not SAO.ProceduralPlanning then return nil end
    if SAO.History.literacyOf(id) == "none" then return nil end
    local person, best, bestScore = rec(id), nil, -1
    local designated = SAO.Census.JOB_PERK[person.designation]
    local desired = SAO.Census.bookSkillFor(designated)
    local demand = SAO.ProceduralPlanning.studyDemand(id)
    desired = demand and demand.bookSkill or desired
    local prior = person.studyWork
    local items = SAOJavaBridge:privateCarriedItems(body)
    for i = 0, math.min(items:size(), 128) - 1 do
        local item = items:get(i)
        if instanceof(item, "Literature") and eligible(body, item)
            and (not requiredDomain or item:getSkillTrained() == requiredDomain) then
            local domain = item:getSkillTrained()
            local score = domain == desired and 2 or 1
            if prior and prior.status == "interrupted" and prior.fullType == item:getFullType() then
                score = score + 2
            end
            if score > bestScore or score == bestScore
                and tostring(item:getID()) < tostring(best:getID()) then
                best, bestScore = item, score
            end
        end
    end
    return best
end
function S.begin(id, body, item)
    if not SAO.ProceduralPlanning or not live(id, body) or not held(body, item)
        or not eligible(body, item) or SAO.History.literacyOf(id) == "none"
        or body:tooDarkToRead() or SAO.Needs.busy(body) then return false end
    if S.active(id, body) then return true end
    local person = rec(id)
    local domain, definition = item:getSkillTrained(), SkillBook[item:getSkillTrained()]
    local perk = definition.perk:getId()
    local effort = SAO.Conditions and SAO.Conditions.readingTime(id) or 1
    local retained = SAO.ProceduralPlanning.studyPurpose(id, perk)
    local purpose, step = SAO.ProceduralPlanning.planStudy(id, person.designation, {
        perk = perk, bookSkill = domain, bookKey = item:getFullType(), bookOwned = true,
        purposeId = retained and retained.id,
        literacy = SAO.History.literacyOf(id), readingTime = effort,
    })
    if not purpose or not step or step.verb ~= "read" then return false end
    person.studySequence = (person.studySequence or 0) + 1
    local workId = "study/" .. tostring(person.studySequence)
    local work = { id = workId, purposeId = purpose.id, fullType = item:getFullType(),
        itemId = tostring(item:getID()), subject = perk, bookSkill = domain, status = "reading",
        pagesBefore = body:getAlreadyReadPages(item:getFullType()),
        totalPages = item:getNumberOfPages(), beganAt = hours() }
    local action = SAOStudyAction:new(body, item)
    action.personId, action.workId, action.purposeId = id, workId, purpose.id
    action.bodyToken = body:getModData().SAOExternalToken
    -- Preserve the native full-book duration and resumed startPage fraction.
    action.maxTime = action.maxTime * math.max(0.25, tonumber(effort) or 1)
    person.studyWork, runtime[id] = work, { action = action }
    if not SAO.Needs.queueVerified(action) then
        close(action, "interrupted", "native-reading-queue-refused")
        return false
    end
    SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId)
    return true
end
function S.snapshot(id)
    local person = rec(id)
    local work = person and person.studyWork
    if not work then return nil end
    local pages = work.pagesAfter or work.pagesBefore
    local active = runtime[id]
    if active and bound(active.action) then
        pages = active.action.character:getAlreadyReadPages(work.fullType)
    elseif work.status == "interrupted" then
        local body = SAO.Body.get(id)
        if live(id, body) then pages = body:getAlreadyReadPages(work.fullType) end
    end
    return { subject = work.subject, status = work.status, reason = work.reason,
        pages = pages, totalPages = work.totalPages, fullType = work.fullType }
end
local function reset()
    runtime = {}
end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(reset) end
return S
