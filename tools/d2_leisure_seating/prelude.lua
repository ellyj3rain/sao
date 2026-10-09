require=function()end
getText=function(x)return x end
isClient=function()return false end
isServer=function()return false end
ISLogSystem={logAction=function()end}
Events={OnTick={Add=function()end}}
__hours=10;__ms=1000000;__clockWrites=0;__xpWrites=0
getTimestampMs=function()return __ms end
getGameTime=function()return {getRealworldSecondsSinceLastUpdate=function()return .25 end}end
setGameSpeed=function()__clockWrites=__clockWrites+1 end
addXp=function()__xpWrites=__xpWrites+1;error('seating awarded XP')end
SAO={Identity={},Body={},History={countyHours=function()return __hours end,ticks=function()return __hours*9000 end},Needs={},Standing={},Locomotion={jobs={}},LeisureMusic={}}
SAO.Identity.get=function(id)return __records[id]end
SAO.Body.get=function(id)return __bodies[id]end
SAO.Needs.ownsRecoveryBody=function(id,body)return __bodies[id]==body and body:getModData().SAOPersonId==id and body:getModData().SAOExternalToken==__records[id].bodyOwnerToken end
SAO.Needs.workAvailable=function(body)return not __busy and not body:isDead() and not body:isAsleep()end
SAO.Standing.mayAttemptBelieved=function()return not __denied end
SAO.Locomotion.order=function(id,body,x,y,z)
 if __routeRefuse then return false end
 SAO.Locomotion.jobs[id]={body=body,goal={x=x,y=y,z=z},lastVerdict='started',sameVerdictTicks=0,done=false,result=nil,x=x,y=y,z=z};return true
end
SAO.Locomotion.cancel=function(id)SAO.Locomotion.jobs[id]=nil end
__fixtureRouteOrder=SAO.Locomotion.order;__fixtureRouteCancel=SAO.Locomotion.cancel
SAO.Log={line=function()end}
SAO.Needs.queueVerified=function(action)
 if __queueRefuse then return false end
 __action=action
 local queue=ISTimedActionQueue.getTimedActionQueue(action.character)
 table.insert(queue.queue,action);queue.current=queue.queue[1];action:create()
 return ISTimedActionQueue.hasAction(action)
end
SAO.Perception={}
SAO.Perception.leisureObjects=function(id,body)
 if __hidden or not SAO.Needs.ownsRecoveryBody(id,body)then return{}end
 return __observations
end
SAO.Perception.resolveLeisureObject=function(id,body,key)
 if __hidden or not SAO.Needs.ownsRecoveryBody(id,body)then return nil end
 for _,r in ipairs(__observations)do if r.actorId==id and r.key==key then return __objects[key]end end
end
SAO.LeisureMusic.intentOffers=function(id,body)
 if __offerUnavailable or id~='person' or body~=__body then return{}end
 local here,there=body:getSquare(),__piano:getSquare()
 local ready=body:isSittingOnFurniture()and here and there and here:getZ()==there:getZ()and math.abs(here:getX()-there:getX())<=1 and math.abs(here:getY()-there:getY())<=1 and body:isFacingObject(__piano,.8)
 __offer.requiresPreparation={sitFurniture=not body:isSittingOnFurniture(),faceObject=not body:isFacingObject(__piano,.8),adjacentObject=not ready}
 return {__offer}
end
