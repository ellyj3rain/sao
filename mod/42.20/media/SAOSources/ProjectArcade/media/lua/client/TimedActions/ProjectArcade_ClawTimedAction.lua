require "TimedActions/ISBaseTimedAction"
require "ProjectArcade_PrizeRegistry"

ProjectArcade_ClawTimedAction = ISBaseTimedAction:derive("ProjectArcade_ClawTimedAction")

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

local function PA_GetSfxVolMult()
    local pct = 100
    if SandboxVars and SandboxVars.ProjectArcade and SandboxVars.ProjectArcade.SfxVolumePct ~= nil then
        pct = tonumber(SandboxVars.ProjectArcade.SfxVolumePct) or 100
    end
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct / 100.0
end

-- ===== World-sound helpers (MP) =====
local function PA_MakeSoundKeyFromMachine(machine)
    if not machine or not machine.getSquare then return "nil" end
    local sq = machine:getSquare()
    if not sq then return "nil" end
    return tostring(sq:getX()) .. ":" .. tostring(sq:getY()) .. ":" .. tostring(sq:getZ())
end

local function PA_SendWorldSoundStart_Claw(self, soundName)
    if not isClient() then return end
    if not self or not self.machine or not soundName then return end
    local sq = self.machine:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundStart", {
        key = PA_MakeSoundKeyFromMachine(self.machine),
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        sound = soundName,
    })
end

local function PA_SendWorldSoundStop_Claw(self)
    if not isClient() then return end
    if not self or not self.machine then return end
    local sq = self.machine:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundStop", {
        key = PA_MakeSoundKeyFromMachine(self.machine),
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
    })
end

local function PA_SendWorldSoundOneShot_Claw(self, soundName)
    if not isClient() then return end
    if not self or not self.machine or not soundName then return end
    local sq = self.machine:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundOneShot", {
        key = PA_MakeSoundKeyFromMachine(self.machine),
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        sound = soundName,
    })
end

-- ===== One-shot at machine (LOCAL) =====
local function PA_PlayOneShotAtClawMachine(self, soundName)
    if not soundName then return end
    if not self or not self.machine then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local sq = self.machine:getSquare()
    if not sq then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    if not e then return end

    e:setPos(sq:getX(), sq:getY(), sq:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
        local mult = (PA_GetSfxVolMult and PA_GetSfxVolMult()) or 1.0
        e:setVolume(id, clipVol * mult)
        e:set3D(id, true)
        e:tick()
    end
end

local function PA_ClawNoisePulse(self, soundName)
    if isClient() then return end 
    if not addSound then return end
    if not self or not self.machine or not soundName then return end

    local sq = self.machine:getSquare()
    if not sq then return end

    local now = getTimestampMs and getTimestampMs() or (os.time() * 1000)
    self._PA_nextNoiseMs = self._PA_nextNoiseMs or 0
    if now < self._PA_nextNoiseMs then return end
    self._PA_nextNoiseMs = now + 2000 

    local radius = 20
    local volume = 50

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if snd then
        local clip = snd:getRandomClip()
        if clip then
            if clip.getMaxDistance then
                local dmax = clip:getMaxDistance()
                if dmax and dmax > 0 then radius = math.floor(dmax) end
            end
            if clip.getVolume then
                local v = clip:getVolume()
                if v and v > 0 then volume = math.floor(math.min(100, v * 100)) end
            end
        end
    end

    addSound(self.character, sq:getX(), sq:getY(), sq:getZ(), radius, volume)
end

local function PA_PlayOneShotAtCharacter(character, soundName)
    if not character or not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    e:setPos(character:getX(), character:getY(), character:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        e:setVolume(id, 1.0 * PA_GetSfxVolMult())
        e:set3D(id, true)
        e:tick()
    end
end

local function PA_PlayLoopedOnSelf(self, soundName)
    if not self or not self.character or not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    if not self.emitter then
        self.emitter = IsoWorld.instance:getFreeEmitter()
    end
    self.emitter:setPos(self.character:getX(), self.character:getY(), self.character:getZ())

    if self.soundId and self.soundId ~= 0 then
        self.emitter:stopSound(self.soundId)
        self.soundId = nil
    end

    self.soundId = self.emitter:playClip(clip, nil)
    if self.soundId and self.soundId ~= 0 then
        self.emitter:setVolume(self.soundId, 1.0 * PA_GetSfxVolMult())
        self.emitter:set3D(self.soundId, true)
        self.emitter:tick()
    end
end

local function PA_StopSoundOnSelf(self)
    if not self then return end
    if self.emitter and self.soundId and self.soundId ~= 0 then
        self.emitter:stopSound(self.soundId)
        self.emitter:tick()
    end
    self.soundId = nil
end

function ProjectArcade_ClawTimedAction:isValid()
    return self.machine ~= nil and self.machine:getSquare() ~= nil
end

function ProjectArcade_ClawTimedAction:waitToStart()
    if self.machine then
        self.character:faceThisObject(self.machine)
    end
    return self.character:isPlayerMoving() or self.character:isTurning() or self.character:shouldBeTurning()
end

function ProjectArcade_ClawTimedAction:start()
    self.paid = false

    if not self.debugFreePlay then
        local inv = self.character and self.character:getInventory()
        if not inv then
            ISBaseTimedAction.stop(self)
            return
        end

        if inv:getCountTypeRecurse(self.currencyFullType) < self.cost then
            if self.character and self.character.Say then
                self.character:Say(safeGetText("ContextMenu_ProjectArcade_NotEnoughCoins"))
            end
            self.useProgressBar = false
            self.maxTime = 0
            self.paid = false
            ISBaseTimedAction.perform(self)
            return
        end
    end

    self.paid = true

    self.maxTime = 624
    self.useProgressBar = true
    self:setActionAnim("PlayRecreativeClaw")
    self.character:setMetabolicTarget(Metabolics.UsingTools)

	self._PA_loopSound = "PAclaw"
	PA_PlayLoopedOnSelf(self, self._PA_loopSound)
	PA_SendWorldSoundStart_Claw(self, self._PA_loopSound)
end


function ProjectArcade_ClawTimedAction:update()
    self.character:setMetabolicTarget(Metabolics.UsingTools)

    if self._PA_loopSound then
        PA_ClawNoisePulse(self, self._PA_loopSound)
    end
end

function ProjectArcade_ClawTimedAction:stop()
    PA_StopSoundOnSelf(self)
    PA_SendWorldSoundStop_Claw(self)

    if not self._PA_endPlayed then
        self._PA_endPlayed = true
        PA_PlayOneShotAtClawMachine(self, "PAclawend")
        PA_SendWorldSoundOneShot_Claw(self, "PAclawend")
    end

    ISBaseTimedAction.stop(self)
end

function ProjectArcade_ClawTimedAction:perform()
	PA_StopSoundOnSelf(self)
	PA_SendWorldSoundStop_Claw(self)
    if not self.paid then
        ISBaseTimedAction.perform(self)
        return
    end
	
	if not self._PA_endPlayed then
		self._PA_endPlayed = true
		PA_PlayOneShotAtClawMachine(self, "PAclawend")
		PA_SendWorldSoundOneShot_Claw(self, "PAclawend")
	end
	
    local character = self.character
    if not character then
        ISBaseTimedAction.perform(self)
        return
    end

    local inv = character:getInventory()
    if not inv then
        ISBaseTimedAction.perform(self)
        return
    end
    
	if isClient() and not isServer() then
		require "ProjectArcade_PrizeNet"

		local nonce = ProjectArcade_PrizeNet.makeNonce()

		ProjectArcade_PrizeNet.Pending[nonce] = {
			playerIndex = 0, 
		}

		sendClientCommand(character, ProjectArcade_PrizeNet.MODULE, ProjectArcade_PrizeNet.CMD_ROLL, {
			nonce = nonce,
		})

		ISBaseTimedAction.perform(self)
		return
	end
    
	local prizeType = ProjectArcade_PrizeRegistry.rollMerged()
	if not prizeType then
		if character and character.Say then character:Say(safeGetText("ContextMenu_ProjectArcade_NoPrizeRegistered")) end
		HaloTextHelper.addTextWithArrow(character, safeGetText("ContextMenu_ProjectArcade_NoPrizeRegistered"), true, 255, 120, 120)
		ISBaseTimedAction.perform(self)
		return
	end


	local item = inv:AddItem(prizeType)
	
	if item then
			local name = item:getDisplayName() or tostring(prizeType)
			HaloTextHelper.addTextWithArrow(character, safeGetText("ContextMenu_ProjectArcade_NamePrize") .. name, true, 200, 255, 200)
		else
			HaloTextHelper.addTextWithArrow(character, safeGetText("ContextMenu_ProjectArcade_PrizeFailed") .. tostring(prizeType), true, 255, 120, 120)
	end

    if isServer() and item then
        sendAddItemToContainer(inv, item)
    end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_ClawTimedAction:new(character, machine, cost, currencyFullType, debugFreePlay)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.machine = machine
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 624
    o.useProgressBar = true

    o.cost = cost or 1
    o.currencyFullType = currencyFullType or "Base.SilverCoin"
    o.debugFreePlay = debugFreePlay == true

	o.emitter = nil
	o.soundId = nil

    o.paid = false
    return o
end


local function onServerCommand(module, command, args)
    if module ~= "ProjectArcade" then return end
    if command ~= "RollPrizeResult" then return end

    require "ProjectArcade_PrizeNet"

    local nonce = args and args.nonce
    if not nonce then return end

    local pending = ProjectArcade_PrizeNet.Pending and ProjectArcade_PrizeNet.Pending[nonce]
    if not pending then return end

    ProjectArcade_PrizeNet.Pending[nonce] = nil

    local player = getSpecificPlayer(pending.playerIndex or 0)
    if not player then return end

    if not (args and args.ok == true) then
        if player and player.Say then
            player:Say(safeGetText("ContextMenu_ProjectArcade_NoPrizeRegistered"))
        end
        if HaloTextHelper and HaloTextHelper.addTextWithArrow then
            HaloTextHelper.addTextWithArrow(player, safeGetText("ContextMenu_ProjectArcade_NoPrizeRegistered"), true, 255, 120, 120)
        end
        return
    end

    local name = (args and args.displayName) or (args and args.prizeType) or "???"

    if HaloTextHelper and HaloTextHelper.addTextWithArrow then
        HaloTextHelper.addTextWithArrow(player, safeGetText("ContextMenu_ProjectArcade_NamePrize") .. tostring(name), true, 200, 255, 200)
    end
end


Events.OnServerCommand.Add(onServerCommand)

