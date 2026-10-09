require "TimedActions/ISBaseTimedAction"
require "ProjectArcade_Currency"

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function getArcadeMachineType(spriteName)
    local arcadeMachineSprites = {
        ArcadeMachine1 = { "recreational_01_16","recreational_01_17","recreational_01_18","recreational_01_19" },
        ArcadeMachine2 = { "recreational_01_20","recreational_01_21","recreational_01_22","recreational_01_23" },

        ArcadeStreetFighter = { "pa_arcades_0","pa_arcades_1","pa_arcades_2","pa_arcades_3" },
        ArcadePacman        = { "pa_arcades_4","pa_arcades_5","pa_arcades_6","pa_arcades_7" },
        ArcadeDoubleDragon  = { "pa_arcades_8","pa_arcades_9","pa_arcades_10","pa_arcades_11" },
        ArcadeSpaceInvaders = { "pa_arcades_12","pa_arcades_13","pa_arcades_14","pa_arcades_15" },
		ArcadeDonkeyKong = { "pa_arcades_16","pa_arcades_17","pa_arcades_18","pa_arcades_19", },
        ArcadeCentipede   = { "pa_arcades_20","pa_arcades_21","pa_arcades_22","pa_arcades_23" },
        ArcadeDigDug      = { "pa_arcades_24","pa_arcades_25","pa_arcades_26","pa_arcades_27" },
        ArcadeNBAJam     = { "pa_arcades_28","pa_arcades_29","pa_arcades_30","pa_arcades_31" },
        ArcadeTMNT       = { "pa_arcades_32","pa_arcades_33","pa_arcades_34","pa_arcades_35" },
        ArcadeMK         = { "pa_arcades_36","pa_arcades_37","pa_arcades_38","pa_arcades_39" },

        ComplexTerminator2 = { "pa_complex_0", "pa_complex_1" },
		ComplexStarWars = {
            "pa_complex_2", "pa_complex_3",
            "pa_complex_4", "pa_complex_5",
            "pa_complex_6", "pa_complex_7",
            "pa_complex_8", "pa_complex_9"
        },

        PinballMachine = { "recreational_01_24","recreational_01_27" },

        PinballAddamsFamily = { "pa_pinballs_0", "pa_pinballs_3" },
        PinballTwilightZone = { "pa_pinballs_4", "pa_pinballs_7" },
        PinballIndianaJones = { "pa_pinballs_8", "pa_pinballs_11" },
        PinballBlackKnight2000 = { "pa_pinballs_12", "pa_pinballs_15" },
        PinballFunHouse        = { "pa_pinballs_16", "pa_pinballs_19" },
        PinballElviraPartyMonsters = { "pa_pinballs_20", "pa_pinballs_23" },
        PinballMarioBros = { "pa_pinballs_24", "pa_pinballs_27" },
    }

    for machineType, sprites in pairs(arcadeMachineSprites) do
        for _, s in ipairs(sprites) do
            if s == spriteName then
                return machineType
            end
        end
    end
    return nil
end

local function getFrontTileForRecreational(square, spriteName)
    if not square or not spriteName then return nil end

        if tableContains({ "recreational_01_16", "recreational_01_20", "recreational_01_24" }, spriteName) then
        return square:getS()
    elseif tableContains({ "recreational_01_17", "recreational_01_21", "recreational_01_27" }, spriteName) then
        return square:getE()
    elseif tableContains({ "recreational_01_19", "recreational_01_23" }, spriteName) then
        return square:getN()
    elseif tableContains({ "recreational_01_18", "recreational_01_22" }, spriteName) then
        return square:getW()
    end

    if tableContains({ "pa_arcades_0","pa_arcades_4","pa_arcades_8","pa_arcades_12","pa_arcades_16","pa_arcades_20","pa_arcades_24","pa_arcades_28","pa_arcades_32","pa_arcades_36" }, spriteName) then
        return square:getS()
    elseif tableContains({ "pa_arcades_1","pa_arcades_5","pa_arcades_9","pa_arcades_13","pa_arcades_17","pa_arcades_21","pa_arcades_25","pa_arcades_29","pa_arcades_33","pa_arcades_37" }, spriteName) then
        return square:getE()
    elseif tableContains({ "pa_arcades_2","pa_arcades_6","pa_arcades_10","pa_arcades_14","pa_arcades_18","pa_arcades_22","pa_arcades_26","pa_arcades_30","pa_arcades_34","pa_arcades_38" }, spriteName) then
        return square:getW()
    elseif tableContains({ "pa_arcades_3","pa_arcades_7","pa_arcades_11","pa_arcades_15","pa_arcades_19","pa_arcades_23","pa_arcades_27","pa_arcades_31","pa_arcades_35","pa_arcades_39" }, spriteName) then
        return square:getN()
	end
	
    if tableContains({ "pa_complex_0" }, spriteName) then
        return square:getS()
    elseif tableContains({ "pa_complex_1" }, spriteName) then
        return square:getE()
    end
		
    if tableContains({ "pa_pinballs_0", "pa_pinballs_4", "pa_pinballs_8", "pa_pinballs_12", "pa_pinballs_16", "pa_pinballs_20", "pa_pinballs_24" }, spriteName) then
        return square:getS()
    elseif tableContains({ "pa_pinballs_3", "pa_pinballs_7", "pa_pinballs_11", "pa_pinballs_15", "pa_pinballs_19", "pa_pinballs_23", "pa_pinballs_27" }, spriteName) then
        return square:getE()
    end

    return nil
end

local function getComplexStarWarsTailSprite(spriteName)
    if not spriteName then return nil end

    -- Solo cola, no frente
    if spriteName == "pa_complex_4" then
        return "pa_complex_4"
    end

    if spriteName == "pa_complex_3" then
        return "pa_complex_3"
    end

    if spriteName == "pa_complex_6" then
        return "pa_complex_6"
    end

    if spriteName == "pa_complex_9" then
        return "pa_complex_9"
    end

    return nil
end

local function getComplexStarWarsInteractionTile(square, spriteName)
    if not square or not spriteName then return nil end

    local tailSprite = getComplexStarWarsTailSprite(spriteName)
    if not tailSprite then return nil end

    -- S = cola pa_complex_4 -> entrar por el ESTE
    if tailSprite == "pa_complex_4" then
        return square:getE()
    end

    -- E = cola pa_complex_3 -> entrar por el NORTE
    if tailSprite == "pa_complex_3" then
        return square:getN()
    end

    -- W = cola pa_complex_6 -> entrar por el SUR
    if tailSprite == "pa_complex_6" then
        return square:getS()
    end

    -- N = cola pa_complex_9 -> entrar por el OESTE
    if tailSprite == "pa_complex_9" then
        return square:getW()
    end

    return nil
end

local function getInteractionTileForRecreational(square, spriteName, machineType)
    if not square or not spriteName then return nil end

    if machineType == "ComplexStarWars" then
        return getComplexStarWarsInteractionTile(square, spriteName)
    end

    return getFrontTileForRecreational(square, spriteName)
end

local PA_MACHINE_CONFIG = {     -- Animaciones
    ArcadeStreetFighter = { actionAnim = "PlayArcadeSF2" },
    ArcadePacman        = { actionAnim = "PlayArcadePac" },
    ArcadeDoubleDragon  = { actionAnim = "PlayArcadeDD" },
    ArcadeSpaceInvaders = { actionAnim = "PlayArcadeSI" },
    ArcadeDonkeyKong    = { actionAnim = "PlayArcadeDK" },
    ArcadeCentipede    = { actionAnim = "PlayArcadeCen", loopSound = "PAcenplay", endSound = "PAcenend" },
    ArcadeDigDug       = { actionAnim = "PlayArcadeDig", loopSound = "PAdigplay", endSound = "PAdigend" },
    ArcadeNBAJam       = { actionAnim = "PlayArcade4P", loopSound = "PAnbaplay", endSound = "PAnbaend" },
    ArcadeTMNT         = { actionAnim = "PlayArcade4P", loopSound = "PAtmntplay", endSound = "PAtmntend" },
    ArcadeMK           = { actionAnim = "PlayArcade4P", loopSound = "PAmkplay", endSound = "PAmkend" },
	
    ArcadeMachine1      = { actionAnim = "PlayArcade" },
    ArcadeMachine2      = { actionAnim = "PlayArcade" },

    PinballMachine      = { actionAnim = "PlayPinball" },
    PinballAddamsFamily = { actionAnim = "PlayPinball" },
    PinballTwilightZone = { actionAnim = "PlayPinball" },
    PinballIndianaJones = { actionAnim = "PlayPinball" },
    PinballBlackKnight2000 = { actionAnim = "PlayPinball" },
    PinballFunHouse        = { actionAnim = "PlayPinball" },
    PinballElviraPartyMonsters = { actionAnim = "PlayPinball" },
	PinballMarioBros       = { actionAnim = "PlayPinball" },

    ComplexTerminator2  = { actionAnim = "PlayComplex", loopSound = "PAt2play", endSound = "PAt2end" },
    ComplexStarWars    = { actionAnim = "PlayComplexSW", loopSound = "PAswplay", endSound = "PAswend" },
}

local function PA_MakeSoundKeyFromObject(obj)
    if not obj or not obj.getSquare then return "nil" end
    local sq = obj:getSquare()
    if not sq then return "nil" end
    return tostring(sq:getX()) .. ":" .. tostring(sq:getY()) .. ":" .. tostring(sq:getZ())
end

local function PA_SendWorldSoundStart(self, soundName)
    if not isClient() then return end
    if not self or not self.object or not soundName then return end
    local sq = self.object:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundStart", {
        key = PA_MakeSoundKeyFromObject(self.object),
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        sound = soundName,
    })
end

local function PA_SendWorldSoundStop(self)
    if not isClient() then return end
    if not self or not self.object then return end
    local sq = self.object:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundStop", {
        key = PA_MakeSoundKeyFromObject(self.object),
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
    })
end

local function PA_SendWorldSoundOneShot(self, soundName)
    if not isClient() then return end
    if not self or not self.object or not soundName then return end
    local sq = self.object:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundOneShot", {
        key = PA_MakeSoundKeyFromObject(self.object),
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        sound = soundName,
    })
end

local function PA_GetMachineConfig(machineType)
    return (machineType and PA_MACHINE_CONFIG[machineType]) or nil
end

local function getPlayLoopSound(machineType)
    if machineType == "ArcadeStreetFighter" then return "PAMsfplay" end
    if machineType == "ArcadePacman" then return "PAMpacplay" end
    if machineType == "ArcadeDoubleDragon" then return "PAddplay" end
    if machineType == "ArcadeSpaceInvaders" then return "PAsiplay" end
	if machineType == "ArcadeDonkeyKong" then return "PAdkplay" end
    if machineType == "ArcadeMachine2" then return "PAMdroidsplay" end
    if machineType == "ArcadeNBAJam" then return "PAnbaplay" end
    if machineType == "ArcadeTMNT" then return "PAtmntplay" end
    if machineType == "ArcadeMK" then return "PAmkplay" end
	
    if machineType == "ComplexTerminator2" then return "PAt2play" end
    if machineType == "ComplexStarWars" then return "PAswplay" end

    if machineType == "PinballMachine" then return "PAMpinballplay" end
    if machineType == "PinballAddamsFamily" then return "PAafplay" end
    if machineType == "PinballTwilightZone" then return "PAtzplay" end
    if machineType == "PinballIndianaJones" then return "PAijplay" end
    if machineType == "PinballBlackKnight2000" then return "PAbk2000play" end
    if machineType == "PinballFunHouse"        then return "PAfhplay" end
    if machineType == "PinballElviraPartyMonsters" then return "PAetpmplay" end
    if machineType == "PinballMarioBros" then return "PAmbplay" end

    return "PAMkaboomplay"
end

local function getEndSound(machineType)
    if machineType == "ArcadeStreetFighter" then return "PAMsfend" end
    if machineType == "ArcadePacman" then return "PAMpacend" end
	if machineType == "ArcadeDoubleDragon" then return "PAddend" end
	if machineType == "ArcadeSpaceInvaders" then return "PAsiend" end
	if machineType == "ArcadeDonkeyKong" then return "PAdkend" end
	if machineType == "ArcadeMachine2" then return "PAMdroidsend" end
    if machineType == "ArcadeNBAJam" then return "PAnbaend" end
    if machineType == "ArcadeTMNT" then return "PAtmntend" end
    if machineType == "ArcadeMK" then return "PAmkend" end
	
    if machineType == "ComplexTerminator2" then return "PAt2end" end
	if machineType == "ComplexStarWars" then return "PAswend" end

    if machineType == "PinballMachine" then return "PAMpinballend" end
    if machineType == "PinballAddamsFamily" then return "PAafend" end
    if machineType == "PinballTwilightZone" then return "PAtzend" end
    if machineType == "PinballIndianaJones" then return "PAijend" end
    if machineType == "PinballBlackKnight2000" then return "PAbk2000end" end
    if machineType == "PinballFunHouse"        then return "PAfhend" end
    if machineType == "PinballElviraPartyMonsters" then return "PAetpmend" end
    if machineType == "PinballMarioBros" then return "PAmbend" end
	
    return "PAMkaboomend"
end

local function getLoopDurationMs(soundName)
    if soundName == "PAMsfplay" then return 46000 end
    if soundName == "PAMdroidsplay" then return 30000 end
    if soundName == "PAMpinballplay" then return 29000 end
    if soundName == "PAddplay" then return 58000 end
	if soundName == "PAsiplay" then return 38000 end 
    if soundName == "PAafplay" then return 50000 end
    if soundName == "PAtzplay" then return 53000 end
    if soundName == "PAijplay" then return 60500 end
	if soundName == "PAdkplay" then return 55000 end
    if soundName == "PAt2play" then return 60000 end
    if soundName == "PAcenplay" then return 60000 end
    if soundName == "PAdigplay" then return 64000 end
    if soundName == "PAnbaplay" then return 62000 end
    if soundName == "PAtmntplay" then return 62000 end
    if soundName == "PAmkplay" then return 60000 end
    if soundName == "PAfhplay" then return 60000 end
    if soundName == "PAbk2000play" then return 70000 end
    if soundName == "PAetpmplay" then return 60000 end
    if soundName == "PAswplay" then return 60000 end
    if soundName == "PAmbplay" then return 60000 end

    return 25000
end


local function applyMoodChanges_B42Safe(character, boredomDecrease, unhappinessDecrease, stressDecrease)
    local stats = character:getStats()

    if CharacterStat and stats and stats.get and stats.set then
        local curBoredom = stats:get(CharacterStat.BOREDOM)
        local curUnhappy = stats:get(CharacterStat.UNHAPPINESS)
        local curStress  = stats:get(CharacterStat.STRESS)

        stats:set(CharacterStat.BOREDOM, math.max(0, curBoredom - boredomDecrease))
        stats:set(CharacterStat.UNHAPPINESS, math.max(0, curUnhappy - unhappinessDecrease))
        stats:set(CharacterStat.STRESS, math.max(0, curStress - stressDecrease))
        return
    end

    local bd = character:getBodyDamage()
    if bd then
        if bd.getBoredomLevel and bd.setBoredomLevel then
            bd:setBoredomLevel(math.max(0, bd:getBoredomLevel() - boredomDecrease))
        end
        if bd.getUnhappinessLevel and bd.setUnhappinessLevel then
            bd:setUnhappinessLevel(math.max(0, bd:getUnhappinessLevel() - unhappinessDecrease))
        end
    end
    if stats and stats.getStress and stats.setStress then
        stats:setStress(math.max(0, stats:getStress() - stressDecrease))
    end
end

local function PA_SendMoodDeltaToServer(self, boredomDec, unhappyDec, stressDec)
    if not self or not self.character then return end

    if not isClient() then
        applyMoodChanges_B42Safe(self.character, boredomDec, unhappyDec, stressDec)
        return
    end

    local nowMs = (getTimestampMs and getTimestampMs()) or nil
    if not nowMs then
        sendClientCommand(self.character, "ProjectArcade", "ApplyMoodDelta", {
            boredom = boredomDec,
            unhappiness = unhappyDec,
            stress = stressDec
        })
        return
    end

    self._PA_moodAccB = (self._PA_moodAccB or 0) + (boredomDec or 0)
    self._PA_moodAccU = (self._PA_moodAccU or 0) + (unhappyDec or 0)
    self._PA_moodAccS = (self._PA_moodAccS or 0) + (stressDec or 0)

    if not self._PA_nextMoodSendMs then
        self._PA_nextMoodSendMs = nowMs + 1000
        return
    end

    if nowMs < self._PA_nextMoodSendMs then return end
    self._PA_nextMoodSendMs = nowMs + 1000

    sendClientCommand(self.character, "ProjectArcade", "ApplyMoodDelta", {
        boredom = self._PA_moodAccB,
        unhappiness = self._PA_moodAccU,
        stress = self._PA_moodAccS
    })

    self._PA_moodAccB = 0
    self._PA_moodAccU = 0
    self._PA_moodAccS = 0
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

local function PA_PlayGameSound(self, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    if not self.emitter then
        self.emitter = IsoWorld.instance:getFreeEmitter()
    end

    local sq = self.object and self.object:getSquare() or nil
    if not sq then return end
    self.emitter:setPos(sq:getX(), sq:getY(), sq:getZ())

    local nowMs = (getTimestampMs and getTimestampMs()) or nil
    local shouldRestart = (not self.soundId or self.soundId == 0)

    if nowMs then
        if not self.nextLoopAtMs then self.nextLoopAtMs = 0 end
        if self.nextLoopAtMs ~= 0 and nowMs >= self.nextLoopAtMs then
            shouldRestart = true
        end
    end

    if shouldRestart then
        if self.soundId and self.soundId ~= 0 then
            self.emitter:stopSound(self.soundId)
            self.soundId = nil
        end

        local clip = snd:getRandomClip()
        if not clip then return end

        self.soundId = self.emitter:playClip(clip, nil)
        if self.soundId and self.soundId ~= 0 then
            -- Respeta volumen del script:
            local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
            self.emitter:setVolume(self.soundId, clipVol * PA_GetSfxVolMult())
            self.emitter:set3D(self.soundId, true)

            if nowMs then
                local dur = getLoopDurationMs(soundName) or 60000
                self.nextLoopAtMs = nowMs + dur - 200
            end
        end
    end

    self.emitter:tick()
end

local function PA_StopGameSound(self)
    if self.emitter and self.soundId and self.soundId ~= 0 then
        self.emitter:stopSound(self.soundId)
        self.emitter:tick()
    end
    self.soundId = nil
    self.nextLoopAtMs = 0
end

local function PA_PlayOneShotAtCharacter(character, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    if not e then return end

    e:setPos(character:getX(), character:getY(), character:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
        local mult = (PA_GetSfxVolMult and PA_GetSfxVolMult()) or 1.0
        e:setVolume(id, clipVol * mult)
        e:set3D(id, true)
        e:tick()
    end
end


local function PA_PlayOneShotAtMachine(self, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local sq = self.object and self.object:getSquare() or nil
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


local PA_MOOD_TICK_MS = 12000 
local function PA_HaloArrow(character, translationKey, isPositive, r, g, b)
    if not character then return end
    if not (HaloTextHelper and HaloTextHelper.addTextWithArrow) then return end

    local text = getText(translationKey) or translationKey
    HaloTextHelper.addTextWithArrow(character, text, isPositive, r or 200, g or 255, b or 200)
end

local function PA_QueueHalo(self, translationKey, isPositive, r, g, b, delayMs)
    if not self then return end
    if not self.haloQueue then self.haloQueue = {} end

    local nowMs = (getTimestampMs and getTimestampMs()) or 0
    table.insert(self.haloQueue, {
        at = nowMs + (delayMs or 0),
        key = translationKey,
        pos = isPositive,
        r = r, g = g, b = b
    })
end

local function PA_TickHaloQueue(self)
    if not self or not self.haloQueue or #self.haloQueue == 0 then return end
    local nowMs = (getTimestampMs and getTimestampMs()) or nil
    if not nowMs then return end

        for i = #self.haloQueue, 1, -1 do
        local msg = self.haloQueue[i]
        if nowMs >= msg.at then
            PA_HaloArrow(self.character, msg.key, msg.pos, msg.r, msg.g, msg.b)
            table.remove(self.haloQueue, i)
        end
    end
end

local function PA_MoodTick(self, boredomDec, unhappyDec, stressDec)
    if not self or not self.character then return end

        local nowMs = (getTimestampMs and getTimestampMs()) or nil
    if not nowMs then return end

	if not self.nextMoodHaloAtMs then
		self.nextMoodHaloAtMs = nowMs + 2000 		return
	end

    if nowMs < self.nextMoodHaloAtMs then return end
    self.nextMoodHaloAtMs = nowMs + PA_MOOD_TICK_MS

	local d = 0
	if boredomDec and boredomDec > 0 then
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_BoredomDown", true, 200, 255, 200, d)
		d = d + 300
	end
	if unhappyDec and unhappyDec > 0 then
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_UnhappinessDown", true, 200, 255, 200, d)
		d = d + 300
	end
	if stressDec and stressDec > 0 then
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_StressDown", true, 200, 255, 200, d)
		d = d + 300
	end

end

-- =========================================================
-- Arcade "Screen ON" overlay (B42 safe) - uses attached anim sprites
-- Based on Open All Containers overlay technique
-- =========================================================

local PA_ARCADE_SCREEN_OVERLAYS = {
    ["pa_arcades_0"]  = "pa_arcades_overlay_0",
    ["pa_arcades_1"]  = "pa_arcades_overlay_1",
    ["pa_arcades_4"]  = "pa_arcades_overlay_4",
    ["pa_arcades_5"]  = "pa_arcades_overlay_5",
    ["pa_arcades_8"]  = "pa_arcades_overlay_8",
    ["pa_arcades_9"]  = "pa_arcades_overlay_9",
    ["pa_arcades_12"] = "pa_arcades_overlay_12",
    ["pa_arcades_13"] = "pa_arcades_overlay_13",
	["pa_arcades_16"] = "pa_arcades_overlay_16",
	["pa_arcades_17"] = "pa_arcades_overlay_17",
	["pa_arcades_20"] = "pa_arcades_overlay_20",
	["pa_arcades_21"] = "pa_arcades_overlay_21",
	["pa_arcades_24"] = "pa_arcades_overlay_24",
	["pa_arcades_25"] = "pa_arcades_overlay_25",
	["pa_arcades_28"] = "pa_arcades_overlay_28",
	["pa_arcades_29"] = "pa_arcades_overlay_29",
	["pa_arcades_32"] = "pa_arcades_overlay_32",
	["pa_arcades_33"] = "pa_arcades_overlay_33",
	["pa_arcades_36"] = "pa_arcades_overlay_36",
	["pa_arcades_37"] = "pa_arcades_overlay_37",
	
    ["pa_complex_0"] = "pa_complex_overlay_0",
    ["pa_complex_1"] = "pa_complex_overlay_1",
	["pa_complex_3"] = "pa_complex_overlay_3",
    ["pa_complex_4"] = "pa_complex_overlay_4",
}

local function PA_GetOverlayForSprite(spriteName)
    if not spriteName then return nil end
    return PA_ARCADE_SCREEN_OVERLAYS[spriteName]
end

local PA_MD_KEY_ORIG_OVERLAY = "PA_originalTileOverlay"
local PA_MD_KEY_IS_ON = "PA_arcadeScreenOn"

local function PA_SaveAndRemoveAnyTileOverlay(obj)
    if not obj then return end
    local modData = obj:getModData()
    if modData[PA_MD_KEY_ORIG_OVERLAY] then
        return -- ya lo guardamos antes
    end

    local saved = nil

    local childSprites = obj:getChildSprites()
    local overlaySprite = obj:getOverlaySprite()
    local hasAnim = obj:hasAttachedAnimSprites()

    if childSprites and childSprites:size() > 0 then
        local firstChild = childSprites:get(0)
        if firstChild and firstChild:getName() then saved = firstChild:getName() end
        obj:setChildSprites(nil)

    elseif overlaySprite then
        saved = overlaySprite:getName()
        obj:setOverlaySprite(nil)

    elseif hasAnim then
        local animSprite = obj:getAttachedAnimSprite()
        if animSprite and animSprite:getName() then saved = animSprite:getName() end
        obj:setAttachedAnimSprite(nil)
    end

    if saved then
        modData[PA_MD_KEY_ORIG_OVERLAY] = saved
    end

    obj:transmitUpdatedSprite()
    obj:transmitModData()
end

local function PA_RestoreSavedTileOverlay(obj)
    if not obj then return end
    local modData = obj:getModData()

    -- limpiar overlays actuales
    obj:setOverlaySprite(nil)
    if obj:hasAttachedAnimSprites() then
        obj:setAttachedAnimSprite(nil)
    end

    local saved = modData[PA_MD_KEY_ORIG_OVERLAY]
    if saved then
        local spr = IsoSpriteManager.instance:getSprite(saved)
        if spr then
            obj:addAttachedAnimSprite(spr)
        end
        modData[PA_MD_KEY_ORIG_OVERLAY] = nil
    end

    obj:transmitUpdatedSprite()
    obj:transmitModData()
end

local function PA_ForceOverlayRefresh(obj)
    if not obj then return end

    obj:transmitUpdatedSprite()

    if ItemPicker and ItemPicker.updateOverlaySprite then
        ItemPicker.updateOverlaySprite(obj)
    end

    local sq = obj:getSquare()
    if sq then
        sq:RecalcProperties()

        if sq.InvalidateSpecialObjects then
            sq:InvalidateSpecialObjects()
        end

        if sq.RecalcLighting then
            sq:RecalcLighting()
        end
    end
end


local function PA_SetArcadeScreenOverlay(obj, enabled)
    if not obj or not obj:getSprite() then return end
	local spriteName = obj:getSprite():getName()
	local overlayName = PA_GetOverlayForSprite(spriteName)
	if not overlayName then return end


    local modData = obj:getModData()

    if enabled then
        if modData[PA_MD_KEY_IS_ON] then
            return
        end
        modData[PA_MD_KEY_IS_ON] = true

        PA_SaveAndRemoveAnyTileOverlay(obj)

        local onSpr = IsoSpriteManager.instance:getSprite(overlayName)
        if onSpr then
            obj:addAttachedAnimSprite(onSpr)
        end

        obj:transmitUpdatedSprite()
        obj:transmitModData()
        if ItemPicker and ItemPicker.updateOverlaySprite then
            ItemPicker.updateOverlaySprite(obj)
        end
		PA_ForceOverlayRefresh(obj)
    else
        if not modData[PA_MD_KEY_IS_ON] then
            return 
        end
        modData[PA_MD_KEY_IS_ON] = nil

        PA_RestoreSavedTileOverlay(obj)

        if ItemPicker and ItemPicker.updateOverlaySprite then
            ItemPicker.updateOverlaySprite(obj)
        end
		PA_ForceOverlayRefresh(obj)
    end
end


ProjectArcade_PlayArcadeTimedAction = ISBaseTimedAction:derive("ProjectArcade_PlayArcadeTimedAction")

function ProjectArcade_PlayArcadeTimedAction:isValid()
    if not self.character or not self.object then return false end
    local square = self.object:getSquare()
    if not square then return false end

    local sprite = self.object:getSprite()
    local spriteName = sprite and sprite:getName() or nil

    local interactionTile = getInteractionTileForRecreational(square, spriteName, self.machineType)

    if interactionTile and interactionTile ~= self.character:getSquare() then
        if not self.hasSaidMessage then
            self.character:Say(safeGetText("ContextMenu_StepInFront"))
            self.hasSaidMessage = true
        end
        return false
    end

    return true
end

local function getFacingTargetSquareForMachine(square, spriteName, machineType)
    if not square or not spriteName then return square end

    if machineType == "ComplexStarWars" then
        -- En todos los casos mira hacia la máquina/cola
        return square
    end

    return square
end

function ProjectArcade_PlayArcadeTimedAction:start()
        self.paid = false
		
		self._PA_moodAccB = 0
	self._PA_moodAccU = 0
	self._PA_moodAccS = 0
	self._PA_nextMoodSendMs = nil

    local sq = self.object and self.object:getSquare() or nil
    local sp = self.object and self.object:getSprite() or nil
    local spriteName = sp and sp:getName() or nil
    local faceSq = getFacingTargetSquareForMachine(sq, spriteName, self.machineType) or sq
    if faceSq then
        self.character:faceLocation(faceSq:getX(), faceSq:getY())
    end

        if not self.debugFreePlay then
    end

    self.paid = true

    local cfg = PA_GetMachineConfig(self.machineType)
    local anim = (cfg and cfg.actionAnim) or "PlayArcade"
    self:setActionAnim(anim)
    PA_SetArcadeScreenOverlay(self.object, true)

    self.loopSoundName = (cfg and cfg.loopSound) or getPlayLoopSound(self.machineType)

    PA_SendWorldSoundStart(self, self.loopSoundName)

    -- Suprime el sonido de ambiente de esta máquina mientras se juega
    if ArcadeAmbientSound and ArcadeAmbientSound.suppressForObject then
        ArcadeAmbientSound.suppressForObject(self.object)
    end

end


function ProjectArcade_PlayArcadeTimedAction:update()
    local delta = getGameTime():getTrueMultiplier()

-- Recordatorio para mi mismo
    local boredomBase = 25
    local unhappinessBase = 35
    local stressBase = 25
-- ---------------------------

    local boredomDecrease = (boredomBase / self.maxTime) * delta
    local unhappinessDecrease = (unhappinessBase / self.maxTime) * delta
    local stressDecrease = (stressBase / (100 * self.maxTime)) * delta

	PA_SendMoodDeltaToServer(self, boredomDecrease, unhappinessDecrease, stressDecrease)
	PA_MoodTick(self, boredomDecrease, unhappinessDecrease, stressDecrease)

    if not self.loopSoundName then
        local cfg = PA_GetMachineConfig(self.machineType)
        self.loopSoundName = (cfg and cfg.loopSound) or getPlayLoopSound(self.machineType)
    end

    PA_PlayGameSound(self, self.loopSoundName)

    -- SP: en singleplayer no hay server que reciba comandos, así que generamos ruido real acá
    if not isClient() then
        local nowMs = (getTimestampMs and getTimestampMs()) or (os.time() * 1000)
        self._PA_nextAggroMs = self._PA_nextAggroMs or 0
        if nowMs >= self._PA_nextAggroMs then
            local sq = self.object and self.object:getSquare() or nil
            if sq and addSound then
                local x, y, z = sq:getX(), sq:getY(), sq:getZ()

                -- Tomamos parámetros desde el clip (distanceMax/volume) si está disponible.
                local aggroRadius, aggroVol = 30, 0.5
                local snd = GameSounds and GameSounds.getSound and self.loopSoundName and GameSounds.getSound(self.loopSoundName)
                if snd then
                    local clip = snd:getRandomClip()
                    if clip then
                        if clip.getMaxDistance then
                            local d = clip:getMaxDistance()
                            if d and d > 0 then aggroRadius = math.floor(d) end
                        end
                        if clip.getVolume then
                            local v = clip:getVolume()
                            if v and v > 0 then aggroVol = v end
                        end
                    end
                end

                addSound(self.character, x, y, z, aggroRadius, aggroVol)
            end
            self._PA_nextAggroMs = nowMs + 2000
        end
    end


    local sq = self.object and self.object:getSquare() or nil
    local sp = self.object and self.object:getSprite() or nil
    local spriteName = sp and sp:getName() or nil
    local faceSq = getFacingTargetSquareForMachine(sq, spriteName, self.machineType) or sq
    if faceSq then
        self.character:faceLocation(faceSq:getX(), faceSq:getY())
    end
	PA_TickHaloQueue(self)
end

local function PA_PlayOneShotAtMachine(self, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local sq = self.object and self.object:getSquare() or nil
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

function ProjectArcade_PlayArcadeTimedAction:stop()
    PA_StopGameSound(self)
    PA_SetArcadeScreenOverlay(self.object, false)

    PA_SendWorldSoundStop(self)

	if not self._PA_endPlayed then
		local cfg = PA_GetMachineConfig(self.machineType)
		local endSnd = (cfg and cfg.endSound) or getEndSound(self.machineType)
		self._PA_endPlayed = true

		PA_PlayOneShotAtMachine(self, endSnd)

		PA_SendWorldSoundOneShot(self, endSnd)
	end
	
	self._PA_moodAccB = 0
	self._PA_moodAccU = 0
	self._PA_moodAccS = 0
	self._PA_nextMoodSendMs = nil
	
    ISBaseTimedAction.stop(self)
end

function ProjectArcade_PlayArcadeTimedAction:perform()
    PA_SetArcadeScreenOverlay(self.object, false)
    PA_StopGameSound(self)

    PA_SendWorldSoundStop(self)

    local cfg = PA_GetMachineConfig(self.machineType)
    local endSnd = (cfg and cfg.endSound) or getEndSound(self.machineType)

    PA_PlayOneShotAtMachine(self, endSnd)

    if not self._PA_endPlayed then
        self._PA_endPlayed = true
        PA_SendWorldSoundOneShot(self, endSnd)
    end

	self.announcedResult = self.announcedResult or false

    local stats = self.character:getStats()
    if CharacterStat and stats and stats.get and stats.set then
        if self.didWin then
            stats:set(CharacterStat.BOREDOM, math.max(0, stats:get(CharacterStat.BOREDOM) - 20))
            stats:set(CharacterStat.UNHAPPINESS, math.max(0, stats:get(CharacterStat.UNHAPPINESS) - 25))
            stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.15))
			if not self.announcedResult then
				self.announcedResult = true
				PA_QueueHalo(self, self.didWin and "ContextMenu_ArcadeWin" or "ContextMenu_ArcadeLose", self.didWin, 200, 255, 200, 0)
				PA_TickHaloQueue(self)
			end
        else
--            stats:set(CharacterStat.UNHAPPINESS, math.min(100, stats:get(CharacterStat.UNHAPPINESS) + 5))
            stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.1))
			if not self.announcedResult then
				self.announcedResult = true
				PA_QueueHalo(self, self.didWin and "ContextMenu_ArcadeWin" or "ContextMenu_ArcadeLose", self.didWin, 200, 255, 200, 0)
				PA_TickHaloQueue(self)
			end
        end
    else
			if not self.announcedResult then
				self.announcedResult = true
				PA_QueueHalo(self, self.didWin and "ContextMenu_ArcadeWin" or "ContextMenu_ArcadeLose", self.didWin, 200, 255, 200, 0)
				PA_TickHaloQueue(self)
			end
    end
	
	if not self.didWin then
--		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_UnhappinessUp", false, 255, 120, 120, 0)
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_StressUp", false, 255, 120, 120, 300)
		PA_TickHaloQueue(self)
	end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_PlayArcadeTimedAction:new(character, object, time, cost, currencyFullType, debugFreePlay)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.object = object

    local sprite = object and object:getSprite()
    local spriteName = sprite and sprite:getName() or nil
    o.machineType = getArcadeMachineType(spriteName)

    o.maxTime = time or 3000
    o.hasSaidMessage = false

    o.stopOnWalk = true
    o.stopOnRun = true

    o.emitter = nil
    o.soundId = nil
    o.loopSoundName = nil
    o.nextLoopAtMs = 0

    o.didWin = (ZombRand(100) < 60)
	
	o.nextMoodHaloAtMs = 0


        o.cost = cost or (ProjectArcade_Currency and ProjectArcade_Currency.Config and ProjectArcade_Currency.Config.Cost) or 1
    o.currencyFullType = currencyFullType or (ProjectArcade_Currency and ProjectArcade_Currency.Config and ProjectArcade_Currency.Config.CurrencyFullType) or "Base.SilverCoin"
    o.debugFreePlay = (debugFreePlay == true)
    o.paid = false

    return o
end
