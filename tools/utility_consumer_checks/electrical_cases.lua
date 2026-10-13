local E=SAO.ElectricalService;local count=0;local results={}
local function check(name,value)print('CHECK '..name..'='..tostring(value==true));assert(value,name);count=count+1 end
local fact={sourceId='human-direct',fingerprint='human-direct'}
local function measure()return E.measure(body,generator,consumer,fact)end
local first=measure();assert(first,'current bridge native measurement');results.first=first
print('BILL part='..first.partRate..' group='..first.groupRate..' count='..first.partCount..' bill='..first.totalRate)
check('real_multipart',first.partCount>1 and first.groupRate>=first.partRate)
check('native_power_and_coverage',first.active and first.connected and first.powered and first.covered)
local opening=__native('facts');check('native_multipart_bill_matches_both_parts',math.abs(first.totalRate-opening.base-first.groupRate*opening.fuelScale)<.00001);__native('hour');local burned=__native('facts');results.opening=opening;results.burned=burned
check('native_hour_burn_once',math.abs(opening.fuel-burned.fuel-opening.bill)<.00001)
__native('update');local repeated=__native('facts');check('same_hour_no_second_burn',repeated.fuel==burned.fuel)
if CONTROL=='restore-fuel-revoke'then check('restored_fuel_guard_detected',not E.sameMeasurement(first,measure()));__native('dump',results);print('PASS detected restore-fuel-revoke '..count);return end
check('natural_burn_measurement_keeps_current',E.sameMeasurement(first,measure()))
local function context()return {options={},addOption=function(self,label,b,fn,...)local row={label=label,body=b,fn=fn,args={...}};self.options[#self.options+1]=row;return row end}end
local select=context();SAO.ElectricalMenu.fill(0,select,{generator},false);check('actual_generator_menu_selection',#select.options==2);select.options[1].fn(select.options[1].body,unpack(select.options[1].args))
local function finish(operation,midHour)
 local menu=context();SAO.ElectricalMenu.fill(0,menu,{consumer},false);local option
 for _,row in ipairs(menu.options)do if row.args[#row.args]==operation then option=row end end
 check(operation..'_menu_callback',option~=nil)
 check(operation..'_human_ingress',option.fn(option.body,unpack(option.args))==true)
 local q=ISTimedActionQueue.getTimedActionQueue(body);local a=q.current;check(operation..'_original_current_queue',a and q.queue[1]==a and a.action and a.action:getTable()==a)
 check(operation..'_native_started',__native('start',a.action)==true)
 if midHour then local before=__native('facts');local after;local hours=0
  repeat __native('hour');hours=hours+1;after=__native('facts');assert(a:isValid(),'current action survives native progression')until after.condition<before.condition or hours>=256
  check(operation..'_burn_during_work',after.fuel<before.fuel and a:isValid());check(operation..'_natural_wear_keeps_current',after.condition<before.condition and a:isValid());check(operation..'_native_hours_conserved',after.hours-before.hours==hours and math.abs(before.fuel-after.fuel-before.bill*hours)<.0002);results.during={before=before,after=after,hours=hours};print('NATIVE_WEAR hours='..hours..' condition='..before.condition..'->'..after.condition..' fuel='..before.fuel..'->'..after.fuel)
 end
 check(operation..'_native_timer_finished',__native('finish',a.action)==true)
 local rows=body:getModData().electricalServiceOutcomes;local row=rows and rows[#rows];results[operation]=row
 if operation=='shed-load'and CONTROL=='omit-native-toggle'then check('omitted_native_toggle_detected',row and row.status=='failed'and not row.nativeCompleted and not row.nativeCredit and consumer:Activated());return false end
 check(operation..'_native_effect',row and row.status=='completed'and row.nativeCompleted and row.nativeCredit==row.id and E.effect(operation,row.before,row.after));return true
end
if finish('shed-load',true)==false then __native('dump',results);print('PASS detected omit-native-toggle '..count);return end
check('original_stove_toggle_effect',not consumer:Activated()and measure().groupRate==0)
__native('bill');results.afterShed=measure();check('native_bill_recomputed_after_shed',results.afterShed.totalRate<first.totalRate)
__native('move',11,20);consumer=generator;finish('breaker-open',false)
check('original_breaker_open_effect',not generator:isActivated()and E.breakerOpen(generator))
finish('breaker-reset',false)
check('original_breaker_reset_effect',generator:isActivated()and not E.breakerOpen(generator))
results.final=__native('facts');__native('dump',results);print('PASS native D6 service '..count)
