local checks = 0
local function check(ok, name)
    assert(ok, name)
    checks = checks + 1
end
local function close(a,b) return math.abs(a-b) < 0.000001 end
local records, represented = {}, {}
local faults = {}
SAO.Log.line = function(_, text)
    if string.find(text, "fault", 1, true) then faults[#faults+1] = text end
end
SAO.Identity.all = function() return records end
SAO.Identity.get = function(id) return records[id] end
SAO.History.countyHours = function() return __hours end
SAO.History.countyTimeOfDay = function() return 12 end
SAO.History.ticks = function() return __tick end
SAO.History.speedModOf = function() return 1 end
SAO.Standing.fallHasCome = function() return true, 'after' end
SAO.Standing.driftStandings = function() end
SAO.Body.hasRepresentation = function(id) return represented[id] ~= nil end
SAO.Body.get = function(id) return represented[id] end
SAO.Body.recover = function() return true end
SAO.WorldSources.reconcileReservations = function() end
SAO.WorldSources.ownsActor = function() return false end
SAO.WorldSources.pendingActionFor = function() return nil end
SAO.Perception.learnGroundNear = function() end
SAO.PopulationAdmissions.ensurePopulation = function() end
SAO.PopulationAdmissions.genesisSettled = function() return true end
SAO.PopulationRepresentation.inhabitKnox = function() end
SAO.DormantPopulation.dormantAttrition = function() end
SAO.DormantPopulation.dormantSettle = function() end
SAO.DormantPopulation.dormantProvision = function() end
SAO.DormantPopulation.dormantEncounters = function() end
SAO.Population.commitBodyFacts = function() end
local history = ModData.getOrCreate('SurvivorAwareness_Standing')
history.yearsAsked, history.yearsOwed, history.yearsRun = true,0,0
history.yearsTicks, history.countySettled = 0,true
local reach = SAO.Places.comfortHorizon()
__tick = 110000

local function person()
    records, represented = {}, {}
    local rec = {id='saved',forename='Saved',surname='Person',x=100,y=200,z=0,
        homeX=100,homeY=200,homeZ=0,dayGoalX=10000,dayGoalY=200,
        nextDormantMoveAt=0,lastWalkHours=2,epistemicMonths=1,kitGranted=true,
        dormantSleeping=false,dormantPhysiologyOrigin='generated-default',
        dormantFatigue=0,dormantEndurance=1,dormantSleepNeed=1,dormantPhysiologyAtHours=12,
        lastWaterDay=0,lastFoodDay=0,lastRiskDay=0}
    records.saved=rec
    return rec
end
local function step(rec, now)
    __hours=now;__tick=__tick+240;rec.nextDormantMoveAt=0
    SAO.DormantPopulation.dormantLife({},__tick)
end

local rec=person()
represented.saved={}
step(rec,12)
check(rec.x==100 and rec.lastWalkHours==2,'represented-body travel changed')
-- Exercise the production physical checkpoint producer, as save/release does.
SAO.BodySnapshot.commit(rec,{packed='saved-native-snapshot',hours=12,x=100,y=200,z=0,facts={}})
check(rec.releasedAtHours==12 and rec.lastWalkHours==2,'checkpoint boundary was not retained')
represented.saved=nil
step(rec,12)
check(rec.x==100,'represented interval replayed as dormant travel')
step(rec,13)
check(close(rec.x,100+reach/24),'real post-release dormant interval lost')
step(rec,14)
check(close(rec.x,100+reach*2/24),'physical boundary repeatedly spent or double counted')

rec=person();rec.releasedAtHours=12
step(rec,14)
check(close(rec.x,100+reach*2/24),'reloaded checkpoint replayed represented travel')
rec=person();rec.lastWalkHours=13;rec.releasedAtHours=12
step(rec,14)
check(close(rec.x,100+reach/24),'later dormant clock was discarded')
rec=person();rec.lastWalkHours=nil;rec.releasedAtHours=12
step(rec,13)
check(close(rec.x,100+reach/24),'checkpoint-only old save lost real elapsed travel')
rec=person();rec.lastWalkHours=nil
step(rec,13)
check(rec.x==100,'unknown legacy interval invented travel')
rec=person();rec.releasedAtHours=nil
step(rec,3)
check(close(rec.x,100+reach/24),'ordinary legacy dormant rate changed')
for _,bad in ipairs({'old',-1,math.huge,0/0}) do
    rec=person();rec.releasedAtHours=bad
    step(rec,3)
    check(close(rec.x,100+reach/24),'malformed physical boundary changed valid legacy travel')
end
rec=person();rec.releasedAtHours=15
step(rec,14)
check(rec.x==100,'future physical boundary invented travel')

-- Run the actual population callback and actual representation-band consumer.
-- Only native Body.materialize is controlled; it must see the saved coordinates
-- before any dormant owner advances that person. Both regional centers count.
local attempts = {}
SAO.Participants={residencyCenter=function() return 0,0,0 end,
    residencyCenters=function() return {{x=0,y=0,z=0},{x=100,y=200,z=0}} end}
SAO.Controller={adopt=function() end}
SAO.Body.materialize=function(r)
    attempts[#attempts+1]={x=r.x,y=r.y}
    local body={getX=function() return r.x end,getY=function() return r.y end,getZ=function() return r.z end}
    represented[r.id]=body
    return body
end
rec=person();rec.releasedAtHours=12
__hours=14;__tick=__tick+1000
SAO.Population.onTick()
check(#attempts==1 and attempts[1].x==100 and attempts[1].y==200,'dormant movement ran before native admission')
check(represented.saved~=nil and rec.x==100,'nearby resumed person did not reach representation owner')
check(#faults==0,'production population callback fault: '..tostring(faults[1]))

-- A refusal preserves the exact real dormant interval; arrival/admission is
-- never fabricated. The next pass may retry through the normal band owner.
SAO.Body.materialize=function(r) attempts[#attempts+1]={x=r.x,y=r.y};return nil,'fixture-native-refusal' end
rec=person();rec.releasedAtHours=12
__hours=13;__tick=__tick+1000
SAO.Population.onTick()
check(attempts[#attempts].x==100 and represented.saved==nil,'refused native admission became representation')
check(close(rec.x,100+reach/24),'native refusal replayed already represented hours')

-- Historical catch-up calls the existing dormant owner without physical
-- reification. Its rate and absence of a release timestamp stay unchanged.
rec=person();rec.lastWalkHours=0;rec.releasedAtHours=nil
local before=#attempts
step(rec,24)
check(close(rec.x,100+reach) and #attempts==before,'historical dormant day changed')
RESULT='PASS population resume '..checks
