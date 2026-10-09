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

PlayInstrumentTraining = ISBaseTimedAction:derive('PlayInstrumentTraining');

local function getSandboxOption()
	local t = {
		[1] = 0.5,
		[2] = 1,
		[3] = 2,
		[4] = 4,
	}
	return t[SandboxVars.Music.StrengthMultiplier or 2] or 1
end

local function minMult(varMult, value, num)
	local thresholds = {
		[1] = {{0.8, 0.1}, {0.6, 0.8}, {0.4, 0.9}},
		[2] = {{0.6, 0.1}, {0.4, 0.5}, {0.2, 0.9}},
		[3] = {{0.8, 0.01}, {0.6, 0.15}, {0.4, 0.3}, {0.2, 0.5}},
		[4] = {{0.8, 0.02}, {0.7, 0.2}, {0.5, 0.4}, {0.4, 0.6}},
		[5] = {{0.2, 0.02}, {0.3, 0.2}, {0.4, 0.4}, {0.7, 0.6}},
	}
	for _, t in ipairs(thresholds[num]) do
		if num == 5 and value <= t[1] then varMult = math.min(varMult, t[2]) break;
		elseif num ~= 5 and value >= t[1] then varMult = math.min(varMult, t[2]) break end
	end
	return varMult
end

local function checkAmbitions(character, level)
	if level < 10 then return; end
	if LSAmbtMng.hasActive(character, "LSRockstar") and (not LSAmbtMng.hasCompleted(character, "LSRockstar")) then
		character:getModData().Ambitions["LSRockstar"].goal2progress = math.floor(character:getModData().Ambitions["LSRockstar"].goal2progress+1)
	end
end

local function adjustStats(character, musicLevel)

	local moodleData = character:getModData().LSMoodles

	local currentStress = LSUtil.getCharacterMood(character, "Stress")
	local currentExhaustion = LSUtil.getCharacterMood(character, "Endurance")
	local currentFatigue = LSUtil.getCharacterMood(character, "Fatigue")

	--SANDBOX
	local sandboxMult = getSandboxOption()

	--VARIABLES
	local traitBonus = LSAmbtMng.hasActiveCompleted(character, "LSRockstar") and 3 or
	(character:hasTrait(CharacterTrait.VIRTUOSO) or character:hasTrait(CharacterTrait.KEEN_HEARING) or (moodleData["PartyGood"] and moodleData["PartyGood"].Value >= 0.2)) and 1 or 0
	local reverseBuffs = character:hasTrait(CharacterTrait.TONEDEAF) and 1 or 0
	local level = math.max((musicLevel*2)/1.5,0.5)
	local varMult = character:hasTrait(CharacterTrait.HARD_OF_HEARING) and 0.9 or 1
	local args = {currentStress, moodleData["PartyBad"].Value, moodleData["Embarrassed"].Value, currentFatigue, currentExhaustion}

	for n=1, #args do
		if args[n] and args[n] > 0 then
			varMult = minMult(varMult, args[n], n)
		end
	end

	--RESULT
	local varAdd = traitBonus + level + 1
	local varResult = varAdd * varMult * sandboxMult * 0.5

	local moodList = {}
	--ENDURANCE
	moodList["Endurance"] = {-0.003, false, false, false}
	moodList["Fatigue"] = {0.001, false, false, true}
	--BOREDOM 0 - 100
	local boredomChange = (1/varMult)/(sandboxMult+varAdd)
	--SET
	if character:hasTrait(CharacterTrait.TONEDEAF) then
		local stressChange = boredomChange/100
		moodList["Stress"] = {stressChange, false, false, true}
		local unhappynessChange = boredomChange/10
		moodList["Unhappiness"] = {unhappynessChange, unhappynessChange >= 2, false, true}
		boredomChange = boredomChange*2
		varResult = varResult*0.5		
	end
	if not character:hasTrait(CharacterTrait.VIRTUOSO) then moodList["Boredom"] = {boredomChange, false, false, true}; end

	LSUtil.changeCharacterMoodGroup(character, moodList)

	--XP
	if musicLevel < 10 then
		level = math.max(level, 1)
		--print("PlayInstrumentTraining - adjustStats function - level is: "..tostring(level).." and varResult is: "..tostring(varResult));
		local xpChange = math.max(math.floor(varResult*level),0.25)
		--character:getXp():AddXP(Perks.Music, xpChange)
		sendClientCommand(character, "LS", "AddXP", {"Music", xpChange})
	end

	--INVISIBLE
	if character:isInvisible() then character:Say("PLAYER IS INVISIBLE: CAN'T PLAY SOUND"); end
end

local function getSandboxOptionMusicChance()
	local sandboxValue = SandboxVars.Music.LearningChance or 3
	local chance = 0
	if sandboxValue == 1 then chance = -2;
	elseif sandboxValue == 2 then chance = -1;
	elseif sandboxValue == 3 then chance = 0;
	elseif sandboxValue == 4 then chance = 2;
	elseif sandboxValue == 5 then chance = 5;
	end
	return chance
end

function PlayInstrumentTraining:isValid()
	if self.character:getVehicle() or self.character:isSneaking() then return false; end
	return self.instrumentType ~= "Piano" or self.character:isSittingOnFurniture()
end

function PlayInstrumentTraining:waitToStart()
	return false
end

local function getFailState(randomchance)
	return randomchance >= 96
end

local function getRandomChance(character, stress, lvls, baseStress)
	local num1, num2 = baseStress, 100
	if not lvls or stress < 0.2 then return num1, num2; end

	if stress > 0.8 then num1, num2 = lvls[5], lvls[6];
	elseif stress > 0.5 then num1, num2 = lvls[3], lvls[4];
	else num1, num2 = lvls[1], lvls[2];
	end
	return num1, num2
end

local function getStandingAnim(playerLevel, instrument, movingAnim)
	local t = {
		GuitarAcoustic = {3, "Bob_PlayGuitar"},
		GuitarElectricBass = {3, "Bob_PlayGuitar"},
		GuitarElectric = {3, "Bob_PlayGuitar"},
		Violin = {0, "Bob_PlayViolin"}
	}
	if not t[instrument] or playerLevel < t[instrument][1] then return movingAnim; end
	if playerLevel < 6 then return t[instrument][2].."Default_Mov"; end
	local animTypes = {"Default", "Good"}
	local animIdx = ZombRand(#animTypes)+1
	return t[instrument][2]..animTypes[animIdx].."_Mov"
end

local function getNewTargetVal(tiers)
	local target
	local t = {198,201,205,208}
	for n=1, #tiers do
		if tiers[n] and tiers[n] > 0 then target = t[n]; break; end
	end
	return target
end

function PlayInstrumentTraining:boredomHalo()
	if not self.character:hasTrait(CharacterTrait.VIRTUOSO) then HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 200, 200); end
end

local function getRandomSong(lists)
	local song
	for n=1, #lists do
		if lists[n] and #lists[n] > 0 then
			local idx = ZombRand(#lists[n])+1
			song = lists[n][idx]
			break
		end
	end
	return song
end

function PlayInstrumentTraining:resetLearnTables()
	local tables = {
		{"PriorityToLearnLow",2},
		{"PriorityToLearnMid",5},
		{"PriorityToLearnHigh",8},
		{"PriorityToLearnMaster",10},
	}

	for n=1, #tables do
		self[tables[n][1]] = {}
	end
	
	for k,v in pairs(self.instrumentSounds) do
		local newSong
		if v.level <= self.playerLevel and v.isaddon ~= 2 then
			newSong = true
			if #self.learnedTracksData > 0 then
				for i,j in pairs(self.learnedTracksData) do
					if j.isaddon ~= 2 and j.name == v.name then
						newSong = false
						break
					end
				end
			end
		end
		if newSong then
			for n=1, #tables do
				if v.level <= tables[n][2] then table.insert(self[tables[n][1]], v); break; end
			end
		end
	end
end

function PlayInstrumentTraining:learnSong()
	local song = getRandomSong({self.PriorityToLearnLow,self.PriorityToLearnMid,self.PriorityToLearnHigh,self.PriorityToLearnMaster})
	if song and song.name then
		table.insert(self.learnedTracksData,song)
		HaloTextHelper.addGoodText(self.character, getText("IGUI_HaloNote_LearnSong"))
		HaloTextHelper.addGoodText(self.character, getText(song.name))
		getSoundManager():playUISound("PZLevelSound")
		checkAmbitions(self.character, song.level)
		LSSync.updateClientData(self.character, self.character:getModData())
	end
	self.learnedSong = true
	self.learnedOneSong = true
	self["resetLearnTables"](self)
end

function PlayInstrumentTraining:learnMidSong()
	if self.learnedOneSong or self.playerLevel < 2 then return; end
	local song = getRandomSong({self.PriorityToLearnLow,self.PriorityToLearnMid})
	if song and song.name then
		table.insert(self.learnedTracksData,song)
		HaloTextHelper.addGoodText(self.character, getText("IGUI_HaloNote_LearnSong"))
		HaloTextHelper.addGoodText(self.character, getText(song.name))
		getSoundManager():playUISound("PZLevelSound")
		checkAmbitions(self.character, song.level)
		self.learnedOneSong = true
	end
end

function PlayInstrumentTraining:soundPing()
	local soundRadius, volume = 10, 5
	if self.character:isOutside() then soundRadius, volume = 30, 10; end
	addSound(self.character,self.character:getX(),self.character:getY(),self.character:getZ(),soundRadius,volume)
end

function PlayInstrumentTraining:playSong()
	local isPlaying = self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound)
	if isPlaying then return; end
	local randomTrack = self.AvailableInstrumentTracks[ZombRand(#self.AvailableInstrumentTracks)+1]
	local sound = randomTrack.sound
	if self.lastSound and self.lastSound == sound then
		randomTrack = self.AvailableInstrumentTracks[ZombRand(#self.AvailableInstrumentTracks)+1]
		sound = randomTrack.sound
	end
	self.lastSound = sound
	self.gameSound = self.character:getEmitter():playSound(sound)
	self["soundPing"](self)
end

local function getAdjPiece(key)
	local t ={
		-- Western Piano
		recreational_01_8 = {"recreational_01_9","E",0,-0.3},
		recreational_01_9 = {"recreational_01_8","W",0,-0.3},
		recreational_01_12 = {"recreational_01_13","N",-0.25,0},
		recreational_01_13 = {"recreational_01_12","S",-0.25,0},
		recreational_01_28 = {"recreational_01_29","E",0,0.3},
		recreational_01_29 = {"recreational_01_28","W",0,0.3},
		recreational_01_30 = {"recreational_01_31","N",0.5,0},
		recreational_01_31 = {"recreational_01_30","S",0.5,0},
		-- Grand Piano
		recreational_01_40 = {"recreational_01_41","E",0,0},
		recreational_01_41 = {"recreational_01_40","W",0,0},
		recreational_01_48 = {"recreational_01_49","N",-0.1,0},
		recreational_01_49 = {"recreational_01_48","S",-0.1,0},
		recreational_01_108 = {"recreational_01_109","E",0,0},
		recreational_01_109 = {"recreational_01_108","W",0,0},
		recreational_01_99 = {"recreational_01_96","N",0.1,0},
		recreational_01_96 = {"recreational_01_99","S",0.1,0},
	}
	return t[key]
end

local function getAdjObj(mainObj, spriteName, ogSquare)
	local square = mainObj:getSquare()
	if not square or (square and square ~= ogSquare) then return false; end
	local objVars, adjObject = getAdjPiece(spriteName), false
	if objVars then
		local objAdjSqr = square:getAdjacentSquare(IsoDirections[objVars[2]])
		if not objAdjSqr then return false; end
		for i=1,objAdjSqr:getObjects():size() do
			local obj = objAdjSqr:getObjects():get(i-1)
			if obj then
				local objName = obj:getSpriteName() or obj:getTextureName()
				if objName and objName == objVars[1] then adjObject = obj; break; end
			end
		end
	end
	return adjObject
end

function PlayInstrumentTraining:checkObj()
	if self.instrumentType ~= "Piano" and self.instrumentType ~= "Drums" then return; end
	if not self.obj or not instanceof(self.obj, "IsoObject") or not self.objSquare then self.instrument = false; return; end
	local adjObj = getAdjObj(self.obj, self.instrument, self.objSquare)
	if not adjObj then self.instrument = false; return; end
end

function PlayInstrumentTraining:update()
	if self.panicLevel and self.character:getMoodles():getMoodleLevel(MoodleType.PANIC) > self.panicLevel then self.isFailState = true; end
	
	if self.isFailState or not self.instrument or isKeyDown(Keyboard.KEY_E) or self.character:isSneaking() or (not self.character:getPrimaryHandItem() and self.instrumentType ~= "Piano") or #self.AvailableInstrumentTracks == 0 then
		self:forceStop()
	end

	if not self.character:isPlayerMoving() and not self.character:isSitOnGround() and not self.character:getModData().IsSittingOnSeat and not self.character:isSittingOnFurniture() then
		if self.currentAction ~= 3 then
			local anim = getStandingAnim(self.playerLevel, self.instrumentType, self.AnimToplay)
			self:setActionAnim(anim)
			self.currentAction = 3
		end
	elseif self.currentAction ~= 1 then
		self:setActionAnim(self.AnimToplay)
		self.currentAction = 1
	end
	
	self["playSong"](self)

	self.actionCount = self.actionCount + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	if self.actionCount > self.actionTotal then
		self.actionCount = 0
		adjustStats(self.character, self.playerLevel)
		self["soundPing"](self)

		if self.playerLevel < 6 then
			-- stress and level check
			local num1, num2 = getRandomChance(self.character, LSUtil.getCharacterMood(self.character, "Stress"), self.stressLvls, self.baseStress)
			local randomchance = ZombRand(num1, num2)
			self.isFailState = getFailState(randomchance)
			if self.isFailState and not self.failGrace then self.isFailState, self.failGrace = false, true; end
		end

		if not self.isFailState then
			if self.learnedSong then
				self["boredomHalo"](self)
				self.relearnCount = self.relearnCount + 1
				if self.relearnCount >= self.relearnTotal then
					self.relearnCount = 0
					self.learnedSong = false
				end
			elseif self.playerLevel < 2 then
				self["boredomHalo"](self)
			else
				local randomDice = ZombRand(200)+1+self.sandboxAddChance
				local randomDiceTarget = getNewTargetVal({#self.PriorityToLearnLow,#self.PriorityToLearnMid,#self.PriorityToLearnHigh,#self.PriorityToLearnMaster})

				if randomDiceTarget and (randomDice >= randomDiceTarget-self.baseLearnChance) then
					self["learnSong"](self)
				else
					self["boredomHalo"](self)
				end
			end
		end
		self["checkObj"](self)
	end

	if self.doMetabolics then self.character:setMetabolicTarget(Metabolics.UsingTools); end
end

local function getInstrumentParams(instrument)
	local t = {
		Trumpet = {"PlayTrumpetTracks","TrumpetLearnedTracks"},
		GuitarAcoustic = {"PlayGuitarAcousticTracks","GuitarALearnedTracks"},
		Banjo = {"PlayBanjoTracks","BanjoLearnedTracks"},
		Keytar = {"PlayKeytarTracks","KeytarLearnedTracks"},
		Saxophone = {"PlaySaxophoneTracks","SaxophoneLearnedTracks"},
		GuitarElectricBass = {"PlayGuitarElectricBassTracks","GuitarEBLearnedTracks"},
		GuitarElectric = {"PlayGuitarElectricTracks","GuitarELearnedTracks"},
		Flute = {"PlayFluteTracks","FluteLearnedTracks"},
		Harmonica = {"PlayHarmonicaTracks","HarmonicaLearnedTracks"},
		Violin = {"PlayViolinTracks","ViolinLearnedTracks"},
		Piano = {"PlayPianoTracks","PianoLearnedTracks"},
	}
	return t[instrument][1], t[instrument][2]
end

local function getPropItem(itemName)
	local prop
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and item:getFullName() and item:getFullName() == itemName then
			local itemInstance = item:InstanceItem(item:getFullName())
			prop = itemInstance:getWorldStaticItem()
			break
        end
    end
	return prop
end

local function getFailChanceArgs(character)
	local baseStress, lvls = 1, {11, 100, 21, 100, 31, 100}
	if character:hasTrait(CharacterTrait.CLUMSY) then baseStress = 16; end
	if character:hasTrait(CharacterTrait.DISCIPLINED) then return baseStress, false; end

	if character:hasTrait(CharacterTrait.DEXTROUS) then
		lvls = {6, 100, 14, 100, 22, 100}
	elseif character:hasTrait(CharacterTrait.CLUMSY) then
		lvls = {24, 100, 36, 100, 48, 100}
	end

	return baseStress, lvls
end

function PlayInstrumentTraining:adjustPlayerPosition()
	-- workaround for piano positioning
	if LSUtil.pianoPos then return; end
	--if self.ogPos then self.character:setX(self.ogPos[1]); self.character:setY(self.ogPos[2]); return; end
	local vars = getAdjPiece(self.instrument)
	if not vars or not vars[3] or not vars[4] then return; end
	--local sqr = self.character:getSquare()
	local x, y = self.character:getX(),self.character:getY()
	--self.ogPos = {x,y}
	self.character:setX(x+vars[3]); self.character:setY(y+vars[4])
	LSUtil.pianoPos = true
end

function PlayInstrumentTraining:pianoParams()
	self.stopOnWalk = true
	self.stopOnAim = true
	self:setOverrideHandModels(nil, nil)
	self["adjustPlayerPosition"](self)
end

function PlayInstrumentTraining:instrumentParams()
	if self.instrumentType == "Piano" then
		self["pianoParams"](self)
	elseif self.instrumentType == "Violin" then
		local prop = getPropItem("Lifestyle.violinBow")
		self:setOverrideHandModels(prop, self.instrument)
	elseif self.instrumentType == "Harmonica" and self.instrument:getFullType() ~= "Lifestyle.Harmonica" then
		self:setOverrideHandModels("Lifestyle.Harmonica", nil)
	else
		self:setOverrideHandModels(self.instrument, nil)
	end
end

local function isValidAnim(pLvl, sitting, aLvl, aSit)
	if pLvl < aLvl then return false; end
	if aSit and ((sitting and aSit ~= 1) or (not sitting and aSit ~= 0)) then return false; end
	if pLvl >= 4 and aLvl < pLvl-3 then return false; end
	return true
end

function PlayInstrumentTraining:animParams()
	local t = {}
	local isSitting = self.character:isSitOnGround()
	for k,v in pairs(LSMusic.anims) do
		if v.instrument == self.instrumentType and isValidAnim(self.playerLevel, isSitting, v.level, v.isSit) then
			table.insert(t, v)
		end
	end
	local idxAnim = ZombRand(#t)+1
	self.AnimToplay = t[idxAnim].name
end

function PlayInstrumentTraining:musicParams()
	--music played during training
	--attempts to play learned tracks only
	--if not enough learned tracks then plays the low level songs designed for training
	local temp = {}
	if self.playerLevel > 1 and self.learnedTracksData and #self.learnedTracksData > 0 then
		for k,v in pairs(self.learnedTracksData) do
			if v.level <= self.playerLevel then
				if v.level+4 >= self.playerLevel then -- filter
					table.insert(self.AvailableInstrumentTracks, v)
				else
					table.insert(temp, v)
				end
			end
		end
		if #self.AvailableInstrumentTracks < 5 and #temp > 0 then -- add excluded if not enough tracks found
			for n=1,#temp do
				table.insert(self.AvailableInstrumentTracks, temp[n])
			end
		end
	end
	if #self.AvailableInstrumentTracks < 5 then
		for k,v in pairs(self.instrumentSounds) do
			if v.level <= self.playerLevel and v.isaddon and v.isaddon == 2 then
				table.insert(self.AvailableInstrumentTracks, v)
			end
		end
	end
end

local function playGuitarSFX(character, instrument, soundName, num)
	if instrument ~= "GuitarElectric" and instrument ~= "GuitarElectricBass" then return; end
	local sfx = soundName..tostring(ZombRand(num)+1)
	character:getEmitter():playSound(sfx)
end

function PlayInstrumentTraining:start()
	self.sandboxAddChance = getSandboxOptionMusicChance()
	self["instrumentParams"](self)
	
	self.character:getModData().PlayingInstrument = true

	getSoundManager():setMusicVolume(0)

	self.action:setUseProgressBar(true)
	
	self["animParams"](self)

	local fileName, instrumentData = getInstrumentParams(self.instrumentType)
	if self.instrumentType == "Piano" then -- temporary fix until everything else is moved to instruments folder
		self.instrumentSounds = require("Instruments/Tracks/"..fileName)
	else
		self.instrumentSounds = require("TimedActions/"..fileName)
	end
	
	if not self.character:getModData()[instrumentData] then self.character:getModData()[instrumentData] = {}; end
	self.learnedTracksData = self.character:getModData()[instrumentData]

	self["musicParams"](self)

	if self.playerLevel >= 2 then
		self["resetLearnTables"](self)
	end

	-- panic check
	if not self.character:hasTrait(CharacterTrait.DESENSITIZED) then
		if self.character:hasTrait(CharacterTrait.BRAVE) or self.character:hasTrait(CharacterTrait.DISCIPLINED) then
			self.panicLevel = 3
		else
			self.panicLevel = 2
		end
	end
	self.baseStress, self.stressLvls = getFailChanceArgs(self.character)

	playGuitarSFX(self.character, self.instrumentType, "Guitar_pickup", 4)
end

function PlayInstrumentTraining:stop()

	local characterData = self.character:getModData()
	characterData.PlayingInstrument = false

	if self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound) then self.character:getEmitter():stopSound(self.gameSound); end

	if self.isFailState then
		local failsound = self.instrumentType.."Failstate0"..tostring(ZombRand(3)+1)
		self.character:getEmitter():playSound(failsound);
		self["soundPing"](self)
		if characterData.LSMoodles["Embarrassed"].Value then
			characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.1
		end
		HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)
	end

	if characterData.IsSittingOnSeat then
		if characterData.IsSittingOnSeatSouth then
			self.character:setVariable("SittingToggleLoop", "S")
			self.character:setVariable("IsSittingInChair", "IsSittingS")
		else
			self.character:setVariable("SittingToggleLoop", "N")
			self.character:setVariable("IsSittingInChair", "IsSitting")
		end
	end

	playGuitarSFX(self.character, self.instrumentType, "Guitar_stop", 3)

	getSoundManager():setMusicVolume(self.musicOriginalVolume)

	LSSync.updateClientData(self.character, characterData)
	ISBaseTimedAction.stop(self);
end

function PlayInstrumentTraining:perform()

	self["learnMidSong"](self)

	if self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound) then self.character:getEmitter():stopSound(self.gameSound); end

	adjustStats(self.character, self.playerLevel)

	local characterData = self.character:getModData()
	characterData.PlayingInstrument = false

	if characterData.IsSittingOnSeat then
		if characterData.IsSittingOnSeatSouth then
			self.character:setVariable("SittingToggleLoop", "S")
			self.character:setVariable("IsSittingInChair", "IsSittingS")
		else
			self.character:setVariable("SittingToggleLoop", "N")
			self.character:setVariable("IsSittingInChair", "IsSitting")
		end
	end

	playGuitarSFX(self.character, self.instrumentType, "Guitar_stop", 3)

	getSoundManager():setMusicVolume(self.musicOriginalVolume)

	LSSync.updateClientData(self.character, characterData)
    ISBaseTimedAction.perform(self);
end

local function isMetabolicsEnabled(option)
	local t = {
		[1] = true,
		[2] = true,
		[3] = false,
	}
	return t[option]
end

function PlayInstrumentTraining:complete()

	return true
end

function PlayInstrumentTraining:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 9000
end

function PlayInstrumentTraining:new(character, instrument, instrumentType, obj) -- Item must be SPRITENAME for piano and drums, Object is used for piano and drums
    local o = {}
	local level = character:getPerkLevel(Perks.Music)
	local trait = 0
	if character:hasTrait(CharacterTrait.VIRTUOSO) then trait = 1; end
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.instrument = instrument;
	o.obj = obj
	o.objSquare = obj and obj:getSquare()
    o.stopOnWalk = instrumentType == "Piano";
    o.stopOnRun = true;
    o.stopOnAim = instrumentType == "Piano";
	o.ignoreDynamicTime = true;
	o.maxTime = o:getDuration()
	o.instrumentType = instrumentType
	o.instrumentSounds = false
	o.AnimToplay = 0
	o.gameSound = 0
	o.musicOriginalVolume = tonumber(getSoundManager():getMusicVolume())
	o.actionCount = 0
	o.actionTotal = 60--300
	o.AvailableInstrumentTracks = {}
	o.PriorityToLearnLow = {}
	o.PriorityToLearnMid = {}
	o.PriorityToLearnHigh = {}
	o.PriorityToLearnMaster = {}
	o.songDifficulty = false
	o.noKnownSongs = false
	o.lastSound = false
	o.learnedSong = true
	o.learnedOneSong = false
	o.handItem = false
	o.learnedTracksData = false
	o.relearnCount = 0
	o.relearnTotal = 5
	o.sandboxAddChance = 0
	o.currentAction = 0
	o.panicLevel = false
	o.isFailState = false
	o.playerLevel = level
	o.stressLvls = false
	o.baseStress = 1
	o.baseLearnChance = level+trait
	o.doMetabolics = isMetabolicsEnabled(SandboxVars.Music.Metabolics or 1)
    return o;
end