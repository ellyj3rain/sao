require = function() end
__controlledOwnedSourceReader=function(mod,path)
    local value=__sourceTexts[path:sub(11)];if not value then return nil end
    if __sourceDrift then value=value..'\n-- source drift\n' end
    local cursor=1
    return {readLine=function()
        if cursor>#value then return nil end
        local ending=value:find('\n',cursor,true);local row=value:sub(cursor,ending and ending-1 or #value)
        cursor=ending and ending+1 or #value+1;return row
    end,close=function()end}
end
newrandom = function() return {} end
getText = function(x) return x end
isClient = function() return __client end
isServer = function() return false end
getActivatedMods = function() return {contains=function(_,id)return __active and id=='LifestyleHobbies' end} end
GTLSCheck = 1
Perks = {Meditation='Meditation'}
BodyPartType = {Neck='Neck'}
CharacterTrait = {DISCIPLINED='DISCIPLINED',COUCHPOTATO='COUCHPOTATO',SMOKER='SMOKER'}
Metabolics = {Fitness='Fitness'}
SandboxVars = {Meditation={KeepBags=true,StrengthMultiplier=2}, LSMeditation={RemoveLevitation=true}}
getGameTime = function() return {getGameWorldSecondsSinceLastUpdate=function()return 101 end} end
HaloTextHelper = {addGoodText=function()end,addBadText=function()end,addTextWithArrow=function()end}
LSSync = {isClientOnly=function()return false end}
ISLogSystem = {logAction=function()end}
sendClientCommand = function()error('unowned global player XP command')end
SAO={Identity={get=function(id)return __records[id]end}, History={countyHours=function()return __hours end},
    Needs={ownsRecoveryBody=function(id,body)return id=='person' and body==__body and __owned end,
        workAvailable=function(body)return not __queued and not body:isAsleep() end},
    ConceptKnowledge={infer=function(id,from,into)
        return __familiar and {actorId=id,paths={{id='concept:person:meditation',status='expectation',
            evidenceIds={'acquired:person:meditation'},basis='personal-relational-inference'}}} or {actorId=id,paths={}}
    end},ProceduralPlanning={admitHobbyWork=function(id,pid,sequence)
        local work=SAO.Leisure.work(id)
        return __admit and work and work.sequence==sequence and work.purposeId==pid
    end,hobbyAdmission=function(id,pid,wid)
        local work=SAO.Leisure.work(id)
        if __admit and work and work.workId==wid and work.purposeId==pid then
            work.ownerName='SAO.Leisure';return work
        end
    end,consumeHobbyOutcome=function(id,sequence)
        local row=SAO.Leisure.outcome(id,sequence);assert(row and row.actorId==id)
        __consumed=__consumed+1;return true
    end},LeisureSkill={consume=function(id,body,owner,work,sequence)
        assert(owner=='SAO.Leisure' and body==__body)
        local request=SAO.Leisure.skillRequest(id,work,sequence)
        assert(request and request.perkName=='Meditation' and request.nativeProgress.actionStarted)
        __xpMessages=__xpMessages+1 -- Source requests are verified; this controlled receiver grants no XP.
        return true
    end}}
SAOJavaBridge={privateCarriedItems=function(_,body)return {size=function()return 0 end}end}
instanceof=function()return false end
ISTimedActionQueue={add=function(action)
    if __refuseQueue then return end
    __queued=action
    action.action={setUseProgressBar=function()end,setActionAnim=function()end,
        getJobDelta=function()return __delta end,
        forceStop=function() if __queued==action then action:stop();if __queued==action then __queued=__follower;__follower=nil end end end}
end,hasAction=function(action)return __queued==action end,
getTimedActionQueue=function()return {
    current=__queued,resetQueue=function()__queued=nil;__follower=nil end,
    onCompleted=function(_,action)if __queued==action then __queued=__follower;__follower=nil end end,
    removeFromQueue=function(_,action)if __queued==action then __queued=__follower;__follower=nil end end}
end}
function __fresh()
    if SAO.Leisure then SAO.Leisure.reset('fixture-reset') end
    __active=true;__client=false;__owned=true;__familiar=true;__admit=true;__refuseQueue=false
    __hours=10;__delta=0;__queued=nil;__follower=nil;__xpMessages=0;__consumed=0
    __soundFault=false;__soundStopFault=false;__sourceDrift=false
    __stats:set(CharacterStat.BOREDOM,15);__stats:set(CharacterStat.STRESS,.8)
    __stats:set(CharacterStat.UNHAPPINESS,30);__stats:set(CharacterStat.ENDURANCE,.8)
    __stats:set(CharacterStat.FATIGUE,.2);__stats:set(CharacterStat.PAIN,0)
    local data={SAOPersonId='person',SAOExternalToken='generation:1',
        LSMoodles={MindfulState={Value=0},WasTaughtSkill={Value=0}}}
    local pain=0
    local emitter={isPlaying=function()if __soundFault then error('source sound unavailable')end;return false end,
        playSound=function()if __soundFault then error('source sound unavailable')end;return 1 end,
        stopSound=function()if __soundStopFault then error('source sound cleanup unavailable')end end}
    __body={getModData=function()return data end,isDead=function()return false end,
        isAsleep=function()return false end,getVehicle=function()return nil end,
        isAiming=function()return false end,isSitOnGround=function()return __sitting~=false end,
        isSittingOnFurniture=function()return false end,getPrimaryHandItem=function()return nil end,
        getSecondaryHandItem=function()return nil end,setPrimaryHandItem=function()end,
        setSecondaryHandItem=function()end,getPerkLevel=function()return 0 end,
        hasTrait=function()return false end,getStats=function()return __stats end,
        getBodyDamage=function()return {getBodyPart=function()return {
            getAdditionalPain=function()return pain end,setAdditionalPain=function(_,v)pain=v end}end}end,
        getWornItems=function()return {size=function()return 0 end}end,
        getEmitter=function()return emitter end,setMetabolicTarget=function()end,
        isTimedActionInstant=function()return false end,setIsFarming=function()end}
    __sitting=true
    local purpose={id='purpose:1',domain='leisure',status='active',cursor=1,
        leisure={activity='meditate',itemKey='body:meditation'},
        steps={{id='perform-activity',owner='SAO.Leisure',status='available'}}}
    __records={person={id='person',proceduralPlanning={purposes={['purpose:1']=purpose}}}}
    return __records.person
end

-- Controlled source host for action/mechanical proofs; actual packaged registry has a separate joined proof.
SAO.SourceIntegration={active=function(id)return __active and id=='LifestyleHobbies' end,reader=__controlledOwnedSourceReader}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getModFileReader=function()error("external source reader forbidden")end
getActivatedMods=function()return {contains=function()return false end}end
