-- Real SAO_Nuke.lua loads between this prelude and the case function.
local state = {}
SAO = {
    Log = { line = function() end },
    History = { countyHours = function() return 0 end },
    Standing = {
        fallHasCome = function() return true end,
        chronicle = function() return {} end,
    },
    Rand = { int = function(low, _) return low end },
}
SandboxVars = {
    SurvivorAwareness = { WeekOneNuke = true },
    BanditsWeekOne = { EventFinalSolution = true },
}
BWOScheduler = {}
ModData = { getOrCreate = function() return state end }
Events = { LoadGridsquare = { Add = function() end } }
function getSpecificPlayer(_) return nil end
function getWorld()
    return { getWorld = function() return "Selected World" end,
        getGameMode = function() return "Sandbox" end }
end
checkCount, failureCount = 0, 0
local failed = {}
local function check(name, condition)
    checkCount = checkCount + 1
    if condition then print("PASS " .. name)
    else
        failureCount = failureCount + 1
        failed[#failed + 1] = name
        print("FAIL " .. name)
    end
end
function fixtureCases()
    SandboxVars.SurvivorAwareness.WeekOneNuke = false
    SandboxVars.BanditsWeekOne.EventFinalSolution = false
    check("default-off/no-premature-weekone-owner",
        SAO.Nuke.effectiveProducer() == nil and state.producer == nil
            and SAO.Nuke.onDay() == false and state.drawn == nil)
    SandboxVars.SurvivorAwareness.WeekOneNuke = true
    SandboxVars.BanditsWeekOne.EventFinalSolution = true
    check("weekone-priority/selected-on-first-day",
        SAO.Nuke.onDay() == false and state.producer == "BanditsWeekOne"
            and state.drawn == nil)
    SandboxVars.BanditsWeekOne.EventFinalSolution = false
    check("world-lock/no-late-second-producer",
        SAO.Nuke.onDay() == false
            and SAO.Nuke.effectiveProducer() == "BanditsWeekOne"
            and state.drawn == nil)

    state = {}
    check("sao-dial/selected-when-weekone-off",
        SAO.Nuke.onDay() == true and state.producer == "SAO"
            and state.drawn == true and state.struck ~= true)
    SandboxVars.BanditsWeekOne.EventFinalSolution = true
    check("world-lock/sao-kept-after-weekone-toggle",
        SAO.Nuke.effectiveProducer() == "SAO"
            and SAO.Nuke.onDay() == true)

    state = { drawn = true, strikeAtHours = 500, circles = {} }
    check("legacy-save/drawn-sao-owner",
        SAO.Nuke.effectiveProducer() == "SAO"
            and SAO.Nuke.onDay() == true)

    state = {}
    SandboxVars.SurvivorAwareness.WeekOneNuke = false
    SandboxVars.BanditsWeekOne.EventFinalSolution = false
    check("both-off/no-strike-owner",
        SAO.Nuke.onDay() == false
            and SAO.Nuke.effectiveProducer() == nil
            and state.drawn == nil)
    local receipt = { schema = "sao-created-player/1", newWorld = true,
        decisionId = "Selected World|Sandbox|1", world = "Selected World",
        gameMode = "Sandbox", characterId = "sao-player-1",
        playerKey = "player:1", appliedAtHours = 0,
        nativeDescriptorId = 7, nukeChoice = "none" }
    state = {}
    check("creator/explicit-none-applied",
        SAO.Nuke.applyCreatorChoice("none", receipt) == true
            and state.producer == "none"
            and state.creatorChoice.decisionId == receipt.decisionId)
    SandboxVars.BanditsWeekOne.EventFinalSolution = true
    check("creator/none-survives-source-toggle",
        SAO.Nuke.effectiveProducer() == "none"
            and SAO.Nuke.onDay() == false and state.drawn == nil)
    check("creator/exact-replay-idempotent",
        SAO.Nuke.applyCreatorChoice("none", receipt) == true)
    local foreignDescriptor = {}
    for key, value in pairs(receipt) do foreignDescriptor[key] = value end
    foreignDescriptor.nativeDescriptorId = receipt.nativeDescriptorId + 1
    local originalChoice = state.creatorChoice
    check("creator/seeded-foreign-native-descriptor-refused",
        SAO.Nuke.applyCreatorChoice("none", foreignDescriptor) == false
            and state.creatorChoice == originalChoice
            and state.creatorChoice.nativeDescriptorId == receipt.nativeDescriptorId
            and state.producer == "none")
    local conflict = { schema = receipt.schema, newWorld = true,
        decisionId = "Selected World|Sandbox|2", world = receipt.world,
        gameMode = receipt.gameMode, characterId = "sao-player-2",
        playerKey = receipt.playerKey, appliedAtHours = 0,
        nativeDescriptorId = 7,
        nukeChoice = "SAO" }
    check("creator/conflicting-choice-refused",
        SAO.Nuke.applyCreatorChoice("SAO", conflict) == false
            and state.producer == "none")
    state = {}
    local foreign = { schema = receipt.schema, newWorld = false,
        decisionId = receipt.decisionId, world = receipt.world,
        gameMode = receipt.gameMode, characterId = receipt.characterId,
        playerKey = receipt.playerKey, appliedAtHours = 0,
        nativeDescriptorId = 7,
        nukeChoice = "none" }
    check("creator/foreign-receipt-refused",
        SAO.Nuke.applyCreatorChoice("none", foreign) == false
            and state.producer == nil)
    local unidentified = { schema = receipt.schema, newWorld = true,
        decisionId = receipt.decisionId, world = receipt.world,
        gameMode = receipt.gameMode, characterId = receipt.characterId,
        playerKey = receipt.playerKey, appliedAtHours = 0,
        nukeChoice = "none" }
    check("creator/missing-native-descriptor-refused",
        SAO.Nuke.applyCreatorChoice("none", unidentified) == false
            and state.producer == nil)
    state = { producer = "BanditsWeekOne" }
    check("legacy/creator-cannot-override-world",
        SAO.Nuke.applyCreatorChoice("none", receipt) == false
            and state.producer == "BanditsWeekOne")
    state = {}
    receipt.nukeChoice = "SAO"
    SandboxVars.BanditsWeekOne.EventFinalSolution = false
    SandboxVars.SurvivorAwareness.WeekOneNuke = true
    check("creator/explicit-sao-applied",
        SAO.Nuke.applyCreatorChoice("SAO", receipt) == true
            and state.producer == "SAO" and SAO.Nuke.onDay() == true)
    state = {}
    check("creator/pre-native-selector-recorded",
        SAO.Nuke.effectiveProducer() == "SAO"
            and state.producer == "SAO"
            and state.creatorChoice == nil)
    check("creator/pre-native-selector-admits-same-choice",
        SAO.Nuke.applyCreatorChoice("SAO", receipt) == true
            and state.creatorChoice.decisionId == receipt.decisionId)
    state = { producer = "SAO", drawn = true }
    check("creator/drawn-fate-still-refused",
        SAO.Nuke.applyCreatorChoice("SAO", receipt) == false
            and state.creatorChoice == nil)
    check("nuke/source-runs-without-failure", failureCount == 0)
    return tostring(checkCount) .. ":" .. table.concat(failed, ",")
end
