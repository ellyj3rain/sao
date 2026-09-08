-- SAO_Inspect.lua - the inspect harness ([C6]).
-- ---------------------------------------------------------------------------
-- The operator's terms: normal launch, not -debug; a bound key or
-- panel; the selected survivor's seen / heard / told, standing, needs,
-- last decision, tick cost, and the population counts; the same lines
-- to the local JSONL. The panel can see everything - it reads the
-- stores raw, provenance and all - and the survivors gain NOTHING from
-- it: this file never observes, never tells, never moves standing,
-- never orders a body. A window is not a pathway.
--
-- Selection: "Inspect (panel)" under SAO Debug on a right-clicked
-- survivor, or the bound key (options screen, "[SAO]" section), which
-- opens on the nearest survivor when nobody is selected.

require "ISUI/ISCollapsableWindow"

SAO = SAO or {}
SAO.Inspect = SAO.Inspect or {}
local Ins = SAO.Inspect

SAOInspectWindow = ISCollapsableWindow:derive("SAOInspectWindow")
SAOInspectWindow.instance = nil

-- What the panel said last, and when it last said it to the JSONL -
-- the same lines, on a slow cadence, through the telemetry door the
-- sandbox already owns a dial for.
Ins.selectedId = nil
Ins.lastJsonlMs = 0
local JSONL_EVERY_MS = 2000

-- The knowledge tally: every belief in the store, counted by how it
-- was come by. The panel reads the store raw - that is its licence -
-- and the counts are the [B39] provenance law made visible.
local function knowledgeTally(id)
    local tally = { observed = 0, heard = 0, told = 0, lived = 0,
        unknown = 0 }
    local b = SAO.Perception.beliefs[id]
    if not b then return tally end
    for _, bucket in ipairs({ b.zombies, b.people, b.factions, b.places }) do
        for _, belief in pairs(bucket or {}) do
            local s = belief.source or "unknown"
            tally[s] = (tally[s] or 0) + 1
        end
    end
    return tally
end

local function nearestSurvivor()
    local me = getSpecificPlayer(0)
    if not me then return nil end
    local px, py = me:getX(), me:getY()
    local best, bestD = nil, nil
    for id, body in pairs(SAO.Body.active) do
        local ok, d = pcall(function()
            local dx, dy = body:getX() - px, body:getY() - py
            return dx * dx + dy * dy
        end)
        if ok and d and (not bestD or d < bestD) then best, bestD = id, d end
    end
    return best
end

function Ins.select(id)
    Ins.selectedId = id
end

function SAOInspectWindow:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = "Inspect"
    o.resizable = true
    o.minimumWidth = 360
    o.minimumHeight = 240
    return o
end

function SAOInspectWindow:build()
    local rows = {}
    local jsonl = {}
    local function header(text)
        rows[#rows + 1] = { kind = "header", text = text }
    end
    local function row(text)
        rows[#rows + 1] = { kind = "row", text = text }
    end

    -- The county, counted the way the boot digest counts it.
    local living, dead = 0, 0
    for _, r in pairs(SAO.Identity.all()) do
        if r.dead then dead = dead + 1 else living = living + 1 end
    end
    local bodies = 0
    for _ in pairs(SAO.Body.active) do bodies = bodies + 1 end
    header("The county")
    -- [C16] The dead census, read live (DR-021). Plain copy (DR-018).
    pcall(function()
        local me = getSpecificPlayer(0)
        if not me or not SAOJavaBridge then return end
        local s = SAOJavaBridge:deadCensus(me)
        local crowd = s and tonumber(s:match("crowd=(%d+)"))
        local marked = s and tonumber(s:match("marked=(%d+)"))
        if crowd then
            row("zombies loaded: " .. crowd
                .. ((marked and marked > 0)
                    and (" (+" .. marked .. " identity-bearing)") or ""))
        end
    end)
    row(living .. " living, " .. dead .. " dead, " .. bodies
        .. " bodies near you")
    jsonl.living, jsonl.dead, jsonl.bodies = living, dead, bodies
    local tickMs = SAO.Controller.lastTickMs
    if tickMs then
        row(string.format("controller tick: %.1f ms", tickMs))
        jsonl.tickMs = tickMs
    end

    local id = Ins.selectedId
    if not id or not SAO.Identity.get(id) then
        id = nearestSurvivor()
        Ins.selectedId = id
    end
    if not id then
        header("Nobody selected")
        row("Right-click a survivor: The County... > SAO Debug >"
            .. " Inspect (panel)")
        return rows, jsonl
    end
    local rec = SAO.Identity.get(id)
    jsonl.who = id

    header(tostring(SAO.Identity.knownName(rec) or id))
    row("id " .. tostring(id)
        .. (rec.designation and (", " .. tostring(rec.designation)) or "")
        .. (rec.occupation and (", was a " .. tostring(rec.occupation)) or ""))

    -- The last decision, in the words the pressure law requires.
    local agent = SAO.Controller.agents and SAO.Controller.agents[id]
    if agent then
        local pressure = agent.pressure or {}
        row("state " .. tostring(agent.state or "?") .. " - "
            .. tostring(pressure.answer or "?") .. ": "
            .. tostring(pressure.detail or "?"))
        row("walk: " .. tostring(SAO.Locomotion.status(id)))
        jsonl.state = tostring(agent.state)
        jsonl.answer = tostring(pressure.answer)
        jsonl.detail = tostring(pressure.detail)
    else
        row("dormant (no live agent)")
        jsonl.state = "dormant"
    end

    -- Needs, read off the body the way Needs reads them.
    local body = SAO.Body.get(id)
    if body then
        pcall(function()
            local stats = body:getStats()
            row(string.format(
                "hunger %.2f, thirst %.2f, health %.0f%%",
                stats:getHunger(), stats:getThirst(),
                body:getHealth()))
            jsonl.hunger = stats:getHunger()
            jsonl.thirst = stats:getThirst()
        end)
    end

    -- Standing: where they stand with you and with their people.
    local me = getSpecificPlayer(0)
    local pKey = me and SAO.Standing.playerKey(me) or nil
    if pKey then
        local trust = SAO.Standing.trust(id, pKey)
        local hostile = SAO.Standing.isHostileTo(id, pKey)
        row(string.format("trust in you %.2f%s", trust or 0,
            hostile and ", HOSTILE" or ""))
        jsonl.trust = trust
    end
    local g = SAO.Standing.groupOf(id)
    if g then
        row("of " .. tostring(SAO.Standing.factionName(g) or g))
        jsonl.group = tostring(g)
    end
    -- [C46] Their place, as the county actually read it during the
    -- years: the ways into it and how many are shut. Absent for a
    -- county that never had years to live.
    pcall(function()
        local rec46 = SAO.Identity.get(id)
        if rec46 and rec46.waysIntoHome then
            row("their place: " .. rec46.waysIntoHome .. " way"
                .. (rec46.waysIntoHome == 1 and "" or "s") .. " in, "
                .. (rec46.boardedAtHome or 0) .. " shut")
            jsonl.waysIntoHome = rec46.waysIntoHome
        end
    end)
    -- [C44] What they have actually built, which is a fact about them
    -- and not a promise: the windows they boarded with their own
    -- hands. Absent for everyone who has never managed one, which is
    -- the honest reading of a county that has not.
    pcall(function()
        local agent = SAO.Controller.agents[id]
        local boarded = agent and agent.boarded or 0
        if boarded > 0 then
            row("boarded " .. boarded .. " window"
                .. (boarded == 1 and "" or "s"))
            jsonl.boarded = boarded
        end
    end)
    -- [C37] On your word: whether they would take an order from you,
    -- and why not, in plain words (DR-017; SAO_Command).
    if pKey then
        pcall(function()
            local word = SAO.Command.describe(id, pKey)
            if word then
                row("on your word: " .. word)
                jsonl.onYourWord = word
            end
        end)
    end
    -- [C32] What they carry, in plain words (DR-017).
    pcall(function()
        local parts = {}
        local conditions = SAO.Conditions.describe(id)
        if conditions then parts[#parts + 1] = conditions end
        -- [C33] the habits beside the conditions, in the same words.
        local habits = nil
        pcall(function() habits = SAO.Habits.describe(id) end)
        if habits then parts[#parts + 1] = habits end
        if #parts > 0 then
            local carries = table.concat(parts, ", ")
            row("carries: " .. carries)
            jsonl.carries = carries
        end
    end)

    -- Seen / heard / told: the store raw, counted by provenance.
    local tally = knowledgeTally(id)
    header("What they hold")
    row("seen " .. tally.observed .. ", heard " .. tally.heard
        .. ", told " .. tally.told .. ", lived " .. tally.lived
        .. (tally.unknown > 0
            and (", UNKNOWN " .. tally.unknown) or ""))
    jsonl.seen, jsonl.heard, jsonl.told =
        tally.observed, tally.heard, tally.told
    jsonl.lived, jsonl.unknown = tally.lived, tally.unknown

    -- [C27] The same person through the knowledge surface - the
    -- exact input the talking system's two models will read
    -- (SPEECH_ML_DESIGN.md), shown here so what they know can be
    -- gauged today, before anything speaks.
    pcall(function()
        local claims = SAO.Knowledge.claims(id, pKey,
            SAO.Controller.tick())
        header("What they would say it from")
        local c = claims.conditioning or {}
        local moods = {}
        for k, v in pairs(c.moment or {}) do
            if v then
                moods[#moods + 1] = (k == "grief")
                    and ("grief (" .. tostring(v) .. ")") or k
            end
        end
        row("answers you " .. (c.trusted and "openly" or "guardedly")
            .. (#moods > 0
                and (" - carrying: " .. table.concat(moods, ", "))
                or ""))
        local parts = {}
        for _, topic in ipairs(SAO.Knowledge.topics()) do
            local facts = (claims.facts or {})[topic]
            if facts then
                parts[#parts + 1] = topic .. " " .. #facts
            end
        end
        row("holds: " .. (#parts > 0
            and table.concat(parts, ", ") or "nothing yet"))
        jsonl.knowledge = parts
        -- [C47] And the fence around it: how much this person could
        -- ever say, which is the whole of what a speaker will be
        -- handed. A wide fence is a person with a lot to tell.
        pcall(function()
            if not SAOJavaBridge then return end
            local flat = SAO.Knowledge.flatClaims(id, pKey,
                SAO.Controller.tick())
            local said = tostring(SAOJavaBridge:speechMeasure(flat))
            local slots = tonumber(said:match("slots=(%d+)"))
            local values = tonumber(said:match("values=(%d+)"))
            if slots and values then
                row("could say: " .. values .. " thing"
                    .. (values == 1 and "" or "s") .. " across "
                    .. slots .. " kind" .. (slots == 1 and "" or "s"))
                jsonl.sayableValues = values
            end
        end)
    end)

    return rows, jsonl
end

function SAOInspectWindow:render()
    ISCollapsableWindow.render(self)
    local okT, nowT = pcall(function() return getTimestampMs() end)
    if okT and nowT then
        if not self.lastBuiltMs or nowT - self.lastBuiltMs > 500 then
            self.lastBuiltMs = nowT
            local rows, jsonl = self:build()
            self.rows = rows
            -- The same lines to the JSONL, on a slower cadence,
            -- through the door the Telemetry sandbox dial owns. The
            -- writer is required-inert; nothing reads it back.
            if nowT - Ins.lastJsonlMs > JSONL_EVERY_MS then
                Ins.lastJsonlMs = nowT
                pcall(function()
                    SAO.Telemetry.event("inspect", jsonl)
                end)
            end
        end
    end
    -- One drawing discipline: the Ledger's own row renderer.
    if SAO.UI and SAO.UI.drawRows then
        SAO.UI.drawRows(self, self.rows)
    end
end

function SAOInspectWindow.toggle()
    if SAOInspectWindow.instance
        and SAOInspectWindow.instance:isVisible() then
        SAOInspectWindow.instance:setVisible(false)
        SAOInspectWindow.instance:removeFromUIManager()
        SAOInspectWindow.instance = nil
        return
    end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local ww, wh = 400, 320
    local w = SAOInspectWindow:new(
        math.max(0, sw - ww - 40), math.floor((sh - wh) / 3), ww, wh)
    w:initialise()
    w:addToUIManager()
    SAOInspectWindow.instance = w
end

function Ins.show(id)
    if id then Ins.selectedId = id end
    if not (SAOInspectWindow.instance
        and SAOInspectWindow.instance:isVisible()) then
        SAOInspectWindow.toggle()
    end
end

-- The bound key ([C6]): normal launch, the options screen owns the
-- binding, and the handler does nothing but show or hide a window.
Events.OnKeyPressed.Add(function(key)
    local ok, bound = pcall(function()
        return getCore():getKey("SAOInspect")
    end)
    if ok and bound and bound ~= 0 and key == bound then
        SAOInspectWindow.toggle()
    end
end)

return SAOInspectWindow
