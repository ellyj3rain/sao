-- Adds vanilla-style rarity semantic presets for New Music spawn-rate doubles.
require "OptionScreens/SandboxOptions"

NMSandboxOptionsUX = NMSandboxOptionsUX or {}

local TARGET_SETTINGS = {
    ["NewMusic.CassettesSpawnRate"] = { title = "MediaLootRarity" },
    ["NewMusic.VinylRecordsSpawnRate"] = true,
    ["NewMusic.CDsSpawnRate"] = true,
    ["NewMusic.WalkmanSpawnRate"] = { title = "DeviceLootRarity" },
    ["NewMusic.BoomboxSpawnRate"] = true,
    ["NewMusic.CDPlayerSpawnRate"] = true,
    ["NewMusic.RecordPlayerSpawnRate"] = true,
    ["NewMusic.MusicalZombiesSpawnRate"] = { title = "ZombieLootRarity" },
}

local RARITY_ADVANCED_COMBO = {
    default = 4,
    values = {
        { name = "Sandbox_None", text = "0.0" },
        { name = "Sandbox_Insane", text = "0.05" },
        { name = "Sandbox_ExtremelyRare", text = "0.2" },
        { name = "Sandbox_Rare", text = "0.6" },
        { name = "Sandbox_Normal", text = "1.0" },
        { name = "Sandbox_Common", text = "2.0" },
        { name = "Sandbox_Abundant", text = "3.0" },
    },
}

local originalCreatePanel = SandboxOptionsScreen.createPanel

function SandboxOptionsScreen:createPanel(page)
    if page and type(page.settings) == "table" then
        for _, setting in ipairs(page.settings) do
            if setting and TARGET_SETTINGS[setting.name] then
                setting.advancedCombo = RARITY_ADVANCED_COMBO
                local rule = TARGET_SETTINGS[setting.name]
                if type(rule) == "table" and rule.title then
                    setting.title = rule.title
                end
            end
        end
    end
    return originalCreatePanel(self, page)
end

