-- Original pamphlets join ordinary native book pools. Discovery and carrying
-- retain WorldSources/SourceUse; distribution grants no person knowledge.
require "Items/ProceduralDistributions"
require "SAO_StudySources"
SAO=SAO or {}
SAO.LiteratureLoot=SAO.LiteratureLoot or {}
local Loot=SAO.LiteratureLoot
Loot.rules={{items={"BuildingsRoutesUpkeep_Civilian","BuildingsRoutesUpkeep_Engineering",
    "BuildingsRoutesUpkeep_Military"},weight=.5,pools={"BookstoreBooks","LibraryBooks"}}}
function Loot.install()
    local list=ProceduralDistributions and ProceduralDistributions.list
    if type(list)~="table" then return false end
    for _,rule in ipairs(Loot.rules) do for _,name in ipairs(rule.pools) do
        local pool=list[name]
        if type(pool)=="table" and type(pool.items)=="table" then
            for _,item in ipairs(rule.items) do
                local full="SAO."..item;local present=false
                for index=1,#pool.items,2 do if pool.items[index]==full then present=true;break end end
                if not present then pool.items[#pool.items+1]=full;pool.items[#pool.items+1]=rule.weight end
            end
        end
    end end
    return true
end
Loot.install()
return Loot
