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

InventionsMenu = InventionsMenu or {}

--[[ -- check if OnWeaponHitTree covers this
local ogActionAnimEvent = ISChopTreeAction.animEvent;
function ISChopTreeAction:animEvent(event, parameter)
	if event ~= 'ChopTree' or (self.axe and self.axe:getType() ~= "PowerAxe") then ogActionAnimEvent(self, event, parameter); return; end
	self.tree:WeaponHit(self.character, self.axe)
	self:useEndurance()
	
	
	LSUtil.rollBreakdownChanceInventionIem(character, item, data, itemType)
	
	if ZombRand(self.axe:getConditionLowerChance() * 2 + self.character:getMaintenanceMod() * 2) == 0 then
		self.axe:setCondition(self.axe:getCondition() - 1)
		ISWorldObjectContextMenu.checkWeapon(self.character)

	if event == 'ChopTree' then
		
		
		
			
			;
		else
			self.character:getXp():AddXP(Perks.Maintenance, 1)
		end
		if self.tree:getObjectIndex() == -1 then
			self:forceComplete()
		end
	end
    ;
end
]]--
InventionsMenu.PowerAxe = function(context, parentMenu, character, item, data, itemType)


end

local function getExplosionChanceStr(chance)
	local t = {
		[50] = {"IGUI_Inventions_Stats_HighAttention"," <RGB:0.9,0.5,0.5>"},
		[20] = {"IGUI_Inventions_Stats_Medium"," <RGB:0.8,0.6,0.6>"},
		[10] = {"IGUI_Inventions_Stats_Low"," <RGB:0.8,0.7,0.7>"},
		[1] = {"IGUI_Inventions_Stats_VeryLow"," <RGB:0.6,0.8,0.6>"},
	}
	for k, v in pairs(t) do
		if chance >= tonumber(k) then
			return v[1],v[2]
		end
	end
	return "IGUI_Inventions_Stats_None",""
end

InventionsMenu.getAdditionalStatsDescPowerAxe = function(item, data)
	local main, improv, other
	local iN, oN = 1, 1

	local explosionChance, eRgb = "IGUI_Inventions_Stats_None", ""
	if data['inventionData']['power'][3] and data['inventionData']['durability'][1] > 0 then
		explosionChance, eRgb = getExplosionChanceStr(data['inventionData']['durability'][1])
	end
	other = " <TEXT><RGB:0.9,0.9,0.9>"..getText("IGUI_Inventions_Stats_ExplosionChance")..": <SPACE>"..eRgb..getText(explosionChance)

	--local treeDmg = tostring(item:getTreeDamage())
	local treeDmg = tostring(data['inventionData']['power'][1])
	local rgb, noFuel = "",""
	local gpTex, gpName = LSUtil.getTexIcon("GunPowder")
	if data['inventionData']['power'][1] <= 10 then rgb, noFuel = " <RGB:0.8,0.6,0.6>", " <RGB:0.5,0.5,0.5><LINE>"..getText("IGUI_Inventions_Stats_noFuel").." - ( "..gpTex.." - "..gpName..")"; end
	other = other.." <LINE><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_Inventions_Stats_TreeDmg")..": <SPACE>"..rgb..treeDmg..noFuel
	oN = oN+1

	local conditionChance = tostring(item:getConditionLowerChance())
	other = other.." <LINE><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_Inventions_Stats_conditionLowerChance",1,conditionChance).." <RGB:0.5,0.5,0.5><LINE>"..getText("IGUI_Inventions_Stats_conditionLowerChance_desc")
	oN = oN+1

	return main, improv, iN, other, oN
end
