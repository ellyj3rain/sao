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

require ("ISBaseObject")

HygieneHeatObject = ISBaseObject:derive("HygieneHeatObject")

function HygieneHeatObject:init()

	local cell = getCell()
	if cell and cell:getGridSquare(self.pX, self.pY, self.pZ) and not self.heatSource then
		--print("Obj heat is " .. self.heatObj)
		self.heatSource = IsoHeatSource.new(self.pX, self.pY, self.pZ, self.radius, self.heatObj)
		cell:addHeatSource(self.heatSource)   
	else
		--print("failed to create heat source")
		self:destroy()
    end
end

function HygieneHeatObject:destroy()
    if self.heatSource then
		--print("removing obj heat")
        getCell():removeHeatSource(self.heatSource)
        self.heatSource = nil
    end
end

function HygieneHeatObject:new(x, y, z, radius, heat)
    local o = ISBaseObject:new()
    setmetatable(o, self)
    self.__index = self
    o.heatSource = nil
    o.pX = x
    o.pY = y
    o.pZ = z
    o.radius = radius
    o.heatObj = heat
    o:init()
    return o
end