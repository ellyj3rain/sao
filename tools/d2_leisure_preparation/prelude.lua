require=function()end
getText=function(x)return x end
isClient=function()return false end
isServer=function()return false end
ISLogSystem={logAction=function()end}
Events={OnTick={Add=function()end}}
__hours=10;__clockWrites=0;__xpWrites=0
setGameSpeed=function()__clockWrites=__clockWrites+1 end
addXp=function()__xpWrites=__xpWrites+1;error('preparation awarded XP')end
sendEquip=function()end
syncItemActivated=function()end
triggerEvent=function()end
SAO={Identity={},Body={},History={countyHours=function()return __hours end,ticks=function()return __hours*9000 end},Needs={},Standing={},Locomotion={jobs={}},LeisureExercise={}}
SAO.Identity.get=function(id)return __records[id]end
SAO.Body.get=function(id)return __bodies[id]end
SAO.Needs.ownsRecoveryBody=function(id,body)return __bodies[id]==body and body:getModData().SAOPersonId==id and body:getModData().SAOExternalToken==__records[id].bodyOwnerToken end
SAO.Needs.workAvailable=function(body)return not __busy and not body:isDead() and not body:isAsleep()end
SAO.Standing.mayAttemptBelieved=function()return not __denied end
SAO.Needs.bleeding=function()return __bleeding or 0 end
SAO.Needs.cold=function()return __cold or 0 end
SAO.Disposition={drinkAt=function()return .5 end,eatAt=function()return .5 end}
SAO.ConflictResponse={gesturePriority=function()return __threat end}
SAO.Locomotion.order=function(id,body,x,y,z)
 if __routeRefuse then return false end
 SAO.Locomotion.jobs[id]={body=body,goal={x=x,y=y,z=z},lastVerdict='started',sameVerdictTicks=0,done=false,result=nil,x=x,y=y,z=z};return true
end
SAO.Locomotion.cancel=function(id)SAO.Locomotion.jobs[id]=nil end
__fixtureRouteOrder=SAO.Locomotion.order;__fixtureRouteCancel=SAO.Locomotion.cancel
SAO.Log={line=function()end}
-- Actual queue management methods are loaded; only scheduler/animation timing
-- is driven explicitly in this bounded fixture.
SAO.Needs.queueVerified=function(action)
 if __queueRefuse then return false end
 __action=action
 local queue=ISTimedActionQueue.getTimedActionQueue(action.character)
 table.insert(queue.queue,action);queue.current=queue.queue[1]
 action:create()
 return ISTimedActionQueue.hasAction(action)
end
SAO.LeisureExercise.intentOffers=function(id,body)
 if id~='person' or body~=__body or __offerUnavailable then return {} end
 local p={}
 if __mode=='primary' and body:getPrimaryHandItem()~=__dumbbell then p.equipPrimary={itemKey=tostring(__dumbbell:getID()),itemType=__dumbbell:getFullType()} end
 if __mode=='secondary' and body:getSecondaryHandItem()~=__dumbbell then p.equipSecondary={itemKey=tostring(__dumbbell:getID()),itemType=__dumbbell:getFullType()} end
 if __mode=='twoHands' and (body:getPrimaryHandItem()~=__barbell or body:getSecondaryHandItem()~=__barbell) then p.equipPrimary={itemKey=tostring(__barbell:getID()),itemType=__barbell:getFullType(),twoHands=true} end
 if __mode=='bag' and body:isEquippedClothing(__bag) then p.removeBags={{itemKey=tostring(__bag:getID()),itemType=__bag:getFullType()}} end
 if __mode=='clearHands' and (body:getPrimaryHandItem() or body:getSecondaryHandItem()) then p.clearHands=true end
 if __mode=='mask' and not body:isEquippedClothing(__mask) then p.weldingMask=true end
 if __mode=='route' and body:getX()<11 then p.frontSquare={x=11,y=20,z=0} end
 if __mode=='stand' and body:isSitOnGround() then p.stand=true end
 if __mode=='initialize' and not __initialized then p.sourceInitialization=true end
 return {{id='exercise-fixture',activity='source-exercise',sourceId='native:ISFitnessAction',revision='fixture-source-1',
 itemKey=tostring(__dumbbell:getID()),itemType=__dumbbell:getFullType(),targetX=11,targetY=20,targetZ=0,
 requiresPreparation=p,materials={item3={id=__mask:getID(),itemType=__mask:getFullType()}}}}
end
SAO.LeisureExercise.prepareActor=function()__initialized=true;return true end
Ctl={beginLeisureOffer=function()__begun=(__begun or 0)+1 end}
