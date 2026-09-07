-- Border 105's stub county: just enough for SAO_History to load and
-- answer age questions in the engine's own bare VM - none of it
-- engine. SAO_Hash.lua is loaded before this as a real chunk (the
-- hash is the fact everything about a person is drawn from, so the
-- probe runs the real one), and SAO_History.lua after it.

SAO = SAO or {}

SAO.Log = {
    line = function(tag, msg) end,
    tally = function(tag, kind) end,
}

-- A census that always deals a trades row, so that when a child comes
-- back a student and an elder a retiree, it was the age that decided,
-- not the draw.
SAO.Census = {
    assign = function(id)
        return { key = "carpenter", label = "carpenter", per10k = 100 }
    end,
    rowOf = function(key)
        return { key = key, label = key, per10k = 100 }
    end,
    classOf = function(key)
        if key == "student" or key == "retiree" then return "settled" end
        return "trades"
    end,
    originNote = function(rec) return nil end,
}

-- The eight axes SAO_Disposition declares, flat; the past's grammar
-- compares them and nothing here cares which way they lean. (The
-- first draft named eight axes of its own and the grammar compared
-- nil with a number - generate() threw after the work was set.)
SAO.Disposition = {
    traits = function(id)
        return { nerve = 0.5, discipline = 0.5, aggression = 0.5,
                 initiative = 0.5, selfPreservation = 0.5,
                 compassion = 0.5, appetite = 0.5,
                 talkativeness = 0.5 }
    end,
}

SAO.Lessons = {
    learn = function() end,
    all = function() return {} end,
    -- [C31] the disposition's decisions ask these; nothing learned here.
    shootBarBump = function() return 0 end,
    charityEase = function() return 0 end,
}

SAO.Standing = {}
SAO.Identity = {
    get = function(id) return nil end,
    all = function() return {} end,
}
