local Ph,body,count=SAO.Pharmacology,__realBody,0
local function check(name,value)
    print("CASE "..name.."="..tostring(value));assert(value,"PHARMA:"..name);count=count+1
end
local function close(a,b) return math.abs(a-b)<0.0001 end
local function stat(name) return body:getStats():get(CharacterStat[name]) end
local function put(name,n)body:getStats():set(CharacterStat[name],n)end
local function nativeOwner(delta,to,origin)
    if origin then
        for name,value in pairs(origin.stats)do put(name,value)end
        body:setAsleep(origin.sleeping)
    end
    return string.sub(__nativeMetabolism(delta),1,11)=="METABOLIZED"
end
local serial=0
local function fresh(at,habits)
    serial=serial+1;hours=at or 0
    local id="pharma-"..serial;local rec={id=id,drinks=7,lastUseHours={cocaine=0}}
    records[id]=rec;body:getModData().SAOPersonId=id
    body:getModData().SAOExternalOwner=nil;body:getModData().SAOExternalToken=nil
    body:getModData().ZAOOwned=nil;SAO.Body.foreign={}
    body:setAsleep(false)
    body:setSitOnGround(false)
    if SAO.PharmacologyProfiles.sensitivityTrait then
        body:getCharacterTraits():set(SAO.PharmacologyProfiles.sensitivityTrait,false)
    end
    SAO.Body.active={[id]=body}
    SAO.Habits.assert(id,habits or {})
    for _,name in ipairs(SAO.PharmacologyProfiles.stats) do put(name,0) end
    put("HUNGER",.5);put("THIRST",.5);put("FATIGUE",.5);put("ENDURANCE",.5)
    local parts=body:getBodyDamage():getBodyParts()
    for index=0,parts:size()-1 do parts:get(index):setAdditionalPain(0);parts:get(index):setStiffness(0) end
    return rec
end
local function take(rec,name)
    local item=__copyNativeItem("SAO."..name)
    local action=ISTakePillAction:new(body,item)
    assert(action,"native action "..name)
    action:start()
    local token=action.saoPharmacologyToken
    assert(token,"native start admission "..name)
    local before=item:getCurrentUses()
    action:perform()
    local result=action:complete()
    local events=rec.pharmacology.events
    local receipt=events[#events]
    assert(result==true and receipt and receipt.status=="completed" and receipt.sequence==token.sequence,
        "completion "..name..":"..tostring(before)..":"..tostring(item:getCurrentUsesFloat()))
    return receipt,token,item
end
local function advance(rec,minutes,loaded)
    hours=hours+minutes/60
    local actualBody=body;if loaded==false then actualBody=nil end
    local ran,ok,reason=pcall(Ph.advance,rec,actualBody,hours)
    assert(ran and ok,"advance:"..tostring(ok)..":"..tostring(reason))
end
check("external_globals_absent",BenzoEffect==nil and OpioidEffect==nil and NnCReg==nil
    and CokeHead==nil and SteroidEffect==nil and NnCPainRemoval==nil)
local rec=fresh()
local function drinkItem(fluid,amount,portion)
    local item=__copyNativeItem("Base.WaterBottle")
    local container=item:getFluidContainer();container:Empty()
    if amount>0 then container:addFluid(fluid,amount) end
    return ISDrinkFluidAction:new(body,item,portion or 1),item,container
end
local drink,bottle,fluid=drinkItem(Fluid.Whiskey,.5)
drink:start();drink:updateEat(.25)
check("native_partial_alcohol_counted",fluid:getAmount()<.5 and stat("INTOXICATION")>0
    and rec.drinks==8 and rec.drinksToday==1)
drink:stop()
check("interrupted_real_drink_retained",rec.drinks==8 and rec.drinksToday==1)
drink:perform();drink:complete();drink:complete()
check("partial_then_complete_not_recounted",fluid:isEmpty() and rec.drinks==8 and rec.drinksToday==1)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,.25)
drink:start();drink:perform();drink:complete()
check("last_alcohol_fluid_counted",fluid:isEmpty() and rec.drinks==8 and rec.drinksToday==1)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,.5)
drink:updateEat(0)
check("callback_without_fluid_loss_not_counted",close(fluid:getAmount(),.5) and rec.drinks==7 and rec.drinksToday==nil)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Water,.5)
drink:complete()
check("native_water_not_alcohol",fluid:isEmpty() and rec.drinks==7 and rec.drinksToday==nil)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,0)
drink:complete()
check("empty_fluid_not_counted",fluid:isEmpty() and rec.drinks==7 and rec.drinksToday==nil)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,.5)
SAO.Body.active={};drink:complete()
check("unowned_body_drink_not_attributed",fluid:isEmpty() and rec.drinks==7 and rec.drinksToday==nil)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,.5)
body:getInventory():Remove(bottle);__otherBody:getInventory():AddItem(bottle)
drink:complete()
check("foreign_carried_fluid_not_attributed",close(fluid:getAmount(),.5) and rec.drinks==7 and rec.drinksToday==nil)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,.5)
__afterNativeFluidUpdate=function()SAO.Body.active={} end
drink:complete();__afterNativeFluidUpdate=nil
check("changed_owner_drink_not_attributed",fluid:isEmpty() and rec.drinks==7 and rec.drinksToday==nil)
rec=fresh();drink,bottle,fluid=drinkItem(Fluid.Whiskey,.5)
__afterNativeFluidUpdate=function()error("native-fluid-after-effect-error")end
local drinkOk,drinkError=pcall(drink.updateEat,drink,.25);__afterNativeFluidUpdate=nil
check("native_drink_error_preserved",not drinkOk and string.find(tostring(drinkError),"native-fluid-after-effect-error",1,true)~=nil)
check("real_partial_before_error_counted",fluid:getAmount()<.5 and rec.drinks==8 and rec.drinksToday==1)
rec=fresh()
local nitems=0
for name in pairs(__ownedItems) do
    local _,token,item=take(rec,name)
    check("native_item_"..name,item:getCurrentUses()==token.beforeUses-1)
    check("native_family_"..name,SAOJavaBridge:drugFamilyOf(item)==SAO.PharmacologyProfiles.items[item:getFullType()].family)
    nitems=nitems+1
end
check("all_owned_profiles_exist",nitems==15)
rec=fresh();queued=nil
check("owned_native_selector_queues_action",SAO.Needs.useCarriedDrug(rec.id,body,"sedatives")
    and queued and queued.Type=="ISTakePillAction")
queued:start();queued:perform();local selected=queued.item;local selectedUses=selected:getCurrentUses()
check("owned_selector_native_complete",queued:complete()==true and selected:getCurrentUses()==selectedUses-1
    and rec.pharmacology.families.sedatives.effect>0)

rec=fresh();put("PANIC",70);put("STRESS",.6);put("NICOTINE_WITHDRAWAL",70)
take(rec,"SedativeTablets");advance(rec,1)
check("sedative_native_effect",stat("PANIC")==0 and stat("STRESS")==0 and stat("NICOTINE_WITHDRAWAL")==0)
check("sedative_history_preserved",rec.drinks==7 and rec.lastUseHours.sedatives==0)

rec=fresh();take(rec,"Cocaine");advance(rec,1)
check("cocaine_native_effect",close(stat("FATIGUE"),.49) and close(stat("ENDURANCE"),.51)
    and close(stat("HUNGER"),.49) and close(stat("THIRST"),.501))
local value=stat("FATIGUE");Ph.advance(rec,body,hours)
check("same_minute_no_replay",stat("FATIGUE")==value)

rec=fresh();take(rec,"Stimulant");advance(rec,9)
check("native_onset_waits",close(stat("FATIGUE"),.5))
advance(rec,1)
check("stimulant_native_effect",close(stat("FATIGUE"),.49))

rec=fresh();local head=body:getBodyDamage():getBodyPart(BodyPartType.Head)
head:setAdditionalPain(20);head:setStiffness(10);put("PAIN",30)
take(rec,"Opioid");advance(rec,1)
check("opioid_native_effect",close(stat("FATIGUE"),.51) and close(stat("ENDURANCE"),.49))
check("pain_suppression_native_receiver",stat("PAIN")==0 and head:getAdditionalPain()==0 and head:getStiffness()==0)

rec=fresh();take(rec,"PsychoactiveTablets");advance(rec,30)
check("psychedelic_native_effect",stat("FATIGUE")<.5 and stat("THIRST")>.5)
rec=fresh();put("PANIC",50);put("STRESS",.8);take(rec,"CannabisEdible");advance(rec,20)
check("cannabis_native_effect",stat("HUNGER")>.5 and stat("PANIC")==0 and stat("STRESS")==0)
rec=fresh();take(rec,"SteroidTablets");advance(rec,10)
check("steroid_native_effect",stat("FATIGUE")<.5 and stat("ANGER")>0 and stat("UNHAPPINESS")>0)

rec=fresh();take(rec,"Opioid");take(rec,"SedativeTablets");put("INTOXICATION",10);advance(rec,1)
check("combined_native_depressant_effect",stat("FATIGUE")>.6 and stat("ENDURANCE")<.4 and stat("INTOXICATION")>10)
rec=fresh();for i=1,10 do take(rec,"Opioid") end;advance(rec,1)
check("overload_native_effect",stat("FATIGUE")>.59 and stat("UNHAPPINESS")>0 and Ph.effects(rec).overload)
rec=fresh();take(rec,"Cocaine");body:setAsleep(true);advance(rec,10)
check("sleep_suppresses_active_packets",close(stat("FATIGUE"),.5) and rec.pharmacology.families.cocaine.effect==14)
body:setAsleep(false)

rec=fresh(72,{cocaine=true})
Ph.advance(rec,body,hours)
check("existing_dependency_migrates",Ph.dependent(rec,"cocaine") and SAO.Habits.has(rec.id,"cocaine"))
advance(rec,60)
check("withdrawal_native_effect",stat("FATIGUE")>.5 and stat("ENDURANCE")<.5 and stat("STRESS")>0)
local drift=SAO.Habits.drift(rec.id,hours,1)
check("withdrawal_not_double_counted",drift.STRESS==nil and drift.FATIGUE==nil)

rec=fresh();for i=1,8 do take(rec,"CocainePure") end;advance(rec,10)
check("use_acquires_dependency",Ph.dependent(rec,"cocaine") and rec.habitsGained.cocaine)
local f=rec.pharmacology.families.cocaine
f.effect=0;f.amount=0;f.counter=2879
advance(rec,10)
check("abstinence_retires_dependency",not Ph.dependent(rec,"cocaine") and rec.habitsQuit.cocaine)

rec=fresh(72,{opioids=true});Ph.advance(rec,body,hours)
local beforeCounter=rec.pharmacology.families.opioids.counter
take(rec,"MaintenanceTablets");local beforeClean=SAO.Habits.cleanDays(rec.id,"opioids",hours)
advance(rec,20)
check("maintenance_pauses_dependency",rec.pharmacology.families.opioids.counter==beforeCounter
    and close(SAO.Habits.cleanDays(rec.id,"opioids",hours),beforeClean) and stat("STRESS")==0)
rec.pharmacology.maintenance=1;advance(rec,10)
check("maintenance_resumes_exact_clock",rec.useFrozen.opioids==nil
    and close(SAO.Habits.cleanDays(rec.id,"opioids",hours),beforeClean))

rec=fresh();local item=__copyNativeItem("SAO.OpioidTablets")
local token=Ph.captureUse(rec.id,body,item)
check("capture_has_no_exposure",rec.pharmacology.families.opioids.effect==0)
check("unconsumed_native_action_refused",Ph.completeUse(token,body,true)==nil
    and rec.pharmacology.families.opioids.effect==0)
token=Ph.captureUse(rec.id,body,item);item:Use()
check("native_failure_censored",Ph.completeUse(token,body,false)==nil and rec.pharmacology.families.opioids.effect==0)
local receipt,done=take(rec,"OpioidTablets")
local amount=rec.pharmacology.families.opioids.amount
check("repeated_completion_idempotent",Ph.completeUse(done,body,true)==nil and rec.pharmacology.families.opioids.amount==amount)
token=Ph.captureUse(rec.id,body,item)
check("interruption_censored",Ph.interruptUse(token,"threat") and Ph.completeUse(token,body,true)==nil)
local other=fresh();check("foreign_item_owner_refused",Ph.completeUse(done,body,true)==nil)
body:getInventory():Remove(item)
check("noncarried_item_refused",Ph.captureUse(other.id,body,item)==nil)

rec=fresh();take(rec,"Cocaine");advance(rec,5)
local saved=Ph.snapshot(rec);local fatigue=stat("FATIGUE")
rec.pharmacology=saved
Ph.advance(rec,body,hours)
check("reload_cursor_no_repeat",stat("FATIGUE")==fatigue)
advance(rec,1)
check("reload_continues_active_effect",close(stat("FATIGUE"),fatigue-.01))
local snapshot=Ph.snapshot(rec);snapshot.families.cocaine.effect=0
check("snapshot_is_detached",rec.pharmacology.families.cocaine.effect>0)
local minute=rec.pharmacology.minute
check("clock_regression_refused",not Ph.advance(rec,body,hours-1) and rec.pharmacology.minute==minute)

rec=fresh();take(rec,"Cocaine");advance(rec,1)
local checkpoint=Ph.checkpoint(rec,body,hours)
check("checkpoint_stages_only",checkpoint and rec.pharmacology.dormant==nil)
rec.dormantFatigue=stat("FATIGUE");rec.dormantEndurance=stat("ENDURANCE");rec.dormantSleeping=false
check("dormancy_commit",Ph.enterDormancy(rec,checkpoint))
SAO.Body.active={}
local capturedFatigue=stat("FATIGUE")
hours=hours+1/60
check("dormant_clock_progresses",Ph.advance(rec,nil,hours))
check("dormant_does_not_write_old_body",stat("FATIGUE")==capturedFatigue
    and close(rec.dormantFatigue,capturedFatigue-.01))
rec.pharmacology=Ph.snapshot(rec)
SAO.Body.active={[rec.id]=body}
check("restored_native_effect",Ph.restore(rec,body,hours,nativeOwner) and close(stat("FATIGUE"),capturedFatigue-.01))
fatigue=stat("FATIGUE")
check("restore_exact_once",Ph.restore(rec,body,hours,nativeOwner) and stat("FATIGUE")==fatigue)

rec=fresh();take(rec,"Cocaine")
for i=1,80 do take(rec,"AttentionTablets") end
check("history_bounded_with_loss_count",#rec.pharmacology.events==64 and rec.pharmacology.dropped>0)
local function dataOnly(value,depth)
    local kind=type(value);if kind~="table" then return kind=="string" or kind=="number" or kind=="boolean" or kind=="nil" end
    if depth>12 then return false end
    for key,item in pairs(value) do if not dataOnly(key,depth+1) or not dataOnly(item,depth+1) then return false end end
    return true
end
check("durable_state_contains_no_native_handles",dataOnly(rec.pharmacology,0))
check("read_only_effect_projection",Ph.effects(rec) and #rec.pharmacology.events==64)
-- Native owner identity is more than a copied SAOPersonId field.
rec=fresh();take(rec,"Cocaine")
local staleItem=__copyNativeItem("SAO.Cocaine")
__otherBody:getModData().SAOPersonId=rec.id
SAO.Body.active[rec.id]=__otherBody
local oldFatigue=stat("FATIGUE")
check("stale_shell_capture_refused",Ph.captureUse(rec.id,body,staleItem)==nil)
check("stale_shell_advance_refused",not Ph.advance(rec,body,hours+1/60) and stat("FATIGUE")==oldFatigue)
check("stale_shell_checkpoint_restore_refused",Ph.checkpoint(rec,body,hours)==nil and not Ph.restore(rec,body,hours))
SAO.Body.active[rec.id]=body
rec.transitioning=true
check("transition_action_refused",Ph.captureUse(rec.id,body,staleItem)==nil and not Ph.advance(rec,body,hours))
check("owned_transition_checkpoint_admitted",Ph.checkpoint(rec,body,hours)~=nil)
rec.transitioning=nil

rec=fresh();rec.bodyOwner="ZAO";rec.bodyOwnerToken="external-1"
local md=body:getModData();md.SAOExternalOwner="ZAO";md.SAOExternalToken="wrong";md.ZAOOwned=true
SAO.Body.active={};SAO.Body.foreign[rec.id]=body
check("foreign_token_refused",Ph.captureUse(rec.id,body,staleItem)==nil)
md.SAOExternalToken=rec.bodyOwnerToken
check("foreign_owner_admitted",Ph.ownsBody(rec,body))
take(rec,"Cocaine");advance(rec,1)
check("foreign_native_effect",close(stat("FATIGUE"),.49))
local pending=Ph.captureUse(rec.id,body,staleItem);staleItem:Use()
rec.bodyOwnerToken="external-2";md.SAOExternalToken="external-2"
check("changed_token_completion_refused",Ph.completeUse(pending,body,true)==nil)
SAO.Body.active[rec.id]=body
check("ambiguous_owner_refused",not Ph.ownsBody(rec,body))
SAO.Body.active={}
SAO.Drugs.resetRuntimeForWorld();drugTick();hours=hours+1/60;drugTick()
check("foreign_loaded_driver",close(stat("FATIGUE"),.48))
oldFatigue=stat("FATIGUE");drugTick()
check("loaded_driver_exact_once",stat("FATIGUE")==oldFatigue)

rec=fresh(24);take(rec,"Cocaine");reloadDrugWorld();drugTick()
check("world_reset_no_old_interval",rec.drugDay==nil and close(stat("FATIGUE"),.5))
hours=hours+1/60;drugTick()
check("ordinary_loaded_driver",close(stat("FATIGUE"),.49))
local oldClient=isClient;function isClient()return true end
check("client_cannot_apply_physiology",not Ph.advance(rec,body,hours+1/60) and Ph.captureUse(rec.id,body,staleItem)==nil)
isClient=oldClient

rec=fresh();check("owned_sensitivity_registered",SAO.PharmacologyProfiles.sensitivityTrait~=nil)
body:getCharacterTraits():set(SAO.PharmacologyProfiles.sensitivityTrait,true)
take(rec,"Cocaine");advance(rec,1)
print("SENSITIVITY "..tostring(SAO.PharmacologyProfiles.sensitivityOf(body))..":"..tostring(rec.pharmacology.paranoid)..":"..stat("PANIC")..":"..stat("STRESS")..":"..stat("UNHAPPINESS"))
check("owned_sensitivity_native_effect",stat("PANIC")==25 and stat("STRESS")>.2 and stat("UNHAPPINESS")>0)

rec=fresh();local measured={}
Ph.onNativeChange=function(id,event)measured[#measured+1]={id=id,event=event}end
take(rec,"Cocaine");advance(rec,1)
check("authentic_physical_change_receipt",#measured==1 and measured[1].id==rec.id
    and measured[1].event.minute==1 and close(measured[1].event.stats.FATIGUE.before,.5)
    and measured[1].event.stats.FATIGUE.after==stat("FATIGUE") and measured[1].event.exposures.cocaine==1)
Ph.advance(rec,body,hours)
check("physical_change_not_repeated",#measured==1)
measured[1].event.stats.FATIGUE.after=99
check("physical_receipt_detached",rec.pharmacology.events[#rec.pharmacology.events].stats.FATIGUE.after~=99)
Ph.onNativeChange=nil
rec.pharmacology=__roundTrip(rec.pharmacology)
oldFatigue=stat("FATIGUE");Ph.advance(rec,body,hours)
check("native_save_reload_no_repeat",stat("FATIGUE")==oldFatigue)
advance(rec,1)
check("native_save_reload_continues",close(stat("FATIGUE"),oldFatigue-.01))

rec=fresh();take(rec,"Cocaine")
local cp=Ph.checkpoint(rec,body,hours)
check("save_checkpoint_keeps_live_mode",Ph.commitCheckpoint(rec,cp) and rec.pharmacology.dormant==nil)
advance(rec,1)
check("save_does_not_stop_live_effects",close(stat("FATIGUE"),.49))
local invalid=Ph.snapshot(rec).saved;invalid.stats.FATIGUE=nil
check("incomplete_checkpoint_refused",not Ph.enterDormancy(rec,invalid))
cp=Ph.checkpoint(rec,body,hours);Ph.enterDormancy(rec,cp);SAO.Body.active={}
rec.dormantFatigue=stat("FATIGUE");rec.dormantEndurance=stat("ENDURANCE");rec.dormantSleeping=false
rec.pharmacology=__roundTrip(rec.pharmacology);hours=hours+1/60
check("saved_dormant_continues",Ph.advance(rec,nil,hours) and close(rec.dormantFatigue,.48))
SAO.Body.active[rec.id]=body;rec.transitioning=true
check("owned_transition_restore_admitted",Ph.restore(rec,body,hours,nativeOwner) and close(stat("FATIGUE"),.48))
rec.transitioning=nil

rec=fresh();local smoke=__copyNativeItem("SAO.Cannabis")
local matches=__matches;body:getInventory():Remove(matches)
check("native_ignition_required",ISTakePillAction:new(body,smoke)==nil and rec.pharmacology==nil)
body:getInventory():AddItem(matches)
local action=ISTakePillAction:new(body,smoke);body:getInventory():Remove(matches)
local began=pcall(function()action:start()end)
check("native_start_failure_censored",not began and action.saoPharmacologyToken.settled
    and rec.pharmacology.families.cannabis.effect==0)
body:getInventory():AddItem(matches)
local stopped=ISTakePillAction:new(body,smoke);stopped:start();local uses=smoke:getCurrentUses();stopped:stop()
check("native_stop_no_dose",smoke:getCurrentUses()==uses and rec.pharmacology.families.cannabis.effect==0
    and stopped.saoPharmacologyToken.settled)

rec=fresh();Ph.advance(rec,body,hours);hours=7
local laggedItem=__copyNativeItem("SAO.OpioidTablets")
local lagged=ISTakePillAction:new(body,laggedItem);local oldUses=laggedItem:getCurrentUses()
check("unready_start_refuses_native_use",lagged:start()==false and lagged.stopped
    and lagged:complete()==false and laggedItem:getCurrentUses()==oldUses
    and rec.pharmacology.families.opioids.effect==0)
rec=fresh();laggedItem=__copyNativeItem("SAO.OpioidTablets")
lagged=ISTakePillAction:new(body,laggedItem);lagged:start();oldUses=laggedItem:getCurrentUses();hours=7
check("unready_completion_refuses_native_use",lagged:complete()==false and lagged.stopped
    and laggedItem:getCurrentUses()==oldUses and lagged.saoPharmacologyToken.settled
    and rec.pharmacology.families.opioids.effect==0)
rec=fresh();laggedItem=__copyNativeItem("SAO.OpioidTablets")
lagged=ISTakePillAction:new(body,laggedItem);lagged:start();oldUses=laggedItem:getCurrentUses()
body:getInventory():Remove(laggedItem);__otherBody:getInventory():AddItem(laggedItem)
check("moved_dose_refuses_native_completion",lagged:complete()==false and lagged.stopped
    and laggedItem:getCurrentUses()==oldUses and rec.pharmacology.families.opioids.effect==0)
rec=fresh();laggedItem=__copyNativeItem("SAO.OpioidTablets")
lagged=ISTakePillAction:new(body,laggedItem);lagged:start();oldUses=laggedItem:getCurrentUses()
lagged:perform()
check("native_perform_grants_no_exposure",laggedItem:getCurrentUses()==oldUses
    and rec.pharmacology.families.opioids.effect==0 and not lagged.saoPharmacologyToken.settled)
check("native_complete_applies_one_exposure",lagged:complete()==true
    and laggedItem:getCurrentUses()==oldUses-1 and rec.pharmacology.families.opioids.effect>0)
local effect=rec.pharmacology.families.opioids.effect
check("native_duplicate_callback_cannot_reconsume",lagged:complete()==false
    and laggedItem:getCurrentUses()==oldUses-1 and rec.pharmacology.families.opioids.effect==effect)
rec=fresh();local ordinary=__copyNativeItem("Base.Pills")
local ordinaryAction=ISTakePillAction:new(body,ordinary);oldUses=ordinary:getCurrentUses()
ordinaryAction:start();ordinaryAction:perform()
check("unregistered_native_action_unchanged",ordinaryAction:complete()==true
    and ordinary:getCurrentUses()==oldUses-1 and ordinaryAction.saoPharmacologyToken==nil)

-- A native moodle update is the physical projection consumed by Neuro.
rec=fresh();put("FATIGUE",.59);__nativeTiredMoodleUpdate()
local beforeAttention,beforeMotor=SAO.Neuro.physicalReadiness(rec)
take(rec,"Opioid");take(rec,"SedativeTablets");advance(rec,1);__nativeTiredMoodleUpdate()
local attention,motor=SAO.Neuro.physicalReadiness(rec)
print("NATIVE_READINESS "..beforeAttention..":"..attention..":"..beforeMotor..":"..motor)
check("native_moodle_neuro_impairment",attention<beforeAttention and motor<beforeMotor
    and SAO.Neuro.clarityOf(rec)<=attention and SAO.Neuro.motorSteadiness(rec)<=motor)
rec=fresh();put("FATIGUE",.61);__nativeTiredMoodleUpdate()
beforeAttention=SAO.Neuro.physicalReadiness(rec)
take(rec,"Cocaine");advance(rec,2);__nativeTiredMoodleUpdate()
attention=SAO.Neuro.physicalReadiness(rec)
check("native_moodle_neuro_stimulant",attention>beforeAttention)

local loot=SAO.PharmacologyLoot
local nativeLoot=__nativeLoot();local available={};local entries=0
for _,rule in ipairs(loot.rules)do
    for _,pool in ipairs(rule.pools)do
        for _,name in ipairs(rule.items)do
            local full="SAO."..name
            assert(nativeLoot[pool..":"..full] and close(nativeLoot[pool..":"..full],rule.weight),"PHARMA:native_loot_registration:"..pool..":"..full..":"..tostring(nativeLoot[pool..":"..full]))
            available[full]=true;entries=entries+1
        end
    end
end
local availableCount=0;for _ in pairs(available)do availableCount=availableCount+1 end
check("native_loot_all_owned_items",availableCount==15 and entries>100)
local beforeItems=#ProceduralDistributions.list.BathroomCabinet.items;loot.install()
check("loot_reload_no_weight_duplication",#ProceduralDistributions.list.BathroomCabinet.items==beforeItems)
check("medical_native_distribution",nativeLoot["MedicalClinicDrugs:SAO.MaintenanceTablets"]==.5)

-- Native actor, existing Rest law, and native elapsed metabolism compose in
-- chronological slices. Geometry/rest admission is controlled; the law is the
-- actual production DormantPopulation.advanceRest function.
body:getInventory():getItems():clear()
local function restOrigin(rec,origin)
    for name,value in pairs(origin.stats)do put(name,value)end
    body:getBodyDamage():getBodyPart(BodyPartType.Head):setAdditionalPain(origin.headPain)
    body:setAsleep(origin.sleeping);body:setSitOnGround(origin.resting)
    rec.dormantPhysiologyOrigin="native-snapshot"
    rec.dormantFatigue=origin.stats.FATIGUE;rec.dormantEndurance=origin.stats.ENDURANCE
    rec.dormantSleepNeed=1;rec.dormantPhysiologyAtHours=origin.atHours
    rec.dormantSleeping=origin.sleeping;rec.dormantResting=origin.resting
end
local function joinedOwner(rec,calls)
    return function(delta,to,origin)
        calls.count=calls.count+1
        if origin then restOrigin(rec,origin);return true end
        assert(string.sub(__nativeMetabolism(delta),1,11)=="METABOLIZED","native-metabolism")
        if not SAO.DormantPopulation.advanceRest(rec.id,rec,to) then return false end
        assert(SAOJavaBridge:applyDormantRestState(body,rec.dormantFatigue,rec.dormantEndurance))
        body:setAsleep(rec.dormantSleeping==true)
        body:setSitOnGround(rec.dormantResting==true or rec.dormantSleeping==true)
        return true
    end
end
local function statsCopy()
    local out={};for _,name in ipairs(SAO.PharmacologyProfiles.stats)do out[name]=stat(name)end
    return out
end
local function statsClose(a,b)
    for name,value in pairs(a)do if not close(value,b[name])then
        print("STAT_DIFF "..name..":"..value..":"..tostring(b[name]));return false end end
    return true
end
rec=fresh(21.99);rec.x=10;rec.y=20;rec.homeX=10;rec.homeY=20
put("FATIGUE",.25);put("ENDURANCE",.55);take(rec,"Cocaine")
local origin=Ph.checkpoint(rec,body,hours)
check("checkpoint_retains_native_posture",origin.resting==false and origin.sleeping==false)
local initial=__roundTrip(rec);local initialHours=hours;local finalHours=hours+2
local function scenario(preview,partitions)
    local restored=__roundTrip(initial);records[restored.id]=restored
    SAO.Body.active={[restored.id]=body};body:getModData().SAOPersonId=restored.id
    restOrigin(restored,origin);assert(Ph.enterDormancy(restored,origin))
    SAO.Body.active={};hours=finalHours
    local seen=0;Ph.onNativeChange=function()seen=seen+1 end
    if preview then
        for n=1,partitions do
            local to=initialHours+(finalHours-initialHours)*n/partitions
            assert(Ph.advanceDormant(restored,to,function(_,finish)
                return SAO.DormantPopulation.advanceRest(restored.id,restored,finish)
            end),"dormant-preview")
        end
    end
    local previewFatigue=restored.dormantFatigue
    -- Same durable state after a real Kahlua save/load; native snapshot is the
    -- old body at the original checkpoint, not the preview's changed stats.
    restored=__roundTrip(restored);records[restored.id]=restored
    SAO.Body.active={[restored.id]=body}
    local calls={count=0};local current=Ph.restore(restored,body,finalHours,joinedOwner(restored,calls))
    assert(current,"joined-restore")
    Ph.onNativeChange=nil
    return restored,statsCopy(),seen,previewFatigue,calls.count
end
local direct,directStats,directSeen=scenario(false,1)
local once,onceStats,onceSeen,previewFatigue=scenario(true,1)
local split,splitStats,splitSeen,splitFatigue=scenario(true,24)
check("dormant_replay_matches_native_rest_metabolism",statsClose(directStats,onceStats))
check("dormant_partition_preserves_physical_state",statsClose(onceStats,splitStats)
    and close(previewFatigue,splitFatigue))
check("dormant_replay_does_not_create_felt_evidence",directSeen==0 and onceSeen==0 and splitSeen==0)
check("dormant_origin_stats_not_overwritten",close(onceStats.FATIGUE,once.dormantFatigue)
    and once.pharmacology.dormant==nil and close(origin.stats.FATIGUE,.25))
check("dormant_rest_actually_sleeps",body:isAsleep() and split.dormantSleeping==true)

-- Previewed dependency changes survive restoration without a second history.
rec=fresh(1,{cocaine=true});Ph.advance(rec,body,hours)
rec.pharmacology.families.cocaine.counter=2879
rec.x=10;rec.y=20;rec.homeX=10;rec.homeY=20
origin=Ph.checkpoint(rec,body,hours);restOrigin(rec,origin);assert(Ph.enterDormancy(rec,origin))
SAO.Body.active={};hours=hours+1/6
assert(Ph.advanceDormant(rec,hours,function(_,to)return SAO.DormantPopulation.advanceRest(rec.id,rec,to)end))
local function dependencies(value)
    local n=0;for _,event in ipairs(value.pharmacology.events)do if event.kind=="dependency" then n=n+1 end end
    return n
end
local transitions=dependencies(rec);SAO.Body.active[rec.id]=body
assert(Ph.restore(rec,body,hours,joinedOwner(rec,{count=0})))
check("replay_dependency_history_exact_once",transitions==1 and dependencies(rec)==1
    and rec.habitsQuit.cocaine==true)

-- Refusal leaves the durable origin and cursor available for the body's
-- existing teardown/rollback transaction; no partial replay is published.
rec=fresh();take(rec,"Opioid");origin=Ph.checkpoint(rec,body,hours);assert(Ph.enterDormancy(rec,origin))
local prior=__roundTrip(rec.pharmacology);hours=1/30
local refused=Ph.restore(rec,body,hours,function(delta,_,source)
    if source then restOrigin(rec,source);return true end
    return false
end)
check("restore_owner_refusal_keeps_durable_origin",not refused and rec.pharmacology.dormant~=nil
    and rec.pharmacology.minute==prior.minute and rec.pharmacology.families.opioids.effect==prior.families.opioids.effect)
check("restore_requires_elapsed_owner",not Ph.restore(rec,body,hours))

-- No remaining pharmacology means one ordinary owner interval, even over a
-- long elapsed horizon. The callback count, not a wall timer, proves the cap.
rec=fresh();Ph.advance(rec,body,hours);origin=Ph.checkpoint(rec,body,hours)
assert(Ph.enterDormancy(rec,origin));SAO.Body.active={}
local noEffectCalls=0;hours=87600
local fast=Ph.advanceDormant(rec,hours,function()noEffectCalls=noEffectCalls+1;return true end)
check("settled_dormancy_fast_forwards",fast and noEffectCalls==1 and rec.pharmacology.minute==hours*60)
SAO.Body.active[rec.id]=body;noEffectCalls=0
assert(Ph.restore(rec,body,hours,function(_,_,source)
    noEffectCalls=noEffectCalls+1;if source then restOrigin(rec,source)end;return true end))
check("settled_restore_fast_forwards",noEffectCalls==2)

-- Legacy data is migrated through the real body's ModData once. A save-only
-- first checkpoint must preserve it as carefully as the loaded driver does.
rec=fresh(1);local legacy=body:getModData()
legacy.NnCCokeEffect=12;legacy.NnCCokeAmount=100;legacy.NnCTenMinutesCokeHead=-321
local legacyCheckpoint=Ph.checkpoint(rec,body,hours)
check("first_checkpoint_is_read_only",legacyCheckpoint and rec.pharmacology==nil)
assert(Ph.commitCheckpoint(rec,legacyCheckpoint))
check("first_checkpoint_retains_legacy_state",rec.pharmacology.families.cocaine.effect==12
    and rec.pharmacology.families.cocaine.amount==100 and rec.pharmacology.families.cocaine.counter==-321)
legacy.NnCCokeEffect=1;legacy.NnCCokeAmount=1;legacy.NnCTenMinutesCokeHead=1
Ph.advance(rec,body,hours)
check("legacy_import_does_not_repeat",rec.pharmacology.families.cocaine.effect==12)
legacy.NnCCokeEffect=nil;legacy.NnCCokeAmount=nil;legacy.NnCTenMinutesCokeHead=nil

-- A partial native failure is held explicitly. Repeating a tick cannot apply
-- its first physical writes a second time after an exception.
rec=fresh();take(rec,"Cocaine");local savedStats=CharacterStat
CharacterStat={};for _,name in ipairs(SAO.PharmacologyProfiles.stats)do CharacterStat[name]=savedStats[name]end
CharacterStat.ENDURANCE="unavailable-native-stat"
local failed=Ph.advance(rec,body,1/60);CharacterStat=savedStats
local faultFatigue=stat("FATIGUE")
check("native_fault_recorded",not failed and rec.pharmacology.fault~=nil)
check("native_fault_does_not_replay",not Ph.advance(rec,body,1/60) and stat("FATIGUE")==faultFatigue)
PHARMACOLOGY_RESULT="PASS owned pharmacology "..count
