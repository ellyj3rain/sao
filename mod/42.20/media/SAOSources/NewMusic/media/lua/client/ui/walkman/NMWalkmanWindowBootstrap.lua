require "ISUI/ISPanel"
require "ISUI/ISToolTip"
require "ui/shared/slots/NMSlotHostLifecycle"
require "ui/shared/host/NMDeviceUiHost"
require "ui/shared/host/NMFancyWindowChrome"
require "ui/shared/host/NMFancyDeviceUiScale"
local PortableWindowRegistry = require "ui/shared/host/NMPortableWindowRegistry"

_G.NMWalkmanWindow = _G.NMWalkmanWindow or {}
_G.NMWalkmanWindowEnv = _G.NMWalkmanWindowEnv or {}

local env = _G.NMWalkmanWindowEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end

env.NMWalkmanWindow = _G.NMWalkmanWindow
env.WalkmanWindow = env.WalkmanWindow or ISPanel:derive("NMWalkmanWindow")
env.windowsByPlayer = env.windowsByPlayer or {}
env.WindowRegistry = env.WindowRegistry or PortableWindowRegistry
env.pendingRestoreByPlayer = env.pendingRestoreByPlayer or {}
env.WALKMAN_UI_TEXTURES_BY_VARIANT = env.WALKMAN_UI_TEXTURES_BY_VARIANT or {}
env.UI_TEXTURES = env.UI_TEXTURES or {}

require "ui/walkman/NMWalkmanRenderState"

if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") == true then
    NMCore.logChannel(
        "ui_lifecycle",
        "ui_lifecycle_registry_bind",
        string.format(
            "uiFamily=walkman registryBound=%s registryTable=%s",
            tostring(env.WindowRegistry ~= nil),
            tostring(env.WindowRegistry)
        )
    )
end

return env
