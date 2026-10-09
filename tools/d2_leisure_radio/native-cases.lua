local count=0
local function check(name,value)if not value then error('D2_NATIVE_RADIO:'..name)end;count=count+1;print('CHECK '..name)end
local R,S=SAO.LeisureRadio,SAO.LeisureSkill
__records={person={id='person'}};__owned=true;__familiar=true;__admit=true;__hours=10;__nativeHours=10;__events={};__queue={};__delta=0
__registers=0;__unregisters=0;__consumed=0;__registerAllowed=true;__eventCurrent=true;__sourceDrift=false;__frame=100
__body:getModData().SAOPersonId='person';__body:getModData().SAOExternalToken='native-radio:1'
SAO.Body={get=function(id)return id=='person'and __body or nil end}
SAO.Needs.ownsRecoveryBody=function(id,body)return id=='person'and body==__body and not body:isDead()end
SAOJavaBridge.privateCarriedItems=function()return {size=function()return 0 end}end
__objects={{key='object:radio',actorId='person',runtimeInstance='native-radio-object'}}
SAO.Perception.resolveLeisureObject=function(id,body,key)return id=='person'and body==__body and key=='object:radio'and __nativeRadio or nil end
SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)
 local w=R.work(id);if __admit and w and w.workId==wid and w.purposeId==pid then w.ownerName='SAO.LeisureRadio';return w end
end
getCell=function()return __body:getCell()end
local stats=__body:getStats();stats:set(CharacterStat.BOREDOM,40);stats:set(CharacterStat.UNHAPPINESS,30)
local perk=Perks.Woodwork;__body:setPerkLevelDebug(perk,0)
check('actual_offslot_native_radio_and_actor',__body:getPlayerNum()==1 and __body:isExistInTheWorld()
 and instanceof(__nativeRadio,'IsoRadio')and __nativeRadio:getSquare():getObjects():contains(__nativeRadio))
local function begin()
 local row=assert(R.offers('person',__body)[1]);local ok,w=R.begin('person',__body,row,'purpose');assert(ok,tostring(w));return w
end
local w=begin();local prior=__body:getXp():getXP(perk)
__events={{actorId='person',workId=w.workId,sourceKey='object:radio',sequence=1,atHours=10,text='actual receiver host line',
 guid='native-line:1',codes='CRP+2,BOR-1',channel=88000,mediaIndex=__nativeRadio:getDeviceData():getMediaIndex(),x=-1,y=-1,z=-1,
 authority='native-emission-current-owned-receiver'}}
R.advance('person',__body)
local seq=__records.person.leisureRadioSkillSequence;local receipt=seq and S.receipt('person','SAO.LeisureRadio',w.sequence,seq)
check('joined_native_radio_XP',receipt and receipt.status=='applied'and __body:getXp():getXP(perk)>prior)
check('actual_source_native_stats_effect',stats:get(CharacterStat.BOREDOM)==35)
check('actual_source_native_known_guid',__body:isKnownMediaLine('native-line:1'))
check('actual_source_line_terminal',R.outcome('person',w.sequence).status=='completed'and R.outcome('person',w.sequence).nativeProgress.heardLines==1)
local applied=__body:getXp():getXP(perk);w=begin()
__events={{actorId='person',workId=w.workId,sourceKey='object:radio',sequence=2,atHours=10,text='same actual received line',
 guid='native-line:1',codes='CRP+2,BOR-1',channel=88000,mediaIndex=__nativeRadio:getDeviceData():getMediaIndex(),x=-1,y=-1,z=-1,
 authority='native-emission-current-owned-receiver'}}
R.advance('person',__body)
check('native_known_guid_prevents_replayed_XP_and_stats',__body:getXp():getXP(perk)==applied and stats:get(CharacterStat.BOREDOM)==35)
check('native_source_exact_request_rate_and_provenance',receipt.amount==100 and receipt.receiverSourceId=='native:ISRadioInteractions:doSkill'
 and receipt.nativeProgress.nativeEmissionSequence==1 and receipt.nativeProgress.sourceCallback=='update')
for n=1,31 do R.onNativeTick()end
check('native_source_cooldown_actual_ticks',__records.person.leisureRadioCooldowns[2].CRP<=0)
__body:removeKnownMediaLine('native-line:1');__body:setPerkLevelDebug(perk,10);w=begin()
__events={{actorId='person',workId=w.workId,sourceKey='object:radio',sequence=3,atHours=10,text='cutoff actual receiver',
 guid='native-line:cutoff',codes='CRP+2',channel=88000,mediaIndex=__nativeRadio:getDeviceData():getMediaIndex(),x=-1,y=-1,z=-1,
 authority='native-emission-current-owned-receiver'}}
R.advance('person',__body)
check('native_level_cutoff_no_request',__records.person.leisureRadioSkillSequence==seq and __body:isKnownMediaLine('native-line:cutoff'))
local data=__nativeRadio:getDeviceData();data:setIsTurnedOn(false);data:setPower(0);data:setHasBattery(false)
__nativeBattery:setCurrentUses(75);__body:getInventory():AddItem(__nativeBattery)
local nativeFirstCharge=__nativeBattery:getCurrentUsesFloat()
SAOJavaBridge.privateCarriedItems=function(_,body)return body:getInventory():getItems()end
w=begin();check('native_battery_missing_queues_insert_then_power',#__queue==2 and __queue[1].isRemove==false and __queue[1].secondaryItem==__nativeBattery)
__runActions()
print('NATIVE_BATTERY inserted='..tostring(data:getHasBattery())..' power='..tostring(data:getPower())..' on='..tostring(data:getIsTurnedOn())
 ..' custody='..tostring(__body:getInventory():contains(__nativeBattery))..' work='..tostring(R.work('person')~=nil)
 ..' reason='..tostring(R.outcome('person',w.sequence)and R.outcome('person',w.sequence).reason))
check('native_battery_original_insert_power_and_custody',data:getHasBattery()and math.abs(data:getPower()-nativeFirstCharge)<.00001 and data:getIsTurnedOn()
 and not __body:getInventory():contains(__nativeBattery)and R.work('person')and __body:getXp():getXP(perk)==applied)
R.interrupt('person',__body,'battery-qualification-boundary')
data:setPower(0);data:setIsTurnedOn(false)
local spare=__body:getInventory():AddItem('Base.Battery');spare:setCurrentUses(60)
local nativeSecondCharge=spare:getCurrentUsesFloat()
w=begin();check('native_depleted_battery_queues_original_remove_insert',#__queue==3 and __queue[1].isRemove==true and __queue[2].secondaryItem==spare)
__runActions()
check('native_depleted_battery_physical_replacement',data:getHasBattery()and math.abs(data:getPower()-nativeSecondCharge)<.00001 and data:getIsTurnedOn()
 and not __body:getInventory():contains(spare)and __body:getInventory():getItems():size()==1)
local removed=__body:getInventory():getItems():get(0)
check('native_removed_empty_battery_retained',removed:getFullType()=='Base.Battery'and removed:getCurrentUsesFloat()==0)
check('native_battery_preparation_is_not_heard_success',R.work('person')and not R.outcome('person',w.sequence)
 and R.work('person').nativeProgress.nativeBatteryPreparation.inserted)
R.interrupt('person',__body,'native-proof-complete')
print('PASS native source radio '..count)
