-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMZombieVisualTargetContract = NMZombieVisualTargetContract or {}

NMZombieVisualTargetContract.NetCommand = "zombie_visual_targets"
NMZombieVisualTargetContract.ModDataKey = "nmZombieWalkmanProof"
NMZombieVisualTargetContract.SelectionSource = "server_ledger"
NMZombieVisualTargetContract.PublishIntervalTicks = 90
NMZombieVisualTargetContract.RepublishIntervalTicks = 180
NMZombieVisualTargetContract.ClientCacheTtlTicks = 270
NMZombieVisualTargetContract.NearbyRadius = 30
NMZombieVisualTargetContract.MaxTargetsPerPlayer = 96

local function safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then
        return tonumber(fallback) or 0
    end
    return number
end

local function copyTargetSnapshotRecord(record)
    if type(record) ~= "table" then
        return nil
    end
    local zombieId = tostring(record.zombieId or "")
    if zombieId == "" then
        return nil
    end
    return {
        zombieId = zombieId,
        variantId = tostring(record.variantId or ""),
        fullType = tostring(record.fullType or ""),
        attachmentLocation = tostring(record.attachmentLocation or ""),
        modelAttachmentName = tostring(record.modelAttachmentName or "")
    }
end

function NMZombieVisualTargetContract.getZombieId(zombie)
    if zombie and zombie.getOnlineID then
        local onlineId = safeNumber(zombie:getOnlineID(), -1)
        if onlineId >= 0 then
            return tostring(math.floor(onlineId))
        end
    end
    if zombie and zombie.getObjectID then
        local objectId = safeNumber(zombie:getObjectID(), -1)
        if objectId >= 0 then
            return tostring(math.floor(objectId))
        end
    end
    return tostring(zombie or "")
end

function NMZombieVisualTargetContract.buildTargetSnapshotLookup(records)
    local lookup = {}
    if type(records) ~= "table" then
        return lookup
    end
    for i = 1, #records do
        local record = copyTargetSnapshotRecord(records[i])
        if record then
            lookup[record.zombieId] = record
        end
    end
    return lookup
end

function NMZombieVisualTargetContract.getTargetSnapshotSignature(records)
    if type(records) ~= "table" or #records == 0 then
        return ""
    end
    local parts = {}
    for i = 1, #records do
        local record = copyTargetSnapshotRecord(records[i])
        if record then
            parts[#parts + 1] = table.concat({
                record.zombieId,
                record.variantId,
                record.fullType,
                record.attachmentLocation,
                record.modelAttachmentName
            }, "|")
        end
    end
    return table.concat(parts, ",")
end

return NMZombieVisualTargetContract
