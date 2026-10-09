-- Canonical source presentation/input receivers are controlled here; the native
-- body and actual Planner/Cognition/Models/Disposition execute unchanged.
local C,P,D=SAO.Cognition,SAO.ProceduralPlanning,SAO.Disposition
local nativeInterpret=C.interpretPlans
local count=0
local function check(name,v)assert(v,'D2_GAME_INPUT:'..name);count=count+1;print('CASE '..name)end
local function clone(v)if type(v)~='table'then return v end;local t={}for k,x in pairs(v)do t[k]=clone(x)end;return t end
local function fresh()
    __hours=10;__records={person={id='person'},foreign={id='foreign'}};__stores={}
    __body:getModData().SAOPersonId='person';__body:getModData().SAOExternalOwner=nil
    __body:getModData().SAOExternalToken=nil;__body:getModData().ZAOOwned=nil
    __body:setAsleep(false);__body:getCharacterActions():clear()
    SAO.Body.active.person=__body;SAO.Body.foreign.person=nil
    SAO.Conditions={bend=function()return 0 end};assert(C.configure(0,12,3))
    local r=__records.person;r.gameContextReads=0;r.gameAppraisals=0;C.interpretPlans=function(id,candidates,context)r.gameAppraisals=r.gameAppraisals+1;return nativeInterpret(id,candidates,context)end;SAO.Controller.agents.person={rec=r,state='IDLE'}
    local purpose=P.planLeisure('person',{activity='play-computer',activityKey='computer:private',owner='SAO.LeisureGames',
        affordance='ComputerModkum:PZPongGame',atLocation=true,locationKey='10:20:0'})
    local w={actorId='person',sequence=1,workId='games/person/1',purposeId=purpose.id,family='games',
        activity='play-computer',sourceId='ComputerModkum:PZPongGame',revision=string.rep('a',64),
        bodyGenerationKnown=false,admittedAtHours=10,status='active',nativeOwner='controlled:game-owner',nativeProgress={}}
    r.leisureGamesWork=w
    local scene={actorId='person',workSequence=1,workId=w.workId,sourceId=w.sourceId,revision=w.revision,
        frameId=1,atHours=10,status='presented-source-scene',viewport={width=450,height=253},
        commands={{kind='text',args={'PLAYER'}}},labels={action='SPACE',up='UP',down='DOWN'}}
    local inputs,accepted={},{ }
    local function offers()
        local result={}
        for _,keys in ipairs({{}, {'action'}, {'up'}, {'down'}})do
            result[#result+1]={id='game-input:'..table.concat(keys,'+')..':'..scene.frameId,keys=clone(keys),
                actorId='person',workSequence=1,workId=w.workId,frameId=scene.frameId,sourceId=w.sourceId,revision=w.revision}
        end return result
    end
    SAO.LeisureGames={work=function(id)return id=='person'and clone(r.leisureGamesWork)end,
        context=function(id,body)r.gameContextReads=r.gameContextReads+1;return id=='person'and clone(scene)end,
        inputOffers=offers,
        submitInput=function(id,body,input)
            if id~='person'or body~=__body then return false end
            accepted[#accepted+1]=clone(input);return true
        end}
    assert(P.admitHobbyWork('person',purpose.id,1,'SAO.LeisureGames'));r.gameAppraisals=0
    return r,purpose,w,scene,accepted
end
do
    local r,p,w,s,accepted=fresh()
    local mood=__body:getStats():get(CharacterStat.BOREDOM)
    check('actual_comparison_submits_source_control',C.chooseGameInput('person',__body)and #accepted==1 and #accepted[1].keys>0)
    check('source_frame_and_trait_provenance_retained',r.gameInputDecision.frameId==1 and r.gameInputDecision.sourceId==w.sourceId
        and r.gameInputDecision.curiosity.effective==D.curiosity('person').effective and #r.gameInputDecision.alternatives==4)
    check('duplicate_frame_does_not_repeat_source_input',not C.chooseGameInput('person',__body)and #accepted==1)
    check('input_acceptance_has_no_outcome_or_xp_credit',r.cognition==nil and p.status=='maintained'
        and r.gameInputDecision.completionCredit==false and r.gameInputDecision.skillCredit==false
        and __body:getStats():get(CharacterStat.BOREDOM)==mood)
    s.frameId=2;s.commands[1].args[1]='PLAYER 1'
    check('next_presented_frame_can_be_selected',C.chooseGameInput('person',__body)and #accepted==2)
    check('after_input_change_retains_causal_uncertainty',#r.gameInputExperience.observations==1
        and r.gameInputExperience.observations[1].previousFrameId==1
        and r.gameInputExperience.observations[1].interpretation=='presented after own input; causal effect remains uncertain')
end
do
    local r,p,w,s,accepted=fresh()
    check('foreign_body_cannot_submit',not C.chooseGameInput('person',__other)and #accepted==0 and r.gameContextReads==0)
    s.actorId='foreign'
    check('foreign_source_frame_cannot_submit',not C.chooseGameInput('person',__body)and #accepted==0 and r.gameAppraisals==0)
    s.actorId='person';s.frameId=0
    check('invalid_source_frame_cannot_submit',not C.chooseGameInput('person',__body)and #accepted==0)
    s.frameId=1;s.atHours=9
    check('old_source_presentation_cannot_submit',not C.chooseGameInput('person',__body)and #accepted==0)
    s.atHours=10;p.status='abandoned'
    check('retired_purpose_cannot_submit',not C.chooseGameInput('person',__body)and #accepted==0)
end
do
    local r,p,w,s,accepted=fresh()
    r.traitEchoes={curiosity=-1};assert(C.chooseGameInput('person',__body));local first=accepted[1].keys[1]
    s.frameId=2;assert(C.chooseGameInput('person',__body));local low=accepted[2].keys[1]
    r.traitEchoes.curiosity=1;s.frameId=3;assert(C.chooseGameInput('person',__body));local high=accepted[3].keys[1]
    check('personal_curiosity_changes_source_selected_input',low==first and high~=low)
end
do
    local r,p,w,s,accepted=fresh()
    -- Familiar keys compete with an actually displayed source instruction.
    local key=w.sourceId..':'..w.revision
    r.gameInputExperience={actorId='person',sources={},order={key},observations={},omittedSources=0,omittedObservations=0}
    r.gameInputExperience.sources[key]={counts={action=20,up=0,down=0},lastInput='up'}
    s.commands={{kind='text',args={'SPACE TO RESTART'}}}
    check('presented_instruction_changes_selected_control',C.chooseGameInput('person',__body)and accepted[1].keys[1]=='action')
    check('read_instruction_is_retained_as_source_expectation',r.gameInputDecision.presentedText[1]=='SPACE TO RESTART')
end
do
    local r,p,w,s,accepted=fresh()
    SAO.LeisureGames.submitInput=function()return false end
    check('refused_source_input_does_not_create_experience',not C.chooseGameInput('person',__body)and r.gameInputExperience==nil)
end
print('PASS D2 game input '..count)
