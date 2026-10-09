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

LS_FileMng = {}

LS_FileMng.separators = {
	['LSConfig.ini'] = "=",
	['LSUIPrefs.ini'] = "=",
	['LSNoteExclude.ini'] = "=",
}

local function getLineInfo(line, separator)
	if separator then
		local splitedLine = string.split(line, separator)
		return splitedLine[1], splitedLine[2]
	end
	return line, false
end

LS_FileMng.readOrCreate = function(fileName, create)
	return getFileReader(fileName, create)
end

LS_FileMng.write = function(fileName, append)
	return getFileWriter(fileName, true, append)
end

LS_FileMng.getLines = function(fileName, exclude, forbid)
	local file = LS_FileMng.readOrCreate(fileName, true)
	if not file then return false; end
	local t, line = {}, false
	local separator = LS_FileMng.separators[fileName]
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local name, value = getLineInfo(line, separator)
		if not exclude or name ~= exclude then table.insert(t, line); end
		if forbid and name == forbid then file:close(); return false; end
	end
	return t
end

local function sortLineFormat(value, formatting)
	if not value or value == "" then return false; end
	if formatting then
		return (formatting == "bool" and value ~= "FALSE") or (formatting == "num" and tonumber(value))
	end
	return value
end

LS_FileMng.getSpecificLine = function(fileName, lineName, formatting)
	local file = LS_FileMng.readOrCreate(fileName, true)
	if not file then return false; end
	local line
	local separator = LS_FileMng.separators[fileName]
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local name, value = getLineInfo(line, separator)
		if name == lineName then
			file:close()
			return name, sortLineFormat(value, formatting)
		end
	end
	return false
end

LS_FileMng.getLineValue = function(fileName, lineName, formatting)
	local file = LS_FileMng.readOrCreate(fileName, true)
	if not file then return false; end
	local line
	local separator = LS_FileMng.separators[fileName]
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local name, value = getLineInfo(line, separator)
		if name == lineName then
			file:close()
			return sortLineFormat(value, formatting)
		end
	end
	return false
end

LS_FileMng.getLineName = function(fileName, lineValue)
	local separator = LS_FileMng.separators[fileName]
	if not separator then return false; end
	local file = LS_FileMng.readOrCreate(fileName, true)
	if not file then return false; end
	local line
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local name, value = getLineInfo(line, separator)
		if value == lineValue then file:close(); return name; end
	end
	return false
end

local function sortNewLineFormat(lineValue, formatting)
	if formatting then
		if formatting == "bool" then -- add more here
			return (lineValue and (type(lineValue) ~= "string" or lineValue ~= "FALSE") and "TRUE") or "FALSE"
		end
	elseif not lineValue then
		return false
	end
	return tostring(lineValue)
end

LS_FileMng.newLine = function(fileName, lineName, lineValue, formatting)
	local allLines = LS_FileMng.getLines(fileName, false, lineName)
	if not allLines then return; end
	local separator = LS_FileMng.separators[fileName]
	local newLineValue = sortNewLineFormat(lineValue, formatting)
	local newKey = lineName..(separator or "")..(newLineValue or "")
	local file = LS_FileMng.write(fileName, true) -- append is true (no overwrite)
	if not file then return; end -- failed to write file
	file:write(newKey.."\n")
	file:close()
end

LS_FileMng.changeLine = function(fileName, lineName, lineValue, formatting)
	local allLines = LS_FileMng.getLines(fileName, lineName, false)
	if not allLines then return; end
	local separator = LS_FileMng.separators[fileName]
	local newLineValue = sortNewLineFormat(lineValue, formatting)
	local newKey = lineName..(separator or "")..(newLineValue or "")
	table.insert(allLines, newKey) -- most recent changes will appear last in the file
	local file = LS_FileMng.write(fileName, false) -- append is false (overwrite)
	if not file then return; end -- failed to write file
	for n=1, #allLines do
		file:write(allLines[n].."\n")
	end
	file:close()
end

LS_FileMng.getOrCreateLineValue = function(fileName, lineName, lineValue, formatting)
	local name, value = LS_FileMng.getSpecificLine(fileName, lineName, formatting)
	if name then return value; end
	LS_FileMng.newLine(fileName, lineName, lineValue, formatting)
	return sortLineFormat(lineValue, formatting)
end