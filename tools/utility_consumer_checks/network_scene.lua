if __utilityCase=="review-corrections"or __utilityCase=="recipe-mutation"then
__scene=__setupUtilityPersonScene();body=__scene.body
local generator=newGenerator(10,20,0);generator:getSquare():getProperties():set(IsoFlagType.exterior);__ordinaryInitialPower(generator)
local donor=__newTaintedProvider(15,22,0,4)
local header=newProvider(12,22,1,0,0);header:getModData().SAOHouseholdHeader=true
local saved=ModData.getOrCreate("LGExtendedPlumbing");saved.floors={};saved.walls={}
__reviewInputs=__reviewInitialInputs()
raise("OnInitGlobalModData",false)
for _,object in pairs({generator,donor,header})do raise("LoadGridsquare",object:getSquare())end
__scene.generator,__scene.pump,__scene.header=generator,donor,header
return end
__scene=__setupUtilityPersonScene();body=__scene.body
local fuel=newProvider(13,20,1,0,7);fuel:getModData().SAOHouseholdSource=true
local generator=newGenerator(10,20,0);generator:getSquare():getProperties():set(IsoFlagType.exterior)
__ordinaryInitialPower(generator)
local pump=__newTaintedProvider(10,21,0,4);pump:getModData().SAOHouseholdSource=false
local header=newProvider(10,20,1,0,0);header:getModData().SAOHouseholdSource=false
-- Actual existing saved infrastructure input, read through native GlobalModData.
local saved=ModData.getOrCreate("LGExtendedPlumbing")
saved.floors={}
saved.walls={}
local fixture=newProvider(10,20,0,0,0);__utilityInitialSprite(fixture,"fixtures_sinks_01_0");fixture:getSprite():getProperties():set(IsoFlagType.waterPiped);fixture:setUsesExternalWaterSource(true)
__ordinaryInitialStairs();__ordinaryInitialMountingWall()
raise("OnInitGlobalModData",false)
for _,object in pairs({fuel,generator,pump,header,fixture})do raise("LoadGridsquare",object:getSquare())end
__scene.fuel,__scene.generator,__scene.pump,__scene.fixture,__scene.header=fuel,generator,pump,fixture,header
__scene.initialThirst=body:getStats():get(CharacterStat.THIRST)
