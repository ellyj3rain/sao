NMServerSPZombieAssignmentEligibility = NMServerSPZombieAssignmentEligibility or {}

local function getCurrentTick(deps)
    return tonumber(deps and deps.nowTick or 0) or 0
end

function NMServerSPZombieAssignmentEligibility.isZombieSettled(zombie, md, spec, deps)
    local findAttachedProofItem = deps and deps.findAttachedProofItem or nil
    local status = tostring(md and md.status or "")
    if status ~= "attached" then
        return false
    end
    if md and md.selected ~= true then
        return false
    end
    if tostring(md and md.selectionSource or "") ~= "server_ledger" then
        return false
    end
    return spec ~= nil and findAttachedProofItem and findAttachedProofItem(zombie, spec) ~= nil
end

function NMServerSPZombieAssignmentEligibility.shouldAttemptAttach(zombie, md, spec, deps)
    local findAttachedProofItem = deps and deps.findAttachedProofItem or nil
    local findInventoryProofItem = deps and deps.findInventoryProofItem or nil
    local failedRetryTicks = tonumber(deps and deps.failedRetryTicks or 0) or 0
    local currentTick = getCurrentTick(deps)
    local status = tostring(md and md.status or "")
    local mediaMode = tostring(md and md.mediaMode or "")
    if status == "attached" then
        local selected = md and md.selected == true
        local selectionSource = tostring(md and md.selectionSource or "")
        local hasAttachedProof = spec and findAttachedProofItem and findAttachedProofItem(zombie, spec) ~= nil
        if selected and selectionSource == "server_ledger" and hasAttachedProof then
            return false
        end
        return true
    end
    if status == "media_only" then
        return mediaMode == ""
    end
    if status == "excluded" or status == "suppressed" then
        if spec and findAttachedProofItem and findInventoryProofItem then
            if findAttachedProofItem(zombie, spec) or findInventoryProofItem(zombie, spec) then
                return true
            end
        end
        return false
    end
    if status ~= "failed" then
        return true
    end
    local lastAttemptTick = tonumber(md and md.lastAttemptTick or 0) or 0
    return (currentTick - lastAttemptTick) >= failedRetryTicks
end

function NMServerSPZombieAssignmentEligibility.getRecentAttemptCooldownTicks(md, deps)
    local failedUpdateRetryTicks = tonumber(deps and deps.failedUpdateRetryTicks or 0) or 0
    local updateRetryTicks = tonumber(deps and deps.updateRetryTicks or 0) or 0
    local statelessRetryTicks = tonumber(deps and deps.statelessRetryTicks or 0) or 0
    local status = tostring(md and md.status or "")
    if status == "failed" then
        return failedUpdateRetryTicks
    end
    if status == "" then
        return statelessRetryTicks
    end
    return updateRetryTicks
end

function NMServerSPZombieAssignmentEligibility.evaluateZombie(zombie, deps)
    local getModData = deps and deps.getModData or nil
    local getStampedVariantSpec = deps and deps.getStampedVariantSpec or nil
    local getRecentAttemptTick = deps and deps.getRecentAttemptTick or nil
    local nowTick = getCurrentTick(deps)
    local zombieKey = tostring(deps and deps.zombieKey or "")
    local md = getModData and getModData(zombie) or nil
    local spec = getStampedVariantSpec and getStampedVariantSpec(zombie) or nil
    if NMServerSPZombieAssignmentEligibility.isZombieSettled(zombie, md, spec, deps) then
        return false, "settled", md, spec
    end
    if NMServerSPZombieAssignmentEligibility.shouldAttemptAttach(zombie, md, spec, deps) ~= true then
        return false, "ineligible", md, spec
    end
    local lastRecentAttempt = getRecentAttemptTick and tonumber(getRecentAttemptTick(zombieKey)) or 0
    local recentCooldown = NMServerSPZombieAssignmentEligibility.getRecentAttemptCooldownTicks(md, deps)
    if lastRecentAttempt > 0 and (nowTick - lastRecentAttempt) < recentCooldown then
        return false, "cooldown", md, spec, lastRecentAttempt + recentCooldown
    end
    return true, "eligible", md, spec
end

return NMServerSPZombieAssignmentEligibility
