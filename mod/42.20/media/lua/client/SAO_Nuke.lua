-- SAO_Nuke - the government's answer, as the operator ruled the port
-- ([C119], Speakeasy records 49-50).
-- ---------------------------------------------------------------------------
-- Week One's FinalSolution is a SCRIPT: hour 168 of every world, eight
-- to ten fixed circles, default ON, with a seven-night dream quest, a
-- siren countdown, and an in-game kill switch at the military base's
-- computer. Existing worlds that already chose its script keep that
-- producer. New SAO-created worlds offer an explicit no-strike or SAO
-- event choice. SAO's separate world dial uses the EVENT and its
-- engine idioms, credited (CREDITS.md): the fire (SetOnFire on every
-- body in the circles), the ground (BurnWalls as squares stream in),
-- the sound (their two kaboom files, near and distant), and the
-- sickness (the engine's own food-sickness stat rising inside the
-- circles).
--
-- What replaces the script is the operator's ruling, in full:
--   * A DIAL, default OFF. Nothing here runs in a world that did not
--     ask for it.
--   * When the dial is on, the strike is DRAWN for that world alone -
--     the day, the towns, how many, how wide - and persisted, so the
--     same save carries one fate and a new county is a novel
--     apocalypse. No fixed circles, no fixed week.
--   * The countdown starts at THE FALL, not at the save: the strike
--     is the government's answer to the Knox Event, so it is the
--     event's own calendar that orders it, whenever the event came
--     to this county.
--   * After the strike there is no script at all: the engine's fire
--     burns what fire burns, the sickness rises where the circles
--     hold, and every consequence after is the county's own
--     machinery reading a county that changed.
--
-- Honest limits, named here so they are not mistaken for lost:
--   * The dormant half (people simulated without bodies) feels no
--     fire and no fallout - the dial they answer is the dormant-risk
--     dial, which is the off-screen danger of the world they walk.
--   * The distant booms do not stagger as their scheduler staggered
--     them; a county struck in four places hears four booms at once.
--   * No nuclear winter (their climate override), no hazmat immunity,
--     no hydro deaths, no player screen flash, no vehicles burned
--     (their vehicle burn is a script-swap to a burnt wreck, not an
--     engine call). No dream quest, no siren, no variant schedule.
--   * The dial governs the WHOLE feature: off stops the countdown,
--     the strike, the fallout, and the burning of new ground alike,
--     and a strike overdue while off lands when it is on again.

SAO = SAO or {}
SAO.Nuke = SAO.Nuke or {}
local N = SAO.Nuke

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("NUKE", msg) end

-- The SAO dial ([C119]) remains off by default. A selected Week One strike
-- and an already drawn SAO fate each keep one producer for this save.
local function saoSelected()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return sv ~= nil and sv.WeekOneNuke == true
end

local function weekOneSelected()
    local sv = SandboxVars and SandboxVars.BanditsWeekOne or nil
    return type(BWOScheduler) == "table"
        and sv ~= nil and sv.EventFinalSolution == true
end

-- The world's own memory of its fate. ModData is the same store the
-- standing tables use; a drawn world carries its draw across loads.
local function store()
    local ok, s = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Nuke")
    end)
    if ok and type(s) == "table" then return s end
    return nil
end

local function producer(s)
    if s.producer == "SAO" or s.producer == "BanditsWeekOne"
        or s.producer == "none" then
        return s.producer
    end
    -- Older saves that already drew or felt the SAO strike retain its owner.
    if s.drawn or s.struck then
        s.producer = "SAO"
    elseif weekOneSelected() then
        s.producer = "BanditsWeekOne"
    elseif saoSelected() then
        s.producer = "SAO"
    end
    return s.producer
end

local function creatorReceiptValid(choice, receipt)
    if (choice ~= "none" and choice ~= "SAO") or type(receipt) ~= "table"
        or receipt.schema ~= "sao-created-player/1" or receipt.newWorld ~= true
        or receipt.nukeChoice ~= choice or type(receipt.world) ~= "string"
        or receipt.world == "" or type(receipt.gameMode) ~= "string"
        or receipt.gameMode == "" or type(receipt.decisionId) ~= "string"
        or type(receipt.characterId) ~= "string"
        or not receipt.characterId:match("^sao%-player%-%d+$")
        or type(receipt.playerKey) ~= "string" or receipt.playerKey == ""
        or type(receipt.appliedAtHours) ~= "number"
        or receipt.appliedAtHours ~= receipt.appliedAtHours
        or receipt.appliedAtHours < 0
        or math.abs(receipt.appliedAtHours) == math.huge
        or type(receipt.nativeDescriptorId) ~= "number"
        or receipt.nativeDescriptorId < 0
        or receipt.nativeDescriptorId % 1 ~= 0 then
        return false
    end
    local ok, world, mode = pcall(function()
        local current = getWorld()
        return current:getWorld(), current:getGameMode()
    end)
    if not ok or world ~= receipt.world or mode ~= receipt.gameMode then
        return false
    end
    local prefix = receipt.world .. "|" .. receipt.gameMode .. "|"
    return receipt.decisionId:sub(1, #prefix) == prefix
        and receipt.decisionId:sub(#prefix + 1):match("^[1-9]%d*$") ~= nil
end

-- The creator calls this only after its confirmed new-world draft matches a
-- real native character. Existing saved worlds keep their prior owner/fate.
function N.applyCreatorChoice(choice, receipt)
    if not creatorReceiptValid(choice, receipt) then
        return false, "invalid-creator-receipt"
    end
    local s = store()
    if not s then return false, "world-store-unavailable" end
    if s.creatorChoice then
        local prior = s.creatorChoice
        if prior.decisionId == receipt.decisionId and prior.nukeChoice == choice
            and prior.world == receipt.world and prior.gameMode == receipt.gameMode
            and prior.characterId == receipt.characterId
            and prior.playerKey == receipt.playerKey
            and prior.nativeDescriptorId == receipt.nativeDescriptorId then
            return true, "already-applied"
        end
        return false, "creator-choice-conflict"
    end
    -- World load may read the selected SAO dial before OnCreatePlayer can
    -- attach the confirmed native body. Complete that same owner's receipt;
    -- a different producer or an already drawn fate still cannot change.
    if (s.producer ~= nil and s.producer ~= choice)
        or s.drawn or s.struck then
        return false, "world-producer-already-owned"
    end
    s.creatorChoice = {
        schema = receipt.schema, decisionId = receipt.decisionId,
        world = receipt.world, gameMode = receipt.gameMode,
        characterId = receipt.characterId,
        nativeDescriptorId = receipt.nativeDescriptorId,
        playerKey = receipt.playerKey,
        appliedAtHours = receipt.appliedAtHours, nukeChoice = choice,
    }
    s.producer = choice
    return true, "applied"
end

function N.effectiveProducer()
    local s = store()
    return s and producer(s) or nil
end

local function armed(s)
    return producer(s) == "SAO" and saoSelected()
end

-- Where a strike can land: the county's own towns, Week One's own
-- target list carried whole (their SetupNukes coordinates - map
-- facts, like the street hour, credited in CREDITS.md). What is NOT
-- carried is their certainty of striking all of them, every world,
-- the same week: which towns, how many, how wide is the draw below.
local TOWNS = {
    { name = "Muldraugh",     x = 10800, y = 9800  },
    { name = "March Ridge",   x = 10040, y = 12760 },
    { name = "Rosewood",      x = 8160,  y = 11550 },
    { name = "Doe Valley",    x = 7267,  y = 8320  },
    { name = "Riverside",     x = 6350,  y = 5430  },
    { name = "West Point",    x = 11740, y = 6900  },
    { name = "Ekron",         x = 646,   y = 9734  },
    { name = "Louisville",    x = 12980, y = 2256  },
    { name = "Brandenburg",   x = 2060,  y = 5930  },
    { name = "Irvington",     x = 2336,  y = 14294 },
}

local function dist2(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return dx * dx + dy * dy
end

-- Is this position inside any struck circle? (2D, like theirs.)
local function inCircles(s, x, y)
    for _, c in ipairs(s.circles or {}) do
        local r = c.r or 0
        if dist2(x, y, c.x or 0, c.y or 0) <= r * r then
            return true, c
        end
    end
    return false, nil
end

-- The fall's own hours: the earliest stamp the county wrote at its
-- moments that matter (outbreak, first turning, the taps), or zero
-- for a world that began after the fall had already come - county
-- hours already count the world's behind, so the fall of a begun-
-- fallen world is the world's own beginning.
local function fallAtHours()
    local fallen, why = false, nil
    pcall(function()
        fallen, why = SAO.Standing.fallHasCome()
    end)
    if fallen ~= true then return nil end
    local earliest = nil
    pcall(function()
        local ch = SAO.Standing.chronicle()
        for _, v in pairs({ ch.outbreakAtHours, ch.firstTurnedAtHours,
                            ch.tapsDryAtHours }) do
            if type(v) == "number" and (not earliest or v < earliest) then
                earliest = v
            end
        end
    end)
    return earliest or 0
end

-- THE DRAW. Once per world, at the first county day the fallen world
-- is asked about. Nothing in it is authored: the delay, the count,
-- the towns, the radii are the engine's own dice, drawn once and
-- kept, so the same save is one fate and a new county is a new one.
local function draw(s, fallHours)
    -- R.int's high bound is exclusive (its draw is `% span`, the same
    -- arithmetic the roam's own `int(-range, range + 1)` leans on), so
    -- every span below runs one past the reachable end.
    local delayDays = 5 + SAO.Rand.int(0, 18)         -- 5 .. 21 days
    local count = 1 + SAO.Rand.int(0, 4)              -- 1 .. 4 circles
    local pool = {}
    for i, t in ipairs(TOWNS) do pool[i] = t end
    local circles = {}
    for _ = 1, count do
        local idx = SAO.Rand.int(1, #pool + 1)        -- 1 .. #pool
        local t = table.remove(pool, idx)
        circles[#circles + 1] = {
            name = t.name,
            x = t.x, y = t.y,
            r = 500 + SAO.Rand.int(0, 501),           -- 500 .. 1000
        }
    end
    s.drawn = true
    s.fallAtHours = fallHours
    s.strikeAtHours = fallHours + delayDays * 24.0
    s.circles = circles
    local named = {}
    for _, c in ipairs(circles) do
        named[#named + 1] = c.name .. " (r" .. tostring(c.r) .. ")"
    end
    log("the fate is drawn: " .. #circles .. " strike(s), "
        .. delayDays .. " days after the fall - "
        .. table.concat(named, ", "))
end

-- THE STRIKE. Their Nuke's engine surfaces, one pass, no scheduler:
-- the sound near or far by where the player actually stands, the
-- fire on every body in the circles at ground level - the county's
-- people, the risen, the player - and the ground's turn follows at
-- the square loader below. What happens next is the engine's fire.
local function strike(s)
    s.struck = true
    local player = nil
    pcall(function() player = (SAO.Participants and SAO.Participants.player or getSpecificPlayer)(0) end)

    if player then
        for _, c in ipairs(s.circles or {}) do
            local r = c.r or 0
            local near = dist2(player:getX(), player:getY(),
                c.x or 0, c.y or 0) <= (r * 1.5) * (r * 1.5)
            pcall(function()
                player:playSound(near and "SAONukeNear" or "SAONukeDist")
            end)
        end
    end

    local burned = 0
    for id, body in pairs(SAO.Body.active or {}) do
        local inside = false
        pcall(function() inside = SAO.Body.get(id) == body
            and inCircles(s, body:getX(), body:getY()) end)
        if inside then
            local lit = false
            pcall(function()
                if body:getZ() >= 0 then
                    body:SetOnFire()
                    lit = true
                end
            end)
            if lit then burned = burned + 1 end
        end
    end

    local okZ, zombies = pcall(function()
        return getCell():getZombieList()
    end)
    if okZ and zombies then
        pcall(function()
            for i = 0, zombies:size() - 1 do
                local z = zombies:get(i)
                if z and z:getZ() >= 0
                    and inCircles(s, z:getX(), z:getY()) then
                    z:SetOnFire()
                    burned = burned + 1
                end
            end
        end)
    end

    if player then
        local inside = false
        pcall(function()
            inside = player:getZ() >= 0
                and inCircles(s, player:getX(), player:getY())
        end)
        if inside then
            pcall(function() player:SetOnFire() end)
        end
    end

    local names = {}
    for _, c in ipairs(s.circles or {}) do
        names[#names + 1] = c.name
    end
    log("THE GOVERNMENT'S ANSWER: " .. table.concat(names, ", ")
        .. " - " .. burned .. " bodies burning. The circles hold.")
end

-- THE FALLOUT, once a county day for every live body inside the
-- circles. The county's own people pay on the body's health; the
-- player pays on the engine's food-sickness stat - their exact
-- idiom (BWOPlayer's radiation tick, credited), which is the
-- poison the engine already knows how to make felt. Neither is
-- authored: it is what standing inside the answer costs.
local RADIATION_TOLL = 0.12      -- of a body's health, per day
local function attrition(s)
    for id, body in pairs(SAO.Body.active or {}) do
        local inside = false
        pcall(function() inside = SAO.Body.get(id) == body
            and inCircles(s, body:getX(), body:getY()) end)
        if inside then
            pcall(function()
                local h = body:getHealth()
                if type(h) == "number" and h > 0 then
                    body:setHealth(math.max(0, h - RADIATION_TOLL))
                end
            end)
        end
    end
    local player = nil
    pcall(function() player = (SAO.Participants and SAO.Participants.player or getSpecificPlayer)(0) end)
    if player then
        local inside = false
        pcall(function() inside = inCircles(s, player:getX(), player:getY()) end)
        if inside then
            pcall(function()
                if CharacterStat and player.getStats then
                    local stats = player:getStats()
                    local sick = stats:get(CharacterStat.FOOD_SICKNESS)
                    local inc = player:isOutside() and 0.05 or 0.025
                    if sick < 160 then
                        stats:set(CharacterStat.FOOD_SICKNESS, sick + inc)
                    end
                end
            end)
        end
    end
end

-- The county day hook (Population's dailyCounty, the [C65] law's
-- own gate): the draw, the strike, the fallout - one pass, the
-- same clock every other county-day verb runs on, so the years
-- pass drives a struck county exactly as the live one does.
function N.onDay()
    local s = store()
    if not s then return false end
    if not armed(s) then return false end
    local hours = nil
    pcall(function() hours = SAO.History.countyHours() end)
    if type(hours) ~= "number" then return false end
    local fallHours = fallAtHours()
    if not fallHours then return false end
    if not s.drawn then draw(s, fallHours) end
    if not s.struck and hours >= (s.strikeAtHours or 0) then
        strike(s)
    end
    if s.struck then attrition(s) end
    return true
end

-- The ground's turn ([C119]): every square that streams in inside a
-- struck circle burns once - their own loader idiom
-- (BurnWalls(false, true), credited), the burnt set kept per
-- square so a re-visit does not re-burn. Squares already loaded at
-- the strike burn when their chunk next reloads, which is how
-- theirs behaves too: the fire follows the player's own horizon.
local function onSquare(square)
    local s = store()
    if not s or not armed(s) or not s.struck then return end
    if not square then return end
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = square:getX(), square:getY(), square:getZ() end)
    if type(x) ~= "number" or type(y) ~= "number" then return end
    local inside = inCircles(s, x, y)
    if not inside then return end
    s.burnt = s.burnt or {}
    local key = x .. "," .. y .. "," .. tostring(z)
    if s.burnt[key] then return end
    s.burnt[key] = true
    pcall(function() square:BurnWalls(false, true) end)
end

Events.LoadGridsquare.Add(onSquare)

log("nuke module loaded (SAO dial off by default; world producer selected once)")

return N
