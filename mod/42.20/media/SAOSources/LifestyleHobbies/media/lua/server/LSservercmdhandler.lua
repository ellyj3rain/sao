
if ISPlace3DItemCursor then
	local ogGetSurface = ISPlace3DItemCursor.getSurface
	function ISPlace3DItemCursor:getSurface( _square )
		for i=1,_square:getObjects():size() do
			local object = _square:getObjects():get(i-1);
			if object:getSurfaceOffsetNoTable() > 0 then
				local properties = object:getSprite() and object:getSprite():getProperties()
				if properties and properties:has("CustomName") and properties:get("CustomName") == "Jukebox" then
					return 0
				end
			end
		end
		return ogGetSurface(self, _square)
	end
end

local function CreateDirtPuddle(arg)
    local entity, isOverlay, spriteName = arg[1], arg[2], arg[3]
	if isOverlay then
		entity:setOverlaySprite(spriteName, 1, 1, 1, 1)
		entity:transmitUpdatedSpriteToClients()
	else
		local NewLitterObj = IsoObject.new(targetFloor, spriteName)
		targetFloor:AddTileObject(NewLitterObj)
		NewLitterObj:transmitCompleteItemToClients()
		--targetFloor:transmitAddObjectToSquare(NewLitterObj, -1)
	end
end

function LSServerCommandHandler(command, arg)
	--if command then print("LSServerCommandHandler with command "..command); else print("LSServerCommandHandler failed command is NIL"); end
	if command and command == "CreateDirtPuddle" then CreateDirtPuddle(arg); end
end
