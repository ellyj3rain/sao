CHECKS = 0
function check(ok, name)
    if not ok then error("D2_CALLBACK:" .. name) end
    CHECKS = CHECKS + 1
end
function require(name) end
SAO = {SourceIntegration={active=function() return true end}}
LSAmbtMng = {setMutualExclusive=function() end,hasActiveCompleted=function() return false end}
LSUtil = {
    weaponHasCategory=function() return true end,
    isValidMeleeWeapon=function() return true end,
    isWeaponType=function(player, weapon, kind) return kind ~= "HANDGUN" end,
    isBareHands=function() return false end,
    changeCharacterMood=function() end,
}
function instanceof(object, class) return object and object.class == class end
function isClient() return false end
function isServer() return false end
function ZombRand() return 1 end
function getGameTime() return {getGameWorldSecondsSinceLastUpdate=function() return 100 end} end
GTLSCheck=1
Perks={};CharacterStat={FOOD_SICKNESS="food",POISON="poison"}
ISWorldMap={IsAllowed=function() return false end}
WeaponType={FIREARM="firearm",HANDGUN="handgun",TWO_HANDED="two",getWeaponType=function() return "two" end}
WEAPON={getConditionLowerChance=function() return 10 end,setConditionLowerChance=function() end}
BODY={class="IsoPlayer",data={Ambitions={},LSMoodles={ElDoradoGood={Value=0},ElDoradoBad={Value=0}}},variables={}}
function BODY:hasModData() return true end
function BODY:getModData() return self.data end
function BODY:isDead() return false end
function BODY:isAsleep() return false end
function BODY:isDoShove() return false end
function BODY:isSneaking() return true end
function BODY:isAiming() return false end
function BODY:getPrimaryHandItem() return WEAPON end
function BODY:setVariable(key,value) self.variables[key]=value end
function BODY:getStats() return {get=function() return 0 end} end
function getSpecificPlayer(index) if index==0 then return BODY end end
TARGET={class="IsoZombie",health=100,isDead=function() return false end}
function TARGET:getHealth() return self.health end
function TARGET:setHealth(value) self.health=value end
LISTENER_HITS=0
function sentinel() LISTENER_HITS=LISTENER_HITS+1 end
for _,event in pairs(Events) do event.Add(sentinel) end
function registered(event) check(eventCount(event)==2,"registered_"..event) end
function retired(event,name) check(eventCount(event)==1,"retired_"..name) end
