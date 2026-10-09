local M,L=SAO.LeisureMusic,SAO.LeisureLifestyle;local checks=0
local function check(v,name)assert(v,'D2_LIFESTYLE_HEARING:'..name);checks=checks+1 end
__freshLifestyle();local performer=__body;__level=3;local receiver={};for k,v in pairs(performer)do receiver[k]=v end
local receiverMd=__roundtrip(performer:getModData());receiverMd.SAOPersonId='receiver';receiverMd.SAOExternalToken='receiver:1'
receiver.getModData=function()return receiverMd end;receiver.getStats=function()return __stats2 end
receiver.getPrimaryHandItem=function()return nil end;receiver.getSecondaryHandItem=function()return nil end
receiver.getUsername=function()return 'Acquired receiver' end;performer.getUsername=function()return 'Acquired musician' end
receiver.getPlayerNum=function()return 2 end;receiver.hasTimedActions=function()return false end
__stats2:set(CharacterStat.STRESS,.3);__stats2:set(CharacterStat.BOREDOM,20);__stats2:set(CharacterStat.UNHAPPINESS,30)
__records.receiver={id='receiver'};local bodies={person=performer,receiver=receiver};local active={};local known=true;local hearing=true
SAO.Body.get=function(id)return bodies[id]end
SAO.Needs.ownsRecoveryBody=function(id,body)return bodies[id]==body and __owned end;SAO.Needs.workAvailable=function()return true end
SAOJavaBridge.canConverseNow=function(_,source,target,range)return source==performer and target==receiver and range==8 and hearing end
SAOJavaBridge.privateCarriedItems=function(_,body)return{size=function()return body==performer and #__items or 0 end,get=function(_,n)return __items[n+1]end}end
SAO.Perception.knownPeople=function(id)return id=='receiver'and known and {{id='person'}}or{}end
SAO.Perception.leisureObjects=function()return{}end
SAO.Perception.canHearLeisureObject=function()return false end
SAO.ConceptKnowledge.infer=function(id,from)return{actorId=id,paths={{id='private:'..id..':'..from,status='expectation',evidenceIds={'acquired:'..id..':'..from}}}}end
local originalAdd=ISTimedActionQueue.add
ISTimedActionQueue.add=function(action)originalAdd(action);active[action]=true end
ISTimedActionQueue.hasAction=function(action)return active[action]==true end
SAO.ProceduralPlanning.admitHobbyWork=function(id,pid,sequence,owner)local provider=owner=='SAO.LeisureMusic'and M or L;local w=provider.work(id);return __admit and w and w.sequence==sequence end
SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)
 for _,name in ipairs({'LeisureMusic','LeisureLifestyle'})do local provider=SAO[name];local w=provider.work(id)
 if __admit and w and w.workId==wid and w.purposeId==pid then return{ownerName='SAO.'..name,sequence=w.sequence,workId=w.workId}end end
end
SAO.ProceduralPlanning.consumeHobbyOutcome=function(id,seq,owner)local provider=owner=='SAO.LeisureMusic'and M or L;return provider.outcome(id,seq)~=nil end
SAO.LeisureSkill.consume=function(id,body,owner,work,seq)local provider=owner=='SAO.LeisureMusic'and M or L;return provider.skillRequest(id,work,seq)~=nil end
addSound=function()__worldSounds=__worldSounds+1 end
local offers=M.offers('person',performer);local practice
for _,row in ipairs(offers)do if row.activity=='practice-instrument'then practice=row end end
check(practice~=nil,'actual_original_instrument_offer')
local admitted,sequence=M.begin('person',performer,practice,'purpose:musician');check(admitted,'canonical_original_performer_admitted')
sequence=sequence.sequence;local sourceAction=__queued;sourceAction:start();for n=1,100 do sourceAction:update()end
check(sourceAction.gameSound~=0 and __playing[sourceAction.gameSound],'actual_original_performer_sound')
local fact=M.currentPerformerMusic('receiver',receiver)
check(fact and fact.performerId=='person'and fact.performerWorkSequence==sequence and fact.sourceSoundId==sourceAction.gameSound,'exact_current_acquired_performer')
known=false;check(not M.currentPerformerMusic('receiver',receiver),'unknown_performer_refused');known=true
hearing=false;check(not M.currentPerformerMusic('receiver',receiver),'native_directed_hearing_required');hearing=true
local playing=performer:getModData().PlayingInstrument;performer:getModData().PlayingInstrument=false
check(not M.currentPerformerMusic('receiver',receiver),'source_flag_required');performer:getModData().PlayingInstrument=playing
__playing[sourceAction.gameSound]=false;check(not M.currentPerformerMusic('receiver',receiver),'actual_current_performer_sound_required');__playing[sourceAction.gameSound]=true
local listener
for _,row in ipairs(L.offers('receiver',receiver))do if row.activity=='listen-lifestyle-music'then listener=row end end
check(listener and listener.heardMusic.performerId=='person','receiver_original_source_offer')
local ok,listenSequence=L.begin('receiver',receiver,listener,'purpose:listener');check(ok,'canonical_receiver_admitted')
local before=LSUtil.getCharacterMood(receiver,'Stress');__engineHours=__engineHours+1/60;__event('EveryOneMinute')
check(not L.outcome('receiver',listenSequence),'receiver_pending_not_completion')
__engineHours=__engineHours+1/6;__event('EveryTenMinutes');local outcome=L.outcome('receiver',listenSequence)
check(outcome and outcome.status=='completed'and LSUtil.getCharacterMood(receiver,'Stress')<before,'original_performer_receiver_effect')
check(outcome.sourceOffer.heardMusic.performerWorkId==M.work('person').workId,'receipt_exact_source_correlation')
local after=LSUtil.getCharacterMood(receiver,'Stress');__event('EveryTenMinutes')
check(LSUtil.getCharacterMood(receiver,'Stress')==after,'duplicate_callback_no_effect')
check(__volume==.61,'operator_volume_unchanged')
local stale=listener;__admit=false
check(not L.begin('receiver',receiver,stale,'purpose:listener'),'retired_source_admission_refused')
__freshLifestyle('dj');performer=__body;performer.getUsername=function()return 'Acquired DJ'end;__level=3;known=true;hearing=true
__records.receiver={id='receiver'};bodies.person=performer;bodies.receiver=receiver;SAO.Body.get=function(id)return bodies[id]end
SAO.Perception.leisureObjects=function(id)return id=='person'and __objects or{}end
SAO.Perception.resolveLeisureObject=function(id,b,key)return id=='person'and b==performer and __objectHandles[key]or nil end
local djOffer
for _,row in ipairs(L.offers('person',performer))do if row.activity=='perform-dj'and row.track.mode=='slow'then djOffer=row end end
check(djOffer~=nil,'original_DJ_personal_station_offer')
ok,sequence=L.begin('person',performer,djOffer,'purpose:DJ');check(ok,'current_DJ_admitted')
sourceAction=__queued;sourceAction:start();for n=1,100 do sourceAction:update()end
fact=L.currentHeardMusic('receiver',receiver)
check(fact and fact.sourceContext=='lifestyle-dj'and fact.sourceSoundId==sourceAction.gameSound,'actual_current_DJ_hearing')
hearing=false;check(not L.currentHeardMusic('receiver',receiver),'DJ_directed_hearing_required');hearing=true
known=false;check(not L.currentHeardMusic('receiver',receiver),'DJ_unknown_source_refused');known=true
for _,row in ipairs(L.offers('receiver',receiver))do if row.activity=='listen-lifestyle-music'then listener=row end end
ok,listenSequence=L.begin('receiver',receiver,listener,'purpose:DJ-listener');check(ok,'independent_DJ_listener_purpose')
before=LSUtil.getCharacterMood(receiver,'Stress');__engineHours=__engineHours+1/60;__event('EveryOneMinute')
__engineHours=__engineHours+1/6;__event('EveryTenMinutes');outcome=L.outcome('receiver',listenSequence)
check(outcome and outcome.status=='completed'and LSUtil.getCharacterMood(receiver,'Stress')<before,'original_DJ_receiver_effect')
check(outcome.sourceOffer.heardMusic.performerWorkId==L.work('person').workId,'DJ_receiver_exact_source_correlation')
local ownSourceHandle=sourceAction.gameSound;__playing[ownSourceHandle]=false
check(not L.currentHeardMusic('receiver',receiver),'DJ_actual_sound_required')
print('PASS Lifestyle hearing '..checks)
