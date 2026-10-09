-- Installed Kahlua executes the production appearance code against distinct
-- body and descriptor visuals, matching IsoPlayer's constructor ownership.
local ages = {}
local failures = {}
local checks = 0
SAO = {
    Hash = { of = function() return 0 end },
    History = { ageOf = function(id) return ages[id] end },
    Log = { line = function() end },
}

local function colour(r, g, b)
    local c = { r = r, g = g, b = b }
    function c:getRedFloat() return self.r end
    function c:getGreenFloat() return self.g end
    function c:getBlueFloat() return self.b end
    return c
end
ImmutableColor = { new = colour }

local function near(a, b)
    return a and b and math.abs(a.r - b.r) < 0.001
        and math.abs(a.g - b.g) < 0.001
        and math.abs(a.b - b.b) < 0.001
end

local function visual(hair, beard)
    local v = {
        naturalHair = colour(0.20, 0.10, 0.05),
        naturalBeard = colour(0.25, 0.13, 0.08),
        hair = hair or colour(0.20, 0.10, 0.05),
        beard = beard or colour(0.25, 0.13, 0.08),
        hairModel = "Short", beardModel = "Full",
        writes = 0, naturalWrites = 0,
    }
    function v:getNaturalHairColor() return self.naturalHair end
    function v:getNaturalBeardColor() return self.naturalBeard end
    function v:getHairColor() return self.hair end
    function v:getBeardColor() return self.beard end
    function v:setHairColor(c) self.hair = c; self.writes = self.writes + 1 end
    function v:setBeardColor(c) self.beard = c; self.writes = self.writes + 1 end
    function v:getHairModel() return self.hairModel end
    function v:getBeardModel() return self.beardModel end
    function v:setHairModel(m) self.hairModel = m; self.writes = self.writes + 1 end
    function v:setBeardModel(m) self.beardModel = m; self.writes = self.writes + 1 end
    return v
end

local function body(bodyVisual, descriptorVisual)
    local b = { visual = bodyVisual, descriptor = { visual = descriptorVisual }, redraws = 0,
        beardResets = 0 }
    function b:getHumanVisual() return self.visual end
    function b:getDescriptor() return self.descriptor end
    function b.descriptor:getHumanVisual() return self.visual end
    function b:resetModelNextFrame() self.redraws = self.redraws + 1 end
    function b:resetBeardGrowingTime() self.beardResets = self.beardResets + 1 end
    return b
end

local function check(name, yes)
    checks = checks + 1
    if yes then print("PASS " .. name)
    else print("FAIL " .. name); failures[#failures + 1] = name end
end

function appearanceBaseVisualCases()
    local A = SAO.Appearance
    local rec = { id = "legacy-older", greyApplied = true, name = "Known Person" }
    ages[rec.id] = 45
    local base, desc = visual(), visual()
    local b = body(base, desc)
    local original = base.naturalHair
    local old = desc.hair
    check("legacy/body-baseVisual", A.applyAge(rec, b) == true
        and base.hair ~= old and base.hair.r > 0.2 and b.redraws == 1)
    check("legacy/descriptor-aligned", near(desc.hair, base.hair)
        and near(desc.beard, base.beard))
    check("legacy/natural-identity-preserved", base.naturalHair == original
        and base.naturalWrites == 0 and rec.id == "legacy-older"
        and rec.name == "Known Person")
    check("legacy/age-owned-record", type(rec.appearanceGrey) == "table"
        and near(rec.appearanceGrey.hair, base.hair)
        and rec.greyApplied == true)
    local redraws = b.redraws
    check("reload/same-age-idempotent", A.applyAge(rec, b) == false
        and b.redraws == redraws)

    -- Snapshot/reload keeps a displayed visual plus the plain-table person
    -- record. Age progression updates only colours still owned by age.
    local loadedBase = visual(base.hair, base.beard)
    local loadedDesc = visual(desc.hair, desc.beard)
    local loaded = body(loadedBase, loadedDesc)
    ages[rec.id] = 50
    local previousHair = rec.appearanceGrey and rec.appearanceGrey.hair or base.hair
    check("reload/age-progresses", A.applyAge(rec, loaded) == true
        and loadedBase.hair.r > previousHair.r
        and near(loadedDesc.hair, loadedBase.hair)
        and near(rec.appearanceGrey and rec.appearanceGrey.hair, loadedBase.hair))
    check("reload/second-pass-idempotent", A.applyAge(rec, loaded) == false
        and loaded.redraws == 1)

    local ownedHair = rec.appearanceGrey and rec.appearanceGrey.hair or base.hair
    local dyed = colour(0.04, 0.12, 0.84)
    loadedBase:setHairColor(dyed)
    ages[rec.id] = 55
    check("choice/dye-preserved", A.applyAge(rec, loaded) == true
        and loadedBase.hair == dyed and loadedDesc.hair == dyed
        and rec.appearanceGrey and rec.appearanceGrey.hair == ownedHair)
    loadedBase:setHairColor(loadedBase.naturalHair)
    check("choice/natural-restored-ages", A.applyAge(rec, loaded) == true
        and loadedBase.hair ~= dyed and loadedBase.hair.r > ownedHair.r)

    local child = { id = "child" }
    ages[child.id] = 12
    local childBase, childDesc = visual(), visual()
    childBase.hairModel, childBase.beardModel = "MohawkFan", "Full"
    local childBody = body(childBase, childDesc)
    check("child/body-style", A.applyAge(child, childBody) == true
        and childBase.hairModel ~= "MohawkFan"
        and childBase.beardModel == "" and childBody.beardResets == 1
        and childDesc.hairModel == childBase.hairModel
        and childDesc.beardModel == "")
    check("child/second-pass-idempotent", A.applyAge(child, childBody) == false
        and childBody.beardResets == 1)

    local absent = body(nil, visual())
    local absentWrites = absent.descriptor.visual.writes
    check("missing-body-visual/fail-closed", A.applyAge(rec, absent) == false
        and absent.descriptor.visual.writes == absentWrites)
    return tostring(checks) .. ":" .. table.concat(failures, ",")
end
