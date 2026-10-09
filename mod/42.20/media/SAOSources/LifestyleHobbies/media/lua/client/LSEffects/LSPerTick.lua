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

local LSCanDoDirtRoll = 0
local LSCanDoDirtRollTotal = 60
local LSCarpentryXP = 0
local LSMetalworkingXP = 0
local LSTailoringXP = 0
local LSCookingXP = 0
local LSCanDoDirtRollDelayEndCount = 0
local LSCanDoDirtRollDelayEnd = false
local dbDelay = false
local dbCount = 0

local function PlayerCreateDirtForAction(thisPlayer, playerData)

	if LSCanDoDirtRollDelayEndCount > 0 then
		LSCanDoDirtRollDelayEndCount = LSCanDoDirtRollDelayEndCount - 1
	end
	
	if LSCanDoDirtRoll >= LSCanDoDirtRollTotal then
		LSCanDoDirtRoll = 0
	local MainLitterList = require("Properties/LitterTypes")
	local thisCategory = "grime"

	local dirtChance = 0
	local dirtSprite = "overlay_grime_floor_01_15"--backup
	local dirtSolid = 2---1 is solid, 2 is overlay

	local fileName, CallFrame = nil, getCoroutineCallframeStack(getCurrentCoroutine(),0)
	local fileDir = CallFrame ~= nil and CallFrame and getFilenameOfCallframe(CallFrame)
	local i = fileDir and fileDir:match('^.*()/')
	fileName = i and fileDir:sub(i+1):gsub(".lua", "")

	if thisPlayer:isReading() then
		LSCarpentryXP = tonumber(thisPlayer:getXp():getXP(Perks.Woodwork))
		LSTailoringXP = tonumber(thisPlayer:getXp():getXP(Perks.Tailoring))
		LSMetalworkingXP = tonumber(thisPlayer:getXp():getXP(Perks.MetalWelding))
		LSCookingXP = tonumber(thisPlayer:getXp():getXP(Perks.Cooking))
	elseif (thisPlayer:getModData() and thisPlayer:getModData().xpRI) or (fileName and ((fileName == "ISRadioInteractions") or (fileName == "TVRADIOTraits_ISRadioInteractions"))) then
		LSCarpentryXP = tonumber(thisPlayer:getXp():getXP(Perks.Woodwork))
		LSTailoringXP = tonumber(thisPlayer:getXp():getXP(Perks.Tailoring))
		LSMetalworkingXP = tonumber(thisPlayer:getXp():getXP(Perks.MetalWelding))
		LSCookingXP = tonumber(thisPlayer:getXp():getXP(Perks.Cooking))
		if thisPlayer:getModData() and thisPlayer:getModData().xpRI then
			thisPlayer:getModData().xpRI = false
		end
	elseif LSCarpentryXP and LSCarpentryXP > 0 and LSCarpentryXP < thisPlayer:getXp():getXP(Perks.Woodwork) then
		dirtChance = 90
		thisCategory = "wood"
		LSCarpentryXP = tonumber(thisPlayer:getXp():getXP(Perks.Woodwork))
	elseif LSTailoringXP and LSTailoringXP > 0 and LSTailoringXP < thisPlayer:getXp():getXP(Perks.Tailoring) then
		dirtChance = 70
		thisCategory = "cloth"
		LSTailoringXP = tonumber(thisPlayer:getXp():getXP(Perks.Tailoring))
	elseif LSMetalworkingXP and LSMetalworkingXP > 0 and LSMetalworkingXP < thisPlayer:getXp():getXP(Perks.MetalWelding) then
		dirtChance = 80
		thisCategory = "metal"
		LSMetalworkingXP = tonumber(thisPlayer:getXp():getXP(Perks.MetalWelding))
	elseif LSCookingXP and LSCookingXP > 0 and LSCookingXP < thisPlayer:getXp():getXP(Perks.Cooking) then
		dirtChance = 60
		thisCategory = "food"
		LSCookingXP = tonumber(thisPlayer:getXp():getXP(Perks.Cooking))
	end

	if LSCarpentryXP == 0 then
		LSCarpentryXP = tonumber(thisPlayer:getXp():getXP(Perks.Woodwork))
	elseif thisCategory == "wood" then
		dirtChance = dirtChance - (tonumber(thisPlayer:getPerkLevel(Perks.Woodwork))*10)
	end
	if LSTailoringXP == 0 then
		LSTailoringXP = tonumber(thisPlayer:getXp():getXP(Perks.Tailoring))
	elseif thisCategory == "cloth" then
		dirtChance = dirtChance - (tonumber(thisPlayer:getPerkLevel(Perks.Tailoring))*10)
	end
	if LSMetalworkingXP == 0 then
		LSMetalworkingXP = tonumber(thisPlayer:getXp():getXP(Perks.MetalWelding))
	elseif thisCategory == "metal" then
		dirtChance = dirtChance - (tonumber(thisPlayer:getPerkLevel(Perks.MetalWelding))*10)
	end
	if LSCookingXP == 0 then
		LSCookingXP = tonumber(thisPlayer:getXp():getXP(Perks.Cooking))
	elseif thisCategory == "food" then
		dirtChance = dirtChance - (tonumber(thisPlayer:getPerkLevel(Perks.Cooking))*10)
	end

	if dirtChance > 0 then
		if thisPlayer:hasTrait(CharacterTrait.SLOPPY) then
			dirtChance = dirtChance + 20
		elseif thisPlayer:hasTrait(CharacterTrait.TIDY) then
			dirtChance = dirtChance - 20
		end
	end

	if LSUtil.canLitter(dirtChance) then
	
		local LitterList = {}

		for k,v in pairs(MainLitterList) do
			if v.category == thisCategory then
				table.insert(LitterList, v)
			end
		end

		local randomNumber = ZombRand(#LitterList) + 1
		local randomSprite = LitterList[randomNumber]
		dirtSprite = randomSprite.name
	
		--thisPlayer:Say(tostring(dirtSprite))
		local x = thisPlayer:getX()
		local y = thisPlayer:getY()
		local z = thisPlayer:getZ()
		--sendClientCommand("LS", "DebugAddLitter", {x, y, z, dirtSolid, dirtSprite})
		if isClient() then
			sendClientCommand("LS", "DebugAddLitter", {x, y, z, dirtSolid, dirtSprite})
		else
			LSAddLitter(x, y, z, dirtSolid, dirtSprite)
		end
	--else
		--thisPlayer:Say("Failed the roll")
	end
	
		LSCarpentryXP = tonumber(thisPlayer:getXp():getXP(Perks.Woodwork))
		LSTailoringXP = tonumber(thisPlayer:getXp():getXP(Perks.Tailoring))
		LSMetalworkingXP = tonumber(thisPlayer:getXp():getXP(Perks.MetalWelding))
		LSCookingXP = tonumber(thisPlayer:getXp():getXP(Perks.Cooking))
		LSCanDoDirtRollTotal = ZombRand(60,120)
	end
	LSCanDoDirtRoll = LSCanDoDirtRoll + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
end

local function dbTimerPerform()
	if not dbDelay then return false; end
	if dbCount > dbDelay then dbCount = 0; return true; end
	dbCount = dbCount + getGameTime():getGameWorldSecondsSinceLastUpdate()
	return false
end

function LSAtEveryTick()
	local thisPlayer = getPlayer()
	
	local playerData = thisPlayer:getModData()
	if thisPlayer ~= nil and playerData.LSMoodles ~= nil then

		if dbTimerPerform() then
			LSrefreshDB(thisPlayer)
			LSrefreshJB(thisPlayer)
			LSrefreshIO(thisPlayer)
			LSrefreshDFM(thisPlayer)
			LSrefreshDF(thisPlayer)
			JukeboxMusicCheck(thisPlayer)
		end

		if thisPlayer:isDead() then return; end

		if not thisPlayer:isAsleep() then--when player is asleep some functions won't play
			if LSUtil.pianoPos and not thisPlayer:isSittingOnFurniture() then LSUtil.pianoPos = false; end
			if SandboxVars.Text.DividerHygiene then
				if thisPlayer:hasTimedActions() and not thisPlayer:isOutside() and not thisPlayer:isInvisible() then
					LSCanDoDirtRollDelayEnd = true
					PlayerCreateDirtForAction(thisPlayer, playerData)
				elseif LSCanDoDirtRollDelayEndCount > 0 then
					PlayerCreateDirtForAction(thisPlayer, playerData)
				elseif LSCanDoDirtRollDelayEnd then
					LSCanDoDirtRollDelayEnd = false
					LSCanDoDirtRollDelayEndCount = 1000
				end
			end
			if SandboxVars.Text.DividerArt then
				CLSInv.UpdateInvScripts(thisPlayer)
			end
		end
	end
end

Events.OnTick.Add(LSAtEveryTick);

local function setDiscoDelay()
	dbDelay = 10/GTLSCheck

end

Events.OnGameStart.Add(setDiscoDelay)