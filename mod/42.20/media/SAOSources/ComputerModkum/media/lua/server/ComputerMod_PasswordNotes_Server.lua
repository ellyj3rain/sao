require "ComputerMod_PasswordNotes"

ComputerModPasswordNotesServer = ComputerModPasswordNotesServer or {}

local function lowerText(value)
    return value and string.lower(tostring(value)) or ""
end

local function isEligibleContainer(containerType)
    local name = lowerText(containerType)
    return string.find(name, "desk")
        or string.find(name, "shelf")
        or string.find(name, "counter")
        or string.find(name, "crate")
        or string.find(name, "cabinet")
        or string.find(name, "dresser")
        or string.find(name, "sidetable")
        or string.find(name, "locker")
        or string.find(name, "filing")
        or string.find(name, "wardrobe")
end

local function getContainerSquare(container)
    if not container then return nil end
    if container.getSourceGrid then
        local ok, square = pcall(function() return container:getSourceGrid() end)
        if ok and square then return square end
    end
    if container.getParent then
        local okParent, parent = pcall(function() return container:getParent() end)
        if okParent and parent and parent.getSquare then
            local okSquare, square = pcall(function() return parent:getSquare() end)
            if okSquare then return square end
        end
    end
    return nil
end

local function findNearbyComputer(sourceSquare)
    if not sourceSquare or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local x = sourceSquare:getX()
    local y = sourceSquare:getY()
    local z = sourceSquare:getZ()
    local best = nil
    local bestDistance = nil
    local function inspectObjects(objects, dx, dy)
        if not objects then return end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if ComputerModPasswordNotes.isComputerObject(object) then
                local data = object.getModData and object:getModData() or nil
                if data and data.ComputerModNetworkTerminal ~= true and data.ComputerModNearbyPasswordNoteInitialized ~= true then
                    local distance = dx * dx + dy * dy
                    if not bestDistance or distance < bestDistance then
                        best = object
                        bestDistance = distance
                    end
                end
            end
        end
    end
    for dx = -4, 4 do
        for dy = -4, 4 do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            if square then
                inspectObjects(square.getObjects and square:getObjects() or nil, dx, dy)
                inspectObjects(square.getSpecialObjects and square:getSpecialObjects() or nil, dx, dy)
            end
        end
    end
    return best
end

local function transmitComputerData(computer)
    if computer and computer.transmitModData then
        pcall(function() computer:transmitModData() end)
    end
end

function ComputerModPasswordNotesServer.onFillContainer(roomType, containerType, container)
    if ComputerModSandbox.getPercent("NearbyPasswordNoteChance") <= 0 then return end
    if not isEligibleContainer(containerType) then return end
    local computer = findNearbyComputer(getContainerSquare(container))
    if not computer or not computer.getModData then return end
    local data = computer:getModData()
    data.ComputerModNearbyPasswordNoteInitialized = true
    local password = ComputerModPasswordNotes.ensureComputerPassword(computer)
    if not password or password == "" then
        data.ComputerModNearbyPasswordNoteSpawned = false
        transmitComputerData(computer)
        return
    end
    if ZombRand(100) >= ComputerModSandbox.getPercent("NearbyPasswordNoteChance") then
        data.ComputerModNearbyPasswordNoteSpawned = false
        transmitComputerData(computer)
        return
    end
    local ok, item = pcall(function() return container:AddItem("ComputerMod.PasswordNote") end)
    if not ok or not item then
        data.ComputerModNearbyPasswordNoteSpawned = false
        transmitComputerData(computer)
        return
    end
    if item.setName then
        pcall(function() item:setName("PASS: " .. tostring(password)) end)
    end
    if item.setCustomName then
        pcall(function() item:setCustomName(true) end)
    end
    if item.getModData then
        local itemData = item:getModData()
        itemData.ComputerModPasswordNoteText = tostring(password)
        itemData.ComputerModPasswordNoteMachineID = tostring(data.ComputerModMachineID or "")
        itemData.ComputerModPasswordNoteX = computer.getX and computer:getX() or nil
        itemData.ComputerModPasswordNoteY = computer.getY and computer:getY() or nil
        itemData.ComputerModPasswordNoteZ = computer.getZ and computer:getZ() or nil
    end
    data.ComputerModNearbyPasswordNoteSpawned = true
    transmitComputerData(computer)
end

Events.OnFillContainer.Add(ComputerModPasswordNotesServer.onFillContainer)
