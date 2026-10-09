require "zombies/NMServerZombieScanHelpers"

NMServerMPZombieAssignmentEligibility = NMServerMPZombieAssignmentEligibility or {}

function NMServerMPZombieAssignmentEligibility.isProcessed(zombie, getModDataFn)
    local md = getModDataFn and getModDataFn(zombie) or nil
    local status = tostring(md and md.status or "")
    if status == "attached" then
        return tostring(md and md.mediaMode or "") ~= ""
    end
    return status == "none" or status == "suppressed" or status == "excluded" or status == "media_only"
end

function NMServerMPZombieAssignmentEligibility.isFailureCoolingDown(zombie, getModDataFn, nowTick, cooldownTicks)
    local md = getModDataFn and getModDataFn(zombie) or nil
    local failedTick = md and tonumber(md.failedTick) or nil
    if failedTick == nil then
        return false
    end
    local currentTick = tonumber(nowTick) or 0
    local cooldown = tonumber(cooldownTicks) or 0
    return (currentTick - failedTick) < cooldown
end

function NMServerMPZombieAssignmentEligibility.shouldQueueNaturalZombie(zombie, deps)
    local isAliveZombie = deps and deps.isAliveZombie or NMServerZombieScanHelpers.isAliveZombie
    local getModData = deps and deps.getModData or nil
    local nowTick = deps and deps.nowTick or 0
    local cooldownTicks = deps and deps.cooldownTicks or 0
    if not isAliveZombie or isAliveZombie(zombie) ~= true then
        return false
    end
    if NMServerMPZombieAssignmentEligibility.isProcessed(zombie, getModData) then
        return false
    end
    if NMServerMPZombieAssignmentEligibility.isFailureCoolingDown(zombie, getModData, nowTick, cooldownTicks) then
        return false
    end
    return true
end

return NMServerMPZombieAssignmentEligibility
