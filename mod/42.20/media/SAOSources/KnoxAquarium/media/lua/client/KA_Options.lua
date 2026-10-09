--[[ Knox Aquarium - client settings (Options, Mods, Knox Aquarium).

    Stored in Zomboid/ModOptions.ini by the game's own PZAPI.ModOptions, so it
    is per player, never in a save and never sent to a server. Removing the mod
    leaves nothing behind but that one line in ModOptions.ini.

    Reported on the Workshop: the Fish Tank entry on every right-click is
    distracting. It stays on by default - it is how the beta has always behaved -
    and this lets each player switch it off.
]]
require 'KA_Core'
local K = KnoxAquarium

K.options = K.options or {}
local O = K.options
O.DEFAULTS = {menuEverywhere = true}

function O.get(id)
    local value = O.DEFAULTS[id]
    local handle = O.handle
    if handle and handle.getOption then
        local option = handle:getOption(id)
        if option and option.getValue then
            local ok, v = pcall(function() return option:getValue() end)
            if ok and v ~= nil then value = v end
        end
    end
    return value
end

function O.register()
    if O.handle then return end
    local api = rawget(_G, 'PZAPI')
    if not (api and api.ModOptions and api.ModOptions.create) then return end
    local ok, opts = pcall(function()
        return api.ModOptions:create('KnoxAquarium', 'IGUI_KnoxAquarium_Options')
    end)
    if not ok or not opts then return end
    -- 0.14.1: guarded. PZAPI.ModOptions is the game's own API but not every
    -- build exposes the same signature, and this whole file runs at LOAD on the
    -- client - which a hosted game loads in the same process as its server. An
    -- uncaught throw here would take the boot down with it. Losing the tickbox
    -- only means the menu setting falls back to K.menuAlwaysShown.
    local added = pcall(function()
        opts:addTickBox('menuEverywhere', 'IGUI_KnoxAquarium_MenuEverywhere', O.DEFAULTS.menuEverywhere,
            'IGUI_KnoxAquarium_MenuEverywhere_tip')
    end)
    if not added then return end
    O.handle = opts
    -- The options screen only loads saved values when it is opened; load them
    -- now so the choice holds from the first right-click. save() is left to the
    -- options screen, which keeps every other mod's lines.
    pcall(function() api.ModOptions:load() end)
end

-- Whether the world menu shows its entry on every right-click. KA_Menu's
-- K.menuAlwaysShown is the fallback when the options API is not there.
function K.menuShownEverywhere()
    if O.handle then return O.get('menuEverywhere') == true end
    return K.menuAlwaysShown == true
end

-- 0.14.1: never let the options screen stop the mod loading.
pcall(O.register)
