-- NPC art over privately observed installed stations and exact carried materials.
-- Isolated Lifestyle source cores retain selection, physical effects and timing.
-- Player UI presentation is captured privately; unbound XP requests remain pending.
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
SAO = SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end
SAO.LeisureArt = SAO.LeisureArt or {}
local A = SAO.LeisureArt
if A.reset then A.reset("module-reload") end
local runtime = {}
local REVISIONS = {canvas="e79e7faf4523849380d2570cab16f8606424d11f5a61dff9523cd609f949fd67",sculpture="3a70b6ffd14b9a593e4e403eafbbcb0280d2519902027439f9ef4c0252a88f06",appraise="654574b6512ae39efab3658f781d6150b2f9a02259ee6235e9f7d84f185139d9"}
local SOURCE = "LifestyleHobbies"
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function plain(value, depth)
    depth=depth or 0
    if type(value)=="string" or type(value)=="boolean" then return value end
    if type(value)=="number" then return finite(value) and value or nil end
    if type(value)~="table" or depth>8 then return nil end
    local out={} for key,item in pairs(value) do
        if type(key)=="string" or type(key)=="number" then out[key]=plain(item,depth+1) end
    end return out
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end return true
end
local function record(id) return SAO.Identity and SAO.Identity.get(id) end
local function hours() return SAO.History.countyHours() end
local function live(id,body)
    return record(id) and not record(id).dead and body and SAO.Needs
        and SAO.Needs.ownsRecoveryBody(id,body)==true and not body:isDead()
        and not body:isAsleep() and body:isExistInTheWorld()
end
local function activeFor(body)
    local id=body and body:getModData().SAOPersonId
    local active=id and runtime[id]
    return active and active.body==body and live(id,body)
        and record(id).artLeisureWork==active.work
        and active.work.status=="active" and active.started and active.callback
        and active.body:getModData().SAOExternalToken==active.work.bodyToken and active or nil
end
local function sample(body)
    local out={}
    for _,name in ipairs({"BOREDOM","UNHAPPINESS","STRESS","ENDURANCE","FATIGUE"}) do
        local stat=CharacterStat and CharacterStat[name]
        local value=stat and body:getStats():get(stat)
        if finite(value) then out[name]=value end
    end return out
end
local function isolatedChange(active,before,after)
    local measured=active.work.measuredEffects
    for name,value in pairs(before) do
        if finite(after[name]) then measured.sourceDeltas[name]=(measured.sourceDeltas[name] or 0)+after[name]-value end
    end
    measured.sourceMoodCalls=measured.sourceMoodCalls+1
end
local function recordPresentation(character,values)
    local active=activeFor(character)
    if active then active.presentation=plain(values) end
end
-- These lexical receivers affect only the private NPC cores below.
local function getSoundManager() return {playUISound=function() end} end
local function sendClientCommand(character,module,command,args)
    local active=activeFor(character)
    if not active or module~="LS" or command~="AddXP" or type(args)~="table"
        or args[1]~="Art" or not finite(args[2]) or args[2]<=0 then error("unbound-npc-art-source-command") end
    local pending=active.work.pendingSkillEffects
    pending.count,pending.totalRequested=pending.count+1,pending.totalRequested+args[2]
    local r=record(active.work.actorId)
    r.artSkillSequence=(r.artSkillSequence or 0)+1
    local row={sequence=r.artSkillSequence,actorId=active.work.actorId,workId=active.work.workId,
        purposeId=active.work.purposeId,workSequence=active.work.sequence,
        perkName=args[1],amount=args[2],atHours=hours(),status="requested",
        sourceId=active.work.sourceId,revision=active.work.revision,
        nativeProgress={sourceCallback=active.callback,sourceInvocationSequence=active.invocations,
            actionStarted=active.started==true,jobDelta=active.action:getJobDelta()}}
    active.skillRequests=active.skillRequests or {}
    active.skillRequests[row.sequence]=plain(row)
    r.artSkillRequests=r.artSkillRequests or {}
    r.artSkillRequests[#r.artSkillRequests+1]=plain(row)
    if #r.artSkillRequests>256 then table.remove(r.artSkillRequests,1) end
    pending.requests[#pending.requests+1]=row
    if #pending.requests>256 then table.remove(pending.requests,1);pending.omittedRequests=pending.omittedRequests+1 end
    local skill=SAO.LeisureSkill
    if skill and skill.consume then
        local ok,result,reason=pcall(skill.consume,active.work.actorId,character,"SAO.LeisureArt",active.work.sequence,row.sequence)
        if ok and result==true then pending.consumed=(pending.consumed or 0)+1
        else pending.lastRefusal=ok and reason or "native-skill-owner-unavailable" end
    end
end
local LSUtil = {
    getPercentage=function(...) return _G.LSUtil.getPercentage(...) end,
    changeCharacterMood=function(character,...)
        local active=activeFor(character)
        if not active then error("foreign-npc-art-mood") end
        local before=sample(character)
        _G.LSUtil.changeCharacterMood(character,...)
        isolatedChange(active,before,sample(character))
    end,
    useItem=function(item,character,...)
        local active=activeFor(character)
        if not active then error("foreign-npc-art-material") end
        local before=item:getCurrentUses()
        _G.LSUtil.useItem(item,character,...)
        local after=item:getCurrentUses()
        if finite(before) and finite(after) and after<=before then
            local values=active.work.nativeProgress.materialUses
            local key=tostring(item:getID())
            values[key]=(values[key] or 0)+before-after
        end
    end,
}

-- BEGIN INSTALLED SOURCE shared/TimedActions/LSCanvasPaintingAction.lua
local canvasCore = (function()
local Core = ISBaseTimedAction:derive("SAONpcArtcanvasCore")
local function adjustStats(character, painting, xp)

	local PlayerArtLevel = character:getPerkLevel(Perks.Art)

	if painting["size"] == "medium" then xp[1] = xp[1]*2; xp[2] = xp[2]*2;
	elseif painting["size"] == "large" then xp[1] = xp[1]*3; xp[2] = xp[2]*3; end

	if painting["level"] > 1 then xp[1] = xp[1]*painting["level"]; xp[2] = xp[2]*painting["level"]; end

	--DEFINES
	LSUtil.changeCharacterMood(character, "Boredom", -1, false, false)
	
	local xpChange = (ZombRand(xp[1],xp[2]))/10
	if (xpChange > 0) and (PlayerArtLevel < 10) then
		sendClientCommand(character, "LS", "AddXP", {"Art", xpChange})
		--character:getXp():AddXP(Perks.Art, xpChange)
	end
end

local function getNewPalette(thisPlayer)
	local it = thisPlayer:getInventory():getItems()
	local item, newPalette
	for j = 0, it:size()-1 do
		item = it:get(j);
		if item and (item:getType()) and (item:getType() == "paintPalette") then newPalette = item; break; end
	end
	return newPalette
end

local function shouldChangePaintSound(character, sound)
	if sound and sound ~= 0 then
		if character:getEmitter():isPlaying(sound) then return false; end
	end
	return true
end

local function getSoundTable(state)
	if state == "Paint" then
		return {"Easel_Paint1","Easel_Paint2","Easel_Paint3","Easel_Paint4","Easel_Paint5"}
	end

	return {"Easel_Brush1","Easel_Brush2","Easel_Brush3","Easel_Brush4","Easel_Brush5"}
end

local function getNewSound(state, oldSound)
	local audioTable = getSoundTable(state)
	if oldSound then
		for n=1, #audioTable do
			if audioTable[n] == oldSound then table.remove(audioTable, n); break; end
		end
	end

	return audioTable[ZombRand(#audioTable)+1]
end

local function getEaselFacing(easel)
	local facing
	local properties = easel:getSprite():getProperties()
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	return facing
end

local function getMarkingSpriteName(easel, size)
	local facing = getEaselFacing(easel)
	local t = LSArt.Markings[facing]
	local newTable
	for k, v in ipairs(t) do
		if v.size == size then
			newTable = v.sprites
		end
	end
	return newTable[ZombRand(#newTable)+1]
end

local function updateCanvasSprite(easel, newSprite, stage, newProgress)
	if stage == 0.5 then newSprite = getMarkingSpriteName(easel, newSprite); end
	easel:getModData().stage = stage
	if stage < 4 then easel:getModData().progress = newProgress; end
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{easel:getX(),easel:getY(),easel:getZ(),easel:getSprite():getName()}, newSprite})
		sendClientCommand("LS", "ModifyObjData", {{easel:getX(),easel:getY(),easel:getZ(),easel:getSprite():getName()}, false, easel:getModData()})
	else
		easel:setOverlaySprite(newSprite, isClient())
	end
end

local function shouldUpdateCanvas(easel, painting, currentDuration, jobProgress, stage)
	if stage == 4 then return; end
	local val = 0
	local currentProgress = currentDuration - jobProgress
	if currentProgress < 0 then
		val = 100
	elseif painting and painting.duration and currentProgress then
		local realProgress = painting.duration - currentProgress
		val = LSUtil.getPercentage(painting.duration,realProgress, 2, false)
	end

	if val < 5 then return; end
	
	if (val >= 1) and (stage == 0) then updateCanvasSprite(easel, painting["size"], 0.5, currentProgress);
	elseif (val >= 25) and (stage == 0.5) then updateCanvasSprite(easel, painting["stage1"], 1, currentProgress);
	elseif (val >= 50) and (stage == 1) then updateCanvasSprite(easel, painting["stage2"], 2, currentProgress);
	elseif (val >= 75) and (stage == 2) then updateCanvasSprite(easel, painting["stage3"], 3, currentProgress);
	elseif (val >= 100) then updateCanvasSprite(easel, painting["stage4"], 4);
	end
end

function Core:isValid()
	return true;
end

function Core:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.easel);
	return self.character:shouldBeTurning();
end

local function paintPaletteHasUses(palette)
	--if palette:getCurrentUses() and (palette:getCurrentUses() > 0) then return true; end
	if palette:isInPlayerInventory() then return true; end
	return false
end

function Core:update()

	if self.easel:getModData().stage == 4 then self:forceComplete(); end
	self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	
	if self.animChangeCount > self.animChangeTotal then
		self.animChangeCount = 0
		if self.currentState == "Paint" then self.currentState = "Brush"; self.animChangeTotal = 15+ZombRand(10);
		elseif self.currentState == "Brush" then
			if not paintPaletteHasUses(self.paintItems.palette) then
				self.paintItems.palette = getNewPalette(self.character)
				if not self.paintItems.palette then self:forceStop(); end
			end
			self.currentState = "Paint"; self.animChangeTotal = 2+ZombRand(3);
		end
	end

	if self.count >= self.countTotal then
		if self.character:isSitOnGround() then self:forceStop(); end
		self.count = 0
		self.animChangeCount = self.animChangeCount+1
		
		self.soundName = getNewSound(self.currentState, self.soundName)
		self.sound = self.character:getEmitter():playSound(self.soundName)
		self:setActionAnim("Bob_Easel_"..self.currentState)

		if self.currentState == "Brush" then shouldUpdateCanvas(self.easel, self.painting, self.maxTime, self.jobProgress, self.easel:getModData().stage);
		else LSUtil.useItem(self.paintItems.palette, self.character, self.chance);
		end
		
		adjustStats(self.character, self.painting, {0,4})
	end
	self.jobProgress = self:getJobDelta()*self.maxTime
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function Core:start()
	self:setOverrideHandModels(self.paintItems.brush, self.paintItems.palette)
	self:setActionAnim("Bob_Easel_Paint")
	self.chance = LSArt.getUseChance(self.character, 20)
end

function Core:stop()
	self.easel:getModData().progress = (self.maxTime - self.jobProgress)
	if isClient() then sendClientCommand("LS", "ModifyObjData", {{self.easel:getX(),self.easel:getY(),self.easel:getZ(),self.easel:getSprite():getName()}, false, self.easel:getModData()}); end

    ISBaseTimedAction.stop(self);		
end

local function getPerformSound(quality)
	local sound = "UI_Painting_Complete"
	if quality == "IGUI_PaintingQuality_Masterpiece" then
		local soundTable = {"UI_Masterpiece1","UI_Masterpiece2","UI_Masterpiece3"}
		sound = soundTable[ZombRand(#soundTable)+1]
	end
	return sound
end

local function doNote(character, quality, texture)
	local choice = ZombRand(2)+1
	recordPresentation(character, {quality=quality, texture=texture, noteVariant=choice})
end

local function getPaintingTex(easel, painting)
	return painting["stage"..tostring(easel:getModData().stage)]
end

function Core:perform()
	updateCanvasSprite(self.easel, self.painting["stage4"], 4)
	adjustStats(self.character, self.painting, {50,150})
	local soundName = getPerformSound(self.painting["quality"])
	getSoundManager():playUISound(soundName)

	local paintingTexture = getPaintingTex(self.easel, self.painting)
	doNote(self.character, self.painting["quality"], paintingTexture)

	ISBaseTimedAction.perform(self);
end

function Core:complete()

	return true
end

function Core:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function Core:new(character, easel, painting, actionTime, paintItems)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.easel = easel
	o.painting = painting
	o.paintItems = paintItems
	o.actionTime = actionTime
	o.ignoreDynamicTime = true;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.count = 0
	o.countTotal = 15
	o.animChangeCount = 0
	o.animChangeTotal = 3
	o.currentState = "Paint"
	o.sound = 0
	o.soundName = false
	return o;
end

return Core
end)()
-- END INSTALLED SOURCE shared/TimedActions/LSCanvasPaintingAction.lua
-- BEGIN INSTALLED SOURCE shared/TimedActions/LSSculptingAction.lua
local sculptureCore = (function()
local Core = ISBaseTimedAction:derive("SAONpcArtsculptureCore")
local function getRepeatSplashSpriteTable(sprite, alphaStage)
	local t = {
		LS_Sculptures_26 = {stage1="LS_Sculptures_32",stage2="LS_Sculptures_40",stage3="LS_Sculptures_48"},
		LS_Sculptures_27 = {stage1="LS_Sculptures_33",stage2="LS_Sculptures_41",stage3="LS_Sculptures_49"},
		LS_Sculptures_28 = {stage1="LS_Sculptures_34",stage2="LS_Sculptures_42",stage3="LS_Sculptures_50"},
		LS_Sculptures_29 = {stage1="LS_Sculptures_35",stage2="LS_Sculptures_43",stage3="LS_Sculptures_51"},
		LS_Sculptures_30 = {stage1="LS_Sculptures_36",stage2="LS_Sculptures_44",stage3="LS_Sculptures_52"},
		LS_Sculptures_31 = {stage1="LS_Sculptures_37",stage2="LS_Sculptures_45",stage3="LS_Sculptures_53"},
	}
	return t[sprite]['stage'..tostring(alphaStage)]
end

local function getSplashSpriteTable()
	return {"LS_Sculptures_26","LS_Sculptures_27","LS_Sculptures_28","LS_Sculptures_29","LS_Sculptures_30","LS_Sculptures_31"}
end

local function getNewSplashSprite(oldSprite)
	local t = getSplashSpriteTable()
	for n=1, #t do
		if t[n] == oldSprite then table.remove(t, n); break; end
	end
	return t[ZombRand(#t)+1]
end

local function getAndStopSound(character, sound, soundL)
	if sound and (sound ~= 0) and character:getEmitter():isPlaying(sound) then character:getEmitter():stopSound(sound); end
	if soundL and (soundL ~= 0) and character:getEmitter():isPlaying(soundL) then character:getEmitter():stopSound(soundL); end
end

local function adjustStats(character, artwork, xp)

	local PlayerArtLevel = character:getPerkLevel(Perks.Art)
	
	if artwork["size"] == "medium" then xp[1] = xp[1]*2; xp[2] = xp[2]*2;
	elseif artwork["size"] == "large" then xp[1] = xp[1]*3; xp[2] = xp[2]*3; end

	if artwork["level"] > 1 then xp[1] = xp[1]*artwork["level"]; xp[2] = xp[2]*artwork["level"]; end

	--DEFINES
	--local boredomChange, stressChange, unhappynessChange, neckPainChange, xpChange = adjustStatsGetChanges(Aversion, Buffer, varResult, currentPain, WasTaught, PlayerMeditationLevel)
	LSUtil.changeCharacterMood(character, "Boredom", -1, false, false)
	
	local xpChange = (ZombRand(xp[1],xp[2]))/10
	if (xpChange > 0) and (PlayerArtLevel < 10) then
		sendClientCommand(character, "LS", "AddXP", {"Art", xpChange})
		--character:getXp():AddXP(Perks.Art, xpChange)
	end
end

local function getNewSound(oldSound, soundTable)
	local t = soundTable
	if oldSound then
		t = {}
		for n=1, #soundTable do
			if soundTable[n] ~= oldSound then table.insert(t, soundTable[n]); end
		end
	end

	return t[ZombRand(#t)+1]
end

local function updateArtworkSprite(station, newSprite, stage, newProgress)
	station:getModData().stage = stage
	if stage < 4 then station:getModData().progress = newProgress; end
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{station:getX(),station:getY(),station:getZ(),station:getSprite():getName()}, newSprite})
		sendClientCommand("LS", "ModifyObjData", {{station:getX(),station:getY(),station:getZ(),station:getSprite():getName()}, false, station:getModData()})
	else
		station:setOverlaySprite(newSprite, true)
	end
end

local function shouldUpdateWork(station, artwork, currentDuration, jobProgress, stage)
	if stage == 4 then return; end
	local currentProgress = currentDuration - jobProgress
	local val = 0
	if currentProgress < 0 then
		val = 100
	elseif artwork and artwork.duration and currentProgress then
		local realProgress = artwork.duration - currentProgress
		val = LSUtil.getPercentage(artwork.duration,realProgress, 2, false)
	end
	
	if val < 5 then return; end
	
	if (val >= 25) and (stage == 0) then updateArtworkSprite(station, artwork["stage1"], 1, currentProgress);
	elseif (val >= 50) and (stage == 1) then updateArtworkSprite(station, artwork["stage2"], 2, currentProgress);
	elseif (val >= 75) and (stage == 2) then updateArtworkSprite(station, artwork["stage3"], 3, currentProgress);
	elseif (val >= 100) then updateArtworkSprite(station, artwork["result"], 4);
	end
end

function Core:isValid()
	return true;
end

function Core:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.station);
	return self.character:shouldBeTurning();
end

local function getMetalSwitch(soundLoopName, workItems)
	local anim, sound, item1, item2 = "Bob_Sculpt_Metal_", "BlowTorch", workItems['item1'], workItems['item2']
	if soundLoopName == sound then anim, sound, item1, item2 = "Bob_Sculpt_MetalB_", "Hammering_METAL", workItems['item2'], false; end
	return anim, sound, item1, item2
end

local function getPropaneUses(item)
	return item and item:getCurrentUsesFloat() > 0
end

function Core:update()

	if not self.station:getModData().style then self:forceStop(); end -- Ice Melt
	if self.station:getModData().stage == 4 then self:forceComplete(); end
	self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)

	if self.animChangeCount > self.animChangeTotal then
		self.animChangeCount = 0
		if self.currentState == "Wait" then self.currentState = "Action"; self.animChangeTotal = 15+ZombRand(10); self.countS = self.countTotalS;
		elseif self.currentState == "Action" then
			self.currentState = "Wait"; self.animChangeTotal = 2+ZombRand(3);
		end
		if self.isMetal and (self.currentState == "Action") then
			self.animName, self.soundLoopName, self.handItem1, self.handItem2 = getMetalSwitch(self.soundLoopName, self.workItems)
		elseif self.isMetal and (self.currentState == "Wait") then
			getAndStopSound(self.character, self.sound, false)
		end
	end

	if self.count >= self.countTotal then
		if self.character:isSitOnGround() then self:forceStop(); end
		self.count = 0
		if self.isMetal and (self.currentState == "Action") and (self.animChangeCount == 0) then
			self:setOverrideHandModels(self.handItem1, self.handItem2)
			if self.soundLoopName == "BlowTorch" then
				if not getPropaneUses(self.item) then self:forceStop(); end
				self.sound = self.character:getEmitter():playSound(self.soundLoopName)
				LSUtil.useItem(self.item, self.character, self.chance)
			end
		end
		self.animChangeCount = self.animChangeCount+1
		self:setActionAnim(self.animName..self.currentState)
		self.countS = self.countS+1
		if self.countS >= self.countTotalS then
			self.countS = 0
			if self.soundTable and (self.currentState ~= "Wait") then
				if self.isMetal then
					if self.soundLoopName == "Hammering_METAL" then self.sound = self.character:getEmitter():playSound(self.soundLoopName); end
				else
					self.soundName = getNewSound(self.soundName, self.soundTable)
					self.sound = self.character:getEmitter():playSound(self.soundName)
				end
			end
		end
		if self.currentState == "Action" then shouldUpdateWork(self.station, self.artwork, self.maxTime, self.jobProgress, self.station:getModData().stage); 
		else getAndStopSound(self.character, self.sound, false); end
		
		adjustStats(self.character, self.artwork, {0,4})

		self.objAlpha = math.floor(self.objAlpha+1)

		if self.objAlpha < 4 then
			--self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],self.objAlpha)
			local repeatSprite = getRepeatSplashSpriteTable(self.splashSprite, self.objAlpha)
			self.splashObj:setSprite(repeatSprite)
			self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],1)
		elseif self.currentState == "Action" then
			self.splashSprite = getNewSplashSprite(self.splashSprite)
			self.splashObj:setSprite(self.splashSprite)
			self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],1)
			self.objAlpha = 0
		end

	end
	
	self.jobProgress = self:getJobDelta()*self.maxTime
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

local function getStyleParams(style)
	local styleParams = {
		Hedge = {anim = "Bob_Sculpt_Hedge_", soundTime = 4, splashColor = {0, 0.4, 0.1}, soundLoop = "Chainsaw_LOOP", soundTable = {"Chainsaw_Cut1","Chainsaw_Cut2","Chainsaw_Cut3","Chainsaw_Cut4","Chainsaw_Cut5"}},
		Wood  = {anim = "Bob_Sculpt_Wood_", soundTime = 3, splashColor = {1, 0.8, 0.5}, soundLoop = false, soundTable = {"Chisel_WOOD1","Chisel_WOOD2","Chisel_WOOD3","Chisel_WOOD4","Chisel_WOOD5","Chisel_WOOD6"}},
		Metal = {anim = "Bob_Sculpt_Metal_", soundTime = 3, splashColor = {0.6, 0.6, 0.6}, soundLoop = "BlowTorch", soundTable = "Hammering_METAL"},
		Ice   = {anim = "Bob_Sculpt_Hedge_", soundTime = 4, splashColor = {0.9, 0.96, 1}, soundLoop = "Chainsaw_LOOP", soundTable = {"Chainsaw_Cut1","Chainsaw_Cut2","Chainsaw_Cut3","Chainsaw_Cut4","Chainsaw_Cut5"}},
		Stone = {anim = "Bob_Sculpt_Wood_", soundTime = 3, splashColor = {0.8, 0.8, 0.8}, soundLoop = false, soundTable = {"Chisel_STONE1","Chisel_STONE2","Chisel_STONE3","Chisel_STONE4","Chisel_STONE5","Chisel_STONE6","Chisel_STONE7","Chisel_STONE8"}},
	}
	local params = styleParams[style] or {}
	return params.anim or "Bob_Sculpt_Wood_", params.soundTime or 15, params.splashColor or {1, 1, 1}, params.soundLoop or false, params.soundTable
end

local function getPropItem()
	local prop
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and item:getFullName() and ((item:getFullName() == "Chainsaw") or (item:getFullName() == "Lifestyle.Chainsaw")) then
			prop = item:InstanceItem(item:getFullName())
			break
        end
    end
	return prop
end

local function getSpecialItem(style)
	local hasSI = {Hedge=1,Ice=1}
	return hasSI[style] or false
end

local function getHandItems(artwork, workItems)
	local h1, h2, specialItem = workItems['item1'], workItems['item2'], getSpecialItem(artwork.style)
	if specialItem then h1, h2 = getPropItem(), false; end
	return h1, h2
end

function Core:start()
	self.handItem1, self.handItem2 = getHandItems(self.artwork, self.workItems)
	self.isMetal = self.artwork.style and self.artwork.style == "Metal"
	self.animName, self.countTotalS, self.splashColor, self.soundLoopName, self.soundTable = getStyleParams(self.artwork.style)
	self.countS = self.countTotalS
	if self.isMetal then self.item = self.workItems['item1']; self.chance = LSArt.getUseChance(self.character, 30); end
	if self.soundLoopName and (not self.isMetal) then self.soundLoop = self.character:getEmitter():playSound(self.soundLoopName); end
	self:setOverrideHandModels(self.handItem1, self.handItem2)
	self:setActionAnim(self.animName.."Action")
	
	self.splashObj = IsoObject.new(self.tileSqr, self.splashSprite)
	self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],1)
	self.tileSqr:AddTileObject(self.splashObj)
	--self.useDelta = getUseDelta(self.character)
end

function Core:stop()
	self.station:getModData().progress = (self.maxTime - self.jobProgress)
	if isClient() then
		sendClientCommand("LS", "ModifyObjData", {{self.station:getX(),self.station:getY(),self.station:getZ(),self.station:getSprite():getName()}, false, self.station:getModData()})
	else
		self.tileSqr:transmitRemoveItemFromSquare(self.splashObj)
	end
	self.tileSqr:RemoveTileObject(self.splashObj)
	
	getAndStopSound(self.character, self.sound, self.soundLoop)
	
    ISBaseTimedAction.stop(self);		
end

local function getPerformSound(quality, isKnownArtwork)
	local sound = "UI_Painting_Complete"
	if quality == "IGUI_PaintingQuality_Masterpiece" then
		local soundTable = {"UI_Masterpiece1","UI_Masterpiece2","UI_Masterpiece3"}
		sound = soundTable[ZombRand(#soundTable)+1]
	elseif not isKnownArtwork then
		sound = "UI_Artwork_New"
	end
	return sound
end

local function doNote(character, quality, texture, known)
	local choice = ZombRand(2)+1
	recordPresentation(character, {quality=quality, texture=texture, known=known, noteVariant=choice})
end

function Core:perform()
	local resultSpriteName = self.artwork["result"]
	updateArtworkSprite(self.station, resultSpriteName, 4)
	adjustStats(self.character, self.artwork, {50,150})
	getAndStopSound(self.character, self.sound, self.soundLoop)
	if not self.character:getModData()['KnownArtworkList'] then self.character:getModData()['KnownArtworkList'] = {}; end
	local isKnownArtwork = self.character:getModData()['KnownArtworkList'][resultSpriteName]
	local soundName = getPerformSound(self.artwork["quality"], isKnownArtwork)
	getSoundManager():playUISound(soundName)

	if not isKnownArtwork then
		self.character:getModData()['KnownArtworkList'][resultSpriteName] = true
		LSSync.updateClientData(self.character, self.character:getModData())
	end

	if not isClient() then self.tileSqr:transmitRemoveItemFromSquare(self.splashObj); end
	self.tileSqr:RemoveTileObject(self.splashObj)

	doNote(self.character, self.artwork["quality"], resultSpriteName, isKnownArtwork)

	ISBaseTimedAction.perform(self);
end

function Core:complete()

	return true
end

function Core:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function Core:new(character, station, artwork, actionTime, workItems)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.station = station
	o.artwork = artwork
	o.actionTime = actionTime
	o.workItems = workItems
	o.ignoreDynamicTime = true;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.count = 0
	o.countTotal = 15
	o.countS = 0
	o.countTotalS = 15
	o.animChangeCount = 0
	o.animChangeTotal = 3
	o.currentState = "Action"
	o.animName = "Bob_Sculpt_Wood_"
	o.sound = 0
	o.soundLoop = 0
	o.soundTable = false
	o.soundName = false
	o.splashObj = false
	o.splashColor = false
	o.splashSprite = "LS_Sculptures_26"
	o.tileSqr = o.station:getSquare()
	o.objAlpha = 0
	o.isMetal = false
	o.soundLoopName = false
	o.handItem1 = false
	o.handItem2 = false
	o.item = false
	o.useDelta = 3
	o.oldUseDelta = false
	return o;
end

return Core
end)()
-- END INSTALLED SOURCE shared/TimedActions/LSSculptingAction.lua
-- BEGIN INSTALLED SOURCE shared/TimedActions/LSCanvasAppraiseAction.lua
local appraiseCore = (function()
local Core = ISBaseTimedAction:derive("SAONpcArtappraiseCore")
local function doNote(character, texture, guess, qualityType)
	recordPresentation(character, {texture=texture, qualityGuess=guess, qualityType=qualityType})
end

local function getPaintingTex(easel, painting)
	return painting["stage"..tostring(easel:getModData().stage)]
end

local function getQualityRange()
	-- painting quality table from worst to best
	return {"IGUI_PaintingQuality_Awful","IGUI_PaintingQuality_Poor","IGUI_PaintingQuality_Shoddy","IGUI_PaintingQuality_Normal","IGUI_PaintingQuality_Good","IGUI_PaintingQuality_Excellent","IGUI_PaintingQuality_Impressive","IGUI_PaintingQuality_Wondrous","IGUI_PaintingQuality_Masterpiece"}
end

local function getQualityIndex(quality, qualityRange)
	local index
    for i, q in ipairs(qualityRange) do
        if q == quality then
            index = i
            break
        end
    end
	return index
end

local function getMarginBounds(qualityRange, precision, index)
	local lowerBound, upperBound
	local num = 3
	if precision == "medium" then num = 2; elseif precision == "high" then num = 1; end

	lowerBound = math.max(index-num, 1) -- highest number
	upperBound = math.min(index+num, #qualityRange) -- lowest number

	return lowerBound, upperBound
end

local function getQualityType(val)
	if val < 3 then return "Bad"; end
	if val > 5 then return "Good"; end
	return "Neutral"
end

local function getMargin(quality, precision)
	local qualityRange = getQualityRange()
	local index = getQualityIndex(quality, qualityRange)
	local lowerBound, upperBound = getMarginBounds(qualityRange, precision, index)
	local randomIndex = ZombRand(lowerBound, upperBound + 1)
	local qualityType = getQualityType(randomIndex)
	return qualityRange[randomIndex], qualityType
end

local function LSCYGetAnimSound()
	return {
		{name="Bob_Converse_Agreeing",animTime=100,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_Converse_AgreeingHandGesture",animTime=100,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_Converse_Listening01",animTime=120,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_Converse_Acknowledging",animTime=100,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_PullAtCollar",animTime=45,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_PullAtCollar2H",animTime=45,soundType="IntriguedHmm",soundTime=0},
	}
end

local function doIdxVariation(idx, limit)
	local variation = ZombRand(2) == 0 and -1 or 1
	local newIdx = idx+variation
	if newIdx > limit then
		newIdx = 1
	elseif newIdx < 1 then
		newIdx = limit
	end
	return newIdx
end

local function getNextRoutine(animList, oldAnim)
	local idxA = ZombRand(#animList) + 1
	if oldAnim and animList[idxA].name == oldAnim then idxA = doIdxVariation(idxA, #animList); end
	return animList[idxA].name, animList[idxA].animTime, animList[idxA].soundType, animList[idxA].soundTime
	--anim name, anim time, sound type, sound time
end

local function getSoundIdx(sound)
	if (sound == "IntriguedHmm") then
		return {"IntriguedHMM01","IntriguedHMM02","IntriguedHMM03","IntriguedHMM04","IntriguedHMM05","IntriguedHMM06","IntriguedHMM07","IntriguedHMM08","IntriguedHMM09"}
	end
end

local function getSoundIdxEnd(sound)
	if (sound == "Good") then
		return {"AgreeableUHU01","AgreeableUHU02","AgreeableUHU03","LikeHMM01","LikeHMM02","LikeHMM03"}
	elseif (sound == "Bad") then
		return {"NoUHUH01","NoUHUH02","ListenBlowOff01","ListenBlowOff02","ListenBlowOff03"}
	elseif (sound == "Neutral") then
		return {"Bored01","Bored02","IndifferentHMM01","IndifferentHMM02","IndifferentHMM03","IndifferentHMM04","IndifferentHMM05"}
	end
end

local function getNewSoundByName(soundType, oldSound, isFemale, isEnd)
	local newSound, gender = false, "Man"
	if isFemale then gender = "Woman"; end
	if isEnd then newSound = getSoundIdxEnd(soundType); end
	if not newSound then newSound = getSoundIdx(soundType); end
	local idxS = ZombRand(#newSound)+1
	if oldSound and (gender..newSound[idxS] == oldSound) then idxS = doIdxVariation(idxS, #newSound); end
	return gender..newSound[idxS]
end

function Core:isValid()
	return true
end

function Core:waitToStart()
	--self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.easel)
	return self.character:shouldBeTurning()
end

function Core:update()
	if not self.animName then
		self.animName, self.animTime, self.soundType, self.soundTime = getNextRoutine(self.animList, false)
		self.animTime = self.animTime+self.doAnim
		if (self.soundTime ~= 0) then self.soundTimeInterval = self.soundTime+self.doAnim; end
		
		self:setActionAnim(self.animName)
		self.soundName = getNewSoundByName(self.soundType, false, self.character:isFemale(), false)
	
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end

	elseif self.doAnim >= self.animTime then

		local newAnim, newSound
		newAnim, self.animTime, self.soundType, self.soundTime = getNextRoutine(self.animList, self.animName)
		self.animName = newAnim
		self.animTime = self.animTime+self.doAnim
		if (self.soundTime ~= 0) then self.soundTimeInterval = self.soundTime+self.doAnim; end
		
		self:setActionAnim(self.animName)
		if self.gameSoundLoop ~= 0 then
			self.character:getEmitter():stopSound(self.gameSoundLoop)
		end
		newSound = getNewSoundByName(self.soundType, self.soundName, self.character:isFemale(), false)
		self.soundName = newSound
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end
		
	end

	if self.soundTimeInterval and (self.soundTime ~= 0) and (self.doAnim >= self.soundTimeInterval) then
		self.soundTimeInterval = self.soundTime+self.doAnim
		if self.gameSoundLoop ~= 0 then
			self.character:getEmitter():stopSound(self.gameSoundLoop)
		end
		local newSound
		newSound = getNewSoundByName(self.soundType, self.soundName, self.character:isFemale(), false)
		self.soundName = newSound
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end
	
	end

	self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)

end

function Core:start()
	self:setOverrideHandModels(nil, nil)
	self.animList = LSCYGetAnimSound()
	if self.character:hasTrait(CharacterTrait.DEAF) then self.canTalk = false; end
end

function Core:stop()
	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
    ISBaseTimedAction.stop(self);	
end

function Core:perform()
	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
	local qualityGuess, qualityType = getMargin(self.quality, self.precision)
	local paintingTexture = getPaintingTex(self.easel, self.painting)
	-------------------------
	--------------SOUND
	if self.canTalk then
		local sound = getNewSoundByName(qualityType, false, self.character:isFemale(), true)
		self.character:getEmitter():playSound(sound)
	end
	
	doNote(self.character, paintingTexture, qualityGuess, qualityType)
	self.character:getModData().LSCooldowns['brushmaster'] = 6

	ISBaseTimedAction.perform(self);
end

function Core:complete()
	return true
end

function Core:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 800
end

function Core:new(character, easel, painting, precision)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.easel = easel
	o.painting = painting
	o.precision = precision
	o.quality = painting.quality
	o.gameSoundLoop = 0
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.animList = false
	o.doAnim = 0
	o.animName = false
	o.animTime = false
	o.soundType = false
	o.soundTime = 0
	o.soundTimeInterval = false
	o.canTalk = true
	return o;
end


return Core
end)()
-- END INSTALLED SOURCE shared/TimedActions/LSCanvasAppraiseAction.lua
-- BEGIN INSTALLED SOURCE client/Painting/EaselCanvasContextMenu.lua
local selectCanvas = (function()
local function getCanvasSize(spriteName)
	if (spriteName == "LS_Painting_50") or (spriteName == "LS_Painting_51") then return "large"; end
	if (spriteName == "LS_Painting_2") or (spriteName == "LS_Painting_3") then return "medium"; end
	if (spriteName == "LS_Painting_26") or (spriteName == "LS_Painting_27") then return "small"; end
	return false
end

local function getEaselFacing(easel)
	local facing
	local properties = easel:getSprite():getProperties()
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	return facing
end

local function getRandomLevelChance(minNumb, maxNumb)
	--here we get a table based on artlevel to randomize in another function
	--each level adds their values, repeating by their level - so level 1 is included once, level 2 is included twice and so forth...
	--increases the odds of getting a painting your level (or closer to your level)
	local randomNumbers = {}
	if minNumb == 0 then table.insert(randomNumbers, 0); end
	for n=1, maxNumb do
		if n >= minNumb then
			for j=1, n do
				table.insert(randomNumbers, n)
			end
		end
	end
	return randomNumbers
end

local function getMinMaxNumb(artLevel, paintingOption)
	if not paintingOption then return 0, artLevel; end
	if paintingOption == "simple" then return 2, math.floor(artLevel-4);----------simple option is available starting from level 7
	elseif paintingOption == "normal" then
		local minNumb = math.floor(artLevel-3)
		if minNumb < 0 then minNumb = 0; end
		return minNumb, artLevel; 
	end
	return 0, artLevel
end

local function getPaintingLevel(artLevel, paintingOption, size)
	if artLevel == 0 then return 0; end
	local minNumb, maxNumb = getMinMaxNumb(artLevel, paintingOption)
	if (size == "medium") and (minNumb < 2) then minNumb = 2; elseif (size == "large") and (minNumb < 5) then minNumb = 5; end
	local randomNumbers = getRandomLevelChance(minNumb, maxNumb)
	return randomNumbers[ZombRand(#randomNumbers)+1]
end

local function getPaintingsTable(artLevel, facing, size, qualityNumb, paintingLevel)
	--local paintingLevel = getPaintingLevel(artLevel, paintingOption)
	local t = require("Painting/lib/PaintingLibrary"..tostring(paintingLevel)..facing)
	local newTable = {}
	for k, v in ipairs(t) do
		if (v.level == paintingLevel) and (v.size == size) and ((v.style ~= "Masterpiece") or (qualityNumb == 3)) then
			table.insert(newTable, v)
		end
	end
	return newTable
end

local function getSizeMultiplier(size)
	local sizeMultipliers = {small=1,medium=6,large=12}
	return sizeMultipliers[size] or 1
end

local function getNewPaintingDuration(characterLevel, character, paintingLevel, size)
	local sizeMult = getSizeMultiplier(size)
	local brushmaster = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSBrushmaster"))
	local playerLevel = math.floor(characterLevel/2)
	if brushmaster then playerLevel = math.ceil(playerLevel*1.5); end
	return (((10000*sizeMult)+(paintingLevel*12000))-(playerLevel*1000*(sizeMult/2)))
end

local function getQualityFromRandomNumb(randomNumb)
	if randomNumb == 1.2 then return "IGUI_PaintingQuality_Good"; elseif randomNumb == 1.5 then return "IGUI_PaintingQuality_Excellent"; elseif randomNumb == 1.8 then return "IGUI_PaintingQuality_Impressive"; elseif randomNumb == 2.2 then return "IGUI_PaintingQuality_Wondrous"; elseif randomNumb == 3 then return "IGUI_PaintingQuality_Masterpiece";
	elseif randomNumb == 0.6 then return "IGUI_PaintingQuality_Awful"; elseif randomNumb == 0.7 then return "IGUI_PaintingQuality_Poor"; elseif randomNumb == 0.8 then return "IGUI_PaintingQuality_Shoddy"; end
	return "IGUI_PaintingQuality_Normal"
end

local function getBaseRandomNumbersFromSize(size)
	local randomNumbers, n = {}, 20
	if size == "small" then n = n*3; elseif size == "medium" then n = n*2; end
	for i=1, n do table.insert(randomNumbers, 1); end
	return randomNumbers
end

local function getRandomNumbersChance(character, characterLevel, paintingLevel, paintingOption, paintingSize)
	--local randomNumbers = {0.7, 0.8, 0.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.1, 1.2, 1.3, 1.4, 1.5}
	--local randomNumbers = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	local randomNumbers = getBaseRandomNumbersFromSize(paintingSize)
	local n = 1
	if paintingSize == "small" then n = 3; elseif paintingSize == "medium" then n = 2; end--small and medium canvas are less likely to produce masterpieces
	local masterpainter = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSMasterPainter"))
	local t = require("Painting/Quality")
	for k, v in ipairs(t) do
		if (v.level == characterLevel) and (((paintingOption == "normal") and (paintingLevel >= 8)) or (v.numb ~= 3)) then--Masterpieces can't occur if option is simple and paintingLevel is lesser than 8
			local repeatChance = v.chance
			if masterpainter and (v.numb >= 2.2) then repeatChance = 3;
			elseif repeatChance > 1 then repeatChance = repeatChance*n; end
			for i=1, repeatChance do table.insert(randomNumbers, v.numb); end
			
		end
	end
	
	return randomNumbers
end

local function getBeautyRandomVar(character, characterLevel, paintingLevel, paintingOption, paintingSize)
	if characterLevel == 0 then return 0.6; elseif characterLevel == 1 then return 0.7; end
	local randomNumbers = getRandomNumbersChance(character, characterLevel, paintingLevel, paintingOption, paintingSize)
	return randomNumbers[ZombRand(#randomNumbers)+1]
end

local function getPaintingBeauty(beautyQualityNumb, painting)
	local beauty, quality = 0, "IGUI_PaintingQuality_Awful"
	if painting.level == 0 then return beauty, quality; elseif painting.level == 1 then return 1, "IGUI_PaintingQuality_Poor"; end
	if painting.size == "small" then beauty = 2*painting.level; elseif painting.size == "medium" then beauty = 4*painting.level; elseif painting.size == "large" then beauty = 6*painting.level; end
	if painting.style == "Masterpiece" then beauty = beauty*3; quality = "IGUI_PaintingQuality_Masterpiece";
	elseif beautyQualityNumb == 1 then return beauty, "IGUI_PaintingQuality_Normal";
	elseif painting.level >= 2 then if beautyQualityNumb > 1 then beauty = math.ceil(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); elseif beautyQualityNumb < 1 then beauty = math.floor(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); end; end;

	return beauty, quality
end

local function getNewPainting(character, easel, spriteName, paintingOption)
	--local paintingLib = getPaintingsTable(character, character:getPerkLevel(Perks.Art))
	local facing = getEaselFacing(easel)
	local size = getCanvasSize(spriteName)
	local paintingLevel = getPaintingLevel(character:getPerkLevel(Perks.Art), paintingOption, size)
	local beautyQualityNumb = getBeautyRandomVar(character, character:getPerkLevel(Perks.Art), paintingLevel, paintingOption, size)
	local paintingLib = getPaintingsTable(character:getPerkLevel(Perks.Art), facing, size, beautyQualityNumb, paintingLevel)
	local newPainting = plain(paintingLib[ZombRand(#paintingLib)+1])
	newPainting.beauty, newPainting.quality = getPaintingBeauty(beautyQualityNumb, newPainting)
	newPainting.duration = getNewPaintingDuration(character:getPerkLevel(Perks.Art), character, newPainting.level, size)
	return newPainting, 0, newPainting.duration, character:getDescriptor():getForename().." "..character:getDescriptor():getSurname()
end


return getNewPainting
end)()
-- END INSTALLED SOURCE client/Painting/EaselCanvasContextMenu.lua
-- BEGIN INSTALLED SOURCE client/Painting/Sculpting/SculptingWorkContextMenu.lua
local selectSculpture = (function()
local function getArtworkTable(artLevel, station, list, knownList)
	local style = station:getModData().style or "Wood"
	local t = require("Painting/Sculpting/lib/Sculpture_"..style)
	local newTable = {}
	for k, v in ipairs(t) do
		if (list or not v.parent) and v.level <= artLevel then
			table.insert(newTable, v)
			if knownList and not knownList[v.result] then
				table.insert(newTable, v)
			end
		end
	end
	return newTable
end

local function getSizeMultiplier(size)
	local sizeMultipliers = {small=1,medium=6,large=12}
	return sizeMultipliers[size] or 1
end

local function getStyleDurationPenalty(style)
	local styleMultipliers = {Hedge=1,Wood=2,Metal=4,Ice=6,Stone=12}
	return styleMultipliers[style] or 1
end

local function getNewArtworkDuration(characterLevel, character, artworkLevel, size, style)
	local sizeMult = getSizeMultiplier(size)
	local brushmaster = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSBrushmaster"))
	local playerLevel = math.floor(characterLevel/2)
	local artworkStyle = getStyleDurationPenalty(style)
	if brushmaster then playerLevel = math.ceil(playerLevel*1.5); end
	return (((10000*sizeMult)+(artworkLevel*12000)+(artworkStyle*5000))-(playerLevel*1000*(sizeMult/2)))
end

local function getQualityFromRandomNumb(randomNumb)
	if randomNumb == 1.2 then return "IGUI_PaintingQuality_Good"; elseif randomNumb == 1.5 then return "IGUI_PaintingQuality_Excellent"; elseif randomNumb == 1.8 then return "IGUI_PaintingQuality_Impressive"; elseif randomNumb == 2.2 then return "IGUI_PaintingQuality_Wondrous"; elseif randomNumb == 3 then return "IGUI_PaintingQuality_Masterpiece";
	elseif randomNumb == 0.6 then return "IGUI_PaintingQuality_Awful"; elseif randomNumb == 0.7 then return "IGUI_PaintingQuality_Poor"; elseif randomNumb == 0.8 then return "IGUI_PaintingQuality_Shoddy"; end
	return "IGUI_PaintingQuality_Normal"
end

local function getBaseRandomNumbersFromStyle(style)
	local randomNumbers, n, multi = {}, 20, 1
	if (style == "Wood") or (style == "Hedge") then n = n*3; multi = 3; elseif (style == "Metal") then n = n*2; multi = 2; end
	for i=1, n do table.insert(randomNumbers, 1); end
	return randomNumbers, multi
end

local function getRandomNumbersChance(character, characterLevel, artworkLevel, style)
	--local randomNumbers = {0.7, 0.8, 0.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.1, 1.2, 1.3, 1.4, 1.5}
	--local randomNumbers = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	local randomNumbers, n = getBaseRandomNumbersFromStyle(style)
	local masterpainter = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSMasterPainter"))
	local t = require("Painting/Quality")
	for k, v in ipairs(t) do
		if (v.level == characterLevel) and ((artworkLevel >= 8) or (v.numb ~= 3)) then--Masterpieces can't occur if option is simple and artworkLevel is lesser than 8
			local repeatChance = v.chance
			if masterpainter and (v.numb >= 2.2) then repeatChance = 3;
			elseif repeatChance > 1 then repeatChance = repeatChance*n; end
			for i=1, repeatChance do table.insert(randomNumbers, v.numb); end
			
		end
	end
	return randomNumbers
end

local function getBeautyRandomVar(character, characterLevel, artworkLevel, style)
	if characterLevel == 0 then return 0.6; elseif characterLevel == 1 then return 0.7; end
	local randomNumbers = getRandomNumbersChance(character, characterLevel, artworkLevel, style)
	return randomNumbers[ZombRand(#randomNumbers)+1]
end

local function getArtworkBeauty(beautyQualityNumb, artwork)
	local beauty, quality = 0, "IGUI_PaintingQuality_Awful"
	if artwork.level == 0 then return beauty, quality; elseif artwork.level == 1 then return 1, "IGUI_PaintingQuality_Poor"; end
	if artwork.size == "small" then beauty = 2*artwork.level; elseif artwork.size == "medium" then beauty = 4*artwork.level; elseif artwork.size == "large" then beauty = 6*artwork.level; end
	if artwork.style == "Masterpiece" then beauty = beauty*3; quality = "IGUI_PaintingQuality_Masterpiece";
	elseif beautyQualityNumb == 1 then return beauty, "IGUI_PaintingQuality_Normal";
	elseif artwork.level >= 2 then if beautyQualityNumb > 1 then beauty = math.ceil(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); elseif beautyQualityNumb < 1 then beauty = math.floor(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); end; end;
	return beauty, quality
end

local function getArtworkFromList(artworkList, workOption)
	if workOption ~= "normal" then
		local artwork
		for n=1, #artworkList do
			if artworkList[n] and artworkList[n].result and (artworkList[n].result == workOption) then artwork = artworkList[n]; break; end
		end
		if artwork then return artwork; end
	end
	return artworkList[ZombRand(#artworkList)+1]
end

local function getNewArtwork(character, station, workOption, fullList)
	local sculptureLib = getArtworkTable(character:getPerkLevel(Perks.Art), station, fullList, character:getModData()['KnownArtworkList'])
	local newArtwork = plain(getArtworkFromList(sculptureLib, workOption))
	local beautyQualityNumb = getBeautyRandomVar(character, character:getPerkLevel(Perks.Art), newArtwork.level, newArtwork.style)
	newArtwork.beauty, newArtwork.quality = getArtworkBeauty(beautyQualityNumb, newArtwork)
	newArtwork.duration = getNewArtworkDuration(character:getPerkLevel(Perks.Art), character, newArtwork.level, newArtwork.size, newArtwork.style)
	return newArtwork, 0, newArtwork.duration, character:getDescriptor():getForename().." "..character:getDescriptor():getSurname()
end


return getNewArtwork
end)()
-- END INSTALLED SOURCE client/Painting/Sculpting/SculptingWorkContextMenu.lua

local function sourceReady()
    if not (SAO.SourceIntegration and SAO.SourceIntegration.available(SOURCE)) then return false,"source-not-active" end
    if isClient() or isServer() then return false,"npc-source-command-binding-unverified" end
    if not _G.LSUtil or not _G.LSUtil.changeCharacterMood or not _G.LSUtil.useItem or not _G.LSUtil.getPercentage
        or not Perks or not Perks.Art or not GTLSCheck or not getCell or not LSArt or not LSArt.getUseChance
        or not LSArt.Markings or not LSSync then return false,"source-runtime-unavailable" end
    return true
end
local function knowledge(id)
    local K=SAO.ConceptKnowledge
    if not K or not K.infer then return nil end
    for _,concept in ipairs({"art","painting","sculpture"}) do
        local view=K.infer(id,concept,"recreation")
        local path=view and view.actorId==id and view.paths and view.paths[1]
        if path and path.status=="expectation" and type(path.id)=="string"
            and type(path.evidenceIds)=="table" and #path.evidenceIds>0 then
            return {concept=concept,id=path.id,evidenceIds=plain(path.evidenceIds),modal=true}
        end
    end
end
local function held(body,item)
    if not item then return false end
    local list=SAOJavaBridge:privateCarriedItems(body)
    for index=0,list:size()-1 do if list:get(index)==item then return true end end return false
end
local function findItem(body,name)
    local list=SAOJavaBridge:privateCarriedItems(body)
    for index=0,list:size()-1 do
        local item=list:get(index);local tag=ItemTag and ItemTag[string.upper(name)]
        if item:getType()==name or tag and item:hasTag(tag) then
            if (name~="BlowTorch" or item:getCurrentUsesFloat()>0)
                and (name~="paintPalette" or _G.LSUtil.itemHasUses(item)) then return item end
        end
    end
end
local TOOLS={Hedge={"Saw"},Wood={"Hammer","CarpentryChisel"},Stone={"Hammer","MasonsChisel"},
    Metal={"BlowTorch","Hammer","WeldingMask"},Ice={"Saw"}}
local SKILLS={Hedge={Art=3,Farming=6},Wood={Art=4,Woodwork=4},Metal={Art=6,MetalWelding=4},Stone={Art=8},Ice={Art=10}}
local function materials(body,kind,style)
    local out={}
    if kind=="art-canvas" then
        out.brush,out.palette=findItem(body,"oldPaintBrush"),findItem(body,"paintPalette")
        if not out.brush or not out.palette or not _G.LSUtil.itemHasUses(out.palette) then return nil end
    else
        if not TOOLS[style] then return nil end
        for name,level in pairs(SKILLS[style]) do if not Perks[name] or body:getPerkLevel(Perks[name])<level then return nil end end
        for index,name in ipairs(TOOLS[style]) do
            out['item'..index]=findItem(body,name)
            if not out['item'..index] then return nil end
        end
    end return out
end
local function materialKeys(items)
    local out={}
    for name,item in pairs(items or {}) do out[name]={id=tostring(item:getID()),itemType=item:getFullType()} end
    return out
end
local function permission(id,body,obj,appraisal)
    if not SAO.Standing or not SAO.Standing.mayEnterCurrent
        or not SAO.Standing.mayEnterCurrent(id,obj:getX(),obj:getY()) then return false end
    if appraisal then return true end
    local data=obj:getModData()
    if data.SAOArtAuthorId and data.SAOArtAuthorId~=id then return false end
    local desc=body:getDescriptor()
    return not data.author or data.author==desc:getForename().." "..desc:getSurname()
end
local function front(obj,kind)
    local square=obj:getSquare()
    if kind=="art-sculpture" then return square:getS() or square:getE() end
    local props=obj:getSprite():getProperties();local direction=props:has("Facing") and props:get("Facing")
    if direction=="S" then return square:getS() elseif direction=="E" then return square:getE()
    elseif direction=="W" then return square:getW() elseif direction=="N" then return square:getN() end
end
local function artKind(obj)
    local p=obj:getSprite():getProperties()
    local custom=p:has("CustomName") and p:get("CustomName")
    local group=p:has("GroupName") and p:get("GroupName")
    if custom=="Painting" and (group=="EaselCanvasSmall" or group=="EaselCanvas" or group=="EaselCanvasLarge") then return "art-canvas" end
    if custom=="Sculpting" and group=="StationWork" then return "art-sculpture" end
end
local function artifact(obj,kind)
    local d=obj:getModData()
    return {style=d.style,stage=d.stage,progress=d.progress,author=d.author,actorId=d.SAOArtAuthorId,
        artifactId=d.SAOArtArtifactId,definition=plain(kind=="art-canvas" and d.painting or d.sculpture),spriteName=obj:getSprite():getName()}
end
local function visible(id,body)
    local out={};local tick=SAO.History.ticks()
    local P=SAO.Perception
    if not P or not P.leisureObjects or not P.resolveLeisureObject then return out end
    for _,row in ipairs(P.leisureObjects(id,body)) do
        if row.actorId==id and row.kind=="object" and (row.concept=="art-canvas" or row.concept=="art-sculpture")
            and row.source=="native-personal-visibility" and finite(row.at) and row.at<=tick and tick-row.at<=120
            and finite(row.x) and finite(row.y) and finite(row.z) and math.floor(body:getZ())==row.z
            and type(row.key)=="string" and type(row.spriteName)=="string" and type(row.runtimeInstance)=="string" then
            local x,y,z,index,concept=row.key:match("^object:([%-0-9]+):([%-0-9]+):([%-0-9]+):([0-9]+):([%w%-]+)$")
            x,y,z,index=tonumber(x),tonumber(y),tonumber(z),tonumber(index)
            if x==row.x and y==row.y and z==row.z and concept==row.concept and index
                and (row.objectIndex==nil or row.objectIndex==index) then
                local square=getCell():getGridSquare(x,y,z);local objects=square and square:getObjects()
                local obj=objects and index<objects:size() and objects:get(index)
                if obj and obj:getSprite():getName()==row.spriteName and artKind(obj)==row.concept
                    and P.resolveLeisureObject(id,body,row.key)==obj
                    and permission(id,body,obj,true) then out[#out+1]={row=row,object=obj,kind=row.concept} end
            end
        end
    end return out
end
local function offers(id,body)
    if not live(id,body) or not sourceReady() then return {} end
    local evidence=knowledge(id)
    if not evidence then return {} end
    local out={}
    for _,v in ipairs(visible(id,body)) do
        local obj,kind=v.object,v.kind;local d=obj:getModData();local position=front(obj,kind)
        local items=materials(body,kind,d.style)
        local sprite=obj:getSprite():getName();local level=body:getPerkLevel(Perks.Art)
        local canvasAllowed=kind~="art-canvas" or sprite=="LS_Painting_26" or sprite=="LS_Painting_27"
            or (sprite=="LS_Painting_2" or sprite=="LS_Painting_3") and level>=2
            or (sprite=="LS_Painting_50" or sprite=="LS_Painting_51") and level>=5
        local function add(activity,revision)
            out[#out+1]={id="art:"..activity..":"..v.row.key,actorId=id,family="art",activity=activity,
                sourceId=SOURCE..":"..activity,revision=revision,revisionAuthority="audited-source; loaded-byte-seal-unavailable",
                objectKey=v.row.key,objectKind=kind,x=v.row.x,y=v.row.y,z=v.row.z,objectIndex=v.row.objectIndex,
                spriteName=sprite,runtimeInstance=v.row.runtimeInstance,artifact=artifact(obj,kind),materials=materialKeys(items),evidence=evidence,
                targetX=position:getX(),targetY=position:getY(),targetZ=position:getZ(),
                afterSequence=record(id).artLeisureSequence or 0,
                requiresPreparation={frontSquare=body:getCurrentSquare()~=position,
                    weldingMask=items and items.item3 and not body:isEquippedClothing(items.item3) or false}}
        end
        if position and canvasAllowed and items and permission(id,body,obj)
            and (d.stage==nil or finite(d.stage) and d.stage<4) then
            add(kind=="art-canvas" and "paint-canvas" or "sculpt-"..d.style,kind=="art-canvas" and REVISIONS.canvas or REVISIONS.sculpture)
        end
        local art=kind=="art-canvas" and d.painting or d.sculpture
        local cooldown=body:getModData().LSCooldowns and body:getModData().LSCooldowns.brushmaster
        local complete=LSAmbtMng and LSAmbtMng.hasCompleted and LSAmbtMng.hasCompleted(body,"LSBrushmaster")
        local progress=art and finite(art.duration) and art.duration>0 and finite(d.progress)
            and _G.LSUtil.getPercentage(art.duration,art.duration-d.progress,2,false)
        -- Source's sculpture menu checks painting by mistake. Its native action
        -- receives sculpture; this typed adapter retains that actual artwork.
        if position and complete and finite(progress) and progress>=25 and progress<100 and not (cooldown and cooldown>0)
            and finite(d.stage) and d.stage>=1 and d.stage<4 then add("appraise-art",REVISIONS.appraise) end
    end return out
end
-- These source requirements describe types; they do not acquire a station or supplies.
function A.materialRequirementsForType(_,itemType)
    if not sourceReady() or type(itemType)~="string" or not getScriptManager then return {} end
    local definition=getScriptManager():getItem(itemType)
    if not definition then return {} end
    local out={}
    local function add(name,activity,revision)
        local tag=ItemTag and ItemTag[string.upper(name)]
        if definition:getName()==name or tag and definition:hasTag(tag) then
            out[#out+1]={owner="SAO.LeisureArt",family="art",activity=activity,
                sourceId=SOURCE..":"..activity,revision=revision,role="material",
                requirementId=activity..":"..name,itemType=itemType}
        end
    end
    add("oldPaintBrush","paint-canvas",REVISIONS.canvas)
    add("paintPalette","paint-canvas",REVISIONS.canvas)
    for style,names in pairs(TOOLS) do
        for _,name in ipairs(names) do add(name,"sculpt-"..style,REVISIONS.sculpture) end
    end
    return out
end
function A.materialRequirementAvailable(id,body,requirement)
    if not live(id,body) or not sourceReady() or not knowledge(id) or type(requirement)~="table" then return false end
    local admitted
    for _,row in ipairs(A.materialRequirementsForType(nil,requirement.itemType)) do
        if same(row,requirement) then admitted=row;break end
    end
    if not admitted then return false end
    local name=admitted.requirementId:match(":([^:]+)$")
    if not name or findItem(body,name) then return false end
    for _,v in ipairs(visible(id,body)) do
        local d=v.object:getModData();local style=d.style
        local activity=v.kind=="art-canvas" and "paint-canvas" or style and "sculpt-"..style
        local sprite=v.object:getSprite():getName();local level=body:getPerkLevel(Perks.Art)
        local allowed=v.kind~="art-canvas" or sprite=="LS_Painting_26" or sprite=="LS_Painting_27"
            or (sprite=="LS_Painting_2" or sprite=="LS_Painting_3") and level>=2
            or (sprite=="LS_Painting_50" or sprite=="LS_Painting_51") and level>=5
        if activity==admitted.activity and allowed and front(v.object,v.kind) and permission(id,body,v.object)
            and (d.stage==nil or finite(d.stage) and d.stage<4) then
            local skills=true
            for skill,needed in pairs(SKILLS[style] or {}) do
                if not Perks[skill] or body:getPerkLevel(Perks[skill])<needed then skills=false;break end
            end
            if skills then return true end
        end
    end
    return false
end
function A.offers(id,body)
    local ok,found=pcall(offers,id,body)
    return ok and found or {},ok and nil or "art-opportunity-unavailable"
end
A.intentOffers=A.offers
function A.work(id) local r=record(id);return r and plain(r.artLeisureWork) end
function A.skillRequest(id,workSequence,sequence)
    local active=runtime[id]
    if not active or not activeFor(active.body) or active.work.sequence~=workSequence then return nil end
    local request=active.skillRequests and active.skillRequests[sequence]
    if request and request.actorId==id and request.workSequence==workSequence and request.sequence==sequence
        and request.nativeProgress.sourceCallback==active.callback
        and request.nativeProgress.sourceInvocationSequence==active.invocations then return plain(request) end
end
function A.outcome(id,sequence)
    for _,w in ipairs(record(id) and record(id).artLeisureOutcomes or {}) do
        if w.actorId==id and w.sequence==sequence then return plain(w) end
    end
end
local function owned(active)
    local w=active.work;local r=record(w.actorId)
    return r and r.artLeisureWork==w and runtime[w.actorId]==active and live(w.actorId,active.body)
        and active.body:getModData().SAOExternalToken==w.bodyToken and hours()>=w.admittedAtHours
end
local function cleanup(active)
    local action=active.action
    if not action then return end
    -- Only this action's actual transient splash and sound handles are cleaned.
    -- A changed station does not authorize writing its art/progress metadata.
    local ok=pcall(function()
        if action.splashObj and action.tileSqr then
            local objects=action.tileSqr:getObjects()
            for i=0,objects:size()-1 do
                if objects:get(i)==action.splashObj then
                    action.tileSqr:transmitRemoveItemFromSquare(action.splashObj)
                    action.tileSqr:RemoveTileObject(action.splashObj);break
                end
            end
        end
        local emitter=active.body and active.body:getEmitter()
        if emitter then for _,name in ipairs({"sound","soundLoop","gameSoundLoop"}) do
            local handle=action[name]
            if handle and handle~=0 and emitter:isPlaying(handle) then emitter:stopSound(handle) end
        end end
    end)
    if not ok then active.work.transientCleanup="unobservable" end
end
local function finish(active,status,reason)
    local w=active.work;local r=record(w.actorId)
    if not r or r.artLeisureWork~=w or w.status=="completed" or w.status=="interrupted" then return false end
    if status=="interrupted" then cleanup(active) end
    w.status,w.reason,w.atHours=status,reason,hours()
    w.presentation=plain(active.presentation)
    w.physicalArt=plain(active.artifact)
    w.measuredEffects.after=active.body and owned(active) and sample(active.body) or nil
    w.measuredEffects.intervalAttribution="unassigned; sourceDeltas contain only immediate owned source calls"
    r.artLeisureOutcomes=r.artLeisureOutcomes or {}
    r.artLeisureOutcomes[#r.artLeisureOutcomes+1]=plain(w)
    if #r.artLeisureOutcomes>32 then table.remove(r.artLeisureOutcomes,1) end
    r.artLeisureWork=nil;runtime[w.actorId]=nil
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeHobbyOutcome then
        SAO.ProceduralPlanning.consumeHobbyOutcome(w.actorId,w.sequence,"SAO.LeisureArt")
    end return true
end
local function refresh(active)
    active.artifact=artifact(active.object,active.kind)
    active.work.physicalArt=plain(active.artifact)
    active.work.nativeProgress.stage=active.artifact.stage
    active.work.nativeProgress.remaining=active.artifact.progress
    active.work.nativeProgress.jobDelta=active.action.action and active.action:getJobDelta() or 0
end
local function usable(active)
    if not owned(active) or not sourceReady() or not permission(active.work.actorId,active.body,active.object,active.work.activity=="appraise-art")
        or SAO.Perception.resolveLeisureObject(active.work.actorId,active.body,active.work.objectKey)~=active.object
        or active.object:getSquare()==nil or active.body:getCurrentSquare()~=front(active.object,active.kind)
        or not same(active.artifact,artifact(active.object,active.kind))
        or active.body:getVehicle() or active.body:isSitOnGround() or active.body:getModData().IsSittingOnSeat then return false end
    for _,item in pairs(active.items) do
        if not held(active.body,item) then
            if item==active.items.palette and (active.work.nativeProgress.materialUses[tostring(item:getID())] or 0)>0
                and findItem(active.body,"paintPalette") then
                -- Source's own Paint/Brush transition selects the next exact palette.
            else return false end
        end
    end
    return not active.items.item3 or active.body:isEquippedClothing(active.items.item3)
end
local function wrap(core,activity)
    local Action=core:derive("SAOOwnedArt"..activity)
    function Action:isValid()return usable(self.owner) and core.isValid(self) end
    function Action:waitToStart()
        if not self:isValid() then self:forceStop();return false end
        return core.waitToStart(self)
    end
    function Action:start()
        if not self:isValid() then self:forceStop();return end
        self.owner.started=true;self.owner.work.status="active"
        core.start(self);refresh(self.owner)
    end
    function Action:update()
        if not self:isValid() then self:forceStop();return end
        self.owner.callback="update";self.owner.invocations=(self.owner.invocations or 0)+1
        core.update(self)
        self.owner.callback=nil
        if runtime[self.owner.work.actorId]~=self.owner then return end
        self.owner.work.nativeProgress.sourceUpdates=self.owner.work.nativeProgress.sourceUpdates+1
        refresh(self.owner)
    end
    function Action:perform()
        if self.owner.performed or not self.owner.started or not self:isValid()
            or not self.action or self:getJobDelta()<1 or self.owner.work.nativeProgress.sourceUpdates<1 then
            if owned(self.owner) then self:forceStop() end return
        end
        self.owner.performed=true
        self.owner.callback="perform";self.owner.invocations=(self.owner.invocations or 0)+1
        core.perform(self);refresh(self.owner)
        self.owner.callback=nil
    end
    function Action:complete()
        if not owned(self.owner) or not self.owner.performed then return false end
        local completed=core.complete(self)==true
        local expected=activity=="canvas" and self.painting.stage4 or activity=="sculpture" and self.artwork.result
        local overlay=self.owner.object:getOverlaySprite()
        if activity~="appraise" then completed=completed and self.owner.artifact.stage==4 and overlay and overlay:getName()==expected end
        return finish(self.owner,completed and "completed" or "interrupted",completed and nil or "native-art-result-unmeasured")
    end
    function Action:stop()
        if not owned(self.owner) then return end
        if usable(self.owner) and self.owner.started then core.stop(self);refresh(self.owner)
        else ISBaseTimedAction.stop(self) end
        finish(self.owner,"interrupted","native-art-stopped")
    end
    function Action:forceCancel() if owned(self.owner) then self:stop() end end
    return Action
end
local Canvas=wrap(canvasCore,"canvas")
local Sculpture=wrap(sculptureCore,"sculpture")
local Appraise=wrap(appraiseCore,"appraise")
local function begin(id,body,offer,purposeId)
    if not live(id,body) or runtime[id] or not SAO.Needs.workAvailable(body) or type(purposeId)~="string" then return false end
    local selected
    for _,candidate in ipairs(A.offers(id,body)) do if same(candidate,offer) then selected=candidate break end end
    if not selected or selected.requiresPreparation.frontSquare or selected.requiresPreparation.weldingMask then return false end
    local observed
    for _,v in ipairs(visible(id,body)) do if v.row.key==selected.objectKey then observed=v break end end
    if not observed or SAO.Perception.resolveLeisureObject(id,body,selected.objectKey)~=observed.object then return false end
    local r=record(id);r.artLeisureSequence=(r.artLeisureSequence or 0)+1
    local d=observed.object:getModData();local items=materials(body,observed.kind,d.style) or {}
    local token=body:getModData().SAOExternalToken
    local work={actorId=id,sequence=r.artLeisureSequence,workId="art:"..id..":"..tostring(r.artLeisureSequence),
        purposeId=purposeId,family="art",activity=selected.activity,sourceId=selected.sourceId,revision=selected.revision,
        nativeOwner="SAO.LeisureArt/"..selected.activity,bodyGenerationKnown=type(token)=="string" and token~="",bodyToken=token,
        admittedAtHours=hours(),atHours=hours(),status="prepared",objectKey=selected.objectKey,runtimeInstance=selected.runtimeInstance,
        materials=materialKeys(items),revisionAuthority=selected.revisionAuthority,
        nativeProgress={sourceUpdates=0,jobDelta=0,stage=d.stage or 0,remaining=d.progress,materialUses={}},
        measuredEffects={before=sample(body),sourceDeltas={},sourceMoodCalls=0},
        pendingSkillEffects={status="pending-native-authority",count=0,totalRequested=0,omittedRequests=0,requests={}}}
    r.artLeisureWork=work
    local active={body=body,work=work,object=observed.object,kind=observed.kind,items=items,artifact=artifact(observed.object,observed.kind)}
    runtime[id]=active
    local P=SAO.ProceduralPlanning
    if not P or not P.admitHobbyWork or not P.admitHobbyWork(id,purposeId,work.sequence,"SAO.LeisureArt") then
        r.artLeisureWork=nil;runtime[id]=nil;return false
    end
    local action
    if selected.activity=="appraise-art" then
        local art=observed.kind=="art-canvas" and d.painting or d.sculpture
        local progress=_G.LSUtil.getPercentage(art.duration,art.duration-d.progress,2,false)
        local precision=progress>75 and "high" or progress>50 and "medium" or "low"
        -- NPC bodies do not receive the player's Lifestyle initialization hook.
        -- The original action writes this existing source-owned cooldown table.
        body:getModData().LSCooldowns=body:getModData().LSCooldowns or {}
        action=Appraise:new(body,observed.object,art,precision)
    elseif observed.kind=="art-canvas" then
        if not d.painting then d.painting,d.stage,d.progress,d.author=selectCanvas(body,observed.object,selected.spriteName,"normal") end
        action=Canvas:new(body,observed.object,d.painting,d.progress,items)
    else
        if not d.sculpture then d.sculpture,d.stage,d.progress,d.author=selectSculpture(body,observed.object,"normal",false) end
        action=Sculpture:new(body,observed.object,d.sculpture,d.progress,items)
    end
    if selected.activity~="appraise-art" then d.SAOArtAuthorId=d.SAOArtAuthorId or id end
    d.SAOArtArtifactId=d.SAOArtArtifactId or work.workId
    work.artifactId=d.SAOArtArtifactId
    active.action,action.owner=action,active
    refresh(active)
    if not SAO.Needs.queueVerified(action) then finish(active,"interrupted","native-art-queue-refused");return false end
    return true
end
function A.begin(id,body,offer,purposeId)
    local ok,result=pcall(begin,id,body,offer,purposeId)
    if not ok then local active=runtime[id];if active then finish(active,"interrupted","art-source-admission-unavailable") end end
    return ok and result==true
end
function A.detach(id,body,reason)
    local active=runtime[id]
    if not active then return A.interrupt(id,body,reason)end
    if active.body~=body then return false end
    if owned(active)then return A.interrupt(id,body,reason)end
    local action=active.action
    cleanup(active)
    if action and ISTimedActionQueue.hasAction(action)then
        if action.action then pcall(function()action.action:forceStop()end)end
        local queue=ISTimedActionQueue.getTimedActionQueue(body)
        if queue.current==action then queue:onCompleted(action)else queue:removeFromQueue(action)end
    end
    local r=record(id)
    if r and r.artLeisureWork==active.work then finish(active,"interrupted",reason or "native-body-owner-ended")
    else runtime[id]=nil end
    return true
end
function A.interrupt(id,body,reason)
    local active=runtime[id]
    if active and active.body~=body then return false end
    if active and active.body==body and owned(active) then
        if active.action and ISTimedActionQueue.hasAction(active.action) then
            if active.action.action then active.action:forceStop() else active.action:forceCancel() end
        else finish(active,"interrupted",reason or "art-interrupted") end
        return true
    end
    local r=record(id);local w=r and r.artLeisureWork
    if w and (w.status=="prepared" or w.status=="active") then
        finish({work=w,artifact=w.physicalArt},"interrupted",reason or "art-runtime-unavailable")
    end return true
end
function A.advance(id,body)
    local active=runtime[id]
    if not active then A.interrupt(id,body,"art-runtime-unavailable");return false end
    if not owned(active) or not ISTimedActionQueue.hasAction(active.action) and not active.performed then
        finish(active,"interrupted","art-owner-or-queue-lost");return false
    end return true
end
function A.reset(reason)
    local ids={} for id in pairs(runtime) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do A.interrupt(id,runtime[id] and runtime[id].body,reason) end
end
return A
