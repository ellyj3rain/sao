local A=SAO.LeisureArt
local n=0
local function check(name,v)if not v then error('D2_ART:'..name)end;n=n+1;print('PASS '..name)end
local function eq(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not eq(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function offer(body,id,activity)
    for _,v in ipairs(A.offers(id,body))do if not activity or v.activity==activity then return v end end
end
local function begin(id,style,level)
    local b,o=fixture(id,style,level);local v=offer(b,id)
    check('available_'..id,v~=nil)
    check('admitted_'..id,A.begin(id,b,v,'purpose:'..id)==true)
    return b,o,ISTimedActionQueue.queues[b]
end
local function run(action)
    native(action,.4);action:update();action.delta=1;action:update();action:perform();return action:complete()
end
-- Queries never roll art quality or create physical art, work or source effects.
local b,o=fixture('offers')
local rng=__rng;local before=copy(o.data)
local v=offer(b,'offers')
check('offer_is_read_only',v and __rng==rng and eq(before,o.data)and A.work('offers')==nil)
local forged=copy(v);forged.revision='foreign-source'
check('forged_source_refused',not A.begin('offers',b,forged,'purpose'))
forged=copy(v);forged.targetX=100
check('forged_locator_refused',not A.begin('offers',b,forged,'purpose'))
check('foreign_actor_refused',not A.begin('foreign',b,v,'purpose'))
b.observations[1].at=__tick-121
check('stale_visibility_refused',#A.offers('offers',b)==0)
b.observations[1].at=__tick;b.items[2]=item('foreignPalette',99)
check('missing_material_refused',#A.offers('offers',b)==0)
body,obj,action=begin('premature')
native(action,.4);local early=copy(obj.data)
action:perform()
check('premature_terminal_refused',obj.data.stage~=4 and A.outcome('premature',1).status=='interrupted')
body,obj,action=begin('prepared-cancel')
A.interrupt('prepared-cancel',body,'cancel before start')
check('prepared_cancel_closes',A.outcome('prepared-cancel',1).status=='interrupted')
-- Installed source core versus the installed original timed action with identical
-- body/stat/material/physical receivers and exactly the same RNG stream.
for _,style in ipairs({'canvas','Hedge','Wood','Metal','Stone','Ice'})do
    local id='equivalent-'..style
    local body,obj,action=begin(id,style~='canvas' and style or nil,style=='Ice' and 10 or style=='Stone' and 8 or style=='Metal' and 6 or 4)
    local definition=copy(style=='canvas' and obj.data.painting or obj.data.sculpture)
    local initial=copy(obj.data)
    __rng=0
    local completed=run(action)
    local receipt=A.outcome(id,1)
    check('physical_completion_'..style,completed==true and receipt.status=='completed'and obj.data.stage==4 and obj.overlay)
    check('typed_detached_outcome_'..style,receipt.actorId==id and receipt.family=='art'and receipt.physicalArt.definition and receipt.nativeProgress.sourceUpdates==2)
    local final=copy(obj.data);local overlay=obj.overlay:getName();local stats=copy(body.stats.values);local uses={}
    for i,item in ipairs(body.items)do uses[i]=item.uses end
    local rolls=__rng;local requests=receipt.pendingSkillEffects.requests
    local originalBody,originalObject=fixture('original-'..style,style~='canvas' and style or nil,body.level)
    originalObject.data=copy(initial);originalBody.data.SAOPersonId='original-'..style
    local material={};local original
    if style=='canvas'then material={brush=originalBody.items[1],palette=originalBody.items[2]}
        original=LSCanvasPaintingAction:new(originalBody,originalObject,copy(definition),definition.duration,material)
    else
        local names=style=='Wood' and {'Hammer','CarpentryChisel'}or style=='Stone'and {'Hammer','MasonsChisel'}or style=='Metal'and {'BlowTorch','Hammer','WeldingMask'}or {'Saw'}
        for i,name in ipairs(names)do for _,item in ipairs(originalBody.items)do if item.name==name then material['item'..i]=item end end end
        original=LSSculptingAction:new(originalBody,originalObject,copy(definition),definition.duration,material)
    end
    local actualRequests={};sendClientCommand=function(character,module,command,args)
        check('actual_source_xp_route_'..style,character==originalBody and module=='LS'and command=='AddXP')
        actualRequests[#actualRequests+1]={perkName=args[1],amount=args[2]}
    end
    __rng=0;run(original)
    check('original_physical_equivalence_'..style,eq(final,originalObject.data)and overlay==originalObject.overlay:getName())
    check('original_mood_equivalence_'..style,eq(stats,originalBody.stats.values))
    local materialMatch=true;for i,item in ipairs(originalBody.items)do materialMatch=materialMatch and uses[i]==item.uses end
    check('original_material_equivalence_'..style,materialMatch)
    local xpMatch=#requests==#actualRequests
    for i,r in ipairs(requests)do xpMatch=xpMatch and r.amount==actualRequests[i].amount and r.perkName==actualRequests[i].perkName end
    check('original_rng_xp_equivalence_'..style,xpMatch and __rng==rolls)
    check('source_call_mood_measured_'..style,receipt.measuredEffects.sourceMoodCalls==3 and receipt.measuredEffects.sourceDeltas.BOREDOM==-3)
    check('old_terminal_request_refused_'..style,A.skillRequest(id,1,requests[1]and requests[1].sequence or 1)==nil)
    receipt.status='forged';check('outcome_is_detached_'..style,A.outcome(id,1).status=='completed')
    local count=#(__records[id].artLeisureOutcomes or{});local oldstage=obj.data.stage
    action:perform();action:complete()
    check('duplicate_terminal_refused_'..style,#__records[id].artLeisureOutcomes==count and obj.data.stage==oldstage)
end
-- The source owns measured partial progress, and interruptions preserve its art.
local body,obj,action=begin('partial')
native(action,.4);action.currentState='Brush';action:update();action:update()
local physical=copy(obj.data)
check('source_partial_stage_visible',obj.data.stage>0 and obj.data.stage<4)
A.interrupt('partial',body,'danger')
local partial=A.outcome('partial',1)
check('partial_is_attempt_not_success',partial.status=='interrupted'and partial.nativeProgress.sourceUpdates==2 and obj.data.stage<4)
check('partial_progress_persisted',obj.data.progress==action.maxTime-action.jobProgress and obj.data.progress<obj.data.painting.duration)
check('partial_receipt_actual_art',partial.physicalArt.stage==obj.data.stage and partial.physicalArt.definition.stage4==obj.data.painting.stage4)
local resumed=offer(body,'partial');check('partial_can_resume',resumed and A.begin('partial',body,resumed,'purpose:partial'))
local resumedAction=ISTimedActionQueue.queues[body];check('resume_uses_actual_remaining',resumedAction.maxTime==obj.data.progress)
native(resumedAction,.2);resumedAction:update()
local savedArt=copy(obj.data)
__reloadArt();A=SAO.LeisureArt
check('reload_retains_unfinished_art',eq(savedArt,obj.data)or obj.data.progress==resumedAction.maxTime-resumedAction.jobProgress)
check('reload_terminal_is_interrupted',A.outcome('partial',2).status=='interrupted'and A.work('partial')==nil)
check('pending_cannot_grant_after_reload',A.skillRequest('partial',2,1)==nil)
local saved=__nativeRoundtrip(__records.partial)
check('native_roundtrip_retains_receipts',saved.artLeisureOutcomes[2].status=='interrupted'and saved.artLeisureOutcomes[2].physicalArt.definition)
-- Authenticated skill receiver sees the exact source call during its transient
-- binding; saved requests alone do not recreate that authority.
local seen={}
SAO.LeisureSkill={consume=function(id,character,owner,workSeq,requestSeq)
    local req=A.skillRequest(id,workSeq,requestSeq)
    seen[#seen+1]=req
    check('source_request_callback_bound',req and owner=='SAO.LeisureArt'and req.nativeProgress.actionStarted and req.nativeProgress.sourceInvocationSequence>=1
        and(req.nativeProgress.sourceCallback=='update'or req.nativeProgress.sourceCallback=='perform')and req.nativeProgress.jobDelta>=0 and req.nativeProgress.jobDelta<=1)
    return true
end}
body,obj,action=begin('skill')
run(action)
check('skill_only_real_requests',#seen>0 and A.outcome('skill',1).pendingSkillEffects.consumed==#seen)
SAO.LeisureSkill=nil
body,obj,action=begin('custody')
native(action,.4);table.remove(body.items,2);local prior=copy(obj.data)
action:update()
local stopped=A.outcome('custody',1)
check('lost_material_interrupts_without_progress',stopped and stopped.status=='interrupted'and eq(prior,obj.data))
body,obj,action=begin('replacement')
native(action,.4);__bodies.replacement=fixture('replacement-new')
prior=copy(obj.data);action:update();A.advance('replacement',body)
check('foreign_body_cannot_write_art',eq(prior,obj.data)and A.outcome('replacement',1).status=='interrupted')
body,obj,action=begin('sprite')
native(action,.4);obj.sprite=sprite('foreignSprite',{});prior=copy(obj.data);action:update()
check('foreign_station_interrupts',A.outcome('sprite',1).status=='interrupted'and eq(prior,obj.data))
body,obj,action=begin('station-instance','Wood')
native(action,.4);obj.square.objects[1]={foreign=true};prior=copy(obj.data);action:update()
stopped=A.outcome('station-instance',1)
check('station_instance_changed_refused',stopped and stopped.status=='interrupted'and eq(prior,obj.data)and #obj.square.objects==1)
body,obj,action=begin('generation')
native(action,.4);body.data.SAOExternalToken='generation-2';prior=copy(obj.data);action:update();A.advance('generation',body)
stopped=A.outcome('generation',1)
check('body_generation_changed_refused',stopped and stopped.status=='interrupted'and eq(prior,obj.data))
body,obj,action=begin('metadata')
native(action,.4);obj.data.painting.quality='IGUI_PaintingQuality_Masterpiece';prior=copy(obj.data);action:update()
stopped=A.outcome('metadata',1)
check('foreign_art_metadata_refused',stopped and stopped.status=='interrupted'and eq(prior,obj.data))
-- Appraisal reports the original fallible quality guess and preserves the art.
for _,style in ipairs({'canvas','Wood'})do
    local id='appraise-'..style
    body,obj,action=begin(id,style~='canvas'and style or nil,4)
    native(action,.4);action.currentState=style=='canvas'and'Brush'or'Action';action:update();action:update();action:update();action:stop()
    body.brushmaster=true
    local o=offer(body,id,'appraise-art')
    check('appraisal_available_'..style,o~=nil)
    check('appraisal_admitted_'..style,A.begin(id,body,o,'purpose:appraisal'))
    local appraisal=ISTimedActionQueue.queues[body];local before=copy(obj.data)
    check('appraisal_actual_native_duration_'..style,appraisal.maxTime==800)
    __rng=0;run(appraisal);local rolls=__rng
    local outcome=A.outcome(id,2)
    check('appraisal_preserves_physical_art_'..style,eq(before,obj.data)and outcome.status=='completed'and body.data.LSCooldowns.brushmaster==6)
    check('appraisal_is_fallible_source_guess_'..style,outcome.presentation and outcome.presentation.qualityGuess and outcome.presentation.qualityType and outcome.measuredEffects.sourceMoodCalls==0)
    local originalBody,originalObject=fixture('original-appraise-'..style,style~='canvas'and style or nil,4)
    originalObject.data=copy(before);originalBody.data.LSCooldowns={}
    local art=style=='canvas'and originalObject.data.painting or originalObject.data.sculpture
    local original=LSCanvasAppraiseAction:new(originalBody,originalObject,art,appraisal.precision)
    __rng=0;__notePayload=nil;run(original)
    check('original_appraisal_equivalence_'..style,eq(before,originalObject.data)and originalBody.data.LSCooldowns.brushmaster==6
        and __rng==rolls and __notePayload[2]:find(outcome.presentation.qualityGuess,1,true)~=nil)
end
local savedSkill=SAO.LeisureSkill;local privateRequestMatched=false
SAO.LeisureSkill={consume=function(id,actor,provider,workSequence,sequence)
    local saved=__records[id].artSkillRequests[#__records[id].artSkillRequests]
    local original=saved.amount;saved.amount=999999
    local issued=A.skillRequest(id,workSequence,sequence)
    privateRequestMatched=issued and issued.amount==original
    return true
end}
body,obj,action=begin('private-request');run(action)
check('saved_request_cannot_replace_live_issuance',privateRequestMatched)
SAO.LeisureSkill=savedSkill
body,obj,action=begin('dead-art');native(action,.4);action:update()
local physical=copy(obj.data);local mood=copy(body.stats.values)
local foreign=fixture('foreign-cleanup')
check('foreign_interrupt_cannot_retire_art',not A.interrupt('dead-art',foreign,'foreign') and A.work('dead-art')~=nil)
body.dead=true
check('exact_dead_body_detaches_art',A.detach('dead-art',body,'death') and A.work('dead-art')==nil
    and A.outcome('dead-art',1).status=='interrupted' and not ISTimedActionQueue.hasAction(action))
check('dead_cleanup_preserves_physical_art_and_mood',eq(physical,obj.data) and eq(mood,body.stats.values))
-- The installed default catalogue has zero repeat intervals. The following
-- controlled nonzero action state exercises its existing repeat scheduler;
-- it does not introduce a new live-game repertoire entry.
local oldClock=getGameTime
local function scheduledAppraisal(id,interval)
    local body,obj,paint=begin(id)
    native(paint,.4);paint.currentState='Brush';paint:update();paint:update();paint:update();paint:stop()
    body.brushmaster=true;body.data.LSCooldowns={}
    local candidate=offer(body,id,'appraise-art')
    check('interval_appraisal_offer_'..id,candidate~=nil)
    check('interval_appraisal_admit_'..id,A.begin(id,body,candidate,'purpose:interval:'..id))
    local action=ISTimedActionQueue.queues[body];native(action,.4)
    local defaultZero=true
    for _,routine in ipairs(action.animList)do if routine.soundTime~=0 then defaultZero=false end end
    check('default_appraisal_repeat_disabled_'..id,defaultZero)
    action.animName='controlled-current-source-routine';action.animTime=1000
    action.soundType='IntriguedHmm';action.soundName='ManIntriguedHMM01'
    action.soundTime=interval;action.soundTimeInterval=interval
    body.emitter.plays=0;body.emitter.stops=0
    body.emitter.playSound=function(self,name)self.plays=self.plays+1;return self.plays end
    body.emitter.stopSound=function(self)self.stops=self.stops+1 end
    return body,obj,action
end
local firstBody,firstObject,first=scheduledAppraisal('interval-first',2)
local secondBody,secondObject,second=scheduledAppraisal('interval-second',5)
getGameTime=function()return {getGameWorldSecondsSinceLastUpdate=function()return 1 end}end
local previousGlobal=soundTimeInterval;soundTimeInterval='unrelated-global-sentinel'
local function step(action,object)__station=object;action:update()end
step(first,firstObject);step(second,secondObject);step(first,firstObject);step(second,secondObject)
check('repeat_sound_waits_until_exact_interval',firstBody.emitter.plays==0 and secondBody.emitter.plays==0)
step(first,firstObject)
check('action_owned_interval_advances',first.soundTimeInterval==4 and firstBody.emitter.plays==1)
check('second_action_interval_not_changed',second.soundTimeInterval==5 and secondBody.emitter.plays==0)
check('unrelated_global_interval_unchanged',soundTimeInterval=='unrelated-global-sentinel')
step(first,firstObject)
check('repeat_sound_not_each_update',firstBody.emitter.plays==1)
step(first,firstObject)
check('second_exact_repeat_occurs',firstBody.emitter.plays==2 and first.soundTimeInterval==6)
step(second,secondObject);step(second,secondObject);step(second,secondObject);step(second,secondObject)
check('second_independent_exact_repeat',secondBody.emitter.plays==1 and second.soundTimeInterval==10)
__station=firstObject;first:stop();__station=secondObject;second:stop()
soundTimeInterval=previousGlobal;getGameTime=oldClock
__result='PASS D2 leisure art '..n
print(__result)
