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

LSPingPong = ISBaseTimedAction:derive("LSPingPong")

local volleyTime = 8
local maxVolley_delta = 0.3
local edgeExtension = 0.9
local edgeSpan = 2 * edgeExtension + 1

local bounceFrac_min, bounceFrac_max = 0.55, 1.35
local fadeFrac_start = 0.6

local lateral_max = 0.4
local lateral_wild = 0.9

local overshootGoodOut = 0.3

local ballTex = "media/ui/tennisball.png"
local ballScale = 10

local bounce_sounds = {"Pong_BOUNCE1", "Pong_BOUNCE2", "Pong_BOUNCE3", "Pong_BOUNCE4", "Pong_BOUNCE5", "Pong_BOUNCE6"}
local hit_sounds = {"Pong_HIT1", "Pong_HIT2", "Pong_HIT3", "Pong_HIT4", "Pong_HIT5", "Pong_HIT6"}

local vol_min, vol_max = 0.85, 1.0
local pitch_min, pitch_max = 0.9, 1.1

local restTime_round = 6
local restTime_match = 12
local restTime_anticipation = 3

local paddleItem = "BadmintonRacket"

local function addNumbered(list, prefix, count)
	for n = 1, count do
		local suffix = (n < 10) and ("0"..tostring(n)) or tostring(n)
		table.insert(list, prefix..suffix)
	end
end

local negativeAnim_round = {
	"Bob_Converse_Angry01", "Bob_Converse_Angry02", "Bob_Converse_ShakeHeadNo",
	"Bob_Converse_Dismissive01", "Bob_Converse_Dismissive02",
}
local positiveAnim_round = {
	"Bob_Converse_Acknowledging", "Bob_Converse_AgreeingHandGesture", "Bob_Converse_Agreeing",
	"Bob_EmoteClap", "Bob_EmoteClap02", "Bob_EmoteThumbsUp",
}

local negativeAnim_match = {
	"Bob_ConverseEnd_Frustrated01", "Bob_ConverseEnd_Frustrated02",
	"Bob_ConverseEnd_Frustrated03", "Bob_ConverseEnd_Frustrated04", "Bob_EmoteInsult",
}
local positiveAnim_match = {
	"Bob_Applauding", "Bob_EmoteSalute_Casual", "Bob_EmoteWaveHi", "Bob_EmoteWaveHi02",
	"Bob_DancingChicken", "Bob_DancingClubSidestep", "Bob_DancingHandsInAir",
}

local idleAnim = "Bob_Aim1Hand"
local swingAnim_miss = "Bob_Swing1Hand01_Miss"

local swingAnims_hit = {
	"Bob_Swing1Hand01_CritHit", "Bob_Swing1Hand02_CritHit", "Bob_Swing1Hand03_CritHit",
	"Bob_Swing1Hand01_Hit", "Bob_Swing1Hand01_HitB", "Bob_Swing1Hand01_HitC",
	"Bob_Swing1Hand02_Hit", "Bob_Swing1Hand03_Hit",
}

local negativeVoice_round = {}
addNumbered(negativeVoice_round, "NoUHUH", 2)
addNumbered(negativeVoice_round, "Bored", 2)
addNumbered(negativeVoice_round, "ConfusedHUH", 4)
addNumbered(negativeVoice_round, "IndifferentHMM", 5)
local positiveVoice_round = {}
addNumbered(positiveVoice_round, "IntriguedHMM", 9)
addNumbered(positiveVoice_round, "LikeHMM", 3)
local negativeVoice_match = {}
addNumbered(negativeVoice_match, "ListenBlowOff", 3)
addNumbered(negativeVoice_match, "NegativeOOOU", 4)
local positiveVoice_match = {}
addNumbered(positiveVoice_match, "Woohoo", 3)
addNumbered(positiveVoice_match, "AgreeableUHU", 3)

local function playReaction(actionSelf, character, animList, voiceList)
	if not character then return; end
	if animList and #animList > 0 then
		actionSelf:setActionAnim(animList[LSUtil.rdm_inst:random(#animList)])
	end
	if voiceList and #voiceList > 0 and character.getEmitter then
		local prefix = character:isFemale() and "Woman" or "Man"
		character:getEmitter():playSound(prefix..voiceList[LSUtil.rdm_inst:random(#voiceList)])
	end
end

local function playSwingHit(actionSelf, character)
	local anim = swingAnims_hit[LSUtil.rdm_inst:random(#swingAnims_hit)]
	actionSelf:setActionAnim(anim)
	if character and character.Say then character:Say(anim); end
end

local function playSwingMiss(actionSelf, character)
	actionSelf:setActionAnim(swingAnim_miss)
	if character and character.Say then character:Say(swingAnim_miss); end
end

local function hash01(n)
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

local function playRandomBallSound(character, soundList)
	if not character or not character.getEmitter then return; end
	local soundName = soundList[LSUtil.rdm_inst:random(#soundList)]
	local emitter = character:getEmitter()
	local sound = emitter:playSound(soundName)
	if not sound then return; end
	local volume = vol_min + LSUtil.rdm_inst:random() * (vol_max - vol_min)
	local pitch = pitch_min + LSUtil.rdm_inst:random() * (pitch_max - pitch_min)
	emitter:setVolume(sound, volume)
	emitter:setPitch(sound, pitch)
end

local function getMatchData(args)
	if type(args) == "table" and type(args[1]) == "table" and args[1].event then
		return args[1].event, args[1]
	end
	return nil, (type(args) == "table" and args[1]) or nil
end

local function scanSquareForSprite(s, spriteName)
	if not s or not spriteName then return nil; end
	local objs = s:getObjects()
	for i = 1, objs:size() do
		local o = objs:get(i-1)
		if o and LSUtil.getObjSpriteName(o) == spriteName then
			return o
		end
	end
	return nil
end

-- checks sqr itself then neighbors for an object with required spriteName
local function scanAroundForSprite(sqr, spriteName)
	if not sqr or not spriteName then return nil; end
	local found = scanSquareForSprite(sqr, spriteName)
	if found then return found; end
	for _, dirName in ipairs({"N", "S", "E", "W"}) do
		found = scanSquareForSprite(sqr:getAdjacentSquare(IsoDirections[dirName]), spriteName)
		if found then return found; end
	end
	return nil
end

local function findTableObj(character, spriteName)
	if not character then return nil; end
	return scanAroundForSprite(character:getSquare(), spriteName)
end

function LSPingPong:resolveTableObjs()
	if (self.matchObj and self.opponentObj) or not self.matchArgs then return; end
	local mySpriteName = self.source and self.matchArgs.sN or self.matchArgs.aSN or self.matchArgs.sN
	local otherSpriteName = self.source and self.matchArgs.aSN or self.matchArgs.sN
	if not self.matchObj and mySpriteName then self.matchObj = findTableObj(self.character, mySpriteName); end
	if not self.opponentObj and otherSpriteName and otherSpriteName ~= mySpriteName then
		self.opponentObj = self.matchObj and scanAroundForSprite(self.matchObj:getSquare(), otherSpriteName)
	end
end

function LSPingPong:computeEdges()
	if self.myEdgeX or not self.matchObj or not self.opponentObj then return; end
	local mx, my, mz = self.matchObj:getX(), self.matchObj:getY(), self.matchObj:getZ()
	local ox, oy = self.opponentObj:getX(), self.opponentObj:getY()
	local dx, dy = ox - mx, oy - my
	local dist = math.sqrt(dx*dx + dy*dy)
	local ux, uy = 0, 0
	if dist > 0 then ux, uy = dx/dist, dy/dist; end
	self.myCenterX, self.myCenterY, self.z = mx, my, mz
	self.oppCenterX, self.oppCenterY = ox, oy
	self.myEdgeX, self.myEdgeY = mx - ux*edgeExtension, my - uy*edgeExtension
	self.oppEdgeX, self.oppEdgeY = ox + ux*edgeExtension, oy + uy*edgeExtension
	self.perpX, self.perpY = -uy, ux
end

function LSPingPong:spawnBall()
	if not LSPingPongBall or not getTexture then return; end
	if not self.matchObj or not self.opponentObj then return; end
	local ok, overlay = pcall(function()
		return LSPingPongBall:new(self.character, getTexture(ballTex), {ballScale, ballScale})
	end)
	if not ok or not overlay then return; end
	self.overlay = overlay
	self:computeEdges()
	self.overlay:setShot({
		fromX = self.myEdgeX, fromY = self.myEdgeY,
		toX = self.oppEdgeX, toY = self.oppEdgeY,
		z = self.z, t = 0, endT = 1,
		variant = self.pointIdx * 10 + self.volleyIdx,
	})
	self.overlay:setVisible(true)
	self.overlay:addToUIManager()
end

function LSPingPong:releaseTable()
	if self.matchObj and self.matchObj.getModData and self.matchObj:getModData().movableData then
		self.matchObj:getModData().movableData.inUse = false
	end
end

function LSPingPong:resolvePoint()
	local pointDetails = self.matchData and self.matchData.points[self.pointIdx]
	if not pointDetails then
		self:forceComplete()
		return
	end

	local iWon = (pointDetails.winner == "source") == (self.source == true)

	if self.character.Say then
		--self.character:Say(iWon and "win!" or "lost!")
	end

	self.pointIdx = self.pointIdx + 1
	self.volleyIdx = 1
	self.volleyTimer = 0

	local isMatchPoint = self.pointIdx > #self.matchData.points
	self.resting = true
	self.restEndTimestamp = getTimestamp() + (isMatchPoint and restTime_match or restTime_round)
	self.restFinalize = isMatchPoint
	if isMatchPoint then
		playReaction(self, self.character, iWon and positiveAnim_match or negativeAnim_match, iWon and positiveVoice_match or negativeVoice_match)
	else
		playReaction(self, self.character, iWon and positiveAnim_round or negativeAnim_round, iWon and positiveVoice_round or negativeVoice_round)
	end
end

function LSPingPong:waitToStart()
	self.character:nullifyAiming()
	self.character:setX(self.character:getX())
	self.character:setY(self.character:getY())

	self:resolveTableObjs()

	if self.otherPlayer then
		self.character:faceLocation(self.otherPlayer:getX(), self.otherPlayer:getY())
		self.character:faceLocationF(self.otherPlayer:getX(), self.otherPlayer:getY())
	elseif self.opponentObj then -- fakeRival improv
		self.character:faceLocation(self.opponentObj:getX(), self.opponentObj:getY())
		self.character:faceLocationF(self.opponentObj:getX(), self.opponentObj:getY())
	end

	return self.character:shouldBeTurning()
end

function LSPingPong:isValid()
	return true
end

function LSPingPong:update()

	self.character:nullifyAiming()

	if self.character:getModData().LSInteractionState == "none" and self.otherPlayer then
		self:forceStop()
		return
	elseif (self.character:pressedMovement(true)) and (isKeyDown(Keyboard.KEY_LSHIFT)) then
		self:forceStop()
		return
	end

	if self.resting then
		if getTimestamp() < self.restEndTimestamp then
			return
		end
		self.resting = false
		if self.restFinalize then
			self:forceComplete()
			return
		end
		self.anticipating = true
		self.anticipationEndTimestamp = getTimestamp() + restTime_anticipation
		self:setActionAnim(idleAnim)
	end

	-- aim/ready anim
	if self.anticipating then
		if getTimestamp() < self.anticipationEndTimestamp then
			return
		end
		self.anticipating = false
	end

	if not self.matchData then return; end

	local pointDetails = self.matchData.points[self.pointIdx]
	if not pointDetails then
		self:forceComplete()
		return
	end

	local totalVolleys = pointDetails.volleys + 1
	local isFinalVolley = self.volleyIdx >= totalVolleys
	local myServe = (self.pointIdx % 2 == 1) == (self.source == true)
	local towardOpponent = (self.volleyIdx % 2 == 1) == myServe

	self.volleyTimer = self.volleyTimer + math.min(maxVolley_delta, getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	self:computeEdges()

	if self.overlay and self.myEdgeX and self.oppEdgeX then
		local fromX, fromY = towardOpponent and self.myEdgeX or self.oppEdgeX, towardOpponent and self.myEdgeY or self.oppEdgeY
		local toX, toY = towardOpponent and self.oppEdgeX or self.myEdgeX, towardOpponent and self.oppEdgeY or self.myEdgeY
		local fromCenterX, fromCenterY = towardOpponent and self.myCenterX or self.oppCenterX, towardOpponent and self.myCenterY or self.oppCenterY
		local toCenterX, toCenterY = towardOpponent and self.oppCenterX or self.myCenterX, towardOpponent and self.oppCenterY or self.myCenterY
		local localT = math.min(1, self.volleyTimer / volleyTime)
		local variant = self.pointIdx * 10 + self.volleyIdx
		local frac = bounceFrac_min + hash01(variant + 17.3) * (bounceFrac_max - bounceFrac_min)
		local lateralOffset = (hash01(variant + 53.7) - 0.5) * 2 * lateral_max
		local bounceX = fromCenterX + (toCenterX - fromCenterX) * frac + self.perpX * lateralOffset
		local bounceY = fromCenterY + (toCenterY - fromCenterY) * frac + self.perpY * lateralOffset
		local bounceT = (edgeExtension + frac) / edgeSpan

		local shot = {
			fromX = fromX, fromY = fromY, toX = toX, toY = toY,
			bounceX = bounceX, bounceY = bounceY, bounceT = bounceT,
			z = self.z, variant = variant, alpha = 1,
		}
		if isFinalVolley and pointDetails.faultType == "net" then
			shot.endT, shot.hasBounce = 0.5, false
			local missT = math.min(1, localT / fadeFrac_start)
			shot.t = missT * shot.endT
			shot.dropped = (missT >= 1)
			shot.alpha = 1 - math.max(0, (localT - fadeFrac_start) / (1 - fadeFrac_start))
		elseif isFinalVolley and pointDetails.faultType == "badOut" then
			shot.endT, shot.hasBounce, shot.wild = 0.55, false, true
			local wildLateral = (hash01(variant + 71.3) - 0.5) * 2 * lateral_wild
			shot.toX = toX + self.perpX * wildLateral
			shot.toY = toY + self.perpY * wildLateral
			local missT = math.min(1, localT / fadeFrac_start)
			shot.t = missT * shot.endT
			shot.dropped = (missT >= 1)
			shot.alpha = 1 - math.max(0, (localT - fadeFrac_start) / (1 - fadeFrac_start))
		elseif isFinalVolley and pointDetails.faultType == "goodOut" then
			shot.endT, shot.hasBounce = 1 + overshootGoodOut / edgeSpan, true
			shot.t = localT * shot.endT
			shot.alpha = 1 - math.max(0, (localT - fadeFrac_start) / (1 - fadeFrac_start))
		else
			shot.endT, shot.hasBounce = 1, true
			shot.t = localT
		end
		self.overlay:setShot(shot)

		if shot.hasBounce and not self.bounceSoundPlayed and shot.t >= bounceT then
			self.bounceSoundPlayed = true
			playRandomBallSound(self.character, bounce_sounds)
		end
	end

	if self.volleyTimer >= volleyTime then
		self.volleyTimer = 0
		self.bounceSoundPlayed = false
		if isFinalVolley then
			if pointDetails.faultType == "goodOut" then
				if towardOpponent then
					playSwingHit(self, self.character)
				else
					playSwingMiss(self, self.character)
				end
			elseif towardOpponent then
				playSwingMiss(self, self.character)
			end
		else
			playRandomBallSound(self.character, hit_sounds)
			if not towardOpponent then
				playSwingHit(self, self.character)
			end
		end
		self.volleyIdx = self.volleyIdx + 1
		if self.volleyIdx > totalVolleys then
			self:resolvePoint()
		end
	end
end

function LSPingPong:start()

	if self.otherPlayer then
		self.character:getModData().LSInteractionState =
			(self.character:getModData().LSInteractionState == "sourceStoppedWaiting") and "none" or "doingAction"
	end

	self:setOverrideHandModels(paddleItem, nil)
	self.character:setBlockMovement(true)

	if not self.matchData then
		local pending = self.character:getModData().LSObjInteractionArgsPending
		self.character:getModData().LSObjInteractionArgsPending = false
		if pending then
			self.matchData = pending.event
			self.matchArgs = pending
		end
	end

	if not self.matchData or not self.matchData.points or #self.matchData.points == 0 then
		self:forceStop()
		return
	end

	self:resolveTableObjs()

	self.anticipating = true
	self.anticipationEndTimestamp = getTimestamp() + restTime_anticipation
	self:setActionAnim(idleAnim)
	self:spawnBall()
end

function LSPingPong:stop()

	self.character:setBlockMovement(false)
	self:setOverrideHandModels(nil, nil)
	self:releaseTable()

	if self.otherPlayer and self.character:getModData().LSInteractionState == "doingAction" then
		sendClientCommand(self.character, "LS", "StopOrStartInteraction", {self.otherPlayer:getOnlineID(), "none"})
	end
	self.character:getModData().LSInteractionState = "none"

	if self.overlay then self.overlay:close(); self.overlay = nil; end

	ISBaseTimedAction.stop(self);
end

function LSPingPong:perform()

	self.character:setBlockMovement(false)
	self.character:getModData().LSInteractionState = "none"
	self:setOverrideHandModels(nil, nil)
	self:releaseTable()

	if self.overlay then self.overlay:close(); self.overlay = nil; end

	if self.matchData and self.matchData.winner then
		-- maybe track plays for a hidden skill later
		--[[
		local iWon = (self.matchData.winner == "source") == (self.source == true)
		local charData = self.character:getModData()
		if iWon then
			charData.LSPingPongWins = (charData.LSPingPongWins or 0) + 1
		else
			charData.LSPingPongLosses = (charData.LSPingPongLosses or 0) + 1
		end
		]]--
	end

	ISBaseTimedAction.perform(self);
end

function LSPingPong:complete()
	return true
end

function LSPingPong:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 2000
end

function LSPingPong:new(character, otherPlayer, args)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.otherPlayer = otherPlayer
	o.args = args
	local matchData, matchArgs = getMatchData(args)
	o.matchData = matchData
	o.matchArgs = matchArgs
	o.matchObj = nil
	o.source = (type(args) == "table" and args[2]) and true or false
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	o.pointIdx = 1
	o.volleyIdx = 1
	o.volleyTimer = 0
	o.bounceSoundPlayed = false
	o.resting = false
	o.restEndTimestamp = 0
	o.restFinalize = false
	o.anticipating = false
	o.anticipationEndTimestamp = 0
	o.myCenterX, o.myCenterY = nil, nil
	o.oppCenterX, o.oppCenterY = nil, nil
	o.myEdgeX, o.myEdgeY = nil, nil
	o.oppEdgeX, o.oppEdgeY = nil, nil
	o.perpX, o.perpY = nil, nil
	o.z = nil
	o.overlay = nil
	return o;
end

return LSPingPong
