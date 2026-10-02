check("body_production_onsave_callback_is_registered", Events.OnSave.count() == 1
    and Events.OnSave.at(1) == SAO.Body.onSaveCheckpoint)

local c = bodyCase(false)
check("body_active_save_orders_cooler_before_native_capture", bodyOrdered(c, "active-save"))
check("body_active_save_preserves_live_owner", SAO.Body.get(c.id) == c.set.body and c.removed == 0
    and c.dropped == 0 and c.rec.bodyOwner == nil and c.rec.bodyCheckpointFailure == nil)
c = bodyCase(true)
check("body_foreign_save_orders_cooler_before_native_capture", bodyOrdered(c, "foreign-save"))
check("body_foreign_save_preserves_external_owner", SAO.Body.get(c.id) == c.set.body
    and c.rec.bodyOwner == "ZAO" and c.rec.bodyOwnerToken == "foreign-token" and c.removed == 0)
c = bodyCase(false)
check("body_transfer_preparation_orders_cooler_before_native_capture", bodyOrdered(c, "transfer"))
check("body_transfer_preparation_keeps_original_owner_and_journal", SAO.Body.active[c.id] == c.set.body
    and SAO.Body.foreign[c.id] == nil and c.rec.bodyOwner == nil and c.removed == 0
    and c.rec.bodyTransfer.owner == "ZAO" and c.rec.bodyTransfer.captured.packed ~= c.oldPacked)
c = bodyCase(false)
check("body_release_orders_cooler_before_native_capture", bodyOrdered(c, "release"))
check("body_release_commits_then_drops_exact_owner", SAO.Body.active[c.id] == nil and c.removed == 1
    and c.dropped == 1 and c.rec.bodyRelease == nil and c.rec.hibernation ~= c.oldPacked)
c = bodyCase(true)
check("body_external_hibernation_orders_cooler_before_native_capture", bodyOrdered(c, "foreign-hibernate"))
check("body_external_hibernation_keeps_durable_external_owner", SAO.Body.foreign[c.id] == nil and c.removed == 1
    and c.dropped == 0 and c.rec.bodyOwner == "ZAO" and c.rec.bodyOwnerToken == "foreign-token"
    and c.rec.bodyRelease == nil and c.rec.hibernation ~= c.oldPacked)

c = bodyCase(false)
check("body_active_save_refusal_retains_snapshot_body_and_owner", bodyRefused(c, "active-save"))
c = bodyCase(true)
check("body_foreign_save_refusal_retains_snapshot_body_and_owner", bodyRefused(c, "foreign-save"))
c = bodyCase(false)
check("body_transfer_refusal_retains_snapshot_body_and_owner", bodyRefused(c, "transfer"))
c = bodyCase(false)
check("body_release_refusal_retains_snapshot_body_and_owner", bodyRefused(c, "release"))
c = bodyCase(true)
check("body_external_hibernation_refusal_retains_snapshot_body_and_owner", bodyRefused(c, "foreign-hibernate"))

c = bodyCase(false)
local installed = TienCoolers
TienCoolers = nil
local absent = bodyInvoke(c, "active-save")
TienCoolers = installed
check("body_absent_optional_mod_keeps_native_checkpoint_semantics", absent == true and c.captures == 1
    and c.removed == 0 and c.dropped == 0 and SAO.Body.get(c.id) == c.set.body
    and c.set.cooler:getModData().tcLast == c.oldClock and __snapshotValid(c.rec.hibernation))
print("BODY_CALLER_BOUNDARY all five production captureCurrent paths + native person codecs; queue/population/teardown services controlled")
print("CASES " .. __count)
