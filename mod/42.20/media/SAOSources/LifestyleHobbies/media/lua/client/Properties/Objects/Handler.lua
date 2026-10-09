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

require "LSEffectsJukeboxFunctions"

local LSInteractiveObjs = {}
LSInteractiveObjs.total = 30--150
LSInteractiveObjs.count = 0

LSInteractiveObjs.Jukebox = function(thisPlayer, object)
	if object and object:hasModData() and object:getModData().OnOff and
	object:getModData().OnOff == "on" and object:getModData().OnPlay and
	object:getModData().OnPlay ~= "nothing" and tostring(object:getModData().Style) ~= nil then
		local style = object:getModData().Style
		if (not object:getModData().Emitter) or (not object:getModData().OnPlayEMITTER) then
			object:getModData().OnPlay = "nothing"
			object:getModData().Length = 3
			object:getModData().genre = "JukeboxAfterTurnOn"
			OnJukeboxStyleChange(object:getX(), object:getY(), object:getZ(), style, 3, "JukeboxAfterTurnOn")			
		end
		if thisPlayer:getModData().IsListeningToDJ then thisPlayer:getModData().IsListeningToJukebox = false; return; end
		thisPlayer:getModData().IsListeningToJukebox = true
		if (not thisPlayer:getModData().IsListeningToMusicStyle) or
		tostring(thisPlayer:getModData().IsListeningToMusicStyle) ~= tostring(style) then
			thisPlayer:getModData().IsListeningToMusicStyle = tostring(style)
		end
	else
	thisPlayer:getModData().IsListeningToJukebox = false
	end
end

LSInteractiveObjs.DiscoBall = function(thisPlayer, object)
	--tbd
end

LSInteractiveObjs.DiscoFloor = function(thisPlayer, object)
	--tbd
end

LSInteractiveObjs.GFClock = function(thisPlayer, object)
	--tbd
end

LSInteractiveObjs.Hygienator = function(thisPlayer, object)
	--tbd
end

local function getInteractiveObjsCNOrGN()
	return {"Jukebox","Disco Ball","GF Clock","StationWork","Sculpture Ice","Sculpture Lamp", "Disco Floor", "Hygienator", "FoodSynthesizer", "DrinkingBuddy"}
end

local function checkList(object, objList)
	if #objList == 0 then return false; end
	local hasObj = false
	for i,v in pairs(objList) do
		if v and v:getSquare() and v:getX() and v:getY() and (v:getX() == object:getX()) and (v:getY() == object:getY()) then hasObj = true; break; end
	end
	return hasObj
end

local function getPropertyName(object, property)
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has(property) then
        return properties:get(property)
    end
    return nil
end

local function LSScanObjs(numberTicks)

    LSInteractiveObjs.count = LSInteractiveObjs.count + getGameTime():getGameWorldSecondsSinceLastUpdate()
	if LSInteractiveObjs.count >= LSInteractiveObjs.total then
        LSInteractiveObjs.count = 0
		local thisPlayer = getSpecificPlayer(0)
		if not thisPlayer then return; end
		local objList = require("Properties/Objects/List")
		local t = getInteractiveObjsCNOrGN()
		local hasJuke = false
		for x = thisPlayer:getX()-8,thisPlayer:getX()+8 do
			for y = thisPlayer:getY()-8,thisPlayer:getY()+8 do
				local square = getCell():getGridSquare(x,y,thisPlayer:getZ())
				if square then
					for i=0,square:getObjects():size()-1 do
						local thisObject = square:getObjects():get(i)
						if thisObject and thisObject:getSprite() and thisObject:getSprite():getProperties() then
							local customName = getPropertyName(thisObject, "CustomName")
							local groupName = getPropertyName(thisObject, "GroupName")
							if customName or groupName then
								if customName == "Jukebox" then hasJuke = true; end
								for n=1, #t do
									local nameWS
									if customName and customName == t[n] then
										nameWS = customName:gsub(" ", "")
									elseif groupName and groupName == t[n] then
										nameWS = groupName:gsub(" ", "")
									end
									if nameWS then
										if not checkList(thisObject, objList) then
											table.insert(objList, thisObject)
										end
										if LSInteractiveObjs[nameWS] then LSInteractiveObjs[nameWS](thisPlayer, thisObject); end
										break
									end
								end
							end
						end
					end
				end
			end
		end
		if thisPlayer:getModData().IsListeningToJukebox and not hasJuke then thisPlayer:getModData().IsListeningToJukebox = false; end
	end
end


local function ScanAreaOnce(range)
	local thisPlayer = getSpecificPlayer(0)
	if not thisPlayer then return; end
	local objList = require("Properties/Objects/List")
	local t = getInteractiveObjsCNOrGN()

	for x = thisPlayer:getX()-range,thisPlayer:getX()+range do
		for y = thisPlayer:getY()-range,thisPlayer:getY()+range do
			local square = getCell():getGridSquare(x,y,thisPlayer:getZ())
			if square then
				for i=0,square:getObjects():size()-1 do
					local thisObject = square:getObjects():get(i)
					if thisObject and thisObject:getSprite() and thisObject:getSprite():getProperties() then
						local customName = getPropertyName(thisObject, "CustomName")
						local groupName = getPropertyName(thisObject, "GroupName")
						if customName or groupName then
							for n=1, #t do
								local nameWS
								if customName and customName == t[n] then
									nameWS = customName:gsub(" ", "")
								elseif groupName and groupName == t[n] then
									nameWS = groupName:gsub(" ", "")
								end
								if nameWS then
									if not checkList(thisObject, objList) then
										table.insert(objList, thisObject)
									end
									if LSInteractiveObjs[nameWS] then LSInteractiveObjs[nameWS](thisPlayer, thisObject); end
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

local function LSOnScanObjStart()
	LSInteractiveObjs.total = 30/GTLSCheck
	if LSInteractiveObjs.event then return; end
    Events.OnTick.Add(LSScanObjs)
	ScanAreaOnce(60)
	LSInteractiveObjs.event = true
end
Events.OnGameStart.Add(LSOnScanObjStart)
