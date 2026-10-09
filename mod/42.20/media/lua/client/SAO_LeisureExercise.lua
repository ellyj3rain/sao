-- NPC-scoped adaptation of installed ISFitnessAction (B42.20).
-- Source SHA256 d2d31a0984baba07023a25ee157a04b463a8a7e1fe31a36eeb9404c3d800d458.
-- Native physical lifecycle is retained. Player UI threshold is its shipped 2;
-- the two global clock writes are omitted. FWO player-slot overrides stay separate.
require "Definitions/FitnessExercises"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISBaseTimedAction"

-- The installed base stop resets every action for a player. This source owner
-- retires only its exact queued action, retaining the native queue lifecycle.
local SourceBaseTimedAction=ISBaseTimedAction
local ISBaseTimedAction=SourceBaseTimedAction:derive("SAOExerciseSourceBase")
local function removeOwnedAction(action)
    if not action or not ISTimedActionQueue.hasAction(action) then return end
    local queue=ISTimedActionQueue.getTimedActionQueue(action.character)
    if queue.current==action then queue:onCompleted(action)
    elseif queue.removeFromQueue then queue:removeFromQueue(action) end
end
function ISBaseTimedAction:stop()
    removeOwnedAction(self)
    self.character:setIsFarming(false)
end

local SAONpcExerciseCore = ISBaseTimedAction:derive("SAONpcExerciseCore");

function SAONpcExerciseCore:isValidStart()
	return self.character:getMoodles():getMoodleLevel(MoodleType.ENDURANCE) <= 2
end

function SAONpcExerciseCore:isValid()
	return self.character:getVehicle() == nil;
end

function SAONpcExerciseCore:waitToStart()
	if self.character:isAiming() then
		self.character:nullifyAiming()
	end
	if self.character:isSneaking() then
		self.character:setSneaking(false)
	end
    if self.character:isSittingOnFurniture() then
        self.character:setVariable("forceGetUp", true)
        self.character:setVariable("pressedRunButton", true) -- needed by PlayerGetUpState.enter()
        self.character:setVariable("getUpQuick", true) -- overridden by PlayerGetUpState.enter()
    end
	if not self.character:isCurrentState(IdleState.instance()) then
		-- Only the player.idle state has a transition to the player.fitness state.
		return true
	end
	return false
end

function SAONpcExerciseCore:update()
	if self.character:isClimbing() or self.character:isAiming() or self.character:isSittingOnFurniture() then
		self:forceStop();
	end
	if self.character:isSneaking() then
		self.character:setSneaking(false)
	end
	if self.character:pressedMovement(true) or self.character:getMoodles():getMoodleLevel(MoodleType.ENDURANCE) > 2 then
		self.character:setVariable("ExerciseStarted", false);
		self.character:setVariable("ExerciseEnded", true);
		self:forceStop();
	end
	
	if getGameTime():getCalender():getTimeInMillis() > self.endMS then
		self.character:setVariable("ExerciseStarted", false);
		self.character:setVariable("ExerciseEnded", true);
		self:forceStop();
	end
	
	self.character:setMetabolicTarget(self.exeData.metabolics);
end


function SAONpcExerciseCore:start()
	self.action:setUseProgressBar(false)
	if self.character:getCurrentState() ~= FitnessState.instance() then
		self.character:setVariable("ExerciseType", self.exercise);
		self.character:reportEvent("EventFitness");
		self.character:clearVariable("ExerciseStarted");
		self.character:clearVariable("ExerciseEnded");
		
		self.character:reportEvent("EventUpdateFitness");
	end

--	self:showHandModel();
end

function SAONpcExerciseCore:showHandModel()
	if self.exeData.item then
		if self.character:getPrimaryHandItem() and self.character:getPrimaryHandItem():getType() == self.exeData.item then
			self:setOverrideHandModels(self.character:getPrimaryHandItem():getStaticModel(), nil);
		elseif self.character:getSecondaryHandItem() and self.character:getSecondaryHandItem():getType() == self.exeData.item then
			self:setOverrideHandModels(nil, self.character:getSecondaryHandItem():getStaticModel());
		end
	else
		self:setOverrideHandModels(nil, nil);
	end
end

function SAONpcExerciseCore:forceStop()
    self.fitness:setCurrentExercise(nil);
    self.action:forceStop();
end

function SAONpcExerciseCore:stop()
	if not isClient() and not isServer() then
		self.character:SetVariable("FitnessFinished","true");
	end
    if isClient() then
        self.character:updateHandEquips()
    end

	self.character:setVariable("ExerciseEnded", true);
	-- The operator owns the global game clock.
    self.fitness:setCurrentExercise(nil)
	ISBaseTimedAction.stop(self);
end

function SAONpcExerciseCore:complete()
	if not isClient() and not isServer() then
		self.character:SetVariable("FitnessFinished","true");
	end
	emulateAnimEventOnce(self.netAction, 100, nil, "FitnessFinished=TRUE")
	return true;
end

function SAONpcExerciseCore:perform()
	self.character:PlayAnim("Idle");
	
--	if self.fitnessUI then
--		self.fitnessUI:updateExercises();
--	end
	
	self.character:setVariable("ExerciseEnded", true);
--	print("REP NBR!:", self.repnb)
	-- The operator owns the global game clock.
	ISBaseTimedAction.perform(self);
end

-- handle endurance loss, regularity, stats boosts, etc.
function SAONpcExerciseCore:exeLooped()
	self.repnb = self.repnb + 1;
	self.fitness:exerciseRepeat();
	self:setFitnessSpeed();
end

function SAONpcExerciseCore:serverStart()
	self.fitness = self.character:getFitness();
	self.fitness:init();
	self.fitness:setCurrentExercise(self.exeDataType);

	local period = 0;
	if self.exeDataType == "squats" then
		period = 3000;
	elseif self.exeDataType == "pushups" then
		period = 1300;
    elseif self.exeDataType == "situp" then
        period = 1300;
	elseif self.exeDataType == "burpees" then
		period = 2400;
	elseif self.exeDataType == "barbellcurl" then
		period = 2200;
	elseif self.exeDataType == "dumbbellpress" then
		period = 1500;
	elseif self.exeDataType == "bicepscurl" then
		period = 1900;
	end

	emulateAnimEvent(self.netAction, period, "ActiveAnimLooped", nil)
	end

function SAONpcExerciseCore:serverStop()
	emulateAnimEventOnce(self.netAction, 100, nil, "FitnessFinished=TRUE")
    self.fitness:setCurrentExercise(nil);
end

function SAONpcExerciseCore:animEvent(event, parameter)
	local isSinglePlayerMode = (not isClient() and not isServer());

	if isServer() or isSinglePlayerMode then
		if parameter == "FitnessFinished=TRUE" then
			self:forceStop();
		end

		-- Check isStarted() to avoid exercise-related things in waitToStart()
		if event == "ActiveAnimLooped" and (self:isStarted() or isServer()) then
			self:exeLooped();
		end
	else
		if event == "ActiveAnimLooped" and self:isStarted() then
			if self.exeData.prop == "switch" then -- switch hand used every X times
				self.switchTime = self.switchTime -1;
				if self.switchTime == 1 then
					self.switchTime = 5;
					if self.switchHandUsed == "right" then
						self.switchHandUsed = "left";
						self.character:setVariable("ExerciseHand", "left");
						self.character:setSecondaryHandItem(self.character:getPrimaryHandItem());
						self.character:setPrimaryHandItem(nil);
					else
						self.switchHandUsed = "right";
						self.character:clearVariable("ExerciseHand");
						self.character:setPrimaryHandItem(self.character:getSecondaryHandItem());
						self.character:setSecondaryHandItem(nil);
					end
				end
			end
			self.character:reportEvent("EventUpdateFitness");
	end

--		print("loopityloop", self.exeData.prop)
	end
end

function SAONpcExerciseCore:setFitnessSpeed()
	self.character:setFitnessSpeed()
end

function SAONpcExerciseCore:getDuration()
	return 5000000;
end

function SAONpcExerciseCore:new(character, exercise, timeToExe, exeData, exeDataType)
	local o = ISBaseTimedAction.new(self, character);
	o.character = character;
	o.exercise = exercise;
	o.timeToExe = timeToExe;
	o.exeData = exeData;
	o.exeDataType = exeDataType;
	o.switchTime = 5;
	o.switchHandUsed = "right";
	-- calcul time we need in ingame minutes
	o.startMS = getGameTime():getCalender():getTimeInMillis();
	o.endMS = o.startMS + (timeToExe * 60000)
	o.maxTime = o:getDuration();
	o.fitness = character:getFitness();
	o.repnb = 0;

	o:setFitnessSpeed();
	o.fitness:setCurrentExercise(exeDataType);
	
	o.caloriesModifier = 3;
	
	return o;
end

SAO = SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end
SAO.LeisureExercise = SAO.LeisureExercise or {}
local E = SAO.LeisureExercise
local runtime = {}
local EXERCISES = {"squats", "pushups", "situp", "burpees", "barbellcurl", "dumbbellpress", "bicepscurl"}
local REVISION = "sha256:d2d31a0984baba07023a25ee157a04b463a8a7e1fe31a36eeb9404c3d800d458"
local FWO_REVISION = "sha256:ed2182547d28b4f0eabd7616553fb487b5fd8ae75c49b3afc9262e859bb2fed4"
local YOGA_REVISION = "sha256:00430eadeba1d79ee592697de1a6ccec3de1e9f5b6f5a3de423d3fe410102e32"
local AQUARIUM_REVISION = "sha256:b682224fb83fa1333e99b49fb7b7a217c382a087c3e239b716eb76c220a13cd9"
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1000000000 end
local function copy(v)
    if type(v)~="table" then return v end
    local out={} for k,x in pairs(v) do out[k]=copy(x) end return out
end
local function record(id) return SAO.Identity and SAO.Identity.get(id) end
local function hours() return SAO.History and SAO.History.countyHours() end
local function live(id,body)
    local r=record(id)
    return r and not r.dead and body and SAO.Body and SAO.Body.get(id)==body
        and SAO.Needs and SAO.Needs.ownsRecoveryBody(id,body)
        and not body:isDead() and not body:isAsleep() and body:isExistInTheWorld()
end
local function permission(id,body)
    return SAO.Standing and SAO.Standing.mayEnterCurrent
        and SAO.Standing.mayEnterCurrent(id,body:getX(),body:getY())==true
end
local function equipment(body,data)
    if not data.item then return true,nil end
    for hand=1,2 do
        local item=hand==1 and body:getPrimaryHandItem() or body:getSecondaryHandItem()
        if item and item:getFullType()==data.item then
            local items=SAOJavaBridge:privateCarriedItems(body)
            for i=0,items:size()-1 do if items:get(i)==item then return true,item end end
        end
    end
    return false
end
local function physical(body)
    return body:getVehicle()==nil and not body:isClimbing() and not body:isAiming()
        and not body:isSneaking() and not body:isSittingOnFurniture()
        and not body:pressedMovement(true) and body:getMoodles():getMoodleLevel(MoodleType.ENDURANCE)<=2
end
local function sample(body,activity)
    local out={}
    local stats=body:getStats()
    for _,name in ipairs({"ENDURANCE","FATIGUE","BOREDOM","UNHAPPINESS","STRESS","THIRST","TEMPERATURE"}) do
        local stat=CharacterStat and CharacterStat[name]
        if stat then local n=stats:get(stat);if finite(n) then out[name]=n end end
    end
    if body.getXp and Perks then
        for _,name in ipairs({"Fitness","Strength","Sprinting","Nimble"}) do
            local perk=Perks[name];local n=perk and body:getXp():getXP(perk)
            if finite(n) then out["XP:"..name]=n end
        end
    end
    local data=body:getModData();local yoga=data.LSHiddenSkills and data.LSHiddenSkills.Yoga
    if yoga then out.YogaLevel=yoga[1];out.YogaXP=yoga[2] end
    if data.LSMoodles and data.LSMoodles.Zen then out.Zen=data.LSMoodles.Zen.Value end
    if activity~="watch-aquarium" then
        local n=body:getFitness():getRegularity(activity)
        if finite(n) then out.regularity=n end
    end
    return out
end
local function effects(before,after)
    local deltas={} for k,n in pairs(before or {}) do
        if finite(after[k]) then deltas[k]=after[k]-n end
    end
    return {before=copy(before),after=copy(after),deltas=deltas}
end
local function bodyMatches(w,body)
    local token=body:getModData().SAOExternalToken
    return w.bodyGenerationKnown==(type(token)=="string" and token~="") and w.bodyToken==token
end
local function validWork(w,id)
    return type(w)=="table" and w.actorId==id and finite(w.sequence)
        and w.sequence>=1 and w.sequence==math.floor(w.sequence)
        and w.workId=="exercise/"..id.."/"..w.sequence
        and type(w.purposeId)=="string" and #w.purposeId>0 and #w.purposeId<=160
        and finite(w.admittedAtHours) and ((finite(w.minutes) and w.minutes>0)
            or (w.family=="yoga" and w.minutes==nil and w.sourceDuration=="phase-controlled"))
        and ((w.family=="exercise" and w.sourceId=="native:ISFitnessAction" and w.revision==REVISION)
            or (w.family=="equipment-exercise" and w.sourceId=="FWO:FWOTreadmillBenchpressExercise" and w.revision==FWO_REVISION)
            or (w.family=="yoga" and w.sourceId=="Lifestyle:LSYogaAction" and w.revision==YOGA_REVISION)
            or (w.family=="aquarium" and w.sourceId=="KnoxAquarium:KA_Comfort" and w.revision==AQUARIUM_REVISION))
        and type(w.bodyGenerationKnown)=="boolean"
        and ((w.bodyGenerationKnown and type(w.bodyToken)=="string" and #w.bodyToken>0)
            or (w.bodyGenerationKnown==false and w.bodyToken==nil))
end
local function owned(active)
    local w=active.work
    local r=record(w.actorId)
    local P=SAO.ProceduralPlanning
    local admission=P and P.hobbyAdmission and P.hobbyAdmission(w.actorId,w.purposeId,w.workId)
    local admitted=type(admission)=="table" and admission.ownerName=="SAO.LeisureExercise"
    for _,field in ipairs({"actorId","sequence","workId","purposeId","sourceId","revision","family","activity",
        "itemKey","itemType","objectKey","runtimeInstance","secondaryItemKey","sourceSkillLevel","nativeOwner","minutes","sourceDuration",
        "bodyGenerationKnown","bodyToken","admittedAtHours"}) do
        if not admitted or admission[field]~=w[field] then admitted=false;break end
    end
    return admitted and r and validWork(w,w.actorId) and r.exerciseLeisureWork==w and runtime[w.actorId]==active
        and live(w.actorId,active.body) and bodyMatches(w,active.body)
        and finite(hours()) and hours()>=w.admittedAtHours
end
local function finish(active,status,reason)
    local w=active.work;local r=record(w.actorId)
    if not r or r.exerciseLeisureWork~=w then return false end
    w.status,w.reason,w.atHours=status,reason,hours()
    w.nativeProgress=copy(active.progress)
    local ok,after=false,nil
    if live(w.actorId,active.body) and bodyMatches(w,active.body) then ok,after=pcall(sample,active.body,w.activity) end
    w.measuredEffects=ok and effects(active.before,after) or {before=copy(active.before),afterUnavailable=true}
    w.measuredEffects.intervalAttribution="unassigned; immediate source-call and repetition effects retained separately"
    r.exerciseLeisureOutcomes=r.exerciseLeisureOutcomes or {}
    r.exerciseLeisureOutcomes[#r.exerciseLeisureOutcomes+1]=copy(w)
    if #r.exerciseLeisureOutcomes>32 then table.remove(r.exerciseLeisureOutcomes,1) end
    local P=SAO.ProceduralPlanning
    local admission=P and P.hobbyAdmission and P.hobbyAdmission(w.actorId,w.purposeId,w.workId)
    local consumed=admission and admission.ownerName=="SAO.LeisureExercise" and P.consumeHobbyOutcome
        and P.consumeHobbyOutcome(w.actorId,w.sequence,"SAO.LeisureExercise")==true
    r.exerciseLeisureOutcomes[#r.exerciseLeisureOutcomes].plannerConsumed=consumed==true
    r.exerciseLeisureWork=nil;runtime[w.actorId]=nil
    return true
end
-- The source's comfortTanksNear scans every nearby square. This NPC adaptation
-- resolves only Perception's actual, fresh, visible object acquisitions and
-- retains original predicates, sandbox settings, constants and native Stats.
local function tanks(id,body)
    local K=KnoxAquarium
    if not K or not K.comfort or not K.comfortEnabled or not K.comfortEnabled()
        or isClient() then return {} end
    local tick=SAO.History.ticks()
    local context=SAO.Perception and SAO.Perception.conceptContext(id,tick)
    if not context or context.status~="observed" then return {} end
    local found,seen={},{}
    local range,maxTanks=K.comfortRange(),K.comfortMaxTanks()
    if not finite(range) or range<=0 or not finite(maxTanks) or maxTanks<1 or maxTanks>32 then return {} end
    for _,row in ipairs(context.observations or {}) do
        if #found>=maxTanks then break end
        if row.actorId==id and row.kind=="object" and row.concept=="aquarium"
            and row.source=="native-personal-visibility" and finite(row.at)
            and row.at<=tick and tick-row.at<=120 and row.aquariumMode=="water"
            and row.aquariumOccupied==true and row.aquariumWaterPresent==true
            and type(row.spriteName)=="string" and type(row.key)=="string" and type(row.runtimeInstance)=="string"
            and not seen[row.key] then
            local x,y,z,index=row.key:match("^object:([%-0-9]+):([%-0-9]+):([%-0-9]+):([0-9]+):aquarium$")
            x,y,z,index=tonumber(x),tonumber(y),tonumber(z),tonumber(index)
            if x and y and z and index==row.objectIndex and z==body:getZ()
                and x>=math.floor(body:getX()-range) and x<=math.floor(body:getX()+range)
                and y>=math.floor(body:getY()-range) and y<=math.floor(body:getY()+range)
                and SAO.Standing.mayEnterCurrent(id,x,y)==true then
                local square=body:getCell():getGridSquare(x,y,z)
                local objects=square and square:getObjects()
                local obj=objects and index>=0 and index<objects:size() and objects:get(index)
                local current=SAO.Perception.resolveLeisureObject and SAO.Perception.resolveLeisureObject(id,body,row.key)
                if current~=obj then obj=nil end
                local sprite=obj and obj:getSprite()
                local data=obj and obj:getSquare()==square and sprite and sprite:getName()==row.spriteName and K.tankData(obj)
                if data and not seen[obj] and not K.isDry(data) and #(data.fish or {})>=K.comfort.minFish
                    and (tonumber(data.water) or 0)>0 then
                    found[#found+1]={key=row.key,object=obj,at=row.at,runtimeInstance=row.runtimeInstance}
                    seen[row.key]=true;seen[obj]=true
                end
            end
        end
    end
    return found
end
-- Source prerequisites are resolved from current acquired physical objects.
local function nativeDefinitionInit(id,body,activity)
    local bridge=SAOJavaBridge
    if not bridge or not bridge.initFitnessExerciseDefinitions then return false end
    local defs=copy(FitnessExercises.exercisesType)
    local scope=record(id).exerciseDefinitionScope
    local moodles=body:getModData().LSMoodles
    if scope and (not moodles or not moodles.Zen or moodles.Zen.Level<=0
        or not SandboxVars.Text or not SandboxVars.Text.DividerMeditationNew) then
        record(id).exerciseDefinitionScope=nil;body:getModData().LSZenActive=nil;scope=nil
    end
    if scope and scope.bodyToken==body:getModData().SAOExternalToken then
        for name,value in pairs(scope.modifiers or {}) do if defs[name] then defs[name].xpMod=value end end
    end
    if activity=="treadmill" then
        local modifier=1.5*(SandboxVars.FWOWorkingTreadmill.FitnessXPMultiply or 1)
        if modifier<=0 then modifier=0.000001 end
        if not defs.treadmill then return false end
        defs.treadmill.xpMod=modifier
    end
    local result=bridge:initFitnessExerciseDefinitions(body,defs)
    return result=="initialized" or result=="retained"
end
local function machineReady(id,body,row,intent)
    if not SAO.Perception or not SAO.Perception.resolveLeisureObject or type(row.key)~="string"
        or type(row.runtimeInstance)~="string" then return nil end
    local obj=SAO.Perception.resolveLeisureObject(id,body,row.key)
    local square=obj and obj:getSquare();local sprite=obj and obj:getSprite()
    if not square or not sprite or sprite:getName()~=row.spriteName or body:getZ()~=square:getZ() then return nil end
    local props=sprite:getProperties();local name=props:get("CustomName");local group=props:get("GroupName")
    local activity
    local walkable
    if name=="Hamster Wheel" and group=="Human" and row.concept=="fitness-treadmill" then
        activity="treadmill";walkable={recreational_sports_01_28=true,recreational_sports_01_31=true,recreational_sports_01_37=true,recreational_sports_01_38=true}
    elseif name=="Contraption" and group=="Fitness" and row.concept=="fitness-bench" then
        activity="benchpress";walkable={recreational_sports_01_45=true,recreational_sports_01_40=true,recreational_sports_01_43=true,recreational_sports_01_46=true}
    else return nil end
    if walkable[row.spriteName] then return nil end
    local facing=props:get("Facing");if facing~=row.facing then return nil end
    local methods={N="getN",S="getS",E="getE",W="getW"}
    local directions={N=IsoDirections.S,S=IsoDirections.N,E=IsoDirections.W,W=IsoDirections.E}
    local method=methods[facing];local front=method and square[method](square)
    if not front or (not intent and body:getCurrentSquare()~=front) or not SAO.Standing.mayEnterCurrent(id,square:getX(),square:getY())
        or not SAO.Standing.mayEnterCurrent(id,front:getX(),front:getY()) then return nil end
    local preparation={targetX=front:getX(),targetY=front:getY(),targetZ=front:getZ()}
    if body:getCurrentSquare()~=front then preparation.frontSquare={x=front:getX(),y=front:getY(),z=front:getZ()} end
    if body:isSitOnGround() then if not intent then return nil end;preparation.stand=true end
    if body:getMoodles():getMoodleLevel(MoodleType.PAIN)>3
        or body:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD)>2 then return nil end
    local config=SandboxVars.FWOWorkingTreadmill
    if not config.BenchTreadKeepBagsOn then
        for i=0,body:getWornItems():size()-1 do
            local bag=body:getWornItems():get(i):getItem()
            if instanceof(bag,"InventoryContainer") then
                if not intent then return nil end
                preparation.removeBags=preparation.removeBags or {}
                preparation.removeBags[#preparation.removeBags+1]={itemKey=tostring(bag:getID()),itemType=bag:getFullType()}
            end
        end
    end
    local primary,secondary=body:getPrimaryHandItem(),body:getSecondaryHandItem()
    local function held(item,types)
        if not item or not types[item:getType()] then return false end
        local items=SAOJavaBridge:privateCarriedItems(body)
        for i=0,items:size()-1 do if items:get(i)==item then return true end end
        return false
    end
    local item
    if activity=="treadmill" then
        if primary or secondary then if not intent then return nil end;preparation.clearHands=true end
        local power=(SandboxVars.ElecShutModifier>-1 and getGameTime():getNightsSurvived()<SandboxVars.ElecShutModifier)
            or square:haveElectricity() or front:haveElectricity()
        if not power then return nil end
    else
        if held(primary,{BarBell=true,BarBell_Forged=true}) then item=primary
        elseif held(primary,{DumbBell=true,DumbBell_Forged=true})
            and held(secondary,{DumbBell=true,DumbBell_Forged=true}) and primary~=secondary then item=primary
        elseif intent then
            local items=SAOJavaBridge:privateCarriedItems(body);local gathered={}
            for _,kind in ipairs({"BarBell","BarBell_Forged","DumbBell","DumbBell_Forged"}) do
                for i=0,items:size()-1 do
                    local candidate=items:get(i)
                    if candidate:getType()==kind then
                        if kind=="BarBell" or kind=="BarBell_Forged" then item=candidate;break end
                        gathered[#gathered+1]=candidate
                    end
                end
                if item then break end
            end
            if not item and #gathered>=2 then item=gathered[1];secondary=gathered[2] end
            if not item then return nil end
            preparation.equipPrimary={itemKey=tostring(item:getID()),itemType=item:getFullType(),
                twoHands=item:getType()=="BarBell" or item:getType()=="BarBell_Forged"}
            if secondary and (item:getType()=="DumbBell" or item:getType()=="DumbBell_Forged") then
                preparation.equipSecondary={itemKey=tostring(secondary:getID()),itemType=secondary:getFullType()}
            end
        else return nil end
    end
    return {object=obj,front=front,facing=directions[facing],activity=activity,item=item,
        secondary=secondary,key=row.key,runtimeInstance=row.runtimeInstance,preparation=preparation}
end
local function machines(id,body,intent)
    local out={}
    if isClient() or isServer() or not SandboxVars.FWOWorkingTreadmill
        or not (SAO.SourceIntegration and SAO.SourceIntegration.available("FWOBenchPressTreadmill")) or not SAO.Perception
        or not SAO.Perception.leisureObjects or not SAOJavaBridge.initFitnessExerciseDefinitions then return out end
    for _,row in ipairs(SAO.Perception.leisureObjects(id,body) or {}) do
        if row.actorId==id and row.source=="native-personal-visibility" then
            local machine=machineReady(id,body,row,intent)
            if machine and FitnessExercises.exercisesType[machine.activity] then out[#out+1]=machine end
        end
    end
    return out
end

function E.sourceAvailability(family)
    if family=="yoga" then return SAO.LeisureSkill~=nil and SAOJavaBridge.initFitnessExerciseDefinitions~=nil,"requires-source-person-moodles-and-private-yoga-mat-when-enabled" end
    if family=="aquarium" then
        return SAO.Perception and SAO.Perception.conceptContext~=nil and KnoxAquarium~=nil,
            "requires-current-private-stocked-tank-observation"
    end
    if family=="equipment-exercise" then return SAOJavaBridge and SAOJavaBridge.initFitnessExerciseDefinitions~=nil and SandboxVars.FWOWorkingTreadmill~=nil,"requires-current-private-prepared-machine-and-source-native-definition-bridge" end
    return family=="exercise"
end
local yogaOffer
function E.offers(id,body)
    if not live(id,body) or not finite(hours()) or not SAO.Needs.workAvailable(body)
        or not permission(id,body) then return {} end
    local out={}
    local conceptual=SAO.ConceptKnowledge and SAO.ConceptKnowledge.infer(id,"exercise","physical-practice")
    if conceptual and conceptual.status=="expectation" and physical(body) then
        for _,name in ipairs(EXERCISES) do
            local data=FitnessExercises and FitnessExercises.exercisesType[name]
            if data and data.type==name and finite(data.xpMod) and data.metabolics then
                local available,item=equipment(body,data)
                if available then out[#out+1]={id="exercise:"..name,family="exercise",activity=name,
                    sourceId="native:ISFitnessAction",revision=REVISION,minutes=10,
                    itemKey=item and tostring(item:getID()),itemType=item and item:getFullType()} end
            end
        end
    end
    if conceptual and conceptual.status=="expectation" and physical(body) then
        for _,machine in ipairs(machines(id,body)) do
            out[#out+1]={id="equipment:"..machine.key,family="equipment-exercise",activity=machine.activity,
                sourceId="FWO:FWOTreadmillBenchpressExercise",revision=FWO_REVISION,minutes=10,
                objectKey=machine.key,runtimeInstance=machine.runtimeInstance,
                targetX=machine.front:getX(),targetY=machine.front:getY(),targetZ=machine.front:getZ(),
                itemKey=machine.item and tostring(machine.item:getID()),itemType=machine.item and machine.item:getFullType(),
                secondaryItemKey=machine.secondary and tostring(machine.secondary:getID())}
        end
    end
    local yoga=yogaOffer and yogaOffer(id,body,conceptual)
    if yoga then out[#out+1]=yoga end
    local available=tanks(id,body)
    if #available>0 then out[#out+1]={id="aquarium:"..available[1].key,family="aquarium",
        activity="watch-aquarium",sourceId="KnoxAquarium:KA_Comfort",revision=AQUARIUM_REVISION,
        objectKey=available[1].key,runtimeInstance=available[1].runtimeInstance,minutes=1} end
    return out
end
local function selected(id,body,offer)
    if type(offer)~="table" then return nil end
    for _,held in ipairs(E.offers(id,body)) do
        if held.id==offer.id and held.family==offer.family and held.activity==offer.activity
            and held.sourceId==offer.sourceId and held.revision==offer.revision
            and held.itemKey==offer.itemKey and held.itemType==offer.itemType
            and held.objectKey==offer.objectKey and held.runtimeInstance==offer.runtimeInstance
            and held.secondaryItemKey==offer.secondaryItemKey and held.sourceSkillLevel==offer.sourceSkillLevel
            and held.minutes==offer.minutes and held.sourceDuration==offer.sourceDuration then return held end
    end
end
local perk_boost_map = {
    [1] = 1.75,
    [2] = 2,
    [3] = 2.25,
}

local function calcMulExe(player, perkType, perkLvl, avgRegularity, currentExercise)
    if not player or not perkType then return end
    
    local mulXP = 1
    local playerFitness = player:getFitness()
    
    -- 1. Initial Perk Bonus
    if SandboxVars.FWOFitness.InitialPerkBonus then
        local perkBoost = player:getXp():getPerkBoost(perkType)
        if perk_boost_map[perkBoost] then
            mulXP = mulXP * perk_boost_map[perkBoost]
        end
    end
    
    -- 2. Current Exercise Regularity Bonus
    -- CRITICAL: Uses passed currentExercise parameter, not global
    if SandboxVars.FWOFitness.currentExerciseRegularityBonus and currentExercise ~= nil then
        local regularity = playerFitness:getRegularity(currentExercise)
        local offset = SandboxVars.FWOFitness.currentExerciseOffset or 25
        local rate = SandboxVars.FWOFitness.currentExerciseRate or 5.0
        mulXP = mulXP + ((regularity - offset) * rate) / 100
    end
    
    -- 3. Average Exercise Regularity Bonus
    if SandboxVars.FWOFitness.AverageExerciseRegularityBonus then
        mulXP = mulXP + ((avgRegularity / 100) * SandboxVars.FWOFitness.AverageExerciseRegularityBonus)
    end
    
    -- 4. Level Bonus
    if SandboxVars.FWOFitness.LevelBonus then
        mulXP = mulXP + (perkLvl * SandboxVars.FWOFitness.LevelBonus)
    end
    
    -- 5. Space Out Exercise Bonus/Nerf
    if SandboxVars.FWOFitness.SpaceOutExercise then
        if perkType == Perks.Strength then
            local stiffnessTimer = playerFitness:getCurrentExeStiffnessTimer("arms")
            if stiffnessTimer < 60 and stiffnessTimer > 0 then
                mulXP = mulXP * (SandboxVars.FWOFitness.SpaceOutExerciseNegative or 0.90)
            end
        elseif perkType == Perks.Fitness then
            local legsTimer = playerFitness:getCurrentExeStiffnessTimer("legs")
            local absTimer = playerFitness:getCurrentExeStiffnessTimer("abs")
            if (legsTimer < 60 and legsTimer > 0) or (absTimer < 60 and absTimer > 0) then
                mulXP = mulXP * (SandboxVars.FWOFitness.SpaceOutExerciseNegative or 0.90)
            end
        end
    end
    
    -- 6. Rested Bonus (muscle soreness check)
    if SandboxVars.FWOFitness.RestedBonus then
        if playerFitness:onGoingStiffness() then
            mulXP = mulXP * (SandboxVars.FWOFitness.RestedBonusNegative or 0.90)
        end
    end
    
    -- 7. Global XP Multiplier
    if SandboxVars.FWOFitness.XPMultiplier then
        mulXP = mulXP * SandboxVars.FWOFitness.XPMultiplier
    end
    
    -- 8. Passive Multiplier (when not exercising)
    if currentExercise == nil then
        mulXP = mulXP * (SandboxVars.FWOFitness.PassiveMultiplier or 1.0)
    end
    
    -- Apply the multiplier. addXpMultiplier(perk, multiplier, minLevel, maxLevel) is a
    -- LEVEL-BRACKET gate, not a timer (confirmed against vanilla ISReadABook.lua's skill
    -- book logic, which uses the same call to bound a book's effect between its intrinsic
    -- min/max trainable level and the character's current perk level). There is no
    -- time-based decay here: the multiplier stays in the XP multiplier map, valid while
    -- perkLvl (current level) <= 10, until something overwrites or removes it.
    -- We keep it accurate by re-issuing this call on every exercise start/stop AND on the
    -- EveryTenMinutes tick (see CheckRegularity below), so it's continuously refreshed
    -- rather than left to expire on its own.
    player:getXp():addXpMultiplier(perkType, mulXP, perkLvl, 10)
end

--- Calculate average regularity and apply multipliers for a player
-- @param player IsoGameCharacter - The player character
-- @param currentExercise string|nil - Current exercise for this player
local function processPlayerRegularity(player, currentExercise)
    if not player or player:isDead() then return end
    
    local sumAverage = 0
    local count = 0
    
    for k, v in pairs(FitnessExercises.exercisesType) do
        count = count + 1
        sumAverage = sumAverage + player:getFitness():getRegularity(k)
    end
    
    if count == 0 then return end
    
    sumAverage = math.ceil(sumAverage * 100) / 100
    local totAverage = math.ceil((sumAverage / count) * 100) / 100
    
    -- Apply multipliers for both Strength and Fitness
    calcMulExe(player, Perks.Strength, player:getPerkLevel(Perks.Strength), totAverage, currentExercise)
    calcMulExe(player, Perks.Fitness, player:getPerkLevel(Perks.Fitness), totAverage, currentExercise)
end


local function fwoActive() return SandboxVars and SandboxVars.FWOFitness and SAO.SourceIntegration and SAO.SourceIntegration.available("FWOFitnessWorkoutOverhaul") end
local function fwoRegularity(body,exercise)
    if fwoActive() then processPlayerRegularity(body,exercise) end
end
local function fwoMood(body)
    if not fwoActive() or (getActivatedMods and getActivatedMods():contains("DynamicTraits")) then return end
    local player=body
    local boredomMul=SandboxVars.FWOFitness.BoredomMultiplier or 1
    local unhappyMul=SandboxVars.FWOFitness.UnhappynessMultiplier or 1
    player:getStats():remove(CharacterStat.BOREDOM,0.33*boredomMul)
    player:getStats():remove(CharacterStat.UNHAPPINESS,0.33*unhappyMul)
    player:getStats():remove(CharacterStat.STRESS,0.004)
    player:getStats():remove(CharacterStat.NICOTINE_WITHDRAWAL,0.0004)
    player:getStats():remove(CharacterStat.ANGER,0.004)
end
local function addTreadmillXP(player, weightMultiplier)
    if not player then return end

    -- Default multiplier if not provided
    weightMultiplier = weightMultiplier or 1.0

    local strengthXPMultiply = SandboxVars.FWOWorkingTreadmill.StrengthXPMultiply or 1
    local sprintingXPMultiply = SandboxVars.FWOWorkingTreadmill.SprintingXPMultiply or 1

    -- Sprinting XP: 0.139 per rep (increased by 25% from 0.111)
    local sprintingXp = 0.139 * sprintingXPMultiply
    -- Strength XP: 0.075 per rep, scaled by weight carried (1.0-2.0x)
    local strengthXp = 0.075 * strengthXPMultiply * weightMultiplier

    -- Always award Sprinting XP (treadmill is cardio)
    addXp(player, Perks.Sprinting, sprintingXp)
    
    -- Award Strength XP only when carrying 50%+ weight
    if player:getInventoryWeight() > player:getMaxWeight() * 0.5 then
        addXp(player, Perks.Strength, strengthXp)
    end
end

local function fwoEquipmentRepeat(self)
    local player = self.character

    -- Set metabolic target for heat/sweat system (matches vanilla fitness)
    if self.exeData and self.exeData.metabolics then
        self.character:setMetabolicTarget(self.exeData.metabolics)
    end

    -- Only process treadmill/benchpress exercises
    if self.exercise == "treadmill" or self.exercise == "benchpress" then
        -- Ensure fitness state is active
        if self.character:getCurrentState() ~= FitnessState.instance() then
            self.character:setVariable("ExerciseType", self.exercise)
            self.character:reportEvent("EventFitness")
            self.character:clearVariable("ExerciseStarted")
            self.character:clearVariable("ExerciseEnded")
            self.character:reportEvent("EventUpdateFitness")
        end

        -- ====================================================================
        -- SERVER-AUTHORITATIVE LOGIC (XP + Stats only on server/dedicated)
        -- ====================================================================
        if isServer() or (not isClient() and not isServer()) then
            -- ====================================================================
            -- TREADMILL EXERCISE (Cardio - Higher intensity)
            -- ====================================================================
            if self.exercise == "treadmill" then
                local inventoryWeight = player:getInventoryWeight() or 0
                local maxWeight = player:getMaxWeight() or 1
                local weightRatio = inventoryWeight / maxWeight

                -- Calculate weight multiplier: 50% weight = 1.0x, 100% weight = 2.0x strength XP
                local weightMultiplier = 1.0
                if weightRatio > 0.5 then
                    weightMultiplier = 1.0 + ((weightRatio - 0.5) * 2.0)

                    -- Bonus stamina drain for weighted training. exeLooped already fires at a
                    -- fixed rate per unit of IN-GAME time (customPeriods above are simulated
                    -- ms), so a fixed number of reps always occurs over a given stretch of
                    -- game time no matter the selected speed. Multiplying by the current speed
                    -- multiplier here would make that same fixed number of reps drain
                    -- proportionally more stamina purely because the player fast-forwarded,
                    -- with no extra exertion actually happening - so we don't.
                    local extraDrain = 0.001 * weightMultiplier
                    player:getStats():remove(CharacterStat.ENDURANCE, extraDrain)
                end

                -- Award XP (Sprinting always, Strength if weighted) - SERVER ONLY
                addTreadmillXP(player, weightMultiplier)

                -- Heat & Thirst: Get sandbox multipliers (default 1.0)
                local heatMultiplier = SandboxVars.FWOWorkingTreadmill.HeatMultiplier or 1.0
                local thirstMultiplier = SandboxVars.FWOWorkingTreadmill.ThirstMultiplier or 1.0

                -- Manual temperature/thirst per rep (base: heat = 0.07, thirst = 0.0025).
                -- Not scaled by game speed - see the stamina-drain comment above.
                local tempIncrease = 0.07 * heatMultiplier
                player:getStats():add(CharacterStat.TEMPERATURE, tempIncrease)

                -- Thirst from dehydration (cardio)
                local thirstIncrease = 0.0025 * thirstMultiplier
                player:getStats():add(CharacterStat.THIRST, thirstIncrease)
            end

            -- ====================================================================
            -- BENCHPRESS EXERCISE (Strength - Moderate intensity)
            -- ====================================================================
            if self.exercise == "benchpress" then
                -- Get sandbox multipliers (default 1.0)
                local strengthXPMultiply = SandboxVars.FWOWorkingTreadmill.StrengthXPMultiply or 1.0
                local heatMultiplier = SandboxVars.FWOWorkingTreadmill.HeatMultiplier or 1.0
                local thirstMultiplier = SandboxVars.FWOWorkingTreadmill.ThirstMultiplier or 1.0

                -- Strength XP: 0.12 per rep (higher than treadmill since it's pure strength).
                -- Not scaled by game speed - see the stamina-drain comment in the treadmill
                -- branch above (exeLooped's rep rate is already fixed per unit of game time).
                local strengthXp = 0.12 * strengthXPMultiply
                addXp(player, Perks.Strength, strengthXp)

                -- Manual temperature/thirst per rep (base: heat = 0.07, thirst = 0.0025)
                local tempIncrease = 0.07 * heatMultiplier
                player:getStats():add(CharacterStat.TEMPERATURE, tempIncrease)

                -- Thirst from exertion (strength)
                local thirstIncrease = 0.0025 * thirstMultiplier
                player:getStats():add(CharacterStat.THIRST, thirstIncrease)
            end
        end

        -- Prevent sitting exploit (runs on all clients for visual feedback)
        if self.character:isSitOnGround() then
            self.character:PlayAnim("Idle")
            self.character:setVariable("ExerciseEnded", true)
            -- forceComplete() requires a full client-side ISBaseTimedAction; the dedicated
            -- server drives exeLooped through a lightweight NetTimedAction stand-in that
            -- doesn't support it, so calling it there throws "forceComplete of non-table: null".
            if not isServer() then
                self:forceComplete()  -- Use forceComplete to trigger exit animation
            end
            self.character:setFallOnFront(true)
        end

        -- Stop from exhaustion (endurance below 20%) - runs on all clients
        if self.character:getStats():get(CharacterStat.ENDURANCE) < 0.2 then
            self.character:setVariable("ExerciseEnded", "true")
            self.character:setVariable("ExerciseStarted", "false")
            self.character:reportEvent("EventUpdateFitness")
        end
    end

    -- Call vanilla for core fitness logic (stamina drain, regularity, Fitness XP)
    fwoMood(self.character)
    SAONpcExerciseCore.exeLooped(self)
end


-- Local receiver of source-issued Yoga AddXP commands. Values remain the
-- source's actual requests, typed/custodied by the same native action callback.
local function yogaSourceSkill(character,module,command,args)
    local id=character:getModData().SAOPersonId;local active=id and runtime[id]
    if not active or not owned(active) or active.body~=character or active.work.family~="yoga"
        or module~="LS" or command~="AddXP" or type(args)~="table"
        or (args[1]~="Fitness" and args[1]~="Nimble") or not finite(args[2]) or args[2]<=0
        or (active.callback~="update" and active.callback~="perform") then error("unowned-yoga-source-request") end
    local r=record(id);local seq=(r.exerciseSkillSequence or 0)+1;r.exerciseSkillSequence=seq
    active.skillRequests=active.skillRequests or {}
    local w=active.work
    local request={actorId=id,workId=w.workId,purposeId=w.purposeId,workSequence=w.sequence,sequence=seq,
        perkName=args[1],amount=args[2],atHours=hours(),status="requested",sourceId=w.sourceId,revision=w.revision,
        nativeProgress={sourceCallback=active.callback,sourceInvocationSequence=active.invocations,
            actionStarted=active.started==true,jobDelta=active.action:getJobDelta()}}
    active.skillRequests[seq]=request
    local accepted,receipt=SAO.LeisureSkill.consume(id,character,"SAO.LeisureExercise",w.sequence,seq)
    active.progress.skillRequests=(active.progress.skillRequests or 0)+1
    active.progress.skillApplied=(active.progress.skillApplied or 0)+(accepted and 1 or 0)
    active.progress.lastSkillStatus=type(receipt)=="table" and receipt.status or tostring(receipt)
    if not accepted and (type(receipt)~="table" or receipt.status~="noeffect") then error("yoga-native-skill-request-unapplied") end
end
function E.skillRequest(id,workSequence,sequence)
    local active=runtime[id]
    if not active or not owned(active) or active.work.sequence~=workSequence or not active.started
        or (active.callback~="update" and active.callback~="perform") then return nil end
    return active.skillRequests and copy(active.skillRequests[sequence])
end
local function yogaMats(id,body)
    if not SAO.Perception or not SAO.Perception.leisureObjects or not SAO.Perception.resolveLeisureObject then return nil end
    local t={floors_rugs_01_52={"floors_rugs_01_53","getE"},floors_rugs_01_53={"floors_rugs_01_52","getW"},
        floors_rugs_01_54={"floors_rugs_01_55","getN"},floors_rugs_01_55={"floors_rugs_01_54","getS"},
        floors_rugs_01_56={"floors_rugs_01_57","getE"},floors_rugs_01_57={"floors_rugs_01_56","getW"},
        floors_rugs_01_58={"floors_rugs_01_59","getN"},floors_rugs_01_59={"floors_rugs_01_58","getS"},
        floors_rugs_01_48={"floors_rugs_01_49","getE"},floors_rugs_01_49={"floors_rugs_01_48","getW"},
        floors_rugs_01_50={"floors_rugs_01_51","getN"},floors_rugs_01_51={"floors_rugs_01_50","getS"}}
    local seen={}
    for _,row in ipairs(SAO.Perception.leisureObjects(id,body) or {}) do
        if row.actorId==id and row.concept=="yoga-mat" and row.source=="native-personal-visibility" then
            local obj=SAO.Perception.resolveLeisureObject(id,body,row.key)
            if obj and obj:getSprite() and obj:getSprite():getName()==row.spriteName then seen[#seen+1]={object=obj,row=row} end
        end
    end
    for _,first in ipairs(seen) do
        local vars=t[first.row.spriteName]
        if vars and first.object:getSquare()==body:getCurrentSquare() then
            local adjacent=first.object:getSquare()[vars[2]](first.object:getSquare())
            for _,other in ipairs(seen) do
                if other.row.spriteName==vars[1] and other.object:getSquare()==adjacent
                    and SAO.Standing.mayEnterCurrent(id,adjacent:getX(),adjacent:getY()) then return other.object,first.object end
            end
        end
    end
end
local function yogaReady(id,body)
    if isClient() or isServer() or not (SAO.SourceIntegration and SAO.SourceIntegration.available("LifestyleHobbies"))
        or not SandboxVars.Yoga or not SandboxVars.Text or not HiddenSkills or not HiddenSkills.getSkill
        or not LSUtil or not LSUtil.changeCharacterMoodGroup or not LSUtil.reduceAllStiffness
        or not LSUtil.truncateToTwoDecimals or not SAO.LeisureSkill or not SAOJavaBridge.initFitnessExerciseDefinitions
        or not finite(GTLSCheck) or not physical(body) or body:isSitOnGround() then return false end
    local data=body:getModData();local m=data.LSMoodles
    if not m or not m.Zen or not m.Embarrassed or not m.WasTaughtSkill
        or not finite(m.Zen.Value) or not finite(m.Zen.Level) or not finite(m.Embarrassed.Level)
        or not finite(m.WasTaughtSkill.Value) then return false end
    local exhaustion={false,.8,.6,.3};local embarrassment={false,1,2,3}
    local threshold=exhaustion[SandboxVars.Yoga.Exhaustion or 3]
    if threshold and body:getStats():get(CharacterStat.ENDURANCE)<=threshold then return false end
    threshold=embarrassment[SandboxVars.Yoga.Embarrassment or 2]
    if threshold and m.Embarrassed.Level>=threshold then return false end
    if SandboxVars.Yoga.RequiresMat and not yogaMats(id,body) then return false end
    if not SandboxVars.Yoga.KeepBags then
        for i=0,body:getWornItems():size()-1 do if instanceof(body:getWornItems():get(i):getItem(),"InventoryContainer") then return false end end
    end
    for _,item in ipairs({body:getPrimaryHandItem(),body:getSecondaryHandItem()}) do
        if item:hasTag(ItemTag.HEAVY_ITEM) then return false end
    end
    return true
end
local function yogaArgs(level)
    local t={{"Beginner",50,1,2},{"Beginner",50,1,2},{"Beginner",40,1,3},
        {"Intermediate",40,2,3},{"Intermediate",30,2,4},{"Intermediate",30,2,4},
        {"Advanced",30,3,6},{"Advanced",20,3,6},{"Advanced",20,3,8},{"Master",10,4,10},{"Master",0,4,10}}
    return t[level+1]
end
yogaOffer=function(id,body,conceptual)
    if not conceptual or conceptual.status~="expectation" or not yogaReady(id,body) then return nil end
    local data=body:getModData();local skill=data.LSHiddenSkills and data.LSHiddenSkills.Yoga
    local level=skill and skill[1] or 0
    if not finite(level) or level~=math.floor(level) or not yogaArgs(level) then return nil end
    return {id="yoga:body",family="yoga",activity="yoga",sourceId="Lifestyle:LSYogaAction",revision=YOGA_REVISION,
        sourceDuration="phase-controlled",sourceSkillLevel=level}
end
function E.intentOffers(id,body)
    if not live(id,body) or not finite(hours()) or not SAO.Needs.workAvailable(body) or not permission(id,body) then return {} end
    local out=E.offers(id,body);local seen={}
    for _,offer in ipairs(out) do seen[offer.id]=true end
    local conceptual=SAO.ConceptKnowledge and SAO.ConceptKnowledge.infer(id,"exercise","physical-practice")
    if not conceptual or conceptual.status~="expectation" then return out end
    for _,machine in ipairs(machines(id,body,true)) do
        local idKey="equipment:"..machine.key
        if not seen[idKey] then
            out[#out+1]={id=idKey,family="equipment-exercise",activity=machine.activity,
                sourceId="FWO:FWOTreadmillBenchpressExercise",revision=FWO_REVISION,minutes=10,
                objectKey=machine.key,runtimeInstance=machine.runtimeInstance,
                targetX=machine.front:getX(),targetY=machine.front:getY(),targetZ=machine.front:getZ(),
                itemKey=machine.item and tostring(machine.item:getID()),itemType=machine.item and machine.item:getFullType(),
                secondaryItemKey=machine.secondary and tostring(machine.secondary:getID()),
                requiresPreparation=copy(machine.preparation)}
            seen[idKey]=true
        end
    end
    if not seen["yoga:body"] and not isClient() and not isServer()
        and SAO.SourceIntegration and SAO.SourceIntegration.available("LifestyleHobbies") and SandboxVars.Yoga and LSUtil and HiddenSkills
        and SAO.LeisureSkill and SAOJavaBridge.initFitnessExerciseDefinitions then
        local data=body:getModData();local m=data.LSMoodles
        local skill=data.LSHiddenSkills and data.LSHiddenSkills.Yoga;local level=skill and skill[1] or 0
        local eligible=true
        local exhaustion={false,.8,.6,.3};local threshold=exhaustion[SandboxVars.Yoga.Exhaustion or 3]
        if threshold and body:getStats():get(CharacterStat.ENDURANCE)<=threshold then eligible=false end
        local embarrassment={false,1,2,3};threshold=embarrassment[SandboxVars.Yoga.Embarrassment or 2]
        if threshold and m and m.Embarrassed and finite(m.Embarrassed.Level) and m.Embarrassed.Level>=threshold then eligible=false end
        if eligible and finite(level) and level==math.floor(level) and yogaArgs(level) then
            local preparation={sourceInitialization=not m or not m.Zen or not m.Embarrassed or not m.WasTaughtSkill,
                stand=body:isSitOnGround(),requiresYogaMat=SandboxVars.Yoga.RequiresMat==true and yogaMats(id,body)==nil}
            if not SandboxVars.Yoga.KeepBags then
                for i=0,body:getWornItems():size()-1 do
                    local bag=body:getWornItems():get(i):getItem()
                    if instanceof(bag,"InventoryContainer") then
                        preparation.removeBags=preparation.removeBags or {}
                        preparation.removeBags[#preparation.removeBags+1]={itemKey=tostring(bag:getID()),itemType=bag:getFullType()}
                    end
                end
            end
            out[#out+1]={id="yoga:body",family="yoga",activity="yoga",sourceId="Lifestyle:LSYogaAction",revision=YOGA_REVISION,
                sourceDuration="phase-controlled",sourceSkillLevel=level,requiresPreparation=preparation}
        end
    end
    return out
end

local function buildYogaSource()
    local sendClientCommand=yogaSourceSkill
    -- The source cache/expiry formerly lived in a file-global zenBonus. The
    -- isolated action writes only this person's source state and future definitions.
    local LSupdateZenBonus=function(data) end
local SAONpcYogaCore = ISBaseTimedAction:derive("LSYogaAction");

function SAONpcYogaCore:isValid()
	return true;
end

local function getMat(key)
	local t ={
		floors_rugs_01_52 = {"floors_rugs_01_53","getE"},
		floors_rugs_01_53 = {"floors_rugs_01_52","getW"},
		floors_rugs_01_54 = {"floors_rugs_01_55","getN"},
		floors_rugs_01_55 = {"floors_rugs_01_54","getS"},
		floors_rugs_01_56 = {"floors_rugs_01_57","getE"},
		floors_rugs_01_57 = {"floors_rugs_01_56","getW"},
		floors_rugs_01_58 = {"floors_rugs_01_59","getN"},
		floors_rugs_01_59 = {"floors_rugs_01_58","getS"},
		floors_rugs_01_48 = {"floors_rugs_01_49","getE"},
		floors_rugs_01_49 = {"floors_rugs_01_48","getW"},
		floors_rugs_01_50 = {"floors_rugs_01_51","getN"},
		floors_rugs_01_51 = {"floors_rugs_01_50","getS"},
	}
	return t[key]
end

local function getYogaMat(character)
    return yogaMats(character:getModData().SAOPersonId,character)
end

function SAONpcYogaCore:waitToStart()
	self.action:setUseProgressBar(false)
	self.matObj = getYogaMat(self.character)
	if self.matObj then
		if SandboxVars.Yoga.AidObjects then
			self.boostVars[1] = 1
		end
		self.character:faceThisObject(self.matObj)
	end
	return self.character:shouldBeTurning()
end

local function getNewParam(oldParam, paramTable)
	local t = paramTable
	if oldParam then
		t = {}
		for n=1, #paramTable do
			if paramTable[n] ~= oldParam then table.insert(t, paramTable[n]); end
		end
	end

	return t[ZombRand(#t)+1]
end

local function stopSound(character, sound)
	if sound and sound ~= 0 and character:getEmitter():isPlaying(sound) then
		character:getEmitter():stopSound(sound)
	end
end

function SAONpcYogaCore:update()
	if self.character:isSitOnGround() or self.character:getVehicle() then self:forceStop(); end

	self.deltaAdd = getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck
	self.fakeDelta = self.fakeDelta+self.deltaAdd
	self.jobProgress = self.fakeDelta
	

	for _, phase in ipairs(self.phases) do
		if (not self.phaseStates[phase.name]) and self.jobProgress > (self.fakeMax * phase.threshold) then
			self.phaseStates[phase.name] = true
			self[phase.handler](self)
			break
		--elseif self.phaseStates[phase.name] and self.jobProgress < (self.maxTime * phase.threshold) then
			--self.phaseStates[phase.name] = false
		end
	end

	--local timeTick = getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck -- do not use it here

	
	if self.animVars.countTotal then
		if not self.animVars.count then self.animVars.count = 0; end
		self.animVars.count = self.animVars.count+(getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		if self.animVars.count >= self.animVars.countTotal then
			self.animVars.count = 0
			if not self.animVars.start then
				self.animVars.start = true
				self:setActionAnim(self.animVars.anim.."_Loop")
				self.animVars.countTotal = self.animVars.soundTime
			else
				if self.animVars.playOnce then
					self.character:getEmitter():playSound("Body_Falling"..tostring(ZombRand(4)+1))
					self.animVars.countTotal = false
				else
					--stopSound(self.character, self.sound)
					--self.soundName = getNewParam(self.soundName, self.soundTable[self.soundGroup])
					--self.sound = self.character:getEmitter():playSound(self.soundName)
				end
				if self.sandboxFailChance and self.animVars.fail > 0 and not self.doFailState then
					if ZombRand(100)+1+10*self.skillLevel <= math.min(80, (self.animVars.fail + self.baseFailChance)*self.sandboxFailChance) then self.doFailState = true; end
					self.animVars.fail = 0
				end
				--if self.animVars.playOnce then self.animVars.countTotal = false; end
			end
		end
	end
	
	self.character:setMetabolicTarget(Metabolics[self.exerciseMetabolics])
end

function SAONpcYogaCore:endAction()
	--stopSound(self.character, self.sound)
	self:forceComplete()
end

function SAONpcYogaCore:doFinalInteraction()
	--stopSound(self.character, self.sound)
	self.animVars = {parent=false,anim="Bob_Yoga_Rest_"..self.skillGroup,countTotal=100,soundTime=100,fail=0}
	self:setActionAnim(self.animVars.anim.."_Start")
end

function SAONpcYogaCore:endFinalInteraction()
	--stopSound(self.character, self.sound)
	self.animVars.countTotal = false
	self:setActionAnim("Bob_Yoga_Rest_"..self.skillGroup.."_End")
	self["reduceStiffness"](self)
	self["reducePainStressBoredom"](self)
end

function SAONpcYogaCore:endInteraction()
	--stopSound(self.character, self.sound)
	local anim, total = "_End", false
	if self.doFailState then
		anim = "_Fail"
		total = 2 -- average body falling fail sound time for anims
		self.animVars.count = 0
		self.animVars.playOnce = true
		local sex = "Man"
		if self.character:isFemale() then sex = "Woman"; end
		self.character:getEmitter():playSound(sex.."Fall0"..tostring(ZombRand(3)+1))
		self["embarrassSelf"](self)
	end
	self:setActionAnim(self.animVars.anim..anim)

	self.animVars.fail = 0
	self.animVars.countTotal = total
	
	
	self.poseCount = self.poseCount+1
	if not self.doFailState then
		if self.animVars.parent or self.poseCount < self.poseLimit then -- reset if it should execute doInteraction again (self.poseLimit not reached or current pose has parent / and player didn't fail, otherwise ends with fail anim upright
			--self:resetJobDelta()
			self.fakeDelta = 0; self.jobProgress = 0
			self:resetPhases(false,true) -- {"a","b",...}, all phases
		end
		self["reduceStiffness"](self)
		self["reducePainStressBoredom"](self)
		self["grantXP"](self)
	end
end

function SAONpcYogaCore:embarrassSelf()
	if not self.playerData.LSMoodles["Embarrassed"] then return; end
	self.playerData.LSMoodles["Embarrassed"].Value = self.playerData.LSMoodles["Embarrassed"].Value + 0.2
	HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)
end

function SAONpcYogaCore:resetPhases(list, all)
	for _, phase in ipairs(self.phases) do
		if self.phaseStates[phase.name] and (all or list and list[phase.name]) then
			self.phaseStates[phase.name] = false
		end
	end
end

--[[
local function getNewSoundTable(sex, group)
	local t = {
		Cheer = {sex.."Cheer01",sex.."Cheer02",sex.."Cheer03",sex.."Cheer04"},
		Listen = {sex.."ListenAttentive01",sex.."ListenAttentive02",sex.."ListenAttentive03",sex.."ListenAttentive04"},
		Hug = {sex.."_Hug_Good1",sex.."_Hug_Good2",sex.."_Hug_Good3"}
	}
	return t
end
]]--

local function getInteractionArgs(action)
	local t = {
		Circle = {parent=false,anim="Bob_Yoga_Sitting_Circle",countTotal=110,soundTime=100,fail=0,xp=2.5}, -- parent - if it should assume another position instead of ending upright, often uses parent Start anim / Bob_Yoga_Circle_Start, Bob_Yoga_Circle_Loop, Bob_Yoga_Circle_Fail, Bob_Yoga_Circle_End / countTotal - time to change between Start and Loop anims / soundTime - takes over once countTotal is reached / fail - chance to fail, 0 = never / xp - max xp that can be gained from pose
		BellyDown = {parent=false,anim="Bob_Yoga_BellyDown",countTotal=70,soundTime=100,fail=5,xp=4}, -- ok
		Plank = {parent=false,anim="Bob_Yoga_Plank",countTotal=100,soundTime=100,fail=5,xp=4},
		Wind = {parent=false,anim="Bob_Yoga_SitUp_Wind",countTotal=70,soundTime=100,fail=0,xp=2.5},
		Idle = {parent=false,anim="Bob_Yoga_Sitting_Idle",countTotal=150,soundTime=100,fail=0,xp=2.5},
		Staff = {parent=false,anim="Bob_Yoga_Sitting_Staff",countTotal=90,soundTime=100,fail=0,xp=2.5},
		Tree = {parent=false,anim="Bob_Yoga_Tree",countTotal=50,soundTime=100,fail=0,xp=2.5},
		Lunge = {parent=false,anim="Bob_Yoga_Lunge",countTotal=70,soundTime=100,fail=0,xp=2.5},
		Cobra = {parent="BellyDown",anim="Bob_Yoga_BellyDown_Cobra",countTotal=70,soundTime=100,fail=0,xp=2.5},
		Cow = {parent="Cobra",anim="Bob_Yoga_BellyDown_Cow",countTotal=70,soundTime=100,fail=0,xp=2.5},
		Cat = {parent="Cow",anim="Bob_Yoga_BellyDown_Cat",countTotal=70,soundTime=100,fail=0,xp=2.5},
		-- intermediate
		Pistol = {parent=false,anim="Bob_Yoga_Pistol",countTotal=50,soundTime=100,fail=0,xp=5},
		BellyDownWalk = {parent="BellyDown",anim="Bob_Yoga_BellyDown_Walk",countTotal=120,soundTime=100,fail=10,xp=8},
		PlankHard = {parent="Plank",anim="Bob_Yoga_Plank_Hard",countTotal=100,soundTime=100,fail=10,xp=8},
		Boat = {parent=false,anim="Bob_Yoga_Sit_Boat",countTotal=110,soundTime=100,fail=0,xp=5},
		TreeHand = {parent="Tree",anim="Bob_Yoga_Tree_Hand",countTotal=50,soundTime=100,fail=10,xp=8},
		HandsToFeet = {parent=false,anim="Bob_Yoga_HandsToFeet",countTotal=70,soundTime=100,fail=0,xp=5},
		HalfMoon = {parent=false,anim="Bob_Yoga_HalfMoon",countTotal=70,soundTime=100,fail=0,xp=5},
		BackBend = {parent=false,anim="Bob_Yoga_BackBend",countTotal=70,soundTime=100,fail=0,xp=5},
		Bridge = {parent="Idle",anim="Bob_Yoga_Bridge",countTotal=150,soundTime=100,fail=0,xp=5},
		Warrior = {parent="Lunge",anim="Bob_Yoga_Lunge_Warrior",countTotal=70,soundTime=100,fail=0,xp=5},
		LungeLow = {parent="Lunge",anim="Bob_Yoga_Lunge_Low",countTotal=70,soundTime=100,fail=0,xp=5},
		-- advanced
		PlankSide = {parent="PlankHard",anim="Bob_Yoga_Plank_Side",countTotal=100,soundTime=100,fail=15,xp=12},
		TreeLeg = {parent="Tree",anim="Bob_Yoga_Tree_Leg",countTotal=50,soundTime=100,fail=15,xp=12},
		BellyDownWalkAdvanced = {parent="BellyDownWalk",anim="Bob_Yoga_BellyDown_Walk_Advanced",countTotal=120,soundTime=100,fail=15,xp=12},
		Ragdoll = {parent="HandsToFeet",anim="Bob_Yoga_HandsToFeet_Ragdoll",countTotal=70,soundTime=100,fail=0,xp=7.5},
		HandsToKnee = {parent=false,anim="Bob_Yoga_HandsToKnee",countTotal=70,soundTime=100,fail=0,xp=7.5},
		BalancingStick = {parent=false,anim="Bob_Yoga_BalancingStick",countTotal=70,soundTime=100,fail=15,xp=12},
		WarriorFront = {parent="Warrior",anim="Bob_Yoga_Lunge_WarriorFront",countTotal=70,soundTime=100,fail=0,xp=7.5},
		-- master
		TreeLegHard = {parent="TreeLeg",anim="Bob_Yoga_Tree_Leg_Hard",countTotal=40,soundTime=100,fail=20,xp=16},
		BellyDownWalkAdvancedHand = {parent="BellyDownWalkAdvanced",anim="Bob_Yoga_BellyDown_Walk_Advanced_Hand",countTotal=120,soundTime=100,fail=20,xp=16},
		BalancingBow = {parent="BalancingStick",anim="Bob_Yoga_BalancingBow",countTotal=70,soundTime=100,fail=20,xp=16},
		WarriorTriangle = {parent="WarriorFront",anim="Bob_Yoga_Lunge_WarriorFront_Triangle",countTotal=70,soundTime=100,fail=0,xp=10},
	}
	return t[action]
end

function SAONpcYogaCore:doInteraction()
	--stopSound(self.character, self.sound)
	
	local anim = "_Start"
	
	if self.animVars.parent then -- when previous pose has a parent
		self.currentAction = self.animVars.parent
		self.animVars.start = true
		anim = "_Loop"
	else
		self.currentAction = getNewParam(self.currentAction, self.actionTable)
	end
	
	self.animVars = getInteractionArgs(self.currentAction)

	
	--self.soundName = getNewParam(self.soundName, self.soundTable[self.soundGroup])
	--self.sound = self.character:getEmitter():playSound(self.soundName)
	
	--self.character:Say(self.animVars.anim..anim)
	self:setActionAnim(self.animVars.anim..anim)
end

local function getActionTable(playerSkill, actionTable)
	local t = {
		{lvl=0,anims={"Circle","BellyDown","Plank","Wind","Idle","Staff","Tree","Lunge","Cobra","Cow","Cat"}},
		{lvl=3,anims={"Pistol","BellyDownWalk","PlankHard","Boat","TreeHand","HandsToFeet","HalfMoon","BackBend","Bridge","Warrior","LungeLow"}},
		{lvl=6,anims={"PlankSide","TreeLeg","BellyDownWalkAdvanced","Ragdoll","HandsToKnee","BalancingStick","WarriorFront"}},
		{lvl=9,anims={"TreeLegHard","BellyDownWalkAdvancedHand","BalancingBow","WarriorTriangle"}},
	}
	for _, v in pairs(t) do
		if v.lvl <= playerSkill then
			for _, anim in ipairs(v.anims) do
				table.insert(actionTable, anim)
			end
		end
	end
	return actionTable
end

local function getTotalEfficiency(base, t)
	for n=1, #t do
		base = base+t[n]
	end
	return math.min(base, 6)
end

function SAONpcYogaCore:start()

	self.fakeMax = 1100
	self.fakeDelta = 0
	self.deltaAdd = 0

	if SandboxVars.Yoga.RequiresMat and not self.matObj then self:forceStop(); end

	self:setOverrideHandModels(nil, nil)
	self:setActionAnim(self.animVars.anim)
	--self.character:getEmitter():playSound("PutItemInBag")
	
	self.phases = {
		{name="a",threshold=0.07,handler="doInteraction"},
		{name="b",threshold=0.30,handler="endInteraction"}, -- resets back to "a" until poseLimit is reached or character fails or animation has parent (then executes parent with a final doInteraction loop)
		{name="c",threshold=0.37,handler="doFinalInteraction"}, -- laying down for a bit
		{name="d",threshold=0.70,handler="endFinalInteraction"}, -- and then getting up
		{name="e",threshold=0.80,handler="endAction"}, -- perform action earlier
	}
	
	--self.soundTable = getNewSoundTable(self.sex)
	self.actionTable = getActionTable(self.skillLevel, self.actionTable)
	
	self.bonus = getTotalEfficiency(self.efficiency, self.boostVars)

	local data = self.character:getModData()
	if data.LSMoodles["WasTaughtSkill"].Value >= 0.2 and data.WasTaughtLast and data.WasTaughtLast == "Yoga" then self.XPmultipliers.Yoga = self.XPmultipliers.Yoga+3; end

end

function SAONpcYogaCore:stop()
	--stopSound(self.character, self.sound)
	self["reduceXP"](self)

    ISBaseTimedAction.stop(self);		
end

function SAONpcYogaCore:reducePainStressBoredom()
	LSUtil.changeCharacterMoodGroup(self.character, {
		["Boredom"] = {-5, false, false, true},
		["Nicotine_Withdrawal"] = {-0.01*self.bonus, false, false, true},
		["Stress"] = {-0.01*self.bonus, true, false, true},
		["Pain"] = {-5*self.bonus*self.sandboxMult, false, false, true},
	})
end

function SAONpcYogaCore:reduceStiffness()
	LSUtil.reduceAllStiffness(self.character, 2*self.bonus*self.sandboxMult)
end

function SAONpcYogaCore:reduceXP() -- penalty for stopping earlier, can't reduce level / penalty is based on how many poses were done vs pose limit / penalty is not applied if no xp was granted / reduces xp and zen
	if self.skillLevel >= 10 or self.gainedXP == 0 then return; end
	local amount = 20
	if self.poseCount >= self.poseLimit then amount = amount*math.max(1,self.skillLevel); -- 0-20,1-20,2-40,3-60,4-80,5-100,6-120,7-140,8-160,9-180
	else
		local val = self.poseLimit-self.poseCount
		amount = amount*val
	end
	if self.playerData.LSMoodles["Zen"] and self.playerData.LSMoodles["Zen"].Value > 0 then self.playerData.LSMoodles["Zen"].Value = math.max(0, self.playerData.LSMoodles["Zen"].Value-0.05); end
	HiddenSkills.removeXP(self.character, "Yoga", amount)
end

local function addPerkXP(character, perkName, val, div, multiTable)
	if character:getPerkLevel(Perks[perkName]) >= 10 then return; end
	local xp = math.ceil(val/div)*multiTable[perkName]
	xp = LSUtil.truncateToTwoDecimals(xp)
	--character:getXp():AddXP(Perks[perkName], xp)
	sendClientCommand(character, "LS", "AddXP", {perkName, xp})
end

function SAONpcYogaCore:grantXP() -- pose base xp multiplied by the sum of total bonus (skill+variables) + ceil result of zen level/2 (1,2)
	if self.skillLevel >= 10 and self.character:getPerkLevel(Perks.Fitness) >= 10 and self.character:getPerkLevel(Perks.Nimble) >= 10 then return; end
	local totalXP = self.bonus
	if self.playerData.LSMoodles["Zen"] and self.playerData.LSMoodles["Zen"].Level > 0 then totalXP = totalXP+math.ceil(self.playerData.LSMoodles["Zen"].Level/2); end
	totalXP = totalXP*self.animVars.xp
	self.gainedXP = self.gainedXP+totalXP
	if self.skillLevel < 10 then
		local yogaXP = LSUtil.truncateToTwoDecimals(totalXP*self.XPmultipliers.Yoga)
		HiddenSkills.addXP(self.character, "Yoga", yogaXP, false, true)
		self.skillLevel = HiddenSkills.getLevel(self.character, "Yoga") -- update skill level
	end
	addPerkXP(self.character, "Fitness", totalXP, 1, self.XPmultipliers)
	addPerkXP(self.character, "Nimble", totalXP, 3, self.XPmultipliers)
end

local function getLevelLimit(key)
	local t = {
		[0] = 10,
		[1]	= 15,
		[2]	= 20,
		[3]	= 30,
		[4] = 50,
		[5] = 75,
		[6] = 100,
		[7] = 150,
		[8] = 200,
		[9] = 250,
	}
	return t[key] or 50
end

function SAONpcYogaCore:grantBonusXP() -- random number between a third and the total sum of xp from all the poses performed (bonus included), limited by level
	if self.gainedXP == 0 or (self.skillLevel >= 10 and self.character:getPerkLevel(Perks.Fitness) >= 10 and self.character:getPerkLevel(Perks.Nimble) >= 10) then return; end
	local bonusXP = math.ceil(ZombRand(self.gainedXP/3, self.gainedXP+1))
	local limit = getLevelLimit(self.skillLevel)
	bonusXP = math.min(limit, bonusXP)
	if self.skillLevel < 10 then
		local yogaXP = LSUtil.truncateToTwoDecimals(bonusXP*self.XPmultipliers.Yoga)
		HiddenSkills.addXP(self.character, "Yoga", yogaXP, false, true)
	end
	addPerkXP(self.character, "Fitness", bonusXP, 1, self.XPmultipliers)
	addPerkXP(self.character, "Nimble", bonusXP, 3, self.XPmultipliers)
end

function SAONpcYogaCore:fitnessBonus()
    if self.playerData.LSZenActive then return end
    local val=0.05*self.bonus*self.sandboxMult
    local defs=FitnessExercises and FitnessExercises.exercisesType
    if defs then
        local r=record(self.owner.work.actorId)
        self.playerData.LSZenActive={}
        r.exerciseDefinitionScope={bodyToken=self.playerData.SAOExternalToken,modifiers={}}
        for k,v in pairs(defs) do
            self.playerData.LSZenActive[k]=v.xpMod
            r.exerciseDefinitionScope.modifiers[k]=v.xpMod+val
        end
    end
end

function SAONpcYogaCore:perform()
	--stopSound(self.character, self.sound)

	--doMoodChange(self.character)
	
	if self.skillLevel ~= 0 and not self.doFailState then self.playerData.LSMoodles["Zen"].Value = 0.25*self.efficiency; self["fitnessBonus"](self); LSupdateZenBonus(self.playerData) end

	self["grantBonusXP"](self)
	
	self.character:getEmitter():playSound("UI_SK_Meditation")

	ISBaseTimedAction.perform(self);
end

local function getYogaSandboxMult(val)
	if not val then return 1; end
	local t = {
		[1] = 0.5,
		[2] = 1,
		[3] = 2,
		[4] = 3,
	}
	return t[val] or 1
end

local function getYogaSandboxFailChance(val)
	if not val then return 1; end
	local t = {
		[1] = false,
		[2] = 0.2,
		[3] = 0.5,
		[4] = 1,
		[5] = 1.5,
		[6] = 2,
	}
	return t[val] or 1
end

local function getYogaMetabolicTarget(fitnessLevel)
	local metabolics = "Fitness"
	if fitnessLevel < 8 then metabolics = "FitnessHeavy"; end
	return metabolics
end

function SAONpcYogaCore:complete()

	return true
end

function SAONpcYogaCore:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function SAONpcYogaCore:new(character, skillLevel, Args)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.skillLevel = skillLevel
	o.Args = Args
	o.skillGroup = Args[1]
	o.baseFailChance = Args[2]
	o.efficiency = Args[3]
	o.poseLimit = Args[4]
	o.playerData = character:getModData()
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.stopOnAim         = true
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.phases = false
	o.phaseStates = {}
	o.actionTable = {}
	o.currentAction = false
	o.actionCount = 0
	o.poseCount = 0
	o.animVars = {parent=false,anim="Bob_Yoga_Start_"..Args[1],countTotal=false,soundTime=false,fail=0}
	o.sound = 0
	o.soundTable = false
	o.soundName = "none"
	o.boostVars = {0,0} -- yoga mat, incense
	o.gainedXP = 0
	o.sandboxMult = getYogaSandboxMult(SandboxVars.Yoga.StrengthMultiplier or 2)
	o.sandboxFailChance = getYogaSandboxFailChance(SandboxVars.Yoga.FailChance or 4)
	o.XPmultipliers = {Yoga = SandboxVars.Yoga.YogaXPMultiplier or 1, Fitness = SandboxVars.Yoga.FitnessXPMultiplier or 1, Nimble = SandboxVars.Yoga.NimbleXPMultiplier or 1} -- yoga, fitness, nimble
	o.exerciseMetabolics = getYogaMetabolicTarget(character:getPerkLevel(Perks.Fitness))
	return o;
end
    return SAONpcYogaCore
end
local YogaCore=buildYogaSource()
local Yoga=YogaCore:derive("SAOOwnedYoga")
function Yoga:isValid() return owned(self.owner) and permission(self.owner.work.actorId,self.character)
    and yogaReady(self.owner.work.actorId,self.character) end
function Yoga:waitToStart()
    if not self:isValid() then return false end
    return YogaCore.waitToStart(self)
end
function Yoga:start()
    if not self:isValid() then return end
    self.owner.work.status="active";self.owner.started=true
    YogaCore.start(self)
end
function Yoga:update()
    if not self.owner.started or not self:isValid() then self:forceStop();return end
    self.owner.callback="update";self.owner.invocations=(self.owner.invocations or 0)+1
    local ok,why=pcall(YogaCore.update,self)
    if not ok then self.owner.progress.sourceFailureReason=string.sub(tostring(why),1,160) end
    self.owner.callback=nil
    self.owner.progress.sourceUpdates=(self.owner.progress.sourceUpdates or 0)+1
    self.owner.progress.poses=self.poseCount;self.owner.progress.gainedYogaXP=self.gainedXP
    self.owner.progress.jobDelta=self:getJobDelta()
    if not ok then self.owner.sourceFailure=true;self:forceStop() end
end
function Yoga:endAction()
    if not owned(self.owner) or not self.owner.started then return end
    self.owner.sourceReachedEnd=true;YogaCore.endAction(self)
end
function Yoga:perform()
    if not owned(self.owner) or not self.owner.started or not self.owner.sourceReachedEnd
        or (self.owner.progress.sourceUpdates or 0)<1 or self.poseCount<1 then return end
    self.owner.callback="perform";self.owner.invocations=(self.owner.invocations or 0)+1
    local ok,why=pcall(YogaCore.perform,self)
    if not ok then self.owner.progress.sourceFailureReason=string.sub(tostring(why),1,160) end
    self.owner.callback=nil;self.owner.stopped=true
    self.owner.completed=ok and not self.owner.sourceFailure
end
function Yoga:stop()
    if not owned(self.owner) then return end
    self.owner.callback="stop";self.owner.invocations=(self.owner.invocations or 0)+1
    local ok=pcall(YogaCore.stop,self)
    self.owner.callback=nil
    self.owner.stopped=true;self.owner.sourceFailure=self.owner.sourceFailure or not ok
end
function Yoga:forceStop()
    if not owned(self.owner) then return end
    if self.action then self.action:forceStop() else self:stop() end
end
function Yoga:forceCancel() if owned(self.owner) then self:stop() end end
function Yoga:complete() return owned(self.owner) and self.owner.sourceReachedEnd==true end

-- Source helper calls are valid only during the actual owned lifecycle callback.
for _,name in ipairs({"grantXP","grantBonusXP","reduceXP","embarrassSelf","reduceStiffness",
    "reducePainStressBoredom","fitnessBonus","doInteraction","endInteraction","endFinalInteraction","doFinalInteraction"}) do
    local operation=YogaCore[name]
    Yoga[name]=function(self,...)
        if not owned(self.owner) or (self.owner.callback~="update" and self.owner.callback~="perform"
            and self.owner.callback~="stop") then return end
        local before=sample(self.character,"yoga")
        local value=operation(self,...)
        local after=sample(self.character,"yoga")
        local measured=effects(before,after)
        self.owner.progress.sourceCalls=(self.owner.progress.sourceCalls or 0)+1
        self.owner.progress.lastSourceEffects=measured
        return value
    end
end
local function equipmentSound(self,ending)
    local active=self.owner
    if not active.machine or isServer() then return end
    if active.gameSound and active.soundEmitter then active.soundEmitter:stopSound(active.gameSound) end
    if ending and self.exercise~="treadmill" then active.gameSound=nil;return end
    local sound=ending and "FWOtreadmillend" or (self.exercise=="treadmill" and "FWOtreadmillrun" or "FWObench")
    active.gameSound=self.character:playSound(sound)
    active.soundEmitter=self.character:getEmitter()
    addSound(self.character,self.character:getX(),self.character:getY(),self.character:getZ(),ending and 15 or 13,6)
end

local Action=SAONpcExerciseCore:derive("SAOOwnedExercise")
function Action:isValidStart() return owned(self.owner) and permission(self.owner.work.actorId,self.character)
    and SAONpcExerciseCore.isValidStart(self) end
function Action:isValid() return owned(self.owner) and permission(self.owner.work.actorId,self.character)
    and equipment(self.character,self.exeData) and SAONpcExerciseCore.isValid(self)
    and (not self.owner.machine or self:machineValid()) end
function Action:machineValid()
    for _,current in ipairs(machines(self.owner.work.actorId,self.character)) do
        if current.key==self.owner.work.objectKey and current.object==self.owner.machine.object
            and current.runtimeInstance==self.owner.machine.runtimeInstance
            and (current.item and tostring(current.item:getID()) or nil)==self.owner.work.itemKey
            and (current.secondary and tostring(current.secondary:getID()) or nil)==self.owner.work.secondaryItemKey then return true end
    end
    return false
end
function Action:waitToStart()
    if not owned(self.owner) then return false end
    if self.owner.machine then
        if not self:machineValid() then return false end
        self.character:setDir(self.FWOObjectFacing);return self.character:shouldBeTurning()
    end
    return SAONpcExerciseCore.waitToStart(self)
end
function Action:animEvent(event,parameter)
    if owned(self.owner) then return SAONpcExerciseCore.animEvent(self,event,parameter) end
end
function Action:serverStart()
    if not owned(self.owner) then return end
    fwoRegularity(self.character,self.exercise)
    if self.owner.machine then
        if not self:machineValid() then return end
        self.character:setDir(self.FWOObjectFacing)
        self.fitness=self.character:getFitness()
        if not nativeDefinitionInit(self.owner.work.actorId,self.character,self.exercise) then return end
        self.fitness:setCurrentExercise(self.exeDataType)
        emulateAnimEvent(self.netAction,self.exercise=="treadmill" and 2000 or 2200,"ActiveAnimLooped",nil)
        return
    end
    return SAONpcExerciseCore.serverStart(self)
end
function Action:serverStop()
    if owned(self.owner) then return SAONpcExerciseCore.serverStop(self) end
end
function Action:complete()
    if not owned(self.owner) then return false end
    return SAONpcExerciseCore.complete(self)
end
function Action:showHandModel()
    if owned(self.owner) then return SAONpcExerciseCore.showHandModel(self) end
end
function Action:start()
    if not self:isValidStart() then self:forceStop();return end
    self.owner.work.status="active"
    self.fitness:init()
    self.fitness:setCurrentExercise(self.exeDataType)
    fwoRegularity(self.character,self.exercise)
    SAONpcExerciseCore.start(self)
end
function Action:exeLooped()
    if not self:isValid() or not physical(self.character) then self:forceStop();return end
    -- Count only a successful native physical repetition, not a duration signal.
    local before=sample(self.character,self.exercise)
    if self.owner.machine then fwoEquipmentRepeat(self)
    else fwoMood(self.character);SAONpcExerciseCore.exeLooped(self) end
    local after=sample(self.character,self.exercise)
    if not self.fitness:getCurrentExe() or not ((after.regularity or 0)>(before.regularity or 0)
        or (after.ENDURANCE or 0)<(before.ENDURANCE or 0)) then
        self.owner.physicalEffectFailed=true;self:forceStop();return
    end
    self.owner.progress.repetitions=self.owner.progress.repetitions+1
    self.owner.progress.lastRepeatEffects=effects(before,after)
end
function Action:update()
    if not self:isValid() then self:forceStop();return end
    if not physical(self.character) then self:forceStop();return end
    if self.owner.machine and (not self.owner.gameSound or not self.character:getEmitter():isPlaying(self.owner.gameSound)) then
        equipmentSound(self,false)
    end
    self.owner.durationReached=getGameTime():getCalender():getTimeInMillis()>self.endMS
    SAONpcExerciseCore.update(self)
end
function Action:forceStop()
    if owned(self.owner) then SAONpcExerciseCore.forceStop(self) end
end
function Action:stop()
    if not owned(self.owner) then return end
    self.owner.stopped=true
    if self.owner.machine then emulateAnimEventOnce(self.netAction,100,nil,"FitnessFinished=TRUE");equipmentSound(self,true) end
    fwoRegularity(self.character,nil)
    SAONpcExerciseCore.stop(self)
end
function Action:perform()
    if not owned(self.owner) then return end
    self.owner.stopped=true
    equipmentSound(self,true)
    fwoRegularity(self.character,nil)
    SAONpcExerciseCore.perform(self)
end
function Action:forceCancel()
    if owned(self.owner) then self.owner.stopped=true;self.fitness:setCurrentExercise(nil) end
end
function E.begin(id,body,offer,purposeId)
    local r=record(id)
    if not r or r.exerciseLeisureWork or runtime[id] or type(purposeId)~="string"
        or #purposeId==0 or #purposeId>160 then return false,"work-unavailable" end
    local held=selected(id,body,offer)
    if not held then return false,"offer-unavailable" end
    local token=body:getModData().SAOExternalToken
    if token~=nil and (type(token)~="string" or #token==0 or #token>160) then return false,"body-generation-invalid" end
    local sequence=(tonumber(r.exerciseLeisureSequence) or 0)+1
    if not finite(sequence) or sequence~=math.floor(sequence) then return false,"sequence-invalid" end
    local w=copy(held);w.id=nil;w.actorId=id;w.sequence=sequence;w.workId="exercise/"..id.."/"..sequence
    w.purposeId=purposeId;w.bodyToken=token;w.bodyGenerationKnown=type(token)=="string" and token~=""
    w.admittedAtHours=hours();w.atHours=w.admittedAtHours;w.status="prepared"
    w.nativeOwner=(w.family=="exercise" or w.family=="equipment-exercise") and "ISFitnessAction:owned-NPC-core" or "KA_Comfort:acquired-tank-adaptation"
    if w.family=="yoga" then w.nativeOwner="LSYogaAction:owned-source-core" end
    local ok,before=pcall(sample,body,w.activity)
    if not ok then return false,"measurements-unavailable" end
    local active={body=body,work=w,before=before,progress={repetitions=0,applications=0},
        actorId=id,record=r,bodyToken=body:getModData().SAOExternalToken,
        bodyGenerationKnown=w.bodyGenerationKnown}
    r.exerciseLeisureSequence=sequence;r.exerciseLeisureWork=w;runtime[id]=active
    local P=SAO.ProceduralPlanning
    if not P or not P.admitHobbyWork or not P.admitHobbyWork(id,purposeId,sequence,"SAO.LeisureExercise") then
        r.exerciseLeisureWork=nil;runtime[id]=nil
        return false,"typed-planner-admission-refused"
    end
    if w.family=="exercise" or w.family=="equipment-exercise" then
        if w.family=="equipment-exercise" then
            for _,machine in ipairs(machines(id,body)) do if machine.key==w.objectKey then active.machine=machine end end
            if not active.machine then finish(active,"interrupted","machine-custody-unavailable");return false,"machine-custody-unavailable" end
        end
        local created,action=pcall(function()
            if w.family=="equipment-exercise" or r.exerciseDefinitionScope then
                if not nativeDefinitionInit(id,body,w.activity) then error("native-definition-init-unavailable") end
            else body:getFitness():init() end
            return Action:new(body,w.activity,w.minutes,
            FitnessExercises.exercisesType[w.activity],w.activity) end)
        if not created or not action or not action.fitness:getCurrentExe() then
            finish(active,"interrupted","native-constructor-failed");return false,"native-constructor-failed"
        end
        action.owner=active;active.action=action
        if active.machine then action.FWOObject=active.machine.object;action.FWOObjectFacing=active.machine.facing end
        local admitted=pcall(ISTimedActionQueue.addGetUpAndThen,body,action)
        if not admitted then action.fitness:setCurrentExercise(nil);finish(active,"interrupted","queue-refused");return false,"queue-refused" end
        w.queueAdmitted=true
    elseif w.family=="yoga" then
        local skill=HiddenSkills.getSkill(body,"Yoga")
        if not skill or skill[1]~=w.sourceSkillLevel then finish(active,"interrupted","yoga-person-state-changed");return false,"yoga-person-state-changed" end
        local action=Yoga:new(body,skill[1],yogaArgs(skill[1]));action.owner=active;active.action=action
        w.nativeOwner="LSYogaAction:owned-source-core"
        local ok=pcall(ISTimedActionQueue.addGetUpAndThen,body,action)
        if not ok then finish(active,"interrupted","queue-refused");return false,"queue-refused" end
        w.queueAdmitted=true
    else
        active.tanks=tanks(id,body)
        w.status="active"
    end
    return true,copy(w)
end
function E.work(id) local r=record(id);return r and r.exerciseLeisureWork and copy(r.exerciseLeisureWork) end
function E.outcome(id,sequence)
    local r=record(id)
    for _,w in ipairs(r and r.exerciseLeisureOutcomes or {}) do
        if w.actorId==id and w.sequence==sequence then return copy(w) end
    end
end
local function cleanupCaptured(active)
    local action=active.action
    if active.soundEmitter and active.gameSound then
        pcall(function()active.soundEmitter:stopSound(active.gameSound)end)
        active.gameSound=nil
    end
    -- A retirement may revoke planning admission before the source stop runs.
    -- Native animation/Fitness cleanup still belongs to the same living body;
    -- source Yoga penalties/XP and new machine ending sounds require admission.
    local body=active.body
    local current=record(active.actorId)==active.record and SAO.Body.get(active.actorId)==body
        and SAO.Needs.ownsRecoveryBody(active.actorId,body) and body:isExistInTheWorld()
        and body:getModData().SAOPersonId==active.actorId
        and body:getModData().SAOExternalToken==active.bodyToken
    if current and not body:isDead() and not active.record.dead and action and action.character==body then
        if active.work.family=="exercise" or active.work.family=="equipment-exercise" then
            body:setVariable("ExerciseStarted",false);body:setVariable("ExerciseEnded",true)
            action.fitness:setCurrentExercise(nil)
        end
        body:setIsFarming(false)
    end
    if action and action.character==body then
        if action.action then pcall(function()action.action:forceStop()end)end
        removeOwnedAction(action)
    end
    active.stopped=true
end
function E.detach(id,body,reason)
    local active=runtime[id]
    if not active then return E.interrupt(id,body,reason)end
    if active.body~=body then return false end
    if live(id,body)then return E.interrupt(id,body,reason)end
    cleanupCaptured(active)
    local r=record(id)
    if r and r.exerciseLeisureWork==active.work then finish(active,"interrupted",reason or "native-body-owner-ended")
    else runtime[id]=nil end
    return true
end
function E.interrupt(id,body,reason)
    local r=record(id);local w=r and r.exerciseLeisureWork
    if not validWork(w,id) or not live(id,body) or not bodyMatches(w,body)
        or not finite(hours()) or hours()<w.admittedAtHours then return false end
    local active=runtime[id]
    if not active then
        active={body=body,work=w,before={},progress={repetitions=0,applications=0}}
    elseif active.body~=body then return false end
    if active.action and owned(active) then pcall(function()active.action:forceStop()end) end
    if runtime[id]==active then cleanupCaptured(active) end
    return finish(active,"interrupted",reason or "interrupted")
end
function E.prepareActor(id,body)
    if not live(id,body) then return false,"body-unavailable" end
    return SAO.Leisure and SAO.Leisure.prepareActor and SAO.Leisure.prepareActor(id,body)
end
-- Called by the maintained owner loop; applies source EveryTenMinutes regularity
-- to this exact canonical NPC without iterating player slots or online IDs.
function E.maintainActor(id,body)
    if not live(id,body) or not finite(hours()) then return false end
    local r=record(id);local at=hours();local last=r.fwoRegularityAtHours
    if last~=nil and not finite(last) then return false end
    if fwoActive() and (last==nil or at-last>=10/60) then
        local active=runtime[id]
        local physicalWork=active and owned(active) and (active.work.family=="exercise" or active.work.family=="equipment-exercise")
        fwoRegularity(body,physicalWork and active.work.activity or nil)
        r.fwoRegularityAtHours=at
    end
    return true
end
function E.advance(id,body)
    local r=record(id);local w=r and r.exerciseLeisureWork
    if not w then return false,"no-work" end
    if not validWork(w,id) then return false,"invalid-saved-work" end
    if not finite(hours()) or hours()<w.admittedAtHours then return false,"clock-regressed" end
    local active=runtime[id]
    if not active then
        if live(id,body) and bodyMatches(w,body) then E.interrupt(id,body,"reload-native-custody-unavailable") end
        return false,"reload-native-custody-unavailable"
    end
    if active.body~=body then return false,"foreign-body" end
    if not owned(active) then
        cleanupCaptured(active)
        return finish(active,"interrupted","body-custody-lost")
    end
    local at=hours();active.progress.elapsedMinutes=(at-w.admittedAtHours)*60
    if not permission(id,body) then E.interrupt(id,body,"standing-changed");return false,"standing-changed" end
    if w.family=="exercise" or w.family=="equipment-exercise" then
        if active.stopped then
            local completed=active.durationReached==true and active.progress.repetitions>0 and active.progress.elapsedMinutes>=w.minutes
            return finish(active,completed and "completed" or "interrupted",completed and "native-duration-and-repetitions" or "native-stopped-early")
        end
        local queue=ISTimedActionQueue.getTimedActionQueue(body)
        local present=false
        for _,action in ipairs(queue and queue.queue or {}) do if action==active.action then present=true;break end end
        if not present then return finish(active,"interrupted","native-queue-custody-lost") end
        w.nativeProgress=copy(active.progress);return true,"active"
    end
    if w.family=="yoga" then
        if active.stopped then return finish(active,active.completed and "completed" or "interrupted",
            active.completed and "native-source-yoga-ended" or "native-source-yoga-interrupted") end
        if not yogaReady(id,body) then E.interrupt(id,body,"yoga-prerequisites-changed");return false,"yoga-prerequisites-changed" end
        local queue=ISTimedActionQueue.getTimedActionQueue(body);local present=false
        for _,action in ipairs(queue and queue.queue or {}) do if action==active.action then present=true end end
        if not present then return finish(active,"interrupted","native-queue-custody-lost") end
        w.nativeProgress=copy(active.progress);return true,"active"
    end
    if w.family~="aquarium" then return false,"family-unavailable" end
    if not SAO.Needs.workAvailable(body) then E.interrupt(id,body,"body-busy");return false,"body-busy" end
    local acquired=tanks(id,body)
    local matching=false
    for _,current in ipairs(acquired) do
        if current.key==w.objectKey then
            for _,held in ipairs(active.tanks or {}) do
                if held.key==current.key and held.object==current.object then matching=true end
            end
        end
    end
    if not matching then E.interrupt(id,body,"acquired-tank-unavailable");return false,"acquired-tank-unavailable" end
    if active.progress.elapsedMinutes<1 then return true,"active" end
    local last=r.lastAquariumComfortAtHours
    if last~=nil and (not finite(last) or at-last<1/60) then
        E.interrupt(id,body,"comfort-cadence");return false,"comfort-cadence"
    end
    local K=KnoxAquarium
    local before=sample(body,w.activity)
    local scale=math.min(1,#acquired/K.comfortMaxTanks())
    local amounts={UNHAPPINESS=K.comfort.unhappiness*scale,
        BOREDOM=K.comfort.boredom*scale,STRESS=K.comfort.stress*scale}
    r.lastAquariumComfortAtHours=at -- An interrupted partial application cannot be retried in this minute.
    local success=pcall(function()
        local stats=body:getStats()
        stats:remove(CharacterStat.UNHAPPINESS,amounts.UNHAPPINESS)
        stats:remove(CharacterStat.BOREDOM,amounts.BOREDOM)
        stats:remove(CharacterStat.STRESS,amounts.STRESS)
    end)
    local after=sample(body,w.activity)
    for name,amount in pairs(amounts) do
        if not finite(before[name]) or not finite(after[name])
            or math.abs(after[name]-math.max(0,before[name]-amount))>0.00002 then success=false end
    end
    active.progress.applications=success and 1 or 0;active.progress.tanks=#acquired
    active.progress.sourceApplicationEffects=effects(before,after)
    return finish(active,success and "completed" or "interrupted",success and "native-comfort-applied" or "native-comfort-failed")
end
