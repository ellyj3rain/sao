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

-- [C60] Vanilla validates item/container identity but does not re-ask a
-- vehicle whether this character may use its part. Keep the vanilla action
-- and add the one authority it lacks. isValid runs throughout the timed
-- action, so movement, unload or a lock change refuses before completion.
local SAOVerifiedWorldTransferAction =
    ISInventoryTransferAction:derive("SAOVerifiedWorldTransferAction")

function SAOVerifiedWorldTransferAction:isValid()
    if not ISInventoryTransferAction.isValid(self) then return false end
    if not SAOJavaBridge or self.saoWorldContainer == nil then return false end
    local ok, accessible = pcall(function()
        return SAOJavaBridge:containerAccessibleNow(
            self.character, self.saoWorldContainer)
    end)
    if not ok or accessible ~= true then return false end
    if self.saoSourceReservation then
        local reservation = SAO.WorldSources
            and SAO.WorldSources.reservation(self.saoSourceReservation)
        if not reservation or reservation.status ~= "reserved"
            or reservation.actorId ~= self.saoSourceActor then return false end
        local located, position = pcall(function()
            return SAOJavaBridge:worldTransferPosition(self.character,
                self.saoWorldContainer)
        end)
        if not located or type(position) ~= "string" then return false end
        local x, y, z = string.match(position, "^AT:(%-?%d+):(%-?%d+):(%-?%d+)$")
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        if not x or not y or not z then return false end
        if reservation.sourceKind == "vehicle" and (not reservation.placeMinX
            or x < reservation.placeMinX or x >= reservation.placeMaxX
            or y < reservation.placeMinY or y >= reservation.placeMaxY) then
            return false
        end
        reservation.currentSourceX, reservation.currentSourceY,
            reservation.currentSourceZ = x, y, z
        return SAO.Standing and SAO.Standing.mayTakeCurrent
            and SAO.Standing.mayTakeCurrent(self.saoSourceActor, x, y,
                reservation.admission) == true
    end
    return true
end

-- Vanilla may reach transferItem after its last queue validity check. Repeat
-- the current authority check at the actual native mutation boundary.
function SAOVerifiedWorldTransferAction:transferItem(item)
    if not self:isValid() then self.dontAdd = true; return end
    local checked, fresh = pcall(function()
        return SAO.SourceUse and SAO.SourceUse.nativeTransferPending
            and SAO.SourceUse.nativeTransferPending(self.saoSourceActor,
                self.character, self.saoSourceReservation)
    end)
    local result = ISInventoryTransferAction.transferItem(self, item)
    if checked and fresh == true and SAO.SourceUse.observeNativeTransfer then
        -- Observation failure cannot undo a native move. Reconciliation still
        -- owns completion, and does not invent witnesses on a later retry.
        pcall(SAO.SourceUse.observeNativeTransfer, self.saoSourceActor,
            self.character, self.saoSourceReservation, self.saoWorldContainer)
    end
    return result
end

function SAOVerifiedWorldTransferAction:new(
        character, item, srcContainer, destContainer, worldContainer)
    local o = ISInventoryTransferAction.new(
        self, character, item, srcContainer, destContainer)
    o.saoWorldContainer = worldContainer
    return o
end

local function worldTransfer(body, item, srcContainer, destContainer,
                             worldContainer)
    return SAOVerifiedWorldTransferAction:new(
        body, item, srcContainer, destContainer, worldContainer)
end

-- [C62] The exact-source executor owns selection and lifecycle, while this
-- module continues to own the verified vanilla transfer shape. Returning the
-- action (rather than queueing it) lets the executor use the same queue
-- acceptance proof as every other body action.
function N.worldSourceTransferAction(body, item, srcContainer,
                                     worldContainer)
    if body == nil or item == nil or srcContainer == nil
        or worldContainer == nil then return nil end
    return worldTransfer(body, item, srcContainer, body:getInventory(),
        worldContainer)
end

function N.worldStoreTransferAction(body, item, srcContainer, destContainer)
    if body == nil or item == nil or srcContainer == nil
        or destContainer == nil then return nil end
    return worldTransfer(body, item, srcContainer, destContainer, destContainer)
end

-- [C25] How far a body NOTICES (DR-027). This was the ErrandRadius
-- sandbox dial, and the operator ruled the dial a lie about what it
-- measured: "They're operating off of social structures and social
-- incentives and personal desires and understanding and awareness.
-- It's not, oh, you can move within a radius of twelve." Twelve
-- tiles is the span of the probe - what is close enough to see and
-- walk straight to - and that is ALL it is. How far a person will GO
-- is knowledge and desire now: the county's places, searched nearest
-- first, committed to by need (SAO.WorldSources.nearestBelieved, the
-- controller's knowledge step). A perception span is not a leash,
-- and it is nobody's option.
N.PERCEPTION_TILES = 12

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
        return SAOJavaBridge:findFoodSource(body, radius or N.PERCEPTION_TILES)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, name = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+):(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), name
end

-- Queue taking the remembered source item through the vanilla transfer
-- action (into the body's own inventory). Java revalidates the source.
function N.queueTake(id, body, context)
    if not SAOJavaBridge then return false end
    local okR, within = pcall(function()
        return SAOJavaBridge:foodSourceWithinReach(body)
    end)
    if not okR or not within then return false end
    local okI, item = pcall(function() return SAOJavaBridge:foodSourceItem(body) end)
    local okC, container = pcall(function() return SAOJavaBridge:foodSourceContainer(body) end)
    if not (okI and okC) or item == nil or container == nil then return false end
    if not context or context.category == "legacy" then
        -- Medication and other older FORAGE consumers retain their native
        -- transfer adapter until their own action family has an exact result.
        return N.queueVerified(worldTransfer(body, item, container,
            body:getInventory(), container))
    end
    return SAO.SourceUse and SAO.SourceUse.beginTransfer(id, body, "food",
        context.admission or "standing", item, container, "acquire", context)
        or false
end

-- A sweep discovers a candidate, then the exact transfer owner rechecks
-- inspection, permission and holders. Each item takes its native action.
function N.collectNearby(id, body, radius, remaining)
    local x, y, z = N.findSource(id, body, radius)
    if not x then return nil end
    local context = { purpose = "forage", category = "food", admission = "standing",
        haulRemaining = math.max(0, math.min(3, (remaining or 1) - 1)),
        haulRadius = math.max(1, math.min(4, radius or 4)) }
    local ok, within = pcall(function()
        return SAOJavaBridge:foodSourceWithinReach(body)
    end)
    if not ok then return nil end
    if within then
        return N.queueTake(id, body, context) and "TAKE" or nil, context
    end
    if not (SAO.Standing and SAO.Standing.mayAttemptBelieved
        and SAO.Standing.mayAttemptBelieved(id, x, y, context.admission)) then
        return nil
    end
    if SAO.Locomotion.order(id, body, x, y, z) then
        return "FORAGE", context
    end
    return nil
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
        return SAOJavaBridge:findWaterSource(body, radius or N.PERCEPTION_TILES)
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
        return SAOJavaBridge:findWeaponUpgrade(body, radius or N.PERCEPTION_TILES)
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
    local queued = N.queueVerified(worldTransfer(
        body, item, container, body:getInventory(), container))
    if queued then log(id .. " takes a better weapon from a container") end
    return queued
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
function N.shareFoodWith(id, body, fellowBody, recipientId, options)
    if not (SAOJavaBridge and SAO.Handover and recipientId) then
        return false
    end
    local okS, item = pcall(function() return SAOJavaBridge:findSpareFood(body) end)
    if not okS or item == nil then return false end
    local receipt = SAO.Handover.begin(id, body, recipientId, fellowBody, item,
        "food", options)
    if receipt then log(id .. " queues food for a fellow") end
    return receipt or false
end

-- [B22] The book goes round. The same vanilla transfer every other
-- kindness in this mod uses - nothing special, which is the point: a
-- retired clerk handing over a paperback is worth something to a
-- house in a way that has nothing to do with what they did for money.
function N.passReadingTo(id, body, otherBody, recipientId, options)
    if not (SAOJavaBridge and otherBody and SAO.Handover and recipientId) then
        return false
    end
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
    local receipt = SAO.Handover.begin(id, body, recipientId, otherBody, book,
        "reading", options)
    return receipt or false
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
-- Returns "treated", a pending Handover receipt, or false, because treatment
-- and giving the dressing are different acts with different completion proof.
function N.aidWound(id, body, patientBody, recipientId, options)
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
    if not (SAO.Handover and recipientId) then return false end
    local receipt = SAO.Handover.begin(id, body, recipientId, patientBody, item,
        "bandage", options)
    if receipt then
        log(id .. " queues a bandage - nothing open to dress")
    end
    return receipt or false
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
function N.shareDisinfectantWith(id, body, otherBody, recipientId, options)
    if not (SAO.Handover and recipientId) then return false end
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
    local receipt = SAO.Handover.begin(id, body, recipientId, otherBody, gift,
        "disinfectant", options)
    if receipt then log(id .. " queues what cleans a wound") end
    return receipt or false
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
        return SAOJavaBridge:hearthNear(body, radius or N.PERCEPTION_TILES)
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
    return SAO.SourceUse and SAO.SourceUse.beginTransfer(id, body, "water",
        "standing", vessels[2].item, container, "store", { purpose = "storage" })
        or false
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
    return SAO.SourceUse and SAO.SourceUse.beginTransfer(id, body, "water",
        "standing", found, container, "acquire", { purpose = "draw-water" })
        or false
end

function N.depositSpareFood(id, body, context)
    if not SAOJavaBridge then return false end
    local okS, item = pcall(function() return SAOJavaBridge:findSpareFood(body) end)
    if not okS or item == nil then return false end
    local okC, container = pcall(function()
        return SAOJavaBridge:findNearbyContainer(body, 5)
    end)
    if not okC or container == nil then return false end
    return SAO.SourceUse and SAO.SourceUse.beginTransfer(id, body, "food",
        "standing", item, container, "store", context or { purpose = "storage" })
        or false
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
        return SAOJavaBridge:findAmmoSource(body, radius or N.PERCEPTION_TILES)
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
    local queued = N.queueVerified(worldTransfer(
        body, item, container, body:getInventory(), container))
    if queued then log(id .. " takes ammunition from a container") end
    return queued
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
function N.shareDrinkWith(id, body, fellowBody, recipientId, options)
    if not (SAOJavaBridge and SAO.Handover and recipientId) then
        return false
    end
    local okS, item = pcall(function() return SAOJavaBridge:findSpareDrink(body) end)
    if not okS or item == nil then return false end
    local receipt = SAO.Handover.begin(id, body, recipientId, fellowBody, item,
        "drink", options)
    if receipt then log(id .. " queues a drink for a fellow") end
    return receipt or false
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

-- [C121] The RealSmoking dial, read at the seam that owns the body's
-- acts. A smoke break is a body's act - a cigarette in a hand, an
-- animation a witness can see - so the dormant half has nothing to
-- read: its people carry the same habits through the shared
-- SAO_Habits (drawn for every person in both halves), and the dial
-- governs only the visible act, which exists only where a body
-- does. The fallback is the declared default: on.
function N.casualSmokingOn()
    if SandboxVars and SandboxVars.SurvivorAwareness then
        return SandboxVars.SurvivorAwareness.RealSmoking ~= false
    end
    return true
end

-- Hand a smoke over (the smokers' bond) through the vanilla transfer.
function N.shareSmokeWith(id, body, fellowBody, recipientId, options)
    if not (SAOJavaBridge and SAO.Handover and recipientId) then
        return false
    end
    local okS, item = pcall(function() return SAOJavaBridge:findCarriedSmokable(body) end)
    if not okS or item == nil then return false end
    local receipt = SAO.Handover.begin(id, body, recipientId, fellowBody, item,
        "smoke", options)
    if receipt then log(id .. " queues a smoke for a fellow") end
    return receipt or false
end

-- Give the bonded the BEST carried food - the spare-only rule is for
-- everyone else.
function N.shareAllWith(id, body, fellowBody, recipientId, options)
    if not (SAOJavaBridge and SAO.Handover and recipientId) then
        return false
    end
    local okS, item = pcall(function() return SAOJavaBridge:findFoodForBonded(body) end)
    if not okS or item == nil then return false end
    local receipt = SAO.Handover.begin(id, body, recipientId, fellowBody, item,
        "food", options)
    if receipt then log(id .. " queues their food for their bonded") end
    return receipt or false
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

-- [C33] A drink, for the shakes: the fullest alcoholic drink carried,
-- a quarter of it, through the vanilla fluid action (the same one
-- the context menu queues; shared TimedActions/ISDrinkFluidAction).
-- A quarter is a drink - ours. Returns true when queued.
function N.drinkCarriedAlcohol(id, body)
    if not SAOJavaBridge then return false end
    local okF, item = pcall(function() return SAOJavaBridge:findCarriedAlcohol(body) end)
    if not okF or item == nil then return false end
    local queued = N.queueVerified(ISDrinkFluidAction:new(body, item, 0.25))
    if queued then log(id .. " takes a drink (vanilla fluid action)") end
    return queued
end

-- [C33] Where a drink is: the nearest container holding one, into the
-- same source record food uses, so queueTake takes it. Returns
-- x, y, z, name or nil.
function N.findDrinkSource(id, body, radius)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:findAlcoholSource(body, radius or N.PERCEPTION_TILES)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, name = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+):(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), name
end

-- Whether the body's own action stack still holds queued work.
function N.busy(body)
    local ok, pending = pcall(function()
        return SAOJavaBridge:hasPendingActions(body)
    end)
    return ok and pending == true
end

-- [C121] A dose, for the shakes: the first carried drug of a county
-- family, through the vanilla eat action - the same one the context
-- menu queues. The item's own OnEat hooks run the drug mod's own
-- counters and highs, exactly as they would for the player. Returns
-- true when queued.
function N.useCarriedDrug(id, body, family)
    if not SAOJavaBridge then return false end
    local okF, item = pcall(function()
        return SAOJavaBridge:findCarriedDrug(body, family)
    end)
    if not okF or item == nil then return false end
    local queued = N.queueVerified(ISEatFoodAction:new(body, item, 1))
    if queued then log(id .. " takes a dose (vanilla eat action)") end
    return queued
end

-- [C121] Where a stash is: the nearest container holding a drug of
-- the family, into the same source record the drink uses, so
-- queueTake takes it. Returns x, y, z, name or nil.
function N.findDrugSource(id, body, radius, family)
    if not SAOJavaBridge then return nil end
    local ok, s = pcall(function()
        return SAOJavaBridge:findDrugSource(body, radius or N.PERCEPTION_TILES, family)
    end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local x, y, z, name = string.match(s, "^(%-?%d+):(%-?%d+):(%-?%d+):(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(z), name
end

-- [C33] The county's drinks are counted (The Alcoholic wraps the eat
-- action the same way, CREDITS.md): when one of OUR bodies finishes
-- a drink of anything alcoholic - by its own hand or the player's
-- gift - the habit hears it. A field on the vanilla class, wrapped
-- once; the player's own drinks pass straight through.
-- [C121] The drink also reaches the ladder SAO_Drugs carries (the
-- per-drink relief at The Alcoholic's own figures), the same way the
-- player's drinks reach theirs.
if ISDrinkFluidAction and not ISDrinkFluidAction.SAOHabitsWrapped then
    ISDrinkFluidAction.SAOHabitsWrapped = true
    local baseComplete = ISDrinkFluidAction.complete
    function ISDrinkFluidAction:complete()
        local result = baseComplete(self)
        pcall(function()
            local body = self.character
            local id = body and body:getModData().SAOPersonId or nil
            if id and SAOJavaBridge and SAOJavaBridge:isAlcoholicDrink(self.item) then
                if SAO.Habits.drank(tostring(id)) then
                    log(tostring(id) .. " has had a drink")
                end
                if SAO.Drugs and SAO.Drugs.onDrink then
                    SAO.Drugs.onDrink(tostring(id), body)
                end
            end
        end)
        return result
    end
end

-- [C121] The county's uses are recorded: when one of OUR bodies
-- finishes eating anything - a pill, a joint, whatever the drug
-- mod's own items are - the family it belongs to is stamped on the
-- record and that family's clean clock starts over. The item's own
-- OnEat globals have already run inside the base call (the engine
-- fires them from perform), so the drug mod's counters rise before
-- the stamp does, and the stamp only says when the use happened.
-- The Alcoholic wraps this same perform the same way; a field on the
-- vanilla class, wrapped once, and the player's own meals pass
-- straight through.
if ISEatFoodAction and not ISEatFoodAction.SAODrugsWrapped then
    ISEatFoodAction.SAODrugsWrapped = true
    local basePerform = ISEatFoodAction.perform
    function ISEatFoodAction:perform()
        local result = basePerform(self)
        pcall(function()
            local body = self.character
            local id = body and body:getModData().SAOPersonId or nil
            if id and SAOJavaBridge then
                local ok, family = pcall(function()
                    return SAOJavaBridge:drugFamilyOf(self.item)
                end)
                if ok and family and family ~= "" then
                    if SAO.Habits.used(tostring(id), family) then
                        log(tostring(id) .. " has had a use of " .. family)
                    end
                end
            end
        end)
        return result
    end
end

log("needs module loaded")

return N
