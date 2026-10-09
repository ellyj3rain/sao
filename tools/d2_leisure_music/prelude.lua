require=function(name)
    local key='LifestyleHobbies:client/'..name..'.lua'
    local source=__sources[key]
    if source then return assert(loadstring(source,name))() end
end
newrandom=function()return {} end
Events=setmetatable({},{__index=function()return {Add=function()__eventRegistrations=(__eventRegistrations or 0)+1 end}end})
getText=function(x)return x end
isClient=function()return false end
isServer=function()return false end
getActivatedMods=function()return {contains=function(_,id)return __active and (id=='LifestyleHobbies' or id=='NewMusic' and __tali) end}end
__controlledOwnedSourceReader=function(mod,path)
    local key=mod..':'..path:sub(11);local value=__sources[key]
    if not value then return nil end
    if __sourceDrift then value=value..'\n-- source drift\n' end
    local cursor=1
    return {readLine=function()
        if cursor>#value then return nil end
        local ending=value:find('\n',cursor,true);local row=value:sub(cursor,ending and ending-1 or #value)
        cursor=ending and ending+1 or #value+1;return row
    end,close=function()end}
end
GTLSCheck=1
Perks={Music='Music',Dancing='Dancing'}
CharacterTrait={DEAF='DEAF',DESENSITIZED='DESENSITIZED',BRAVE='BRAVE',DISCIPLINED='DISCIPLINED',
    VIRTUOSO='VIRTUOSO',KEEN_HEARING='KEEN_HEARING',TONEDEAF='TONEDEAF',HARD_OF_HEARING='HARD_OF_HEARING',
    CLUMSY='CLUMSY',DEXTROUS='DEXTROUS'}
Metabolics={LightWork='LightWork',HeavyWork='HeavyWork',Dancing='Dancing'}
getAllItems=function()return {size=function()return 1 end,get=function()return {
    getFullName=function()return 'Lifestyle.violinBow' end,InstanceItem=function()return {getWorldStaticItem=function()return 'source-violin-bow' end}end}end}end
MoodleType={PANIC='PANIC'}
Keyboard={KEY_E='E',KEY_O='O'}
SandboxVars={Music={StrengthMultiplier=2,Metabolics=2},Dancing={StrengthMultiplier=2}}
getGameTime=function()return {getGameWorldSecondsSinceLastUpdate=function()return __seconds end}end
getTimestampMs=function()return __milliseconds end
getTimestamp=function()return math.floor(__milliseconds/1000)end
ZombRand=function(a,b)if b then return a end;return 0 end
isKeyDown=function()return true end -- Operator keys must not cancel NPC work.
HaloTextHelper={addTextWithArrow=function()end}
LSAmbtMng={hasActiveCompleted=function()return false end,hasActive=function()return false end,hasCompleted=function()return false end}
LSSync={isClientOnly=function()return false end,updateClientData=function(body)assert(body==__body)end}
ISLogSystem={logAction=function()end}
getSoundManager=function()return {getMusicVolume=function()return __volume end,setMusicVolume=function(_,v)__volume=v end}end
LSNoteMng={addToQueue=function()error('operator UI escaped isolation')end}
getCore=function()return {getScreenWidth=function()return 1280 end,getScreenHeight=function()return 720 end}end
getPlayer=function()error('operator player escaped isolation')end
getNumActivePlayers=function()error('player slots escaped isolation')end
sendClientCommand=function()error('player command escaped isolation')end
SAO={Identity={get=function(id)return __records[id]end},History={countyHours=function()return __hours end},
    Needs={ownsRecoveryBody=function(id,body)return id=='person' and body==__body and __owned end,
        workAvailable=function()return __queued==nil end},
    ConceptKnowledge={infer=function(id,from,effect)
        return {actorId=id,paths=__familiar and {{id='private:'..from,status='expectation',evidenceIds={'prior:person:'..from},basis='source-supported-personal-prior'}} or {}}
    end},ProceduralPlanning={admitHobbyWork=function(id,pid,sequence,owner)
        assert(owner=='SAO.LeisureMusic');local w=SAO.LeisureMusic.work(id)
        return __admit and pid=='purpose:1' and w and w.sequence==sequence
    end,hobbyAdmission=function(id,pid,wid)
        local w=SAO.LeisureMusic.work(id)
        if __admit and w and w.workId==wid and w.purposeId==pid then return {ownerName='SAO.LeisureMusic',sequence=w.sequence}end
    end,consumeHobbyOutcome=function(id,sequence,owner)
        assert(owner=='SAO.LeisureMusic');local row=SAO.LeisureMusic.outcome(id,sequence)
        assert(row and row.actorId==id);__consumed=__consumed+1;return true
    end},LeisureSkill={consume=function(id,body,owner,work,sequence)
        if __tamperRequest then
            local saved=__records.person.leisureMusicSkillRequests[#__records.person.leisureMusicSkillRequests]
            __tamperOriginal=saved.amount;saved.amount=999999
        end
        local r=SAO.LeisureMusic.skillRequest(id,work,sequence)
        assert(r and r.nativeProgress.actionStarted and r.nativeProgress.sourceCallback,'canonical live source callback required')
        if __tamperRequest then __tamperResisted=r.amount==__tamperOriginal end
        __skillRequests=__skillRequests+1;return true
    end}}
SAOJavaBridge={privateCarriedItems=function(_,body)return {size=function()return #__items end,get=function(_,n)return __items[n+1]end}end}
ISTimedActionQueue={add=function(action)
    if __queueRefusal then return end
    __queued=action
    action.action={setUseProgressBar=function()end,setActionAnim=function(_,anim)__animation=anim end,
        setOverrideHandModelsObject=function()end,setOverrideHandModelsString=function()end,getJobDelta=function()return __delta end,
        setTime=function()end,setCurrentTime=function()end,resetJobDelta=function()end,forceComplete=function()action:perform()end,
        forceStop=function()if __queued==action then action:stop();__queued=nil end end}
end,hasAction=function(action)return __queued==action end,
getTimedActionQueue=function()return {resetQueue=function()__queued=nil end,onCompleted=function()__queued=nil end}end}
function __fresh(kind)
    if SAO.LeisureMusic then SAO.LeisureMusic.reset('fixture-reset')end
    __active=true;__owned=true;__familiar=true;__admit=true;__queueRefusal=false;__sourceDrift=false;__tali=false
    __objects={};__objectHandles={};__tamperRequest=false;__tamperResisted=false
    __hours=10;__milliseconds=100000;__seconds=1;__delta=0;__queued=nil;__consumed=0;__skillRequests=0
    __level=0;__panic=0;__volume=.61;__played={};__playing={};__animation=nil;__nextSound=0;__audioFailure=false;__sneaking=false
    __stats:set(CharacterStat.BOREDOM,15);__stats:set(CharacterStat.STRESS,.2)
    __stats:set(CharacterStat.UNHAPPINESS,30);__stats:set(CharacterStat.ENDURANCE,.8)
    __stats:set(CharacterStat.FATIGUE,.2);__stats:set(CharacterStat.PAIN,0)
    local md={SAOPersonId='person',SAOExternalToken='generation:1',
        LSMoodles={PartyBad={Value=0},PartyGood={Value=0},Embarrassed={Value=0},WasTaughtSkill={Value=0}}}
    local itype=kind or 'Harmonica'
    __instrument={getID=function()return 10 end,getFullType=function()return 'Base.'..itype end,
        getType=function()return itype end,isBroken=function()return false end,getModData=function()return {}end}
    __primary=__instrument;__items={__instrument}
    local emitter={isPlaying=function(_,handle)return __playing[handle]==true end,
        playSound=function(_,name)
            __nextSound=__nextSound+1;__played[#__played+1]=name;__playing[__nextSound]=not __audioFailure;return __nextSound
        end,stopSound=function(_,handle)__playing[handle]=false end}
    __body={getModData=function()return md end,getStats=function()return __stats end,isAsleep=function()return false end,
        getVehicle=function()return nil end,isSneaking=function()return __sneaking end,isAiming=function()return false end,
        isSitOnGround=function()return false end,isSittingOnFurniture=function()return false end,
        getPrimaryHandItem=function()return __primary end,getSecondaryHandItem=function()return nil end,
        setPrimaryHandItem=function(_,item)__primary=item end,setSecondaryHandItem=function()end,
        getPerkLevel=function()return __level end,hasTrait=function()return false end,
        getEmitter=function()return emitter end,getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end,
        isOutside=function()return false end,isInvisible=function()return false end,isPlayerMoving=function()return false end,
        getMoodles=function()return {getMoodleLevel=function()return __panic end}end,isTimedActionInstant=function()return false end,
        setIsFarming=function()end,setMetabolicTarget=function()end,setVariable=function()end,clearVariable=function()end,isItemInBothHands=function()return false end,
        getBodyDamage=function()return {getTemperature=function()return 37 end}end,
        getDescriptor=function()return {isFemale=function()return false end}end}
    __records={person={id='person'}}
    __worldSounds=0;return __records.person
end
addSound=function(body)assert(body==__body);__worldSounds=__worldSounds+1 end
IsoDirections={E='E',W='W',N='N',S='S'}
instanceof=function(obj,kind)return kind=='IsoObject' and obj.__isoObject==true end
SAO.Perception={leisureObjects=function()return __objects end,
    resolveLeisureObject=function(id,body,key)return id=='person' and body==__body and __objectHandles[key] or nil end}
function __pianoFixture(sprite,pairSprite,dx,dy)
    __fresh();__items={};__primary=nil;__furniture=true;__facing=true;__x=10.5;__y=11.5
    local mainSquare={getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end}
    local pairSquare={getX=function()return 10+dx end,getY=function()return 10+dy end,getZ=function()return 0 end}
    local main={__isoObject=true,getSquare=function()return mainSquare end,getSpriteName=function()return sprite end}
    local pair={__isoObject=true,getSquare=function()return pairSquare end,getSpriteName=function()return pairSprite end}
    mainSquare.getAdjacentSquare=function(_,dir)
        if dir=='E' and dx==1 or dir=='W' and dx==-1 or dir=='N' and dy==-1 or dir=='S' and dy==1 then return pairSquare end
    end
    pairSquare.getObjects=function()return {size=function()return __objectHandles['pair'] and 1 or 0 end,
        get=function()return __objectHandles['pair']end}end
    __objects={{key='piano',actorId='person',x=10,y=10,z=0,spriteName=sprite,runtimeInstance='main:1'},
        {key='pair',actorId='person',x=10+dx,y=10+dy,z=0,spriteName=pairSprite,runtimeInstance='pair:1'}}
    __objectHandles={piano=main,pair=pair}
    __body.getSquare=function()return {getX=function()return math.floor(__x)end,
        getY=function()return math.floor(__y)end,getZ=function()return 0 end}end
    __body.getX=function()return __x end;__body.getY=function()return __y end
    __body.setX=function(_,x)__x=x end;__body.setY=function(_,y)__y=y end
    __body.isSittingOnFurniture=function()return __furniture end
    __body.isFacingObject=function(_,obj)return obj==main and __facing end
    return main,pair
end

-- Controlled source host for action/mechanical proofs; actual packaged registry has a separate joined proof.
SAO.SourceIntegration={active=function(id)return __active and (id=='LifestyleHobbies' or id=='NewMusic' and __tali) end,reader=__controlledOwnedSourceReader}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getModFileReader=function()error("external source reader forbidden")end
getActivatedMods=function()return {contains=function()return false end}end
