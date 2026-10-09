-- Installed body, Stats and carried materials; source-owned recall input and
-- physical admission receivers are controlled. No rendered participation claim.
local Ctl=SAO.Controller
local count=0
local function check(name,condition)
    assert(condition,'D2_PERSONAL:'..name);count=count+1;print('CASE '..name)
end
SAO.Disposition.traits=function()return {initiative=.5,discipline=.5,compassion=.5}end
SAO.Disposition.eatAt=function()return .3 end
SAO.Disposition.drinkAt=function()return .3 end
SAO.Perception.believedThreatCount=function()return 0 end
SAO.Standing.insideClaim=function()return false end
SAO.Study.offer=function()return nil end
SAO.Study.active=function()return false end
Ctl.reconcileLeisureCommitment=function()end
local noPressure={hunger=0,thirst=0,fatigue=.1,endurance=1}
local recall={}
SAO.PersonalMemory={query=function(id,family)
    return {actorId=id,status='available',episodes=recall[family] or {}}
end}
local function episode(family,value,actor)
    return {actorId=actor or 'person',ownerId=actor or 'person',accessible=true,
        accessibility=1,valence=value,episodeId=family..'-episode',sourceId='controlled:dated-history',
        sourceSha256=string.rep('a',64),provenance='authored-synthetic'}
end
local function fresh()
    __hours=10;__records={person={id='person'},foreign={id='foreign'}};__stores={};__dispatch={};recall={}
    __body:getInventory():clear();__other:getInventory():clear()
    __body:getInventory():AddItem(__harmonica);__body:getInventory():AddItem(__book)
    local data=__body:getModData();data.SAOPersonId='person';data.SAOExternalOwner=nil
    data.SAOExternalToken=nil;data.ZAOOwned=nil
    __body:setAsleep(false);__body:setCanShout(true);__body:getCharacterActions():clear()
    __body:getStats():set(CharacterStat.BOREDOM,0)
    __body:getStats():set(CharacterStat.UNHAPPINESS,0)
    __body:getStats():set(CharacterStat.STRESS,0)
    SAO.Body.active.person=__body;SAO.Body.foreign.person=nil
    assert(SAO.Cognition.configure(0,12,3))
    local rec=__records.person;local agent={rec=rec,state='IDLE'};Ctl.agents.person=agent
    SAO.Study.beginLeisure=function(id,body,item)
        __dispatch[#__dispatch+1]={kind='reading',item=item}
        return SAO.Study.readingEligibility(id,body,item,'leisure')
    end
    return rec,agent
end
do
    __hours=10;__records={person={id='person'}};__stores={}
    SAO.Identity.all=function()return __records end
    SAO.Cognition.onGameStart()
    local settings=SAO.Cognition.settings()
    check('normal_start_initializes_existing_cognitive_budget',settings.enabled==true
        and settings.opponentShare==.5 and settings.opportunitiesPerHour==12 and settings.maxDepth==3)
    local offer={id='startup-duet-choice',kind='leisure',utility=.2,evidence=1,
        continuity=0,novelty=0,informationGain=0,blockers=0,maxAdjustment=.25,
        consequences={{kind='hobby',category='leisure',sourceId='LifestyleHobbies',
            condition='duet:partner',value=.4}}}
    local frame={domain='ordinary-purpose',atHours=10,pressure=.1}
    local cold=SAO.Cognition.scorePlan('person',offer,frame)
    local oldOrganization=SAO.Organization
    SAO.Organization={duetParticipationFor=function(id,pid)
        if id=='person' and pid=='normal-world-duet' then return {
            actorId=id,processId=pid,partnerId='partner',revision=1,
            sourceId='LifestyleHobbies',sequence=1,atHours=10,workId='own-work',
            measurementAuthority='actual-source-interval; concurrent-effects-not-isolated',
            before={},after={},coPerformance={status='completed',
                basis='two-committed-native-source-duet-results',ownResultId='own-work',
                partnerResultId='peer-work'}} end
    end}
    local learned=SAO.Cognition.duetOutcome('person','normal-world-duet')
    local warm=SAO.Cognition.scorePlan('person',offer,frame)
    check('normal_start_source_duet_reaches_private_future_choice',learned and cold and warm and warm>cold)
    SAO.Organization=oldOrganization
    local store=__stores.SurvivorAwareness_Cognition
    local saved={enabled=false,opponentShare=.75,opportunitiesPerHour=7,maxDepth=2}
    store.settings=saved;SAO.Cognition.onGameStart()
    check('saved_disabled_setting_survives_normal_reload',store.settings==saved
        and SAO.Cognition.settings().enabled==false)
    store.settings='malformed-saved-setting';SAO.Cognition.onGameStart()
    check('malformed_saved_setting_is_not_silently_replaced',store.settings=='malformed-saved-setting'
        and SAO.Cognition.settings().enabled==false)
end
do
    local rec,agent=fresh()
    local reasons=Ctl.leisureReasons('person',__body,'reading')
    check('native_mood_is_read_without_mutation',reasons.moodStatus=='native' and reasons.boredom==0
        and __body:getStats():get(CharacterStat.BOREDOM)==0)
    local offers=Ctl.leisureOffers('person',agent,__body,10000)
    local original=offers[1].utility
    __body:getStats():set(CharacterStat.BOREDOM,80)
    offers=Ctl.leisureOffers('person',agent,__body,10000)
    local kind,selected=Ctl.chooseOrdinaryPurpose('person',agent,__body,10000,noPressure)
    check('native_boredom_changes_ordinary_comparison',offers[1].utility>original and kind=='leisure'
        and selected.candidate.reasons.boredom==.8)
    check('comparison_admits_no_alternative',#__dispatch==0 and not rec.studyWork and not rec.instrumentSequence)
end
do
    local rec,agent=fresh();recall.music={episode('music',-1)};recall.reading={episode('reading',1)}
    local kind,selected=Ctl.chooseOrdinaryPurpose('person',agent,__body,10000,noPressure)
    local admitted=Ctl.dispatchOrdinaryPurpose('person',agent,__body,10000,noPressure,kind,selected)
    check('dated_valence_changes_actual_selected_receiver',kind=='leisure' and selected.payload.kind=='reading'
        and admitted and #__dispatch==1 and __dispatch[1].kind=='reading')
    check('source_provenance_retained_in_private_reasons',selected.candidate.reasons.episodeIds[1].sourceSha256==string.rep('a',64)
        and selected.candidate.reasons.episodeIds[1].provenance=='authored-synthetic')
    check('mood_pressure_does_not_manufacture_relief',__body:getStats():get(CharacterStat.UNHAPPINESS)==0
        and not rec.leisureReadingOutcomes)
end
do
    local rec,agent=fresh();recall.reading={episode('reading',1,'foreign')}
    local reasons=Ctl.leisureReasons('person',__body,'reading')
    check('foreign_episode_cannot_supply_interest',reasons.interest==0 and #reasons.episodeIds==0)
    recall.reading={episode('reading',1)};recall.reading[1].accessible=false
    check('inaccessible_episode_cannot_supply_interest',Ctl.leisureReasons('person',__body,'reading').interest==0)
    recall.reading={episode('reading',1)};recall.reading[1].sourceSha256=nil
    check('unbound_episode_cannot_supply_interest',Ctl.leisureReasons('person',__body,'reading').interest==0)
end
do
    local rec,agent=fresh();agent.nextPageAt=20000;recall.reading={episode('reading',1)}
    local offers=Ctl.leisureOffers('person',agent,__body,10000)
    check('cooldown_removes_reading_before_comparison',#offers==1 and offers[1].family=='music')
    agent.nextTuneAt=20000
    check('cooldown_removes_all_unavailable_activities',#Ctl.leisureOffers('person',agent,__body,10000)==0)
end
do
    local rec,agent=fresh();recall.reading={episode('reading',1)}
    local needs={hunger=.6,thirst=0,fatigue=.1,endurance=1}
    local kind=Ctl.chooseOrdinaryPurpose('person',agent,__body,10000,needs)
    check('actual_hunger_outweighs_available_leisure',kind=='food')
    local before=Ctl.leisureOffers('person',agent,__other,10000)
    check('foreign_body_cannot_offer_private_leisure',#before==0)
end
do
    local rec,agent=fresh();recall.music={episode('music',1)}
    local saved={}
    local bindings={{'Leisure','meditation'},{'LeisureExercise','exercise'},{'LeisureArt','art'},
        {'LeisureMusic','music'},{'LeisureGames','games'},{'LeisureRadio','music'}}
    for _,binding in ipairs(bindings) do
        local name,family=binding[1],binding[2];saved[name]=SAO[name]
        SAO[name]={intentOffers=function()
            local rows={}
            for index=1,24 do rows[index]={id=name..':'..index,family=family,activity='source-activity',
                sourceId='LifestyleHobbies',itemKey=family..':'..index,itemType='Base.Harmonica'} end
            return rows
        end}
    end
    local acquired=Ctl.leisureOffers('person',agent,__body,10000)
    check('all_providers_reach_personal_comparison_pool',#acquired==146)
    local kind,selected=Ctl.chooseOrdinaryPurpose('person',agent,__body,10000,noPressure)
    check('overfull_pool_still_selects_through_actual_models',kind=='leisure' and selected
        and rec.ordinaryPurposeDecision.interpretations and selected.candidate.family=='music')
    local decision=rec.ordinaryPurposeDecision;local families={}
    for _,candidate in ipairs(decision.alternatives)do if candidate.kind=='leisure'then families[candidate.family]=true end end
    local all=true for _,binding in ipairs(bindings)do if not families[binding[2]]then all=false end end
    check('bounded_comparison_retains_each_available_family',all and #decision.alternatives==16)
    check('omitted_alternatives_have_explicit_custody',decision.comparison.offered==147
        and decision.comparison.compared==16 and #decision.comparison.omitted==131)
    SAO.LeisureArt.intentOffers=function()
        local rows={}for index=1,200 do rows[index]={id='dense-art:'..index,family='art',activity='source-activity',
            sourceId='LifestyleHobbies',itemKey='art:'..index,itemType='Base.Harmonica'}end;return rows
    end
    local rank=SAO.Cognition.scorePlan;local radioRanked={}
    SAO.Cognition.scorePlan=function(id,candidate,context)
        if candidate.id:find('LeisureRadio:',1,true)==1 then radioRanked[candidate.id]=true end
        return rank(id,candidate,context)
    end
    kind,selected=Ctl.chooseOrdinaryPurpose('person',agent,__body,10001,noPressure)
    local ranked=0 for _ in pairs(radioRanked)do ranked=ranked+1 end
    check('dense_early_owner_cannot_hide_radio_from_private_model',kind=='leisure'and selected and ranked==24)
    check('dense_pool_omissions_preserve_all_acquired_ids',rec.ordinaryPurposeDecision.comparison.offered==323
        and rec.ordinaryPurposeDecision.comparison.compared==16 and #rec.ordinaryPurposeDecision.comparison.omitted==307)
    SAO.Cognition.scorePlan=rank
    for _,binding in ipairs(bindings)do SAO[binding[1]]=saved[binding[1]]end
end
do
    local rec,agent=fresh();recall.music={episode('music',1)}
    local oldMusic,oldOrganization,oldCoordination,oldCommunication=
        SAO.LeisureMusic,SAO.Organization,SAO.Coordination,SAO.Communication
    local partner='duet-partner';local other='other-contact'
    local ownWork='duet-work:person:1';local partnerWork='duet-work:partner:1'
    local sourceReceipt={actorId='person',processId='duet-process:1',partnerId=partner,
        revision=1,sourceId='LifestyleHobbies',sequence=1,atHours=10,
        measurementAuthority='actual-source-interval; concurrent-effects-not-isolated',
        before={},after={},workId=ownWork,
        coPerformance={status='completed',basis='two-committed-native-source-duet-results',
            ownResultId=ownWork,partnerResultId=partnerWork}}
    SAO.Organization={openMatter=function()return nil end,
        duetParticipationFor=function(id,processId)
            if id=='person' and processId=='duet-process:1' then return sourceReceipt end
        end}
    SAO.Coordination={knownContacts=function()return {
        {id=partner,hostile=false,relationship=0},
        {id=other,hostile=false,relationship=0}} end}
    SAO.Communication={canConverse=function()return true end}
    SAO.LeisureMusic={intentOffers=function()return {} end,
        duetChoices=function()return {{id='native-duet-choice',sourceId='LifestyleHobbies',
            itemKey='owned-instrument',itemType='Base.Harmonica',partnerRoles={'instrument'}}} end}
    local function pairOffers()
        local offered=Ctl.leisureOffers('person',agent,__body,10000)
        local byPartner={}
        for _,row in ipairs(offered) do
            if row.activity=='invite-source-duet' then byPartner[row.reasons.recipientId]=row end
        end
        return byPartner[partner],byPartner[other]
    end
    local first,unrelated=pairOffers()
    local frame={domain='ordinary-purpose',atHours=10,pressure=.1,
        needs={hunger=0,thirst=0,fatigue=.1,endurance=1}}
    local coldFirst=first and SAO.Cognition.scorePlan('person',first,frame)
    local coldOther=unrelated and SAO.Cognition.scorePlan('person',unrelated,frame)
    local foreignCold=first and SAO.Cognition.scorePlan('foreign',first,frame)
    check('two_conversable_contacts_have_separate_real_invitation_candidates',first and unrelated
        and first.consequences[1].condition=='duet:'..partner
        and unrelated.consequences[1].condition=='duet:'..other)
    check('cold_partner_candidates_have_neutral_equal_expectation',coldFirst and coldOther
        and math.abs(coldFirst-coldOther)<.00001)
    local learned,reason=SAO.Cognition.duetOutcome('person','duet-process:1')
    local warmFirst=SAO.Cognition.scorePlan('person',first,frame)
    local warmOther=SAO.Cognition.scorePlan('person',unrelated,frame)
    local foreignWarm=SAO.Cognition.scorePlan('foreign',first,frame)
    check('completed_source_duet_informs_exact_partner_choice',learned and warmFirst and warmOther
        and warmFirst>coldFirst and math.abs(warmOther-coldOther)<.00001)
    check('completed_duet_cannot_teach_another_person',foreignCold and foreignWarm
        and math.abs(foreignWarm-foreignCold)<.00001)
    local revisions=rec.cognition and rec.cognition.models.ordinary.revision
    local replay=SAO.Cognition.duetOutcome('person','duet-process:1')
    check('duplicate_source_duet_does_not_relearn',replay and rec.cognition.models.ordinary.revision==revisions)
    SAO.LeisureMusic,SAO.Organization,SAO.Coordination,SAO.Communication=
        oldMusic,oldOrganization,oldCoordination,oldCommunication
end
do
    local rec,agent=fresh();recall.music={episode('music',1)}
    local oldMusic,oldOrganization,oldCoordination,oldCommunication=
        SAO.LeisureMusic,SAO.Organization,SAO.Coordination,SAO.Communication
    local partner='dance-partner';local other='other-contact'
    local ownWork='dance-work:person:1';local peerWork='dance-work:partner:1'
    local sourceReceipt={actorId='person',processId='dance-process:1',partnerId=partner,
        revision=1,sourceId='LifestyleHobbies',musicKey='current-native-music',role='source',
        sequence=1,atHours=10,workId=ownWork,
        measurementAuthority='actual-source-interval; concurrent-effects-not-isolated',
        before={},after={},coPerformance={status='completed',
            basis='two-committed-native-source-dance-results',
            ownResultId=ownWork,partnerResultId=peerWork}}
    SAO.Organization={openMatter=function()return nil end,
        danceParticipationFor=function(id,processId)
            if id=='person' and processId=='dance-process:1' then return sourceReceipt end
        end}
    SAO.Coordination={knownContacts=function()return {
        {id=partner,hostile=false,relationship=0},
        {id=other,hostile=false,relationship=0}} end}
    SAO.Communication={canConverse=function()return true end}
    SAO.LeisureMusic={intentOffers=function()return {} end,
        danceChoices=function()return {{id='native-dance-choice',sourceId='LifestyleHobbies',
            itemKey='current-music',itemType='native-dance',role='source'}} end}
    local offered=Ctl.leisureOffers('person',agent,__body,10000)
    local byPartner={}
    for _,row in ipairs(offered) do
        if row.activity=='invite-source-dance' then byPartner[row.reasons.recipientId]=row end
    end
    local first,unrelated=byPartner[partner],byPartner[other]
    local frame={domain='ordinary-purpose',atHours=10,pressure=.1,
        needs={hunger=0,thirst=0,fatigue=.1,endurance=1}}
    local coldFirst=first and SAO.Cognition.scorePlan('person',first,frame)
    local coldOther=unrelated and SAO.Cognition.scorePlan('person',unrelated,frame)
    local foreignCold=first and SAO.Cognition.scorePlan('foreign',first,frame)
    check('two_contacts_have_separate_native_dance_invitations',first and unrelated
        and first.consequences[1].condition=='dance:'..partner
        and unrelated.consequences[1].condition=='dance:'..other)
    check('cold_dance_contacts_have_neutral_equal_expectation',coldFirst and coldOther
        and math.abs(coldFirst-coldOther)<.00001)
    sourceReceipt.coPerformance.status='interrupted'
    check('incomplete_pair_cannot_enter_dance_memory',not SAO.Cognition.danceOutcome('person','dance-process:1'))
    sourceReceipt.coPerformance.status='completed'
    local learned=SAO.Cognition.danceOutcome('person','dance-process:1')
    local warmFirst=SAO.Cognition.scorePlan('person',first,frame)
    local warmOther=SAO.Cognition.scorePlan('person',unrelated,frame)
    local foreignWarm=SAO.Cognition.scorePlan('foreign',first,frame)
    check('completed_source_dance_informs_exact_partner_choice',learned and warmFirst
        and warmFirst>coldFirst and math.abs(warmOther-coldOther)<.00001)
    check('source_dance_cannot_teach_another_person',foreignCold and foreignWarm
        and math.abs(foreignWarm-foreignCold)<.00001)
    local revisions=rec.cognition and rec.cognition.models.ordinary.revision
    check('duplicate_source_dance_does_not_relearn',SAO.Cognition.danceOutcome('person','dance-process:1')
        and rec.cognition.models.ordinary.revision==revisions)
    SAO.LeisureMusic,SAO.Organization,SAO.Coordination,SAO.Communication=
        oldMusic,oldOrganization,oldCoordination,oldCommunication
end
print('PASS D2 personal '..count)
