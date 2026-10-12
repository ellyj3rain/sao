-- Registered construction requirements for the existing physical work owner.
-- Native handles are transient. The plain projection grants no acquired site,
-- Standing, stock, knowledge, physical effect or consumer completion.
SAO = SAO or {}
SAO.ConstructionPolicy = {}
local P = SAO.ConstructionPolicy

local function plain(value, seen)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then
        if value == value and value ~= math.huge and value ~= -math.huge then return value end
        return nil
    end
    if kind ~= "table" or getmetatable(value) ~= nil then return nil end
    seen = seen or {}; if seen[value] then return nil end; seen[value] = true
    local result = {}
    for key, v in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then seen[value] = nil; return nil end
        local copied = plain(v, seen)
        if copied == nil then seen[value] = nil; return nil end
        result[key] = copied
    end
    seen[value] = nil; return result
end

local function callback(name)
    local current = _G
    for part in name:gmatch("[^%.]+") do
        if type(current) ~= "table" then return nil end
        current = current[part]
    end
    return type(current) == "function" and current or nil
end

-- Native cursor WNES is one-based; SpriteConfig cardinal NWSE is zero-based.
-- Resolve the installed nearest-valid-face policy without silently choosing it.
function P.resolveFace(info, cursor)
    if not info or type(cursor) ~= "number" or cursor % 1 ~= 0 or cursor < 1 or cursor > 4 then
        return nil, "native-cursor-required"
    end
    local ok, result = pcall(function()
        local requested = ({"W", "N", "E", "S"})[cursor]
        for offset = 0, 3 do
            local resolvedCursor = (cursor - 1 + offset) % 4 + 1
            local name = ({"W", "N", "E", "S"})[resolvedCursor]
            local face = info:getFace(name)
            if face then return {face = face, requested = requested, resolved = face:getFaceName(),
                cursor = resolvedCursor, fallback = offset ~= 0} end
        end
    end)
    if not ok then return nil, "native-face-resolution-unavailable" end
    return result, result == nil and "native-face-unavailable" or nil
end

local function geometry(info, selected)
    if type(selected) ~= "table" or type(selected.face) ~= "string" then return nil, "selected-face-required" end
    local face = info:getFace(selected.face)
    if not face then return nil, "selected-face-unavailable" end
    local cursor = selected.cursor
    if cursor ~= nil then
        local resolved, reason = P.resolveFace(info, cursor)
        if not resolved then return nil, reason end
        if resolved.fallback then return nil, "selected-face-fallback-required" end
        if resolved.resolved:upper() ~= selected.face:upper() then return nil, "selected-face-cursor-mismatch" end
    end
    local row = {face = face:getFaceName(), selectedFace = selected.face, cursor = cursor,
        width = face:getWidth(), height = face:getHeight(),
        zLayers = face:getzLayers(), masterSet = face:isMasterSet(), multiSquare = face:isMultiSquare(),
        masterX = face:getMasterX(), masterY = face:getMasterY(), masterZ = face:getMasterZ(),
        tiles = {}, occupiedCount = 0, blockingCount = 0}
    if row.width < 1 or row.height < 1 or row.zLayers < 1 then return nil, "native-face-dimensions-invalid" end
    local tiles = {}
    for z = 0, row.zLayers - 1 do for y = 0, row.height - 1 do for x = 0, row.width - 1 do
        local tile = face:getTileInfo(x, y, z)
        if tile then
            local sprite = tile:getSpriteName()
            local occupied = sprite ~= nil and sprite ~= ""
            local blocking = tile:isBlocking()
            local t = {x = tile:getX(), y = tile:getY(), z = tile:getZ(), sprite = sprite,
                occupied = occupied, blocking = blocking, empty = tile:isEmpty(), master = tile:isMaster(),
                masterOffsetX = tile:getMasterOffsetX(), masterOffsetY = tile:getMasterOffsetY(),
                masterOffsetZ = tile:getMasterOffsetZ()}
            row.tiles[#row.tiles + 1] = t
            tiles[#tiles + 1] = {script = tile, requirement = t}
            if occupied then row.occupiedCount = row.occupiedCount + 1 end
            if blocking then row.blockingCount = row.blockingCount + 1 end
        end
    end end end
    if row.occupiedCount == 0 then return nil, "native-face-no-object-effect" end
    return {face = face, tiles = tiles, requirement = row}
end

-- Describes an actual station component, not a declaration-only workplace.
-- Acquisition, key/revision and current Standing remain caller-owned.
function P.describeWorkplace(object, body)
    if not object or not body then return nil, "native-workplace-body-required" end
    local ok, result, reason = pcall(function()
        local entity = object:getEntityScript()
        if not entity or ScriptManager.instance:getGameEntityScript(entity:getScriptObjectFullType()) ~= entity then
            return nil, "workplace-entity-registration-changed"
        end
        local script = entity:getComponentScriptFor(ComponentType.CraftBench)
        local bench = object:getComponent(ComponentType.CraftBench)
        if not script or not bench then return nil, "actual-craftbench-component-required" end
        local recipes = {}
        local nativeRecipes = bench:getRecipes()
        if nativeRecipes then for n = 0, nativeRecipes:size() - 1 do
            local recipe = nativeRecipes:get(n)
            if ScriptManager.instance:getCraftRecipe(recipe:getScriptObjectFullType()) ~= recipe then
                return nil, "workplace-recipe-registration-changed"
            end
            recipes[#recipes + 1] = recipe:getScriptObjectFullType()
        end end
        local logic = BuildLogic.new(body, bench, object)
        local row = {entity = entity:getScriptObjectFullType(), recipeTagQuery = bench:getRecipeTagQuery(),
            -- Installed BuildLogic inherits a non-spatial true base method.
            -- A native result is therefore not actual reach or site admission.
            recipes = recipes, nativeRangeResult = logic:isCharacterInRangeOfWorkbench(),
            custody = object:isUsingPlayer(body), acquisitionRequired = true, standingRequired = true,
            rangeAdmission = "owner-required", resourceSupply = "owner-required"}
        return {object = object, entity = entity, script = script, bench = bench, requirements = row}
    end)
    if not ok then return nil, "native-workplace-description-unavailable" end
    return result, reason
end

-- admissible means native policy eligibility only, never site/Standing/materials,
-- queue/body-purpose admission or physical credit. Unmet requirements remain.
-- No input selection is performed. Supply this BuildLogic to the existing
-- owner and its coordinated exact-slot selector; never substitute HandcraftLogic.
function P.describe(entityId, body, purpose, selected, workplace)
    if type(entityId) ~= "string" or not body or not SAO.RecipePolicy then
        return nil, "construction-entity-body-recipe-policy-required"
    end
    if type(purpose) ~= "table" or not plain(purpose) then return nil, "construction-purpose-not-plain" end
    local ok, policy, reason = pcall(function()
        local entity = ScriptManager.instance:getGameEntityScript(entityId)
        if not entity or entity:getScriptObjectFullType() ~= entityId then return nil, "entity-registration-required" end
        local sprite = entity:getComponentScriptFor(ComponentType.SpriteConfig)
        local component = entity:getComponentScriptFor(ComponentType.CraftRecipe)
        if not sprite or not component then return nil, "native-build-components-required" end
        local recipe = component:getCraftRecipe()
        if not recipe or ScriptManager.instance:getCraftRecipe(recipe:getScriptObjectFullType()) ~= recipe then
            return nil, "build-recipe-registration-changed"
        end
        local info = SpriteConfigManager.GetObjectInfo(sprite:getName())
        if not info or info:getScript() ~= sprite or info:getRecipe() ~= component then
            return nil, "native-build-object-identity-changed"
        end
        local logic = BuildLogic.new(body, workplace and workplace.bench, workplace and workplace.object)
        local registered = logic:getAllBuildableRecipes()
        if not registered:contains(recipe) then return nil, "native-build-recipe-not-admitted" end
        -- getAllBuildableRecipes initializes the exact component lookup;
        -- no unrelated player-zero UI recipe-list filter is needed.
        -- Installed BuildLogic.setRecipe writes buildLastRecipe. Preserve that
        -- exact native preference even on failure; this is a requirement probe.
        local modData = body:getModData()
        local previousRecipe = modData.buildLastRecipe
        local bound, bindError = pcall(function() logic:setRecipe(recipe) end)
        modData.buildLastRecipe = previousRecipe
        if not bound then error(bindError) end
        if logic:getSelectedBuildObject() ~= info then return nil, "native-selected-build-object-mismatch" end
        local shape, shapeReason = geometry(info, selected)
        if not shape then return nil, shapeReason end
        local recipePolicy, recipeReason = SAO.RecipePolicy.describe(recipe, body, purpose, workplace)
        if not recipePolicy then return nil, recipeReason end
        local issues = {}
        for _, row in ipairs(recipePolicy.unmet) do issues[#issues + 1] = plain(row) end
        for _, row in ipairs(recipePolicy.requirements.unsupported) do issues[#issues + 1] = plain(row) end
        local menu = {callback = recipe:getOnAddToMenu(), admitted = true}
        if menu.callback and menu.callback ~= "" then
            if menu.callback == "debugTest" then
                menu.admitted = false; issues[#issues + 1] = {reason = "debug-build-policy-refused"}
            else
                if not callback(menu.callback) and type(require) == "function" then
                    pcall(require, "CraftRecipeCode/CraftRecipe_BuildMenu")
                end
                if not callback(menu.callback) then
                    menu.admitted = false; issues[#issues + 1] = {reason = "native-menu-callback-unavailable"}
                else
                    local called, admitted = pcall(BaseCraftingLogic.callLuaBool, menu.callback,
                        {player = body, recipe = recipe, shouldShowAll = false})
                    menu.admitted = called and admitted == true
                    if not menu.admitted then issues[#issues + 1] = {reason = called and "native-menu-refused" or "native-menu-callback-unavailable"} end
                end
            end
        end
        if workplace and workplace.bench then
            local current, why = P.describeWorkplace(workplace.object, body)
            if not current or current.bench ~= workplace.bench or not current.requirements.custody
                or not current.requirements.nativeRangeResult then
                issues[#issues + 1] = {reason = why or "current-workplace-custody-or-native-policy-required"}
            end
        end
        local requirements = {schema = "sao-construction-policy/1", entity = entityId,
            recipe = recipe:getScriptObjectFullType(), nativeVersion = tostring(info:getVersion()),
            modId = entity:getModID(), purpose = plain(recipePolicy.purpose),
            sourceRevision = recipePolicy.purpose.sourceRevision, geometry = shape.requirement, menu = menu,
            recipePolicy = SAO.RecipePolicy.project(recipePolicy),
            effect = sprite:isProp() and "native-moveable-placement" or "native-iso-entity-construction",
            callbacks = {onIsValid = sprite:getOnIsValid(), onCreate = sprite:getOnCreate(),
                timedActionOnIsValid = sprite:getTimedActionOnIsValid(), effect = "unmeasured"},
            acquisitionRequired = true, standingRequired = true, consumerCompletion = "owner-required",
            resultMeasurement = "owner-required", inputSelection = "existing-build-owner-required",
            nativePolicyOnly = true, privatePurposeAdmission = "owner-required", siteAdmission = "owner-required",
            bodyAdmission = "owner-required", observationAdmission = "owner-required", physicalReachAdmission = "owner-required",
            materialsAdmission = "owner-required", queueAdmission = "owner-required", issues = issues}
        return {entity = entity, info = info, recipe = recipe, logic = logic, geometry = shape,
            recipePolicy = recipePolicy, requirements = requirements, body = body,
            admissible = #issues == 0}, issues[1] and issues[1].reason or nil
    end)
    if not ok then return nil, "native-construction-description-unavailable" end
    return policy, reason
end

function P.project(policy)
    return policy and plain(policy.requirements) or nil
end

-- Exact native allocation on this transient initialized BuildLogic. Current
-- registered policy/menu/workplace eligibility is reacquired; admission and
-- effects stay with the private physical work owner.
function P.selectInputs(policy, body, reservationContext, candidateContainers)
    if not policy or body ~= policy.body or not policy.requirements or not policy.logic then
        return nil, {{reason = "current-construction-body-policy-required"}}
    end
    local ok, selection, issues = pcall(function()
        local shape = policy.requirements.geometry
        local current, reason = P.describe(policy.requirements.entity, body, policy.recipePolicy.purpose,
            {face = shape.selectedFace, cursor = shape.cursor}, policy.recipePolicy.workplace)
        if not current then return nil, {{reason = reason}} end
        if not current.admissible then return nil, current.requirements.issues end
        if current.recipe ~= policy.recipe or current.info ~= policy.info
            or current.geometry.face ~= policy.geometry.face then
            return nil, {{reason = "native-construction-selection-changed"}}
        end
        return SAO.RecipePolicy.selectInputs(current.recipePolicy, body, reservationContext,
            candidateContainers, policy.logic)
    end)
    if not ok then return nil, {{reason = "native-construction-input-selection-unavailable", detail = tostring(selection)}} end
    return selection, issues
end

function P.inputEligible(requirement, item, body)
    if not SAO.RecipePolicy then return false, "recipe-policy-required" end
    return SAO.RecipePolicy.inputEligible(requirement, item, body)
end
