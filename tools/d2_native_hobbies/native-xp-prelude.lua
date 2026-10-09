require=function()end
__controlledOwnedSourceReader=function(mod,path)
    local value=__sourceTexts[path:sub(11)];if not value then return nil end
    if __sourceDrift then value=value..'\n-- altered source\n' end
    local cursor=1
    return {readLine=function()
        if cursor>#value then return nil end
        local ending=value:find('\n',cursor,true);local row=value:sub(cursor,ending and ending-1 or #value)
        cursor=ending and ending+1 or #value+1;return row
    end,close=function()end}
end
getActivatedMods=function()return {contains=function(_,id)return id=='LifestyleHobbies'end}end
isClient=function()return false end;isServer=function()return false end
sendClientCommand=function()error('global XP command must remain unused')end
newrandom=function()return {}end;getText=function(x)return x end
getGameTime=function()return {getGameWorldSecondsSinceLastUpdate=function()return 101 end}end
GTLSCheck=1
SandboxVars={Meditation={KeepBags=true,StrengthMultiplier=2},LSMeditation={RemoveLevitation=true}}
HaloTextHelper={addTextWithArrow=function()end,addGoodText=function()end,addBadText=function()end}
LSSync={isClientOnly=function()return false end};ISLogSystem={logAction=function()end}
__hours=10;__delta=0;__admit=true;__familiar=true
SAO={Identity={get=function(id)return __records[id]end},Body={get=function(id)return __bodies[id]end},
    History={countyHours=function()return __hours end},
    Needs={ownsRecoveryBody=function(id,body)
        return body==__bodies[id] and not body:isDead() and body:getModData().SAOPersonId==id
            and body:getModData().SAOExternalToken==__records[id].bodyOwnerToken
    end,workAvailable=function()return __queued==nil end},
    ConceptKnowledge={infer=function(id)
        return {actorId=id,paths=__familiar and {{id='native-personal:meditation',status='expectation',
            evidenceIds={'acquired:native-person:meditation'},basis='personally-supported-concept'}} or {}}
    end},ProceduralPlanning={admitHobbyWork=function(id,pid,seq)
        local w=SAO.Leisure.work(id);return __admit and w and w.sequence==seq and w.purposeId==pid
    end,hobbyAdmission=function(id,pid,wid)
        local w=SAO.Leisure.work(id)
        if __admit and w and w.workId==wid and w.purposeId==pid then w.ownerName='SAO.Leisure';return w end
    end,consumeHobbyOutcome=function(id,seq)
        __consumed=__consumed+1;return true
    end}}
ISTimedActionQueue={add=function(action)
    __queued=action;action.action={setUseProgressBar=function()end,setActionAnim=function()end,
        getJobDelta=function()return __delta end,
        forceStop=function()if __queued==action then action:stop();if __queued==action then __queued=__follower;__follower=nil end end end}
end,hasAction=function(action)return __queued==action end,
getTimedActionQueue=function()return {current=__queued,
    resetQueue=function()__queued=nil;__follower=nil end,
    onCompleted=function(_,action)if __queued==action then __queued=__follower;__follower=nil end end,
    removeFromQueue=function(_,action)if __queued==action then __queued=__follower;__follower=nil end end}end}
function __nativeFresh(clear)
    if SAO.Leisure then SAO.Leisure.reset('fixture-reset')end
    if clear then __clearXP()end
    __delta=0;__admit=true;__familiar=true;__sourceDrift=false;__queued=nil;__follower=nil;__consumed=0
    __body:setHealth(100)
    __body:getModData().SAOPersonId='person';__body:getModData().SAOExternalToken='native:1'
    __other:getModData().SAOPersonId='foreign';__other:getModData().SAOExternalToken='native:2'
    __body:setSitOnGround(true);__body:setPrimaryHandItem(nil);__body:setSecondaryHandItem(nil)
    __emitter:reset()
    local stats=__body:getStats();stats:set(CharacterStat.BOREDOM,15);stats:set(CharacterStat.STRESS,.8)
    stats:set(CharacterStat.UNHAPPINESS,30);stats:set(CharacterStat.ENDURANCE,.8);stats:set(CharacterStat.FATIGUE,.2)
    stats:set(CharacterStat.PAIN,0)
    LSMoodleManager.init(__body)
    __bodies={person=__body,foreign=__other}
    local purpose={id='purpose:1',domain='leisure',status='maintained',cursor=1,
        leisure={activity='meditate',itemKey='body:meditation'},
        steps={{id='perform-activity',owner='SAO.Leisure',status='available'}}}
    __records={person={id='person',bodyOwnerToken='native:1',proceduralPlanning={purposes={['purpose:1']=purpose}}},
        foreign={id='foreign',bodyOwnerToken='native:2'}}
end

-- Controlled source host for action/mechanical proofs; actual packaged registry has a separate joined proof.
SAO.SourceIntegration={active=function(id)return id=='LifestyleHobbies' end,reader=__controlledOwnedSourceReader}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getModFileReader=function()error("external source reader forbidden")end
getActivatedMods=function()return {contains=function()return false end}end
