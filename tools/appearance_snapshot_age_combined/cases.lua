local failures, checks = {}, 0
local function channels(c)
    if not c then return nil end
    if type(c) == "table" then return c.r, c.g, c.b end
    return c:getRedFloat(), c:getGreenFloat(), c:getBlueFloat()
end
local function near(a, b)
    if not a or not b then return false end
    local ar, ag, ab = channels(a)
    local br, bg, bb = channels(b)
    return ar and br and math.abs(ar - br) < 0.006
        and math.abs(ag - bg) < 0.006
        and math.abs(ab - bb) < 0.006
end
local function check(name, yes)
    checks = checks + 1
    if yes then print("PASS " .. name)
    else print("FAIL " .. name); failures[#failures + 1] = name end
end

function appearanceSnapshotAgeCases()
    local A = SAO.Appearance
    local rec = { id = "native-v4-age-person", name = "Native fixture" }
    local body = __nativeBody
    local base = body:getHumanVisual()
    local descriptor = body:getDescriptor():getHumanVisual()
    __age = 45
    local originalNatural = base:getNaturalHairColor()
    local previous = base:getHairColor()
    check("bridge/same-restored-native-body", __isSameBody(body)
        and __isNativeBody(body) and base ~= descriptor)
    check("combined/age-after-v4-restore", A.applyAge(rec, body) == true
        and not near(base:getHairColor(), previous)
        and rec.appearanceGrey and rec.appearanceGrey.fraction > 0)
    check("combined/display-and-descriptor", near(base:getHairColor(),
        descriptor:getHairColor()) and near(base:getBeardColor(),
        descriptor:getBeardColor()) and near(base:getNaturalHairColor(), originalNatural))
    local first = base:getHairColor()
    check("combined/same-age-idempotent", A.applyAge(rec, body) == false
        and near(base:getHairColor(), first))

    local reload = __reloadBody(body)
    local reloadedBase = reload:getHumanVisual()
    local reloadedDesc = reload:getDescriptor():getHumanVisual()
    check("reload/v4-preserves-age-display", __isNativeBody(reload)
        and reload ~= body and near(reloadedBase:getHairColor(), first))
    check("reload/same-age-idempotent", A.applyAge(rec, reload) == false)
    __age = 50
    check("reload/later-age-progresses", A.applyAge(rec, reload) == true
        and reloadedBase:getHairColor():getRedFloat() > first:getRedFloat()
        and near(reloadedBase:getHairColor(), reloadedDesc:getHairColor()))
    check("reload/later-age-idempotent", A.applyAge(rec, reload) == false)

    local ageOwned = reloadedBase:getHairColor()
    local dye = __nativeColour()
    reloadedBase:setHairColor(dye)
    local dyedReload = __reloadBody(reload)
    local dyedBase = dyedReload:getHumanVisual()
    check("choice/v4-preserves-dye", near(dyedBase:getHairColor(), dye))
    __age = 55
    A.applyAge(rec, dyedReload)
    check("choice/later-age-preserves-dye", near(dyedBase:getHairColor(), dye)
        and near(dyedReload:getDescriptor():getHumanVisual():getHairColor(), dye)
        and near(rec.appearanceGrey.hair, ageOwned))
    __age = nil
    local missing = { id = "native-missing-age" }
    local missingBody = __newBody()
    local atMissing = missingBody:getHumanVisual():getHairColor()
    check("missing-age/refuses", A.applyAge(missing, missingBody) == false
        and near(missingBody:getHumanVisual():getHairColor(), atMissing)
        and missing.appearanceGrey == nil)
    return tostring(checks) .. ":" .. table.concat(failures, ",")
end
