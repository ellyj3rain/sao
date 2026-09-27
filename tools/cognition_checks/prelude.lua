hours=2
records={a={id="a"},b={id="b"},c={id="c"}}
stores={}
ModData={get=function(key)return stores[key]end,getOrCreate=function(key)stores[key]=stores[key] or {};return stores[key]end}
Events=setmetatable({}, {__index=function(t,k)local v={Add=function()end,Remove=function()end};rawset(t,k,v);return v end})
SAO={Log={line=function()end},History={countyHours=function()return hours end},
 Identity={get=function(id)return records[id]end,all=function()return records end},
 Census={skillOf=function(id,perk)return perk=="Cooking" and 2 or 0 end}}
