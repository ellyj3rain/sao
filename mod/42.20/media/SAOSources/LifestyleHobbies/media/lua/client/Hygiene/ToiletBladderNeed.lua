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

require "LSEffects/LSPerMinute"

LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerMin = LSMoodHandler.PerMin or {}

local function getSatisfyConditions(character)
	if character:getVehicle() then return false; end
	local zombies = LSMovObjs.getMovingObjects(character:getSquare(), "IsoZombie", 8)
	if zombies and #zombies > 0 then return false; end
	if character:hasTimedActions() then character:StopAllActionQueue(); end
	if character:isSitOnGround() or character:isSittingOnFurniture() then ISTimedActionQueue.add(ISWaitWhileGettingUp:new(character)); end
	return true
end

local function doBBNegMoodles(thisPlayer, playerData)
	if playerData.LSMoodles["Embarrassed"] and playerData.LSMoodles["Embarrassed"].Value then
		playerData.LSMoodles["Embarrassed"].Value = playerData.LSMoodles["Embarrassed"].Value + 0.45
		if playerData.LSMoodles["Embarrassed"].Value > 1 then playerData.LSMoodles["Embarrassed"].Value = 1; end
		HaloTextHelper.addTextWithArrow(thisPlayer, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)
	end
end

local function doBBDirtVisual(thisPlayer, playerData)
	local visual = thisPlayer:getHumanVisual()
	for i = 1, BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i - 1)
		local bodyPartList = require("LSBodyPartList")
		for k,v in pairs(bodyPartList) do
			local partFromList = BloodBodyPartType.FromString(v.name)
			if v.category == "low" and part:getDisplayName() == partFromList:getDisplayName() then
				local dirt = visual:getDirt(part)
				if dirt < 1 then
					visual:setDirt(part, 1)
				end
			end
		end
	end
	if LSUtil.getCharacterMood(thisPlayer, "Wetness") < 70 then LSUtil.changeCharacterMood(thisPlayer, "Wetness", 70, false, true); end
	playerData.hygieneNeed = 100
	HaloTextHelper.addTextWithArrow(thisPlayer, getText("IGUI_HaloNote_Hygiene"), false, 255, 120, 120)
end

local function BBadjustStats(character)
	--VARIABLES
	local addUnhappiness = 50
	local addStress = 0.5
	local Trait = 1

	--TRAIT
	if character:hasTrait(CharacterTrait.CLEANFREAK) then
		Trait = 0.5
	elseif character:hasTrait(CharacterTrait.SLOPPY) then
		Trait = 2
	end

	--PANIC
	if character:getMoodles():getMoodleLevel(MoodleType.PANIC) > 2 then addUnhappiness = addUnhappiness/2; addStress = addStress/2; end

	--DEFINES
	--STRESS 0 - 1
	--LSUtil.changeCharacterMood(thisPlayer, "Stress", addStress/Trait, false, false, true)
	--UNHAPPYNESS 0 - 100
	--LSUtil.changeCharacterMood(thisPlayer, "Unhappiness", addUnhappiness/Trait, false, false, true)
	
	LSUtil.changeCharacterMoodGroup(character, {
		["Unhappiness"] = {addUnhappiness/Trait, false, false, true},
		["Stress"] = {addStress/Trait, false, false, true},
	})
	
end

local function DoBladderBurst(thisPlayer, playerData)
	--add puddle
	if not thisPlayer:isOutside() then
		LSHygiene.TF.doDirtPuddle(thisPlayer:getSquare())
	end
	--add negative moodles
	doBBNegMoodles(thisPlayer, playerData)
	--make character wet and dirtier (visually and h need)
	doBBDirtVisual(thisPlayer, playerData)
	--set bladder need to 0
	playerData.bathroomNeed = 0
	playerData.LSMoodles["BladderNeed"].Value = 0
	--add stress and unhappiness
	BBadjustStats(thisPlayer)
	if getSatisfyConditions(thisPlayer) then
		--play the ta
		ISTimedActionQueue.add(LSReactionFullBladder:new(thisPlayer))
	end
	getSoundManager():playUISound("UI_sting_fail"..tostring(ZombRand(4)+1))
	--play sound
	--getWorld():getFreeEmitter()
	--local emitter = getWorld():getFreeEmitter()
	--local sound = emitter:playSoundImpl("UI_sting_fail"..tostring(ZombRand(4)+1), false) -- requires IsoObject or IsoGridSquare proxy
	--emitter:setVolume(sound, 0.1)
end

function AdjustBladderNeed(thisPlayer, playerData, bodyDamage)

	local increaseRate = 0.06
	local traitMultiplier = 1
	local traitMultiplierPain1 = 1
	local PainChange
	local BladderFull
	local moodList

	----------------- TO DO LIST

	-- GENERAL
	-- x tick up slowly; more if satiated; less if hungry, asleep or thirsty
	-- x wake up if at tier 2 (from 0) - sandbox toggle
	-- x can use toilet starting at tier 0, no mood effect
	-- x tier 1 no mood effect unless weak stomach
	-- x tier 2 slight pain and stress (more if weak stomach; less if iron gut)
	-- x tier 3 pain and stress (debilitating pain for weak stomach; players can soil themselves upon reaching max level at this tier)
	-- x freeze need increase during toilet use

	-- TRAITS
	-- x WeakStomach should give pain and smaller bladder threshold (or bigger rate)
	-- x IronGut no pain except last level and bigger bladder threshold (or smaller rate)
	-- x HighThirst/HeartyAppitite increased bladder rate, traits not cumulative, negated by LightEater/LowThirst
	-- x LowThirst/LightEater decreased bladder rate, traits not cumulative, negated by HighThirst/HeartyAppitite
	-- x Cowardly -1 level required to soil themselves due to panic; Brave and Desensitized will never soil due to panic

	-- SOIL
	-- x Panic at high bladder level can cause player to soil themselves (no animation or sound as to not interrupt combat)
	-- x If not caused by panic then do animation and sound IF player is not holding a weapon, running or aiming (in case of desensitized or long lived character), interrupted by running; if sitting then force get up first; if doing another timed action then clear queue and cancel action;
	-- x Upon reaching maximum bladder level there's a 10% chance player will soil themselves each minute
	-- x Soiling yourself makes lower bodyparts and clothes wet and max dirt
	-- x Decreases bladder need to 0; increases hygiene need to 100
	-- x "Had an accident" and embarrassed moodle; embarrassed clears faster but had an accident can stay up to several in-game hours (less if sloppy, more if neat freak);
	-- x if panicked embarrassed won't trigger and had an accident won't give penalties (moodle duration suspended until panic is lower);
	-- x Goal is to heavily penalize players who ignore bladder need, but not kill them immediately by setting max unhappiness during a combat situation (will reach max eventually trough the moodle);

	-- OTHER NOTES
	-- x Using the toilet without toilet paper or ripped sheets in inventory, bag or nearby container will decrease hygiene and add dirt; paper napkins and tissues can be used but will only reduce the hygiene decrease (but no added dirt)
	-- x If toilet paper or ripped sheet is around the toilet icon (next to the use toilet) will show with default color, if not present will show dark red, if only tissue or napkin will show brownish yellow, tooltip to explain
	-- If toilet has the bidet improvement (only for fancy and low) then it won't decrease hygiene or add dirt and won't use toilet paper, ripped sheets, etc; but will use slightly more water (won't activate if not enough water); toilet with bidet shows toilet icon golden yellow (if enough water for bidet); tooltip explains "toilet with bidet improvement"
	-- x Relieving bladder need on the ground is only available at tier >= 2 (-1 if outdoorsman or sloppy); medium decrease to hygiene and adds more dirt to body parts (less if outdoorsman, no benefit if character is also sloppy); toilet paper and ripped sheets will mitigate hygiene decrease and added dirt; should also add dirt to ground
	-- x/2 Embarrassed moodle if another player walks in, will interrupt toilet use. Player will be unable to use option again for a few minutes. Character will complain if others are nearby.
	-- If newspaper, magazine or book in inventory or nearby container character may spontaneously "read" for a bit of boredom decrease; won't consume item, long interval before happening again. For fancy and low toilet only;
	-- Hanging toilet, outhouse/wooden and chemical can't have improvements (except auto-cleaning for hanging toilet); hanging can only be used by men, is slightly faster than toilets, has a steady hygiene decrease that can't be removed by upgrades or toilet paper
	-- x IMPORTANT - other players detection can't be by area, must use line of sight (otherwise stalls won't work); player who walk in on another using the toilet will get first tier of embarrassed (not more);

	----------------------------

	if thisPlayer:hasTrait(CharacterTrait.IRON_GUT) then
		increaseRate = 0.04
		traitMultiplierPain1 = 0.5
	elseif thisPlayer:hasTrait(CharacterTrait.WEAK_STOMACH) then
		increaseRate = 0.08
		traitMultiplier = 1.5
		traitMultiplierPain1 = 1.5
	end

	if (thisPlayer:hasTrait(CharacterTrait.HIGH_THIRST) and not thisPlayer:hasTrait(CharacterTrait.LIGHT_EATER)) or (thisPlayer:hasTrait(CharacterTrait.HEARTY_APPETITE) and not thisPlayer:hasTrait(CharacterTrait.LOW_THIRST)) then
		increaseRate = increaseRate + 0.015
	elseif (thisPlayer:hasTrait(CharacterTrait.LIGHT_EATER) and not thisPlayer:hasTrait(CharacterTrait.HIGH_THIRST)) or (thisPlayer:hasTrait(CharacterTrait.LOW_THIRST) and not thisPlayer:hasTrait(CharacterTrait.HEARTY_APPETITE)) then
		increaseRate = increaseRate - 0.015
	end

	if thisPlayer:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) > 0 then
		increaseRate = increaseRate + 0.08
	elseif (thisPlayer:isAsleep()) or (thisPlayer:getMoodles():getMoodleLevel(MoodleType.HUNGRY) > 0) or (thisPlayer:getMoodles():getMoodleLevel(MoodleType.THIRST) > 0) then
		increaseRate = increaseRate - 0.05
	end

	if increaseRate < 0.01 then increaseRate = 0.01; end

	if playerData.LSMoodles["BladderNeed"].Value == 0 or playerData.LSMoodles["BladderNeed"].Value == 0.8 then--we do this so that bladder need takes longer to show up and takes longer to reach 100 need
		increaseRate = increaseRate * 0.5
	end

	increaseRate = increaseRate*SandboxVars.LSHygiene.BladderNeedMultiplier

	if not playerData.IsDoingToilet then playerData.IsDoingToilet = false; end
	if not playerData.bathroomNeed then playerData.bathroomNeed = 0; end	
	if thisPlayer:isGodMod() then playerData.bathroomNeed = 0; end	
	if playerData.IsDoingToilet and not thisPlayer:hasTimedActions() then playerData.IsDoingToilet = false; end
	if playerData.IsDoingToilet then increaseRate = 0; end
	if thisPlayer:isAsleep() and playerData.LSMoodles["BladderNeed"].Value >= 0.7 then thisPlayer:setAsleep(false); thisPlayer:setAsleepTime(0.0); UIManager.FadeIn(thisPlayer:getPlayerNum(), 1); end

	if playerData.bathroomNeed < 100 and increaseRate > 0 then
		playerData.bathroomNeed = playerData.bathroomNeed + increaseRate
	elseif playerData.bathroomNeed > 100 then
		playerData.bathroomNeed = 100
	end

	--PAIN
	--local currentPain = thisPlayer:getStats():getPain()
	local currentPain = bodyDamage:getBodyPart(BodyPartType.Torso_Lower):getPain()


	if playerData.bathroomNeed >= 90 then--COMFORT
		playerData.LSMoodles["BladderNeed"].Value = 0.8
		if playerData.LSMoodles["BladderNeed"].Level == 4 then
			playerData.LSMoodles["BladderNeed"].Level = 4.1
		end
		PainChange = 20*traitMultiplierPain1 
		if currentPain > 90 then
			PainChange = 0
		end
		if PainChange > 0 then
			LSUtil.addPainBodyPart(thisPlayer, "Torso_Lower", PainChange, false)
		end
		if not thisPlayer:isAsleep() then
			moodList = {
				["Unhappiness"] = {0.4*traitMultiplier, false, false, true},
				["Stress"] = {0.015*traitMultiplier, false, false, true},
			}
		else
			thisPlayer:setAsleep(false);
			thisPlayer:setAsleepTime(0.0);
			UIManager.FadeIn(thisPlayer:getPlayerNum(), 1);
		end
	elseif playerData.bathroomNeed >= 80 then
		playerData.LSMoodles["BladderNeed"].Value = 0.6
		PainChange = 10*traitMultiplierPain1
		if currentPain > 60 then
			PainChange = 0
		end
		if PainChange > 0 then
			LSUtil.addPainBodyPart(thisPlayer, "Torso_Lower", PainChange, false)
		end
		if not thisPlayer:isAsleep() then
			moodList = {
				["Unhappiness"] = {0.2*traitMultiplier, false, false, true},
				["Stress"] = {0.005*traitMultiplier, false, false, true},
			}
		end
	elseif playerData.bathroomNeed >= 60 then
		playerData.LSMoodles["BladderNeed"].Value = 0.4
		PainChange = 5*traitMultiplierPain1 
		if currentPain > 25 then
			PainChange = 0
		end
		if PainChange > 0 then
			LSUtil.addPainBodyPart(thisPlayer, "Torso_Lower", PainChange, false)
		end
		if not thisPlayer:isAsleep() then
			LSUtil.changeCharacterMood(thisPlayer, "Stress", 0.002*traitMultiplier, false, false)
		end
	elseif playerData.bathroomNeed >= 30 then
		playerData.LSMoodles["BladderNeed"].Value = 0.2
	elseif playerData.bathroomNeed < 30 then
		playerData.LSMoodles["BladderNeed"].Value = 0
	end

	-------------- Bladder Control
	local d10 = ZombRand(10) + 1
	if thisPlayer:isAsleep() then d10 = 1; end
	if playerData.bathroomNeed >= 100 and d10 == 10 then
		BladderFull = true
	elseif playerData.bathroomNeed >= 80 and d10 >= 8 and thisPlayer:getMoodles():getMoodleLevel(MoodleType.PANIC) > 2 and (not thisPlayer:hasTrait(CharacterTrait.DESENSITIZED)) and (not thisPlayer:hasTrait(CharacterTrait.BRAVE)) then
		BladderFull = true
	elseif playerData.bathroomNeed >= 60 and d10 >= 7 and thisPlayer:getMoodles():getMoodleLevel(MoodleType.PANIC) > 2 and thisPlayer:hasTrait(CharacterTrait.COWARDLY) then
		BladderFull = true
	end

	if BladderFull then
		DoBladderBurst(thisPlayer, playerData)
	elseif moodList then
		for k, v in pairs(moodList) do
			if not v[3] then -- refuses to add from isSet
				if not LSMoodHandler.PerMin[k] then
					LSMoodHandler.PerMin[k] = {v[1], v[2], v[3], v[4]}
				else
					LSMoodHandler.PerMin[k][1] = LSMoodHandler.PerMin[k][1]+v[1]
				end
			end
		end
	end

end
