-- Independent computational contestants. Neither reads or judges the other.
-- This initial model is not trained awareness. Its associations describe
-- possibilities; no function grants recipes, skills, access or native effects.
SAO = SAO or {}
SAO.CognitiveModels = SAO.CognitiveModels or {}
local M = SAO.CognitiveModels
local VERSION = {ordinary="sao-ordinary/3",associative="sao-associative/3"}
local PREVIOUS_VERSION = {ordinary="sao-ordinary/2",associative="sao-associative/2"}
local LEGACY_VERSION = {ordinary="sao-ordinary/1",associative="sao-associative/1"}
local MAX_BELIEFS, MAX_HYPOTHESES, MAX_EVENTS = 32, 32, 256
local CONFIDENCE_HALF_LIFE_HOURS = 24
local ACTIONS = { "food", "water", "inspect", "continue" }
local FRAME_KEYS = { id=true, actorId=true, worldHours=true, hunger=true,
    thirst=true, fatigue=true, eatAt=true, drinkAt=true, foodAllowed=true,
    waterAllowed=true, inspectionAllowed=true, knownFood=true, knownWater=true,
    knownPlaces=true, capabilities=true, priorIntent=true }
local EVENT_KEYS = { id=true, actorId=true, observerId=true, worldHours=true, consumerId=true,
    entityId=true, recipeId=true, originalFixtureSourceId=true,
    siteKey=true, siteX=true, siteY=true, siteZ=true, feedsFixture=true,
    kind=true, category=true, sourceId=true, itemType=true, perspective=true,
    status=true, foodPresent=true, waterPresent=true, hungerDelta=true,
    thirstDelta=true, detail=true, capabilities=true, itemId=true,
    occurredAtHours=true, stats=true, beforeCookingTime=true,
    afterCookingTime=true, heatObserved=true, consumedAmount=true, quantityUnit=true, actionKind=true, apertureState=true, succeeded=true,
    beforeValue=true, afterValue=true, durationHours=true,
    effectMetric=true, conditionLoss=true, headConditionLoss=true,
    soundId=true, sourceBrainId=true, sourceBorn=true, sourceBodyId=true,
    observerBrainId=true, observerBorn=true,
    decisionAtTick=true, claimOwner=true, sourceProgram=true,
    sourceStage=true, startedAtHours=true, nativeCompletedAtHours=true,
    pulseId=true, sourceEpoch=true,
    sourceSequence=true, soundHandle=true, nativeClock=true,
    nativeEmittedAtHours=true, nativeHeardAtHours=true,
    nativeWitnessedAtHours=true, nativeClaimedAtHours=true,
    partnerId=true,processId=true,processRevision=true,musicKey=true,role=true,
    sourceWorkSequence=true }
local HOBBY_KINDS={ ["leisure-meditation"]=true,["leisure-exercise"]=true,
    ["leisure-art"]=true,["leisure-music"]=true,["leisure-games"]=true,["leisure-radio"]=true,["leisure-lifestyle"]=true,
    ["leisure-duet"]=true,["leisure-dance"]=true }
local HOBBY_SOURCES={LifestyleHobbies=true,["native:ISFitnessAction"]=true,["KnoxAquarium:KA_Comfort"]=true,NewMusic=true,
    ["LifestyleHobbies:paint-canvas"]=true,["LifestyleHobbies:appraise-art"]=true,
    ["LifestyleHobbies:sculpt-Hedge"]=true,["LifestyleHobbies:sculpt-Wood"]=true,
    ["LifestyleHobbies:sculpt-Metal"]=true,["LifestyleHobbies:sculpt-Stone"]=true,["LifestyleHobbies:sculpt-Ice"]=true}
HOBBY_SOURCES["Lifestyle:LSYogaAction"]=true
HOBBY_SOURCES["FWO:FWOTreadmillBenchpressExercise"]=true
HOBBY_SOURCES["LifestyleHobbies:LSPingPong/fakeRival"]=true
HOBBY_SOURCES["native:RecipeCodeOnCreate.drawRandomCard"]=true
HOBBY_SOURCES["native:RecipeCodeOnCreate.rollDice"]=true
HOBBY_SOURCES["native:ISRadioInteractions"]=true
for _,class in ipairs({"PZPongGame","PZSnakeGame","PZMinesweeperGame","PZTetrisGame","PZSpaceInvadersGame",
    "PZDoomGame","PZRacerGame","PZFlappyGame","PZBreakoutGame","PZAsteroidsGame","PZFroggerGame",
    "PZMissileCommandGame","PZLunarLanderGame","PZCircuitRunnerGame","PZMemoryMatchGame","PZStarPilotGame",
    "PZCaveRunnerGame","PZLightsOutGame","PZSignalMatchGame","PZBoxPushGame","PZTileSlideGame",
    "PZPipeLinkGame","PZCodeBreakerGame","PZOutbreakOpsGame"}) do HOBBY_SOURCES["ComputerModkum:"..class]=true end
for _,machine in ipairs({"ArcadeMachine1","ArcadeMachine2","ArcadeStreetFighter","ArcadePacman",
    "ArcadeDoubleDragon","ArcadeSpaceInvaders","ArcadeDonkeyKong","ArcadeCentipede","ArcadeDigDug",
    "ArcadeNBAJam","ArcadeTMNT","ArcadeMK","ComplexTerminator2","ComplexStarWars","PinballMachine",
    "PinballAddamsFamily","PinballTwilightZone","PinballIndianaJones","PinballBlackKnight2000",
    "PinballFunHouse","PinballElviraPartyMonsters","PinballMarioBros"}) do
    HOBBY_SOURCES["ProjectArcade:ProjectArcade_PlayArcadeTimedAction:"..machine]=true
end
local COLLECTOR_ENTITIES = { ["Base.RainCollector"]=true, ["Base.RainCollectorRound"]=true,
    ["Base.RainCollector_Tarp"]=true, ["Base.RainCollectorRound_Tarp"]=true }
local EXTENDED = { ["generator-operation"]=true, ["medication-use"]=true, ["physical-change"]=true, preparation=true, plumbing=true, ["collector-construction"]=true,
    ["animal-care"]=true, ["window-repair"]=true, ["material-crafting"]=true, ["tool-repair"]=true, ["entry-outcome"]=true, ["recovery-outcome"]=true, ["study-outcome"]=true, ["commitment-outcome"]=true, ["instrument-use"]=true, ["leisure-reading"]=true,
    ["leisure-meditation"]=true,["leisure-exercise"]=true,["leisure-art"]=true,["leisure-music"]=true,["leisure-games"]=true,["leisure-radio"]=true,["leisure-lifestyle"]=true,
    ["leisure-duet"]=true,["leisure-dance"]=true,["weekone-instrument-performance"]=true,
    ["weekone-performance-hearing"]=true }
local STATS = { "HUNGER", "THIRST", "FATIGUE", "ENDURANCE", "PANIC", "STRESS",
    "NICOTINE_WITHDRAWAL", "BOREDOM", "UNHAPPINESS", "DISCOMFORT", "INTOXICATION", "ANGER", "PAIN" }
local STAT_KEYS = {} for _,name in ipairs(STATS) do STAT_KEYS[name]=true end
local CAPABILITIES = { cook="manufacturing", forage="agriculture", treat="medicine" }
-- A relational grammar, not an unlock sequence. Rules state possible
-- analogies and their missing mechanisms, never that an operation exists.
local RULES = {
    { from="contain", into="retain", branch="logistics-preservation",
      missing="Retention duration, loss and spoilage are unmeasured." },
    { from="convey", into="transfer", branch="logistics-preservation",
      missing="A usable transfer interface and its losses are unknown." },
    { from="operate", into="regulate", branch="manufacturing",
      missing="A controllable input and its effect have not been demonstrated." },
    { from="retain", into="regulate", branch="manufacturing",
      missing="Whether thermal or other control preserves this property is unknown." },
    { from="regulate", into="transfer", branch="electrical-systems",
      missing="A usable energy source and conversion mechanism are unknown." },
    { from="transfer", into="separate", branch="metallurgy-materials",
      missing="Selective separation and compatible material properties are unknown." },
    { from="transform", into="regulate", branch="manufacturing",
      missing="Repeatability, safe heating ranges and apparatus controls remain untested." },
}

local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function unit(n) return finite(n) and n>=0 and n<=1 end
local function text(s, limit) return type(s)=="string" and #s>0 and #s<=limit end
local function clamp(n) return math.max(0, math.min(1, n)) end
local function plainKeys(value, keys)
    if type(value)~="table" then return false end
    for key in pairs(value) do if not keys[key] then return false end end
    return true
end
local function capabilities(value)
    if type(value)~="table" then return false end
    for key, enabled in pairs(value) do
        if not CAPABILITIES[key] or type(enabled)~="boolean" then return false end
    end
    return true
end
local function model(id) return id=="ordinary" or id=="associative" end
local function occurrencePosition(e)
    local prefix=e.kind=="medication-use" and "medication/"
        or e.kind=="physical-change" and "physical/"
        or e.kind=="preparation" and ("cooking/"..e.actorId.."/")
        or e.kind=="generator-operation" and ("generator/"..e.actorId.."/")
        or e.kind=="animal-care" and ("animal-care/"..e.actorId.."/")
        or e.kind=="window-repair" and (e.actorId.."/window-result/")
        or e.kind=="material-crafting" and ("resource-production/"..e.actorId.."/")
        or (e.kind=="tool-repair" or e.kind=="plumbing" or e.kind=="collector-construction") and ("resource-production/"..e.actorId.."/")
        or e.kind=="entry-outcome" and ("entry/"..e.actorId.."/")
        or e.kind=="recovery-outcome" and ("recovery/"..e.actorId.."/")
        or e.kind=="study-outcome" and ("study/"..e.actorId.."/")
        or e.kind=="commitment-outcome" and ("commitment/"..e.actorId.."/")
        or e.kind=="instrument-use" and ("instrument/"..e.actorId.."/")
        or e.kind=="leisure-reading" and ("leisure-reading/"..e.actorId.."/")
        or e.kind=="weekone-instrument-performance" and ("weekone-instrument-performance/"..e.actorId.."/")
        or e.kind=="weekone-performance-hearing" and "weekone-heard/"
        or HOBBY_KINDS[e.kind] and (e.kind.."/"..e.actorId.."/") or nil
    if not prefix or not text(e.id,128) or string.sub(e.id,1,#prefix)~=prefix then return nil end
    local suffix=string.sub(e.id,#prefix+1)
    local position=tonumber(suffix)
    if not finite(position) or position<(e.kind=="physical-change" and 0 or 1)
        or position>9007199254740991 or position~=math.floor(position)
        or tostring(position)~=suffix then return nil end
    return position
end
local function validPositions(value)
    if value==nil then return true end
    if type(value)~="table" then return false end
    for kind,position in pairs(value) do
        local n=tonumber(position)
        if not EXTENDED[kind] or not text(position,32) or not finite(n)
            or n<0 or n>9007199254740991 or n~=math.floor(n) then return false end
    end
    return true
end
local function action(id)
    for _, candidate in ipairs(ACTIONS) do if candidate==id then return true end end
    return false
end
local function validFrame(f)
    if not plainKeys(f, FRAME_KEYS) or not text(f.id,128)
        or not text(f.actorId,128) or not finite(f.worldHours) or f.worldHours<0
        or not capabilities(f.capabilities) then return false end
    for _, key in ipairs({"hunger","thirst","fatigue","eatAt","drinkAt"}) do
        if not unit(f[key]) then return false end
    end
    for _, key in ipairs({"foodAllowed","waterAllowed","inspectionAllowed"}) do
        if type(f[key])~="boolean" then return false end
    end
    for _, key in ipairs({"knownFood","knownWater","knownPlaces"}) do
        if not finite(f[key]) or f[key]<0 or f[key]>100000 or f[key]~=math.floor(f[key]) then return false end
    end
    return f.priorIntent==nil or action(f.priorIntent)
end
local GENERATOR_EVENT_KEYS = {id=true, actorId=true, observerId=true, worldHours=true,
    occurredAtHours=true, kind=true, category=true, sourceId=true, consumerId=true,
    perspective=true, status=true, actionKind=true, succeeded=true,
    itemId=true, itemType=true, beforeValue=true, afterValue=true, capabilities=true}
local GENERATOR_OPERATIONS = {inspect=true, repair=true, fuel=true, connect=true,
    activate=true, ["verify-power"]=true}
local function validEvent(e)
    if not plainKeys(e, EVENT_KEYS) or not text(e.id,128)
        or not text(e.actorId,128) or not text(e.observerId,128)
        or not finite(e.worldHours) or e.worldHours<0
        or (e.kind~="inspection" and e.kind~="acquire" and e.kind~="store" and e.kind~="consume" and not EXTENDED[e.kind])
        or (e.category~="food" and e.category~="water" and e.category~="container" and e.category~="medicine" and e.category~="body" and e.category~="animal" and e.category~="construction" and e.category~="learning" and e.category~="social" and e.category~="leisure" and e.category~="utilities")
        or (e.status~="completed" and e.status~="no-effect"
            and e.status~="interrupted" and e.status~="unavailable")
        or (e.perspective~="performed" and e.perspective~="observed") then return false end
    if e.kind=="generator-operation" then
        if not plainKeys(e, GENERATOR_EVENT_KEYS) or e.category~="utilities"
            or e.status~="completed" or e.perspective~="performed" or e.actorId~=e.observerId
            or not finite(e.occurredAtHours) or e.occurredAtHours<0 or e.occurredAtHours>e.worldHours
            or not occurrencePosition(e) or not text(e.sourceId,160) or e.sourceId:sub(1,2)~="J:"
            or not text(e.consumerId,160) or e.consumerId:sub(1,2)~="E:"
            or not GENERATOR_OPERATIONS[e.actionKind] or e.succeeded~=true
            or e.capabilities~=nil and not capabilities(e.capabilities) then return false end
        if e.actionKind=="repair" or e.actionKind=="fuel" then
            local maximum=e.actionKind=="repair" and 100 or 10
            return finite(e.itemId) and e.itemId==math.floor(e.itemId)
                and e.itemId>=-2147483648 and e.itemId<=2147483647 and text(e.itemType,160)
                and finite(e.beforeValue) and finite(e.afterValue) and e.beforeValue>=0
                and e.afterValue>e.beforeValue and e.afterValue<=maximum
        end
        return e.itemId==nil and e.itemType==nil and e.beforeValue==nil and e.afterValue==nil
    end
    if e.category=="utilities" or e.consumerId~=nil then return false end
    if e.kind ~= "tool-repair" and (e.effectMetric ~= nil or e.conditionLoss ~= nil or e.headConditionLoss ~= nil) then return false end
    if e.kind ~= "collector-construction" and (e.entityId ~= nil or e.recipeId ~= nil
        or e.originalFixtureSourceId ~= nil or e.siteKey ~= nil or e.siteX ~= nil
        or e.siteY ~= nil or e.siteZ ~= nil or e.feedsFixture ~= nil) then return false end
    local behavior=e.kind=="entry-outcome" or e.kind=="recovery-outcome"
    if not behavior and (e.kind~="commitment-outcome" and e.kind~="instrument-use" and e.kind~="leisure-reading" and e.kind~="weekone-instrument-performance" and not HOBBY_KINDS[e.kind] and (e.actionKind~=nil or e.succeeded~=nil) or e.apertureState~=nil
        or e.kind~="study-outcome" and e.kind~="tool-repair" and (e.beforeValue~=nil or e.afterValue~=nil) or e.durationHours~=nil) then return false end
    if e.category=="learning" and e.kind~="study-outcome" or e.category=="social" and e.kind~="commitment-outcome" then return false end
    if e.kind=="weekone-performance-hearing" then
        local position=occurrencePosition(e)
        return position~=nil and e.category=="leisure" and e.status=="completed"
            and e.perspective=="observed" and e.actorId~=e.observerId
            and string.sub(e.actorId,1,4)=="bwo-"
            and e.sourceId=="BanditsWeekOne:SAOPerform"
            and e.itemId==nil and e.itemType==nil and e.actionKind==nil
            and e.succeeded==nil and e.stats==nil and e.detail==nil
            and e.foodPresent==nil and e.waterPresent==nil
            and e.hungerDelta==nil and e.thirstDelta==nil
            and e.consumedAmount==nil and e.quantityUnit==nil
            and e.sourceBodyId==nil and e.decisionAtTick==nil
            and e.claimOwner==nil and e.sourceProgram==nil
            and e.sourceStage==nil and e.startedAtHours==nil
            and e.nativeCompletedAtHours==nil
            and e.beforeCookingTime==nil and e.afterCookingTime==nil
            and e.heatObserved==nil and e.episodeId==nil
            and text(e.sourceEpoch,36) and #e.sourceEpoch==36
            and text(e.pulseId,56) and text(e.soundId,96)
            and finite(e.sourceSequence) and e.sourceSequence>=1
            and e.sourceSequence<=9007199254740991
            and e.sourceSequence==math.floor(e.sourceSequence)
            and e.pulseId==e.sourceEpoch.."-"..tostring(e.sourceSequence)
            and finite(e.sourceBrainId) and e.sourceBrainId==math.floor(e.sourceBrainId)
            and e.sourceBrainId>=-2147483648 and e.sourceBrainId<=2147483647
            and finite(e.sourceBorn) and math.abs(e.sourceBorn)<=1000000000000
            and ((e.observerBrainId==nil and e.observerBorn==nil)
                or (finite(e.observerBrainId)
                    and e.observerBrainId==math.floor(e.observerBrainId)
                    and e.observerBrainId>=-2147483648
                    and e.observerBrainId<=2147483647
                    and finite(e.observerBorn)
                    and math.abs(e.observerBorn)<=1000000000000))
            and finite(e.soundHandle) and e.soundHandle>=1
            and e.soundHandle<=9007199254740991
            and e.soundHandle==math.floor(e.soundHandle)
            and e.nativeClock=="native-world-age-hours"
            and finite(e.nativeEmittedAtHours) and e.nativeEmittedAtHours>=0
            and finite(e.nativeHeardAtHours)
            and e.nativeHeardAtHours>=e.nativeEmittedAtHours
            and finite(e.nativeWitnessedAtHours)
            and e.nativeWitnessedAtHours>=e.nativeHeardAtHours
            and finite(e.nativeClaimedAtHours)
            and e.nativeClaimedAtHours>=e.nativeWitnessedAtHours
            and finite(e.occurredAtHours) and e.occurredAtHours>=0
            and e.occurredAtHours<=e.worldHours
    end
    if e.kind~="leisure-duet" and e.kind~="leisure-dance" and (e.partnerId~=nil or e.processId~=nil
        or e.processRevision~=nil or e.sourceWorkSequence~=nil) then return false end
    if e.kind~="leisure-dance" and (e.musicKey~=nil or e.role~=nil) then return false end
    if e.observerBrainId~=nil or e.observerBorn~=nil then return false end
    if e.pulseId~=nil or e.sourceEpoch~=nil or e.sourceSequence~=nil
        or e.soundHandle~=nil or e.nativeClock~=nil
        or e.nativeEmittedAtHours~=nil or e.nativeHeardAtHours~=nil
        or e.nativeWitnessedAtHours~=nil or e.nativeClaimedAtHours~=nil then return false end
    if e.category=="leisure" and e.kind~="instrument-use" and e.kind~="leisure-reading" and e.kind~="weekone-instrument-performance" and not HOBBY_KINDS[e.kind] then return false end
    if e.kind~="weekone-instrument-performance" and (e.soundId~=nil or e.sourceBrainId~=nil
        or e.sourceBorn~=nil or e.sourceBodyId~=nil or e.decisionAtTick~=nil
        or e.claimOwner~=nil or e.sourceProgram~=nil or e.sourceStage~=nil
        or e.startedAtHours~=nil or e.nativeCompletedAtHours~=nil) then return false end
    if e.kind~="animal-care" and (e.consumedAmount~=nil or e.quantityUnit~=nil) then return false end
    if e.category=="animal" and e.kind~="animal-care" then return false end
    if e.category=="construction" and e.kind~="window-repair" and e.kind~="material-crafting" and e.kind~="tool-repair" and e.kind~="plumbing" and e.kind~="collector-construction" then return false end
    if e.capabilities~=nil and not capabilities(e.capabilities) then return false end
    for _, key in ipairs({"sourceId","itemType"}) do
        if e[key]~=nil and not text(e[key],160) then return false end
    end
    if e.detail~=nil and (type(e.detail)~="string" or #e.detail>512) then return false end
    for _, key in ipairs({"foodPresent","waterPresent"}) do
        if e[key]~=nil and type(e[key])~="boolean" then return false end
    end
    for _, key in ipairs({"hungerDelta","thirstDelta"}) do
        if e[key]~=nil and (not finite(e[key]) or math.abs(e[key])>1) then return false end
    end
    if EXTENDED[e.kind] then
        if e.perspective~="performed" or e.actorId~=e.observerId
            or e.foodPresent~=nil or e.waterPresent~=nil or e.hungerDelta~=nil or e.thirstDelta~=nil
            or not finite(e.occurredAtHours) or e.occurredAtHours<0
            or e.occurredAtHours>e.worldHours or not occurrencePosition(e) then return false end
        if behavior then
            if e.category~="body" or e.status~="completed" or type(e.succeeded)~="boolean"
                or e.itemId~=nil or e.itemType~=nil or e.stats~=nil
                or e.beforeCookingTime~=nil or e.afterCookingTime~=nil or e.heatObserved~=nil then return false end
            if e.kind=="entry-outcome" then
                return text(e.sourceId,160) and (e.actionKind=="door" or e.actionKind=="window")
                    and (e.apertureState=="open" or e.apertureState=="closed" or e.apertureState=="clear"
                        or e.apertureState=="smashed" or e.apertureState=="barricaded" or e.apertureState=="unknown")
                    and e.beforeValue==nil and e.afterValue==nil and e.durationHours==nil
            end
            return e.sourceId==nil and e.apertureState==nil and (e.actionKind=="sleep" or e.actionKind=="rest")
                and unit(e.beforeValue) and unit(e.afterValue) and finite(e.durationHours)
                and e.durationHours>0 and e.durationHours<=12
                and e.succeeded==(e.actionKind=="sleep" and e.afterValue<e.beforeValue
                    or e.actionKind=="rest" and e.afterValue>e.beforeValue)
        end
        if e.kind=="instrument-use" then
            return e.category=="leisure" and e.status=="completed"
                and e.sourceId=="native:sound:BlowHarmonica" and e.actionKind=="blow-harmonica"
                and type(e.succeeded)=="boolean" and text(e.itemType,160)
                and finite(e.itemId) and e.itemId==math.floor(e.itemId)
                and e.itemId>=-2147483648 and e.itemId<=2147483647 and e.stats==nil
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="weekone-instrument-performance" then
            local sounds={ ["Base.GuitarElectric"]="BWOInstrumentBassGuitar1",
                ["Base.Violin"]="BWOInstrumentViolinPaganini",
                ["Base.Saxophone"]="BWOInstrumentSax1" }
            return e.category=="leisure" and e.status=="completed"
                and e.sourceId=="BanditsWeekOne:SAOPerform"
                and e.actionKind=="perform-instrument" and e.succeeded==true
                and sounds[e.itemType]==e.soundId and finite(e.itemId)
                and e.itemId==math.floor(e.itemId) and e.itemId>=-2147483648
                and e.itemId<=2147483647 and finite(e.sourceBrainId)
                and e.sourceBrainId==math.floor(e.sourceBrainId)
                and e.sourceBrainId>=-2147483648 and e.sourceBrainId<=2147483647
                and e.sourceBodyId==e.sourceBrainId and finite(e.sourceBorn)
                and e.sourceBorn>=-1000000000000 and e.sourceBorn<=1000000000000
                and finite(e.decisionAtTick) and e.decisionAtTick>=0
                and e.decisionAtTick<=9007199254740991
                and e.decisionAtTick==math.floor(e.decisionAtTick)
                and e.claimOwner=="BanditsWeekOne"
                and text(e.sourceProgram,96) and text(e.sourceStage,96)
                and finite(e.startedAtHours) and e.startedAtHours>=0
                and (e.nativeCompletedAtHours==nil
                    and e.startedAtHours<=e.occurredAtHours
                    or finite(e.nativeCompletedAtHours)
                        and e.nativeCompletedAtHours>=e.startedAtHours)
                and e.stats==nil and e.beforeCookingTime==nil
                and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="leisure-duet" then
            return e.category=="leisure" and e.status=="completed"
                and e.perspective=="performed" and e.succeeded==true
                and e.actionKind=="duet" and e.sourceId=="LifestyleHobbies"
                and text(e.partnerId,128) and e.partnerId~=e.actorId
                and text(e.processId,160)
                and finite(e.processRevision) and e.processRevision>=1
                and e.processRevision<=9007199254740991
                and e.processRevision==math.floor(e.processRevision)
                and finite(e.sourceWorkSequence) and e.sourceWorkSequence>=1
                and e.sourceWorkSequence<=9007199254740991
                and e.sourceWorkSequence==math.floor(e.sourceWorkSequence)
                and e.itemId==nil and e.itemType==nil and e.stats==nil
                and e.beforeCookingTime==nil and e.afterCookingTime==nil
                and e.heatObserved==nil
        end
        if e.kind=="leisure-dance" then
            return e.category=="leisure" and e.status=="completed"
                and e.perspective=="performed" and e.succeeded==true
                and e.actionKind=="dance" and e.sourceId=="LifestyleHobbies"
                and text(e.partnerId,128) and e.partnerId~=e.actorId
                and text(e.processId,160) and text(e.musicKey,160)
                and (e.role=="source" or e.role=="target")
                and finite(e.processRevision) and e.processRevision>=1
                and e.processRevision<=9007199254740991
                and e.processRevision==math.floor(e.processRevision)
                and finite(e.sourceWorkSequence) and e.sourceWorkSequence>=1
                and e.sourceWorkSequence<=9007199254740991
                and e.sourceWorkSequence==math.floor(e.sourceWorkSequence)
                and e.itemId==nil and e.itemType==nil and e.stats==nil
                and e.beforeCookingTime==nil and e.afterCookingTime==nil
                and e.heatObserved==nil
        end
        if HOBBY_KINDS[e.kind] then
            return e.category=="leisure" and e.status=="completed" and type(e.succeeded)=="boolean"
                and text(e.sourceId,160) and HOBBY_SOURCES[e.sourceId] and text(e.actionKind,96)
                and e.itemId==nil and e.stats==nil and e.beforeCookingTime==nil
                and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="leisure-reading" then
            if e.category ~= "leisure" or e.status ~= "completed" or type(e.succeeded) ~= "boolean"
                or not text(e.itemType, 160) or not finite(e.itemId) or e.itemId ~= math.floor(e.itemId)
                or e.itemId < -2147483648 or e.itemId > 2147483647
                or e.beforeCookingTime ~= nil or e.afterCookingTime ~= nil or e.heatObserved ~= nil then return false end
            local note = e.actionKind == "read-note" and e.sourceId == "native:literature:customPages"
            local book = e.actionKind == "read-book" and e.sourceId == "native:literature:ISReadABook"
            if not note and not book then return false end
            if e.stats ~= nil then
                if not book or not e.succeeded or not plainKeys(e.stats, {BOREDOM=true, UNHAPPINESS=true, STRESS=true}) then return false end
                for _, name in ipairs({ "BOREDOM", "UNHAPPINESS", "STRESS" }) do
                    local v = e.stats[name]
                    if not plainKeys(v, {before=true, after=true}) or not finite(v.before) or not finite(v.after)
                        or v.before < 0 or v.after < 0 or v.before > 1000000 or v.after > 1000000 then return false end
                end
            end
            return true
        end
        if e.kind=="commitment-outcome" then
            return e.category=="social" and e.status=="completed" and text(e.sourceId,160)
                and (e.actionKind=="prepare" or e.actionKind=="deliver"
                    or e.actionKind=="watch-return") and e.succeeded==true
                and e.itemId==nil and e.itemType==nil and e.stats==nil
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="study-outcome" then
            return e.category=="learning" and e.status=="completed" and text(e.sourceId,160)
                and e.sourceId:sub(1,7)=="manual:" and text(e.itemType,160)
                and finite(e.itemId) and e.itemId==math.floor(e.itemId)
                and e.itemId>=-2147483648 and e.itemId<=2147483647
                and finite(e.beforeValue) and e.beforeValue>=0 and finite(e.afterValue)
                and e.afterValue>e.beforeValue and e.afterValue<=1000000000
                and e.stats==nil and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="physical-change" then
            if e.category~="body" or e.itemId~=nil or e.itemType~=nil or e.sourceId~=nil
                or e.beforeCookingTime~=nil or e.afterCookingTime~=nil or e.heatObserved~=nil
                or type(e.stats)~="table" then return false end
            local n=0
            for name,value in pairs(e.stats) do
                if not STAT_KEYS[name] or not plainKeys(value,{before=true,after=true})
                    or not finite(value.before) or not finite(value.after)
                    or math.abs(value.before)>1000000 or math.abs(value.after)>1000000
                    or value.before==value.after then return false end
                n=n+1
            end
            return n>0 and n<=#STATS
        end
        if e.stats~=nil or not text(e.itemType,160) or not finite(e.itemId)
            or e.itemId~=math.floor(e.itemId) or e.itemId< -2147483648 or e.itemId>2147483647 then return false end
        if e.kind=="animal-care" then
            return e.category=="animal" and text(e.sourceId,160)
                and string.match(e.sourceId,"^animal/%-?%d+$")~=nil
                and finite(e.consumedAmount) and e.consumedAmount>0 and e.consumedAmount<=1000000000
                and (e.quantityUnit=="uses" or e.quantityUnit=="fluid" or e.quantityUnit=="food-hunger")
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="window-repair" then
            return e.category=="construction" and e.status=="completed"
                and e.itemType=="RepairableWindows.LargeGlassPane" and text(e.sourceId,160)
                and (string.match(e.sourceId,"^window:%-?%d+:%-?%d+:%-?%d+:%d+:true$")~=nil
                    or string.match(e.sourceId,"^window:%-?%d+:%-?%d+:%-?%d+:%d+:false$")~=nil)
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="collector-construction" then
            if e.category~="construction" or e.status~="completed" or not COLLECTOR_ENTITIES[e.entityId]
                or not text(e.recipeId,160) or not text(e.sourceId,160) or e.sourceId:sub(1,2)~="F:"
                or not text(e.originalFixtureSourceId,160) or e.originalFixtureSourceId:sub(1,2)~="F:"
                or not text(e.siteKey,160) or type(e.feedsFixture)~="boolean"
                or e.beforeCookingTime~=nil or e.afterCookingTime~=nil or e.heatObserved~=nil then return false end
            for _,key in ipairs({"siteX","siteY","siteZ"}) do
                if not finite(e[key]) or e[key]~=math.floor(e[key]) or math.abs(e[key])>2147483647 then return false end
            end
            return e.siteKey==string.format("collector-site:%d:%d:%d",e.siteX,e.siteY,e.siteZ)
        end
        if e.kind=="plumbing" then
            return e.category=="construction" and e.status=="completed" and text(e.sourceId,160)
                and string.sub(e.sourceId,1,2)=="F:"
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="material-crafting" then
            return e.category=="construction" and e.status=="completed" and e.sourceId=="Base.SawLogs"
                and e.itemType=="Base.Plank" and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="tool-repair" then
            local sharp = e.sourceId=="Base.SharpenBlade" or e.sourceId=="Base.SharpenBladePoorlyWithFile"
            return e.category=="construction" and (e.sourceId=="Base.FixSaw" or sharp)
                and (sharp and e.effectMetric=="sharpness" or not sharp and (e.effectMetric==nil or e.effectMetric=="condition"))
                and (e.conditionLoss==nil or sharp and finite(e.conditionLoss) and e.conditionLoss>=0 and e.conditionLoss<=1000000000)
                and (e.headConditionLoss==nil or sharp and finite(e.headConditionLoss) and e.headConditionLoss>=0 and e.headConditionLoss<=1000000000)
                and finite(e.beforeValue) and (e.beforeValue>0 or sharp and e.beforeValue==0) and e.beforeValue<=1000000000
                and finite(e.afterValue) and e.afterValue>=0 and e.afterValue<=1000000000
                and (e.status=="completed" and e.afterValue>e.beforeValue
                    or e.status=="no-effect" and e.afterValue<=e.beforeValue)
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        if e.kind=="medication-use" then
            return e.category=="medicine" and e.sourceId==nil
                and e.beforeCookingTime==nil and e.afterCookingTime==nil and e.heatObserved==nil
        end
        return e.category=="food" and text(e.sourceId,160) and e.heatObserved==true
            and finite(e.beforeCookingTime) and e.beforeCookingTime>=0
            and finite(e.afterCookingTime) and e.afterCookingTime>e.beforeCookingTime
            and e.afterCookingTime<=1000000000
    end
    if e.category=="medicine" or e.category=="body" or e.itemId~=nil or e.occurredAtHours~=nil
        or e.stats~=nil or e.beforeCookingTime~=nil or e.afterCookingTime~=nil or e.heatObserved~=nil then return false end
    if e.kind=="inspection" and e.category~="container" then return false end
    if e.kind~="inspection" and (e.foodPresent~=nil or e.waterPresent~=nil) then return false end
    if e.kind~="consume" and (e.hungerDelta~=nil or e.thirstDelta~=nil) then return false end
    if e.kind=="consume" and e.category=="container" then return false end
    if e.perspective=="performed" then
        if e.actorId~=e.observerId then return false end
    elseif e.hungerDelta~=nil or e.thirstDelta~=nil
        or e.foodPresent~=nil or e.waterPresent~=nil
        or (e.kind~="acquire" and e.kind~="store") then return false end
    return true
end
-- The ledger uses this same strict boundary for the new private fact types.
-- It does not authenticate a native callback; its producer owns that receipt.
function M.acceptsExperience(e) return validEvent(e) end
local function validState(id, state)
    return model(id) and type(state)=="table" and state.modelId==id
        and (state.version==VERSION[id] or state.version==PREVIOUS_VERSION[id] or state.version==LEGACY_VERSION[id]) and type(state.beliefs)=="table"
        and validPositions(state.nativePositions)
        and type(state.beliefOrder)=="table" and type(state.hypotheses)=="table"
        and type(state.seen)=="table" and type(state.eventOrder)=="table"
        and #state.beliefOrder<=MAX_BELIEFS and #state.hypotheses<=MAX_HYPOTHESES
        and #state.eventOrder<=MAX_EVENTS
end
local function copyList(values, limit)
    local out={} for i=1,math.min(#(values or {}),limit) do out[i]=values[i] end return out
end
local function appendUnique(values, value, limit)
    for _, v in ipairs(values) do if v==value then return end end
    values[#values+1]=value
    if #values>limit then table.remove(values,1) end
end
local function posterior(b, hours)
    if not b then return 0.5 end
    hours=hours or b.lastHours or 0
    local support,against=0,0
    for _, sample in ipairs(b.samples) do
        -- Receipt facts stay intact. Only their present epistemic weight ages;
        -- reading at a later hour cannot acquire or strengthen knowledge.
        local weight=0.5^(math.max(0,hours-sample.hours)/CONFIDENCE_HALF_LIFE_HOURS)
        if sample.yes then support=support+weight else against=against+weight end
    end
    return (1+support)/(2+support+against)
end
local function status(b)
    if b.against>0 then return b.support>0 and "refined" or "falsified" end
    return b.support>0 and "supported" or "hypothesis"
end

function M.newState(modelId)
    if not model(modelId) then return nil,"unknown-model" end
    return { modelId=modelId, version=VERSION[modelId], revision=0, nextBelief=0,
        nextHypothesis=0, beliefs={}, beliefOrder={}, hypotheses={},
        seen={}, eventOrder={}, evictedThroughHours=-1,
        omittedBeliefs=0, omittedHypotheses=0, omittedEvents=0 }
end

local function remember(state, key, label, yes, e, relation, from, into)
    local b=state.beliefs[key]
    if not b then
        if #state.beliefOrder>=MAX_BELIEFS then
            local drop=1
            for i,k in ipairs(state.beliefOrder) do
                if string.sub(k,1,5)~="goal:" then drop=i break end
            end
            state.beliefs[table.remove(state.beliefOrder,drop)]=nil
            state.omittedBeliefs=state.omittedBeliefs+1
        end
        state.nextBelief=state.nextBelief+1
        b={ id=state.modelId.."/belief/"..tostring(state.nextBelief), key=key,
            label=string.sub(label,1,256), support=0, against=0, evidenceIds={},samples={},omittedSamples=0,
            relation=relation, from=from, into=into, branch="logistics-preservation" }
        state.beliefs[key]=b state.beliefOrder[#state.beliefOrder+1]=key
    end
    if yes then b.support=b.support+1 else b.against=b.against+1 end
    b.samples[#b.samples+1]={id=e.id,hours=e.worldHours,yes=yes}
    if #b.samples>8 then table.remove(b.samples,1) b.omittedSamples=b.omittedSamples+1 end
    b.lastHours=math.max(b.lastHours or e.worldHours,e.worldHours)
    b.confidence=posterior(b) b.status=status(b)
    appendUnique(b.evidenceIds,e.id,8)
    return b
end
local function relation(state, verb, from, into, yes, e, branch)
    return remember(state,"relation:"..verb..":"..from..":"..into,
        verb.."("..from..", "..into..") observed association",yes,e,verb,from,into,branch)
end
local function mergeEvidence(roots)
    local out={}
    for _, root in ipairs(roots) do
        for _, id in ipairs(root.evidenceIds) do appendUnique(out,id,8) end
    end
    return out
end

local function rebuildHypotheses(state, maxDepth, contexts)
    local prior={}
    for _, h in ipairs(state.hypotheses) do prior[h.key]=h end
    local output, keys, roots={}, {}, {}
    local omitted=0
    for _, key in ipairs(state.beliefOrder) do
        local b=state.beliefs[key]
        if b.relation then roots[#roots+1]=b end
    end
    local function add(key, verb, from, into, branch, depth, bases, parents, missing, active)
        if keys[key] then return nil end
        if #output>=MAX_HYPOTHESES then omitted=omitted+1 return nil end
        active=active~=false
        local confidence, disposition=1,"hypothesis"
        for _, base in ipairs(bases) do
            confidence=math.min(confidence,posterior(base,state.lastHours))
            if base.status=="falsified" then disposition="falsified"
            elseif base.status=="refined" and disposition~="falsified" then disposition="refined" end
        end
        -- Derived paths never count their own predictions as observations.
        confidence=confidence*(0.55^(depth-1))
        if depth==1 then disposition=status(bases[1]) end
        local previous=prior[key]
        local id=previous and previous.id
        if not id then
            state.nextHypothesis=state.nextHypothesis+1
            id="associative/hypothesis/"..tostring(state.nextHypothesis)
        end
        local gaps=copyList(missing,8)
        local physical=false
        for _,base in ipairs(bases) do if base.relation=="vary" then physical=true end end
        if depth>1 and physical then
            appendUnique(gaps,"Separate felt changes do not establish an ingestion's cause or efficacy; timing and alternatives remain untested.",8)
        end
        local h={id=id,key=key,label=string.sub((depth==1 and "Observed association " or "Analogy ")..verb.."("..from..", "..into..")",1,256),
            relation=verb,from=from,into=into,branch=branch,depth=depth,
            confidence=confidence,status=disposition,evidenceIds=mergeEvidence(bases),
            parentIds=copyList(parents,4),missing=gaps,roots=bases,active=active,
            revisions={},omittedRevisions=previous and (previous.omittedRevisions or 0) or 0}
        for _, revision in ipairs(previous and previous.revisions or {}) do
            h.revisions[#h.revisions+1]={worldHours=revision.worldHours,status=revision.status,
                active=revision.active,evidenceIds=copyList(revision.evidenceIds,8)}
        end
        if not previous or previous.status~=disposition or (previous.active~=false)~=active then
            h.revisions[#h.revisions+1]={worldHours=state.lastHours,status=disposition,
                active=active,evidenceIds=copyList(h.evidenceIds,8)}
            if #h.revisions>8 then
                table.remove(h.revisions,1) h.omittedRevisions=h.omittedRevisions+1
            end
        end
        output[#output+1]=h keys[key]=h
        return h
    end
    local seeds={}
    for _, b in ipairs(roots) do
        local h=add("seed:"..b.id,b.relation,b.from,b.into,b.branch,1,{b},{},
            {"Association does not establish an operating method or recipe."})
        if h then seeds[#seeds+1]=h end
    end
    -- Compose observed links by a common semantic endpoint. Inputs remain
    -- distinct evidence roots even when a later path reuses the same relation.
    if maxDepth>=2 then
        local work=0
        for _, a in ipairs(roots) do
            for _, b in ipairs(roots) do
                work=work+1
                if work<=128 and a.id~=b.id and a.into==b.from
                    and posterior(a,state.lastHours)>0.5 and posterior(b,state.lastHours)>0.5
                    and keys["seed:"..a.id] and keys["seed:"..b.id] then
                    add("compose:"..a.id..":"..b.id,"compose",a.from,b.into,
                        b.branch or "logistics-preservation",2,{a,b},
                        {keys["seed:"..a.id].id,keys["seed:"..b.id].id},
                        {"The composed operation has not been performed.",
                         "Interfaces, timing and losses remain unmeasured."})
                end
            end
        end
    end
    local function sharesMaterial(a,b)
        for _, left in ipairs({a.from,a.into}) do
            if left~="container" and left~="source" then
                if left==b.from or left==b.into then return true end
            end
        end
        return false
    end
    local function connectedEvidence(seed)
        local bases={seed} local used={[seed.relation]=true}
        local evidence={} for _,id in ipairs(seed.evidenceIds) do evidence[id]=true end
        for pass=1,3 do
            for _,candidate in ipairs(roots) do
                local distinct,connected=false,false
                for _,id in ipairs(candidate.evidenceIds) do if not evidence[id] then distinct=true end end
                for _,base in ipairs(bases) do if sharesMaterial(base,candidate) then connected=true end end
                if #bases<4 and not used[candidate.relation] and distinct and connected
                    and posterior(candidate,state.lastHours)>0.5 then
                    bases[#bases+1]=candidate used[candidate.relation]=true
                    for _,id in ipairs(candidate.evidenceIds) do evidence[id]=true end
                end
            end
        end
        return bases
    end
    local frontier={}
    for _,h in ipairs(seeds) do
        if h.status~="falsified" and h.confidence>0.5 then
            local bases=connectedEvidence(h.roots[1])
            local relevantContext=(contexts.cook and (h.from=="food" or h.into=="food"))
                or (contexts.forage and (h.from=="food" or h.into=="food"))
                or (contexts.treat and (h.into=="hunger-relief" or h.into=="thirst-relief"))
            frontier[#frontier+1]={hypothesis=h,bases=bases,
                limit=math.min(maxDepth,#bases+((#bases>=3 and relevantContext) and 1 or 0))}
        end
    end
    for depth=2,maxDepth do
        local nextFrontier={}
        for _, path in ipairs(frontier) do
            local h=path.hypothesis
            for _, rule in ipairs(RULES) do
                if rule.from==h.relation and depth<=path.limit then
                    local child=add(h.key.."/"..rule.into,h.relation=="operate" and "regulate" or rule.into,
                        h.from,h.into,rule.branch,depth,path.bases,{h.id},
                        {rule.missing,"Connected containment, conveyance or use is an analogy basis, not the proposed mechanism.",
                         "No demonstrated recipe, apparatus or operating method."})
                    if child then nextFrontier[#nextFrontier+1]={hypothesis=child,bases=path.bases,limit=path.limit} end
                end
            end
        end
        frontier=nextFrontier
    end
    -- Existing personal capabilities are analogy contexts, not outcomes.
    -- They never certify a new branch or strengthen the observed relation.
    if maxDepth>=2 then
        for _, h in ipairs(seeds) do
            for _, cap in ipairs({"cook","forage","treat"}) do
                if contexts[cap]==true then
                    add(h.key.."/context:"..cap,"operate",h.into,cap,
                        CAPABILITIES[cap],2,h.roots,{h.id},
                        {"Transfer from this association to "..cap.." has not been tested.",
                         "The required materials and operating method remain unknown."})
                end
            end
        end
    end
    -- A contradicted path remains a revisable record. It cannot be used as
    -- current support, but renewed evidence must not turn it into a new idea
    -- with no refutation history. Retention shares the hypothesis cap.
    for _, previous in ipairs(state.hypotheses) do
        if not keys[previous.key] and previous.depth>1 then
            local bases, counterevidence={},false
            for _, oldRoot in ipairs(previous.roots) do
                local current=state.beliefs[oldRoot.key]
                local root=(current and current.id==oldRoot.id) and current or oldRoot
                bases[#bases+1]=root
                if root.against>0 then counterevidence=true end
            end
            if counterevidence then
                local missing=copyList(previous.missing,7)
                appendUnique(missing,"Supporting evidence was challenged; this path is held until its premises qualify again.",8)
                add(previous.key,previous.relation,previous.from,previous.into,previous.branch,
                    previous.depth,bases,previous.parentIds,missing,false)
            end
        end
    end
    state.hypotheses=output
    state.omittedHypotheses=omitted
end

local function measurable(e)
    if e.status=="interrupted" or e.status=="unavailable" then return nil,"censored-access-or-interruption" end
    if EXTENDED[e.kind] then
        if e.kind=="tool-repair" and e.status=="no-effect" then return "private-fact",false end
        if e.status~="completed" then return nil,"completion-unmeasured" end
        return "private-fact",true
    end
    if e.kind=="inspection" then
        if e.perspective~="performed" or e.status~="completed"
            or (e.foodPresent==nil and e.waterPresent==nil) then return nil,"contents-unmeasured" end
        return "inspect",true
    end
    if e.kind=="consume" then
        local delta=e.category=="food" and e.hungerDelta or e.category=="water" and e.thirstDelta or nil
        if delta==nil then return nil,"relief-unmeasured" end
        return e.category,delta>0
    end
    if e.category=="container" then return nil,"resource-category-unavailable" end
    return e.category,e.status=="completed"
end

local function planBeliefKey(kind, category, sourceId, itemType, condition)
    local source, item = sourceId or "", itemType or ""
    return "plan:"..kind..":"..category..":"..#source..":"..source..":"..#item..":"..item..(condition and ":"..condition or "")
end

-- Both contestants retain the same measured occurrence independently. Exact
-- source and item identities stay available when a later plan asks about them.
local function rememberPlanEvidence(state, e, yes)
    local function retain(kind, category, result, facet)
        local item = kind == "inspect" and nil or e.itemType
        local condition=facet or (kind=="commitment" and e.actionKind or nil)
        local b = remember(state, planBeliefKey(kind, category, e.sourceId, item, condition),
            "Personally acquired "..kind.." evidence for "..category, result, e)
        b.planKind, b.category, b.sourceId, b.itemType, b.condition = kind, category, e.sourceId, item, condition
    end
    if e.kind == "acquire" then retain("acquire", e.category, yes)
    elseif e.kind == "preparation" then retain("prepare", "food", true)
    elseif e.kind == "plumbing" then retain("plumb", "construction", true)
    elseif e.kind == "generator-operation" and e.actionKind=="verify-power" then retain("power", "utilities", true)
    elseif e.kind == "collector-construction" then
        local b = remember(state, planBeliefKey("construct", "construction", e.originalFixtureSourceId, e.entityId),
            "Personally acquired collector construction evidence", true, e)
        b.planKind, b.category, b.sourceId, b.itemType = "construct", "construction", e.originalFixtureSourceId, e.entityId
    elseif e.kind == "tool-repair" then
        retain("tool-repair", "construction", e.afterValue>e.beforeValue)
        if e.effectMetric=="sharpness" then
            retain("tool-repair", "construction", (e.conditionLoss or 0)>0 or (e.headConditionLoss or 0)>0, "damage")
        end
    elseif e.kind == "study-outcome" then retain("study", "learning", true)
    elseif e.kind == "commitment-outcome" then retain("commitment", "social", true)
    elseif e.kind == "instrument-use" then retain("recreate", "leisure", e.succeeded)
    elseif e.kind=="leisure-duet" then
        retain("hobby","leisure",true,"duet:"..e.partnerId)
    elseif e.kind=="leisure-dance" then
        retain("hobby","leisure",true,"dance:"..e.partnerId)
    elseif HOBBY_KINDS[e.kind] then retain("hobby", "leisure", e.succeeded,e.actionKind)
    elseif e.kind == "weekone-instrument-performance" then
        retain("hobby", "leisure", true, e.actionKind)
    elseif e.kind == "leisure-reading" then
        retain("recreate", "leisure", e.succeeded)
        for name, v in pairs(e.stats or {}) do retain("reading-relief", "leisure", v.after < v.before, name) end
    elseif e.kind == "inspection" then
        retain("inspect", "container", true)
        if e.foodPresent ~= nil then retain("inspect", "food", e.foodPresent) end
        if e.waterPresent ~= nil then retain("inspect", "water", e.waterPresent) end
    end
end

local function extendedEvidence(modelId,state,e)
    if e.kind=="entry-outcome" or e.kind=="recovery-outcome" then
        local key=e.kind=="entry-outcome" and ("entry:"..e.sourceId..":"..e.apertureState)
            or ("recovery:"..e.actionKind)
        remember(state,key,"Personally performed "..e.actionKind.." outcome",e.succeeded,e)
    elseif e.kind=="commitment-outcome" then
        remember(state,"direct:accepted-work:"..e.sourceId..":"..e.actionKind,"Personally performed accepted "..e.actionKind.." work; broader social effects unmeasured",true,e)
    elseif e.kind=="study-outcome" then
        remember(state,"direct:study:"..e.itemType,"Personally completed native manual reading; understanding and competence unassessed",true,e)
    elseif e.kind=="instrument-use" then
        remember(state,"direct:instrument:"..e.itemType,"Personally attempted a native sound; repertoire, skill and shared participation unassessed",e.succeeded,e)
    elseif e.kind=="weekone-instrument-performance" then
        remember(state,"direct:weekone-performance:"..e.itemType..":"..e.soundId,
            "Personally performed with the held instrument; skill, pleasure and shared participation unmeasured",true,e)
    elseif e.kind=="weekone-performance-hearing" then
        remember(state,"heard:weekone-performance:"..e.actorId..":"..e.soundId,
            "Heard "..e.actorId.." perform "..e.soundId.."; enjoyment, assent and participation unmeasured",true,e)
    elseif e.kind=="leisure-duet" then
        remember(state,"direct:duet:"..e.sourceId..":"..e.partnerId,
            "Personally performed a source duet with "..e.partnerId.."; enjoyment and trust remain unmeasured",true,e)
    elseif e.kind=="leisure-dance" then
        remember(state,"direct:dance:"..e.sourceId..":"..e.partnerId,
            "Personally performed a source partner dance with "..e.partnerId.."; enjoyment and trust remain unmeasured",true,e)
    elseif HOBBY_KINDS[e.kind] then
        remember(state,"direct:hobby:"..e.sourceId..":"..e.actionKind,
            "Personally attempted "..e.actionKind.."; pleasure, skill and shared participation need their own evidence",e.succeeded,e)
    elseif e.kind=="leisure-reading" then
        remember(state,"direct:leisure-reading:"..e.sourceId..":"..e.itemType,
            "Personally attempted reading; native completion and text exposure do not certify understanding",e.succeeded,e)
    elseif e.kind=="physical-change" then
        -- Numeric changes remain separate from dose identity and pharmacology.
        -- A reversed measured direction challenges the prior direction; it
        -- does not refute or support any particular medicine's effectiveness.
        for _,name in ipairs(STATS) do
            local values=e.stats[name]
            if values then
                local direction=values.after>values.before and "increase" or "decrease"
                local opposite=direction=="increase" and "decrease" or "increase"
                if modelId=="ordinary" then
                    local key="direct:physical-change:"..name..":"
                    if state.beliefs[key..opposite] then
                        remember(state,key..opposite,"Felt "..name.." "..opposite.."; cause unassigned",false,e)
                    end
                    remember(state,key..direction,"Felt "..name.." "..direction.."; cause unassigned",true,e)
                else
                    local into="felt:"..name..":"
                    if state.beliefs["relation:vary:body:"..into..opposite] then
                        relation(state,"vary","body",into..opposite,false,e,"medicine")
                    end
                    relation(state,"vary","body",into..direction,true,e,"medicine")
                end
            end
        end
    elseif e.kind=="generator-operation" then
        if modelId=="ordinary" then
            remember(state,"direct:generator:"..e.sourceId..":"..e.consumerId..":"..e.actionKind,
                "Personally measured generator "..e.actionKind.." for "..e.consumerId,true,e)
        else
            relation(state,"operate","generator:"..e.sourceId,"consumer:"..e.consumerId..":"..e.actionKind,
                true,e,"electrical-systems")
        end
    elseif e.kind=="tool-repair" then
        local improved = e.afterValue>e.beforeValue
        if modelId=="ordinary" then
            remember(state,"direct:tool-repair:"..e.sourceId..":"..e.itemType,
                "Native "..e.sourceId.." changed held "..e.itemType.." "..(e.effectMetric or "condition").." from "..e.beforeValue.." to "..e.afterValue,improved,e)
            if e.effectMetric=="sharpness" then
                remember(state,"direct:tool-damage:"..e.sourceId..":"..e.itemType,
                    "Observed condition loss "..(e.conditionLoss or 0).." and head condition loss "..(e.headConditionLoss or 0),
                    (e.conditionLoss or 0)>0 or (e.headConditionLoss or 0)>0,e)
            end
        else
            relation(state,"transform","repair:"..e.sourceId,"tool:"..e.itemType,improved,e,"manufacturing")
            if e.effectMetric=="sharpness" then
                relation(state,"vary","repair:"..e.sourceId,"damage:"..e.itemType,
                    (e.conditionLoss or 0)>0 or (e.headConditionLoss or 0)>0,e,"manufacturing")
            end
        end
    elseif e.kind=="collector-construction" then
        if modelId=="ordinary" then
            remember(state,"direct:collector-construction:"..e.sourceId..":"..e.entityId,
                "Constructed "..e.entityId.." at "..e.siteKey,true,e)
        else relation(state,"transform","recipe:"..e.recipeId,"collector:"..e.sourceId,true,e,"manufacturing") end
    elseif e.kind=="plumbing" then
        if modelId=="ordinary" then
            remember(state,"direct:plumbing:"..e.sourceId..":"..e.itemType,
                "Connected "..e.sourceId.." using "..e.itemType,true,e)
        else relation(state,"operate","tool:"..e.itemType,e.sourceId,true,e,"manufacturing") end
    elseif e.kind=="material-crafting" then
        if modelId=="ordinary" then
            remember(state,"direct:material-crafting:"..e.sourceId..":"..e.itemType,
                "Made held "..e.itemType.." through native "..e.sourceId,true,e)
        else relation(state,"transform","recipe:"..e.sourceId,"output:"..e.itemType,true,e,"manufacturing") end
    elseif e.kind=="window-repair" then
        if modelId=="ordinary" then
            remember(state,"direct:window-repair:"..e.sourceId..":"..e.itemType,
                "Replaced broken glass in "..e.sourceId.." using "..e.itemType,true,e)
        else relation(state,"transform","broken-glass:"..e.sourceId,"repaired-glass:"..e.sourceId,true,e,"manufacturing") end
    elseif e.kind=="animal-care" then
        if modelId=="ordinary" then
            remember(state,"direct:animal-care:"..e.sourceId..":"..e.itemType,
                "Fed "..e.itemType.." to "..e.sourceId.."; later animal condition unmeasured",true,e)
        else relation(state,"convey","feed:"..e.itemType,e.sourceId,true,e,"animal-care") end
    elseif e.kind=="medication-use" then
        if modelId=="ordinary" then
            remember(state,"direct:medication-use:"..e.itemType,"Ingested "..e.itemType.." into self; efficacy unmeasured",true,e)
        else relation(state,"convey","medicine:"..e.itemType,"body",true,e,"medicine") end
    else
        if modelId=="ordinary" then
            remember(state,"direct:preparation:"..e.sourceId..":"..e.itemType,
                "Native thermal preparation of "..e.itemType.."; ingestion and relief unmeasured",true,e)
        else relation(state,"transform","food","thermally-prepared-food",true,e,"manufacturing") end
    end
end

function M.observe(modelId, state, experience, maxDepth)
    if not validState(modelId,state) then return "rejected:model-state" end
    if not validEvent(experience) then return "rejected:experience" end
    if not finite(maxDepth) or maxDepth<1 or maxDepth>4 or maxDepth~=math.floor(maxDepth) then
        return "rejected:depth"
    end
    local e=experience
    if state.actorId and state.actorId~=e.observerId then return "rejected:foreign-observer" end
    if state.seen[e.id] then return "ignored:duplicate" end
    local position=EXTENDED[e.kind] and occurrencePosition(e)
    local previousPosition=position and state.nativePositions and tonumber(state.nativePositions[e.kind])
    if previousPosition and position<=previousPosition then return "ignored:native-receipt" end
    if not position then
        if e.worldHours<=state.evictedThroughHours then return "ignored:evicted-evidence-frontier" end
    end
    local goal, yes=measurable(e)
    if not goal then return "ignored:"..yes end
    if position then
        state.nativePositions=state.nativePositions or {}
        -- Three scalar strings stay within existing serialized-number bounds.
        -- Distinct catch-up minutes may share the true acquisition timestamp.
        state.nativePositions[e.kind]=tostring(position)
    end
    -- Keep stored beliefs/IDs and old frozen proposals. Reading a /1 state is
    -- inert; only an authentic new observation migrates its learning variant.
    if state.version~=VERSION[modelId] then
        state.migratedFrom=state.version
        state.version=VERSION[modelId]
    end
    state.actorId=e.observerId
    state.seen[e.id]=true
    state.eventOrder[#state.eventOrder+1]={id=e.id,hours=e.worldHours}
    if #state.eventOrder>MAX_EVENTS then
        local old=table.remove(state.eventOrder,1)
        state.seen[old.id]=nil
        state.evictedThroughHours=math.max(state.evictedThroughHours,old.hours)
        state.omittedEvents=state.omittedEvents+1
    end
    state.revision=state.revision+1
    state.lastHours=math.max(state.lastHours or e.worldHours,e.worldHours)
    -- Store is evidence of placement, not a new food/water-goal completion.
    if e.kind~="store" and action(goal) then
        remember(state,"goal:"..goal,"Qualified "..goal.." outcomes",yes,e)
    end
    rememberPlanEvidence(state, e, yes)
    if EXTENDED[e.kind] then extendedEvidence(modelId,state,e)
    elseif modelId=="ordinary" then
        remember(state,"direct:"..e.kind..":"..e.category..":"..tostring(e.sourceId or e.itemType or "unspecified"),
            e.perspective.." "..e.kind.." "..e.category.." at "..tostring(e.sourceId or "unlocated source"),yes,e)
    else
        if e.kind=="inspection" then
            if e.foodPresent~=nil then relation(state,"contain","container","food",e.foodPresent,e) end
            if e.waterPresent~=nil then relation(state,"contain","container","water",e.waterPresent,e) end
        elseif e.kind=="consume" then
            relation(state,"operate",e.category,e.category=="food" and "hunger-relief" or "thirst-relief",yes,e)
        elseif e.kind=="acquire" then
            relation(state,"convey","source",e.category,yes,e)
        else
            relation(state,"contain","container",e.category,yes,e)
        end
    end
    if modelId=="associative" then
        local contexts=state.capabilities or {}
        if e.capabilities and (not state.capabilityHours or e.worldHours>=state.capabilityHours) then
            contexts={cook=e.capabilities.cook==true,forage=e.capabilities.forage==true,treat=e.capabilities.treat==true}
            state.capabilityHours=e.worldHours
        end
        state.capabilities=contexts
        rebuildHypotheses(state,maxDepth,contexts)
    end
    return "revised:"..modelId..":"..tostring(state.revision)..":"..(yes and "observed-effect" or "counterexample")
end

local function probability(state, goal, associative, hours)
    local direct=state.beliefs["goal:"..goal]
    if direct then return posterior(direct,hours) end
    if associative and (goal=="food" or goal=="water") then
        local b=state.beliefs["relation:contain:container:"..goal]
        if b then return 0.5+(posterior(b,hours)-0.5)*0.6 end
    end
    return 0.5
end
local function predictions(state, associative, hours)
    return {
        food={probability=probability(state,"food",associative,hours),
            claim="The next qualified food acquisition succeeds or measured own consumption relieves hunger."},
        water={probability=probability(state,"water",associative,hours),
            claim="The next qualified water acquisition succeeds or measured own consumption relieves thirst."},
        inspect={probability=probability(state,"inspect",associative,hours),
            claim="A performed inspection returns definite contents evidence, including an empty result."},
        continue={probability=0.5,
            claim="No new goal is initiated; its outcome remains unobserved without a matching action receipt."},
    }
end
local function associativeChoice(state, f, p)
    local food=f.hunger/math.max(0.05,f.eatAt)
    local water=f.thirst/math.max(0.05,f.drinkAt)
    local pressure=math.max(food,water)
    if pressure<0.55 then return "continue","Current pressure leaves room to retain the ongoing intent." end
    local scores={food=-1,water=-1,inspect=-1,continue=0.16}
    -- A reserve margin anticipates need before the ordinary threshold.
    -- It is a policy horizon, not a claim about unmeasured physiological rates.
    if f.foodAllowed and food>=0.72 then
        scores.food=food*p.food.probability*(f.knownFood>0 and 1 or 0.4)
    end
    if f.waterAllowed and water>=0.72 then
        scores.water=water*p.water.probability*(f.knownWater>0 and 1 or 0.4)
    end
    if f.inspectionAllowed and f.knownPlaces>0 then
        local uncertainFood=4*p.food.probability*(1-p.food.probability)
        local uncertainWater=4*p.water.probability*(1-p.water.probability)
        local unknown=(f.knownFood==0 and food or 0)+(f.knownWater==0 and water or 0)
        scores.inspect=unknown*(0.18+0.18*(uncertainFood+uncertainWater)/2)*p.inspect.probability
        local contain=state.beliefs["relation:contain:container:food"]
        local waterContain=state.beliefs["relation:contain:container:water"]
        if contain or waterContain then
            scores.inspect=scores.inspect+0.12*pressure*math.max(posterior(contain,f.worldHours),posterior(waterContain,f.worldHours))
        end
    end
    if f.priorIntent and scores[f.priorIntent] and scores[f.priorIntent]>=0 then
        scores[f.priorIntent]=scores[f.priorIntent]+0.025
    end
    local selected="continue"
    for _, name in ipairs({"water","food","inspect"}) do
        if scores[name]>scores[selected] then selected=name end
    end
    return selected,"Anticipated pressure, independently learned outcomes and information value favor "..selected.."."
end

function M.behaviorExpectation(modelId, state, kind, sourceId, condition, hours)
    if not validState(modelId,state) or not finite(hours) or hours<0
        or state.lastHours and hours<state.lastHours then return nil end
    local key
    if kind=="entry" and text(sourceId,160) and text(condition,32) then
        key="entry:"..sourceId..":"..condition
    elseif kind=="sleep" or kind=="rest" then key="recovery:"..kind
    else return nil end
    local belief=state.beliefs[key]
    if not belief then return nil end
    return posterior(belief,hours)
end

function M.propose(modelId, state, frame)
    if not validState(modelId,state) then return nil,"model-state" end
    if not validFrame(frame) then return nil,"private-frame" end
    if state.actorId and state.actorId~=frame.actorId then return nil,"foreign-actor" end
    if state.lastHours and frame.worldHours<state.lastHours then return nil,"future-evidence" end
    local p=predictions(state,modelId=="associative",frame.worldHours)
    local selected, interpretation="continue","No admissible ordinary need threshold is reached."
    if modelId=="ordinary" then
        if frame.waterAllowed and frame.thirst>=frame.drinkAt then
            selected,interpretation="water","Thirst reaches the existing personal drinking threshold."
        elseif frame.foodAllowed and frame.hunger>=frame.eatAt then
            selected,interpretation="food","Hunger reaches the existing personal eating threshold."
        end
    else selected,interpretation=associativeChoice(state,frame,p) end
    local proposal={modelId=modelId,version=VERSION[modelId],actionId=selected,
        interpretation=interpretation,confidence=p[selected].probability,predictions=p}
    if modelId=="associative" then
        for _, h in ipairs(state.hypotheses) do
            if h.active~=false and h.status~="falsified" and (h.into==selected or h.from==selected) then
                proposal.hypothesisId=h.id break
            end
        end
    end
    return proposal
end

-- The same private plan candidates are interpreted independently by each
-- contestant. This ranks proposed routes through already represented work;
-- it cannot add a verb, technique, material, spatial fact or native result.
local CONSEQUENCE_KEYS = {kind=true, category=true, sourceId=true, itemType=true, condition=true, value=true}
local CONDITIONS = {open=true, closed=true, clear=true, smashed=true, barricaded=true, unknown=true}
local NEED_KEYS = {fatigue=true, endurance=true, hunger=true, thirst=true}
local function boundedArray(value, maximum, minimum)
    if type(value) ~= "table" or #value > maximum or #value < (minimum or 0) then return false end
    local count = 0
    for key in pairs(value) do
        if not finite(key) or key ~= math.floor(key) or key < 1 or key > #value then return false end
        count = count + 1
    end
    return count == #value
end
local function validConsequences(candidate)
    if candidate.consequences == nil then return true end
    if not boundedArray(candidate.consequences, 4) then return false end
    for _, consequence in ipairs(candidate.consequences) do
        local c = consequence
        if not plainKeys(c, CONSEQUENCE_KEYS) or not finite(c.value) or c.value > 2
            or c.value < 0 and not (c.kind=="tool-repair" and c.condition=="damage" and c.value>=-2) then return false end
        if c.sourceId ~= nil and not text(c.sourceId, 160) then return false end
        if c.itemType ~= nil and not text(c.itemType, 160) then return false end
        if c.condition ~= nil and not (c.kind=="entry" and CONDITIONS[c.condition]
            or c.kind=="commitment" and (c.condition=="prepare"
                or c.condition=="deliver" or c.condition=="watch-return")
            or c.kind=="reading-relief" and (c.condition=="BOREDOM" or c.condition=="UNHAPPINESS" or c.condition=="STRESS")
            or c.kind=="hobby" and text(c.condition,160)
            or c.kind=="tool-repair" and c.condition=="damage") then return false end
        if c.kind == "entry" then
            if c.category ~= "body" or not text(c.sourceId, 160) or not CONDITIONS[c.condition] or c.itemType ~= nil then return false end
        elseif c.kind == "sleep" or c.kind == "rest" then
            if c.category ~= "body" or c.sourceId ~= nil or c.itemType ~= nil then return false end
        elseif c.kind == "study" or c.kind == "practice" or c.kind == "investigate" then
            if c.category ~= "learning" then return false end
        elseif c.kind == "commitment" then
            if c.category ~= "social" or not text(c.sourceId, 160) then return false end
        elseif c.kind == "hobby" then
            if c.category~="leisure" or not HOBBY_SOURCES[c.sourceId] or not text(c.condition,160) then return false end
        elseif c.kind == "recreate" then
            if c.category ~= "leisure" or (c.sourceId ~= "native:sound:BlowHarmonica"
                and c.sourceId ~= "native:literature:ISReadABook" and c.sourceId ~= "native:literature:customPages")
                or not text(c.itemType,160) or c.condition ~= nil then return false end
        elseif c.kind == "reading-relief" then
            if c.category ~= "leisure" or c.sourceId ~= "native:literature:ISReadABook"
                or not text(c.itemType, 160) or (c.condition ~= "BOREDOM" and c.condition ~= "UNHAPPINESS" and c.condition ~= "STRESS") then return false end
        elseif c.kind == "prepare" then
            if c.category ~= "food" then return false end
        elseif c.kind == "plumb" then
            if c.category ~= "construction" or not text(c.sourceId,160)
                or string.sub(c.sourceId,1,2) ~= "F:" or c.condition ~= nil then return false end
        elseif c.kind == "power" then
            if c.category~="utilities" or not text(c.sourceId,160) or c.sourceId:sub(1,2)~="J:"
                or c.condition~=nil or c.itemType~=nil then return false end
        elseif c.kind == "construct" then
            if c.category ~= "construction" or not text(c.sourceId,160)
                or c.sourceId:sub(1,2) ~= "F:" or not COLLECTOR_ENTITIES[c.itemType]
                or c.condition ~= nil then return false end
        elseif c.kind == "tool-repair" then
            if c.category ~= "construction" or (c.sourceId ~= "Base.FixSaw" and c.sourceId ~= "Base.SharpenBlade"
                and c.sourceId ~= "Base.SharpenBladePoorlyWithFile") or not text(c.itemType,160)
                or c.condition~=nil and c.condition~="damage" then return false end
        elseif c.kind == "acquire" then
            if c.category ~= "food" and c.category ~= "water" then return false end
        elseif c.kind == "inspect" then
            if c.category ~= "food" and c.category ~= "water" and c.category ~= "container" then return false end
        else return false end
    end
    return true
end
local function planContext(modelId, state, context)
    if not validState(modelId, state) or type(context) ~= "table"
        or not text(context.actorId, 128) or not finite(context.atHours) or context.atHours < 0
        or not unit(context.pressure) then return false end
    if state.actorId and state.actorId ~= context.actorId then return false end
    if #state.beliefOrder > 0 and not text(state.actorId, 128) then return false end
    if state.lastHours ~= nil and (not finite(state.lastHours) or state.lastHours > context.atHours) then return false end
    if context.capabilities ~= nil and not capabilities(context.capabilities) then return false end
    if context.needs ~= nil then
        if not plainKeys(context.needs, NEED_KEYS) then return false end
        for _, value in pairs(context.needs) do if not unit(value) then return false end end
    end
    return true
end
local function planCandidate(candidate, context, structural)
    if type(candidate) ~= "table"
        or not unit(candidate.evidence) or not unit(candidate.continuity) or not unit(candidate.novelty)
        or not unit(candidate.informationGain) or not finite(candidate.blockers)
        or candidate.blockers < 0 or candidate.blockers > 16 or candidate.blockers ~= math.floor(candidate.blockers)
        or candidate.utility ~= nil and (not finite(candidate.utility) or math.abs(candidate.utility) > 16)
        or candidate.maxAdjustment ~= nil and (not finite(candidate.maxAdjustment)
            or candidate.maxAdjustment < 0 or candidate.maxAdjustment > 8)
        then return false end
    -- A native-feasible option can exceed the prediction identity budget.
    -- Neutral fallback consumes only these structural values and leaves its
    -- exact identity intact for the native owner.
    if not structural and (not text(candidate.id, 128)
        or not validConsequences(candidate)) then return false end
    local a = candidate.appraisal
    if a ~= nil and (type(a) ~= "table" or context and a.actorId ~= context.actorId
        or type(a.danger) ~= "table" or not unit(a.danger.ordinal)
        or type(a.travel) ~= "table" or not unit(a.travel.outwardCost) or not unit(a.travel.returnCost)
        or not unit(a.requestValue) or type(a.social) ~= "table" or type(a.social.requests) ~= "table"
        or type(a.social.responsibilities) ~= "table") then return false end
    return true
end

local function consequenceBeliefs(modelId, state, c)
    local exact, transfer = {}, {}
    if c.kind == "entry" or c.kind == "sleep" or c.kind == "rest" then
        local key = c.kind == "entry" and ("entry:"..c.sourceId..":"..c.condition) or ("recovery:"..c.kind)
        if state.beliefs[key] then exact[1] = state.beliefs[key] end
        return exact, "exact-experience", 1
    end
    for _, key in ipairs(state.beliefOrder) do
        local b = state.beliefs[key]
        if type(b) == "table" and b.planKind == c.kind and b.category == c.category
            and (c.kind~="tool-repair" or b.condition==c.condition)
            and (c.kind~="commitment" and c.kind~="reading-relief" and c.kind~="hobby" or c.condition~=nil and b.condition==c.condition)
            and (c.itemType == nil or b.itemType == c.itemType
                or modelId=="associative" and c.kind=="study" and b.sourceId==c.sourceId) then
            if c.sourceId ~= nil and b.sourceId == c.sourceId
                and (c.itemType==nil or b.itemType==c.itemType)
                or c.kind == "prepare" and c.sourceId == nil and c.itemType ~= nil then exact[#exact+1] = b
            elseif modelId == "associative" and (c.kind == "inspect"
                or c.kind == "study" and b.sourceId==c.sourceId
                or c.kind == "commitment" and b.condition==c.condition
                or c.kind == "prepare" and c.itemType ~= nil and b.itemType == c.itemType
                or c.kind == "hobby" and c.itemType ~= nil and b.itemType == c.itemType
                    and b.condition == c.condition) then
                transfer[#transfer+1] = b
            end
        end
    end
    -- Existing /1-/3 states retain their original exact direct records. Reads
    -- use those records without migrating, manufacturing receipts or teaching.
    if #exact == 0 and c.sourceId ~= nil then
        local key
        if c.kind == "acquire" and c.itemType == nil then key = "direct:acquire:"..c.category..":"..c.sourceId
        elseif c.kind == "inspect" and c.category == "container" then key = "direct:inspection:container:"..c.sourceId
        elseif c.kind == "prepare" and c.itemType ~= nil then key = "direct:preparation:"..c.sourceId..":"..c.itemType end
        if key and state.beliefs[key] then exact[1] = state.beliefs[key] end
    end
    if #exact > 0 then return exact, "exact-experience", 1 end
    if modelId == "associative" and #transfer > 0 then return transfer, "related-experience", 0.45 end
    if modelId == "associative" and c.kind == "inspect" and c.category ~= "container" then
        local b = state.beliefs["relation:contain:container:"..c.category]
        if b then return {b}, "related-experience", 0.35 end
    end
    return {}, "unknown", 0
end

local function consequencePrediction(modelId, state, c, context)
    local beliefs, basis, strength = consequenceBeliefs(modelId, state, c)
    local seen, evidenceIds, beliefIds, support, against, count = {}, {}, {}, 0, 0, 0
    for _, b in ipairs(beliefs) do
        if not text(b.id, 160) or not boundedArray(b.samples, 8) then return nil end
        appendUnique(beliefIds, b.id, 8)
        for _, sample in ipairs(b.samples) do
            if type(sample) ~= "table" or not text(sample.id, 128) or not finite(sample.hours)
                or sample.hours < 0 or sample.hours > context.atHours or type(sample.yes) ~= "boolean" then return nil end
            if not seen[sample.id] then
                seen[sample.id] = true
                local weight = 0.5 ^ ((context.atHours - sample.hours) / CONFIDENCE_HALF_LIFE_HOURS)
                if sample.yes then support = support + weight else against = against + weight end
                appendUnique(evidenceIds, sample.id, 8)
                count = count + 1
            end
        end
    end
    local probability = 0.5 + strength * ((1 + support) / (2 + support + against) - 0.5)
    if count == 0 then
        basis = "unknown"
        if c.kind == "prepare" and context.capabilities and context.capabilities.cook == true then
            probability, basis = 0.6, "current-cooking-capability"
        end
    end
    return {kind=c.kind, category=c.category, sourceId=c.sourceId, itemType=c.itemType,
        condition=c.condition, value=c.value, probability=probability,
        uncertainty=1-math.abs(probability-0.5)*2, basis=basis,
        evidenceIds=evidenceIds, beliefIds=beliefIds, omittedEvidence=math.max(0,count-#evidenceIds)}
end

function M.planPrediction(modelId, candidate, state, context)
    if not planContext(modelId, state, context) then return nil, "private-plan-context" end
    if not planCandidate(candidate, context) then return nil, "private-plan-candidate" end
    local result = {schema="sao-plan-prediction/1", predictions={}, expectedValue=0, adjustment=0}
    for _, consequence in ipairs(candidate.consequences or {}) do
        local p = consequencePrediction(modelId, state, consequence, context)
        if not p then return nil, "private-plan-evidence" end
        result.predictions[#result.predictions+1] = p
        result.expectedValue = result.expectedValue + p.probability * p.value
        result.adjustment = result.adjustment + (p.probability - 0.5) * p.value
    end
    return result
end

function M.planScore(modelId, candidate, pressure, state, context)
    if not model(modelId) or not unit(pressure)
        or not planCandidate(candidate, context, state == nil and context == nil) then return nil end
    local adjustment = 0
    if state ~= nil or context ~= nil then
        local predicted = M.planPrediction(modelId, candidate, state, context)
        if not predicted then return nil end
        adjustment = predicted.adjustment
    end
    if candidate.maxAdjustment ~= nil then
        adjustment = math.max(-candidate.maxAdjustment, math.min(candidate.maxAdjustment, adjustment))
    end
    local appraisal = candidate.appraisal or {}
    local danger, travel = appraisal.danger or {}, appraisal.travel or {}
    local risk = unit(danger.ordinal) and danger.ordinal or 0
    -- An explicit material benefit does not erase a personally supported risk.
    -- Use the same danger contribution as ordinary structural plan appraisal.
    if candidate.utility ~= nil then
        return candidate.utility - risk * (modelId == "ordinary" and 0.45 or 0.30) + adjustment
    end
    local outward = unit(travel.outwardCost) and travel.outwardCost or 0
    local returning = unit(travel.returnCost) and travel.returnCost or 0
    local request = unit(appraisal.requestValue) and appraisal.requestValue or 0
    if modelId == "ordinary" then
        return candidate.evidence * 0.55 + candidate.continuity * 0.30 + pressure * 0.15
            - math.min(1, candidate.blockers * 0.35) - risk * 0.45
            - outward * 0.18 - returning * 0.15 + request * 0.18 + adjustment
    end
    return candidate.evidence * 0.25 + candidate.continuity * 0.15 + candidate.novelty * 0.20
        + candidate.informationGain * 0.30 + pressure * 0.10 + adjustment
        - math.min(1, candidate.blockers * 0.25) - risk * 0.30
        - outward * 0.12 - returning * 0.10 + request * 0.15
end

function M.interpretPlans(modelId, state, candidates, context)
    if not planContext(modelId, state, context) or not boundedArray(candidates, 16, 1) then
        return nil, "private-plan-frame"
    end
    local pressure = context.pressure
    local ranked, ids = {}, {}
    for _, candidate in ipairs(candidates) do
        if not planCandidate(candidate, context) or ids[candidate.id] then
            return nil, "private-plan-candidate"
        end
        ids[candidate.id] = true
        local predicted, failure = M.planPrediction(modelId, candidate, state, context)
        if not predicted then return nil, failure end
        local score, interpretation
        if modelId == "ordinary" then
            score = M.planScore(modelId, candidate, pressure, state, context)
            interpretation = "Demonstrated feasibility, maintained purpose and current pressure favor this route."
        else
            score = M.planScore(modelId, candidate, pressure, state, context)
            interpretation = "Association value, uncertainty reduction and possible adjacency favor testing this route."
        end
        for _, p in ipairs(predicted.predictions) do
            interpretation = interpretation .. " " .. p.kind .. " " .. p.category .. ": " .. p.basis
                .. (p.basis=="unknown" and "; I have not established how this attempt will turn out."
                    or "; past experience informs this expectation, but this attempt remains uncertain.")
        end
        if candidate.appraisal then
            local a = candidate.appraisal
            interpretation = interpretation .. " Destination danger: " .. tostring(a.danger.status)
                .. "; believed threats " .. tostring(a.danger.believedCount or "unknown")
                .. "; own approach tiles " .. tostring(a.travel.outwardTiles or "unknown")
                .. "; home return tiles " .. tostring(a.travel.returnTiles or "unknown")
                .. "; acquired requests " .. tostring(#a.social.requests)
                .. "; accepted responsibilities " .. tostring(#a.social.responsibilities)
                .. ". Route safety and successful delivery remain unconfirmed."
        end
        ranked[#ranked + 1] = { id = candidate.id, score = score,
            interpretation = interpretation, appraisal = candidate.appraisal,
            predictions=predicted.predictions, expectedValue=predicted.expectedValue }
    end
    table.sort(ranked, function(a, b)
        if a.score == b.score then return a.id < b.id end
        return a.score > b.score
    end)
    return { modelId = modelId, version = VERSION[modelId],
        selected = ranked[1].id, score = ranked[1].score,
        interpretation = ranked[1].interpretation, ranked = ranked }
end

function M.summary(modelId, state, hours)
    if not validState(modelId,state) or not finite(hours) then return nil,"model-state" end
    if state.lastHours and hours<state.lastHours then return nil,"future-evidence" end
    local out={beliefs={},hypotheses={}}
    for _, key in ipairs(state.beliefOrder) do
        local b=state.beliefs[key]
        out.beliefs[#out.beliefs+1]={id=b.id,label=b.label,confidence=posterior(b,hours),status=status(b)}
    end
    for _, h in ipairs(state.hypotheses) do
        local confidence=1
        for _,root in ipairs(h.roots) do confidence=math.min(confidence,posterior(root,hours)) end
        confidence=confidence*(0.55^(h.depth-1))
        out.hypotheses[#out.hypotheses+1]={id=h.id,label=h.label,branch=h.branch,
            depth=h.depth,confidence=confidence,status=h.status,
            evidenceIds=copyList(h.evidenceIds,8),parentIds=copyList(h.parentIds,4),missing=copyList(h.missing,8)}
    end
    return out
end

-- Conflict is an appraisal of possible effects under personal concerns. The
-- executor supplies availability; a conceptual expectation grants no target,
-- safe route, agreement, or completed effect. Weights remain implementation
-- detail. The returned account consists of reasons and unresolved premises.
-- Floors describe the person's spatial evidence, not native attack reach.
-- Legacy XY-only beliefs retain their uncertainty and distance convention.
function M.contactGeometry(threat)
    if type(threat)~="table" then return nil end
    for _,key in ipairs({"z","observerZ"}) do
        if threat[key]~=nil and (not finite(threat[key])
            or threat[key]~=math.floor(threat[key])) then return nil end
    end
    local known=threat.z~=nil and threat.observerZ~=nil
    local same=known and threat.z==threat.observerZ or nil
    if known and threat.z~=threat.observerZ then same=false end
    if threat.floorKnown~=nil and threat.floorKnown~=known
        or threat.sameFloor~=nil and threat.sameFloor~=same then return nil end
    return {floorKnown=known,sameFloor=same,reachability="unknown",
        close=finite(threat.distance) and threat.distance<=3 and same~=false}
end
function M.interpretConflict(frame, offers)
    if type(frame) ~= "table" or not text(frame.actorId,128) or not finite(frame.atHours)
        or type(frame.values) ~= "table" or type(frame.threat) ~= "table"
        or not boundedArray(offers,16,1) then return nil,"invalid-conflict-frame" end
    local v=frame.values
    for _,key in ipairs({"selfPreservation","aggression","nerve","discipline","compassion"}) do
        if not unit(v[key]) then return nil,"invalid-conflict-values" end
    end
    local fear=unit(frame.fear) and frame.fear or 0
    local geometry=M.contactGeometry(frame.threat)
    if not geometry then return nil,"invalid-conflict-geometry" end
    local close=geometry.close
    local concerning=frame.risk and frame.risk.elevated and frame.risk.withinConcern
    local distant=finite(frame.threat.distance) and frame.threat.distance>8 and not concerning
    local unknown=frame.threat.source~="observed"
    local protects=frame.commitment and frame.commitment.accepted==true
        and frame.commitment.protectOther==true
    local kinds={withdraw=true,reposition=true,engage=true,defend=true,communicate=true,coordinate=true,concede=true,watch=true}
    local candidates,ids={},{}
    for _,offer in ipairs(offers) do
        if type(offer)~="table" or not text(offer.id,128) or ids[offer.id] or not kinds[offer.kind]
            or type(offer.available)~="boolean" or not text(offer.reason,256)
            or not boundedArray(offer.effects,8) or not boundedArray(offer.objections,8) then return nil,"invalid-conflict-offer" end
        ids[offer.id]=true
        local row={id=offer.id,kind=offer.kind,available=offer.available,continuing=offer.continuing==true,
            reasons={},objections={},expectedEffects={},effects=copyList(offer.effects,8),arguments={}}
        local merit,seen=0,{}
        -- These arguments are the evaluated structure, not a graph appended
        -- after selection. Each contribution has an effect, a personal concern
        -- and the premises on which this person currently relies.
        local function consider(amount,effect,concern,reason,relation,condition)
            local premises={{kind="execution-offer",id=offer.id,available=offer.available,
                basis="current-executor-offer"}}
            if relation then premises[#premises+1]={kind="concept-path",from=relation.from,into=relation.into,
                status=relation.supported and "supported" or "unresolved",basis=relation.basis,
                evidenceIds=relation.evidenceIds,links=relation.links,contradictions=relation.contradictions} end
            if condition then premises[#premises+1]=condition end
            if frame.risk then premises[#premises+1]={kind="personally-appraised-danger",actorId=frame.risk.actorId,
                contactKey=frame.risk.contactKey,form=frame.risk.form,elevated=frame.risk.elevated,
                withinConcern=frame.risk.withinConcern,provenance=frame.risk.provenance} end
            row.arguments[#row.arguments+1]={effect=effect,concern=concern,reason=reason,
                polarity=amount>0 and "supports" or amount<0 and "opposes" or "unresolved",
                expectedStatus="possible",uncertainty="The action may fail or conditions may change.",
                premises=premises,valueBasis={actorId=frame.actorId,owner="SAO.Disposition",
                    provenance=v.provenance}}
            merit=merit+amount
        end
        local situation={kind="private-situation",contactKey=frame.threat.key,source=frame.threat.source,
            close=close,z=frame.threat.z,observerZ=frame.threat.observerZ,floorKnown=geometry.floorKnown,
            sameFloor=geometry.sameFloor,reachability=geometry.reachability,
            overwhelmed=frame.overwhelmed,escapeBlocked=frame.escapeBlocked}
        local obligation=protects and {kind="accepted-commitment",key=frame.commitment.key,
            concern="protect-another-person",accepted=true} or nil
        for _,effect in ipairs(offer.effects) do
            if not text(effect,96) then return nil,"invalid-conflict-effect" end
            if not seen[effect] then
                seen[effect]=true
                local relation=frame.relations and frame.relations[offer.kind=="concede"
                    and ("concession:"..effect) or effect]
                if relation and relation.supported then
                    local gain,reason
                    if effect=="break-contact" then
                        gain=3*v.selfPreservation+fear
                        reason="Separation may break contact and protect my life."
                        if protects then
                            consider(-2*v.compassion-v.discipline,"separation-from-dependent","honor-accepted-protection",
                                "Leaving may abandon the person I accepted responsibility to protect.",relation,obligation)
                            row.objections[#row.objections+1]="Leaving may abandon the person I accepted responsibility to protect."
                        end
                    elseif effect=="create-space" then
                        gain=2*v.selfPreservation+v.nerve+(frame.escapeBlocked and 1.5 or 0)
                        reason="Defensive action may create space to act or get away."
                    elseif effect=="stop-threat" then
                        gain=2.4*v.aggression+1.6*v.nerve+(close and v.selfPreservation or 0)
                        reason="Force may stop the threat, but it may fail."
                        if protects then
                            gain=gain+2*v.compassion+v.discipline
                            reason="Resisting may protect the person I accepted responsibility for, despite a cost to myself."
                        end
                    elseif effect=="possible-agreement" then
                        gain=1.8*v.compassion+v.discipline+0.5*v.selfPreservation
                        reason="Communication may open agreement; the other person still chooses their response."
                        if offer.kind=="concede" then
                            gain=gain+fear+v.selfPreservation
                            reason="Giving something up may open agreement; it does not guarantee the other person will stop."
                        end
                    elseif effect=="imposed-compliance" then
                        gain=2*v.aggression+v.nerve+v.discipline
                        reason="A demand may make the other person comply, but they may refuse or resist."
                    elseif effect=="mutual-support" then
                        gain=1.5*v.compassion+v.discipline+v.selfPreservation
                        reason="Cooperation may provide mutual support; reception and participation still need to happen."
                    end
                    if gain then
                        local concern=effect=="stop-threat" and (protects and "honor-accepted-protection" or "resist-threat")
                            or effect=="break-contact" and "preserve-own-life" or effect=="create-space" and "retain-room-to-act"
                            or effect=="imposed-compliance" and "compel-a-response" or effect=="mutual-support" and "mutual-support"
                            or "seek-agreement-without-assuming-assent"
                        consider(gain,effect,concern,reason,relation,obligation or situation)
                        row.reasons[#row.reasons+1]=reason
                        row.expectedEffects[#row.expectedEffects+1]={concept=effect,status="possible",basis=relation.basis}
                    else
                        row.objections[#row.objections+1]="I have not connected this effect to the concerns in this decision."
                    end
                else
                    consider(0,effect,"unresolved-means","I have not established this action's expected effect.",relation,situation)
                    row.objections[#row.objections+1]="Whether this action can "..effect:gsub("%-"," ").." is unresolved."
                    row.expectedEffects[#row.expectedEffects+1]={concept=effect,status="unresolved",
                        basis=relation and relation.basis or "no-personal-association"}
                end
            end
        end
        local exposure=offer.kind=="engage" or offer.kind=="defend"
        local ranged=offer.nativeMode=="ranged"
        local waiting=offer.kind=="communicate" or offer.kind=="coordinate" or offer.kind=="concede" or offer.kind=="watch"
        local execution={kind="native-execution",mode=offer.nativeMode,
            contactRequired=not ranged,closeBelief=close,floorKnown=geometry.floorKnown,
            z=frame.threat.z,observerZ=frame.threat.observerZ,sameFloor=geometry.sameFloor,
            reachability=geometry.reachability,basis="current-executor-offer-and-private-distance"}
        if exposure and (not ranged or close) then
            local cost=(1.7*v.selfPreservation+(1-v.nerve)*0.6+fear*0.8)
                *(frame.overwhelmed and 1.6 or 1)*(offer.kind=="defend" and 0.45 or 1)
            consider(-cost,"bodily-harm","preserve-own-life",ranged
                and "The nearby threat may harm me while I shoot." or "Close action may expose me to harm.",
                frame.relations and frame.relations["bodily-harm"],execution)
            row.objections[#row.objections+1]=frame.overwhelmed
                and "Facing several threats may expose me to harm even if this action works."
                or ranged and "Shooting leaves me exposed to the nearby threat."
                or "Close action exposes me to possible harm."
        elseif exposure and ranged then
            consider(0,"bodily-harm","preserve-own-life",
                "This shot does not require closing; whether the threat can retaliate remains unresolved.",
                frame.relations and frame.relations["bodily-harm"],execution)
            row.objections[#row.objections+1]="The shot may fail, and distance does not establish safety."
        end
        if close and waiting then
            consider(-3*v.selfPreservation-2*fear,"continued-exposure","preserve-own-life",
                "Waiting may leave the close threat able to act; native reach remains unconfirmed.",frame.relations and frame.relations["bodily-harm"],situation)
            row.objections[#row.objections+1]="Waiting for information or a response may leave the close threat able to act."
        end
        if offer.kind=="watch" then
            consider((unknown and 2 or 0)+(distant and 2 or 0)+0.5*v.discipline,"clearer-observation","understand-before-committing",
                "Watching may clarify what is happening; it does not prevent harm.",nil,situation)
            row.reasons[#row.reasons+1]="Watching may clarify what is happening; it does not prevent harm."
            if concerning then row.objections[#row.objections+1]="What I recognize about this danger makes distance alone insufficient reassurance." end
        end
        if frame.escapeBlocked and offer.kind=="withdraw" then
            consider(-3*v.selfPreservation-1,"movement-refused","find-a-usable-way-out",
                "No offered withdrawal is currently usable.",frame.relations and frame.relations["blocks-movement"],situation)
            row.objections[#row.objections+1]="No currently offered way out is usable; another route needs checking."
        end
        for _,objection in ipairs(offer.objections) do
            if not text(objection,128) then return nil,"invalid-conflict-objection" end
            row.objections[#row.objections+1]=objection
            local cost=objection=="blocks-movement" and 4
                or (objection=="bodily-harm" or objection=="exposure") and (v.selfPreservation+fear)
                or (objection=="unanswered" or objection=="response-unconfirmed") and v.discipline
                or objection=="loss-of-supplies" and (v.selfPreservation+0.5*v.discipline) or 0
            consider(-cost,objection,"resolve-an-executor-objection",objection,nil,
                {kind="executor-objection",objection=objection,basis="current-executor-offer"})
        end
        if offer.continuing then consider(0.5*v.discipline,"maintained-action","avoid-unnecessary-interruption",
            "The current action remains executable.",nil,{kind="native-continuity",offerId=offer.id}) end
        if not offer.available then row.objections[#row.objections+1]=offer.reason end
        row.reason=(row.reasons[1] or "I have not established a useful consequence of this option.")
            ..(#row.objections>0 and " "..row.objections[1] or "")
        candidates[#candidates+1]={row=row,merit=merit}
    end
    table.sort(candidates,function(a,b)
        if a.row.available~=b.row.available then return a.row.available end
        if a.merit==b.merit then return a.row.id<b.row.id end
        return a.merit>b.merit
    end)
    local selected
    for _,candidate in ipairs(candidates) do
        local row=candidate.row
        if row.available and not selected then selected=row end
        if row.available and row.continuing and frame.preserveContinuity
            and frame.priorAction and row.id==frame.priorAction.id then
            selected=row;break
        end
    end
    local alternatives={}
    for _,candidate in ipairs(candidates) do
        candidate.row.selected=selected and candidate.row.id==selected.id or false
        alternatives[#alternatives+1]=candidate.row
    end
    return {selected=selected and selected.id,kind=selected and selected.kind,
        reason=selected and selected.reason or "No offered action is presently admitted; I need another feasible response.",
        alternatives=alternatives,frameId=frame.frameId,evidenceKey=frame.evidenceKey,
        continuing=selected and selected.continuing and frame.preserveContinuity==true or false}
end

return M
