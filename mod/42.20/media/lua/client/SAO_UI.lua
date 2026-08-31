-- SAO_UI - the County Ledger window ([A25]).
-- ---------------------------------------------------------------------------
-- The county's state as a NATIVE window in the game's own idiom
-- (ISCollapsableWindow: title bar, drag, close - the same base the KS
-- panels derive from), replacing console prose. Everything rendered is
-- read at open/refresh time from records and standing; nothing stored.

require "ISUI/ISCollapsableWindow"

SAO = SAO or {}

SAOCountyWindow = ISCollapsableWindow:derive("SAOCountyWindow")
SAOCountyWindow.instance = nil

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium

local function safeGroups()
    local groups = {}
    for _, r in pairs(SAO.Identity.all()) do
        if not r.dead then
            local g = SAO.Standing.groupOf(r.id)
            if g and not groups[g] then groups[g] = true end
        end
    end
    return groups
end

-- [B29] A line that does not fit is SHORTENED, not clipped. Every
-- row here is a plain string drawn at a fixed left margin, and
-- nothing measured it against the window - so a long row ran off the
-- right edge and lost half of itself, silently. The engine has always
-- been able to answer how wide a string is; nobody asked.
local function fitText(text, font, maxW)
    text = tostring(text or "")
    if maxW <= 0 then return "" end
    local tm = getTextManager()
    if not tm then return text end
    local okW, w = pcall(function() return tm:MeasureStringX(font, text) end)
    if not okW or not w or w <= maxW then return text end
    -- Trim from the end until the ellipsis fits too. Linear on a
    -- string that is already short; this runs on a 500ms cadence, not
    -- per frame ([B5]'s audit applies to windows as well).
    local cut = #text
    while cut > 1 do
        cut = cut - 1
        local candidate = string.sub(text, 1, cut) .. "..."
        local okC, cw = pcall(function()
            return tm:MeasureStringX(font, candidate)
        end)
        if not okC or not cw then return text end
        if cw <= maxW then return candidate end
    end
    return "..."
end

function SAOCountyWindow:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = "County Ledger"
    o.resizable = true
    o.minimumWidth = 380
    o.minimumHeight = 260
    return o
end

-- Assemble display rows: { {kind="header"|"row", text=..}, ... }
function SAOCountyWindow:build()
    local rows = {}
    local function header(text) rows[#rows + 1] = { kind = "header", text = text } end
    local function row(text) rows[#rows + 1] = { kind = "row", text = text } end

    local living, dead = 0, 0
    local recentDead = {}
    for _, r in pairs(SAO.Identity.all()) do
        if r.dead then
            dead = dead + 1
            recentDead[#recentDead + 1] = r
        else
            living = living + 1
        end
    end
    table.sort(recentDead, function(a, b)
        return (a.diedAtHours or 0) > (b.diedAtHours or 0)
    end)

    -- [B47] How many of them are actually IN the world.
    --
    -- The operator played a session and asked whether it had worked.
    -- The log carried 234 identities, 340 population lines and not one
    -- body ever materialising - and there was no way to tell, from
    -- inside the game, whether that meant nobody had come near them or
    -- the live half was not running at all. "234 living" reads the
    -- same either way, which is [B33]'s shape: a world running
    -- differently with nothing saying so.
    --
    -- `Near you` cannot answer it, because that section VANISHES when
    -- it is empty. Absent-because-nobody-is-near and
    -- absent-because-nobody-exists look identical. One number on the
    -- line above tells the two apart.
    local loadedOurs, loadedKnox = 0, 0
    pcall(function()
        loadedOurs = SAO.Body.activeCount()
        loadedKnox = SAO.Body.knoxCount()
    end)
    local here = loadedOurs + loadedKnox
    header("The County - " .. living .. " living, " .. dead .. " dead"
        .. " - " .. here .. " loaded here")
    -- [B43] Which jar is actually loaded, said out loud. [B33] found
    -- the shipped SAO.jar two days stale and missing seventeen engine
    -- classes; deploy overwrote it on the way to the game, so the
    -- LIVE install was always right and the defect was invisible from
    -- inside a session. `getVersion` existed the whole time and was
    -- the one bridge method no Lua ever called - and it answered with
    -- a hardcoded string five minor versions behind VERSION, so
    -- wiring it before [B43] would only have reported a lie.
    --
    -- Stamped from VERSION at build time now, so what this line says
    -- is what was actually compiled.
    pcall(function()
        local jv = SAOJavaBridge and SAOJavaBridge:getVersion() or nil
        if jv and jv ~= "" then row("running " .. tostring(jv)) end
    end)
    -- [B33] A seam that disabled itself leaves a world that looks
    -- normal. Said once, at the top, and only when there is something
    -- to say - the console already carries the detail.
    if SAO.Seams and SAO.Seams.count() > 0 then
        header("Not everything is running: "
            .. table.concat(SAO.Seams.names(), ", ")
            .. " stopped this session")
    end
    -- [B45] The same rule, pointed the other way. A seam going dark
    -- leaves a world that looks normal; so does a neighbour's mod
    -- being held. Suppression's whole result is an ABSENCE, and an
    -- absence nobody reports is the shape this project has now found
    -- at [B33], [B42], [B42] and [B44]. Said only when there is
    -- something to say.
    if SAO.Neighbours and SAO.Neighbours.line then
        local nbLine = SAO.Neighbours.line()
        if nbLine then header(nbLine) end
    end

    local me = getSpecificPlayer(0)
    local myKey = SAO.Standing.playerKey(me)
    -- [B37] Your ground, and who knows about it. [B34] made the
    -- extent derive from the building; [B35] made a released claim
    -- forgettable; [B35] let the dormant learn it by walking past;
    -- [B35] stopped anyone building over it. Every one of those is
    -- invisible from inside the game - the county behaves differently
    -- and nothing says so, which is exactly the condition [B33]
    -- named for the seams.
    --
    -- Knowing is per-survivor and spreads on foot, so the count is
    -- the honest measure of how far word has got: it starts at zero
    -- the moment you claim and climbs as people actually pass by.
    if myKey then
        local mine = SAO.Standing.claimOf(myKey)
        if mine then
            local knows = 0
            for id, b in pairs(SAO.Perception.beliefs or {}) do
                if b.places and b.places[myKey] then
                    knows = knows + 1
                end
            end
            local w = mine.maxX - mine.minX + 1
            local h = mine.maxY - mine.minY + 1
            header("Your ground - " .. w .. " by " .. h .. " at "
                .. math.floor((mine.minX + mine.maxX) / 2) .. ","
                .. math.floor((mine.minY + mine.maxY) / 2))
            row(knows == 0
                and "Nobody has come past it yet."
                or (knows .. (knows == 1 and " survivor knows"
                    or " survivors know") .. " it is yours."))
        end
    end
    if myKey then
        local sum, n, hostiles = 0, 0, 0
        for _, r in pairs(SAO.Identity.all()) do
            if not r.dead then
                local tr = SAO.Standing.trust(r.id, myKey)
                if tr ~= 0 then sum = sum + tr; n = n + 1 end
                if SAO.Standing.isHostileTo(r.id, myKey) then
                    hostiles = hostiles + 1
                end
            end
        end
        if n > 0 then
            row("You: known to " .. n .. ", regard "
                .. string.format("%.2f", sum / n)
                .. (hostiles > 0 and (", " .. hostiles .. " hostile")
                    or ", none hostile"))
        else
            row("You: a stranger to the county still")
        end
        -- [B18] Your ground and who calls it home.
        local myClaim = SAO.Standing.claimOf(myKey)
        if myClaim then
            local household = 0
            if SAO.Controller and SAO.Controller.agents then
                for _, ag in pairs(SAO.Controller.agents) do
                    if ag.companioning then household = household + 1 end
                end
            end
            row("Your ground: "
                .. math.floor((myClaim.minX + myClaim.maxX) / 2) .. ","
                .. math.floor((myClaim.minY + myClaim.maxY) / 2)
                .. (household > 0
                    and ("  -  " .. household .. " come home here")
                    or "  -  yours alone"))
        end
    end

    -- Near you ([B18]): the question a player opens this window
    -- with. Every value here already existed - the pressure claim is
    -- computed on every decision and was rendered only to a debug
    -- console. Read at draw time; nothing stored.
    do
        local me2 = getSpecificPlayer(0)
        local near = {}
        if me2 and SAO.Controller and SAO.Controller.agents then
            local myKey2 = SAO.Standing.playerKey(me2)
            for aid, agent in pairs(SAO.Controller.agents) do
                local abody = SAO.Body.get(aid)
                local arec = SAO.Identity.get(aid)
                if abody and arec and not arec.dead then
                    local ddx = abody:getX() - me2:getX()
                    local ddy = abody:getY() - me2:getY()
                    -- [B52] `dist`, not `d2`. This holds a ROOTED
                    -- distance and was the one place in twenty that
                    -- named one `d2` - which means squared everywhere
                    -- else in this tree, and is compared against a
                    -- square everywhere else. `d2 <= 40` was correct
                    -- and read exactly like the mistake of comparing
                    -- a squared distance to an unsquared literal, at
                    -- which point this would silently be 6.3 tiles.
                    local dist = math.sqrt(ddx * ddx + ddy * ddy)
                    if dist <= 40 then
                        -- [B42] Say what is known and nothing else.
                        -- These fell back to "…" and "?", so a survivor
                        -- with no pressure answer yet rendered as
                        -- `Danilo Sumpter (1m) - … [?]` - two fields
                        -- claimed that the county does not have. Worse,
                        -- U+2026 has no glyph in the game's font and
                        -- came out as a stray `&`, so the one line that
                        -- said "I don't know" was also the one line
                        -- that looked broken.
                        local doing = agent.pressure
                            and agent.pressure.detail or nil
                        local why = agent.pressure
                            and agent.pressure.answer or nil
                        local marks = {}
                        pcall(function()
                            local bd2 = abody:getBodyDamage()
                            if bd2 and bd2:getNumPartsBitten() > 0 then
                                marks[#marks + 1] = "BITTEN"
                            elseif SAO.Needs.woundInfection(abody) > 0 then
                                marks[#marks + 1] = "fevered"
                            elseif SAO.Needs.bleeding(abody) > 0 then
                                marks[#marks + 1] = "bleeding"
                            end
                        end)
                        if SAO.Standing.debt(aid, myKey2) > 0 then
                            marks[#marks + 1] = "you owe them"
                        end
                        -- [B19] Which of these are YOURS.
                        if agent.companioning then
                            marks[#marks + 1] = "with you"
                        end
                        -- [B19] Who is out with whom.
                        if agent.escortId then
                            local eRec = SAO.Identity.get(agent.escortId)
                            if eRec then
                                marks[#marks + 1] = "with "
                                    .. tostring(
                                        SAO.Identity.displayName(eRec))
                            end
                        end
                        local line2 = string.format("%s (%.0fm)",
                            tostring(SAO.Identity.displayName(arec)), dist)
                        if doing then
                            line2 = line2 .. " - " .. tostring(doing)
                        end
                        if why then
                            line2 = line2 .. " [" .. tostring(why) .. "]"
                        end
                        if #marks > 0 then
                            line2 = line2 .. "  "
                                .. table.concat(marks, ", ")
                        end
                        near[#near + 1] = { d = dist, text = line2 }
                    end
                end
            end
        end
        if #near > 0 then
            table.sort(near, function(a, b) return a.d < b.d end)
            header("Near you")
            for i = 1, math.min(8, #near) do row(near[i].text) end
            if #near > 8 then
                row("(" .. (#near - 8) .. " more within earshot)")
            end
        end
    end

    header("Companies")
    local groups = safeGroups()
    local any = false
    for g in pairs(groups) do
        any = true
        local creed = SAO.Standing.creedOf(g)
        local fname = SAO.Standing.factionName(g) or g
        local gc = SAO.Standing.groupClaimOf(g)
        local line = fname
        if creed then
            line = line .. "  [" .. creed.name
            -- Temper ([A25]): the second voice of the creed, when it
            -- carries real weight per-capita.
            local best2, best2v = nil, 0
            for _, k in ipairs({ "order", "mercy", "wall", "road" }) do
                if k ~= creed.name then
                    local v = (creed.comp[k] or 0) / math.max(1, creed.size)
                    if v > best2v then best2, best2v = k, v end
                end
            end
            if best2 and best2v >= 0.25 then
                line = line .. ", " .. best2 .. "-tempered"
            end
            line = line .. ", " .. creed.size .. " strong]"
        end
        local policy = SAO.Standing.rationPolicyOf
            and SAO.Standing.rationPolicyOf(g) or nil
        if policy then line = line .. "  policy: " .. policy end
        local larder6 = SAO.Standing.larderOf
            and SAO.Standing.larderOf(g) or nil
        if larder6 then
            line = line .. "  larder: " .. tostring(larder6.word)
        end
        -- [B23] Who stands second, where a house believes in ranks
        -- at all. Its ABSENCE is the information: a house with no
        -- second is telling you it is flat.
        -- [B23] What kind of place this is to live.
        local form6 = SAO.Standing.formOf
            and SAO.Standing.formOf(g) or nil
        if form6 and form6 ~= "empty" then
            line = line .. "  " .. tostring(form6)
        end
        local second6 = SAO.Standing.secondOf
            and SAO.Standing.secondOf(g) or nil
        if second6 then
            local srec6 = SAO.Identity.get(second6)
            if srec6 then
                line = line .. "  second: "
                    .. tostring(SAO.Identity.displayName(srec6))
            end
        end
        local pool6 = SAO.Standing.motorPoolOf
            and SAO.Standing.motorPoolOf(g) or nil
        if pool6 and pool6.cars and #pool6.cars > 0 then
            -- [B19] Tell the truth about the wheels. This line used
            -- to read "wheels: 3 (12 seats)" for a yard of hulks.
            local road6 = SAO.Standing.roadworthy
                and SAO.Standing.roadworthy(g) or nil
            if road6 then
                local plain6 = tostring(road6.name or "car")
                plain6 = plain6:gsub("^Base%.", "")
                line = line .. "  wheels: " .. plain6
                    .. " (" .. (road6.free or 0) .. " seats"
                    .. (road6.open and "" or ", no key") .. ")"
            else
                line = line .. "  wheels: " .. #pool6.cars
                    .. ", none run"
            end
        end
        local water6 = SAO.Standing.waterStoreOf
            and SAO.Standing.waterStoreOf(g) or nil
        if water6 then
            line = line .. "  water: " .. tostring(water6.word)
        end
        local hearth6 = SAO.Standing.hearthOf
            and SAO.Standing.hearthOf(g) or nil
        if hearth6 then
            line = line .. "  hearth: "
                .. (hearth6.burning and "lit" or "dark")
        end
        local chair6 = SAO.Standing.playerChairOf
            and SAO.Standing.playerChairOf(g) or nil
        if chair6 then
            line = line .. "  chair: "
                .. tostring(chair6):gsub("^player:", "")
        end
        line = line .. (gc and ("  holds " .. gc.minX .. "," .. gc.minY)
            or "  (no ground)")
        row(line)
        -- [B23] Short, and saying so. [B23] made this a real county
        -- fact and the Ledger had no line for it - a player who
        -- cannot see who is hungry cannot read anything the wire
        -- says about it.
        if SAO.Standing.isAsking and SAO.Standing.isAsking(g) then
            row("   short - asking the county")
        end
        for g2 in pairs(groups) do
            if g2 ~= g and SAO.Standing.feudBetween(g, g2) then
                row("   at war with " .. tostring(
                    SAO.Standing.factionName(g2) or g2))
            elseif g2 ~= g and SAO.Standing.pactBetween
                and SAO.Standing.pactBetween(g, g2) then
                row("   in pact with " .. tostring(
                    SAO.Standing.factionName(g2) or g2))
            elseif g2 ~= g then
                -- [B23] Who fed whom. The debt is leader-to-leader
                -- because that is how [B23] records a gift, so this
                -- reads it exactly where it lives rather than
                -- inventing a house-level ledger beside it.
                local lead1 = SAO.Standing.leaderOf(g)
                local lead2 = SAO.Standing.leaderOf(g2)
                if lead1 and lead2
                    and SAO.Standing.debt(lead2, lead1) > 0 then
                    row("   owes " .. tostring(
                        SAO.Standing.factionName(g2) or g2)
                        .. " - they were fed")
                end
            end
        end
    end
    if not any then row("(no companies yet)") end
    do
        local solo9 = 0
        for _, r in pairs(SAO.Identity.all()) do
            if not r.dead and not SAO.Standing.groupOf(r.id) then
                solo9 = solo9 + 1
            end
        end
        if solo9 > 0 then
            row("keeping their own company: " .. solo9)
        end
    end

    local chron = {}
    local s = nil
    pcall(function() s = ModData.getOrCreate("SurvivorAwareness_Standing") end)
    for g in pairs(groups) do
        local fname2 = tostring(SAO.Standing.factionName(g) or g)
        local meta = s and s.groupMeta and s.groupMeta[tostring(g)] or nil
        for _, war in ipairs((meta and meta.feudHistory) or {}) do
            if war.liftedAtHours then
                chron[#chron + 1] = { at = war.liftedAtHours,
                    text = fname2 .. " fought " .. tostring(
                        SAO.Standing.factionName(war.other) or war.other)
                    .. " - peace on day "
                    .. math.floor((war.liftedAtHours or 0) / 24) }
            end
        end
        -- Governance in your absence ([A25]): the house's own
        -- decisions, discoverable.
        for _, ev in ipairs(SAO.Standing.govHistoryOf(g)) do
            if ev.kind == "policy" then
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " turned " .. tostring(ev.policy) }
            elseif ev.kind == "schism" then
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " broke - "
                    .. tostring(ev.left) .. " walked out" }
            elseif ev.kind == "pact" and tostring(g) < tostring(ev.other) then
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " and " .. tostring(
                        SAO.Standing.factionName(ev.other) or ev.other)
                    .. " shook on bread-for-watch" }
            elseif ev.kind == "creed" then
                -- [B23] A house turning is chronicle-grade. Written by
                -- the election and, until this line, dropped silently
                -- by the reader.
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " turned " .. tostring(ev.creed)
                    .. " - they were " .. tostring(ev.from) }
            elseif ev.kind == "form" then
                -- [B23] The operator's whole map. Flight is the one
                -- that is not a government: it is what is left when
                -- nobody held.
                local FORM_SAID = {
                    divided = "split into two minds",
                    council = "began deciding together",
                    ladder = "began keeping a second",
                    empty = "stopped speaking as one house",
                    flight = "gave up - lean, dry and dark",
                }
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " "
                    .. (FORM_SAID[ev.form] or tostring(ev.form)) }
            elseif ev.kind == "abandon" then
                -- [B42] And WHERE. The record kept only a timestamp,
                -- so this could say a house gave up their ground and
                -- never which ground - the one fact that makes it a
                -- place you could go and look at.
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " gave up their ground"
                    .. ((ev.atX and ev.atY)
                        and (" at " .. ev.atX .. "," .. ev.atY) or "") }
            elseif ev.kind == "chair" then
                -- [B42] Written since [A25] and dropped by the reader
                -- ever since, which is exactly what [B23] found for
                -- `creed`. Both of the kinds this Chronicle silently
                -- discarded are the two that are about YOU.
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " gave you a seat" }
            elseif ev.kind == "unseated" then
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": " .. fname2 .. " took your seat back" }
            elseif ev.kind == "pactBroke"
                and tostring(g) < tostring(ev.other) then
                chron[#chron + 1] = { at = ev.atHours,
                    text = "day " .. math.floor((ev.atHours or 0) / 24)
                    .. ": the pact with " .. tostring(
                        SAO.Standing.factionName(ev.other) or ev.other)
                    .. " broke" }
            end
        end
    end
    -- The day it started ([B1]): the county's own first witnessed
    -- horror, chronicled from its stamp - derives, never asserted.
    if s and s.tapsDryAtHours then
        chron[#chron + 1] = { at = s.tapsDryAtHours,
            text = "day " .. math.max(1,
                math.floor(s.tapsDryAtHours / 24))
            .. ": the taps ran dry" }
    end
    if s and s.firstTurnedAtHours then
        chron[#chron + 1] = { at = s.firstTurnedAtHours,
            text = "day " .. math.max(1,
                math.floor(s.firstTurnedAtHours / 24))
            .. ": the dead stopped staying dead" }
    end
    if s and s.outbreakAtHours then
        chron[#chron + 1] = { at = s.outbreakAtHours,
            text = "day " .. math.max(1,
                math.floor(s.outbreakAtHours / 24))
            .. ": the first of them was seen to kill" }
    end
    if #chron > 0 then
        table.sort(chron, function(a, b) return (a.at or 0) < (b.at or 0) end)
        header("Chronicle")
        for _, c in ipairs(chron) do row(c.text) end
    end

    if #recentDead > 0 then
        header("Lost")
        for i = 1, math.min(5, #recentDead) do
            local r = recentDead[i]
            row(tostring(SAO.Identity.displayName(r)) .. " - "
                .. tostring(r.deathCause or "unknown"))
        end
    end

    -- [B42] "Unnamed" is the ABSENCE of a name, not a name.
    --
    -- `backfillName` reads the name off the engine shell, so it needs a
    -- BODY - a survivor the county has never materialised has
    -- `forename == "Unnamed"` by design, and the comment there says so.
    -- Bonds form among the dormant, so this section rendered five rows
    -- of "Unnamed & Unnamed": a real fact about the county, printed as
    -- if the ledger knew who they were.
    --
    -- The convention already exists here - `SAO_Radio` and three sites
    -- in `SAO_Controller` all treat the sentinel as absence. This is
    -- the one surface that did not. Name the pairs the county has met,
    -- and COUNT the rest, which is the same idiom "Near you" already
    -- uses for the ones it cannot fit.
    local bondsShown = false
    local unmet = 0
    for _, r in pairs(SAO.Identity.all()) do
        if not r.dead then
            local mate = SAO.Standing.bondedWith(r.id)
            if mate and tostring(r.id) < tostring(mate) then
                local a = SAO.Identity.knownName(r)
                local b = SAO.Identity.knownName(SAO.Identity.get(mate))
                if a and b then
                    if not bondsShown then
                        header("Bonds")
                        bondsShown = true
                    end
                    row(a .. " & " .. b)
                else
                    unmet = unmet + 1
                end
            end
        end
    end
    if unmet > 0 then
        if not bondsShown then
            header("Bonds")
            bondsShown = true
        end
        row("(" .. unmet .. (unmet == 1 and " bond" or " bonds")
            .. " between people you have not met)")
    end

    -- [B42] Our county's news, on our surface, under our own rule.
    --
    -- This rendered another framework's world-event string verbatim:
    -- their text, unconditionally, on the one surface this mod owns -
    -- while our own `radioNews` queue reached the player only over a
    -- live wire. Their news was free and ours had to be earned. That is
    -- the influence running the wrong way, and it is the whole of what
    -- the operator asked to invert.
    --
    -- The PATTERN is worth keeping; the source was not. This reads our
    -- own queue and renders it through the wire's own composer, so
    -- there is one spelling of what a news item says rather than a
    -- second one growing here. And it applies the same physical gate
    -- the wire applies ([A26]): a county that talks to you without a
    -- radio is omniscience under a different name.
    --
    -- It PEEKS. `SAOWire.air` empties the queue when it broadcasts, so
    -- reading a surface must not consume what the wire has not yet
    -- said - a display that eats its own subject is [B39]'s defect
    -- with a header on it.
    pcall(function()
        local me3 = getSpecificPlayer(0)
        if not (me3 and SAO.RadioEar and SAO.RadioEar.hasLiveWireRadio
            and SAO.RadioEar.hasLiveWireRadio(me3)) then return end
        local s3 = ModData.getOrCreate("SurvivorAwareness_Standing")
        local news3 = type(s3) == "table" and s3.radioNews or nil
        if not (news3 and #news3 > 0 and SAOWire and SAOWire.render) then
            return
        end
        header("Word around the county")
        local aired3 = math.min(6, #news3)
        for i = 1, aired3 do
            row(tostring(SAOWire.render(news3[i])))
        end
        if #news3 > aired3 then
            row("(" .. (#news3 - aired3) .. " more waiting on the wire)")
        end
    end)

    return rows
end

function SAOCountyWindow:render()
    ISCollapsableWindow.render(self)
    -- [B18] The window LIVES: [B18] put live claims at the top of a
    -- surface that rendered once at open. Re-read on a cadence, not
    -- per frame - a full county scan every frame is exactly what the
    -- [B5] audit convicted elsewhere, and a window is not exempt.
    local okT, nowT = pcall(function() return getTimestampMs() end)
    if okT and nowT then
        if not self.lastBuiltMs or nowT - self.lastBuiltMs > 500 then
            self.lastBuiltMs = nowT
            self.rows = self:build()
        end
    end
    local rows = self.rows or {}
    local x = 12
    local y = self:titleBarHeight() + 8
    local lineS = getTextManager():getFontHeight(FONT_S) + 2
    local lineM = getTextManager():getFontHeight(FONT_M) + 4
    for _, r in ipairs(rows) do
        if y > self.height - 24 then
            self:drawText("...", x, y, 0.6, 0.6, 0.6, 1, FONT_S)
            break
        end
        if r.kind == "header" then
            y = y + 4
            self:drawText(fitText(r.text, FONT_M, self.width - x * 2),
                x, y, 0.88, 0.86, 0.70, 1, FONT_M)
            y = y + lineM
            self:drawRect(x, y - 2, self.width - x * 2, 1,
                0.5, 0.50, 0.48, 0.40)
        else
            self:drawText(
                fitText(r.text, FONT_S, self.width - (x + 6) - x),
                x + 6, y, 0.80, 0.82, 0.80, 1, FONT_S)
            y = y + lineS
        end
    end
end

function SAOCountyWindow:refresh()
    self.rows = self:build()
end

function SAOCountyWindow.toggle()
    if SAOCountyWindow.instance and SAOCountyWindow.instance:isVisible() then
        SAOCountyWindow.instance:setVisible(false)
        SAOCountyWindow.instance:removeFromUIManager()
        SAOCountyWindow.instance = nil
        return
    end
    -- [B18] Taller by default: the window carries a Near-you
    -- section now, and a window that truncates its chronicle
    -- to show it would have traded one surface for another.
    -- [B29] Where a panel goes is a question about the SCREEN, and
    -- this asked nothing. Hard-coded at (120, 100) it sat off to the
    -- left of a wide display and did not fit a small one at all.
    -- Centred, and never larger than the screen it has to live on -
    -- the minimums in :new() still hold, so it degrades to a scroll
    -- rather than to nothing.
    local sw, sh = 1920, 1080
    pcall(function()
        local core = getCore()
        if core then
            sw = core:getScreenWidth() or sw
            sh = core:getScreenHeight() or sh
        end
    end)
    -- [B29] Provisional only. The real size is measured below, from
    -- the text this window is actually about to draw.
    local w = SAOCountyWindow:new(0, 0, 470, 560)
    w:initialise()
    w:refresh()

    -- [B29] A window the size of what is in it.
    --
    -- 470 by 560 was 470 by 560 because someone typed it. Fonts are
    -- not a fixed height across machines and B21 exposes no UI render
    -- scale on Core to read, so the only honest measure is the text
    -- itself. [B29]'s truncation stays underneath as the floor for a
    -- screen that genuinely cannot fit a line - it is the fallback
    -- now, not the mechanism.
    local ww, wh = 380, 260
    pcall(function()
        local tm = getTextManager()
        if not tm then return end
        local widest = 0
        for _, r in ipairs(w.rows or {}) do
            local font = (r.kind == "header") and FONT_M or FONT_S
            local indent = (r.kind == "header") and 0 or 6
            local sx = tm:MeasureStringX(font, tostring(r.text or ""))
            if sx and sx + indent > widest then widest = sx + indent end
        end
        local lineS = tm:getFontHeight(FONT_S) + 2
        local lineM = tm:getFontHeight(FONT_M) + 4
        local tall = w:titleBarHeight() + 8
        for _, r in ipairs(w.rows or {}) do
            tall = tall + ((r.kind == "header") and (lineM + 4) or lineS)
        end
        -- x margin is 12 a side in the render, plus the scrollbar's
        -- worth of slack so a line never sits flush to the frame.
        ww = widest + 12 * 2 + 8
        wh = tall + 16
    end)
    ww = math.max(380, math.min(ww, sw - 80))
    wh = math.max(260, math.min(wh, sh - 120))
    w:setWidth(ww)
    w:setHeight(wh)
    w:setX(math.max(0, math.floor((sw - ww) / 2)))
    w:setY(math.max(0, math.floor((sh - wh) / 2)))
    w:addToUIManager()
    SAOCountyWindow.instance = w
end

return SAOCountyWindow
