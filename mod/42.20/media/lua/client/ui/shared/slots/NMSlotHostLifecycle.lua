-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMSlotHostLifecycle = NMSlotHostLifecycle or {}

require "ui/shared/slots/NMDeviceUiSlotContract"

local installContextCache = require "ui/shared/slots/NMSlotHostContextCache"
local installFrameBuilder = require "ui/shared/slots/NMSlotHostFrameBuilder"
local installAuthority = require "ui/shared/slots/NMSlotHostAuthority"
local installDragLifecycle = require "ui/shared/slots/NMSlotHostDragLifecycle"
local installDispatch = require "ui/shared/slots/NMSlotHostDispatch"

installContextCache(NMSlotHostLifecycle)
installFrameBuilder(NMSlotHostLifecycle)
installAuthority(NMSlotHostLifecycle)
installDragLifecycle(NMSlotHostLifecycle)
installDispatch(NMSlotHostLifecycle)

return NMSlotHostLifecycle
