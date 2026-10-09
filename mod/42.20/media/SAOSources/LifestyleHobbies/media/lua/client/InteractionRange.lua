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
require "LSEffects"

local function sqrHasEnergy(obj)
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end

local function getObj(v, cm)
	local obj, facing, groupName
	local sqr = v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ()) or v:getModData().JukeBckpSquare

	for i=0,sqr:getObjects():size()-1 do
		local thisObject = sqr:getObjects():get(i)	
		local thisSprite = thisObject:getSprite()
				
		if thisSprite then	
			local properties = thisObject:getSprite():getProperties()
			if properties and properties:has("CustomName") and (properties:get("CustomName") == cm) then
				obj = thisObject;
				if properties:has("Facing") then
					facing = properties:get("Facing")
				end
				groupName = properties:has("GroupName") and properties:get("GroupName")
			end
		end
	end
	return obj, facing, groupName
end

local function playerIsInRange(player, obj, numb)
	if player and (player:getX() >= obj:getX() - numb and player:getX() <= obj:getX() + numb and
	player:getY() >= obj:getY() - numb and player:getY() <= obj:getY() + numb) then return true; end
	return false
end

local function getObjAndRemove(square)
	local lights = {"LS_JukeboxLight_0","LS_JukeboxLight_7","LS_JukeboxLight_1","LS_JukeboxLight_5","LS_JukeboxLight_2","LS_JukeboxLight_6","LS_JukeboxLight_3","LS_JukeboxLight_4"}
	local objects = square:getObjects()
	if not objects or objects:size() == 0 then return; end
	for i = objects:size()-1, 1, -1 do
		local obj = square:getObjects():get(i)
		local spriteName = obj and ((obj.getSpriteName and obj:getSpriteName()) or (obj.getSprite and obj:getSprite():getName()))
		if spriteName then
			for n=1,#lights do
				local lightName = lights[n]
				if spriteName == lights[n] then
					square:RemoveTileObject(obj)
					break
				end
			end
		end
	end
end

local function getObjAndRemoveSecondaryLights(square)
	local lights = {"LS_JukeboxLight_0","LS_JukeboxLight_7","LS_JukeboxLight_1","LS_JukeboxLight_5","LS_JukeboxLight_2","LS_JukeboxLight_6"}
	local objects = square:getObjects()
	if not objects or objects:size() == 0 then return; end
	for i = objects:size()-1, 1, -1 do
		local obj = square:getObjects():get(i)
		local spriteName = obj and ((obj.getSpriteName and obj:getSpriteName()) or (obj.getSprite and obj:getSprite():getName()))
		if spriteName then
			for n=1,#lights do
				local lightName = lights[n]
				if spriteName == lights[n] then
					square:RemoveTileObject(obj)
					break
				end
			end
		end
	end
end

local function getjbObj(square, names)
	if not square then return false; end
	local objs = {}
	for i=0,square:getObjects():size()-1 do
		local thisObj = square:getObjects():get(i)
		local spriteName = thisObj and ((thisObj.getSpriteName and thisObj:getSpriteName()) or (thisObj.getSprite and thisObj:getSprite():getName()))
		if spriteName then
			for k, v in pairs(names) do
				local skip
				for n=1,#v do
					if spriteName == v[n] then
						objs[k] = thisObj
						skip = true
						break
					end
				end
				if skip then break; end
			end
		end
	end
	return objs.main, objs.play1, objs.play2, objs.overlay
end

local function removeObjSingle(JukeboxSquare)
	local lights = {"LS_JukeboxLight_1","LS_JukeboxLight_5","LS_JukeboxLight_2","LS_JukeboxLight_6"}
	local obj
	for i=0,JukeboxSquare:getObjects():size()-1 do
		local thisObj = JukeboxSquare:getObjects():get(i)
		local spriteName = thisObj and ((thisObj.getSpriteName and thisObj:getSpriteName()) or (thisObj.getSprite and thisObj:getSprite():getName()))
		--if object2 and ((object2:getName() == "JukePlayLight1") or (object2:getName() == "JukePlayLight2")) then
		if spriteName then
			for n=1,#lights do
				if spriteName and spriteName == lights[n] then
					obj = thisObj
					break
				end
			end
			if obj then break; end
		end
	end--for
	if obj then JukeboxSquare:RemoveTileObject(obj); end
end

local function getCustomName(object)
	if not object then return nil; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") and (properties:get("CustomName") == "Jukebox") then
        return true
    end
    return nil
end

local function getPlayerDataStrings()
	return {
		"IsListeningToJukebox",
	}
end

local function setPlayerListeningData(playerData, boolean)
	local dataList = getPlayerDataStrings()
	for n=1,#dataList do
		local value = dataList[n]
		playerData[value] = boolean
	end
end

local function addObject(square, obj, spriteName)
	obj:setAlpha(0.8)
	square:AddSpecialObject(obj)
	--obj:setSprite(spriteName)
    --getTileOverlays():fixTableTopOverlays(square)
    --square:RecalcProperties()
    --square:RecalcAllWithNeighbours(true)
end

function LSrefreshJB(playerObj)
	local jukelist = require("Properties/Objects/List")
	if (not jukelist) or (#jukelist == 0) then return; end
	local hasJukeNearby
	for i,v in ipairs(jukelist) do
		local hasCustomName = getCustomName(v)
		if v:hasModData() and v:getModData().OnOff and hasCustomName then
			local JukeboxLightSprite, JukeboxLightSpritePlay1, JukeboxLightSpritePlay2, JukeboxLightSpritePlayOverlay = "LS_JukeboxLight_3", "LS_JukeboxLight_1", "LS_JukeboxLight_2", "LS_JukeboxLight_0"
			local Facing
			local groupName
			---
			if v:getModData().JukeinRange and (v:getModData().JukeinRange ~= "out of range") and (v:getModData().OnOff == "on") and v:getModData().JukeBckpSquare then
				local Jukebox
				Jukebox, Facing, groupName = getObj(v, "Jukebox")
				if Facing and (Facing == "S") then
					JukeboxLightSprite, JukeboxLightSpritePlay1, JukeboxLightSpritePlay2, JukeboxLightSpritePlayOverlay = "LS_JukeboxLight_4", "LS_JukeboxLight_5", "LS_JukeboxLight_6", "LS_JukeboxLight_7"
				end
				if not Jukebox then v:getModData().OnOff = "off"; v:getModData().OnPlay = "nothing"; v:getModData().JukeinRange = "out of range"; end
				if Jukebox and (not sqrHasEnergy(Jukebox)) then v:getModData().OnOff = "off"; v:getModData().OnPlay = "nothing"; end	
			end
			---
			if not playerIsInRange(playerObj, v, 60) then
				if v:getModData().JukeinRange and (v:getModData().JukeinRange ~= "out of range") then
					v:getModData().JukeinRange = "out of range"
					if v:getModData().OnPlay and (v:getModData().OnPlay ~= "nothing") then
						v:getModData().SilenceMusic = "yes"
					end
				end
			else
				if (not v:getModData().JukeinRange) or (v:getModData().JukeinRange and (v:getModData().JukeinRange ~= "out of range") and (v:getModData().JukeinRange ~= "in range")) then
					v:getModData().JukeinRange = "in range"
					if v:getModData().OnOff == "on" then OnJukeboxStart(v:getX(), v:getY(), v:getZ()); end
					if v:getModData().OnPlay and (v:getModData().OnOff == "on") and v:getModData().Length and
					v:getModData().Style and v:getModData().genre then
						v:getModData().OnPlay, v:getModData().Length, v:getModData().genre = "nothing", 3, "JukeboxAfterTurnOn"							
						OnJukeboxStyleChange(v:getX(), v:getY(), v:getZ(), v:getModData().Style, v:getModData().Length, v:getModData().genre)
						hasJukeNearby = true
					end
				else
					if v:getModData().JukeinRange == "out of range" then
						v:getModData().JukeinRange = "in range"
						if v:getModData().OnPlay and (v:getModData().OnOff == "on") and v:getModData().Style then
							OnJukeboxStart(v:getX(), v:getY(), v:getZ())
							v:getModData().OnPlay, v:getModData().Length, v:getModData().genre = "nothing", 3, "JukeboxAfterTurnOn"
							OnJukeboxSendSong(v:getX(), v:getY(), v:getZ(), v)
							hasJukeNearby = true
						end
					elseif v:getModData().JukeinRange == "in range" then
						if v:getModData().JukeNoObject and (v:getModData().OnOff == "on") and v:getModData().OnPlay and v:getModData().Style then
							v:getModData().JukeNoObject = false
							OnJukeboxStart(v:getX(), v:getY(), v:getZ())
							v:getModData().OnPlay, v:getModData().Length, v:getModData().genre = "nothing", 3, "JukeboxAfterTurnOn"	
							OnJukeboxSendSong(v:getX(), v:getY(), v:getZ(), v)
							hasJukeNearby = true
						end
					end
				end
			end--range
			
			------------------------------------
			if not v:getModData().Cell then v:getModData().Cell = v:getCell(); end
			if not v:getModData().JukeBckpSquare then v:getModData().JukeBckpSquare = (v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ())); end					
			if groupName and groupName == "Gramophone" then
				if v:getModData().OnOff and v:getModData().OnOff == "on" and v:getModData().OnPlay and v:getModData().OnPlay ~= "nothing" and
				v:getModData().genre and v:getModData().genre ~= "JukeboxAfterTurnOn" and playerIsInRange(playerObj, v, 30) then
					hasJukeNearby = true
				end
			else
			local JukeboxCell = v:getModData().Cell
			local JukeboxSquare = v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ()) or v:getModData().JukeBckpSquare
			--[[
			print("TROUBLESHOOT START")
			if not v:getModData().JukeBckpSquare then print("v:getModData().JukeBckpSquare NOT FOUND"); end
			if not playerIsInRange(playerObj, v, 30) then print("playerIsInRange NOT IN RANGE"); end
			if not v:getModData().OnOff then print("v:getModData().OnOff NOT FOUND"); end
			if v:getModData().OnOff ~= "on" then print("v:getModData().OnOff NOT ON"); end
			if v:getModData().MainLight then print("v:getModData().MainLight IS FOUND"); end
			if not JukeboxSquare then print("JukeboxSquare NOT FOUND"); end
			if JukeboxSquare and getjbObj(JukeboxSquare, "JukeLight", false, false) then print("getjbObj IS FOUND"); end
			print("TROUBLESHOOT END")
			]]--
			if (v:getModData().OnOff ~= "on") or (not playerIsInRange(playerObj, v, 30)) then
				if JukeboxCell then
					if v:getModData().MainLight then JukeboxCell:removeLamppost(v:getModData().MainLight); v:getModData().MainLight = false; end
					if v:getModData().RGBLightOverlay then JukeboxCell:removeLamppost(v:getModData().RGBLightOverlay); v:getModData().RGBLightOverlay = false; end
				end
				if JukeboxSquare then getObjAndRemove(JukeboxSquare); end			
			elseif v:getModData().OnOff == "on" and playerIsInRange(playerObj, v, 30) and Facing then
				local hasMain = getjbObj(JukeboxSquare, {main={"LS_JukeboxLight_3", "LS_JukeboxLight_4"}})
				if not v:getModData().MainLight or not hasMain then
					--print("CREATING NEW LIGHT")
					local JukeboxLight = IsoObject.new(v:getCell(), JukeboxSquare, JukeboxLightSprite)
					--JukeboxLight:setName("JukeLight")
					if JukeboxSquare then
						addObject(JukeboxSquare, JukeboxLight, JukeboxLightSprite)
						--JukeboxSquare:AddSpecialObject(JukeboxLight)
					end
					v:getModData().MainLight = IsoLightSource.new(v:getX(), v:getY(), v:getZ(), 75, 75, 0, 2)
					if JukeboxCell then JukeboxCell:addLamppost(v:getModData().MainLight); end
				end
				if v:getModData().OnPlay and JukeboxSquare then
					if v:getModData().OnPlay == "nothing" then
						removeObjSingle(JukeboxSquare)
					elseif (v:getModData().genre == "JukeboxAfterTurnOn") and JukeboxCell then
						if v:getModData().RGBLightOverlay then JukeboxCell:removeLamppost(v:getModData().RGBLightOverlay); v:getModData().RGBLightOverlay = false; end
						getObjAndRemoveSecondaryLights(JukeboxSquare)					
					elseif JukeboxCell then
						local mainLight, JukeboxLightPlayOn1, JukeboxLightPlayOn2, JukeboxPlayLightOverlay = getjbObj(JukeboxSquare, {play1={"LS_JukeboxLight_1","LS_JukeboxLight_5"},play2={"LS_JukeboxLight_2","LS_JukeboxLight_6"},overlay={"LS_JukeboxLight_0", "LS_JukeboxLight_7"}})
						if not JukeboxPlayLightOverlay then
							JukeboxPlayLightOverlay = IsoObject.new(v:getCell(), JukeboxSquare, JukeboxLightSpritePlayOverlay)
							--JukeboxPlayLightOverlay:setName("JukePlayLightOverlay")
							addObject(JukeboxSquare, JukeboxPlayLightOverlay, JukeboxLightSpritePlayOverlay)
							--JukeboxSquare:AddSpecialObject(JukeboxPlayLightOverlay)
						else
							if (not v:getModData().changecolor) or ((v:getModData().changecolor ~= 0) and (v:getModData().changecolor ~= 1) and (v:getModData().changecolor ~= 2) and
							(v:getModData().changecolor ~= 3) and (v:getModData().changecolor ~= 4) and (v:getModData().changecolor ~= 5)) then
								v:getModData().changecolor = 1
							end
							local rgbTable = JukeboxProps.get("overlay", v:getModData().changecolor)
							if rgbTable and rgbTable.objR then	
								JukeboxPlayLightOverlay:setCustomColor(rgbTable.objR, rgbTable.objG, rgbTable.objB, 1)
								if v:getModData().RGBLightOverlay then JukeboxCell:removeLamppost(v:getModData().RGBLightOverlay); end
								v:getModData().RGBLightOverlay = IsoLightSource.new(v:getX(), v:getY(), v:getZ(), rgbTable.lightR, rgbTable.lightG, rgbTable.lightB, 3)
								JukeboxCell:addLamppost(v:getModData().RGBLightOverlay)		
							end
							v:getModData().changecolor = math.floor(v:getModData().changecolor+1)
							if v:getModData().changecolor > 5 then v:getModData().changecolor = 0; end
						end
						local lightSprite, lightName = JukeboxLightSpritePlay1, "JukePlayLight1"
						local r, g, b
						local lightsRGB = require("Properties/Light/JBStyles")
						for j, style in ipairs(lightsRGB) do
							if (style.name == v:getModData().Style) or (style.cname == v:getModData().Style) then
								r, g, b = style.r, style.g, style.b
								break
							end
						end
						if JukeboxLightPlayOn1 then
							lightSprite, lightName = JukeboxLightSpritePlay2, "JukePlayLight2"
							JukeboxSquare:RemoveTileObject(JukeboxLightPlayOn1)
						elseif JukeboxLightPlayOn2 then
							JukeboxSquare:RemoveTileObject(JukeboxLightPlayOn2)
						end
						local JukeboxNewPlayLight = IsoObject.new(v:getCell(), JukeboxSquare, lightSprite)
						--JukeboxNewPlayLight:setName(lightName)
						if r and g and b then JukeboxNewPlayLight:setCustomColor(r, g, b, 1); end
						addObject(JukeboxSquare, JukeboxNewPlayLight, lightSprite)
						--JukeboxSquare:AddSpecialObject(JukeboxNewPlayLight)
						hasJukeNearby = true
					end--OnPlay==nothing
				end--OnPlay
			end--ONOFF Lights
			end--GRAMOPHONE
		end--HASMODDATA
	end--for
	setPlayerListeningData(playerObj:getModData(), hasJukeNearby)
end