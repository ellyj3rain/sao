require "SAO_PlayerCreatorUI"
require "OptionScreens/CharacterCreationMain"
require "OptionScreens/CoopCharacterCreationMain"

local C = SAO.Creator
local nativeWrapper, variantWrapper, coopWrapper

local function install()
    if CharacterCreationMain
        and type(CharacterCreationMain.onOptionMouseDown) == "function"
        and CharacterCreationMain.onOptionMouseDown ~= nativeWrapper then
        local previous = CharacterCreationMain.onOptionMouseDown
        nativeWrapper = function(self, clicked, x, y)
            if not clicked or clicked.internal ~= "NEXT" then
                return previous(self, clicked, x, y)
            end
            local main = MainScreen and MainScreen.instance
            -- Week One's native character button normally opens its variant
            -- page. TIYL also calls the hidden native PLAY button directly;
            -- route that call through the visible variant page so its scenario
            -- remains the player's choice.
            if main and not main.inGame and main.variantMain
                and self.variantButton
                and type(self.onOptionMouseDown2) == "function" then
                return self:onOptionMouseDown2(self.variantButton, x, y)
            end
            if C.beforeWorldTransition(self, function()
                return previous(self, clicked, x, y)
            end) then return end
            return previous(self, clicked, x, y)
        end
        CharacterCreationMain.onOptionMouseDown = nativeWrapper
    end

    if CharacterCreationMain
        and type(CharacterCreationMain.onOptionMouseDown2) == "function"
        and CharacterCreationMain.onOptionMouseDown2 ~= variantWrapper then
        local previous = CharacterCreationMain.onOptionMouseDown2
        variantWrapper = function(self, clicked, x, y)
            if not clicked or clicked.internal ~= "VARIANT" then
                return previous(self, clicked, x, y)
            end
            local main = MainScreen and MainScreen.instance
            if main and main.inGame then
                if C.beforeWorldTransition(self, function()
                    return previous(self, clicked, x, y)
                end) then return end
            end
            return previous(self, clicked, x, y)
        end
        CharacterCreationMain.onOptionMouseDown2 = variantWrapper
    end

    if CoopCharacterCreationMain
        and type(CoopCharacterCreationMain.onOptionMouseDown) == "function"
        and CoopCharacterCreationMain.onOptionMouseDown ~= coopWrapper then
        local previous = CoopCharacterCreationMain.onOptionMouseDown
        coopWrapper = function(self, clicked, x, y)
            if clicked and clicked.internal == "NEXT" then
                if C.beforeWorldTransition(self, function()
                    return previous(self, clicked, x, y)
                end) then return end
            end
            return previous(self, clicked, x, y)
        end
        CoopCharacterCreationMain.onOptionMouseDown = coopWrapper
    end

    local main = MainScreen and MainScreen.instance
    local native = main and main.charCreationMain
    if native then
        if native.playButton then native.playButton.onclick = nativeWrapper end
        if native.variantButton and variantWrapper then
            native.variantButton.onclick = variantWrapper
        end
    end
end

C.installNativeHooks = install
install()
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(install) end
if Events and Events.OnMainMenuEnter then
    Events.OnMainMenuEnter.Add(function()
        C.pending = nil
        C.unconfirmed = nil
        install()
    end)
end

return C
