ComputerModSandbox = ComputerModSandbox or {}

ComputerModSandbox.defaults = {
    DiscSpawnChance = 14,
    GameDiscWeightPercent = 100,
    SystemDiscWeightPercent = 100,
    BlankDiscWeightPercent = 100,
    HackDiscWeightPercent = 100,
    PreinstalledGameChance = 60,
    PasswordChance = 34,
    FramePasswordNoteChance = 12,
    NearbyPasswordNoteChance = 18,
    HackRequiredElectricalLevel = 1,
    EmptyFolderChance = 28,
    FolderMagazineChance = 12,
    FolderNewspaperChance = 18,
    FolderVideoChance = 9,
    PaintFileChance = 10,
    ComponentSpawnChance = 6,
    FoundComputerBadPartChance = 18,
    FoundComputerBrokenPartChance = 1,
    ComponentWearRate = 100,
    EnableGameInstallVirus = true,
    GameInstallVirusChance = 8,
    EnableBoardApp = true,
    EnableChatApp = true,
    EnableCommerceApp = true,
    NetworkOutageOnPowerLoss = true,
    NetworkTerminalNeedsPower = true,
    MarketShopRefreshHours = 24,
    MarketJobRefreshHours = 24,
    MailAccountChance = 42,
    MailLoggedInChance = 55,
    SecretSiteHintChance = 28
}

local function getSandboxTable()
    if SandboxVars and SandboxVars.ComputerMod then
        return SandboxVars.ComputerMod
    end
    return nil
end

function ComputerModSandbox.getNumber(key, defaultValue)
    local sandbox = getSandboxTable()
    if sandbox and sandbox[key] ~= nil then
        local value = tonumber(sandbox[key])
        if value ~= nil then
            return value
        end
    end
    return defaultValue
end

function ComputerModSandbox.getPercent(key)
    local fallback = ComputerModSandbox.defaults[key] or 0
    local value = ComputerModSandbox.getNumber(key, fallback)
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

function ComputerModSandbox.getBool(key, defaultValue)
    local sandbox = getSandboxTable()
    local fallback = defaultValue
    if fallback == nil then fallback = ComputerModSandbox.defaults[key] end
    if sandbox and sandbox[key] ~= nil then
        local value = sandbox[key]
        return value == true or value == 1 or value == "true"
    end
    return fallback == true
end
