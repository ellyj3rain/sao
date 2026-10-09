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
LSHygiene = LSHygiene or {}
LSHygiene.Sounds = {};
LSHygiene.Sounds._cache = {}
LSHygiene.Sounds.BrushTeeth = {"Brush_Teeth",4}

LSHygiene.Sounds.getFromFile = function(fileName) -- ToiletSounds;etc
	if not LSHygiene.Sounds._cache[fileName] then LSHygiene.Sounds._cache[fileName] = require("Hygiene/Tracks/"..fileName); end
	return LSHygiene.Sounds._cache[fileName]
end

LSHygiene.Sounds.filterByCategory = function(sounds, category)
	local available = {}
	for k,v in pairs(sounds) do
		if v.category == category then
			table.insert(available, v)
		end
	end
	return available
end

LSHygiene.Sounds.getFirstByCategory = function(sounds, category)
	for k,v in ipairs(sounds) do
		if v.category == category then return v; end
	end
	return nil
end

LSHygiene.Sounds.getRandomFromFile = function(category, fileName, oldID)
	local sounds = LSHygiene.Sounds.getFromFile(fileName)
	if not sounds then return nil; end
	if category then sounds = LSHygiene.Sounds.filterByCategory(sounds, category); end
	if not sounds or #sounds == 0 then return nil; end
	if not oldID then return sounds and #sounds > 0 and sounds[ZombRand(#sounds)+1]; end
	local newSounds = {}
	for k, v in pairs(sounds) do
		if not v.id or v.id ~= oldID then table.insert(newSounds, v); end
	end
	return newSounds and ((#newSounds > 0 and newSounds[ZombRand(#newSounds)+1]) or sounds[1])
end

LSHygiene.Sounds.getRandom = function(group, oldSound)
	local sounds = LSHygiene.Sounds[group]
	if not sounds then return ""; end
	if not oldSound then return sounds[1]..tostring(ZombRand(sounds[2])+1); end
	local newSounds = {}
	for n=1, sounds[2] do
		local name = sounds[1]..tostring(n)
		if not oldSound or name ~= oldSound then table.insert(newSounds, name); end
	end
	return newSounds and ((#newSounds > 0 and newSounds[ZombRand(#newSounds)+1]) or sounds[1])
end
