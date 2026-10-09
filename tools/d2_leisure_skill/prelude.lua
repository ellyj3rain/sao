require=function()end
__hours=10;__client=false;__server=false
isClient=function()return __client end
isServer=function()return __server end
SAO={Identity={},Body={},Needs={},History={countyHours=function()return __hours end},
    LeisureArt={},LeisureMusic={},Leisure={}}
SAO.Identity.get=function(id)return __records[id]end
SAO.Body.get=function(id)return __bodies[id]end
SAO.Needs.ownsRecoveryBody=function(id,body)
    return __bodies[id]==body and body:getModData().SAOPersonId==id
        and body:getModData().SAOExternalToken==__records[id].bodyOwnerToken
end
local function canonicalRequest(id,workSequence,sequence)
    local work=__works[id]
    local row=__requests[id] and __requests[id][sequence]
    if not __sourceLost and work and work.sequence==workSequence and row then return row end
end
SAO.LeisureArt.work=function(id)return __works[id]end
SAO.LeisureArt.skillRequest=canonicalRequest
SAO.LeisureMusic.work=SAO.LeisureArt.work;SAO.LeisureMusic.skillRequest=canonicalRequest
SAO.Leisure.work=SAO.LeisureArt.work;SAO.Leisure.skillRequest=canonicalRequest
LSUtil={changeCharacterMood=function(body,name,amount)return body:getStats():remove(CharacterStat.BOREDOM,-amount)end}
ZombRand=function(low,high)return low end
-- The actual source adjustStats emits this exact request. The source action/
-- active callback binding is a controlled provider; native XP is real.
sendClientCommand=function(body,module,command,args)
    assert(module=='LS' and command=='AddXP' and body==__body)
    __sourceCalls=__sourceCalls+1
    local w=__works.person
    local rows=__requests.person
    rows[#rows+1]={actorId='person',workId=w.workId,purposeId=w.purposeId,
        workSequence=w.sequence,sequence=#rows+1,perkName=args[1],amount=args[2],atHours=__hours,
        sourceId=w.sourceId,revision=w.revision,status='requested',
        nativeProgress={sourceCallback='update',sourceInvocationSequence=__sourceCalls,actionStarted=true,jobDelta=0}}
end
