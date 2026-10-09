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

LSCanvasAction = ISBaseTimedAction:derive("LSCanvasAction");

function LSCanvasAction:isValid()
	return true;
end

function LSCanvasAction:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.easel);
	return self.character:shouldBeTurning();
end

function LSCanvasAction:update()
	if self.character:isSitOnGround() then self:forceStop(); end

end

function LSCanvasAction:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "High")
	self.character:getEmitter():playSound("PutItemInBag")
end

function LSCanvasAction:stop()
	self.character:SetVariable("LootPosition", "Mid")
    ISBaseTimedAction.stop(self);		
end

function LSCanvasAction:perform()
	if self.savePainting then
		sendClientCommand(self.character, "LS", "CreateArtworkItem", {self.easel:getModData().author, self.easel:getModData().painting})
	end
	self.easel:getModData().stage = 0
	self.easel:getModData().painting = false
	self.easel:getModData().author = false
	sendClientCommand("LS", "ModifySprite", {{self.easel:getX(),self.easel:getY(),self.easel:getZ(),self.easel:getSprite():getName()}, self.newEasel, false})
	sendClientCommand("LS", "ModifyObjData", {{self.easel:getX(),self.easel:getY(),self.easel:getZ(),self.easel:getSprite():getName()}, false, self.easel:getModData()})

	self.character:SetVariable("LootPosition", "Mid")
	ISBaseTimedAction.perform(self);
end

function LSCanvasAction:complete()

	return true
end

function LSCanvasAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 60
end

function LSCanvasAction:new(character, easel, newEasel, savePainting)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.easel = easel
	o.newEasel = newEasel
	o.savePainting = savePainting
	o.newItem = false
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = true;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	return o;
end
