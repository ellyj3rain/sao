local O,Q,C=SAO.Organization
local actualCommitments=O.activeCommitments
local count=0
local function check(name,value)count=count+1;assert(value,'D2_PARTNER_DANCE:'..name);print('CASE '..name)end
local function fresh()
 M.reset('partner-dance-fixture');O.processes={};O.processOrder={};O.processMeta={sequence=0};O.workReceipts={}
 local state=fixture('placed',true);__level=0;__seconds=1;__heard=true;__known=true;__hostile=false;__need=0;__negative=false;__competing=false;__obligation=false;__privateMusic=true
 SandboxVars.Debug={DanceAnim=false};Metabolics.Fitness='Fitness';CharacterTrait.PARTYANIMAL='PARTYANIMAL'
 __body.getPrimaryHandItem=function()return nil end;__body.setPrimaryHandItem=function()end
 __body.hasModData=function()return true end;__body.getUsername=function()return 'NativeSourceName'end
 __body:getModData().SAOPersonId='person';__body:getModData().PlayerVoice=0
 __x=10;__y=10;__body.getX=function()return __x end;__body.getY=function()return __y end
 __body.setX=function(_,v)__x=v end;__body.setY=function(_,v)__y=v end
 __body.faceLocation=function()__sourceFaced=true end;__body.faceLocationF=function()__sourceFacedF=true end
 __body.CanSee=function()return __seen end;__seen=true;__sourceFaced=false;__sourceFacedF=false;__targetFaced=false
 local peer={};for key,value in pairs(__body)do peer[key]=value end
 local data={SAOPersonId='peer',SAOExternalToken='generation:peer',PlayerVoice=0,
  LSMoodles={PartyGood={Value=0},PartyBad={Value=0},Embarrassed={Value=0}}}
 peer.getModData=function()return data end;peer.getUsername=function()return 'NativeTargetName'end
 peer.getX=function()return 11 end;peer.getY=function()return 10 end;peer.setX=function()error('source moved target')end;peer.setY=peer.setX
 peer.faceLocation=function()__targetFaced=true end;peer.faceLocationF=peer.faceLocation
 peer.getStats=function()return __stats2 end;peer.isDead=function()return false end
 __body.isDead=function()return false end
 local sounds={};peer.getEmitter=function()return{playSound=function()error('partner issued unexpected audio')end,isPlaying=function()return false end,stopSound=function()end}end
 __peer=peer;__stats2:set(CharacterStat.ENDURANCE,.8);__stats2:set(CharacterStat.PAIN,0)
 __records.peer={id='peer'};__bodies={person=__body,peer=peer}
 SAO.Body={get=function(id)return __bodies[id]end}
 SAO.Needs.ownsRecoveryBody=function(id,b)return __owned and __bodies[id]==b end
 __queues={};SAO.Needs.workAvailable=function(b)return __queues[b]==nil end
 SAOJavaBridge.privateCarriedItems=function()return{size=function()return 0 end}end
 SAOJavaBridge.canConverseNow=function(_,a,b,range)return __heard and a~=b and range>0 end
 SAO.Perception.leisureAudioSources=function(id)
  if not __visible then return{}end;local row={};for k,v in pairs(__row)do row[k]=v end;row.actorId=id;return{row}
 end
 SAO.Perception.resolveLeisureAudioSource=function(id,b,key)return __visible and __bodies[id]==b and key==__row.key and __target or nil end
 SAO.Perception.canHearLeisureSource=function(id,b,row,range)return __hearing and(id~='person'or __privateMusic)and __bodies[id]==b and row.actorId==id and range>0 end
 SAO.Perception.knownPeople=function(id)return __known and{{id=id=='person'and'peer'or'person',observedAtHours=__hours}}or{}end
 SAO.Perception.nearestBelievedThreat=function()return nil end
 SAO.Needs.read=function()return{hunger=__need,thirst=0,fatigue=0}end
 SAO.Standing={relationsOf=function(id)return{[id=='person'and'peer'or'person']={trust=.6,hostile=__hostile}}end,
  trust=function()return .6 end,isHostileTo=function()return __hostile end,groupOf=function()return nil end,mayAttemptBelieved=function()return true end}
 SAO.Disposition={traits=function()return{talkativeness=.7,discipline=.2}end}
 SAO.PersonalMemory={query=function(id)return{actorId=id,status='controlled-dated-recall',episodes={{actorId=id,ownerId=id,accessible=true,accessibility=1,
  valence=__negative and -.8 or .3,episodeId='dated-dance:'..id,sourceId='LifestyleHobbies',sourceSha256=string.rep('a',64),provenance='controlled-native-personal-input'}}}end}
 SAO.ProceduralPlanning.participationInterests=function()return{related=true,competing=__competing}end
 O.activeCommitments=function(id)local rows=actualCommitments(id);if __obligation then rows[#rows+1]={processId='other-obligation'}end;return rows end
 SAO.ProceduralPlanning.planLeisure=function()return{id='purpose:1'}end
 SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)local w=M.work(id);if __admit and w and w.purposeId==pid and w.workId==wid then w.ownerName='SAO.LeisureMusic';return w end end
 ISTimedActionQueue.add=function(action)
  __queues[action.character]=action
  action.action={setUseProgressBar=function()end,setActionAnim=function(_,anim)__animation=anim end,
   setOverrideHandModelsObject=function()end,setOverrideHandModelsString=function()end,getJobDelta=function()return __delta end,
   setTime=function()end,setCurrentTime=function()end,resetJobDelta=function()end,forceComplete=function()action:perform()end,
   forceStop=function()if __queues[action.character]==action then action:stop();__queues[action.character]=nil end end}
 end
 ISTimedActionQueue.hasAction=function(action)return __queues[action.character]==action end
 ISTimedActionQueue.getTimedActionQueue=function(b)return{resetQueue=function()__queues[b]=nil end,onCompleted=function()__queues[b]=nil end}end
 SAO.Coordination={};SAO.Communication={};assert(loadstring(__sources['social:coord']))();assert(loadstring(__sources['social:comm']))()
 Q=SAO.Coordination;C=SAO.Communication;SAO.Controller={agents={},tick=function()return 100 end}
 -- CONTROLLER_SOURCE
 __agent={rec=__records.person};SAO.Controller.agents.person=__agent
 __sourceTick();return state
end
local function choice(id,role)for _,row in ipairs(M.danceChoices(id,__bodies[id]))do if row.role==role then return row end end end
local function invitation(deliver)
 local state=fresh();local own=assert(choice('person','source'))
 local p=assert(O.proposeDance('person','peer',own.id,'target',__hours+1))
 if deliver~=false then assert(C.deliverProcessProposal('person','peer',p.processId,'spoken'))end
 return p,state
end
local function agreed()
 local p,state=invitation();local response=Q.formResponse('peer',p.processId,__peer,'idle','source-dance-proof')
 assert(response and response.response=='accept');assert(C.deliverPendingResponses('peer','person','spoken')==1)
 return p,state
end
local function begin(id)
 local row;for _,o in ipairs(M.offers(id,__bodies[id]))do if o.dance then row=o;break end end
 assert(row,'typed dance offer missing:'..id);local ok,w=M.begin(id,__bodies[id],row,'purpose:1');assert(ok,tostring(w));return w,__queues[__bodies[id]]
end
fresh();local rows=SAO.Controller.danceInvitationOffers('person',__agent,__body,100)
check('own_source_invitation_collection',#rows==2 and rows[1].partnerRole=='target')
local originalChoices=M.danceChoices;M.danceChoices=function(id,b)assert(id=='person','collector read private partner repertoire');return originalChoices(id,b)end
check('collector_does_not_query_private_partner',#SAO.Controller.danceInvitationOffers('person',__agent,__body,100)==2);M.danceChoices=originalChoices
local stale={};for k,v in pairs(rows[1])do stale[k]=v end;stale.choiceId='absent-own-source-choice'
check('chosen_invitation_requeries_source',not SAO.Controller.beginLeisureOffer('person',__agent,__body,100,{payload={kind='dance-invitation',offer=stale}}))
fresh();rows=SAO.Controller.danceInvitationOffers('person',__agent,__body,100)
check('chosen_controller_invitation_actual_delivery',SAO.Controller.beginLeisureOffer('person',__agent,__body,100,{payload={kind='dance-invitation',offer=rows[1]}})
 and O.viewFor('peer',__records.person.danceInvitation.processId,false)and __records.person.danceInvitation.agreement=='unobserved')
__hostile=true;check('hostile_contact_not_invited',#SAO.Controller.danceInvitationOffers('person',__agent,__body,100)==0)
__hostile=false;__known=false;check('unknown_contact_not_invited',#SAO.Controller.danceInvitationOffers('person',__agent,__body,100)==0)
local p,state=invitation(false);check('undelivered_proposal_no_acceptance',Q.formResponse('peer',p.processId,__peer,'idle','test')==nil and O.danceOffer('person',p.processId)==nil)
p,state=invitation();local response,context=Q.formResponse('peer',p.processId,__peer,'idle','test')
check('actual_typed_personal_appraisal',response.response=='accept'and context.interests.sourceChoiceId==choice('peer','target').id)
check('private_response_no_assumed_agreement',O.danceOffer('person',p.processId)==nil)
__heard=false;check('unheard_return_no_agreement',C.deliverPendingResponses('peer','person','spoken')==0 and O.danceOffer('person',p.processId)==nil)
__heard=true;check('delivered_mutual_claimed_parts',C.deliverPendingResponses('peer','person','spoken')==1 and O.danceOffer('person',p.processId)and O.danceOffer('peer',p.processId))
check('generic_proposal_consent_and_receipt_bypass_refused',O.raiseMatter('person','leisure-dance',nil,{cooperative=true},{'peer'}, {})==nil
 and O.appraiseMatter(p.processId,'peer',{choice='accept'})==nil and O.respond(p.processId,'peer','accept',{}, {})==nil
 and not O.recordReception(p.processId,'peer',1,'spoken','person',{})and not O.deliverResponse(p.processId,'peer','person','spoken',{}))
p,state=invitation();__need=.9;response=Q.formResponse('peer',p.processId,__peer,'idle','test');check('current_need_defers',response.response=='defer')
p,state=invitation();__negative=true;response=Q.formResponse('peer',p.processId,__peer,'idle','test');check('negative_personal_recall_declines',response.response=='decline')
p,state=invitation();__competing=true;response=Q.formResponse('peer',p.processId,__peer,'idle','test');check('competing_personal_interest_defers',response.response=='defer')
p,state=invitation();__obligation=true;response=Q.formResponse('peer',p.processId,__peer,'idle','test');check('other_accepted_obligation_defers',response.response=='defer')
p,state=invitation();__hearing=false;response=Q.formResponse('peer',p.processId,__peer,'idle','test');check('no_current_music_declines',response.response=='decline')
p,state=agreed();local w,a=begin('person');a:start();a:update()
check('single_source_owner_no_partner_release',not M.work('person').nativeProgress.danceReleased and __body:getModData().IsDancingPartner=='none'and not __body:getModData().WantsToDance)
local pw,pa=begin('peer');pa:start();a:update();pa:update()
local own=O.danceOffer('person',p.processId)
check('generic_work_admission_refused',not O.noteWorkAdmission(own.commitmentId,'SAO.LeisureMusic',w.workId,{}))
check('generic_procedure_result_refused',not O.consumeProcedureResult({commitmentId=own.commitmentId,actorId='person',id=w.workId,
 token='dance:performed',stepId='perform-originator',owner='SAO.LeisureMusic',status='completed',at=__hours}))
check('both_actual_source_owners_release_original_acceptance',M.work('person').nativeProgress.danceReleased and M.work('peer').nativeProgress.danceReleased
 and __body:getModData().IsDancingPartner=='source'and __peer:getModData().IsDancingPartner=='target'
 and __body:getModData().WantsToDance==true and __peer:getModData().WantsToDance==true)
check('original_source_position_and_mutual_facing',__x==10.5 and __y==10 and __sourceFaced and __sourceFacedF and __targetFaced)
check('original_partner_animation_no_synthetic_solo_effects',__animation=='Bob_DancingDiscoTargetDefault'and __skillRequests==0
 and __stats:get(CharacterStat.ENDURANCE)>.79 and M.outcome('person',w.sequence)==nil and M.outcome('peer',pw.sequence)==nil)
check('no_timer_partner_completion',__seconds==1 and M.work('person').phase=='awaiting-native-partner-animation-cycle')
check('emission_guard_only_exact_maintained_owners',M.nativeDanceCycleAllowed(__body,w.workId,'Bob_DancingDiscoSourceDefault')
 and not M.nativeDanceCycleAllowed(__body,pw.workId,'Bob_DancingDiscoSourceDefault')
 and not M.nativeDanceCycleAllowed(__body,w.workId,'Bob_DancingDiscoTargetDefault'))
__privateMusic=false;check('native_emission_guard_requires_current_private_music',not M.nativeDanceCycleAllowed(__body,w.workId,'Bob_DancingDiscoSourceDefault'));__privateMusic=true
local forged={actorId='foreign',bodyToken=w.bodyToken,workId=w.workId,sequence=1,clip='Bob_DancingDiscoSourceDefault',engineAtHours=10,authority='native-current-owned-source-animation-loop'}
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end;SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end;SAOJavaBridge.observeNativeDanceCycle=function()return forged end
SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
SAOJavaBridge.unregisterNativeDanceCycle=function()return true end
a:update();check('foreign_native_cycle_receipt_refused',M.outcome('person',w.sequence)==nil)
forged.actorId='person';SAOJavaBridge.nativeDanceCycleCurrent=function()return false end
a:update();check('noncurrent_native_cycle_receipt_refused',M.outcome('person',w.sequence)==nil)
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil;SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil;SAOJavaBridge.nativeDanceCycleCurrent=nil
M.interrupt('person',__body,'urgent-need')
check('source_partner_stop_once_not_shared_completion',__peer:getModData().PartnerStopped==true and __body:getModData().WantsToDance==false
 and M.outcome('person',w.sequence).status=='interrupted'and M.outcome('peer',pw.sequence)==nil
 and O.danceParticipationFor('person',p.processId)==nil)
pa:update();check('other_original_owner_interrupts_independently',M.outcome('peer',pw.sequence).status=='interrupted'and __peer:getModData().WantsToDance==false)
p,state=agreed();__hours=12;check('expired_agreement_not_executable',O.danceOffer('person',p.processId)==nil)
p,state=agreed();state.playbackEpoch=state.playbackEpoch+1;__sourceTick();check('changed_shared_music_invalidates_agreement',O.danceOffer('person',p.processId)==nil)
p,state=agreed();check('generic_revision_cannot_rewrite_source_consent',O.reviseMatter(p.processId,'person',{cooperative=true}, {})==nil)
fresh();__body:getModData().IsListeningToMusicStyle='metal';check('unimplemented_original_partner_genre_refused',#M.danceChoices('person',__body)==0)
local p=invitation();check('generic_originator_commitment_refused',O.commitOriginator(p.processId,'person',{capabilities={['perform-dance']=true},stepIds={'perform-originator'}})==nil)
p,state=invitation();check('foreign_role_acceptance_refused',O.respondDance('peer',p.processId,choice('peer','source').id,'accept',{})==nil)
p,state=agreed();local first,action=begin('person');action:start();local second,other=begin('peer');other:start();__seen=false;action:update()
check('current_native_visibility_required_before_release',not M.work('person').nativeProgress.danceReleased and not __body:getModData().WantsToDance)
__seen=true;__admit=false;action:update();check('lost_typed_purpose_never_releases',M.outcome('person',first.sequence).status=='interrupted'and not __peer:getModData().WantsToDance)
p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start();action:update();other:update()
local unregisterCalls=0
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end;SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end;SAOJavaBridge.observeNativeDanceCycle=function()return nil end
SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
SAOJavaBridge.unregisterNativeDanceCycle=function()unregisterCalls=unregisterCalls+1;return true end;action:update()
__peer.hasModData=function()error('controlled actual PartnerStopDance receiver fault')end
local md=__body:getModData();md.WantsToDance=nil
setmetatable(md,{__newindex=function(t,k,v)if k=='WantsToDance'then error('controlled original willingness cleanup fault')end;rawset(t,k,v)end})
local cleanupCall=pcall(M.interrupt,'person',__body,'urgent-need');local failed=M.outcome('person',first.sequence)
check('independent_source_cleanup_faults_cannot_escape_or_skip_native_retirement',cleanupCall and failed and failed.status=='interrupted'
 and failed.cleanupSucceeded==false and #failed.nativeProgress.sourcePartnerCleanup.failures==2 and unregisterCalls==1 and M.work('person')==nil)
setmetatable(md,nil);__peer.hasModData=function()return true end
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil;SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil;SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
for _,retirement in ipairs({'false','throws'})do
 p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start();action:update();other:update()
 local attempts=0
 SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end;SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end;SAOJavaBridge.observeNativeDanceCycle=function()return nil end
 SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
 SAOJavaBridge.unregisterNativeDanceCycle=function()attempts=attempts+1;if retirement=='throws'then error('controlled native retirement fault')end;return false end
 action:update();local called=pcall(M.interrupt,'person',__body,'urgent-need');local result=M.outcome('person',first.sequence)
 check('native_retirement_'..retirement..'_explicitly_unconfirmed',called and attempts==1 and result and result.cleanupSucceeded==false
  and result.nativeProgress.sourcePartnerCleanup.nativeListenerRetirement==(retirement=='false'and'unconfirmed-or-already-absent'or'failed'))
 SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil;SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil;SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
end
state=fresh();__body:getModData().SAOExternalToken=nil;__peer:getModData().SAOExternalToken=nil
local ownChoice=choice('person','source');p=assert(O.proposeDance('person','peer',ownChoice.id,'target',__hours+1))
assert(C.deliverProcessProposal('person','peer',p.processId,'spoken'));assert(Q.formResponse('peer',p.processId,__peer,'idle','test'))
assert(C.deliverPendingResponses('peer','person','spoken')==1);first,action=begin('person');action:start();second,other=begin('peer');other:start();action:update();other:update()
check('tokenless_owned_source_generation_binding',first.bodyToken==nil and first.bodyGenerationKnown==false
 and M.nativeDanceCycleAllowed(__body,first.workId,'Bob_DancingDiscoSourceDefault'))
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end;SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end;SAOJavaBridge.nativeDanceCycleCurrent=function()return true end;SAOJavaBridge.unregisterNativeDanceCycle=function()return true end
SAOJavaBridge.observeNativeDanceCycle=function()return{actorId='person',bodyToken='null',workId=first.workId,sequence=1,clip='Bob_DancingDiscoSourceDefault',
 engineAtHours=10,authority='native-current-owned-source-animation-loop'}end
action:update();check('string_null_is_not_unknown_generation',M.outcome('person',first.sequence)==nil)
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil;SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil;SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
-- Readiness must be confirmed before attaching any native cycle listener.
p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start();action:update();other:update()
local registrationAttempts=0
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return false end;SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()registrationAttempts=registrationAttempts+1;return true end
SAOJavaBridge.observeNativeDanceCycle=function()return nil end;SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
SAOJavaBridge.unregisterNativeDanceCycle=function()return true end
action:update();check('unready_native_completion_never_registers_cycle',registrationAttempts==0 and M.outcome('person',first.sequence)==nil
 and M.work('person').nativeProgress.nativeCycleOwnerState=='native-animation-cycle-helper-unavailable')
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil
SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil;SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
-- Completion authority is a controlled host here; the separate actual native
-- caller proof qualifies the BaseAction.perform transition and exact scope.
for _,completion in ipairs({'absent','false','true','cleanup-false'})do
 p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start();action:update();other:update()
 SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end;SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end
 SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
 SAOJavaBridge.nativeDanceCycleCompletionCurrent=completion~='absent'and function()return completion~='false'end or nil
 SAOJavaBridge.unregisterNativeDanceCycle=function()return completion~='cleanup-false'end
 SAOJavaBridge.observeNativeDanceCycle=function()return{actorId='person',bodyToken=first.bodyToken,workId=first.workId,sequence=1,
  clip='Bob_DancingDiscoSourceDefault',engineAtHours=10,authority='native-current-owned-source-animation-loop'}end
 action:update();local result=M.outcome('person',first.sequence)
 if completion=='true'then check('completion_scope_accepts_confirmed_native_cycle',result and result.status=='completed')
 elseif completion=='cleanup-false'then check('perform_cleanup_failure_has_precise_reason',result and result.status=='interrupted'
  and result.reason=='source-partner-cleanup-failed'and not result.cleanupSucceeded)
 elseif completion=='absent'then check('completion_scope_absent_refused',not result and M.work('person').nativeProgress.nativeCycleOwnerState=='native-animation-cycle-helper-unavailable')
 else check('completion_scope_false_refused',result and result.status=='interrupted')end
 SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil;SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil;SAOJavaBridge.nativeDanceCycleCurrent=nil
 SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
end
-- The two native action callbacks finish in separate updates. The first
-- performer cannot cancel the other person's already accepted source part.
p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start()
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end
SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end
SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
SAOJavaBridge.unregisterNativeDanceCycle=function()return true end
SAOJavaBridge.observeNativeDanceCycle=function(_,body,workId)
 local clip=body==__body and 'Bob_DancingDiscoSourceDefault' or 'Bob_DancingDiscoTargetDefault'
 if not M.nativeDanceCycleAllowed(body,workId,clip)then return nil end
 local work=body==__body and first or second
 return{actorId=body:getModData().SAOPersonId,bodyToken=work.bodyToken,workId=workId,sequence=1,
  clip=clip,engineAtHours=__hours,authority='native-current-owned-source-animation-loop'}
end
action:update()
check('first_native_dance_part_preserves_second',M.outcome('person',first.sequence)
 and M.outcome('person',first.sequence).status=='completed' and M.work('peer')
 and not __peer:getModData().PartnerStopped
 and M.nativeDanceCycleAllowed(__peer,second.workId,'Bob_DancingDiscoTargetDefault'))
check('first_native_dance_part_has_no_shared_receipt',O.danceParticipationFor('person',p.processId)==nil
 and O.danceParticipationFor('peer',p.processId)==nil)
SAO.Cognition=SAO.Cognition or {};local priorDanceOutcome=SAO.Cognition.danceOutcome;local cognitionCalls={}
SAO.Cognition.danceOutcome=function(id,pid)
 assert(O.danceParticipationFor(id,pid),'dance receipt must precede cognition')
 cognitionCalls[id]=(cognitionCalls[id]or 0)+1
 return cognitionCalls[id]>1
end
other:update()
check('second_native_dance_part_completes',M.outcome('peer',second.sequence)
 and M.outcome('peer',second.sequence).status=='completed')
local ownReceipt=O.danceParticipationFor('person',p.processId)
local peerReceipt=O.danceParticipationFor('peer',p.processId)
local ownResult=M.outcome('person',first.sequence);local peerResult=M.outcome('peer',second.sequence)
check('two_private_committed_dance_receipts',ownReceipt and peerReceipt
 and ownReceipt.actorId=='person'and peerReceipt.actorId=='peer'
 and ownReceipt.partnerId=='peer'and peerReceipt.partnerId=='person'
 and ownReceipt.processId==p.processId and peerReceipt.processId==p.processId
 and ownReceipt.revision==p.revision and peerReceipt.revision==p.revision
 and ownReceipt.sourceId=='LifestyleHobbies'and peerReceipt.sourceId=='LifestyleHobbies'
 and ownReceipt.musicKey==peerReceipt.musicKey and ownReceipt.role=='source'and peerReceipt.role=='target'
 and ownReceipt.coPerformance.status=='completed'
 and ownReceipt.coPerformance.basis=='two-committed-native-source-dance-results'
 and ownReceipt.coPerformance.ownResultId==first.workId
 and ownReceipt.coPerformance.partnerResultId==second.workId
 and peerReceipt.coPerformance.ownResultId==second.workId
 and peerReceipt.coPerformance.partnerResultId==first.workId)
check('dance_receipts_retain_only_own_measured_interval',ownReceipt.before.Stress==ownResult.before.Stress
 and ownReceipt.after.Stress==ownResult.after.Stress
 and peerReceipt.before.Stress==peerResult.before.Stress
 and peerReceipt.after.Stress==peerResult.after.Stress
 and ownReceipt.partnerBefore==nil and ownReceipt.partnerAfter==nil
 and ownReceipt.enjoyment==nil and ownReceipt.trust==nil
 and ownReceipt.measurementAuthority=='actual-source-interval; concurrent-effects-not-isolated')
check('dance_cognition_uses_frozen_actor_private_receipts',cognitionCalls.person==1 and cognitionCalls.peer==1)
ownReceipt.before.Stress=999
check('dance_receipt_detached_and_private',O.danceParticipationFor('person',p.processId).before.Stress~=999
 and O.danceParticipationFor('foreign',p.processId)==nil)
check('dance_duplicate_retries_without_receipt_rewrite',O.consumeDance('person',p.processId,first.sequence)
 and cognitionCalls.person==2 and cognitionCalls.peer==2
 and O.danceParticipationFor('person',p.processId).id==ownReceipt.id)
SAO.Cognition.danceOutcome=priorDanceOutcome
O.processes=__roundtrip(O.processes);O.workReceipts=__roundtrip(O.workReceipts)
check('dance_private_receipts_survive_native_save_load',O.danceParticipationFor('person',p.processId).before.Stress==ownResult.before.Stress
 and O.danceParticipationFor('peer',p.processId).after.Stress==peerResult.after.Stress)
check('dance_duplicate_after_reload',O.consumeDance('peer',p.processId,second.sequence))
__records.person.leisureMusicOutcomes={};__records.peer.leisureMusicOutcomes={}
check('dance_frozen_receipts_survive_outcome_eviction',O.danceParticipationFor('person',p.processId).coPerformance.partnerResultId==second.workId
 and O.consumeDance('peer',p.processId,second.sequence))
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil
SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil
SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
-- Hold the second Organization callback after its real source perform. Each
-- changed input must be rejected before the two private receipts are frozen.
p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start()
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end
SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end
SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
SAOJavaBridge.unregisterNativeDanceCycle=function()return true end
SAOJavaBridge.observeNativeDanceCycle=function(_,body,workId)
 local clip=body==__body and 'Bob_DancingDiscoSourceDefault' or 'Bob_DancingDiscoTargetDefault'
 if not M.nativeDanceCycleAllowed(body,workId,clip)then return nil end
 local work=body==__body and first or second
 return{actorId=body:getModData().SAOPersonId,bodyToken=work.bodyToken,workId=workId,sequence=1,
  clip=clip,engineAtHours=__hours,authority='native-current-owned-source-animation-loop'}
end
action:update()
local consumeDance=O.consumeDance
O.consumeDance=function(id,pid,sequence)if id=='peer'then return true end;return consumeDance(id,pid,sequence)end
other:update();O.consumeDance=consumeDance
check('two_native_dance_results_before_second_commit_have_no_pair_receipt',M.outcome('person',first.sequence)
 and M.outcome('peer',second.sequence) and O.danceParticipationFor('person',p.processId)==nil)
local raw=__records.person.leisureMusicOutcomes[#__records.person.leisureMusicOutcomes]
local changes={{'wrong_partner_result_no_dance_receipt',raw.sourceOffer.dance,'partnerId','foreign'},
 {'wrong_revision_result_no_dance_receipt',raw.sourceOffer.dance,'revision',p.revision+1},
 {'wrong_role_result_no_dance_receipt',raw.sourceOffer.dance,'role','target'},
 {'wrong_music_result_no_dance_receipt',raw.sourceOffer,'musicKey','different-music'},
 {'wrong_body_result_no_dance_receipt',raw,'bodyToken','foreign-body'},
 {'missing_native_perform_return_no_dance_receipt',raw.nativeProgress,'sourcePerformReturned',false},
 {'wrong_native_setup_partner_no_dance_receipt',raw.nativeProgress.sourcePartnerSetup,'partnerId','foreign'}}
for _,change in ipairs(changes)do
 local name,owner,field,bad=change[1],change[2],change[3],change[4]
 local original=owner[field];owner[field]=bad
 check(name,consumeDance('peer',p.processId,second.sequence)
  and O.danceParticipationFor('person',p.processId)==nil
  and O.danceParticipationFor('peer',p.processId)==nil)
 owner[field]=original
end
check('restored_exact_dance_results_form_pair_once',consumeDance('peer',p.processId,second.sequence)
 and O.danceParticipationFor('person',p.processId).coPerformance.partnerResultId==second.workId)
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil
SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil
SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
p,state=agreed();first,action=begin('person');action:start();second,other=begin('peer');other:start()
SAOJavaBridge.nativeDanceCycleCompletionReady=function()return true end
SAOJavaBridge.nativeDanceCycleCompletionCurrent=function()return true end
SAOJavaBridge.registerNativeDanceCycle=function()return true end
SAOJavaBridge.nativeDanceCycleCurrent=function()return true end
SAOJavaBridge.unregisterNativeDanceCycle=function()return true end
SAOJavaBridge.observeNativeDanceCycle=function(_,body,workId)
 local clip=body==__body and 'Bob_DancingDiscoSourceDefault' or 'Bob_DancingDiscoTargetDefault'
 if not M.nativeDanceCycleAllowed(body,workId,clip)then return nil end
 local work=body==__body and first or second
 return{actorId=body:getModData().SAOPersonId,bodyToken=work.bodyToken,workId=workId,sequence=1,
  clip=clip,engineAtHours=__hours,authority='native-current-owned-source-animation-loop'}
end
other:update()
check('target_first_keeps_source_part_active',M.outcome('peer',second.sequence)
 and M.outcome('peer',second.sequence).status=='completed' and M.work('person')
 and not __body:getModData().PartnerStopped and O.danceParticipationFor('peer',p.processId)==nil)
action:update()
check('source_second_freezes_exact_pair',M.outcome('person',first.sequence)
 and M.outcome('person',first.sequence).status=='completed'
 and O.danceParticipationFor('person',p.processId).coPerformance.partnerResultId==second.workId)
SAOJavaBridge.nativeDanceCycleCompletionReady=nil;SAOJavaBridge.nativeDanceCycleCompletionCurrent=nil
SAOJavaBridge.registerNativeDanceCycle=nil;SAOJavaBridge.observeNativeDanceCycle=nil
SAOJavaBridge.nativeDanceCycleCurrent=nil;SAOJavaBridge.unregisterNativeDanceCycle=nil
print('PASS source partner dance '..count)
