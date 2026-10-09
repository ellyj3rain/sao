require=function()end
getText=function(x)return x end
MoodleType={ENDURANCE=__enduranceMoodle}
__hours=10;__ms=1000000;__clockWrites=0
getGameTime=function()return {getCalender=function()return {getTimeInMillis=function()return __ms end}end}end
setGameSpeed=function()__clockWrites=__clockWrites+1 end
isClient=function()return false end
isServer=function()return false end
ISLogSystem={logAction=function()end}
__queue={queue={}}
__queue.resetQueue=function(self)self.queue={}end
__queue.onCompleted=function(self,action)self.queue={}end
ISTimedActionQueue={getTimedActionQueue=function(body)return __queue end,
    addGetUpAndThen=function(body,action)
        if __queueRefuse then error('controlled queue refusal') end
        __queue.queue={action};__action=action
        action.action={forceStop=function()action:stop()end,isStarted=function()return true end,
            setUseProgressBar=function()end}
    end}
SAO={Identity={},Body={},History={countyHours=function()return __hours end,ticks=function()return __hours*9000 end},
    Needs={},Standing={},ConceptKnowledge={}}
SAO.Identity.get=function(id)return __records[id]end
SAO.Body.get=function(id)return __bodies[id]end
SAO.Needs.ownsRecoveryBody=function(id,body)return __bodies[id]==body
    and body:getModData().SAOPersonId==id and body:getModData().SAOExternalToken==__records[id].bodyOwnerToken end
SAO.Needs.workAvailable=function(body)return not __busy and not body:isDead() and not body:isAsleep()end
SAO.Standing.mayEnterCurrent=function()return not __denied end
SAO.ConceptKnowledge.infer=function()return {status=__conceptDenied and 'unsupported' or 'expectation'}end
Events={EveryOneMinute={Add=function()end}}
SandboxVars={KnoxAquarium={}}
SAO.Perception={conceptContext=function()return {status='observed',observations=__observations or {}}end}
-- Native Fitness.init reads the installed definitions through LuaManager.env.

SAO.Perception.resolveLeisureObject=function(id,body,key)
    for _,row in ipairs(__observations or {}) do
        if row.actorId==id and row.key==key and row.runtimeInstance=='aquarium-1' then return __tank end
    end
end
