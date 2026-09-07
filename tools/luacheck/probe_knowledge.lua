-- Border 101's stub county: just enough store for SAO_Knowledge to
-- answer from, none of it engine. The knowledge module must load and
-- answer in this bare VM - that is the offline-by-construction
-- promise SPEECH.md made for rung 1.

SAO = SAO or {}

-- One person, "p1", who has seen two crowds, knows Marcus is dead
-- because Dana said so, carries one lesson, belongs to a house at
-- war, and trusts the listener not at all.

SAO.Perception = {
    beliefs = {
        p1 = {
            people = {
                Marcus = { dead = true, source = "told",
                           teller = "Dana" },
                Dana = { x = 120, y = 80, at = 1500,
                         source = "observed", condition = "ok" },
            },
            zombies = {
                ["100,100"] = { x = 100, y = 100, dist = 30,
                                at = 1900, source = "observed" },
                ["300,300"] = { x = 300, y = 300, dist = 250,
                                at = 400, source = "heard" },
            },
            places = {
                p9 = { minX = 10, maxX = 30, minY = 10, maxY = 30,
                       source = "observed" },
            },
        },
    },
    whereWord = function(x, y, sx, sy) return "north of here" end,
}

SAO.Identity = {
    get = function(id)
        if id == "p1" then
            return { id = "p1", x = 50, y = 50,
                     newcomer = true, arrivedAtHours = 120,
                     designation = "forager",
                     lessonsKnown = { ["keep-quiet"] = true },
                     lessonMeta = { ["keep-quiet"] = {
                         src = "lived", of = nil } } }
        end
        if id == "p9" then return { id = "p9",
            forename = "Ruth", surname = "Hall" } end
        return nil
    end,
    knownName = function(rec)
        if not rec then return nil end
        if rec.forename then
            return rec.forename .. " " .. (rec.surname or "")
        end
        return nil
    end,
}

SAO.Standing = {
    trust = function(id, key) return 0.2 end,
    debt = function(id, key) return 1 end,
    isHostileTo = function(id, key) return false end,
    groupOf = function(id) return "g1" end,
    factionName = function(g)
        if g == "g1" then return "the Mill" end
        if g == "g2" then return "the Yard" end
        return nil
    end,
    leaderOf = function(g) return "p9" end,
    creedOf = function(g) return { name = "wall" } end,
    larderOf = function(g) return { word = "lean" } end,
    waterStoreOf = function(g) return { word = "fine" } end,
    allGroupClaims = function()
        return { g1 = { minX = 0, maxX = 9, minY = 0, maxY = 9 },
                 g2 = { minX = 90, maxX = 99, minY = 90, maxY = 99 } }
    end,
    feudBetween = function(a, b) return true end,
    pactBetween = function(a, b) return false end,
}

SAO.Census = {
    describe = function(rec) return "kept a store" end,
    originNote = function(rec) return "Muldraugh" end,
}

SAO.Lessons = {
    REGISTRY = { ["keep-quiet"] = { line = "Quiet keeps you alive." } },
    firstLessonHours = function(id) return 72 end,
}

SAO.Disposition = {
    traits = function(id)
        return { nerve = 0.5, discipline = 0.5, aggression = 0.5,
                 initiative = 0.5, selfPreservation = 0.5,
                 compassion = 0.5, appetite = 0.5,
                 talkativeness = 0.5 }
    end,
}

SAO.Body = { get = function(id) return nil end }

SAO.Places = {
    comfortHorizon = function() return 150 end,
    nearestOffering = function(x, y, offer, horizon)
        return { cx = 60, cy = 40, id = 7 }
    end,
}

GameTime = {
    getInstance = function()
        return { getWorldAgeHours = function(self) return 240 end }
    end,
}
