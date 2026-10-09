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

--Disco Floor Lights
-- _1 RED
-- _2 BLUE
-- _3 YELLOW
-- _4 GREEN
-- _5 CYAN
-- _6 WHITE
-- _7 BLACK
-- _8 PINK
-- _9 MAGENTA
-- _10 ORANGE
-- _11 PURPLE
-- _12 DARK GREEN
-- _13 DARK BLUE
-- _14 DARK RED
-- _15 GOLD
-- _16 LIME
-- _17 TEAL
-- _18 LAVENDER
-- _19 MAROON
-- _20 TURQUOISE
-- _21 SILVER
-- _22 CORAL
-- _23 INDIGO
-- _24 VIOLET
-- _25 BEIGE
-- _26 OLIVE
-- _27 SALMON
-- _28 SKY BLUE
-- _29 MUSTARD
-- _30 PEACH
-- _31 GRAY
-- _32 DARK GRAY
-- _33 NAVY

DFProps = DFProps or {}
DFPropsColor = {}

DFPropsColor.Red = {"_1",0.8,0,0}
DFPropsColor.Green = {"_4",0,0.8,0}
DFPropsColor.Blue = {"_2",0,0,0.8}
DFPropsColor.Black = {"_7",0,0.1,0.2}
DFPropsColor.White = {"_6",1,1,0.9}
DFPropsColor.Yellow = {"_3",1,0.9,0.2}
DFPropsColor.Orange = {"_10",1,0.6,0.1}
DFPropsColor.Pink = {"_8",1,0.6,1}
DFPropsColor.Magenta = {"_9",1,0,1}
DFPropsColor.Cyan = {"_5",0.6,1,1}
DFPropsColor.Purple = {"_11",0.7,0.2,1}
DFPropsColor.DarkGreen = {"_12",0,0.4,0}
DFPropsColor.DarkBlue = {"_13",0,0.2,0.5}
DFPropsColor.DarkRed = {"_14",0.4,0,0}
DFPropsColor.Gold = {"_15",0.9,0.7,0}
DFPropsColor.Lime = {"_16", 0.75, 1, 0}
DFPropsColor.Teal = {"_17", 0, 0.5, 0.5}
DFPropsColor.Lavender = {"_18", 0.9, 0.7, 1}
DFPropsColor.Maroon = {"_19", 0.5, 0, 0}
DFPropsColor.Turquoise = {"_20", 0.25, 0.88, 0.82}
DFPropsColor.Silver = {"_21", 0.75, 0.75, 0.75}
DFPropsColor.Coral = {"_22", 1, 0.5, 0.31}
DFPropsColor.Indigo = {"_23", 0.29, 0, 0.51}
DFPropsColor.Violet = {"_24", 0.93, 0.51, 0.93}
DFPropsColor.Beige = {"_25", 0.96, 0.96, 0.86}
DFPropsColor.Olive = {"_26", 0.5, 0.5, 0}
DFPropsColor.Salmon = {"_27", 1, 0.55, 0.41}
DFPropsColor.SkyBlue = {"_28", 0.53, 0.81, 0.92}
DFPropsColor.Mustard = {"_29", 1, 0.86, 0.35}
DFPropsColor.Peach = {"_30", 1, 0.85, 0.73}
DFPropsColor.Gray = {"_31", 0.5, 0.5, 0.5}
DFPropsColor.DarkGray = {"_32", 0.25, 0.25, 0.25}
DFPropsColor.Navy = {"_33", 0, 0, 0.5}

--val: coords - is a table containing the x and y coordinates from the matrix/main floor
--val: x and y - are the coordinates of the target floor (the floor which is receving changes)
--val: stage - is the current moment in the sequence, patterns have 4 stages (from 0 to 3)
--val: sC - (short for stage color) is the ending number of the colored sprite
--val: r, g, b - colors of the lights (from 0 to 1)

DFProps.bitwiseXOR = function(a, b)
	local result = 0
	local bitval = 1
	while a > 0 or b > 0 do
		local abit = a % 2
		local bbit = b % 2
		if abit ~= bbit then
			result = result + bitval
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		bitval = bitval * 2
	end
	return result
end

DFProps.defaultStages = function(sc, stage, style)
	local stages = {
		None_1 = {S0=DFPropsColor.Red, S1=DFPropsColor.Blue, S2=DFPropsColor.Red, S3=DFPropsColor.Blue},
		None_2 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Red, S2=DFPropsColor.Blue, S3=DFPropsColor.Red},
		None_6 = {S0=DFPropsColor.White, S1=DFPropsColor.Black, S2=DFPropsColor.White, S3=DFPropsColor.Black},
		Disco_1 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Orange, S3=DFPropsColor.Pink},
		Disco_2 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Coral, S2=DFPropsColor.Red, S3=DFPropsColor.Gold},
		Disco_6 = {S0=DFPropsColor.White, S1=DFPropsColor.Magenta, S2=DFPropsColor.Pink, S3=DFPropsColor.Yellow},
		Jazz_1 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_2 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Jazz_6 = {S0=DFPropsColor.Black, S1=DFPropsColor.Silver, S2=DFPropsColor.White, S3=DFPropsColor.Gold},
		Elec1_1 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_2 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec1_6 = {S0=DFPropsColor.White, S1=DFPropsColor.Blue, S2=DFPropsColor.Cyan, S3=DFPropsColor.Black},
		Elec2_1 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_2 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec2_6 = {S0=DFPropsColor.White, S1=DFPropsColor.Magenta, S2=DFPropsColor.Pink, S3=DFPropsColor.Coral},
		Elec3_1 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_2 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec3_6 = {S0=DFPropsColor.White, S1=DFPropsColor.Indigo, S2=DFPropsColor.Violet, S3=DFPropsColor.SkyBlue}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.default = function(coords, x, y, stage, style)
	local sC, r, g, b = "_2", 1, 1, 1
	if x % coords[1] == 0 and y % coords[2] == 0 then
		sC = "_6"
	elseif x % coords[1] == 0 or y % coords[2] == 0 then
		sC = "_1"
	end
	sC, r, g, b = DFProps.defaultStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.checkersStages = function(sc, stage, style)
	local stages = {
		None_1 = {S0=DFPropsColor.Red, S1=DFPropsColor.Black, S2=DFPropsColor.Red, S3=DFPropsColor.Black},
		None_7 = {S0=DFPropsColor.Black, S1=DFPropsColor.Yellow, S2=DFPropsColor.Black, S3=DFPropsColor.Yellow},
		Disco_1 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Orange},
		Disco_7 = {S0=DFPropsColor.Pink, S1=DFPropsColor.White, S2=DFPropsColor.Coral, S3=DFPropsColor.Gold},
		Jazz_1 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_7 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_1 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_7 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec2_1 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_7 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec3_1 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_7 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.checkers = function(coords, x, y, stage, style)
	local sC, r, g, b = "_7", 1, 1, 1
	if (x + y) % 2 == 0 then
		sC = "_1"
	end
	sC, r, g, b = DFProps.checkersStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.lineStages = function(sc, stage, style)
	local stages = {
		None_4 = {S0=DFPropsColor.Green, S1=DFPropsColor.Cyan, S2=DFPropsColor.Green, S3=DFPropsColor.Cyan},
		None_5 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Green, S2=DFPropsColor.Cyan, S3=DFPropsColor.Green},
		Disco_4 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Orange, S3=DFPropsColor.White},
		Disco_5 = {S0=DFPropsColor.Red, S1=DFPropsColor.Coral, S2=DFPropsColor.Pink, S3=DFPropsColor.Gold},
		Jazz_4 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_5 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_4 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_5 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec2_4 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_5 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec3_4 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_5 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.line = function(coords, x, y, stage, style)
	local sC, r, g, b = "_5", 1, 1, 1
	if x % coords[1] == 0 then
		sC = "_4"
	end
	sC, r, g, b = DFProps.lineStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.waveStages = function(sc, stage, style)
	local stages = {
		None_20 = {S0=DFPropsColor.Turquoise, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Lavender, S3=DFPropsColor.Silver},
		None_28 = {S0=DFPropsColor.SkyBlue, S1=DFPropsColor.Silver, S2=DFPropsColor.Lavender, S3=DFPropsColor.Indigo},
		Disco_20 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Pink, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_28 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Gold},
		Jazz_20 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_28 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_20 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_28 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec2_20 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_28 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec3_20 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_28 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.wave = function(coords, x, y, stage, style)
	local sC, r, g, b = "_20", 1, 1, 1
	local wave = math.sin((x - coords[1]) / 5) * math.cos((y - coords[2]) / 5)
	if wave > 0 then
		sC = "_20"
	else
		sC = "_28"
	end
	sC, r, g, b = DFProps.waveStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.spiralStages = function(sc, stage, style)
	local stages = {
		None_23 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Violet, S2=DFPropsColor.Mustard, S3=DFPropsColor.Navy},
		None_24 = {S0=DFPropsColor.Peach, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Beige},
		Disco_23 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Pink, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_24 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Gold},
		Jazz_23 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_24 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_23 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_24 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec2_23 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_24 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec3_23 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_24 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.spiral = function(coords, x, y, stage, style)
	local sC, r, g, b = "_23", 1, 1, 1
	local angle = (math.atan2(y - coords[2], x - coords[1]) * (180 / math.pi) + stage * 15) % 360
	if math.floor(angle / 45) % 2 == 0 then
		sC = "_23"
	else
		sC = "_24"
	end
	sC, r, g, b = DFProps.spiralStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.hexStages = function(sc, stage, style)
	local stages = {
		None_15 = {S0=DFPropsColor.Gold, S1=DFPropsColor.Orange, S2=DFPropsColor.Beige, S3=DFPropsColor.Olive},
		None_10 = {S0=DFPropsColor.Gray, S1=DFPropsColor.DarkGray, S2=DFPropsColor.Black, S3=DFPropsColor.Silver},
		Disco_15 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Pink, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_10 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Red, S2=DFPropsColor.Coral, S3=DFPropsColor.Gold},
		Jazz_15 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_10 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_15 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_10 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec2_15 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_10 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec3_15 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_10 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.hexagonal = function(coords, x, y, stage, style)
	local sC, r, g, b = "_15", 1, 1, 1
	local modValue = math.max(1, math.floor(coords[1] / 3))
	if ((x - coords[1]) + (y - coords[2])) % modValue == 0 then
		sC = "_15"
	else
		sC = "_10"
	end
	sC, r, g, b = DFProps.hexStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.fractalStages = function(sc, stage, style)
	local stages = {
		None_18 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Maroon, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Coral},
		None_19 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Navy, S3=DFPropsColor.White},
		Disco_18 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Pink, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_19 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Red, S2=DFPropsColor.Coral, S3=DFPropsColor.Gold},
		Jazz_18 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_19 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_18 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_19 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec2_18 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_19 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Coral, S2=DFPropsColor.Purple, S3=DFPropsColor.Violet},
		Elec3_18 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_19 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.fractal = function(coords, x, y, stage, style)
	local sC, r, g, b = "_18", 1, 1, 1
	local value = DFProps.bitwiseXOR(x, y) % 4
	if value < 2 then
		sC = "_18"
	else
		sC = "_19"
	end
	sC, r, g, b = DFProps.fractalStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.pulseStages = function(sc, stage, style)
	local stages = {
		None_6 = {S0=DFPropsColor.White, S1=DFPropsColor.Cyan, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.DarkBlue},
		Disco_6 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Orange, S2=DFPropsColor.Magenta, S3=DFPropsColor.White},
		Jazz_6 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Elec1_6 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec2_6 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec3_6 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.pulse = function(coords, x, y, stage, style)
	local sC, r, g, b = "_6", 1, 1, 1
	local intensity = math.sin((x + y + stage) * 0.5) * 0.5 + 0.5
	sC, r, g, b = DFProps.pulseStages(sC, "S"..tostring(stage), style)
	r, g, b = r * intensity, g * intensity, b * intensity
	if r > 1 then r = 1; end; if g > 1 then g = 1; end; if b > 1 then b = 1; end; 
	return sC, r, g, b
end

DFProps.rippleStages = function(sc, stage, style)
	local stages = {
		None_28 = {S0=DFPropsColor.SkyBlue, S1=DFPropsColor.Silver, S2=DFPropsColor.Lavender, S3=DFPropsColor.Indigo},
		None_21 = {S0=DFPropsColor.Gray, S1=DFPropsColor.Black, S2=DFPropsColor.Silver, S3=DFPropsColor.White},
		Disco_28 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Pink, S2=DFPropsColor.Magenta, S3=DFPropsColor.White},
		Disco_21 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Jazz_28 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_21 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Purple, S2=DFPropsColor.Lavender, S3=DFPropsColor.Silver},
		Elec1_28 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_21 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Gray, S3=DFPropsColor.Black},
		Elec2_28 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_21 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Violet, S2=DFPropsColor.Lavender, S3=DFPropsColor.White},
		Elec3_28 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_21 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Indigo, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.ripple = function(coords, x, y, stage, style)
	local sC, r, g, b = "_28", 1, 1, 1
	local distance = math.sqrt(x^2 + y^2)
	if math.floor(distance) % 4 == stage then
		sC = "_28"
	else
		sC = "_21"
	end
	sC, r, g, b = DFProps.rippleStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.triangleStages = function(sc, stage, style)
	local stages = {
		None_15 = {S0=DFPropsColor.Gold, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Mustard},
		None_10 = {S0=DFPropsColor.Gray, S1=DFPropsColor.DarkGray, S2=DFPropsColor.Black, S3=DFPropsColor.Silver},
		Disco_15 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Pink, S2=DFPropsColor.Magenta, S3=DFPropsColor.White},
		Disco_10 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Jazz_15 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_10 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Purple, S2=DFPropsColor.Lavender, S3=DFPropsColor.Silver},
		Elec1_15 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec1_10 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Gray, S3=DFPropsColor.Black},
		Elec2_15 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Red, S3=DFPropsColor.Pink},
		Elec2_10 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Violet, S2=DFPropsColor.Lavender, S3=DFPropsColor.White},
		Elec3_15 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_10 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Indigo, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.triangle = function(coords, x, y, stage, style)
	local sC, r, g, b = "_15", 1, 1, 1
	if (DFProps.bitwiseXOR(x % coords[1], y % coords[2]) % 3) == stage then
		sC = "_15"
	else
		sC = "_10"
	end
	sC, r, g, b = DFProps.triangleStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.prismStages = function(sc, stage, style)
	local stages = {
		None_24 = {S0=DFPropsColor.Violet, S1=DFPropsColor.Magenta, S2=DFPropsColor.Pink, S3=DFPropsColor.Peach},
		None_9  = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Red, S2=DFPropsColor.Orange, S3=DFPropsColor.Yellow},
		None_30 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Blue, S2=DFPropsColor.Indigo, S3=DFPropsColor.White},
		Disco_24 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Cyan, S3=DFPropsColor.White},
		Disco_9  = {S0=DFPropsColor.Pink, S1=DFPropsColor.Green, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Disco_30 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Peach},
		Jazz_24 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_9  = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Jazz_30 = {S0=DFPropsColor.Coral, S1=DFPropsColor.Salmon, S2=DFPropsColor.Mustard, S3=DFPropsColor.Beige},
		Elec1_24 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_9  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec1_30 = {S0=DFPropsColor.Turquoise, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec2_24 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_9  = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Elec2_30 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Violet, S2=DFPropsColor.Indigo, S3=DFPropsColor.Cyan},
		Elec3_24 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_9  = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec3_30 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.Blue, S3=DFPropsColor.White}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.prism = function(coords, x, y, stage, style)
	local sC, r, g, b = "_24", 1, 1, 1
	local angle = (math.atan2(y - coords[2], x - coords[1]) * (180 / math.pi) + stage * 20) % 360
	
	if angle < 120 then
		sC = "_24"
	elseif angle < 240 then
		sC = "_9"
	else
		sC = "_30"
	end
	sC, r, g, b = DFProps.prismStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.hexagonStages = function(sc, stage, style)
	local stages = {
		None_17 = {S0=DFPropsColor.Turquoise, S1=DFPropsColor.Cyan, S2=DFPropsColor.DarkBlue, S3=DFPropsColor.Silver},
		None_5 = {S0=DFPropsColor.Gray, S1=DFPropsColor.DarkGray, S2=DFPropsColor.Black, S3=DFPropsColor.Silver},
		Disco_17 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_5 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Blue, S2=DFPropsColor.Lime, S3=DFPropsColor.White},
		Jazz_17 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_5 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_17 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_5 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec2_17 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_5 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Elec3_17 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_5 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.hexagon = function(coords, x, y, stage, style)
	local sC, r, g, b = "_17", 1, 1, 1
	if math.abs((x + y) % 6) == stage then
		sC = "_17"
	else
		sC = "_5"
	end
	sC, r, g, b = DFProps.hexagonStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.wavyCheckersStages = function(sc, stage, style)
	local stages = {
		None_3 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Black, S2=DFPropsColor.Mustard, S3=DFPropsColor.Gold},
		None_7 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Violet, S2=DFPropsColor.Pink, S3=DFPropsColor.Magenta},
		Disco_3 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Pink, S3=DFPropsColor.White},
		Disco_7 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Blue, S2=DFPropsColor.Lime, S3=DFPropsColor.White},
		Jazz_3 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_7 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_3 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_7 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec2_3 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_7 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Elec3_3 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_7 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.wavyCheckers = function(coords, x, y, stage, style)
	local sC, r, g, b = "_3", 1, 1, 1
	local waveEffect = math.sin((x + y) * 0.8 + stage * math.pi / 2) * 2
	if math.floor(waveEffect) % 2 == 0 then
		sC = "_3"
	else
		sC = "_7"
	end
	sC, r, g, b = DFProps.wavyCheckersStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.quadrantSpiralStages = function(sc, stage, style)
	local stages = {
		None_1  = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.DarkRed},
		None_10 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Navy, S2=DFPropsColor.Cyan, S3=DFPropsColor.White},
		None_22 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Gold, S2=DFPropsColor.Mustard, S3=DFPropsColor.Beige},
		None_14 = {S0=DFPropsColor.Gray, S1=DFPropsColor.Silver, S2=DFPropsColor.Black, S3=DFPropsColor.White},
		Disco_1  = {S0=DFPropsColor.Pink, S1=DFPropsColor.Magenta, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_10 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Lime, S3=DFPropsColor.White},
		Disco_22 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Yellow, S2=DFPropsColor.Peach, S3=DFPropsColor.White},
		Disco_14 = {S0=DFPropsColor.Red, S1=DFPropsColor.Magenta, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Jazz_1  = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_10 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Jazz_22 = {S0=DFPropsColor.Salmon, S1=DFPropsColor.Orange, S2=DFPropsColor.Peach, S3=DFPropsColor.Gold},
		Jazz_14 = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Red, S2=DFPropsColor.Coral, S3=DFPropsColor.Orange},
		Elec1_1  = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_10 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec1_22 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Lavender, S3=DFPropsColor.White},
		Elec1_14 = {S0=DFPropsColor.Gray, S1=DFPropsColor.Silver, S2=DFPropsColor.Black, S3=DFPropsColor.White},
		Elec2_1  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_10 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Purple},
		Elec2_22 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Elec2_14 = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Red, S2=DFPropsColor.Magenta, S3=DFPropsColor.White},
		Elec3_1  = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_10 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec3_22 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Violet, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		Elec3_14 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.Black, S3=DFPropsColor.Gray}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.quadrantSpiral = function(coords, x, y, stage, style)
	local sC, r, g, b = "_1", 1, 1, 1
	local angle = (math.atan2(y - coords[2], x - coords[1]) * (180 / math.pi) + stage * 15) % 360
	local radius = math.sqrt((x - coords[1])^2 + (y - coords[2])^2)

	if (math.floor(radius) + math.floor(angle / 90)) % 2 == 0 then
		sC = "_1"
	else
		sC = "_10"
	end
	sC, r, g, b = DFProps.quadrantSpiralStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.layeredPrismsStages = function(sc, stage, style)
	local stages = {
		None_24 = {S0=DFPropsColor.Violet, S1=DFPropsColor.Magenta, S2=DFPropsColor.Lavender, S3=DFPropsColor.Peach},
		None_9  = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Red, S2=DFPropsColor.Orange, S3=DFPropsColor.Yellow},
		Disco_24 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Magenta, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_9  = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Yellow},
		Jazz_24 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_9  = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Salmon, S2=DFPropsColor.Orange, S3=DFPropsColor.Gold},
		Elec1_24 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_9  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec2_24 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_9  = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Elec3_24 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_9  = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.layeredPrisms = function(coords, x, y, stage, style)
	local sC, r, g, b = "_24", 1, 1, 1
	if math.abs((x % 4) - (y % 4)) == stage then
		sC = "_24"
	else
		sC = "_9"
	end
	sC, r, g, b = DFProps.layeredPrismsStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.radialWavesStages = function(sc, stage, style)
	local stages = {
		None_20 = {S0=DFPropsColor.Turquoise, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Cyan, S3=DFPropsColor.White},
		None_5  = {S0=DFPropsColor.Gray, S1=DFPropsColor.Black, S2=DFPropsColor.Silver, S3=DFPropsColor.White},
		None_28 = {S0=DFPropsColor.SkyBlue, S1=DFPropsColor.Silver, S2=DFPropsColor.Lavender, S3=DFPropsColor.Indigo},
		Disco_20 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Yellow, S2=DFPropsColor.Orange, S3=DFPropsColor.White},
		Disco_5  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Disco_28 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Jazz_20 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_5  = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Jazz_28 = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Salmon, S2=DFPropsColor.Orange, S3=DFPropsColor.Gold},
		Elec1_20 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_5  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec1_28 = {S0=DFPropsColor.Navy, S1=DFPropsColor.Blue, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec2_20 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_5  = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Coral, S3=DFPropsColor.Pink},
		Elec2_28 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Cyan, S3=DFPropsColor.Blue},
		Elec3_20 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_5  = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec3_28 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Purple, S2=DFPropsColor.Turquoise, S3=DFPropsColor.Navy}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.radialWaves = function(coords, x, y, stage, style)
	local sC, r, g, b = "_20", 1, 1, 1
	if (math.sqrt(x^2 + y^2) + stage * 2) % 6 < 3 then
		sC = "_5"
	else
		sC = "_28"
	end
	sC, r, g, b = DFProps.radialWavesStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.digitalLightningStages = function(sc, stage, style)
	local stages = {
		None_23 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Blue, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		None_2  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Cyan, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.White},
		None_21 = {S0=DFPropsColor.Gray, S1=DFPropsColor.Black, S2=DFPropsColor.Silver, S3=DFPropsColor.White},
		Disco_23 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Disco_2  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Disco_21 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Jazz_23 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_2  = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Jazz_21 = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Maroon, S2=DFPropsColor.Orange, S3=DFPropsColor.Gold},
		Elec1_23 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_2  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec1_21 = {S0=DFPropsColor.Navy, S1=DFPropsColor.Blue, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec2_23 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_2  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Blue, S2=DFPropsColor.Cyan, S3=DFPropsColor.Purple},
		Elec2_21 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Yellow, S3=DFPropsColor.Pink},
		Elec3_23 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_2  = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec3_21 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Purple, S2=DFPropsColor.Cyan, S3=DFPropsColor.Navy}
	}
	--print("digitalLightningStages: ".."sc is: "..sc.." / stage is: "..stage.." / style is: "..style)
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.digitalLightning = function(coords, x, y, stage, style)
	local sC, r, g, b = "_23", 1, 1, 1
	if ZombRand(1, 7) == 1 then
		sC = "_2"
	else
		sC = "_21"
	end
	sC, r, g, b = DFProps.digitalLightningStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.hypnoticSpiralStages = function(sc, stage, style)
	local stages = {
		None_9  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Pink, S2=DFPropsColor.Violet, S3=DFPropsColor.Peach},
		None_8  = {S0=DFPropsColor.Coral, S1=DFPropsColor.Orange, S2=DFPropsColor.Red, S3=DFPropsColor.DarkRed},
		None_24 = {S0=DFPropsColor.Lavender, S1=DFPropsColor.Purple, S2=DFPropsColor.Blue, S3=DFPropsColor.Indigo},
		None_30 = {S0=DFPropsColor.White, S1=DFPropsColor.Silver, S2=DFPropsColor.Black, S3=DFPropsColor.Gray},
		Disco_9  = {S0=DFPropsColor.Pink, S1=DFPropsColor.Green, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_8  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Black, S3=DFPropsColor.White},
		Disco_24 = {S0=DFPropsColor.Red, S1=DFPropsColor.Blue, S2=DFPropsColor.Purple, S3=DFPropsColor.Orange},
		Disco_30 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Cyan, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Jazz_9  = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_8  = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Jazz_24 = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Orange, S2=DFPropsColor.Beige, S3=DFPropsColor.Gold},
		Jazz_30 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Coral, S2=DFPropsColor.Navy, S3=DFPropsColor.White},
		Elec1_9  = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_8  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec1_24 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Navy, S2=DFPropsColor.DarkBlue, S3=DFPropsColor.Black},
		Elec1_30 = {S0=DFPropsColor.Navy, S1=DFPropsColor.Blue, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec2_9  = {S0=DFPropsColor.Pink, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_8  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Blue, S2=DFPropsColor.Cyan, S3=DFPropsColor.Purple},
		Elec2_24 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Yellow, S3=DFPropsColor.Pink},
		Elec2_30 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Green, S3=DFPropsColor.Purple},
		Elec3_9  = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_8  = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec3_24 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Purple, S2=DFPropsColor.Cyan, S3=DFPropsColor.Navy},
		Elec3_30 = {S0=DFPropsColor.Blue, S1=DFPropsColor.White, S2=DFPropsColor.Silver, S3=DFPropsColor.Cyan}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.hypnoticSpiral = function(coords, x, y, stage, style)
	local sC, r, g, b = "_9", 1, 1, 1
	local angle = (math.atan2(y - coords[2], x - coords[1]) * (180 / math.pi) + stage * 30) % 360
	local distance = math.sqrt((x - coords[1])^2 + (y - coords[2])^2)
	
	if math.floor(distance + angle / 90) % 2 == 0 then
		sC = "_9"
	else
		sC = "_8"
	end
	sC, r, g, b = DFProps.hypnoticSpiralStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.glitchPixelsStages = function(sc, stage, style)
	local stages = {
		None_1  = {S0=DFPropsColor.Red, S1=DFPropsColor.Cyan, S2=DFPropsColor.Black, S3=DFPropsColor.White},
		None_5  = {S0=DFPropsColor.DarkGray, S1=DFPropsColor.Gray, S2=DFPropsColor.Silver, S3=DFPropsColor.White},
		Disco_1  = {S0=DFPropsColor.Pink, S1=DFPropsColor.Green, S2=DFPropsColor.Yellow, S3=DFPropsColor.White},
		Disco_5  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Black, S3=DFPropsColor.White},
		Jazz_1  = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Purple, S3=DFPropsColor.Beige},
		Jazz_5  = {S0=DFPropsColor.Indigo, S1=DFPropsColor.Lavender, S2=DFPropsColor.Silver, S3=DFPropsColor.Gray},
		Elec1_1  = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_5  = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Silver},
		Elec2_1  = {S0=DFPropsColor.Pink, S1=DFPropsColor.Yellow, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_5  = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Blue, S2=DFPropsColor.Cyan, S3=DFPropsColor.Purple},
		Elec3_1  = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.White},
		Elec3_5  = {S0=DFPropsColor.Cyan, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.glitchPixels = function(coords, x, y, stage, style)
	local sC, r, g, b, limit = "_1", 1, 1, 1, 3+stage
	if ZombRand(1, limit) == 1 then
		sC = "_1"
	else
		sC = "_5"
	end
	sC, r, g, b = DFProps.glitchPixelsStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.dynamicFlamesStages = function(sc, stage, style)
	local stages = {
		None_14 = {S0=DFPropsColor.DarkRed, S1=DFPropsColor.Orange, S2=DFPropsColor.Gold, S3=DFPropsColor.Yellow},
		None_10 = {S0=DFPropsColor.Gray, S1=DFPropsColor.DarkGray, S2=DFPropsColor.Black, S3=DFPropsColor.Silver},
		Disco_14 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Lime, S3=DFPropsColor.Yellow},
		Disco_10 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Blue, S2=DFPropsColor.Red, S3=DFPropsColor.Green},
		Jazz_14 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Gold, S2=DFPropsColor.Beige, S3=DFPropsColor.Orange},
		Jazz_10 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Lavender, S2=DFPropsColor.Indigo, S3=DFPropsColor.Silver},
		Elec1_14 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Indigo, S3=DFPropsColor.Purple},
		Elec1_10 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.White, S3=DFPropsColor.Gray},
		Elec2_14 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Yellow, S2=DFPropsColor.Cyan, S3=DFPropsColor.White},
		Elec2_10 = {S0=DFPropsColor.Green, S1=DFPropsColor.Blue, S2=DFPropsColor.Purple, S3=DFPropsColor.Magenta},
		Elec3_14 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Blue, S2=DFPropsColor.Cyan, S3=DFPropsColor.White},
		Elec3_10 = {S0=DFPropsColor.Indigo, S1=DFPropsColor.DarkBlue, S2=DFPropsColor.Silver, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.dynamicFlames = function(coords, x, y, stage, style)
	local sC, r, g, b = "_14", 1, 1, 1
	local intensity = (math.abs(y - coords[2]) + stage) % 4
	if intensity < 2 then
		sC = "_14"
	else
		sC = "_10"
	end
	sC, r, g, b = DFProps.dynamicFlamesStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.linesStages = function(sc, stage, style)
	local stages = {
		None_4 = {S0=DFPropsColor.SkyBlue, S1=DFPropsColor.Mustard, S2=DFPropsColor.SkyBlue, S3=DFPropsColor.Mustard},
		None_5 = {S0=DFPropsColor.Mustard, S1=DFPropsColor.SkyBlue, S2=DFPropsColor.Mustard, S3=DFPropsColor.SkyBlue},
		Disco_4 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Lime, S3=DFPropsColor.Yellow},
		Disco_5 = {S0=DFPropsColor.Orange, S1=DFPropsColor.Blue, S2=DFPropsColor.Red, S3=DFPropsColor.Green},
		Jazz_4 = {S0=DFPropsColor.Gold, S1=DFPropsColor.Purple, S2=DFPropsColor.Indigo, S3=DFPropsColor.Beige},
		Jazz_5 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Lavender, S2=DFPropsColor.Navy, S3=DFPropsColor.Silver},
		Elec1_4 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Blue, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_5 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec2_4 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Blue, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_5 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.Magenta},
		Elec3_4 = {S0=DFPropsColor.SkyBlue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec3_5 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.lines = function(coords, x, y, stage, style)
	local sC, r, g, b = "_5", 1, 1, 1
	if (x % 3) == (stage % 3) then
		sC = "_4"
	end
	sC, r, g, b = DFProps.linesStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

DFProps.rectanglesStages = function(sc, stage, style)
	local stages = {
		None_1 = {S0=DFPropsColor.Red, S1=DFPropsColor.Orange, S2=DFPropsColor.Yellow, S3=DFPropsColor.Gold},
		None_2 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Cyan, S2=DFPropsColor.Indigo, S3=DFPropsColor.Purple},
		Disco_1 = {S0=DFPropsColor.Magenta, S1=DFPropsColor.Cyan, S2=DFPropsColor.Lime, S3=DFPropsColor.Yellow},
		Disco_2 = {S0=DFPropsColor.Blue, S1=DFPropsColor.Orange, S2=DFPropsColor.Red, S3=DFPropsColor.Green},
		Jazz_1 = {S0=DFPropsColor.Gold, S1=DFPropsColor.Purple, S2=DFPropsColor.Indigo, S3=DFPropsColor.Beige},
		Jazz_2 = {S0=DFPropsColor.Maroon, S1=DFPropsColor.Lavender, S2=DFPropsColor.Navy, S3=DFPropsColor.Silver},
		Elec1_1 = {S0=DFPropsColor.Cyan, S1=DFPropsColor.Blue, S2=DFPropsColor.Purple, S3=DFPropsColor.White},
		Elec1_2 = {S0=DFPropsColor.DarkBlue, S1=DFPropsColor.Indigo, S2=DFPropsColor.Silver, S3=DFPropsColor.Black},
		Elec2_1 = {S0=DFPropsColor.Pink, S1=DFPropsColor.Blue, S2=DFPropsColor.Green, S3=DFPropsColor.White},
		Elec2_2 = {S0=DFPropsColor.Yellow, S1=DFPropsColor.Cyan, S2=DFPropsColor.Purple, S3=DFPropsColor.Magenta},
		Elec3_1 = {S0=DFPropsColor.SkyBlue, S1=DFPropsColor.Cyan, S2=DFPropsColor.White, S3=DFPropsColor.Silver},
		Elec3_2 = {S0=DFPropsColor.Purple, S1=DFPropsColor.Indigo, S2=DFPropsColor.Blue, S3=DFPropsColor.Black}
	}
	return stages[style..sc][stage][1], stages[style..sc][stage][2], stages[style..sc][stage][3], stages[style..sc][stage][4]
end

DFProps.rectangles = function(coords, x, y, stage, style)
	local sC, r, g, b = "_1", 1, 1, 1
	local dx, dy = math.abs(x - coords[1]), math.abs(y - coords[2])
	local layer = math.max(dx, dy)

	if (layer + stage) % 2 == 0 then
		sC = "_1"
	else
		sC = "_2"
	end
	
	sC, r, g, b = DFProps.rectanglesStages(sC, "S"..tostring(stage), style)
	return sC, r, g, b
end

local function getMode(mode)
	local styleList = {"Disco","Jazz","Elec1","Elec2","Elec3"}
	local style
	for i=1,#styleList do
		if luautils.stringEnds(mode, styleList[i]) then style = styleList[i]; break; end
	end
	if not style then return false, false; end
	return mode:sub(1,-#style-1), style
end

local function getStageNumb(stage)
	if stage < 4 then return stage; end
	local t = {S4=0,S5=1,S6=2,S7=3}
	return t["S"..tostring(stage)] or 0
end

DFProps.get = function(mode, coords, x, y, stage)
	--print("DFProps.get EXECUTE")
	local newStage = getStageNumb(stage)
	local tMode, style = mode, "None"
	if not DFProps[tMode] then tMode, style = getMode(mode); end
	if not tMode then return "_1", 1, 1, 1; end
	--print("DFProps.get style IS: "..style)
	local sC, r, g, b = DFProps[tMode](coords, x, y, newStage, style)
	return sC, r, g, b, 1
end