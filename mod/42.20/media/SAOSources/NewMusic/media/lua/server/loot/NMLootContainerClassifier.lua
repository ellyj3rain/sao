NMLootContainerClassifier = NMLootContainerClassifier or {}

local classifier = NMLootContainerClassifier

local function toLower(value)
    return string.lower(tostring(value or ""))
end

local function classifyVehicleContainer(containerType)
    local lower = toLower(containerType)
    if lower == "" then
        return nil
    end
    if string.find(lower, "glove", 1, true) then
        return "vehicle_glovebox"
    end
    if string.find(lower, "seat", 1, true) then
        return "vehicle_seatrear"
    end
    if string.find(lower, "truck", 1, true)
        or string.find(lower, "trunk", 1, true)
        or string.find(lower, "cargo", 1, true)
        or string.find(lower, "roof", 1, true)
    then
        return "vehicle_cargo"
    end
    return "vehicle_cargo"
end

local function isLikelyVehicleContainer(container, containerType)
    local parent = container and container.getParent and container:getParent() or nil
    if parent and (tostring(parent):find("BaseVehicle", 1, true) or tostring(parent):find("Vehicle", 1, true)) then
        return true
    end
    local lower = toLower(containerType)
    return string.find(lower, "glove", 1, true) ~= nil
        or string.find(lower, "seat", 1, true) ~= nil
        or string.find(lower, "truck", 1, true) ~= nil
        or string.find(lower, "trunk", 1, true) ~= nil
        or string.find(lower, "cargo", 1, true) ~= nil
end

function classifier.classifyContainer(roomName, containerType, container)
    local roomLower = toLower(roomName)
    local typeLower = toLower(containerType)

    if isLikelyVehicleContainer(container, containerType) then
        return classifyVehicleContainer(containerType)
    end
    if roomLower == "cdstore"
        or string.find(roomLower, "music", 1, true)
        or string.find(typeLower, "music", 1, true)
    then
        return "music_store"
    end
    if string.find(roomLower, "elect", 1, true) or string.find(typeLower, "elect", 1, true) then
        return "electronics"
    end
    if string.find(roomLower, "mail", 1, true)
        or string.find(roomLower, "post", 1, true)
        or string.find(typeLower, "mail", 1, true)
        or string.find(typeLower, "post", 1, true)
    then
        return "mail"
    end
    if roomLower == "livingroom"
        or roomLower == "bedroom"
        or roomLower == "kitchen"
        or roomLower == "bathroom"
        or roomLower == "garage"
        or roomLower == "diningroom"
        or roomLower == "shed"
        or roomLower == "hall"
        or roomLower == "closet"
        or roomLower == "utilityroom"
    then
        return "residential_misc"
    end
    return "other"
end

return classifier
