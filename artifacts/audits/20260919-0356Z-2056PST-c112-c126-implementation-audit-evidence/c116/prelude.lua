function noop() end
Events={OnPlayerDeath={Remove=noop,Add=noop},OnTick={Remove=noop,Add=noop}}
records={loaded={id="loaded",x=10,y=10,z=0,dead=true,forename="A",surname="B"},dormant={id="dormant",x=100,y=100,z=0,dead=true,forename="C",surname="D"}}
SAO={Log={line=noop},Perception={},History={countyHours=function() return 24 end},Disposition={describe=function() return "known" end},Identity={get=function(id) return records[id] end,femaleOf=function() return false end,updatePosition=function(r,x,y,z)r.x=x;r.y=y;r.z=z end}}
function makeBody(x,y,z) local data={};return {getX=function() return x end,getY=function() return y end,getZ=function() return z end,getModData=function()return data end,setNpc=noop,isNpc=function()return true end,dressInRandomOutfit=noop,resetModelNextFrame=noop} end
SAOJavaBridge={spawnShellNamed=function(self,f,s,x,y,z) return makeBody(x,y,z) end,ensureDressed=function()return "OK" end}
ZAO={Controller={controlled={loaded=makeBody(10,10,0)}},StateStore={read=function(id)return {terminalState="afflicted",currentForm="ghoul",formPerformance=0.4} end}}
