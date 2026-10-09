local origin = "BanditsWeekOne"
local first = {id = 101, born = 3.5, clan = "same",
    hostile = true, saoWeekOneOrigin = origin}
local second = {id = 102, born = 4.5, clan = "same",
    hostile = true, saoWeekOneOrigin = origin}
local foreign = {id = 103, born = 5.5, clan = "other", hostile = true}
local function body(brain, personId)
    local b = {brain = brain, alive = true, marker = {
        SAOWeekOneOrigin = origin, SAOWeekOneBrainId = brain.id,
        SAOWeekOneBorn = brain.born, SAOWeekOnePersonId = personId}}
    b.getModData = function(self) return self.marker end
    b.isAlive = function(self) return self.alive end
    return b
end
local bodies = {[101] = body(first, "sao-a"),
    [102] = body(second, "sao-b")}
local current = true
local hostile = {}
local groups = {}
local sourceCalls = 0
BanditZombie = {GetInstanceById = function(id) return bodies[id] end}
BanditUtils = {AreEnemies = function(a, b)
    sourceCalls = sourceCalls + 1
    if not a or not b then return true end
    return (a.clan ~= b.clan and (a.hostile or b.hostile))
        or a.loyal and b.hostileP or b.loyal and a.hostileP or false
end}
SAO = {Standing = {
    isHostileTo = function(a, b) return hostile[a .. ":" .. b] == true end,
    groupOf = function(id) return groups[id] end,
}, WeekOneContinuity = {sourceBodyFor = function(personId)
    if not current then return nil end
    if personId == "sao-a" then return bodies[101], first end
    if personId == "sao-b" then return bodies[102], second end
    return nil
end}}
Events = {OnGameBoot = {Add = function() end},
    OnGameStart = {Add = function() end}}

function __safeInterpersonCombat()
    local ok, err = pcall(function()
        local combat = SAO.WeekOneInterpersonCombat
        assert(combat and combat.ready() == true,
            "SAO interperson relation adapter did not install")
        local sourceAtStart = sourceCalls
        assert(BanditUtils.AreEnemies(first, second) == false
            and sourceCalls == sourceAtStart,
            "source clan/global hostility still authorizes two SAO people")
        hostile["sao-a:sao-b"] = true
        assert(BanditUtils.AreEnemies(first, second) == true
            and BanditUtils.AreEnemies(second, first) == true,
            "one SAO Standing conflict did not reach physical source action")
        groups["sao-a"], groups["sao-b"] = "household", "household"
        assert(BanditUtils.AreEnemies(first, second) == false,
            "same SAO group received conflict permission")
        groups["sao-b"] = nil
        hostile["sao-a:sao-b"] = false
        assert(BanditUtils.AreEnemies(first, second) == false,
            "removed SAO Standing conflict stayed physical")
        hostile["sao-b:sao-a"] = true
        assert(BanditUtils.AreEnemies(first, second) == true,
            "reverse person Standing conflict was ignored")
        hostile["sao-b:sao-a"] = false
        hostile["sao-a:sao-b"] = true
        bodies[101].marker.SAOWeekOneBorn = 99
        assert(BanditUtils.AreEnemies(first, second) == false,
            "changed source body retained person combat authority")
        bodies[101].marker.SAOWeekOneBorn = first.born
        current = false
        assert(BanditUtils.AreEnemies(first, second) == false,
            "lost SAO crosswalk retained person combat authority")
        current = true
        bodies[102].alive = false
        assert(BanditUtils.AreEnemies(first, second) == false,
            "dead source proxy retained person combat authority")
        bodies[102].alive = true
        hostile["sao-a:sao-b"] = false
        local beforeForeign = sourceCalls
        assert(BanditUtils.AreEnemies(first, foreign) == false
            and BanditUtils.AreEnemies(foreign, first) == false
            and sourceCalls == beforeForeign,
            "mixed relation promoted a marked person's source hostility")
        assert(BanditUtils.AreEnemies(foreign, {clan='third', hostile=true}) == true
            and sourceCalls == beforeForeign + 1,
            "two unmarked source actors lost their relation")
        assert(BanditUtils.AreEnemies(nil, first) == true,
            "ordinary zombie case lost source physical conflict")
        groups["sao-a"] = nil
        hostile["sao-a:sao-a"] = true
        assert(BanditUtils.AreEnemies(first, first) == false,
            "same SAO person could fight itself")
        local exact = BanditUtils.AreEnemies
        BanditUtils.AreEnemies = function() return true end
        assert(combat.ready() == false and combat.install() == false,
            "replaced source relation was silently accepted")
        BanditUtils.AreEnemies = exact
        assert(combat.ready() == true,
            "restored exact relation adapter remained unavailable")
    end)
    if not ok then return "FAIL:" .. tostring(err) end
    return "PASS"
end
