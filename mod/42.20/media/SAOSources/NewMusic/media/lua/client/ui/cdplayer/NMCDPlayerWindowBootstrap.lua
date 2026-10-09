require "ISUI/ISPanel"
require "ui/shared/slots/NMSlotHostLifecycle"
require "ui/shared/host/NMDeviceUiHost"
require "ui/shared/host/NMFancyWindowChrome"
require "ui/shared/host/NMFancyDeviceUiScale"
local PortableWindowRegistry = require "ui/shared/host/NMPortableWindowRegistry"

_G.NMCDPlayerWindow = _G.NMCDPlayerWindow or {}
_G.NMCDPlayerWindowEnv = _G.NMCDPlayerWindowEnv or {}

local env = _G.NMCDPlayerWindowEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end

env.NMCDPlayerWindow = _G.NMCDPlayerWindow
env.CDPlayerWindow = env.CDPlayerWindow or ISPanel:derive("NMCDPlayerWindow")
env.windowsByPlayer = env.windowsByPlayer or {}
env.WindowRegistry = env.WindowRegistry or PortableWindowRegistry
env.pendingRestoreByPlayer = env.pendingRestoreByPlayer or {}
env.UI_TEXTURES = env.UI_TEXTURES or {}

require "ui/cdplayer/NMCDPlayerDisplayRenderState"

if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") == true then
    NMCore.logChannel(
        "ui_lifecycle",
        "ui_lifecycle_registry_bind",
        string.format(
            "uiFamily=cdplayer registryBound=%s registryTable=%s",
            tostring(env.WindowRegistry ~= nil),
            tostring(env.WindowRegistry)
        )
    )
end

return env
