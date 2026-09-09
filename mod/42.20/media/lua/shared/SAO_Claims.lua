-- SAO_Claims - somebody else's body, and how this county knows it.
-- ---------------------------------------------------------------------------
-- The county held this fact as `rec.knox`, a boolean named after one
-- mod, and read it in twenty-four places to decide four different
-- things: never conjure a body for them, never walk them on the
-- dormant day, never let attrition take them, and presume their
-- occupation rather than asserting it.
--
-- None of those is a question about Knox Survivors. Every one of them
-- is the same question - **is somebody else driving this body** - and
-- writing it as a mod's name put that mod into the logic of a project
-- whose rule is that a mod is never named in logic (DR-035). The next
-- population framework would have needed a second boolean and
-- twenty-four more branches beside the first.
--
-- So the fact is a property now. `heldBy` names WHO, because a claim
-- with no owner cannot be released by the right party or reported to a
-- player, and the sister project found the same thing reading two
-- other mods: a claim query that answers who and how is a different
-- instrument from one that answers yes or no.
--
-- WHAT THIS IS NOT. It is not a registry of mods and it is not an
-- integration. The one place that needs to know a claim belongs to a
-- particular mod - because it dispatches into that mod's own menu - is
-- that mod's own integration file, where the name is a constant in one
-- place rather than a condition in twenty.
--
-- LEGACY RECORDS. A save written before this carries `rec.knox` and
-- nothing else. It is read here, once, as a claim by the only holder
-- that flag could ever have meant. Nothing rewrites the record: a live
-- save keeps working and the old flag simply answers the new question.
--
-- OFFLINE BY CONSTRUCTION: pure table reads, no engine surface at all.

SAO = SAO or {}
SAO.Claims = SAO.Claims or {}
local Cl = SAO.Claims

-- The one holder this county currently integrates with, named here so
-- that it is named ONCE. Every site that used to branch on a mod's
-- name now asks a property; the two places that actually record a
-- claim reach for this constant, and a record written before the
-- property existed is read through it as well, because a boolean named
-- after one mod could only ever have meant that mod.
Cl.KNOX_SURVIVORS = "KnoxSurvivors"

---Who holds this person's body, or nil if the county does.
---@param rec table
---@return string|nil owner
function Cl.heldBy(rec)
    if type(rec) ~= "table" then return nil end
    local owner = rec.heldBy
    if type(owner) == "string" and owner ~= "" then return owner end
    -- A record from before the property existed.
    if rec.knox then return Cl.KNOX_SURVIVORS end
    return nil
end

---Is anybody else driving this body?
function Cl.isHeld(rec)
    return Cl.heldBy(rec) ~= nil
end

---The same question by id, for the many call sites that hold one.
function Cl.isHeldId(id)
    if not (SAO.Identity and SAO.Identity.get) then return false end
    return Cl.isHeld(SAO.Identity.get(id))
end

---Record that another system drives this body from now on.
---
---Never writes the legacy flag. A record claimed after this batch
---carries the owner and nothing else, and one claimed before carries
---the flag and is read through it - the two coexist and neither is
---rewritten, because rewriting somebody's save to tidy a field name is
---a judgement about their save.
function Cl.claim(rec, owner)
    if type(rec) ~= "table" then return false end
    if type(owner) ~= "string" or owner == "" then return false end
    rec.heldBy = owner
    return true
end

---Give the body back. The county may drive it again.
function Cl.release(rec)
    if type(rec) ~= "table" then return false end
    local had = Cl.isHeld(rec)
    rec.heldBy = nil
    rec.knox = nil
    return had
end

return Cl
