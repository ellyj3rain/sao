CHECKS=0
function check(ok,name)if not ok then error('D2_NAMESPACE:'..name)end CHECKS=CHECKS+1 end
SAO={SourceIntegration={active=function()return true end}}
function require(name)return CATALOGUES[name] or {}end
function isServer()return false end
function isClient()return false end
function getTexture(key)return key end
function getText(key,...)if HOOK then local h=HOOK;HOOK=nil;h(key)end return key end
function getTimestampMs()return NOW or 0 end
function ZombRand(a,b)return b and a or 0 end
Perks={Music='Music'};CharacterTrait={DEAF='Deaf'};SandboxVars={LSHygiene={ColdSeverity=2},Text={DividerHygiene=true},Debug={Expressions=false}}
IsoDirections={N='N',S='S',E='E',W='W'}
LSAmbtMng={};LSUtil={};KnoxAquarium={};ISUIHandler={};ComputerScreenUI={};ComputerModUIShared={}
function getCore()return{getScreenWidth=function()return 1280 end,getScreenHeight=function()return 720 end}end
ISToolTip={new=function()return{initialise=function()end,setVisible=function()end,setName=function()end}end}
function list(items)return{size=function()return #items end,get=function(_,i)return items[i+1]end}end
function menu()
 local m={options={},children={}}
 function m:addOption(name,object,callback,...)local row={name=name,object=object,callback=callback,args={...}};self.options[#self.options+1]=row;return row end
 m.addOptionOnTop=m.addOption
 function m:getNew()local child=menu();self.children[#self.children+1]=child;return child end
 function m:addSubMenu(row,child)row.child=child end
 return m
end
ISContextMenu={getNew=function(_,parent)return parent:getNew()end}
function player(id)
 local p={id=id,data={LSMoodles={SmellGood={Value=0}}}}
 function p:hasModData()return true end;function p:getModData()return self.data end
 function p:getPerkLevel()return 10 end;function p:hasTrait()return false end
 function p:getVehicle()return nil end;function p:isSneaking()return false end
 function p:isSitOnGround()return false end;function p:hasTimedActions()return false end
 function p:isAsleep()return false end;function p:getPlayerNum()return self.id=='A' and 0 or 1 end
 return p
end
A=player('A');B=player('B')
for _,p in ipairs({A,B})do
 function p:getInventory()return{getItems=function()return list({})end}end
 function p:getHoursSurvived()return 100 end
 function p:getDescriptor()return{getForename=function()return self.id end,getSurname=function()return 'Person' end}end
end
function getSpecificPlayer(n)return n==0 and A or B end
function getPlayerInventory()return{inventoryPane={inventoryPage={backpacks={}}}}end
getPlayerLoot=getPlayerInventory
ArrayList={new=function()local a={};function a:add(x)self[#self+1]=x end;function a:size()return #self end;function a:get(n)return self[n+1]end;return a end}
SENTINELS={}
function foreign(names)for _,name in ipairs(names)do local value={name=name};SENTINELS[name]=value;_G[name]=value end end
function preserved(names)for _,name in ipairs(names)do check(_G[name]==SENTINELS[name],'foreign_owner_'..name)end end
