local total=0
local actualActiveCommitments=O.activeCommitments
local function verify(name,value)total=total+1;assert(value,'D2_SOCIAL:'..name);print('CASE '..name)end
local function fresh()
 fixture();SAO.Coordination={};SAO.Communication={}
 assert(loadstring(__sources['social:coord'],'actual Coordination'))()
 assert(loadstring(__sources['social:comm'],'actual Communication'))()
 __heard=true;__hostile=false;__known=true;__need=0;__negative=false;__competing=false;__obligation=false;__traits={talkativeness=.7,discipline=.2}
 SAO.Controller={agents={},tick=function()return 100 end}
 SAO.Needs.read=function()return {hunger=__need,thirst=0,fatigue=0}end
 SAO.Needs.carriedInstrument=function()return nil end
 SAOJavaBridge.canConverseNow=function(_,a,b,reach)__conversationQueries=(__conversationQueries or 0)+1;return __heard and a~=b and reach>0 end
 SAO.Perception.knownPeople=function(id)return __known and {{id=id=='person'and'peer'or'person',observedAtHours=__hours}}or{}end
 SAO.Perception.nearestBelievedThreat=function()return nil end
 SAO.Standing={relationsOf=function(id)return {[id=='person'and'peer'or'person']={trust=.6,hostile=__hostile}}end,
  trust=function()return .6 end,isHostileTo=function()return __hostile end,groupOf=function()return nil end,mayAttemptBelieved=function()return true end}
 SAO.Disposition={traits=function()return __traits end}
 SAO.PersonalMemory={query=function(id)return {actorId=id,status='controlled-recall-input',episodes={{actorId=id,ownerId=id,accessible=true,accessibility=1,
  valence=__negative and -.8 or .3,episodeId='dated-source-experience:'..id,sourceId='LifestyleHobbies',sourceSha256=string.rep('a',64),provenance='controlled-dated-personal-input'}}}end}
 SAO.ProceduralPlanning.participationInterests=function()return {related=true,competing=__competing}end
 SAO.ProceduralPlanning.planLeisure=function()return {id='purpose:duet'}end
 SAO.Cooking=nil
 local active=actualActiveCommitments
 O.activeCommitments=function(id)local result=active(id);if __obligation then result[#result+1]={processId='other-obligation'}end;return result end
 -- CONTROLLER_SOURCE
 __agent={rec=__records.person};SAO.Controller.agents.person=__agent
 return SAO.Coordination,SAO.Communication,SAO.Controller
end
local function invite(deliver)
 local Q,C,T=fresh();local a=choice('person','Summertime');__savedChoiceId=a.id
 local p=assert(O.proposeDuet('person','peer',a.id,'vocalf',__hours+1))
 if deliver~=false then assert(C.deliverProcessProposal('person','peer',p.processId,'spoken'))end
 return p,Q,C,T
end
local Q,C,T=fresh();local parts=M.duetChoices
 M.duetChoices=function(id,body)assert(id=='person','collector queried private partner source');return parts(id,body)end
 local rows=T.duetInvitationOffers('person',__agent,__body,100)
 verify('collector_only_own_source',#rows>0 and rows[1].uncertainty=='recipient-source-part-and-agreement-are-unobserved')
 M.duetChoices=parts
 __hostile=true;verify('hostile_invitation_refused',#T.duetInvitationOffers('person',__agent,__body,100)==0)
 __hostile=false;__known=false;verify('unknown_invitation_refused',#T.duetInvitationOffers('person',__agent,__body,100)==0)
 __known=true;__heard=false;verify('unheard_invitation_refused',#T.duetInvitationOffers('person',__agent,__body,100)==0)
 __heard=true
 verify('foreign_body_invitation_not_admitted',not T.beginLeisureOffer('person',__agent,__peer,100,{payload={kind='duet-invitation',offer=rows[1]}}))
 local stale={};for k,v in pairs(rows[1])do stale[k]=v end;stale.choiceId='missing-original-source-choice';__savedChoiceId=rows[1].choiceId
 verify('stale_choice_requery_refused',not T.beginLeisureOffer('person',__agent,__body,100,{payload={kind='duet-invitation',offer=stale}}))
 Q,C,T=fresh();rows=T.duetInvitationOffers('person',__agent,__body,100)
 verify('chosen_invitation_actual_join',T.beginLeisureOffer('person',__agent,__body,100,{key=rows[1].id,payload={kind='duet-invitation',offer=rows[1]}}))
 local pid=__records.person.duetInvitation.processId
 verify('proposal_acquired_no_assumed_consent',O.viewFor('peer',pid,false)and #O.duetOffers('person')==0 and __records.person.duetInvitation.agreement=='unobserved')
 verify('transport_capability_expired',not C.participationTransport(pid,'person','peer','proposal') and not O.recordReception(pid,'peer',1,'spoken','person',{}))
 local p;p,Q,C,T=invite(false)
 verify('undelivered_no_appraisal',Q.formResponse('peer',p.processId,__peer,'idle','social-proof')==nil)
 local forged=C.send('person','peer','process-proposal',{processId=p.processId,revision=1,kind='leisure-duet'});forged.transportAdmitted=true;forged.channel='spoken';C.deliver(forged)
 local unheard=O.viewFor('peer',p.processId,false)
 verify('generic_envelope_no_reception',not unheard or not unheard.proposal)
 p,Q,C,T=invite();local response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('actual_typed_appraisal_accepts',response and response.response=='accept' and context.interests.sourceChoiceId==choice('peer','Summertime').id)
 verify('appraisal_personal_provenance',context.interests.episodeIds[1].id=='dated-source-experience:peer' and context.inputOwners.interests:find('SAO.PersonalMemory',1,true))
 verify('formed_response_still_private',O.duetOffer('person',p.processId)==nil)
 __heard=false;verify('unheard_response_stays_private',C.deliverPendingResponses('peer','person','spoken')==0 and O.duetOffer('person',p.processId)==nil)
 __heard=true;verify('actual_return_transport_agreement',C.deliverPendingResponses('peer','person','spoken')==1 and O.duetOffer('person',p.processId)and O.duetOffer('peer',p.processId))
 verify('transport_duplicate_no_new_delivery',C.deliverPendingResponses('peer','person','spoken')==0 and not C.participationTransport(p.processId,'peer','person','response'))
 local offer;for _,row in ipairs(M.offers('person',__body))do if row.duet then offer=row;break end end
 verify('delivered_acceptance_executable_source_offer',offer and T.beginLeisureOffer('person',__agent,__body,100,{key=offer.id,payload={kind='hobby',ownerName='SAO.LeisureMusic',offer=offer}}))
 p,Q,C,T=invite();__need=.8;response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('urgent_need_defers',response and response.response=='defer' and context.interests.reason=='bodily-need-needs-attention')
 p,Q,C,T=invite();__negative=true;response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('negative_history_declines',response and response.response=='decline' and context.interests.musicAffinity<0)
 p,Q,C,T=invite();__obligation=true;response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('other_obligation_defers',response and response.response=='defer' and context.interests.acceptedObligation)
 p,Q,C,T=invite();__competing=true;response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('pending_interest_defers',response and response.response=='defer' and context.interests.competingIntention)
 p,Q,C,T=invite();__hostile=true;response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('hostile_response_declines',response and response.response=='decline' and context.contest)
 p,Q,C,T=invite();local prior=M.duetChoices
 M.duetChoices=function(id,body)local all=prior(id,body);for _,row in ipairs(all)do row.role='invalid-role'end;return all end
 response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof');M.duetChoices=prior
 verify('absent_source_declines',response and response.response=='decline' and context.interests.reason=='no-personally-supported-source-part')
 p,Q,C,T=invite();__hours=__hours+2;response,context=Q.formResponse('peer',p.processId,__peer,'idle','social-proof')
 verify('expired_terms_never_execute',not O.duetOffer('person',p.processId) and (not response or response.response~='accept'))
 local old=p.processId;local new=Q.proposeDuet('person',__body,'peer',choice('person','Summertime').id,'vocalf')
 verify('expired_own_invitation_replaced',new and new.processId~=old)
 Q,C,T=fresh();local oldIntent=M.intentOffers
 M.intentOffers=function()local many={};for n=1,135 do many[n]={id='controlled-candidate:'..n,family='music',activity='source-test',sourceId='LifestyleHobbies'}end;return many end
 local oldRadio=SAO.LeisureRadio
 SAO.LeisureRadio={intentOffers=function()return{{id='controlled-late-radio',family='radio',activity='source-test',sourceId='native:ISRadioInteractions'}}end}
 local candidates,receivers=T.leisureOffers('person',__agent,__body,100);M.intentOffers=oldIntent;SAO.LeisureRadio=oldRadio
 local bound,lateInvitation=true,false;for _,row in ipairs(candidates)do
  if not receivers[row.id]then bound=false end
  if receivers[row.id]and receivers[row.id].kind=='duet-invitation'then lateInvitation=true end
 end
 verify('collector_retains_all_acquired_and_late_families',#candidates>136 and bound and receivers['controlled-candidate:135']
  and receivers['controlled-late-radio']and lateInvitation)
 local scored={};local oldCognition=SAO.Cognition
 SAO.Cognition={scorePlan=function(id,candidate)assert(id=='person');scored[candidate.id]=true;return candidate.id=='controlled-late-radio'and 2 or 1 end}
 local selected,receipt=T.limitPurposeComparison('person',candidates,{});SAO.Cognition=oldCognition
 local allScored=true;for _,row in ipairs(candidates)do if not scored[row.id]then allScored=false end end
 local selectedIDs={};for _,row in ipairs(selected)do selectedIDs[row.id]=true end
 local completeReceipt=#receipt.omitted==#candidates-#selected
 for _,key in ipairs(receipt.omitted)do if not receivers[key]or selectedIDs[key]then completeReceipt=false end end
 verify('bounded_comparison_scores_all_and_records_omitted',allScored and #selected==16 and completeReceipt
  and receipt.offered==#candidates and receipt.compared==16 and selectedIDs['controlled-late-radio'])
 p,Q,C,T=invite(false);__owned=false
 local lost=C.deliverProcessProposal('person','peer',p.processId,'spoken')
 verify('lost_transport_owner_reports_refusal',lost==nil and not O.viewFor('peer',p.processId,false).proposal)
 M.reset('social-proof-terminal');print('PASS D2 social '..total)
