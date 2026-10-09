-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_Sandbox"

ComputerModPasswordNotes = ComputerModPasswordNotes or {}
ComputerModPasswordNotes.passwords = {"1234", "2468", "1357", "2580", "1984", "1993", "2000", "0909", "1111", "4321", "8080", "2424"}

function ComputerModPasswordNotes.isComputerSpriteName(spriteName)
    local value = spriteName and string.lower(tostring(spriteName)) or ""
    return value == "appliances_com_01_72"
        or value == "appliances_com_01_73"
        or value == "appliances_com_01_74"
        or value == "appliances_com_01_75"
        or value == "appliances_com_01_76"
        or value == "appliances_com_01_77"
        or value == "appliances_com_01_78"
        or value == "appliances_com_01_79"
end

function ComputerModPasswordNotes.isComputerObject(object)
    if not object or not object.getSprite then return false end
    local sprite = object:getSprite()
    return ComputerModPasswordNotes.isComputerSpriteName(sprite and sprite.getName and sprite:getName() or nil)
end

function ComputerModPasswordNotes.randomPassword()
    return ComputerModPasswordNotes.passwords[ZombRand(#ComputerModPasswordNotes.passwords) + 1]
end

function ComputerModPasswordNotes.ensureComputerPassword(object)
    if not ComputerModPasswordNotes.isComputerObject(object) or not object.getModData then return nil end
    local data = object:getModData()
    if data.ComputerModNetworkTerminal == true then return nil end
    if data.ComputerModStartingHouseNoPasswordPending == true then
        data.ComputerModPasswordEnabled = false
        data.ComputerModPassword = nil
        return nil
    end
    if data.ComputerModPasswordEnabled == nil then
        data.ComputerModPasswordEnabled = ZombRand(100) < ComputerModSandbox.getPercent("PasswordChance")
    end
    if data.ComputerModPasswordEnabled == true and (not data.ComputerModPassword or data.ComputerModPassword == "") then
        data.ComputerModPassword = ComputerModPasswordNotes.randomPassword()
    elseif data.ComputerModPasswordEnabled ~= true then
        data.ComputerModPassword = nil
    end
    return data.ComputerModPassword
end
