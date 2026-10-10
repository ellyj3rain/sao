-- Native reading over the person's maintained study or leisure purpose.
require "TimedActions/ISReadABook"

SAO = SAO or {}
SAO.Study = SAO.Study or {}
local S = SAO.Study
local runtime = {}
local generatorReading

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
    local generator=kind=="generator-reading"
    if kind ~= "study" and kind ~= "leisure" and not generator then return false, "unknown-reading-purpose" end
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
        or not writable and (kind == "leisure" or generator) and leisureReadable(body, item)
        or kind == "study" and readable(body, item)
    if not meaningful then return false, "unsupported-reading-material" end
    if generator and (item:getIsCraftingConsumed() or not item:getLearnedRecipes()
        or not item:getLearnedRecipes():contains("Generator")) then return false,"not-generator-literature" end
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
    if not (writable or (kind == "leisure" or generator) and leisureUnread(body, item)
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
-- Terminal reading facts belong to the persistent person; native objects stay
-- transient. A detached query cannot alter the canonical measured occurrence.
function S.leisureOutcome(id, sequence)
    local person = rec(id)
    for _, row in ipairs(person and person.leisureReadingOutcomes or {}) do
        if row.actorId == id and row.sequence == sequence then
            local out = {}
            for key, value in pairs(row) do if key ~= "mood" then out[key] = value end end
            if row.mood then
                out.mood = {}
                for name, values in pairs(row.mood) do
                    out.mood[name] = { before = values.before, after = values.after }
                end
            end
            return out
        end
    end
end
local function readingMood(action)
    local ok, values = pcall(function()
        local stats, out = action.character:getStats(), {}
        for _, name in ipairs({ "BOREDOM", "UNHAPPINESS", "STRESS" }) do
            local value = stats:get(CharacterStat[name])
            if type(value) ~= "number" or value ~= value or value < 0 or value > 1000000 then return nil end
            out[name] = value
        end
        return out
    end)
    return ok and values or nil
end
local function recordLeisureOutcome(person, work, action, custody)
    if work.kind ~= "leisure" then return end
    local note = work.contentKind == "written-note"
    local outcome = { actorId = person.id, sequence = work.sequence, workId = work.id,
        purposeId = work.purposeId, status = work.status,
        nativeOwner = note and "SAONoteReadAction/ISBaseTimedAction" or "ISReadABook.complete",
        token = note and "note:text-exposed" or "leisure:performed",
        sourceId = note and "native:literature:customPages" or "native:literature:ISReadABook",
        actionKind = note and "read-note" or "read-book", itemId = work.itemId, itemType = work.fullType,
        bodyGenerationKnown = work.bodyGenerationKnown, bodyToken = work.bodyToken,
        beganAt = work.beganAt, startedAt = work.startedAt, atHours = work.endedAt,
        progress = work.progress, custodyVerified = custody == true,
        nativeStarted = work.startedAt ~= nil, nativeCompleted = action and action.nativeCompleted == true or false,
        pagesBefore = work.pagesBefore, pagesAfter = work.pagesAfter, totalPages = work.totalPages,
        contentPages = work.contentPages, contentBytes = work.contentBytes,
        contentBinding = note and work.id or nil,
        meaning = note and "text-exposure; comprehension-unassessed" or "native-reading; comprehension-unassessed",
        reason = work.reason }
    if outcome.status == "completed" and not note and action and action.readingMood then
        outcome.mood = action.readingMood
        outcome.moodMeasurement = "immediate-native-completion"
    end
    person.leisureReadingOutcomes = person.leisureReadingOutcomes or {}
    person.leisureReadingOutcomes[#person.leisureReadingOutcomes + 1] = outcome
    if #person.leisureReadingOutcomes > 32 then table.remove(person.leisureReadingOutcomes, 1) end
    if SAO.Cognition and SAO.Cognition.leisureReadingOutcome then
        SAO.Cognition.leisureReadingOutcome(person.id, work.sequence)
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
    if work.kind=="generator-reading" then return generatorReading.finish(action.personId,status,reason) end
    local valid = bound(action)
    local note = work.contentKind == "written-note"
    local pages = not note and (valid and action.character:getAlreadyReadPages(work.fullType)
        or work.pagesAfter or work.pagesBefore) or nil
    work.pagesAfter, work.endedAt = pages, hours()
    if status == "completed" and (not valid or not action.nativeCompleted
        or (work.progress or 0) <= 0 or work.phase ~= "executing"
        or not note and work.totalPages > 0 and (pages <= work.pagesBefore or pages < work.totalPages)) then
        status, reason = "interrupted", "native-reading-not-proven"
    end
    work.status, work.phase, work.reason = status, status, reason
    runtime[action.personId] = nil
    recordLeisureOutcome(person, work, action, valid)
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
    rec(self.personId).studyWork.startedAt = hours()
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
        work.pagesAfter = self.character:getAlreadyReadPages(work.fullType)
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
    -- Sample immediately around the installed completion's ReadLiterature
    -- effect. Elapsed boredom drift and note exposure are not attributed here.
    local leisure = self.readingKind == "leisure"
    local before = leisure and readingMood(self)
    local result = ISReadABook.complete(self)
    local after = leisure and bound(self) and readableAction(self) and readingMood(self)
    if result == true and before and after then
        self.readingMood = {}
        for name, value in pairs(before) do self.readingMood[name] = { before = value, after = after[name] } end
    end
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
    if work.kind=="generator-reading" then return generatorReading.interrupt(id,body,reason) end
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
        if work.contentKind ~= "written-note" and work.pagesAfter == nil then work.pagesAfter = work.pagesBefore end
        work.status, work.phase, work.reason, work.endedAt = "interrupted", "interrupted", "study-runtime-unavailable", hours()
        recordLeisureOutcome(person, work, nil, false)
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
    if work.kind=="generator-reading" then
        if active and active.generator and not active.closed then
            if not bound(active.action) or active.cancelling or not generatorReading.ownsQueue(active) then
                generatorReading.interrupt(id,body,"generator-reading-owner-changed")
            end
            return rec(id).studyWork.status=="reading"
        end
        return not generatorReading.interrupt(id,body,"generator-reading-runtime-unavailable")
    end
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
local function begin(id, body, item, kind, context)
    local leisure = kind == "leisure"
    local generator=kind=="generator-reading"
    if not SAO.ProceduralPlanning or not S.readingEligibility(id, body, item, kind)
        or body:tooDarkToRead() or not SAO.Needs.workAvailable(body) then return false end
    if S.active(id, body) then
        return runtime[id].action.item == item and runtime[id].action.readingKind == kind
    end
    local person = rec(id)
    if generator and (person.resourceProductionWork or person.worldSourceReservation or person.cookingWork
        or SAOJavaBridge:hasPendingActions(body)) then return false end
    local content = item:canBeWrite() and noteContent(item) or nil
    if item:canBeWrite() and not content then return false end
    local domain, definition = item:getSkillTrained(), SkillBook[item:getSkillTrained()]
    local perk = definition and definition.perk:getId()
    local effort = SAO.Conditions and SAO.Conditions.readingTime(id) or 1
    local activityKey = content and noteActivity(person, item)
    local activity = content and "read written notes" or "read " .. item:getFullType()
    local purpose, step
    if generator then
        local state=person.proceduralPlanning
        purpose=state and state.purposes[context.purposeId]
        step=purpose and purpose.steps[purpose.cursor]
        if not purpose or not purpose.generatorPower or purpose.admission or not step or step.owner~="SAO.Study"
            or step.id~=context.purposeStepId or step.operation~="learn-generator"
            or tostring(step.inputItemId)~=tostring(item:getID()) or step.inputItemType~=item:getFullType() then return false end
    elseif leisure then
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
    if not purpose or not step or not generator and step.verb ~= (leisure and "recreate" or "read") then return false end
    person.studySequence = (person.studySequence or 0) + 1
    local workId = generator and "generator-reading/"..id.."/"..person.studySequence or "study/" .. tostring(person.studySequence)
    local work = { id = workId, sequence=person.studySequence, purposeId = purpose.id, fullType = item:getFullType(),
        itemId = tostring(item:getID()), subject = perk, bookSkill = domain, status = "reading",
        kind = generator and "generator-reading" or leisure and "leisure" or "study", phase = "preparing", progress = 0,
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
    work.bodyToken = action.bodyToken
    work.bodyGenerationKnown = type(action.bodyToken) == "string" and action.bodyToken ~= ""
    -- Preserve the native full-book duration and resumed startPage fraction.
    action.maxTime = action.maxTime * math.max(0.25, tonumber(effort) or 1)
    person.studyWork, runtime[id] = work, { action = action }
    if generator then
        work.owner,work.operation,work.token="SAO.Study","learn-generator","utility:generator-known"
        work.actorId,work.itemType,work.purposeStepId=id,item:getFullType(),step.id
        work.requestedPurposeId,work.requestedPurposeStepId=purpose.id,step.id
        work.world=getWorld():getWorld()
        if SAO.ProceduralPlanning.admitGeneratorReading(id,work)~=true then person.studyWork=nil;runtime[id]=nil;return false end
        generatorReading.guard(id,body,item,work,action)
    end
    if content and not SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId) then
        close(action, "interrupted", "note-purpose-binding-refused")
        return false
    end
    if not SAO.Needs.queueVerified(action) then
        if generator then
            if work.status=="completed" then return true end
            generatorReading.interrupt(id,body,"native-reading-queue-refused")
            return false
        end
        if content and work.status == "completed" and work.exposureCompleted == true then return true end
        close(action, "interrupted", "native-reading-queue-refused")
        if leisure then SAO.ProceduralPlanning.leisureRefusal(id, purpose.id, workId) end
        return false
    end
    if content then return work.status == "reading" or work.status == "completed" end
    if not generator then SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId) end
    return true
end
function S.begin(id, body, item) return begin(id, body, item, "study") end
function S.beginLeisure(id, body, item) return begin(id, body, item, "leisure") end
function S.beginGenerator(id,body,item,purposeId,stepId)
    return begin(id,body,item,"generator-reading",{purposeId=purposeId,purposeStepId=stepId})
end
generatorReading={}
function generatorReading.finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
function generatorReading.ownsQueue(rt)
    return rt.queue==ISTimedActionQueue.queues[rt.body] and rt.queue.current==rt.action
        and rt.queue.queue[1]==rt.action and rt.queue:indexOf(rt.action)==1 and queued(rt.action)
end
function generatorReading.identity(id,w)
    return type(w)=="table" and not getmetatable(w) and w.kind=="generator-reading" and w.actorId==id and generatorReading.finite(w.sequence)
        and w.sequence>0 and w.sequence%1==0 and w.id=="generator-reading/"..id.."/"..w.sequence
        and type(w.itemId)=="string" and w.itemType==w.fullType and type(w.itemType)=="string"
        and type(w.purposeId)=="string" and type(w.purposeStepId)=="string" and generatorReading.finite(w.beganAt)
        and w.beganAt>=0 and w.token=="utility:generator-known" and w.owner=="SAO.Study" and w.operation=="learn-generator"
        and type(w.world)=="string" and (w.bodyToken==nil or type(w.bodyToken)=="string" and #w.bodyToken>0)
end
function generatorReading.purpose(person,w)
    local state=person and person.proceduralPlanning;local p=state and state.purposes[w.purposeId]
    local s=p and p.steps[p.cursor];local a=p and p.admission
    return p and p.generatorPower and s and a and s.owner=="SAO.Study" and s.operation=="learn-generator"
        and s.id==w.purposeStepId and s.token==w.token and s.inputItemId==w.itemId and s.inputItemType==w.itemType
        and a.owner==s.owner and a.stepId==s.id and a.correlationId==w.id and a.target==s.target
end
function S.generatorOutcome(id,outcomeId)
    local person=rec(id)
    local rows=person and person.generatorReadingOutcomes or {}
    if type(rows)~="table" or getmetatable(rows) or #rows>32 then return nil end
    for _,row in ipairs(rows) do if type(row)=="table" and row.id==outcomeId then
        if not generatorReading.identity(id,row) or row.workId~=row.id or row.outcomeId~=row.id
            or row.sequence>(person.studySequence or 0) or row.nativeOwner~="ISReadABook.complete" or not generatorReading.finite(row.atHours) or row.atHours>hours()
            or not generatorReading.finite(row.startedAt) or row.startedAt<row.beganAt or row.atHours<row.startedAt or row.endedAt~=row.atHours or not generatorReading.finite(row.progress)
            or row.progress<0 or row.progress>1 or type(row.recipeKnown)~="boolean"
            or type(row.nativeStarted)~="boolean" or type(row.nativeCompleted)~="boolean"
            or row.status~="completed" and row.status~="interrupted" then return nil end
        if row.status=="completed" and (not row.nativeStarted or not row.nativeCompleted or row.progress<=0 or not row.recipeKnown) then return nil end
        local out={};for k,v in pairs(row) do if type(v)~="string" and type(v)~="number" and type(v)~="boolean" then return nil end;out[k]=v end
        return out
    end end
end
function generatorReading.finish(id,status,reason)
    local person,rt=rec(id),runtime[id]
    local w=person and person.studyWork
    if not rt or not rt.generator or not w or not generatorReading.identity(id,w) or rt.work~=w
        or rt.record~=person or not generatorReading.purpose(person,w) or not rt.ack or queued(rt.action)
        or rt.queue.current==rt.action or hours()<w.beganAt then return false end
    if status=="completed" and (not rt.action.nativeCompleted or not bound(rt.action) or not readableAction(rt.action)
        or (w.progress or 0)<=0 or not rt.body:isRecipeActuallyKnown("Generator")) then status="interrupted" end
    local row={id=w.id,workId=w.id,outcomeId=w.id,sequence=w.sequence,actorId=id,kind=w.kind,token=w.token,
        owner=w.owner,operation=w.operation,itemId=w.itemId,itemType=w.itemType,fullType=w.fullType,
        purposeId=w.purposeId,purposeStepId=w.purposeStepId,status=status,reason=reason,beganAt=w.beganAt,
        world=w.world,bodyToken=w.bodyToken,
        startedAt=w.startedAt or w.beganAt,endedAt=hours(),atHours=hours(),nativeOwner="ISReadABook.complete",
        nativeStarted=rt.action.nativeStarted==true,nativeCompleted=rt.action.nativeCompleted==true,
        progress=w.progress or 0,recipeKnown=status=="completed" and rt.body:isRecipeActuallyKnown("Generator") or false}
    person.generatorReadingOutcomes=person.generatorReadingOutcomes or {}
    local rows=person.generatorReadingOutcomes
    if #rows>=32 and not rows[1].delivered then return false end
    rows[#rows+1]=row;if #rows>32 then table.remove(rows,1) end
    if not S.generatorOutcome(id,row.id) then table.remove(rows);return false end
    w.status,w.phase,w.reason,w.endedAt=status,status,reason,row.endedAt
    runtime[id]=nil;rt.closed=true
    rt.action._SAOGeneratorReadingRetireSaved=nil
    if SAO.ProceduralPlanning.consumeGeneratorReading(id,row.id) then row.delivered=true end
    return true
end
function generatorReading.guard(id,body,item,w,a)
    local rt={generator=true,action=a,body=body,item=item,work=w,record=rec(id),queue=ISTimedActionQueue.getTimedActionQueue(body)}
    runtime[id]=rt
    local function current()
        return not rt.closed and rt.queue==ISTimedActionQueue.queues[body] and rt.queue.current==a
            and rt.queue.queue[1]==a and rt.queue:indexOf(a)==1
            and body:getModData().SAOExternalToken==w.bodyToken and a.character==body
    end
    local function exact()
        return bound(a) and readableAction(a) and rec(id)==rt.record and rec(id).studyWork==w
            and generatorReading.purpose(rt.record,w) and a.item==item and item:getFullType()==w.itemType
            and rt.work.id==w.id and a.bodyToken==w.bodyToken and w.world==getWorld():getWorld() and hours()>=w.beganAt
    end
    function a:complete()
        if rt.closed or rt.cancelling or self.nativeCompleted or not exact() or not self.nativeStarted
            or (w.progress or 0)<=0 or not self.action or self:getJobDelta()<1
            or not current() and not (rt.ack and not rt.queue.current and #rt.queue.queue==0) then return false end
        local result=ISReadABook.complete(self)
        self.nativeCompleted=result==true
        if rt.ack then generatorReading.finish(id,"completed") end
        return result
    end
    function a:perform()
        if rt.closed or rt.performed or rt.cancelling or not current() or not exact()
            or not self.action or not self.action:isStarted() or not (self.action:finished() or self.action:isForceComplete()) then return false end
        rt.performed=true
        ISReadABook.perform(self)
        if rt.queue:indexOf(self)==-1 and rt.queue.current~=self then rt.ack=true end
        if self.nativeCompleted then return generatorReading.finish(id,"completed") end
        return true
    end
    function a:stop()
        if rt.closed or rt.ack then return false end
        rt.cancelling=true
        if current() then
            if item:getNumberOfPages()>0 and item:getAlreadyReadPages()>=item:getNumberOfPages() then item:setAlreadyReadPages(item:getNumberOfPages()) end
            body:setReading(false);item:setJobDelta(0)
            body:playSound(self:isBook(item) and "CloseBook" or "CloseMagazine")
            body:setIsFarming(false);rt.ack=true;rt.queue:onCompleted(self)
        else
            rt.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end
        end
        return generatorReading.finish(id,"interrupted",rt.reason or "native-generator-reading-stopped")
    end
    function a:forceCancel()
        rt.cancelling=true
        if not self.action and not self.nativeStarted and not w.startedAt then
            rt.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end
        end
        return false
    end
    a._SAOGeneratorReadingRetireSaved=function(person,saved)
        if not generatorReading.identity(id,saved) or not generatorReading.purpose(person,saved) or saved.id~=w.id
            or saved.itemId~=w.itemId or saved.itemType~=w.itemType or saved.bodyToken~=w.bodyToken or saved.world~=w.world then return false end
        rt.cancelling=true;rt.reason="generator-reading-runtime-unavailable"
        if a.action then a:forceStop() else a:forceCancel() end
        if rt.ack and not queued(a) and rt.queue.current~=a then
            if runtime[id]==rt then runtime[id]=nil end
            a._SAOGeneratorReadingRetireSaved=nil;rt.closed=true;return true
        end
        return false
    end
end
function generatorReading.interrupt(id,body,reason)
    local person,rt=rec(id),runtime[id];local w=person and person.studyWork
    if not w or w.kind~="generator-reading" or w.status~="reading" then return true end
    if rt and rt.generator then
        if body and rt.body~=body then return false end
        rt.cancelling,rt.reason=true,reason or "higher-priority-work"
        if rt.action.action then pcall(function() rt.action:forceStop() end) else rt.action:forceCancel() end
        return rt.closed==true or generatorReading.finish(id,"interrupted",rt.reason)
    end
    if not generatorReading.identity(id,w) or not generatorReading.purpose(person,w) or not body or hours()<w.beganAt
        or tostring(body:getModData().SAOPersonId or "")~=tostring(id) or body:getModData().SAOExternalToken~=w.bodyToken
        or w.world~=getWorld():getWorld() then return false end
    for _,q in pairs(ISTimedActionQueue.queues) do
        local pending={};for _,a in ipairs(q.queue) do pending[#pending+1]=a end
        if q.current and q:indexOf(q.current)==-1 then pending[#pending+1]=q.current end
        for _,a in ipairs(pending) do
        if a.workId==w.id and a.personId==id then
            if type(a._SAOGeneratorReadingRetireSaved)~="function" or a._SAOGeneratorReadingRetireSaved(person,w)~=true then return false end
        end
    end end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if SAOJavaBridge:hasPendingActions(body) or q.current or #q.queue>0 then return false end
    local a={personId=id,workId=w.id,character=body,nativeStarted=false,nativeCompleted=false}
    runtime[id]={generator=true,action=a,body=body,item=nil,work=w,record=person,queue=ISTimedActionQueue.getTimedActionQueue(body),ack=true}
    return generatorReading.finish(id,"interrupted","generator-reading-runtime-unavailable")
end
function S.reconcileGeneratorReading(id,body)
    for _,row in ipairs(rec(id) and rec(id).generatorReadingOutcomes or {}) do
        if not row.delivered and S.generatorOutcome(id,row.id) and SAO.ProceduralPlanning.consumeGeneratorReading(id,row.id) then row.delivered=true end
    end
    local work=rec(id) and rec(id).studyWork
    if work and work.kind=="generator-reading" and work.status=="reading" then return generatorReading.interrupt(id,body,"generator-reading-reconciled") end
    return true
end
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
    local retained={}
    for id,rt in pairs(runtime) do if rt.generator and not generatorReading.interrupt(id,rt.body,"world-reset") then retained[id]=rt end end
    runtime = retained
end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(reset) end
return S
