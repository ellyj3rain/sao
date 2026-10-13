__scene=__setupUtilityPersonScene();body=__scene.body
local fuel=newProvider(13,20,1,0,7);fuel:getModData().SAOHouseholdSource=true
local generator=newGenerator(10,20,0);generator:getSquare():getProperties():set(IsoFlagType.exterior)
local pump=__newTaintedProvider(11,20,0,4);pump:getModData().SAOHouseholdSource=true
local header=newProvider(10,20,1,0,0);header:getModData().SAOHouseholdSource=true
-- Actual existing saved infrastructure input, read through native GlobalModData.
local saved=ModData.getOrCreate("LGExtendedPlumbing")
saved.floors={{x=10,y=20,z=0},{x=11,y=20,z=0},{x=10,y=20,z=1},{x=11,y=20,z=1},{x=12,y=20,z=1},{x=13,y=20,z=1}}
saved.walls={{x=10,y=20,z=0,north=true}}
local fixture=newProvider(10,20,0,0,0);__utilityInitialSprite(fixture,"fixtures_sinks_01_0");fixture:getSprite():getProperties():set(IsoFlagType.waterPiped);fixture:setUsesExternalWaterSource(true)
raise("OnInitGlobalModData",false)
for _,object in pairs({fuel,generator,pump,header,fixture})do raise("LoadGridsquare",object:getSquare())end
__scene.fuel,__scene.generator,__scene.pump,__scene.fixture,__scene.header=fuel,generator,pump,fixture,header
__scene.initialThirst=body:getStats():get(CharacterStat.THIRST)
