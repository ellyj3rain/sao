CHECKS=0
function check(ok,name) if not ok then error('D2_TEMP:'..name)end CHECKS=CHECKS+1 end
SAO={SourceIntegration={active=function()return true end}}
function require(name) return CATALOGUES[name] end
function isServer()return MODE=='server' end
function isClient()return false end
function getTexture(key)return key end
CharacterTrait={DEAF='Deaf',VIRTUOSO='Virtuoso',TONEDEAF='ToneDeaf',HARD_OF_HEARING='HardOfHearing',PARTYANIMAL='PartyAnimal'}
Perks={Music='Music'};Metabolics={Fitness='Fitness'}
SandboxVars={ElecShutModifier=-1,Debug={DanceAnim=false}}
LSUtil={hasAdminRights=function()return false end,debugPrint=function()end}
LSAmbtMng={hasCompleted=function()return false end}
luautils={stringEnds=function(s,p)return string.sub(s,-#p)==p end,stringStarts=function(s,p)return string.sub(s,1,#p)==p end}
ISToolTip={new=function()return {initialise=function()end,setVisible=function()end}end}
LSNoteMng={addToQueue=function()end}
function getCore()return {getScreenWidth=function()return 1280 end,getScreenHeight=function()return 720 end}end
function ZombRand(n)return 0 end
GTLSCheck=1
function getGameTime()return {getGameWorldSecondsSinceLastUpdate=function()return 0 end}end
HOOK=nil
function getText(key,...) if HOOK then local run=HOOK;HOOK=nil;run(key)end return key end
function list(items)return {size=function()return #items end,get=function(_,i)return items[i+1]end}end
function menu()
 local m={options={},children={}}
 function m:addOption(name,object,callback,...) local row={name=name,object=object,callback=callback,args={...}};self.options[#self.options+1]=row;return row end
 m.addOptionOnTop=m.addOption
 function m:getNew()local child=menu();self.children[#self.children+1]=child;return child end
 function m:addSubMenu(row,child)row.child=child end
 return m
end
ISContextMenu={getNew=function(_,parent)return parent:getNew()end}
function findOption(m,name)
 for _,row in ipairs(m.options)do if row.name==name then return row end;if row.child then local found=findOption(row.child,name);if found then return found end end end
end
QUEUED={};QUEUE={completed=0}
function QUEUE:onCompleted(action)self.completed=self.completed+1 end
function QUEUE:resetQueue()end
ISTimedActionQueue={add=function(action)QUEUED[#QUEUED+1]=action end,getTimedActionQueue=function()return QUEUE end}
ISLogSystem={logAction=function()end}
-- Controlled native-action constructor sink: original onAction reaches this exact signature.
PlayInstrumentActionNew={new=function(_,body,item,kind,sound,length,level,training,duet)return {body=body,item=item,kind=kind,sound=sound,length=length,level=level}end}
PlayInstrumentTraining={new=function(_,body,item,kind)return {body=body,item=item,kind=kind,training=true}end}
CATALOGUES['TimedActions/PlayDJBoothAction']={new=function(_,...)return {args={...}}end}
function player(id)
 local p={id=id,data={PlayerVoice=0,LSMoodles={Embarrassed={Value=0}}},metabolic={},queries={},primary={id=id..':P'},secondary={id=id..':S'}}
 function p:getVehicle()return nil end;function p:isSneaking()return false end;function p:isSitOnGround()return false end
 function p:hasTrait()return false end;function p:hasModData()return true end;function p:getModData()return self.data end
 function p:getPerkLevel()return 10 end;function p:isTimedActionInstant()return false end;function p:isDead()return false end
 function p:setMetabolicTarget(value)self.metabolic[#self.metabolic+1]=value end
 function p:getPrimaryHandItem()return self.primary end;function p:getSecondaryHandItem()return self.secondary end
 function p:isItemInBothHands(item)self.queries[#self.queries+1]={item=item};return item~=nil and item==self.primary and item==self.secondary end
 function p:setPrimaryHandItem(item)self.primary=item end;function p:setSecondaryHandItem(item)self.secondary=item end
 function p:setVariable(name,value)self.data[name]=value end;function p:setIsFarming(value)self.data.farming=value end
 function p:getInventory()return {getItems=function()return list({})end,contains=function(_,item)return item.owner==self.id end}end
 function p:getX()return 10 end;function p:getY()return 10 end;function p:getZ()return 0 end
 function p:isEquippedClothing(item)return true end
 return p
end
A=player('A');B=player('B');PLAYERS={A,B}
function getSpecificPlayer(id)return PLAYERS[id+1]end
function item(kind)return {getFullType=function()return kind end,getType=function()return string.match(kind,'[^.]+$')end,isEquipped=function()return true end,isBroken=function()return false end,isInPlayerInventory=function()return true end,getAttachedSlot=function()return -1 end}end
function pick(catalogue,offset)
 local rows={};for _,row in ipairs(catalogue)do if row.isaddon~=2 and row.level>=2 and row.level<=10 then rows[#rows+1]=row end end
 check(#rows>=offset+2,'original_catalogue_sufficient');return {rows[offset+1],rows[offset+2]}
end
SCENES={};SERVER_REMOVED={};CELL_READS=0
function object(name,x,sprite)
 local o={name=name,x=x,data={movableData={artBeauty=1}}}
 function o:getSprite()return {getName=function()return sprite end,getProperties=function()return {has=function(_,key)return key=='CustomName' end,get=function()return name end}end}end
 function o:getModData()return self.data end;function o:getX()return self.x end;function o:getY()return 10 end;function o:getZ()return 0 end
 function o:getCell()CELL_READS=CELL_READS+1;return {} end
 return o
end
function square(objects)
 local s={objects=objects}
 function s:getObjects()return list(self.objects)end
 function s:transmitRemoveItemFromSquare(obj)self.transmitted=obj end
 function s:RemoveTileObject(obj)SERVER_REMOVED[#SERVER_REMOVED+1]=obj end
 function s:haveElectricity()return true end
 return s
end
function getCell()return {getGridSquare=function(_,x,y,z)return SCENES[x..':'..y..':'..z]end}end
function sendServerCommand(...)end
