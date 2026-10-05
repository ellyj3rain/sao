-- Native reading over the person's maintained study or leisure purpose.
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
        and SAO.Needs.ownsRecoveryBody(id, body)
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
local function leisureReadable(body, item)
    -- Print media's native perform opens the human player's reader UI. Until
    -- that owner has an off-slot path, it is not an available NPC action.
    return item and instanceof(item, "Literature")
        and not SkillBook[item:getSkillTrained()]
        and item:getNumberOfPages() ~= 0
        and not (item:hasModData() and item:getModData().printMedia)
        and not body:hasTrait(CharacterTrait.ILLITERATE)
end
local function leisureUnread(body, item)
    local title = item:hasModData() and item:getModData().literatureTitle
    return not (title and body:isLiteratureRead(title))
        and (item:getNumberOfPages() < 0
            or body:getAlreadyReadPages(item:getFullType()) < item:getNumberOfPages())
end
-- getCustomPages/seePage lazily allocate on a blank item; the native empty
-- query must precede them. Irregular or oversized text is unavailable rather
-- than silently clipped into a different passage.
local function noteContent(item)
    local ok, content, reason = pcall(function()
        if item:isEmptyPages() then return nil, "note-content-empty" end
        local count = item:getCustomPages():size()
        if count < 1 or count > 32 or count ~= math.floor(count) then return nil, "note-content-outside-bounds" end
        local pages, bytes, meaningful = {}, 0, false
        for index = 1, count do
            local text = item:seePage(index)
            if type(text) ~= "string" then return nil, "note-page-shape-unavailable" end
            bytes = bytes + #text
            if #text > 16384 or bytes > 65536 then return nil, "note-content-outside-bounds" end
            pages[index] = text
            if text:find("%S") then meaningful = true end
        end
        if not meaningful then return nil, "note-content-empty" end
        return { pages = pages, pageCount = count, bytes = bytes,
            source = "native-Literature.customPages", meaning = "unassessed-written-text" }
    end)
    if not ok then return nil, "note-content-unavailable" end
    return content, reason
end
local function sameNoteContent(first, second)
    if type(first) ~= "table" or type(second) ~= "table" or type(first.pages) ~= "table"
        or type(second.pages) ~= "table" or first.pageCount ~= second.pageCount or first.bytes ~= second.bytes
        or #first.pages ~= first.pageCount or #second.pages ~= second.pageCount then return false end
    for index, text in ipairs(first.pages) do if second.pages[index] ~= text then return false end end
    return true
end
local function noteActivity(person, item)
    local prior = person.studyWork
    if prior and prior.contentKind == "written-note" and prior.itemId == tostring(item:getID())
        and prior.fullType == item:getFullType() and prior.status ~= "completed"
        and type(prior.noteActivity) == "string" then return prior.noteActivity end
    return "read existing note text " .. item:getFullType() .. ": exposure " .. tostring((person.studySequence or 0) + 1)
end
local function noteWasExposed(id, item, content)
    for _, row in ipairs(rec(id).noteReadingOutcomes or {}) do
        if row.actorId == id and row.itemId == tostring(item:getID()) and row.itemType == item:getFullType()
            and row.nativeOwner == "SAONoteReadAction/ISBaseTimedAction" and row.status == "completed"
            and row.token == "note:text-exposed" and type(row.atHours) == "number" and row.atHours <= hours()
            and sameNoteContent(row.content, content) then return true end
    end
    return false
end
local function readableAction(action)
    return S.readingEligibility(action.personId, action.character, action.item,
        action.readingKind or "study", true)
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

-- The installed menu excludes UNINTERESTING literature (including ID cards).
-- A negative page count is valid native literature, not evidence of blank text.
-- Ongoing reads use the same material rules, but may reach their final page.
function S.readingEligibility(id, body, item, kind, continuing)
    if kind ~= "study" and kind ~= "leisure" then return false, "unknown-reading-purpose" end
    if not live(id, body) then return false, "reading-body-unavailable" end
    if not item or not instanceof(item, "Literature") then return false, "not-literature" end
    if not held(body, item) then return false, "reading-item-not-held" end
    if item:hasTag(ItemTag.UNINTERESTING) then return false, "uninteresting-literature" end
    if SAO.History.literacyOf(id) == "none" then return false, "reading-not-understood" end
    local writable = item:canBeWrite()
    local content, contentWhy
    if writable then
        if kind ~= "leisure" then return false, "note-is-not-a-skill-manual" end
        content, contentWhy = noteContent(item)
        if not content then return false, contentWhy end
    end
    local meaningful = writable and not (item:hasModData() and item:getModData().printMedia)
            and not body:hasTrait(CharacterTrait.ILLITERATE)
        or not writable and kind == "leisure" and leisureReadable(body, item)
        or kind == "study" and readable(body, item)
    if not meaningful then return false, "unsupported-reading-material" end
    if continuing then
        local active = runtime[id]
        if not active or active.action.character ~= body or active.action.item ~= item
            or active.action.readingKind ~= kind or not bound(active.action) then
            return false, "reading-attempt-not-owned"
        end
        local work = rec(id).studyWork
        if writable ~= (work.contentKind == "written-note")
            or writable and not sameNoteContent(active.action.noteContent, content) then
            return false, "reading-content-changed"
        end
        return true
    end
    if not (writable or kind == "leisure" and leisureUnread(body, item)
        or kind == "study" and eligible(body, item)) then return false, "reading-already-finished" end
    if writable and noteWasExposed(id, item, content) then return false, "note-text-already-exposed" end
    if kind == "leisure" and SAO.ProceduralPlanning and SAO.ProceduralPlanning.leisureChoice then
        if writable then return SAO.ProceduralPlanning.leisureChoice(id, "read written notes", tostring(item:getID()), noteActivity(rec(id), item)) end
        return SAO.ProceduralPlanning.leisureChoice(id, "read " .. item:getFullType(), tostring(item:getID()))
    end
    return true
end
function S.outcome(id,sequence)
    local person=rec(id)
    for _,row in ipairs(person and person.studyOutcomes or {}) do
        if row.actorId==id and row.sequence==sequence then
            local copy={} for key,value in pairs(row) do copy[key]=value end return copy
        end
    end
end
function S.noteOutcome(id, sequence)
    local person = rec(id)
    for _, row in ipairs(person and person.noteReadingOutcomes or {}) do
        if row.actorId == id and row.sequence == sequence then
            local copy = {}
            for key, value in pairs(row) do if key ~= "content" then copy[key] = value end end
            copy.content = { pages = {}, pageCount = row.content.pageCount, bytes = row.content.bytes,
                source = row.content.source, meaning = row.content.meaning }
            for index, text in ipairs(row.content.pages) do copy.content.pages[index] = text end
            return copy
        end
    end
end
function S.noteWork(id)
    local active, person = runtime[id], rec(id)
    local work = person and person.studyWork
    if not active or not work or work.contentKind ~= "written-note" or not bound(active.action)
        or not readableAction(active.action) then return nil end
    return { actorId = id, workId = work.id, sequence = work.sequence, purposeId = work.purposeId,
        itemId = work.itemId, itemType = work.fullType, activityKey = work.noteActivity,
        contentBinding = work.id, contentPages = work.contentPages, contentBytes = work.contentBytes,
        bodyGenerationKnown = work.bodyGenerationKnown, bodyToken = work.bodyToken,
        beganAt = work.beganAt, status = "prepared" }
end
local function close(action, status, reason)
    local person = rec(action.personId)
    local work = person and person.studyWork
    if not work or work.id ~= action.workId or work.status ~= "reading" then return false end
    local valid = bound(action)
    local note = work.contentKind == "written-note"
    local pages = not note and (valid and action.character:getAlreadyReadPages(work.fullType) or work.pagesBefore) or nil
    work.pagesAfter, work.endedAt = pages, hours()
    if status == "completed" and (not valid or not action.nativeCompleted
        or (work.progress or 0) <= 0 or work.phase ~= "executing"
        or not note and work.totalPages > 0 and (pages <= work.pagesBefore or pages < work.totalPages)) then
        status, reason = "interrupted", "native-reading-not-proven"
    end
    work.status, work.phase, work.reason = status, status, reason
    runtime[action.personId] = nil
    if status == "completed" then
        if note then
            work.exposureCompleted = true
            local outcome = { actorId = action.personId, sequence = work.sequence, workId = work.id,
                purposeId = work.purposeId, status = "completed", nativeOwner = "SAONoteReadAction/ISBaseTimedAction",
                token = "note:text-exposed", itemId = work.itemId, itemType = work.fullType,
                content = action.noteContent, contentBinding = work.id,
                bodyGenerationKnown = work.bodyGenerationKnown, bodyToken = work.bodyToken,
                beganAt = work.beganAt, startedAt = work.startedAt, endedAt = work.endedAt, atHours = work.endedAt,
                meaning = "completed-text-exposure; comprehension-unassessed" }
            person.noteReadingOutcomes = person.noteReadingOutcomes or {}
            person.noteReadingOutcomes[#person.noteReadingOutcomes + 1] = outcome
            if #person.noteReadingOutcomes > 16 then table.remove(person.noteReadingOutcomes, 1) end
        end
        if work.kind=="study" then
            local outcome={actorId=action.personId,sequence=work.sequence,workId=work.id,
                status="completed",nativeOwner="ISReadABook.complete",token="reading:progressed",
                itemId=tonumber(work.itemId),itemType=work.fullType,bookSkill=work.bookSkill,
                pagesBefore=work.pagesBefore,pagesAfter=pages,totalPages=work.totalPages,
                beganAt=work.beganAt,atHours=work.endedAt}
            person.studyOutcomes=person.studyOutcomes or {}
            person.studyOutcomes[#person.studyOutcomes+1]=outcome
            if #person.studyOutcomes>32 then table.remove(person.studyOutcomes,1) end
            if SAO.Cognition and SAO.Cognition.studyOutcome then SAO.Cognition.studyOutcome(action.personId,outcome) end
        end
        if note then return SAO.ProceduralPlanning.consumeNoteOutcome(action.personId, work.sequence) end
        return SAO.ProceduralPlanning.recordResult(action.personId, work.purposeId, {
            owner = "SAONeeds", token = work.kind == "leisure" and "leisure:performed"
                or "reading:progressed", status = "completed",
            correlationId = work.id, atHours = work.endedAt,
        })
    end
    SAO.ProceduralPlanning.releaseStudy(action.personId, work.purposeId, work.id)
    SAO.ProceduralPlanning.interrupt(action.personId, work.purposeId, reason, work.endedAt)
    return true
end

SAOStudyAction = ISReadABook:derive("SAOStudyAction")
function SAOStudyAction:isValid()
    return bound(self) and readableAction(self)
        and ISReadABook.isValid(self)
end
function SAOStudyAction:start()
    if not self:isValid() then self:forceStop(); return end
    ISReadABook.start(self)
    self.nativeStarted = true
end
function SAOStudyAction:update()
    if not self:isValid() then self:forceStop(); return end
    if not self.nativeStarted or not self.character:isReading() then return end
    ISReadABook.update(self)
    local work = rec(self.personId).studyWork
    local progress = self:getJobDelta()
    -- Queue admission and setting Read are preparation. Advancing the exact
    -- native action (and pages, for paged books) is observed execution.
    if progress > (self.startPage or 0) / math.max(1, work.totalPages)
        and (work.totalPages < 0
            or self.character:getAlreadyReadPages(work.fullType) > work.pagesBefore) then
        work.phase, work.progress = "executing", progress
        work.lastProgressAt = hours()
    end
end
function SAOStudyAction:complete()
    -- Native completion owns pages and the XP multiplier. The receipt only
    -- observes that result, and neither changes a skill nor completes practice.
    if not bound(self) or not readableAction(self) or not self.nativeStarted
        or (rec(self.personId).studyWork.progress or 0) <= 0
        or not self.action or self:getJobDelta() < 1 then
        close(self, "interrupted", "study-owner-or-book-changed")
        return false
    end
    local result = ISReadABook.complete(self)
    self.nativeCompleted = result == true
    if result == true then close(self, "completed") end
    return result
end
function SAOStudyAction:stop()
    local person = rec(self.personId)
    local ownsQueue = person and person.studyWork and person.studyWork.id == self.workId
        and ISTimedActionQueue.hasAction(self) == true
    close(self, "interrupted", "native-reading-stopped")
    if ownsQueue and live(self.personId, self.character)
        and self.bodyToken == self.character:getModData().SAOExternalToken then ISReadABook.stop(self) end
end
function SAOStudyAction:forceCancel()
    close(self, "interrupted", "native-reading-cancelled")
end
function SAOStudyAction:perform()
    if self.nativePerformed then return end
    if not ISTimedActionQueue.hasAction(self) then return end
    local person = rec(self.personId)
    local work = person and person.studyWork
    if not work or work.id ~= self.workId or not live(self.personId, self.character)
        or self.bodyToken ~= self.character:getModData().SAOExternalToken then return end
    self.nativePerformed = true
    -- Native perform also records a title as read. It cannot be allowed to
    -- bypass the progress/ownership checks on complete, including late calls.
    if self.nativeStarted and (work.progress or 0) > 0 and held(self.character, self.item)
        and self.action and self:getJobDelta() >= 1
        and (work.status == "reading" or self.nativeCompleted and work.status == "completed") then
        ISReadABook.perform(self)
    else
        self.character:setReading(false)
        ISBaseTimedAction.perform(self)
    end
end

-- ISWriteSomething is a player UI session. The off-slot note owner instead
-- uses the native timed action and Read presentation over exact existing text.
-- It never invokes book page-counter, ReadLiterature or recipe completion.
SAONoteReadAction = ISBaseTimedAction:derive("SAONoteReadAction")
function SAONoteReadAction:isBook(item) return ISReadABook.isBook(self, item) end
function SAONoteReadAction:isValid()
    if not bound(self) or not readableAction(self) or self.character:tooDarkToRead() then return false end
    local vehicle = self.character:getVehicle()
    return not vehicle or not vehicle:isDriver(self.character)
        or not vehicle:isEngineRunning() or vehicle:getSpeed2D() == 0
end
function SAONoteReadAction:start()
    if not self:isValid() then self:forceStop(); return end
    -- No startPage and no printMedia: native start supplies Read presentation,
    -- the held item and opening sound, without the player note UI.
    ISReadABook.start(self)
    self.nativeStarted = true
    rec(self.personId).studyWork.startedAt = hours()
end
function SAONoteReadAction:update()
    if not self:isValid() then self:forceStop(); return end
    if not self.nativeStarted or not self.character:isReading() then return end
    local progress = self:getJobDelta()
    self.item:setJobDelta(progress)
    if progress > 0 then
        local work = rec(self.personId).studyWork
        work.phase, work.progress, work.lastProgressAt = "executing", progress, hours()
    end
end
function SAONoteReadAction:complete()
    local active = runtime[self.personId]
    if not self:isValid() or not self.nativeStarted or not active or active.notePerformed ~= self
        or not self.action or self:getJobDelta() < 1
        or (rec(self.personId).studyWork.progress or 0) <= 0 then
        close(self, "interrupted", "note-owner-content-or-progress-unproven")
        return false
    end
    self.nativeCompleted = true
    return close(self, "completed")
end
local function endNotePresentation(action)
    action.character:setReading(false)
    if held(action.character, action.item) then action.item:setJobDelta(0) end
    action.character:playSound(action:isBook(action.item) and "CloseBook" or "CloseMagazine")
end
function SAONoteReadAction:stop()
    local person, active = rec(self.personId), runtime[self.personId]
    local owned = person and person.studyWork and person.studyWork.id == self.workId
        and person.studyWork.status == "reading" and active and active.action == self
        and ISTimedActionQueue.hasAction(self) == true
    close(self, "interrupted", "native-note-reading-stopped")
    if owned and live(self.personId, self.character)
        and self.bodyToken == self.character:getModData().SAOExternalToken then
        endNotePresentation(self)
        ISBaseTimedAction.stop(self)
    end
end
function SAONoteReadAction:forceCancel() close(self, "interrupted", "native-note-reading-cancelled") end
function SAONoteReadAction:perform()
    if self.nativePerformed or ISTimedActionQueue.hasAction(self) ~= true then return end
    local person = rec(self.personId)
    local work = person and person.studyWork
    if not work or work.id ~= self.workId or not live(self.personId, self.character)
        or self.bodyToken ~= self.character:getModData().SAOExternalToken then return end
    local active = runtime[self.personId]
    if work.status ~= "reading" or not active or active.action ~= self then return end
    self.nativePerformed = true
    -- Installed IsoGameCharacter calls perform, then complete. Preserve this
    -- exact owned terminal observation across the queue's onCompleted handoff.
    if active and self:isValid() and self.nativeStarted and self.character:isReading()
        and self.action and self:getJobDelta() >= 1 and (work.progress or 0) > 0 then
        active.notePerformed = self
    else
        close(self, "interrupted", "native-note-completion-unproven")
    end
    endNotePresentation(self)
    ISBaseTimedAction.perform(self)
end
function SAONoteReadAction:new(character, item, pageCount)
    local o = ISBaseTimedAction.new(self, character)
    o.item, o.playerNum = item, character:getPlayerNum()
    -- Installed reading duration inputs, without getDuration's write to the
    -- item's fullType-based already-read counter. These scale time, not skill.
    local minutes = getSandboxOptions():getOptionByName("MinutesPerPage"):getValue() or 2
    if minutes < 0 then minutes = 2 end
    local duration = pageCount * minutes * getGameTime():getMinutesPerDay() * 2
    if item:hasTag(ItemTag.FAST_READ) then duration = 50 end
    if character:hasTrait(CharacterTrait.FAST_READER) then duration = duration * 0.7 end
    if character:hasTrait(CharacterTrait.SLOW_READER) then duration = duration * 1.3 end
    local eye = character:getWornItems():getItem(ItemBodyLocation.EYES)
    if eye and eye:getType() == "Glasses_Reading" then duration = duration * 0.9 end
    if character:isSitting() then duration = duration * 0.9 end
    o.maxTime = character:isTimedActionInstant() and 1 or math.max(duration, 1)
    o.ignoreHandsWounds, o.caloriesModifier, o.forceProgressBar = true, 0.5, true
    return o
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
        local data = body:getModData()
        local deathCleanup = person.dead and SAO.Body.active[id] == body and SAO.Body.get(id) == body
            and SAO.Body.foreign[id] == nil and person.bodyOwner == nil
            and not person.zaoTransferPending and not person.crossedTransferPending
            and data.SAOPersonId == id and data.SAOExternalOwner == nil and data.ZAOOwned ~= true
            and data.SAOExternalToken == person.bodyOwnerToken
        if queued(active.action) and (live(id, body) or deathCleanup)
            and active.action.bodyToken == data.SAOExternalToken then
            if work.contentKind == "written-note" then endNotePresentation(active.action) end
            ISTimedActionQueue.clear(body)
        end
    else
        if work.contentKind ~= "written-note" and live(id, body) then work.pagesAfter = body:getAlreadyReadPages(work.fullType) end
        work.status, work.phase, work.reason, work.endedAt = "interrupted", "interrupted", "study-runtime-unavailable", hours()
        SAO.ProceduralPlanning.releaseStudy(id, work.purposeId, work.id)
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
        if S.readingEligibility(id, body, item, "study")
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
function S.offerLeisure(id, body)
    if not live(id, body) or SAO.History.literacyOf(id) == "none" then return nil end
    local best, person = nil, rec(id)
    local items = SAOJavaBridge:privateCarriedItems(body)
    for i = 0, math.min(items:size(), 128) - 1 do
        local item = items:get(i)
        if S.readingEligibility(id, body, item, "leisure")
            and (not best or item:getFullType() == person.reading
                and best:getFullType() ~= person.reading
                or item:getFullType() == best:getFullType()
                    and tostring(item:getID()) < tostring(best:getID())) then best = item end
    end
    return best
end
local function begin(id, body, item, kind)
    local leisure = kind == "leisure"
    if not SAO.ProceduralPlanning or not S.readingEligibility(id, body, item, kind)
        or body:tooDarkToRead() or not SAO.Needs.workAvailable(body) then return false end
    if S.active(id, body) then
        return runtime[id].action.item == item and runtime[id].action.readingKind == kind
    end
    local person = rec(id)
    local content = item:canBeWrite() and noteContent(item) or nil
    if item:canBeWrite() and not content then return false end
    local domain, definition = item:getSkillTrained(), SkillBook[item:getSkillTrained()]
    local perk = definition and definition.perk:getId()
    local effort = SAO.Conditions and SAO.Conditions.readingTime(id) or 1
    local activityKey = content and noteActivity(person, item)
    local activity = content and "read written notes" or "read " .. item:getFullType()
    local purpose, step
    if leisure then
        purpose, step = SAO.ProceduralPlanning.planLeisure(id, {
            activity = activity, activityKey = activityKey, affordance = item:getFullType(),
            nativeVerb = content and "read-written-note",
            itemKey = tostring(item:getID()),
            locationKey = "reading-place:" .. math.floor(body:getX()) .. ":"
                .. math.floor(body:getY()) .. ":" .. math.floor(body:getZ()),
            atLocation = true, owner = "SAONeeds", spontaneous = true,
        })
    else
        local retained = SAO.ProceduralPlanning.studyPurpose(id, perk)
        purpose, step = SAO.ProceduralPlanning.planStudy(id, person.designation, {
            perk = perk, bookSkill = domain, bookKey = item:getFullType(), bookOwned = true,
            purposeId = retained and retained.id,
            literacy = SAO.History.literacyOf(id), readingTime = effort,
        })
    end
    if not purpose or not step or step.verb ~= (leisure and "recreate" or "read") then return false end
    person.studySequence = (person.studySequence or 0) + 1
    local workId = "study/" .. tostring(person.studySequence)
    local work = { id = workId, sequence=person.studySequence, purposeId = purpose.id, fullType = item:getFullType(),
        itemId = tostring(item:getID()), subject = perk, bookSkill = domain, status = "reading",
        kind = leisure and "leisure" or "study", phase = "preparing", progress = 0,
        pagesBefore = not content and body:getAlreadyReadPages(item:getFullType()) or nil,
        totalPages = not content and item:getNumberOfPages() or nil, beganAt = hours(),
        contentKind = content and "written-note" or "native-book",
        noteActivity = activityKey,
        contentPages = content and content.pageCount, contentBytes = content and content.bytes,
        contentSource = content and content.source }
    local action = content and SAONoteReadAction:new(body, item, content.pageCount) or SAOStudyAction:new(body, item)
    action.noteContent = content
    action.personId, action.workId, action.purposeId = id, workId, purpose.id
    action.readingKind = work.kind
    action.bodyToken = body:getModData().SAOExternalToken
    if content then
        work.bodyToken = action.bodyToken
        work.bodyGenerationKnown = type(action.bodyToken) == "string" and action.bodyToken ~= ""
    end
    -- Preserve the native full-book duration and resumed startPage fraction.
    action.maxTime = action.maxTime * math.max(0.25, tonumber(effort) or 1)
    person.studyWork, runtime[id] = work, { action = action }
    if content and not SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId) then
        close(action, "interrupted", "note-purpose-binding-refused")
        return false
    end
    if not SAO.Needs.queueVerified(action) then
        if content and work.status == "completed" and work.exposureCompleted == true then return true end
        close(action, "interrupted", "native-reading-queue-refused")
        if leisure then SAO.ProceduralPlanning.leisureRefusal(id, purpose.id, workId) end
        return false
    end
    if content then return work.status == "reading" or work.status == "completed" end
    SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId)
    return true
end
function S.begin(id, body, item) return begin(id, body, item, "study") end
function S.beginLeisure(id, body, item) return begin(id, body, item, "leisure") end
function S.describe(id)
    local work = S.snapshot(id)
    if not work then return "wants to read; no native reading admitted" end
    if work.phase == "executing" then
        if work.contentKind == "written-note" then return "reads the existing text of a carried note" end
        return work.kind == "leisure" and "reads carried literature; native reading is progressing"
            or "studies a carried manual; native pages are progressing"
    end
    if work.phase == "preparing" then return "prepares to read carried literature" end
    return "reading " .. tostring(work.phase) .. (work.reason and ": " .. work.reason or "")
end
function S.snapshot(id)
    local person = rec(id)
    local work = person and person.studyWork
    if not work then return nil end
    local pages = work.pagesAfter or work.pagesBefore
    local active = runtime[id]
    if work.contentKind ~= "written-note" and active and bound(active.action) then
        pages = active.action.character:getAlreadyReadPages(work.fullType)
    elseif work.contentKind ~= "written-note" and work.status == "interrupted" then
        local body = SAO.Body.get(id)
        if live(id, body) then pages = body:getAlreadyReadPages(work.fullType) end
    end
    local phase = work.phase or "preparing"
    if work.status == "reading" and phase == "executing"
        and not (active and bound(active.action) and queued(active.action)
            and active.action.character:isReading()) then phase = "preparing" end
    return { subject = work.subject, status = work.status, reason = work.reason,
        kind = work.kind or "study", phase = phase, progress = work.progress or 0,
        pages = pages, totalPages = work.totalPages, fullType = work.fullType,
        contentKind = work.contentKind, contentPages = work.contentPages,
        exposureCompleted = work.exposureCompleted == true }
end
local function reset()
    runtime = {}
end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(reset) end
return S
