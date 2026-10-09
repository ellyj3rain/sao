-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
require 'KA_Core'
local K=KnoxAquarium
local function copy(value,depth)
    if type(value)~='table' then
        if type(value)=='string' or type(value)=='number' or type(value)=='boolean' then return value end
        return nil
    end
    if depth>8 then return nil end
    local result={}
    for key,v in pairs(value) do if type(key)=='string' or type(key)=='number' then result[key]=copy(v,depth+1) end end
    return result
end
function K.captureFish(item,d)
    d.nextFishId=(d.nextFishId or 0)+1
    return {id='fish:'..d.nextFishId,type=item:getFullType(),name=item:getName(),length=item:getModData().fishing_FishSize,
        snapshot={metadata=copy(item:getModData(),0),age=item:getAge(),weight=item:getActualWeight(),
        calories=item:getCalories(),lipids=item:getLipids(),carbs=item:getCarbohydrates(),proteins=item:getProteins(),
        hunger=item:getHungChange(),baseHunger=item:getBaseHunger(),condition=item:getCondition(),favorite=item:isFavorite()}}
end
function K.restoreFish(record,player)
    if not record.snapshot then return nil,'This prototype fish has no original item data. It can be individually discarded.' end
    local item=instanceItem(record.type)
    if not item then return nil,'The original fish item definition is unavailable.' end
    local s=record.snapshot
    item:copyModData(copy(s.metadata or {},0));item:setName(record.name)
    item:setAge(s.age);item:setActualWeight(s.weight);item:setCustomWeight(true)
    item:setCalories(s.calories);item:setLipids(s.lipids);item:setCarbohydrates(s.carbs);item:setProteins(s.proteins)
    item:setBaseHunger(s.baseHunger);item:setHungChange(s.hunger);item:setCondition(s.condition);item:setFavorite(s.favorite)
    item:setWorldScale(record.length/100)
    local now=K.now()
    item:getModData().fishing_FishSize=record.length
    item:getModData().KnoxAquariumFish={caught=now,expires=K.deadline(now,player:getPerkLevel(Perks.Fishing))}
    return item
end
