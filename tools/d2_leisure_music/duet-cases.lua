local M,O=SAO.LeisureMusic,SAO.Organization
local transport
local function delivered(kind,pid,from,to,fn)
 transport={kind=kind,processId=pid,fromId=from,toId=to};local result=fn();transport=nil;return result
end
local count=0
local function check(name,value)count=count+1;assert(value,'D2_DUET:'..name);print('CASE '..name)end
local function fixture(piano)
    M.reset('duet-fixture-reset');O.processes={};O.processOrder={};O.processMeta={sequence=0};O.workReceipts={}
    __fresh('GuitarAcoustic');__level=4;__seconds=1;__seenPeer=true;transport=nil
    SAO.Communication={participationTransport=function(pid,from,to,kind)
        return transport and transport.kind==kind and transport.processId==pid and transport.fromId==from and transport.toId==to or false
    end}
    __body.hasModData=function()return true end;__body.CanSee=function()return __seenPeer end
    local sq={getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end}
    __body.getSquare=function()return sq end
    __body:getModData().GuitarALearnedTracks={}
    local known=__body:getModData().GuitarALearnedTracks
    for _,t in ipairs(require('TimedActions/PlayGuitarAcousticTracks'))do known[#known+1]=t;if #known==9 then break end end
    local peer={};for k,v in pairs(__body)do peer[k]=v end
    local md={SAOPersonId='peer',SAOExternalToken='peer-generation:1',
        LSMoodles={PartyBad={Value=0},PartyGood={Value=0},Embarrassed={Value=0}}}
    local front={getX=function()return 12 end,getY=function()return 10 end,getZ=function()return 0 end}
    local micSquare={getX=function()return 12 end,getY=function()return 9 end,getZ=function()return 0 end,
        getAdjacentSquare=function(_,dir)return dir=='S' and front or nil end}
    local mic={__isoObject=true,getSquare=function()return micSquare end,getSpriteName=function()return 'source-microphone-sprite'end,
        getSprite=function()return {getProperties=function()return {has=function(_,k)return k=='Facing'end,get=function()return 'S'end}end}end}
    peer.getModData=function()return md end;peer.getStats=function()return __stats2 end
    peer.getDescriptor=function()return {isFemale=function()return true end}end
    peer.getX=function()return 12 end;peer.getY=function()return 10 end;peer.getSquare=function()return front end
    peer.getPrimaryHandItem=function()return nil end;peer.setPrimaryHandItem=function()end
    peer.getEmitter=function()return {isPlaying=function(_,id)return __peerPlaying[id]==true end,
        playSound=function(_,name)__peerNext=__peerNext+1;__peerPlaying[__peerNext]=true;__peerPlayed[#__peerPlayed+1]=name;return __peerNext end,
        stopSound=function(_,id)__peerPlaying[id]=false end}end
    __peer=peer;__peerNext=0;__peerPlaying={};__peerPlayed={}
    __stats2:set(CharacterStat.ENDURANCE,.8);__stats2:set(CharacterStat.FATIGUE,.2);__stats2:set(CharacterStat.STRESS,.2)
    __bodies={person=__body,peer=peer};__records.peer={id='peer'}
    SAO.Body={get=function(id)return __bodies[id]end}
    SAO.Needs.ownsRecoveryBody=function(id,body)return __bodies[id]==body and __owned end
    __queues={};SAO.Needs.workAvailable=function(body)return __queues[body]==nil end
    SAOJavaBridge.privateCarriedItems=function(_,body)
        local list=body==__body and __items or {};return {size=function()return #list end,get=function(_,n)return list[n+1]end}
    end
    SAO.Perception.leisureObjects=function(id)return id=='peer' and {{key='mic:peer',actorId='peer',x=12,y=9,z=0,
        spriteName='source-microphone-sprite',customName='Microphone',groupName='Standing',runtimeInstance='mic:peer:1'}} or {}end
    SAO.Perception.resolveLeisureObject=function(id,body,key)return id=='peer' and body==peer and key=='mic:peer' and mic or nil end
    ISTimedActionQueue.add=function(action)
        __queues[action.character]=action
        action.action={setUseProgressBar=function()end,setActionAnim=function(_,anim)__animation=anim end,
            setOverrideHandModelsObject=function()end,setOverrideHandModelsString=function()end,getJobDelta=function()return __delta end,
            setTime=function()end,setCurrentTime=function()end,resetJobDelta=function()end,
            forceComplete=function()action:perform()end,forceStop=function()
                if __queues[action.character]==action then action:stop();__queues[action.character]=nil end
            end}
    end
    ISTimedActionQueue.hasAction=function(action)return __queues[action.character]==action end
    ISTimedActionQueue.getTimedActionQueue=function(body)return {resetQueue=function()__queues[body]=nil end,
        onCompleted=function()__queues[body]=nil end}end
    SAO.ProceduralPlanning.admitHobbyWork=function(id,pid,seq,owner)
        local w=M.work(id);return __admit and owner=='SAO.LeisureMusic' and pid=='purpose:duet' and w and w.sequence==seq
    end
    SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)
        local w=M.work(id);if __admit and w and w.purposeId==pid and w.workId==wid then return {ownerName='SAO.LeisureMusic',sequence=w.sequence}end
    end
    SAO.ProceduralPlanning.consumeHobbyOutcome=function()__consumed=__consumed+1;return true end
    addSound=function(body)assert(body==__body or body==peer);__worldSounds=__worldSounds+1 end
    if piano then
        __items={};__primary=nil
        local x,y=10.5,10.5
        local mainSquare={getX=function()return 10 end,getY=function()return 9 end,getZ=function()return 0 end}
        local pairSquare={getX=function()return 11 end,getY=function()return 9 end,getZ=function()return 0 end}
        local main={__isoObject=true,getSquare=function()return mainSquare end,getSpriteName=function()return 'recreational_01_8'end}
        local pair={__isoObject=true,getSquare=function()return pairSquare end,getSpriteName=function()return 'recreational_01_9'end}
        mainSquare.getAdjacentSquare=function(_,dir)return dir=='E'and pairSquare or nil end
        pairSquare.getObjects=function()return {size=function()return 1 end,get=function()return pair end}end
        __body.getX=function()return x end;__body.getY=function()return y end
        __body.setX=function(_,v)x=v end;__body.setY=function(_,v)y=v end
        __body.isSittingOnFurniture=function()return true end;__body.isFacingObject=function(_,obj)return obj==main end
        __body:getModData().PianoLearnedTracks={}
        for _,track in ipairs(require('Instruments/Tracks/PlayPianoTracks'))do local known=__body:getModData().PianoLearnedTracks;known[#known+1]=track;if #known==9 then break end end
        local previousObjects=SAO.Perception.leisureObjects;local previousResolve=SAO.Perception.resolveLeisureObject
        SAO.Perception.leisureObjects=function(id)
            if id~='person'then return previousObjects(id)end
            return {{key='piano:person',actorId=id,x=10,y=9,z=0,spriteName='recreational_01_8'},
                {key='pair:person',actorId=id,x=11,y=9,z=0,spriteName='recreational_01_9'}}
        end
        SAO.Perception.resolveLeisureObject=function(id,body,key)
            if id~='person'then return previousResolve(id,body,key)end
            if not __pianoPairLost then return key=='piano:person'and main or key=='pair:person'and pair or nil end
        end
        __pianoPairLost=false
    end
    return peer
end
local function choice(id,song,role)
    for _,row in ipairs(M.duetChoices(id,__bodies[id]))do if row.songId==song and (not role or row.role==role)then return row end end
end
local function invitation(deliver)
    fixture();local own,peer=choice('person','Summertime'),choice('peer','Summertime')
    assert(own and peer,'audited source compatible parts absent')
    local proposal=assert(O.proposeDuet('person','peer',own.id,peer.role,__hours+.5))
    assert(delivered('proposal',proposal.processId,'person','peer',function()return O.recordReception(proposal.processId,'peer',1,'controlled-native-channel','person',{basis='focused-transport-host'})end))
    assert(O.respondDuet('peer',proposal.processId,peer.id,'accept',{relationship=.5}))
    if deliver then assert(delivered('response',proposal.processId,'peer','person',function()return O.deliverResponse(proposal.processId,'peer','person','controlled-native-channel',{basis='focused-transport-host'})end))end
    return proposal,own,peer
end
local function begin(id)
    for _,offer in ipairs(M.offers(id,__bodies[id]))do if offer.duet then
        local ok,w=M.begin(id,__bodies[id],offer,'purpose:duet');assert(ok,tostring(w));return w,__queues[__bodies[id]]
    end end
    error('accepted duet offer absent:'..id)
end
fixture();check('source_roles_personal',choice('person','Summertime').role=='guitaracoustic' and choice('peer','Summertime').role=='vocalf')
local own=choice('person','Summertime')
check('unknown_source_role_refused',not O.proposeDuet('person','peer',own.id,'listen',__hours+.5))
check('vocal_source_front_preparation',choice('peer','Summertime').targetX==12 and choice('peer','Summertime').targetY==10
 and choice('peer','Summertime').requiresPreparation.frontSquare==false)
check('generic_duet_proposal_refused',O.raiseMatter('person','leisure-duet',nil,{})==nil)
local testing=assert(O.proposeDuet('person','peer',own.id,'vocalf',__hours+.5))
check('generic_duet_reception_refused',not O.recordReception(testing.processId,'peer',1,'arbitrary','person',{}))
delivered('proposal',testing.processId,'person','peer',function()return O.recordReception(testing.processId,'peer',1,'controlled-native-channel','person',{})end)
check('generic_duet_appraisal_refused',O.appraiseMatter(testing.processId,'peer',{})==nil)
check('generic_duet_response_refused',O.respond(testing.processId,'peer','accept',{}, {})==nil)
assert(O.respondDuet('peer',testing.processId,choice('peer','Summertime').id,'accept',{}))
check('generic_duet_delivery_refused',not O.deliverResponse(testing.processId,'peer','person','arbitrary',{}))
local p,a,b=invitation(false)
check('undelivered_acceptance_refused',O.duetOffer('person',p.processId)==nil and #O.duetOffers('peer')==0)
delivered('response',p.processId,'peer','person',function()return O.deliverResponse(p.processId,'peer','person','controlled-native-channel',{})end)
local agreement=O.duetOffer('person',p.processId)
check('mutual_claimed_source_agreement',agreement and agreement.songId=='Summertime' and agreement.partnerId=='peer'
    and O.duetOffer('peer',p.processId).role=='vocalf')
agreement.choice.sound='invented';check('detached_duet_query',O.duetOffer('person',p.processId).choice.sound==a.sound)
check('foreign_actor_no_agreement',O.duetOffer('foreign',p.processId)==nil)
check('generic_work_admission_refused',not O.noteWorkAdmission(O.duetOffer('person',p.processId).commitmentId,'SAO.LeisureMusic','forged',{}))
local wp,act=begin('person');act:start();act:update()
check('missing_partner_does_not_release',__body:getModData().WaitingDuet==true and not M.work('person').nativeProgress.soundObserved)
local wq,vocal=begin('peer');vocal:start()
check('original_vocal_waiting_state',__peer:getModData().WaitingDuet==true and __volume==.61)
check('generic_terminal_result_refused',not O.consumeProcedureResult({commitmentId=O.duetOffer('person',p.processId).commitmentId,
    actorId='person',id=wp.workId,token='duet:performed',stepId='perform-originator',owner='SAO.LeisureMusic',status='completed',at=__hours}))
__seenPeer=false;act:update();check('private_visibility_blocks_release',__body:getModData().WaitingDuet and __peer:getModData().WaitingDuet)
__seenPeer=true;act:update();vocal:update()
check('authentic_source_release_both',not __body:getModData().WaitingDuet and not __peer:getModData().WaitingDuet
    and M.work('person').nativeProgress.duetReleased and M.work('peer').nativeProgress.duetReleased)
check('original_two_source_parts_audible',__played[1]==a.sound and __peerPlayed[1]==b.sound
    and M.work('person').nativeProgress.soundObserved and M.work('peer').nativeProgress.soundObserved)
__playing[act.gameSound]=false;act:update()
check('own_completion_only',M.outcome('person',wp.sequence).status=='completed' and M.work('peer')~=nil
    and M.outcome('peer',wq.sequence)==nil)
check('one_performer_has_no_shared_receipt',O.duetParticipationFor('person',p.processId)==nil
    and O.duetParticipationFor('peer',p.processId)==nil)
SAO.Cognition=SAO.Cognition or {};local priorDuetOutcome=SAO.Cognition.duetOutcome
local cognitionCalls={}
SAO.Cognition.duetOutcome=function(id,pid)
    assert(O.duetParticipationFor(id,pid),'duet receipt must precede cognition')
    cognitionCalls[id]=(cognitionCalls[id] or 0)+1
    return cognitionCalls[id]>1
end
__stats2:set(CharacterStat.STRESS,.777)
__peerPlaying[vocal.gameSound]=false;vocal:update()
check('vocal_source_ending_completes_own_part',M.outcome('peer',wq.sequence).status=='completed')
local ownReceipt=O.duetParticipationFor('person',p.processId)
local peerReceipt=O.duetParticipationFor('peer',p.processId)
local ownResult=M.outcome('person',wp.sequence);local peerResult=M.outcome('peer',wq.sequence)
check('two_private_committed_receipts',ownReceipt and peerReceipt and ownReceipt.actorId=='person'
    and peerReceipt.actorId=='peer' and ownReceipt.partnerId=='peer' and peerReceipt.partnerId=='person'
    and ownReceipt.processId==p.processId and peerReceipt.processId==p.processId
    and ownReceipt.revision==p.revision and peerReceipt.revision==p.revision
    and ownReceipt.coPerformance.status=='completed' and peerReceipt.coPerformance.status=='completed'
    and ownReceipt.coPerformance.ownResultId==wp.workId and ownReceipt.coPerformance.partnerResultId==wq.workId
    and peerReceipt.coPerformance.ownResultId==wq.workId and peerReceipt.coPerformance.partnerResultId==wp.workId)
check('own_measured_interval_only',ownReceipt.before.Stress==ownResult.before.Stress
    and ownReceipt.after.Stress==ownResult.after.Stress and peerReceipt.before.Stress==peerResult.before.Stress
    and peerReceipt.after.Stress==peerResult.after.Stress and ownReceipt.after.Stress~=peerReceipt.after.Stress
    and ownReceipt.partnerBefore==nil and ownReceipt.partnerAfter==nil and peerReceipt.partnerBefore==nil
    and ownReceipt.enjoyment==nil and ownReceipt.trust==nil
    and ownReceipt.measurementAuthority=='actual-source-interval; concurrent-effects-not-isolated')
check('both_cognition_callbacks_after_freeze',cognitionCalls.person==1 and cognitionCalls.peer==1)
ownReceipt.before.Stress=999
check('private_receipt_detached',O.duetParticipationFor('person',p.processId).before.Stress~=999
    and O.duetParticipationFor('foreign',p.processId)==nil)
check('duplicate_callback_retries_without_rewrite',O.consumeDuet('person',p.processId,wp.sequence)
    and cognitionCalls.person==2 and cognitionCalls.peer==2
    and O.duetParticipationFor('person',p.processId).id==ownReceipt.id)
SAO.Cognition.duetOutcome=priorDuetOutcome
O.processes=__roundtrip(O.processes);O.workReceipts=__roundtrip(O.workReceipts)
check('shared_receipts_survive_native_save_load',O.duetParticipationFor('person',p.processId).before.Stress==ownResult.before.Stress
    and O.duetParticipationFor('peer',p.processId).after.Stress==peerResult.after.Stress)
check('typed_result_exact_once_after_reload',O.consumeDuet('peer',p.processId,wq.sequence))
__records.person.leisureMusicOutcomes={};__records.peer.leisureMusicOutcomes={}
check('frozen_receipts_survive_source_outcome_eviction',O.duetParticipationFor('person',p.processId).coPerformance.partnerResultId==wq.workId)
check('retired_source_request_refused',M.skillRequest('peer',wq.sequence,1)==nil and O.duetReady('person',p.processId)==nil)
p,a,b=invitation(true);__hours=11
check('expired_agreement_refused',O.duetOffer('person',p.processId)==nil)
p,a,b=invitation(true);local process=O.processes[p.processId]
local old=O.viewFor('person',p.processId,false).proposal.proposal
O.reviseMatter(p.processId,'person',old,{})
check('revised_agreement_refused',O.duetOffer('person',p.processId)==nil)
fixture();a=choice('person','Summertime');p=O.proposeDuet('person','peer',a.id,'vocalf',__hours+.5)
delivered('proposal',p.processId,'person','peer',function()return O.recordReception(p.processId,'peer',1,'controlled-native-channel','person',{})end)
check('foreign_song_acceptance_refused',O.respondDuet('peer',p.processId,choice('peer','Greensleeves').id,'accept',{})==nil)
p,a,b=invitation(true);wp,act=begin('person');act:start();wq,vocal=begin('peer');vocal:start()
M.interrupt('peer',__peer,'voluntary-withdrawal');act:update()
check('retired_partner_interrupts_other',M.outcome('person',wp.sequence).status=='interrupted')
check('interruption_never_forms_duet_receipt',O.duetParticipationFor('person',p.processId)==nil
    and O.duetParticipationFor('peer',p.processId)==nil)
p,a,b=invitation(true);wp,act=begin('person');act:start();wq,vocal=begin('peer');vocal:start()
__admit=false;act:update()
check('lost_typed_purpose_never_releases',M.outcome('person',wp.sequence).status=='interrupted' and __peer:getModData().WaitingDuet)
fixture(true);local pianoPart=choice('person','Summertime','piano');local vocalPart=choice('peer','Summertime','vocalf')
check('personally_paired_piano_duet_choice',pianoPart and pianoPart.pairObjectKey=='pair:person' and pianoPart.sound=='PianoDuet04Summertime')
__pianoPairLost=true;check('piano_duet_lost_pair_refused',choice('person','Summertime','piano')==nil);__pianoPairLost=false
local pianoProposal=assert(O.proposeDuet('person','peer',pianoPart.id,vocalPart.role,__hours+.5))
delivered('proposal',pianoProposal.processId,'person','peer',function()return O.recordReception(pianoProposal.processId,'peer',1,'controlled-native-channel','person',{})end)
assert(O.respondDuet('peer',pianoProposal.processId,vocalPart.id,'accept',{}))
delivered('response',pianoProposal.processId,'peer','person',function()return O.deliverResponse(pianoProposal.processId,'peer','person','controlled-native-channel',{})end)
wp,act=begin('person');act:start();act:update()
check('piano_original_duet_waits',act.isDuet==true and __body:getModData().WaitingDuet==true and not M.work('person').nativeProgress.soundObserved)
wq,vocal=begin('peer');vocal:start();act:update();vocal:update()
check('piano_original_duet_two_source_sounds',M.work('person').nativeProgress.duetReleased and M.work('person').nativeProgress.sound=='PianoDuet04Summertime'
 and M.work('peer').nativeProgress.sound=='VocalDuet04Summertime')
__playing[act.gameSound]=false;act:update();__peerPlaying[vocal.gameSound]=false;vocal:update()
check('piano_original_duet_own_endings',M.outcome('person',wp.sequence).status=='completed' and M.outcome('peer',wq.sequence).status=='completed')
check('piano_completed_private_receipts',O.duetParticipationFor('person',pianoProposal.processId)
    and O.duetParticipationFor('peer',pianoProposal.processId))
-- A real pair can finish while a retained result is corrupted. The receipt
-- remains absent until both exact source-result bindings can be revalidated.
p,a,b=invitation(true);wp,act=begin('person');act:start();wq,vocal=begin('peer');vocal:start()
act:update();vocal:update();__playing[act.gameSound]=false;act:update()
local raw=__records.person.leisureMusicOutcomes[#__records.person.leisureMusicOutcomes]
local correctPartner=raw.sourceOffer.duet.partnerId;raw.sourceOffer.duet.partnerId='foreign'
__peerPlaying[vocal.gameSound]=false;vocal:update()
check('wrong_partner_result_no_receipt',O.duetParticipationFor('person',p.processId)==nil)
raw.sourceOffer.duet.partnerId=correctPartner
local correctNativeReturn=raw.nativeProgress.sourcePerformReturned;raw.nativeProgress.sourcePerformReturned=false
check('missing_native_result_no_receipt',O.consumeDuet('person',p.processId,wp.sequence)
    and O.duetParticipationFor('person',p.processId)==nil)
raw.nativeProgress.sourcePerformReturned=correctNativeReturn
local correctRevision=raw.sourceOffer.duet.revision;raw.sourceOffer.duet.revision=correctRevision+1
check('wrong_revision_result_no_receipt',not O.consumeDuet('person',p.processId,wp.sequence)
    and O.duetParticipationFor('person',p.processId)==nil)
raw.sourceOffer.duet.revision=correctRevision
check('validated_duplicate_forms_exact_pair',O.consumeDuet('peer',p.processId,wq.sequence)
    and O.duetParticipationFor('person',p.processId).coPerformance.partnerResultId==wq.workId)
M.reset('duet-proof-terminal')
print('PASS D2 source duet '..count)
