local M, CF = SAO.ModMechanics, TienCoolers
local a, b, p = __a, __b, __p
local worldOk, worldDetail = pcall(function()
    local w = getWorld()
    local c = w:getCell()
    return tostring(c:getObjectList():contains(a.body)) .. "/" .. tostring(c:getAddList():contains(a.body))
end)
print("MEASURE current_world_methods=" .. tostring(worldOk) .. " detail=" .. tostring(worldDetail))
check("late_shared_load_keeps_installed_callbacks", Events.EveryOneMinute.count() == 3
    and Events.EveryOneMinute.at(1) == __adapterMinute
    and Events.EveryOneMinute.at(2) ~= __adapterMinute
    and Events.EveryOneMinute.at(3) ~= __adapterMinute)
local playerMinute, serverMinute = Events.EveryOneMinute.at(2), Events.EveryOneMinute.at(3)
CF.storeCharge(a.ice, 1) CF.storeCharge(b.ice, .5) CF.storeCharge(p.ice, .75)
__time(12)
a.loose:updateAge() b.loose:updateAge() p.loose:updateAge()
Events.OnPlayerUpdate.fire(p.body)
Events.EveryOneMinute.fire()
local start = CF.worldHours()
local startFoodAge, startLooseAge = a.food:getAge(), a.loose:getAge()
local firstState = M.coolerStatus("cool-a")
print("MEASURE first_npc_pass=" .. tostring(firstState and firstState.status)
    .. " error=" .. tostring(firstState and firstState.lastError))
check("both_owned_offslot_inventories_receive_native_baseline", a.cooler:getModData().tcLast == start
    and b.cooler:getModData().tcLast == start and a.food:getModData().tcCooler ~= b.food:getModData().tcCooler)
local ok, status = M.processCoolers("player", p.body)
check("native_player_inventory_retains_installed_authority", ok == false and status == "native-player-owned"
    and p.cooler:getModData().tcLast == start and M.coolerStatus("player") == nil)
__time(14)
Events.EveryOneMinute.fire()
a.loose:updateAge() b.loose:updateAge() p.loose:updateAge()
local elapsed = CF.worldHours() - start
local chargeA, chargeB, chargeP = CF.getCharge(a.ice), CF.getCharge(b.ice), CF.getCharge(p.ice)
print("MEASURE world_elapsed=" .. elapsed .. " ice_a=" .. chargeA .. " ice_b=" .. chargeB .. " ice_player=" .. chargeP)
print("MEASURE start=" .. start .. " tcLast=" .. tostring(a.cooler:getModData().tcLast)
    .. " charge_exact=" .. tostring(a.ice:getModData().tcCharge) .. " cold=" .. tostring(CF.containerIsCold(a.body:getInventory()))
    .. " power=" .. tostring(CF.icePower(a.ice)) .. " status=" .. tostring(M.coolerStatus("cool-a").status))
check("installed_ice_debit_uses_each_exact_native_inventory", near(chargeA, 1 - elapsed / 48)
    and near(chargeB, .5 - elapsed / 48) and near(chargeP, .75 - elapsed / 48)
    and a.ice:getContainer() == a.cooler:getInventory() and b.ice:getContainer() == b.cooler:getInventory())
print("MEASURE age_a=" .. a.food:getAge() .. " age_b=" .. b.food:getAge() .. " age_player=" .. p.food:getAge()
    .. " age_loose=" .. a.loose:getAge() .. " factor=" .. CF.coolFactor())
check("native_food_age_matches_installed_player_cooling", near(a.food:getAge(), p.food:getAge())
    and near(b.food:getAge(), p.food:getAge()) and a.food:getAge() > 0
    and a.food:getAge() < a.loose:getAge()
    and near(a.food:getAge() - startFoodAge, (a.loose:getAge() - startLooseAge) * CF.coolFactor()))
local itemIds = { a.cooler:getID(), a.ice:getID(), a.food:getID(), a.bag:getID() }
local foodAge = a.food:getAge()
M.processCoolers("cool-a", a.body) M.beforeSnapshot(SAO.Identity.get("cool-a"), a.body)
CF.processTopLevel(a.body:getInventory())
check("native_item_clock_prevents_duplicate_cooling", near(chargeA, CF.getCharge(a.ice))
    and near(foodAge, a.food:getAge()) and a.cooler:getID() == itemIds[1]
    and a.ice:getID() == itemIds[2] and a.food:getID() == itemIds[3] and a.bag:getID() == itemIds[4])
local row = M.coolerStatus("cool-a")
row.actorId = "tampered" row.passes = -1
check("per_actor_status_is_detached_plain_data", plain(M.coolerStatus("cool-a"))
    and M.coolerStatus("cool-a").actorId == "cool-a" and M.coolerStatus("cool-a").passes > 0
    and M.coolerStatus("cool-b").actorId == "cool-b" and M.coolerStatus("cool-a").body == nil)
check("all_installed_item_moddata_is_strict_snapshot_data", plain(a.cooler:getModData())
    and plain(a.ice:getModData()) and plain(a.food:getModData()) and plain(a.bag:getModData()))

local before = b.cooler:getModData().tcLast
b.body:getModData().SAOExternalToken = "other-token"
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-b"), b.body)
check("foreign_actor_token_mismatch_refuses_checkpoint", ok == false and status == "body-identity-mismatch"
    and b.cooler:getModData().tcLast == before and near(chargeB, CF.getCharge(b.ice)))
b.body:getModData().SAOExternalToken = "foreign-token"
__detach(b.body, true)
ok, status = M.processCoolers("cool-b", b.body)
check("detached_native_body_cannot_process_carried_items", ok == false
    and b.cooler:getModData().tcLast == before and near(chargeB, CF.getCharge(b.ice)))
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-b"), b.body)
check("detached_checkpoint_requires_canonical_unload_journal", ok == false
    and b.cooler:getModData().tcLast == before)
SAO.Body.unloaded["cool-b"] = true
__transition = "cool-b"
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-b"), b.body)
check("authenticated_unloaded_inventory_can_reach_final_checkpoint", ok == true
    and status == "processed" and near(chargeB, CF.getCharge(b.ice)))
ok, status = M.processCoolers("cool-b", b.body)
check("unload_journal_never_permits_ordinary_physical_tick", ok == false)
SAO.Body.unloaded["cool-b"] = nil
__transition = nil
__detach(b.body, false)
__transition = "cool-b"
ok, status = M.processCoolers("cool-b", b.body)
check("ownership_transition_cannot_process_retained_handle", ok == false and status == "body-unavailable")
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-b"), b.body)
check("authenticated_body_checkpoint_can_capture_staged_living_actor", ok == true and status == "processed"
    and near(chargeB, CF.getCharge(b.ice)))
ok, status = M.beforeSnapshot({ id = "cool-b" }, b.body)
check("checkpoint_does_not_accept_unregistered_record_in_transition", ok == false and status == "body-record-mismatch")
__transition = nil
CF.syncPlayer = p.body
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), a.body)
check("installed_request_context_is_never_overwritten", ok == false and status == "cooler-context-busy"
    and CF.syncPlayer == p.body and near(chargeA, CF.getCharge(a.ice)))
CF.syncPlayer = nil CF.leaveCoolers = true
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), a.body)
check("installed_remote_cooler_authority_is_preserved", ok == false and status == "cooler-context-busy"
    and CF.leaveCoolers == true and near(chargeA, CF.getCharge(a.ice)))
CF.leaveCoolers = nil
__client = true
ok, status = M.processCoolers("cool-a", a.body)
local clientGuard = ok == true and status == "multiplayer-unowned" and near(chargeA, CF.getCharge(a.ice))
__client = false __server = true
ok, status = M.processCoolers("cool-a", a.body)
check("multiplayer_endpoints_do_not_invent_npc_inventory_authority", clientGuard and ok == true
    and status == "multiplayer-unowned" and near(chargeA, CF.getCharge(a.ice)))
__server = false

-- No ice in this cooler: the source ages food normally and creates no cold
-- source. Moving the same native item is a fixture setup, not adapter physics.
a.cooler:getInventory():Remove(a.ice)
__time(15)
M.processCoolers("cool-a", a.body)
local withoutIceAge = a.food:getAge()
__time(16)
M.processCoolers("cool-a", a.body)
check("uniced_cooler_cannot_fabricate_ice_or_preservation", a.cooler:getInventory():getItems():size() == 1
    and a.cooler:getInventory():getItems():get(0) == a.food
    and near(a.food:getAge() - withoutIceAge, 1 / 24))
a.cooler:getInventory():AddItem(a.ice)
local nativeProcess = CF.processTopLevel
check("installed_callbacks_and_shared_functions_keep_identity", CF.processTopLevel == nativeProcess
    and Events.EveryOneMinute.at(2) == playerMinute and Events.EveryOneMinute.at(3) == serverMinute)

__replaceWorld(true)
ok, status = M.processCoolers("cool-a", a.body)
check("retained_old_native_world_cannot_process_inventory", ok == false and status == "body-world-mismatch"
    and a.body:isExistInTheWorld() and getWorld():getCell():getObjectList():contains(a.body) == false)
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), a.body)
check("retained_old_native_world_cannot_checkpoint_inventory", ok == false and status == "body-world-mismatch")
__replaceWorld(false)

-- Before-save catch-up is part of Body's caller-owned transaction. This call
-- precedes the actual strict native person capture, including nested item data.
__time(18)
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), a.body)
local saveTime, saveCharge, saveAge = CF.worldHours(), CF.getCharge(a.ice), a.food:getAge()
local packed = __capture(a.body)
check("cooler_checkpoint_precedes_strict_native_capture", ok == true and type(packed) == "string"
    and a.cooler:getModData().tcLast == saveTime and plain(a.cooler:getModData()))
local wake = __newBody("cool-a")
__time(19)
local journal = __wake(wake, packed, 1)
check("native_wake_restores_nested_cooler_and_item_state", string.sub(journal, 1, 9) == "AWAKENED ")
local bag = wake:getInventory():getItems():get(0)
local cooler = bag:getInventory():getItems():get(0)
local ice, food
local contents = cooler:getInventory():getItems()
for i = 0, contents:size() - 1 do
    local item = contents:get(i)
    if item:getID() == itemIds[2] then ice = item end
    if item:getID() == itemIds[3] then food = item end
end
check("strict_snapshot_retains_exact_item_ids_and_quantities", bag:getID() == itemIds[4]
    and cooler:getID() == itemIds[1] and ice:getID() == itemIds[2] and food:getID() == itemIds[3]
    and near(CF.getCharge(ice), saveCharge) and cooler:getModData().tcLast == saveTime
    and near(food:getAge(), saveAge) and cooler:getInventory():getItems():size() == 2)
food:updateAge()
local uncooledWakeAge = food:getAge()
SAO.Body.active["cool-a"] = wake
ok, status = M.processCoolers("cool-a", wake)
local wakeElapsed = CF.worldHours() - saveTime
check("elapsed_native_food_age_is_reconciled_from_saved_cooler_clock", ok == true and status == "processed"
    and near(CF.getCharge(ice), saveCharge - wakeElapsed / 48)
    and food:getAge() < uncooledWakeAge and near(food:getAge() - saveAge, wakeElapsed / 24 * CF.coolFactor())
    and near(cooler:getModData().tcLast, CF.worldHours()))
check("wake_replaces_runtime_body_without_sharing_other_actor_state", M.coolerStatus("cool-a").passes == 1
    and near(CF.getCharge(b.ice), chargeB) and M.coolerStatus("cool-b").actorId == "cool-b")
local repeatedAge, repeatedCharge = food:getAge(), CF.getCharge(ice)
M.processCoolers("cool-a", wake)
check("wake_reconciliation_is_exactly_once_at_native_time", near(food:getAge(), repeatedAge)
    and near(CF.getCharge(ice), repeatedCharge))
ok, status = M.detach("cool-a", a.body)
check("detach_cannot_retire_replacement_native_body", ok == false and status == "body-mismatch"
    and M.coolerStatus("cool-a") ~= nil)
M.detach("cool-a", wake)
check("exact_detach_drops_runtime_without_touching_inventory", M.coolerStatus("cool-a") == nil
    and near(CF.getCharge(ice), repeatedCharge) and cooler:getID() == itemIds[1])
M.reset()
check("world_reset_discards_runtime_only", M.coolerStatus("cool-b") == nil
    and near(CF.getCharge(b.ice), chargeB) and getSpecificPlayer(0) == p.body)

-- Actual installed source advances its clock before these injected failures.
-- These two cases distinguish lost ice time from already-consumed ice.
__time(20)
CF.storeCharge(b.ice, 1)
local updateName = CF.updateCoolerName
CF.updateCoolerName = function() error("controlled failure after actual cooler clock write") end
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-b"), b.body)
check("native_update_error_refuses_partial_checkpoint", ok == false and status == "cooler-update-error"
    and M.coolerStatus("cool-b").status == "cooler-update-error"
    and b.cooler:getModData().tcLast == CF.worldHours() and near(CF.getCharge(b.ice), 1))
CF.updateCoolerName = updateName
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-b"), b.body)
check("clock_only_failure_retry_cannot_certify_checkpoint", ok == false and status == "cooler-reconciliation-required")
ok, status = M.processCoolers("cool-b", b.body)
check("physical_retry_never_erases_unfinished_interval", ok == false and status == "cooler-reconciliation-required"
    and near(CF.getCharge(b.ice), 1) and plain(SAO.Identity.get("cool-b").inventoryMechanics))

CF.storeCharge(ice, 1)
local rotSpeed = CF.foodRotSpeed
CF.foodRotSpeed = function() error("controlled failure after native ice debit") end
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), wake)
local partialCharge = CF.getCharge(ice)
check("native_post_ice_failure_records_real_consumed_charge", ok == false and status == "cooler-update-error"
    and partialCharge < 1 and partialCharge > 0)
CF.foodRotSpeed = rotSpeed
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), wake)
check("post_ice_failure_retry_cannot_certify_checkpoint", ok == false and status == "cooler-reconciliation-required"
    and near(partialCharge, CF.getCharge(ice)))
M.processCoolers("cool-a", wake)
check("same_time_native_retry_does_not_debit_twice", near(partialCharge, CF.getCharge(ice)))
M.reset()
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), wake)
check("runtime_reset_cannot_erase_failed_physics", ok == false and status == "cooler-reconciliation-required"
    and M.coolerStatus("cool-a").failedAtWorldHours == CF.worldHours())
local oldRec = SAO.Identity.get("cool-a")
local restoredRec = __recordRoundTrip(oldRec)
replaceRecord("cool-a", restoredRec)
ok, status = M.beforeSnapshot(restoredRec, wake)
check("native_person_record_reload_retains_unresolved_pass", oldRec ~= restoredRec and ok == false
    and status == "cooler-reconciliation-required" and plain(restoredRec)
    and restoredRec.inventoryMechanics.coolerFailure.error == oldRec.inventoryMechanics.coolerFailure.error)
M.detach("cool-a", wake)
check("retirement_cannot_certify_unresolved_durable_physics", M.beforeSnapshot(restoredRec, wake) == false
    and M.coolerStatus("cool-a").status == "cooler-reconciliation-required")
print("BOUNDARY loaded inventory + one-hour native wake replay; dormant meal selection before cooler replay remains unintegrated")
print("CASES " .. __count)
