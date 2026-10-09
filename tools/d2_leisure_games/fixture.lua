-- Augments the shared controlled body/object receiver used in source art proof.
UIFont={Small='Small',Medium='Medium',Large='Large'}
Keyboard={KEY_LSHIFT=0}
getTexture=function(name)return {getName=function()return name end}end
__rngState=173
ZombRand=function(a,b)
    __rng=__rng+1;__rngState=(__rngState*48271)%2147483647
    if b then return a+__rngState%(b-a)end;return __rngState%a
end
ZombRandFloat=function(a,b)__rng=__rng+1;__rngState=(__rngState*48271)%2147483647;return a+(b-a)*(__rngState/2147483647)end
function seed(n)__rng=0;__rngState=n end
getActivatedMods=function()return {contains=function(_,m)return m=='LifestyleHobbies'or m=='ComputerModkum'or m=='ProjectArcade'end}end
Perks.Fitness='Fitness';Perks.Nimble='Nimble'
IsoDirections={N='N',S='S',E='E',W='W'}
ComputerModSandbox={getNumber=function(_,default)return default end,getBool=function(_,default)return default end}
getGameTime=function()return {getGameWorldSecondsSinceLastUpdate=function()return .3 end,getWorldAgeHours=function()return __hours end,getTrueMultiplier=function()return 1 end}end
getTimestampMs=function()return __hours*3600000 end
getText=function(key)return key end
getScriptManager=function()return {getItem=function(_,fullType)
    if fullType=='Base.SilverCoin' or fullType=='Base.Battery' then
        return {getFullName=function()return fullType end}
    end
end}end
HaloTextHelper={addTextWithArrow=function()end}
Events.OnGameStart={Add=function()end};Events.OnServerCommand={Add=function()end}
IsoSpriteManager={instance={getSprite=function(_,name)return sprite(name,{})end}}
addSound=function(body,x,y,z,radius,volume)body.lastWorldSound={x=x,y=y,z=z,radius=radius,volume=volume}end
SAO.ProceduralPlanning.hobbyAdmission=function(id,purposeId,workId)
    local w=SAO.LeisureGames and SAO.LeisureGames.work(id)
    if not w or w.purposeId~=purposeId or w.workId~=workId or __records[id].purposeRetired then return nil end
    w.ownerName='SAO.LeisureGames';return w
end
ComputerModPower={hasComputerPower=function(obj)return obj.power~=false end}
local artFixture=fixture
__objects={}
function gameFixture(id,gameId,ping)
    local b,o=artFixture(id,nil,4)
    __objects={};__objects['object:10:10:0:0:computer']=o
    local p={CustomName='Computer'}
    o.sprite=sprite('appliances_com_01_72',p)
    o.power=true;o.data={ComputerModMetaInitialized=true,ComputerModPowerOn=true,ComputerModOSInstalled=true,
        ComputerModMachineID='machine:'..id,ComputerModInstalledGames={gameId},ComputerModComponentsInitialized=true,
        ComputerModComponentsLastWearHour=__hours,ComputerModComponents={}}
    for _,name in ipairs({'motherboard','cpu','ram','gpu','hardDrive'})do o.data.ComputerModComponents[name]={condition=100}end
    b.observations[1].key='object:10:10:0:0:computer';b.observations[1].concept='computer';b.observations[1].spriteName=o.sprite:getName()
    function b:getX()return self.current.x end;function b:getY()return self.current.y end;function b:getSquare()return self.current end
    function b:nullifyAiming()end;function b:setX()end;function b:setY()end
    function b:faceLocation()end;function b:faceLocationF()end;function b:pressedMovement()return false end
    function b:setBlockMovement(v)self.blocked=v end
    function b:Say(t)self.speech=t end
    b.emitter.setVolume=function()end;b.emitter.setPitch=function()end
    if ping then
        o.sprite=sprite('LS_Recreation_0',{CustomName='Table',GroupName='Ping Pong'});o.data={movableData={fakeRival=true,inUse=false}}
        local other={square=square(11,10),data={movableData={fakeRival=true,inUse=false}},sprite=sprite('LS_Recreation_1',{CustomName='Table',GroupName='Ping Pong'})}
        for _,name in ipairs({'getModData','getSprite','getSquare','getZ'})do other[name]=o[name]end
        other.getX=function()return 11 end;other.getY=function()return 10 end
        o.square.getAdjacentSquare=function(_,direction)return direction=='E'and other.square or b.current end
        other.square.getAdjacentSquare=function()return b.current end
        other.square.objects={other}
        b.observations[1].key='object:10:10:0:0:ping-pong';b.observations[1].concept='ping-pong';b.observations[1].spriteName=o.sprite:getName()
        b.observations[2]={actorId=id,kind='object',source='native-personal-visibility',concept='ping-pong',at=__tick,
            x=11,y=10,z=0,objectIndex=0,key='object:11:10:0:0:ping-pong',spriteName=other.sprite:getName(),runtimeInstance='native-other:'..id}
        __objects={[b.observations[1].key]=o,[b.observations[2].key]=other}
        return b,o,other
    end
    return b,o
end
SAO.Perception.resolveLeisureObject=function(id,b,key)
    for _,row in ipairs(b.observations)do
        local obj=__objects[key]
        if row.key==key and obj and row.spriteName==obj.sprite:getName()and obj.square.objects[1]==obj
            and (row.runtimeInstance=='native-instance:'..id or row.runtimeInstance=='native-other:'..id)then return obj end
    end
end
function native(action,delta)
    action.delta=delta
    action.action={getJobDelta=function()return action.delta end,setActionAnim=function()end,setOverrideHandModelsObject=function()end,
        setUseProgressBar=function()end,forceStop=function()action:forceCancel()end,
        forceComplete=function()action.delta=1;action:perform();action:complete()end}
    action:start()
end
function arcadeFixture(id,name,count)
    local body,obj=gameFixture(id,'pong')
    local sp=name or 'pa_arcades_0';obj.sprite=sprite(sp,{CustomName='Arcade'})
    obj.data={};obj.square.haveElectricity=function()return obj.power~=false end
    for _,direction in ipairs({'S','E','N','W'})do obj.square['get'..direction]=function()return body.current end end
    obj.square.RecalcProperties=function()end
    obj.hasAttachedAnimSprites=function(self)return self.attached~=nil end
    obj.getChildSprites=function(self)return self.children and list(self.children)or nil end
    obj.setChildSprites=function(self,value)self.children=value end
    obj.transmitUpdatedSprite=function()end
    obj.getAttachedAnimSprite=function(self)return self.attached end
    obj.setAttachedAnimSprite=function(self,value)self.attached=value end
    obj.addAttachedAnimSprite=function(self,value)self.attached=value end
    obj.transmitModData=function()end
    body.observations[1].key='object:10:10:0:0:arcade-machine';body.observations[1].concept='arcade-machine';body.observations[1].spriteName=sp
    __objects={[body.observations[1].key]=obj}
    body.items={};for i=1,count or 2 do
        local coin=item('Base.SilverCoin',100+i);coin.getFullType=function()return 'Base.SilverCoin'end;body.items[i]=coin
    end
    local inv={getItems=function()return list(body.items)end,
        getCountTypeRecurse=function(_,type)local n=0;for _,v in ipairs(body.items)do if v:getFullType()==type then n=n+1 end end;return n end,
        Remove=function(_,value)for i,v in ipairs(body.items)do if v==value then table.remove(body.items,i);break end end end}
    body.getInventory=function()return inv end
    return body,obj
end
-- Original UI classes receive the same logical viewport, input and presentation
-- receivers. Installed original game functions remain unmodified.
ISPanel=ISBaseObject:derive('ControlledOriginalPanel')
function ISPanel:new(x,y,w,h)local o={x=x,y=y,width=w,height=h};setmetatable(o,self);self.__index=self;return o end
function ISPanel:initialise()end
local function draw(scene,kind,args)scene.__commands=scene.__commands or{};scene.__commands[#scene.__commands+1]={kind=kind,args=args}end
function ISPanel:drawRect(...)draw(self,'rect',{...})end
function ISPanel:drawText(t,x,y,r,g,b,a,font)draw(self,'text',{t,x,y,r,g,b,a,tostring(font)})end
function ISPanel:drawTextureScaled(tex,x,y,w,h,a,r,g,b)draw(self,'texture',{tex and tex:getName(),x,y,w,h,a,r,g,b})end
ComputerModGameInput={isDown=function(scene,key)return scene.__keys and scene.__keys[key]==true end}
ComputerModGameInput.isGamepadDown=ComputerModGameInput.isDown
ComputerModGameInput.getInputLabel=function(_,key)return string.upper(key)end
ComputerModGameInput.hasGamepad=function()return true end
ComputerModGameInput.getPlayer=function()return nil end
function ComputerModGameInput.drawGamepadSelection(scene,x,y,w,h)
    local p=.72+math.abs(math.sin((tonumber(scene.animationTick or scene.tick or scene.timerTicks)or 0)*.08))*.28
    scene:drawRect(x,y,w,2,p,.94,.90,.34);scene:drawRect(x,y+h-2,w,2,p,.94,.90,.34)
    scene:drawRect(x,y,2,h,p,.94,.90,.34);scene:drawRect(x+w-2,y,2,h,p,.94,.90,.34)
end

-- Explicit controlled owned-package availability, independent of external activation.
SAO.SourceIntegration={active=function(id)return id=='LifestyleHobbies'or id=='ComputerModkum'or id=='ProjectArcade' end}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getActivatedMods=function()return {contains=function()return false end}end
