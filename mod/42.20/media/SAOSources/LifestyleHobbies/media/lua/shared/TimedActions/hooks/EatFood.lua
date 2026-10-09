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

local function isAmbitionValid(ambt,name)
	return ambt and ambt[name]
end

local function isAmbitionInProgress(ambt,name)
	return ambt[name].isActive and not ambt[name].completed
end

local function isAmbitionCompleted(ambt,name)
	return ambt[name].completed
end

local function foodIsValid(item)
	if item:isbDangerousUncooked() and not item:isCooked() and not item:isBurnt() then return true; end
	--LSUtil.debugDiagnostics("/client/ISAmbt/LSGoodEating", "foodIsValid", {['item:isbDangerousUncooked()']=item:isbDangerousUncooked(),['item:isCooked()']=item:isCooked(),['item:isBurnt()']=item:isBurnt()})
	return false
end

local function foodEaten(item, percentage)
	if item:getFullType()=="Base.Cigarettes" then return false; end
	local hungerChange = math.abs(item:getHungerChange() * 100)
	return hungerChange and hungerChange > 1 and percentage >= 0.95
end

local ogActionPerform = ISEatFoodAction.perform;
function ISEatFoodAction:perform()
	local ambtData = self.character and self.character:getModData().Ambitions
	if isAmbitionValid(ambtData,"LSGoodEating") and isAmbitionInProgress(ambtData, "LSGoodEating") and foodIsValid(self.item) then
		ambtData['LSGoodEating'].goal1progress = (ambtData['LSGoodEating'].goal1progress and math.floor(ambtData['LSGoodEating'].goal1progress+1)) or 1
	end
	if self.fulfilling and isAmbitionValid(ambtData,"LSDietOfGods") then
		--print("ISEatFoodAction:ogActionPerform, LSDietOfGods fulfilling food eaten")
		ambtData['LSDietOfGods'].ateRecent = true
	end
    ogActionPerform(self);
end

local ogActionStop = ISEatFoodAction.stop;
function ISEatFoodAction:stop()
	local ambtData = self.character and self.character:getModData().Ambitions
	if isAmbitionValid(ambtData,"LSGoodEating") and isAmbitionInProgress(ambtData, "LSGoodEating") and foodIsValid(self.item) and foodEaten(self.item, self:getJobDelta()) then
		ambtData['LSGoodEating'].goal1progress = (ambtData['LSGoodEating'].goal1progress and math.floor(ambtData['LSGoodEating'].goal1progress+1)) or 1
	end
	if self.fulfilling and isAmbitionValid(ambtData,"LSDietOfGods") and foodEaten(self.item, self:getJobDelta()) then
		--print("ISEatFoodAction:stop, LSDietOfGods fulfilling food eaten")
		ambtData['LSDietOfGods'].ateRecent = true
	end
    ogActionStop(self);
end

local ogActionStart = ISEatFoodAction.start
function ISEatFoodAction:start()
	local hungryLvl = self.character:getMoodles():getMoodleLevel(MoodleType.HUNGRY) > 0
	local currentHunger = (self.item.getHungerChange and math.abs(self.item:getHungerChange()*100*self.percentage)) or 0
	--print("ISEatFoodAction:start, LSDietOfGods currentHunger is: "..tostring(currentHunger))
	self.fulfilling = hungryLvl and currentHunger and currentHunger > 30
	--if self.fulfilling then print("ISEatFoodAction:start, LSDietOfGods food is fulfilling"); end
    ogActionStart(self)
end

local ogActionEat = ISEatFoodAction.eat
function ISEatFoodAction:eat(food, percentage)
	local ambtData = self.character and self.character:getModData().Ambitions
	local currentHunger = (self.item.getHungerChange and math.abs(self.item:getHungerChange()*100*self.percentage)) or 0
	--print("ISEatFoodAction:eat, LSDietOfGods currentHunger is: "..tostring(currentHunger))
	if currentHunger and currentHunger > 10 then
		--print("ISEatFoodAction:eat, LSDietOfGods currentHunger is enough for bonus")
		self.bonusFed = (currentHunger > 30 and "Lifestyle.DebugFoodMediumTest") or "Lifestyle.DebugFoodSmallTest"
	end
	if self.bonusFed and percentage > 0.95 and isAmbitionValid(ambtData,"LSDietOfGods") and isAmbitionCompleted(ambtData,"LSDietOfGods") then
		--print("ISEatFoodAction:eat, LSDietOfGods passive bonus")
		LSUtil.MakeCharWellFed(self.character, self.bonusFed)
	end
	ogActionEat(self, food, percentage)
end

local ogActionComplete = ISEatFoodAction.complete
function ISEatFoodAction:complete()
	local ambtData = self.character and self.character:getModData().Ambitions
	local currentHunger = (self.item.getHungerChange and math.abs(self.item:getHungerChange()*100*self.percentage)) or 0
	--print("ISEatFoodAction:complete, LSDietOfGods currentHunger is: "..tostring(currentHunger))
	if currentHunger and currentHunger > 10 then
		--print("ISEatFoodAction:complete, LSDietOfGods currentHunger is enough for bonus")
		self.bonusFed = (currentHunger > 30 and "Lifestyle.DebugFoodMediumTest") or "Lifestyle.DebugFoodSmallTest"
	end
	if self.bonusFed and isAmbitionValid(ambtData,"LSDietOfGods") and isAmbitionCompleted(ambtData,"LSDietOfGods") then
		--print("ISEatFoodAction:complete, LSDietOfGods passive bonus")
		LSUtil.MakeCharWellFed(self.character, self.bonusFed)
	end
	return ogActionComplete(self)
end