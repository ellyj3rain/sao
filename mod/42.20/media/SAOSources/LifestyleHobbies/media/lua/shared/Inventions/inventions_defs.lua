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

-- Inventions starting definitions

 -- player mod data only saves known inventions and current improvement levels if any and # of specials researched
 -- resources can be stored in nearby containers. Research UI checks both player inv and nearby containers (loot)

LSInv = LSInv or {}
LSInventionDefs = {}

LSInventionDefs.Improvements = {}
--LSInventionDefs.Moveables = {}
LSInventionDefs.Items = {}
--LSInventionDefs.Weapons = {}
--LSInventionDefs.Clothing = {}
LSInventionDefs.ItemScript = {}
LSInventionDefs.Modifiers = {}

LSInventionDefs.ImprovCost = {} -- how much each improvement adds to costPenalty
LSInventionDefs.ImprovCost.addR=0.02 -- common repeatable per lvl
LSInventionDefs.ImprovCost.addRS=0.1 -- special repeatable per lvl
LSInventionDefs.ImprovCost.add=0.2 -- common single
LSInventionDefs.ImprovCost.addS=0.5 -- special single
LSInventionDefs.ImprovCost.numPenalty = 3 -- each X improvements research adds to costPenalty (value is addR), eg invention with 30 improvements will add 0.2 to its total cost penalty (0.02*30/3)

local params = {}

-- base resource costs, modified by sandbox
params.cost = {}
params.cost.vvlow = 2
params.cost.vlow = 5
params.cost.low = 10
params.cost.midlow = 15
params.cost.mid = 20
params.cost.midhigh = 30
params.cost.high = 40
params.cost.vhigh = 60
params.cost.vvhigh = 90
params.cost.ludicrous = 120
params.cost.vludicrous = 200
params.cost.vvludicrous = 300

params.discBase = {
	"Base.ScrapMetal","Base.ElectronicsScrap","Base.Plank","Base.SheetMetal","Base.SmallSheetMetal","Base.MetalBar","Base.SteelBar","Base.IronBar","Base.SteelBarHalf","Base.IronBarHalf",
	"Base.LongStick","Base.LongHandle","Base.Handle","Base.WoodenStick2"
}
params.discAdd = {
	"Base.ElectricWire","Base.Amplifier","Base.Hinge","Base.WeldingRods","Base.Wire","Base.MetalPipe","Base.CopperScrap","Base.AluminumFragments","Base.IronBand","Base.IronScrap",
	"Base.TirePiece","Base.Buckle","Base.SteelScrap","Base.CircularSawblade","Base.IronBandSmall","Base.SteelRodHalf","Base.SteelRodQuarter","Base.AluminumScrap"
}
params.discParts = {
	"Base.Glue","Base.Screws","Base.DuctTape","Base.Nails","Base.Woodglue","Base.Epoxy","Base.NutsBolts","Base.FiberglassTape"
}

params[8] = { -- improvement level
	electrical = {skills={"Electricity",10,"Mechanics",8,"Maintenance",8},upgrades={"Lifestyle.upgradeElectricRare",1,"Lifestyle.upgradeElectric",2,"Lifestyle.upgradeMechanical",2}},
	electricalHard = {skills={"Electricity",10,"Mechanics",10,"Maintenance",10},upgrades={"Lifestyle.upgradeElectricRare",2,"Lifestyle.upgradeElectric",4,"Lifestyle.upgradeMechanical",3}},

	machinery = {skills={"Mechanics",10,"MetalWelding",8,"Electricity",8},upgrades={"Lifestyle.upgradeMechanicalRare",1,"Lifestyle.upgradeElectricRare",1,"Lifestyle.upgradeMechanical",2,"Lifestyle.upgradeElectric",1,"Lifestyle.upgradePlumbing",1}},
	machineryHard = {skills={"Mechanics",10,"MetalWelding",10,"Electricity",10},upgrades={"Lifestyle.upgradeMechanicalRare",2,"Lifestyle.upgradeElectricRare",2,"Lifestyle.upgradePlumbingRare",2,"Lifestyle.upgradeMechanical",3,"Lifestyle.upgradeElectric",2,"Lifestyle.upgradePlumbing",2}},

	metalwork = {skills={"MetalWelding",10,"Blacksmith",8,"Mechanics",6},upgrades={"Lifestyle.upgradeMechanicalRare",1,"Lifestyle.upgradeMechanical",3,"Lifestyle.upgradePlumbing",2}},
	metalworkHard = {skills={"MetalWelding",10,"Blacksmith",10,"Mechanics",8},upgrades={"Lifestyle.upgradeMechanicalRare",2,"Lifestyle.upgradeMechanical",4,"Lifestyle.upgradePlumbing",4}},

	plumbing = {skills={"Maintenance",10,"Mechanics",8,"MetalWelding",8},upgrades={"Lifestyle.upgradePlumbingRare",1,"Lifestyle.upgradePlumbing",2,"Lifestyle.upgradeMechanical",2}},
	plumbingHard = {skills={"Maintenance",10,"Mechanics",10,"MetalWelding",10},upgrades={"Lifestyle.upgradePlumbingRare",2,"Lifestyle.upgradePlumbing",4,"Lifestyle.upgradeMechanical",3}},	

	woodwork = {skills={"Woodwork",10,"Carving",8,"Maintenance",8},upgrades={"Lifestyle.upgradeWoodRare",1,"Lifestyle.upgradeWood",3,"Lifestyle.upgradeMechanical",2}},
	woodworkHard = {skills={"Woodwork",10,"Carving",10,"Maintenance",10},upgrades={"Lifestyle.upgradeWoodRare",2,"Lifestyle.upgradeWood",4,"Lifestyle.upgradeMechanical",4}},

	cost = { -- vvlow = 2 vlow = 5 low = 10 midlow = 15 mid = 20 midhigh = 30 high = 40 vhigh = 60 vvhigh = 90 ludicrous = 120 params.cost.vludicrous = 200 vvludicrous = 300
		normal = {
			base = {params.cost.ludicrous, params.cost.vvhigh, params.cost.vvhigh, params.cost.vhigh, params.cost.vhigh, params.cost.high, params.cost.high},
			connector = {params.cost.vhigh, params.cost.high, params.cost.high, params.cost.midhigh, params.cost.midhigh},
			parts = {params.cost.ludicrous,params.cost.vvhigh,params.cost.vvhigh,params.cost.vhigh,params.cost.vhigh,params.cost.high,params.cost.high,params.cost.midhigh},
		},
		hard = {
			base = {params.cost.vludicrous, params.cost.ludicrous, params.cost.ludicrous, params.cost.high, params.cost.high, params.cost.midhigh},
			connector = {params.cost.ludicrous, params.cost.vvhigh, params.cost.vvhigh, params.cost.vhigh, params.cost.vhigh, params.cost.high},
			parts = {params.cost.vvludicrous,params.cost.vludicrous,params.cost.ludicrous,params.cost.ludicrous,params.cost.vvhigh,params.cost.vvhigh,params.cost.vhigh,params.cost.high},
		},
	},
}

params[6] = {
	electrical = {skills={"Electricity",8,"Mechanics",8,"Maintenance",6},upgrades={"Lifestyle.upgradeElectric",4,"Lifestyle.upgradeMechanical",3}},
	electricalHard = {skills={"Electricity",9,"Mechanics",8,"Maintenance",8},upgrades={"Lifestyle.upgradeElectricRare",1,"Lifestyle.upgradeElectric",3,"Lifestyle.upgradeMechanical",2}},

	machinery = {skills={"Mechanics",8,"MetalWelding",8,"Electricity",6},upgrades={"Lifestyle.upgradeMechanical",4,"Lifestyle.upgradeElectric",3,"Lifestyle.upgradeWood",1,"Lifestyle.upgradePlumbing",2}},
	machineryHard = {skills={"Mechanics",9,"MetalWelding",8,"Electricity",8},upgrades={"Lifestyle.upgradeMechanicalRare",1,"Lifestyle.upgradeElectricRare",1,"Lifestyle.upgradeMechanical",2,"Lifestyle.upgradeElectric",2,"Lifestyle.upgradePlumbing",1}},

	metalwork = {skills={"MetalWelding",8,"Blacksmith",6,"Mechanics",4},upgrades={"Lifestyle.upgradeMechanical",6,"Lifestyle.upgradePlumbing",2}},
	metalworkHard = {skills={"MetalWelding",9,"Blacksmith",8,"Mechanics",6},upgrades={"Lifestyle.upgradeMechanicalRare",1,"Lifestyle.upgradeMechanical",2,"Lifestyle.upgradePlumbing",2}},

	plumbing = {skills={"Maintenance",8,"Mechanics",6,"MetalWelding",6},upgrades={"Lifestyle.upgradePlumbing",4,"Lifestyle.upgradeMechanical",2}},
	plumbingHard = {skills={"Maintenance",9,"Mechanics",8,"MetalWelding",8},upgrades={"Lifestyle.upgradePlumbingRare",1,"Lifestyle.upgradePlumbing",2,"Lifestyle.upgradeMechanical",1}},	

	woodwork = {skills={"Woodwork",8,"Carving",8,"Maintenance",6},upgrades={"Lifestyle.upgradeWood",6,"Lifestyle.upgradeMechanical",2}},
	woodworkHard = {skills={"Woodwork",9,"Carving",8,"Maintenance",8},upgrades={"Lifestyle.upgradeWoodRare",1,"Lifestyle.upgradeWood",2,"Lifestyle.upgradeMechanical",2}},

	cost = { -- vvlow = 2 vlow = 5 low = 10 midlow = 15 mid = 20 midhigh = 30 high = 40 vhigh = 60 vvhigh = 90 ludicrous = 120 params.cost.vludicrous = 200 vvludicrous = 300
		normal = {
			base = {params.cost.high, params.cost.midhigh, params.cost.midhigh, params.cost.mid, params.cost.mid, params.cost.midlow},
			connector = {params.cost.mid, params.cost.mid, params.cost.midlow, params.cost.low},
			parts = {params.cost.vhigh,params.cost.high,params.cost.high,params.cost.high,params.cost.midhigh,params.cost.midhigh,params.cost.mid},
		},
		hard = {
			base = {params.cost.vvhigh, params.cost.vhigh, params.cost.vhigh, params.cost.high, params.cost.high, params.cost.midhigh},
			connector = {params.cost.vhigh, params.cost.vhigh, params.cost.high, params.cost.high, params.cost.midhigh},
			parts = {params.cost.vvhigh,params.cost.vhigh,params.cost.vhigh,params.cost.high,params.cost.high,params.cost.midhigh},
		},
	},
}

params[4] = {
	electrical = {skills={"Electricity",7,"Mechanics",6,"Maintenance",4},upgrades={"Lifestyle.upgradeElectric",3,"Lifestyle.upgradeMechanical",2}},
	electricalHard = {skills={"Electricity",8,"Mechanics",7,"Maintenance",6},upgrades={"Lifestyle.upgradeElectric",5,"Lifestyle.upgradeMechanical",3}},

	machinery = {skills={"Mechanics",7,"MetalWelding",6,"Electricity",4},upgrades={"Lifestyle.upgradeMechanical",3,"Lifestyle.upgradeElectric",2,"Lifestyle.upgradeWood",2}},
	machineryHard = {skills={"Mechanics",8,"MetalWelding",7,"Electricity",7},upgrades={"Lifestyle.upgradeMechanical",4,"Lifestyle.upgradeElectric",3,"Lifestyle.upgradeWood",2,"Lifestyle.upgradePlumbing",2}},

	metalwork = {skills={"MetalWelding",7,"Blacksmith",5,"Mechanics",3},upgrades={"Lifestyle.upgradeMechanical",4}},
	metalworkHard = {skills={"MetalWelding",8,"Blacksmith",6,"Mechanics",5},upgrades={"Lifestyle.upgradeMechanical",6,"Lifestyle.upgradePlumbing",2}},

	plumbing = {skills={"Maintenance",7,"Mechanics",6,"MetalWelding",4},upgrades={"Lifestyle.upgradePlumbing",3,"Lifestyle.upgradeMechanical",1}},
	plumbingHard = {skills={"Maintenance",8,"Mechanics",7,"MetalWelding",6},upgrades={"Lifestyle.upgradePlumbing",5,"Lifestyle.upgradeMechanical",3}},	

	woodwork = {skills={"Woodwork",7,"Carving",6,"Maintenance",4},upgrades={"Lifestyle.upgradeWood",4}},
	woodworkHard = {skills={"Woodwork",8,"Carving",7,"Maintenance",7},upgrades={"Lifestyle.upgradeWood",5,"Lifestyle.upgradeMechanical",2}},

	cost = { -- vvlow = 2 vlow = 5 low = 10 midlow = 15 mid = 20 midhigh = 30 high = 40 vhigh = 60 vvhigh = 90 ludicrous = 120 params.cost.vludicrous = 200 vvludicrous = 300
		normal = {
			base = {params.cost.mid, params.cost.mid, params.cost.midlow, params.cost.midlow, params.cost.midlow, params.cost.low},
			connector = {params.cost.low, params.cost.low, params.cost.low, params.cost.vlow},
			parts = {params.cost.midhigh,params.cost.mid,params.cost.midlow,params.cost.midlow,params.cost.midlow,params.cost.low,params.cost.low},
		},
		hard = {
			base = {params.cost.vhigh, params.cost.high, params.cost.midhigh, params.cost.midhigh, params.cost.mid, params.cost.mid},
			connector = {params.cost.midhigh, params.cost.midhigh, params.cost.mid, params.cost.midlow},
			parts = {params.cost.vhigh,params.cost.high,params.cost.midhigh,params.cost.midhigh,params.cost.midhigh,params.cost.mid},
		},
	},
}

params[2] = {
	electrical = {skills={"Electricity",4,"Mechanics",3,"Maintenance",2},upgrades={"Lifestyle.upgradeElectric",2}},
	electricalHard = {skills={"Electricity",7,"Mechanics",6,"Maintenance",5},upgrades={"Lifestyle.upgradeElectric",4}},

	machinery = {skills={"Mechanics",4,"MetalWelding",3,"Electricity",2},upgrades={"Lifestyle.upgradeMechanical",1,"Lifestyle.upgradeWood",1}},
	machineryHard = {skills={"Mechanics",7,"MetalWelding",6,"Electricity",6},upgrades={"Lifestyle.upgradeMechanical",2,"Lifestyle.upgradeElectric",2,"Lifestyle.upgradeWood",3}},

	metalwork = {skills={"MetalWelding",4,"Blacksmith",3,"Mechanics",2},upgrades={"Lifestyle.upgradeMechanical",3}},
	metalworkHard = {skills={"MetalWelding",7,"Blacksmith",4,"Mechanics",3},upgrades={"Lifestyle.upgradeMechanical",4,"Lifestyle.upgradePlumbing",1}},

	plumbing = {skills={"Maintenance",4,"Mechanics",3,"MetalWelding",2},upgrades={"Lifestyle.upgradePlumbing",2}},
	plumbingHard = {skills={"Maintenance",7,"Mechanics",5,"MetalWelding",5},upgrades={"Lifestyle.upgradePlumbing",4}},	

	woodwork = {skills={"Woodwork",4,"Carving",3,"Maintenance",2},upgrades={"Lifestyle.upgradeWood",3}},
	woodworkHard = {skills={"Woodwork",7,"Carving",6,"Maintenance",5},upgrades={"Lifestyle.upgradeWood",4}},

	cost = { -- vvlow = 2 vlow = 5 low = 10 midlow = 15 mid = 20 midhigh = 30 high = 40 vhigh = 60 vvhigh = 90 ludicrous = 120 params.cost.vludicrous = 200 vvludicrous = 300
		normal = {
			base = {params.cost.mid, params.cost.mid, params.cost.midlow, params.cost.midlow, params.cost.midlow, params.cost.low},
			connector = {params.cost.low, params.cost.low, params.cost.low, params.cost.vlow},
			parts = {params.cost.midhigh,params.cost.mid,params.cost.midlow,params.cost.midlow,params.cost.midlow,params.cost.low,params.cost.low},
		},
		hard = {
			base = {params.cost.midhigh, params.cost.midhigh, params.cost.mid, params.cost.mid, params.cost.mid, params.cost.midlow},
			connector = {params.cost.mid, params.cost.mid, params.cost.midlow, params.cost.low},
			parts = {params.cost.high,params.cost.high,params.cost.midhigh,params.cost.midhigh,params.cost.mid,params.cost.midlow},
		},
	},
}

params[1] = {
	electrical = {skills={"Electricity",2,"Mechanics",1},upgrades={"Lifestyle.upgradeElectric",1}},
	electricalHard = {skills={"Electricity",5,"Mechanics",4,"Maintenance",3},upgrades={"Lifestyle.upgradeElectric",2}},

	machinery = {skills = {"Mechanics",2,"MetalWelding",1},upgrades={"Lifestyle.upgradeWood",1}},
	machineryHard = {skills = {"Mechanics",5,"MetalWelding",3,"Electricity",3},upgrades={"Lifestyle.upgradeMechanical",1,"Lifestyle.upgradeElectric",1,"Lifestyle.upgradeWood",1}},

	metalwork = {skills = {"MetalWelding",2,"Blacksmith",1},upgrades={"Lifestyle.upgradeMechanical",1}},
	metalworkHard = {skills = {"MetalWelding",5,"Blacksmith",2,"Mechanics",1},upgrades={"Lifestyle.upgradeMechanical",3}},

	plumbing = {skills = {"Maintenance",2,"Mechanics",1},upgrades={"Lifestyle.upgradePlumbing",1}},
	plumbingHard = {skills = {"Maintenance",5,"Mechanics",3,"MetalWelding",3},upgrades={"Lifestyle.upgradePlumbing",2}},	

	woodwork = {skills = {"Woodwork",2,"Carving",1},upgrades={"Lifestyle.upgradeWood",1}},
	woodworkHard = {skills = {"Woodwork",5,"Carving",4,"Maintenance",3},upgrades={"Lifestyle.upgradeWood",3}},

	cost = { -- vvlow = 2 vlow = 5 low = 10 midlow = 15 mid = 20 midhigh = 30 high = 40 vhigh = 60 vvhigh = 90 ludicrous = 120 params.cost.vludicrous = 200 vvludicrous = 300
		normal = {
			base = {params.cost.midlow, params.cost.low, params.cost.vlow, params.cost.vlow, params.cost.vlow, params.cost.vvlow},
			connector = {params.cost.vlow, params.cost.vlow, params.cost.vvlow, params.cost.vvlow},
			parts = {params.cost.mid,params.cost.midlow,params.cost.low,params.cost.low,params.cost.low,params.cost.vlow,params.cost.vlow},
		},
		hard = {
			base = {params.cost.mid, params.cost.midlow, params.cost.midlow, params.cost.low, params.cost.low, params.cost.vlow},
			connector = {params.cost.midlow, params.cost.low, params.cost.low, params.cost.vlow},
			parts = {params.cost.midhigh,params.cost.midhigh,params.cost.mid,params.cost.mid,params.cost.midlow,params.cost.low},
		},
	},
}

params.materials = {}
params.materials.electrical = {
	base = {
		"Base.ElectronicsScrap", "Base.ElectricWire", "Base.CopperSheet", "Base.SmallCopperSheet", "Base.CopperScrap"
	},
	connector = {
		"Base.DuctTape", "Base.Glue", "Base.FiberglassTape", "Base.Screws", "Base.Wire"
	},
	parts = {
		"Base.ElectronicsScrap", "Base.ElectricWire", "Base.CopperSheet", "Base.SmallCopperSheet", "Base.CopperScrap", "Base.Receiver",
		"Base.DuctTape", "Base.LightBulb", "Base.RadioReceiver", "Base.RadioTransmitter", "Base.CarBattery2", "Base.Amplifier", "Base.NoiseTrap",
		"Base.Battery", "Base.MotionSensor", "Base.AlarmClock2", "Base.Aluminum", "Base.LightBulbGreen", "Base.Screws", "Base.TinCanEmpty",
		"Base.AluminumFragments", "Base.Wire", "Base.MetalPipe", "Base.CordlessPhone", "Base.Remote", "Base.Pager", "Base.Timer"
	},
}
params.materials.electricalHard = {
	base = {
		"Base.CopperSheet", "Base.ElectricWire"
	},
	connector = {
		"Base.DuctTape", "Base.DuctTape", "Base.FiberglassTape"
	},
	parts = params.materials.electrical.parts,
}
params.materials.machinery = {
	base = {
		"Base.ScrapMetal", "Base.MetalBar", "Base.SheetMetal", "Base.SmallSheetMetal"
	},
	connector = {
		"Base.DuctTape", "Base.Screws", "Base.FiberglassTape", "Base.NutsBolts", "Base.Wire", "Base.Epoxy", "Base.Glue", "Base.WeldingRods"
	},
	parts = {
		"Base.MetalPipe", "Base.MetalBar", "Base.ElectronicsScrap", "Base.SteelBar", "Base.DuctTape", "Base.Screws", "Base.FiberglassTape", "Base.NutsBolts",
		"Base.Wire", "Base.IronBand", "Base.IronBandSmall", "Base.Glue", "Base.Epoxy", "Base.IronBar", "Base.ScrapMetal", "Base.SteelScrap", "Base.WeldingRods",
		"Base.CopperSheet", "Base.SmallCopperSheet", "Base.IronScrap", "Base.CopperScrap", "Base.ElectricWire", "Base.SheetMetal", "Base.SmallSheetMetal",
		"Base.Hinge", "Base.EngineParts", "Base.AluminumScrap", "Base.Latch", "Base.TirePiece", "Base.Buckle", "Base.BrassScrap", "Base.NormalSuspension1",
		"Base.OldCarMuffler1", "Base.CarBattery1", "Base.OldBrake1"
	},
}
params.materials.machineryHard = {
	base = {
		"Base.SteelBar", "Base.MetalBar", "Base.SheetMetal"
	},
	connector = {
		"Base.DuctTape", "Base.DuctTape", "Base.DuctTape", "Base.FiberglassTape", "Base.FiberglassTape", "Base.Epoxy", "Base.Epoxy"
	},
	parts = {
		"Base.MetalPipe", "Base.MetalBar", "Base.ElectronicsScrap", "Base.SteelBar", "Base.DuctTape", "Base.Screws", "Base.FiberglassTape", "Base.NutsBolts",
		"Base.Wire", "Base.IronBand", "Base.Epoxy", "Base.IronBar", "Base.ScrapMetal", "Base.SteelScrap", "Base.WeldingRods", "Base.CopperSheet",
		"Base.IronScrap", "Base.CopperScrap", "Base.ElectricWire", "Base.SheetMetal", "Base.EngineParts", "Base.NormalSuspension2", "Base.NormalBrake2",
		"Base.CarBattery2", "Base.NormalCarMuffler2"
	},
}
params.materials.metalwork = {
	base = {
		"Base.MetalPipe", "Base.MetalBar", "Base.SmallSheetMetal", "Base.SheetMetal"
	},
	connector = {
		"Base.Screws", "Base.NutsBolts", "Base.WeldingRods"
	},
	parts = {
		"Base.HeavyChainLink", "Base.MetalBar", "Base.MetalPipe", "Base.SteelBar", "Base.SmallSheetMetal", "Base.Screws", "Base.SheetMetal", "Base.NutsBolts",
		"Base.DrawPlate", "Base.IronBand", "Base.IronBandSmall", "Base.SteelRodHalf", "Base.SteelRodQuarter", "Base.IronBar", "Base.ScrapMetal", "Base.SteelScrap",
		"Base.IronBarHalf", "Base.IronScrap", "Base.SteelBarHalf", "Base.Hinge"
	},
}
params.materials.metalworkHard = params.materials.metalwork
params.materials.plumbing = {
	base = {
		"Base.MetalPipe", "Base.MetalBar", "Base.LeadPipe"
	},
	connector = {
		"Base.DuctTape", "Base.Screws", "Base.FiberglassTape", "Base.NutsBolts", "Base.Wire"
	},
	parts = {
		"Base.MetalPipe", "Base.MetalBar", "Base.LeadPipe", "Base.SteelBar", "Base.DuctTape", "Base.Screws", "Base.FiberglassTape", "Base.NutsBolts",
		"Base.Wire", "Base.IronBand", "Base.IronBandSmall", "Base.SteelRodHalf", "Base.SteelRodQuarter", "Base.IronBar", "Base.ScrapMetal", "Base.SteelScrap",
		"Base.CopperSheet", "Base.SmallCopperSheet", "Base.IronScrap", "Base.CopperScrap"
	},
}
params.materials.plumbingHard = {
	base = {
		"Base.SteelBar", "Base.MetalBar"
	},
	connector = {
		"Base.DuctTape", "Base.DuctTape", "Base.DuctTape", "Base.FiberglassTape", "Base.FiberglassTape"
	},
	parts = params.materials.plumbing.parts,
}
params.materials.woodwork = {
	base = {
		"Base.LargePlank", "Base.Plank", "Base.LongStick", "Base.WoodenStick2"
	},
	connector = {
		"Base.Woodglue", "Base.Nails", "Base.LeatherStrips", "Base.Screws", "Base.Epoxy"
	},
	parts = {
		"Base.Woodglue", "Base.Nails", "Base.LeatherStrips", "Base.Screws", "Base.Epoxy", "Base.Handle", "Base.Plank", "Base.LongStick",
		"Base.String", "Base.Wire", "Base.Twine", "Base.LongHandle", "Base.WoodenStick2", "Base.NutsBolts", "Base.BurlapPiece", "Base.Rope",
		"Base.Thread_Sinew", "Base.Thread", "Base.Yarn", "Base.RippedSheets", "Base.FabricRoll_Cotton", "Base.SmallHandle", "Base.Tarp"
	},
}
params.materials.woodworkHard = {
	base = params.materials.woodwork.base,
	connector = {
		"Base.Woodglue", "Base.Woodglue", "Base.Woodglue", "Base.Epoxy", "Base.Epoxy", "Base.Thread_Aramid"
	},
	parts = params.materials.woodwork.parts,
}

--res list
--electrical - Base.ElectronicsScrap Base.ElectricWire Base.Receiver Base.DuctTape Base.LightBulb Base.RadioReceiver Base.RadioTransmitter Base.CarBattery1 Base.CarBattery2 Base.CarBattery3 Base.Amplifier Base.NoiseTrap Base.TriggerCrafted 
-- Base.MotionSensor Base.TimerCrafted Base.Aluminum Base.LightBulb Base.LightBulbGreen Base.Screws Base.TinCanEmpty Base.Wire Base.MetalPipe Base.CordlessPhone Base.Remote Base.Glue
--machinery - Base.ElectronicsScrap Base.ElectricWire Base.DuctTape Base.ScrapMetal Base.MetalPipe Base.Hinge Base.Screws Base.Wire Base.EngineParts Base.ModernSuspension1 Base.ModernSuspension2 Base.ModernSuspension3 Base.NormalBrake2
--metalwork - Base.MetalPipe Base.MetalBar Base.SheetMetal Base.SmallSheetMetal Base.WeldingRods Base.Hinge Base.ScrapMetal
--plumbing - Base.DuctTape Base.MetalPipe Base.LeadPipe Base.MetalBar
--woodwork - Base.Woodglue Base.Nails Base.Plank Base.LeatherStrips Base.Twine Base.Screws Base.Wire

--b42 only
--electrical - Base.ElectricWire Base.CopperScrap Base.AluminumFragments Base.Pager Base.Timer
--machinery - Base.ElectricWire Base.Epoxy Base.AluminumScrap Base.IronBand Base.IronBar Base.Latch Base.IronScrap Base.TirePiece Base.Buckle Base.NutsBolts Base.SteelBar Base.SteelScrap Base.CircularSawblade
--metalwork - Base.IronBar Base.IronBarHalf Base.SteelBar Base.SteelBarHalf 
--plumbing - Base.FiberglassTape Base.IronBand Base.IronBandSmall Base.SteelRodHalf Base.SteelRodQuarter
--woodwork - Base.LongStick Base.LongHandle Base.Handle Base.WoodenStick2 Base.NutsBolts Base.Leather_Crude_Medium_Tan Base.TableLeg

--junk - Base.CanPipe Base.TableLeg Base.Bell Base.Camera Base.ChairLeg Base.Cork Base.DryerLint Base.FurTuft_Black Base.FurTuft_Browndark Base.FurTuft_Grey Base.FurTuft_Brownlight Base.FurTuft_White
-- Base.Clitter Base.HolePuncher Base.Pinecone Base.Pipe Base.PlasticTray Base.ClayPlate Base.RubberBand Base.SpadeHead Base.Stapler Base.Staples Base.Straw2 Base.Tsquare Base.TinCanEmpty
-- Base.AnimalBone Base.LargeAnimalBone Base.BoneBead_Large Base.SharpBoneFragment Base.Charcoal Base.Coke 	Base.CharcoalCrafted

params[3] = params[2]; params[5] = params[4]; params[7] = params[6]; params[9] = params[8]; params[10] = params[8]; params[11] = params[8];

---- INVENTIONS

---- HYGIENATOR

LSInventionDefs.Items.Hygienator = {
	-- data for moveables is copied over to item moveable data when created (after checking for player-made improvements)
	-- essential
	enabled = true, -- functional, discoverable and craftable
	discover = {"Mechanics",3,"MetalWelding",2,"Electricity",2,"Maintenance",1}, -- minimum skill to be able to invent this item, false means no skill req, must be at minimum the skill req for production - div is 2
	isMoveable = true, -- moveables item data is not persistent, so is added to moveables data
	costDefs = {{"machineryHard","plumbing"},2,1.5}, -- item and skill groups, skill div, production div (repair is half)
	costPenalty = 1, -- cost is multiplied by this number, increases with total number of improvements, improvement type and level / updated when produced
	repairList = false, -- required for repair list permanence
	-- common non-improvements
	isBroken = false, -- broken - required for obj inventions that can break
	cooldown = false, -- current cooldown / in game hours
	-- specific non-improvements
	hygieneMax = 30,	
	-- repeatable improvements
	-- common
	efficiency = 0.1, -- improved hygiene and visual cleaning values
	cooldownTime = 48, -- cooldown between uses / in game hours
	waterUsage = {100, 50}, -- water used, cleanining liquid used / in units
	costDecrease = 1, -- penalty is divided by this number
	durability = {50,75}, -- reduces breakdown and failure (and puddle) chance
	standardization = 1, -- piece standardization, production cost and time are divided by this number
	-- special
	isPerfumed = false,
	-- non repeatable improvements
	-- common
	-- special
	noPlumbing = false, -- no water req
	selfPowered = false, -- no energy req
	isHeated = false, -- removes cold water debuff, adds hot water buff
	hasDryJet = false, -- won't make worn clothes and character wet
	hasHighPressureJet = false, -- clean worn clothes
	-- indirect improvements - multiplied by efficiency improvement
	efficiencyBase = {70,1,1},
	efficiencyMult = {7,0.1,0.1},
	-- cheats
	neverBreak = false,
	neverSpill = false,
	noCooldown = false,
	-- (desc stats)
	reqWater = true,
	reqPower = true,
}

--repeatable - table, each key represents a level, improvements is set to key value upon research
--result - research will always set improvement to result value and is treated as level 10 for research. repeatable must be nil
--special - how many researched improvements are required to enable this improvement {# of improvements, min level in each} and improvement is added to special list (limited research)
--customRes - table, custom resource followed by number
--customSkill - perk string, level is same as improvement level

LSInventionDefs.Improvements.Hygienator = {
	-- list of improvements and its research args / last arg of repeatables is omitted for players without the relevant ambition (for improvements with >2 repetitions)
	costDecrease = {repeatable={1.1,1.3,1.4,1.7,1.9,2.2,2.4,3,3.3,3.6}, defs="machinery"},
	efficiency = {repeatable={0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1}, defs="plumbing"},
	standardization = {repeatable={1.2,1.5,1.7,2.2,2.5,3}, defs="metalworkHard"},
	durability = {repeatable={{45,70}, {40,60}, {35,50}, {30,40}, {25,30}, {15,20}, {10,15}, {5,10}, {2,5}, {0,0}}, defs="metalwork", customSkill="Maintenance"},
	cooldownTime = {repeatable={44, 36, 30, 24, 18, 12, 8, 4}, defs="electrical"},
	waterUsage = {repeatable={{75,40}, {60,30}, {40,20}, {20,10}, {10,5}}, defs="plumbing"},
	isPerfumed = {special={2,3},repeatable={{level=0.2,buff=10}, {level=0.2,buff=25}, {level=0.6,buff=40}, {level=0.8,buff=60}}, defs="machineryHard", customRes={"Base.Perfume",5,"Base.GardeningSprayEmpty",1,"Base.TriggerCrafted",1}},
	-- non-repeatables use value from result when research is finished; they use improvement level 10 for skill and res defs
	noPlumbing = {special={3,5}, result=true, defs="plumbingHard", customRes={"Base.Charcoal",3,"Base.Coldpack",1}},
	selfPowered = {special={3,5}, result=true, defs="electricalHard", customRes={"Base.PowerBar",1,"Base.MotionSensor",1,"Base.Battery",2,"Base.CarBatteryCharger",1}},
	isHeated = {special={2,3}, result=true, defs="electricalHard", customRes={"Base.HairDryer",1,"Base.HairIron",1,"Base.Hairspray",2,"Base.Lighter",5,"Base.Sparklers",1}},
	hasDryJet = {special={2,3}, result=true, defs="plumbingHard", customRes={"Base.TimerCrafted",1,"Base.HairDryer",2}},
	hasHighPressureJet = {special={3,5}, result=true, defs="plumbingHard", customRes={"Base.EngineParts",10,"Base.BlowerFan",1}},
}

---- FOOD SYNTHESIZER

LSInventionDefs.Items.FoodSynthesizer = {
	-- data for moveables is copied over to item moveable data when created (after checking for player-made improvements)
	-- essential
	enabled = true, -- functional, discoverable and craftable
	discover = {"Cooking",3,"Electricity",2,"Maintenance",1}, -- minimum skill to be able to invent this item, false means no skill req, must be at minimum the skill req for production - div is 2
	isMoveable = true, -- moveables item data is not persistent, so is added to moveables data
	costDefs = {{"electricalHard","metalwork"},2,1.5}, -- item and skill groups, skill div, production div (repair is half)
	costPenalty = 1, -- cost is multiplied by this number, increases with total number of improvements, improvement type and level / updated when produced
	repairList = false, -- required for repair list permanence
	-- common non-improvements
	isBroken = false, -- broken - required for obj inventions that can break
	cooldown = false, -- current cooldown / in game hours
	waterUsage = {10},
	running = false,
	-- specific non-improvements
	storedWeight = 0, -- current food weight stored in machine
	foodReady = false, -- current food in machine represented by int and string {1,"Lifestyle.PasteGrub"} where #1 is amount and #2 is food fullType
	foodTime = false, -- time until food is ready, defined by ta
	-- repeatable improvements
	-- common
	cooldownTime = 8, -- cooldown between uses / in game hours
	costDecrease = 1, -- penalty is divided by this number
	durability = {50,75}, -- reduces breakdown and failure chances
	standardization = 1, -- piece standardization, production cost and time are divided by this number
	foodContainer = 3, -- how much food weight it can hold, anything added beyond this value is wasted
	-- special
	foodUsage = 3.0, -- food used in weight
	foodQuality = {-0.05,20,100}, -- satiety/hunger, unhappiness and chance of food sickness
	-- non repeatable improvements
	-- common
	-- special
	noPlumbing = false, -- no water req
	selfPowered = false, -- no energy req
	burgerPrint = false, -- produces paste burgers instead of paste grub
	acceptRotten = false, -- can use rotten food
	multiplyPaste = false, -- 50% of double paste, 15% of triple, 1% of quadruple paste
	-- cheats
	neverBreak = false,
	noCooldown = false,
	-- (desc stats)
	reqWater = true,
	reqPower = true,
}

--repeatable - table, each key represents a level, improvements is set to key value upon research
--result - research will always set improvement to result value and is treated as level 10 for research. repeatable must be nil
--special - how many researched improvements are required to enable this improvement {# of improvements, min level in each, specific improv, min level, mutually exclusive improv} and improvement is added to special list (limited research)
--customRes - table, custom resource followed by number
--customSkill - perk string, level is same as improvement level

LSInventionDefs.Improvements.FoodSynthesizer = {
	-- list of improvements and its research args / last arg of repeatables is omitted for players without the relevant ambition (for improvements with >2 repetitions)
	costDecrease = {repeatable={1.1,1.3,1.4,1.7,1.9,2.2,2.4,3,3.3,3.6}, defs="machinery"},
	standardization = {repeatable={1.2,1.5,1.7,2.2,2.5,3}, defs="metalworkHard"},
	durability = {repeatable={{45,70}, {40,60}, {35,50}, {30,40}, {25,30}, {15,20}, {10,15}, {5,10}, {2,5}, {0,0}}, defs="metalwork", customSkill="Maintenance"},
	cooldownTime = {repeatable={7, 6, 5, 4, 3, 2, 1, 0}, defs="electrical"},
	foodContainer = {repeatable={3, 6, 8, 10, 12}, defs="metalwork"},
	foodUsage = {repeatable={2.8,2.6,2.4,2.1,1.8,1.5,1.2,0.8,0.5,0.3}, defs="machinery"},
	foodQuality = {repeatable={{-0.1,10,50},{-0.15,5,20},{-0.2, 0,5},{-0.25,-5,1},{-0.3,-15,0}}, defs="machineryHard", customRes={"Base.SeasoningSalt",2,"Base.Sugar",1,"Base.BalsamicVinegar",1}},
	-- non-repeatables use value from result when research is finished; they use improvement level 10 for skill and res defs
	noPlumbing = {special={3,5}, result=true, defs="plumbingHard"},
	selfPowered = {special={3,5}, result=true, defs="electricalHard", customRes={"Base.PowerBar",1,"Base.CarBattery2",1,"Base.CarBatteryCharger",1}},
	burgerPrint = {special={2,5,"foodQuality",5}, result=true, defs="plumbingHard", customRes={"Base.Flour2",2,"Base.BakingSoda",10}},
	acceptRotten = {special={2,3}, result=true, defs="machineryHard", customRes={"Base.Hairspray",1,"Base.Salt",2,"Base.Bleach",1}},
	multiplyPaste = {special={3,5}, result=true, defs="metalworkHard", customRes={"Base.EngineParts",10,"Base.AnimalFeedBag",20}},
}

---- HARVESTER

LSInventionDefs.Items.Harvester = {
	-- copied over to item data when created (after checking for player-made improvements)
	-- keys not added to this list will be removed from data if added elsewhere
	-- essential
	enabled = true, -- functional, discoverable and craftable
	discover = {"Electricity",4,"Mechanics",3,"Maintenance",3,"MetalWelding",2}, -- minimum skill to be able to invent this item, false means no skill req - div is 1.4
	costDefs = {{"electricalHard","metalwork","machinery"},1.4,1}, -- item and skill groups, skill div, production div (repair is half)
	costPenalty = 1, -- cost is multiplied by this number, increases with total number of improvements, improvement type and level / updated when produced
	weightTotal = 20, -- total item weight (base + fuelContainer[2] - weightDecrease) / never less than 0.1
	autoSync = true, -- if loaddefs updates scripts
	repairList = false, -- required for repair list permanence
	-- fuel essentials
	fuelUses = 0,
	fuelDelta = 0, -- fuel quantity stored that isn't enough to 
	fuelUseDelta = 4, -- set how much item/fuel use will add to fuelDelta, essentially a way to multiplie use
	fuelItem = "PetrolCan",
	fuelLiquid = "Petrol",
	fuelTag = false,
	fuelingSound = "GeneratorAddFuel",
	fuelingBaseTime = 100, -- base fueling time (added to delta time calc)
	-- common non-improvements
	--isBroken = false, -- broken
	cooldown = false, -- current cooldown / in game hours - required if invention has a cooldown period

	-- specific non-improvements

	-- repeatable improvements
	-- common
	power = {0.1,5}, -- improves work speed and container capacity
	sensors = {1,2}, -- better sensors improve range and maximum harvest number
	cooldownTime = 36, -- cooldown if machine overheats / in game hours
	fuelConsumption = 10, -- reduces fuel consumption / in fuel uses per machine use
	fuelContainer = {3,0}, -- how many uses it can hold, increases weight
	costDecrease = 1, -- penalty is divided by this number
	durability = {50,75}, -- reduces breakdown and overheat chance (rolls when stopping and completing)
	weightDecrease = 0, -- lighter materials reduce item encumbrance
	standardization = 1, -- piece standardization, production cost and time are divided by this number
	-- special
	booster = 1, -- increases crop and seed yield
	-- non repeatable improvements
	-- common
	recirculator = false, -- chance to not spend fuel on use
	-- special
	silent = false, -- muffled vaccuum sound and won't draw nearby zombies
	replant = false, -- harvester will attempt to replant when possible

	-- indirect improvements - multiplied by efficiency improvement

	-- (desc stats)

}

LSInventionDefs.Improvements.Harvester = {
	-- list of improvements and its research args / last arg of repeatables is omitted for players without the relevant ambition (for improvements with >2 repetitions)
	costDecrease = {repeatable={1.1,1.3,1.4,1.7,1.9,2.2,2.4,3,3.3,3.6}, defs="metalwork"},
	power = {repeatable={{0.2,6}, {0.3,8}, {0.4,10}, {0.5,12}, {0.6,15}, {0.7,18}, {0.8,22}, {0.9,25}, {1,30}}, defs="machinery", customRes={"Base.BlowerFan",1}},
	standardization = {repeatable={1.2,1.5,1.7,2.2,2.5,3}, defs="metalworkHard"},
	sensors = {repeatable={{2,3}, {3,4}, {4,6}, {5,8}, {6,10}, {7,12}, {7,15}, {8,18}, {8,20}, {9,25}}, defs="electrical", customRes={"Base.EngineParts",2,"Base.ScannerModule",1}},
	durability = {repeatable={{45,70}, {40,60}, {35,50}, {30,40}, {25,30}, {15,20}, {10,15}, {5,10}, {2,5}, {0,0}}, defs="metalwork", customSkill="Maintenance"},
	cooldownTime = {repeatable={32, 28, 24, 20, 16, 12, 8, 4, 2}, defs="machinery"},
	fuelConsumption = {repeatable={9,8,7,5,4,3,2}, defs="machinery"},
	fuelContainer = {repeatable={{5,3}, {7,5}, {10,7}, {15,10}, {20,15}, {30,18}}, defs="machineryHard", customRes={"Base.BigGasTank2",1}},
	weightDecrease = {repeatable={2,4,7,10,13,16,20,25}, defs="metalwork"},
	-- special
	booster = {special={2,3},repeatable={1.1,1.2,1.3,1.4,1.5}, defs="machineryHard", customRes={"Base.EngineParts",10,"Base.HairDryer",2}},
	-- non-repeatables use value from result when research is finished; they use improvement level 10 for skill and res defs
	recirculator = {special={5,3}, result=true, defs="metalworkHard"},
	silent = {special={3,3}, result=true, defs="machineryHard", customRes={"Base.Pillow",3,"Base.ModernCarMuffler2",1}},
	replant = {special={3,3}, result=true, defs="electricalHard", customRes={"Base.TriggerCrafted",1,"Base.Battery",10}},
}

LSInventionDefs.ItemScript.Harvester = {
	power = {false, 'Capacity'},
	weightTotal = 'ActualWeight',
}

LSInventionDefs.Modifiers.Harvester = {
	weightTotal = {key=false,min=0.1,add={20,{false,'fuelContainer'}},subtract={'weightDecrease'}},
}

----

---- POWER AXE

LSInventionDefs.Items.PowerAxe = {
	-- sent to item moveable data when created (after checking for player-made improvements)
	-- essential
	enabled = true, -- functional, discoverable and craftable
	discover = {"Electricity",2,"Mechanics",3,"Axe",4}, -- minimum skill to be able to invent this item, false means no skill req - div is 1.4
	costDefs = {{"machineryHard","electrical"},1.4,1}, -- item and skill groups, skill div, production div (repair is half)
	costPenalty = 1, -- cost is multiplied by this number, increases with total number of improvements, improvement type and level / updated when produced
	--weightTotal = 5, -- total item weight (base + fuelContainer[2] - weightDecrease) / never less than 0.1
	repairList = false, -- required for repair list permanence
	-- fuel essentials
	fuelUses = 0, -- fuel quantity stores in uses
	fuelDelta = 0, -- fuel quantity stored that isn't enough to reach 1 fuel use
	fuelUseDelta = 1, -- set how much item/fuel use will add to fuelDelta, essentially a way to multiplie use
	fuelItem = "GunPowder",
	fuelLiquid = false, -- liquid tag
	fuelTag = false, -- other tags
	fuelingSound = "GeneratorAddFuel",
	fuelingBaseTime = 70, -- base fueling time (added to delta time calc)
	-- common non-improvements

	--isBroken = false, -- broken
	--cooldown = false, -- current cooldown / in game hours
	-- specific non-improvements
	-- repeatable improvements
	-- common
	fuelConsumption = 9, -- reduces fuel consumption / in units per use (gunpowder)
	fuelContainer = {1,0}, -- how much fuel it can hold / in uses ; weight increase (disabled - not using weight increase for HandWeapon types)
	costDecrease = 1, -- penalty is divided by this number
	durability = {50,50}, -- reduces explosion/breakdown chance (no explosion - only breaks - below 10 chance) (chance rolls for break, if it passes then rolls again for explosion)
	--weightDecrease = 0, -- lighter materials reduce item encumbrance
	standardization = 1, -- piece standardization, production cost and time are divided by this number
	-- special
	power = {30, 0, false}, -- power hit damage, increases breakdown chance (adds to roll), any upgrade in this enables explosion chance
	resistant = 5, -- HandWeapon only, decreases weapon condition loss chance
	-- non repeatable improvements
	-- common
	recirculator = false, -- chance to not spend fuel on use
	-- special
	lethal = false, -- powered hits can be used against other targets (target takes half power damage and chance to stun / doubles fuel consumption)

	-- indirect improvements - multiplied by efficiency improvement (removes base_)

	-- (desc stats)

}

LSInventionDefs.Improvements.PowerAxe = {
	-- list of improvements and its research args / last arg of repeatables is omitted for players without the relevant ambition (for improvements with >2 repetitions)
	power = {repeatable={{60,2,false},{90,4,true},{150,5,true},{250,5,true}}, defs="machineryHard"},
	costDecrease = {repeatable={1.1,1.3,1.4,1.7,1.9,2.2,2.4,3,3.3,3.6}, defs="metalwork"},
	standardization = {repeatable={1.2,1.5,1.7,2.2,2.5,3}, defs="metalworkHard"},
	durability = {repeatable={{40,45}, {30,40}, {20,35}, {15,30}, {10,25}, {5,20}, {3,15}, {2,10}, {1,5}, {0,0}}, defs="metalwork", customSkill="Maintenance"},
	fuelConsumption = {repeatable={8,6,4,2,1}, defs="machinery"},
	fuelContainer = {repeatable={{3,1},{5,3},{8,5},{16,8},{24,10},{40,15},{60,20}}, defs="metalwork"},
	resistant = {repeatable={8,12,16,22,28,35,40}, defs="metalworkHard", customSkill="Maintenance"},
	--weightDecrease = {repeatable={2,4,6,8,10,14,20}, defs="metalwork"},
	-- non-repeatables use value from result when research is finished; they use improvement level 10 for skill and res defs
	recirculator = {special={5,3}, result=true, defs="metalworkHard"},
	lethal = {special={5,3}, result=true, defs="machineryHard"},
}

LSInventionDefs.ItemScript.PowerAxe = {
	power = {'TreeDamage'},
	resistant = 'ConditionLowerChance',
	--weightTotal = 'ActualWeight', -- can't modify HandWeapon weight directly, using weaponpart workaround would add unnecessary complexity
}

LSInventionDefs.Modifiers.PowerAxe = {
	--weightTotal = {arg=false,min=0.1,add={5,{false,'fuelContainer'}},subtract={'weightDecrease'}},
	--costDefs = {key=3,min=0.1,add={5,{false,'fuelContainer'}},subtract={'weightDecrease'}},
}

---- NEURAL HAT

LSInventionDefs.Items.NeuralHat = {
	-- sent to item moveable data when created (after checking for player-made improvements)
	-- essential
	enabled = true, -- functional, discoverable and craftable
	discover = {"Electricity",6,"Mechanics",6,"Maintenance",4}, -- minimum skill to be able to invent this item, false means no skill req - div is 1.4
	costDefs = {{"machineryHard","electrical"},1.4,1}, -- item and skill groups, skill div, production div (repair is half)
	costPenalty = 1, -- cost is multiplied by this number, increases with total number of improvements, improvement type and level / updated when produced
	--weightTotal = 5, -- total item weight (base + fuelContainer[2] - weightDecrease) / never less than 0.1
	repairList = false, -- required for repair list permanence
	-- fuel essentials
	running = false, -- if gadget has a running state it requires this key
	fuelUses = 0, -- fuel quantity stores in uses
	fuelDelta = 0, -- fuel quantity stored that isn't enough to reach 1 fuel use
	fuelUseDelta = 1, -- set how much item/fuel use will add to fuelDelta, essentially a way to multiplie use
	fuelItem = "Battery",
	fuelLiquid = false, -- liquid tag
	fuelBattery = true, -- fuel acts as battery (insert/remove)
	hasBattery = false,
	fuelTag = false, -- other tags
	fuelingSound = false,
	fuelMin = 0.15, -- min liquid or usedelta to add fuel
	fuelingBaseTime = 70, -- base fueling time (added to delta time calc)
	-- common non-improvements
	cooldown = false, -- current cooldown / in game hours - required if invention has a cooldown period
	recentActive = 0, -- 10min per unity delay for overdrive management
	isBroken = false, -- broken
	-- specific non-improvements
	-- repeatable improvements
	-- common
	efficiency = 0.1, -- improved xp gains
	cooldownTime = 12, -- cooldown / in game hours
	fuelConsumption = 25, -- reduces fuel consumption / in units per use (gunpowder)
	fuelContainer = {100,0}, -- how much fuel it can hold / in uses (battery types always have 100) ; weight increase (disabled for battery types)
	costDecrease = 1, -- penalty is divided by this number
	durability = {50,50}, -- reduces explosion/breakdown chance (no explosion - only breaks - below 10 chance) (chance rolls for break, if it passes then rolls again for explosion)
	--weightDecrease = 0, -- lighter materials reduce item encumbrance
	standardization = 1, -- piece standardization, production cost and time are divided by this number
	-- special
	overdrive = {false, 0, 0}, -- overdrive level, increases breakdown chance (adds to roll), increases fuel consumption, cant research safe, each new level decreases fuel consumption of previous levels
	-- non repeatable improvements
	-- common
	recirculator = false, -- chance to not spend fuel on use
	-- special
	safe = false, -- reduces all breakdown chances to 0, cant research overdrive
	fastRead = false, -- cuts read time by half when not in overdrive
	-- indirect improvements - multiplied by efficiency improvement (removes base_)
	efficiencyBase = {1,2,0.5}, -- base values - xp gain div / read speed / extra xp gain (chance based)
	efficiencyMult = {0.1,0.2,0.05}, -- final result of base*efficiency
	-- (desc stats)

}

LSInventionDefs.Improvements.NeuralHat = {
	-- list of improvements and its research args / last arg of repeatables is omitted for players without the relevant ambition (for improvements with >2 repetitions)
	costDecrease = {repeatable={1.1,1.3,1.4,1.7,1.9,2.2,2.4,3,3.3,3.6}, defs="metalwork"},
	efficiency = {repeatable={0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1}, defs="plumbing"},
	standardization = {repeatable={1.2,1.5,1.7,2.2,2.5,3}, defs="metalworkHard"},
	durability = {repeatable={{40,45}, {30,40}, {20,35}, {15,30}, {10,25}, {5,20}, {3,15}, {2,10}, {1,2}}, defs="metalwork", customSkill="Maintenance"},
	cooldownTime = {repeatable={10, 8, 6, 4, 2, 1}, defs="electrical"},
	fuelConsumption = {repeatable={20,15,10,7,3}, defs="machinery"},
	--weightDecrease = {repeatable={2,4,6,8,10,14,20}, defs="metalwork"},
	-- special
	overdrive = {special={3,4,"durability",4,"safe"}, repeatable={{1,2,5},{2,4,7},{3,10,10}}, defs="machineryHard"},
	-- non-repeatables use value from result when research is finished; they use improvement level 10 for skill and res defs
	fastRead = {special={2,2}, result=true, defs="electricalHard"},
	safe = {special={2,2,"durability",9,"overdrive"}, result=true, defs="plumbingHard"},
	recirculator = {special={3,3,"fuelConsumption",5}, result=true, defs="metalworkHard"},
}

LSInventionDefs.ItemScript.NeuralHat = {

}

LSInventionDefs.Modifiers.NeuralHat = {

}

----

LSInv.getResearchGroupedItems = function(defs, level)
	local mainDef = (type(defs) == "string" and defs) or defs[1]
	local list = params.materials[mainDef] or params.materials['machineryHard']
	local upgradeTable = params[level][mainDef].upgrades
	local upgradeList = {}
	for j=1,#upgradeTable do
		local upgrade = upgradeTable[j]
		if type(upgrade) ~= "number" then table.insert(upgradeList, upgrade); end
	end
	list.upgrades = upgradeList
	return list
end

LSInv.getDiscoveryBasicItems = function(level, skillLevel)
	local div = (skillLevel == 10 and 2) or 1
	--local minLevel = math.max(1, level)
	local maxItems = math.ceil(0.4*level)
	local lists = {"discBase","discAdd","discParts"}
	local itemList = {}
	for j=1, #lists do
		local i = 0
		local list = params[lists[j]]
		if lists[j] ~= "discAdd" or level > 5 then
			for n=1, #list do
				if ZombRand(101) <= 25 then
					local rdmNum = LSUtil.rdm_inst:random(5)+level
					itemList[list[n]] = math.floor(rdmNum/div)
					i=i+1
					if i >= maxItems then break; end
				end
			end
		end
		if i == 0 and lists[j] == "discBase" then 
			local rdmItem = list[ZombRand(#list)+1]
			itemList[rdmItem] = math.floor((LSUtil.rdm_inst:random(5)+level)/div)
		end
	end
	return itemList
end

local function getNewCosts(data, resList, resName, value, isRepair, isResearch)
	local div, mult = 1, data['costPenalty']/data['costDecrease']
	if not isResearch then
		div = data['standardization']
		local divMult = data['costDefs'][3]
		if isRepair then divMult = divMult*4; else divMult=divMult*2; end
		div = div*divMult
	end
	value = math.ceil((value*mult)/(div*2))
	if not resList[resName] then resList[resName] = 0; end
	return math.ceil(resList[resName]+value)
end

local function addToResourceTable(resTable, resName, resCost, isRepair)
	table.insert(resTable, resName)
	local idx = ZombRand(#resCost)+1
	local value = resCost[idx]
	if string.find(resName, "Brake") or string.find(resName, "CarBattery") or string.find(resName, "Muffler") or string.find(resName, "Suspension") then
		value = (isRepair and 1) or math.min(2, value)
	end
	table.insert(resTable, value)
	return resTable
end

local function getResourceTable(costTable, defTable, maxParts, isRepair)
	local resTable = {}
	local resRef = {'base','connector'}
	for n=1, #resRef do
		local res = resRef[n]
		local idx = ZombRand(#defTable[res])+1
		local resName = defTable[res][idx]
		resTable = addToResourceTable(resTable, resName, costTable[res], isRepair)
	end
	local partsByNum = LSUtil.getRandomNumbers(#defTable.parts, maxParts, true)
	for k, v in pairs(partsByNum) do
		local part = defTable.parts[v]
		if part then
			resTable = addToResourceTable(resTable, part, costTable.parts, isRepair)
		end
	end
	return resTable
end

LSInv.getInventionDefinitionsMult = function(obj, level, defs, data, workData) -- isRepair, isResearch, customResList, skillsOnly, phase
	if not data or not level or not defs or not params[level] then return false; end
	local halfLevel = math.floor(level/2)
	local limit = {4, 4+level, 2+halfLevel}
	if workData[1] then
		if data['repairList'] then return data['repairList']; end
		limit = {2, 3+halfLevel, 2+math.floor(level/4)}
	end
	
	local t = {reqSkills={},reqRes={}}
	--if level == 10 and workData[2] then return t; end -- improv research at max
	local list = {}
	if type(defs) == "string" then table.insert(list, defs); else list = defs; end
	for n=1,#list do
		local def = list[n]
		-- skills
		for j=1,#params[level][def].skills do
			local param = params[level][def].skills[j]
			if type(param) ~= "number" then
				local value = params[level][def].skills[j+1]
				local div = 1
				if not workData[2] then
					local divMult = data['costDefs'][2]
					div = div*divMult
				end
				value = math.ceil(value/div)
				if not t.reqSkills[param] then t.reqSkills[param] = 0; end
				t.reqSkills[param] = math.max(t.reqSkills[param], value)
			end
		end
		-- resources
		if not workData[4] then
			local maxChoices = (n == 1 and ZombRand(limit[1],limit[2]+1)) or ZombRand(1,limit[3]+1)
			local costRef = (string.find(def, "Hard") and "hard") or "normal"
			local resTable = getResourceTable(params[level].cost[costRef], params.materials[def], maxChoices, workData[1])
			local chosenNums = LSUtil.getRandomOddNumbers(#resTable, maxChoices, nil)
			for j=1,#resTable do
				local param = resTable[j]
				if type(param) ~= "number" and ((n == 1 and j < 6) or chosenNums[j]) then
					t.reqRes[param] = getNewCosts(data, t.reqRes, param, resTable[j+1], workData[1], workData[2])
				end
			end
			if workData[2] then -- research upgrade parts
				local upgradeTable = params[level][def].upgrades
				for j=1,#upgradeTable do
					local upgrade, val = upgradeTable[j], upgradeTable[j+1]
					if type(upgrade) ~= "number" then
						if t.reqRes[upgrade] then t.reqRes[upgrade] = t.reqRes[upgrade]+val; else t.reqRes[upgrade] = val; end
					end
				end
			end
		end
	end
	if workData[4] then return t.reqSkills; end
	if workData[3] then
		for n=1,#workData[3] do
			local param = workData[3][n]
			if type(param) ~= "number" then
				t.reqRes[param] = getNewCosts(data, t.reqRes, param, workData[3][n+1], workData[1], workData[2])
			end
		end
	end
	if workData[1] then data['repairList'] = t; LSSync.transmit(obj); end -- (production cost is saved to charInvData[invName][workCost]) (research (last phase) costs added during LSIWAction)
	return t
end
--[[
local function getNewCosts(data, resList, resName, value, isRepair, isResearch)
	local div, mult = 1, data['costPenalty']/data['costDecrease']
	if not isResearch then
		div = data['standardization']
		local divMult = data['costDefs'][3]
		if isRepair then divMult = divMult*2; end
		div = div*divMult
	end
	value = math.ceil((value*mult)/div)
	if not resList[resName] then resList[resName] = 0; end
	return math.ceil(resList[resName]+value)
end

LSInv.getInventionDefinitionsMult = function(inv, level, defs, data, isRepair, isResearch, customResList)
	if not data or not level or not defs or not params[level] then return false; end
	local halfLevel = math.floor(level/2)
	local limit = {4, 4+level, 2+halfLevel}
	if isRepair then
		if data['repairList'] then return data['repairList']; end
		limit = {2, 3+halfLevel, 2+math.floor(level/4)}
	end
	
	local t = {reqSkills={},reqRes={}}
	local list = {}
	if type(defs) == "string" then table.insert(list, defs); else list = defs; end
	for n=1,#list do
		local def = list[n]
		for j=1,#params[level].skills[def] do
			local param = params[level].skills[def][j]
			if type(param) ~= "number" then
				local value = params[level].skills[def][j+1]
				local div = 1
				if not isResearch then
					local divMult = data['costDefs'][2]
					div = div*divMult
				end
				value = math.ceil(value/div)
				if not t.reqSkills[param] then t.reqSkills[param] = 0; end
				t.reqSkills[param] = math.max(t.reqSkills[param], value)
			end
		end
		local resTable = params[level].res[def]
		local maxChoices = (n == 1 and ZombRand(limit[1],limit[2]+1)) or ZombRand(1,limit[3]+1)
		local chosenNums = LSUtil.getRandomOddNumbers(#resTable, maxChoices, nil)
		for j=1,#resTable do
			local param = resTable[j]
			if type(param) ~= "number" and ((n == 1 and j < 6) or chosenNums[j]) then
				t.reqRes[param] = getNewCosts(data, t.reqRes, param, resTable[j+1], isRepair, isResearch)
			end
		end
	end
	if customResList then
		for n=1,#customResList do
			local param = customResList[n]
			if type(param) ~= "number" then
				t.reqRes[param] = getNewCosts(data, t.reqRes, param, customResList[n+1], isRepair, isResearch)
			end
		end
	end
	if isRepair then data['repairList'] = t; LSSync.transmit(inv); end -- expand to include production and research (last phase) costs
	return t
end
]]--
local function updateClientInventionDefs()
	local lsData = ModData.getOrCreate("LSDATA")
	if lsData and lsData["INVT"] then
		if lsData["INVT"].Items then
			for k, v in pairs(lsData["INVT"].Items) do
				if v and LSInventionDefs.Items[k] then
					for j, i in pairs(v) do
						LSInventionDefs.Items[k][j] = i;
					end
				end
			end
		end
		if lsData["INVT"].Improvements then
			for k, v in pairs(lsData["INVT"].Improvements) do
				if v and LSInventionDefs.Improvements[k] then
					for j, i in pairs(v) do
						LSInventionDefs.Improvements[k][j] = i;
					end
				end
			end
		end
	end	
end

local function OGSInvDefs()
	updateClientInventionDefs()
end

Events.OnGameStart.Add(OGSInvDefs)