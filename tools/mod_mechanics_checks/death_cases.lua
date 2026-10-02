-- Execute the exact production Identity.markDead body. Death admission and
-- other county services are controlled; native inventories and cooler physics
-- remain the installed receivers from the preceding Body caller proof.
local M, CF = SAO.ModMechanics, TienCoolers
local function deathCase(foreign)
    local c = bodyCase(foreign)
    c.rec.forename, c.rec.surname = "Native", "Proof"
    c.rec.x, c.rec.y = c.set.body:getX(), c.set.body:getY()
    return c
end

local c = deathCase(false)
local clock, charge = c.set.cooler:getModData().tcLast, CF.getCharge(c.set.ice)
local before = M.coolerStatus(c.id)
local accepted, reason = M.forget(c.id)
check("living_actor_cannot_forget_cooler_runtime", accepted == false and reason == "actor-not-dead"
    and M.coolerStatus(c.id).passes == before.passes)
check("actual_death_releases_living_cooler_runtime", SAO.Identity.markDead(c.rec, 0, "controlled-death") == true
    and c.rec.dead == true and M.coolerStatus(c.id) == nil)
check("death_retains_native_possessions_and_existing_body_owner", SAO.Body.active[c.id] == c.set.body
    and c.removed == 0 and c.dropped == 0 and c.set.body:getInventory():contains(c.set.bag)
    and near(c.set.cooler:getModData().tcLast, clock) and near(CF.getCharge(c.set.ice), charge))
check("duplicate_death_cannot_repeat_runtime_retirement", SAO.Identity.markDead(c.rec, 0, "repeated-death") == false)

c = deathCase(true)
check("foreign_death_drops_runtime_preserves_external_owner", SAO.Identity.markDead(c.rec, 0, "controlled-death") == true
    and M.coolerStatus(c.id) == nil and SAO.Body.foreign[c.id] == c.set.body
    and c.rec.bodyOwner == "ZAO" and c.rec.bodyOwnerToken == "foreign-token" and c.removed == 0)

c = deathCase(false)
local updateName = CF.updateCoolerName
CF.updateCoolerName = function() error("controlled real cooler partial-pass death") end
local report = M.tickCoolers()
CF.updateCoolerName = updateName
M.tickCoolers() -- Reach the source-owned unresolved interval and its dedup key.
local failure = c.rec.inventoryMechanics and c.rec.inventoryMechanics.coolerFailure
local logged = c.coolerLogs
check("partial_native_failure_is_retained_before_death", report.failed == 1 and failure ~= nil
    and M.coolerStatus(c.id).status == "cooler-reconciliation-required")
accepted = SAO.Identity.markDead(c.rec, 0, "controlled-death")
local status = M.coolerStatus(c.id)
check("death_drops_handles_keeps_unresolved_physical_interval", accepted == true and status.passes == 0
    and status.lastWorldHours == nil and c.rec.inventoryMechanics.coolerFailure == failure
    and SAO.Body.active[c.id] == c.set.body and c.removed == 0)

-- A controlled registry replacement makes the same key observable again.
-- This inspects discarded log scratch; it does not establish human revival.
local replacement = __recordRoundTrip(c.rec)
replacement.dead = nil
replaceRecord(c.id, replacement)
M.tickCoolers()
check("death_drops_cooler_log_dedup_scratch", c.coolerLogs == logged + 1
    and replacement.inventoryMechanics.coolerFailure.error == failure.error)
print("DEATH_CALLER_BOUNDARY actual production markDead and native inventory physics; death admission/registry replacement controlled")
