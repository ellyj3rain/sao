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

--LSH = {}
--LSH.ItemKey = {}

local traits = {
	"Artistic","Disciplined","CouchPotato","Virtuoso","ToneDeaf","PartyAnimal","Killjoy","Sloppy","CleanFreak","Tidy",
	"disco","discono","beach","beachno","classical","classicalno","country","countryno","holiday","holidayno","jazz","jazzno","metal","metalno",
	"muzak","muzakno","pop","popno","rap","rapno","rbsoul","rbsoulno","reggae","reggaeno","rock","rockno","salsa","salsano","world","worldno",
	}

for n=1,#traits do
	CharacterTrait[string.upper(traits[n])] = CharacterTrait.register("Lifestyle:"..traits[n])
	--CharacterTrait.register("Lifestyle:"..traits[n])
end

--[[
local items = {
	{"BloodSausage","FOOD",false},
	"Artistic","Disciplined","CouchPotato","Virtuoso","ToneDeaf","PartyAnimal","Killjoy","Sloppy","CleanFreak","Tidy",
	"disco","discono","beach","beachno","classical","classicalno","country","countryno","holiday","holidayno","jazz","jazzno","metal","metalno",
	"muzak","muzakno","pop","popno","rap","rapno","rbsoul","rbsoulno","reggae","reggaeno","rock","rockno","salsa","salsano","world","worldno",
	}

for k, v in pairs(items) do
	

	CharacterTrait[string.upper(traits[n])] = CharacterTrait.register("Lifestyle:"..traits[n])
	--CharacterTrait.register("Lifestyle:"..traits[n])
end
]]--

ItemTag['LSInvention'] = ItemTag.register("Lifestyle:LSInvention")