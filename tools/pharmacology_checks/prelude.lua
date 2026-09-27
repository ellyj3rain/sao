print=__nativePrint
instanceof=__nativeInstanceof
moduleDotType=__nativeModuleDotType
ArrayList=__nativeArrays
ItemTag=__nativeItemTag
CharacterStat=__nativeCharacterStat
CharacterTrait=__nativeCharacterTrait
BodyPartType=__nativeBodyPartType
ResourceLocation=__nativeResourceLocation
MoodleType=__nativeMoodleType
SAOJavaBridge=__realBridge
CharacterActionAnims={Eat="Eat",Drink="Drink",TakePills="TakePills"}
function isServer() return false end
function isClient() return false end
function isDebugEnabled() return false end
function getPlayerInventory() return nil end
CCampfireSystem={instance={getLuaObjectOnSquare=function()return nil end}}
luautils={stringStarts=function(v,p)return type(v)=="string" and string.sub(v,1,#p)==p end}
function ISBaseTimedAction:stop() end
hours=0; records={}
SAO.History={countyHours=function()return hours end,ageOf=function()return 30 end}
SAO.Identity={get=function(id)return records[tostring(id)] end,all=function()return records end}
SAO.Log={line=function()end}
SAO.Body={active={},foreign={},isTransitioning=function(rec)return rec.transitioning==true end}
function SAO.Body.get(id)return SAO.Body.active[id] or SAO.Body.foreign[id]end
SAO.Rand={int=function(a,b)return b and a or 0 end}
SAO.Controller={tick=function()return math.floor(hours*3600) end}
Events={OnTick={Add=function(fn) drugTick=fn end},
    OnGameStart={Add=function(fn) resetDrugWorld=fn end},
    OnLoad={Add=function(fn) reloadDrugWorld=fn end}}
ISTimedActionQueue={add=function(action) queued=action end,hasAction=function(action)return queued==action end}
function getGameTime()return {getMinutesStamp=function()return hours*60 end} end
-- A disabled-by-default fixture hook runs only after the installed method
-- consumes real native fluid. It lets ownership/error controls change the
-- boundary between that native effect and SAO's post-effect attribution.
local nativeFluidUpdate=ISDrinkFluidAction.updateEat
function ISDrinkFluidAction:updateEat(...)
    local result=nativeFluidUpdate(self,...)
    if __afterNativeFluidUpdate then __afterNativeFluidUpdate(self) end
    return result
end
