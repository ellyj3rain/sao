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

-- Context Menu S

local LScontextTable = {}

local function getCSTables()
	return {
		{contextname=LSDebugAdmin,isdebug=true,itemA="none",itemB="none",clothing="none",ismp=false,self=false,mod="GNL"},
		{contextname=ToiletGroundContextMenu,isdebug=false,itemA="none",itemB="none",clothing="none",ismp=false,self=false,mod="HGN"},
		{contextname=LSCleanRoomContextMenu,isdebug=false,itemA="none",itemB="none",clothing="none",ismp=false,self=false,mod="HGN"},
		{contextname=LSCleanRoomGFContextMenu,isdebug=false,itemA="none",itemB="none",clothing="none",ismp=false,self=false,mod="HGN"},
		{contextname=LSSKContextMenu,isdebug=false,itemA="none",itemB="none",clothing="none",ismp=true,self=false,mod="GNL"},
		{contextname=LSDanceContextMenu,isdebug=false,itemA="none",itemB="none",clothing="none",ismp=false,self=false,mod="DNC"},
		{contextname=ZenWellnessContextMenu,isdebug=false,itemA="none",itemB="none",clothing="none",ismp=false,self=true,mod="MDT"},
	}
end

local function getCGTables()
	return {
		{customname="Shower",groupname="none",contextname=ShowerContextMenu,multiple="single",mod="HGN"},
		{customname="Bath",groupname="Large Deluxe",contextname=BathContextMenu,multiple="single",mod="HGN"},
		{customname="Toilet",groupname="none",contextname=ToiletContextMenu,multiple="single",mod="HGN"},
		{customname="Cabinet",groupname="Medicine",contextname=CabinetContextMenu,multiple="Sink",mod="GNL"},
		{customname="Mirror",groupname="none",contextname=MirrorContextMenu,multiple="Sink",mod="GNL"},
		{customname="Piano",groupname="none",contextname=InstrumentPianoContextMenu,multiple="single",mod="MSC"},
		{customname="Grand Piano",groupname="none",contextname=InstrumentPianoContextMenu,multiple="single",mod="MSC"},
		{customname="Microphone",groupname="Standing",contextname=VocalContextMenu,multiple="single",mod="MSC"},
		{customname="Painting",groupname="Easel",contextname=EaselContextMenu,multiple="single",mod="ART"},
		{customname="Painting",groupname="EaselCanvasSmall",contextname=EaselCanvasContextMenu,multiple="single",mod="ART"},
		{customname="Painting",groupname="EaselCanvas",contextname=EaselCanvasContextMenu,multiple="single",mod="ART"},
		{customname="Painting",groupname="EaselCanvasLarge",contextname=EaselCanvasContextMenu,multiple="single",mod="ART"},
		{customname="Painting",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="none",groupname="Fortune Teller",contextname=LSFTContextMenu,multiple="single",mod="GNL"},
		{customname="none",groupname="GF Clock",contextname=GFClockContextMenu,multiple="single",mod="GNL"},
		{customname="Sculpture Seating",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpture Hedge",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpture Wooden",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpture Ice",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpture Metal",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpture Stone",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpture Lamp",groupname="none",contextname=ArtCardContextMenu,multiple="single",mod="ART"},
		{customname="Sculpting",groupname="Station",contextname=SculptingContextMenu,multiple="single",mod="ART"},
		{customname="Sculpting",groupname="StationWork",contextname=SculptingWorkContextMenu,multiple="single",mod="ART"},
		{customname="Disco Ball",groupname="none",contextname=DiscoBallMenu,multiple="single",mod="GNL"},
		{customname="Disco Floor",groupname="none",contextname=DanceFloorMenu,multiple="single",mod="GNL"},
		{customname="Jukebox",groupname="none",contextname=JukeboxMenu,multiple="single",mod="GNL"},
		{customname="none",groupname="Inventions",contextname=InventionsMenu,multiple="single",mod="ART"},
		{customname="Invention",groupname="Station",contextname=InventionsMenu.workbench,multiple="single",mod="ART"},
		{customname="Invention",groupname="StationWork",contextname=InventionsMenu.workbench,multiple="single",mod="ART"},
		{customname="Wardrobe",groupname="none",contextname=LSWardrobeContextMenu,multiple="single",mod="GNL"},
		{customname="Drawers",groupname="none",contextname=LSWardrobeContextMenu,multiple="single",mod="GNL"},
		{customname="Rack",groupname="none",contextname=LSWardrobeContextMenu,multiple="single",mod="GNL"},
		{customname="Clothes Stand",groupname="none",contextname=LSWardrobeContextMenu,multiple="single",mod="GNL"},
		{customname="Locker",groupname="Yellow Wall",contextname=LSWardrobeContextMenu,multiple="single",mod="GNL"},
		{customname="Locker",groupname="Blue Wall",contextname=LSWardrobeContextMenu,multiple="single",mod="GNL"},
		{customname="Table",groupname="Ping Pong",contextname=LSPingPongCM,multiple="single",mod="GNL"},
	}
end

local function getCITables()
	return {
		{name="Banjo",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="GuitarAcoustic",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="GuitarElectric",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Flute",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Trumpet",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Keytar",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Saxophone",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Violin",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Lifestyle.Harmonica",contextname=NewInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Base.Harmonica",contextname=VanillaInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Lifestyle.SheetMusicBook",contextname=MusicSheetBookContextMenu,cat="PF",mod="MSC"},
		{name="Perfume",contextname=PerfumeContextMenu,cat="PF",mod="HGN"},
		{name="Cologne",contextname=PerfumeContextMenu,cat="PF",mod="HGN"},
		{name="HMW.H_Bass",contextname=NewInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="HMW.H_Acoustic",contextname=NewInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="HMW.H_Electric",contextname=NewInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="HMW.H_Banjo",contextname=NewInstrumentsContextMenu,cat="all",mod="MSC"},
		{name="Spiffo",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="BorisBadger",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="JacquesBeaver",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="FreddyFox",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="PancakeHedgehog",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="FluffyfootBunny",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="MoleyMole",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="FurbertSquirrel",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="PanchoDog",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="TrashGoblin",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="Plushabug",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="ToyBear_Crafted_Burlap",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="ToyBear_Crafted_Cotton",contextname=PlushiesContextMenu,cat="PF",mod="GNL"},
		{name="Lifestyle.",contextname=InventionsMenu,tag="LSInvention",cat="PF",mod="ART"},
		--{name="Lifestyle.",contextname=PaintItemContextMenu,tag="LSCanPaint",cat="PF",mod="ART"},
	}
end

local function loadModuleContexts(contextTable, context, Modules)
	local TCS
	if context == "contextSelfTable" then TCS = getCSTables(); elseif context == "contextCGTable" then TCS = getCGTables(); elseif context == "contextItemTable" then TCS = getCITables(); end
	for k, v in ipairs(TCS) do
		for _, mod in ipairs(Modules) do
			if v.mod == mod then
				table.insert(contextTable, v)
			end
		end
	end
	return contextTable
end

local function LSgetAvailableModules()
	local modules = {}
	table.insert(modules, "GNL")
	if SandboxVars.Text.DividerHygiene then table.insert(modules, "HGN"); end
	if SandboxVars.Text.DividerMeditationNew then table.insert(modules, "MDT"); end
	if SandboxVars.Text.DividerMusicNew then table.insert(modules, "MSC"); end
	if SandboxVars.Text.DividerDancingNew then table.insert(modules, "DNC"); end
	if SandboxVars.Text.DividerArt then table.insert(modules, "ART"); end
	return modules
end

function LSGetContextOptions(player, context)
	if not LScontextTable[context] then
		LScontextTable[context] = {}
		local modules = LSgetAvailableModules()
		LScontextTable[context] = loadModuleContexts(LScontextTable[context], context, modules)
	end
	return LScontextTable[context]
end

local function LSresetContextSelfTable()
	LScontextTable = {}
end
Events.OnCreatePlayer.Add(LSresetContextSelfTable)

