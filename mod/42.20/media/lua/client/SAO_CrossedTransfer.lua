-- SAO_CrossedTransfer - one-way ownership of a living Crossed shell.
--
-- A successful intentional exposure changes pathogen state in ZAO.  This
-- seam preserves the same human-looking body and everything it carries while
-- moving runtime authority from SAO's controller to ZAO.  The native snapshot
-- is captured before the owner changes, so reload can reconstruct the shell
-- without replaying the exposure or minting a replacement person.

SAO = SAO or {}
SAO.CrossedTransfer = SAO.CrossedTransfer or {}
local Transfer = SAO.CrossedTransfer

local function recOf(personId)
    return SAO.Identity and SAO.Identity.get(tostring(personId)) or nil
end

local function publish(rec, body)
    if ZAO and ZAO.Controller and ZAO.Controller.acceptExternal then
        pcall(ZAO.Controller.acceptExternal, rec.id, body,
            rec.bodyOwnerToken)
    end
end

local function bodyIsDead(body)
    if not body then return false end
    local ok, dead = pcall(function() return body:isDead() end)
    return ok and dead == true
end

-- Death retains the corpse under the world's mortality path.  A captured
-- living-shell handoff must never outlive that fact and later publish the
-- dead body as a living ZAO-owned person.
function Transfer.cancelForDeath(rec)
    if not rec then return false end
    rec.crossedTransferPending = nil
    if rec.bodyTransfer and rec.bodyTransfer.owner == "ZAO" then
        rec.bodyTransfer = nil
    end
    return true
end

function Transfer.resume(rec)
    if not rec or not rec.bodyTransfer then return false, "no-transfer" end
    if rec.bodyTransfer.owner ~= "ZAO" then
        return false, "wrong-transfer-owner"
    end
    local active = SAO.Body and SAO.Body.active and SAO.Body.active[rec.id] or nil
    if rec.dead or bodyIsDead(active) then
        Transfer.cancelForDeath(rec)
        return false, "person-dead"
    end
    local ok, reason = SAO.Body.commitExternalTransfer(rec)
    if not ok then return false, reason end
    local body = SAO.Body.foreign[rec.id]
    publish(rec, body)
    if SAO.Neuro and SAO.Neuro.recordTerminal then
        pcall(SAO.Neuro.recordTerminal, rec, "crossed",
            rec.releasedAtHours, "crossed-transfer")
    end
    rec.crossedTransferPending = nil
    return true, reason
end

function Transfer.begin(personId, body, token, atHours)
    local rec = recOf(personId)
    if not rec then return false, "missing-person" end
    token = tostring(token or "")
    if token == "" then return false, "invalid-transfer-token" end
    body = body or (SAO.Body and SAO.Body.active and SAO.Body.active[rec.id])
    if rec.dead or bodyIsDead(body) then
        Transfer.cancelForDeath(rec)
        return false, "person-dead"
    end
    if rec.bodyOwner == "ZAO" and rec.bodyOwnerToken == token then
        rec.crossedTransferPending = nil
        publish(rec, SAO.Body.foreign[rec.id])
        return true, "already-transferred"
    end
    if rec.bodyOwner then return false, "owned-by-another" end
    if rec.bodyTransfer then
        if rec.bodyTransfer.owner ~= "ZAO" or rec.bodyTransfer.token ~= token then
            return false, "another-transfer-pending"
        end
        return Transfer.resume(rec)
    end
    if rec.crossedTransferPending
        and rec.crossedTransferPending.token ~= token then
        return false, "another-transfer-pending"
    end
    rec.crossedTransferPending = { token = token, atHours = tonumber(atHours) }
    if SAO.SourceUse and SAO.SourceUse.closeForOwnershipTransfer
        and not SAO.SourceUse.closeForOwnershipTransfer(rec.id, body,
            "crossed-ownership-transfer") then
        return false, "source-action-pending"
    end
    local prepared, reason = SAO.Body.prepareExternalTransfer(
        rec, body, "ZAO", token)
    if not prepared then return false, reason end
    return Transfer.resume(rec)
end

function Transfer.resumePending()
    if not (SAO.Identity and SAO.Body) then return false end
    local complete = true
    for _, rec in pairs(SAO.Identity.all()) do
        if rec.dead then
            Transfer.cancelForDeath(rec)
        elseif rec.bodyTransfer and rec.bodyTransfer.owner == "ZAO" then
            local ok = Transfer.resume(rec)
            if not ok then complete = false end
        elseif rec.crossedTransferPending then
            if rec.dead then
                rec.crossedTransferPending = nil
            else
                local pending = rec.crossedTransferPending
                local body = SAO.Body.active[rec.id]
                local ok = false
                if body then
                    ok = Transfer.begin(rec.id, body,
                        pending.token, pending.atHours)
                elseif SAO.Body.claimExternalDormant then
                    ok = SAO.Body.claimExternalDormant(rec, "ZAO",
                        pending.token)
                    if ok then
                        publish(rec, nil)
                        if SAO.Neuro and SAO.Neuro.recordTerminal then
                            pcall(SAO.Neuro.recordTerminal, rec, "crossed",
                                pending.atHours, "crossed-transfer")
                        end
                        rec.crossedTransferPending = nil
                    end
                end
                if not ok then complete = false end
            end
        end
    end
    return complete
end

if Events and Events.OnGameStart then
    if Transfer.onGameStart then Events.OnGameStart.Remove(Transfer.onGameStart) end
    Transfer.onGameStart = function() Transfer.resumePending() end
    Events.OnGameStart.Add(Transfer.onGameStart)
end

return Transfer
