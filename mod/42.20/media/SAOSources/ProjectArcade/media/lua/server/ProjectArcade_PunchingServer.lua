local function safeGetText(key)
    if getText then
        local ok, txt = pcall(getText, key)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

local function safeGetTextFmt(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

local function isMultiplayerGame()
    if isSinglePlayer then
        return not isSinglePlayer()
    end
    return true
end

local function PA_GetAnnouncementLangCode()
    local v = nil

    if getSandboxOptions then
        local so = getSandboxOptions()
        if so and so.getOptionByName then
            local opt = so:getOptionByName("ProjectArcade.AnnouncementLanguage")
            if opt and opt.getValue then
                v = opt:getValue()
            end
        end
    end

    if v == nil and SandboxVars and SandboxVars.ProjectArcade then
        v = SandboxVars.ProjectArcade.AnnouncementLanguage
    end

    if type(v) == "number" then
        if v == 2 then return "ES"
        elseif v == 3 then return "RU"
        else return "EN" end
    end

    if type(v) == "string" then
        local s = string.upper(v)
        if s == "2" or s == "SPANISH" or s == "ES" then return "ES" end
        if s == "3" or s == "RUSSIAN" or s == "RU" then return "RU" end
        return "EN"
    end

    return "EN"
end

local PA_ANNOUNCE_TEXT = {
    EN = {
        PunchingNewHighScore = "[Project Arcade] New Punching Machine high score: %s - %s!",
    },
    ES = {
        PunchingNewHighScore = "[Project Arcade] Nuevo record en la Punching Machine: %s - %s!",
    },
    RU = {
        PunchingNewHighScore = "[Project Arcade] Новый рекорд на боксерском автомате: %s - %s!",
    },
}

local function PA_AnnounceFmt(key, a, b)
    local lang = PA_GetAnnouncementLangCode()
    local tbl = PA_ANNOUNCE_TEXT[lang] or PA_ANNOUNCE_TEXT.EN
    local fmt = tbl[key] or (PA_ANNOUNCE_TEXT.EN and PA_ANNOUNCE_TEXT.EN[key]) or "%s"
    return string.format(fmt, tostring(a or ""), tostring(b or ""))
end

local function announcePunchingHighScore(playerName, score)
    if not isServer() then return end
    if not isMultiplayerGame() then return end
    if not sendServerCommand then return end

    local msg = PA_AnnounceFmt("PunchingNewHighScore", playerName, score)

    sendServerCommand("ProjectArcade", "PunchingAnnounceHighScore", { msg = msg })
end

local function prettifyName(s)
    if not s or s == "" then return "Jugador" end
    if not string.find(s, "%s") then
        s = string.gsub(s, "(%l)(%u)", "%1 %2")
        s = string.gsub(s, "(%a)(%d)", "%1 %2")
    end
    return s
end

local function isAdminPlayer(playerObj)
    if not playerObj then return false end
    if not playerObj.getAccessLevel then return false end

    local ok, access = pcall(playerObj.getAccessLevel, playerObj)
    if not ok then return false end

    return access ~= nil and tostring(access) == "admin"
end

local function updatePunchHighScoresServer(player, args)
    if not args then return end

    local score = tonumber(args.score) or 0
    if score < 0 then score = 0 end

    local isFemale = args.isFemale == true
    local name = prettifyName(tostring(args.name or "Jugador"))

    local g = ModData.getOrCreate("ProjectArcade")

    g.PA_Punch_HS_Female = tonumber(g.PA_Punch_HS_Female) or 0
    g.PA_Punch_HS_FemaleName = g.PA_Punch_HS_FemaleName or safeGetText("ContextMenu_ProjectArcade_None")

    g.PA_Punch_HS_Male = tonumber(g.PA_Punch_HS_Male) or 0
    g.PA_Punch_HS_MaleName = g.PA_Punch_HS_MaleName or safeGetText("ContextMenu_ProjectArcade_None")

    local changed = false

    if isFemale then
        if score > g.PA_Punch_HS_Female then
            g.PA_Punch_HS_Female = score
            g.PA_Punch_HS_FemaleName = name
            changed = true
        end
    else
        if score > g.PA_Punch_HS_Male then
            g.PA_Punch_HS_Male = score
            g.PA_Punch_HS_MaleName = name
            changed = true
        end
    end

    if changed and ModData.transmit then
        ModData.transmit("ProjectArcade")
    end

    if changed then
        announcePunchingHighScore(name, score)
    end

    if player and sendServerCommand then
        sendServerCommand(player, "ProjectArcade", "PunchingHSResult", {
            isHighscore = changed,
            showKind = isFemale and "female" or "male",
            score = score,
            name = name,
        })
    end
end

local function resetPunchHighScoresServer(player)
    local ok = false

    if isAdminPlayer(player) then
        local g = ModData.getOrCreate("ProjectArcade")

        g.PA_Punch_HS_Female = 0
        g.PA_Punch_HS_FemaleName = safeGetText("ContextMenu_ProjectArcade_None")

        g.PA_Punch_HS_Male = 0
        g.PA_Punch_HS_MaleName = safeGetText("ContextMenu_ProjectArcade_None")

        if ModData.transmit then
            ModData.transmit("ProjectArcade")
        end

        ok = true
    end

    if player and sendServerCommand then
        sendServerCommand(player, "ProjectArcade", "PunchingResetHSResult", {
            ok = ok
        })
    end
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ProjectArcade" then return end
	
	if command == "PunchingResetHS" then
        resetPunchHighScoresServer(player)
        return
    end

    if command == "PunchingUpdateHS" then
        updatePunchHighScoresServer(player, args)
        return
    end

    if command == "PunchingRequestHS" then
        if not isServer() or not sendServerCommand then return end

        local g = ModData.getOrCreate("ProjectArcade")

        local male = tonumber(g.PA_Punch_HS_Male) or 0
        local maleName = g.PA_Punch_HS_MaleName or safeGetText("ContextMenu_ProjectArcade_None")

        local fem = tonumber(g.PA_Punch_HS_Female) or 0
        local femName = g.PA_Punch_HS_FemaleName or safeGetText("ContextMenu_ProjectArcade_None")

        sendServerCommand(player, "ProjectArcade", "PunchingSendHighScores", {
            male = male,
            maleName = maleName,
            female = fem,
            femaleName = femName,
        })
        return
    end
end)
