local M = SAO.ModMechanics
local ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), __a.body)
check("absent_optional_mod_is_checkpoint_noop", ok == true and status == "mod-absent"
    and M.coolerStatus("cool-a") == nil and __a.cooler:getModData().tcLast == nil)
TienCoolers = {}
ok, status = M.beforeSnapshot(SAO.Identity.get("cool-a"), __a.body)
check("present_incomplete_mod_refuses_checkpoint", ok == false and status == "cooler-api-incomplete")
TienCoolers = nil
__adapterMinute = M.onCoolerMinute
