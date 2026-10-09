-- Shared vehicle pool accessor for Java-backed collections exposed to Lua.
NMVehiclePoolAccessor = NMVehiclePoolAccessor or {}
local _pcall = pcall

local function safePcall(fn)
    if type(_pcall) ~= "function" then
        return false, nil
    end
    return _pcall(fn)
end

local function getMember(target, key)
    local ok, value = safePcall(function()
        return target and target[key] or nil
    end)
    if not ok then
        return nil
    end
    return value
end

local function clampCount(value)
    local n = tonumber(value)
    if not n then
        return 0
    end
    return math.max(0, math.floor(n))
end

local function readVehiclesFromContext(opts)
    opts = opts or {}
    if opts.vehicles then
        return opts.vehicles, "opts.vehicles"
    end
    local cell = opts.cell or (getCell and getCell() or nil)
    if not cell then
        return nil, "no_cell"
    end
    local vehicles = nil
    local ok, value = safePcall(function()
        return cell:getVehicles()
    end)
    if ok then
        vehicles = value
    elseif cell.getVehicles then
        local okDot, dotValue = safePcall(function()
            return cell.getVehicles(cell)
        end)
        if okDot then
            vehicles = dotValue
        end
    end
    if not vehicles then
        return nil, "cell_no_vehicles"
    end
    return vehicles, "cell.getVehicles"
end

local function readSize(vehicles, probe)
    local sizeMember = getMember(vehicles, "size")
    if type(sizeMember) == "function" then
        local okDot, countDot = safePcall(function()
            return vehicles:size()
        end)
        if okDot and tonumber(countDot) then
            return clampCount(countDot), "size_colon"
        end
        probe.getErrors = probe.getErrors + (okDot and 0 or 1)

        local okDotFn, countDotFn = safePcall(function()
            return vehicles.size(vehicles)
        end)
        if okDotFn and tonumber(countDotFn) then
            return clampCount(countDotFn), "size_dot_fn"
        end
        probe.getErrors = probe.getErrors + (okDotFn and 0 or 1)
    end

    if type(vehicles) == "table" then
        return clampCount(#vehicles), "size_table_len_fallback"
    end

    return 0, "size_unavailable"
end

local function readAt(vehicles, idx, modeName, probe)
    local getMemberFn = getMember(vehicles, "get")
    if type(getMemberFn) == "function" then
        local okColon, valColon = safePcall(function()
            return vehicles:get(idx)
        end)
        if okColon and valColon ~= nil then
            return valColon, "get_colon"
        end
        probe.getErrors = probe.getErrors + (okColon and 0 or 1)

        local okDot, valDot = safePcall(function()
            return vehicles.get(vehicles, idx)
        end)
        if okDot and valDot ~= nil then
            return valDot, "get_dot_fn"
        end
        probe.getErrors = probe.getErrors + (okDot and 0 or 1)
    end

    local fallbackPrimary = idx
    local fallbackSecondary = idx + 1
    if modeName == "0" then
        fallbackPrimary = idx + 1
        fallbackSecondary = idx
    end
    local okIdxA, valIdxA = safePcall(function()
        return vehicles[fallbackPrimary]
    end)
    if okIdxA and valIdxA ~= nil then
        return valIdxA, "index_primary_fallback"
    end
    probe.getErrors = probe.getErrors + (okIdxA and 0 or 1)

    local okIdxB, valIdxB = safePcall(function()
        return vehicles[fallbackSecondary]
    end)
    if okIdxB and valIdxB ~= nil then
        return valIdxB, "index_secondary_fallback"
    end
    probe.getErrors = probe.getErrors + (okIdxB and 0 or 1)

    return nil, "nil"
end

function NMVehiclePoolAccessor.collect(maxScan, opts)
    local probe = {
        poolSource = "none",
        totalReported = 0,
        iteratedSlots = 0,
        nonNilVehicles = 0,
        nilSlots = 0,
        sampleIds = {},
        getErrors = 0,
        indexBaseTried = "none",
        indexBaseUsed = "none",
        _vehicles = {}
    }

    local vehicles, source = readVehiclesFromContext(opts)
    if not vehicles then
        probe.poolSource = source or "none"
        return probe
    end

    local count, sizePath = readSize(vehicles, probe)
    probe.poolSource = tostring(source or "vehicles") .. ":" .. tostring(sizePath or "unknown")
    probe.totalReported = count
    if count < 1 then
        return probe
    end

    local scanCap = math.max(1, math.min(count, clampCount(maxScan or count)))
    local modes = {
        { name = "0", startAt = 0, endAt = scanCap - 1 },
        { name = "1", startAt = 1, endAt = scanCap }
    }

    local bestCount = -1
    local bestNil = scanCap
    local bestVehicles = {}
    local tried = {}

    for i = 1, #modes do
        local mode = modes[i]
        tried[#tried + 1] = mode.name
        local modeVehicles = {}
        local modeNonNil = 0
        local modeNil = 0
        for idx = mode.startAt, mode.endAt do
            probe.iteratedSlots = probe.iteratedSlots + 1
            local vehicle = nil
            local from = "nil"
            vehicle, from = readAt(vehicles, idx, mode.name, probe)
            if vehicle then
                modeNonNil = modeNonNil + 1
                modeVehicles[#modeVehicles + 1] = vehicle
                if #probe.sampleIds < 6 then
                    local vid = tostring(vehicle.getId and vehicle:getId() or "nil")
                    probe.sampleIds[#probe.sampleIds + 1] = vid .. "@" .. tostring(from)
                end
            else
                modeNil = modeNil + 1
            end
        end
        if modeNonNil > bestCount then
            bestCount = modeNonNil
            bestNil = modeNil
            bestVehicles = modeVehicles
            probe.indexBaseUsed = mode.name
        end
    end

    probe.indexBaseTried = table.concat(tried, ",")
    probe.nonNilVehicles = math.max(0, bestCount)
    probe.nilSlots = math.max(0, bestNil)
    probe._vehicles = bestVehicles
    return probe
end

function NMVehiclePoolAccessor.scanUuid(uuid, partId, probe, collectAllMatches)
    local info = {
        matched = 0,
        matchedIds = {},
        partMissing = 0,
        partUuidMissing = 0,
        uuidCompared = 0,
        vehicle = nil,
        part = nil
    }
    local vehicles = probe and probe._vehicles or {}
    local wanted = tostring(uuid or "")
    local desiredPartId = tostring(partId or "Radio")
    local stateKey = tostring(NMCore and NMCore.StateKey or "nm_device_state")

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle then
            local part = vehicle.getPartById and vehicle:getPartById(desiredPartId) or nil
            if not part then
                info.partMissing = info.partMissing + 1
            else
                local md = part.getModData and part:getModData() or nil
                local node = md and md[stateKey] or nil
                local partUuid = tostring(node and node.deviceUUID or "")
                if partUuid == "" then
                    info.partUuidMissing = info.partUuidMissing + 1
                else
                    info.uuidCompared = info.uuidCompared + 1
                    if wanted ~= "" and partUuid == wanted then
                        local vid = tostring(vehicle.getId and vehicle:getId() or "")
                        info.matched = info.matched + 1
                        info.matchedIds[#info.matchedIds + 1] = vid
                        if not info.vehicle then
                            info.vehicle = vehicle
                            info.part = part
                            if not collectAllMatches then
                                return info
                            end
                        end
                    end
                end
            end
        end
    end
    return info
end

