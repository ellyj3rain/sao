-- Synthetic menu and player ports around production creator Lua in Kahlua.
local passed, failed = 0, 0
local failures = {}
local function check(name, value)
    if value then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1
        failures[#failures+1] = name
        print("FAIL " .. name)
    end
end

require = function() return true end
local function event()
    return { Add = function() end, Remove = function() end }
end
Events = {
    OnCreatePlayer = event(), OnGameBoot = event(),
    OnMainMenuEnter = event(),
}
ISPanelJoypad = {}
function ISPanelJoypad:derive()
    local child = {}
    setmetatable(child, {__index = self})
    return child
end
function ISPanelJoypad:new(x, y, width, height)
    local item = {x=x,y=y,width=width,height=height,children={}}
    setmetatable(item, {__index=self})
    return item
end
function ISPanelJoypad:initialise() end
function ISPanelJoypad:addChild(child)
    self.children[#self.children+1] = child
    if child.createChildren then child:createChildren() end
end
function ISPanelJoypad:removeChild() end
function ISPanelJoypad:setVisible(value) self.visible = value end
function ISPanelJoypad:prerender() end
function ISPanelJoypad:onGainJoypadFocus(data) self.joyfocus = data end
function ISPanelJoypad:onLoseJoypadFocus() self.joyfocus = nil end
function ISPanelJoypad:clearJoypadFocus() end
function ISPanelJoypad:insertNewLineOfButtons(...)
    local row = {...}
    self.joypadButtonsY[#self.joypadButtonsY+1] = row
    for _, item in ipairs(row) do
        self.allJoypadButtons[#self.allJoypadButtons+1] = item
    end
end
function ISPanelJoypad:clearISButtons()
    self.ISButtonA, self.ISButtonB = nil, nil
end
function ISPanelJoypad:setISButtonForA(button) self.ISButtonA = button end
function ISPanelJoypad:setISButtonForB(button) self.ISButtonB = button end
Keyboard = {KEY_ESCAPE=1, KEY_TAB=2, KEY_RETURN=3}
ISButton = {}
function ISButton:new(x, y, width, height, title, owner, click)
    return setmetatable({x=x,y=y,width=width,height=height,
        title=title,owner=owner,onclick=click},
        {__index=self})
end
function ISButton:initialise() end
function ISButton:instantiate() end
function ISButton:setVisible(value) self.visible=value end
function ISButton:setTitle(value) self.title=value end
function ISButton:setJoypadButton(value) self.joypadButton=value end
function ISButton:clearJoypadButton() self.joypadButton=nil end
ISTextEntryBox = {}
function ISTextEntryBox:new(value,x,y,width,height)
    return setmetatable({text=value,x=x,y=y,width=width,height=height},
        {__index=self})
end
function ISTextEntryBox:initialise() end
function ISTextEntryBox:instantiate() end
function ISTextEntryBox:getText() return self.text end
function ISTextEntryBox:setText(value) self.text = value end
function ISTextEntryBox:setMultipleLine() end
function ISTextEntryBox:setMaxLines() end
function ISTextEntryBox:setVisible(value) self.visible=value end
function ISTextEntryBox:focus() self.focused=true end
function ISTextEntryBox:unfocus() self.focused=false end
function ISTextEntryBox:isFocused() return self.focused==true end
CharacterCreationAvatar = {}
function CharacterCreationAvatar:new(x,y,width,height)
    return setmetatable({x=x,y=y,width=width,height=height},
        {__index=self})
end
function CharacterCreationAvatar:initialise() end
function CharacterCreationAvatar:setSurvivorDesc(desc)
    self.survivorDesc=desc
end
function CharacterCreationAvatar:rescaleAvatarViewer()
    self.rescaled=true
end
UIFont = {Small="Small", Medium="Medium", Large="Large"}
local core = {width=1280,height=800,
    getScreenWidth=function(self) return self.width end,
    getScreenHeight=function(self) return self.height end}
local accountName = "PlayerOne"
function core:getAccountUsed()
    return {getUserName=function() return accountName end}
end
getCore = function() return core end
local world = {name="creator-fixture", mode="Sandbox"}
function world:getWorld() return self.name end
function world:getGameMode() return self.mode end
getWorld = function() return world end
SandboxVars = {
    BanditsWeekOne={EventFinalSolution=true,Variant=2},
    SurvivorAwareness={WeekOneNuke=false},
    WhereIWas={ActiveScenario=4},
}
local created = {}
ModData = {getOrCreate=function(key)
    created[key] = created[key] or {}
    return created[key]
end}
local nativeNext, variantNext, coopNext = 0, 0, 0
local mainDescriptorId = 6
CharacterCreationMain = {
    onOptionMouseDown=function(_, click)
        if click.internal == "NEXT" then nativeNext = nativeNext + 1 end
    end,
    onOptionMouseDown2=function(_, click)
        if click.internal == "VARIANT" then
            variantNext = variantNext + 1
        end
    end,
}
CoopCharacterCreationMain = {
    onOptionMouseDown=function(_, click)
        if click.internal == "NEXT" then coopNext = coopNext + 1 end
    end,
}
local main = {
    createWorld=true, inGame=false, children={},
    desc={nativeAppearance="selected-live-descriptor",
        getID=function() return mainDescriptorId end},
    charCreationMain={
        forenameEntry={getText=function() return "Avery" end},
        surnameEntry={getText=function() return "Stone" end},
        setVisible=function(self, value) self.visible=value end,
    },
}
function main:addChild(child)
    self.children[#self.children+1] = child
    if child.createChildren then child:createChildren() end
end
function main:removeChild() end
MainScreen = {instance=main}
setmetatable(main.charCreationMain, {__index=CharacterCreationMain})
TIYL = {PendingOriginId="origin-riverside"}
local joined, roster, nukeCalls = {}, {}, 0
SAO = {History={countyHours=function() return 20 end},
    Standing={
        playerAccountKey=function(player)
            return "player:" .. player:getUsername()
        end,
        characterKey=function(player, characterId)
            return "player:" .. player:getUsername()
                .. "/character/" .. characterId
        end,
        playerKey=function(player)
            local receipt=player:getModData().SAOCreationReceipt
            if not receipt then return "player:" .. player:getUsername() end
            if receipt.accountKey~="player:" .. player:getUsername()
                or receipt.playerKey~="player:" .. player:getUsername()
                    .. "/character/" .. receipt.characterId then
                return nil
            end
            return receipt.playerKey
        end,
        joinGroup=function(key, name)
            roster[key] = name
            joined[#joined+1] = {key=key,name=name}; return true
        end,
        joinCreatorGroup=function(key, name)
            if roster[key] ~= nil then return false end
            local accepted = SAO.Standing.joinGroup(key, name)
            if not accepted or roster[key] ~= name then return false end
            return true, {key=key, name=name, active=true}
        end,
        rollbackCreatorGroup=function(token)
            if not token.active or roster[token.key] ~= token.name then
                return false
            end
            roster[token.key] = nil
            token.active = false
            return true
        end,
    },
    Nuke={applyCreatorChoice=function(choice, receipt)
        nukeCalls=nukeCalls+1
        return (choice=="none" or choice=="SAO")
            and receipt.schema=="sao-created-player/1"
            and receipt.newWorld==true
    end},
}

local function body(forename, surname, descriptorId, username)
    local desc = {
        getForename=function() return forename end,
        getSurname=function() return surname end,
        getID=function() return descriptorId end,
        getCharacterProfession=function()
            return {getName=function() return "firefighter" end}
        end,
    }
    return {
        data={}, getModData=function(self) return self.data end,
        getDescriptor=function() return desc end,
        getUsername=function() return username or "PlayerOne" end,
    }
end

function fixtureCases()
    local C = SAO.Creator
    local draft = C.newDraft(nil)
    check("draft/native-context", draft.context.world=="creator-fixture"
        and draft.context.forename=="Avery"
        and draft.context.nativeDescriptorId==6
        and draft.context.playerSlot==0
        and draft.context.accountKey=="player:PlayerOne"
        and draft.context.scenario==4
        and draft.context.origin=="origin-riverside")
    check("draft/optional-nuke-default-off",
        draft.context.originalSaoNuke==false
        and draft.nukeChoice=="none")
    local native = main.charCreationMain
    local continued = 0
    local shown = C.beforeWorldTransition(native,
        function() continued=continued+1 end)
    check("ui/opens-before-world", shown==true and continued==0
        and C.UI.active~=nil and native.visible==false)
    local panel = C.UI.active
    panel:onClick(panel.continueButton)
    check("ui/history-required", panel.error=="background-required"
        and continued==0)
    panel.backgroundEntry:setText("Grew up in Riverside and repaired pumps.")
    panel.groupEntry:setText("Old friends")
    panel:onClick(panel.continueButton)
    check("ui/nuke-optional-default", continued==1
        and C.pending and C.pending.draft.nukeChoice=="none")
    check("native/new-world-continues", continued==1
        and C.pending.transitioned==true
        and SandboxVars.BanditsWeekOne.EventFinalSolution==false
        and SandboxVars.SurvivorAwareness.WeekOneNuke==false)
    local wrong = body("Someone", "Else", 6)
    local applied, reason = C.onCreatePlayer(0, wrong)
    check("native/mismatch-refused", applied==false
        and reason=="native-character-changed"
        and wrong.data.SAOCreationReceipt==nil
        and nukeCalls==0)
    local unidentified = body("Avery", "Stone", nil)
    applied, reason = C.onCreatePlayer(0, unidentified)
    check("native/missing-descriptor-refused", applied==false
        and reason=="native-character-changed"
        and unidentified.data.SAOCreationReceipt==nil
        and nukeCalls==0)
    local wrongDescriptor = body("Avery", "Stone", 7)
    applied, reason = C.onCreatePlayer(0, wrongDescriptor)
    check("native/same-name-other-descriptor-refused", applied==false
        and reason=="native-character-changed"
        and wrongDescriptor.data.SAOCreationReceipt==nil
        and nukeCalls==0)
    local wrongSlot = body("Avery", "Stone", 6)
    applied, reason = C.onCreatePlayer(1, wrongSlot)
    check("native/same-name-other-slot-refused", applied==false
        and reason=="world-or-slot-changed"
        and wrongSlot.data.SAOCreationReceipt==nil
        and nukeCalls==0)
    local wrongAccount = body("Avery", "Stone", 6, "Other")
    applied, reason = C.onCreatePlayer(0, wrongAccount)
    check("native/same-name-other-account-refused", applied==false
        and reason=="native-account-changed"
        and wrongAccount.data.SAOCreationReceipt==nil
        and nukeCalls==0)
    local avery = body("Avery", "Stone", 6)
    applied, reason = C.onCreatePlayer(0, avery)
    local first = avery.data.SAOCreationReceipt
    check("identity/native-receipt", applied==true and first
        and first.schema=="sao-created-player/1"
        and first.characterId=="sao-player-1"
        and first.accountKey=="player:PlayerOne"
        and first.playerKey=="player:PlayerOne/character/sao-player-1"
        and first.nativeDescriptorId==6
        and first.nativeProfession=="firefighter"
        and first.background=="Grew up in Riverside and repaired pumps."
        and first.nativeScenario==4 and first.nativeOrigin=="origin-riverside"
        and first.nukeChoice=="none")
    check("identity/world-and-standing", nukeCalls==1
        and #joined==1 and joined[1].name=="Old friends"
        and joined[1].key=="player:PlayerOne/character/sao-player-1"
        and created.SurvivorAwareness_PlayerCreator
            .characters["sao-player-1"]~=nil)
    applied, reason = C.onCreatePlayer(0, avery)
    check("identity/reload-idempotent", applied==true
        and reason=="already-applied" and nukeCalls==1
        and created.SurvivorAwareness_PlayerCreator.nextCharacter==2)
    if avery.data.SAOCreationReceipt then
        avery.data.SAOCreationReceipt.accountKey="player:Other"
        applied,reason=C.onCreatePlayer(0,avery)
        check("identity/foreign-receipt-refused", applied==false
            and reason=="creation-receipt-invalid")
        avery.data.SAOCreationReceipt.accountKey="player:PlayerOne"
    else
        check("identity/foreign-receipt-refused", false)
    end
    main.createWorld=false
    mainDescriptorId=7
    local again = C.beforeWorldTransition(native,
        function() continued=continued+1 end)
    panel = C.UI.active
    check("respawn/world-choice-read-only", again==true
        and panel.noneButton==nil and panel.saoButton==nil)
    panel.backgroundEntry:setText("A different life in the same county.")
    panel:onClick(panel.continueButton)
    check("respawn/native-transition", continued==2
        and C.pending.draft.nukeChoice==nil and nukeCalls==1)
    local second = body("Avery", "Stone", 7)
    applied = C.onCreatePlayer(0, second)
    check("respawn/distinct-durable-character", applied==true
        and second.data.SAOCreationReceipt
        and second.data.SAOCreationReceipt.characterId=="sao-player-2"
        and second.data.SAOCreationReceipt.playerKey
            =="player:PlayerOne/character/sao-player-2"
        and nukeCalls==1)
    main.createWorld=true
    mainDescriptorId=8
    main.variantMain={}
    native.variantButton={internal="VARIANT"}
    CharacterCreationMain.onOptionMouseDown(native, {internal="NEXT"})
    check("tiyl/direct-next-enters-weekone-variant",
        variantNext==1 and nativeNext==0 and C.UI.active==nil)
    main.variantMain=nil
    native.variantButton=nil
    CharacterCreationMain.onOptionMouseDown(native, {internal="NEXT"})
    check("native/direct-next-opens-owned-creator", C.UI.active~=nil
        and nativeNext==0)
    C.UI.active:close(true)
    SandboxVars.BanditsWeekOne.EventFinalSolution=true
    SandboxVars.SurvivorAwareness.WeekOneNuke=false
    local draftRollback = C.newDraft(native)
    draftRollback.background="Was a mechanic before the event."
    draftRollback.nukeChoice="SAO"
    C.confirm(draftRollback, native)
    local advanced = C.continueConfirmed(native, function()
        error("native transition failed")
    end)
    check("transition/error-restores-sandbox", advanced==false
        and SandboxVars.BanditsWeekOne.EventFinalSolution==true
        and SandboxVars.SurvivorAwareness.WeekOneNuke==false
        and C.pending.transitioned==false)
    C.pending=nil
    local draftFalse=C.newDraft(native)
    draftFalse.background="A prior life in this county."
    draftFalse.nukeChoice="SAO"
    C.confirm(draftFalse,native)
    advanced=C.continueConfirmed(native,function() return false end)
    check("transition/false-result-restores-sandbox", advanced==false
        and SandboxVars.BanditsWeekOne.EventFinalSolution==true
        and SandboxVars.SurvivorAwareness.WeekOneNuke==false
        and C.pending.transitioned==false)
    C.pending=nil
    C.beforeWorldTransition(native,function()
        error("native transition failed again")
    end)
    local failedPanel=C.UI.active
    failedPanel.backgroundEntry:setText("A life before the outbreak.")
    failedPanel:onClick(failedPanel.noneButton)
    failedPanel:onClick(failedPanel.continueButton)
    failedPanel:onClick(failedPanel.backButton)
    check("transition/back-revokes-confirmed-pending",
        C.pending==nil and C.UI.active==nil)
    C.beforeWorldTransition(native,function() continued=continued+1 end)
    check("transition/next-reopens-explicit-creator",
        C.UI.active~=nil and continued==2)
    C.UI.active:close(true)
    local stale = C.newDraft(native)
    stale.background="Had family in this county."
    stale.nukeChoice="none"
    C.confirm(stale,native)
    SandboxVars.WhereIWas.ActiveScenario=5
    advanced = C.continueConfirmed(native, function()
        continued=continued+1
    end)
    check("native/scenario-change-refuses-stale-draft", advanced==false
        and continued==2)
    SandboxVars.WhereIWas.ActiveScenario=4
    C.pending=nil
    local identityDraft=C.newDraft(native)
    identityDraft.background="Kept the same native creation choice."
    identityDraft.nukeChoice="none"
    C.confirm(identityDraft,native)
    mainDescriptorId=88
    advanced=C.continueConfirmed(native,function() continued=continued+1 end)
    check("transition/descriptor-change-refuses-draft",
        advanced==false and continued==2)
    mainDescriptorId=8
    C.pending=nil
    identityDraft=C.newDraft(native)
    identityDraft.background="Kept the same selected account."
    identityDraft.nukeChoice="none"
    C.confirm(identityDraft,native)
    accountName="Other"
    advanced=C.continueConfirmed(native,function() continued=continued+1 end)
    check("transition/account-change-refuses-draft",
        advanced==false and continued==2)
    accountName="PlayerOne"
    C.pending=nil
    CoopCharacterCreation={instance={playerIndex=2,charCreationMain=native}}
    identityDraft=C.newDraft(native)
    identityDraft.background="Kept the same selected player slot."
    identityDraft.nukeChoice="none"
    C.confirm(identityDraft,native)
    CoopCharacterCreation.instance.playerIndex=3
    advanced=C.continueConfirmed(native,function() continued=continued+1 end)
    check("transition/slot-change-refuses-draft",
        advanced==false and continued==2)
    CoopCharacterCreation.instance=nil
    C.pending=nil
    local retry = C.newDraft(native)
    retry.background="Repaired engines with old friends."
    retry.groupName="Old friends"
    retry.nukeChoice="none"
    C.confirm(retry,native)
    C.continueConfirmed(native,function() continued=continued+1 end)
    local nukeOwner = SAO.Nuke.applyCreatorChoice
    SAO.Nuke.applyCreatorChoice=function() return false end
    local beforeSequence =
        created.SurvivorAwareness_PlayerCreator.nextCharacter
    local retryBody=body("Avery","Stone",8)
    local retryKey="player:PlayerOne/character/sao-player-"
        ..tostring(beforeSequence)
    local beforeNuke=nukeCalls
    local accepted, refusal=C.onCreatePlayer(0,retryBody)
    check("identity/nuke-refusal-no-partial-record", accepted==false
        and refusal=="nuke-owner-refused"
        and retryBody.data.SAOCreationReceipt==nil
        and roster[retryKey]==nil and nukeCalls==beforeNuke
        and created.SurvivorAwareness_PlayerCreator.nextCharacter
            ==beforeSequence)
    SAO.Nuke.applyCreatorChoice=nukeOwner
    local groupOwner=SAO.Standing.joinCreatorGroup
    SAO.Standing.joinCreatorGroup=function() return false end
    accepted,refusal=C.onCreatePlayer(0,retryBody)
    check("identity/group-refusal-no-partial-record", accepted==false
        and refusal=="group-owner-refused"
        and retryBody.data.SAOCreationReceipt==nil
        and roster[retryKey]==nil and nukeCalls==beforeNuke
        and created.SurvivorAwareness_PlayerCreator.nextCharacter
            ==beforeSequence)
    SAO.Standing.joinCreatorGroup=groupOwner
    accepted=C.onCreatePlayer(0,retryBody)
    check("identity/retained-native-body-retries", accepted==true
        and roster[retryKey]=="Old friends" and nukeCalls==beforeNuke+1
        and retryBody.data.SAOCreationReceipt
        and retryBody.data.SAOCreationReceipt.characterId
            =="sao-player-"..tostring(beforeSequence))
    local oldHours=SAO.History.countyHours
    SAO.History.countyHours=function() error("clock not ready") end
    mainDescriptorId=9
    GameTime={getInstance=function()
        return {getWorldAgeHours=function() return 31 end}
    end}
    local fallback=C.newDraft(native)
    fallback.background="Built bridges before the event."
    fallback.nukeChoice="none"
    C.confirm(fallback,native)
    C.continueConfirmed(native,function() continued=continued+1 end)
    local hourBody=body("Avery","Stone",9)
    accepted=C.onCreatePlayer(0,hourBody)
    check("identity/native-clock-fallback", accepted==true
        and hourBody.data.SAOCreationReceipt
        and hourBody.data.SAOCreationReceipt.appliedAtHours==31)
    SAO.History.countyHours=oldHours
    mainDescriptorId=10
    local collision = C.newDraft(native)
    collision.background="Kept the same saved people."
    collision.nukeChoice="none"
    C.confirm(collision,native)
    C.continueConfirmed(native,function() end)
    local creatorStore=created.SurvivorAwareness_PlayerCreator
    local preserved=creatorStore.characters["sao-player-1"]
    local nextCharacter=creatorStore.nextCharacter
    creatorStore.nextCharacter=1
    local collisionBody=body("Avery","Stone",10)
    accepted,refusal=C.onCreatePlayer(0,collisionBody)
    check("identity/character-collision-preserves-prior-save",
        accepted==false and refusal=="character-sequence-conflict"
        and creatorStore.characters["sao-player-1"]==preserved
        and collisionBody.data.SAOCreationReceipt==nil)
    creatorStore.nextCharacter=nextCharacter
    C.pending=nil
    core.height=736
    C.UI.show(native,function() end)
    local wide=C.UI.active
    check("geometry/720-background-before-world-band",
        wide.height==720 and not wide.compact
        and wide.backgroundEntry.y+wide.backgroundEntry.height
            <=wide.noneButton.y-15
        and wide.noneButton.y+wide.noneButton.height
            <wide.continueButton.y)
    check("native/live-descriptor-preview",
        wide.preview and wide.preview.survivorDesc==main.desc
        and wide.preview.rescaled==true
        and main.desc.nativeAppearance=="selected-live-descriptor")
    wide:close(true)
    core.height=516
    C.UI.show(native,function() end)
    local medium=C.UI.active
    check("geometry/500-background-before-world-band",
        medium.height==500 and not medium.compact
        and medium.backgroundEntry.y+medium.backgroundEntry.height
            <=medium.noneButton.y-15
        and medium.noneButton.y+medium.noneButton.height
            <medium.continueButton.y)
    medium:close(true)
    core.height=480
    C.UI.show(native,function() end)
    local small=C.UI.active
    check("geometry/464-compact-history-fits", small.height==464
        and small.compact and small.page==1
        and small.backgroundEntry.y+small.backgroundEntry.height
            <small.continueButton.y
        and small.noneButton.visible==false)
    small.backgroundEntry:setText("A new life in this world.")
    small:onClick(small.continueButton)
    check("geometry/464-compact-world-choice-fits", small.page==2
        and small.backgroundEntry.visible==false
        and small.noneButton.visible==true
        and small.noneButton.y+small.noneButton.height
            <small.continueButton.y)
    small:close(true)
    core.height=340
    local shown, reason=C.UI.show(native,function() end)
    check("geometry/tiny-screen-blocks-before-overflow",
        shown==false and reason=="screen-too-small-for-creation"
        and C.UI.active==nil)
    core.width, core.height = 640, 480
    C.UI.show(native,function() continued=continued+1 end)
    local narrow=C.UI.active
    check("geometry/narrow-history-bands",
        narrow.width==624 and narrow.height==464 and narrow.singleColumn
        and narrow.backgroundEntry.y+narrow.backgroundEntry.height
            <narrow.continueButton.y
        and narrow.groupEntry.y>=187)
    local joypadData={}
    narrow:onGainJoypadFocus(joypadData)
    check("controller/history-rows-and-actions",
        narrow.joyfocus==joypadData and #narrow.joypadButtonsY==3
        and narrow.joypadButtonsY[1][1]==narrow.groupEntry
        and narrow.ISButtonA==narrow.continueButton
        and narrow.ISButtonB==narrow.backButton)
    narrow:onKeyRelease(Keyboard.KEY_TAB)
    local firstFocus=narrow.groupEntry:isFocused()
    narrow:onKeyRelease(Keyboard.KEY_TAB)
    local secondFocus=narrow.backgroundEntry:isFocused()
    narrow.backgroundEntry:setText("A life in the county before the outbreak.")
    narrow:onKeyRelease(Keyboard.KEY_TAB)
    narrow:onKeyRelease(Keyboard.KEY_RETURN)
    check("keyboard/tab-history-enter-world-page",
        firstFocus and secondFocus and narrow.page==2
        and not narrow.backgroundEntry:isFocused())
    check("controller/world-choice-rows",
        #narrow.joypadButtonsY==2
        and narrow.joypadButtonsY[1][1]==narrow.noneButton
        and narrow.ISButtonA==narrow.continueButton)
    narrow:onKeyRelease(Keyboard.KEY_TAB)
    narrow:onKeyRelease(Keyboard.KEY_RETURN)
    check("keyboard/explicit-world-selection",
        narrow.draft.nukeChoice=="none")
    narrow:onKeyRelease(Keyboard.KEY_RETURN)
    check("keyboard/enter-confirms-and-continues",
        C.UI.active==nil and C.pending and C.pending.transitioned
        and continued==5)
    C.pending=nil
    C.UI.show(native,function() end)
    local backPanel=C.UI.active
    backPanel.backgroundEntry:setText("Kept the family farm working.")
    backPanel:onKeyRelease(Keyboard.KEY_ESCAPE)
    check("keyboard/back-keeps-unconfirmed-draft",
        C.UI.active==nil and C.unconfirmed
        and C.unconfirmed.background=="Kept the family farm working.")
    C.UI.show(native,function() end)
    check("keyboard/reopen-restores-draft",
        C.UI.active and C.UI.active.backgroundEntry:getText()
            =="Kept the family farm working.")
    C.UI.active:onGainJoypadFocus(joypadData)
    C.UI.active:onLoseJoypadFocus(joypadData)
    check("controller/focus-release",
        C.UI.active.joyfocus==nil and C.UI.active.ISButtonA==nil
        and C.UI.active.ISButtonB==nil)
    C.UI.active:close(true)
    core.height=400
    shown,reason=C.UI.show(native,function() end)
    check("geometry/narrow-short-screen-blocked",
        shown==false and reason=="screen-too-small-for-creation")
    return tostring(passed) .. ":" .. tostring(failed)
        .. ":" .. table.concat(failures, ",")
end
