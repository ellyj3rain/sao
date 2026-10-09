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

LSUIPrefs = {}

LSUIPrefs.getAllPrefs = function(uiName)
	local file = getFileReader("LSUIPrefs.ini",true)
	if not file then return false; end -- failed to write file
	local t = {}
	local line
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local splitedLine = string.split(line, "=")
		local name = splitedLine[1]
		if not uiName or name ~= uiName then table.insert(t, line); end
	end
	return t
end

LSUIPrefs.getPrefs = function(uiName)
	local file = getFileReader("LSUIPrefs.ini",true)
	if not file then return false; end -- failed to write file
	local line
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local splitedLine = string.split(line, "=")
		local name = splitedLine[1]
		if name == uiName then
			local values = string.split(splitedLine[2], ",")
			return tonumber(values[1]), tonumber(values[2])
		end
	end
	return nil
end

LSUIPrefs.updatePref = function(uiName, x, y)
	local allLines = LSUIPrefs.getAllPrefs(uiName)
	if not allLines then return; end
	local newKey = uiName.."="..tostring(x)..","..tostring(y)
	table.insert(allLines, newKey)
	local file = getFileWriter("LSUIPrefs.ini",true,false) -- append is false (override)
	if not file then return; end -- failed to write file
	for n=1, #allLines do
		file:write(allLines[n].."\n")
	end
	file:close()
end

