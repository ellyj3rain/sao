-- Inventory/world context menu integration for New Music devices.
-- Canonical device UI path is NMDeviceUI -> NMDeviceWindow.
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPaneContextMenu"

_G.NMContextMenus = _G.NMContextMenus or {}
_G.NMContextMenusEnv = _G.NMContextMenusEnv or {}
local env = _G.NMContextMenusEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end

env.NMContextMenus = _G.NMContextMenus
env.NMContextMenus.Flags = env.NMContextMenus.Flags or {
    enableLegacySubmenu = false
}
env.NMContextMenus._flipIdAlias = env.NMContextMenus._flipIdAlias or {}
env.NMContextMenus._flipInFlight = env.NMContextMenus._flipInFlight or {}
env.NMContextMenus._flipPendingRequestBySource = env.NMContextMenus._flipPendingRequestBySource or {}
env.NMContextMenus._flipPendingSourceByRequest = env.NMContextMenus._flipPendingSourceByRequest or {}
env.fallbackIconByDeviceType = env.fallbackIconByDeviceType or {
    boombox = "Item_NM_BoomboxBlue",
    walkman = "Item_NM_WalkmanBlue",
    vinylplayer = "Item_NM_VinylplayerOak",
    cdplayer = "Item_NM_CDPlayerBlue",
    vehicle_radio = "Item_NM_BoomboxBlue"
}

return env
