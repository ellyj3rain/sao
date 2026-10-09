require=function()end
__hours=10;__client=false;__server=false
isClient=function()return __client end;isServer=function()return __server end
getActivatedMods=function()return {contains=function()return false end}end
getTexture=function()return nil end;UIFont={};Keyboard={KEY_LSHIFT=0}
getText=function(x)return x end;Events={OnGameStart={Add=function()end}}
SAO={Identity={},Needs={},History={countyHours=function()return __hours end,ticks=function()return __hours*60 end},ConceptKnowledge={},Perception={}}
SAO.Identity.get=function(id)return __records and __records[id]end
SAO.Needs.ownsRecoveryBody=function(id,b)return __bodies and __bodies[id]==b and b:getModData().SAOPersonId==id and b:getModData().SAOExternalToken==__records[id].bodyOwnerToken end
SAO.Needs.workAvailable=function()return __queue==nil end
SAO.Needs.queueVerified=function(a)__queue=a;return __queueNative(a)end
SAO.Needs.resetOwnedQueue=function(a)if __queue==a then __queue=nil end end
SAO.ConceptKnowledge.infer=function(id,key)return {actorId=id,paths={{id='prior:'..key,status='expectation',evidenceIds={'private:'..key}}}}end
SAO.Perception.leisureObjects=function()return {}end
SAO.Perception.resolveLeisureObject=function()end
ISTimedActionQueue={queues={},hasAction=function(a)return __queue==a end,getTimedActionQueue=function()return {onCompleted=function(_,a)if __queue==a then __queue=nil end end,removeFromQueue=function(_,a)if __queue==a then __queue=nil end end,resetQueue=function()__queue=nil end}end}
ISLogSystem={logAction=function()end}

-- Explicit controlled owned-package availability, independent of external activation.
SAO.SourceIntegration={active=function(id)return false end}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getActivatedMods=function()return {contains=function()return false end}end
