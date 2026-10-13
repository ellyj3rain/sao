local function electricalReviewCases()
local id='electrical-cook';local rec=__record;local npc=body;local G,P,E=SAO.Generator,SAO.ProceduralPlanning,SAO.ElectricalService;local count=0
local function check(n,v)print('CHECK '..n..'='..tostring(v==true));assert(v,n);count=count+1 end
local function fact(prefix)for _,place in pairs(SAO.Perception.knownPlaces(id,true))do for _,f in pairs(place.sourceFacts or{})do if(f.sourceId or f.id):sub(1,2)==prefix then local x={}for k,v in pairs(f)do x[k]=v end;x.sourceId=f.sourceId or f.id;return x end end end end
local function context(intent)return {intent=intent,options=G.options(id,body,intent),sources={},pressure=.8,position={x=body:getX(),y=body:getY(),z=0},tick=SAO.History.ticks(),atHours=SAO.History.countyHours()}end
local function finish(action)check('original_native_started_'..count,__native('start',action.action));check('original_native_clock_'..count,__native('finish',action.action))end
__native('move',11,20);check('native_consumer_acquired',SAO.Perception.rememberGeneratorConsumer(id,body,consumer));check('native_generator_acquired',SAO.Perception.observeGenerators(id,body,SAO.History.ticks()))
local intent={consumer=fact('E:'),managedElectrical=true,electricalOperation='shed-load',requestingActivity='maintain observed appliance load'}
local purpose,step=P.planGenerator(id,context(intent));check('npc_actual_inspection_selected',step and step.operation=='inspect-load');check('npc_inspection_admitted',G.begin(id,body,step,{purposeId=purpose.id,purposeStepId=step.id}));local q=ISTimedActionQueue.getTimedActionQueue(body);finish(q.current);check('npc_inspection_completed',G.outcome(id,rec.generatorSequence).status=='completed')
intent=purpose.generatorPower;purpose,step=P.planGenerator(id,context(intent));check('npc_actual_shed_selected',step and step.operation=='shed-load');check('npc_shed_admitted',G.begin(id,body,step,{purposeId=purpose.id,purposeStepId=step.id}));q=ISTimedActionQueue.getTimedActionQueue(body);local shed=q.current;local target=shed.object;shed.object=__native('other-part',target)
if CONTROL=='omit-receiver'then finish(shed);local unsafe=G.outcome(id,rec.generatorSequence);__native('dump','receiver-control',{row=unsafe,record=rec});check('npc_receiver_tamper_refused',unsafe.status~='completed');return end
check('npc_receiver_tamper_refused',shed:isValid()==false);shed.object=target;finish(shed);local shedrow=G.outcome(id,rec.generatorSequence)
check('npc_original_shed_effect',shedrow.status=='completed'and shedrow.nativeCredit==shedrow.id and shedrow.electricalService.after.groupRate<shedrow.electricalService.before.groupRate and not target:Activated())
local human=__native('human');check('actual_local_human',not SAOJavaBridge:isShell(human)and getSpecificPlayer(0)==human and human:isExistInTheWorld());check('human_normal_admitted',E.beginHuman(body,generator,generator,'breaker-open'));q=ISTimedActionQueue.getTimedActionQueue(body);local normal=q.current;check('human_retained_native_started',__native('start',normal.action));check('human_early_perform_refused',normal:perform()==false and normal:complete()==false and generator:isActivated())
local originalGenerator,originalActivate=normal.generator,normal.activate;normal.generator=__native('other-generator');normal.activate=true
check('human_receiver_tamper_refused',normal:isValid()==false and normal:perform()==false);normal.generator,normal.activate=originalGenerator,originalActivate;check('human_original_clock',__native('finish',normal.action));local rows=body:getModData().electricalServiceOutcomes
check('human_normal_endpoint_effect',not generator:isActivated()and rows[#rows].nativeCompleted and rows[#rows].nativeCredit==rows[#rows].id)
__holdPrestart=true;check('human_prestart_admitted',E.beginHuman(body,generator,generator,'inspect-load'));q=ISTimedActionQueue.getTimedActionQueue(body);local obsolete=q.current;print('PRESTART_NATIVE',obsolete.action:isStarted(),body:getCharacterActions():contains(obsolete.action));check('human_actual_never_started',not obsolete.action:isStarted()and body:getCharacterActions():contains(obsolete.action));local retained=obsolete.action;obsolete.action=__native('duplicate-native',obsolete);check('human_swapped_actual_native_refused',obsolete:start()==false and obsolete:create()==false);obsolete.action=retained;__native('stop-native');check('human_original_stop_removed_instance',not body:getCharacterActions():contains(obsolete.action));q:tick();rows=body:getModData().electricalServiceOutcomes
check('human_prestart_interrupted_retired',not body:getModData().resourceProductionWork and not q.current and #q.queue==0 and rows[#rows].status=='interrupted'and not rows[#rows].nativeCredit)
check('human_successor_usable',E.beginHuman(body,generator,generator,'inspect-load'));local successor=q.current;local successorWork=body:getModData().resourceProductionWork;local beforeRows=#rows
check('human_obsolete_callbacks_inert',obsolete:isValid()==false and obsolete:start()==false and obsolete:perform()==false and obsolete:complete()==false and obsolete:stop()==false and obsolete:forceCancel()==false and q.current==successor and body:getModData().resourceProductionWork==successorWork and #rows==beforeRows)
__native('stop-native');q:tick();check('human_successor_cleanup',not body:getModData().resourceProductionWork)
check('original_human_breaker_reset_admitted',E.beginHuman(body,generator,generator,'breaker-reset'));q=ISTimedActionQueue.getTimedActionQueue(body);finish(q.current);check('owned_open_marker_retired',generator:isActivated()and not E.breakerOpen(generator));local switch=ISActivateGenerator:new(body,generator,false);ISTimedActionQueue.add(switch);finish(switch);check('original_switch_off_for_legacy_case',not generator:isActivated()and not E.breakerOpen(generator))
__native('body',npc);local food=__native('item');local fp,fs=P.planResource(id,{category='food',pressure=.8,needs={hunger=.8,fatigue=0,health=1},canWork=true,carriedRaw=1,carriedReady=0,carriedRawItems={{itemId=food:getID(),itemType=food:getFullType(),cookable=food:isCookable()}},sources={},position={x=body:getX(),y=body:getY(),z=0},atHours=SAO.History.countyHours(),tick=SAO.History.ticks()});check('real_pending_food_parent',fp and fs and fs.owner=='Cooking')
local demand=SAO.Cooking.powerDemand(id,body,{purposeId=fp.id,acquiredItemId=food:getID(),privateFood=true});check('actual_original_unpowered_request',demand~=nil);demand.managedElectrical=true;demand.generator=shedrow.generatorAfter;check('new_generator_state_acquired',SAO.Perception.observeGenerators(id,body,SAO.History.ticks()))
local op,st=P.planGenerator(id,context(demand));print('LEGACY_STAGE_SELECTED',st and st.operation)
if st and st.operation=='inspect-load'then check('current_original_request_inspection',G.begin(id,body,st,{purposeId=op.id,purposeStepId=st.id}));finish(ISTimedActionQueue.getTimedActionQueue(body).current);demand=op.generatorPower;op,st=P.planGenerator(id,context(demand))end
check('legacy_activation_selected',st and st.operation=='activate');check('managed_legacy_activation_admitted',G.begin(id,body,st,{purposeId=op.id,purposeStepId=st.id}));q=ISTimedActionQueue.getTimedActionQueue(body);local activate=q.current;local priorRevision=fp.revision
P.maintain(id,{key=fp.key,objective=fp.objective..' with revised private intent',domain=fp.domain,atHours=SAO.History.countyHours()});check('original_parent_revision_changed',fp.revision>priorRevision)
check('managed_legacy_revocation_refuses_effect',not activate:isValid()and activate:perform()==false and not generator:isActivated());__native('stop-native');q:tick();G.tick(id,body);local rejected=G.outcome(id,rec.generatorSequence)
check('managed_legacy_revocation_no_credit',rejected and rejected.status=='interrupted'and not rejected.nativeCompleted and not rejected.nativeCredit and not rec.resourceProductionWork)
__native('dump','review-corrections',{record=rec,human=human:getModData(),native=__native('facts')});print('PASS bounded native review corrections '..count)

end
local function sourceProductionReview()
local id='electrical-cook';local rec=__record;local Ctl,P,G,E,Per=SAO.Controller,SAO.ProceduralPlanning,SAO.Generator,SAO.ElectricalService,SAO.Perception;local agent=Ctl.agents[id];local count=0;local data={}
local function check(n,v)print('CHECK '..n..'='..tostring(v==true));assert(v,n);count=count+1 end
local function finish(a)check('actual_native_start_'..count,__native('start',a.action));check('actual_native_clock_'..count,__native('finish',a.action))end
local function advance()return Ctl.advanceGeneratorPurpose(id,agent,body,SAO.History.ticks(),SAO.Needs.read(body))end
local function idleScheduler()agent.state='IDLE';__native('clock-step')end -- declared state scheduling / original native clock endpoint
__native('move',11,20);check('actual_private_supply',Per.observeGenerators(id,body,SAO.History.ticks()));__native('move',17,20)
check('unseen_consumer_no_intent',Ctl.electricalControlIntent(id,body)==nil);check('actual_empty_consumer_acquired',Per.rememberGeneratorConsumer(id,body,consumer));check('actual_idle_physical_inspection',E.idleConsumer(body,consumer,id)==true)
local proposed=Ctl.electricalControlIntent(id,body);print('OBSERVED_CONTROL',proposed and proposed.electricalOperation);check('source_idle_control_intent',proposed and proposed.electricalOperation=='shed-load'and proposed.requestingActivity=='electrical-conservation')
local stock=__native('item');__native('stock-put',stock,consumer);check('occupied_refresh_original',Per.refreshElectricalConsumers(id,body));check('occupied_source_refusal',Ctl.electricalControlIntent(id,body)==nil);__native('stock-take',stock,consumer);Per.refreshElectricalConsumers(id,body)
check('source_default_idle_dispatch',advance());local purpose,step=P.generatorPurpose(id);check('source_default_inspection_selected',step and step.operation=='inspect-load');finish(ISTimedActionQueue.getTimedActionQueue(body).current);check('source_native_inspection_complete',G.outcome(id,rec.generatorSequence).status=='completed')
idleScheduler();check('source_default_shed_dispatch',advance());purpose,step=P.generatorPurpose(id);check('source_default_shed_selected',step and step.operation=='shed-load');local action=ISTimedActionQueue.getTimedActionQueue(body).current
__native('stock-put',stock,consumer);check('added_item_current_native_refusal',action:isValid()==false);__native('stop-native');ISTimedActionQueue.getTimedActionQueue(body):tick();G.tick(id,body);local blocked=G.outcome(id,rec.generatorSequence);check('added_item_no_effect_credit',blocked.status=='interrupted'and not blocked.nativeCredit and consumer:Activated());__native('stock-take',stock,consumer)
idleScheduler();check('source_idle_retry_dispatch',advance());purpose,step=P.generatorPurpose(id);finish(ISTimedActionQueue.getTimedActionQueue(body).current);local shed=G.outcome(id,rec.generatorSequence)
check('source_default_shed_effect_completed',shed.status=='completed'and shed.nativeCredit==shed.id and purpose.status=='completed'and shed.electricalService.before.covered and shed.electricalService.after.covered and shed.electricalService.after.groupRate<shed.electricalService.before.groupRate);data.shed=shed
idleScheduler();__native('move',11,22);check('private_indoor_hazard_acquired',Per.observeGenerators(id,body,SAO.History.ticks()));local safety=Ctl.electricalControlIntent(id,body);check('source_private_safety_intent',safety and safety.electricalOperation=='breaker-open'and safety.requestingActivity=='electrical-safety');check('source_safety_dispatch',advance());purpose,step=P.generatorPurpose(id);check('source_original_safety_open_selected',step and step.operation=='breaker-open');finish(ISTimedActionQueue.getTimedActionQueue(body).current);local opened=G.outcome(id,rec.generatorSequence);check('source_original_safety_open_completed',opened.status=='completed'and opened.nativeCredit==opened.id and purpose.status=='completed'and not __native('other-generator'):isActivated());data.open=opened
local npc=body;local human=__native('human');__native('move',17,20);local on=ISToggleStoveAction:new(body,consumer);ISTimedActionQueue.add(on);finish(on);local uncovered=__native('uncovered');local sample=E.measure(body,uncovered,consumer,{sourceId='human-direct',fingerprint='human-direct'});check('native_uncovered_measurement',sample and sample.consumerActive and not sample.covered)
local before=shed.electricalService.before;local after=shed.electricalService.after;local b,a={},{}for k,v in pairs(before)do b[k]=v end;for k,v in pairs(after)do a[k]=v end;b.covered=false;a.covered=false
check('uncovered_effect_refused',E.effect('shed-load',b,a)==false)
check('human_uncovered_shed_refused',E.beginHuman(body,uncovered,consumer,'shed-load')==false)
local ctx={options={},addOption=function(self,label,b,fn,...)local row={label=label,body=b,fn=fn,args={...}};self.options[#self.options+1]=row;return row end};SAO.ElectricalMenu.fill(0,ctx,{uncovered},false);ctx.options[1].fn(ctx.options[1].body,unpack(ctx.options[1].args));ctx.options={};SAO.ElectricalMenu.fill(0,ctx,{consumer},false);local offered=false;for _,row in ipairs(ctx.options)do if row.label=='Switch off appliance load'then offered=true end end;check('human_uncovered_menu_refused',not offered)
__native('body',npc);__native('move',17,20);Per.refreshElectricalConsumers(id,body);check('fresh_idle_intent_before_demand',Ctl.electricalControlIntent(id,body)~=nil)
local food,foodstep=P.planResource(id,{category='food',pressure=.8,needs={hunger=.8,fatigue=0,health=1},canWork=true,carriedRaw=1,carriedReady=0,carriedRawItems={{itemId=stock:getID(),itemType=stock:getFullType(),cookable=stock:isCookable()}},sources={},position={x=body:getX(),y=body:getY(),z=0},atHours=SAO.History.countyHours(),tick=SAO.History.ticks()});check('genuine_pending_food_demand',food and foodstep and foodstep.owner=='Cooking');check('current_food_demand_refuses_conservation',Ctl.electricalControlIntent(id,body)==nil)
data.record=rec;data.captureHours=SAO.History.countyHours();data.full=SAO.Cognition.snapshot(id,true);data.bounded=SAO.Cognition.snapshot(id,false);__native('dump','production-controls',data);print('PASS source production electrical controls '..count)

end
if __case=="review-corrections"then if CONTROL=="omit-receiver"then electricalReviewCases()else sourceProductionReview()end;return end
local id='electrical-cook';local rec=__record;local P,G,C=SAO.ProceduralPlanning,SAO.Generator,SAO.Cognition;local count=0
local function check(n,v)print('CHECK '..n..'='..tostring(v==true));assert(v,n);count=count+1 end
local function capture(name)__native('dump',name,{captureHours=SAO.History.countyHours(),record=rec,full=C.snapshot(id,true),bounded=C.snapshot(id,false),native=__native('facts'),stove=__native('stove'),beliefs=SAO.Perception.beliefs[id]})end
local food=__native('item');__food=food;check('actual_shell_food_environment',SAOJavaBridge:isShell(body)and food:getFullType()=='Base.MuttonChop'and body:getInventory():contains(food)and consumer:Activated()and not consumer:getContainer():isPowered())
__native('move',11,20)
local native={itemId=food:getID(),itemType=food:getFullType(),cookable=food:isCookable()}
local foodPurpose,foodStep=P.planResource(id,{category='food',pressure=.8,needs={hunger=.8,fatigue=0,health=1},canWork=true,carriedRaw=1,carriedReady=0,carriedRawItems={native},sources={},position={x=body:getX(),y=body:getY(),z=body:getZ()},atHours=SAO.History.countyHours(),tick=SAO.History.ticks()})
check('actual_retained_food_plan',foodPurpose and foodStep and foodStep.owner=='Cooking'and foodStep.acquiredItemId==food:getID())
__foodPurpose=foodPurpose
local demand=SAO.Cooking.powerDemand(id,body,{purposeId=foodPurpose.id,acquiredItemId=food:getID(),privateFood=true})
check('original_cooking_unpowered_demand',demand and demand.consumer.powered==false and demand.foodItemId==food:getID())
demand.managedElectrical=true
check('actual_private_source_acquisition',SAO.Perception.observeGenerators(id,body,SAO.History.ticks())and SAO.Perception.knownPlaces(id,true)~=nil)
capture('opening')
local finalPurpose,finalStep
for iteration=1,6 do
 local options=G.options(id,body,demand);local purpose,step=P.planGenerator(id,{intent=demand,options=options,sources={},pressure=.8,position={x=body:getX(),y=body:getY(),z=body:getZ()},tick=SAO.History.ticks(),atHours=SAO.History.countyHours()})
 print('PLAN',iteration,step and step.operation,purpose and purpose.status,#options)
 check('plan_'..iteration,purpose and step and step.owner=='SAO.Generator'and step.status=='available')
 local go=SAO.WorldSources.generatorObject(body,step.generator,step.operation);local co=SAO.WorldSources.generatorConsumerObject(body,step.consumer)
 local ok,load=pcall(function()return SAOJavaBridge:worldElectricalLoad(body,step.consumer.sourceId,step.consumer.fingerprint,co)end)
 print('NATIVE_DIAGNOSTIC',SAO.WorldSources.generatorTarget(body,step.generator,'inspect'),tostring(go),tostring(co),go and SAO.WorldSources.generatorValid(body,go,step.generator,step.operation),ok,type(load),go and co and SAO.ElectricalService.measure(body,go,co,step.consumer),P.generatorRequestCurrent(id,{purposeId=purpose.id}))
 __native('dump','diagnostic-'..iteration,{load=ok and load or tostring(load),generatorCurrent=go~=nil,consumerCurrent=co~=nil,measurement=go and co and SAO.ElectricalService.measure(body,go,co,step.consumer),requestCurrent=P.generatorRequestCurrent(id,{purposeId=purpose.id})})
 if CONTROL=='changed-source'then
  check('actual_native_source_withdrawal',__native('remove-consumer',co))
  local rejected=G.begin(id,body,step,{purposeId=purpose.id,purposeStepId=step.id});local row=G.outcome(id,rec.generatorSequence)
  check('changed_source_refuses_native_credit',not rejected and row and row.status=='interrupted'and not row.nativeAttempted and not row.nativeCompleted and not row.nativeCredit)
  capture('changed-source');check('changed_source_no_cognitive_event',not rec.cognition or rec.cognition.eventSequence==0);print('PASS detected changed-source '..count);return
 end
 local before=#(rec.generatorOutcomes or{});local accepted=G.begin(id,body,step,{purposeId=purpose.id,purposeStepId=step.id})
 print('BEGIN',iteration,step.operation,accepted,rec.resourceProductionWork and rec.resourceProductionWork.stage)
 capture('before-stage-'..iteration)
 check('begin_'..iteration,accepted==true)
 if rec.resourceProductionWork and rec.resourceProductionWork.stage=='approaching'then G.tick(id,body)end
 local q=ISTimedActionQueue.getTimedActionQueue(body);local a=q.current
 if a then check('native_start_'..iteration,__native('start',a.action)==true);check('native_clock_'..iteration,__native('finish',a.action)==true)end
 G.tick(id,body)
 local row=G.outcome(id,rec.generatorSequence);print('OUTCOME',row and row.operation,row and row.status,row and row.detail,row and row.purposeDelivered,row and row.experienceDelivered)
 capture('after-stage-'..iteration)
 check('canonical_delivery_'..iteration,row and row.status=='completed'and row.nativeCredit==row.id and row.purposeDelivered and row.experienceDelivered and #(rec.generatorOutcomes or{})==before+1)
 local events=rec.cognition.eventSequence;local experiences=#rec.cognition.experiences;G.tick(id,body);P.consumeGeneratorOutcome(id,row.sequence);G.onOutcome(id,G.outcome(id,row.id))
 check('once_no_replay_credit_'..iteration,rec.cognition.eventSequence==events and #rec.cognition.experiences==experiences and #(rec.generatorOutcomes or{})==before+1)
 finalPurpose,finalStep=purpose,step
 if step.operation=='verify-service'then break end
 demand=purpose.generatorPower
end
check('connected_native_service',generator:isActivated()and consumer:getContainer():isPowered()and finalStep.operation=='verify-service')
check('original_requested_parent_ready',P.poweredMeal(id)~=nil and foodPurpose.steps[foodPurpose.cursor].owner=='Cooking')
capture('completed-service')
local saved=__native('roundtrip',rec,'person');__native('dump','saved-person',saved)
__native('dump','completed-full',C.snapshot(id,true));__native('dump','completed-bounded',C.snapshot(id,false))
__native('roundtrip',C.snapshot(id,true),'completed-full');__native('roundtrip',C.snapshot(id,false),'completed-bounded')
print('PASS native ordinary service '..count)
