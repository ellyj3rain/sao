-- PopulationRepresentation - loaded body bands and passive foreign adoption.

SAO = SAO or {}
SAO.PopulationRepresentation = SAO.PopulationRepresentation or {}
local R = SAO.PopulationRepresentation
local function log(msg) SAO.Log.line("POP", msg) end
local function tally(kind) SAO.Log.tally("POP", kind) end
local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function backfillName(rec, body)
    if rec.forename ~= "Unnamed" or not SAOJavaBridge then return end
    local ok, name = pcall(function() return SAOJavaBridge:getShellName(body) end)
    if ok and type(name) == "string" and name ~= "" then
        local sep = string.find(name, "|", 1, true)
        -- [C71] What the county has been calling them until now. Every
        -- belief anybody holds about this person is keyed by it, and
        -- the line below is where it stops being their key.
        local wasKey = SAO.Identity.beliefKey(rec)
        if sep then
            rec.forename = string.sub(name, 1, sep - 1)
            rec.surname = string.sub(name, sep + 1)
            -- [B38] A family shares a name. Genesis cannot do this -
            -- names arrive from the engine shell when a body first
            -- materialises, long after the unit was formed - so the
            -- first of a family to be named keeps theirs and the rest
            -- take it when their turn comes.
            if rec.unitId and rec.unitKind == "family" then
                for _, other in pairs(SAO.Identity.all()) do
                    if other.unitId == rec.unitId and other.id ~= rec.id
                        and other.surname and other.surname ~= ""
                        and other.forename ~= "Unnamed" then
                        rec.surname = other.surname
                        break
                    end
                end
            end
            SAO.Identity.noteRenamed()   -- [A22] name index drops
            -- [C71] And everyone who knew them keeps knowing them.
            -- Without this the county forgets a person at the moment
            -- a player first walks near them, because that is when
            -- their key changes.
            pcall(function()
                local moved = SAO.Perception.migratePersonKey(
                    wasKey, SAO.Identity.beliefKey(rec))
                if moved > 0 then
                    log(moved .. " belief(s) about " .. rec.id
                        .. " follow the name they were just given")
                end
            end)
            log(rec.id .. " is " .. rec.forename .. " " .. rec.surname
                .. " of " .. tostring(rec.originRegion))
        end
    end
end

local function materializeBand(px, py, conf)
    for id, rec in pairs(SAO.Identity.all()) do
      if not rec.dead and SAO.Body.recover(rec) == true then
        local hasBody = SAO.Body.hasRepresentation(id)
        local d = dist(rec.x, rec.y, px, py)
        if SAO.Claims.isHeld(rec) then
            -- Inhabitants are never conjured ([A17]): a Knox person's
            -- body is the legacy mod's business; absence means they are
            -- elsewhere, not ours to spawn. Passive adoption handles
            -- presence; nothing here may replace them.
        elseif not hasBody and d <= conf.materialize then
            local body = SAO.Body.materialize(rec)
            if body then
                backfillName(rec, body)
                -- [B38] Age reaches the head. Once per person, the
                -- first time a body exists to carry it.
                if SAO.Appearance and SAO.Appearance.applyAge then
                    pcall(SAO.Appearance.applyAge, rec, body)
                end
                rec.backstory = nil   -- [A14]: stored prose is not a record field
                if rec.epistemicMonths == nil then
                    pcall(function() SAO.History.generate(id, rec) end)
                end
                -- A person owns things. What they carry follows who they are:
                -- the aggressive keep a weapon to hand; everyone has a knife
                -- in the kitchen. Granted once per record, at first meeting.
                if not rec.kitGranted and not rec.hibernation and SAOJavaBridge then
                    rec.kitGranted = true
                    -- Dress the trade ([A20]): the census becomes
                    -- visible - you SEE the deputy. Fresh bodies only;
                    -- an awakened person wears what they wore.
                    local outfitName = SAO.Census and SAO.Census.outfitOf
                        and SAO.Census.outfitOf(rec.occupation) or nil
                    if outfitName then
                        pcall(function()
                            SAOJavaBridge:dressInOutfit(body, outfitName)
                        end)
                    end
                    -- The pockets of the place ([A28]): nothing is
                    -- granted. The containers around their lived-in
                    -- ground hold the engine's OWN distributed loot
                    -- (census anchoring put the deputy at the station,
                    -- so the station's real lockers are their supply);
                    -- items are MOVED, not conjured - what they carry
                    -- leaves a shelf somewhere. WHO they are decides
                    -- what they spotted, by trait and class AXES,
                    -- never profession rows. Barren surroundings mean
                    -- poor pockets - that is what desperate means.
                    local t = SAO.Disposition.traits(id)
                    local cls = SAO.Census and SAO.Census.classOf
                        and SAO.Census.classOf(rec.occupation) or nil
                    -- Day zero innocence ([A29]): before the fall,
                    -- only the duty trades go armed - a civilian does
                    -- not carry a bat to the diner. The first horrors
                    -- change who reaches for weapons, through lessons,
                    -- not through this gate.
                    local dz200 = SandboxVars
                        and SandboxVars.SurvivorAwareness
                        and SandboxVars.SurvivorAwareness.DayZero == true
                    local dutyArmed = rec.occupation == "police"
                        or rec.occupation == "soldier"
                        or rec.occupation == "veteran"
                    pcall(function()
                        if (dz200 and dutyArmed)
                            or (not dz200
                                and (t.aggression > 0.55
                                    or cls == "hardened")) then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "weapon", 1)
                        end
                        SAOJavaBridge:takeWantedFromNearby(body, 10,
                            "food", 1 + math.floor(t.appetite * 2 + 0.5))
                        SAOJavaBridge:takeWantedFromNearby(
                            body, 10, "water", 1)
                        -- Everybody grabs the flashlight ([B17]).
                        SAOJavaBridge:takeWantedFromNearby(
                            body, 10, "light", 1)
                        if cls == "carer" or t.compassion > 0.55 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "medical", 2)
                        end
                        if rec.occupation == "farmer"
                            or cls == "settled" then
                            -- Farm hands spot their gear ([B4]).
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "seeds", 2)
                        end
                        if cls == "trades" then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "tool", 1)
                            -- Builders spot materials ([B2]).
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "plank", 2)
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "nails", 1)
                        end
                        if cls == "hardened" or cls == "outdoors"
                            or t.initiative > 0.6 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "device", 1)
                        end
                        SAOJavaBridge:equipBestMelee(body)
                        -- Ownership is READ, never asserted: the radio
                        -- claim derives from what the place actually
                        -- yielded ([A27] ownsRadio).
                        rec.hasRadio = SAO.Standing.ownsRadio(id) or nil
                        -- The journal ([A24]): a written snapshot of
                        -- who they are at first meeting - claims
                        -- rendered at WRITE time (staleness is what
                        -- journals are). Loot the corpse, read the
                        -- life.
                        pcall(function()
                            local jname = (SAO.Identity.displayName(rec)
                                or "A survivor") .. "'s journal"
                            local page1 = (SAO.Census.describe(rec) or "")
                            local orig = SAO.Census.originNote
                                and SAO.Census.originNote(rec) or nil
                            if orig then
                                page1 = page1 .. "\nIt started at "
                                    .. orig .. "."
                            end
                            local page2 = SAO.History.describe(id) or ""
                            -- The era in ink ([B1]): a journal written
                            -- after the world changed for them says
                            -- so; one written in innocence carries no
                            -- such line - the absence IS the era mark.
                            local fh9 = SAO.Lessons.firstLessonHours
                                and SAO.Lessons.firstLessonHours(id) or nil
                            if fh9 then
                                page2 = page2 .. "\nDay "
                                    .. math.max(1, math.floor(fh9 / 24))
                                    .. " was when I stopped believing"
                                    .. " it would pass."
                            end
                            SAOJavaBridge:giveJournal(body, jname,
                                page1, page2)
                        end)
                        -- The rest of the pockets ([A28], same law):
                        -- the habit and the temperament SPOT what the
                        -- place holds; nothing granted. Carer medical
                        -- spotting lives in the main pulls above.
                        if SAO.Disposition.isSmoker(id) then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "smokes", 2)
                        end
                        -- [B25] The bar was 0.6 where both other
                        -- identity gates use 0.5 - the midpoint of
                        -- the human envelope [0.15, 0.85] this file's
                        -- own header declares. Nothing justified the
                        -- difference, and the 0.50-0.60 band it
                        -- created was a dead zone: too quiet to play,
                        -- and shut out of `reading` too unless
                        -- disciplined. Seven people in a county of
                        -- sixty lived in that band with nothing.
                        if SAO.Disposition.traits(id).talkativeness > 0.5 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "instrument", 1)
                        end
                        -- Ownership is READ: the instrument claim
                        -- derives from what the place actually
                        -- yielded, engine display category as the
                        -- truth.
                        local carried = SAOJavaBridge:carriedDisplayCategory(
                            body, "InstrumentWeapon")
                        rec.instrument = (carried ~= nil and carried ~= "")
                            and tostring(carried) or nil
                        -- [B22] What they carry FORWARD. The same law
                        -- as the instrument above - temperament spots
                        -- what the place holds, and ownership is READ
                        -- rather than granted - extended past the two
                        -- entries it had. Most of this county has no
                        -- useful trade, and a person is not their job.
                        if SAO.Disposition.traits(id).compassion > 0.5 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "memento", 1)
                        end
                        -- [B25] The `talkativeness <= 0.6` clause is
                        -- gone. Nothing else in the identity layer is
                        -- exclusive - a keepsake already sits happily
                        -- beside either of the others - and being
                        -- talkative is no reason a disciplined person
                        -- would not keep their books. It was also
                        -- written against the same constant as the
                        -- gate above, so moving that bar alone would
                        -- have taken the book off the two most
                        -- disciplined people in the county (0.82 and
                        -- 0.81) and handed them an instrument.
                        if SAO.Disposition.traits(id).discipline > 0.5 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "reading", 1)
                        end
                        -- [B26] Both of the engine's words for a
                        -- keepsake, because the seek side already
                        -- takes either. Reading only the display
                        -- category meant a survivor could pick up a
                        -- photo album and still be recorded as
                        -- carrying nothing forward.
                        local kept = SAOJavaBridge:carriedMemento(body)
                        rec.keepsake = (kept ~= nil and kept ~= "")
                            and tostring(kept) or nil
                        local read = SAOJavaBridge:carriedDisplayCategory(
                            body, "Literature")
                        rec.reading = (read ~= nil and read ~= "")
                            and tostring(read) or nil
                    end)
                end
                -- [C3] One person, one name: the papers a body carries
                -- say what the menu says. Runs on EVERY materialization
                -- - it heals journals titled while the name pipeline
                -- stamped "Unnamed" over the engine's name, and ensures
                -- the ID card death will drop, named with the living
                -- name. A nameless record carries no papers.
                local paperName = SAO.Identity.knownName(rec)
                if paperName and SAOJavaBridge then
                    pcall(function()
                        SAOJavaBridge:refreshIdentityPapers(body, paperName)
                    end)
                end
                SAO.Controller.adopt(rec)
                log(rec.id .. " is nearby (" .. string.format("%.0f", d) .. " tiles)")
            end
        elseif hasBody and d > conf.hibernate then
            local body = SAO.Body.get(id)
            local bd = body and dist(body:getX(), body:getY(), px, py) or d
            if bd > conf.hibernate then
                local released, reason = SAO.Body.release(rec)
                if released then
                    log(rec.id .. " continues without you (dormant at "
                        .. rec.x .. "," .. rec.y .. ")")
                else
                    log(rec.id .. " release deferred: " .. tostring(reason))
                end
            end
        end
      end
    end
end

-- The Knox base seed ([A19], DR-009 read-only): the legacy mod's own
-- world store names each survivor's group and each group's base. An
-- adoptee's HOME and their place-belief of their own base come from
-- there - what Nicole knows best is where Nicole lives, and the roads
-- ([A17]) can now carry it. Their store is never written.
local function seedKnoxBase(id, rec, kid)
    local okD, data = pcall(function()
        return ModData.getOrCreate("KnoxSurvivorsWorld")
    end)
    if not okD or type(data) ~= "table" then return end
    local survivors = data.survivors or {}
    local entry = survivors[kid] or survivors[tonumber(kid)] or nil
    if not entry then return end
    -- [B42] [A20] REVERSED, on operator direction and on DR-009,
    -- which it had always contradicted: "where the two systems collide
    -- SAO's reading overrides on SAO's side."
    --
    -- What stood here read a foreign profile's coarse archetype,
    -- mapped it onto a census key through a table written by hand -
    -- its own comment said "by closest life-shape" - and then did two
    -- things with it. It overwrote `rec.occupation`, which DR-009 says
    -- it may not. And it cleared `rec.occupationPresumed`, which is
    -- worse and was the part nobody was looking at.
    --
    -- That flag is this project's honesty about its own guessing.
    -- `Census.describe` says "carries themselves like a nurse" while it
    -- is set and "was a nurse in Riverside when it started" once it is
    -- not, and `Census.originNote` refuses to invent a beginning for a
    -- presumed trade at all ([A22]: "we do not put a beginning in the
    -- mouth of someone whose past we only guessed at"). So clearing it
    -- did not import a fact - it LAUNDERED OUR OWN GUESS INTO ONE, on
    -- the strength of thirteen authored equivalences.
    --
    -- Their profile is still read: the trust rows below and the camp
    -- come from it, because those are theirs to state. Who somebody
    -- was is ours to presume, and to say we presumed it.
    -- Their people came with them ([A21]): the legacy store keeps
    -- DIRECTIONAL relationship rows ("kid|kid" -> weight). Import this
    -- adoptee's outbound rows ONCE, at half-strength (weight/100,
    -- clamped to +-0.8) - Nicole trusts her squadmates in our economy
    -- too, but nothing imported can outweigh what gets earned here.
    -- Read-only; rows toward non-survivor targets (the player's KS-side
    -- id) are skipped - a named gap, not a guess.
    if not rec.ksTrustImported then
        rec.ksTrustImported = true
        local rels = data.relationships or {}
        local prefix = tostring(kid) .. "|"
        local imported = 0
        for key, row in pairs(rels) do
            if imported >= 20 then break end
            if tostring(key):sub(1, #prefix) == prefix
                and type(row) == "table" and tonumber(row.weight) then
                local targetKid = tostring(key):sub(#prefix + 1)
                if survivors[targetKid] then
                    local delta = math.max(-0.8, math.min(0.8,
                        tonumber(row.weight) / 100.0))
                    if delta ~= 0 then
                        SAO.Standing.adjustTrust(id, "ks:" .. targetKid, delta)
                        imported = imported + 1
                    end
                end
            end
        end
        if imported > 0 then
            log(id .. " brought their people with them ("
                .. imported .. " standing relations imported)")
        end
    end
    -- The base seed needs a group; solo lives stop here with their
    -- truth already kept ([A20] guard split).
    if not entry.groupId then return end
    local group = (data.groups or {})[entry.groupId]
    local base = group and group.baseId
        and (data.bases or {})[group.baseId] or nil
    if not base or not base.x then return end
    if not rec.homeX then
        rec.homeX, rec.homeY, rec.homeZ = base.x, base.y, base.z or 0
    end
    local bounds = {
        minX = base.x - 6, minY = base.y - 6,
        maxX = base.x + 6, maxY = base.y + 6,
    }
    pcall(function()
        -- [B39] Their OWN camp. The registry is the evidence here
        -- because they live in it - which is the one case where
        -- reading a table and having been somewhere are the same
        -- fact, and it is worth saying so rather than assuming it.
        SAO.Perception.learnPlace(id, "ks-camp:" .. tostring(group.baseId
            or entry.groupId), bounds, "observed")
    end)
    log(id .. " knows their own camp at " .. base.x .. "," .. base.y)
end

-- Inhabitation ([A17], DR-009): the Knox people already living in this
-- save ARE the population. A live Knox human seen in the world gets an
-- SAO record - id "ks:<name>", months-alive from the engine's own
-- hours-survived, contact-scaled past - and stands in the economy as a
-- PASSIVE agent: never driven, never released, never rewritten on the
-- KS side. Their body registers for the exchange; their death mourns.
local function inhabitKnox()
    if not SAOJavaBridge then return end
    local me = getSpecificPlayer(0)
    if not me then return end
    local ok, listed = pcall(function()
        return SAOJavaBridge:listKnoxHumans(me)
    end)
    if not ok or type(listed) ~= "string" then return end
    local seen = {}
    if listed ~= "" then
        for entry in string.gmatch(listed, "[^|]+") do
            local kid, name, kx, ky, hours = string.match(entry,
                "^([^:]+):([^:]+):(%-?%d+):(%-?%d+):(%d+)$")
            if kid and name then
                local id = "ks:" .. kid
                seen[id] = true
                -- The rename owes nothing ([A19]): a save that met this
                -- person under the [A17] name-keyed scheme holds their
                -- trust web at "ks:<name>". The kid-keyed record absorbs
                -- it once - standing (both directions), beliefs, and the
                -- legacy record's own settled fields - then the orphan
                -- is removed.
                -- [A24]: legacy name-keyed ids may be forename-only
                -- (pre-full-name era) or full-name - try both.
                local forenameOnly = string.match(name, "^([^ ]+)") or name
                local legacyId = "ks:" .. name
                if not SAO.Identity.get(legacyId) then
                    local alt = "ks:" .. forenameOnly
                    if SAO.Identity.get(alt) then legacyId = alt end
                end
                if legacyId ~= id then
                    local legacy = SAO.Identity.get(legacyId)
                    if legacy then
                        pcall(function()
                            SAO.Standing.migrateKey(legacyId, id)
                            if SAO.Perception.beliefs[legacyId]
                                and not SAO.Perception.beliefs[id] then
                                SAO.Perception.beliefs[id] =
                                    SAO.Perception.beliefs[legacyId]
                            end
                            SAO.Perception.beliefs[legacyId] = nil
                            if SAO.Identity.get(id) then
                                -- Both exist somehow: keep the kid-keyed
                                -- record, drop the orphan.
                                SAO.Identity.remove(legacyId)
                            else
                                -- Absorb by rebirth: the legacy record
                                -- BECOMES the kid-keyed one - history,
                                -- lessons, and all.
                                SAO.Identity.rekey(legacyId, id)
                            end
                            log(legacyId .. " -> " .. id
                                .. " (the rename owes nothing)")
                        end)
                    end
                end
                -- [C3] One person, one name. The neighbour framework
                -- names its people from its own profile table and never
                -- writes the descriptor - the descriptor carries a
                -- random engine name the neighbour never shows, and
                -- adopting THAT put two names on one body: this menu's
                -- and the neighbour's ID card's. The profile name is
                -- the person's name; the descriptor is aligned below so
                -- every reader agrees.
                local ksName = nil
                pcall(function()
                    local KSNS = KnoxSurvivors
                    if type(KSNS) == "table" and KSNS.GetActor
                        and KSNS.GetActorProfile then
                        local actor = KSNS.GetActor(kid)
                        local prof = actor and KSNS.GetActorProfile(actor)
                        if prof and prof.name
                            and tostring(prof.name) ~= "" then
                            ksName = tostring(prof.name)
                        end
                    end
                end)
                local rec = SAO.Identity.ensure(id, ksName or name, "", kx, ky, 0)
                if rec and ksName and rec.forename ~= ksName then
                    log(id .. " answers to " .. ksName .. " (the county had "
                        .. tostring(rec.forename) .. ") - one person, one name")
                    rec.forename = ksName
                    rec.surname = ""
                    SAO.Identity.noteRenamed()
                end
                if rec and not SAO.Claims.isHeld(rec) then
                    SAO.Claims.claim(rec, SAO.Claims.KNOX_SURVIVORS)
                    local monthsAlive = (tonumber(hours) or 0) / (24.0 * 30.0)
                    seedKnoxBase(id, rec, kid)
                    pcall(function()
                        SAO.History.generate(id, rec, math.max(0.1, monthsAlive))
                    end)
                    log(id .. " inhabits the economy ("
                        .. string.format("%.1f", monthsAlive) .. " months survived)")
                end
                if rec then
                    -- [A22]: records adopted BEFORE the import/seed
                    -- eras catch up here - seedKnoxBase is guarded
                    -- per-feature (ksTrustImported, homeX, occupation
                    -- same-value), so this is a no-op once caught up.
                    if SAO.Claims.isHeld(rec) and not rec.ksTrustImported then
                        seedKnoxBase(id, rec, kid)
                    end
                    -- [B42] The residue of [A20], in worlds that
                    -- already ran it. `H.generate` returns early once a
                    -- record has a past, so reversing the code does not
                    -- reach anyone already adopted: they keep an
                    -- occupation that came from a foreign archetype
                    -- through a hand-written table, asserted as fact.
                    --
                    -- They are identifiable exactly. The census flags
                    -- EVERY Knox draw as presumed, so a Knox record
                    -- holding an occupation with no flag can only have
                    -- got it from the seed that DR-012 removed. The
                    -- occupation itself is left alone - rewriting who
                    -- somebody is mid-save is the one thing worth
                    -- avoiding here - and only the warning label goes
                    -- back on, which is what [A22] wanted all along.
                    if SAO.Claims.isHeld(rec) and rec.occupation
                        and not rec.occupationPresumed then
                        rec.occupationPresumed = true
                        log(id .. " was never known to have been a "
                            .. tostring(rec.occupation)
                            .. " - that was read off a legacy archetype;"
                            .. " the county presumes it now")
                    end
                    rec.x, rec.y = tonumber(kx), tonumber(ky)
                    local okB, kbody = pcall(function()
                        return SAOJavaBridge:knoxBodyByName(me, name)
                    end)
                    -- forename stays the belief-level name; the record id
                    -- is theirs for good.

                    if okB and kbody then
                        SAO.Body.foreign[id] = kbody
                        -- [C3] Align the descriptor to the profile name
                        -- so the scanner, knoxBodyByName, and the
                        -- neighbour's own card say one string from here.
                        if ksName then
                            pcall(function()
                                SAOJavaBridge:alignKnoxName(kbody, ksName)
                            end)
                        end
                        -- [C8] Our id on his body, our key only - the
                        -- hands-off rule ([A17]) is about HIS keys. Death
                        -- and the turn carry the mark through the
                        -- engine's own modData copies (F-044).
                        pcall(function()
                            kbody:getModData().SAOPersonId = id
                        end)
                        SAO.Controller.adoptPassive(rec)
                    end
                end
            end
        end
    end
    -- Bodies that left the cell (or died) fall out of the live registry;
    -- records persist, deaths are noticed by the passive pass.
    for id in pairs(SAO.Body.foreign) do
        if not seen[id] then
            SAO.Body.foreign[id] = nil
        end
    end
end

R.materializeBand = materializeBand
R.inhabitKnox = inhabitKnox
return R
