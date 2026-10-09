-- Actual native actor/action/track host joined to the unchanged Music/social owners.
local M,O,Q,C=SAO.LeisureMusic,SAO.Organization
local checks=0
local function check(name,pass)checks=checks+1;assert(pass,'D2_NATIVE_PARTNER:'..name);print('CASE '..name)end
local state=fixture('placed',true)
local rendererBody=__body
__body,__peer=__nativeBody,__nativePeer
__records={person={id='person'},peer={id='peer'}};__bodies={person=__body,peer=__peer}
__queues={};__privateMusic=true;__owned=true;__admit=true;__hours=10
for id,b in pairs(__bodies)do
 b:getModData().SAOPersonId=id;b:getModData().SAOExternalToken=nil;b:getModData().PlayerVoice=0
 __initSourceTraits(b);LSMoodleManager.init(b)
 b:setPrimaryHandItem(nil);b:setSecondaryHandItem(nil);b:setSitOnGround(false);b:setSittingOnFurniture(false)
 b:getStats():set(CharacterStat.ENDURANCE,.8);b:getStats():set(CharacterStat.FATIGUE,.2);b:getStats():set(CharacterStat.PAIN,0)
end
SAO.Body={get=function(id)return __bodies[id]end}
SAO.Needs.ownsRecoveryBody=function(id,b)return __owned and __bodies[id]==b end
SAO.Needs.workAvailable=function(b)return __queues[b]==nil end
SAO.Needs.read=function()return{hunger=0,thirst=0,fatigue=0}end
SAO.Perception.leisureAudioSources=function(id)local row={};for k,v in pairs(__row)do row[k]=v end;row.actorId=id;return{row}end
SAO.Perception.resolveLeisureAudioSource=function(id,b,key)return __bodies[id]==b and key==__row.key and __target or nil end
SAO.Perception.canHearLeisureSource=function(id,b,row,range)return __hearing and(id~='person'or __privateMusic)and __bodies[id]==b and row.actorId==id and range>0 end
SAO.Perception.knownPeople=function(id)return{{id=id=='person'and'peer'or'person',observedAtHours=__hours}}end
SAO.Perception.nearestBelievedThreat=function()return nil end
SAO.Standing={relationsOf=function(id)return{[id=='person'and'peer'or'person']={trust=.6,hostile=false}}end,
 trust=function()return .6 end,isHostileTo=function()return false end,groupOf=function()return nil end,mayAttemptBelieved=function()return true end}
SAO.Disposition={traits=function()return{talkativeness=.7,discipline=.2}end}
SAO.PersonalMemory={query=function(id)return{actorId=id,status='controlled-dated-recall',episodes={{actorId=id,ownerId=id,accessible=true,accessibility=1,
 valence=.3,episodeId='dated-dance:'..id,sourceId='LifestyleHobbies',sourceSha256=string.rep('a',64),provenance='controlled-native-personal-input'}}}end}
SAO.ProceduralPlanning.participationInterests=function()return{related=true,competing=false}end
SAO.Controller={tick=function()return 100 end,agents={}}
SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)local w=M.work(id);if __admit and w and w.purposeId==pid and w.workId==wid then w.ownerName='SAO.LeisureMusic';return w end end
ISTimedActionQueue.add=function(a)__queues[a.character]=a;__nativeQueue(a)end
ISTimedActionQueue.hasAction=function(a)return __queues[a.character]==a end
ISTimedActionQueue.getTimedActionQueue=function(b)return{resetQueue=function()__queues[b]=nil end,onCompleted=function(_,a)if __queues[b]==a then __queues[b]=nil end end}end
SAOJavaBridge.privateCarriedItems=function(_,b)return b:getInventory():getItems()end
SAOJavaBridge.canConverseNow=function(_,a,b,range)return a~=b and range>0 end
for _,name in ipairs({'registerNativeDanceCycle','observeNativeDanceCycle','nativeDanceCycleCurrent','nativeDanceCycleCompletionCurrent','nativeDanceCycleCompletionReady','unregisterNativeDanceCycle'})do
 SAOJavaBridge[name]=function(_,...)return __bridge[name](__bridge,...)end
end
SAO.Coordination={};SAO.Communication={};assert(loadstring(__sources['social:coord']))();assert(loadstring(__sources['social:comm']))()
Q,C=SAO.Coordination,SAO.Communication
SandboxVars.Debug={DanceAnim=false};__sourceTick()
check('actual_native_mutual_LOS',__body:CanSee(__peer)and __peer:CanSee(__body))
check('current_private_public_audio',M.currentHeardMusic('person',__body).soundObserved and M.currentHeardMusic('peer',__peer).soundObserved)
local function choice(id,role)for _,r in ipairs(M.danceChoices(id,__bodies[id]))do if r.role==role then return r end end end
local choiceSource=assert(choice('person','source'))
local p=assert(O.proposeDance('person','peer',choiceSource.id,'target',__hours+1))
check('actual_delivered_invitation',C.deliverProcessProposal('person','peer',p.processId,'spoken'))
local response=Q.formResponse('peer',p.processId,__peer,'idle','native-source-dance')
check('actual_personal_acceptance',response and response.response=='accept')
check('actual_delivered_return',C.deliverPendingResponses('peer','person','spoken')==1)
local function begin(id)
 local offer;for _,o in ipairs(M.offers(id,__bodies[id]))do if o.dance then offer=o;break end end
 assert(offer,'native typed partner offer absent:'..id);local ok,w=M.begin(id,__bodies[id],offer,'purpose:1');assert(ok,tostring(w));return w,__queues[__bodies[id]]
end
local w,a=begin('person');local pw,pa=begin('peer')
local xpBefore=__body:getXp():getXP(Perks.Dancing);local peerXpBefore=__peer:getXp():getXP(Perks.Dancing)
__nativeUpdate(__body);__nativeUpdate(__peer);__nativeUpdate(__body)
check('actual_source_both_released',M.work('person').nativeProgress.danceReleased and M.work('peer').nativeProgress.danceReleased)
check('original_native_position_measurement',M.work('person').nativeProgress.sourcePartnerSetup.before.source.x==10.5
 and M.work('person').nativeProgress.sourcePartnerSetup.after.x==11 and __body:getX()==11 and __peer:getX()==11.5)
check('native_exact_role_variables',__body:getVariableString('PerformingAction')=='Bob_DancingDiscoSourceDefault'and __peer:getVariableString('PerformingAction')=='Bob_DancingDiscoTargetDefault')
__nativeTrack(__body,'Bob_DancingDiscoSourceDefault');__nativeTrack(__peer,'Bob_DancingDiscoTargetDefault')
__nativeUpdate(__body);__nativeUpdate(__peer)
__nativeUpdate(__body)
check('both_production_native_listener_registrations',M.work('person').nativeProgress.nativeCycleOwnerState=='awaiting-observed-native-loop'
 and M.work('peer').nativeProgress.nativeCycleOwnerState=='awaiting-observed-native-loop')
check('actual_M_emission_guard',M.nativeDanceCycleAllowed(__body,w.workId,'Bob_DancingDiscoSourceDefault')and M.nativeDanceCycleAllowed(__peer,pw.workId,'Bob_DancingDiscoTargetDefault'))
check('native_no_loop_no_completion',M.outcome('person',w.sequence)==nil and M.outcome('peer',pw.sequence)==nil)
check('original_terminal_variable_initially_false',not __body:getVariableBoolean('ExerciseEnded'))
__privateMusic=false
check('actual_M_withdrawn_private_music_false',not M.nativeDanceCycleAllowed(__body,w.workId,'Bob_DancingDiscoSourceDefault'))
__nativeLoop(__body);__privateMusic=true
check('withdrawn_actual_M_guard_loop_rejected',__bridge:observeNativeDanceCycle(__body,w.workId)==nil)
__nativeUpdate(__body);__nativeUpdate(__peer)
__nativeDiagnostics(__body);__nativeDiagnostics(__peer)
print('NATIVE_REGISTER '..tostring(M.work('person').nativeProgress.nativeCycleOwnerState)..' / '..tostring(M.work('peer').nativeProgress.nativeCycleOwnerState))
__nativeLoop(__body);__nativeLoop(__peer)
check('actual_native_two_independent_receipts',__bridge:observeNativeDanceCycle(__body,w.workId)and __bridge:observeNativeDanceCycle(__peer,pw.workId))
__nativeUpdate(__body);__nativePerform(__body)
local out=M.outcome('person',w.sequence)
check('actual_native_M_original_perform_completed',out and out.status=='completed'and out.nativeProgress.sourcePartnerCycle.actorId=='person'and out.nativeProgress.sourcePartnerCycle.bodyToken==nil)
check('original_source_terminal_variable_transition',__body:getVariableBoolean('ExerciseEnded')and not __body:getVariableBoolean('ExerciseStarted'))
check('actual_source_peer_stop_not_completion',__peer:getModData().PartnerStopped==true and M.outcome('peer',pw.sequence)==nil)
__nativeUpdate(__peer);__nativePerform(__peer)
local peerOut=M.outcome('peer',pw.sequence)
check('peer_native_stop_interrupted',peerOut and peerOut.status=='interrupted'and peerOut.nativeProgress.sourcePartnerCycle==nil)
check('no_partner_XP_or_solo_effects',__skillRequests==0 and __body:getStats():get(CharacterStat.ENDURANCE)>.79 and __peer:getStats():get(CharacterStat.ENDURANCE)>.79)
check('actual_native_partner_XP_unchanged',__body:getXp():getXP(Perks.Dancing)==xpBefore and __peer:getXp():getXP(Perks.Dancing)==peerXpBefore)
check('typed_actual_Org_results',O.consumeDance('person',p.processId,w.sequence)and O.consumeDance('peer',p.processId,pw.sequence)
 and out.status=='completed'and peerOut.status=='interrupted')
local countBefore=#__records.person.leisureMusicOutcomes;local peerCountBefore=#__records.peer.leisureMusicOutcomes
a.action:perform();pa.action:perform();a:update();pa:update()
check('native_source_callback_replay_no_duplicate_outcomes',#__records.person.leisureMusicOutcomes==countBefore and #__records.peer.leisureMusicOutcomes==peerCountBefore
 and __body:getXp():getXP(Perks.Dancing)==xpBefore and __peer:getXp():getXP(Perks.Dancing)==peerXpBefore)
check('closed_owners_no_native_completion_replay',not M.nativeDanceCycleAllowed(__body,w.workId,'Bob_DancingDiscoSourceDefault')
 and not __bridge:nativeDanceCycleCompletionCurrent(__body,w.workId,out.nativeProgress.sourcePartnerCycle.sequence)
 and O.consumeDance('person',p.processId,w.sequence)and O.consumeDance('peer',p.processId,pw.sequence))
print('PASS native Music partner join '..checks)
