-- Production SAO_Standing.lua is loaded between this host and fixtureCases.
local standingStore = {}
SAO = {
    Log = {line = function() end},
    Identity = {idByName = function() return nil end},
}
ModData = {
    getOrCreate = function() return standingStore end,
    get = function() return standingStore end,
}
local worldName, modeName = "Owned World", "Sandbox"
function getWorld()
    return {
        getWorld = function() return worldName end,
        getGameMode = function() return modeName end,
    }
end
local slots = {}
function getSpecificPlayer(slot) return slots[slot] end
local onlineBodies = {}
function getOnlinePlayers()
    return {
        size = function() return #onlineBodies end,
        get = function(_, index) return onlineBodies[index + 1] end,
    }
end
local function body(username, descriptorId, forename, surname)
    local modData = {}
    local descriptor = {
        getID = function() return descriptorId end,
        getForename = function() return forename end,
        getSurname = function() return surname end,
    }
    return {
        getUsername = function() return username end,
        getModData = function() return modData end,
        getDescriptor = function() return descriptor end,
    }, modData
end
local checks, failed = 0, {}
local function check(name, value)
    checks = checks + 1
    if value then print("PASS " .. name) else
        failed[#failed + 1] = name
        print("FAIL " .. name)
    end
end
function fixtureCases()
    local S = SAO.Standing
    local first, firstData = body("operator", 17, "Ava", "Parker")
    local second, secondData = body("operator", 18, "Maya", "Parker")
    slots[0] = first
    check("legacy/account-key-preserved",
        S.playerKey(first) == "player:operator")
    local firstModData = first.getModData
    first.getModData = function() error("native mod data unavailable") end
    check("legacy/failed-moddata-refused", S.playerKey(first) == nil)
    first.getModData = firstModData
    local firstKey = S.characterKey(first, "sao-player-1")
    local secondKey = S.characterKey(second, "sao-player-2")
    check("creator/distinct-character-keys",
        firstKey ~= secondKey and S.isPlayerKey(firstKey)
            and S.isPlayerKey(secondKey))
    check("creator/invalid-id-refused",
        S.characterKey(first, "sao-player-x") == nil)
    local function receipt(key, id, descriptorId, forename, surname)
        return {
            schema = "sao-created-player/1",
            accountKey = "player:operator", playerKey = key,
            characterId = id, world = worldName, gameMode = modeName,
            nativeDescriptorId = descriptorId,
            forename = forename, surname = surname,
        }
    end
    firstData.SAOCreationReceipt =
        receipt(firstKey, "sao-player-1", 17, "Ava", "Parker")
    secondData.SAOCreationReceipt =
        receipt(secondKey, "sao-player-2", 18, "Maya", "Parker")
    check("creator/first-native-key", S.playerKey(first) == firstKey)
    local firstDescriptor = first.getDescriptor
    firstData.SAOCreationReceipt.nativeDescriptorId = nil
    first.getDescriptor = function()
        return {getID=function() return nil end,
            getForename=function() return "Ava" end,
            getSurname=function() return "Parker" end}
    end
    check("creator/missing-native-descriptor-refused",
        S.playerKey(first) == nil)
    first.getDescriptor = firstDescriptor
    firstData.SAOCreationReceipt.nativeDescriptorId = 17
    check("creator/second-native-key", S.playerKey(second) == secondKey)
    check("standing/character-groups-isolated",
        S.joinGroup(firstKey, "North") and S.joinGroup(secondKey, "South")
            and S.groupOf(firstKey) == "North"
            and S.groupOf(secondKey) == "South")
    check("standing/observed-active-character",
        S.keyForObserved("operator") == firstKey)
    check("standing/attacker-active-character",
        S.keyForAttackerTag("player", "operator") == firstKey)
    slots[0] = second
    check("standing/switch-character-uses-own-history",
        S.keyForObserved("operator") == secondKey
            and S.groupOf(S.playerKey(second)) == "South")
    local remote, remoteData = body("remote", 41, "Reed", "Miller")
    local remoteKey = S.characterKey(remote, "sao-player-3")
    remoteData.SAOCreationReceipt = {
        schema = "sao-created-player/1",
        accountKey = "player:remote", playerKey = remoteKey,
        characterId = "sao-player-3", world = worldName,
        gameMode = modeName, nativeDescriptorId = 41,
        forename = "Reed", surname = "Miller",
    }
    onlineBodies[1] = remote
    check("standing/observed-online-character",
        S.keyForObserved("remote") == remoteKey
            and S.keyForAttackerTag("player", "remote") == remoteKey)
    onlineBodies[1] = nil
    slots[0] = first
    firstData.SAOCreationReceipt.accountKey = "player:other"
    check("creator/foreign-account-receipt-refused",
        S.playerKey(first) == nil and S.keyForObserved("operator") == nil)
    firstData.SAOCreationReceipt.accountKey = "player:operator"
    firstData.SAOCreationReceipt.nativeDescriptorId = 18
    check("creator/stale-body-receipt-refused",
        S.playerKey(first) == nil)
    firstData.SAOCreationReceipt.nativeDescriptorId = 17
    worldName = "Different World"
    check("creator/stale-world-receipt-refused",
        S.playerKey(first) == nil)
    worldName = "Owned World"
    check("creator/reload-stable-character-key",
        S.playerKey(first) == firstKey
            and S.groupOf(S.playerKey(first)) == "North")
    firstData.SAOCreationReceipt = nil
    check("legacy/receiptless-reload-stable",
        S.playerKey(first) == "player:operator")
    check("standing/foreign-domain-preserved",
        S.keyForObserved("~other") == "foreign:other")
    check("standing/source-runs-without-failure", #failed == 0)
    return tostring(checks) .. ":" .. table.concat(failed, ",")
end
