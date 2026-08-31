-- SAO_Radio - the county wire ([A26]).
-- ---------------------------------------------------------------------------
-- A survivor-run transmitter on the amateur band: the county's politics
-- and losses, aired through the game's OWN radio system so the player
-- hears governance happen from a shelf radio tuned to 101.2. Built on
-- the vanilla DynamicRadio plug-in pattern (exemplar: ISWeatherChannel)
-- - channel inserted at load, script called back hourly. News items are
-- CLAIMS (ids, kinds); all text is rendered here at air time.

if not DynamicRadio then return end

-- [B37] The band, declared ONCE. It was written here and again in
-- SAO_RadioEar, and two constants that must agree are the shape that
-- fails silently: change one and the county broadcasts on a band it
-- does not listen to, with no error and no log - just survivors who
-- stop hearing the player, which looks exactly like nobody talking.
SAOWire = { channelUUID = "SAO-CW-0451", freq = 101200 }

table.insert(DynamicRadio.channels, {
    name = "The County Wire",
    freq = SAOWire.freq,
    category = "Amateur",
    uuid = SAOWire.channelUUID,
    register = true,
})

local function nameOf(id)
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if rec and SAO.Identity.displayName then
        return SAO.Identity.displayName(rec)
    end
    return tostring(id)
end

local function houseOf(group)
    local n = SAO.Standing and SAO.Standing.factionName
        and SAO.Standing.factionName(group) or nil
    return "the " .. tostring(n or group)
end

local POLICY_PHRASE = {
    ["watch-first"] = "the watch first now",
    ["house-first"] = "their own and no one else",
    ["weak-first"] = "the weakest first, official now",
    ["carry-light"] = "light packs, nothing held back",
}

function SAOWire.render(item)
    if item.kind == "election" then
        return "Word from the camps: " .. houseOf(item.group)
            .. " chose " .. nameOf(item.leader) .. " to lead."
    elseif item.kind == "policy" then
        return houseOf(item.group) .. " feed "
            .. (POLICY_PHRASE[item.policy] or tostring(item.policy)) .. "."
    elseif item.kind == "creed" then
        -- [B23] A house changing what it believes is news on the wire
        -- for the same reason a new chair is.
        return houseOf(item.group) .. " have turned. Different house"
            .. " than it was a month ago."
    elseif item.kind == "ask" then
        return houseOf(item.group) .. " are short. Shelves down to"
            .. " nothing. They're not too proud to say it."
    elseif item.kind == "form" then
        if item.form == "divided" then
            return houseOf(item.group) .. " are arguing with themselves."
                .. " Two minds under one roof. Don't take a side."
        elseif item.form == "council" then
            return houseOf(item.group) .. " talk it out now. Nobody"
                .. " there speaks for the rest."
        elseif item.form == "ladder" then
            return houseOf(item.group) .. " keep a second now. If the"
                .. " leader's not there, someone still speaks for them."
        elseif item.form == "flight" then
            return houseOf(item.group) .. " are done. Shelves bare,"
                .. " bottles dry, fire out. They're walking."
        end
        return houseOf(item.group) .. " answer to nobody in particular"
            .. " any more."
    elseif item.kind == "feud" then
        return houseOf(item.a) .. " and " .. houseOf(item.b)
            .. " have gone to war. Keep clear of both."
    elseif item.kind == "peace" then
        return "The war between " .. houseOf(item.a) .. " and "
            .. houseOf(item.b) .. " is over. The leaders shook on it."
    elseif item.kind == "schism" then
        return houseOf(item.group) .. " broke. " .. tostring(item.left)
            .. " walked out. Watch the roads."
    elseif item.kind == "death" then
        return "We lost " .. nameOf(item.id) .. "."
    elseif item.kind == "pact" then
        return houseOf(item.a) .. " and " .. houseOf(item.b)
            .. " shook on a pact - bread for watch. The county gets"
            .. " smaller, in the good way."
    elseif item.kind == "pactBroke" then
        return "The pact between " .. houseOf(item.a) .. " and "
            .. houseOf(item.b) .. " is off. Draw your own conclusions."
    elseif item.kind == "abandon" then
        return houseOf(item.group) .. " has given up their ground."
            .. " Lean, dry, and cold. They're on the road now."
    elseif item.kind == "tapsDry" then
        return "The water's stopped. Taps are dry county-wide. Fill"
            .. " what you can from the rivers and boil it."
    elseif item.kind == "turned" then
        return "The dead are not staying dead. Someone we knew was"
            .. " seen walking. Burn your bitten bandages and pray."
    elseif item.kind == "outbreak" then
        return "Something is wrong. Someone was KILLED - by one of"
            .. " those things. Lock your doors. This is not a drill."
    elseif item.kind == "skirmish" then
        return "Blood between " .. houseOf(item.a) .. " and "
            .. houseOf(item.b) .. ". The feud is hot. Stay off"
            .. " their roads."
    elseif item.kind == "stranger" then
        -- [B28] Said "a walker", which in this genre is a
        -- zombie. The news KIND was always right - `stranger`
        -- is a fact about acquaintance, which is exactly what
        -- the county wire is in a position to report.
        return "Someone new came in off the road. The county"
            .. " counts one more."
    elseif item.kind == "chair" then
        return houseOf(item.group) .. " put a new voice in the chair."
            .. " County business runs through them now."
    elseif item.kind == "unseated" then
        return houseOf(item.group) .. " took the chair back. The house"
            .. " steers itself again."
    elseif item.kind == "aidCall" then
        return "A call for aid went out on the band. Someone's moving."
    elseif item.kind == "onAir" then
        return "Someone new was on the band. You know who you are. "
            .. "Keep talking."
    end
    return nil
end

local function say(bc, text)
    if text then
        bc:AddRadioLine(RadioLine.new(text, 0.35, 0.85, 0.45))
    end
end

-- The bulletin composer, callable on demand ([A26]) as well as on
-- the hourly cadence. force=true airs the beacon even off-schedule
-- when there is no news (the caller ASKED; the wire answers).
function SAOWire.air(_channel, force)
    local ok, s = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Standing")
    end)
    if not ok or type(s) ~= "table" then return false end
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    local now = okH and h or 0
    local news = s.radioNews
    if news and #news > 0 then
        local bc = RadioBroadCast.new(
            "SAOW-" .. tostring(ZombRand(100000, 999999)), -1, -1)
        say(bc, "This is the county wire.")
        local aired = math.min(#news, 6)
        for i = 1, aired do say(bc, SAOWire.render(news[i])) end
        if #news > aired then
            local rest = {}
            for i = aired + 1, #news do rest[#rest + 1] = news[i] end
            s.radioNews = rest
        else
            s.radioNews = {}
        end
        say(bc, "That's the news. Hold your ground.")
        _channel:setAiringBroadcast(bc)
        s.radioLastAirAt = now
        -- The county hears its own news ([B9]).
        local airedItems = {}
        for i = 1, aired do airedItems[#airedItems + 1] = news[i] end
        local okD, reached = pcall(function()
            return SAOWire.deliverToListeners(airedItems)
        end)
        if okD and reached and reached > 0 then
            SAO.Log.line("WIRE", "the bulletin reaches " .. reached
                .. " listener(s)")
        end
        return true
    elseif force or now - (s.radioLastAirAt or 0) >= 12 then
        -- Dead air is diegetic for a survivor band; the beacon is the
        -- find-the-frequency hook, not a chatterbox.
        local bc = RadioBroadCast.new(
            "SAOW-" .. tostring(ZombRand(100000, 999999)), -1, -1)
        -- The era decides the beacon's voice ([B3]/T-002): a county
        -- that has not fallen hears a hobbyist ham; a county that has
        -- hears the lifeline.
        if s.outbreakAired then
            say(bc, "This is the county wire on one-oh-one-point-two.")
            say(bc, "No news tonight. If you can hear this, you're"
                .. " not alone.")
        else
            say(bc, "This is the county wire on one-oh-one-point-two,"
                .. " your amateur voice in the valley.")
            say(bc, "Quiet evening. Clear skies tomorrow. 4-H results"
                .. " read Thursday as usual.")
        end
        _channel:setAiringBroadcast(bc)
        s.radioLastAirAt = now
        return true
    end
    return false
end

-- The county listens ([B9]): the claims behind an aired bulletin
-- reach everyone who really owns a receiver, at TOLD weight - the
-- same as a neighbour's word, which is what a broadcast is. Only
-- the kinds that map to a belief a person can HOLD are delivered;
-- announcements are not knowledge.
-- [B27] What hearing the wire DOES, defined once.
--
-- This used to be the body of a loop over survivors, which meant the
-- player - who owns a receiver the same way, and who literally sits
-- there listening to the broadcast - received words while everyone
-- else received knowledge. One definition and two callers, the same
-- shape [B20] used for the cry, because copying the formula is how
-- the two drift apart.
--
-- `reactive` is the one honest asymmetry. A survivor hearing that
-- someone they were bonded to is dead LEARNS something from it and
-- their voice changes; that is their interior, modelled because it
-- has to be. A player has their own interior and does not need one
-- issued. What CROSSES is identical either way, which is the whole
-- of the operator's law.
local function hearTheWire(key, b, items, reactive)
    local heardSomething = false
    for _, item in ipairs(items) do
        if item.kind == "death" and item.id ~= key then
            local drec = SAO.Identity.get(item.id)
            local dname = drec
                and SAO.Identity.displayName(drec) or nil
            if dname and dname ~= "Unnamed" then
                -- [B28] `wasNews` is per-DEATH. This used to read
                -- the cumulative `heardSomething`, which a feud
                -- earlier in the same bulletin had already set - so a
                -- death the listener already knew about fired the
                -- handler anyway. The guard said "if we heard
                -- something" and meant "if THIS death was news".
                local wasNews = false
                local pb = b.people[dname]
                if pb then
                    if not pb.dead then
                        pb.dead = true
                        wasNews = true
                    end
                else
                    b.people[dname] = {
                        x = drec.x, y = drec.y, dist = 999,
                        at = 0, source = "told",
                        dead = true,
                    }
                    wasNews = true
                end
                if wasNews then heardSomething = true end
                if reactive and wasNews
                    and SAO.Perception.deathNewsHandler then
                    pcall(SAO.Perception.deathNewsHandler,
                        key, dname, 0)
                end
            end
        elseif item.kind == "feud" or item.kind == "peace" then
            local stance = (item.kind == "feud")
                and "wary" or "neutral"
            for _, g in ipairs({ item.a, item.b }) do
                -- Only houses they already KNOW: a name on
                -- the radio is not a place on your map.
                if g and b.factions and b.factions[g] then
                    SAO.Perception.setFactionStance(key, g, stance)
                    heardSomething = true
                end
            end
        end
    end
    return heardSomething
end

function SAOWire.deliverToListeners(items)
    if not (SAO.Identity and SAO.Standing and SAO.Perception) then
        return 0
    end
    local reached = 0
    for _, rec in pairs(SAO.Identity.all()) do
        if not rec.dead and SAO.Standing.ownsRadio
            and SAO.Standing.ownsRadio(rec.id) then
            local b = SAO.Perception.beliefs[rec.id]
            if b and hearTheWire(rec.id, b, items, true) then
                reached = reached + 1
            end
        end
    end
    -- [B27] And you, on the same terms: only if you are carrying a
    -- receiver, into the same belief store, at the same `told`
    -- provenance. This is what makes the news yours to pass on -
    -- [B27] gave you a mouth and this is what puts something in it.
    pcall(function()
        local me = getSpecificPlayer(0)
        if not me or me:isDead() then return end
        local myKey = SAO.Standing.playerKey(me)
        if not myKey then return end
        if not SAO.Standing.ownsRadio(myKey, me) then return end
        local b = SAO.Perception.beliefs[myKey]
        if b and hearTheWire(myKey, b, items, false) then
            reached = reached + 1
        end
    end)
    return reached
end

function SAOWire.OnEveryHour(_channel, _gametime, _radio)
    SAOWire.air(_channel, false)
end

-- On-demand airing from the call verbs ([A26]).
function SAOWire.airNow()
    local chan = DynamicRadio and DynamicRadio.cache
        and DynamicRadio.cache[SAOWire.channelUUID] or nil
    if not chan then return false end
    return SAOWire.air(chan, true)
end

function SAOWire.OnLoadRadioScripts()
    table.insert(DynamicRadio.scripts, SAOWire)
end

Events.OnLoadRadioScripts.Add(SAOWire.OnLoadRadioScripts)
