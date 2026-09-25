-- SAO_CrossedTransfer - one-way ownership of a living ZAO-driven person.
--
-- Afflicted and Crossed are distinct pathogen states, but ZAO drives both.
-- This seam preserves the same human shell and everything it carries while
-- moving runtime authority from SAO's controller to ZAO. The native snapshot
-- is captured before the owner changes, so reload can reconstruct the shell
-- without replaying the state transition or minting a replacement person.
--
-- The historical public name remains as a compatibility alias because saved
-- actions and the sister already call it. It no longer implies that Crossed
-- are the only ZAO-owned living people.

SAO = SAO or {}
SAO.ZAOPersonTransfer = SAO.ZAOPersonTransfer or SAO.CrossedTransfer or {}
SAO.CrossedTransfer = SAO.ZAOPersonTransfer
local Transfer = SAO.ZAOPersonTransfer

local function recOf(personId)
    return SAO.Identity and SAO.Identity.get(tostring(personId)) or nil
end

local function pathogenState(personId)
    if not (ZAO and ZAO.StateStore and ZAO.StateStore.read) then return nil end
    local ok, state = pcall(ZAO.StateStore.read, tostring(personId))
    return ok and type(state) == "table" and state or nil
end

local function terminalOf(rec, supplied)
    local terminal = tostring(supplied or "")
    if terminal == "afflicted" or terminal == "crossed" then return terminal end
    local state = rec and pathogenState(rec.id) or nil
    terminal = state and tostring(state.terminalState or "") or ""
    if terminal == "afflicted" or terminal == "crossed" then return terminal end
    return nil
end

local function pendingOf(rec)
    if not rec then return nil end
    if rec.zaoTransferPending then return rec.zaoTransferPending end
    -- Migrate the pre-Afflicted-driver handoff in place. A legacy pending
    -- record could only have been a Crossed conversion.
    if rec.crossedTransferPending then
        rec.zaoTransferPending = rec.crossedTransferPending
        rec.zaoTransferPending.terminalState =
            rec.zaoTransferPending.terminalState or "crossed"
        rec.crossedTransferPending = nil
    end
    return rec.zaoTransferPending
end

local function publish(rec, body, terminal)
    if ZAO and ZAO.Controller and ZAO.Controller.acceptExternal then
        local ok, accepted = pcall(ZAO.Controller.acceptExternal, rec.id, body,
            rec.bodyOwnerToken, terminal)
        return ok and accepted == true
    end
    return false
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
    rec.zaoTransferPending = nil
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
    local pending = pendingOf(rec)
    local terminal = terminalOf(rec, pending and pending.terminalState)
    if not terminal then return false, "non-zao-person-state" end
    local ok, reason = SAO.Body.commitExternalTransfer(rec)
    if not ok then return false, reason end
    local body = SAO.Body.foreign[rec.id]
    if not publish(rec, body, terminal) then
        return false, "zao-owner-rejected"
    end
    if SAO.Neuro and SAO.Neuro.recordTerminal then
        pcall(SAO.Neuro.recordTerminal, rec, terminal,
            rec.releasedAtHours, "zao-person-transfer")
    end
    rec.zaoTransferPending = nil
    rec.crossedTransferPending = nil
    return true, reason
end

function Transfer.begin(personId, body, token, atHours, terminalState)
    local rec = recOf(personId)
    if not rec then return false, "missing-person" end
    token = tostring(token or "")
    if token == "" then return false, "invalid-transfer-token" end
    local terminal = terminalOf(rec, terminalState)
    -- Calls from older Crossed code predate the explicit terminal argument.
    -- The token is not used to classify new state; this fallback exists only
    -- when the pathogen owner is absent from an isolated compatibility test.
    if not terminal and not (ZAO and ZAO.StateStore) then terminal = "crossed" end
    if not terminal then return false, "non-zao-person-state" end
    body = body or (SAO.Body and SAO.Body.active and SAO.Body.active[rec.id])
    if rec.dead or bodyIsDead(body) then
        Transfer.cancelForDeath(rec)
        return false, "person-dead"
    end
    if rec.bodyOwner == "ZAO" and rec.bodyOwnerToken == token then
        if not publish(rec, SAO.Body.foreign[rec.id], terminal) then
            return false, "zao-owner-rejected"
        end
        rec.zaoTransferPending = nil
        rec.crossedTransferPending = nil
        return true, "already-transferred"
    end
    if rec.bodyOwner then return false, "owned-by-another" end
    if rec.bodyTransfer then
        if rec.bodyTransfer.owner ~= "ZAO" or rec.bodyTransfer.token ~= token then
            return false, "another-transfer-pending"
        end
        return Transfer.resume(rec)
    end
    local pending = pendingOf(rec)
    if pending and pending.token ~= token then
        return false, "another-transfer-pending"
    end
    rec.zaoTransferPending = pending or { token = token,
        atHours = tonumber(atHours), terminalState = terminal }
    rec.zaoTransferPending.terminalState = terminal
    if SAO.SourceUse and SAO.SourceUse.closeForOwnershipTransfer
        and not SAO.SourceUse.closeForOwnershipTransfer(rec.id, body,
            "zao-person-ownership-transfer") then
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
        elseif pendingOf(rec) then
            if rec.dead then
                rec.zaoTransferPending = nil
                rec.crossedTransferPending = nil
            else
                local pending = pendingOf(rec)
                local body = SAO.Body.active[rec.id]
                local ok = false
                if rec.bodyOwner == "ZAO" then
                    ok = publish(rec, SAO.Body.foreign[rec.id],
                        terminalOf(rec, pending.terminalState))
                    if ok then
                        rec.zaoTransferPending = nil
                        rec.crossedTransferPending = nil
                    end
                elseif body then
                    ok = Transfer.begin(rec.id, body,
                        pending.token, pending.atHours,
                        pending.terminalState)
                elseif SAO.Body.claimExternalDormant then
                    ok = SAO.Body.claimExternalDormant(rec, "ZAO",
                        pending.token)
                    if ok then
                        ok = publish(rec, nil, terminalOf(rec,
                            pending.terminalState))
                        if not ok then complete = false end
                    end
                    if ok then
                        if SAO.Neuro and SAO.Neuro.recordTerminal then
                            pcall(SAO.Neuro.recordTerminal, rec,
                                terminalOf(rec, pending.terminalState),
                                pending.atHours, "zao-person-transfer")
                        end
                        rec.zaoTransferPending = nil
                        rec.crossedTransferPending = nil
                    end
                end
                if not ok then complete = false end
            end
        end
    end
    return complete
end

-- A reconstructed return can finish offscreen without briefly creating an
-- SAO controller. The validated person envelope moves directly to ZAO.
function Transfer.claimDormant(personId, token, atHours, terminalState)
    local rec = recOf(personId)
    if not rec then return false, "missing-person" end
    token = tostring(token or "")
    local terminal = terminalOf(rec, terminalState)
    if token == "" or not terminal then return false, "invalid-transfer" end
    rec.zaoTransferPending = { token = token, atHours = tonumber(atHours),
        terminalState = terminal }
    local ok, reason = SAO.Body.claimExternalDormant(rec, "ZAO", token)
    if not ok then return false, reason end
    if not publish(rec, nil, terminal) then
        return false, "zao-owner-rejected"
    end
    if SAO.Neuro and SAO.Neuro.recordTerminal then
        pcall(SAO.Neuro.recordTerminal, rec, terminal, atHours,
            "zao-person-transfer")
    end
    rec.zaoTransferPending = nil
    rec.crossedTransferPending = nil
    return true, reason
end

Transfer.terminalOf = terminalOf

if Events and Events.OnGameStart then
    if Transfer.onGameStart then Events.OnGameStart.Remove(Transfer.onGameStart) end
    Transfer.onGameStart = function() Transfer.resumePending() end
    Events.OnGameStart.Add(Transfer.onGameStart)
end

return Transfer
