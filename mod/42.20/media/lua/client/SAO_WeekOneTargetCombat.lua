-- A retained Week One person's hostile Standing names one player character.
-- Bandits2's hostile and hostileP fields are global, so neither field grants
-- permission to select, strike, shove, shoot or burn a player for this person.
SAO = SAO or {}
SAO.WeekOneTargetCombat = SAO.WeekOneTargetCombat or {}
local T = SAO.WeekOneTargetCombat
local OWNER = "BanditsWeekOne"
local wrapped, originals, actionContext = {}, {}, nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

-- BanditUpdate's local ManageCombat reads one brain from BanditBrain.Get
-- immediately before its all-player hostile/hostileP loop. The source
-- provenance remains on the brain, while these source-global switches are
-- cleared whenever an SAO-stamped body or brain is read. A broken body/brain
-- crosswalk is quarantined as well: returning its true global flag would
-- revive the source all-player loop before SAO could reject its action.
local function normalizeSourceHostility(body, brain)
    if type(brain) ~= "table" then return brain end
    local ok, marker, outfit, alive = pcall(function()
        return body:getModData(), body:getPersistentOutfitID(), body:isAlive()
    end)
    local marked = ok and type(marker) == "table"
        and marker.SAOWeekOneOrigin == OWNER
    local stamped = brain.saoWeekOneOrigin == OWNER
    if not stamped and not marked then return brain end
    local scope = "quarantined"
    if stamped and marked and alive == true
        and finite(brain.id) and brain.id % 1 == 0
        and finite(brain.born) and outfit == brain.id
        and marker.SAOWeekOneBrainId == brain.id
        and marker.SAOWeekOneBorn == brain.born
        and type(marker.SAOWeekOnePersonId) == "string"
        and marker.SAOWeekOnePersonId ~= "" then
        scope = "exact-body"
    end
    local original = brain.saoWeekOneSourceHostility
    if type(original) ~= "table" then
        original = { source = "Bandits2.brain",
            hostile = brain.hostile == true,
            hostileP = brain.hostileP == true,
            reassertions = 0, scope = scope }
        brain.saoWeekOneSourceHostility = original
    else
        original.scope = scope
        if brain.hostile == true or brain.hostileP == true then
            original.reassertions = (finite(original.reassertions)
                and original.reassertions or 0) + 1
            original.lastHostile = brain.hostile == true
            original.lastHostileP = brain.hostileP == true
        end
    end
    brain.hostile = false
    brain.hostileP = false
    return brain
end

local function sourceState(body)
    if not body or not (BanditBrain and type(BanditBrain.Get) == "function") then
        return nil, "foreign" end
    local ok, brain, marker, outfit, alive = pcall(function()
        local data = body:getModData()
        return BanditBrain.Get(body), data, body:getPersistentOutfitID(),
            body:isAlive()
    end)
    if not ok then return nil, "unavailable" end
    local stamped = type(brain) == "table"
        and brain.saoWeekOneOrigin == OWNER
    local marked = type(marker) == "table"
        and marker.SAOWeekOneOrigin == OWNER
    if not stamped and not marked then return nil, "foreign" end
    if not stamped or not marked or alive ~= true
        or not finite(brain.id) or brain.id % 1 ~= 0
        or not finite(brain.born) or outfit ~= brain.id
        or marker.SAOWeekOneBrainId ~= brain.id
        or marker.SAOWeekOneBorn ~= brain.born
        or type(marker.SAOWeekOnePersonId) ~= "string" then
        return nil, "body-mismatch" end
    local W = SAO.WeekOneContinuity
    if not (W and type(W.sourceBodyFor) == "function"
        and SAO.Identity and type(SAO.Identity.get) == "function"
        and SAO.Claims and type(SAO.Claims.heldBy) == "function") then
        return nil, "person-unavailable" end
    local okCurrent, currentBody, currentBrain =
        pcall(W.sourceBodyFor, marker.SAOWeekOnePersonId)
    local rec = SAO.Identity.get(marker.SAOWeekOnePersonId)
    local phase = rec and rec.weekOne
    if not okCurrent or currentBody ~= body or currentBrain ~= brain
        or not phase or rec.dead or phase.source ~= OWNER
        or phase.status ~= "external" or phase.pending or phase.stageToken
        or phase.brainId ~= brain.id or phase.born ~= brain.born
        or SAO.Claims.heldBy(rec) ~= OWNER then
        return nil, "person-mismatch" end
    return { brain = brain, personId = rec.id, rec = rec }, "selected"
end

-- nil means a foreign Bandits2 body, which keeps its installed behavior.
-- false means a selected source body has no authority over this exact player.
function T.canAttackPlayer(body, player)
    local state, kind = sourceState(body)
    if kind == "foreign" then return nil end
    if not state or not player or not instanceof
        or not instanceof(player, "IsoPlayer")
        or not (SAO.Standing and type(SAO.Standing.playerKey) == "function"
            and type(SAO.Standing.isHostileTo) == "function"
            and type(SAO.Standing.groupOf) == "function") then return false end
    local ok, key, alive = pcall(function()
        return SAO.Standing.playerKey(player), player:isAlive()
    end)
    if not ok or alive ~= true or type(key) ~= "string" or key == ""
        then return false end
    local decided, hostile, actorGroup, targetGroup = pcall(function()
        return SAO.Standing.isHostileTo(state.personId, key),
            SAO.Standing.groupOf(state.personId), SAO.Standing.groupOf(key)
    end)
    return decided and hostile == true
        and (actorGroup == nil or actorGroup ~= targetGroup)
end

local function sourcePlayer(task)
    if type(task) ~= "table" or task.eid == nil
        or not (BanditPlayer and type(BanditPlayer.GetPlayerById) == "function")
        then return nil, false end
    local ok, player = pcall(BanditPlayer.GetPlayerById, task.eid)
    if ok and player and instanceof and instanceof(player, "IsoPlayer") then
        -- ZASmack resolves the zombie cache before the player map.
        if BanditZombie and BanditZombie.Cache
            and BanditZombie.Cache[task.eid] then return nil, true end
        if not (type(BanditPlayer.GetPlayers) == "function"
            and BanditUtils and type(BanditUtils.GetCharacterID) == "function")
            then return nil, true end
        local listed, players = pcall(BanditPlayer.GetPlayers)
        local counted, count = pcall(function() return players:size() end)
        if not listed or not counted or not finite(count)
            or count < 0 or count > 256 then return nil, true end
        local matches = 0
        for index = 0, count - 1 do
            local valid, id = pcall(function()
                return BanditUtils.GetCharacterID(players:get(index))
            end)
            if valid and id == task.eid then matches = matches + 1 end
            if matches > 1 then return nil, true end
        end
        if matches ~= 1 then return nil, true end
        return player, false
    end
    return nil, false
end

local function withPlayerContext(prior, body, task, player)
    local priorContext = actionContext
    actionContext = { body = body, player = player }
    local ok, result = pcall(prior, body, task)
    actionContext = priorContext
    if not ok then error(result, 0) end
    return result
end

local function actionGate(prior, body, task)
    local player, ambiguous = sourcePlayer(task)
    if not player then
        if ambiguous then
            local _, kind = sourceState(body)
            if kind ~= "foreign" then return true end
        end
        -- An SAO-authored player attack cannot be redirected to a stale ID.
        if type(task) == "table" and task.saoWeekOneTargetKey ~= nil then
            local _, kind = sourceState(body)
            if kind ~= "foreign" then return true end
        end
        return prior(body, task)
    end
    local allowed = T.canAttackPlayer(body, player)
    if allowed == nil then return prior(body, task) end
    if allowed ~= true then return true end
    if task.saoWeekOneTargetKey ~= nil then
        local ok, key = pcall(SAO.Standing.playerKey, player)
        if not ok or key ~= task.saoWeekOneTargetKey then return true end
    end
    return withPlayerContext(prior, body, task, player)
end

-- This is the selected player branch of installed BanditUtils.Hit. SAO owns
-- the permission and keeps the source's accuracy and physical damage model.
-- No global brain flag is set, even transiently.
local function selectedBulletHit(body, item, player, state)
    if not (item and BanditUtils and BanditUtils.DistTo
        and BanditRandom and type(BanditRandom.Get) == "function"
        and BanditCompatibility and BanditCompatibility.GetScopeRange
        and PlayerDamageModel and PlayerDamageModel.BulletHit
        and SandboxVars and SandboxVars.Bandits
        and type(SandboxVars.Bandits.General_OverallAccuracy) == "number"
        and BanditPlayer and BanditPlayer.WakeEveryone
        and ZombRand) then return false end
    local ok, landed = pcall(function()
        local dist = BanditUtils.DistTo(player:getX(), player:getY(),
            body:getX(), body:getY())
        if not finite(dist) or dist < 0 then return false end
        local levels = { -8, -4, 0, 4, 8 }
        local sight = levels[SandboxVars.Bandits.General_OverallAccuracy] or 0
        local boost = state.brain.accuracyBoost or 0
        if not finite(boost) then return false end
        local scope = item:getWeaponPart("Scope")
        if scope then
            local gain = BanditCompatibility.GetScopeRange(scope)
            if not finite(gain) then return false end
            sight = sight + gain
        end
        local d50 = 16 + sight + boost
        local threshold = 1200 + (9000 - 1200)
            / (1 + math.exp(0.13 * (dist - d50)))
        local roll = BanditRandom.Get()
        if not finite(roll) then return false end
        if roll < threshold then
            BanditPlayer.WakeEveryone()
            player:playSound("ZSHit" .. tostring(1 + ZombRand(3)))
            PlayerDamageModel.BulletHit(body, item, player)
        else
            local square = player:getSquare()
            if not square then return false end
            square:playSound("ZSMiss" .. tostring(1 + ZombRand(8)))
        end
        if player:getHealth() <= 1 and Bandit and Bandit.Say then
            Bandit.Say(body, "DEATH")
        end
        return true
    end)
    return ok and landed == true
end

-- W calls this only for a freshly observed person it already chose to
-- confront. It returns one source melee task when that exact player remains
-- visible, hostile, within physical weapon reach, and correctly equipped.
function T.authorizedTaskForObserved(brain, body, personId, observedName, tick)
    if not T.ready() then return nil, "physical-gate-unavailable" end
    local state = sourceState(body)
    if not state or state.brain ~= brain or state.personId ~= personId
        or type(observedName) ~= "string" or observedName == ""
        or not finite(tick) or not (SAO.History and SAO.History.ticks
            and SAO.Perception and SAO.Perception.beliefs
            and SAO.Standing and SAO.Standing.keyForObserved
            and BanditPlayer and BanditPlayer.GetPlayers
            and BanditZombie and BanditZombie.Cache
            and BanditUtils and BanditUtils.GetCharacterID
            and BanditCompatibility and BanditCompatibility.InstanceItem
            and SAOJavaBridge and SAOJavaBridge.weekOneObservedTarget)
        then return nil, "source-or-decision-unavailable" end
    local okTick, currentTick = pcall(SAO.History.ticks)
    local belief = SAO.Perception.beliefs[personId]
    local seen = belief and belief.people and belief.people[observedName]
    if not okTick or currentTick ~= tick or not seen
        or seen.source ~= "observed" or seen.at ~= tick
        or belief.lastScanAt ~= tick then return nil, "stale-private-sight" end
    local wantedKey = SAO.Standing.keyForObserved(observedName)
    if type(wantedKey) ~= "string" or wantedKey == "" then
        return nil, "observed-identity-unavailable" end
    local okSight, packed = pcall(function()
        return SAOJavaBridge:weekOneObservedTarget(body, "person", observedName)
    end)
    local sx, sy, sz, distance
    if okSight and type(packed) == "string" then
        sx, sy, sz, distance =
            packed:match("^TARGET\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
    end
    sx, sy, sz, distance = tonumber(sx), tonumber(sy), tonumber(sz),
        tonumber(distance)
    if not (finite(sx) and finite(sy) and finite(sz)
        and finite(distance) and distance > 0) then
        return nil, "native-target-unavailable" end
    if not (finite(seen.x) and finite(seen.y) and finite(seen.z))
        or math.floor(sx) ~= seen.x
        or math.floor(sy) ~= seen.y
        or math.floor(sz) ~= seen.z then
        return nil, "private-target-moved" end
    local okPlayers, list = pcall(BanditPlayer.GetPlayers)
    if not okPlayers or not list then return nil, "player-list-unavailable" end
    local okCount, count = pcall(function() return list:size() end)
    if not okCount or not finite(count) or count < 0 or count > 256 then
        return nil, "player-list-unavailable" end
    local target
    for index = 0, count - 1 do
        local okPlayer, player = pcall(function() return list:get(index) end)
        if okPlayer and player then
            local ok, key, x, y, z = pcall(function()
                return SAO.Standing.playerKey(player),
                    player:getX(), player:getY(), player:getZ()
            end)
            if ok and key == wantedKey and finite(x) and finite(y)
                and finite(z) and math.abs(x - sx) < 0.125
                and math.abs(y - sy) < 0.125
                and math.abs(z - sz) < 0.5 then
                if target then return nil, "player-identity-ambiguous" end
                target = player
            end
        end
    end
    if not target or T.canAttackPlayer(body, target) ~= true then
        return nil, "player-not-authorized" end
    local weaponType = brain.weapons and brain.weapons.melee
    if type(weaponType) ~= "string" or weaponType == "" then
        return nil, "melee-weapon-unavailable" end
    local okWeapon, weapon, equipped, facing = pcall(function()
        return BanditCompatibility.InstanceItem(weaponType),
            body:isPrimaryEquipped(weaponType),
            body:isFacingObject(target, 0.5)
    end)
    if not okWeapon or not weapon or not equipped or not facing then
        return nil, "melee-position-unavailable" end
    local okReach, reach = pcall(function() return weapon:getMaxRange() end)
    if not okReach or not finite(reach) or reach <= 0 or reach > 3.5
        or distance > reach + 0.1 then return nil, "out-of-melee-range" end
    local okId, eid = pcall(BanditUtils.GetCharacterID, target)
    if not okId or not finite(eid) then return nil, "player-id-unavailable" end
    if BanditZombie.Cache[eid] then return nil, "source-id-collision" end
    local resolved, sourceTarget = pcall(BanditPlayer.GetPlayerById, eid)
    if not resolved or sourceTarget ~= target then
        return nil, "player-id-ambiguous" end
    local matches = 0
    for index = 0, count - 1 do
        local okPlayer, other = pcall(function() return list:get(index) end)
        if okPlayer and other then
            local valid, otherId = pcall(BanditUtils.GetCharacterID, other)
            if valid and otherId == eid then matches = matches + 1 end
        end
    end
    if matches ~= 1 then return nil, "player-id-ambiguous" end
    return { action = "Smack", time = 65, endurance = -0.03,
        shm = false, weapon = weaponType, eid = eid,
        x = sx, y = sy, z = sz, saoWeekOneTargetKey = wantedKey },
        "native-melee"
end

function T.install()
    if not (BanditBrain and type(BanditBrain.Get) == "function"
        and Bandit and type(Bandit.IsHostile) == "function"
        and BanditUtils and type(BanditUtils.Hit) == "function"
        and type(BanditUtils.ManageLineOfFire) == "function"
        and ZombieActions and ZombieActions.Smack and ZombieActions.Push
        and ZombieActions.Shoot and PlayerDamageModel) then
        return false, "source-actions-unavailable" end
    local actions = {
        { ZombieActions.Smack, "onStart" },
        { ZombieActions.Smack, "onWorking" },
        { ZombieActions.Push, "onStart" },
        { ZombieActions.Push, "onWorking" },
        { ZombieActions.Shoot, "onStart" },
        { ZombieActions.Shoot, "onWorking" },
        { ZombieActions.Shoot, "onComplete" },
    }
    for _, entry in ipairs(actions) do
        if type(entry[1][entry[2]]) ~= "function" then
            return false, "source-action-unavailable" end
    end
    for _, name in ipairs({ "BulletHit", "MeleeHit", "BareHandHit" }) do
        if type(PlayerDamageModel[name]) ~= "function" then
            return false, "source-damage-unavailable" end
    end
    if wrapped.installed then
        return T.ready()
    end

    originals.brainGet = BanditBrain.Get
    wrapped.brainGet = function(body)
        return normalizeSourceHostility(body, originals.brainGet(body))
    end
    BanditBrain.Get = wrapped.brainGet

    originals.hostile = Bandit.IsHostile
    wrapped.hostile = function(body)
        local _, kind = sourceState(body)
        if kind == "foreign" then return originals.hostile(body) end
        return actionContext and actionContext.body == body
            and T.canAttackPlayer(body, actionContext.player) == true or false
    end
    Bandit.IsHostile = wrapped.hostile

    originals.hit = BanditUtils.Hit
    wrapped.hit = function(body, item, victim, damageSplit)
        if not (instanceof and instanceof(victim, "IsoPlayer")) then
            return originals.hit(body, item, victim, damageSplit) end
        local permission = T.canAttackPlayer(body, victim)
        if permission == nil then return originals.hit(body, item, victim, damageSplit) end
        if permission ~= true then return false end
        local state = sourceState(body)
        return state and selectedBulletHit(body, item, victim, state) or false
    end
    BanditUtils.Hit = wrapped.hit

    originals.line = BanditUtils.ManageLineOfFire
    wrapped.line = function(body, enemy, weaponItem, damageSplit, incendiary)
        local _, kind = sourceState(body)
        if kind ~= "foreign" and instanceof
            and instanceof(enemy, "IsoPlayer")
            and T.canAttackPlayer(body, enemy) ~= true then return false end
        if kind ~= "foreign" and incendiary == true then
            -- The selected source call is non-incendiary. Its generic ray
            -- would set every bystander on fire without asking Hit.
            return false end
        return originals.line(body, enemy, weaponItem, damageSplit, incendiary)
    end
    BanditUtils.ManageLineOfFire = wrapped.line

    for _, entry in ipairs(actions) do
        local group, name = entry[1], entry[2]
        originals[group] = originals[group] or {}
        wrapped[group] = wrapped[group] or {}
        local prior = group[name]
        originals[group][name] = prior
        wrapped[group][name] = function(body, task)
            return actionGate(prior, body, task)
        end
        group[name] = wrapped[group][name]
    end
    originals.damage = {}
    wrapped.damage = {}
    for _, name in ipairs({ "BulletHit", "MeleeHit", "BareHandHit" }) do
        local prior = PlayerDamageModel[name]
        originals.damage[name] = prior
        wrapped.damage[name] = function(body, player, ...)
            local permission = T.canAttackPlayer(body, player)
            if permission == nil or permission == true then
                return prior(body, player, ...) end
        end
        -- BulletHit's argument order is shooter, item, player.
        if name == "BulletHit" then
            wrapped.damage[name] = function(body, item, player)
                local permission = T.canAttackPlayer(body, player)
                if permission == nil or permission == true then
                    return prior(body, item, player) end
            end
        end
        PlayerDamageModel[name] = wrapped.damage[name]
    end
    wrapped.installed = true
    return true
end

-- The person planner issues a physical task only after the complete source
-- action and damage seam is still installed. A replaced callback is a refusal.
function T.ready()
    if wrapped.installed ~= true or not (BanditBrain and Bandit and BanditUtils
        and ZombieActions and ZombieActions.Smack and ZombieActions.Push
        and ZombieActions.Shoot and PlayerDamageModel
        and BanditBrain.Get == wrapped.brainGet
        and Bandit.IsHostile == wrapped.hostile
        and BanditUtils.Hit == wrapped.hit
        and BanditUtils.ManageLineOfFire == wrapped.line) then return false end
    for _, group in ipairs({ ZombieActions.Smack, ZombieActions.Push,
        ZombieActions.Shoot }) do
        for name, replacement in pairs(wrapped[group] or {}) do
            if group[name] ~= replacement then return false end
        end
    end
    for name, replacement in pairs(wrapped.damage or {}) do
        if PlayerDamageModel[name] ~= replacement then return false end
    end
    return true
end
