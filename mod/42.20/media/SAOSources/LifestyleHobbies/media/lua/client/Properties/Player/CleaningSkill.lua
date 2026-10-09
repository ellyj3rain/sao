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

LSCleaning = LSCleaning or {}

LSCleaning.traits = {
	["CLEANFREAK"] = {
		timeAdd=0.5,
	},
	["TIDY"] = {
		timeAdd=-0.2,
	},
	["SLOPPY"] = {
		timeAdd=0.2,
	},
	["ALL_THUMBS"] = {
		timeAdd=0.2,
	},
	["DEXTROUS"] = {
		timeAdd=-0.1,
	},
}

LSCleaning.timeTable = {
	Floor = {
		base=350,
		skill=0.07,
	},
	Bathroom = {
		base=50,
		skill=0.07,
	},
	Unclog = {
		base=3000,
		skill=0.05,
	},
}

LSCleaning.getCleaningTime = function(character, args) -- action, condition, bleachItem
	local data = LSCleaning.timeTable[args[1]]
	if not data then LSUtil.debugPrint("(client) - LSCleaning.getCleaningTime, unable to find cleaning data for "..tostring(args[1])..", returning 1 ----"); return 1; end
	-----------------
	-------BASE
	local cleanTime = data.base
	-------OBJ_CONDITION
	--if args[2] and args[2] > 0 then cleanTime = cleanTime*args[2]; end
	-------BLEACH
	if args[3] then
		cleanTime = cleanTime*1.5
		local fluidContainer = LSUtil.getFluidContainer(args[3])
		if not fluidContainer:isPureFluid(Fluid.Bleach) then
			local percent = LSUtil.getPercentage(fluidContainer:getAmount(),fluidContainer:getSpecificFluidAmount(Fluid.Bleach),false,false)
			cleanTime = math.ceil(cleanTime+(10000/percent))			
		end
	end
	-------AMBT
	if LSAmbtMng.hasCompleted(character, 'LSGrimeFighter') then cleanTime = cleanTime/2; end
	-------TRAITS
	local mult = 1
	for k, v in pairs(LSCleaning.traits) do
		if character:hasTrait(CharacterTrait[k]) then
			mult = mult+v.timeAdd
		end
	end
	cleanTime = cleanTime*mult
	-------SKILL
	cleanTime = cleanTime - (data.base*(character:getPerkLevel(Perks.Cleaning)*data.skill))
	-------RETURN
	return math.max(1, math.floor(cleanTime))
end
