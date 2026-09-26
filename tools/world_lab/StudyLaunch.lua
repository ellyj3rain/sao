-- RunConfig is supplied only by the isolated native runner.
-- This uses the game's debug scenario entry, then ordinary game ticks and exit.
require "DebugUIs/DebugScenarios"
Events.OnGameBoot.Add(function()
debugScenarios = debugScenarios or {}
for _, scenario in pairs(debugScenarios) do scenario.forceLaunch = false end
debugScenarios.NativeStudy = {
    name = "Native study", world = RunConfig.mapName,
    forceLaunch = RunConfig.resumeSave == nil,
    startLoc = RunConfig.origin,
    setSandbox = function()
        ActiveMods.getById("currentGame"):copyFrom(ActiveMods.getById("default"))
        getWorld():setGameMode("Sandbox")
    end,
    onStart = function() print("[StudyLaunch] native character created") end
}
getDebugOptions():setBoolean("DebugScenario.ForceLaunch", true)
getCore():setOptionFocusloss(false)
end)
if RunConfig.resumeSave then
    Events.OnMainMenuEnter.Add(function()
        MainScreen.continueLatestSave("Sandbox", RunConfig.resumeSave)
        if RunConfig.replaceDeadPlayer or RunConfig.observer then
            assert(not checkSavePlayerExists() and MainScreen.instance.createWorld == false,
                "continuation configuration requires an existing world without a living player")
            local profession = CharacterCreationProfession.instance
            assert(profession:isVisible() and profession:PointToSpend() >= 0
                and profession.playButton:isEnabled(), "native profession selection unavailable")
            local traits = {}
            for _, row in ipairs(profession.listboxTraitSelected.items) do
                traits[#traits + 1] = row.item:getType():getName()
            end
            print("[StudyLaunch] replacement selection profession=" .. tostring(profession:getSelectedProf():getType())
                .. " traits=" .. table.concat(traits, ","))
            profession.playButton:forceClick()
            local character = CharacterCreationMain.instance
            assert(character:isVisible() and character.playButton:isEnabled(), "native character selection unavailable")
            character.playButton:forceClick()
        end
    end)
end
local function playerReceipt(event, player)
    if not player then return end
    print("[StudyLaunch] player event=" .. event .. " attempt=" .. RunConfig.attempt
        .. " save=" .. getWorld():getWorld() .. " hours=" .. tostring(getGameTime():getWorldAgeHours())
        .. " dead=" .. tostring(player:isDead()) .. " health=" .. tostring(player:getHealth())
        .. " x=" .. tostring(player:getX()) .. " y=" .. tostring(player:getY()) .. " z=" .. tostring(player:getZ())
        .. " globalIsCharacter=" .. tostring(getPlayer() == player)
        .. " slotIsCharacter=" .. tostring(getSpecificPlayer(0) == player))
end
-- getPlayer() reads a mutable global used during NPC updates. Keep the actual
-- launch-slot character so death and horizon receipts cannot switch people.
local launchPlayer = nil
Events.OnNewGame.Add(function(player)
    if player == getSpecificPlayer(0) then
        launchPlayer = player
        playerReceipt("new-character", player)
    end
end)
Events.OnPlayerDeath.Add(function(player)
    if player == launchPlayer then playerReceipt("death", player) end
end)
local started = nil
local finished = false
local captured = false
Events.OnGameStart.Add(function()
    launchPlayer = assert(getSpecificPlayer(0), "native launch-slot character unavailable")
    if RunConfig.observer then
        assert(launchPlayer:getModData().SAO_ObserverAnchor == true, "detached observer unavailable")
        assert(SAO.Participants and SAO.Participants.player(0) == nil, "observer admitted as SAO participant")
        assert(not ZAO or (ZAO.Participants and ZAO.Participants.player(0) == nil),
            "observer admitted as ZAO participant")
        launchPlayer:getModData().SAO_ObserverStarted = true
        UIManager.setVisibleAllUI(false)
        print("[StudyLaunch] nonparticipating observer started")
    else
        playerReceipt("start", launchPlayer)
    end
    started = getGameTime():getWorldAgeHours()
    print("[StudyLaunch] started attempt=" .. RunConfig.attempt .. " save=" .. getWorld():getWorld()
        .. " hours=" .. tostring(started))
end)
Events.OnTick.Add(function()
    if not started or finished then return end
    local elapsed = getGameTime():getWorldAgeHours() - started
    if RunConfig.captureName and not captured and elapsed >= math.min(0.01, RunConfig.hours / 2) then
        captured = true
        takeScreenshot(RunConfig.captureName)
        print("[StudyLaunch] native image requested hours=" .. tostring(getGameTime():getWorldAgeHours()))
    end
    if RunConfig.watch or elapsed < RunConfig.hours then return end
    finished = true
    if not RunConfig.observer then playerReceipt("horizon", launchPlayer) end
    print("[StudyLaunch] horizon attempt=" .. RunConfig.attempt .. " save=" .. getWorld():getWorld()
        .. " start=" .. tostring(started) .. " end=" .. tostring(getGameTime():getWorldAgeHours()))
    getCore():quitToDesktop()
end)
