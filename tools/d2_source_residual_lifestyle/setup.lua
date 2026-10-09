ISPanel=ISBaseObject:derive('ControlledPanelHost');ISPanelJoypad=ISPanel:derive('ControlledJoypadHost')
function ISPanel:new(x,y,w,h)local o={x=x,y=y,width=w,height=h};setmetatable(o,self);self.__index=self;return o end
function ISPanel:setX(x)self.x=x end
function ISPanel:setY(y)self.y=y end
function ISPanel:noBackground()end
function ISPanel:removeFromUIManager()self.removed=true end
function ISPanel:setVisible(v)self.visible=v end
function ISPanel:initialise()end
function ISPanel:getWidth()return self.width end
function ISPanel:getHeight()return self.height end
function ISPanel:addChild()end
function ISPanel:insertNewLineOfButtons()end
ISLabel=ISPanel:derive('Label');ISButton=ISPanel:derive('Button');ISToolTip=ISPanel:derive('Tooltip')
function ISPanel:instantiate()end
function actor(id)
 local a={id=id,data={LSJukeboxCustomPlaylist={{name=id,songs={id}}}},inv=nativeContainer(),primary=nil,traits=nativeTraits()}
 function a:getModData()return self.data end;function a:hasModData()return true end
 function a:getInventory()return self.inv end;function a:getX()return 0 end;function a:getY()return 0 end;function a:getZ()return 0 end
 function a:getPlayerNum()return self.id=='A' and 0 or 1 end;function a:getVehicle()return nil end;function a:isSneaking()return false end
 function a:hasTrait(t)return self.traits:get(t)end;function a:getCharacterTraits()return self.traits end
 function a:getPerkLevel()return 5 end;function a:getPrimaryHandItem()return self.primary end;function a:getSecondaryHandItem()return nil end
 function a:modifyTraitXPBoost(t,remove)self.xpArg=t;self.xpValue=nativeTraitXP(t,remove)end
 function a:setIsFarming(v)self.farming=v end
function a:getStats()return self.stats end;function a:getBodyDamage()return self.body end
 return a
end
A=actor('A');B=actor('B');PLAYERS={[0]=A,[1]=B}
function getSpecificPlayer(i)return PLAYERS[i]end
function getPlayer()return A end
function list(rows)return{size=function()return #rows end,get=function(_,i)return rows[i+1]end}end
function context()
 local c={options={},subs={}}
 function c:addOption(label,target,callback,...)local o={label=label,target=target,callback=callback,args={...}};self.options[#self.options+1]=o;return o end
 c.addOptionOnTop=c.addOption
 function c:addSubMenu(o,sub)self.subs[#self.subs+1]=sub end
 function c:getNew()return context()end
 return c
end
ISContextMenu={getNew=function()return context()end}
ISTimedActionQueue={add=function(action)QUEUED[#QUEUED+1]=action end,clear=function()end};QUEUED={}
PlayInstrumentTraining={new=function(_,p,item,t)return{actor=p,item=item,kind=t,training=true}end}
PlayInstrumentActionNew={new=function(_,p,item,t)return{actor=p,item=item,kind=t}end}
ISEquipWeaponAction={new=function(_,p,item)return{actor=p,item=item,equip=true}end}
CATALOGUES['TimedActions/PlayHarmonicaTracks']={{name='one',level=1,isaddon=0,length=2,sound='one'},{name='two',level=2,isaddon=0,length=2,sound='two'}}
CATALOGUES['TimedActions/PlayGuitarAcousticTracks']=CATALOGUES['TimedActions/PlayHarmonicaTracks']
CATALOGUES['TimedActions/PlayGuitarAcousticTracksDuet']={}
if MODE=='read' then
 function A:isTimedActionInstant()return false end;function A:hasTrait()return false end;function A:isSittingOnFurniture()return false end;function A:isSitOnGround()return false end;function A:isSitting()return false end
 function A:getWornItems()return{getItem=function()return HAT end}end
 function A:getItemVisuals()return{}end
 EyesReading={getReadingGlasses=function()return false end}
end

function ISTimedActionQueue.getTimedActionQueue()return{resetQueue=function()STOPPED=(STOPPED or 0)+1 end}end

LSAmbtMng={hasCompleted=function()return false end}

MakeUpDefinitions={makeup={},tattoo={}}

LS_AMcache={tattoo=true}

function ISLabel:new(x,y,h,label)local o=ISPanel.new(self,x,y,100,h);o.label=label;return o end
