require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISContextMenu"
require "ComputerMod_UI_Text"
require "ComputerMod_ErrorDialog"
require "ComputerMod_Localization"
require "ComputerMod_GameInput"
require "ComputerMod_GamepadUI"
require "ComputerMod_eLuaPong"
require "ComputerMod_eLuaSnake"
require "ComputerMod_eLuaMinesweeper"
require "ComputerMod_eLuaTetris"
require "ComputerMod_eLuaSpaceInvaders"
require "ComputerMod_eLuaDoom"
require "ComputerMod_eLuaRacer"
require "ComputerMod_eLuaFlappy"
require "ComputerMod_eLuaBreakout"
require "ComputerMod_eLuaAsteroids"
require "ComputerMod_eLuaFrogger"
require "ComputerMod_eLuaMissileCommand"
require "ComputerMod_eLuaLunarLander"
require "ComputerMod_eLuaCircuitRunner"
require "ComputerMod_eLuaMemoryMatch"
require "ComputerMod_eLuaStarPilot"
require "ComputerMod_eLuaCaveRunner"
require "ComputerMod_eLuaLightsOut"
require "ComputerMod_eLuaSignalMatch"
require "ComputerMod_eLuaBoxPush"
require "ComputerMod_eLuaTileSlide"
require "ComputerMod_eLuaPipeLink"
require "ComputerMod_eLuaCodeBreaker"
require "ComputerMod_eLuaOutbreakOps"
require "ComputerMod_MagazineData"
require "ComputerMod_ContentData"
require "ComputerMod_Sandbox"
require "ComputerMod_Components"
require "ComputerMod_PasswordNotes"
require "ComputerMod_Mail"
require "ComputerMod_Posts"
require "ComputerMod_Chat"
require "ComputerMod_Market"
require "ComputerMod_AccountRecovery"
require "ComputerMod_Network"
require "ComputerMod_Debug"
require "ComputerMod_SPActivity"
require "ComputerMod_ScreenGlow"
require "ComputerMod_Power"
require "ComputerMod_CD_Client"
require "ComputerMod_Components_Client"
require "ComputerMod_ComputerTypes"

ComputerScreenUI = ISPanel:derive("ComputerScreenUI")
ComputerScreenUI.instance = nil

if ComputerModInstallGamepadUI then
    ComputerModInstallGamepadUI(ComputerScreenUI)
end

if ComputerModUIText then
    ComputerModUIText.installPanelClass(ComputerScreenUI)
    local gamePanelClassNames = {
        "PZPongGame",
        "PZSnakeGame",
        "PZMinesweeperGame",
        "PZTetrisGame",
        "PZSpaceInvadersGame",
        "PZDoomGame",
        "PZRacerGame",
        "PZFlappyGame",
        "PZBreakoutGame",
        "PZAsteroidsGame",
        "PZFroggerGame",
        "PZMissileCommandGame",
        "PZLunarLanderGame",
        "PZCircuitRunnerGame",
        "PZMemoryMatchGame",
        "PZStarPilotGame",
        "PZCaveRunnerGame",
        "PZLightsOutGame",
        "PZSignalMatchGame",
        "PZBoxPushGame",
        "PZTileSlideGame",
        "PZPipeLinkGame",
        "PZCodeBreakerGame",
        "PZOutbreakOpsGame"
    }
    for i = 1, #gamePanelClassNames do
        ComputerModUIText.installPanelClass(_G[gamePanelClassNames[i]], 0.9)
    end
end

local UI_BASE_W = 649
local UI_BASE_H = 560
local UI_HD_W = 866
local UI_HD_H = 747
local UI_UHD_W = 1298
local UI_UHD_H = 1120

local DISPLAY_PROFILES = {
    standard = {
        name = "standard",
        texture = "media/textures/screen.png",
        uiW = UI_BASE_W,
        uiH = UI_BASE_H,
        frameScale = 1,
        contentScale = 1,
        screenX = 65,
        screenY = 70,
        screenW = 500,
        screenH = 346,
    },
    hd = {
        name = "hd",
        texture = "media/textures/screen_hd.png",
        uiW = UI_HD_W,
        uiH = UI_HD_H,
        frameScale = UI_HD_W / UI_BASE_W,
        contentScale = 1,
        screenX = 87,
        screenY = 93,
        screenW = 667,
        screenH = 462,
    },
    uhd = {
        name = "uhd",
        texture = "media/textures/screen_uhd.png",
        uiW = UI_UHD_W,
        uiH = UI_UHD_H,
        frameScale = UI_UHD_W / UI_BASE_W,
        contentScale = 1,
        screenX = 130,
        screenY = 140,
        screenW = 1000,
        screenH = 692,
    },
}

local function scaleRounded(value, scale)
    return math.max(1, math.floor((tonumber(value) or 0) * scale + 0.5))
end

local function cmText(key, fallback)
    local lookup = key
    local fallbackText = fallback or key
    if fallback == nil then
        lookup = "IGUI_ComputerMod_UI_" .. tostring(key):gsub("[^A-Za-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    end
    if getText then
        local ok, value = pcall(getText, lookup)
        if ok and value and value ~= lookup then
            return value
        end
    end
    return fallbackText
end

local function cloneDisplayProfile(profile)
    return {
        name = profile.name,
        texture = profile.texture,
        uiW = profile.uiW,
        uiH = profile.uiH,
        frameScale = profile.frameScale,
        contentScale = profile.contentScale,
        screenX = profile.screenX,
        screenY = profile.screenY,
        screenW = profile.screenW,
        screenH = profile.screenH,
    }
end

require "ComputerMod_FolderSystem"
if ComputerModInstallFolderSystem then
    ComputerModInstallFolderSystem(ComputerScreenUI)
end

local function styleRetroButton(btn)
    if ComputerModUIText then ComputerModUIText.installButton(btn) end
    btn.backgroundColor = {r=0.75, g=0.75, b=0.75, a=1}
    btn.textColor = {r=0, g=0, b=0, a=1}
    btn.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
end

local function styleIconButton(btn)
    if ComputerModUIText then ComputerModUIText.installButton(btn) end
    btn.backgroundColor = {r=0, g=0, b=0, a=0}
    btn.backgroundColorMouseOver = {r=0.8, g=0.8, b=0.8, a=0.15}
    btn.backgroundColorClicked = {r=0.8, g=0.8, b=0.8, a=0.16}
    btn.textColor = {r=0, g=0, b=0, a=0}
    btn.textColorMouseOver = {r=0, g=0, b=0, a=0}
    btn.borderColor = {r=0, g=0, b=0, a=0}
end

local function getGameClockText(use24Hour)
    local hour = 12
    local minute = 0
    local gameTime = nil

    if getGameTime then
        gameTime = getGameTime()
    end

    if gameTime then
        local okTimeOfDay, timeOfDay = pcall(function() return gameTime:getTimeOfDay() end)
        if okTimeOfDay and timeOfDay then
            hour = math.floor(timeOfDay)
            minute = math.floor((timeOfDay - hour) * 60 + 0.5)
        else
            local okHour, valueHour = pcall(function() return gameTime:getHour() end)
            local okMinute, valueMinute = pcall(function() return gameTime:getMinutes() end)
            if okHour and valueHour then hour = valueHour end
            if okMinute and valueMinute then minute = valueMinute end
        end
    end

    hour = math.floor(hour) % 24
    minute = math.floor(minute) % 60

    if use24Hour then
        return string.format("%02d:%02d", hour, minute)
    end

    local suffix = "AM"
    if hour >= 12 then suffix = "PM" end

    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end

    return string.format("%d:%02d %s", displayHour, minute, suffix)
end

local function getGameDateText(monthFirst)
    local day = 1
    local month = 7
    if getGameTime then
        local ok, gameTime = pcall(getGameTime)
        if ok and gameTime then
            local okDay, valueDay = pcall(function() return gameTime:getDay() end)
            local okMonth, valueMonth = pcall(function() return gameTime:getMonth() end)
            if okDay and valueDay then day = math.floor(valueDay) + 1 end
            if okMonth and valueMonth then month = math.floor(valueMonth) + 1 end
        end
    end
    if monthFirst then
        return string.format("%02d/%02d", month, day)
    end
    return string.format("%02d/%02d", day, month)
end

local bootMessages = {
    {time=4, text="Phoenix 486 BIOS Version 1.03", r=0.78, g=0.78, b=0.78},
    {time=9, text="CPU: Intel 486DX2-66 Compatible", r=0.78, g=0.78, b=0.78},
    {time=16, text="Base Memory Test: 640K OK", r=0.78, g=0.78, b=0.78},
    {time=24, text="Fixed Disk 0: CONNER 540MB", r=0.92, g=0.92, b=0.86},
    {time=32, text="ATAPI CD-ROM: 4X DRIVE", r=0.78, g=0.78, b=0.78},
    {time=40, text="Keyboard... Detected", r=0.78, g=0.78, b=0.78},
    {time=48, text="Booting from C:", r=0.92, g=0.92, b=0.86}
}

local browserSites = {
    ["knox-weather.net"] = {
        title = "Knox Weather Network",
        subtitle = "County radar and roadside forecasts",
        lines = {
            "Today: thin fog before noon, dry roads after 13:00.",
            "Louisville front drifting east.",
            "Power utility warning: weak lines near Muldraugh.",
            "Best travel window: 14:00 to 17:00."
        }
    },
    ["spiffo-fanclub.com"] = {
        title = "Spiffo Fan Club",
        subtitle = "Mascot gossip, merch leaks, diner rankings",
        lines = {
            "Weekly poll: best shake flavor is still vanilla cherry.",
            "Forum thread of the day: rare rooftop Spiffo signs.",
            "Upcoming meetup postponed after generator failure.",
            "Featured photo set: roadside diners of Knox County."
        }
    },
    ["triplepixel.arcade"] = {
        title = "Triple Pixel Arcade",
        subtitle = "Cabinet repair logs and scoreboards",
        lines = {
            "Top score in Neon Driver finally beaten.",
            "Tetris tournament signups close Friday.",
            "Repair blog: replacing coin switch assemblies.",
            "Wanted: spare CRT tube for Model 7 cabinet."
        }
    },
    ["classifieds-42.local"] = {
        title = "Classifieds 42",
        subtitle = "Neighborhood buy and sell board",
        lines = {
            "For sale: beige desktop tower, missing side panel.",
            "Wanted: working floppy drive and clean keyboard.",
            "Garage lot posted near Rosewood crossroads.",
            "Trade offer: comic box for portable radio."
        }
    },
    ["fossilmail.org"] = {
        title = "Fossil Mail",
        subtitle = "Slow inbox for slower people",
        lines = {
            "Inbox count: 3 unread.",
            "Subject: Re: monitor stand dimensions.",
            "Subject: diner receipts attached.",
            "Status: mail server lagging by 14 minutes."
        }
    },
    ["archive77.gov"] = {
        title = "Archive 77",
        subtitle = "Public records and scanned county bulletins",
        lines = {
            "Newly indexed: highway surveys from 1987.",
            "Microfilm room closed for maintenance.",
            "Popular search: county shelter maps.",
            "Digitization backlog reduced by 12 boxes."
        }
    },
    ["beigebox.net"] = {
        title = "BeigeBox Repair Net",
        subtitle = "Late-night computer repair notes and spare parts",
        lines = {
            "Stock alert: two clean 486 cases at the Dixie yard sale.",
            "Repair tip: tap the PSU only after unplugging it.",
            "Forum rumor: someone in March Ridge has spare SIMMs.",
            "Weekly rant: dust is the real enemy of beige hardware."
        }
    },
    ["rosewoodscanner.bbs"] = {
        title = "Rosewood Scanner BBS",
        subtitle = "Rumors, sirens and roadside chatter",
        lines = {
            "Caller says the south station lights stayed on all night.",
            "Bus depot line sounds dead after midnight.",
            "Keep one eye on the courthouse block this week.",
            "Unconfirmed: road flare smoke near the school lot."
        }
    },
    ["hamhock.cooking"] = {
        title = "Ham Hock Home Cooking",
        subtitle = "Recipes, diner gossip and kitchen bragging",
        lines = {
            "Pie poll leader: pecan, still undefeated.",
            "Pressure cooker guide updated after three angry letters.",
            "Truck stop review: biscuits excellent, coffee dangerous.",
            "Kitchen board says canned peaches fix almost anything."
        }
    },
    ["cavepaint.video"] = {
        title = "Cave Paint Video",
        subtitle = "Tiny clips, bad compression and stranger comments",
        lines = {
            "Trending: lawn chair race behind the feed store.",
            "Upload limit raised to thirty seconds. Use it wisely.",
            "Most discussed clip: mall fountain coin dive.",
            "Moderator note: stop mailing tapes covered in grease."
        }
    },
    ["ratemyshed.net"] = {
        title = "Rate My Shed",
        subtitle = "Exactly what it sounds like",
        lines = {
            "Shed of the week has indoor carpet and no shame.",
            "User barn_king gave every tool hut a seven out of ten.",
            "Debate ongoing: does a garage still count as a shed?",
            "Top advice: paint the door before judging the soul."
        }
    },
    ["videovault.bbs"] = {
        title = "Video Vault BBS",
        subtitle = "Tape rips and after-hours TV favorites",
        lines = {
            "Tonight's uploads are pulled from worn county tapes.",
            "Pick a title below to save a copy to Downloads.",
            "These files take longer to watch than papers or scans.",
            "Best enjoyed with the lights off and snacks nearby."
        }
    },
    ["knoxshare.bbs"] = {
        title = "KnoxShare BBS",
        subtitle = "Shareware games over dial-up",
        lines = {
            "Select a game package below.",
            "Downloads are saved as setup files.",
            "Leaving the screen keeps the transfer running.",
            "Turning the computer off cancels the transfer."
        }
    }
}

local browserSiteOrder = {
    "knox-weather.net",
    "spiffo-fanclub.com",
    "triplepixel.arcade",
    "classifieds-42.local",
    "fossilmail.org",
    "archive77.gov",
    "beigebox.net",
    "rosewoodscanner.bbs",
    "hamhock.cooking",
    "cavepaint.video",
    "ratemyshed.net",
    "videovault.bbs",
    "knoxshare.bbs"
}

local publicBrowserSiteOrder = {
    "knox-weather.net",
    "spiffo-fanclub.com",
    "triplepixel.arcade",
    "classifieds-42.local",
    "fossilmail.org",
    "archive77.gov",
    "beigebox.net",
    "rosewoodscanner.bbs",
    "hamhock.cooking",
    "cavepaint.video",
    "ratemyshed.net",
    "videovault.bbs",
    "knoxshare.bbs"
}

local desktopFilesTexture = getTexture("media/textures/files.PNG")
local desktopNoteTexture = getTexture("media/textures/Note.PNG")
local desktopBrowserTexture = getTexture("media/textures/browser.PNG")
local desktopCalculatorTexture = getTexture("media/textures/calculator.PNG")
local desktopFolderTexture = getTexture("media/textures/folder.PNG")
local desktopSettingsTexture = getTexture("media/textures/settings.png")
local cdTexture = getTexture("media/textures/cd.png")
local desktopMailTexture = getTexture("media/textures/mail.PNG")
local desktopChatTexture = getTexture("media/textures/chat.PNG")
local desktopTrashTexture = getTexture("media/textures/trashcan.PNG")
local desktopMusicTexture = getTexture("media/textures/musicplayer.PNG")
local desktopBoardTexture = getTexture("media/textures/board.png")
local desktopPaintTexture = getTexture("media/textures/paint.png")
local desktopMarketTexture = getTexture("media/textures/market.PNG")
local stickyNoteTexture = getTexture("media/textures/sticky_note.png")
local gamesPongTexture = getTexture("media/textures/ping-pong.png")
local gamesSnakeTexture = getTexture("media/textures/snake.png")
local gamesMinesTexture = getTexture("media/textures/Minesweeper.PNG")
local gamesTetrisTexture = getTexture("media/textures/tetris.png")
local gamesDoomTexture = getTexture("media/textures/Doom.png")
local gamesInvadersTexture = getTexture("media/textures/space-invaders.png")
local gamesRacerTexture = getTexture("media/textures/racing-game.png")
local gamesFlappyTexture = getTexture("media/textures/bird.png")
local gamesBreakoutTexture = getTexture("media/textures/breakout.png")
local gamesAsteroidsTexture = getTexture("media/textures/asteroid.png")
local gamesFroggerTexture = getTexture("media/textures/frogger.png")
local gamesMissileTexture = getTexture("media/textures/missile.png")
local gamesLanderTexture = getTexture("media/textures/lander.png")
local gamesCircuitTexture = getTexture("media/textures/circuit.png")
local gamesMemoryTexture = getTexture("media/textures/memory.png")
local gamesStarPilotTexture = getTexture("media/textures/starpilot.png")
local gamesCaveRunnerTexture = getTexture("media/textures/caverunner.png")
local gamesLightsOutTexture = gamesCircuitTexture
local gamesSignalMatchTexture = gamesMemoryTexture
local gamesBoxPushTexture = getTexture("media/textures/boxpush.png")
local gamesTileSlideTexture = getTexture("media/textures/tileslide.png")
local gamesPipeLinkTexture = getTexture("media/textures/pipelink.png")
local gamesCodeBreakerTexture = getTexture("media/textures/codebreaker.png")
local gamesOutbreakOpsTexture = getTexture("media/textures/outbreakops.png")
local startIconTexture = getTexture("media/textures/starticon.PNG")
local userTextures = {
    getTexture("media/textures/user1.png"),
    getTexture("media/textures/user2.png"),
    getTexture("media/textures/user3.png"),
    getTexture("media/textures/user4.png"),
    getTexture("media/textures/user5.png"),
    getTexture("media/textures/user6.png")
}

local easyComputerPasswords = {"1234", "2468", "1357", "2580", "1984", "1993", "2000", "0909", "1111", "4321", "8080", "2424"}
local periodComputerNames = {
    "Michael", "James", "Robert", "John", "David", "Mark", "Steven", "Brian", "Kevin", "Eric",
    "Lisa", "Jennifer", "Michelle", "Amanda", "Karen", "Susan", "Donna", "Sarah", "Heather", "Amy"
}
local backgroundPalettes = {
    {name = "Teal", r = 0.00, g = 0.50, b = 0.50},
    {name = "Gray", r = 0.32, g = 0.35, b = 0.38},
    {name = "Blue", r = 0.12, g = 0.34, b = 0.64},
    {name = "Olive", r = 0.34, g = 0.42, b = 0.20},
    {name = "Plum", r = 0.42, g = 0.24, b = 0.42},
    {name = "Brown", r = 0.42, g = 0.30, b = 0.18},
    {name = "Navy", r = 0.08, g = 0.12, b = 0.34},
    {name = "Wine", r = 0.40, g = 0.08, b = 0.16},
    {name = "Slate", r = 0.22, g = 0.28, b = 0.32},
    {name = "Forest", r = 0.10, g = 0.30, b = 0.18},
    {name = "Amber", r = 0.50, g = 0.36, b = 0.10}
}
local textSizeScales = {0.90, 1.00, 1.15, 1.30, 1.45}
local uiScaleOptions = {0, 1.00, 1.25, 1.50, 1.75, 2.00, 2.50}
local gameInstallOrder = {"pong", "snake", "minesweeper", "tetris", "space_invaders", "doom", "racer", "flappy", "breakout", "asteroids", "frogger", "missile", "lander", "circuit", "memory", "starpilot", "caverunner", "lightsout", "signalmatch", "boxpush", "tileslide", "pipelink", "codebreaker", "outbreakops"}
local gameInstallInfo = {
    os = {label = "PZ OS 3.1", disc = "PZ OS 3.1 CD", texture = nil, system = true, discSizeMB = 18},
    pong = {label = "Pong", disc = "Pong CD", texture = gamesPongTexture, discSizeMB = 8},
    snake = {label = "Snake", disc = "Snake CD", texture = gamesSnakeTexture, discSizeMB = 8},
    minesweeper = {label = "Minesweeper", disc = "Minesweeper CD", texture = gamesMinesTexture, discSizeMB = 8},
    tetris = {label = "Tetris", disc = "Tetris CD", texture = gamesTetrisTexture, discSizeMB = 8},
    space_invaders = {label = "Invaders", disc = "Invaders CD", texture = gamesInvadersTexture, discSizeMB = 8},
    doom = {label = "Doom", disc = "Doom CD", texture = gamesDoomTexture, discSizeMB = 8},
    racer = {label = "Road Race", disc = "Road Race CD", texture = gamesRacerTexture, discSizeMB = 8},
    flappy = {label = "Flappy Bird", disc = "Flappy Bird CD", texture = gamesFlappyTexture, discSizeMB = 8},
    breakout = {label = "Breakout", disc = "Breakout CD", texture = gamesBreakoutTexture, discSizeMB = 8},
    asteroids = {label = "Asteroids", disc = "Asteroids CD", texture = gamesAsteroidsTexture, discSizeMB = 8},
    frogger = {label = "Frogger", disc = "Frogger CD", texture = gamesFroggerTexture, discSizeMB = 8},
    missile = {label = "Missile", disc = "Missile Command CD", texture = gamesMissileTexture, discSizeMB = 8},
    lander = {label = "Lander", disc = "Lunar Lander CD", texture = gamesLanderTexture, discSizeMB = 8},
    circuit = {label = "Circuit Runner", disc = "Circuit Runner CD", texture = gamesCircuitTexture, discSizeMB = 8},
    memory = {label = "Memory Match", disc = "Memory Match CD", texture = gamesMemoryTexture, discSizeMB = 8},
    starpilot = {label = "Star Pilot", disc = "Star Pilot CD", texture = gamesStarPilotTexture, discSizeMB = 8},
    caverunner = {label = "Cave Runner", disc = "Cave Runner CD", texture = gamesCaveRunnerTexture, discSizeMB = 8},
    lightsout = {label = "Lights Out", disc = "Lights Out CD", texture = gamesLightsOutTexture, discSizeMB = 8},
    signalmatch = {label = "Signal Match", disc = "Signal Match CD", texture = gamesSignalMatchTexture, discSizeMB = 8},
    boxpush = {label = "Box Push", disc = "Box Push CD", texture = gamesBoxPushTexture, discSizeMB = 8},
    tileslide = {label = "Tile Slide", disc = "Tile Slide CD", texture = gamesTileSlideTexture, discSizeMB = 8},
    pipelink = {label = "Pipe Link", disc = "Pipe Link CD", texture = gamesPipeLinkTexture, discSizeMB = 8},
    codebreaker = {label = "Code Breaker", disc = "Code Breaker CD", texture = gamesCodeBreakerTexture, discSizeMB = 8},
    outbreakops = {label = "Outbreak Ops", disc = "Outbreak Ops CD", texture = gamesOutbreakOpsTexture, discSizeMB = 12},
    blank = {label = "Blank CD", disc = "Blank CD", texture = nil, blank = true, discSizeMB = 0},
    hack = {label = "Password Hack CD", disc = "Password Hack CD", texture = nil, utility = true, discSizeMB = 8},
    generic = {label = "Data CD", disc = "Data CD", texture = nil, generic = true, discSizeMB = 650}
}

local gameDownloadInfo = {
    pong = {sizeMB = 1.2, speedMBPerTick = 0.0040},
    snake = {sizeMB = 0.9, speedMBPerTick = 0.0045},
    minesweeper = {sizeMB = 0.7, speedMBPerTick = 0.0050},
    tetris = {sizeMB = 1.4, speedMBPerTick = 0.0038},
    space_invaders = {sizeMB = 2.2, speedMBPerTick = 0.0034},
    doom = {sizeMB = 7.5, speedMBPerTick = 0.0022},
    racer = {sizeMB = 3.8, speedMBPerTick = 0.0030},
    flappy = {sizeMB = 1.1, speedMBPerTick = 0.0042},
    breakout = {sizeMB = 1.3, speedMBPerTick = 0.0040},
    asteroids = {sizeMB = 1.8, speedMBPerTick = 0.0036},
    frogger = {sizeMB = 1.5, speedMBPerTick = 0.0038},
    missile = {sizeMB = 2.4, speedMBPerTick = 0.0033},
    lander = {sizeMB = 1.9, speedMBPerTick = 0.0035},
    circuit = {sizeMB = 2.1, speedMBPerTick = 0.0034},
    memory = {sizeMB = 1.0, speedMBPerTick = 0.0042},
    starpilot = {sizeMB = 2.6, speedMBPerTick = 0.0032},
    caverunner = {sizeMB = 1.7, speedMBPerTick = 0.0037},
    lightsout = {sizeMB = 0.8, speedMBPerTick = 0.0047},
    signalmatch = {sizeMB = 1.0, speedMBPerTick = 0.0043},
    boxpush = {sizeMB = 1.2, speedMBPerTick = 0.0041},
    tileslide = {sizeMB = 0.9, speedMBPerTick = 0.0045},
    pipelink = {sizeMB = 1.1, speedMBPerTick = 0.0042},
    codebreaker = {sizeMB = 1.2, speedMBPerTick = 0.0041},
    outbreakops = {sizeMB = 3.4, speedMBPerTick = 0.0031}
}
local gameDiscItems = {
    os = "ComputerMod.SystemCDPZOS",
    pong = "ComputerMod.GameCDPong",
    snake = "ComputerMod.GameCDSnake",
    minesweeper = "ComputerMod.GameCDMinesweeper",
    tetris = "ComputerMod.GameCDTetris",
    space_invaders = "ComputerMod.GameCDSpaceInvaders",
    doom = "ComputerMod.GameCDDoom",
    racer = "ComputerMod.GameCDRacer",
    flappy = "ComputerMod.GameCDFlappy",
    breakout = "ComputerMod.GameCDBreakout",
    asteroids = "ComputerMod.GameCDAsteroids",
    frogger = "ComputerMod.GameCDFrogger",
    missile = "ComputerMod.GameCDMissile",
    lander = "ComputerMod.GameCDLander",
    circuit = "ComputerMod.GameCDCircuit",
    memory = "ComputerMod.GameCDMemory",
    starpilot = "ComputerMod.GameCDStarPilot",
    caverunner = "ComputerMod.GameCDCaveRunner",
    lightsout = "ComputerMod.GameCDLightsOut",
    signalmatch = "ComputerMod.GameCDSignalMatch",
    boxpush = "ComputerMod.GameCDBoxPush",
    tileslide = "ComputerMod.GameCDTileSlide",
    pipelink = "ComputerMod.GameCDPipeLink",
    codebreaker = "ComputerMod.GameCDCodeBreaker",
    outbreakops = "ComputerMod.GameCDOutbreakOps",
    blank = "ComputerMod.BlankCD",
    hack = "ComputerMod.PasswordHackCD"
}

local function getComputerTimeStep()
    local multiplier = 1
    if getGameTime then
        local ok, gameTime = pcall(getGameTime)
        if ok and gameTime and gameTime.getMultiplier then
            local okMult, value = pcall(function() return gameTime:getMultiplier() end)
            if okMult and value and value > 0 then
                multiplier = value
            end
        end
    end
    return math.max(1, multiplier)
end

local function playComputerUISound(soundName)
    if not soundName or soundName == "" then return end
    if getSoundManager then
        pcall(function() getSoundManager():playUISound(soundName) end)
    end
end

local function getComputerWorldAgeHours()
    if getGameTime then
        local ok, gameTime = pcall(getGameTime)
        if ok and gameTime and gameTime.getWorldAgeHours then
            local okAge, value = pcall(function() return gameTime:getWorldAgeHours() end)
            if okAge and value then return value end
        end
    end
    return nil
end

local function addItemWithSavedName(inventory, fullType, savedName)
    if not inventory or not inventory.AddItem or not fullType then return end
    local item = nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local okCreate, created = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
        if okCreate and created then
            local okAdd = pcall(function() inventory:AddItem(created) end)
            if okAdd then item = created end
        end
    end
    if not item then
        local okAdd, added = pcall(function() return inventory:AddItem(fullType) end)
        if okAdd then item = added end
    end
    if item and savedName and savedName ~= "" and item.setName then
        pcall(function() item:setName(savedName) end)
    end
    if item and item.getModData and savedName and savedName ~= "" then
        item:getModData().ComputerModDiscLabel = savedName
    end
    return item
end

local function cloneDiscContents(contents)
    local copy = {}
    if type(contents) ~= "table" then return copy end
    for i = 1, #contents do
        local entry = contents[i]
        if type(entry) == "table" then
            local entryCopy = {}
            for k, v in pairs(entry) do
                if type(v) == "table" then
                    local nested = {}
                    for nk, nv in pairs(v) do
                        nested[nk] = nv
                    end
                    entryCopy[k] = nested
                else
                    entryCopy[k] = v
                end
            end
            copy[#copy + 1] = entryCopy
        end
    end
    return copy
end

local function returnDiscToPlayer(playerObj, inventory, fullType, savedName, contents)
    if not inventory or not fullType then return nil end
    local savedContents = cloneDiscContents(contents)
    if isClient and isClient() then return nil end
    local item = addItemWithSavedName(inventory, fullType, savedName)
    if item and item.getModData and type(savedContents) == "table" then
        item:getModData().ComputerModDiscContents = savedContents
    end
    if inventory.setDrawDirty then
        pcall(function() inventory:setDrawDirty(true) end)
    end
    if item and isClient and isClient() and sendAddItemToContainer then
        pcall(function() sendAddItemToContainer(inventory, item) end)
    end
    return item
end

local function isDebugModeEnabled(playerObj)
    local player = playerObj or getPlayer and getPlayer() or nil
    return ComputerModDebug and ComputerModDebug.isEnabled and ComputerModDebug.isEnabled(player) or false
end

local function isPlayerNearComputer(playerObj, computer)
    if not playerObj or not computer or not playerObj:getSquare() or not computer:getSquare() then return false end
    if playerObj:getZ() ~= computer:getZ() then return false end
    return math.abs(playerObj:getX() - computer:getX()) <= 2.6 and math.abs(playerObj:getY() - computer:getY()) <= 2.6
end

local function hasComputerPower(computer)
    return ComputerModPower and ComputerModPower.hasComputerPower and ComputerModPower.hasComputerPower(computer) or false
end

local function applyEntryColors(entry, bg, border, text)
    if not entry then return end
    entry.backgroundColor = bg
    entry.borderColor = border
    entry.textColor = text
    if entry.setTextRGBA then
        entry:setTextRGBA(text.r, text.g, text.b, text.a or 1)
    end
    if entry.setPlaceholderTextRGBA then
        entry:setPlaceholderTextRGBA(0.4, 0.4, 0.4, 1)
    end
end

ComputerModUIShared = {
    styleRetroButton = styleRetroButton,
    styleIconButton = styleIconButton,
    getGameClockText = getGameClockText,
    getGameDateText = getGameDateText,
    getComputerTimeStep = getComputerTimeStep,
    playComputerUISound = playComputerUISound,
    getComputerWorldAgeHours = getComputerWorldAgeHours,
    addItemWithSavedName = addItemWithSavedName,
    returnDiscToPlayer = returnDiscToPlayer,
    isDebugModeEnabled = isDebugModeEnabled,
    isPlayerNearComputer = isPlayerNearComputer,
    hasComputerPower = hasComputerPower,
    applyEntryColors = applyEntryColors,
    tr = cmText,
    bootMessages = bootMessages,
    browserSites = browserSites,
    browserSiteOrder = browserSiteOrder,
    publicBrowserSiteOrder = publicBrowserSiteOrder,
    desktopFilesTexture = desktopFilesTexture,
    desktopNoteTexture = desktopNoteTexture,
    desktopBrowserTexture = desktopBrowserTexture,
    desktopCalculatorTexture = desktopCalculatorTexture,
    desktopFolderTexture = desktopFolderTexture,
    desktopSettingsTexture = desktopSettingsTexture,
    cdTexture = cdTexture,
    desktopMailTexture = desktopMailTexture,
    desktopChatTexture = desktopChatTexture,
    desktopTrashTexture = desktopTrashTexture,
    desktopMusicTexture = desktopMusicTexture,
    desktopBoardTexture = desktopBoardTexture,
    desktopPaintTexture = desktopPaintTexture,
    desktopMarketTexture = desktopMarketTexture,
    stickyNoteTexture = stickyNoteTexture,
    gamesPongTexture = gamesPongTexture,
    gamesSnakeTexture = gamesSnakeTexture,
    gamesMinesTexture = gamesMinesTexture,
    gamesTetrisTexture = gamesTetrisTexture,
    gamesDoomTexture = gamesDoomTexture,
    gamesInvadersTexture = gamesInvadersTexture,
    gamesRacerTexture = gamesRacerTexture,
    gamesFlappyTexture = gamesFlappyTexture,
    gamesBreakoutTexture = gamesBreakoutTexture,
    gamesAsteroidsTexture = gamesAsteroidsTexture,
    gamesFroggerTexture = gamesFroggerTexture,
    gamesMissileTexture = gamesMissileTexture,
    gamesLanderTexture = gamesLanderTexture,
    gamesCircuitTexture = gamesCircuitTexture,
    gamesMemoryTexture = gamesMemoryTexture,
    gamesStarPilotTexture = gamesStarPilotTexture,
    gamesCaveRunnerTexture = gamesCaveRunnerTexture,
    gamesLightsOutTexture = gamesLightsOutTexture,
    gamesSignalMatchTexture = gamesSignalMatchTexture,
    gamesBoxPushTexture = gamesBoxPushTexture,
    gamesTileSlideTexture = gamesTileSlideTexture,
    gamesPipeLinkTexture = gamesPipeLinkTexture,
    gamesCodeBreakerTexture = gamesCodeBreakerTexture,
    gamesOutbreakOpsTexture = gamesOutbreakOpsTexture,
    startIconTexture = startIconTexture,
    userTextures = userTextures,
    easyComputerPasswords = easyComputerPasswords,
    periodComputerNames = periodComputerNames,
    backgroundPalettes = backgroundPalettes,
    textSizeScales = textSizeScales,
    uiScaleOptions = uiScaleOptions,
    gameInstallOrder = gameInstallOrder,
    gameInstallInfo = gameInstallInfo,
    gameDownloadInfo = gameDownloadInfo,
    gameDiscItems = gameDiscItems,
    measureText = ComputerModUIText and ComputerModUIText.measureText or nil,
    getTextLineHeight = ComputerModUIText and ComputerModUIText.getLineHeight or nil
}

require "ComputerMod_UI_State"
require "ComputerMod_UI_System"
require "ComputerMod_UI_Apps"
require "ComputerMod_UI_Lifecycle"
require "ComputerMod_UI_Render"

function ComputerScreenUI:initialise()
    ISPanel.initialise(self)
    self.bootTimer = 0
    self.bootStep = 0
    self.pongInstance = nil
    self.snakeInstance = nil
    self.minesweeperInstance = nil
    self.tetrisInstance = nil
    self.spaceInvadersInstance = nil
    self.doomInstance = nil
    self.racerInstance = nil
    self.flappyInstance = nil
    self.breakoutInstance = nil
    self.asteroidsInstance = nil
    self.froggerInstance = nil
    self.circuitInstance = nil
    self.memoryInstance = nil
    self.starPilotInstance = nil
    self.caveRunnerInstance = nil
    self.lightsOutInstance = nil
    self.signalMatchInstance = nil
    self.boxPushInstance = nil
    self.tileSlideInstance = nil
    self.pipeLinkInstance = nil
    self.codeBreakerInstance = nil
    self.outbreakOpsInstance = nil
    self.gameMusicID = nil
    self.gameMusicEmitter = nil
    self.currentView = "DESKTOP"
    self.calculatorDisplay = "0"
    self.calculatorStoredValue = nil
    self.calculatorOperator = nil
    self.calculatorResetDisplay = false
    self.passwordUnlocked = false
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    self.passwordHackHits = 0
    self.passwordHackLine = 0
    self.passwordHackDirection = 1
    self.passwordHackTarget = 0.5
    self.passwordHackSpeed = 0.028
    self.passwordHackSpaceWasDown = false
    self.fileNoticeText = nil
    self.fileNoticeTimer = 0
    self.downloadLastTransmitMs = nil
    self.resetInProgress = false
    self.resetTimer = 0
    self.noteSaveTick = 0
    self.lastSavedNoteText = ""
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.minimizedWindows = {}
    self.hoverX = -1
    self.hoverY = -1
    self.browserPage = nil
    self.browserLoading = false
    self.browserLoadProgress = 0
    self.browserPendingAddress = nil
    self.browserPendingPage = nil
    self.browserHistory = {}
    self.browserHistoryIndex = 0
    self.downloadGameScrollOffset = 0
    self.folderScrollOffset = 0
    self.marketShopScrollOffset = 0
    self.marketJobsScrollOffset = 0
    self.downloadSelection = "pong"
    self.installGameId = nil
    self.installStep = 1
    self.installInProgress = false
    self.installProgress = 0
    self.discWipeInProgress = false
    self.cdEjectPending = false
    self.discWipeTimer = 0
    self.desktopDrag = nil
    self.gameMoodTick = 0
    self.lastGameOutcomeState = nil
    self:ensureComputerMeta()
    if self.restorePreferredMailSession then self:restorePreferredMailSession() end
    if ComputerModUIText and ComputerModUIText.setInterfaceScale then
        ComputerModUIText.setInterfaceScale(self, self.contentScale or 1)
    end
    if self.applyComputerTextSize then self:applyComputerTextSize() end
    if self.blockComputerMovement then self:blockComputerMovement() end
    getSoundManager():playUISound("ComputerTurnOnOff")
end

function ComputerScreenUI:createChildren()
    self.backgroundColor = {r=0, g=0, b=0, a=0}
    self.borderColor = {r=0, g=0, b=0, a=0}

    local profile = self.displayProfileSpec or DISPLAY_PROFILES.standard
    self.screenX = profile.screenX or 83
    self.screenY = profile.screenY or 79
    self.screenWidth = profile.screenW or 474
    self.screenHeight = profile.screenH or 329

    self.windowX = self.screenX + 8
    self.windowY = self.screenY + 8
    self.windowW = self.screenWidth - 16
    self.windowH = self.screenHeight - 30
    self.titleH = 22
    self.statusH = 16
    self.clientX = self.windowX + 4
    self.clientY = self.windowY + self.titleH + 4
    self.clientW = self.windowW - 8
    self.clientH = self.windowH - self.titleH - self.statusH - 8

    self.closeButton = ISButton:new(self.screenX + self.screenWidth - 25, self.screenY + 5, 20, 20, "X", self, ComputerScreenUI.handleClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.backgroundColor = {r=0.8, g=0, b=0, a=1}
    self.closeButton.textColor = {r=1, g=1, b=1, a=1}
    self.closeButton:setVisible(false)
    self:addChild(self.closeButton)
    if ComputerModUIText then ComputerModUIText.installButton(self.closeButton) end

    self.minimizeButton = ISButton:new(self.screenX + self.screenWidth - 45, self.screenY + 5, 18, 20, "-", self, ComputerScreenUI.minimizeCurrentWindow)
    self.minimizeButton:initialise()
    self.minimizeButton.backgroundColor = {r=0.72, g=0.72, b=0.72, a=1}
    self.minimizeButton.textColor = {r=0, g=0, b=0, a=1}
    self.minimizeButton:setVisible(false)
    self:addChild(self.minimizeButton)
    if ComputerModUIText then ComputerModUIText.installButton(self.minimizeButton) end

    self.fileButton = ISButton:new(self.screenX + 18, self.screenY + 18, 58, 58, "", self, ComputerScreenUI.startFiles)
    self.fileButton:initialise()
    styleIconButton(self.fileButton)
    self.fileButton:setVisible(false)
    self:addChild(self.fileButton)

    self.notepadButton = ISButton:new(self.screenX + 94, self.screenY + 18, 58, 58, "", self, ComputerScreenUI.startNotepad)
    self.notepadButton:initialise()
    styleIconButton(self.notepadButton)
    self.notepadButton:setVisible(false)
    self:addChild(self.notepadButton)

    self.browserButton = ISButton:new(self.screenX + 170, self.screenY + 18, 58, 58, "", self, ComputerScreenUI.startBrowser)
    self.browserButton:initialise()
    styleIconButton(self.browserButton)
    self.browserButton:setVisible(false)
    self:addChild(self.browserButton)

    self.calculatorButton = ISButton:new(self.screenX + 246, self.screenY + 18, 58, 58, "", self, ComputerScreenUI.startCalculator)
    self.calculatorButton:initialise()
    styleIconButton(self.calculatorButton)
    self.calculatorButton:setVisible(false)
    self:addChild(self.calculatorButton)

    self.gamesMenuButton = ISButton:new(self.screenX + 322, self.screenY + 18, 58, 58, "", self, ComputerScreenUI.openGamesMenu)
    self.gamesMenuButton:initialise()
    styleIconButton(self.gamesMenuButton)
    self.gamesMenuButton:setVisible(false)
    self:addChild(self.gamesMenuButton)

    self.settingsDesktopButton = ISButton:new(self.screenX + 322, self.screenY + 96, 58, 58, "", self, ComputerScreenUI.openSettingsWindow)
    self.settingsDesktopButton:initialise()
    styleIconButton(self.settingsDesktopButton)
    self.settingsDesktopButton:setVisible(false)
    self:addChild(self.settingsDesktopButton)

    self.mailButton = ISButton:new(self.screenX + 246, self.screenY + 96, 58, 58, "", self, ComputerScreenUI.startMail)
    self.mailButton:initialise()
    styleIconButton(self.mailButton)
    self.mailButton:setVisible(false)
    self:addChild(self.mailButton)

    self.musicButton = ISButton:new(self.screenX + 170, self.screenY + 96, 58, 58, "", self, ComputerScreenUI.startMusicPlayer)
    self.musicButton:initialise()
    styleIconButton(self.musicButton)
    self.musicButton:setVisible(false)
    self:addChild(self.musicButton)

    self.postsButton = ISButton:new(self.screenX + 18, self.screenY + 96, 58, 58, "", self, ComputerScreenUI.startPostsBoard)
    self.postsButton:initialise()
    styleIconButton(self.postsButton)
    self.postsButton:setVisible(false)
    self:addChild(self.postsButton)

    self.trashButton = ISButton:new(self.screenX + 94, self.screenY + 96, 58, 58, "", self, ComputerScreenUI.openTrashFolder)
    self.trashButton:initialise()
    styleIconButton(self.trashButton)
    self.trashButton.internal = "trash"
    self.trashButton.onRightMouseDown = function(button, x, y)
        self.trashContextMenu = {x = button:getX() + x, y = button:getY() + y}
        return true
    end
    self.trashButton:setVisible(false)
    self:addChild(self.trashButton)

    self.pongButton = ISButton:new(self.screenX + 66, self.screenY + 74, 60, 74, "", self, ComputerScreenUI.startPong)
    self.pongButton:initialise()
    styleIconButton(self.pongButton)
    self.pongButton.internal = "pong"
    self.pongButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.pongButton:setVisible(false)
    self:addChild(self.pongButton)

    self.snakeButton = ISButton:new(self.screenX + 142, self.screenY + 74, 60, 74, "", self, ComputerScreenUI.startSnake)
    self.snakeButton:initialise()
    styleIconButton(self.snakeButton)
    self.snakeButton.internal = "snake"
    self.snakeButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.snakeButton:setVisible(false)
    self:addChild(self.snakeButton)

    self.minesweeperButton = ISButton:new(self.screenX + 218, self.screenY + 74, 60, 74, "", self, ComputerScreenUI.startMinesweeper)
    self.minesweeperButton:initialise()
    styleIconButton(self.minesweeperButton)
    self.minesweeperButton.internal = "minesweeper"
    self.minesweeperButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.minesweeperButton:setVisible(false)
    self:addChild(self.minesweeperButton)

    self.tetrisButton = ISButton:new(self.screenX + 294, self.screenY + 74, 60, 74, "", self, ComputerScreenUI.startTetris)
    self.tetrisButton:initialise()
    styleIconButton(self.tetrisButton)
    self.tetrisButton.internal = "tetris"
    self.tetrisButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.tetrisButton:setVisible(false)
    self:addChild(self.tetrisButton)

    self.spaceInvadersButton = ISButton:new(self.screenX + 104, self.screenY + 164, 60, 74, "", self, ComputerScreenUI.startSpaceInvaders)
    self.spaceInvadersButton:initialise()
    styleIconButton(self.spaceInvadersButton)
    self.spaceInvadersButton.internal = "space_invaders"
    self.spaceInvadersButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.spaceInvadersButton:setVisible(false)
    self:addChild(self.spaceInvadersButton)

    self.doomButton = ISButton:new(self.screenX + 196, self.screenY + 164, 60, 74, "", self, ComputerScreenUI.startDoom)
    self.doomButton:initialise()
    styleIconButton(self.doomButton)
    self.doomButton.internal = "doom"
    self.doomButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.doomButton:setVisible(false)
    self:addChild(self.doomButton)

    self.racerButton = ISButton:new(self.screenX + 272, self.screenY + 164, 60, 74, "", self, ComputerScreenUI.startRacer)
    self.racerButton:initialise()
    styleIconButton(self.racerButton)
    self.racerButton.internal = "racer"
    self.racerButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.racerButton:setVisible(false)
    self:addChild(self.racerButton)

    self.flappyButton = ISButton:new(self.screenX + 66, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startFlappy)
    self.flappyButton:initialise()
    styleIconButton(self.flappyButton)
    self.flappyButton.internal = "flappy"
    self.flappyButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.flappyButton:setVisible(false)
    self:addChild(self.flappyButton)

    self.breakoutButton = ISButton:new(self.screenX + 142, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startBreakout)
    self.breakoutButton:initialise()
    styleIconButton(self.breakoutButton)
    self.breakoutButton.internal = "breakout"
    self.breakoutButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.breakoutButton:setVisible(false)
    self:addChild(self.breakoutButton)

    self.asteroidsButton = ISButton:new(self.screenX + 218, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startAsteroids)
    self.asteroidsButton:initialise()
    styleIconButton(self.asteroidsButton)
    self.asteroidsButton.internal = "asteroids"
    self.asteroidsButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.asteroidsButton:setVisible(false)
    self:addChild(self.asteroidsButton)

    self.froggerButton = ISButton:new(self.screenX + 294, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startFrogger)
    self.froggerButton:initialise()
    styleIconButton(self.froggerButton)
    self.froggerButton.internal = "frogger"
    self.froggerButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.froggerButton:setVisible(false)
    self:addChild(self.froggerButton)

    self.missileButton = ISButton:new(self.screenX + 370, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startMissileCommand)
    self.missileButton:initialise()
    styleIconButton(self.missileButton)
    self.missileButton.internal = "missile"
    self.missileButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.missileButton:setVisible(false)
    self:addChild(self.missileButton)

    self.landerButton = ISButton:new(self.screenX + 446, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startLunarLander)
    self.landerButton:initialise()
    styleIconButton(self.landerButton)
    self.landerButton.internal = "lander"
    self.landerButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.landerButton:setVisible(false)
    self:addChild(self.landerButton)

    self.circuitButton = ISButton:new(self.screenX + 522, self.screenY + 254, 60, 74, "", self, ComputerScreenUI.startCircuitRunner)
    self.circuitButton:initialise()
    styleIconButton(self.circuitButton)
    self.circuitButton.internal = "circuit"
    self.circuitButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.circuitButton:setVisible(false)
    self:addChild(self.circuitButton)

    self.memoryButton = ISButton:new(self.screenX + 66, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startMemoryMatch)
    self.memoryButton:initialise()
    styleIconButton(self.memoryButton)
    self.memoryButton.internal = "memory"
    self.memoryButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.memoryButton:setVisible(false)
    self:addChild(self.memoryButton)

    self.starPilotButton = ISButton:new(self.screenX + 142, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startStarPilot)
    self.starPilotButton:initialise()
    styleIconButton(self.starPilotButton)
    self.starPilotButton.internal = "starpilot"
    self.starPilotButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.starPilotButton:setVisible(false)
    self:addChild(self.starPilotButton)

    self.caveRunnerButton = ISButton:new(self.screenX + 218, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startCaveRunner)
    self.caveRunnerButton:initialise()
    styleIconButton(self.caveRunnerButton)
    self.caveRunnerButton.internal = "caverunner"
    self.caveRunnerButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.caveRunnerButton:setVisible(false)
    self:addChild(self.caveRunnerButton)

    self.lightsOutButton = ISButton:new(self.screenX + 294, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startLightsOut)
    self.lightsOutButton:initialise()
    styleIconButton(self.lightsOutButton)
    self.lightsOutButton.internal = "lightsout"
    self.lightsOutButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.lightsOutButton:setVisible(false)
    self:addChild(self.lightsOutButton)

    self.signalMatchButton = ISButton:new(self.screenX + 370, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startSignalMatch)
    self.signalMatchButton:initialise()
    styleIconButton(self.signalMatchButton)
    self.signalMatchButton.internal = "signalmatch"
    self.signalMatchButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.signalMatchButton:setVisible(false)
    self:addChild(self.signalMatchButton)

    self.boxPushButton = ISButton:new(self.screenX + 446, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startBoxPush)
    self.boxPushButton:initialise()
    styleIconButton(self.boxPushButton)
    self.boxPushButton.internal = "boxpush"
    self.boxPushButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.boxPushButton:setVisible(false)
    self:addChild(self.boxPushButton)

    self.tileSlideButton = ISButton:new(self.screenX + 522, self.screenY + 344, 60, 74, "", self, ComputerScreenUI.startTileSlide)
    self.tileSlideButton:initialise()
    styleIconButton(self.tileSlideButton)
    self.tileSlideButton.internal = "tileslide"
    self.tileSlideButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.tileSlideButton:setVisible(false)
    self:addChild(self.tileSlideButton)

    self.pipeLinkButton = ISButton:new(self.screenX + 66, self.screenY + 434, 60, 74, "", self, ComputerScreenUI.startPipeLink)
    self.pipeLinkButton:initialise()
    styleIconButton(self.pipeLinkButton)
    self.pipeLinkButton.internal = "pipelink"
    self.pipeLinkButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.pipeLinkButton:setVisible(false)
    self:addChild(self.pipeLinkButton)

    self.codeBreakerButton = ISButton:new(self.screenX + 142, self.screenY + 434, 60, 74, "", self, ComputerScreenUI.startCodeBreaker)
    self.codeBreakerButton:initialise()
    styleIconButton(self.codeBreakerButton)
    self.codeBreakerButton.internal = "codebreaker"
    self.codeBreakerButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.codeBreakerButton:setVisible(false)
    self:addChild(self.codeBreakerButton)

    self.outbreakOpsButton = ISButton:new(self.screenX + 218, self.screenY + 434, 60, 74, "", self, ComputerScreenUI.startOutbreakOps)
    self.outbreakOpsButton:initialise()
    styleIconButton(self.outbreakOpsButton)
    self.outbreakOpsButton.internal = "outbreakops"
    self.outbreakOpsButton.onRightMouseDown = function(button, x, y) return self:openGameContextMenu(button.internal, button:getX() + x, button:getY() + y) end
    self.outbreakOpsButton:setVisible(false)
    self:addChild(self.outbreakOpsButton)

    self.backButton = ISButton:new(self.windowX + self.windowW - 20, self.windowY + 3, 17, 17, "X", self, ComputerScreenUI.backToDesktop)
    self.backButton:initialise()
    self.backButton.backgroundColor = {r=0.8, g=0, b=0, a=1}
    self.backButton.textColor = {r=1, g=1, b=1, a=1}
    self.backButton:setVisible(false)
    self:addChild(self.backButton)
    if ComputerModUIText then ComputerModUIText.installButton(self.backButton) end

    self.startButton = ISButton:new(self.screenX + 3, self.screenY + self.screenHeight - 24, 62, 22, "", self, ComputerScreenUI.toggleStartMenu)
    self.startButton:initialise()
    styleIconButton(self.startButton)
    self.startButton:setVisible(false)
    self:addChild(self.startButton)

    self.turnOffButton = ISButton:new(self.screenX + 6, self.screenY + self.screenHeight - 86, 100, 24, cmText("Turn Off"), self, ComputerScreenUI.shutdownComputer)
    self.turnOffButton:initialise()
    styleRetroButton(self.turnOffButton)
    self.turnOffButton:setVisible(false)
    self:addChild(self.turnOffButton)

    self.passwordSettingsButton = ISButton:new(self.screenX + 112, self.screenY + self.screenHeight - 86, 118, 24, cmText("Password"), self, ComputerScreenUI.openPasswordPanel)
    self.passwordSettingsButton:initialise()
    styleRetroButton(self.passwordSettingsButton)
    self.passwordSettingsButton:setVisible(false)
    self:addChild(self.passwordSettingsButton)

    self.settingsButton = ISButton:new(self.screenX + 6, self.screenY + self.screenHeight - 58, 100, 24, cmText("Settings"), self, ComputerScreenUI.openSettingsMenu)
    self.settingsButton:initialise()
    styleRetroButton(self.settingsButton)
    self.settingsButton:setVisible(false)
    self:addChild(self.settingsButton)

    self.muteMusicButton = ISButton:new(self.screenX + 112, self.screenY + self.screenHeight - 58, 118, 24, cmText("Music: On"), self, ComputerScreenUI.toggleMusicMute)
    self.muteMusicButton:initialise()
    styleRetroButton(self.muteMusicButton)
    self.muteMusicButton:setVisible(false)
    self:addChild(self.muteMusicButton)

    self.clockFormatButton = ISButton:new(self.screenX + 112, self.screenY + self.screenHeight - 30, 118, 24, cmText("Clock: 12H"), self, ComputerScreenUI.toggleClockFormat)
    self.clockFormatButton:initialise()
    styleRetroButton(self.clockFormatButton)
    self.clockFormatButton:setVisible(false)
    self:addChild(self.clockFormatButton)

    self.logOffButton = ISButton:new(self.screenX + 6, self.screenY + self.screenHeight - 114, 100, 24, cmText("Log Off"), self, ComputerScreenUI.logOffComputer)
    self.logOffButton:initialise()
    styleRetroButton(self.logOffButton)
    self.logOffButton:setVisible(false)
    self:addChild(self.logOffButton)

    self.internetOffButton = ISButton:new(self.screenX + 6, self.screenY + self.screenHeight - 142, 100, 24, cmText("Net Off"), self, ComputerScreenUI.debugDisconnectInternet)
    self.internetOffButton:initialise()
    styleRetroButton(self.internetOffButton)
    self.internetOffButton:setVisible(false)
    self:addChild(self.internetOffButton)

    self.internetOnButton = ISButton:new(self.screenX + 6, self.screenY + self.screenHeight - 142, 100, 24, cmText("Net On"), self, ComputerScreenUI.debugConnectInternet)
    self.internetOnButton:initialise()
    styleRetroButton(self.internetOnButton)
    self.internetOnButton:setVisible(false)
    self:addChild(self.internetOnButton)

    self.dateFormatButton = ISButton:new(self.clientX + 156, self.clientY + 96, 120, 24, cmText("Date: D/M"), self, ComputerScreenUI.toggleDateFormat)
    self.dateFormatButton:initialise()
    styleRetroButton(self.dateFormatButton)
    self.dateFormatButton:setVisible(false)
    self:addChild(self.dateFormatButton)

    self.debugModeButton = ISButton:new(self.clientX + 126, self.clientY + 196, 184, 24, cmText("Debug mode") .. ": " .. cmText("Disabled"), self, ComputerScreenUI.toggleComputerDebugMode)
    self.debugModeButton:initialise()
    styleRetroButton(self.debugModeButton)
    self.debugModeButton:setVisible(false)
    self:addChild(self.debugModeButton)

    self.usernameEntry = ISTextEntryBox:new("", self.clientX + 106, self.clientY + 52, 150, 24)
    self.usernameEntry:initialise()
    self.usernameEntry:instantiate()
    self.usernameEntry:setVisible(false)
    applyEntryColors(self.usernameEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.usernameEntry)

    self.saveUserButton = ISButton:new(self.clientX + 266, self.clientY + 52, 64, 24, cmText("Save"), self, ComputerScreenUI.saveUserSettings)
    self.saveUserButton:initialise()
    styleRetroButton(self.saveUserButton)
    self.saveUserButton:setVisible(false)
    self:addChild(self.saveUserButton)

    self.mailAddressEntry = ISTextEntryBox:new("", self.clientX + 106, self.clientY + 52, 176, 24)
    self.mailAddressEntry:initialise()
    self.mailAddressEntry:instantiate()
    self.mailAddressEntry:setVisible(false)
    applyEntryColors(self.mailAddressEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.mailAddressEntry)

    self.mailPasswordEntry = ISTextEntryBox:new("", self.clientX + 106, self.clientY + 86, 176, 24)
    self.mailPasswordEntry:initialise()
    self.mailPasswordEntry:instantiate()
    self.mailPasswordEntry:setVisible(false)
    applyEntryColors(self.mailPasswordEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.mailPasswordEntry)

    self.mailPrimaryButton = ISButton:new(self.clientX + 292, self.clientY + 52, 72, 24, cmText("Create"), self, ComputerScreenUI.handleMailPrimaryAction)
    self.mailPrimaryButton:initialise()
    styleRetroButton(self.mailPrimaryButton)
    self.mailPrimaryButton:setVisible(false)
    self:addChild(self.mailPrimaryButton)

    self.mailSecondaryButton = ISButton:new(self.clientX + 292, self.clientY + 86, 72, 24, cmText("Login"), self, ComputerScreenUI.handleMailSecondaryAction)
    self.mailSecondaryButton:initialise()
    styleRetroButton(self.mailSecondaryButton)
    self.mailSecondaryButton:setVisible(false)
    self:addChild(self.mailSecondaryButton)

    self.mailLogoutButton = ISButton:new(self.clientX + 286, self.clientY + 12, 78, 20, cmText("Log Out"), self, ComputerScreenUI.logOutMail)
    self.mailLogoutButton:initialise()
    styleRetroButton(self.mailLogoutButton)
    self.mailLogoutButton:setVisible(false)
    self:addChild(self.mailLogoutButton)

    self.mailComposeButton = ISButton:new(self.clientX + 10, self.clientY + 12, 64, 20, cmText("Write"), self, ComputerScreenUI.startMailCompose)
    self.mailComposeButton:initialise()
    styleRetroButton(self.mailComposeButton)
    self.mailComposeButton:setVisible(false)
    self:addChild(self.mailComposeButton)

    self.mailReplyButton = ISButton:new(self.clientX + 80, self.clientY + 12, 64, 20, cmText("Reply"), self, ComputerScreenUI.replyToSelectedMail)
    self.mailReplyButton:initialise()
    styleRetroButton(self.mailReplyButton)
    self.mailReplyButton:setVisible(false)
    self:addChild(self.mailReplyButton)

    self.mailDeleteButton = ISButton:new(self.clientX + 150, self.clientY + 12, 64, 20, cmText("Delete"), self, ComputerScreenUI.deleteSelectedMail)
    self.mailDeleteButton:initialise()
    styleRetroButton(self.mailDeleteButton)
    self.mailDeleteButton:setVisible(false)
    self:addChild(self.mailDeleteButton)

    self.mailRecoveryLinkButton = ISButton:new(self.clientX + self.clientW - 130, self.clientY + 34, 120, 20, cmText("Open reset link"), self, ComputerScreenUI.openSelectedMailRecoveryLink)
    self.mailRecoveryLinkButton:initialise()
    styleRetroButton(self.mailRecoveryLinkButton)
    self.mailRecoveryLinkButton:setVisible(false)
    self:addChild(self.mailRecoveryLinkButton)

    self.mailSendButton = ISButton:new(self.clientX + 292, self.clientY + 12, 72, 20, cmText("Send"), self, ComputerScreenUI.sendComposedMail)
    self.mailSendButton:initialise()
    styleRetroButton(self.mailSendButton)
    self.mailSendButton:setVisible(false)
    self:addChild(self.mailSendButton)

    self.mailCancelButton = ISButton:new(self.clientX + 214, self.clientY + 12, 72, 20, cmText("Cancel"), self, ComputerScreenUI.cancelMailCompose)
    self.mailCancelButton:initialise()
    styleRetroButton(self.mailCancelButton)
    self.mailCancelButton:setVisible(false)
    self:addChild(self.mailCancelButton)

    self.mailToEntry = ISTextEntryBox:new("", self.clientX + 86, self.clientY + 40, 278, 22)
    self.mailToEntry:initialise()
    self.mailToEntry:instantiate()
    self.mailToEntry:setVisible(false)
    applyEntryColors(self.mailToEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.mailToEntry)

    self.mailSubjectEntry = ISTextEntryBox:new("", self.clientX + 86, self.clientY + 68, 278, 22)
    self.mailSubjectEntry:initialise()
    self.mailSubjectEntry:instantiate()
    self.mailSubjectEntry:setVisible(false)
    applyEntryColors(self.mailSubjectEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.mailSubjectEntry)

    self.mailBodyEntry = ISTextEntryBox:new("", self.clientX + 10, self.clientY + 98, self.clientW - 20, self.clientH - 108)
    self.mailBodyEntry:initialise()
    self.mailBodyEntry:instantiate()
    if self.mailBodyEntry.setMultipleLine then self.mailBodyEntry:setMultipleLine(true) end
    if self.mailBodyEntry.setMultipleLines then self.mailBodyEntry:setMultipleLines(true) end
    if self.mailBodyEntry.setWantKeyEvents then self.mailBodyEntry:setWantKeyEvents(true) end
    if self.mailBodyEntry.javaObject and self.mailBodyEntry.javaObject.setMultipleLine then
        self.mailBodyEntry.javaObject:setMultipleLine(true)
    end
    if self.mailBodyEntry.javaObject and self.mailBodyEntry.javaObject.setMultipleLines then
        self.mailBodyEntry.javaObject:setMultipleLines(true)
    end
    if self.mailBodyEntry.javaObject and self.mailBodyEntry.javaObject.setEditable then
        self.mailBodyEntry.javaObject:setEditable(true)
    end
    if self.mailBodyEntry.javaObject and self.mailBodyEntry.javaObject.setMaxLines then
        self.mailBodyEntry.javaObject:setMaxLines(256)
    end
    if self.mailBodyEntry.addScrollBars then
        self.mailBodyEntry:addScrollBars()
    end
    self.mailBodyEntry:setVisible(false)
    applyEntryColors(self.mailBodyEntry, {r=0.96, g=0.96, b=0.92, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.mailBodyEntry)

    self.chatUserEntry = ISTextEntryBox:new("", self.clientX + 122, self.clientY + 52, 176, 24)
    self.chatUserEntry:initialise()
    self.chatUserEntry:instantiate()
    self.chatUserEntry:setVisible(false)
    applyEntryColors(self.chatUserEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.chatUserEntry)

    self.chatPasswordEntry = ISTextEntryBox:new("", self.clientX + 122, self.clientY + 86, 176, 24)
    self.chatPasswordEntry:initialise()
    self.chatPasswordEntry:instantiate()
    self.chatPasswordEntry:setVisible(false)
    applyEntryColors(self.chatPasswordEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.chatPasswordEntry)

    self.chatRecoveryEmailEntry = ISTextEntryBox:new("", self.clientX + 122, self.clientY + 120, 176, 24)
    self.chatRecoveryEmailEntry:initialise()
    self.chatRecoveryEmailEntry:instantiate()
    self.chatRecoveryEmailEntry:setVisible(false)
    applyEntryColors(self.chatRecoveryEmailEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.chatRecoveryEmailEntry)

    self.chatPrimaryButton = ISButton:new(self.clientX + 302, self.clientY + 120, 72, 24, cmText("Create"), self, ComputerScreenUI.handleChatPrimaryAction)
    self.chatPrimaryButton:initialise()
    styleRetroButton(self.chatPrimaryButton)
    self.chatPrimaryButton:setVisible(false)
    self:addChild(self.chatPrimaryButton)

    self.chatSecondaryButton = ISButton:new(self.clientX + 302, self.clientY + 86, 72, 24, cmText("Login"), self, ComputerScreenUI.handleChatSecondaryAction)
    self.chatSecondaryButton:initialise()
    styleRetroButton(self.chatSecondaryButton)
    self.chatSecondaryButton:setVisible(false)
    self:addChild(self.chatSecondaryButton)

    self.chatForgotButton = ISButton:new(self.clientX + 122, self.clientY + 154, 144, 22, cmText("Forgot password?"), self, ComputerScreenUI.requestChatPasswordReset)
    self.chatForgotButton:initialise()
    styleRetroButton(self.chatForgotButton)
    self.chatForgotButton:setVisible(false)
    self:addChild(self.chatForgotButton)

    self.chatResetPasswordButton = ISButton:new(self.clientX + 302, self.clientY + 86, 116, 24, cmText("Reset password"), self, ComputerScreenUI.submitChatPasswordReset)
    self.chatResetPasswordButton:initialise()
    styleRetroButton(self.chatResetPasswordButton)
    self.chatResetPasswordButton:setVisible(false)
    self:addChild(self.chatResetPasswordButton)

    self.chatLogoutButton = ISButton:new(self.clientX + 286, self.clientY + 12, 78, 20, cmText("Log Out"), self, ComputerScreenUI.logOutChat)
    self.chatLogoutButton:initialise()
    styleRetroButton(self.chatLogoutButton)
    self.chatLogoutButton:setVisible(false)
    self:addChild(self.chatLogoutButton)

    self.chatAddButton = ISButton:new(self.clientX + 10, self.clientY + 12, 60, 20, cmText("Add"), self, ComputerScreenUI.startChatRequestMode)
    self.chatAddButton:initialise()
    styleRetroButton(self.chatAddButton)
    self.chatAddButton:setVisible(false)
    self:addChild(self.chatAddButton)

    self.chatAcceptButton = ISButton:new(self.clientX + 76, self.clientY + 12, 68, 20, cmText("Accept"), self, ComputerScreenUI.acceptSelectedChatRequest)
    self.chatAcceptButton:initialise()
    styleRetroButton(self.chatAcceptButton)
    self.chatAcceptButton:setVisible(false)
    self:addChild(self.chatAcceptButton)

    self.chatCancelButton = ISButton:new(self.clientX + self.clientW - 164, self.clientY + 12, 70, 20, cmText("Cancel"), self, ComputerScreenUI.cancelChatRequestMode)
    self.chatCancelButton:initialise()
    styleRetroButton(self.chatCancelButton)
    self.chatCancelButton:setVisible(false)
    self:addChild(self.chatCancelButton)

    self.chatRequestEntry = ISTextEntryBox:new("", self.clientX + 84, self.clientY + 40, 180, 24)
    self.chatRequestEntry:initialise()
    self.chatRequestEntry:instantiate()
    self.chatRequestEntry:setVisible(false)
    applyEntryColors(self.chatRequestEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.chatRequestEntry)

    self.chatRequestSendButton = ISButton:new(self.clientX + self.clientW - 86, self.clientY + 40, 78, 24, cmText("Send"), self, ComputerScreenUI.sendChatRequest)
    self.chatRequestSendButton:initialise()
    styleRetroButton(self.chatRequestSendButton)
    self.chatRequestSendButton:setVisible(false)
    self:addChild(self.chatRequestSendButton)

    self.chatMessageEntry = ISTextEntryBox:new("", self.clientX + 196, self.clientY + self.clientH - 72, self.clientW - 284, 56)
    self.chatMessageEntry:initialise()
    self.chatMessageEntry:instantiate()
    if self.chatMessageEntry.setMultipleLine then self.chatMessageEntry:setMultipleLine(true) end
    if self.chatMessageEntry.setMultipleLines then self.chatMessageEntry:setMultipleLines(true) end
    if self.chatMessageEntry.setWantKeyEvents then self.chatMessageEntry:setWantKeyEvents(true) end
    if self.chatMessageEntry.javaObject and self.chatMessageEntry.javaObject.setMultipleLine then
        self.chatMessageEntry.javaObject:setMultipleLine(true)
    end
    if self.chatMessageEntry.javaObject and self.chatMessageEntry.javaObject.setMultipleLines then
        self.chatMessageEntry.javaObject:setMultipleLines(true)
    end
    if self.chatMessageEntry.javaObject and self.chatMessageEntry.javaObject.setEditable then
        self.chatMessageEntry.javaObject:setEditable(true)
    end
    if self.chatMessageEntry.javaObject and self.chatMessageEntry.javaObject.setMaxLines then
        self.chatMessageEntry.javaObject:setMaxLines(8)
    end
    if self.chatMessageEntry.addScrollBars then
        self.chatMessageEntry:addScrollBars()
    end
    self.chatMessageEntry:setVisible(false)
    applyEntryColors(self.chatMessageEntry, {r=0.96, g=0.96, b=0.92, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.chatMessageEntry)

    self.chatSendButton = ISButton:new(self.clientX + self.clientW - 78, self.clientY + self.clientH - 40, 68, 24, cmText("Send"), self, ComputerScreenUI.sendChatMessage)
    self.chatSendButton:initialise()
    styleRetroButton(self.chatSendButton)
    self.chatSendButton:setVisible(false)
    self:addChild(self.chatSendButton)

    self.postsNameEntry = ISTextEntryBox:new("", self.clientX + 56, self.clientY + 36, 120, 22)
    self.postsNameEntry:initialise()
    self.postsNameEntry:instantiate()
    self.postsNameEntry:setVisible(false)
    applyEntryColors(self.postsNameEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.postsNameEntry)

    self.postsBodyEntry = ISTextEntryBox:new("", self.clientX + 10, self.clientY + 66, self.clientW - 94, 52)
    self.postsBodyEntry:initialise()
    self.postsBodyEntry:instantiate()
    if self.postsBodyEntry.setMultipleLine then self.postsBodyEntry:setMultipleLine(true) end
    if self.postsBodyEntry.setMultipleLines then self.postsBodyEntry:setMultipleLines(true) end
    if self.postsBodyEntry.setWantKeyEvents then self.postsBodyEntry:setWantKeyEvents(true) end
    if self.postsBodyEntry.javaObject and self.postsBodyEntry.javaObject.setMultipleLine then
        self.postsBodyEntry.javaObject:setMultipleLine(true)
    end
    if self.postsBodyEntry.javaObject and self.postsBodyEntry.javaObject.setMultipleLines then
        self.postsBodyEntry.javaObject:setMultipleLines(true)
    end
    if self.postsBodyEntry.javaObject and self.postsBodyEntry.javaObject.setEditable then
        self.postsBodyEntry.javaObject:setEditable(true)
    end
    if self.postsBodyEntry.javaObject and self.postsBodyEntry.javaObject.setMaxLines then
        self.postsBodyEntry.javaObject:setMaxLines(24)
    end
    if self.postsBodyEntry.addScrollBars then
        self.postsBodyEntry:addScrollBars()
    end
    self.postsBodyEntry:setVisible(false)
    applyEntryColors(self.postsBodyEntry, {r=0.96, g=0.96, b=0.92, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.postsBodyEntry)

    self.postsSendButton = ISButton:new(self.clientX + self.clientW - 76, self.clientY + 36, 66, 22, cmText("Post"), self, ComputerScreenUI.submitBoardPost)
    self.postsSendButton:initialise()
    styleRetroButton(self.postsSendButton)
    self.postsSendButton:setVisible(false)
    self:addChild(self.postsSendButton)

    self.marketUserEntry = ISTextEntryBox:new("", self.clientX + 122, self.clientY + 52, 176, 24)
    self.marketUserEntry:initialise()
    self.marketUserEntry:instantiate()
    self.marketUserEntry:setVisible(false)
    applyEntryColors(self.marketUserEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.marketUserEntry)

    self.marketPasswordEntry = ISTextEntryBox:new("", self.clientX + 122, self.clientY + 86, 176, 24)
    self.marketPasswordEntry:initialise()
    self.marketPasswordEntry:instantiate()
    self.marketPasswordEntry:setVisible(false)
    applyEntryColors(self.marketPasswordEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.marketPasswordEntry)

    self.marketRecoveryEmailEntry = ISTextEntryBox:new("", self.clientX + 122, self.clientY + 144, 176, 24)
    self.marketRecoveryEmailEntry:initialise()
    self.marketRecoveryEmailEntry:instantiate()
    self.marketRecoveryEmailEntry:setVisible(false)
    applyEntryColors(self.marketRecoveryEmailEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.marketRecoveryEmailEntry)

    self.marketPrimaryButton = ISButton:new(self.clientX + 302, self.clientY + 144, 72, 24, cmText("Create"), self, ComputerScreenUI.handleMarketPrimaryAction)
    self.marketPrimaryButton:initialise()
    styleRetroButton(self.marketPrimaryButton)
    self.marketPrimaryButton:setVisible(false)
    self:addChild(self.marketPrimaryButton)

    self.marketSecondaryButton = ISButton:new(self.clientX + 302, self.clientY + 86, 72, 24, cmText("Login"), self, ComputerScreenUI.handleMarketSecondaryAction)
    self.marketSecondaryButton:initialise()
    styleRetroButton(self.marketSecondaryButton)
    self.marketSecondaryButton:setVisible(false)
    self:addChild(self.marketSecondaryButton)

    self.marketForgotButton = ISButton:new(self.clientX + 122, self.clientY + 178, 144, 22, cmText("Forgot password?"), self, ComputerScreenUI.requestMarketPasswordReset)
    self.marketForgotButton:initialise()
    styleRetroButton(self.marketForgotButton)
    self.marketForgotButton:setVisible(false)
    self:addChild(self.marketForgotButton)

    self.marketResetPasswordButton = ISButton:new(self.clientX + 302, self.clientY + 110, 116, 24, cmText("Reset password"), self, ComputerScreenUI.submitMarketPasswordReset)
    self.marketResetPasswordButton:initialise()
    styleRetroButton(self.marketResetPasswordButton)
    self.marketResetPasswordButton:setVisible(false)
    self:addChild(self.marketResetPasswordButton)

    self.marketShopButton = ISButton:new(self.clientX + 10, self.clientY + 12, 66, 20, cmText("Shop"), self, ComputerScreenUI.showMarketShop)
    self.marketShopButton:initialise()
    styleRetroButton(self.marketShopButton)
    self.marketShopButton:setVisible(false)
    self:addChild(self.marketShopButton)

    self.marketJobsButton = ISButton:new(self.clientX + 82, self.clientY + 12, 66, 20, cmText("Jobs"), self, ComputerScreenUI.showMarketJobs)
    self.marketJobsButton:initialise()
    styleRetroButton(self.marketJobsButton)
    self.marketJobsButton:setVisible(false)
    self:addChild(self.marketJobsButton)

    self.marketDebugMoneyButton = ISButton:new(self.clientX + 154, self.clientY + 12, 90, 20, "+$1000", self, ComputerScreenUI.grantMarketDebugMoney)
    self.marketDebugMoneyButton:initialise()
    styleRetroButton(self.marketDebugMoneyButton)
    self.marketDebugMoneyButton:setVisible(false)
    self:addChild(self.marketDebugMoneyButton)

    self.marketResetShopButton = ISButton:new(self.clientX + 250, self.clientY + 12, 78, 20, cmText("Reset Shop"), self, ComputerScreenUI.resetMarketShop)
    self.marketResetShopButton:initialise()
    styleRetroButton(self.marketResetShopButton)
    self.marketResetShopButton:setVisible(false)
    self:addChild(self.marketResetShopButton)

    self.marketResetJobsButton = ISButton:new(self.clientX + 334, self.clientY + 12, 78, 20, cmText("Reset Jobs"), self, ComputerScreenUI.resetMarketJobs)
    self.marketResetJobsButton:initialise()
    styleRetroButton(self.marketResetJobsButton)
    self.marketResetJobsButton:setVisible(false)
    self:addChild(self.marketResetJobsButton)

    self.marketLogoutButton = ISButton:new(self.clientX + self.clientW - 86, self.clientY + 12, 78, 20, cmText("Log Out"), self, ComputerScreenUI.logOutMarket)
    self.marketLogoutButton:initialise()
    styleRetroButton(self.marketLogoutButton)
    self.marketLogoutButton:setVisible(false)
    self:addChild(self.marketLogoutButton)

    self.folderNameEntry = ISTextEntryBox:new("", self.clientX + 30, self.clientY + 74, 240, 24)
    self.folderNameEntry:initialise()
    self.folderNameEntry:instantiate()
    self.folderNameEntry:setVisible(false)
    applyEntryColors(self.folderNameEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.folderNameEntry)

    self.folderSaveButton = ISButton:new(self.clientX + 280, self.clientY + 74, 72, 24, cmText("Save"), self, ComputerScreenUI.confirmFolderEdit)
    self.folderSaveButton:initialise()
    styleRetroButton(self.folderSaveButton)
    self.folderSaveButton:setVisible(false)
    self:addChild(self.folderSaveButton)

    self.folderCancelButton = ISButton:new(self.clientX + 280, self.clientY + 106, 72, 24, cmText("Cancel"), self, ComputerScreenUI.cancelFolderEdit)
    self.folderCancelButton:initialise()
    styleRetroButton(self.folderCancelButton)
    self.folderCancelButton:setVisible(false)
    self:addChild(self.folderCancelButton)

    self.settingsProfileButton = ISButton:new(self.clientX + 12, self.clientY + 18, 90, 24, cmText("Profile"), self, ComputerScreenUI.showSettingsProfile)
    self.settingsProfileButton:initialise()
    styleRetroButton(self.settingsProfileButton)
    self.settingsProfileButton:setVisible(false)
    self:addChild(self.settingsProfileButton)

    self.settingsSecurityButton = ISButton:new(self.clientX + 12, self.clientY + 48, 90, 24, cmText("Security"), self, ComputerScreenUI.showSettingsSecurity)
    self.settingsSecurityButton:initialise()
    styleRetroButton(self.settingsSecurityButton)
    self.settingsSecurityButton:setVisible(false)
    self:addChild(self.settingsSecurityButton)

    self.settingsSystemButton = ISButton:new(self.clientX + 12, self.clientY + 78, 90, 24, cmText("System"), self, ComputerScreenUI.showSettingsSystem)
    self.settingsSystemButton:initialise()
    styleRetroButton(self.settingsSystemButton)
    self.settingsSystemButton:setVisible(false)
    self:addChild(self.settingsSystemButton)

    self.settingsDisplayButton = ISButton:new(self.clientX + 12, self.clientY + 108, 90, 24, cmText("Display"), self, ComputerScreenUI.showSettingsDisplay)
    self.settingsDisplayButton:initialise()
    styleRetroButton(self.settingsDisplayButton)
    self.settingsDisplayButton:setVisible(false)
    self:addChild(self.settingsDisplayButton)

    self.settingsControlsButton = ISButton:new(self.clientX + 12, self.clientY + 138, 90, 24, cmText("Controls"), self, ComputerScreenUI.showSettingsControls)
    self.settingsControlsButton:initialise()
    styleRetroButton(self.settingsControlsButton)
    self.settingsControlsButton:setVisible(false)
    self:addChild(self.settingsControlsButton)

    self.settingsHardwareButton = ISButton:new(self.clientX + 12, self.clientY + 168, 90, 24, cmText("Hardware"), self, ComputerScreenUI.showSettingsHardware)
    self.settingsHardwareButton:initialise()
    styleRetroButton(self.settingsHardwareButton)
    self.settingsHardwareButton:setVisible(false)
    self:addChild(self.settingsHardwareButton)

    self.componentDebugButtons = {}
    local componentDebugActions = {
        {label = "-10", delta = -10},
        {label = "+10", delta = 10},
        {label = "0", value = 0},
        {label = "100", value = 100}
    }
    local debugParts = ComputerModComponents.getPartsForData(self:getComputerData())
    for partIndex = 1, #debugParts do
        local part = debugParts[partIndex]
        for actionIndex = 1, #componentDebugActions do
            local action = componentDebugActions[actionIndex]
            local button = ISButton:new(self.clientX + 238 + (actionIndex - 1) * 44, self.clientY + 42 + (partIndex - 1) * 39, 40, 20, action.label, self, ComputerScreenUI.adjustComponentCondition)
            button:initialise()
            styleRetroButton(button)
            button.internal = {partId = part.id, delta = action.delta, value = action.value, rowIndex = partIndex}
            button:setVisible(false)
            self.componentDebugButtons[#self.componentDebugButtons + 1] = button
            self:addChild(button)
        end
    end

    self.gameControlProfileButton = ISButton:new(self.clientX + 136, self.clientY + 58, 180, 26, "", self, ComputerScreenUI.cycleGameControlProfile)
    self.gameControlProfileButton:initialise()
    styleRetroButton(self.gameControlProfileButton)
    self.gameControlProfileButton:setVisible(false)
    self:addChild(self.gameControlProfileButton)

    self.gameMovementLockButton = ISButton:new(self.clientX + 136, self.clientY + 96, 180, 26, "", self, ComputerScreenUI.toggleGameMovementLock)
    self.gameMovementLockButton:initialise()
    styleRetroButton(self.gameMovementLockButton)
    self.gameMovementLockButton:setVisible(false)
    self:addChild(self.gameMovementLockButton)

    self.avatarButtons = {}
    for i = 1, 6 do
        local button = ISButton:new(self.clientX + 24 + (i - 1) * 32, self.clientY + 142, 30, 28, "", self, ComputerScreenUI.selectAvatar)
        button:initialise()
        styleIconButton(button)
        button.internal = i
        button:setVisible(false)
        self.avatarButtons[#self.avatarButtons + 1] = button
        self:addChild(button)
    end

    self.backgroundButtons = {}
    for i = 1, #backgroundPalettes do
        local button = ISButton:new(self.clientX + 24 + (i - 1) * 32, self.clientY + 142, 28, 24, "", self, ComputerScreenUI.selectBackgroundPalette)
        button:initialise()
        styleIconButton(button)
        button.internal = i
        button:setVisible(false)
        self.backgroundButtons[#self.backgroundButtons + 1] = button
        self:addChild(button)
    end

    self.textSizeButtons = {}
    local textSizeTitles = {"A-", "A", "A+", "A++", "A+++"}
    for i = 1, #textSizeScales do
        local button = ISButton:new(self.clientX + 24 + (i - 1) * 52, self.clientY + 144, 46, 24, textSizeTitles[i], self, ComputerScreenUI.selectTextSize)
        button:initialise()
        styleRetroButton(button)
        button.internal = i
        button:setVisible(false)
        self.textSizeButtons[#self.textSizeButtons + 1] = button
        self:addChild(button)
    end

    self.uiScaleButtons = {}
    local uiScaleTitles = {"Auto", "100%", "125%", "150%", "175%", "200%", "250%"}
    for i = 1, #uiScaleOptions do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local button = ISButton:new(self.clientX + 24 + col * 60, self.clientY + 198 + row * 28, 54, 24, uiScaleTitles[i], self, ComputerScreenUI.selectUIScale)
        button:initialise()
        styleRetroButton(button)
        button.internal = i
        button:setVisible(false)
        self.uiScaleButtons[#self.uiScaleButtons + 1] = button
        self:addChild(button)
    end

    self.notepadEntry = ISTextEntryBox:new("", self.clientX + 6, self.clientY + 6, self.clientW - 12, self.clientH - 12)
    self.notepadEntry:initialise()
    self.notepadEntry:instantiate()
    if self.notepadEntry.setMultipleLine then self.notepadEntry:setMultipleLine(true) end
    if self.notepadEntry.setMultipleLines then self.notepadEntry:setMultipleLines(true) end
    if self.notepadEntry.setWantKeyEvents then self.notepadEntry:setWantKeyEvents(true) end
    if self.notepadEntry.javaObject and self.notepadEntry.javaObject.setMultipleLine then
        self.notepadEntry.javaObject:setMultipleLine(true)
    end
    if self.notepadEntry.javaObject and self.notepadEntry.javaObject.setMultipleLines then
        self.notepadEntry.javaObject:setMultipleLines(true)
    end
    if self.notepadEntry.javaObject and self.notepadEntry.javaObject.setEditable then
        self.notepadEntry.javaObject:setEditable(true)
    end
    if self.notepadEntry.javaObject and self.notepadEntry.javaObject.setMaxLines then
        self.notepadEntry.javaObject:setMaxLines(512)
    end
    if self.notepadEntry.addScrollBars then
        self.notepadEntry:addScrollBars()
    end
    self.notepadEntry.target = self
    self.notepadEntry.onTextChangeFunction = function(ui)
        if ui and ui.updateNotepadScrollRange then ui:updateNotepadScrollRange() end
    end
    self.notepadEntry.onCommandEntered = function(entry)
        return self:insertNotepadNewLine()
    end
    self.notepadEntry.onOtherKey = function(entry, key)
        if key == Keyboard.KEY_RETURN or key == Keyboard.KEY_NUMPADENTER then
            return self:insertNotepadNewLine()
        end
    end
    applyEntryColors(self.notepadEntry, {r=0.96, g=0.96, b=0.92, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self.notepadEntry:setVisible(false)
    self:addChild(self.notepadEntry)

    self.browserBackButton = ISButton:new(self.clientX + 8, self.clientY + 8, 28, 22, "<", self, ComputerScreenUI.goBrowserBack)
    self.browserBackButton:initialise()
    styleRetroButton(self.browserBackButton)
    self.browserBackButton:setVisible(false)
    self:addChild(self.browserBackButton)

    self.browserForwardButton = ISButton:new(self.clientX + 40, self.clientY + 8, 28, 22, ">", self, ComputerScreenUI.goBrowserForward)
    self.browserForwardButton:initialise()
    styleRetroButton(self.browserForwardButton)
    self.browserForwardButton:setVisible(false)
    self:addChild(self.browserForwardButton)

    self.browserAddressEntry = ISTextEntryBox:new("knox-weather.net", self.clientX + 72, self.clientY + 8, self.clientW - 138, 22)
    self.browserAddressEntry:initialise()
    self.browserAddressEntry:instantiate()
    self.browserAddressEntry:setPlaceholderText("archive77.gov")
    applyEntryColors(self.browserAddressEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self.browserAddressEntry:setVisible(false)
    self:addChild(self.browserAddressEntry)

    self.browserGoButton = ISButton:new(self.clientX + self.clientW - 58, self.clientY + 8, 50, 22, cmText("Go"), self, ComputerScreenUI.navigateBrowser)
    self.browserGoButton:initialise()
    styleRetroButton(self.browserGoButton)
    self.browserGoButton:setVisible(false)
    self:addChild(self.browserGoButton)

    self.browserMediaButton = ISButton:new(self.clientX + self.clientW - 112, self.clientY + 38, 104, 22, "", self, ComputerScreenUI.openCurrentBrowserMedia)
    self.browserMediaButton:initialise()
    styleRetroButton(self.browserMediaButton)
    self.browserMediaButton:setVisible(false)
    self:addChild(self.browserMediaButton)

    self.browserDownloadButton = ISButton:new(self.clientX + self.clientW - 112, self.clientY + 206, 104, 22, cmText("Download"), self, ComputerScreenUI.startSelectedDownload)
    self.browserDownloadButton:initialise()
    styleRetroButton(self.browserDownloadButton)
    self.browserDownloadButton:setVisible(false)
    self:addChild(self.browserDownloadButton)

    self.downloadSelectButtons = {}
    for i = 1, #gameInstallOrder do
        local gameId = gameInstallOrder[i]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local btn = ISButton:new(self.clientX + 16 + col * 116, self.clientY + 74 + row * 24, 106, 20, gameInstallInfo[gameId].label, self, ComputerScreenUI.selectDownloadGame)
        btn:initialise()
        styleRetroButton(btn)
        btn.internal = gameId
        btn:setVisible(false)
        self.downloadSelectButtons[#self.downloadSelectButtons + 1] = btn
        self:addChild(btn)
    end

    self.passwordEntry = ISTextEntryBox:new("", self.clientX + 98, self.clientY + 86, 128, 24)
    self.passwordEntry:initialise()
    self.passwordEntry:instantiate()
    self.passwordEntry:setVisible(false)
    applyEntryColors(self.passwordEntry, {r=1, g=1, b=1, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:addChild(self.passwordEntry)

    self.passwordActionButton = ISButton:new(self.clientX + 236, self.clientY + 86, 70, 24, cmText("Save"), self, ComputerScreenUI.handlePasswordAction)
    self.passwordActionButton:initialise()
    styleRetroButton(self.passwordActionButton)
    self.passwordActionButton:setVisible(false)
    self:addChild(self.passwordActionButton)

    self.passwordHackButton = ISButton:new(self.clientX + 236, self.clientY + 116, 70, 24, cmText("Hack"), self, ComputerScreenUI.startPasswordHack)
    self.passwordHackButton:initialise()
    styleRetroButton(self.passwordHackButton)
    self.passwordHackButton:setVisible(false)
    self:addChild(self.passwordHackButton)

    self.passwordResetButton = ISButton:new(self.clientX + 66, self.clientY + 126, 112, 24, cmText("Reset PC"), self, ComputerScreenUI.resetComputerData)
    self.passwordResetButton:initialise()
    styleRetroButton(self.passwordResetButton)
    self.passwordResetButton:setVisible(false)
    self:addChild(self.passwordResetButton)

    self.resetConfirmButton = ISButton:new(self.clientX + 44, self.clientY + 154, 126, 24, cmText("Confirm Reset"), self, ComputerScreenUI.confirmResetComputer)
    self.resetConfirmButton:initialise()
    styleRetroButton(self.resetConfirmButton)
    self.resetConfirmButton:setVisible(false)
    self:addChild(self.resetConfirmButton)

    self.resetCancelButton = ISButton:new(self.clientX + 184, self.clientY + 154, 86, 24, cmText("Cancel"), self, ComputerScreenUI.cancelResetComputer)
    self.resetCancelButton:initialise()
    styleRetroButton(self.resetCancelButton)
    self.resetCancelButton:setVisible(false)
    self:addChild(self.resetCancelButton)

    self.passwordClearButton = ISButton:new(self.clientX + 194, self.clientY + 126, 112, 24, cmText("Clear Password"), self, ComputerScreenUI.clearComputerPassword)
    self.passwordClearButton:initialise()
    styleRetroButton(self.passwordClearButton)
    self.passwordClearButton:setVisible(false)
    self:addChild(self.passwordClearButton)

    self.installNextButton = ISButton:new(self.clientX + 170, self.clientY + 144, 64, 24, cmText("Next"), self, ComputerScreenUI.advanceInstallStep)
    self.installNextButton:initialise()
    styleRetroButton(self.installNextButton)
    self.installNextButton:setVisible(false)
    self:addChild(self.installNextButton)

    self.installCancelButton = ISButton:new(self.clientX + 242, self.clientY + 144, 64, 24, cmText("Cancel"), self, ComputerScreenUI.cancelInstallStep)
    self.installCancelButton:initialise()
    styleRetroButton(self.installCancelButton)
    self.installCancelButton:setVisible(false)
    self:addChild(self.installCancelButton)

    self.bootBiosButton = ISButton:new(self.screenX + self.screenWidth - 74, self.screenY + self.screenHeight - 30, 64, 20, "BIOS", self, ComputerScreenUI.openBiosMenu)
    self.bootBiosButton:initialise()
    styleRetroButton(self.bootBiosButton)
    self.bootBiosButton:setVisible(false)
    self:addChild(self.bootBiosButton)

    self.hardwareCloseButton = ISButton:new(self.screenX + 10, self.screenY + self.screenHeight - 30, 64, 20, cmText("Close"), self, ComputerScreenUI.handleClose)
    self.hardwareCloseButton:initialise()
    styleRetroButton(self.hardwareCloseButton)
    self.hardwareCloseButton:setVisible(false)
    self:addChild(self.hardwareCloseButton)

    self.biosBootDiskButton = ISButton:new(self.clientX + 22, self.clientY + 54, 132, 24, cmText("Boot Hard Disk"), self, ComputerScreenUI.biosBootHardDisk)
    self.biosBootDiskButton:initialise()
    styleRetroButton(self.biosBootDiskButton)
    self.biosBootDiskButton:setVisible(false)
    self:addChild(self.biosBootDiskButton)

    self.biosBootCDButton = ISButton:new(self.clientX + 22, self.clientY + 84, 132, 24, cmText("Boot CD-ROM"), self, ComputerScreenUI.biosBootCD)
    self.biosBootCDButton:initialise()
    styleRetroButton(self.biosBootCDButton)
    self.biosBootCDButton:setVisible(false)
    self:addChild(self.biosBootCDButton)

    self.biosWipeDiskButton = ISButton:new(self.clientX + 22, self.clientY + 114, 132, 24, cmText("Wipe Disk"), self, ComputerScreenUI.biosWipeDisk)
    self.biosWipeDiskButton:initialise()
    styleRetroButton(self.biosWipeDiskButton)
    self.biosWipeDiskButton:setVisible(false)
    self:addChild(self.biosWipeDiskButton)

    self.biosExitButton = ISButton:new(self.clientX + 22, self.clientY + 144, 132, 24, cmText("Exit BIOS"), self, ComputerScreenUI.exitBiosMenu)
    self.biosExitButton:initialise()
    styleRetroButton(self.biosExitButton)
    self.biosExitButton:setVisible(false)
    self:addChild(self.biosExitButton)

    self.downloadAllGamesButton = ISButton:new(self.windowX + self.windowW - 146, self.windowY + 34, 132, 20, cmText("Download All Games"), self, ComputerScreenUI.debugInstallAllGames)
    self.downloadAllGamesButton:initialise()
    styleRetroButton(self.downloadAllGamesButton)
    self.downloadAllGamesButton:setVisible(false)
    self:addChild(self.downloadAllGamesButton)

    self.calculatorButtons = {}
    local calcLayout = {
        {"7", "8", "9", "/"},
        {"4", "5", "6", "*"},
        {"1", "2", "3", "-"},
        {"C", "0", "=", "+"}
    }
    local calcStartX = self.clientX + 26
    local calcStartY = self.clientY + 74
    local calcButtonW = 62
    local calcButtonH = 30
    for row = 1, #calcLayout do
        for col = 1, #calcLayout[row] do
            local label = calcLayout[row][col]
            local button = ISButton:new(calcStartX + (col - 1) * 70, calcStartY + (row - 1) * 38, calcButtonW, calcButtonH, label, self, ComputerScreenUI.onCalculatorButton)
            button:initialise()
            styleRetroButton(button)
            button.internal = label
            button:setVisible(false)
            self.calculatorButtons[#self.calculatorButtons + 1] = button
            self:addChild(button)
        end
    end
    if self.applyUIScaleLayout then
        self:applyUIScaleLayout()
    end
    if self.layoutDesktopShortcutButtons then
        self:layoutDesktopShortcutButtons()
    end
    if self.layoutVisibleGameButtons then
        self:layoutVisibleGameButtons()
    end
    if self.updateSettingsCategoryLayout then
        self:updateSettingsCategoryLayout()
    end
    self.errorDialog = ComputerModErrorDialog:new(self.screenX, self.screenY, self.screenWidth, self.screenHeight, self)
    self.errorDialog:initialise()
    self.errorDialog:instantiate()
    self.errorDialog:setVisible(false)
    self:addChild(self.errorDialog)
    self:resumePoweredSession()
end


if ComputerModInstallUIState then ComputerModInstallUIState(ComputerScreenUI) end
if ComputerModInstallUISystem then ComputerModInstallUISystem(ComputerScreenUI) end
if ComputerModInstallUIApps then ComputerModInstallUIApps(ComputerScreenUI) end
if ComputerModInstallUILifecycle then ComputerModInstallUILifecycle(ComputerScreenUI) end
if ComputerModInstallUIRender then ComputerModInstallUIRender(ComputerScreenUI) end

function ComputerScreenUI:showError(message, title, placement, virusPopup)
    local value = tostring(message or "")
    if value == "" then return end
    self.fileNoticeText = nil
    self.fileNoticeTimer = 0
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    self.paintNoticeText = nil
    self.paintNoticeTimer = 0
    if self.errorDialog then
        self.errorDialog:open(value, title or cmText("Error"), placement, virusPopup)
    end
    playComputerUISound("ComputerError")
end

function ComputerScreenUI:closeError()
    if self.errorDialog then
        self.errorDialog:closeDialog()
    end
end

function ComputerScreenUI:showBootError()
    self.currentView = "BOOT_ERROR"
    self:showError(cmText("Fixed disk is not bootable."))
end

function ComputerScreenUI:showNextVirusError()
    local queue = self.virusErrorQueue
    if not queue or #queue == 0 then
        self.virusErrorQueue = nil
        return
    end
    local entry = table.remove(queue, 1)
    self:showError(entry.message, cmText("Error"), entry.placement, true)
end

function ComputerScreenUI:onErrorDialogClosed(virusPopup)
    if virusPopup then
        self:showNextVirusError()
    end
end

function ComputerScreenUI:tryTriggerGameInstallVirus()
    if not ComputerModSandbox or not ComputerModSandbox.getBool or not ComputerModSandbox.getPercent then return false end
    if not ComputerModSandbox.getBool("EnableGameInstallVirus", true) then return false end
    local chance = ComputerModSandbox.getPercent("GameInstallVirusChance")
    if chance <= 0 or ZombRand(100) >= chance then return false end

    local messages = {
        cmText("An unexpected error has occurred."),
        cmText("Memory could not be read."),
        cmText("A required system file was not found."),
        cmText("The program has stopped responding."),
        cmText("Please contact your system administrator."),
        cmText("The requested operation could not be completed.")
    }
    for i = #messages, 2, -1 do
        local index = ZombRand(i) + 1
        messages[i], messages[index] = messages[index], messages[i]
    end

    local placements = {"top_left", "top_right", "bottom_right", "bottom_left"}
    local startIndex = ZombRand(#placements)
    self.virusErrorQueue = {}
    for i = 1, 4 do
        local placementIndex = ((startIndex + i - 1) % #placements) + 1
        self.virusErrorQueue[#self.virusErrorQueue + 1] = {
            message = messages[i],
            placement = placements[placementIndex]
        }
    end
    self:showNextVirusError()
    return true
end

function ComputerScreenUI:isTextEntryFocused()
    local entries = {
        self.notepadEntry,
        self.browserAddressEntry,
        self.passwordEntry,
        self.usernameEntry,
        self.mailAddressEntry,
        self.mailPasswordEntry,
        self.mailToEntry,
        self.mailSubjectEntry,
        self.mailBodyEntry,
        self.chatUserEntry,
        self.chatPasswordEntry,
        self.chatRecoveryEmailEntry,
        self.chatRequestEntry,
        self.chatMessageEntry,
        self.postsNameEntry,
        self.postsBodyEntry,
        self.marketUserEntry,
        self.marketPasswordEntry,
        self.marketRecoveryEmailEntry,
        self.folderNameEntry
    }
    for i = 1, #entries do
        local entry = entries[i]
        if entry and entry.isFocused then
            local ok, focused = pcall(function() return entry:isFocused() end)
            if ok and focused then return true end
        end
    end
    return false
end

function ComputerScreenUI:claimComputerJoypadFocus()
    if not ComputerModGameInput or not ComputerModGameInput.hasGamepad(self.playerObj) then return false end
    if not getJoypadFocus or not setJoypadFocus then return false end
    local playerNum = tonumber(self.player) or 0
    local ok, currentFocus = pcall(function() return getJoypadFocus(playerNum) end)
    if not ok then return false end
    if currentFocus ~= self then
        self.computerModPreviousJoypadFocus = currentFocus
        pcall(function() setJoypadFocus(playerNum, self) end)
    end
    self.computerModJoypadFocusOwned = true
    return true
end

function ComputerScreenUI:releaseComputerJoypadFocus()
    if self.closeComputerGamepadKeyboard then self:closeComputerGamepadKeyboard(false) end
    if self.computerModJoypadFocusOwned ~= true or not getJoypadFocus or not setJoypadFocus then return end
    local playerNum = tonumber(self.player) or 0
    local ok, currentFocus = pcall(function() return getJoypadFocus(playerNum) end)
    if ok and currentFocus == self then
        local previousFocus = self.computerModPreviousJoypadFocus
        if previousFocus and previousFocus.isReallyVisible then
            local visibleOk, reallyVisible = pcall(function() return previousFocus:isReallyVisible() end)
            if not visibleOk or not reallyVisible then previousFocus = nil end
        else
            previousFocus = nil
        end
        pcall(function() setJoypadFocus(playerNum, previousFocus) end)
    end
    self.computerModPreviousJoypadFocus = nil
    self.computerModJoypadFocusOwned = false
end

function ComputerScreenUI:onJoypadDown(button, joypadData)
    if self.handleComputerGamepadButton then return self:handleComputerGamepadButton(button, joypadData) end
    return true
end

function ComputerScreenUI:onJoypadButtonReleased(button, joypadData)
    return true
end

function ComputerScreenUI:onJoypadDirUp(joypadData)
    if self.handleComputerGamepadDirection and self:handleComputerGamepadDirection("up") then return true end
    return true
end

function ComputerScreenUI:onJoypadDirDown(joypadData)
    if self.handleComputerGamepadDirection and self:handleComputerGamepadDirection("down") then return true end
    return true
end

function ComputerScreenUI:onJoypadDirLeft(joypadData)
    if self.handleComputerGamepadDirection and self:handleComputerGamepadDirection("left") then return true end
    return true
end

function ComputerScreenUI:onJoypadDirRight(joypadData)
    if self.handleComputerGamepadDirection and self:handleComputerGamepadDirection("right") then return true end
    return true
end

function ComputerScreenUI:onKeyPress(key)
    if self.errorDialog and self.errorDialog:isVisible() then
        if key == Keyboard.KEY_RETURN or key == Keyboard.KEY_NUMPADENTER or key == Keyboard.KEY_ESCAPE then
            self:closeError()
        end
        return true
    end
    if self.currentView == "NETWORK_REPAIR" and key == Keyboard.KEY_SPACE then
        return self:handleNetworkRepairSpace()
    end
    if self.currentView == "PASSWORD_HACK" and key == Keyboard.KEY_SPACE then
        return self:handlePasswordHackSpace()
    end
    if key == Keyboard.KEY_SPACE and not self:isTextEntryFocused() then
        if GameKeyboard and GameKeyboard.eatKeyPress then
            pcall(function() GameKeyboard.eatKeyPress(key) end)
        end
        if self.disableComputerSpaceShove then
            self:disableComputerSpaceShove()
        end
        return true
    end
    if self.currentView == "NOTEPAD" and (key == Keyboard.KEY_RETURN or key == Keyboard.KEY_NUMPADENTER) then
        local text = self:getCurrentNoteText() or ""
        self:setNotepadText(text .. "\n")
        self:saveCurrentNote()
        if self.notepadEntry and self.notepadEntry.bringToTop then
            self.notepadEntry:bringToTop()
        end
        return true
    end
    if ISPanel.onKeyPress then
        return ISPanel.onKeyPress(self, key)
    end
    return false
end

function ComputerScreenUI:onKeyRelease(key)
    if self.errorDialog and self.errorDialog:isVisible() then
        return true
    end
    if key == Keyboard.KEY_SPACE and not self:isTextEntryFocused() then
        if GameKeyboard and GameKeyboard.eatKeyPress then
            pcall(function() GameKeyboard.eatKeyPress(key) end)
        end
        return true
    end
    if ISPanel.onKeyRelease then
        return ISPanel.onKeyRelease(self, key)
    end
    return false
end

function ComputerScreenUI.consumeComputerSpaceKey(key)
    if key ~= Keyboard.KEY_SPACE then return end
    local ui = ComputerScreenUI.instance
    if not ui or not ui.isVisible or not ui:isVisible() then return end
    if ui.isTextEntryFocused and ui:isTextEntryFocused() then return end
    if GameKeyboard and GameKeyboard.eatKeyPress then
        pcall(function() GameKeyboard.eatKeyPress(key) end)
    end
    if ui.disableComputerSpaceShove then
        ui:disableComputerSpaceShove()
    end
end

if not ComputerModSpaceKeyEventsInstalled then
    ComputerModSpaceKeyEventsInstalled = true
    if Events.OnKeyStartPressed then
        Events.OnKeyStartPressed.Add(ComputerScreenUI.consumeComputerSpaceKey)
    end
    if Events.OnKeyPressed then
        Events.OnKeyPressed.Add(ComputerScreenUI.consumeComputerSpaceKey)
    end
    if Events.OnKeyKeepPressed then
        Events.OnKeyKeepPressed.Add(ComputerScreenUI.consumeComputerSpaceKey)
    end
end

local function buildScaledDisplayProfile(scale)
    local resolved = math.max(1, tonumber(scale) or 1)
    local texture = "media/textures/screen.png"
    if resolved >= 1.75 then
        texture = "media/textures/screen_uhd.png"
    elseif resolved >= 1.2 then
        texture = "media/textures/screen_hd.png"
    end
    return {
        name = "scale_" .. tostring(resolved),
        texture = texture,
        uiW = scaleRounded(UI_BASE_W, resolved),
        uiH = scaleRounded(UI_BASE_H, resolved),
        frameScale = resolved,
        contentScale = resolved,
        screenX = DISPLAY_PROFILES.standard.screenX,
        screenY = DISPLAY_PROFILES.standard.screenY,
        screenW = DISPLAY_PROFILES.standard.screenW,
        screenH = DISPLAY_PROFILES.standard.screenH
    }
end

function ComputerScreenUI.getDisplayProfile(screenW, screenH, requestedIndex)
    local w = tonumber(screenW) or 1920
    local h = tonumber(screenH) or 1080
    local optionIndex = math.floor(tonumber(requestedIndex or 1) or 1)
    if optionIndex < 1 or optionIndex > #uiScaleOptions then optionIndex = 1 end
    local requestedScale = uiScaleOptions[optionIndex] or 0
    if requestedScale <= 0 then
        if h >= 2000 then
            requestedScale = 2.50
        elseif h >= 1400 then
            requestedScale = 1.75
        elseif h >= 1150 then
            requestedScale = 1.25
        else
            requestedScale = 1.00
        end
    end
    local fitScale = math.min((w - 16) / UI_BASE_W, (h - 16) / UI_BASE_H)
    return buildScaledDisplayProfile(math.max(1, math.min(requestedScale, fitScale)))
end

function ComputerScreenUI.getRecommendedScale(screenW, screenH)
    local profile = ComputerScreenUI.getDisplayProfile(screenW, screenH)
    return profile and profile.frameScale or 1
end

function ComputerScreenUI:applyUIScaleLayout()
    local scale = tonumber(self.contentScale or self.uiScale or 1) or 1
    if scale <= 1.01 or self.uiScaleApplied then
        return
    end
    self.uiScaleApplied = true
    self.screenX = scaleRounded(self.screenX, scale)
    self.screenY = scaleRounded(self.screenY, scale)
    self.screenWidth = scaleRounded(self.screenWidth, scale)
    self.screenHeight = scaleRounded(self.screenHeight, scale)
    self.titleH = scaleRounded(self.titleH, scale)
    self.statusH = scaleRounded(self.statusH, scale)
    self.windowX = self.screenX + scaleRounded(8, scale)
    self.windowY = self.screenY + scaleRounded(8, scale)
    self.windowW = self.screenWidth - scaleRounded(16, scale)
    self.windowH = self.screenHeight - scaleRounded(30, scale)
    self.clientX = self.windowX + scaleRounded(4, scale)
    self.clientY = self.windowY + self.titleH + scaleRounded(4, scale)
    self.clientW = self.windowW - scaleRounded(8, scale)
    self.clientH = self.windowH - self.titleH - self.statusH - scaleRounded(8, scale)

    for _, child in ipairs(self.childrenInOrder or {}) do
        local currentX = child and child.x
        local currentY = child and child.y
        local currentW = child and child.width
        local currentH = child and child.height
        if type(currentX) == "number" and type(currentY) == "number"
                and type(currentW) == "number" and type(currentH) == "number"
                and child.setX and child.setY and child.setWidth and child.setHeight then
            child:setX(scaleRounded(currentX, scale))
            child:setY(scaleRounded(currentY, scale))
            child:setWidth(scaleRounded(currentW, scale))
            child:setHeight(scaleRounded(currentH, scale))
        end
    end
end

function ComputerScreenUI:new(x, y, player, computer)
    local profile = cloneDisplayProfile(DISPLAY_PROFILES.standard)
    local computerTypeDefinition = ComputerModComputerTypes.getDefinition(computer)
    if getCore then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local data = ComputerModComputerTypes.getData(computer)
        profile = ComputerScreenUI.getDisplayProfile(screenW, screenH, data and data.ComputerModUIScale or nil)
    end
    local customDisplayProfiles = computerTypeDefinition and computerTypeDefinition.displayProfiles or nil
    if type(customDisplayProfiles) == "table" and type(customDisplayProfiles.standard) == "table" then
        -- A custom frame owns one 100% logical layout. Scale the frame and its
        -- contents from that same layout exactly once at every UI percentage.
        local baseProfile = customDisplayProfiles.standard
        local resolvedScale = math.max(1, tonumber(profile.contentScale) or tonumber(profile.frameScale) or 1)
        local baseUiW = tonumber(baseProfile.uiW) or UI_BASE_W
        local baseUiH = tonumber(baseProfile.uiH) or UI_BASE_H
        if getCore then
            local screenW = getCore():getScreenWidth()
            local screenH = getCore():getScreenHeight()
            local fitScale = math.min((screenW - 16) / baseUiW, (screenH - 16) / baseUiH)
            resolvedScale = math.max(1, math.min(resolvedScale, fitScale))
        end
        profile.frameScale = resolvedScale
        profile.contentScale = resolvedScale
        profile.uiW = scaleRounded(baseUiW, resolvedScale)
        profile.uiH = scaleRounded(baseUiH, resolvedScale)
        profile.screenX = tonumber(baseProfile.screenX) or profile.screenX
        profile.screenY = tonumber(baseProfile.screenY) or profile.screenY
        profile.screenW = tonumber(baseProfile.screenW) or profile.screenW
        profile.screenH = tonumber(baseProfile.screenH) or profile.screenH
    end
    local uiScale = profile.frameScale or 1
    local uiW = profile.uiW or UI_BASE_W
    local uiH = profile.uiH or UI_BASE_H
    if getCore then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        x = math.max(0, math.floor((screenW - uiW) / 2))
        y = math.max(0, math.floor((screenH - uiH) / 2))
    end
    local o = ISPanel:new(x, y, uiW, uiH)
    setmetatable(o, self)
    self.__index = self
    o.displayProfile = profile.name
    o.uiScale = uiScale
    o.contentScale = profile.contentScale or 1
    o.player = player
    o.playerObj = getSpecificPlayer(player)
    o.computer = computer
    o.computerTypeDefinition = computerTypeDefinition
    o.displayProfileSpec = profile
    o.disableJoypadNavigation = true
    o.ignoreAim = true
    local frameTexture = profile.texture or "media/textures/screen.png"
    local customFrames = o.computerTypeDefinition and o.computerTypeDefinition.frameTextures or nil
    if type(customFrames) == "table" then
        if (profile.frameScale or 1) >= 1.75 then frameTexture = customFrames.uhd or customFrames.hd or customFrames.standard or frameTexture
        elseif (profile.frameScale or 1) >= 1.2 then frameTexture = customFrames.hd or customFrames.standard or frameTexture
        else frameTexture = customFrames.standard or frameTexture end
    elseif o.computerTypeDefinition and o.computerTypeDefinition.frameTexture then
        frameTexture = o.computerTypeDefinition.frameTexture
    end
    o.bgTexture = getTexture(frameTexture)
    if o.setWantKeyEvents then
        o:setWantKeyEvents(true)
    end
    ComputerScreenUI.instance = o
    return o
end
