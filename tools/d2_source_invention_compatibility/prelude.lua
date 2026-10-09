CHECKS=0
function check(ok,name) if not ok then error('D2_INVENTION:'..name) end CHECKS=CHECKS+1 end
OBJECTS={}
function require(name) if name=='Properties/Objects/List' then return OBJECTS end end
SAO={SourceIntegration={active=function() return true end}}
SERVER=false;CLIENT=false
function isServer() return SERVER end
function isClient() return CLIENT end
function getActivatedMods() return {contains=function() return false end} end
function instanceof(o,kind) return o and o.kind==kind end
function ZombRand() return 0 end
function getGameTime() return {getWorldAgeHours=function() return 12 end} end
function getText(key,...) return key end
function getTexture(key) return key end
ISToolTip={new=function() return {initialise=function() end,setVisible=function() end} end}
Perks={Strength='Strength',Nimble='Nimble'}
ItemBodyLocation={HAT='Hat'}
SYNC={items=0,objects=0,commands={}}
LSSync={isServerOnly=function() return SERVER and not CLIENT end,isClientOnly=function() return CLIENT and not SERVER end,isNotServer=function() return not SERVER end,
 syncItemVal=function(item,data,kind) SYNC.items=SYNC.items+1;SYNC.item=item;SYNC.data=data;SYNC.kind=kind end,
 transmit=function(object) SYNC.objects=SYNC.objects+1;SYNC.object=object end}
function sendClientCommand(...) SYNC.commands[#SYNC.commands+1]={...} end
function newEmitter()
 local e={sounds={},pitches={},stops=0}
 function e:playSound(name,proxy) self.sounds[#self.sounds+1]={name,proxy};return #self.sounds end
 function e:playSoundImpl(name,transmit,proxy) return self:playSound(name,proxy) end
 function e:setPitch(handle,value) self.pitches[handle]=value end
 function e:isPlaying(handle) return self.sounds[handle]~=nil end
 function e:stopSound(handle) self.stops=self.stops+1 end
 return e
end
EMITTER=newEmitter();FOREIGN_EMITTER=newEmitter();WORLD_EMITTER=newEmitter()
BODY={kind='IsoPlayer',worn=true,busy=false,resets=0}
function BODY:getEmitter() return EMITTER end
function BODY:isEquippedClothing(item) return self.worn and item==ITEM end
function BODY:isEquipped(item) return self:isEquippedClothing(item) end
function BODY:isHandItem(item) return false end
function BODY:isDead() return false end
function BODY:getVehicle() return nil end
function BODY:isSneaking() return false end
function BODY:hasTimedActions() return self.busy end
function BODY:isAsleep() return false end
function BODY:isTimedActionInstant() return false end
function BODY:resetModel() self.resets=self.resets+1 end
function BODY:setIsFarming(value) self.farming=value end
HAT_DATA={movableData={inventionData={fuelUses=8,fuelContainer={10},overdrive={3},running=true,isBroken=false}}}
ITEM={kind='InventoryItem',synced=0}
function ITEM:getModData() return HAT_DATA end
function ITEM:getVisual() return NATIVE_VISUAL end
function ITEM:getType() return 'NeuralHat' end
function ITEM:getID() return 731 end
function ITEM:isBroken() return false end
function ITEM:synchWithVisual() self.synced=self.synced+1 end
function ITEM:getFullType() return 'Lifestyle.NeuralHat' end
FOREIGN={kind='IsoPlayer',getEmitter=function() return FOREIGN_EMITTER end,isEquippedClothing=function() return false end}
QUEUE={actions={},completed=0,resets=0}
function QUEUE:onCompleted(action) self.completed=self.completed+1;self.last=action end
function QUEUE:resetQueue() self.resets=self.resets+1 end
ISTimedActionQueue={add=function(action) QUEUE.actions[#QUEUE.actions+1]=action end,getTimedActionQueue=function() return QUEUE end}
ISLogSystem={logAction=function() end}
function menu()
 local m={options={},submenus={}}
 function m:addOption(name,item,callback,...) local o={name=name,item=item,callback=callback,args={...}};self.options[#self.options+1]=o;return o end
 function m:getNew() local child=menu();self.submenus[#self.submenus+1]=child;return child end
 function m:addSubMenu(option,child) option.child=child end
 return m
end
TEMPERATURE=20
function getClimateManager() return {getAirTemperatureForSquare=function() return TEMPERATURE end} end
function getWorld() return {getFreeEmitter=function() return WORLD_EMITTER end} end
REMOVALS={transmit=0,remove=0,puddle=0}
SQUARE={}
function SQUARE:getObjects() return {size=function() return #OBJECTS end,get=function(_,i) return OBJECTS[i+1] end} end
function SQUARE:transmitRemoveItemFromSquare(object) REMOVALS.transmit=REMOVALS.transmit+1;REMOVALS.transmitted=object end
function SQUARE:RemoveTileObject(object)
 REMOVALS.remove=REMOVALS.remove+1;REMOVALS.removed=object
 for i,v in ipairs(OBJECTS) do if v==object then table.remove(OBJECTS,i);return end end
end
ICE={kind='IsoObject',customName='Sculpture Ice'}
function ICE:getSquare() return SQUARE end
function ICE:getModData() return NATIVE_ICE_DATA end
function ICE:getX() return 10 end
function ICE:getY() return 10 end
function ICE:getZ() return 0 end
function ICE:getSprite() return {getName=function() return 'LS_Sculpture_0' end,getProperties=function() return {
 has=function(_,key) return key=='CustomName' end,get=function(_,key) return ICE.customName end} end} end
function BODY:getX() return 10 end
function BODY:getY() return 10 end
LSHygiene={TF={doDirtPuddle=function(object) REMOVALS.puddle=REMOVALS.puddle+1;REMOVALS.puddleObject=object end}}
