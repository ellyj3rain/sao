-- SAO's player creation state. The native game chooses the save, body,
-- appearance, profession, traits, scenario and spawn. A confirmed draft joins
-- that choice only after OnCreatePlayer supplies the actual native body.
SAO = SAO or {}
SAO.Creator = SAO.Creator or {}
local C = SAO.Creator

local STORE_KEY = "SurvivorAwareness_PlayerCreator"
local MAX_NAME, MAX_BACKGROUND = 72, 600

local function trim(value, limit)
    if type(value) ~= "string" then return "" end
    local text = value:gsub("^%s+", ""):gsub("%s+$", "")
    if #text > limit then return nil end
    return text
end

local function selectedWorld()
    local ok, name, mode = pcall(function()
        return getWorld():getWorld(), getWorld():getGameMode()
    end)
    if not ok or type(name) ~= "string" or name == ""
        or type(mode) ~= "string" or mode == "" then return nil end
    return name, mode
end

local function nativeName(screen)
    local coop = CoopCharacterCreation and CoopCharacterCreation.instance
    local main = screen and screen.forenameEntry and screen
        or coop and coop.charCreationMain
        or MainScreen and MainScreen.instance
            and MainScreen.instance.charCreationMain
    local ok, forename, surname = pcall(function()
        return main.forenameEntry:getText(), main.surnameEntry:getText()
    end)
    if not ok then return nil end
    forename, surname = trim(forename, MAX_NAME), trim(surname, MAX_NAME)
    if not forename or forename == "" or not surname or surname == "" then
        return nil
    end
    return forename, surname
end

-- The native descriptor survives CharacterCreationMain:initPlayer and the
-- loading transition. CoopCharacterCreation supplies its selected player
-- slot before accept clears its instance.
local function nativeIdentity()
    local main = MainScreen and MainScreen.instance
    local ok, id = pcall(function() return main.desc:getID() end)
    if not ok or type(id) ~= "number" or id < 0
        or id % 1 ~= 0 then return nil, "native-descriptor-unavailable" end
    local coop = CoopCharacterCreation and CoopCharacterCreation.instance
    local slot = coop and coop.playerIndex or 0
    if type(slot) ~= "number" or slot < 0 or slot % 1 ~= 0 then
        return nil, "native-slot-unavailable"
    end
    local account
    if coop and slot > 0 and CoopUserName and CoopUserName.instance then
        ok, account = pcall(function()
            return CoopUserName.instance:getUserName()
        end)
        if not ok or type(account) ~= "string" or account == "" then
            return nil, "native-account-unavailable"
        end
    else
        local accountOK, selected = pcall(function()
            return getCore():getAccountUsed()
        end)
        if accountOK and selected then
            ok, account = pcall(function() return selected:getUserName() end)
            if not ok or type(account) ~= "string" or account == "" then
                return nil, "native-account-unavailable"
            end
        elseif type(isClient) == "function" and isClient()
            and type(getClientUsername) == "function" then
            ok, account = pcall(getClientUsername)
            if not ok or type(account) ~= "string" or account == "" then
                return nil, "native-account-unavailable"
            end
        end
    end
    return {descriptorId = id, playerSlot = slot,
        accountKey = account and "player:" .. account or nil}
end

local function optionValue(group, key)
    if type(group) ~= "table" then return nil end
    return group[key]
end

local function selectedScenario()
    local vars = SandboxVars and (SandboxVars.WhereIWas
        or SandboxVars.KnoxScenarios)
    return vars and vars.ActiveScenario or nil
end

local function selectedOrigin()
    return TIYL and (TIYL.PendingOriginId or TIYL.PendingPosterStoryId)
        or nil
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function currentContext(screen)
    local world, mode = selectedWorld()
    local forename, surname = nativeName(screen)
    if not world or not forename then return nil, "native-choice-unavailable" end
    local identity, reason = nativeIdentity()
    if not identity then return nil, reason end
    local main = MainScreen and MainScreen.instance
    local newWorld = main and main.createWorld == true
    local variant = screen and screen.variantListBox
        and screen.variantListBox.selected
        or SandboxVars and SandboxVars.BanditsWeekOne
            and SandboxVars.BanditsWeekOne.Variant
    return {
        world = world, gameMode = mode, newWorld = newWorld == true,
        forename = forename, surname = surname,
        nativeDescriptorId = identity.descriptorId,
        playerSlot = identity.playerSlot, accountKey = identity.accountKey,
        scenario = selectedScenario(), origin = selectedOrigin(),
        weekOneVariant = variant,
        originalBwoNuke = optionValue(SandboxVars
            and SandboxVars.BanditsWeekOne, "EventFinalSolution"),
        originalSaoNuke = optionValue(SandboxVars
            and SandboxVars.SurvivorAwareness, "WeekOneNuke"),
    }
end

function C.context(screen)
    return currentContext(screen)
end

function C.newDraft(screen)
    local context, reason = currentContext(screen)
    if not context then return nil, reason end
    return {
        schema = "sao-player-creator-draft/1",
        context = context,
        groupName = "",
        background = "",
        nukeChoice = context.newWorld and "none" or nil,
        confirmed = false,
    }
end

local function sameStart(a, b)
    return a and b and a.world == b.world and a.gameMode == b.gameMode
        and a.newWorld == b.newWorld and a.forename == b.forename
        and a.surname == b.surname
        and a.nativeDescriptorId == b.nativeDescriptorId
        and a.playerSlot == b.playerSlot
        and a.accountKey == b.accountKey
        and a.scenario == b.scenario and a.origin == b.origin
        and a.weekOneVariant == b.weekOneVariant
end

function C.validate(draft, context)
    if type(draft) ~= "table"
        or draft.schema ~= "sao-player-creator-draft/1"
        or not sameStart(draft.context, context) then
        return false, "native-choice-changed"
    end
    local group = trim(draft.groupName, MAX_NAME)
    local background = trim(draft.background, MAX_BACKGROUND)
    if not group then return false, "group-name-too-long" end
    if not background then return false, "background-too-long" end
    if background == "" then return false, "background-required" end
    if context.newWorld and draft.nukeChoice == nil then
        draft.nukeChoice = "none"
    end
    if context.newWorld
        and draft.nukeChoice ~= "none" and draft.nukeChoice ~= "SAO" then
        return false, "nuke-choice-required"
    end
    if not context.newWorld and draft.nukeChoice ~= nil then
        return false, "existing-world-choice-is-fixed"
    end
    draft.groupName, draft.background = group, background
    return true
end

function C.confirm(draft, screen)
    local context = currentContext(screen)
    local valid, reason = C.validate(draft, context)
    if not valid then C.pending = nil; return false, reason end
    local confirmed = copy(draft)
    confirmed.context = copy(context)
    confirmed.confirmed = true
    C.pending = {draft = confirmed, context = context}
    return true
end

local function applyWorldChoice(pending)
    if not pending.context.newWorld then return true end
    local choice = pending.draft.nukeChoice
    if choice ~= "none" and choice ~= "SAO" then
        return false, "nuke-choice-required"
    end
    if type(SandboxVars) ~= "table"
        or type(SandboxVars.SurvivorAwareness) ~= "table" then
        return false, "nuke-sandbox-unavailable"
    end
    -- This is an explicit choice made after the native sandbox screen. It
    -- changes only the two strike dials for a newly created world.
    if type(SandboxVars.BanditsWeekOne) == "table" then
        SandboxVars.BanditsWeekOne.EventFinalSolution = false
    end
    SandboxVars.SurvivorAwareness.WeekOneNuke = choice == "SAO"
    return true
end

function C.continueConfirmed(screen, continue)
    local pending = C.pending
    local context = currentContext(screen)
    if not pending or not pending.draft.confirmed
        or not sameStart(pending.context, context) then
        return false, "confirmed-start-unavailable"
    end
    local beforeBwo = SandboxVars and SandboxVars.BanditsWeekOne
        and SandboxVars.BanditsWeekOne.EventFinalSolution
    local beforeSao = SandboxVars and SandboxVars.SurvivorAwareness
        and SandboxVars.SurvivorAwareness.WeekOneNuke
    local ok, reason = applyWorldChoice(pending)
    if not ok then return false, reason end
    pending.context.scenario = context.scenario
    pending.context.origin = context.origin
    pending.context.weekOneVariant = context.weekOneVariant
    pending.transitioned = true
    local advanced, result = pcall(continue)
    if not advanced or result == false then
        if pending.context.newWorld and SandboxVars then
            if SandboxVars.BanditsWeekOne then
                SandboxVars.BanditsWeekOne.EventFinalSolution = beforeBwo
            end
            if SandboxVars.SurvivorAwareness then
                SandboxVars.SurvivorAwareness.WeekOneNuke = beforeSao
            end
        end
        pending.transitioned = false
        return false, advanced and "native-transition-refused"
            or tostring(result)
    end
    return true
end

-- P005 calls this at the final Week One NEXT. The native creator hook calls
-- the same function on paths where the Week One panel is absent.
function C.beforeWorldTransition(screen, continue)
    if type(continue) ~= "function" then return false end
    local context, reason = currentContext(screen)
    if not context then
        C.lastError = reason
        if SAO.Log and SAO.Log.line then
            SAO.Log.line("CREATOR", "creation blocked: " .. tostring(reason))
        end
        return true
    end
    if C.pending and C.pending.draft.confirmed
        and sameStart(C.pending.context, context) then
        local ok, why = C.continueConfirmed(screen, continue)
        C.lastError = why
        return true
    end
    if not C.UI or type(C.UI.show) ~= "function" then
        C.lastError = "creator-ui-unavailable"
        if SAO.Log and SAO.Log.line then
            SAO.Log.line("CREATOR", "creation blocked: creator-ui-unavailable")
        end
        return true
    end
    C.pending = nil
    local shown, why = C.UI.show(screen, continue)
    C.lastError = why
    if shown ~= true then
        if SAO.Log and SAO.Log.line then
            SAO.Log.line("CREATOR", "creation blocked: " .. tostring(why))
        end
    end
    return true
end

local function worldStore()
    local ok, data = pcall(function() return ModData.getOrCreate(STORE_KEY) end)
    if not ok or type(data) ~= "table" then return nil end
    if data.characters == nil then data.characters = {} end
    if data.nextCharacter == nil then data.nextCharacter = 1 end
    if type(data.characters) ~= "table"
        or type(data.nextCharacter) ~= "number"
        or data.nextCharacter < 1
        or data.nextCharacter % 1 ~= 0 then return nil end
    return data
end

local function descriptorOf(player)
    local ok, desc, forename, surname, id, profession = pcall(function()
        local d = player:getDescriptor()
        local p = d and d:getCharacterProfession()
        return d, d:getForename(), d:getSurname(), d:getID(),
            p and p:getName() or nil
    end)
    if not ok or not desc or type(id) ~= "number"
        or id < 0 or id % 1 ~= 0 then return nil end
    return {
        forename = forename, surname = surname, descriptorId = id,
        profession = profession,
    }
end

local function currentHours()
    local ok, hours = pcall(function() return SAO.History.countyHours() end)
    if ok and type(hours) == "number" and hours >= 0 then return hours end
    ok, hours = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    return ok and type(hours) == "number" and hours >= 0
        and hours or nil
end

function C.onCreatePlayer(playerIndex, player)
    if not player then return false, "player-unavailable" end
    local ok, data = pcall(function() return player:getModData() end)
    if not ok or type(data) ~= "table" then
        return false, "player-moddata-unavailable"
    end
    if type(data.SAOCreationReceipt) == "table" then
        local receipt = data.SAOCreationReceipt
        local key = SAO.Standing and SAO.Standing.playerKey
            and SAO.Standing.playerKey(player) or nil
        if type(key) == "string" and key ~= ""
            and key == receipt.playerKey then
            return true, "already-applied"
        end
        return false, "creation-receipt-invalid"
    end
    local pending = C.pending
    if not pending or not pending.transitioned
        or not pending.draft.confirmed then
        return false, "no-confirmed-creation"
    end
    local world, mode = selectedWorld()
    if world ~= pending.context.world or mode ~= pending.context.gameMode
        or type(playerIndex) ~= "number" or playerIndex < 0
        or playerIndex % 1 ~= 0
        or playerIndex ~= pending.context.playerSlot then
        return false, "world-or-slot-changed"
    end
    local native = descriptorOf(player)
    if not native or native.forename ~= pending.context.forename
        or native.surname ~= pending.context.surname
        or native.descriptorId ~= pending.context.nativeDescriptorId then
        return false, "native-character-changed"
    end
    local store = worldStore()
    if not store then return false, "creator-store-unavailable" end
    local sequence = store.nextCharacter
    local characterId = "sao-player-" .. tostring(sequence)
    if store.characters[characterId] ~= nil then
        return false, "character-sequence-conflict"
    end
    local accountKey = SAO.Standing and SAO.Standing.playerAccountKey
        and SAO.Standing.playerAccountKey(player) or nil
    local playerKey = SAO.Standing and SAO.Standing.characterKey
        and SAO.Standing.characterKey(player, characterId) or nil
    if type(accountKey) ~= "string" or accountKey == ""
        or type(playerKey) ~= "string" or playerKey == "" then
        return false, "player-key-unavailable"
    end
    if pending.context.accountKey
        and accountKey ~= pending.context.accountKey then
        return false, "native-account-changed"
    end
    local atHours = currentHours()
    if not atHours then return false, "clock-unavailable" end
    local startBabeChoice = nil
    if pending.context.newWorld and type(SandboxVars) == "table"
        and type(SandboxVars.BanditsWeekOne) == "table"
        and type(SandboxVars.BanditsWeekOne.StartBabe) == "boolean" then
        startBabeChoice = SandboxVars.BanditsWeekOne.StartBabe
    end
    local receipt = {
        schema = "sao-created-player/1",
        decisionId = world .. "|" .. mode .. "|" .. tostring(sequence),
        world = world, gameMode = mode, newWorld = pending.context.newWorld,
        characterId = characterId, accountKey = accountKey,
        playerKey = playerKey,
        playerIndex = playerIndex, nativeDescriptorId = native.descriptorId,
        forename = native.forename, surname = native.surname,
        nativeProfession = native.profession,
        nativeScenario = pending.context.scenario,
        nativeOrigin = pending.context.origin,
        weekOneVariant = pending.context.weekOneVariant,
        weekOneStartBabe = startBabeChoice,
        groupName = pending.draft.groupName,
        background = pending.draft.background,
        nukeChoice = pending.context.newWorld
            and pending.draft.nukeChoice or nil,
        appliedAtHours = atHours,
    }
    if pending.context.newWorld and not (SAO.Nuke
        and type(SAO.Nuke.applyCreatorChoice) == "function") then
        return false, "nuke-owner-unavailable"
    end
    local groupToken
    if receipt.groupName ~= "" then
        if not (SAO.Standing and type(SAO.Standing.joinCreatorGroup)
            == "function" and type(SAO.Standing.rollbackCreatorGroup)
            == "function") then return false, "group-owner-unavailable" end
        local joined, accepted, token = pcall(SAO.Standing.joinCreatorGroup,
            playerKey, receipt.groupName)
        if not joined or accepted ~= true or type(token) ~= "table" then
            return false, "group-owner-refused"
        end
        groupToken = token
    end
    if pending.context.newWorld then
        local called, accepted = pcall(SAO.Nuke.applyCreatorChoice,
            pending.draft.nukeChoice, receipt)
        if not called or accepted ~= true then
            if groupToken then
                local rolled, undone = pcall(
                    SAO.Standing.rollbackCreatorGroup, groupToken)
                if not rolled or undone ~= true then
                    return false, "group-rollback-refused"
                end
            end
            return false, "nuke-owner-refused"
        end
    end
    store.nextCharacter = sequence + 1
    store.characters[characterId] = copy(receipt)
    data.SAOCreationReceipt = copy(receipt)
    C.pending = nil
    return true, receipt
end

if Events and Events.OnCreatePlayer then
    if C.createPlayerHandler then
        Events.OnCreatePlayer.Remove(C.createPlayerHandler)
    end
    C.createPlayerHandler = function(index, player)
        local ok, reason = C.onCreatePlayer(index, player)
        if not ok and reason ~= "no-confirmed-creation" then
            if SAO.Log and SAO.Log.line then
                SAO.Log.line("CREATOR", "native application " .. tostring(reason))
            end
        end
    end
    Events.OnCreatePlayer.Add(C.createPlayerHandler)
end

return C
