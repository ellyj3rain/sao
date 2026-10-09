-- Controlled native object/body/queue receivers; installed source Lua executes.
require=function(name) return __libraries and __libraries[name] end
print=function(s)__lastPrint=s end
newrandom=function()return {random=function(_,n)return n and 1 or .5 end}end
SandboxVars={Debug={LSVerbose=false}}
Events={}
CharacterStat={BOREDOM='BOREDOM',UNHAPPINESS='UNHAPPINESS',STRESS='STRESS',ENDURANCE='ENDURANCE',FATIGUE='FATIGUE'}
CharacterTrait={ARTISTIC='artistic',DEAF='deaf'}
Perks={Art='Art',Farming='Farming',Woodwork='Woodwork',MetalWelding='MetalWelding'}
ItemTag={}
Metabolics={LightWork='LightWork'}
GTLSCheck=1
ISLogSystem={logAction=function()end}
isClient=function()return false end;isServer=function()return false end
getActivatedMods=function()return {contains=function(_,s)return s=='LifestyleHobbies' end}end
getGameTime=function()return {getGameWorldSecondsSinceLastUpdate=function()return 15 end}end
getText=function(s)return s end
getCore=function()return {getScreenWidth=function()return 1920 end,getScreenHeight=function()return 1080 end}end
LSNoteMng={addToQueue=function(x,y,w,h,payload)__uiNotes=(__uiNotes or 0)+1;__notePayload=payload end}
getSoundManager=function()return {playUISound=function()__uiSounds=(__uiSounds or 0)+1 end}end
__rng=0
ZombRand=function(a,b)__rng=__rng+1;if b then return a+math.floor((b-a)/2) end;return 0 end
function list(t)return {size=function()return #t end,get=function(_,i)return t[i+1]end}end
getAllItems=function()return list({{getFullName=function()return 'Lifestyle.Chainsaw'end,InstanceItem=function()return {}end}})end
__records={};__bodies={};__tick=100;__hours=10;__station=nil
SAO={Identity={get=function(id)return __records[id]end},History={ticks=function()return __tick end,countyHours=function()return __hours end},
    Standing={mayEnterCurrent=function()return true end},
    ConceptKnowledge={infer=function(id,concept)return {actorId=id,paths={{status='expectation',id='personal:'..concept,evidenceIds={'owned-observation'}}}}end},
    Perception={conceptContext=function(id)return {status='observed',observations=__bodies[id] and __bodies[id].observations or {}}end},
    Needs={ownsRecoveryBody=function(id,body)return __bodies[id]==body end,workAvailable=function()return true end},
    ProceduralPlanning={admitHobbyWork=function()__admissions=(__admissions or 0)+1;return true end,
        consumeHobbyOutcome=function()__consumptions=(__consumptions or 0)+1;return true end}}
SAOJavaBridge={privateCarriedItems=function(_,body)return list(body.items)end}
ISTimedActionQueue={queues={}}
ISTimedActionQueue.getTimedActionQueue=function(body)return {current=ISTimedActionQueue.queues[body],onCompleted=function()ISTimedActionQueue.queues[body]=nil end,
    removeFromQueue=function(action)if ISTimedActionQueue.queues[body]==action then ISTimedActionQueue.queues[body]=nil end end,
    resetQueue=function()ISTimedActionQueue.queues[body]=nil end}end
ISTimedActionQueue.hasAction=function(action)return ISTimedActionQueue.queues[action.character]==action end
SAO.Needs.queueVerified=function(action)ISTimedActionQueue.queues[action.character]=action;return true end
LSAmbtMng={hasCompleted=function(body)return body.brushmaster==true end,hasActiveCompleted=function()return false end}
function sprite(name,properties)
    return {getName=function()return name end,getProperties=function()return {has=function(_,key)return properties[key]~=nil end,get=function(_,key)return properties[key]end}end}
end
function square(x,y)
    local s={objects={},x=x,y=y}
    function s:getX()return x end;function s:getY()return y end;function s:getZ()return 0 end
    function s:getObjects()return list(self.objects)end
    function s:AddTileObject(o)self.objects[#self.objects+1]=o end
    function s:RemoveTileObject(o)for i,v in ipairs(self.objects)do if v==o then table.remove(self.objects,i);return end end end
    function s:transmitRemoveItemFromSquare()end
    function s:getS()return self.front end;function s:getE()return self.front end
    function s:getN()return self.front end;function s:getW()return self.front end
    return s
end
getCell=function()return {getGridSquare=function(_,x,y,z)return __station and __station.square.x==x and __station.square.y==y and __station.square end}end
IsoObject={new=function(s,name)return {setSprite=function()end,setCustomColor=function()end}end}
function item(name,id)
    local i={name=name,id=id,uses=100}
    function i:getID()return self.id end;function i:getType()return self.name end;function i:getFullType()return 'Lifestyle.'..self.name end
    function i:hasTag()return false end;function i:getCurrentUses()return self.uses end;function i:getCurrentUsesFloat()return self.uses end
    function i:isInPlayerInventory()return self.carried~=false end;function i:UseAndSync()self.uses=self.uses-1 end
    return i
end
function fixture(id,style,level)
    __records[id]={id=id}
    local s=square(10,10);s.front=square(10,11)
    local kind=style and 'art-sculpture' or 'art-canvas'
    local obj={data={style=style},square=s,sprite=sprite(style and 'LS_Sculptures_24' or 'LS_Painting_26',
        {CustomName=style and 'Sculpting' or 'Painting',GroupName=style and 'StationWork' or 'EaselCanvasSmall',Facing='S'})}
    function obj:getModData()return self.data end;function obj:getSprite()return self.sprite end;function obj:getSquare()return self.square end
    function obj:getX()return 10 end;function obj:getY()return 10 end;function obj:getZ()return 0 end
    function obj:setOverlaySprite(name)self.overlay=sprite(name,{})end;function obj:getOverlaySprite()return self.overlay end
    s.objects={obj};__station=obj
    local body={data={SAOPersonId=id,SAOExternalToken='generation-1'},items={},level=level or 4,current=s.front,
        observations={{actorId=id,kind='object',concept=kind,source='native-personal-visibility',at=__tick,x=10,y=10,z=0,
            key='object:10:10:0:0:'..kind,objectIndex=0,spriteName=obj.sprite:getName(),runtimeInstance='native-instance:'..id}}}
    for n,name in ipairs({'oldPaintBrush','paintPalette','Saw','Hammer','CarpentryChisel','MasonsChisel','BlowTorch','WeldingMask'})do body.items[n]=item(name,n)end
    body.stats={values={BOREDOM=50,UNHAPPINESS=20,STRESS=.3,ENDURANCE=.8,FATIGUE=.2},get=function(self,k)return self.values[k]end,
        remove=function(self,k,v)self.values[k]=math.max(0,self.values[k]-v)end,
        add=function(self,k,v)self.values[k]=self.values[k]+v end,set=function(self,k,v)self.values[k]=v end}
    function body:getModData()return self.data end;function body:getStats()return self.stats end
    function body:getPerkLevel(perk)return perk=='Art' and self.level or 10 end
    function body:isDead()return self.dead==true end;function body:isAsleep()return false end;function body:isExistInTheWorld()return true end
    function body:getZ()return 0 end;function body:getCurrentSquare()return self.current end
    function body:getDescriptor()return {getForename=function()return 'Test'end,getSurname=function()return id end}end
    function body:getVehicle()return nil end;function body:isSitOnGround()return false end
    function body:isEquippedClothing()return self.mask~=false end;function body:isTimedActionInstant()return false end
    function body:hasTrait()return false end;function body:isFemale()return false end
    function body:faceThisObject()end;function body:shouldBeTurning()return false end
    function body:setMetabolicTarget(v)self.metabolic=v end;function body:setIsFarming()end
    body.emitter={isPlaying=function()return false end,playSound=function()return 1 end,stopSound=function()end,stopSoundByName=function()end}
    function body:getEmitter()return self.emitter end
    function body:getInventory()return {getItems=function()return list(self.items)end}end
    __bodies[id]=body
    return body,obj
end
SAO.Perception.leisureObjects=function(id,body)return body.observations end
SAO.Perception.resolveLeisureObject=function(id,body,key)
    local row=body.observations[1]
    return __station and row and row.key==key and row.spriteName==__station:getSprite():getName()
        and __station.square.objects[1]==__station and row.runtimeInstance=='native-instance:'..id and __station or nil
end
function native(action,delta)
    action.delta=delta
    action.action={getJobDelta=function()return action.delta end,setActionAnim=function()end,setOverrideHandModelsObject=function()end,
        setUseProgressBar=function()end,forceStop=function()action:forceCancel()end,forceComplete=function()action.delta=1;action:perform();action:complete()end}
    action:start()
end
function copy(t)if type(t)~='table'then return t end;local n={}for k,v in pairs(t)do n[k]=copy(v)end;return n end

-- Explicit controlled owned-package availability, independent of external activation.
SAO.SourceIntegration={active=function(id)return id=='LifestyleHobbies' end}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getActivatedMods=function()return {contains=function()return false end}end
