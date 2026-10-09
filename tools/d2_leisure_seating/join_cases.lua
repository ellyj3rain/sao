local checks=0
local function check(name,yes)assert(yes,'SEATING_JOIN:'..name);checks=checks+1;print('CASE '..name)end
local function begin()
 if SAO.LeisurePreparation.reset then SAO.LeisurePreparation.reset('fixture reset')end
 local purpose=__freshSeating()
 local offer=SAO.LeisureMusic.intentOffers('person',__body)[1]
 local admitted,ready=SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureMusic',offer,'purpose-1')
 check('Q_native_seating_admission',admitted and not ready and __records.person.leisurePreparation.phase=='native-seating')
 local route=SAO.Locomotion.jobs.person
 if route then
  __body:setX(route.x);__body:setY(route.y);route.done=true;route.result='arrived'
  SAO.LeisurePreparation.advance('person',__body)
 end
 return __action,purpose
end
local a,p=begin();__sourceStartSeating(a);__sourceEndSeating(a)
check('Q_no_completion_from_source_action_alone',SAO.LeisurePreparation.advance('person',__body) and __records.person.leisurePreparation.status=='preparing')
__nativePoseSeating()
local held,ready=SAO.LeisurePreparation.advance('person',__body)
for i=1,3 do if held then __settleFacing(__body);held,ready=SAO.LeisurePreparation.advance('person',__body)end end
check('Q_native_pose_current_source_requery',not held and ready and ready.offer.objectKey=='piano' and ready.ownerName=='SAO.LeisureMusic' and __records.person.leisurePreparation.status=='completed')
check('Q_completion_no_hobby_credit',p.status=='maintained' and not p.admission and __xpWrites==0)
a,p=begin();__sourceStartSeating(a);p.status='abandoned';__sourceEndSeating(a);SAO.LeisurePreparation.advance('person',__body)
check('Q_retirement_cancels_seating',__records.person.leisurePreparation.status=='interrupted' and __records.person.leisureSeating.status=='interrupted' and not __body:isSittingOnFurniture())
a=begin();__sourceStartSeating(a);SAO.LeisurePreparation.interrupt('person',__body,'urgent owned need');__sourceEndSeating(a)
check('Q_urgent_interrupt_cancels_source_queue',__records.person.leisurePreparation.status=='interrupted' and __records.person.leisureSeating.status=='interrupted' and not ISTimedActionQueue.hasAction(a))
a=begin();__sourceStartSeating(a);__reloadPreparation();__sourceEndSeating(a)
check('Q_reload_no_seating_completion',__records.person.leisurePreparation.status=='interrupted' and __records.person.leisureSeating.status=='interrupted' and not __body:isSittingOnFurniture())
check('Q_clock_and_XP_unchanged',__clockWrites==0 and __xpWrites==0)
print('PASS seating join '..checks)
