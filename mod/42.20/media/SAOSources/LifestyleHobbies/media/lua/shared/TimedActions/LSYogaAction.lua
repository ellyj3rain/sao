--------------------------------------------------------------------------------------------------
--		----	  |			  |			|		 |				|    --    |      ----			--
--		----	  |			  |			|		 |				|    --	   |      ----			--
--		----	  |		-------	   -----|	 ---------		-----          -      ----	   -------
--		----	  |			---			|		 -----		------        --      ----			--
--		----	  |			---			|		 -----		-------	 	 ---      ----			--
--		----	  |		-------	   ----------	 -----		-------		 ---      ----	   -------
--			|	  |		-------			|		 -----		-------		 ---		  |			--
--			|	  |		-------			|	 	 -----		-------		 ---		  |			--
--------------------------------------------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"

LSYogaAction = ISBaseTimedAction:derive("LSYogaAction");

function LSYogaAction:isValid()
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
	local square = character:getSquare()
	if not square then return false; end
	--print("getYogaMat - found square")
	local matVars, adjObject
	for i=1,square:getObjects():size() do
		local obj = square:getObjects():get(i-1)
		if obj then
			--print("getYogaMat - found obj")
			local objName = obj:getSpriteName() or obj:getTextureName()
			if objName then
				--print("getYogaMat - found objName: "..objName)
				matVars = getMat(objName)
				if matVars then break; end
			end
		end
	end
	if matVars then
		--print("getYogaMat - found matVars")
		objAdjSqr = square[matVars[2]](square)
		if not objAdjSqr then return false; end
		--print("getYogaMat - found objAdjSqr")
		for i=1,objAdjSqr:getObjects():size() do
			local obj = objAdjSqr:getObjects():get(i-1)
			if obj then
				--print("getYogaMat - found objAdjSqr obj")
				local objName = obj:getSpriteName() or obj:getTextureName()
				--if objName then print("getYogaMat - found objAdjSqr objName: "..objName); print("getYogaMat - matVars[1] is: "..matVars[1]); end
				if objName and objName == matVars[1] then adjObject = obj; break; end
			end
		end
	end
	return adjObject
end

function LSYogaAction:waitToStart()
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

function LSYogaAction:update()
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

function LSYogaAction:endAction()
	--stopSound(self.character, self.sound)
	self:forceComplete()
end

function LSYogaAction:doFinalInteraction()
	--stopSound(self.character, self.sound)
	self.animVars = {parent=false,anim="Bob_Yoga_Rest_"..self.skillGroup,countTotal=100,soundTime=100,fail=0}
	self:setActionAnim(self.animVars.anim.."_Start")
end

function LSYogaAction:endFinalInteraction()
	--stopSound(self.character, self.sound)
	self.animVars.countTotal = false
	self:setActionAnim("Bob_Yoga_Rest_"..self.skillGroup.."_End")
	self["reduceStiffness"](self)
	self["reducePainStressBoredom"](self)
end

function LSYogaAction:endInteraction()
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

function LSYogaAction:embarrassSelf()
	if not self.playerData.LSMoodles["Embarrassed"] then return; end
	self.playerData.LSMoodles["Embarrassed"].Value = self.playerData.LSMoodles["Embarrassed"].Value + 0.2
	HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)
end

function LSYogaAction:resetPhases(list, all)
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

function LSYogaAction:doInteraction()
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

function LSYogaAction:start()

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

function LSYogaAction:stop()
	--stopSound(self.character, self.sound)
	self["reduceXP"](self)

    ISBaseTimedAction.stop(self);		
end

function LSYogaAction:reducePainStressBoredom()
	LSUtil.changeCharacterMoodGroup(self.character, {
		["Boredom"] = {-5, false, false, true},
		["Nicotine_Withdrawal"] = {-0.01*self.bonus, false, false, true},
		["Stress"] = {-0.01*self.bonus, true, false, true},
		["Pain"] = {-5*self.bonus*self.sandboxMult, false, false, true},
	})
end

function LSYogaAction:reduceStiffness()
	LSUtil.reduceAllStiffness(self.character, 2*self.bonus*self.sandboxMult)
end

function LSYogaAction:reduceXP() -- penalty for stopping earlier, can't reduce level / penalty is based on how many poses were done vs pose limit / penalty is not applied if no xp was granted / reduces xp and zen
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

function LSYogaAction:grantXP() -- pose base xp multiplied by the sum of total bonus (skill+variables) + ceil result of zen level/2 (1,2)
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

function LSYogaAction:grantBonusXP() -- random number between a third and the total sum of xp from all the poses performed (bonus included), limited by level
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

function LSYogaAction:fitnessBonus()
	if self.playerData.LSZenActive then return; end
	local val = 0.05*self.bonus*self.sandboxMult
	if FitnessExercises and FitnessExercises.exercisesType then
		self.playerData.LSZenActive = {}
		for k, v in pairs(FitnessExercises.exercisesType) do
			local ogVal = v.xpMod
			self.playerData.LSZenActive[k] = ogVal
			v.xpMod = ogVal+val
			--print("LSYogaAction:fitnessBonus - key value "..tostring(k).." was: "..tostring(ogVal).." and is now:"..tostring(v.xpMod))
		end
	end
end

function LSYogaAction:perform()
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

function LSYogaAction:complete()

	return true
end

function LSYogaAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function LSYogaAction:new(character, skillLevel, Args)
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