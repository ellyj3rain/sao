-- Runs the installed action's constructor, animation selector, update and
-- perform with controlled body/container inputs. The transfer spy measures
-- dispatch; actual item movement remains a loaded-native-run requirement.
function require() end
SAO = { Log = { line = function() end } }
ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name)
    local child = { Type = name }
    setmetatable(child, { __index = self })
    child.__index = child
    return child
end
function ISBaseTimedAction:perform() self.baseCompleted = true end
function ISBaseTimedAction:forceStop() self.stopped = true end
function ISBaseTimedAction:setActionAnim(value) self.animation = value end
function ISBaseTimedAction:new(character)
    local result = { character = character }
    setmetatable(result, self); self.__index = self
    return result
end
function ISBaseTimedAction:setAnimVariable(key, value) self[key] = value end
function ISBaseTimedAction:setOverrideHandModels(first, second)
    self.firstModel, self.secondModel = first, second
end
ISInventoryPage = {}
-- Loading the complete inventory-menu module defines an unused tooltip type.
-- These UI receivers permit that definition; no player panel is supplied.
ISToolTip = ISBaseTimedAction
UIFont = { Small = "Small" }
function getTextManager() return { getFontHeight = function() return 12 end } end
CharacterTrait = { DEXTROUS = 1, ALL_THUMBS = 2, DESENSITIZED = 3,
    COWARDLY = 4, BRAVE = 5, HEMOPHOBIC = 6 }
Metabolics = { LightWork = "LightWork" }
function getTimestampMs() return 1000 end
function getText(value) return value end
function getCore() return { getGameMode = function() return "Sandbox" end } end
function isClient() return false end
function instanceof() return false end
local lookups, faces, transfers = 0, 0, 0
local offSlot, faceAllowed = true, true
function getPlayerLoot(index)
    lookups = lookups + 1
    if index ~= 0 then return nil end
    return { selectButtonForContainer = function() end, setForceSelectedContainer = function() end }
end

-- Full installed ISEatFoodAction and inventory-context helper execute below.
-- Bodies, containers and effect receivers are controlled inputs, not a claim
-- that these fixtures have run native inventory mutation or animation.
function CheckEatUi()
    local checks = 0
    local function check(ok, message)
        assert(ok, "EAT_CHECK:" .. message); checks = checks + 1
    end
    local function list(values)
        local result = { values = values or {} }
        function result:size() return #self.values end
        function result:get(index) return self.values[index + 1] end
        function result:add(value) self.values[#self.values + 1] = value end
        return result
    end
    ArrayList = { new = function() return list() end }
    ItemTag = { SMOKABLE = "smokable", SPOON = "spoon", FORK = "fork" }
    CharacterActionAnims = { Eat = "Eat", Drink = "Drink" }
    function moduleDotType(module, name) return module .. "." .. name end
    function isServer() return false end
    function isDebugEnabled() return false end
    function instanceof(object, kind) return object and object.kind == kind end
    local world, flame, vehicle = {}, nil, nil
    local inventory, carried = {}, {}
    local localPlayer, person
    local queued, acceptQueue, ate, inventoryLookups, lootLookups = nil, true, 0, 0, 0
    local heatLookups, directEats = 0, 0
    local function square(x, y, reachable)
        local result = { x = x, y = y, reachable = reachable, objects = list() }
        function result:getX() return self.x end
        function result:getY() return self.y end
        function result:getZ() return 0 end
        function result:getObjects() return self.objects end
        function result:canReachTo(other) return other.reachable end
        function result:hasAdjacentFireObject() return flame end
        world[x .. "," .. y] = result
        return result
    end
    local current = square(10, 20, true)
    local nearby = square(11, 20, true)
    local cell = { getGridSquare = function(_, x, y, z)
        check(z == 0 and math.abs(x - 10) <= 1 and math.abs(y - 20) <= 1,
            "bounded native heat search")
        return world[x .. "," .. y]
    end }
    function inventory:getParent() return nil end
    function inventory:getFirstTagEvalRecurse() return nil end
    function inventory:getFirstTypeEvalRecurse(fullType, predicate)
        local value = carried[fullType]
        return value and predicate(value) and value or nil
    end
    function inventory:contains(value) return value ~= nil end
    function inventory:setDrawDirty(value) self.dirty = value end
    local emitter = { playSound = function() return 0 end, isPlaying = function() return false end }
    person = {
        getInventory = function() return inventory end,
        getCurrentSquare = function() return current end, getSquare = function() return current end,
        getCell = function() return cell end, getVehicle = function() return vehicle end,
        getPlayerNum = function() return 99 end, isTimedActionInstant = function() return false end,
        getEmitter = function() return emitter end,
        reportEvent = function(self, name) self.event = name end,
        Eat = function(self, value, percentage) ate = ate + 1; self.consumed = value; self.fraction = percentage end,
        getModData = function() return {} end,
    }
    localPlayer = setmetatable({ getPlayerNum = function() return 0 end }, { __index = person })
    function getPlayerInventory(index)
        inventoryLookups = inventoryLookups + 1
        if index ~= 0 then return nil end
        return { inventoryPane = { inventoryPage = { backpacks = { { inventory = inventory } } } } }
    end
    function getPlayerLoot(index)
        lootLookups = lootLookups + 1
        if index ~= 0 then return nil end
        return { inventoryPane = { inventoryPage = { backpacks = {} } } }
    end
    CCampfireSystem = { instance = { getLuaObjectOnSquare = function(_, square)
        heatLookups = heatLookups + 1; return square.campfire
    end } }
    SAOJavaBridge.isShell = function(_, who) return who == person end
    local lighter = { uses = .5 }
    function lighter:getCurrentUsesFloat() return self.uses end
    function lighter:getUseDelta() return .1 end
    function lighter:setUsedDelta(value) self.uses = value end
    local smoke = { kind = "Food", smokable = true, required = list({ "Lighter", "Matches" }) }
    function smoke:getContainer() return inventory end
    function smoke:hasTag(tag) return self.smokable and tag == ItemTag.SMOKABLE end
    function smoke:getEatType() return "cigarette" end
    function smoke:getRequireInHandOrInventory() return self.required end
    function smoke:getModule() return "Base" end
    function smoke:getBaseHunger() return 0 end
    function smoke:getHungerChange() return 0 end
    function smoke:getHungChange() return 0 end
    function smoke:getCustomMenuOption() return nil end
    function smoke:getEatTime() return 0 end
    function smoke:getCustomEatSound() return "" end
    function smoke:setJobType(value) self.jobType = value end
    function smoke:setJobDelta(value) self.delta = value end
    function smoke:getScriptItem() return { getReduceInfectionPower = function() return 1 end } end
    local food = setmetatable({ smokable = false }, { __index = smoke })
    function food:getRequireInHandOrInventory() return nil end
    ISTimedActionQueue = {
        add = function(action) if acceptQueue then queued = action end end,
        hasAction = function(action) return queued == action end,
    }
    SAOJavaBridge.findCarriedSmokable = function() return smoke end
    SAOJavaBridge.findCarriedFood = function() return food end
    SAOJavaBridge.findCarriedDrug = function() return smoke end
    SAOJavaBridge.privateCarriedItems = function() return list({ smoke }) end
    SAOJavaBridge.engineEat = function() directEats = directEats + 1; return true end
    local originalContainers = ISInventoryPaneContextMenu.getContainers

    carried["Base.Lighter"] = lighter
    check(SAO.Needs.smokeCarried("p1", person), "carried ignition queues smoke")
    local action = queued
    check(action.item == smoke and action:getRequiredItem() == lighter and not action.openFlame,
        "native constructor retains carried ignition")
    check(inventoryLookups == 0 and lootLookups == 0 and person:getInventory() == inventory,
        "NPC construction touches no player UI or replacement inventory")
    check(ISInventoryPaneContextMenu.getContainers == originalContainers, "helper restored after success")
    action:start(); action:complete(); action:perform()
    check(math.abs(lighter.uses - .4) < .00001 and ate == 1 and person.consumed == smoke
        and person.fraction == 1 and action.baseCompleted and person.event == "EventEating",
        "native start fuel and complete consumption retained")
    check(action.secondModel == smoke and action.animation == "Eat" and smoke.delta == 0,
        "native models animation and completion retained")

    carried["Base.Lighter"] = nil; queued = nil
    check(not SAO.Needs.smokeCarried("p1", person) and queued == nil, "missing ignition refuses smoke")
    carried["Base.Matches"] = lighter; lighter.uses = 0
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "empty carried ignition refused")
    carried["Base.Matches"] = nil
    -- Nearby items never become the character's required-item inventory.
    local holder = { getParent = function() return nil end,
        getFirstTypeEvalRecurse = function() return lighter end }
    local neighbor = { getContainerCount = function() return 1 end,
        getContainerByIndex = function() return holder end }
    nearby.objects:add(neighbor)
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "neighbor inventory cannot supply ignition")
    neighbor.kind = "IsoThumpable"; neighbor.isLockedToCharacter = function() return true end
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "locked neighbor cannot supply ignition")
    nearby.objects = list()

    local hearth = { kind = "IsoFireplace", lit = true }
    local hearthContainer = { getParent = function() return hearth end }
    function hearth:getSquare() return nearby end
    function hearth:isLit() return self.lit end
    function hearth:getContainerCount() return 1 end
    function hearth:getContainerByIndex() return hearthContainer end
    nearby.objects:add(hearth)
    action = ISEatFoodAction:new(person, smoke, 1)
    check(action and action.openFlame == hearth and heatLookups > 0, "actual reachable fireplace retained")
    action:start(); action:complete()
    check(ate == 2 and lighter.uses == 0, "world heat consumes no invented lighter")
    hearth.lit = false
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "unlit world source refused")
    hearth.lit = true; nearby.reachable = false
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "blocked world heat refused")
    nearby.reachable = true; hearth.kind = "IsoBarbecue"
    check(ISEatFoodAction:new(person, smoke, 1).openFlame == hearth, "native barbecue retained")
    hearth.kind = "IsoStove"
    function hearth:Activated() return self.lit end
    function hearth:isMicrowave() return self.microwave end
    function hearth:getProperties() return { get = function() return self.group end } end
    check(ISEatFoodAction:new(person, smoke, 1).openFlame == hearth, "native active stove retained")
    hearth.microwave = true
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "native microwave exclusion retained")
    hearth.microwave = false; hearth.group = "Coffee"
    check(ISEatFoodAction:new(person, smoke, 1) == nil, "native appliance exclusion retained")
    hearth.kind = "IsoObject"; nearby.campfire = { isLit = true }
    check(ISEatFoodAction:new(person, smoke, 1).openFlame == hearth, "native lit campfire retained")
    nearby.campfire = nil; nearby.objects = list(); flame = hearth
    check(ISEatFoodAction:new(person, smoke, 1).openFlame == hearth, "native adjacent fire retained")
    flame = nil; vehicle = { canLightSmoke = function(_, who) return who == person end }
    check(ISEatFoodAction:new(person, smoke, 1).carLighter == true, "native vehicle ignition retained")
    vehicle = nil

    lighter.uses = .5; carried["Base.Lighter"] = lighter
    check(SAO.Needs.eatCarried("p1", person) and queued.item == food, "ordinary carried food constructor")
    check(SAO.Needs.takePills("p1", person) and queued.item == smoke, "medicine constructor uses shell boundary")
    check(SAO.Needs.useCarriedDrug("p1", person, "fixture") and queued.item == smoke,
        "drug constructor uses shell boundary")
    check(ISEatFoodAction:new(person, smoke, 1).item == smoke, "direct exact-source constructor boundary")
    carried["Base.Lighter"] = nil
    SAOJavaBridge.findCarriedFood = function() return smoke end
    check(not SAO.Needs.eatCarried("p1", person) and directEats == 0,
        "construction refusal precedes direct eating fallback")
    carried["Base.Lighter"] = lighter; queued = nil; acceptQueue = false
    check(not SAO.Needs.smokeCarried("p1", person), "queue rejection remains refusal")
    acceptQueue = true

    local oldEatType = smoke.getEatType
    smoke.getEatType = function() error("fixture constructor failure") end
    local ok, message = pcall(function() return ISEatFoodAction:new(person, smoke, 1) end)
    check(not ok and tostring(message):find("fixture constructor failure", 1, true), "constructor error preserved")
    check(ISInventoryPaneContextMenu.getContainers == originalContainers, "helper restored after failure")
    smoke.getEatType = oldEatType
    local nested = false
    smoke.getEatType = function(self)
        if not nested then
            nested = true
            check(ISEatFoodAction:new(person, food, 1).item == food, "nested NPC constructor retained")
            check(ISEatFoodAction:new(localPlayer, smoke, 1).item == smoke, "nested player constructor retained")
        end
        return oldEatType(self)
    end
    check(ISEatFoodAction:new(person, smoke, 1).item == smoke, "outer constructor survives nested calls")
    smoke.getEatType = oldEatType
    check(ISInventoryPaneContextMenu.getContainers == originalContainers, "nested helper scopes restored")
    check(inventoryLookups == 1 and lootLookups == 1, "ordinary player keeps native UI lookup")
    local before = inventoryLookups
    check(ISEatFoodAction:new(localPlayer, smoke, 1).item == smoke and inventoryLookups == before + 1,
        "normal player constructor unchanged")
    return "PASS installed eat action and flame helpers: " .. checks .. " assertions"
end

-- The separate native runner supplies actual installed item definitions,
-- inventory, body, script callbacks and item effects. Only the timed-action
-- queue/animation receiver and Habits observer are controlled here.
function CheckNativeEat()
    print = __nativePrint
    local checks, stamps, queued = 0, 0, nil
    local function check(value, name)
        print("NATIVE_EAT_CHECK " .. name .. "=" .. tostring(value))
        assert(value, "NATIVE_EAT_CHECK:" .. name); checks = checks + 1
    end
    SAOJavaBridge = __realBridge
    instanceof = __nativeInstanceof
    moduleDotType = __nativeModuleDotType
    ArrayList = __nativeArrays
    ItemTag = __nativeItemTag
    local Stat = __nativeCharacterStat
    CharacterActionAnims = { Eat = "Eat", Drink = "Drink", TakePills = "TakePills" }
    function isServer() return false end
    function isDebugEnabled() return false end
    -- The off-slot body has no local-player inventory window.
    function getPlayerInventory() return nil end
    CCampfireSystem = { instance = { getLuaObjectOnSquare = function() return nil end } }
    ISTimedActionQueue = {
        add = function(action) queued = action end,
        hasAction = function(action) return queued == action end,
    }
    local body, pack, single, matches, pills = __realBody, __pack, __single, __matches, __pills
    body:getModData().SAOPersonId = "native-eat-person"
    SAO.Habits = { used = function(id, family)
        check(id == "native-eat-person" and family ~= "", "native habit identity")
        stamps = stamps + 1; return true
    end }
    local originalContainers = ISInventoryPaneContextMenu.getContainers
    check(SAOJavaBridge:isShell(body), "actual off-slot shell")
    check(instanceof(pack, "DrainableComboItem") and not instanceof(pack, "Food"), "actual pack has no Food receiver")
    check(instanceof(single, "Food"), "actual single is Food")
    check(SAOJavaBridge:findCarriedSmokable(body) == pack, "native private carried selection")
    local constructed, direct = pcall(function() return ISEatFoodAction:new(body, pack, 1) end)
    if not constructed then print("NATIVE_CONSTRUCTOR_ERROR " .. tostring(direct)) end
    check(constructed and direct ~= nil, "native direct pack constructor admitted")
    check(SAO.Needs.smokeCarried("native-eat-person", body), "actual pack queued by production")
    local action = queued
    check(action.Type == "ISTakePillAction" and action.item == pack and action.maxTime == pack:getEatTime(),
        "pack uses native drainable constructor and duration")
    check(action:getRequiredItem() == matches and not action.openFlame, "pack keeps actual carried matches")
    check(ISInventoryPaneContextMenu.getContainers == originalContainers, "native pack helper restored")
    local fuel, uses = matches:getCurrentUsesFloat(), pack:getCurrentUsesFloat()
    body:getStats():set(Stat.HUNGER, .5)
    action:start()
    check(math.abs(matches:getCurrentUsesFloat() - (fuel - matches:getUseDelta())) < .00001,
        "native pack start consumes carried ignition")
    -- IsoGameCharacter.updateInternal calls perform before complete. Habits
    -- keeps its existing perform-stage stamp; it is not completion evidence.
    action:perform()
    check(action.baseCompleted and stamps == 0, "native pack perform preserves unclassified habit")
    check(math.abs(body:getStats():get(Stat.HUNGER) - .5) < .00001, "pack perform does not apply consumption effects")
    check(action:complete() == true, "native pack complete")
    check(math.abs(body:getStats():get(Stat.HUNGER) - .47) < .00001, "native nicotine OnEat hunger effect")
    check(math.abs(pack:getCurrentUsesFloat() - (uses - pack:getUseDelta())) < .00001,
        "native pack completion consumes one dose")

    action = ISEatFoodAction:new(body, single, 1)
    check(action.Type == "ISEatFoodAction" and action.item == single, "Food cigarette retains Food action")
    fuel = matches:getCurrentUsesFloat()
    action:start()
    check(math.abs(matches:getCurrentUsesFloat() - (fuel - matches:getUseDelta())) < .00001,
        "native Food start consumes carried ignition")
    action:perform()
    check(action.baseCompleted and stamps == 0, "native Food perform preserves unclassified habit")
    check(action:complete() == true and not body:getInventory():contains(single), "native Food completion consumes item")

    action = ISEatFoodAction:new(body, pills, 1)
    check(action.Type == "ISTakePillAction" and action.item == pills, "native medicine keeps drainable action")
    body:getStats():set(Stat.INTOXICATION, 0)
    body:setPainEffect(0); body:setPainDelta(0)
    uses = pills:getCurrentUsesFloat(); action:start(); action:perform()
    check(body:getPainEffect() == 0 and body:getPainDelta() == 0, "medicine perform does not apply native effects")
    check(action:complete() == true and math.abs(pills:getCurrentUsesFloat() - (uses - pills:getUseDelta())) < .00001,
        "native medicine completion consumes one dose")
    check(body:getPainEffect() == 5400 and math.abs(body:getPainDelta() - .45) < .00001,
        "native medicine pain effect retained")
    check(action.baseCompleted, "native medicine perform retained")
    body:getInventory():Remove(matches)
    check(ISEatFoodAction:new(body, pack, 1) == nil, "native pack missing ignition refuses")
    check(ISInventoryPaneContextMenu.getContainers == originalContainers, "native refusal helper restored")
    body:getInventory():AddItem(matches)
    -- An explicitly controlled family selector checks the existing Habits
    -- forwarding for both actions without relabelling native tobacco scripts.
    local function classifiedPerform(value, expected)
        local nativeBridge, before = SAOJavaBridge, stamps
        SAOJavaBridge = { drugFamilyOf = function(_, item)
            check(item == expected, "perform keeps classified item identity")
            return "fixture-family"
        end }
        value:perform()
        SAOJavaBridge = nativeBridge
        check(value.baseCompleted and stamps == before + 1, "classified " .. value.Type .. " perform forwarded")
    end
    pack:setUsedDelta(pack:getUseDelta())
    action = ISEatFoodAction:new(body, pack, 1); action:start()
    classifiedPerform(action, pack)
    check(body:getInventory():contains(pack), "last-dose pack still owned at perform")
    check(action:complete() == true and not body:getInventory():contains(pack), "last-dose pack removed at native complete")
    action = ISEatFoodAction:new(body, __receiptSingle, 1); action:start()
    classifiedPerform(action, __receiptSingle)
    check(body:getInventory():contains(__receiptSingle), "classified Food still owned at perform")
    check(action:complete() == true and not body:getInventory():contains(__receiptSingle), "classified Food native completion retained")
    return "PASS real installed consume receivers: " .. checks .. " checks"
end
SAOJavaBridge = {
    isShell = function() return offSlot end,
    containerAccessibleNow = function() return true end,
    faceTransferContainer = function(_, body, container)
        if faceAllowed then faces = faces + 1 end
        return faceAllowed
    end,
}
local source, destination, item
local body = {
    getInventory = function() return destination end,
    hasTrait = function() return false end,
    isWearingAwkwardGloves = function() return false end,
    isTimedActionInstant = function() return false end,
    getPlayerNum = function() return offSlot and 99 or 0 end,
    isSittingOnFurniture = function() return false end,
    faceThisObject = function() faces = faces + 1 end,
    shouldBeTurning = function() return false end,
    setMetabolicTarget = function() end,
}
item = {
    getActualWeight = function() return 1 end, isFavorite = function() return false end,
    getFullType = function() return "Fixture.Tool" end, getName = function() return "Tool" end,
    setJobType = function(self, value) self.jobType = value end,
    getJobType = function(self) return self.jobType end,
    setJobDelta = function(self, value) self.delta = value end,
}
source = {
    isInCharacterInventory = function() return false end,
    getType = function() return "counter" end, getParent = function() return {} end,
    isVehicleSeat = function() return false end, contains = function() return true end,
}
destination = {
    isInCharacterInventory = function() return true end, getType = function() return "inventory" end,
    isVehicleSeat = function() return false end,
}
function CheckTransferUi()
    local function action()
        local a = SAO.Needs.worldSourceTransferAction(body, item, source, source)
        a.action = { getJobDelta = function() return .5 end, stopTimedActionAnim = function() end,
                     setLoopedAction = function() end }
        a.doActionAnim = function(self, container) self.animContainer = container end
        a.checkQueueList = function() end
        a.isValid = function() return true end
        a.transferItem = function() transfers = transfers + 1 end
        a.playTransferCompleteSound = function() end
        a.playSourceContainerCloseSound = function() end
        a.playDestContainerCloseSound = function() end
        a.stopLoopingSound = function() end
        a:startActionAnim()
        return a
    end
    local a = action()
    assert(a.saoFacingContainer == source and a.animContainer == source,
        "NPC transfer lost native animation or source-facing identity")
    a:update()
    a:perform()
    assert(lookups == 0, "NPC transfer touched a player loot panel")
    assert(faces == 1 and item.delta == 0 and a.baseCompleted and transfers == 1,
        "NPC transfer lost facing, progress or native completion dispatch")

    faceAllowed = false
    a = action()
    a:update()
    assert(a.stopped, "failed facing continued an NPC transfer")
    faceAllowed = true
    offSlot = false
    a = action()
    assert(a.selectedContainer == source, "ordinary player's selected container was erased")
    a:update()
    a:perform()
    assert(lookups == 2 and transfers == 2 and a.baseCompleted,
        "ordinary player loot interaction changed")
    return "PASS installed transfer action keeps NPC facing and completion without a player loot panel"
end

function CheckCollectApproach()
    local failure = nil
    local function check(value, message)
        if not value and not failure then failure = message or "collection assertion failed" end
    end
    local orders, approaches, takes = 0, 0, 0
    local permitted, within = true, false
    local routeAllowed, routeEvidence = true, { sourceRevision = 3 }
    local target = "AT:11:20:0"
    SAO.Needs.findSource = function() return 12, 20, 0, "cabinet food" end
    SAOJavaBridge.foodSourceWithinReach = function() return within end
    SAOJavaBridge.resourceApproach = function(_, requestedBody, kind, x, y, z)
        approaches = approaches + 1
        check(requestedBody == body and kind == "food" and x == 12 and y == 20 and z == 0,
            "collection changed the original source identity")
        return target
    end
    SAO.Standing = { mayAttemptBelieved = function(id, x, y, admission)
        check(id == "p1" and x == 12 and y == 20 and admission == "standing",
            "collection permission moved from the source to its approach")
        return permitted
    end }
    SAO.Locomotion = { order = function(id, requestedBody, x, y, z)
        orders = orders + 1
        check(id == "p1" and requestedBody == body and x == 11 and y == 20 and z == 0,
            "collection ordered the occupied source tile")
        return true
    end }
    SAO.Controller = { coordinationRouteAllowed = function(id, requestedBody, commitment, x, y, z, phase, sx, sy, sz)
        check(id == "p1" and requestedBody == body and commitment == "commitment:1"
            and x == 11 and y == 20 and z == 0 and phase == "acquiring"
            and sx == 12 and sy == 20 and sz == 0, "commitment reappraisal lost source or approach identity")
        return routeAllowed, "route-backoff", routeEvidence
    end }
    local context = { purpose = "accepted-request", matterId = "matter:1",
        commitmentId = "commitment:1", haulRemaining = 2 }
    local state, returned = SAO.Needs.collectNearby("p1", body, 20, 2, context)
    check(state == "FORAGE" and returned == context and context.matterId == "matter:1"
        and context.commitmentId == "commitment:1" and context.haulRemaining == 2
        and orders == 1 and approaches == 1, "accepted work lost its continuation")
    check(context.routeEvidence == routeEvidence, "accepted route lost private evidence")
    routeAllowed = false
    state, returned = SAO.Needs.collectNearby("p1", body, 20, 2, context)
    check(state == nil and returned == context and context.routeRefusal == "route-backoff"
        and orders == 1, "commitment retry guard was bypassed")
    routeAllowed = true
    state = SAO.Needs.collectNearby("p1", body, 4, 2)
    check(state == "FORAGE" and orders == 2, "hauling continuation did not approach its source")
    target = "UNAVAILABLE"
    check(SAO.Needs.collectNearby("p1", body, 4, 2, context) == nil and orders == 2,
        "unavailable source manufactured a collection route")
    permitted = false
    local before = approaches
    check(SAO.Needs.collectNearby("p1", body, 4, 2, context) == nil
        and approaches == before and orders == 2, "unadmitted source was approached")
    permitted, within = true, true
    SAO.Needs.queueTake = function(id, requestedBody, received)
        check(id == "p1" and requestedBody == body and received == context)
        takes = takes + 1
        return true
    end
    state, returned = SAO.Needs.collectNearby("p1", body, 4, 2, context)
    check(state == "TAKE" and returned == context and takes == 1 and orders == 2,
        "source within reach did not retain the exact transfer owner")
    if failure then return "FAIL " .. failure end
    return "PASS accepted work and hauling preserve permission, reachable approach and exact transfer ownership"
end
