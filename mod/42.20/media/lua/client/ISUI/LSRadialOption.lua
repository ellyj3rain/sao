-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
require 'ISUI/ISEmoteRadialMenu'
require 'ISAmbt/AmbtMng'

LS_AMcache['cmf'] = LS_AMcache['cmf'] or (not LS_AMcache['cmf_cached'] and LS_PatchUtils.hasCompatMod('cmf'))

if LS_AMcache['cmf'] then -- needed as cmf overrides vanilla functions
	require "RadialMenuAPI/EmoteMenuAPI"
end

local ISEmoteRadialMenu_fillMenu_old = ISEmoteRadialMenu.fillMenu
function ISEmoteRadialMenu:fillMenu(submenu)
	local ambtSO = SandboxVars.LSAmbt.Toggle or false
	if ambtSO then
		ISEmoteRadialMenu.menu['LSABT'] = {};
		ISEmoteRadialMenu.menu['LSABT'].name = getText('IGUI_LSAmbitions_RadialOption');
		ISEmoteRadialMenu.icons['LSABT'] = getTexture('media/ui/Ambitions/Ambitions_RO.png');
	end
	ISEmoteRadialMenu_fillMenu_old(self, submenu)
end

local old_ISEmoteRadialMenu_emote = ISEmoteRadialMenu.emote
function ISEmoteRadialMenu:emote(emote)
	--if string.sub(emote,1,string.len('LSABT'))=='LSABT' then
	if emote == "LSABT" then
		LSAmbtMng.AmbitionsMenu()
	else
		old_ISEmoteRadialMenu_emote(self, emote)
	end
end

--[[
local function addNewOption(text, texture, command, arg1, arg2, arg3, arg4, arg5, arg6)
	ISRadialMenu:addSlice(text, getTexture(texture), command, arg1, arg2, arg3, arg4, arg5, arg6)
end
]]--

