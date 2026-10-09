local G=SAO.LeisureGames;local n=0
local function check(name,v)if not v then error('D2_GAMES:'..name)end;n=n+1;print('PASS '..name)end
local function eq(a,b)
    if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if k~='__commands'and k~='__keys'and not eq(v,b[k])then return false end end
    for k in pairs(b)do if k~='__commands'and k~='__keys'and a[k]==nil then return false end end;return true
end
local function offer(id,b,activity)
    for _,v in ipairs(G.offers(id,b))do if not activity or v.activity==activity then return v end end
end
local function enter(id,gameId,ping)
    local b,o,other=gameFixture(id,gameId,ping);local v=offer(id,b)
    check('available_'..id,v~=nil)
    check('admitted_'..id,G.begin(id,b,v,'purpose:'..id))
    return b,o,ISTimedActionQueue.queues[b],other
end
local b,o=gameFixture('query','pong')
seed(173);local rng=__rng;local before=copy(o.data);local v=offer('query',b)
check('offer_readonly',v and __rng==rng and eq(before,o.data)and G.work('query')==nil)
local forged=copy(v);forged.revision='false-source'
check('forged_source_refused',not G.begin('query',b,forged,'purpose'))
forged=copy(v);forged.runtimeInstance='foreign-object'
check('forged_instance_refused',not G.begin('query',b,forged,'purpose'))
check('foreign_person_refused',not G.begin('other',b,v,'purpose'))
o.data.ComputerModPasswordEnabled=true;check('credentials_not_bypassed',#G.offers('query',b)==0)
o.data.ComputerModPasswordEnabled=false;o.power=false;check('no_power_refused',#G.offers('query',b)==0)
o.power=true;o.data.ComputerModOSInstalled=false;check('no_os_refused',#G.offers('query',b)==0)
o.data.ComputerModOSInstalled=true;o.data.ComputerModComponents.cpu.condition=0;check('broken_hardware_refused',#G.offers('query',b)==0)
o.data.ComputerModComponents.cpu.condition=100;o.data.ComputerModInstalledGames={};check('uninstalled_game_refused',#G.offers('query',b)==0)
o.data.ComputerModInstalledGames={'pong'};o.data.ComputerModMetaInitialized=false;check('uninitialized_source_not_invented',#G.offers('query',b)==0)
o.data.ComputerModMetaInitialized=true;o.data.ComputerModPowerOn=false;check('off_computer_not_played',#G.offers('query',b)==0)
o.data.ComputerModPowerOn=true;b.observations[1].at=__tick-121;check('stale_object_refused',#G.offers('query',b)==0)
local ids={};for id in pairs(__definitions)do ids[#ids+1]=id end;table.sort(ids)
for _,gameId in ipairs(ids)do
    local id='equivalence-'..gameId;seed(173)
    local body,obj,action=enter(id,gameId)
    native(action,0)
    local initial=G.context(id,body)
    local initialStats=copy(body.stats.values)
    check('source_control_labels_'..gameId,initial.labels.action=='A'and G.controlPresentation(id,body).labels.action=='A')
    check('presented_source_frame_'..gameId,initial and initial.status=='presented-source-scene'and #initial.commands>0
        and initial.viewport.width==450 and initial.viewport.height==253 and initial.grid==nil and initial.secret==nil)
    local selected
    for _,input in ipairs(G.inputOffers(id,body))do if #input.keys==1 and input.keys[1]=='action'then selected=input end end
    check('source_input_admitted_'..gameId,selected and G.submitInput(id,body,selected))
    check('duplicate_input_refused_'..gameId,not G.submitInput(id,body,selected))
    local last;local steps=0;local startHours=__hours
    while G.work(id)and steps<18 do
        steps=steps+1;__hours=startHours+steps/3600;action:update();last=G.context(id,body)or G.outcome(id,1)and G.outcome(id,1).presentedScene or last
    end
    check('actual_source_updates_'..gameId,action.owner.work.nativeProgress.sourceUpdates==steps and steps>0)
    check('stale_input_refused_'..gameId,not G.submitInput(id,body,selected))
    local rolls=__rng
    local wasCompleted=G.outcome(id,1)~=nil
    G.interrupt(id,body,'inspect source comparison')
    local backend=action.owner.scene
    check('attempt_retained_'..gameId,G.outcome(id,1)and backend)
    local original=_G[__definitions[gameId].className]:new(0,0,450,253)
    seed(173);original:initialise();original.__commands={};original:prerender()
    local initialCommands=copy(original.__commands)
    while #initialCommands>4096 do table.remove(initialCommands,1)end
    check('original_initial_view_'..gameId,eq(initial.commands,initialCommands))
    original.__keys={action=true}
    local originalBody={stats={values=initialStats,get=body.stats.get,set=body.stats.set,add=body.stats.add,remove=body.stats.remove},getStats=body.getStats}
    local originalMood=setmetatable({playerObj=originalBody,game=original},{__index=__originalMoodTarget})
    originalMood.isVisible=function()return true end;originalMood.isGameView=function()return true end
    originalMood.getActiveGameInstance=function(self)return self.game end
    for i=1,steps do
        __hours=startHours+i/3600;original:update();original.__commands={};original:prerender()
        ComputerScreenUI.instance=originalMood;__originalMoodUpdate(originalBody)
    end
    local originalCommands=copy(original.__commands);while #originalCommands>4096 do table.remove(originalCommands,1)end
    check('original_mechanics_equivalent_'..gameId,eq(backend,original))
    check('original_presented_view_equivalent_'..gameId,last and eq(last.commands,originalCommands))
    check('original_rng_equivalent_'..gameId,rolls==__rng)
    check('original_live_mood_equivalent_'..gameId,eq(body.stats.values,originalBody.stats.values))
    -- Source gameplay can resume without reset or extra random draws.
    if not wasCompleted then seed(411)
    check('resume_admitted_'..gameId,G.begin(id,body,offer(id,body),'purpose:'..id))
    local resumed=ISTimedActionQueue.queues[body];native(resumed,0)
    check('resume_does_not_reroll_'..gameId,__rng==0 and G.work(id).resumedFromHours~=nil)
    local c=G.context(id,body)
    check('resume_preserves_actual_view_'..gameId,c and eq(c.commands,last.commands))
    G.interrupt(id,body,'done')
    end
end
-- Hidden source secrets are not returned as actor-visible screen state.
b,o,action=enter('hidden','minesweeper');native(action,0)
local context=G.context('hidden',b)
local function containsKey(t,key)for k,v in pairs(t)do if k==key then return true end;if type(v)=='table'and containsKey(v,key)then return true end end;return false end
check('hidden_board_fields_not_exposed',not containsKey(context,'mine')and not containsKey(context,'grid')and not containsKey(context,'secret'))
local input=G.inputOffers('hidden',b)[2];local counterfeit=copy(input);counterfeit.keys={'invented-win'}
check('forged_controls_refused',not G.submitInput('hidden',b,counterfeit))
G.interrupt('hidden',b,'pause')
-- Real source outcomes can include a loss; native participation is separate.
b,o,action=enter('loss','snake');native(action,0)
local attempts=0
while G.work('loss')and attempts<500 do attempts=attempts+1;action:update()end
local result=G.outcome('loss',1)
check('actual_source_loss_not_fabricated_win',result and result.status=='completed'and result.sourceResult.state=='GAMEOVER'and result.sourceResult.won==false and attempts>1)
local count=#__records.loss.gamesOutcomes;action:perform();action:complete()
check('duplicate_outcome_refused',#__records.loss.gamesOutcomes==count)
result.status='forged';check('detached_canonical_outcome',G.outcome('loss',1).status=='completed')
b,o,action=enter('power-loss','pong');native(action,0);o.power=false;local old=copy(o.data);action:update()
old.SAONpcGameLease=nil
local stopped=G.outcome('power-loss',1)
check('power_loss_interrupts',stopped and stopped.status=='interrupted'and eq(old,o.data))
b,o,action=enter('generation','pong');native(action,0);b.data.SAOExternalToken='new-generation';local prior=G.work('generation').nativeProgress.sourceUpdates
action:update();G.advance('generation',b)
stopped=G.outcome('generation',1)
check('foreign_generation_cannot_play',stopped and stopped.status=='interrupted'and stopped.nativeProgress.sourceUpdates==prior)
b,o,action=enter('station-change','pong');native(action,0);o.square.objects[1]={foreign=true};action:update()
stopped=G.outcome('station-change',1)
check('station_replacement_refused',stopped and stopped.status=='interrupted')
b,o,action=enter('reload','pong');native(action,0);action:update()
local physical=copy(o.data);__reloadGames();G=SAO.LeisureGames
check('reload_interrupts_preserves_machine',G.outcome('reload',1).status=='interrupted'and o.data.SAONpcGameLease==nil and o.data.ComputerModInstalledGames[1]=='pong')
local roundtrip=__nativeRoundtrip(__records.reload)
check('native_persistence_preserves_backend',roundtrip.gamesResume.schema==1 and roundtrip.gamesResume.states[roundtrip.gamesResume.order[1]].state.ball)
b,o,action=enter('fresh-runtime','pong');native(action,0);action:update()
local freshView=G.context('fresh-runtime',b)
local saved=__nativeRoundtrip(__records['fresh-runtime'])
check('active_native_save_retains_source',saved.gamesWork.status=='active'and saved.gamesResume.states[saved.gamesResume.order[1]].state.ball)
__records['fresh-runtime']=saved;ISTimedActionQueue.queues[b]=nil;SAO.LeisureGames=nil;__reloadGames();G=SAO.LeisureGames
check('fresh_runtime_no_native_callback',G.advance('fresh-runtime',b)==false)
check('fresh_runtime_retires_exact_lease',G.outcome('fresh-runtime',1).status=='interrupted'and o.data.SAONpcGameLease==nil)
seed(923)
check('fresh_runtime_resume_admitted',G.begin('fresh-runtime',b,offer('fresh-runtime',b),'purpose:fresh-runtime'))
action=ISTimedActionQueue.queues[b];native(action,0)
check('fresh_runtime_same_source_no_rng',__rng==0 and eq(G.context('fresh-runtime',b).commands,freshView.commands))
G.interrupt('fresh-runtime',b,'fresh-proof-ended')
-- The installed mechanical rival is the exact original source mode. No other
-- person is fabricated and the pre-generated event is not private foresight.
local body,obj,action,other=enter('ping',nil,true)
native(action,0)
check('ping_native_body_participates',body.blocked==true and G.work('ping').nativeProgress.shots==1)
check('ping_source_ball_trajectory',G.work('ping').nativeProgress.ballPosition
    and G.work('ping').nativeProgress.ballPosition.x~=nil and G.work('ping').nativeProgress.ballPosition.arcPixels~=nil)
check('no_precomputed_win_in_private_work',G.work('ping').sourceResult==nil and G.work('ping').matchData==nil)
for i=1,120 do __hours=__hours+.3/3600;action:update()end
local partial=G.work('ping').nativeProgress
G.interrupt('ping',body,'break')
local outcome=G.outcome('ping',1)
check('ping_partial_not_future_win',outcome.status=='interrupted'and outcome.sourceResult==nil and outcome.nativeProgress.sourceUpdates==120)
check('ping_release_preserves_upgrade',body.blocked==false and obj.data.movableData.inUse==false and obj.data.movableData.fakeRival==true
    and obj.data.SAONpcGameLease==nil and other.data.SAONpcGameLease==nil)
seed(831)
check('ping_source_resume',G.begin('ping',body,offer('ping',body),'purpose:ping'))
action=ISTimedActionQueue.queues[body];native(action,0)
check('ping_resume_preserves_event_no_rng',G.work('ping').resumedFromHours~=nil and __rng==0 and G.work('ping').nativeProgress.pointsPlayed==partial.pointsPlayed)
attempts=0
while G.work('ping')and attempts<5000 do attempts=attempts+1;__hours=__hours+.3/3600;action:update()end
outcome=G.outcome('ping',2)
check('ping_actual_source_match_finishes',outcome and outcome.status=='completed'and outcome.sourceResult.state=='source-match-complete'
    and outcome.nativeProgress.pointsPlayed>=5 and outcome.sourceResult.scoreSource+outcome.sourceResult.scoreOther==outcome.nativeProgress.pointsPlayed)
check('ping_source_qualification',outcome.sourceResult.mode=='installed-mechanical-fake-rival; source-generated procedural match')
body,obj,action,other=enter('ping-authority',nil,true);native(action,0)
obj.square.objects[1]={foreign=true};action:update()
stopped=G.outcome('ping-authority',1)
check('ping_instance_loss_interrupts',stopped and stopped.status=='interrupted'and body.blocked==false)
local humanBody,humanObj,humanOther=gameFixture('human',nil,true);humanObj.data.movableData.fakeRival=false;humanOther.data.movableData.fakeRival=false
check('human_partner_not_forced',#G.offers('human',humanBody)==0)
local arcadeSprites={'recreational_01_16','recreational_01_20','recreational_01_24',
    'pa_arcades_0','pa_arcades_4','pa_arcades_8','pa_arcades_12','pa_arcades_16','pa_arcades_20',
    'pa_arcades_24','pa_arcades_28','pa_arcades_32','pa_arcades_36','pa_complex_0','pa_complex_4',
    'pa_pinballs_0','pa_pinballs_4','pa_pinballs_8','pa_pinballs_12','pa_pinballs_16','pa_pinballs_20','pa_pinballs_24'}
local originalCarried,originalInfer=SAOJavaBridge.privateCarriedItems,SAO.ConceptKnowledge.infer
SAOJavaBridge.privateCarriedItems=function()error('arcade type preview read inventory')end
SAO.ConceptKnowledge.infer=function()error('arcade type preview read personal knowledge')end
local currencyRows=G.materialRequirementsForType(nil,'Base.SilverCoin')
check('arcade_type_preview_nil_body',#currencyRows==22 and currencyRows[1].role=='material')
check('arcade_type_preview_exact_activity',currencyRows[1].activity=='arcade-ArcadeMachine1'
    and currencyRows[1].sourceId=='ProjectArcade:ProjectArcade_PlayArcadeTimedAction:ArcadeMachine1')
SAOJavaBridge.privateCarriedItems,SAO.ConceptKnowledge.infer=originalCarried,originalInfer
check('arcade_other_type_not_currency',#G.materialRequirementsForType(nil,'Base.Battery')==0)
local paidBody,paidObject=arcadeFixture('arcade-supply','pa_arcades_0',0)
local supply
for _,row in ipairs(currencyRows)do if row.activity=='arcade-ArcadeStreetFighter'then supply=row;break end end
check('arcade_missing_currency_personal_cabinet',supply and G.materialRequirementAvailable('arcade-supply',paidBody,supply)
    and #G.offers('arcade-supply',paidBody)==0)
local otherSupply
for _,row in ipairs(currencyRows)do if row.activity=='arcade-ArcadePacman'then otherSupply=row;break end end
check('arcade_requirement_machine_binding',not G.materialRequirementAvailable('arcade-supply',paidBody,otherSupply))
local forgedSupply=copy(supply);forgedSupply.revision=string.rep('0',64)
check('arcade_requirement_source_revision',not G.materialRequirementAvailable('arcade-supply',paidBody,forgedSupply))
check('arcade_foreign_actor_no_station',not G.materialRequirementAvailable('foreign',paidBody,supply))
paidObject.power=false
check('arcade_requirement_power_binding',not G.materialRequirementAvailable('arcade-supply',paidBody,supply))
paidObject.power=true;paidBody.observations[1].at=__tick-121
check('arcade_requirement_fresh_observation',not G.materialRequirementAvailable('arcade-supply',paidBody,supply))
paidBody.observations[1].at=__tick
ProjectArcade_Currency.Config.Cost=2
paidBody.items[1]=item('Base.SilverCoin',201);paidBody.items[1].getFullType=function()return 'Base.SilverCoin'end
check('arcade_multi_coin_deficit',G.materialRequirementAvailable('arcade-supply',paidBody,supply)
    and #G.offers('arcade-supply',paidBody)==0)
paidBody.items[2]=item('Base.SilverCoin',202);paidBody.items[2].getFullType=function()return 'Base.SilverCoin'end
local paidOffer=offer('arcade-supply',paidBody,'arcade-ArcadeStreetFighter')
check('arcade_multi_coin_receipt_candidates',paidOffer and #paidOffer.materials==2
    and paidOffer.materials[1].id=='201' and paidOffer.materials[2].id=='202'
    and not G.materialRequirementAvailable('arcade-supply',paidBody,supply))
ProjectArcade_Currency.Config.CurrencyFullType='Base.Battery'
check('arcade_changed_currency_type',#G.materialRequirementsForType(nil,'Base.SilverCoin')==0
    and #G.materialRequirementsForType(nil,'Base.Battery')==22 and #G.offers('arcade-supply',paidBody)==0)
ProjectArcade_Currency.Config.CurrencyFullType='Missing.Currency'
check('arcade_invalid_currency_definition',#G.materialRequirementsForType(nil,'Missing.Currency')==0
    and #G.offers('arcade-supply',paidBody)==0)
ProjectArcade_Currency.Config.CurrencyFullType='Base.SilverCoin';ProjectArcade_Currency.Config.DebugFreePlay=true
check('arcade_free_play_no_supply',#G.materialRequirementsForType(nil,'Base.SilverCoin')==0)
ProjectArcade_Currency.Config.DebugFreePlay=false;ProjectArcade_Currency.Config.Cost=1
for i,sp in ipairs(arcadeSprites)do
    local originalBody,originalObject=arcadeFixture('arcade-original-'..i,sp,2)
    seed(173);local original=ProjectArcade_PlayArcadeTimedAction:new(originalBody,originalObject,2000,1,'Base.SilverCoin',false)
    local actualRng=__rng;native(original,0)
    body,obj=arcadeFixture('arcade-'..i,sp,2);seed(173)
    local currentOffer=offer('arcade-'..i,body)
    check('arcade_available_'..i,currentOffer and __rng==0)
    check('arcade_admission_before_coin_'..i,G.begin('arcade-'..i,body,currentOffer,'purpose:arcade-'..i)and #body.items==2 and __rng==0)
    local payment=ISTimedActionQueue.queues[body];native(payment,0);payment:perform();payment:complete()
    action=ISTimedActionQueue.queues[body];native(action,0)
    check('arcade_exact_source_payment_'..i,#body.items==1 and G.work('arcade-'..i).nativeProgress.payment.sourcePaid==true)
    check('arcade_actual_source_rng_'..i,__rng==actualRng and action.didWin==original.didWin)
    check('arcade_source_screen_on_'..i,obj.data.PA_arcadeScreenOn==originalObject.data.PA_arcadeScreenOn
        and(obj.attached and obj.attached:getName())==(originalObject.attached and originalObject.attached:getName()))
    check('arcade_no_future_win_'..i,G.work('arcade-'..i).sourceResult==nil and #G.inputOffers('arcade-'..i,body)==0)
    for t=1,10 do action.delta=t/11;original.delta=t/11;original:update();action:update()end
    check('arcade_actual_incremental_mood_'..i,eq(body.stats.values,originalBody.stats.values))
    action.delta=1;original.delta=1;original:perform();action:perform();action:complete()
    local terminal=G.outcome('arcade-'..i,1)
    check('arcade_actual_terminal_mood_'..i,eq(body.stats.values,originalBody.stats.values))
    check('arcade_actual_native_completion_'..i,terminal and terminal.status=='completed'and terminal.sourceResult.won==original.didWin
        and terminal.nativeProgress.sourceUpdates==10 and obj.data.PA_arcadeScreenOn==nil and obj.data.SAONpcGameLease==nil)
    check('arcade_measured_source_consequence_'..i,terminal.actualMeasuredBefore.STRESS~=nil and terminal.actualMeasuredAfter.STRESS==body.stats.values.STRESS)
    local remaining=#body.items;payment:perform();action:perform();action:complete()
    check('arcade_exact_once_effects_'..i,#body.items==remaining and #__records['arcade-'..i].gamesOutcomes==1)
end
body,obj=arcadeFixture('arcade-no-coin','pa_arcades_0',0)
check('arcade_no_coin_refused',#G.offers('arcade-no-coin',body)==0)
body,obj=arcadeFixture('arcade-no-power','pa_arcades_0',2);obj.power=false
check('arcade_no_power_refused',#G.offers('arcade-no-power',body)==0)
body,obj=arcadeFixture('arcade-incomplete-source','pa_pinballs_21',2)
check('arcade_unsupported_machine_refused',#G.offers('arcade-incomplete-source',body)==0)
body,obj=arcadeFixture('arcade-partial','pa_arcades_0',2)
check('arcade_partial_begin',G.begin('arcade-partial',body,offer('arcade-partial',body),'purpose:arcade-partial'))
local payment=ISTimedActionQueue.queues[body];native(payment,0);payment:perform();payment:complete();action=ISTimedActionQueue.queues[body];native(action,0);action:update()
action:perform();action:complete()
check('arcade_native_progress_refuses_success',G.work('arcade-partial')and G.outcome('arcade-partial',1)==nil and obj.data.PA_arcadeScreenOn==true)
G.interrupt('arcade-partial',body,'partial')
check('arcade_partial_not_success',G.outcome('arcade-partial',1).status=='interrupted'and G.outcome('arcade-partial',1).sourceResult==nil and #body.items==1 and obj.data.PA_arcadeScreenOn==nil)
body,obj=arcadeFixture('arcade-custody','pa_arcades_0',2)
check('arcade_custody_admission',G.begin('arcade-custody',body,offer('arcade-custody',body),'purpose:arcade-custody'))
body.items={};payment=ISTimedActionQueue.queues[body];native(payment,0);payment:perform();payment:complete()
check('arcade_currency_requeried_before_effect',G.outcome('arcade-custody',1).status=='interrupted'and G.outcome('arcade-custody',1).sourceResult==nil and G.outcome('arcade-custody',1).nativeProgress.payment.sourcePaid==false)
body,obj=arcadeFixture('arcade-bag','pa_arcades_0',2)
local coins=body.items
local inner={getItems=function()return list(coins)end,Remove=function(_,value)for i,v in ipairs(coins)do if v==value then table.remove(coins,i);break end end end}
local bag={getFullType=function()return 'Base.Wallet'end,IsInventoryContainer=function()return true end,getInventory=function()return inner end}
body.items={bag};body:getInventory().getCountTypeRecurse=function(_,type)return type=='Base.SilverCoin'and #coins or 0 end
ProjectArcade_Currency.Config.Cost=2
check('arcade_nested_currency_admission',G.begin('arcade-bag',body,offer('arcade-bag',body),'purpose:arcade-bag'))
payment=ISTimedActionQueue.queues[body];native(payment,0);payment:perform();payment:complete()
check('arcade_exact_recursive_currency',#coins==0 and #body.items==1 and G.work('arcade-bag').nativeProgress.payment.beforeCount==2 and G.work('arcade-bag').nativeProgress.payment.afterCount==0)
action=ISTimedActionQueue.queues[body];native(action,0);G.interrupt('arcade-bag',body,'bag-proof-ended');ProjectArcade_Currency.Config.Cost=1
b,o,action=enter('retired-purpose','pong');native(action,0);__records['retired-purpose'].purposeRetired=true;action:update()
local retired=G.outcome('retired-purpose',1)
check('retired_purpose_cannot_play',retired and retired.status=='interrupted'and retired.nativeProgress.sourceUpdates==0)
__result='PASS D2 leisure games '..n;print(__result)
