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

local function getNewMode(oldMode)
	local modes = {"default","random","circles","spots","gold","rainbow","valentine"}
	if oldMode then
		for n=1, #modes do
			if modes[n] == oldMode then table.remove(modes, n); break; end
		end
	end
	local idx = ZombRand(#modes)+1
	return modes[idx]
end

local function getRandomT(args)
	local t = {}
	for i=1, #args do
		local argRdm = ZombRand(args[i])+1
		if i < 3 then
			local flip = ZombRand(2)+1
			if flip == 2 then argRdm = -argRdm; end
		elseif (i >= 3) and (i <= 5) then
			if t[3] and (t[3] > 100) then argRdm = ZombRand(50)+1;
			elseif t[4] and (t[4] > 100) then argRdm = ZombRand(50)+1; end
		end
		table.insert(t, argRdm)
	end
	return t
end

local function getObj(v, cm)
	local obj
	local Dsqr = v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ()) or v:getModData().DiscoBckpSquare

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
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end

local function playerIsInRange(player, obj)
	if player and (player:getX() >= obj:getX() - 30 and player:getX() <= obj:getX() + 30 and
	player:getY() >= obj:getY() - 30 and player:getY() <= obj:getY() + 30) then return true; end
	return false
end

local function dbColorChange(square)
	if not square then return 0; end
	local change
	for i=0,square:getObjects():size()-1 do
		local obj = square:getObjects():get(i)
		local spriteName = obj and ((obj.getSpriteName and obj:getSpriteName()) or (obj.getSprite and obj:getSprite():getName()))
		if spriteName then
			if spriteName == "LS_Discoball_1" then
				change = 1
			elseif spriteName == "LS_Discoball_2" then
				change = 2
			elseif spriteName == "LS_Discoball_3" then
				change = 3
			elseif spriteName == "LS_Discoball_4" then
				change = 0
			end
			if change then square:RemoveTileObject(obj); break; end
			--if change then sledgeDestroy(obj); end
		end
	end--for
	if not change then change = 0; end
	return change
end

local function getdbRGBLightsRandom()
	return {"DiscoBallRGBLight","DiscoBallRGBLight2","DiscoBallRGBLight3","DiscoBallRGBLight4"}
end

local function getdbRGBLights()
	return {"DiscoBallRGBLight","DiscoBallRGBLight2","DiscoBallRGBLight3","DiscoBallRGBLight4","DiscoBallRGBLight5","DiscoBallRGBLight6","DiscoBallRGBLight7","DiscoBallRGBLight8",
	"DiscoBallRGBLightA1","DiscoBallRGBLightA2","DiscoBallRGBLightA3","DiscoBallRGBLightA4","DiscoBallRGBLightA5","DiscoBallRGBLightA6","DiscoBallRGBLightA7","DiscoBallRGBLightA8"}
end

local function doDBSprite(bc, square, cell)
	local sprite, name = "LS_Discoball_1", "DiscoLight1"
	if bc == 1 then
		sprite, name = "LS_Discoball_2", "DiscoLight2"
	elseif bc == 2 then
		sprite, name = "LS_Discoball_3", "DiscoLight3"
	elseif bc == 3 then
		sprite, name = "LS_Discoball_4", "DiscoLight4"
	end
	local obj = IsoObject.new(cell, square, sprite)
	obj:setAlpha(0.8)
	--DiscoBallTurnedOn:setName(name)
	--square:AddTileObject(obj)
	--obj:setSprite(sprite)
	square:AddSpecialObject(obj)
end

local function getObjAndRemove(square)
	local lights = {"LS_Discoball_1","LS_Discoball_2","LS_Discoball_3","LS_Discoball_4"}
	local obj
	for i=0,square:getObjects():size()-1 do
	--for i = DiscoBallSquare:getObjects():size()-1, 1, -1 do
		local thisObj = square:getObjects():get(i)
		local spriteName = thisObj and ((thisObj.getSpriteName and thisObj:getSpriteName()) or (thisObj.getSprite and thisObj:getSprite():getName()))
		if spriteName then
			for n=1,#lights do
				if spriteName == lights[n] then
					obj = thisObj
					break
				end
			end
			if obj then break; end
		end
	end
	if obj then square:RemoveTileObject(obj); end
	--if obj then sledgeDestroy(obj); end
end

local function getCustomName(object)
	if not object then return nil; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") and (properties:get("CustomName") == "Disco Ball") then
        return true
    end
    return nil
end

function LSrefreshDB(playerObj)

	local discolist = require("Properties/Objects/List")
	if (not discolist) or (#discolist == 0) then return; end

	for i,v in ipairs(discolist) do
		local hasCustomName = getCustomName(v)
		if v:hasModData() and
		v:getModData().OnOff and hasCustomName then
			---
			if v:getModData().OnOff == "on" and
			v:getModData().DiscoBckpSquare ~= nil then
				local DiscoBall = getObj(v, "Disco Ball")
				if not DiscoBall then v:getModData().OnOff = "off";end
				if DiscoBall and (not sqrHasEnergy(DiscoBall)) then v:getModData().OnOff = "off"; end
			end
			---
			if not v:getModData().Cell then v:getModData().Cell = v:getCell(); end
			if not v:getModData().DiscoBckpSquare then v:getModData().DiscoBckpSquare = (v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ())); end							
			local DiscoBallCell = v:getModData().Cell
			local DiscoBallSquare = v:getCell():getGridSquare(v:getX(), v:getY(), v:getZ()) or v:getModData().DiscoBckpSquare

			if v:getModData().OnOff == "on" and playerIsInRange(playerObj, v) then
				if v:getModData().Shuffle and ((v:getModData().Mode == "shuffle") or (v:getModData().MainLight and v:getModData().MainLight == 0)) then
					v:getModData().Mode = getNewMode(v:getModData().Mode)
				end
				if (not v:getModData().MainLight) or (not v:getModData().BallMainLight) then
					if v:getModData().Mode then
						local r, g, b, c = DiscoBallProps.get(v:getModData().Mode, 0)
						v:getModData().BallMainLight = IsoLightSource.new(v:getX(), v:getY(), v:getZ(), r, g, b, c)
						DiscoBallCell:addLamppost(v:getModData().BallMainLight)
						v:getModData().MainLight = 1
					end
				else
					if not playerObj:getModData().ActiveDiscoBallNearby then playerObj:getModData().ActiveDiscoBallNearby = true; end					
					DiscoBallCell:removeLamppost(v:getModData().BallMainLight)
					local r, g, b, c = DiscoBallProps.get(v:getModData().Mode, v:getModData().MainLight)
					v:getModData().BallMainLight = IsoLightSource.new(v:getX(), v:getY(), v:getZ(), r, g, b, c)
					DiscoBallCell:addLamppost(v:getModData().BallMainLight)
					
					v:getModData().MainLight = math.floor(v:getModData().MainLight+1)
					if v:getModData().MainLight > 3 then v:getModData().MainLight = 0; end
				end

				--
				v:getModData().BallColorChange = dbColorChange(DiscoBallSquare)

				local t = getdbRGBLights()
				for n=1, #t do
					local rgblight = t[n]
					if v:getModData()[rgblight] then
						DiscoBallCell:removeLamppost(v:getModData()[rgblight])
						v:getModData()[rgblight] = false
					end
				end

				if DiscoBallSquare and (v:getModData().Mode ~= "random") then
					local DiscoLightsRGB = require("Properties/Light/DB_"..v:getModData().Mode)
					doDBSprite(v:getModData().BallColorChange, DiscoBallSquare, v:getCell())
					for j, light in ipairs(DiscoLightsRGB) do
						if v:getModData().BallColorChange == light.stage then
							v:getModData()[light.name] = IsoLightSource.new(v:getX()+light.x, v:getY()+light.y, v:getZ(), light.r, light.g, light.b, light.c)
							DiscoBallCell:addLamppost(v:getModData()[light.name])
						end
					end
				elseif DiscoBallSquare then
					local DiscoLightsRGB = getdbRGBLightsRandom()
					doDBSprite(v:getModData().BallColorChange, DiscoBallSquare, v:getCell())
					for n=1, #DiscoLightsRGB do
						local randomT = getRandomT({6, 6, 200, 200, 200, 3})
						v:getModData()[DiscoLightsRGB[n]] = IsoLightSource.new(v:getX()+randomT[1], v:getY()+randomT[2], v:getZ(), randomT[3], randomT[4], randomT[5], randomT[6])
						DiscoBallCell:addLamppost(v:getModData()[DiscoLightsRGB[n]])
					end								
				end

			elseif DiscoBallCell then
				if v:getModData().BallMainLight then
					DiscoBallCell:removeLamppost(v:getModData().BallMainLight)
					v:getModData().MainLight = 0		
				end
				
				local t = getdbRGBLights()
				for n=1, #t do
					local rgblight = t[n]
					if v:getModData()[rgblight] then
						DiscoBallCell:removeLamppost(v:getModData()[rgblight])
						v:getModData()[rgblight] = false
					end
				end
				
				v:getModData().BallColorChange = 0
				if DiscoBallSquare then
					getObjAndRemove(DiscoBallSquare)
				
				end
				
			end--ONOFF
		end--HASMODDATA		
	end
end
