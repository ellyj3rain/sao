-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

require "Properties/DiscoFloorLights"

local function getNewMode(oldMode)
	local modes = {"default","checkers","lines"}
	if oldMode then
		for n=1, #modes do
			if modes[n] == oldMode then table.remove(modes, n); break; end
		end
	end
	local idx = ZombRand(#modes)+1
	return modes[idx]
end

local function updateMode(mainDF)
	return mainDF:getModData().Mode or "default"
end

local function getObj(v, cm)
	local obj
	local Dsqr = v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ()) or v:getModData().DiscoFloorBckpSquare

	for i=0,Dsqr:getObjects():size()-1 do
		local thisObject = Dsqr:getObjects():get(i)	
		local thisSprite = thisObject:getSprite()
				
		if thisSprite then	
			local properties = thisObject:getSprite():getProperties()
			if properties and properties:has("CustomName") and (properties:get("CustomName") == cm) then
				obj = thisObject;
			end
		end
	end
	return obj
end

local function sqrHasEnergy(obj)
	if not obj then return false; end
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end

local function playerIsInRange(player, obj)
	if player and (player:getX() >= obj:getX() - 15 and player:getX() <= obj:getX() + 15 and
	player:getY() >= obj:getY() - 15 and player:getY() <= obj:getY() + 15) then return true; end
	return false
end
--[[
local function getObjAndRemove(DFSquare)
	local obj
	for i=0,DFSquare:getObjects():size()-1 do
		local object2 = DFSquare:getObjects():get(i);
		if object2 and (object2:getName() == "DiscoFloorLight") then
			obj = object2
			break
		end
	end--for
	if obj then DFSquare:RemoveTileObject(obj); end
end

local function doDFSprite(DFSquare, spriteColor)
	getObjAndRemove(DFSquare)
	local sprite, name = "LS_Disco"..spriteColor, "DiscoFloorLight"
	local newObj = IsoObject.new(DFSquare, sprite)
	newObj:setName(name)
	DFSquare:AddTileObject(newObj)
end
]]--

local function getObjAndRemove(DFObject)
	DFObject:setOverlaySprite(nil, false)
end

local function doDFSprite(DFObject, spriteColor)
	local sprite = "LS_Disco"..spriteColor
	DFObject:setOverlaySprite(sprite, false)
end

local function getCustomName(object, cName)
	if not object then return false; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") and (properties:get("CustomName") == cName) then
        return true
    end
    return false
end

local function objectIsValid(obj)
	if obj and instanceof(obj, "IsoObject") and obj:getSquare() and obj:getX() and obj:getY() then return true; end
	return false
end

--[[
local function objIsClose(source, obj)
	if source and (source:getX() >= obj:getX() - 15 and source:getX() <= obj:getX() + 15 and
	source:getY() >= obj:getY() - 15 and source:getY() <= obj:getY() + 15) then return true; end
	return false
end

local function objIsMainDF(obj)
	if obj and obj:hasModData() and obj:getModData().Connected and obj:getModData().IsMainDF then return obj; end
	return false
end

local function getMainDanceFloor(obj)
	local objList = require("Properties/Objects/List")
	if (not objList) or (#objList == 0) then return false; end
	local mainDanceFloor
	for i,v in ipairs(objList) do
		if objectIsValid(v) and objIsClose(obj, v) then
			local customName = getCustomName(v, "Disco Floor")
			if customName and objIsMainDF(v) then
				mainDanceFloor = v
				break
			end
		end
	end
	return mainDanceFloor
end

local function getNewCoords(obj)
	local DF = getMainDanceFloor(obj)
	if not DF then return false; end
	return {DF:getX(), DF:getY()}
end
]]--
local function getDFObj(source, coords, ogDF)
	if not coords then return false; end
	if objectIsValid(ogDF) and ogDF:hasModData() and ogDF:getModData().Connected and ogDF:getModData().IsMainDF then return ogDF; end
	--if not coords then coords = getNewCoords(source); end
	--if not coords then print("getDFObj getNewCoords FAILED"); return false; end
	local mainDF
	local square = getCell():getGridSquare(coords[1],coords[2],source:getZ());
	if square then
		for i = 0,square:getObjects():size()-1 do
			local object = square:getObjects():get(i);
			if object and instanceof(object, "IsoObject") and object:hasModData() and object:getModData().Connected and object:getModData().IsMainDF then -- NTY
				mainDF = object
				break
			end
		end
	end
	return mainDF
end

local function hasActiveDataDJ(playerData)
	if (LS_DJBooth and LS_DJBooth.isPlaying) or playerData.IsListeningToDJ then return true; end
	return false
end

local function hasActiveData(Jukebox)
	if Jukebox:getModData().OnOff and Jukebox:getModData().OnPlay and
	Jukebox:getModData().OnOff == "on" and Jukebox:getModData().OnPlay == "playing" then return true; end
	return false
end

local function getActiveObj(object, playerObj)
	local hasActiveObj = "off"
	local playerData = playerObj:getModData()
	for x = object:getX()-8,object:getX()+8 do
		for y = object:getY()-8,object:getY()+8 do
			local square = getCell():getGridSquare(x,y,object:getZ());
			if square then
				for i = 0,square:getObjects():size()-1 do
					local newObject = square:getObjects():get(i);
					if newObject and instanceof(newObject, "IsoObject") then
						if (getCustomName(newObject, "Booth") or getCustomName(newObject, "Microphone")) and hasActiveDataDJ(playerData) then
							hasActiveObj = "on"
							break
						elseif getCustomName(newObject, "Jukebox") and hasActiveData(newObject) then
							hasActiveObj = "on"
							break
						end
					end
				end
			end
		end
	end
	return hasActiveObj
end

function LSrefreshDF(playerObj)

	--print("LSrefreshDF AT 0")
	local discolist = require("Properties/Objects/List")
	if (not discolist) or (#discolist == 0) then return; end

	for i,v in ipairs(discolist) do
		local hasCustomName = getCustomName(v, "Disco Floor")
		--if (not hasCustomName) and v and v:hasModData() and v:getModData().DiscoFloorBckpSquare then print("LSrefreshDF hasCustomName FALSE DiscoFloorBckpSquare TRUE"); end
		--if hasCustomName and not v:getModData().IsMainDF then print("LSrefreshDF hasCustomName TRUE"); if (v:getModData().Connected or v:getModData().DFOnOff) then print("LSrefreshDF Connected or DFOnOff TRUE"); end; end
		if hasCustomName and (v:getModData().Connected or v:getModData().DFOnOff) and not v:getModData().IsMainDF then
			--print("LSrefreshDF AT 1 - hasCustomName")
			---
			local hasDF = true
			if not v:getModData().DFOnOff then v:getModData().DFOnOff = "off"; end
			if v:getModData().DFOnOff == "on" and
			v:getModData().DiscoFloorBckpSquare ~= nil then
				local DF = getObj(v, "Disco Floor")
				if not DF then v:getModData().DFOnOff = "off"; hasDF = false; end
				if DF and ((not sqrHasEnergy(DF)) or not v:getModData().Connected) then v:getModData().DFOnOff = "off"; end
			end
			---
			if not v:getModData().Cell then v:getModData().Cell = v:getCell(); end
			if not v:getModData().DiscoFloorBckpSquare then v:getModData().DiscoFloorBckpSquare = (v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ())); end				
			local DFCell = v:getModData().Cell
			local DFSquare = v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ()) or v:getModData().DiscoFloorBckpSquare
			local mainDFobj
			local playerInRange = false
			if playerIsInRange(playerObj, v) then
				playerInRange = true
				--print("LSrefreshDF AT 2 - playerInRange")
				if v:getModData().IsMainDF then
					local nearbyActive = getActiveObj(v, playerObj)
					if not sqrHasEnergy(v) then v:getModData().DFOnOff = "off"; else v:getModData().DFOnOff = nearbyActive; end
					if not v:getModData().Connected then v:getModData().Connected = {v:getX(),v:getY()}; end
				else
					mainDFobj = getDFObj(v, v:getModData().Connected, v:getModData().ConnectedObj)
					v:getModData().ConnectedObj = mainDFobj
					if (not mainDFobj) or (not sqrHasEnergy(v)) or (not hasDF) then v:getModData().Connected = false; v:getModData().DFOnOff = "off";
					else v:getModData().DFOnOff = mainDFobj:getModData().DFOnOff; end
				end
			end
			if v:getModData().DFOnOff == "on" and playerInRange then
				--print("LSrefreshDF AT 3 - on")
				if v:getModData().IsMainDF and ((not v:getModData().MainLight) or (v:getModData().MainLight and v:getModData().MainLight == 0)) then
					v:getModData().Mode = getNewMode(v:getModData().Mode)
				end
				if mainDFobj then 
					local oldMode = v:getModData().Mode
					v:getModData().Mode = updateMode(mainDFobj)
					if oldMode and oldMode ~= v:getModData().Mode then v:getModData().MainLight = 0; end
				end
				if (not v:getModData().MainLight) or (not v:getModData().DFMainLight) then 
					if v:getModData().Mode then
						local spriteColor, r, g, b, c = DFProps.get(v:getModData().Mode, v:getModData().Connected, v:getX(), v:getY(), 0)
						v:getModData().DFMainLight = IsoLightSource.new(v:getX(), v:getY(), v:getZ(), r, g, b, c)
						DFCell:addLamppost(v:getModData().DFMainLight)
						--doDFSprite(DFSquare, spriteColor)
						doDFSprite(v, spriteColor)
						v:getModData().MainLight = 1
					end
				else
					--print("LSrefreshDF AT 4 - doSprite")
					--if not playerObj:getModData().ActiveDiscoFloorNearby then playerObj:getModData().ActiveDiscoFloorNearby = true; end					
					DFCell:removeLamppost(v:getModData().DFMainLight)
					local spriteColor, r, g, b, c = DFProps.get(v:getModData().Mode, v:getModData().Connected, v:getX(), v:getY(), v:getModData().MainLight)
					v:getModData().DFMainLight = IsoLightSource.new(v:getX(), v:getY(), v:getZ(), r, g, b, c)
					DFCell:addLamppost(v:getModData().DFMainLight)
					--doDFSprite(DFSquare, spriteColor)
					doDFSprite(v, spriteColor)
					v:getModData().MainLight = math.floor(v:getModData().MainLight+1)
					if v:getModData().MainLight > 7 then v:getModData().MainLight = 0; end
				end

				
				--
			elseif DFCell then
			--print("LSrefreshDF AT 5 - DFCell")
				if v:getModData().DFMainLight then
					--print("LSrefreshDF AT 5.1 - DFMainLight")
					DFCell:removeLamppost(v:getModData().DFMainLight)
					v:getModData().MainLight = 0		
				end
				if DFSquare then
					--print("LSrefreshDF AT 5.2 - DFSquare")
					--getObjAndRemove(DFSquare)
					getObjAndRemove(v)
				end
			end--ONOFF
		elseif (not hasCustomName) and v and v:hasModData() and v:getModData().DiscoFloorBckpSquare and not v:getModData().IsMainDF then
			if v:getModData().DFMainLight then
				--print("LSrefreshDF AT 5.1 - DFMainLight")
				v:getModData().Cell:removeLamppost(v:getModData().DFMainLight)
				v:getModData().MainLight = 0		
			end
			--getObjAndRemove(v:getModData().DiscoFloorBckpSquare)
			getObjAndRemove(v)
			v:getModData().Cell = false; v:getModData().DiscoFloorBckpSquare = false; v:getModData().Connected = false; v:getModData().ConnectedObj = false; v:getModData().DFOnOff = "off"

			sendClientCommand("LS", "ModifyObjData", {{v:getX(),v:getY(),v:getZ(),v:getSprite():getName()}, false, v:getModData()})

			--v:transmitModData()
		end--HASMODDATA		
	end
end
