ComputerModCDSpawns = ComputerModCDSpawns or {}

require "ComputerMod_Sandbox"

local function lowerText(value)
    if not value then return "" end
    return string.lower(tostring(value))
end

local function isEligibleContainer(containerType)
    local name = lowerText(containerType)
    return string.find(name, "desk") or string.find(name, "shelf") or string.find(name, "counter") or string.find(name, "crate") or string.find(name, "cabinet") or string.find(name, "dresser") or string.find(name, "sidetable") or string.find(name, "locker")
end

local function addRandomDisc(container, entries)
    if not container or not entries or #entries == 0 then return end
    if ZombRand(100) >= ComputerModSandbox.getPercent("DiscSpawnChance") then return end
    local total = 0
    for i = 1, #entries do
        total = total + entries[i].weight
    end
    local roll = ZombRand(total)
    local cursor = 0
    for i = 1, #entries do
        cursor = cursor + entries[i].weight
        if roll < cursor then
            container:AddItem(entries[i].item)
            return
        end
    end
end

local function getCategoryWeightPercent(category)
    if category == "system" then
        return ComputerModSandbox.getPercent("SystemDiscWeightPercent")
    end
    if category == "blank" then
        return ComputerModSandbox.getPercent("BlankDiscWeightPercent")
    end
    if category == "hack" then
        return ComputerModSandbox.getPercent("HackDiscWeightPercent")
    end
    return ComputerModSandbox.getPercent("GameDiscWeightPercent")
end

local function makeEntry(item, weight, category)
    local scaled = math.floor((weight * getCategoryWeightPercent(category)) / 100 + 0.5)
    if scaled <= 0 then return nil end
    return {item = item, weight = scaled}
end

local function buildEntries(definitions)
    local entries = {}
    for i = 1, #definitions do
        local entry = makeEntry(definitions[i].item, definitions[i].weight, definitions[i].category)
        if entry then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

function ComputerModCDSpawns.onFillContainer(roomType, containerType, container)
    if not isEligibleContainer(containerType) then return end

    local room = lowerText(roomType)
    local entries = nil

    if string.find(room, "class") or string.find(room, "school") or string.find(room, "library") then
        entries = buildEntries({
            {item = "ComputerMod.BlankCD", weight = 16, category = "blank"},
            {item = "ComputerMod.SystemCDPZOS", weight = 10, category = "system"},
            {item = "ComputerMod.GameCDMinesweeper", weight = 35, category = "game"},
            {item = "ComputerMod.GameCDSnake", weight = 28, category = "game"},
            {item = "ComputerMod.GameCDPong", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDTetris", weight = 19, category = "game"},
            {item = "ComputerMod.GameCDFlappy", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDBreakout", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDFrogger", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDMissile", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDLander", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDCircuit", weight = 13, category = "game"},
            {item = "ComputerMod.GameCDMemory", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDStarPilot", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDCaveRunner", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDLightsOut", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDSignalMatch", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDBoxPush", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDTileSlide", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDPipeLink", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDCodeBreaker", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDOutbreakOps", weight = 8, category = "game"},
            {item = "ComputerMod.PasswordHackCD", weight = 1, category = "hack"}
        })
    elseif string.find(room, "police") or string.find(room, "security") or string.find(room, "jail") then
        entries = buildEntries({
            {item = "ComputerMod.BlankCD", weight = 10, category = "blank"},
            {item = "ComputerMod.SystemCDPZOS", weight = 8, category = "system"},
            {item = "ComputerMod.GameCDDoom", weight = 34, category = "game"},
            {item = "ComputerMod.GameCDTetris", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDMinesweeper", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDSpaceInvaders", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDRacer", weight = 6, category = "game"},
            {item = "ComputerMod.GameCDFlappy", weight = 8, category = "game"},
            {item = "ComputerMod.GameCDAsteroids", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDMissile", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDLander", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDCircuit", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDMemory", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDStarPilot", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDCaveRunner", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDLightsOut", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDSignalMatch", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDBoxPush", weight = 8, category = "game"},
            {item = "ComputerMod.GameCDTileSlide", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDPipeLink", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDCodeBreaker", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDOutbreakOps", weight = 24, category = "game"},
            {item = "ComputerMod.PasswordHackCD", weight = 5, category = "hack"}
        })
    elseif string.find(room, "office") or string.find(room, "meeting") then
        entries = buildEntries({
            {item = "ComputerMod.BlankCD", weight = 18, category = "blank"},
            {item = "ComputerMod.SystemCDPZOS", weight = 14, category = "system"},
            {item = "ComputerMod.GameCDPong", weight = 26, category = "game"},
            {item = "ComputerMod.GameCDSnake", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDMinesweeper", weight = 28, category = "game"},
            {item = "ComputerMod.GameCDTetris", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDRacer", weight = 4, category = "game"},
            {item = "ComputerMod.GameCDFlappy", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDBreakout", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDMissile", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDLander", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDCircuit", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDMemory", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDStarPilot", weight = 8, category = "game"},
            {item = "ComputerMod.GameCDCaveRunner", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDLightsOut", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDSignalMatch", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDBoxPush", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDTileSlide", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDPipeLink", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDCodeBreaker", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDOutbreakOps", weight = 18, category = "game"},
            {item = "ComputerMod.PasswordHackCD", weight = 3, category = "hack"}
        })
    elseif string.find(room, "store") or string.find(room, "market") or string.find(room, "elect") or string.find(room, "garage") then
        entries = buildEntries({
            {item = "ComputerMod.BlankCD", weight = 14, category = "blank"},
            {item = "ComputerMod.SystemCDPZOS", weight = 10, category = "system"},
            {item = "ComputerMod.GameCDSpaceInvaders", weight = 25, category = "game"},
            {item = "ComputerMod.GameCDPong", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDTetris", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDDoom", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDRacer", weight = 25, category = "game"},
            {item = "ComputerMod.GameCDFlappy", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDAsteroids", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDFrogger", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDMissile", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDLander", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDCircuit", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDMemory", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDStarPilot", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDCaveRunner", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDLightsOut", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDSignalMatch", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDBoxPush", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDTileSlide", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDPipeLink", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDCodeBreaker", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDOutbreakOps", weight = 20, category = "game"},
            {item = "ComputerMod.PasswordHackCD", weight = 2, category = "hack"}
        })
    elseif string.find(room, "bedroom") or string.find(room, "living") or string.find(room, "house") then
        entries = buildEntries({
            {item = "ComputerMod.BlankCD", weight = 20, category = "blank"},
            {item = "ComputerMod.SystemCDPZOS", weight = 10, category = "system"},
            {item = "ComputerMod.GameCDSnake", weight = 27, category = "game"},
            {item = "ComputerMod.GameCDMinesweeper", weight = 27, category = "game"},
            {item = "ComputerMod.GameCDPong", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDSpaceInvaders", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDRacer", weight = 16, category = "game"},
            {item = "ComputerMod.GameCDFlappy", weight = 22, category = "game"},
            {item = "ComputerMod.GameCDFrogger", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDBreakout", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDMissile", weight = 10, category = "game"},
            {item = "ComputerMod.GameCDLander", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDCircuit", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDMemory", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDStarPilot", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDCaveRunner", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDLightsOut", weight = 20, category = "game"},
            {item = "ComputerMod.GameCDSignalMatch", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDBoxPush", weight = 18, category = "game"},
            {item = "ComputerMod.GameCDTileSlide", weight = 24, category = "game"},
            {item = "ComputerMod.GameCDPipeLink", weight = 14, category = "game"},
            {item = "ComputerMod.GameCDCodeBreaker", weight = 12, category = "game"},
            {item = "ComputerMod.GameCDOutbreakOps", weight = 10, category = "game"},
            {item = "ComputerMod.PasswordHackCD", weight = 1, category = "hack"}
        })
    end

    if entries and #entries > 0 then
        addRandomDisc(container, entries)
    end
end

Events.OnFillContainer.Add(ComputerModCDSpawns.onFillContainer)
