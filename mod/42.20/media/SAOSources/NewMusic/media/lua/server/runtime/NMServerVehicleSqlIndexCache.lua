-- Refresh and diagnose the server vehicle SQL id to runtime id cache.
NMServerVehicleSqlIndexCache = NMServerVehicleSqlIndexCache or {}

local ATTEMPT_PRIORITY = {
    iterator = 1,
    to_array = 2
}

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function safeCall(fn)
    if type(pcall) ~= "function" then
        return false, nil
    end
    return pcall(fn)
end

local function readVehiclesSize(vehicles)
    if not vehicles then
        return 0
    end
    local okA, countA = safeCall(function()
        return vehicles.size and vehicles:size() or nil
    end)
    if okA and tonumber(countA) then
        return math.max(0, math.floor(tonumber(countA) or 0))
    end
    local okB, countB = safeCall(function()
        return vehicles.size and vehicles.size(vehicles) or nil
    end)
    if okB and tonumber(countB) then
        return math.max(0, math.floor(tonumber(countB) or 0))
    end
    return 0
end

local function readVehiclesAtMode(vehicles, idx, mode)
    if mode == "raw_index" then
        return safeCall(function()
            return vehicles[idx]
        end)
    end
    return false, nil
end

local function readClassName(obj)
    if not obj then
        return "nil"
    end
    local okClassText, classText = safeCall(function()
        local cls = obj:getClass()
        return cls and tostring(cls) or nil
    end)
    if okClassText and tostring(classText or "") ~= "" then
        return tostring(classText)
    end
    local okString, asString = safeCall(function()
        return tostring(obj)
    end)
    if okString and tostring(asString or "") ~= "" then
        return tostring(asString)
    end
    return "unknown"
end

local function makeAttempt(name, sizeRef)
    return {
        attemptName = tostring(name),
        nonNil = 0,
        sizeRef = tonumber(sizeRef) or 0,
        errors = 0,
        sampleSqlIds = {},
        sampleVehicleIds = {},
        pairs = {},
        iterated = 0,
        nilSlots = 0,
        indexBase = "none"
    }
end

local function captureVehicle(attempt, vehicle)
    if not vehicle then
        attempt.nilSlots = attempt.nilSlots + 1
        return
    end
    attempt.nonNil = attempt.nonNil + 1
    local sqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or ""
    local vehicleId = NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and NMVehicleHelpers.getVehicleIdString(vehicle) or ""
    if sqlId ~= "" and vehicleId ~= "" then
        attempt.pairs[#attempt.pairs + 1] = { sql = tostring(sqlId), id = tostring(vehicleId) }
    end
    if #attempt.sampleSqlIds < 5 then
        attempt.sampleSqlIds[#attempt.sampleSqlIds + 1] = tostring(sqlId ~= "" and sqlId or "nil")
    end
    if #attempt.sampleVehicleIds < 5 then
        attempt.sampleVehicleIds[#attempt.sampleVehicleIds + 1] = tostring(vehicleId ~= "" and vehicleId or "nil")
    end
end

local function collectFromVehiclesSource(label, vehicles, outMap)
    local report = {
        label = tostring(label or "unknown"),
        sizeReported = 0,
        iteratedSlots = 0,
        nonNilVehicles = 0,
        nilSlots = 0,
        getErrors = 0,
        readModeUsed = "none",
        indexBaseUsed = "none",
        sampleSqlIds = {},
        sampleVehicleIds = {},
        attemptSummary = "",
        attempts = {},
        vehiclesClass = "nil"
    }
    if not vehicles then
        return report
    end

    report.vehiclesClass = readClassName(vehicles)
    local size = readVehiclesSize(vehicles)
    report.sizeReported = size
    if size <= 0 then
        return report
    end

    local best = nil
    local function considerBest(candidate)
        if not best then
            best = candidate
            return
        end
        if candidate.nonNil > best.nonNil then
            best = candidate
            return
        end
        if candidate.nonNil == best.nonNil and candidate.errors < best.errors then
            best = candidate
            return
        end
        if candidate.nonNil == best.nonNil and candidate.errors == best.errors then
            local pa = ATTEMPT_PRIORITY[candidate.attemptName] or 999
            local pb = ATTEMPT_PRIORITY[best.attemptName] or 999
            if pa < pb then
                best = candidate
            end
        end
    end

    do
        local a = makeAttempt("iterator", size)
        local okIt, it = safeCall(function()
            return vehicles.iterator and vehicles:iterator() or nil
        end)
        if not okIt or not it then
            a.errors = a.errors + 1
        else
            while true do
                local okHasNext, hasNext = safeCall(function()
                    return it.hasNext and it:hasNext() or false
                end)
                if not okHasNext then
                    a.errors = a.errors + 1
                    break
                end
                if hasNext ~= true then
                    break
                end
                a.iterated = a.iterated + 1
                local okNext, vehicle = safeCall(function()
                    return it.next and it:next() or nil
                end)
                if not okNext then
                    a.errors = a.errors + 1
                end
                captureVehicle(a, vehicle)
                if a.iterated > 1024 then
                    break
                end
            end
        end
        report.attempts[#report.attempts + 1] = a
        considerBest(a)
    end

    do
        local a = makeAttempt("to_array", size)
        local okArr, arr = safeCall(function()
            return vehicles.toArray and vehicles:toArray() or nil
        end)
        if not okArr or not arr then
            a.errors = a.errors + 1
        else
            local arrSize = 0
            local okArrSizeA, cA = safeCall(function()
                return arr.size and arr:size() or nil
            end)
            if okArrSizeA and tonumber(cA) then
                arrSize = math.max(0, math.floor(tonumber(cA) or 0))
            else
                local okArrSizeB, cB = safeCall(function()
                    return arr.length
                end)
                if okArrSizeB and tonumber(cB) then
                    arrSize = math.max(0, math.floor(tonumber(cB) or 0))
                else
                    arrSize = size
                end
            end
            a.sizeRef = arrSize
            for idx = 0, math.max(0, arrSize - 1) do
                a.iterated = a.iterated + 1
                local okAt, vehicle = readVehiclesAtMode(arr, idx, "raw_index")
                if not okAt then
                    a.errors = a.errors + 1
                end
                captureVehicle(a, vehicle)
            end
        end
        report.attempts[#report.attempts + 1] = a
        considerBest(a)
    end

    best = best or makeAttempt("none", size)
    report.nonNilVehicles = math.max(0, best.nonNil or 0)
    report.iteratedSlots = tonumber(best.iterated) or 0
    report.nilSlots = tonumber(best.nilSlots) or 0
    report.getErrors = tonumber(best.errors) or 0
    report.readModeUsed = tostring(best.attemptName or "none")
    report.indexBaseUsed = (best.attemptName == "iterator") and "iterator" or "array"
    report.sampleSqlIds = best.sampleSqlIds or {}
    report.sampleVehicleIds = best.sampleVehicleIds or {}

    local attempts = {}
    for i = 1, #report.attempts do
        local a = report.attempts[i]
        attempts[#attempts + 1] = string.format(
            "%s@%s=%s/%s e%s",
            tostring(a.attemptName or "none"),
            tostring(a.indexBase or "none"),
            tostring(a.nonNil or 0),
            tostring(a.sizeRef or size),
            tostring(a.errors or 0)
        )
    end
    report.attemptSummary = table.concat(attempts, ",")

    for i = 1, #(best.pairs or {}) do
        local pair = best.pairs[i]
        outMap[pair.sql] = pair.id
    end
    return report
end

local function buildEmptySourceReport(label, getErrors, vehiclesClass, readModeUsed)
    return {
        label = tostring(label or "unknown"),
        sizeReported = 0,
        iteratedSlots = 0,
        nonNilVehicles = 0,
        nilSlots = 0,
        getErrors = tonumber(getErrors) or 0,
        readModeUsed = tostring(readModeUsed or "none"),
        indexBaseUsed = "none",
        sampleSqlIds = {},
        sampleVehicleIds = {},
        attemptSummary = "none",
        vehiclesClass = tostring(vehiclesClass or "nil")
    }
end

local function emitRefreshLog(nowMs, nextMap, sourceReports, cellClass, worldCellClass)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle") and NMCore.shouldLogEvery) then
        return
    end
    if not NMCore.shouldLogEvery("vehicleDiagnostics.server_sql_index_state", nowMs, 60000) then
        return
    end
    local count = 0
    for _, __ in pairs(nextMap) do
        count = count + 1
    end
    local sourceSummary = {}
    for i = 1, #sourceReports do
        local r = sourceReports[i]
        sourceSummary[#sourceSummary + 1] = string.format(
            "src%d=%s:%s/%s mode=%s base=%s nil=%s err=%s vclass=%s sql=%s vid=%s attempts=%s",
            i - 1,
            tostring(r.label or "unknown"),
            tostring(r.nonNilVehicles or 0),
            tostring(r.sizeReported or 0),
            tostring(r.readModeUsed or "none"),
            tostring(r.indexBaseUsed or "none"),
            tostring(r.nilSlots or 0),
            tostring(r.getErrors or 0),
            tostring(r.vehiclesClass or "nil"),
            tostring((r.sampleSqlIds and table.concat(r.sampleSqlIds, ",")) or "none"),
            tostring((r.sampleVehicleIds and table.concat(r.sampleVehicleIds, ",")) or "none"),
            tostring(r.attemptSummary or "none")
        )
    end
    NMCore.logChannel(
        "vehicle",
        "server_vehicle_sql_index_state",
        string.format(
            "entries=%s refreshedMs=%s cellClass=%s worldCellClass=%s %s",
            tostring(count),
            tostring(nowMs),
            tostring(cellClass),
            tostring(worldCellClass),
            table.concat(sourceSummary, " ")
        )
    )
end

function NMServerVehicleSqlIndexCache.refresh()
    NMServerRegistryState.vehicleRuntimeIdBySqlId = NMServerRegistryState.vehicleRuntimeIdBySqlId or {}
    local nowMs = nowRealMs()
    local lastMs = tonumber(NMServerRegistryState.vehicleSqlIndexLastRefreshMs) or 0
    if (nowMs - lastMs) < 1500 then
        return false
    end

    local nextMap = {}
    local sourceReports = {}
    local cell = getCell and getCell() or nil
    local world = getWorld and getWorld() or nil
    local worldCell = world and world.getCell and world:getCell() or nil
    local cellClass = readClassName(cell)
    local worldCellClass = readClassName(worldCell)

    local vehiclesA = nil
    local okVehiclesA = false
    if cell then
        okVehiclesA, vehiclesA = safeCall(function()
            return cell:getVehicles()
        end)
    end
    if okVehiclesA and vehiclesA then
        sourceReports[#sourceReports + 1] = collectFromVehiclesSource("cell.getVehicles", vehiclesA, nextMap)
    else
        sourceReports[#sourceReports + 1] = buildEmptySourceReport("cell.getVehicles", okVehiclesA and 0 or 1, "nil", "none")
    end

    local sameCell = (worldCell ~= nil and worldCell == cell)
    if not sameCell and worldCell then
        local okVehiclesB, vehiclesB = safeCall(function()
            return worldCell:getVehicles()
        end)
        if okVehiclesB and vehiclesB then
            sourceReports[#sourceReports + 1] = collectFromVehiclesSource("world.cell.getVehicles", vehiclesB, nextMap)
        else
            sourceReports[#sourceReports + 1] = buildEmptySourceReport("world.cell.getVehicles", okVehiclesB and 0 or 1, "nil", "none")
        end
    else
        sourceReports[#sourceReports + 1] = buildEmptySourceReport("world.cell.getVehicles", 0, readClassName(vehiclesA), "same_as_cell")
    end

    NMServerRegistryState.vehicleRuntimeIdBySqlId = nextMap
    NMServerRegistryState.vehicleSqlIndexLastRefreshMs = nowMs
    emitRefreshLog(nowMs, nextMap, sourceReports, cellClass, worldCellClass)
    return true
end

return NMServerVehicleSqlIndexCache
