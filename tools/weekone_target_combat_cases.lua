__step = "setup"
__tick = 300
__hostileA, __hostileB = true, false
__sourceCalls = { smack = 0, push = 0, shoot = 0, line = 0, hit = 0 }
__damage = { a = 0, b = 0 }
__wakes = 0
__bodyCurrent = true
__nativeX = 0.8
__sameGroup = false
__duplicateId = false

instanceof = function(object, kind)
    return type(object) == "table" and object.kind == kind
end
local function player(name, id, x)
    local p = { kind = "IsoPlayer", name = name, id = id, x = x, y = 0,
        z = 0, alive = true, health = 100 }
    p.getX = function(self) return self.x end
    p.getY = function(self) return self.y end
    p.getZ = function(self) return self.z end
    p.getHealth = function(self) return self.health end
    p.getSquare = function(self) return {
        playSound = function(_, sound) self.lastMiss = sound end } end
    p.isAlive = function(self) return self.alive end
    p.playSound = function(self, sound) self.lastHit = sound end
    return p
end
__a = player("Alice", 1, 0.8)
__b = player("Bob", 2, 1.0)
__brain = { id = 42, born = 12.5, saoWeekOneOrigin = "BanditsWeekOne",
    hostile = true, hostileP = true, weapons = { melee = "Base.Axe" } }
__body = { kind = "IsoZombie", brain = __brain, alive = true,
    md = { SAOWeekOneOrigin = "BanditsWeekOne",
        SAOWeekOnePersonId = "bwo-1", SAOWeekOneBrainId = 42,
        SAOWeekOneBorn = 12.5 } }
__body.getModData = function(self) return self.md end
__body.getPersistentOutfitID = function() return 42 end
__body.isAlive = function(self) return self.alive end
__body.getX = function() return 0 end
__body.getY = function() return 0 end
__body.isPrimaryEquipped = function(_, item) return item == "Base.Axe" end
__body.isFacingObject = function() return true end
__foreign = { kind = "IsoZombie",
    brain = { id = 99, born = 4, saoWeekOneOrigin = "Bandits2",
        hostile = true, hostileP = true }, md = {} }
__foreign.getModData = function(self) return self.md end
__foreign.getPersistentOutfitID = function() return 99 end
__foreign.isAlive = function() return true end
__record = { id = "bwo-1", weekOne = { source = "BanditsWeekOne",
    status = "external", brainId = 42, born = 12.5 } }
BanditBrain = { Get = function(body) return body.brain end }
BanditZombie = { Cache = {} }
Bandit = {
    IsHostile = function(body) return body.brain.hostile or body.brain.hostileP end,
    Say = function() end,
}
BanditPlayer = {
    GetPlayerById = function(id)
        return id == 1 and __a or id == 2 and __b or nil end,
    GetPlayers = function() return {
        size = function() return 2 end,
        get = function(_, i) return i == 0 and __a or __b end,
    } end,
    WakeEveryone = function() __wakes = __wakes + 1 end,
}
BanditUtils = {
    GetCharacterID = function(p)
        return __duplicateId and p == __b and 1 or p.id end,
    DistTo = function(x, y, xx, yy)
        return math.sqrt((x - xx)^2 + (y - yy)^2) end,
    Hit = function()
        __sourceCalls.hit = __sourceCalls.hit + 1
        return true
    end,
    ManageLineOfFire = function(body, target, item, split, incendiary)
        __sourceCalls.line = __sourceCalls.line + 1
        BanditUtils.Hit(body, item, __b)
        BanditUtils.Hit(body, item, __a)
        if incendiary then __b.burned = true end
        return true
    end,
}
BanditCompatibility = {
    InstanceItem = function(item)
        if item ~= "Base.Axe" then return nil end
        return { getMaxRange = function() return 1.2 end }
    end,
    GetScopeRange = function() return 0 end,
}
BanditRandom = { Get = function() return 0 end }
SandboxVars = { Bandits = { General_OverallAccuracy = 3 } }
ZombRand = function() return 0 end
PlayerDamageModel = {
    BulletHit = function(_, _, victim)
        __damage[victim == __a and "a" or "b"] =
            __damage[victim == __a and "a" or "b"] + 1
    end,
    MeleeHit = function(_, victim)
        __damage[victim == __a and "a" or "b"] =
            __damage[victim == __a and "a" or "b"] + 1
    end,
    BareHandHit = function(_, victim)
        __damage[victim == __a and "a" or "b"] =
            __damage[victim == __a and "a" or "b"] + 1
    end,
}
ZombieActions = {
    Smack = {
        onStart = function() __sourceCalls.smack = __sourceCalls.smack + 1
            return false end,
        onWorking = function(body, task)
            __sourceCalls.smack = __sourceCalls.smack + 1
            if Bandit.IsHostile(body) then
                PlayerDamageModel.MeleeHit(body,
                    BanditPlayer.GetPlayerById(task.eid), {})
            end
            return false
        end,
    },
    Push = {
        onStart = function() __sourceCalls.push = __sourceCalls.push + 1
            return false end,
        onWorking = function(body, task)
            __sourceCalls.push = __sourceCalls.push + 1
            if Bandit.IsHostile(body) then
                PlayerDamageModel.BareHandHit(body,
                    BanditPlayer.GetPlayerById(task.eid))
            end
            return false
        end,
    },
    Shoot = {
        onStart = function() __sourceCalls.shoot = __sourceCalls.shoot + 1
            return false end,
        onWorking = function() __sourceCalls.shoot = __sourceCalls.shoot + 1
            return false end,
        onComplete = function(body, task)
            __sourceCalls.shoot = __sourceCalls.shoot + 1
            return BanditUtils.ManageLineOfFire(body,
                BanditPlayer.GetPlayerById(task.eid),
                { getWeaponPart = function() return nil end }, nil, false)
        end,
    },
}
SAO = {
    Identity = { get = function(id)
        return id == "bwo-1" and __record or nil end },
    Claims = { heldBy = function(rec)
        return rec == __record and "BanditsWeekOne" or nil end },
    Standing = {
        playerKey = function(p) return "player:" .. p.name end,
        keyForObserved = function(name) return "player:" .. name end,
        isHostileTo = function(id, key)
            return id == "bwo-1" and
                ((key == "player:Alice" and __hostileA)
                    or (key == "player:Bob" and __hostileB)) or false
        end,
        groupOf = function(key)
            return __sameGroup and (key == "bwo-1"
                or key == "player:Alice") and "home" or nil
        end,
    },
    History = { ticks = function() return __tick end },
    Perception = { beliefs = { ["bwo-1"] = {
        lastScanAt = 300,
        people = { Alice = { source = "observed", at = 300,
            x = 0, y = 0, z = 0 } },
    } } },
    WeekOneContinuity = { sourceBodyFor = function(id)
        if id == "bwo-1" and __bodyCurrent then return __body, __brain end
    end },
}
SAOJavaBridge = { weekOneObservedTarget = function(_, body, kind, name)
    if body == __body and kind == "person" and name == "Alice" then
        return "TARGET\t" .. tostring(__nativeX) .. "\t0\t0\t"
            .. tostring(__nativeX) end
    return "REFUSED\tsight"
end }

function __safeTargetCombat()
    local ok, err = pcall(function()
        local T = SAO.WeekOneTargetCombat
        __step = "source-player-loop"
        local stamped = BanditBrain.Get(__body)
        assert(stamped == __brain and stamped.hostile == false
            and stamped.hostileP == false,
            "source global player loop retained stamped hostility")
        assert(stamped.saoWeekOneSourceHostility.source == "Bandits2.brain"
            and stamped.saoWeekOneSourceHostility.hostile == true
            and stamped.saoWeekOneSourceHostility.hostileP == true
            and stamped.saoWeekOneSourceHostility.scope == "exact-body",
            "source hostility provenance was lost")
        local foreign = BanditBrain.Get(__foreign)
        assert(foreign.hostile == true and foreign.hostileP == true
            and foreign.saoWeekOneSourceHostility == nil,
            "foreign source hostility was changed")
        __brain.hostile = true
        __brain.hostileP = true
        BanditBrain.Get(__body)
        assert(__brain.hostile == false and __brain.hostileP == false
            and __brain.saoWeekOneSourceHostility.reassertions == 1
            and __brain.saoWeekOneSourceHostility.lastHostile == true
            and __brain.saoWeekOneSourceHostility.lastHostileP == true,
            "source reassertion survived the next brain read")
        __body.md.SAOWeekOneBorn = 99
        __brain.hostileP = true
        BanditBrain.Get(__body)
        assert(__brain.hostile == false and __brain.hostileP == false
            and __brain.saoWeekOneSourceHostility.scope == "quarantined",
            "body marker mismatch did not enter source quarantine")
        __body.md.SAOWeekOneBorn = 12.5
        BanditBrain.Get(__body)
        assert(__brain.saoWeekOneSourceHostility.scope == "exact-body",
            "restored body crosswalk remained quarantined")

        __step = "permission"
        assert(T.canAttackPlayer(__body, __a) == true
            and T.canAttackPlayer(__body, __b) == false,
            "non-target player received hostile permission")
        __sameGroup = true
        assert(T.canAttackPlayer(__body, __a) == false,
            "same-group player received hostile permission")
        __sameGroup = false
        assert(T.canAttackPlayer(__foreign, __b) == nil,
            "foreign source behavior lost")

        __step = "gate-ready"
        assert(T.ready() == true and T.install() == true,
            "source physical gates unavailable or duplicated")
        local exactSmack = ZombieActions.Smack.onWorking
        ZombieActions.Smack.onWorking = function() return true end
        assert(T.ready() == false,
            "replaced physical gate still reported ready")
        ZombieActions.Smack.onWorking = exactSmack
        local exactGet = BanditBrain.Get
        BanditBrain.Get = function(body) return body.brain end
        assert(T.ready() == false,
            "replaced source brain gate still reported ready")
        BanditBrain.Get = exactGet
        assert(T.ready() == true, "restored physical gate remained unavailable")

        __step = "one-observed-melee"
        local task, kind = T.authorizedTaskForObserved(__brain, __body,
            "bwo-1", "Alice", 300)
        assert(type(task) == "table" and task.action == "Smack"
            and task.eid == 1 and task.saoWeekOneTargetKey == "player:Alice"
            and kind == "native-melee", "exact observed hostile player lacked one native task")
        __a.x = 4
        __nativeX = 4
        SAO.Perception.beliefs["bwo-1"].people.Alice.x = 4
        assert(T.authorizedTaskForObserved(__brain, __body,
            "bwo-1", "Alice", 300) == nil,
            "out-of-range player received a melee task")
        __a.x = 0.8
        __nativeX = 0.8
        SAO.Perception.beliefs["bwo-1"].people.Alice.x = 0
        __a.x = 1
        __nativeX = 1
        assert(T.authorizedTaskForObserved(__brain, __body,
            "bwo-1", "Alice", 300) == nil,
            "moved target reused stale private sight")
        __a.x = 0.8
        __nativeX = 0.8
        __tick = 301
        assert(T.authorizedTaskForObserved(__brain, __body,
            "bwo-1", "Alice", 300) == nil,
            "stale private sight produced a combat task")
        __tick = 300
        __duplicateId = true
        assert(T.authorizedTaskForObserved(__brain, __body,
            "bwo-1", "Alice", 300) == nil,
            "duplicate source player ID produced an attack task")
        __duplicateId = false
        BanditZombie.Cache[1] = { kind = "IsoZombie" }
        assert(T.authorizedTaskForObserved(__brain, __body,
            "bwo-1", "Alice", 300) == nil,
            "source zombie ID collision produced a player attack task")
        local sourceBeforeCollision = __sourceCalls.smack
        assert(ZombieActions.Smack.onWorking(__body,
            { eid = 1, saoWeekOneTargetKey = "player:Alice" }) == true
            and __sourceCalls.smack == sourceBeforeCollision,
            "source zombie ID collision passed player action boundary")
        BanditZombie.Cache[1] = nil

        __step = "installed-gate"
        local aTask = { eid = 1, saoWeekOneTargetKey = "player:Alice" }
        local bTask = { eid = 2 }
        local priorSmack = __sourceCalls.smack
        assert(ZombieActions.Smack.onStart(__body, bTask) == true
            and ZombieActions.Smack.onWorking(__body, bTask) == true
            and __sourceCalls.smack == priorSmack,
            "non-target player passed melee action boundary")
        assert(ZombieActions.Smack.onWorking(__body, aTask) == false
            and __damage.a == 1 and __damage.b == 0,
            "allowed exact target did not receive physical melee")
        local priorPush = __sourceCalls.push
        assert(ZombieActions.Push.onWorking(__body, bTask) == true
            and __sourceCalls.push == priorPush and __damage.b == 0,
            "non-target player passed shove boundary")
        ZombieActions.Push.onWorking(__body, aTask)
        assert(__damage.a == 2, "allowed exact target did not receive shove")
        __duplicateId = true
        local priorSmackWithAlias = __sourceCalls.smack
        assert(ZombieActions.Smack.onWorking(__body, aTask) == true
            and __sourceCalls.smack == priorSmackWithAlias
            and __damage.a == 2,
            "duplicate source player ID passed melee boundary")
        __duplicateId = false
        assert(Bandit.IsHostile(__body) == false
            and __brain.hostile == false and __brain.hostileP == false,
            "player action leaked global hostility")

        __step = "bullet-and-line"
        local item = { getWeaponPart = function() return nil end }
        local priorLine = __sourceCalls.line
        assert(BanditUtils.ManageLineOfFire(__body, __b, item) == false
            and __sourceCalls.line == priorLine,
            "non-target player passed line-of-fire boundary")
        assert(ZombieActions.Shoot.onComplete(__body, bTask) == true
            and __sourceCalls.line == priorLine,
            "non-target player fired source shoot action")
        ZombieActions.Shoot.onComplete(__body, aTask)
        assert(__sourceCalls.line == priorLine + 1
            and __damage.a == 3 and __damage.b == 0
            and __wakes == 1 and __sourceCalls.hit == 0,
            "bullet did not separate target from bystander")
        assert(BanditUtils.ManageLineOfFire(__body, __a, item,
            nil, true) == false and __b.burned ~= true
            and __sourceCalls.line == priorLine + 1,
            "incendiary ray bypassed bystander permission")
        local priorDamage = __damage.b
        PlayerDamageModel.MeleeHit(__body, __b, item)
        PlayerDamageModel.BulletHit(__body, item, __b)
        assert(__damage.b == priorDamage,
            "direct player damage sink bypassed Standing")

        __step = "changed-body"
        __body.md.SAOWeekOneBorn = 99
        assert(T.canAttackPlayer(__body, __a) == false
            and ZombieActions.Smack.onWorking(__body, aTask) == true
            and __damage.a == 3,
            "changed source body retained combat permission")
        __body.md.SAOWeekOneBorn = 12.5
        __bodyCurrent = false
        assert(T.canAttackPlayer(__body, __a) == false,
            "stale crosswalk retained combat permission")
        __bodyCurrent = true

        __step = "foreign-route"
        local foreignCalls = __sourceCalls.smack
        assert(ZombieActions.Smack.onWorking(__foreign,
            {eid = 2}) == false and __sourceCalls.smack == foreignCalls + 1
            and __damage.b == 1,
            "foreign Bandits2 route changed")
        assert(__brain.hostile == false and __brain.hostileP == false,
            "global hostility changed after physical action")
    end)
    if not ok then return "FAIL:" .. __step .. ":" .. tostring(err) end
    return "PASS"
end
