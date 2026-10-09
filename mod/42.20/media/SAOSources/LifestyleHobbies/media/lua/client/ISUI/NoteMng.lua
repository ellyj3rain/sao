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

LSNoteMng = {}
LSNoteMng.queue = {}
LSNoteMng.updatedPrefs = false

local function playerIsValid(character)
	if character and character:hasModData() and (not character:isDead()) then return true; end
	return false
end

local function noteIsValid(args)
	args[1]:getModData().LSNoteMng = args[1]:getModData().LSNoteMng or {}
	if args[6] and LSNoteMng[args[6]] then return false; end -- player closed this type of note permanently or noSpam is enabled
	return true
end

local function noteInQueue(args)
	if (not args[3]) or (#LSNoteMng.queue == 0) then return false; end -- note type accepts repeats or none in queue
	for n=1, #LSNoteMng.queue do
		if LSNoteMng.queue[n][5][3] and (LSNoteMng.queue[n][5][3] == args[3]) then return true; end
	end
	return false
end

local function doPanel(x, y, w, h, args)
	local newPanel = LSNote:new(x,y,w,h, args)
	newPanel:initialise()
	newPanel:addToUIManager()
	return newPanel
end

LSNoteMng.getExclusions = function(noteName)
	local file = getFileReader("LSNoteExclude.ini",true)
	if not file then return false; end -- failed to write file
	local t, line = {}, false
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local splitedLine = string.split(line, "=")
		local name = splitedLine[1]
		if name ~= noteName then table.insert(t, line); end
	end
	return t
end

LSNoteMng.newExclude = function(noteName)
	local allLines = LSNoteMng.getExclusions(noteName)
	if not allLines then return; end
	local newKey = noteName.."=TRUE"
	table.insert(allLines, newKey)
	local file = getFileWriter("LSNoteExclude.ini",true,false) -- append is false (overwrite)
	if not file then return; end -- failed to write file
	for n=1, #allLines do
		file:write(allLines[n].."\n")
	end
	file:close()
	LSNoteMng[noteName] = true
end

LSNoteMng.setExclusions = function()
	local file = getFileReader("LSNoteExclude.ini",true)
	if not file then return; end -- failed to write file
	local line
	while true do
		line = file:readLine()
		if not line then file:close(); break; end
		local splitedLine = string.split(line, "=")
		local name = splitedLine[1]
		local value = splitedLine[2]
		if value == "TRUE" then
			LSNoteMng[name] = true
		else
			LSNoteMng[name] = false
		end
	end
	LSNoteMng.updatedPrefs = true
end

LSNoteMng.addToQueue = function(x, y, w, h, args) -- args = {Player, Text, Type, Texture, ScreenTime, ClosePermanent}
	if (not args) or (not playerIsValid(args[1])) then return; end
	if not noteIsValid(args) then return; end
	if noteInQueue(args) then return; end
	
	if not LSNoteMng.NotePanel then
		LSNoteMng.NotePanel = doPanel(x, y, w, h, args)
	else
		table.insert(LSNoteMng.queue, {x, y, w, h, args})
	end
end

LSNoteMng.next = function()
	for n=1, #LSNoteMng.queue do
		if LSNoteMng.queue[n] then
			if playerIsValid(LSNoteMng.queue[n][5][1]) then LSNoteMng.NotePanel = doPanel(LSNoteMng.queue[n][1],LSNoteMng.queue[n][2],LSNoteMng.queue[n][3],LSNoteMng.queue[n][4],LSNoteMng.queue[n][5]); end
			table.remove(LSNoteMng.queue, n)
			break
		end
	end
end

LSNoteMng.LSNOTEONE = function()
	if not LSNoteMng.updatedPrefs then LSNoteMng.setExclusions(); end
	if LSNoteMng and LSNoteMng.queue and (#LSNoteMng.queue > 0) and not LSNoteMng.NotePanel then
		LSNoteMng.next()
	end
end

Events.EveryOneMinute.Add(LSNoteMng.LSNOTEONE)
