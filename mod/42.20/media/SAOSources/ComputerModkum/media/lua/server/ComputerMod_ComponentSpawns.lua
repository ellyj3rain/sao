require "ComputerMod_Components"
require "ComputerMod_Sandbox"

ComputerModComponentSpawns = ComputerModComponentSpawns or {}

local function eligible(containerType)
    local name = string.lower(tostring(containerType or ""))
    return string.find(name, "desk") or string.find(name, "shelf") or string.find(name, "counter") or string.find(name, "crate") or string.find(name, "cabinet") or string.find(name, "locker") or string.find(name, "metal")
end

local function roomMultiplier(roomType)
    local room = string.lower(tostring(roomType or ""))
    if string.find(room, "elect") or string.find(room, "radio") or string.find(room, "computer") then return 2.0 end
    if string.find(room, "office") or string.find(room, "school") or string.find(room, "storage") or string.find(room, "garage") then return 1.25 end
    if string.find(room, "bedroom") or string.find(room, "living") or string.find(room, "house") then return 0.65 end
    return 0.35
end

local weightedParts = {
    {id = "motherboard", weight = 14},
    {id = "cpu", weight = 18},
    {id = "ram", weight = 28},
    {id = "gpu", weight = 16},
    {id = "hardDrive", weight = 24}
}

function ComputerModComponentSpawns.onFillContainer(roomType, containerType, container)
    if not container or not eligible(containerType) then return end
    local chance = math.floor(ComputerModSandbox.getPercent("ComponentSpawnChance") * roomMultiplier(roomType) + 0.5)
    if chance <= 0 or ZombRand(100) >= math.min(100, chance) then return end
    local total = 0
    for i = 1, #weightedParts do total = total + weightedParts[i].weight end
    local roll = ZombRand(total)
    local cursor = 0
    local selected = weightedParts[1]
    for i = 1, #weightedParts do
        cursor = cursor + weightedParts[i].weight
        if roll < cursor then selected = weightedParts[i]; break end
    end
    local part = ComputerModComponents.getPart(selected.id)
    local item = part and container:AddItem(part.itemType) or nil
    if not item then return end
    local seed = tostring(roomType) .. ":" .. tostring(containerType) .. ":" .. tostring(item.getID and item:getID() or ZombRand(1000000))
    local state = ComputerModComponents.newPartState(part.id, ComputerModComponents.randomCondition(seed, part.id), seed)
    ComputerModComponents.writeStateToItem(item, part.id, state)
end

Events.OnFillContainer.Add(ComputerModComponentSpawns.onFillContainer)
