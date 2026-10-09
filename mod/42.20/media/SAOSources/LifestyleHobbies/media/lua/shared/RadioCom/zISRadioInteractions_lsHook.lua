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
-- ISRadioInteractions hook - if it doesn't recognize custom entries then reverts to og instance
-- should work even with most mods that overwrite the og functions (if this file loads after)
-- RadioCustomInt can be easily added to externally (dont forget to add RadioIntCustom_funcs to doSkill and doStat)

require "RadioCom/ISRadioInteractions"

RadioIntCustom_funcs = {}
local DEBUG = false;
local statsHalo = true; -- seems to always be true

RadioIntCustom_funcs.doSkill = function(_player, _amount, _name, _perk)
    if _amount == nil or _amount <= 0 then return; end
    -- if the player already has enough levels in the perk, no xp
    if SandboxVars and (_player:getPerkLevel(_perk) >= SandboxVars.LevelForMediaXPCutoff) then return; end

    --local curXp = _player:getXp():getXP(_perk);
    local amount = 50*_amount;
    --if curXp>0 then
        --amount = (2 / curXp)*50;
    --end

    local oldXp = _player:getXp():getXP(_perk);
    addXp(_player, _perk, amount)
    amount = _player:getXp():getXP(_perk) - oldXp;
    if oldXp~=_player:getXp():getXP(_perk) then
        ISRadioInteractions:getInstance().addHalo(_name, amount, true);
    end
end

local function applyBoredom(_player, _amount, _isSet)
    if _player:getStats() ~= nil then
        local valueChanged = _player:getStats():add(CharacterStat.BOREDOM, _isSet and _amount or _amount * 5)
        if DEBUG then
            _player:setHaloNote("Boredom " .. tostring(_player:getStats():get(CharacterStat.BOREDOM)));
        elseif statsHalo and not _isSet and valueChanged then
            ISRadioInteractions:getInstance().addHalo(getText("IGUI_HaloNote_Boredom"), _amount);
        end
    end
end

local function applyUnhappiness(_player, _amount, _isSet)
    if _player:getStats() ~= nil then
        local valueChanged = _player:getStats():add(CharacterStat.UNHAPPINESS, _isSet and _amount or _amount * 5)
        if DEBUG then
            _player:setHaloNote("Unhappiness " .. tostring(_player:getStats():get(CharacterStat.UNHAPPINESS)));
        elseif statsHalo and not _isSet and valueChanged then
            ISRadioInteractions:getInstance().addHalo(getText("IGUI_HaloNote_Unhappiness"), _amount);
        end
    end
end

RadioIntCustom_funcs.doStat = function(_statStr, _player, _amount, _isSet)
    if _statStr=="Boredom" then
        applyBoredom(_player,_amount,_isSet);
        return;
    elseif _statStr=="Unhappiness" then
        applyUnhappiness(_player,_amount,_isSet);
        return;
    end

    local stats = _player:getStats();
    if stats["get".._statStr]~=nil and stats["set".._statStr]~=nil then -- fixed double get
        local val = stats["get".._statStr](stats);
        local valCache = val;

        local range100 = false;
        if _statStr=="Panic" then
            range100 = true;
        end

        if _isSet then
            val = _amount;
        else
            local mod = range100 and 5 or 0.05;
            local am = _amount*mod;
            val = val+am;
        end

        if val<0 then val = 0; end
        if (not range100) and val>1 then val = 1; end
        if range100 and val>100 then val = 100; end

        stats["set".._statStr](stats,val);
        if DEBUG then
            local val = stats["get".._statStr](stats);
            _player:setHaloNote(getText("IGUI_HaloNote_".._statStr).." "..tostring(val));
        else
            if statsHalo and (not _isSet) then
                if valCache~=stats["get".._statStr](stats) then
                    ISRadioInteractions:getInstance().addHalo(getText("IGUI_HaloNote_".._statStr),_amount);
                end
            end
        end
    end
end

RadioCustomInt = {}
--Stats
RadioCustomInt.ANG = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Anger",_player,_amount, _opIsSet); end       -- Anger
RadioCustomInt.BOR = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Boredom",_player,_amount, _opIsSet); end     -- boredom
RadioCustomInt.END = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Endurance",_player,_amount, _opIsSet); end   -- endurance
RadioCustomInt.FAT = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Fatigue",_player,_amount, _opIsSet); end     -- fatigue
RadioCustomInt.FIT = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Fitness",_player,_amount, _opIsSet); end     -- fitness
RadioCustomInt.HUN = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Hunger",_player,_amount, _opIsSet); end      -- hunger
RadioCustomInt.MOR = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Morale",_player,_amount, _opIsSet); end      -- morale
RadioCustomInt.STS = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Stress",_player,_amount, _opIsSet); end      -- stress
RadioCustomInt.PAN = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Panic",_player,_amount, _opIsSet); end       -- Panic
RadioCustomInt.SAN = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Sanity",_player,_amount, _opIsSet); end      -- Sanity
RadioCustomInt.SIC = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Sickness",_player,_amount, _opIsSet); end    -- Sickness
RadioCustomInt.PAI = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Pain",_player,_amount, _opIsSet); end        -- Pain
RadioCustomInt.DRU = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Intoxication",_player,_amount, _opIsSet); end -- Intoxication
RadioCustomInt.THI = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Thirst",_player,_amount, _opIsSet); end      -- thirst
RadioCustomInt.UHP = function(_player, _amount, _opIsSet) RadioIntCustom_funcs.doStat("Unhappiness",_player,_amount, _opIsSet); end -- Unhappiness
--Skills
--agility
RadioCustomInt.SPR = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Sprinting"), Perks.Sprinting); end         --sprinting
RadioCustomInt.LFT = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Lightfooted"), Perks.Lightfoot); end         --lightfooded
RadioCustomInt.NIM = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Nimble"), Perks.Nimble); end            --nimble
RadioCustomInt.SNE = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Sneaking"), Perks.Sneak); end             --sneaking
--blade
RadioCustomInt.BAA = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Axe"), Perks.Axe); end       -- Axe
RadioCustomInt.BUA = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Blunt"), Perks.Blunt); end       -- Blunt
--crafting
RadioCustomInt.CRP = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Carpentry"), Perks.Woodwork); end           --carpentry
RadioCustomInt.COO = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Cooking"), Perks.Cooking); end           --cooking
RadioCustomInt.FRM = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Farming"), Perks.Farming); end           --farming
RadioCustomInt.DOC = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Doctor"), Perks.Doctor); end            --firstaid
RadioCustomInt.ELC = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Electricity"), Perks.Electricity); end           --electricty
RadioCustomInt.MTL = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Metalworking"), Perks.MetalWelding); end            --metalwelding
RadioCustomInt.FKN = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_FlintKnapping"), Perks.FlintKnapping); end
RadioCustomInt.CRV = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Carving"), Perks.Carving); end
--firearm
RadioCustomInt.AIM = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Aiming"), Perks.Aiming); end            --aiming
RadioCustomInt.REL = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Reloading"), Perks.Reloading); end         --reloading
--survivalist
RadioCustomInt.FIS = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Fishing"), Perks.Fishing); end           --fishing
RadioCustomInt.TRA = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Trapping"), Perks.Trapping); end          --trapping
RadioCustomInt.FOR = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Foraging"), Perks.PlantScavenging); end   --foraging
--new
RadioCustomInt.TAI = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Tailoring"), Perks.Tailoring); end          --tailoring
RadioCustomInt.MEC = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Mechanics"), Perks.Mechanics); end   --mechanics

RadioCustomInt.CMB = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Combat"), Perks.Combat); end
RadioCustomInt.SPE = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Spear"), Perks.Spear); end
RadioCustomInt.SBU = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_SmallBlunt"), Perks.SmallBlunt); end
RadioCustomInt.LBA = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_LongBlade"), Perks.LongBlade); end
RadioCustomInt.SBA = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_SmallBlade"), Perks.SmallBlade); end
RadioCustomInt.MAS = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Masonry"), Perks.Masonry); end
RadioCustomInt.POT = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Pottery"), Perks.Pottery); end

--Lifestyle
RadioCustomInt.DNC = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Dancing"), Perks.Dancing); end   --dancing
RadioCustomInt.ART = function(_player, _amount) RadioIntCustom_funcs.doSkill(_player, _amount, getText("IGUI_perks_Art"), Perks.Art); end   --art

local function customGetPlayer(customInst, player, _guid, _interactCodes, _x, _y, _z, cooldowns)
	local source = (not (_x==-1 and _y==-1 and _z==-1)) and getCell():getGridSquare(_x,_y,_z) or nil;
	local plrsquare = player:getSquare();
	if (source and source:isOutside() ~= plrsquare:isOutside()) or player:isAsleep() then return nil, cooldowns; end

	if _guid ~= nil and _guid ~= "" then
		if player:isKnownMediaLine(_guid) then
			return nil, cooldowns
		end
		player:addKnownMediaLine(_guid)
	end

	if _interactCodes == nil or _interactCodes:len() == 0 then return nil, cooldowns; end

	local currentPlayer = player
        local playerNum = player:getPlayerNum()+1
        if isServer() then
            playerNum = player:getOnlineID()+1
        end
        local stats = player:getStats();
        local xp = player:getXp();

		local traitMult = (player:hasTrait(CharacterTrait.COUCHPOTATO) and 3) or (player:hasTrait(CharacterTrait.DISCIPLINED) and 0.3) or 1

        if stats ~= nil and xp ~= nil then
            local codes = customInst.split(_interactCodes, ",");
            for _,_v in ipairs(codes) do
                if _v:len() > 4 then
                    local code = string.sub(_v, 1, 3);
                    local op = string.sub(_v, 4, 4);
                    local amount = code~="RCP" and tonumber(string.sub(_v, 5, _v:len())) or nil;
                    if amount ~= nil and code~="RCP" then
                        amount = op=="-" and amount*-1 or amount;

                        if RadioCustomInt[code] ~= nil then
                            if not cooldowns[playerNum] or not cooldowns[playerNum][code] or cooldowns[playerNum][code]<=0 then
                                RadioCustomInt[code](player, amount*traitMult, op=="=");
                                cooldowns[playerNum] = cooldowns[playerNum] or {}
                                cooldowns[playerNum][code] = 30;
                            end
                        end
                    end
                end
            end

            local moodles = player:getMoodles();
            if moodles ~= nil then
                moodles:Update();
            end
        end
	return currentPlayer, cooldowns
end

local ogGetInstance = ISRadioInteractions.getInstance
local customInstance

function ISRadioInteractions:getInstance()
	if customInstance ~= nil then return customInstance; end
	local customInst = ogGetInstance(self)
	if not customInst.lsHook then
		customInst.lsHook = {}
		customInst.lsHook.noHalo = {}
		customInst.lsHook.cooldowns = {}
		local ogCheckPlayer = customInst.checkPlayer
		customInst.checkPlayer = function(player, guid, interactCodes, x, y, z, line, source)
			local invalid
			if line and interactCodes and interactCodes:len() > 0 then
				local lineCodes = customInst.split(interactCodes, ",") -- get lineCodes
				for _,_v in ipairs(lineCodes) do
					if _v:len() > 4 then
						local code = string.sub(_v, 1, 3)
						--print("CODE IS "..code)
						if code == "RCP" or not RadioCustomInt[code] then
							invalid = true
							break
						end
					end
				end
			else
				invalid = true
			end
			if not invalid then
				--print("ALL CODE RECOGNIZED, RUNNING CUSTOM")
				customInst.lsHook.currentPlayer, customInst.lsHook.cooldowns = customGetPlayer(customInst, player, guid, interactCodes, x, y, z, customInst.lsHook.cooldowns)
			else
				--print("HAS RECIPE OR UNKNOWN CODE, RUNNING OG")
				customInst.lsHook.currentPlayer = nil
				ogCheckPlayer(player, guid, interactCodes, x, y, z, line, source)
			end
		end

		customInst.OnCustomTick = function()
        if isServer() then
            local players = getOnlinePlayers()
            for i=0, players:size()-1 do
                local tblC = customInst.lsHook.cooldowns[players:get(i):getOnlineID()+1]
                if tblC then
                    for code,value in pairs(tblC) do
                        if value > 0 then
                            tblC[code] = value - (1*getGameTime():getMultiplier());
                        end
                    end
                end
            end
        else
            for playerNum=1,4 do
                local tblC = customInst.lsHook.cooldowns[playerNum]
                if tblC then
                    for code,value in pairs(tblC) do
                        if value > 0 then
                            tblC[code] = value - (1*getGameTime():getMultiplier());
                        end
                    end
                end
            end
        end
    end

		local ogaddHalo = customInst.addHalo
		customInst.addHalo = function(str, amount, inverseCols)
			if customInst.lsHook.noHalo[str] or not customInst.lsHook.currentPlayer then
				ogaddHalo(str, amount, inverseCols)
				return
			end
			local color = HaloTextHelper.getGoodColor();
			local doArrow = 0

			if amount and (type(amount) == "number") then
				if amount < 0 then
					color = inverseCols and HaloTextHelper.getBadColor() or HaloTextHelper.getGoodColor()
					doArrow = -1
				elseif amount > 0 then
					color = inverseCols and HaloTextHelper.getGoodColor() or HaloTextHelper.getBadColor()
					doArrow = 1;
				end
			end
			if doArrow ~= 0 then
				HaloTextHelper.addTextWithArrow(customInst.lsHook.currentPlayer, str, "[br/]", doArrow==1 and true or false, color);
			else
				HaloTextHelper.addText(customInst.lsHook.currentPlayer, str, "[br/]", color);
			end
		end
		
		local ogsetNoHalo = customInst.setNoHalo
		customInst.setNoHalo = function(_type, b)
			customInst.lsHook.noHalo[_type] = b
			ogsetNoHalo(_type, b)
		end
		
		Events.OnTick.Add(customInst.OnCustomTick)
	end
	customInstance = customInst
	return customInst
end