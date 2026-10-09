-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_ComputerTypes"
require "ComputerMod_Components"

ComputerModStartingHouseServer = ComputerModStartingHouseServer or {}
ComputerModStartingHouseServer.buildings = ComputerModStartingHouseServer.buildings or {}

local function getBuildingId(building)
    if not building or not building.getID then return nil end
    local ok, value = pcall(function() return building:getID() end)
    if not ok or value == nil then return nil end
    return tostring(value)
end

local function markComputer(object)
    local definition = ComputerModComputerTypes.getDefinition(object)
    local data = definition and ComputerModComputerTypes.getData(object) or nil
    if not definition or not data or data.ComputerModNetworkTerminal == true then return end

    data.ComputerModPasswordEnabled = false
    data.ComputerModPassword = nil
    data.ComputerModStickyNoteVisible = false
    data.ComputerModStickyNotePassword = nil
    data.ComputerModNearbyPasswordNoteSpawned = false
    if data.ComputerModMetaInitialized == true then
        data.ComputerModStartingHouseNoPasswordPending = nil
    else
        data.ComputerModStartingHouseNoPasswordPending = true
    end
    ComputerModComponents.captureDriveData(data)
    ComputerModComputerTypes.transmitData(object)
end

local function inspectObjects(objects, seen)
    if not objects or not objects.size or not objects.get then return end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object and not seen[object] then
            seen[object] = true
            markComputer(object)
        end
    end
end

function ComputerModStartingHouseServer.markSquare(square)
    if not square or not square.getBuilding then return end
    local building = square:getBuilding()
    local buildingId = getBuildingId(building)
    if not buildingId or ComputerModStartingHouseServer.buildings[buildingId] ~= true then return end
    local seen = setmetatable({}, {__mode = "k"})
    inspectObjects(square.getObjects and square:getObjects() or nil, seen)
    inspectObjects(square.getSpecialObjects and square:getSpecialObjects() or nil, seen)
    inspectObjects(square.getWorldObjects and square:getWorldObjects() or nil, seen)
end

function ComputerModStartingHouseServer.onNewGame(_playerObj, spawnSquare)
    local square = spawnSquare
    if not square and _playerObj and _playerObj.getSquare then square = _playerObj:getSquare() end
    local building = square and square.getBuilding and square:getBuilding() or nil
    local buildingId = getBuildingId(building)
    if not buildingId or not getCell then return end
    ComputerModStartingHouseServer.buildings[buildingId] = true

    local cell = getCell()
    local originX, originY = square:getX(), square:getY()
    for z = -1, 7 do
        for x = originX - 40, originX + 40 do
            for y = originY - 40, originY + 40 do
                local candidate = cell:getGridSquare(x, y, z)
                local candidateBuilding = candidate and candidate.getBuilding and candidate:getBuilding() or nil
                if candidateBuilding and getBuildingId(candidateBuilding) == buildingId then
                    ComputerModStartingHouseServer.markSquare(candidate)
                end
            end
        end
    end
end

Events.OnNewGame.Add(ComputerModStartingHouseServer.onNewGame)
if Events.LoadGridsquare then
    Events.LoadGridsquare.Add(ComputerModStartingHouseServer.markSquare)
end
