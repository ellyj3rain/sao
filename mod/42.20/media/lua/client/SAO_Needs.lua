-- SAO_Needs - the body keeps score (ARCHITECTURE: needs feed decisions).
-- ---------------------------------------------------------------------------
-- Hunger is the first need with teeth. The values are the engine's own stats
-- (read Java-side); the satisfying of them goes through the game's OWN timed
-- actions - ISEatFoodAction and ISInventoryTransferAction - so a survivor
-- eating is animated, audible, takes real time, and can be interrupted, the
-- same as it is for the player. Nothing here teleports a number.
--
-- Interop law: engine objects returned by the bridge (items, containers) are
-- held as opaque values and passed straight into vanilla constructors. They
-- are never indexed, never iterated, never interrogated from Lua.

SAO = SAO or {}
SAO.Needs = SAO.Needs or {}
local N = SAO.Needs

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("NEED", msg) end

-- [B34] Queue an action, and answer whether the queue actually took
-- it.
--
-- ISTimedActionQueue.add RETURNS - it does not throw - on three
-- paths: the action carries ignoreAction, the character is asleep, or
-- a local player is dragging a corpse. Our shells sit inside that
-- last gate rather than outside it, because SAOIsoPlayerShell
-- overrides isLocalPlayer() to true.
--
-- pcall sees only throws. So every caller that read `okQ` as "queued"
-- was reporting success for work that never happened, and the
-- survivor stood in the state it set until the task deadline ran out.
-- hasAction asks the queue itself, which is the only thing that
-- knows.
--
-- One helper rather than a copy per site: [B34] wrote the check
-- twice and a third and fourth copy is exactly what border 14 exists
-- to refuse.
function N.queueVerified(action)
    if action == nil then return false end
    local okQ = pcall(function() ISTimedActionQueue.add(action) end)
    if not okQ then return false end
    local okH, has = pcall(function()
        return ISTimedActionQueue.hasAction(action)
    end)
    return okH and has == true
end

-- Parse the bridge's compact needs string into a plain Lua table.
function N.read(body)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function() return SAOJavaBridge:getNeeds(body) end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local out = {}
    for key, value in string.gmatch(s, "(%a)=([%d%.%-]+)") do
        out[key] = tonumber(value)
    end
    if out.h == nil then return nil end
    return { hunger = out.h, thirst = out.t or 0,
             fatigue = out.f or 0, endurance = out.e or 0,
             nicotine = out.n or 0 }
end

-- Queue eating the best carried food through the vanilla action. Returns true
-- when an action was queued (or the engine fallback ate directly).
function N.eatCarried(id, body)
    if not SAOJavaBridge then return false end
    local okF, item = pcall(function() return SAOJavaBridge:findCarriedFood(body) end)
    if not okF or item == nil then return false end
    local queued = N.queueVerified(ISEatFoodAction:new(body, item, 1))
    if queued then
        log(id .. " begins eating (vanilla action)")
        return true
    end
    -- [B34] Reachable at last. The queue never "refused" - it
    -- accepted the action and dropped it, and pcall could not tell
    -- the difference, so this branch sat here unreachable for the
    -- project's life. The engine's own Eat call is the same semantics
    -- vanilla runs at complete(), minus the animation: a survivor who
    -- was asleep when hunger bit still eats.
    local okE, ate = pcall(function() return SAOJavaBridge:engineEat(body, item) end)
    if okE and ate then
        log(id .. " ate directly (queue path unavailable)")
        return true
    end
    return false
end

-- Ask the world for a food source near the body. Returns x, y, z, name or nil.
function N.findSource(id, body, radius)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:findFoodSource(body, radius or 12)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, name = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+):(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), name
end

-- Queue taking the remembered source item through the vanilla transfer
-- action (into the body's own inventory). Java revalidates the source.
function N.queueTake(id, body)
    if not SAOJavaBridge then return false end
    local okR, within = pcall(function()
        return SAOJavaBridge:foodSourceWithinReach(body)
    end)
    if not okR or not within then return false end
    local okI, item = pcall(function() return SAOJavaBridge:foodSourceItem(body) end)
    local okC, container = pcall(function() return SAOJavaBridge:foodSourceContainer(body) end)
    if not (okI and okC) or item == nil or container == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(body, item, container, body:getInventory()))
    end)
    if okQ then
        log(id .. " takes food from a container (vanilla transfer)")
    end
    return okQ
end

-- Queue drinking the best carried drinkable through the vanilla action.
function N.drinkCarried(id, body)
    if not SAOJavaBridge then return false end
    local ok, item = pcall(function() return SAOJavaBridge:findCarriedDrink(body) end)
    if not ok or item == nil then return false end
    -- [B34] The same silent drop as eating. There is no engineDrink
    -- to fall back to, so this reports the truth instead: saying no
    -- lets the controller move on to the water branch in the same
    -- tick, and that branch changes state - which stands the sleeper
    -- up. Claiming yes parked them in DRINK for a whole task deadline
    -- with nothing queued and nothing drunk.
    local queued = N.queueVerified(
        ISDrinkFluidAction:new(body, item, 0.5))
    if queued then log(id .. " drinks from their pack") end
    return queued
end

-- Ask the world for clean water near the body. Returns x, y, z or nil.
function N.findWater(id, body, radius)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:findWaterSource(body, radius or 12)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z)
end

-- Drink directly from the remembered water object (vanilla item=nil form -
-- the engine sizes the drink by this character's own thirst).
function N.queueDrinkFrom(id, body)
    if not SAOJavaBridge then return false end
    local okR, within = pcall(function()
        return SAOJavaBridge:waterSourceWithinReach(body)
    end)
    if not okR or not within then return false end
    local okO, waterObject = pcall(function()
        return SAOJavaBridge:waterSourceObject(body)
    end)
    if not okO or waterObject == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISTakeWaterAction:new(body, nil, waterObject, nil))
    end)
    if okQ then log(id .. " drinks from a water source") end
    return okQ
end

-- Ask the world for a clearly better melee weapon nearby.
function N.findGear(id, body, radius)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:findWeaponUpgrade(body, radius or 12)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, name = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+):(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), name
end

-- Queue taking the remembered weapon through the vanilla transfer.
function N.queueTakeGear(id, body)
    if not SAOJavaBridge then return false end
    local okR, within = pcall(function()
        return SAOJavaBridge:weaponSourceWithinReach(body)
    end)
    if not okR or not within then return false end
    local okI, item = pcall(function() return SAOJavaBridge:weaponSourceItem(body) end)
    local okC, container = pcall(function() return SAOJavaBridge:weaponSourceContainer(body) end)
    if not (okI and okC) or item == nil or container == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(body, item, container, body:getInventory()))
    end)
    if okQ then log(id .. " takes a better weapon from a container") end
    return okQ
end

-- How many wounds are bleeding right now (0 when the bridge is absent).
function N.bleeding(body)
    local ok, n = pcall(function() return SAOJavaBridge:getBleedingCount(body) end)
    return ok and tonumber(n) or 0
end

-- Queue self-bandaging the worst bleeding part with the best carried
-- bandage, through the vanilla action (animated, timed, interruptible).
function N.bandageSelf(id, body)
    if not SAOJavaBridge then return false end
    local okP, part = pcall(function() return SAOJavaBridge:bleedingBodyPart(body) end)
    if not okP or part == nil then return false end
    local okB, item = pcall(function() return SAOJavaBridge:findBandage(body) end)
    if not okB or item == nil then return false end
    -- [B34] The bleeding branch that calls this is not gated on
    -- state, so it fires on a sleeping survivor - which is exactly
    -- when a survivor starts bleeding, because something found them
    -- asleep. A dropped bandage was reported as a bandage applied.
    local queued = N.queueVerified(
        ISApplyBandage:new(body, body, item, part, true))
    if queued then log(id .. " bandages a wound") end
    return queued
end

-- Hand a spare piece of food to a fellow, through the vanilla transfer
-- between the two inventories. Giver must have a spare (second-best);
-- adjacency is the caller's concern (talking distance already applies).
function N.shareFoodWith(id, body, fellowBody)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function() return SAOJavaBridge:findSpareFood(body) end)
    if not okS or item == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, item, body:getInventory(), fellowBody:getInventory()))
    end)
    if okQ then log(id .. " shares food with a fellow") end
    return okQ
end

-- [B22] The book goes round. The same vanilla transfer every other
-- kindness in this mod uses - nothing special, which is the point: a
-- retired clerk handing over a paperback is worth something to a
-- house in a way that has nothing to do with what they did for money.
function N.passReadingTo(id, body, otherBody)
    if not (SAOJavaBridge and otherBody) then return false end
    local book = nil
    pcall(function()
        local items = body:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local okD, cat = pcall(function()
                return it:getDisplayCategory()
            end)
            if okD and cat == "Literature" then
                book = it
                break
            end
        end
    end)
    if not book then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, book, body:getInventory(), otherBody:getInventory()))
    end)
    return okQ
end

-- [B20] Aid is TREATMENT, not delivery. [A19] set the doctrine as
-- "a spare bandage crosses through the vanilla transfer; the
-- wounded's own TREAT binds it" - which threw away the only thing
-- that makes a medic a medic. Vanilla's own action takes a doctor
-- and a patient as separate arguments and reads
-- `character:getPerkLevel(Perks.Doctor)` to set how long the
-- dressing holds. A Doctor-8 medic handing a bandage to a frightened
-- clerk produced a clerk's dressing.
--
-- Returns "treated", "gave", or false, because the two are different
-- acts and the callers should be able to say which happened.
function N.aidWound(id, body, patientBody)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function()
        return SAOJavaBridge:findSpareBandage(body)
    end)
    if not okS or item == nil then return false end
    -- The worst open wound first: bleeding, and not already dressed.
    local part = nil
    pcall(function()
        local parts = patientBody:getBodyDamage():getBodyParts()
        local worst = -1
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            if bp:bleeding() and not bp:bandaged() then
                local bt = bp:getBleedingTime() or 0
                if bt > worst then worst, part = bt, bp end
            end
        end
    end)
    if part then
        local okT = pcall(function()
            ISTimedActionQueue.add(ISApplyBandage:new(
                body, patientBody, item, part, true))
        end)
        if okT then
            log(id .. " treats a wound - their own hands, their own"
                .. " skill")
            return "treated"
        end
        return false
    end
    -- Nothing to treat, but a dressing they will need is still a
    -- kindness - just not a medical act. The old behaviour, kept
    -- honestly and named for what it is.
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, item, body:getInventory(), patientBody:getInventory()))
    end)
    if okQ then
        log(id .. " hands over a bandage - nothing open to dress")
        return "gave"
    end
    return false
end

-- The quartermaster's deposit ([A19]): a SPARE food item moves from
-- the pack into the nearest real container, through the vanilla
-- transfer. Returns false when there is nothing spare or nothing to
-- put it in.
-- Water is shelved like bread ([B6]): the fullest vessel stays with
-- the carrier (they drink too - the spareFood law, water-shaped);
-- everything else goes on the shelf through the vanilla transfer.
local function carriedVessels(body)
    local out = {}
    pcall(function()
        local items = body:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local okC, fc = pcall(function()
                return it:getFluidContainerFromSelfOrWorldItem()
            end)
            if okC and fc then
                local okA, amt = pcall(function() return fc:getAmount() end)
                if okA and amt and amt > 0.01 then
                    out[#out + 1] = { item = it, amount = amt }
                end
            end
        end
    end)
    table.sort(out, function(a, b) return a.amount > b.amount end)
    return out
end

-- The state you're in ([B9]): what a person brings to a meeting
-- besides themselves. Returns { drunk, pain, stress, anger, morale }
-- or nil - all 0..1 engine stats.
function N.temper(body)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:socialState(body)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local out = {}
    for key, value in string.gmatch(s, "(%a)=([%d%.%-]+)") do
        out[key] = tonumber(value)
    end
    if out.i == nil then return nil end
    return { drunk = out.i or 0, pain = out.p or 0,
             stress = out.s or 0, anger = out.a or 0,
             morale = out.m or 0 }
end

-- Pills ([B7]): the engine's own medicine test - an item that
-- reduces a cold when eaten. Vanilla marks these with the
-- ReduceInfectionPower / cold-reduction properties; the honest read
-- is the item's own script flag, tried in order and guarded.
function N.takePills(id, body)
    local pill = nil
    pcall(function()
        local items = body:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local okS, script = pcall(function()
                return it:getScriptItem()
            end)
            if okS and script then
                local okR, reduce = pcall(function()
                    return script:getReduceInfectionPower()
                end)
                if okR and reduce and reduce > 0 then
                    pill = it
                    break
                end
            end
        end
    end)
    if not pill then return false end
    -- [B34] Same shape as bandaging: the sickness branch does not
    -- gate on state either.
    local queued = N.queueVerified(ISEatFoodAction:new(body, pill, 1))
    if queued then log(id .. " takes something for the sickness") end
    return queued
end

-- The wound gone bad ([B7]): real engine state, read never guessed.
function N.woundInfection(body)
    if not SAOJavaBridge then return 0 end
    local ok, v = pcall(function()
        return SAOJavaBridge:woundInfection(body)
    end)
    return (ok and type(v) == "number") and v or 0
end

function N.dirtyBandages(body)
    if not SAOJavaBridge then return 0 end
    local ok, v = pcall(function()
        return SAOJavaBridge:dirtyBandages(body)
    end)
    return (ok and type(v) == "number") and v or 0
end

-- Clean your own worst wound with what you actually carry.
function N.disinfectSelf(id, body)
    if not SAOJavaBridge then return false end
    local ok, part = pcall(function()
        return SAOJavaBridge:disinfectFromPack(body)
    end)
    if ok and type(part) == "string" and part ~= "" then
        log(id .. " cleans the wound on their " .. part:lower())
        return true
    end
    return false
end

-- The medicine changes hands ([B7]): a carer gives what they carry -
-- the same shape as handing over a bandage. Real item, real transfer.
function N.shareDisinfectantWith(id, body, otherBody)
    local gift = nil
    pcall(function()
        local items = body:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local okA, power = pcall(function()
                return it:getAlcoholPower()
            end)
            if okA and power and power > 0 then
                gift = it
                break
            end
        end
    end)
    if not gift then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, gift, body:getInventory(), otherBody:getInventory()))
    end)
    if okQ then log(id .. " hands over what cleans a wound") end
    return okQ
end

-- Does this person carry something that actually gives light
-- ([B17])? The engine's own strength value decides - no torch table.
function N.hasLight(body)
    local found = false
    pcall(function()
        local items = body:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local okL, strength = pcall(function()
                return items:get(i):getLightStrength()
            end)
            if okL and strength and strength > 0 then
                found = true
                break
            end
        end
    end)
    return found
end

-- Cold is a real state ([B6]), read from the engine's own body.
function N.cold(body)
    if not SAOJavaBridge then return 0 end
    local ok, c = pcall(function()
        return SAOJavaBridge:coldStrength(body)
    end)
    return (ok and type(c) == "number") and c or 0
end

-- The nearest hearth with fuel: x, y, z, fuel - or nil ([B6]).
function N.findHearth(id, body, radius)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:hearthNear(body, radius or 12)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, fuel, lit =
        s:match("^(-?%d+):(-?%d+):(-?%d+):(%d+):(%d)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), tonumber(fuel),
        lit == "1"
end

function N.depositWater(id, body)
    if not SAOJavaBridge then return false end
    local vessels = carriedVessels(body)
    if #vessels < 2 then return false end
    local okC, container = pcall(function()
        return SAOJavaBridge:findNearbyContainer(body, 5)
    end)
    if not okC or container == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, vessels[2].item, body:getInventory(), container))
    end)
    if okQ then log(id .. " shelves the water") end
    return okQ
end

-- Drawing from the house's own stored water ([B6]): a thirsty member
-- whose vessels are dry takes a filled one off the shelf. The take
-- is a real transfer of a real vessel - nothing conjured.
function N.takeStoredWater(id, body)
    if not SAOJavaBridge then return false end
    if #carriedVessels(body) > 0 then return false end
    local okC, container = pcall(function()
        return SAOJavaBridge:findNearbyContainer(body, 5)
    end)
    if not okC or container == nil then return false end
    local found = nil
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local okF, fc = pcall(function()
                return it:getFluidContainerFromSelfOrWorldItem()
            end)
            if okF and fc then
                local okA, amt = pcall(function() return fc:getAmount() end)
                if okA and amt and amt > 0.01 then
                    found = it
                    break
                end
            end
        end
    end)
    if not found then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, found, container, body:getInventory()))
    end)
    if okQ then log(id .. " draws water from the house's stores") end
    return okQ
end

function N.depositSpareFood(id, body)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function() return SAOJavaBridge:findSpareFood(body) end)
    if not okS or item == nil then return false end
    local okC, container = pcall(function()
        return SAOJavaBridge:findNearbyContainer(body, 5)
    end)
    if not okC or container == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, item, body:getInventory(), container))
    end)
    if okQ then log(id .. " stocks the stores") end
    return okQ
end

-- Queue reloading the equipped gun through the vanilla action (sources
-- magazines/rounds from the inventory itself; anim controls the time).
function N.queueReload(id, body)
    local okW, gun = pcall(function() return body:getPrimaryHandItem() end)
    if not okW or gun == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISReloadWeaponAction:new(body, gun))
    end)
    if okQ then log(id .. " reloads") end
    return okQ
end

-- Dry firearm with nothing loadable carried?
function N.needsAmmo(body)
    local ok, v = pcall(function() return SAOJavaBridge:needsAmmo(body) end)
    return ok and v == true
end

function N.findAmmo(id, body, radius)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:findAmmoSource(body, radius or 12)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, name = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+):(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), name
end

function N.queueTakeAmmo(id, body)
    if not SAOJavaBridge then return false end
    local okR, within = pcall(function()
        return SAOJavaBridge:ammoSourceWithinReach(body)
    end)
    if not okR or not within then return false end
    local okI, item = pcall(function() return SAOJavaBridge:ammoSourceItem(body) end)
    local okC, container = pcall(function() return SAOJavaBridge:ammoSourceContainer(body) end)
    if not (okI and okC) or item == nil or container == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(body, item, container, body:getInventory()))
    end)
    if okQ then log(id .. " takes ammunition from a container") end
    return okQ
end

function N.clearAmmo(body)
    pcall(function() SAOJavaBridge:clearAmmoSource(body) end)
end

-- Notice a useful item on the ground within reach. Returns its name or nil.
function N.findOffered(id, body)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function() return SAOJavaBridge:findOfferedItem(body) end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    return s
end

-- Take the noticed ground item through the vanilla grab action.
function N.queueGrabOffered(id, body)
    if not SAOJavaBridge then return false end
    local okI, worldItem = pcall(function() return SAOJavaBridge:offeredWorldItem(body) end)
    if not okI or worldItem == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISGrabItemAction:new(body, worldItem, 50))
    end)
    if okQ then log(id .. " picks something up from the ground") end
    return okQ
end

function N.clearOffered(body)
    pcall(function() SAOJavaBridge:clearOffered(body) end)
end

-- Hand a spare drinkable to a fellow through the vanilla transfer.
function N.shareDrinkWith(id, body, fellowBody)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function() return SAOJavaBridge:findSpareDrink(body) end)
    if not okS or item == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, item, body:getInventory(), fellowBody:getInventory()))
    end)
    if okQ then log(id .. " hands over a drink") end
    return okQ
end

-- Light one up through the same vanilla eat action (SMOKABLE items are
-- eaten; the action handles lighters and the withdrawal relief).
function N.smokeCarried(id, body)
    if not SAOJavaBridge then return false end
    local ok, item = pcall(function() return SAOJavaBridge:findCarriedSmokable(body) end)
    if not ok or item == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISEatFoodAction:new(body, item, 1))
    end)
    if okQ then log(id .. " lights one up") end
    return okQ
end

function N.smokableCount(body)
    local ok, n = pcall(function() return SAOJavaBridge:smokableCount(body) end)
    return ok and tonumber(n) or 0
end

-- Hand a smoke over (the smokers' bond) through the vanilla transfer.
function N.shareSmokeWith(id, body, fellowBody)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function() return SAOJavaBridge:findCarriedSmokable(body) end)
    if not okS or item == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, item, body:getInventory(), fellowBody:getInventory()))
    end)
    if okQ then log(id .. " shares a smoke") end
    return okQ
end

-- Give the bonded the BEST carried food - the spare-only rule is for
-- everyone else.
function N.shareAllWith(id, body, fellowBody)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function() return SAOJavaBridge:findFoodForBonded(body) end)
    if not okS or item == nil then return false end
    local okQ = pcall(function()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(
            body, item, body:getInventory(), fellowBody:getInventory()))
    end)
    if okQ then log(id .. " gives their last to their bonded") end
    return okQ
end

function N.clearGear(body)
    pcall(function() SAOJavaBridge:clearWeaponSource(body) end)
end

function N.clearWater(body)
    pcall(function() SAOJavaBridge:clearWaterSource(body) end)
end

function N.clearSource(body)
    pcall(function() SAOJavaBridge:clearFoodSource(body) end)
end

-- Whether the body's own action stack still holds queued work.
function N.busy(body)
    local ok, pending = pcall(function()
        return SAOJavaBridge:hasPendingActions(body)
    end)
    return ok and pending == true
end

log("needs module loaded")

return N
