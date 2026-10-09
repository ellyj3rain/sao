-- SAO-owned player DJ action. Selected Lifestyle source and terms remain in SAOSources.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

LS_DJBooth = LS_DJBooth or {}

require "TimedActions/ISBaseTimedAction"

PlayDJBoothAction = ISBaseTimedAction:derive('PlayDJBoothAction');
local MusicDoTextHelperUnhappyness = 0
local MusicDoTextHelperBoredom = 0
local activePlayerAction
local headphoneTypes = {
    Hat_EarMuff_Protectors=true, Hat_EarMuff_Protectors_Neck=true,
    Hat_EarMuff_Protectors_AZ=true, Authentic_Headphones=true,
    Authentic_Headphones2=true, Authentic_Headphones3=true,
    Authentic_Headphones4=true, Authentic_HeadphonesNeck=true,
    Authentic_HeadphonesNeck2=true, Authentic_HeadphonesNeck3=true,
    Authentic_HeadphonesNeck4=true,
}

local function nameOf(object)
    local sprite=object and object:getSprite()
    local properties=sprite and sprite:getProperties()
    if not properties or not properties:has("CustomName")
        or properties:get("CustomName")~="Booth" then return nil end
    return sprite:getName()
end

local function contains(square,object)
    local objects=square and square:getObjects()
    if not objects then return false end
    for i=0,objects:size()-1 do
        if objects:get(i)==object then return true end
    end
    return false
end

local function partsAt(booth)
    local square=booth and booth:getSquare()
    local name=nameOf(booth)
    if not square or not contains(square,booth)
        or (name~="ls_djbooth_01_1" and name~="ls_djbooth_01_4") then return nil,nil end
    local cell=getCell()
    if not cell then return nil,nil end
    local left,right
    for x=booth:getX()-1,booth:getX()+1 do
        for y=booth:getY()-1,booth:getY()+1 do
            local nearby=cell:getGridSquare(x,y,booth:getZ())
            local objects=nearby and nearby:getObjects()
            if objects then
                for i=0,objects:size()-1 do
                    local object=objects:get(i)
                    local side=nameOf(object)
                    if side=="ls_djbooth_01_0" or side=="ls_djbooth_01_3" then left=left or object end
                    if side=="ls_djbooth_01_2" or side=="ls_djbooth_01_5" then right=right or object end
                end
            end
        end
    end
    return left,right
end

local function partStillAt(booth,part,left)
    if not part or part==booth then return false end
    local name=nameOf(part)
    if left and name~="ls_djbooth_01_0" and name~="ls_djbooth_01_3" then return false end
    if not left and name~="ls_djbooth_01_2" and name~="ls_djbooth_01_5" then return false end
    local square=part:getSquare()
    return square and contains(square,part)
        and part:getZ()==booth:getZ()
        and math.abs(part:getX()-booth:getX())<=1
        and math.abs(part:getY()-booth:getY())<=1
end

local function frontOf(booth)
    local square=booth and booth:getSquare()
    local sprite=booth and booth:getSprite()
    local properties=sprite and sprite:getProperties()
    local facing=properties and properties:has("Facing") and properties:get("Facing")
    if not square then return nil end
    if facing=="S" then return square:getS() end
    if facing=="E" then return square:getE() end
    if facing=="W" then return square:getW() end
    if facing=="N" then return square:getN() end
end

local function powered(square)
    local cutoff=SandboxVars and SandboxVars.ElecShutModifier
    return square and ((type(cutoff)=="number" and cutoff>-1
        and GameTime:getInstance():getNightsSurvived()<cutoff)
        or square:haveElectricity())
end

local function headphonesOn(character)
    local inventory=character:getInventory()
    local items=inventory and inventory:getItems()
    if not items then return false end
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item and headphoneTypes[item:getType()] and character:isEquippedClothing(item) then
            return true
        end
    end
    return false
end

local function selectedTrack(mode,sound)
    local tracks=require("TimedActions/PlayDJBoothTracks")
    for _,track in ipairs(tracks or {}) do
        if track.mode==mode and track.sound==sound and type(track.length)=="number"
            and track.length>0 then return track.length end
    end
end

local function playerOwns(action)
    local player=action.character
    if not player or action.saoOwner~="SAO.PlayerDJ"
        or action.Type~="PlayDJBoothAction" then return false end
    local index=player:getPlayerNum()
    return type(index)=="number" and action.playerIndex==index
        and getSpecificPlayer(index)==player
        and not player:isDead() and not player:isAsleep()
        and player:isExistInTheWorld()
        and not player:getVehicle() and not player:isSitOnGround()
        and not player:isSneaking() and not player:hasTrait(CharacterTrait.DEAF)
end

local function exactQueueOwner(action)
    local menu=DJBoothMenu
    return menu and type(menu.playerQueueOwner)=="function"
        and menu.playerQueueOwner(action.DJBooth,action)==true
end

local function npcOwns(booth)
    local leisure=SAO and SAO.LeisureLifestyle
    return leisure and type(leisure.physicalSourceOwner)=="function"
        and leisure.physicalSourceOwner(booth)==true
end

local function adjustStats(character)

	local characterData = character:getModData()
	local PlayerMusicLevel = character:getPerkLevel(Perks.Music)

	local currentStress = LSUtil.getCharacterMood(character, "Stress")
	local currentExhaustion = LSUtil.getCharacterMood(character, "Endurance")
	local currentFatigue = LSUtil.getCharacterMood(character, "Fatigue")

	--SANDBOX
	local StrengthMultiplier = 1
	if SandboxVars.Music.StrengthMultiplier ~= nil then
		if SandboxVars.Music.StrengthMultiplier == 1 then
			StrengthMultiplier = 0.5
		elseif SandboxVars.Music.StrengthMultiplier == 2 then
			StrengthMultiplier = 1
		elseif SandboxVars.Music.StrengthMultiplier == 3 then
			StrengthMultiplier = 2
		elseif SandboxVars.Music.StrengthMultiplier == 4 then
			StrengthMultiplier = 4
		end
	end

	--VARIABLES
	local Audience = 0
	local Trait = 0
	local Level = 0
	local varMult = 1
	local reverseBuffs = 0
	--TRAIT
	if character:hasTrait(CharacterTrait.VIRTUOSO) then
		Trait = 2
	elseif character:hasTrait(CharacterTrait.KEEN_HEARING) then
		Trait = 1
	elseif character:hasTrait(CharacterTrait.HARD_OF_HEARING) then
		if varMult > 0.9 then
		varMult = 0.9
		end
	elseif character:hasTrait(CharacterTrait.TONEDEAF) then
		reverseBuffs = 1
	end
	--LEVEL
	Level = ((tonumber(PlayerMusicLevel))/2)

	--AUDIENCE
	if (characterData.LSMoodles["DJAudience"].Value == 0.6) then
		Audience = 4
	elseif (characterData.LSMoodles["DJAudience"].Value == 0.4) then
		Audience = 3
	elseif (characterData.LSMoodles["DJAudience"].Value == 0.2) then
		Audience = 2
	end

	--STRESS
	if currentStress >= 0.8 then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["PartyGood"].Value == 0.4) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["PartyGood"].Value == 0.2) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["PartyBad"].Value == 0.6) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif characterData.LSMoodles["PartyBad"].Value == 0.4 then
		if varMult > 0.15 then
		varMult = 0.15
		end
	elseif characterData.LSMoodles["PartyBad"].Value == 0.2 then
		if varMult > 0.3 then
		varMult = 0.3
		end
	end

	--EMBARRASSED
	if (characterData.LSMoodles["Embarrassed"].Value == 0.8) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["Embarrassed"].Value == 0.6) then
		if varMult > 0.15 then
		varMult = 0.15
		end
	elseif characterData.LSMoodles["Embarrassed"].Value == 0.4 then
		if varMult > 0.3 then
		varMult = 0.3
		end
	elseif characterData.LSMoodles["Embarrassed"].Value == 0.2 then
		if varMult > 0.5 then
		varMult = 0.5
		end
	end

	--FATIGUE
	if currentFatigue >= 0.8 then
		if varMult > 0.02 then
		varMult = 0.02
		end
	elseif currentFatigue >= 0.7 then
		if varMult > 0.2 then
		varMult = 0.2
		end
	elseif currentFatigue >= 0.5 then
		if varMult > 0.4 then
		varMult = 0.4
		end
	elseif currentFatigue >= 0.4 then
		if varMult > 0.6 then
		varMult = 0.6
		end
	end

	--EXHAUSTION
	if currentExhaustion <= 0.2 then
		if varMult > 0.02 then
		varMult = 0.02
		end
	elseif currentExhaustion <= 0.3 then
		if varMult > 0.2 then
		varMult = 0.2
		end
	elseif currentExhaustion <= 0.4 then
		if varMult > 0.4 then
		varMult = 0.4
		end
	elseif currentExhaustion <= 0.7 then
		if varMult > 0.6 then
		varMult = 0.6
		end
	end

	--RESULT
	local varAdd = Trait + Level + Audience + 1
	local varAddRev = Trait + Level + StrengthMultiplier + 1
	local varResult = varAdd * varMult * StrengthMultiplier
	
	if reverseBuffs == 1 then
		if varAddRev >= 6  then
			varAddRev = 5.9
		end
		varResult = (6 - varAddRev)/varMult
	end
	
	--DEFINES
	local moodList = {}
	--ENDURANCE
	moodList["Endurance"] = {-0.003, false, false, false}
	moodList["Fatigue"] = {0.001, false, false, true}
	--BOREDOM 0 - 100
	local boredomChange = 1 * varResult
	--STRESS 0 - 1
	local stressChange = 0.005 * varResult
	--UNHAPPYNESS 0 - 100
	local unhappynessChange = 0.5 * varResult

	--SET
	if reverseBuffs == 1 then
		varResult = varAdd * varMult * StrengthMultiplier * 0.5-- FOR XP
	else
		boredomChange, stressChange, unhappynessChange = -(boredomChange), -(stressChange), -(unhappynessChange)
	end

	moodList["Boredom"] = {boredomChange, boredomChange >= 5, false, true}
	moodList["Stress"] = {stressChange, stressChange >= 0.05, false, true}
	moodList["Unhappiness"] = {unhappynessChange, unhappynessChange >= 2 or unhappynessChange <= -2, false, true}
	
	LSUtil.changeCharacterMoodGroup(character, moodList)
	
	--XP
	local xpChange = varResult
	if PlayerMusicLevel == 10 then
		xpChange = 0
	end
	--character:getXp():AddXP(Perks.Music, xpChange)
	sendClientCommand(character, "LS", "AddXP", {"Music", xpChange})
	--HALOTEXT
--[[
	if boredomChange >= 10 then
		MusicDoTextHelperBoredom = 3
	elseif boredomChange >= 5 then
		MusicDoTextHelperBoredom = 2
	elseif boredomChange >= 1 then
		MusicDoTextHelperBoredom = 1
	end

	if unhappynessChange >= 5 then
		MusicDoTextHelperUnhappyness = 2
	elseif unhappynessChange >= 1 then
		MusicDoTextHelperUnhappyness = 1
	end
]]--
end

function PlayDJBoothAction:isValid()
    if self.saoEnded or not SAO.SourceIntegration.active("LifestyleHobbies")
        or not playerOwns(self) or not exactQueueOwner(self) then return false end
    local booth=self.DJBooth
    if not booth or booth:getSquare()~=self.stationSquare
        or nameOf(booth)~=self.stationSprite
        or not contains(self.stationSquare,booth)
        or not partStillAt(booth,self.leftPart,true)
        or not partStillAt(booth,self.rightPart,false)
        or not self.frontSquare or frontOf(booth)~=self.frontSquare
        or self.character:getSquare()~=self.frontSquare
        or not powered(self.stationSquare) or not headphonesOn(self.character)
        or npcOwns(booth) then return false end
    if self.saoStarted then
        return activePlayerAction==self and LS_DJBooth.isPlaying==true
            and LS_DJBooth.isPlayingMic~=true
    end
    if activePlayerAction or LS_DJBooth.isPlaying==true or LS_DJBooth.isPlayingMic==true
        or not self.sourceLength
        or selectedTrack(self.sourceMode,self.sourceSound)~=self.sourceLength
        or self.mode~=self.sourceMode or self.soundFile~=self.sourceSound then return false end
    local level=self.character:getPerkLevel(Perks.Music)
    if self.mode=="medium" and level<3 or self.mode=="fast" and level<6 then return false end
    local mood=self.character:getModData().LSMoodles
    local embarrassed=mood and mood.Embarrassed and mood.Embarrassed.Value
    return type(embarrassed)~="number" or embarrassed<0.2
end

function PlayDJBoothAction:isValidStart()
    return self:isValid()
end

function PlayDJBoothAction:waitToStart()
    if not self:isValid() then return false end
	self.character:faceThisObject(self.DJBooth);
	return self.character:shouldBeTurning();
end

function PlayDJBoothAction:update()

    if not self.saoStarted or not self:isValid() then
        self:forceStop()
        return
    end

	local characterData = self.character:getModData()
	local playerlevel = self.character:getPerkLevel(Perks.Music)	

	self.countstart = self.countstart + 1
	self.keyDelayStart = self.keyDelayStart + 1
	
	if isKeyDown(Keyboard.KEY_E) or isKeyDown(Keyboard.KEY_C)
        or isKeyDown(Keyboard.KEY_A) or isKeyDown(Keyboard.KEY_S)
        or isKeyDown(Keyboard.KEY_W) or isKeyDown(Keyboard.KEY_D)
        or self.character:isSneaking() then
		self:forceStop()
        return
	end

	if self.Failstate == false then
			if self.keyPause == false then
				if isKeyDown(Keyboard.KEY_UP) or LS_DJBooth.keyUP then
					self.keyPause = true
					LS_DJBooth.keyUP = false
					if self.gameSound and
						self.gameSound ~= 0 and
						self.character:getEmitter():isPlaying(self.gameSound) then
						self.character:getEmitter():stopSound(self.gameSound);
					end
					if self.mode == "housemix" then
						self.mode = "slow"
						LS_DJBooth.speed = 1
					elseif self.mode == "slow" and playerlevel >= 3 then
						self.mode = "medium"
						LS_DJBooth.speed = 2
					elseif self.mode == "medium" and playerlevel >= 6 then
						self.mode = "fast"
						LS_DJBooth.speed = 3
					end----mode
					getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				elseif isKeyDown(Keyboard.KEY_DOWN) or LS_DJBooth.keyDOWN then
					self.keyPause = true
					LS_DJBooth.keyDOWN = false
					if self.gameSound and
						self.gameSound ~= 0 and
						self.character:getEmitter():isPlaying(self.gameSound) then
						self.character:getEmitter():stopSound(self.gameSound);
					end
					if self.mode == "fast" then
						self.mode = "medium"
						LS_DJBooth.speed = 2
					elseif self.mode == "medium" then
						self.mode = "slow"
						LS_DJBooth.speed = 1
					elseif self.mode == "slow" and self.housemix == 1 then
						self.mode = "housemix"
						LS_DJBooth.speed = 4
					end----mode
					getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				elseif isKeyDown(Keyboard.KEY_RIGHT) or isKeyDown(Keyboard.KEY_LEFT) or LS_DJBooth.keyLEFTRIGHT then
					self.keyPause = true
					LS_DJBooth.keyLEFTRIGHT = false
					if self.gameSound and
						self.gameSound ~= 0 and
						self.character:getEmitter():isPlaying(self.gameSound) then
						self.character:getEmitter():stopSound(self.gameSound);
					getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)	
					end
				end----keyDown
				else
				LS_DJBooth.keyUP = false
				LS_DJBooth.keyDOWN = false
				LS_DJBooth.keyLEFTRIGHT = false
			end----KeyPause
	end---CHANGE MODE OR SONG
	

	
	-- panic check
	if not self.character:hasTrait(CharacterTrait.DESENSITIZED) then
		if self.character:hasTrait(CharacterTrait.BRAVE) or self.character:hasTrait(CharacterTrait.DISCIPLINED) then
			if self.character:getMoodles():getMoodleLevel(MoodleType.PANIC) > 3 then
				self:forceStop()
                return
			end
		elseif self.character:getMoodles():getMoodleLevel(MoodleType.PANIC) > 2 then
				self:forceStop()
                return
		end
	end

	local isPlaying = self.gameSound
		and self.gameSound ~= 0
		and self.character:getEmitter():isPlaying(self.gameSound)
		-- update at every 0.05 delta milestone

	if self.countstart >= self.countend then
	self.countstart = 0
	
	if self.Failstate == true then
	
	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end
			
	end
	
	if not isPlaying or self.Failstate then
		--print("TRYING NEW DJ SONG")
		-- Some examples of radius and volume found in PZ code:
		-- Fishing (20,1)
		-- Remove Grass (10,5)
		-- Remove Glass (20,1)
		-- Destroy Stuff (20,10)
		-- Remove Bush (20,10)
		-- Move Sprite (10,5)
		local soundRadius = 30
		local volume = 5
		
		if self.character:isOutside() then
		soundRadius = 75
		volume = 10
		end

		
		
			if self.Failstate == true then
			LS_DJBooth.keyPress(41)
			getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				local soundrandomiser = ZombRand(1, 100)
	
				if soundrandomiser >= 67 then
					self.audio = "dj_booth_fail1"
				elseif soundrandomiser >=33 then
					self.audio = "dj_booth_fail2"
				else
					self.audio = "dj_booth_fail3"
				end
				self.AnimToplay = "Bob_PlayDJFail1"
				self:setActionAnim(self.AnimToplay)
				
				if characterData.LSMoodles["Embarrassed"].Value ~= nil then
					characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.25
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 75, 75)
				end
			
			elseif self.djboothloop == true then
				if self.keyPause == false then
				getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				end
				if self.mode == "slow" then
				
				local randomSlowNumber = ZombRand(#self.AvailableSlowTracks) + 1
				local randomSlowTrack = self.AvailableSlowTracks[randomSlowNumber]
	
				self.audio = tostring(randomSlowTrack.sound)
				
				elseif self.mode == "medium" then
				
				local randomMediumNumber = ZombRand(#self.AvailableMediumTracks) + 1
				local randomMediumTrack = self.AvailableMediumTracks[randomMediumNumber]
	
				self.audio = tostring(randomMediumTrack.sound)
				
				elseif self.mode == "fast" then
				
				local randomFastNumber = ZombRand(#self.AvailableFastTracks) + 1
				local randomFastTrack = self.AvailableFastTracks[randomFastNumber]
	
				self.audio = tostring(randomFastTrack.sound)
				--print("song chosen is" .. tostring(randomFastTrack.sound))
				
				elseif self.mode == "housemix" then
				
				local randomHouseMixNumber = ZombRand(#self.AvailableHouseMixTracks) + 1
				local randomHouseMixTrack = self.AvailableHouseMixTracks[randomHouseMixNumber]
	
				self.audio = tostring(randomHouseMixTrack.sound)
				--print("song chosen is" .. tostring(randomHouseMixTrack.sound))
				
				
				end
			else
			
			self.audio = self.soundFile
			
			end

		self.gameSound = self.character:getEmitter():playSound(self.audio);
		
		addSound(self.character,
				 self.character:getX(),
				 self.character:getY(),
				 self.character:getZ(),
				 soundRadius,
				 volume)
		
		
	self.djboothloop = true
	end
	
	
	if self.Failstate == false then
	if playerlevel <= 5 then

	-- stressCheck
	local randomchance = ZombRand(1, 200)
	if not self.character:hasTrait(CharacterTrait.DISCIPLINED) then
		local stressLevel = LSUtil.getCharacterMood(self.character, "Stress")
		if self.character:hasTrait(CharacterTrait.DEXTROUS) then
			if stressLevel > 0.8 then
					randomchance = ZombRand(22, 200)
			elseif stressLevel > 0.5 then
					randomchance = ZombRand(14, 200)
			elseif stressLevel > 0.2 then
					randomchance = ZombRand(6, 200)
			else
					randomchance = ZombRand(1, 200)
			end
		elseif self.character:hasTrait(CharacterTrait.CLUMSY) then
				if stressLevel > 0.8 then
				randomchance = ZombRand(48, 200)
				elseif stressLevel > 0.5 then
					randomchance = ZombRand(36, 200)
				elseif stressLevel > 0.2 then
					randomchance = ZombRand(24, 200)
				else
					randomchance = ZombRand(16, 100)
				end
		elseif stressLevel > 0.8 then
				randomchance = ZombRand(31, 200)
		elseif stressLevel > 0.5 then
				randomchance = ZombRand(21, 200)
		elseif stressLevel > 0.2 then
				randomchance = ZombRand(11, 200)
		else
				randomchance = ZombRand(1, 200)
		end
	elseif self.character:hasTrait(CharacterTrait.CLUMSY) then
	randomchance = ZombRand(16, 200)
	else
	randomchance = ZombRand(1, 200)
	end
		
			if randomchance >= 198 then
			self.Failstate = true
			end
	
	end
	
	end
	
	end

	self.actionCount = self.actionCount + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	if self.actionCount > self.actionTotal then
		self.actionCount = 0
        local ok,reason=pcall(adjustStats,self.character)
        if not ok then
            self.saoSourceError=tostring(reason)
            self:forceStop()
            return
        end
		
		local soundRadius = 20
		local volume = 5
		
		if self.character:isOutside() then
		soundRadius = 60
		volume = 10
		end

		-- update for zombies as the character moves

		addSound(self.character,
				 self.character:getX(),
				 self.character:getY(),
				 self.character:getZ(),
				 soundRadius,
				 volume)
	
		local HappyOrBored = ZombRand(2)+1
		if self.Failstate == false and self.character:hasTrait(CharacterTrait.TONEDEAF) then
			if HappyOrBored == 1 then 
				if MusicDoTextHelperUnhappyness == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), false, 255, 75, 75)
				elseif MusicDoTextHelperUnhappyness == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), false, 255, 120, 120)
				end
			elseif HappyOrBored == 2 then
				if MusicDoTextHelperBoredom == 3 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 30, 30)
				elseif MusicDoTextHelperBoredom == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 75, 75)
				elseif MusicDoTextHelperBoredom == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 120, 120)
				end
			end
			MusicDoTextHelperUnhappyness = 0
			MusicDoTextHelperBoredom = 0
		elseif self.Failstate == false then
			if HappyOrBored == 1 then 
				if MusicDoTextHelperUnhappyness == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 70, 255, 50)
				elseif MusicDoTextHelperUnhappyness == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 170, 255, 150)
				end
			elseif HappyOrBored == 2 then
				if MusicDoTextHelperBoredom == 3 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 70, 255, 50)
				elseif MusicDoTextHelperBoredom == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 170, 255, 150)
				elseif MusicDoTextHelperBoredom == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 200, 255, 200)
				end
			end
			MusicDoTextHelperUnhappyness = 0
			MusicDoTextHelperBoredom = 0
		end
	
	--self:resetJobDelta()
	end

	if self.keyDelayStart >= self.keyDelayEnd then
	self.keyDelayStart = 0
	self.keyPause = false
	end

	if not LS_DJBooth.failstate and self.AnimToplay ~= "Bob_PlayDJFail1" then--change animations while not in a fail state
		self.AnimDelayStart = self.AnimDelayStart + 1
	
		if self.AnimDelayStart >= self.AnimDelayEnd then
			self.AnimDelayStart = 0
			
			self.idxDJAnim = ZombRand(#self.DJAnim) + 1
			self.AnimToplay = self.DJAnim[self.idxDJAnim]
			if self.pastAnim ~= 0 and self.pastAnim == self.AnimToplay then--not repeat animations in sequence
			local variation = ZombRand(2) + 1--will pick a number between 0 and (target number - 1)
				if self.idxDJAnim == 3 then--last anim
					self.AnimToplay = self.DJAnim[self.idxDJAnim - variation]
				elseif self.idxDJAnim == 1 then--first anim
					self.AnimToplay = self.DJAnim[self.idxDJAnim + variation]
				else
					if variation == 1 then
						self.AnimToplay = self.DJAnim[self.idxDJAnim - 1]
					elseif variation == 2 then
						self.AnimToplay = self.DJAnim[self.idxDJAnim + 1]
					end
				end
			end
			self:setActionAnim(self.AnimToplay)
			self.pastAnim = self.AnimToplay
	
		end
	end

	if (self.audio == "dj_booth_fail1") or (self.audio == "dj_booth_fail2") or (self.audio == "dj_booth_fail3") then
		self.Failstate = false
		self.keyPause = true
		LS_DJBooth.failstate = true
		self.AnimDelayStart = 0
	else
		if self.AnimToplay == "Bob_PlayDJFail1" then
			self.AnimToplay = "Bob_PlayDJDefault"
			self:setActionAnim(self.AnimToplay)
		end
		LS_DJBooth.failstate = false
		if characterData.LSMoodles["Embarrassed"].Value ~= nil and characterData.LSMoodles["Embarrassed"].Value >= 0.6 then
			self:forceStop()
            return
		end
	end
end

local function sourceStart(self)
	
	--local properties = self.DJBooth:getSprite():getProperties()
	--local facing = nil
	--if properties:has("Facing") then
	--	facing = properties:get("Facing")
	--end
	--if facing == "W" then
	--	self.DJAnim = {"Bob_PlayDJScratchCDFlipped","Bob_PlayDJMixFlipped","Bob_PlayDJVibeFlipped"};
	--	self.AnimToplay = "Bob_PlayDJDefaultFlipped"
	--end
	
	--self.character:setLy(self.character:getY())
	--self.character:setLx(self.character:getX())
	self.character:setY(self.character:getY())
	self.character:setX(self.character:getX())

	getSoundManager():setMusicVolume(0)
	
	self.character:getEmitter():playSound("dj_booth_turnon")
	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 5)

	self:setActionAnim(self.AnimToplay)

	--self.character:SetVariable("LootPosition", "Mid")

	self:setOverrideHandModels(nil, nil)
	local PlayDJBoothTracks = require("TimedActions/PlayDJBoothTracks")
				for _,v in ipairs(PlayDJBoothTracks) do
                    if type(v.sound)=="string" and type(v.length)=="number" and v.length>0 then
					if v.mode == "slow" then
						table.insert(self.AvailableSlowTracks, v)
					elseif v.mode == "medium" then
						table.insert(self.AvailableMediumTracks, v)
					elseif v.mode == "fast" then
						table.insert(self.AvailableFastTracks, v)
					elseif v.mode == "housemix" then
						table.insert(self.AvailableHouseMixTracks, v)
					end
                    end
				end
	
	if #self.AvailableHouseMixTracks > 0 then
		self.housemix = 1
	end
	
	local characterData = self.character:getModData()

	if characterData.PlayingInstrument ~= nil
	then
	characterData.PlayingInstrument = true
	else
	characterData.PlayingInstrument = true
	end

	LS_DJBooth.isPlaying = true
	if LS_DJBooth.failstate then LS_DJBooth.failstate = false; end

	if self.mode == "slow" then
		LS_DJBooth.speed = 1
	elseif self.mode == "medium" then
		LS_DJBooth.speed = 2
	elseif self.mode == "fast" then
		LS_DJBooth.speed = 3
	elseif self.mode == "housemix" then
		LS_DJBooth.speed = 4
	end
	
	self.action:setUseProgressBar(false)

    self.DJBoothOverlay = DJSoundboardOverlay:new(self.character, self.DJBooth);
    self.DJBoothOverlay:initialise();
    self.DJBoothOverlay:addToUIManager();

end

function PlayDJBoothAction:start()
    if not self:isValid() then
        self:forceStop()
        return false
    end
    activePlayerAction=self
    self.saoStarted=true
    self.musicOriginalVolume=tonumber(getSoundManager():getMusicVolume())
    local ok,reason=pcall(sourceStart,self)
    if not ok then
        self.saoSourceError=tostring(reason)
        self:forceStop()
        return false
    end
    return true
end

local function finishPhysical(self,turnOff)
    if self.saoEnded then return end
    self.saoEnded=true
    if activePlayerAction~=self then return end
    if type(LS_DJBooth.keyPress)=="function" then pcall(LS_DJBooth.keyPress,41) end
    local ok,emitter=pcall(function()return self.character:getEmitter()end)
    if ok and emitter then
        pcall(function()
            if self.gameSound and self.gameSound~=0 and emitter:isPlaying(self.gameSound) then
                emitter:stopSound(self.gameSound)
            end
        end)
        if turnOff then
            pcall(function()
                emitter:playSound("dj_booth_turnoff")
                addSound(self.character,self.character:getX(),self.character:getY(),
                    self.character:getZ(),10,5)
            end)
        end
    end
    self.Failstate=false
    pcall(function()self.character:getModData().PlayingInstrument=false end)
    LS_DJBooth.isPlaying=false
    LS_DJBooth.failstate=false
    LS_DJBooth.stop=true
    if self.DJBoothOverlay and self.DJBoothOverlay~=0 then
        pcall(function()self.DJBoothOverlay:destroy()end)
        self.DJBoothOverlay=0
    end
    if LS_DJBooth.isPlayingMic~=true and self.musicOriginalVolume then
        pcall(function()
            local manager=getSoundManager()
            if tonumber(manager:getMusicVolume())==0 then
                manager:setMusicVolume(self.musicOriginalVolume)
            end
        end)
    end
    self.saoStarted=false
    activePlayerAction=nil
end

function PlayDJBoothAction:stop()
    if self.saoEnded then return end
    finishPhysical(self,true)
    ISBaseTimedAction.stop(self)
end

function PlayDJBoothAction:perform()
    if self.saoEnded then return end
    local completed=self.saoStarted and self:isValid()
    if completed then
        local ok,reason=pcall(adjustStats,self.character)
        self.saoEffectApplied=ok
        if not ok then self.saoSourceError=tostring(reason) end
    else
        self.saoCompletionRejected=true
    end
    finishPhysical(self,false)
    ISBaseTimedAction.perform(self)
end

function PlayDJBoothAction:complete()

	return true
end

function PlayDJBoothAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function PlayDJBoothAction:new(character, DJBooth, soundFile, mode, length, xp, boredomReduction, stressReduction, actionType, isFail)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.DJBooth = DJBooth;
    o.Type = "PlayDJBoothAction"
    o.saoOwner = "SAO.PlayerDJ"
    o.playerIndex = character and character:getPlayerNum()
    o.stationSquare = DJBooth and DJBooth:getSquare()
    o.stationSprite = nameOf(DJBooth)
    o.frontSquare = frontOf(DJBooth)
    o.leftPart,o.rightPart = partsAt(DJBooth)
    o.sourceMode = mode
    o.sourceSound = soundFile
    o.sourceLength = selectedTrack(mode,soundFile)
    o.saoStarted = false
    o.saoEnded = false
	o.soundFile = soundFile
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.ignoreDynamicTime = true;
	o.length = o.sourceLength and o.sourceLength*48 or 0
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.audio = 0
	o.mode = mode
	o.xp = xp
	o.boredomReduction = boredomReduction
	o.stressReduction = stressReduction
	o.actionType = actionType
	o.isFail = isFail
	o.musicOriginalVolume = nil
	o.pastAnim = 0
	o.AnimToplay = "Bob_PlayDJDefault"
	o.AnimDelayStart = 0
	o.AnimDelayEnd = 1200
	o.DJAnim = {"Bob_PlayDJScratchCD","Bob_PlayDJMix","Bob_PlayDJVibe"};
	o.idxDJAnim = 0
	o.housemix = 0
	o.actionCount = 0
	o.actionTotal = 120--600
	o.Failstate = false
	o.djboothloop = false
	o.AvailableSlowTracks = {}
	o.AvailableMediumTracks = {}
	o.AvailableFastTracks = {}
	o.AvailableHouseMixTracks = {}
	o.countstart = 0
	o.countend = 100
	o.keyPause = true
	o.keyDelayStart = 0
	o.keyDelayEnd = 300
	o.DJBoothOverlay = 0
    return o;
end

return PlayDJBoothAction;
