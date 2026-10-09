require "TimedActions/ISBaseTimedAction"
require "ProjectArcade_Currency"
require "TimedActions/ISWalkToTimedAction"
require "TimedActions/ISTimedActionQueue"

ProjectArcade_PunchingTimedAction = ISBaseTimedAction:derive("ProjectArcade_PunchingTimedAction")




local SCORE_BASE_MAX = 1500
local VARIANCE_PCT   = 0.10

local PERK_STRENGTH = Perks.Strength
local PERK_DEX      = Perks.Nimble




local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    
    if select("#", ...) > 0 then
        local args = { ... }
        return key .. " " .. table.concat(args, " ")
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

local function PA_PlayOneShotAtCharacter(character, soundName)
    if not soundName then return end

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

local function computePunchScore(player)
    local str = (player and player.getPerkLevel and (player:getPerkLevel(PERK_STRENGTH) or 0)) or 0
    local dex = (player and player.getPerkLevel and (player:getPerkLevel(PERK_DEX) or 0)) or 0
    str = clamp(str, 0, 10)
    dex = clamp(dex, 0, 10)

    
    local weighted  = (0.90 * str) + (0.10 * dex)

    
    local baseScore = (weighted / 10.0) * SCORE_BASE_MAX

    
    local varianceMult = ZombRandFloat(1.0 - VARIANCE_PCT, 1.0 + VARIANCE_PCT)

    local score = baseScore * varianceMult

    if score < 0 then score = 0 end
    return math.floor(score + 0.5)
end


local function prettifyName(s)
    if not s then return "Jugador" end
    
    if not string.find(s, "%s") then
        s = string.gsub(s, "(%l)(%u)", "%1 %2")
        s = string.gsub(s, "(%a)(%d)", "%1 %2")
    end
    return s
end

local function getPlayerDisplayName(player)
    if not player then return "Jugador" end

    
    local d = player.getDescriptor and player:getDescriptor() or nil
    if d and d.getForename and d:getForename() then
        local fn = d:getForename()
        local sn = (d.getSurname and d:getSurname()) or nil
        if sn and sn ~= "" then
            return prettifyName(fn .. " " .. sn)
        end
        return prettifyName(fn)
    end

    
    if player.getUsername and player:getUsername() then
        return prettifyName(player:getUsername())
    end

    return "Jugador"
end

require "ProjectArcade_HighscoreUI"

local function isLocalPlayer(player)
    
    if getPlayer and getPlayer() == player then return true end
    
    if player and player.isLocalPlayer then
        local ok, res = pcall(player.isLocalPlayer, player)
        if ok and res == true then return true end
    end
    return false
end

local function updateGlobalHighScores(player, score)
    local g = ModData.getOrCreate("ProjectArcade")

    g.PA_Punch_HS_Female = g.PA_Punch_HS_Female or 0
    g.PA_Punch_HS_FemaleName = g.PA_Punch_HS_FemaleName or safeGetText("ContextMenu_ProjectArcade_None")

    g.PA_Punch_HS_Male = g.PA_Punch_HS_Male or 0
    g.PA_Punch_HS_MaleName = g.PA_Punch_HS_MaleName or safeGetText("ContextMenu_ProjectArcade_None")

    local name = getPlayerDisplayName(player)

    local newFemale = false
    local newMale = false

    if player:isFemale() then
        if score > g.PA_Punch_HS_Female then
            g.PA_Punch_HS_Female = score
            g.PA_Punch_HS_FemaleName = name
            newFemale = true
        end
    else
        if score > g.PA_Punch_HS_Male then
            g.PA_Punch_HS_Male = score
            g.PA_Punch_HS_MaleName = name
            newMale = true
        end
    end

	
	local didHighscore = false

	if isLocalPlayer(player) then
		local showKind = nil

		if newFemale then
			showKind = "female"
		elseif newMale then
			showKind = "male"
		end

		if showKind then
			didHighscore = true

			
			ProjectArcade_HighscoreUI.Show(score, showKind)

			
			PA_PlayOneShotAtCharacter(player, "PAhighscore")

		end
	end

	return didHighscore
end




function ProjectArcade_PunchingTimedAction:isValid()
    return self.character and self.object and self.object:getSquare() ~= nil
end

function ProjectArcade_PunchingTimedAction:start()
    
    self.paid = false

    
    if not self.debugFreePlay then
        local inv = self.character and self.character:getInventory()
        if not inv then
            ISBaseTimedAction.stop(self)
            return
        end

        if inv:getCountTypeRecurse(self.currencyFullType) < self.cost then
            if self.character and self.character.Say then
                self.character:Say(GetText("ContextMenu_ProjectArcade_NotEnoughCoins"))
            end

            
            self.useProgressBar = false
            self.maxTime = 0
            self.paid = false

            ISBaseTimedAction.perform(self)
            return
        end
    end

    self.paid = true

    
    self:setActionAnim("PunchTheBag")

    local punchSounds = { "PApunching1", "PApunching2", "PApunching3" }
    local snd = punchSounds[ZombRand(#punchSounds) + 1]
    if snd then
        PA_PlayOneShotAtCharacter(self.character, snd)
    end
end

function ProjectArcade_PunchingTimedAction:update()
    self.character:faceThisObject(self.object)
end

function ProjectArcade_PunchingTimedAction:perform()
    local score = computePunchScore(self.character)

    local didHighscore = false

    if isClient() then
        -- MP: el server es la autoridad del highscore. El cliente solo reporta el score.
        sendClientCommand("ProjectArcade", "PunchingUpdateHS", {
            score = score,
            isFemale = self.character:isFemale(),
            name = getPlayerDisplayName(self.character),
        })
    else
        -- SP / server-host: podemos actualizar directo (y la UI/sonido se resuelve acá mismo)
        didHighscore = updateGlobalHighScores(self.character, score)
        if ModData.transmit then
            ModData.transmit("ProjectArcade")
        end
    end

    -- Feedback de puntaje: en MP lo decimos siempre (el highscore se confirma por OnServerCommand).
    -- En SP, si fue highscore, updateGlobalHighScores ya mostró UI + sonido.
    if not didHighscore then
        self.character:Say(safeGetText("ContextMenu_ProjectArcade_PunchScore", tostring(score)))
    end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_PunchingTimedAction:new(character, object, cost, currencyFullType, debugFreePlay)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.object = object
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 40 
	
	
    o.cost = cost or (ProjectArcade_Currency and ProjectArcade_Currency.Config and ProjectArcade_Currency.Config.Cost) or 1
    o.currencyFullType = currencyFullType or (ProjectArcade_Currency and ProjectArcade_Currency.Config and ProjectArcade_Currency.Config.CurrencyFullType) or "Base.SilverCoin"
    o.debugFreePlay = (debugFreePlay == true)
    o.paid = false
	
    return o
end
