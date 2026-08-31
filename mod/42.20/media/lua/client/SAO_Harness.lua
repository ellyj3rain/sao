-- SAO_Harness — the operator's manual play-surface (context menu).
-- ---------------------------------------------------------------------------
-- Available in normal play (pre-alpha, private mod). Spawns here are
-- operator ACTS, distinct from world-origin population genesis; the menu
-- always operates on the NEWEST harness survivor (older ones remain full
-- citizens of the population layer). Every layer logs its own prefix, so a
-- failure localizes to one layer from the console alone. Cap: 4 harness
-- survivors.

SAO = SAO or {}
SAO.Harness = SAO.Harness or { activeId = nil }
local H = SAO.Harness

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("HARNESS", msg) end

local MAX_SURVIVORS = 4

local function countActive()
    local n = 0
    for _ in pairs(SAO.Controller.agents) do n = n + 1 end
    return n
end

local function spawn(playerObj)
    if countActive() >= MAX_SURVIVORS then
        log("refused: population cap " .. MAX_SURVIVORS .. " reached")
        return
    end
    if H.activeId and SAO.Body.get(H.activeId) then
        log("spawning additional survivor (" .. (countActive() + 1) .. "/" .. MAX_SURVIVORS .. ")")
        H.activeId = nil
    end
    if H.activeId then
        log("refused: pending record " .. H.activeId .. " exists")
        return
    end
    local x = math.floor(playerObj:getX()) + 2
    local y = math.floor(playerObj:getY())
    local z = math.floor(playerObj:getZ())
    local rec = SAO.Identity.create(nil, nil, x, y, z)
    if not rec then return end
    pcall(function() SAO.History.generate(rec.id, rec) end)
    local body = SAO.Body.materialize(rec)
    if not body then
        log("materialize failed; record " .. rec.id .. " kept for a retry")
        H.activeId = rec.id
        return
    end
    SAO.Controller.adopt(rec)
    H.activeId = rec.id
    log("slice survivor up: " .. rec.id .. ". Right-click a square -> 'SAO: walk here'.")
end

local function rematerialize()
    if not H.activeId then log("nothing to rematerialize") return end
    local rec = SAO.Identity.get(H.activeId)
    if not rec then log("record missing for " .. tostring(H.activeId)) return end
    if SAO.Body.get(rec.id) then log("body already active") return end
    local body = SAO.Body.materialize(rec)
    if body then
        SAO.Controller.adopt(rec)
        log("rematerialized " .. rec.id .. " at its recorded square "
            .. rec.x .. "," .. rec.y .. " - persistent person, temporary body")
    end
end

local function walkHere(worldobjects)
    if not H.activeId then log("no slice survivor") return end
    local sq = nil
    for _, o in ipairs(worldobjects or {}) do
        local ok, s = pcall(function() return o:getSquare() end)
        if ok and s then sq = s break end
    end
    if not sq then log("walkHere: no square under cursor") return end
    -- A goal on or beside the body's own square succeeds trivially and tells
    -- us nothing (two live runs wasted on it). Demand a real trip.
    local body = SAO.Body.get(H.activeId)
    if body then
        local dx = sq:getX() - body:getX()
        local dy = sq:getY() - body:getY()
        -- [B47] Not a number that happens to be three: a goal
        -- inside arrival is one the body is already at, which is why
        -- two live runs were wasted on trips that succeeded without
        -- moving. Read from the Controller, since arrival is its rule.
        local reach = SAO.Controller.ARRIVAL_REACH
        if dx * dx + dy * dy < reach * reach then
            log("walkHere refused: goal inside arrival reach ("
                .. tostring(reach) .. " tiles) - click farther away")
            return
        end
    end
    SAO.Controller.orderTravel(H.activeId, sq:getX(), sq:getY(), sq:getZ())
end

local function status()
    if not H.activeId then log("status: no slice survivor") return end
    local rec = SAO.Identity.get(H.activeId)
    local body = SAO.Body.get(H.activeId)
    log("status " .. tostring(H.activeId)
        .. " | record=" .. (rec and (rec.x .. "," .. rec.y) or "MISSING")
        .. " | body=" .. (body and string.format("%.1f,%.1f", body:getX(), body:getY()) or "released")
        .. " | loco=" .. SAO.Locomotion.status(H.activeId)
        .. " | records=" .. SAO.Identity.count()
        .. " bodies=" .. SAO.Body.activeCount())
end

local function release()
    if not H.activeId then log("nothing to release") return end
    local rec = SAO.Identity.get(H.activeId)
    SAO.Controller.drop(H.activeId)
    if rec then SAO.Body.release(rec) end
    log("released. Record kept - 'rematerialize' must restore the person at "
        .. (rec and (rec.x .. "," .. rec.y) or "?"))
end

local function forget()
    if not H.activeId then log("nothing to forget") return end
    SAO.Controller.drop(H.activeId)
    local rec = SAO.Identity.get(H.activeId)
    if rec and SAO.Body.get(rec.id) then SAO.Body.release(rec) end
    SAO.Identity.remove(H.activeId)
    pcall(function() SAO.Perception.forget(H.activeId) end)
    pcall(function() SAO.Voice.forget(H.activeId) end)
    log("forgot " .. H.activeId .. " entirely (record + body + beliefs)")
    H.activeId = nil
end

-- Any SAO survivor near the clicked square resolves by proximity (S5).
local function survivorNear(worldobjects)
    local sq = nil
    for _, o in ipairs(worldobjects or {}) do
        local ok, s = pcall(function() return o:getSquare() end)
        if ok and s then sq = s break end
    end
    if not sq then return nil end
    local bestId, bestD
    local function consider(id, body)
        local ok, d = pcall(function()
            local dx = body:getX() - sq:getX()
            local dy = body:getY() - sq:getY()
            return dx * dx + dy * dy
        end)
        if ok and d <= 9.0 and (not bestD or d < bestD) then
            bestId, bestD = id, d
        end
    end
    -- F-032: BOTH registries - the under-cursor verbs must reach Knox
    -- inhabitants too, or "one social world" ends at the menu.
    for id, body in pairs(SAO.Body.active) do consider(id, body) end
    for id, body in pairs(SAO.Body.knox or {}) do consider(id, body) end
    return bestId
end

local function playerKeyOf(playerObj)
    -- [B27] One spelling, in Standing.
    return SAO.Standing.playerKey(playerObj)
end

-- Talk: the same word-of-mouth machinery, player-ward. The survivor
-- shares what they would share (a warning line, a lesson if trust
-- permits), and the moment counts as an encounter.
-- Talk ([A15] S5b): one line per talk, drawn from what the survivor
-- actually KNOWS by the same provenance machinery everything else uses -
-- their best lesson, a faction they can name, a place they hold the
-- belief about - trust-gated, cycling so repeat talks reveal a person.
-- Cooldown is GAME hours, aligned with the audited reference.
local function talkTo(playerObj, id)
    local body = SAO.Body.get(id)
    if not body then return end
    local key = playerKeyOf(playerObj)
    local okH, nowHours = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    nowHours = okH and nowHours or 0
    SAO.Harness.talkCooldowns = SAO.Harness.talkCooldowns or {}
    if (SAO.Harness.talkCooldowns[id] or 0) > nowHours then
        log("they need a while")
        return
    end
    SAO.Harness.talkCooldowns[id] = nowHours + 1.0
    SAO.Standing.adjustTrust(id, key, 0.02)

    local spoke = false
    if SAO.Standing.trust(id, key) >= 0.3 then
        SAO.Harness.talkTurn = SAO.Harness.talkTurn or {}
        local turn = (SAO.Harness.talkTurn[id] or 0) + 1
        SAO.Harness.talkTurn[id] = turn
        local offers = {}
        local rec = SAO.Identity.get(id)
        -- The whole person speaks ([A20]): who they were, where it
        -- started, what they do now, whose colors they wear, and the
        -- dead they carry - all RENDERED from claims at read time,
        -- rotating through the same one-line-per-talk cycle as
        -- everything they know.
        if rec then
            local trade = SAO.Census and SAO.Census.describe
                and SAO.Census.describe(rec) or nil
            if trade then
                offers[#offers + 1] = "I " .. trade .. "."
            end
            local origin = SAO.Census and SAO.Census.originNote
                and SAO.Census.originNote(rec) or nil
            if origin then
                offers[#offers + 1] = "For me it started at " .. origin .. "."
            end
            -- The sky is common ground ([B17]): everyone has an
            -- opinion about the weather, and in this world it is
            -- never small talk.
            do
                local okW28, raining28 = pcall(function()
                    return getClimateManager():isRaining()
                end)
                if okW28 and raining28 then
                    offers[#offers + 1] = "Rain's good for the rows and"
                        .. " bad for the ears. Can't hear a thing coming."
                end
            end
            -- Thirst travels faster than hunger ([B6]).
            do
                local wgT = SAO.Standing.groupOf(id)
                local wsT = wgT and SAO.Standing.waterStoreOf
                    and SAO.Standing.waterStoreOf(wgT) or nil
                if wsT and wsT.word == "dry" then
                    offers[#offers + 1] = "We're short on water. If you"
                        .. " know a clean source, that's worth more than"
                        .. " food right now."
                end
            end
            -- The shelves travel by mouth ([A28]): a member of a
            -- house that KNOWS it is short says so.
            local lgT5 = SAO.Standing.groupOf(id)
            if lgT5 then
                local lt5 = SAO.Standing.larderOf
                    and SAO.Standing.larderOf(lgT5) or nil
                if lt5 and lt5.word == "lean" then
                    offers[#offers + 1] = "Shelves are thin at ours."
                        .. " Eat light, or bring something."
                end
            end
            -- The bitten speak ([B3]): their own body, read direct;
            -- the fearful deny it, the composed face it, the middle
            -- say nothing - silence is also true.
            do
                local bitten3 = false
                pcall(function()
                    local bd3 = SAO.Body.get(id)
                    bitten3 = bd3 and bd3:getBodyDamage()
                        :getNumPartsBitten() > 0 or false
                end)
                if bitten3 then
                    local n3 = SAO.Disposition.traits(id).nerve
                    if n3 < 0.45 then
                        offers[#offers + 1] =
                            "It's just a scratch. Barely broke skin."
                    elseif n3 >= 0.55 then
                        offers[#offers + 1] =
                            "If I turn, you do it. Promise me."
                    end
                end
            end
            -- The day it changed for them ([B1]): the hardened can
            -- name it - rendered from their earliest dated lesson,
            -- never stored as prose.
            do
                local fh9 = SAO.Lessons.firstLessonHours
                    and SAO.Lessons.firstLessonHours(id) or nil
                if fh9 then
                    offers[#offers + 1] =
                        "I stopped believing it would pass on day "
                        .. math.max(1, math.floor(fh9 / 24)) .. "."
                end
            end
            -- The innocent speak ([B1]/T-002): a person the world
            -- has taught NOTHING yet talks like it - the fall has not
            -- reached them. The line retires itself the day their
            -- first lesson lands.
            if SAO.Lessons.hasAny and not SAO.Lessons.hasAny(id) then
                offers[#offers + 1] =
                    "It has to blow over soon, right? These things do."
                offers[#offers + 1] =
                    "The radio said stay indoors. It'll pass."
            end
            -- The circle is who they are ([A27]): loners and
            -- band-keepers SAY it - the refusal you got is a person,
            -- not a bug.
            do
                local circ9 = SAO.Disposition.circle
                    and SAO.Disposition.circle(id) or nil
                if circ9 == "loner" then
                    offers[#offers + 1] =
                        "I keep my own company. Always have."
                elseif circ9 == "band" then
                    offers[#offers + 1] =
                        "Small circles stay alive. Big camps draw teeth."
                end
            end
            -- The highway is a memory ([A27]): those who walked in
            -- say so, and how long ago.
            if rec.newcomer and rec.arrivedAtHours then
                local okNH, nh = pcall(function()
                    return GameTime.getInstance():getWorldAgeHours()
                end)
                local days87 = okNH
                    and math.max(1, math.floor((nh - rec.arrivedAtHours) / 24))
                    or 1
                offers[#offers + 1] = "I walked in off the highway "
                    .. days87 .. (days87 == 1 and " day" or " days")
                    .. " back."
            end
            if rec.designation then
                offers[#offers + 1] = (rec.designation == "leads")
                    and "They look to me now. Somebody has to."
                    or ("I keep the " .. rec.designation .. " work these days.")
            end
            local myGroup = SAO.Standing.groupOf(id)
            if myGroup then
                local creed = SAO.Standing.creedOf(myGroup)
                local fname = SAO.Standing.factionName(myGroup)
                if creed and fname then
                    local CREED_LINES = {
                        order = "We keep rules and watches. It works.",
                        mercy = "We take people in. That's the point of us.",
                        wall = "We hold our ground and keep our doors.",
                        road = "We stay light and stay quiet.",
                    }
                    offers[#offers + 1] = "I'm with the " .. fname .. ". "
                        .. (CREED_LINES[creed.name] or "")
                end
                -- The deal is common knowledge in the house ([A26]).
                if SAO.Standing.pactBetween then
                    local s2 = nil
                    pcall(function()
                        s2 = ModData.getOrCreate("SurvivorAwareness_Standing")
                    end)
                    local meta2 = s2 and s2.groupMeta
                        and s2.groupMeta[tostring(myGroup)] or nil
                    if meta2 and meta2.pactWith then
                        for og in pairs(meta2.pactWith) do
                            offers[#offers + 1] = "We trade bread for"
                                .. " watch with the " .. tostring(
                                    SAO.Standing.factionName(og) or og)
                                .. ". It holds."
                            break
                        end
                    end
                end
            end
            -- The wire spreads by word of mouth ([A26]): people who
            -- live in this county know where the voice is.
            offers[#offers + 1] =
                "There's a voice on one-oh-one-point-two. Tune it "
                .. "sometime - you'll hear the county."
            -- The chair is acknowledged ([A27]): the house you
            -- chair asks for its orders.
            if myGroup and SAO.Standing.playerChairOf
                and SAO.Standing.playerChairOf(myGroup) == key then
                offers[#offers + 1] =
                    "You have the chair. Tell us where to stand."
            end
            -- And it runs both ways ([A26]): if their house caught
            -- your voice on the band, they SAY so.
            if SAO.Standing.heardPlayerOnAir
                and SAO.Standing.heardPlayerOnAir(id) then
                -- The voice of the line fits the hearer ([A27]): a
                -- house says we; a lone listener speaks for one.
                offers[#offers + 1] = SAO.Standing.groupOf(id)
                    and "We heard you on the wire. Good to know your voice."
                    or "Caught your voice on the wire. Good to know it."
            end
            -- Ghost camps ([A21]): a Knox inhabitant lived the
            -- county's history - they can tell you which camps
            -- emptied, and why. RENDERED read-only from the legacy
            -- store at talk time; nothing copied, nothing stored. Our
            -- own people do not retell these (no belief carries them) -
            -- a named gap, honest: this is THEIR history.
            local ksData = nil
            if rec.knox then
                local okD, d = pcall(function()
                    return ModData.getOrCreate("KnoxSurvivorsWorld")
                end)
                ksData = okD and type(d) == "table" and d or nil
            end
            if ksData then
                do
                    local shown = 0
                    for _, camp in pairs(ksData.abandonedCamps or {}) do
                        if shown >= 2 then break end
                        if camp and camp.x then
                            shown = shown + 1
                            local why2 = tostring(camp.reason or "emptied")
                            offers[#offers + 1] = "There was a camp near "
                                .. math.floor(camp.x) .. ","
                                .. math.floor(camp.y) .. ". "
                                .. ((why2 == "killed" or why2 == "wiped"
                                    or why2 == "death")
                                    and "Nobody walked away from it."
                                    or "They gave it up. Places do that now.")
                        end
                    end
                end
                -- Word around camp ([A22]): the legacy world's own
                -- last pulse, in a Knox mouth - one line, read-only.
                local pulse = type(ksData.jobEvents) == "table"
                    and ksData.jobEvents.lastWorldEvent or nil
                if pulse and pulse ~= "No world event pulse yet" then
                    offers[#offers + 1] = "Word around camp: "
                        .. tostring(pulse)
                end
                -- Our camp's own doings ([A24]): the KS base carries a
                -- life pulse (mood, milestone, rumor) - THEIR camp
                -- speaks it, read-only.
                do
                    local entry = (ksData.survivors or {})[
                        string.match(rec.id or "", "^ks:(.+)$") or ""]
                    local grp = entry and entry.groupId
                        and (ksData.groups or {})[entry.groupId] or nil
                    local kbase = grp and grp.baseId
                        and (ksData.bases or {})[grp.baseId] or nil
                    local life = kbase and kbase.life or nil
                    if life then
                        if life.nextMilestone then
                            offers[#offers + 1] = "Camp's set on this: "
                                .. tostring(life.nextMilestone) .. "."
                        end
                        if life.rumor then
                            offers[#offers + 1] = "There's talk of "
                                .. tostring(life.rumor) .. "."
                        end
                    end
                end
                -- Their buried ([A21]): the legacy memorial roll in a
                -- Knox mouth - the county's whole past has voices.
                do
                    local mems = ksData.memorials or {}
                    local shown2 = 0
                    for i = #mems, 1, -1 do
                        if shown2 >= 2 then break end
                        local m = mems[i]
                        if m and m.name then
                            shown2 = shown2 + 1
                            offers[#offers + 1] = "We buried "
                                .. tostring(m.name) .. ". "
                                .. ((m.cause == "combat"
                                    or m.cause == "killed")
                                    and "It wasn't the quiet kind of end."
                                    or "The county took them.")
                        end
                    end
                end
            end
            -- The dead they carry: anyone they believe dead, spoken
            -- once in the cycle - the county's memory has voices.
            local myBeliefs = SAO.Perception.beliefs[id]
            if myBeliefs then
                for pname, pb in pairs(myBeliefs.people) do
                    if pb.dead then
                        offers[#offers + 1] = pname .. " is gone. "
                            .. ((pb.source == "told")
                                and "That's what I heard, anyway."
                                or "I was there.")
                    end
                end
            end
        end
        if rec and rec.lessonsKnown then
            for lessonKey in pairs(rec.lessonsKnown) do
                local entry = SAO.Lessons.REGISTRY[lessonKey]
                if entry and entry.line then
                    offers[#offers + 1] = entry.line
                end
            end
        end
        local beliefs = SAO.Perception.beliefs[id]
        if beliefs then
            for g, fb in pairs(beliefs.factions or {}) do
                offers[#offers + 1] = (fb.name
                    and ("The " .. fb.name .. " hold a place at ")
                    or "Somebody holds a place at ")
                    .. fb.baseX .. "," .. fb.baseY .. "."
            end
            for ownerKey, pc in pairs(beliefs.places or {}) do
                local orec = SAO.Identity.get(ownerKey)
                -- [B42] "Unnamed" is absence, not a name.
                offers[#offers + 1] = (SAO.Identity.knownName(orec)
                    or "Somebody") .. "'s place is around "
                    .. math.floor((pc.minX + pc.maxX) / 2) .. ","
                    .. math.floor((pc.minY + pc.maxY) / 2) .. ". Leave it be."
            end
        end
        -- The medium is the moment ([A24]): context outranks the
        -- rotation. A company at war talks about the war; fresh grief
        -- speaks first; standing inside their claim gets you the
        -- territory line. Otherwise the rotation reveals the person.
        local contextual = nil
        do
            -- The debt speaks first ([A26]): you called, they came,
            -- and the person you owe does not make small talk.
            if SAO.Standing.debt(id, key) > 0 then
                contextual = "You called, we came. The house remembers"
                    .. " what's owed."
            end
            -- Your bite is seen ([B3]): a survivor who BELIEVES the
            -- player bitten says so to their face - outranks
            -- smalltalk, below the debt.
            if not contextual then
                local pname3 = nil
                pcall(function()
                    pname3 = tostring(getSpecificPlayer(0):getUsername())
                end)
                local b3 = SAO.Perception.beliefs[id]
                local ppb3 = b3 and pname3 and b3.people[pname3] or nil
                if ppb3 and ppb3.condition == "bitten" then
                    contextual = "Your arm. Show me your arm."
                end
            end
            -- The offer is spoken ([A27]): a chair on the table is
            -- not a secret; the house SAYS it.
            if not contextual then
                local og6 = SAO.Standing.groupOf(id)
                if og6 and SAO.Standing.chairOfferOf
                    and SAO.Standing.chairOfferOf(og6) == key then
                    contextual = "The house wants you in the chair."
                        .. " Say the word."
                end
            end
            local myG3 = SAO.Standing.groupOf(id)
            if not contextual and myG3 then
                for og3 in pairs(SAO.Standing.allGroupClaims()) do
                    if og3 ~= myG3
                        and SAO.Standing.feudBetween(myG3, og3) then
                        contextual = "We're at war with the "
                            .. tostring(SAO.Standing.factionName(og3) or og3)
                            .. ". Keep clear of their roads."
                        break
                    end
                end
            end
            if not contextual and rec and rec.lessonMeta then
                for _, tk in ipairs({ "nothing-left-to-lose",
                    "never-again-that-close" }) do
                    local meta3 = rec.lessonMeta[tk]
                    if meta3 and meta3.src == "lived" and meta3.of then
                        contextual = "I lost " .. tostring(meta3.of)
                            .. ". Don't ask for more than that."
                        break
                    end
                end
            end
            if not contextual then
                local pOk, px3, py3 = pcall(function()
                    return playerObj:getX(), playerObj:getY()
                end)
                if pOk and SAO.Standing.insideClaim(id, px3, py3) then
                    contextual = "You're standing in my home. Mind that."
                end
            end
        end
        if contextual and (turn % 3 ~= 0) then
            -- Context speaks two turns of three; the third stays the
            -- rotation so the person still comes through in wartime.
            pcall(function() body:Say(contextual) end)
            spoke = true
        elseif #offers > 0 then
            local line = offers[((turn - 1) % #offers) + 1]
            pcall(function() body:Say(line) end)
            spoke = true
        end
    end
    if not spoke then
        pcall(function() SAO.Voice.answer(id, "talkBack") end)
    end
    log("talked with " .. id .. " (trust "
        .. string.format("%.2f", SAO.Standing.trust(id, key)) .. ")")
end

-- Ask to walk with me: a nudge when trust is NEAR the line, never a
-- bypass. Within 0.1 below the company threshold the ask itself closes
-- the gap (asking is a gesture); further away it is declined aloud.
local function askToWalk(playerObj, id)
    local key = playerKeyOf(playerObj)
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local trust = SAO.Standing.trust(id, key)
    local body = SAO.Body.get(id)
    if trust > companyAt then
        log(id .. " already would - stay near them")
    elseif trust > companyAt - 0.1 then
        SAO.Standing.adjustTrust(id, key, 0.1)
        if body then pcall(function() SAO.Voice.answer(id, "walkNudge") end) end
        log(id .. " agrees - the ask closed the gap")
    else
        if body then pcall(function() SAO.Voice.answer(id, "walkNo") end) end
        log(id .. " declines (trust " .. string.format("%.2f", trust) .. ")")
    end
end

-- Ask to join them: petition the LEADER of a settled faction. Acceptance
-- is one settled fact; refusal is voiced and costs nothing.
local function askToJoin(playerObj, id)
    local key = playerKeyOf(playerObj)
    local group = SAO.Standing.groupOf(id)
    if not group then
        log(id .. " belongs to no faction")
        return
    end
    local leaderId = SAO.Standing.leaderOf(group)
    local leader = leaderId and SAO.Body.get(leaderId)
    local judge = leaderId or id
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
    if SAO.Standing.playerMemberOf(group) == key then
        log("already one of " .. tostring(SAO.Standing.factionName(group) or group))
        return
    end
    if SAO.Standing.trust(judge, key) > companyAt then
        SAO.Standing.setPlayerMember(group, key)
        if leader then
            pcall(function() SAO.Voice.answer(leaderId, "joinYes") end)
        end
        log("accepted into " .. tostring(SAO.Standing.factionName(group) or group)
            .. " - their base is home ground now")
    else
        if leader then
            pcall(function() SAO.Voice.answer(leaderId, "joinNo") end)
        elseif SAO.Body.get(id) then
            pcall(function() SAO.Voice.answer(id, "joinNo") end)
        end
        log("refused by " .. tostring(SAO.Standing.factionName(group) or group)
            .. " (their leader does not trust you yet)")
    end
end

local function fillMenu(playerNum, context, worldobjects)
    -- Pre-alpha, private mod: the harness is the operator's play-surface, so
    -- it is available in normal play, not just debug launches.
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    -- S5: any survivor under the cursor gets the three plain verbs.
    local nearId = survivorNear(worldobjects)
    if nearId then
        -- [B42] A menu entry never reads "Talk to Unnamed": the
        -- sentinel means the county has not met them, and the id is a
        -- truer thing to show than a placeholder pretending to be a name.
        context:addOption("Talk to " .. (SAO.Identity.knownName(
            SAO.Identity.get(nearId)) or nearId), nil, function()
            talkTo(playerObj, nearId)
        end)
        -- [B12] The menu, native again: the one common verb stays at
        -- the top (talking is what you do with a person) and
        -- everything else you can do WITH them lives under their
        -- name, the way the game groups a vehicle's actions under the
        -- vehicle. Eighteen batches of verbs had grown the top level
        -- back to fifteen entries; [A25]'s law says menus look like
        -- the game's menus.
        local pName19 = SAO.Identity.knownName(
            SAO.Identity.get(nearId)) or "them"
        local personOpt = context:addOption(tostring(pName19) .. "...",
            nil, nil)
        local person = context:getNew(context)
        context:addSubMenu(personOpt, person)
        -- [B27] You can pass on what you have seen. This is the SAME
        -- channel the survivors use on each other - P.tell, the same
        -- provenance, the same `told` rank, the player recorded as
        -- the teller - and the only thing that differs is that a
        -- survivor decides to speak by a trust calculation while you
        -- decide by clicking. Their skepticism is untouched: someone
        -- who distrusts you will not take your word.
        --
        -- Nothing here is authored. What you have to tell is whatever
        -- the same perception pass put in your head while you walked
        -- around, which is why the option is absent when you have
        -- nothing worth passing on.
        do
            local myKey65 = SAO.Standing.playerKey(playerObj)
            -- [B41] The gate asks Perception what can travel instead
            -- of iterating the store here. This was two categories
            -- spelled in the harness, and both were wrong: it opened on
            -- `zombies`, which `tell` cannot carry at all, and it never
            -- counted `factions`, which `tell` can. Before [B41] the
            -- player's store was empty and the option never appeared,
            -- so neither mistake could be seen.
            local hasNews65 = myKey65 and SAO.Perception.hasAnythingToPass(
                myKey65, SAO.Controller.tick()) or false
            if hasNews65 and not SAO.Standing.isHostileTo(nearId, myKey65) then
                person:addOption("Tell them what I've seen", nil, function()
                    local tb65 = SAO.Body.get(nearId)
                    local n = SAO.Perception.tell(myKey65, nearId,
                        SAO.Controller.tick(), true)
                    if n and n > 0 then
                        if tb65 then
                            pcall(function()
                                tb65:Say("Right. I'll keep that in mind.")
                            end)
                        end
                        HaloTextHelper.addGoodText(playerObj,
                            "they note " .. tostring(n)
                            .. (n == 1 and " thing" or " things"))
                        -- Being useful is standing, on the same scale
                        -- everything else in this codebase moves it.
                        SAO.Standing.adjustTrust(nearId, myKey65, 0.03)
                    else
                        if tb65 then
                            pcall(function()
                                tb65:Say("Nothing I didn't know.")
                            end)
                        end
                        HaloTextHelper.addText(playerObj,
                            "nothing new to them")
                    end
                end)
            end
        end
        -- [B20] You can treat them. The same vanilla action the
        -- survivors now use, with the player as the doctor - so YOUR
        -- Doctor level sets how long the dressing holds, exactly as
        -- it does when you bandage yourself. Only offered when there
        -- is something open to dress and something to dress it with.
        do
            local tBody41 = SAO.Body.get(nearId)
            local part41, partName41, bandage41 = nil, nil, nil
            if tBody41 then
                pcall(function()
                    local parts = tBody41:getBodyDamage():getBodyParts()
                    local worst = -1
                    for i = 0, parts:size() - 1 do
                        local bp = parts:get(i)
                        if bp:bleeding() and not bp:bandaged() then
                            local bt = bp:getBleedingTime() or 0
                            if bt > worst then worst, part41 = bt, bp end
                        end
                    end
                    if part41 then
                        partName41 = BodyPartType.getDisplayName(
                            part41:getType())
                    end
                end)
                pcall(function()
                    local items = playerObj:getInventory():getItems()
                    for i = 0, items:size() - 1 do
                        local it = items:get(i)
                        local okB, power = pcall(function()
                            return it:getBandagePower()
                        end)
                        if okB and power and power > 0 then
                            bandage41 = it
                            break
                        end
                    end
                end)
            end
            if part41 and bandage41 then
                person:addOption("Bandage their "
                    .. string.lower(tostring(partName41 or "wound")),
                    nil, function()
                        pcall(function()
                            ISTimedActionQueue.add(ISApplyBandage:new(
                                playerObj, tBody41, bandage41,
                                part41, true))
                        end)
                        pcall(function()
                            SAO.Standing.adjustTrust(nearId,
                                playerKeyOf(playerObj), 0.15)
                        end)
                        log("the player treats " .. nearId)
                    end)
            end
        end
        person:addOption("Ask to walk with me", nil, function()
            askToWalk(playerObj, nearId)
        end)
        -- The deal ([B11]): offer what you are holding, and let THEIR
        -- needs price it. Nothing here is a table of values - every
        -- want is a state that already exists, and what comes back is
        -- what "spare" has always meant in this codebase.
        do
            local held = nil
            pcall(function() held = playerObj:getPrimaryHandItem() end)
            local tKey = playerKeyOf(playerObj)
            local tBody = SAO.Body.get(nearId)
            if held and tBody
                and not SAO.Standing.isHostileTo(nearId, tKey) then
                person:addOption("Offer " .. tostring(held:getName()),
                    nil, function()
                    local wants, why = false, nil
                    local tn = SAO.Needs.read(tBody)
                    local ft = tostring(held:getFullType() or "")
                    pcall(function()
                        if instanceof(held, "Food") then
                            wants = tn and tn.hunger
                                >= SAO.Disposition.eatAt(nearId)
                            why = "food"
                        elseif instanceof(held, "HandWeapon") then
                            local armed = false
                            local its = tBody:getInventory():getItems()
                            for i = 0, its:size() - 1 do
                                if instanceof(its:get(i), "HandWeapon") then
                                    armed = true
                                    break
                                end
                            end
                            wants = not armed
                            why = "a weapon"
                        elseif held:getFluidContainerFromSelfOrWorldItem() then
                            local g = SAO.Standing.groupOf(nearId)
                            local ws = g and SAO.Standing.waterStoreOf
                                and SAO.Standing.waterStoreOf(g) or nil
                            wants = (tn and tn.thirst
                                >= SAO.Disposition.drinkAt(nearId))
                                or (ws and ws.word == "dry") or false
                            why = "water"
                        elseif held:getMinutesToBurn() > 0 then
                            wants = SAO.Needs.cold(tBody) >= 0.4
                            why = "something to burn"
                        elseif held:getAlcoholPower() > 0
                            or ft:find("Bandage") then
                            wants = SAO.Needs.woundInfection(tBody) > 0
                                or SAO.Needs.bleeding(tBody) > 0
                            why = "something for the wound"
                        end
                    end)
                    if not wants then
                        pcall(function()
                            SAO.Voice.answer(nearId, "noDeal")
                        end)
                        log(nearId .. " has no use for that")
                        return
                    end
                    -- What they can genuinely spare, by the law that
                    -- already governs sparing: never their own meal.
                    local giveBack = nil
                    pcall(function()
                        giveBack = SAOJavaBridge:findSpareFood(tBody)
                    end)
                    if not giveBack then
                        pcall(function()
                            local its = tBody:getInventory():getItems()
                            local best, bestAmt = nil, 0
                            local count = 0
                            for i = 0, its:size() - 1 do
                                local it = its:get(i)
                                local fc = it:getFluidContainerFromSelfOrWorldItem()
                                if fc and fc:getAmount() > 0.01 then
                                    count = count + 1
                                    if fc:getAmount() > bestAmt then
                                        best, bestAmt = it, fc:getAmount()
                                    end
                                end
                            end
                            if count >= 2 then giveBack = best end
                        end)
                    end
                    if not giveBack then
                        pcall(function()
                            SAO.Voice.answer(nearId, "noDeal")
                        end)
                        log(nearId .. " wants " .. tostring(why)
                            .. " but has nothing spare to trade")
                        return
                    end
                    -- Add THEN remove, each side guarded ([B11]): a
                    -- failed add must leave the item where it was.
                    -- This economy spent whole batches making goods
                    -- conserved; a trade is the last place to drop
                    -- one on the floor.
                    local moved = pcall(function()
                        if tBody:getInventory():AddItem(held) then
                            playerObj:getInventory():Remove(held)
                        end
                        if playerObj:getInventory():AddItem(giveBack) then
                            tBody:getInventory():Remove(giveBack)
                        end
                    end)
                    if not moved then
                        log("the trade with " .. nearId .. " failed to move")
                        return
                    end
                    SAO.Standing.adjustTrust(nearId, tKey, 0.12)
                    pcall(function()
                        SAO.Voice.answer(nearId, "deal")
                        HaloTextHelper.addGoodText(playerObj,
                            "Traded for " .. tostring(giveBack:getName()))
                    end)
                    log("a deal: " .. tostring(held:getName()) .. " for "
                        .. tostring(giveBack:getName()) .. " with " .. nearId)
                end)
            end
        end
        -- The chair ([A27]): consent verbs when the house has
        -- offered; the work dealt when the chair is yours.
        do
            local cKey = playerKeyOf(playerObj)
            local cGroup6 = SAO.Standing.groupOf(nearId)
            if cGroup6
                and SAO.Standing.chairOfferOf
                and SAO.Standing.chairOfferOf(cGroup6) == cKey then
                person:addOption("Accept the chair", nil, function()
                    if SAO.Standing.acceptChair(cGroup6, cKey) then
                        pcall(function()
                            SAO.Voice.answer(nearId, "chairYes")
                        end)
                        log("the " .. tostring(
                            SAO.Standing.factionName(cGroup6) or cGroup6)
                            .. " seats you in the chair")
                    end
                end)
                person:addOption("Not for me", nil, function()
                    SAO.Standing.declineChair(cGroup6)
                    log("you wave the chair off")
                end)
            end
            if cGroup6
                and SAO.Standing.playerChairOf
                and SAO.Standing.playerChairOf(cGroup6) == cKey then
                local workOpt = person:addOption("Assign work", nil, nil)
                local work = person:getNew(person)
                person:addSubMenu(workOpt, work)
                local nrec6 = SAO.Identity.get(nearId)
                for _, job in ipairs({ "watch", "forager", "scout",
                    "medic", "quartermaster" }) do
                    work:addOption(job
                        .. (nrec6 and nrec6.designation == job
                            and " (now)" or ""),
                        nil, function()
                        local r6 = SAO.Identity.get(nearId)
                        if r6 then
                            r6.designation = job
                            r6.designatedBy = "chair"
                            log(nearId .. " takes the " .. job
                                .. " work - the chair dealt it")
                        end
                    end)
                end
            end
        end
        -- The debt settled ([A26]): food from your pack to their
        -- hands closes what the call opened. Paid is paid.
        do
            local myKey5 = playerKeyOf(playerObj)
            if SAO.Standing.debt(nearId, myKey5) > 0 then
                local inv5 = playerObj:getInventory()
                local food5 = nil
                if inv5 then
                    local items5 = inv5:getItems()
                    for i5 = 0, items5:size() - 1 do
                        local it5 = items5:get(i5)
                        if instanceof(it5, "Food") then
                            food5 = it5
                            break
                        end
                    end
                end
                if food5 then
                    person:addOption("Settle the debt (give food)", nil,
                        function()
                        local b5 = SAO.Body.get(nearId)
                        if not b5 then return end
                        playerObj:getInventory():Remove(food5)
                        b5:getInventory():AddItem(food5)
                        SAO.Standing.settleDebt(nearId, myKey5, 0.5)
                        SAO.Standing.adjustTrust(nearId, myKey5, 0.05)
                        pcall(function()
                            SAO.Voice.answer(nearId, "paid")
                        end)
                        log(nearId .. " takes the food - paid is paid")
                    end)
                end
            end
        end
        if SAO.Standing.groupOf(nearId) then
            person:addOption("Ask to join them", nil, function()
                askToJoin(playerObj, nearId)
            end)
        end
        -- Counsel the leader ([A25]): a trusted MEMBER standing with
        -- their leader can urge the government - asks at faction scale
        -- that move dispositions, never pull levers. Peace still needs
        -- both leaders; settling still needs the scout's own judgment.
        do
            local cKey = playerKeyOf(playerObj)
            local cGroup = SAO.Standing.groupOf(nearId)
            if cGroup and SAO.Standing.playerMemberOf(cGroup) == cKey
                and SAO.Standing.leaderOf(cGroup) == tostring(nearId) then
                local sv2 = SandboxVars and SandboxVars.SurvivorAwareness or nil
                local bar2 = (sv2 and tonumber(sv2.TrustToCompany)) or 0.5
                if SAO.Standing.trust(nearId, cKey) > bar2 then
                    local opt2 = person:addOption("Counsel the leader...",
                        nil, nil)
                    local sub2 = person:getNew(person)
                    person:addSubMenu(opt2, sub2)
                    local counseled = false
                    for og in pairs(SAO.Standing.allGroupClaims()) do
                        if og ~= cGroup
                            and SAO.Standing.feudBetween(cGroup, og) then
                            counseled = true
                            sub2:addOption("urge peace with "
                                .. tostring(SAO.Standing.factionName(og) or og),
                                nil, function()
                                local eLeader = SAO.Standing.leaderOf(og)
                                if eLeader then
                                    SAO.Standing.adjustTrust(nearId,
                                        eLeader, 0.1)
                                    pcall(function()
                                        SAO.Voice.answer(nearId,
                                            "talkBack")
                                    end)
                                    log(nearId
                                        .. " weighs your counsel toward peace")
                                end
                            end)
                        end
                    end
                    -- [B23] Say how it should be. Gated on the
                    -- house's ear: you hold their chair, or their
                    -- leader genuinely thinks well of you. Meeting
                    -- enough people is what earns the right to have
                    -- an opinion about how they live.
                    do
                        local pKeyF = playerKeyOf(playerObj)
                        local heardF = (SAO.Standing.playerChairOf
                            and SAO.Standing.playerChairOf(cGroup) == pKeyF)
                            or SAO.Standing.trust(nearId, pKeyF) > 0.6
                        local formF = SAO.Standing.formOf
                            and SAO.Standing.formOf(cGroup) or "empty"
                        -- A splitting house will not hear it, and a
                        -- house that is walking has other problems.
                        if heardF and formF ~= "divided"
                            and formF ~= "flight" then
                            counseled = true
                            if formF ~= "council" then
                                sub2:addOption("urge them to decide together",
                                    nil, function()
                                    SAO.Standing.urgeForm(cGroup, pKeyF,
                                        "council")
                                    pcall(function()
                                        SAO.Voice.answer(nearId,
                                            "talkBack")
                                    end)
                                    log(nearId .. " hears you out on how"
                                        .. " the house should run")
                                end)
                            end
                            if formF ~= "ladder" then
                                sub2:addOption("urge them to name a second",
                                    nil, function()
                                    SAO.Standing.urgeForm(cGroup, pKeyF,
                                        "ladder")
                                    pcall(function()
                                        SAO.Voice.answer(nearId,
                                            "talkBack")
                                    end)
                                    log(nearId .. " hears you out on how"
                                        .. " the house should run")
                                end)
                            end
                        end
                    end
                    if not SAO.Standing.groupClaimOf(cGroup) then
                        counseled = true
                        sub2:addOption("urge settling somewhere", nil,
                            function()
                            local la = SAO.Controller.agents[nearId]
                            if la then
                                la.nextScoutAt = 0
                                log(nearId
                                    .. " will look for ground - your counsel")
                            end
                        end)
                    end
                    if not counseled then
                        sub2:addOption("(nothing to counsel now)", nil,
                            function() end)
                    end
                end
            end
        end
        -- Companion orders ([A24]): asks for an ACTIVE companion only.
        do
            local coAgent = SAO.Controller.agents[nearId]
            if coAgent and coAgent.companioning then
                local opt = person:addOption("Ask them to...", nil, nil)
                local sub = person:getNew(person)
                person:addSubMenu(opt, sub)
                sub:addOption(coAgent.holdPosition
                    and "wait here (holding)" or "wait here", nil, function()
                    coAgent.holdPosition = true
                    pcall(function() SAO.Voice.answer(nearId, "walkNudge") end)
                    log(nearId .. " will hold this spot")
                end)
                sub:addOption(coAgent.followTight
                    and "stay close (doing it)" or "stay close", nil, function()
                    coAgent.holdPosition = nil
                    coAgent.followTight = true
                    log(nearId .. " will stay close")
                end)
                sub:addOption("walk with me (normal)", nil, function()
                    coAgent.holdPosition = nil
                    coAgent.followTight = nil
                    log(nearId .. " walks with you")
                end)
                -- [B42] Go home. The county has had `HOMEWARD` and a
                -- `homeX` on every record since genesis, and the player
                -- could point at a building but never say "go back to
                -- your own". No new machinery: it is `orderTravel` to
                -- the home they already have, which is what the dusk
                -- homing walks them to on its own.
                --
                -- OFFERED ONLY WHEN THERE IS ONE. [B7] clears the home
                -- fields of everyone in a house that gives up its
                -- ground - "they have no home until they find one" -
                -- and [B42] made that moment recordable. So a
                -- survivor whose house abandoned has nowhere to be
                -- sent, and an order that cannot land must not be on
                -- the menu.
                local homeRec = SAO.Identity.get(nearId)
                if homeRec and homeRec.homeX and homeRec.homeY then
                    sub:addOption("go back to your own place", nil,
                        function()
                            coAgent.holdPosition = nil
                            coAgent.followTight = nil
                            coAgent.companioning = nil
                            if SAO.Controller.orderTravel(nearId,
                                homeRec.homeX, homeRec.homeY,
                                homeRec.homeZ or 0) then
                                pcall(function()
                                    SAO.Voice.answer(nearId, "parting")
                                end)
                                log(nearId .. " heads home")
                            end
                        end)
                end
                sub:addOption("check that building", nil, function()
                    local sq = nil
                    for _, o in ipairs(worldobjects or {}) do
                        local ok, s = pcall(function() return o:getSquare() end)
                        if ok and s then sq = s break end
                    end
                    if sq then
                        coAgent.holdPosition = nil
                        if SAO.Controller.orderTravel(nearId,
                            sq:getX(), sq:getY(), sq:getZ()) then
                            log(nearId .. " goes to look at the place you"
                                .. " pointed out - their eyes, their judgment")
                        end
                    end
                end)
            end
        end
        -- Player-company designations ([A19], C4/S5): a companion (or
        -- anyone trusting past the company line) can be ASKED to work a
        -- job. Asking is all it is - the designation drives the same
        -- workday machinery a company's would. One submenu, sparse.
        do
            local nearKey = playerKeyOf(playerObj)
            local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
            local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
            local nearAgent = SAO.Controller.agents[nearId]
            local willing = (nearAgent and nearAgent.companioning)
                or SAO.Standing.trust(nearId, nearKey) > companyAt
            if willing and not SAO.Standing.groupOf(nearId) then
                local rec = SAO.Identity.get(nearId)
                if rec then
                    local opt = person:addOption("Ask them to work as...", nil, nil)
                    local sub = person:getNew(person)
                    person:addSubMenu(opt, sub)
                    local jobs = { "watch", "scout", "forager",
                        "quartermaster", "medic" }
                    for _, job in ipairs(jobs) do
                        sub:addOption(job
                            .. (rec.designation == job and " (their job now)" or ""),
                            nil, function()
                                rec.designation = job
                                pcall(function()
                                    SAO.Voice.answer(nearId, "company")
                                end)
                                log(nearId .. " takes the " .. job .. " work")
                            end)
                    end
                    sub:addOption("their own devices", nil, function()
                        rec.designation = nil
                        log(nearId .. " is back to their own devices")
                    end)
                end
            end
        end
    end

    -- Native structure ([A25], F-037 kept): the county opens as a
    -- WINDOW from one short label; every debug tool lives under one
    -- submenu instead of a wall of prose options.
    -- [B12] The county's own surfaces group under the county, the
    -- way the game groups a vehicle's under the vehicle. Three
    -- entries at the top level now: the person you're looking at,
    -- the county, and the one verb you use most.
    local countyOpt = context:addOption("The County...", nil, nil)
    local county = context:getNew(context)
    context:addSubMenu(countyOpt, county)
    -- [B18] Your ground: every survivor holds a claim from their
    -- first day and the player held nothing, which since [A28] and
    -- [B15] means foragers could strip a player's base as innocent
    -- ground. The claim machinery is key-blind, so this is a verb -
    -- and everything downstream (avoidance, desperation, war,
    -- pacts) already handles it.
    do
        local gKey = playerKeyOf(playerObj)
        local mine31 = SAO.Standing.claimOf(gKey)
        local px31 = math.floor(playerObj:getX())
        local py31 = math.floor(playerObj:getY())
        local inside31 = mine31 and px31 >= mine31.minX
            and px31 <= mine31.maxX and py31 >= mine31.minY
            and py31 <= mine31.maxY
        if mine31 and inside31 then
            county:addOption("Release this ground", nil, function()
                SAO.Standing.releaseClaim(gKey)
                -- [B18] The household dissolves with the ground: no
                -- home at all is the honest state for people whose
                -- base just stopped existing, and every homing path
                -- already guards on its absence.
                local freed = SAO.Standing.rehomeCompanions(
                    gKey, nil, nil, nil)
                pcall(function()
                    HaloTextHelper.addText(playerObj,
                        freed > 0
                        and ("You give up this ground. " .. freed
                            .. " have nowhere to go.")
                        or "You give up this ground.")
                end)
                log("the player releases their claim")
            end)
        elseif mine31 then
            -- [B34] You hold ground and you are standing somewhere
            -- that is not part of it yet. This branch did not exist:
            -- the chain went "inside your claim" or "no claim at
            -- all", and the case in between - the yard, the shed, the
            -- stretch of fence you actually use - had no verb.
            --
            -- The house is the honest default; this is how it stops
            -- being the whole story. Bounded by the errand radius,
            -- which is already the county's word for "near enough to
            -- be part of daily life", so no new number is invented -
            -- and refused over anyone else's ground, because taking
            -- that is a different verb this county does not have.
            local svE31 = SandboxVars and SandboxVars.SurvivorAwareness
                or nil
            local reach31 = (svE31 and tonumber(svE31.ErrandRadius))
                or 12
            local dx31 = math.max(mine31.minX - px31,
                px31 - mine31.maxX, 0)
            local dy31 = math.max(mine31.minY - py31,
                py31 - mine31.maxY, 0)
            local taken31 = false
            for who31, c31 in pairs(SAO.Standing.allGroupClaims()) do
                if who31 ~= gKey and px31 >= c31.minX
                    and px31 <= c31.maxX and py31 >= c31.minY
                    and py31 <= c31.maxY then
                    taken31 = true
                    break
                end
            end
            if not taken31 and dx31 <= reach31 and dy31 <= reach31 then
                county:addOption("Take this in too", nil, function()
                    if SAO.Standing.growClaim(gKey, px31, py31,
                        playerObj) then
                        local w31, h31 = SAO.Standing.claimSpan(gKey)
                        pcall(function()
                            HaloTextHelper.addGoodText(playerObj,
                                "Your ground reaches here now - "
                                .. tostring(w31) .. " by "
                                .. tostring(h31) .. ".")
                        end)
                        log("the player extends their ground to "
                            .. px31 .. "," .. py31 .. " ("
                            .. tostring(w31) .. "x" .. tostring(h31)
                            .. ")")
                    end
                end)
            end
        elseif not mine31 then
            -- Only where nobody else already stands: taking someone
            -- else's ground is a different verb this county does not
            -- have.
            local occupied31 = false
            for _, c31 in pairs(SAO.Standing.allGroupClaims()) do
                if px31 >= c31.minX and px31 <= c31.maxX
                    and py31 >= c31.minY and py31 <= c31.maxY then
                    occupied31 = true
                    break
                end
            end
            if not occupied31 then
                county:addOption("Claim this ground", nil, function()
                    -- [B34] The house, not a square of invented
                    -- tiles. "This ground is yours" never said how
                    -- much ground, and the answer was 17x17 centred
                    -- on wherever you happened to stand.
                    local minX, minY, maxX, maxY, kind =
                        SAO.Standing.groundAround(playerObj, px31, py31, 8)
                    SAO.Standing.claim(gKey, minX, minY, maxX, maxY,
                        math.floor(playerObj:getZ()))
                    -- [B18] Whoever already walks with you now has
                    -- somewhere to come home to.
                    local homed = SAO.Standing.rehomeCompanions(
                        gKey, px31, py31, math.floor(playerObj:getZ()))
                    local w = maxX - minX + 1
                    local h = maxY - minY + 1
                    pcall(function()
                        HaloTextHelper.addGoodText(playerObj,
                            (kind == "house"
                                and ("This house is yours - " .. w
                                    .. " by " .. h .. ".")
                                or ("This open ground is yours - " .. w
                                    .. " by " .. h .. " around you."))
                            .. (homed > 0
                                and (" " .. homed .. " come home here now.")
                                or " They'll learn it by seeing you here."))
                    end)
                    log("the player claims " .. kind .. " ground "
                        .. minX .. "," .. minY .. " to " .. maxX .. ","
                        .. maxY .. " (" .. w .. "x" .. h .. ")")
                end)
            end
        end
    end

    county:addOption("County Ledger", nil, function()
        if SAOCountyWindow then SAOCountyWindow.toggle() end
    end)


    -- Rally the house ([A27]): the chair calls, the house comes -
    -- once, with feet, through the same locomotion law as everything.
    do
        local rKey = playerKeyOf(playerObj)
        local rGroup = SAO.Standing.groupChairedBy
            and SAO.Standing.groupChairedBy(rKey) or nil
        if rGroup then
            county:addOption("Rally the house", nil, function()
                -- The chair calls once an hour; the house is not a
                -- yo-yo.
                local okRH, rh = pcall(function()
                    return GameTime.getInstance():getWorldAgeHours()
                end)
                local nowR = okRH and rh or 0
                if nowR - (SAO.Harness.rallyAt or -9) < 1 then
                    pcall(function()
                        HaloTextHelper.addText(playerObj,
                            "The house needs a while.")
                    end)
                    return
                end
                SAO.Harness.rallyAt = nowR
                local n7 = 0
                for _, r7 in pairs(SAO.Identity.all()) do
                    if not r7.dead
                        and SAO.Standing.groupOf(r7.id) == rGroup then
                        local b7 = SAO.Body.get(r7.id)
                        if b7 and SAO.Locomotion.order(r7.id, b7,
                            math.floor(playerObj:getX()),
                            math.floor(playerObj:getY()),
                            math.floor(playerObj:getZ())) then
                            n7 = n7 + 1
                        end
                    end
                end
                pcall(function()
                    HaloTextHelper.addText(playerObj,
                        n7 > 0 and ("The house is coming (" .. n7 .. ").")
                        or "Nobody close enough to hear.")
                end)
            end)
        end
    end

    -- The player-driven party ([B1]): the one driver that exists.
    -- Seats are the REAL free seats of the REAL nearest vehicle; the
    -- willing are trust-gated and the circle holds on wheels too -
    -- loners ride with nobody. Release is the door opening; dusk
    -- homing walks them home like any evening.
    do
        local pKey8 = playerKeyOf(playerObj)
        local myHouse8 = SAO.Standing.groupChairedBy
            and SAO.Standing.groupChairedBy(pKey8) or nil
        if not myHouse8 then
            for g8, meta8 in pairs((function()
                local ok8, s8 = pcall(function()
                    return ModData.getOrCreate("SurvivorAwareness_Standing")
                end)
                return (ok8 and s8 and s8.groupMeta) or {}
            end)()) do
                if meta8.playerMemberOf == pKey8 then
                    myHouse8 = g8
                    break
                end
            end
        end
        if myHouse8 then
            local anyRiding8 = false
            for _, r8 in pairs(SAO.Identity.all()) do
                if not r8.dead then
                    local a8 = SAO.Controller.agents[r8.id]
                    if a8 and a8.riding then anyRiding8 = true break end
                end
            end
            if anyRiding8 then
                county:addOption("Let the crew out", nil, function()
                    local let8 = 0
                    for _, r8 in pairs(SAO.Identity.all()) do
                        local a8 = SAO.Controller.agents[r8.id]
                        if a8 and a8.riding then
                            local b8 = SAO.Body.get(r8.id)
                            if b8 then
                                pcall(function()
                                    SAOJavaBridge:unseatFromVehicle(b8)
                                end)
                            end
                            a8.riding = nil
                            let8 = let8 + 1
                        end
                    end
                    pcall(function()
                        HaloTextHelper.addText(playerObj,
                            "The crew steps out (" .. let8 .. ").")
                    end)
                end)
            else
                county:addOption("Take a crew", nil, function()
                    local px8 = playerObj:getX()
                    local py8 = playerObj:getY()
                    local seated8, tried8 = 0, 0
                    local names8 = {}
                    for _, r8 in pairs(SAO.Identity.all()) do
                        if not r8.dead
                            and SAO.Standing.groupOf(r8.id) == myHouse8
                            and SAO.Standing.trust(r8.id, pKey8) >= 0.4 then
                            local b8 = SAO.Body.get(r8.id)
                            if b8 then
                                local dx8 = b8:getX() - px8
                                local dy8 = b8:getY() - py8
                                if dx8 * dx8 + dy8 * dy8 <= 144 then
                                    tried8 = tried8 + 1
                                    if SAO.Disposition.circle
                                        and SAO.Disposition.circle(r8.id)
                                            == "loner" then
                                        pcall(function()
                                            SAO.Voice.answer(r8.id,
                                                "ownCompany")
                                        end)
                                    else
                                        local seat8 = -1
                                        pcall(function()
                                            seat8 = SAOJavaBridge
                                                :seatInNearestVehicle(
                                                    b8, px8, py8)
                                        end)
                                        if seat8 and seat8 >= 0 then
                                            local a8 = SAO.Controller
                                                .agents[r8.id]
                                            if a8 then
                                                a8.riding = true
                                            end
                                            pcall(function()
                                                SAO.Perception
                                                    .announceDeparture(
                                                    r8.id, "crew",
                                                    math.floor(px8),
                                                    math.floor(py8))
                                            end)
                                            seated8 = seated8 + 1
                                            names8[#names8 + 1] =
                                                tostring(r8.forename)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    pcall(function()
                        HaloTextHelper.addText(playerObj,
                            seated8 > 0
                            and ("Crew aboard: "
                                .. table.concat(names8, ", "))
                            or (tried8 > 0
                                and "No seats, or nobody willing."
                                or "Nobody close enough."))
                    end)
                    if seated8 > 0 then
                        log("the player takes a crew of " .. seated8)
                    end
                end)
            end
        end
    end

    -- The call ([A26]): directing the county over the wire is a VERB
    -- surface gated by the radio's physics - a live two-way on 101.2
    -- in hand - never parsed prose. One shared cooldown; the band is
    -- not a bell you hammer.
    if SAO.RadioEar and SAO.RadioEar.hasLiveWireRadio
        and SAO.RadioEar.hasLiveWireRadio(playerObj) then
        local wireOpt = county:addOption("The Wire", nil, nil)
        local wire = county:getNew(county)
        county:addSubMenu(wireOpt, wire)
        local function bandFree()
            local s = nil
            pcall(function()
                s = ModData.getOrCreate("SurvivorAwareness_Standing")
            end)
            if not s then return nil end
            s.onAir = s.onAir or {}
            local okH, h = pcall(function()
                return GameTime.getInstance():getWorldAgeHours()
            end)
            local now = okH and h or 0
            if now - (s.onAir.lastCallAt or -9) < 2 then
                pcall(function()
                    HaloTextHelper.addText(playerObj, "The band needs rest.")
                end)
                return nil
            end
            s.onAir.lastCallAt = now
            return s
        end
        wire:addOption("Call for aid", nil, function()
            local s = bandFree(); if not s then return end
            local myKey = playerKeyOf(playerObj)
            local heard = s.onAir and s.onAir.heardBy or {}
            local heardSolo = s.onAir and s.onAir.heardSolo or {}
            -- [B52] `bestD2`, not `bestD`. These hold SQUARED
            -- distances - correct, and the cheap way to find the
            -- nearest, since a square root would not change the
            -- order. The name is what was wrong: `d` means a rooted
            -- distance in the other nineteen sites, and one compared
            -- against a plain literal here would be silently wrong.
            local best, bestD2 = nil, 1e9
            for _, r in pairs(SAO.Identity.all()) do
                if not r.dead and SAO.Body.get(r.id) then
                    local g = SAO.Standing.groupOf(r.id)
                    if ((g and heard[g]) or heardSolo[r.id])
                        and SAO.Standing.trust(r.id, myKey)
                            >= 0.15 + SAO.Standing.debt(r.id, myKey) * 0.3 then
                        local b = SAO.Body.get(r.id)
                        local dx = b:getX() - playerObj:getX()
                        local dy = b:getY() - playerObj:getY()
                        local d2 = dx * dx + dy * dy
                        if d2 < bestD2 then best, bestD2 = r.id, d2 end
                    end
                end
            end
            if not best then
                pcall(function()
                    HaloTextHelper.addText(playerObj,
                        "The band is quiet. Nobody answers.")
                end)
                return
            end
            local b = SAO.Body.get(best)
            if SAO.Locomotion.order(best, b,
                math.floor(playerObj:getX()), math.floor(playerObj:getY()),
                math.floor(playerObj:getZ())) then
                -- Aid is a DEBT: the county remembers who called.
                SAO.Standing.addDebt(best, myKey, 0.5)
                SAO.Standing.pushRadioNews({ kind = "aidCall" })
                pcall(function()
                    HaloTextHelper.addText(playerObj,
                        tostring(SAO.Identity.displayName(
                            SAO.Identity.get(best))) .. " is coming.")
                end)
                log(best .. " answers the call - and is owed for it")
            end
        end)
        wire:addOption("Share your camp", nil, function()
            local s = bandFree(); if not s then return end
            local heard = s.onAir and s.onAir.heardBy or {}
            local heardSolo = s.onAir and s.onAir.heardSolo or {}
            local pname = tostring(playerObj:getUsername())
            local px = math.floor(playerObj:getX())
            local py = math.floor(playerObj:getY())
            local n = 0
            for _, r in pairs(SAO.Identity.all()) do
                if not r.dead then
                    local g = SAO.Standing.groupOf(r.id)
                    if (g and heard[g]) or heardSolo[r.id] then
                        local b2 = SAO.Perception.beliefs[r.id]
                        if b2 then
                            b2.people[pname] = b2.people[pname]
                                or { at = 0, dist = 999 }
                            b2.people[pname].x = px
                            b2.people[pname].y = py
                            b2.people[pname].source = "told"
                            n = n + 1
                        end
                    end
                end
            end
            pcall(function()
                HaloTextHelper.addText(playerObj,
                    n > 0 and ("The county knows where you camp (" .. n .. ").")
                    or "Nobody's listening yet.")
            end)
        end)
        -- The petition on the air ([B9]): influence on a polity you
        -- are not standing in. A plea for peace reaches the leaders
        -- of warring houses who really own receivers - dormant or
        -- loaded, anywhere - at TOLD weight (half what your face
        -- would carry), and only from a voice they have reason to
        -- heed. This is the survey's named gap: petitioning an
        -- off-screen polity.
        wire:addOption("Urge peace on the air", nil, function()
            local s = bandFree(); if not s then return end
            local myKey = playerKeyOf(playerObj)
            local moved, deaf = 0, 0
            local seen = {}
            for _, r in pairs(SAO.Identity.all()) do
                if not r.dead then
                    local g = SAO.Standing.groupOf(r.id)
                    if g and not seen[g] then
                        seen[g] = true
                        local lead = SAO.Standing.leaderOf(g)
                        if lead then
                            local atWar = nil
                            for g2 in pairs(SAO.Standing.allGroupClaims()) do
                                if g2 ~= g
                                    and SAO.Standing.feudBetween(g, g2) then
                                    atWar = g2
                                    break
                                end
                            end
                            if atWar then
                                if not SAO.Standing.ownsRadio(lead) then
                                    deaf = deaf + 1
                                elseif SAO.Standing.trust(lead, myKey)
                                    >= 0.25 then
                                    local foe = SAO.Standing.leaderOf(atWar)
                                    if foe then
                                        SAO.Standing.adjustTrust(
                                            lead, foe, 0.05)
                                        moved = moved + 1
                                        log("your voice on the band reaches "
                                            .. lead .. " - they weigh peace"
                                            .. " with " .. tostring(foe))
                                    end
                                end
                            end
                        end
                    end
                end
            end
            pcall(function()
                HaloTextHelper.addText(playerObj,
                    moved > 0
                    and ("Heard by " .. moved .. " at war.")
                    or (deaf > 0
                        and "The ones at war have no radio."
                        or "Nobody's at war to hear it."))
            end)
        end)
        wire:addOption("Ask for the news", nil, function()
            local s = bandFree(); if not s then return end
            local ok2 = SAOWire and SAOWire.airNow and SAOWire.airNow()
            pcall(function()
                HaloTextHelper.addText(playerObj,
                    ok2 and "The wire answers." or "Static.")
            end)
        end)
    end

    local dbgOpt = county:addOption("SAO Debug", nil, nil)
    local dbg = county:getNew(county)
    county:addSubMenu(dbgOpt, dbg)
    dbg:addOption("Standing web (console)", nil, H.standingWeb)
    -- [B21] What this world contains. Discovered from the live
    -- script registry, so it reports the operator's actual load
    -- rather than anything this mod was told to expect.
    dbg:addOption("What this world holds (console)", nil, function()
        if not (SAO.World and SAO.World.survey) then return end
        SAO.World.survey()
        local veh = SAO.World.vehicles()
        SAO.Log.line("WORLD", SAO.World.moduleCount()
            .. " modules contribute items")
        SAO.Log.line("WORLD", "vehicles: " .. veh.count
            .. ", largest holds " .. veh.seatsMax
            .. ", " .. veh.seatsBig .. " could move a household"
            .. ", loudness " .. veh.quietest .. "-" .. veh.loudest)
        for _, row in ipairs(SAO.World.topCategories(12)) do
            SAO.Log.line("WORLD", "  " .. row.name .. ": " .. row.count)
        end
    end)

    if not H.activeId then
        dbg:addOption("Spawn survivor", nil, function() spawn(playerObj) end)
        return
    end
    if countActive() < MAX_SURVIVORS then
        dbg:addOption("Spawn another", nil, function() spawn(playerObj) end)
    end
    local hasBody = SAO.Body.get(H.activeId) ~= nil
    if hasBody then
        dbg:addOption("Walk here", nil, function() walkHere(worldobjects) end)
        dbg:addOption("Release body", nil, release)
    else
        dbg:addOption("Rematerialize", nil, rematerialize)
    end
    dbg:addOption("Status", nil, status)
    if hasBody then
        dbg:addOption("Give bat + equip", nil, function()
            local rec = SAO.Identity.get(H.activeId)
            local body = SAO.Body.get(H.activeId)
            if body and SAOJavaBridge then
                -- [B16] Even a debug handler gets the guard: a
                -- throw in a menu callback is a red error box over
                -- the operator's game.
                pcall(function()
                    log(tostring(SAOJavaBridge:giveItem(body, "Base.BaseballBat")))
                    log(tostring(SAOJavaBridge:equipBestMelee(body)))
                end)
            end
        end)
        dbg:addOption("Pillars report", nil, function()
            log(SAO.Controller.describe(H.activeId))
        end)
        dbg:addOption("What they carry", nil, function()
            local rec = SAO.Identity.get(H.activeId)
            if rec then
                log((rec.forename or H.activeId) .. ": "
                    .. SAO.History.describe(H.activeId))
                local trade = SAO.Census and SAO.Census.describe(rec)
                if trade then
                    log((rec.forename or H.activeId) .. " " .. trade)
                end
                if rec.designation then
                    log("Designated: " .. rec.designation)
                end
                local ag = SAO.Controller.agents[H.activeId]
                if ag and ag.pressure then
                    log("The pressure right now - " .. ag.pressure.answer
                        .. ": " .. tostring(ag.pressure.detail))
                end
                local bonded = SAO.Standing.bondedWith(H.activeId)
                if bonded then
                    local brec = SAO.Identity.get(bonded)
                    log("Bonded to " .. (brec and brec.forename or bonded))
                end
                local beliefs = SAO.Perception.beliefs[H.activeId]
                if beliefs and beliefs.factions then
                    for g, fb in pairs(beliefs.factions) do
                        log("Knows of " .. (fb.name or "an unnamed group")
                            .. " at " .. fb.baseX .. "," .. fb.baseY
                            .. " (" .. fb.source .. ", " .. fb.stance .. ")")
                    end
                end
            end
        end)
        dbg:addOption("Engage nearest zombie", nil, function()
            SAO.Controller.orderEngageNearest(H.activeId, true)
        end)
        dbg:addOption("Sic zombie on survivor", nil, function()
            local body = SAO.Body.get(H.activeId)
            if body and SAOJavaBridge then
                pcall(function()
                    log(tostring(SAOJavaBridge:directNearestZombieAt(body)))
                end)
            end
        end)
    end
    dbg:addOption("Forget survivor entirely", nil, forget)
end

-- The county ledger ([A21], freed of the slice gate at [A22]): the
-- whole social state at a glance, rendered from records and standing -
-- never stored. One KS-store read serves the pulse and the memorials.
function H.countyLedger()
    do
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
            log("=== THE COUNTY === living " .. living .. ", dead " .. dead)
            -- How the county sees you ([A24]): mean trust toward your
            -- key across the living who hold ANY relation to you, plus
            -- who wants you dead.
            do
                local me2 = getSpecificPlayer(0)
                -- [B35] Was building the key inline AND without
                -- the pcall S.playerKey wraps getUsername in, so a
                -- throw here would have escaped where every other
                -- caller is guarded.
                local myKey2 = playerKeyOf(me2)
                if myKey2 then
                    local sum, n, hostiles = 0, 0, 0
                    for _, r in pairs(SAO.Identity.all()) do
                        if not r.dead then
                            local tr2 = SAO.Standing.trust(r.id, myKey2)
                            if tr2 ~= 0 then
                                sum = sum + tr2
                                n = n + 1
                            end
                            if SAO.Standing.isHostileTo(r.id, myKey2) then
                                hostiles = hostiles + 1
                            end
                        end
                    end
                    if n > 0 then
                        log("you: known to " .. n .. ", regard "
                            .. string.format("%.2f", sum / n)
                            .. (hostiles > 0 and (", " .. hostiles
                                .. " want you dead") or ", nobody hostile"))
                    else
                        log("you: a stranger to the county still")
                    end
                end
            end
            local groups = {}
            for aid in pairs(SAO.Controller.agents) do
                local g = SAO.Standing.groupOf(aid)
                if g and not groups[g] then groups[g] = true end
            end
            for _, r in pairs(SAO.Identity.all()) do
                if not r.dead then
                    local g = SAO.Standing.groupOf(r.id)
                    if g and not groups[g] then groups[g] = true end
                end
            end
            for g in pairs(groups) do
                local creed = SAO.Standing.creedOf(g)
                local fname = SAO.Standing.factionName(g) or g
                local gc = SAO.Standing.groupClaimOf(g)
                local line = fname
                    .. (creed and (" [" .. creed.name .. ", "
                        .. creed.size .. " strong]") or "")
                    .. (gc and (" holds " .. gc.minX .. "," .. gc.minY)
                        or " (no ground yet)")
                for g2 in pairs(groups) do
                    if g2 ~= g and SAO.Standing.feudBetween(g, g2) then
                        line = line .. " | FEUD with "
                            .. tostring(SAO.Standing.factionName(g2) or g2)
                    end
                end
                log(line)
            end
            -- The county's wars ([A22]): active and settled.
            for g in pairs(groups) do
                local s2 = nil
                pcall(function()
                    s2 = ModData.getOrCreate("SurvivorAwareness_Standing")
                end)
                local meta = s2 and s2.groupMeta
                    and s2.groupMeta[tostring(g)] or nil
                for _, war in ipairs((meta and meta.feudHistory) or {}) do
                    local fname = SAO.Standing.factionName(g) or g
                    local oname = SAO.Standing.factionName(war.other)
                        or war.other
                    if war.liftedAtHours then
                        log("history: " .. fname .. " fought " .. oname
                            .. " - peace on day "
                            .. math.floor((war.liftedAtHours or 0) / 24))
                    else
                        log("history: " .. fname .. " at war with " .. oname
                            .. " since day "
                            .. math.floor((war.declaredAtHours or 0) / 24))
                    end
                end
            end
            -- Bonded pairs ([A22]): each spoken once (lexical guard).
            for _, r in pairs(SAO.Identity.all()) do
                if not r.dead then
                    local mate = SAO.Standing.bondedWith(r.id)
                    if mate and tostring(r.id) < tostring(mate) then
                        local mrec = SAO.Identity.get(mate)
                        log("bonded: " .. tostring(r.forename) .. " & "
                            .. tostring(mrec and mrec.forename or mate))
                    end
                end
            end
            -- [B42] Our own wire, not somebody else's pulse. This
            -- logged another framework's world-event string as though
            -- it were county news; ours sits in `radioNews` and is
            -- rendered by the composer that airs it, so the console
            -- reads what the wire would say and not a foreign summary
            -- of a world we do not model.
            pcall(function()
                local s2 = ModData.getOrCreate("SurvivorAwareness_Standing")
                local q2 = type(s2) == "table" and s2.radioNews or nil
                if not (q2 and #q2 > 0 and SAOWire and SAOWire.render) then
                    return
                end
                for i = 1, math.min(6, #q2) do
                    log("wire: " .. tostring(SAOWire.render(q2[i])))
                end
            end)
            for i = 1, math.min(5, #recentDead) do
                local r = recentDead[i]
                log("lost: " .. tostring(r.forename) .. " - "
                    .. tostring(r.deathCause or "unknown"))
            end
            -- [B45] A block that rendered the neighbouring mod's
            -- memorial list used to sit here, gated on `ksData` - a
            -- local declared fifteen hundred lines up, in a different
            -- function. Out of scope, so the name resolved to a global
            -- nobody writes, so the gate was always false and this has
            -- never run once. Deleted rather than revived: the [A21]
            -- ghost-camp reading is a deliberate thing a Knox
            -- inhabitant TELLS you and stays, but a harness readout
            -- that mirrors his memorials is coupling nobody asked for,
            -- and reviving it would be adding it, not restoring it.
    end
end

-- The standing web ([A22]: freed of the slice gate).
function H.standingWeb()
    do
            -- Dormant whereabouts ([A22]): records without bodies
            -- render one cheap line each - the county is legible even
            -- where it is not loaded.
            local shown = 0
            for _, r in pairs(SAO.Identity.all()) do
                if not r.dead and not SAO.Body.get(r.id)
                    and not r.knox and shown < 12 then
                    shown = shown + 1
                    log(tostring(r.forename) .. " - out there near "
                        .. tostring(r.x) .. "," .. tostring(r.y)
                        .. (r.dayGoalX and " (walking their day)"
                            or " (keeping close to home)"))
                end
            end
            local me = getSpecificPlayer(0)
            local myKey = SAO.Standing.playerKey(me)
            for aid in pairs(SAO.Controller.agents) do
                local rec2 = SAO.Identity.get(aid)
                local g2 = SAO.Standing.groupOf(aid)
                local mark = (g2 and SAO.Standing.leaderOf(g2) == aid) and "*" or ""
                local line = (rec2 and rec2.forename or aid) .. mark
                    .. " [" .. tostring(g2) .. "]"
                if rec2 and rec2.designation then
                    line = line .. " <" .. rec2.designation .. ">"
                end
                if g2 then
                    local creed = SAO.Standing.creedOf(g2)
                    if creed then
                        line = line .. " creed:" .. creed.name
                    end
                    for og in pairs(SAO.Controller.agents) do
                        local og2 = SAO.Standing.groupOf(og)
                        if og2 and og2 ~= g2
                            and SAO.Standing.feudBetween(g2, og2) then
                            line = line .. " FEUD:" .. tostring(
                                SAO.Standing.factionName(og2) or og2)
                            break
                        end
                    end
                end
                local ag = SAO.Controller.agents[aid]
                if ag and ag.pressure then
                    line = line .. " | " .. ag.pressure.answer .. ": "
                        .. tostring(ag.pressure.detail)
                end
                if myKey then
                    line = line .. " you=" .. string.format("%.2f", SAO.Standing.trust(aid, myKey))
                        .. (SAO.Standing.isHostileTo(aid, myKey) and " HOSTILE" or "")
                end
                local enemies = SAO.Standing.enemiesOf(aid)
                if #enemies > 0 then
                    line = line .. " | enemies: " .. table.concat(enemies, ", ")
                end
                log(line)
            end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(fillMenu)
Events.OnFillWorldObjectContextMenu.Add(fillMenu)

log("harness loaded (available in normal play)")
