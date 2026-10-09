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

LSDT = LSDT or {}
LSDT.lvl_ARTISTIC = 6
LSDT.lvl_TIDY = 6
LSDT.lvl_SLOPPY = 4
LSDT.lvl_DISCIPLINED = 8
LSDT.lvl_VIRTUOSO = 8
LSDT.lvl_TONEDEAF = 4
LSDT.lvl_PARTYANIMAL = 8
LSDT.lvl_KILLJOY = 4

local function doAmbitionsNote(thisPlayer)
	local text = " <CENTRE> "..getText("IGUI_T_Ambt_Note")
	local infoText = " <LINE><H1> "..getText("IGUI_T_Ambt_Title").." <LINE> ".." <CENTRE> <IMAGECENTRE:media/ui/tutorial/Ambt_01.png> <LINE><LINE><TEXT> "..getText("IGUI_T_Ambt_Body").." <LINE><LINE> "..getText("IGUI_T_Ambt_Body2")
	.." <LINE><LINE> "..getText("IGUI_T_Ambt_Body3").." <LINE><LINE> "..getText("IGUI_T_Ambt_Body4").." <LINE><LINE> "..getText("IGUI_T_Ambt_Body5").." <LINE><LINE> "..getText("IGUI_T_Ambt_Body6")
	local args = {
		text,
		"tutorialAmbt",
		'media/ui/Ambitions/Ambitions_RO.png',
		5,
		"noteAmbt",
		infoText,
		true,
		{5,9,32}
	}
	LSUtil.doNote(thisPlayer, args)
end

local function doAmbitionsCooldown(thisPlayer, playerData)
	local items = playerData.Ambitions
	for k, v in pairs(items) do
		if playerData.Ambitions[v.name] and (not v.disable) and v.cd and (v.cd > 0) then
			playerData.Ambitions[v.name].cd = v.cd - 1
		end
	end
	if SandboxVars.LSAmbt.Toggle and not thisPlayer:isAsleep() and ZombRand(4) == 1 and thisPlayer:getHoursSurvived()/24 > 7 then
		doAmbitionsNote(thisPlayer)
	end
end

local function doPlayerCooldowns(player, playerData, mins)
	if not playerData.LSCooldowns then playerData.LSCooldowns = {}; end
	local t = LSUtil.getPlayerCooldowns(mins)
	if not t then print("WARN - LSUtil.getPlayerCooldowns, could not get cooldown table for mins="..tostring(mins)); return; end
	for n=1,#t[2] do
		local decrease = 1
		local value = t[2][n]
		--print("doPlayerCooldowns checking cooldown for " .. value)
		if not playerData.LSCooldowns[value] then
			playerData.LSCooldowns[value] = 0
		end
		if playerData.LSCooldowns[value] and (playerData.LSCooldowns[value] > 0) then
			if value == "mentalBlock" then
				local level = HiddenSkills.getLevel(player, "Inventing")
				if level and level >= 6 then decrease = 2; end
			end
			playerData.LSCooldowns[value] = playerData.LSCooldowns[value] - decrease
			--print("doPlayerCooldowns reducing cooldown by 1 for " .. value)
		end
		if playerData.LSCooldowns[value] and (playerData.LSCooldowns[value] < 0) then
			playerData.LSCooldowns[value] = 0
		end
	end

	for n=1,#t[1] do
		local value = t[1][n]
		if playerData.LSMoodles[value] and (playerData.LSMoodles[value].Value > 0) then
			playerData.LSMoodles[value].Value = playerData.LSMoodles[value].Value - 0.2
		end
		if playerData.LSMoodles[value] and (playerData.LSMoodles[value].Value < 0.2) then
			playerData.LSMoodles[value].Value = 0
		end
	end


end

local function doPlayerCooldownsSimple(playerData)
	playerData.TDcomplained = false
	playerData.CurrentBedQuality = false
end

local function severityTable(sev)
	t = {
		k1 = {5, 11},
		k2 = {10, 21},
		k3 = {15, 41},
		k4 = {20, 61},
	}
	return t[sev]
end

local function HNgetColdSeverity()
	local sevSO = SandboxVars.LSHygiene.ColdSeverity or 2
	severity = severityTable("k"..tostring(sevSO))
	return ZombRand(severity[1], severity[2])
end

local function HNdoCatchCold(player)
	local severity = HNgetColdSeverity()
	player:getBodyDamage():setCatchACold(0.0);
	player:getBodyDamage():setHasACold(true);
	player:getBodyDamage():setColdStrength(severity);
	player:getBodyDamage():setTimeToSneezeOrCough(0);
end

local function HNdoColdChance(player)
	if not player or player:getBodyDamage():isHasACold() then return; end
	local chance, chanceMulti = 100, SandboxVars.LSHygiene.ColdChanceMultiplier or 0
	if chanceMulti <= 0 then return; end
	chance = chance/chanceMulti
	if chance == 0 then return false; end
	if player:hasTrait(CharacterTrait.RESILIENT) then
		chance = chance*1.2
	elseif player:hasTrait(CharacterTrait.PRONE_TO_ILLNESS) then
		chance = chance*0.8
	end
	if ZombRand(math.floor(chance)) == 0 then HNdoCatchCold(player); end
end

local function getTraitsTable()
	return {
		{trait="Artistic",traitsN={"Artistic"},skill="Art",level=LSDT.lvl_ARTISTIC,add=true,mod="DividerArt"},
		{trait="Tidy",traitsN={"Tidy","Sloppy"},skill="Cleaning",level=LSDT.lvl_TIDY,add=true,mod="DividerHygiene"},
		{trait="Sloppy",traitsN=false,skill="Cleaning",level=LSDT.lvl_SLOPPY,add=false,mod="DividerHygiene"},
		{trait="Disciplined",traitsN={"Disciplined","CouchPotato","Overweight","Obese","Out_of_Shape","Unfit"},skill="Meditation",level=LSDT.lvl_DISCIPLINED,add=true,mod="DividerMeditationNew"},
		--{trait="CouchPotato",traitsN={"Overweight","Obese"},skill="Meditation",level=4,add=false,mod="DividerMeditationNew"},
		{trait="Virtuoso",traitsN={"Virtuoso","ToneDeaf","Deaf","Hard_Of_Hearing"},skill="Music",level=LSDT.lvl_VIRTUOSO,add=true,mod="DividerMusicNew"},
		{trait="ToneDeaf",traitsN=false,skill="Music",level=LSDT.lvl_TONEDEAF,add=false,mod="DividerMusicNew"},
		{trait="PartyAnimal",traitsN={"PartyAnimal","Killjoy","Deaf"},skill="Dancing",level=LSDT.lvl_PARTYANIMAL,add=true,mod="DividerDancingNew"},
		{trait="Killjoy",traitsN=false,skill="Dancing",level=LSDT.lvl_KILLJOY,add=false,mod="DividerDancingNew"},
	}

end

local function getCanLosePos(thisPlayer, trait, added)
	if not added or not thisPlayer:hasTrait(CharacterTrait[string.upper(trait)]) then return false;
	elseif SandboxVars.LS.DynamicTraitsReverse == 2 then return true;
	elseif SandboxVars.LS.DynamicTraitsReverse == 3 then return thisPlayer:getModData().LSDLT[trait]; end
	return false
end

local function removeDLTrait(character, traitName)
	local traitUpper = string.upper(traitName)
	if isClient() then 
		sendClientCommand(character, "LS", "ChangeTrait", {traitUpper, "remove"})
	else
		character:getCharacterTraits():remove(CharacterTrait[traitUpper]);
		character:modifyTraitXPBoost(CharacterTrait[traitUpper], true);
		SyncXp(character)
	end
	character:getModData().LSDLT[traitName] = false
end

local function addDLTrait(character, traitName)
	local traitUpper = string.upper(traitName)
	if isClient() then 
		sendClientCommand(character, "LS", "ChangeTrait", {traitUpper, "add"})
	else
		character:getCharacterTraits():add(CharacterTrait[traitUpper]);
		character:modifyTraitXPBoost(CharacterTrait[traitUpper], false);
		SyncXp(character)
	end
	character:getModData().LSDLT[traitName] = {}
end

local function couchPotatoLogic(character)
	if character:hasTrait(CharacterTrait["DISCIPLINED"]) then return; end
	local charData = character:getModData()
	charData.LSDLT['CouchPotato'] = charData.LSDLT['CouchPotato'] or {}
	local potatoData = charData.LSDLT['CouchPotato']
	potatoData.reqHours = potatoData.reqHours or ZombRand(500,601)
	if character:hasTrait(CharacterTrait["COUCHPOTATO"]) then
		if character:hasTrait(CharacterTrait["OBESE"]) or character:hasTrait(CharacterTrait["OVERWEIGHT"]) then return; end
		if potatoData.outHours and potatoData.outHours >= potatoData.reqHours and ZombRand(20) == 0 then
			removeDLTrait(character, "CouchPotato")
			HaloTextHelper.addTextWithArrow(character, getText("IGUI_HaloNote_LSDynamicTraitRemove")..", "..getText("UI_trait_couchpotato"), false,  30, 190, 240)
			getSoundManager():playUISound("PZLevelSound")
		end
	elseif potatoData.outHours and potatoData.outHours <= -(potatoData.reqHours*2) and ZombRand(20) == 0 then
		addDLTrait(character, "CouchPotato")
		HaloTextHelper.addTextWithArrow(character, getText("IGUI_HaloNote_LSDynamicTraitAdd")..", "..getText("UI_trait_couchpotato"), true,  30, 190, 240)
	end
	LSUtil.debugDiagnostics("/client/LSEffects/LSPerHour", "couchPotatoLogic",{
	['potatoData.reqHours']=potatoData.reqHours,
	['potatoData.reqHours inside']=-potatoData.reqHours*2,
	['potatoData.outHours']=potatoData.outHours,
	['character:hasTrait(CharacterTrait["OBESE"])']=character:hasTrait(CharacterTrait["OBESE"]),
	})
end

LSDT.doSatisfyTraitCheck = function(thisPlayer, sTraits, noSound)
	if not SandboxVars.LS.DynamicTraits then return; end
	if not thisPlayer:getModData().LSDLT then thisPlayer:getModData().LSDLT = {}; end
	local traits, badOutcome, t = false, false, getTraitsTable()
	local noteTraits
	for k, v in pairs(t) do
		local traitName = string.upper(v.trait)
		local hasLevel, canLosePos = thisPlayer:getPerkLevel(Perks[v.skill]) >= v.level, getCanLosePos(thisPlayer, v.trait, v.add)
		if (not v.mod or SandboxVars.Text[v.mod]) and (v.add or thisPlayer:hasTrait(CharacterTrait[traitName])) and (hasLevel or canLosePos) then
			local incompatible, isAdd = false, v.add
			if canLosePos and not hasLevel then isAdd = false; badOutcome = true;
			elseif v.traitsN then
				for n=1, #v.traitsN do
					traitName = string.upper(v.traitsN[n])
					if CharacterTrait[traitName] and thisPlayer:hasTrait(CharacterTrait[traitName]) then incompatible = true; break; end
				end
			end
			if not incompatible then
				if not traits then traits = {}; end
				--if not sTraits then
					table.insert(traits, {trait=v.trait,add=isAdd})
				--else
				if sTraits then
					noteTraits = noteTraits or {}
					for n=1,#sTraits do
						if traitName == sTraits[n] then noteTraits[traitName] = (isAdd and "good") or "bad"; break; end
					end
				end
			end
		end
	end
	
	if traits then
		local textAdded, textRemoved = "", ""
		for k, v in pairs(traits) do
			local traitLower = string.lower(v.trait)
			if v.add then
				addDLTrait(thisPlayer, v.trait)
				textAdded = textAdded..", "..getText("UI_trait_"..traitLower)
			else
				removeDLTrait(thisPlayer, v.trait)
				textRemoved = textRemoved..", "..getText("UI_trait_"..traitLower)
			end
		end
		if textAdded ~= "" then textAdded = getText("IGUI_HaloNote_LSDynamicTraitAdd")..textAdded; HaloTextHelper.addTextWithArrow(thisPlayer, textAdded, true,  30, 190, 240); end
		if textRemoved ~= "" then textRemoved = getText("IGUI_HaloNote_LSDynamicTraitRemove")..textRemoved; HaloTextHelper.addTextWithArrow(thisPlayer, textAdded, false,  30, 190, 240); end
		if not badOutcome and not noSound then getSoundManager():playUISound("PZLevelSound"); end
		if sTraits then return noteTraits; end
		return
	end
	if sTraits then return noteTraits; end
	couchPotatoLogic(thisPlayer)
end

local ls_hourCount = 0

local function EveryTwoHours(thisPlayer)
	if ls_hourCount < 2 then return; end
	doPlayerCooldowns(thisPlayer, thisPlayer:getModData(), 120)
	
end

function LSEveryHour()
	ls_hourCount = (ls_hourCount >= 2 and 1) or ls_hourCount+1
	local thisPlayer = getPlayer()

	if thisPlayer and not thisPlayer:isDead() then
		EveryTwoHours(thisPlayer)
		local playerData = thisPlayer:getModData()
		local bodyDamage = thisPlayer:getBodyDamage()

		--print("trying to call doPlayerCooldowns")
		doPlayerCooldowns(thisPlayer, playerData, 60)
		doPlayerCooldownsSimple(playerData)
		doAmbitionsCooldown(thisPlayer, playerData)
		LSDT.doSatisfyTraitCheck(thisPlayer, nil, nil)

		if SandboxVars.Text.DividerHygiene and playerData.hygieneNeed > 80 then HNdoColdChance(thisPlayer); end

	if playerData.LSMoodles["MintFresh"] and playerData.LSMoodles["MintFresh"].Value and playerData.LSMoodles["MintFresh"].Value > 0 then
		if playerData.lastBrushTeeth and (playerData.lastBrushTeeth + 3) <= thisPlayer:getHoursSurvived() then
			playerData.LSMoodles["MintFresh"].Value = 0
		end
	end
	if playerData.LSMoodles["BathHot"] and playerData.LSMoodles["BathHot"].Value and playerData.LSMoodles["BathHot"].Value > 0 then
		if playerData.lastBath and (playerData.lastBath + 1) <= thisPlayer:getHoursSurvived() then
			playerData.LSMoodles["BathHot"].Value = 0
		end
	end
	if playerData.LSMoodles["BathCold"] and playerData.LSMoodles["BathCold"].Value and playerData.LSMoodles["BathCold"].Value > 0 then
		if playerData.lastBath and (playerData.lastBath + 1) <= thisPlayer:getHoursSurvived() then
			playerData.LSMoodles["BathCold"].Value = 0
		end
	end

	if playerData.LSMoodles["MintCurio"] and playerData.LSMoodles["MintCurio"].Value and playerData.LSMoodles["MintCurio"].Value >= 0.4 and not playerData.mintCurioEffect then
		local chance = ZombRand(math.floor(100*playerData.LSMoodles["MintCurio"].Value))
		if chance <= 10 then
			LSUtil.changeCharacterMood(thisPlayer, "Intoxication", 100, false, true, true)
			playerData.mintCurioEffect = true
		end
	end

		if playerData.FitnessActivityMuscles ~= nil and playerData.DidFitnessActivity ~= nil then
		
		else
			playerData.FitnessActivityMuscles = 0
			playerData.DidFitnessActivity = 0
		end
		
		if playerData.DidFitnessActivity ~= nil and playerData.DidFitnessActivity ~= 0 and thisPlayer:getPerkLevel(Perks.Fitness) <= 8 then
			playerData.DidFitnessActivity = playerData.DidFitnessActivity + 1
		end

		if playerData.DidFitnessActivity ~= nil and playerData.DidFitnessActivity >= 36 then
			playerData.DidFitnessActivity = 0
			playerData.FitnessActivityMuscles = 0
		end
		--print("didfitnessactivity is ".. playerData.DidFitnessActivity)
		--print("fitnessactivitymuscles is ".. playerData.FitnessActivityMuscles)
		if playerData.DidFitnessActivity ~= nil and playerData.DidFitnessActivity == 12 then
			local LowerLegL = bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):getStiffness()
			local UpperLegL = bodyDamage:getBodyPart(BodyPartType.UpperLeg_L):getStiffness()
			local LowerLegR = bodyDamage:getBodyPart(BodyPartType.LowerLeg_R):getStiffness()
			local UpperLegR = bodyDamage:getBodyPart(BodyPartType.UpperLeg_R):getStiffness()
			local TorsoLower = bodyDamage:getBodyPart(BodyPartType.Torso_Lower):getStiffness()
			--print("stiffness was ".. bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):getStiffness())
			if playerData.FitnessActivityMuscles >= 200 then--severe
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):setStiffness(LowerLegL + 90)
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_L):setStiffness(UpperLegL + 90)
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_R):setStiffness(LowerLegR + 90)
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_R):setStiffness(UpperLegR + 90)
				bodyDamage:getBodyPart(BodyPartType.Torso_Lower):setStiffness(TorsoLower + 90)
			elseif playerData.FitnessActivityMuscles >= 150 then--mild
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):setStiffness(LowerLegL + 60)
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_L):setStiffness(UpperLegL + 60)
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_R):setStiffness(LowerLegR + 60)
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_R):setStiffness(UpperLegR + 60)
				bodyDamage:getBodyPart(BodyPartType.Torso_Lower):setStiffness(TorsoLower + 60)
			elseif playerData.FitnessActivityMuscles >= 50 then--low
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):setStiffness(LowerLegL + 30)
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_L):setStiffness(UpperLegL + 30)
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_R):setStiffness(LowerLegR + 30)
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_R):setStiffness(UpperLegR + 30)
				bodyDamage:getBodyPart(BodyPartType.Torso_Lower):setStiffness(TorsoLower + 30)
			else
				playerData.DidFitnessActivity = 0
				playerData.FitnessActivityMuscles = 0
			end
			--print("stiffness is ".. bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):getStiffness())
			if bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):getStiffness() > 100 then
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_L):setStiffness(100)
			end
			if bodyDamage:getBodyPart(BodyPartType.UpperLeg_L):getStiffness() > 100 then
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_L):setStiffness(100)
			end
			if bodyDamage:getBodyPart(BodyPartType.LowerLeg_R):getStiffness() > 100 then
				bodyDamage:getBodyPart(BodyPartType.LowerLeg_R):setStiffness(100)
			end
			if bodyDamage:getBodyPart(BodyPartType.UpperLeg_R):getStiffness() > 100 then
				bodyDamage:getBodyPart(BodyPartType.UpperLeg_R):setStiffness(100)
			end
			if bodyDamage:getBodyPart(BodyPartType.Torso_Lower):getStiffness() > 100 then
				bodyDamage:getBodyPart(BodyPartType.Torso_Lower):setStiffness(100)
			end
		end

	end
end

Events.EveryHours.Add(LSEveryHour);
