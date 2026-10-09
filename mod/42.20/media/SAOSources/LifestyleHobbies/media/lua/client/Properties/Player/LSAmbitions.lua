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

--LSAmbitions - please take the time to carefully read each param
--name is your ambition key, make it unique
--cat is the category your ambition will show up under - Combat, Crafting, Survival
--texture is the name of your 64x64 png image, image has to be under media/ui/Ambitions/
--leaving a goal as 0 or as " " will hide goal and unit text, it will also disable the automatic trigger on ambition completion (you'll need to set your own)
--isHidden will keep the ambition a secret until it's unlocked
--isPassive - player has to manually select ambitions (up to 3), setting isPassive as true makes the ambition always active without taking up an active slot 
--disable to remove the ambition from the menu and stop it's effects
--goals can be either a float or a string
------if string then translation line will be IGUI_LSAmbitions_YourAmbitionName_goal1, IGUI_LSAmbitions_YourAmbitionName_goal2 and so on
--goal progress is set with params goal1progress, goal2progress and so on - float is goal is float, boolean if goal is string
--resetF leave as false to reset this ambition for players who haven't completed it in case their params differ; set to true to affect all players
--Translation lines:
------IGUI_LSAmbitions_YourAmbitionName = "Your Ambition Title Name",
------IGUI_LSAmbitions_YourAmbitionName_desc = "Add a description here",
------IGUI_LSAmbitions_YourAmbitionName_unit1 = "Your number/goal unit for goal 1, only appears if goal is a float",
------IGUI_LSAmbitions_YourAmbitionName_unit2 = "Your number/goal unit for goal 2, only appears if goal is a float",
------IGUI_LSAmbitions_YourAmbitionName_unit3 = "Your number/goal unit for goal 3, only appears if goal is a float",
------IGUI_LSAmbitions_YourAmbitionName_unit4 = "Your number/goal unit for goal 4, only appears if goal is a float",
------IGUI_LSAmbitions_YourAmbitionName_unit5 = "Your number/goal unit for goal 5, only appears if goal is a float",
------IGUI_LSAmbitions_YourAmbitionName_unit6 = "Your number/goal unit for goal 6, only appears if goal is a float",
------IGUI_LSAmbitions_YourAmbitionName_footer = "Footer text, for a disclaimer or notice - leaving it as a single blank space will hide the footer.",
------IGUI_LSAmbitions_YourAmbitionName_req = "Traits or conditions required to unlock this ambition.",
------IGUI_LSAmbitions_YourAmbitionName_reqNot = "Traits or conditions blocking this ambition.",
------IGUI_LSAmbitions_YourAmbitionName_give = "What the player gets from fulfilling this ambition",
------
------e.g. {name="LSTerminator",cat="Combat",texture="LSTerminator",goal1=5000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,disable=false},
------IGUI_LSAmbitions_LSTerminator = "Terminator",
------IGUI_LSAmbitions_LSTerminator_desc = "A Terminator has eliminated at least 5000 zombies, proving themselves as the ultimate killing machine. Their vast experience in combat allows them to dispatch foes with unmatched efficiency, dealing more damage and taking less in return.",
------IGUI_LSAmbitions_LSTerminator_unit1 = "Kills",
------IGUI_LSAmbitions_LSTerminator_footer = "Does not count previous kills.",

return {
	{name="LSBladeMaster",cat="Combat",texture="LSBladeMaster",goal1=40000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSTerminator",cat="Combat",texture="LSTerminator",goal1=5000,goal2="pain",goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSMasterPainter",cat="Creativity",texture="LSMasterPainter",goal1=9,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=true,disable=false,resetF=false},
	{name="LSJuryRigger",cat="Handiness",texture="LSJuryRigger",goal1=1000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true},
	{name="LSBrushmaster",cat="Creativity",texture="LSBrushmaster",goal1=30,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSGrimeFighter",cat="Handiness",texture="LSGrimeFighter",goal1=3000,goal2=300,goal3=150,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true,reqNotHas=true},
	{name="LSElDorado",cat="Collectibles",texture="LSElDorado",goal1=2,goal2=200,goal3=300,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSCommando",cat="Combat",texture="LSCommando",goal1=6000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true,reqNotHas=true},
	{name="LSTheProfessional",cat="Combat",texture="LSTheProfessional",goal1=6000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true,reqNotHas=true},
	{name="LSLordDeath",cat="Combat",texture="LSLordDeath",goal1=10000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true},
	{name="LSUnstoppable",cat="Survival",texture="LSUnstoppable",goal1=1000,goal2=200,goal3=100,goal4=50,goal5=25,goal6=10,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSGoodEating",cat="Survival",texture="LSGoodEating",goal1=100,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true},
	{name="LSRockstar",cat="Creativity",texture="LSRockstar",goal1=10,goal2=20,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true,reqNotHas=true},
	{name="LSExplorer",cat="Survival",texture="LSExplorer",goal1=400,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSWanderer",cat="Athletic",texture="LSWanderer",goal1=1000000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false},
	{name="LSLumberjack",cat="Survival",texture="LSLumberjack",goal1=500,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true},
	{name="LSKnockdown",cat="Combat",texture="LSKnockdown",goal1=4000,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true},
	{name="LSPlushies",cat="Collectibles",texture="LSPlushies",goal1=1,goal2=2,goal3=2,goal4=2,goal5=2,goal6=0,isHidden=false,isPassive=false,disable=false,resetF=false,reqHas=false},
	{name="LSDietOfGods",cat="Survival",texture="LSDietOfGods",goal1=100,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=false,disable=false,resetF=false,reqHas=true},
}
