require "ISUI/ISPanel"
require "ISUI/ISToolTip"
require "ui/shared/slots/NMSlotHostLifecycle"
require "ui/shared/host/NMDeviceUiHost"
require "ui/shared/host/NMFancyWindowChrome"
require "ui/shared/host/NMFancyDeviceUiScale"

local PortableWindowRegistry = require "ui/shared/host/NMPortableWindowRegistry"

_G.NMBoomboxWindow = _G.NMBoomboxWindow or {}
_G.NMBoomboxWindowEnv = _G.NMBoomboxWindowEnv or {}

local env = _G.NMBoomboxWindowEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end

env.NMBoomboxWindow = _G.NMBoomboxWindow
env.BoomboxWindow = env.BoomboxWindow or ISPanel:derive("NMBoomboxWindow")
env.windowsByPlayer = env.windowsByPlayer or {}
env.WindowRegistry = env.WindowRegistry or PortableWindowRegistry
env.pendingRestoreByPlayer = env.pendingRestoreByPlayer or {}
env.BOOMBOX_UI_TEXTURES_BY_VARIANT = env.BOOMBOX_UI_TEXTURES_BY_VARIANT or {}
env.UI_TEXTURES = env.UI_TEXTURES or {}

require "ui/boombox/NMBoomboxWindowConstants"
require "ui/boombox/NMBoomboxWindowHelpers"
require "ui/boombox/NMBoomboxWindowVariants"
require "ui/boombox/NMBoomboxWindowLayout"
require "ui/boombox/NMBoomboxWindowLid"
require "ui/boombox/NMBoomboxWindowContext"
require "ui/boombox/NMBoomboxWindowTransport"
require "ui/boombox/NMBoomboxWindowRender"
require "ui/boombox/NMBoomboxWindowInput"
require "ui/boombox/NMBoomboxWindowUpdate"
require "ui/boombox/NMBoomboxWindowPersistence"
require "ui/boombox/NMBoomboxWindowCore"

return env
