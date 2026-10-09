-- Shared source-matrix probe for BaseVehicle resolution across multiple runtime pools.
NMVehicleSourceMatrix = NMVehicleSourceMatrix or {}

local function safeCall(fn)
    if type(pcall) ~= "function" then
        return false, nil
    end
    return pcall(fn)
end

local function readVehicleId(vehicle)
    if not vehicle then
        return ""
    end
    local ok, id = safeCall(function()
        return vehicle.getId and vehicle:getId() or nil
    end)
    if not ok then
        return ""
    end
    return tostring(id or "")
end

local function summarizeSource(source, idx)
    local label = tostring(source and source.sourceLabel or "unknown")
    local size = tonumber(source and source.sizeReported or 0) or 0
    local nonNil = tonumber(source and source.nonNilCount or 0) or 0
    local mode = tostring(source and source.readModeUsed or "none")
    local errors = tonumber(source and source.errors or 0) or 0
    return string.format("src%d=%s:%d/%d/%s/e%d", idx, label, size, nonNil, mode, errors)
end

local function addSingletonSource(sources, sourceLabel, vehicle)
    local available = vehicle ~= nil
    local firstIds = {}
    if available then
        local vid = readVehicleId(vehicle)
        if vid ~= "" then
            firstIds[1] = vid
        end
    end
    sources[#sources + 1] = {
        sourceLabel = tostring(sourceLabel),
        available = available,
        sizeReported = available and 1 or 0,
        nonNilCount = available and 1 or 0,
        firstIds = firstIds,
        errors = 0,
        readModeUsed = "singleton",
        vehicle = vehicle,
        probe = nil
    }
end

local function addListSource(sources, sourceLabel, vehiclesObj, maxScan)
    if not vehiclesObj then
        sources[#sources + 1] = {
            sourceLabel = tostring(sourceLabel),
            available = false,
            sizeReported = 0,
            nonNilCount = 0,
            firstIds = {},
            errors = 0,
            readModeUsed = "none",
            vehicle = nil,
            probe = nil
        }
        return
    end
    local probe = NMVehiclePoolAccessor.collect(maxScan, { vehicles = vehiclesObj })
    local firstIds = {}
    local sample = probe and probe.sampleIds or {}
    for i = 1, math.min(3, #sample) do
        firstIds[#firstIds + 1] = tostring(sample[i] or "")
    end
    sources[#sources + 1] = {
        sourceLabel = tostring(sourceLabel),
        available = true,
        sizeReported = tonumber(probe and probe.totalReported or 0) or 0,
        nonNilCount = tonumber(probe and probe.nonNilVehicles or 0) or 0,
        firstIds = firstIds,
        errors = tonumber(probe and probe.getErrors or 0) or 0,
        readModeUsed = tostring(probe and probe.indexBaseUsed or "none"),
        vehicle = nil,
        probe = probe
    }
end

local function getCellVehicles()
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end
    local ok, vehicles = safeCall(function()
        return cell:getVehicles()
    end)
    if ok then
        return vehicles
    end
    return nil
end

local function getWorldCellVehicles()
    local world = getWorld and getWorld() or nil
    if not world then
        return nil
    end
    local okCell, worldCell = safeCall(function()
        return world:getCell()
    end)
    if not okCell or not worldCell then
        return nil
    end
    local okVehicles, vehicles = safeCall(function()
        return worldCell:getVehicles()
    end)
    if okVehicles then
        return vehicles
    end
    return nil
end

function NMVehicleSourceMatrix.collect(opts)
    opts = opts or {}
    local maxScan = math.max(1, tonumber(opts.maxScan) or 200)
    local sources = {}

    addSingletonSource(sources, "cached_id", opts.cachedVehicle)
    addSingletonSource(sources, "owner_vehicle", opts.ownerVehicle)
    addSingletonSource(sources, "authority_hint_id", opts.authorityVehicle)

    local cellVehicles = getCellVehicles()
    addListSource(sources, "cell.getVehicles", cellVehicles, maxScan)

    local worldVehicles = getWorldCellVehicles()
    local sameAsCell = (cellVehicles ~= nil and worldVehicles ~= nil and cellVehicles == worldVehicles)
    if sameAsCell then
        sources[#sources + 1] = {
            sourceLabel = "world.cell.getVehicles",
            available = true,
            sizeReported = 0,
            nonNilCount = 0,
            firstIds = {},
            errors = 0,
            readModeUsed = "same_as_cell",
            vehicle = nil,
            probe = nil
        }
    else
        addListSource(sources, "world.cell.getVehicles", worldVehicles, maxScan)
    end

    local summary = {}
    for i = 1, #sources do
        summary[#summary + 1] = summarizeSource(sources[i], i - 1)
    end

    return {
        sources = sources,
        summary = table.concat(summary, " "),
        selectedListSource = NMVehicleSourceMatrix.selectListSource(sources)
    }
end

function NMVehicleSourceMatrix.selectListSource(sources)
    for i = 1, #sources do
        local src = sources[i]
        if src and src.probe and (tonumber(src.nonNilCount) or 0) > 0 then
            return src
        end
    end
    return nil
end

