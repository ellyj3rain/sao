-- Flight continuity through actual shared appraisal, Controller and Locomotion.
-- Only actor records, native observations/admission/verdicts and clock are fixtures.
local checks={}
local function check(name,ok,detail)
    if not ok then error('FLEE_CHECK:'..name..(detail and (' '..detail) or '')) end
    checks[#checks+1]=name
end
local records,now,moves={},2,''
local nativePathogen=SAO.PathogenPressure
-- Existing cases control the external perception queries. The new contact
-- cases below restore the complete production readers over private records.
local privateNearest=SAO.Perception.nearestBelievedZombie
local privateCount=SAO.Perception.believedThreatCount
local privatePerception={}
for key,value in pairs(SAO.Perception) do privatePerception[key]=value end
for key in pairs(SAO.Perception) do
    if key~='believedZombieContacts' and key~='sortEvidence' then SAO.Perception[key]=__fixturePerception[key] end
end
SAO.Identity.get=function(id)return records[id]end
SAO.Identity.updatePosition=function()end
SAO.History.countyHours=function()return now end
SAO.Disposition.conflictValues=function(id)
    return {actorId=id,selfPreservation=.8,aggression=.2,nerve=.3,discipline=.7,compassion=.3}
end
SAO.Disposition.fear=function()return .1 end
SAO.Disposition.decisionInterval=function()return 20 end
SAO.Disposition.wouldDemand=function()return false end
SAO.Disposition.wouldYieldTo=function()return false end
SAO.Standing.mayEngageZombie=function()return true end
SAO.Standing.mayEngagePerson=function()return false end
SAOJavaBridge.isShell=function()return true end
SAOJavaBridge.localCombatMoves=function()return moves end
SAOJavaBridge.combatOpportunity=function()return 'REFUSED\tout-of-reach' end
SAOJavaBridge.getShellHealth=function()return 100 end
SAOJavaBridge.moveTo=function(self,b,x,y,z)
    __starts=__starts+1;__ordered={body=b,x=x,y=y,z=z}
    return 'MOVE_STARTED route='..__starts
end
SAOJavaBridge.setForceEntry=function()return true end
local function body(id,x,y,z)
    local b={x=x,y=y,z=z,data={SAOPersonId=id}}
    function b:getX()return self.x end
    function b:getY()return self.y end
    function b:getZ()return self.z end
    function b:getModData()return self.data end
    function b:getVehicle()return nil end
    function b:isDead()return false end
    function b:isClimbing()return self.climbing==true end
    function b:getCurrentStateName()return self.nativeState or 'IdleState' end
    function b:getCurrentSquare()
        return {getX=function()return math.floor(self.x)end,getY=function()return math.floor(self.y)end,
            getZ=function()return math.floor(self.z)end}
    end
    function b:faceLocationF(x,y)self.facing={x=x,y=y}end
    function b:Callout()__shouts=__shouts+1 end
    return b
end
local function fresh()
    records={runner={id='runner'},fellow={id='fellow'}};now=2
    __starts=0;__cancels=0;__tells=0;__tick=0;__injury=0;__shouts=0
    __player=nil;__trust={};__group=nil;__fellows={};__forbidden={};__blockAll=false
    __verdict='ManualRoute';__randCalls=0;__randFixed=nil
    __threat={x=-4.5,y=.5,dist=5,source='observed',track='runner:contact:1',at=1}
    __bodies={runner=body('runner',.5,.5,0),fellow=body('fellow',20.5,.5,0)}
    SAO.Body.active=__bodies;SAO.Body.foreign={}
    SAO.Perception.beliefs={runner={people={}},fellow={people={}}}
    SAO.Locomotion.jobs={};SAO.SourceUse=nil;SAO.PathogenPressure=nil
    SAO.Disposition.fleeDistance=function()return 50 end
    SAO.Disposition.overwhelmThreshold=function()return 99 end
    moves=''
    SAO.ProceduralPlanning.rememberSpatial('runner',{key='known-east-path',kind='ground',
        x=10,y=0,z=0,source='observed',routeKnown=true,observedAtHours=now})
    local a={state='IDLE',nextDecisionAt=0,rec=records.runner}
    SAO.Controller.agents={runner=a,fellow={state='IDLE',nextDecisionAt=999,rec=records.fellow}}
    return a,__bodies.runner
end
local function decide(a,b,roused)
    __tick=__tick+1;now=2+__tick/100000
    SAO.Controller.__fleeProbeTick(__tick)
    if roused then
        a.nextDecisionAt=__tick+999
        SAO.Controller.__fleeProbeRouse('fellow',__bodies.fellow)
        check('rousing_reopens_shared_decision',a.nextDecisionAt==0)
    end
    a.nextDecisionAt=__tick+100
    SAO.Controller.__fleeProbeDecide('runner',a,b)
end
local function escaped()
    local a,b=fresh();decide(a,b,false)
    local job=SAO.Locomotion.jobs.runner
    check('shared_escape_owned',__starts==1 and a.state=='FLEE' and job and job.goal.x==10
        and a.conflictRoute and SAO.ProceduralPlanning.conflictSnapshot('runner').admission.owner=='Locomotion',
        tostring(__starts)..' '..tostring(a.state)..' '..tostring(job and job.goal.x)..' '..tostring(a.pressure and a.pressure.detail))
    SAO.ProceduralPlanning.rememberSpatial('runner',{key='known-north-path',kind='ground',
        x=0,y=10,z=0,source='observed',routeKnown=true,observedAtHours=now})
    return a,b,job
end

local a,b,job=escaped();__fellows={'fellow'}
local token=SAO.ProceduralPlanning.conflictSnapshot('runner').admission.id
for _,x in ipairs({1.5,2.5,4.5,6.5}) do
    b.x=x;__bodies.fellow.x=30+x;__bodies.fellow.y=3+x
    __threat.at=__tick+10;__threat.dist=b.x-__threat.x
    SAO.Locomotion.tick('runner');decide(a,b,true)
    check('roused_shared_route_not_restarted',__starts==1 and __cancels==0
        and SAO.Locomotion.jobs.runner==job and a.fleeTargetX==job.goal.x
        and SAO.ProceduralPlanning.conflictSnapshot('runner').admission.id==token)
end
check('shared_rousing_reception_executed',__tells>=4)
for _,x in ipairs({8.5,10.05}) do
    b.x=x;SAO.Locomotion.tick('runner');decide(a,b,true)
    check('near_native_center_keeps_shared_route',__starts==1 and SAO.Locomotion.jobs.runner==job)
end

-- Actual cry consequences remain active while the same route is retained.
-- Reception names the hearers; player arrival and expiry retain that custody.
a,b,job=escaped();__injury=4;__player=body('player',20.5,.5,0)
decide(a,b,true)
check('retained_route_injury_records_hearers',__shouts==1 and a.criedAt==__tick
    and #a.criedHeard==2 and __starts==1 and SAO.Locomotion.jobs.runner==job)
local criedAt=a.criedAt
__player.x=.5;decide(a,b,true)
check('held_route_records_player_arrival',a.playerCame==true and __shouts==1)
__player.x=30.5;__injury=0;__tick=criedAt+1800;decide(a,b,true)
check('held_route_closes_cry_window',a.criedAt==nil and a.criedHeard==nil
    and __trust.fellow==-.1 and __trust['player:test']==nil
    and __starts==1 and SAO.Locomotion.jobs.runner==job)

for _,verdict in ipairs({'FailedObstacle:FAILED_BLOCKED_DIAGONAL',
    'FailedObstacle:FAILED_UNLOADED_NEXT_SQUARE','Succeeded','IDLE','TICK_FAILED fixture'}) do
    a,b,job=escaped();local oldKey=a.conflictRoute.routeKey
    __verdict=verdict;SAO.Controller.__followProbeMovement('runner',a,b)
    local snapshot=SAO.ProceduralPlanning.conflictSnapshot('runner')
    check('native_terminal_attempt_consumed',job.done==true and not a.conflictRoute
        and snapshot.lastOutcome and snapshot.lastOutcome.status==(verdict=='Succeeded' and 'completed' or 'failed')
        and not snapshot.admission and snapshot.status~='completed')
    __verdict='ManualRoute';decide(a,b,true)
    check('native_terminal_reopens_shared_choice',__starts==2 and SAO.Locomotion.jobs.runner~=job)
    if verdict~='Succeeded' then
        check('native_failed_exit_changes_shared_choice',a.conflictRoute.routeKey~=oldKey
            and SAO.ProceduralPlanning.conflictRouteBlocked('runner',oldKey,now))
    end
end

a,b,job=escaped();__threat={x=5,y=.5,dist=4.5,source='observed',track='runner:contact:2',at=2}
decide(a,b,true)
check('new_threat_rejects_route_through_contact',__starts==2
    and SAO.Locomotion.jobs.runner~=job and SAO.Locomotion.jobs.runner.goal.x~=10)

a,b,job=escaped();__forbidden['10,0']=true;__fellows={'fellow'}
__bodies.fellow.x=11.5;SAO.Controller.agents.fellow.fleeTargetX=700
decide(a,b,true)
check('revoked_route_retires_exact_owner',__starts==2 and __cancels==1
    and SAO.Locomotion.jobs.runner~=job and SAO.Locomotion.jobs.runner.goal.y==10)
check('private_fellow_destination_is_not_an_offer',__ordered.x~=700 and __ordered.x~=11)

a,b,job=escaped();b.z=1;moves='MOVE\t1\t0\t1'
decide(a,b,true)
check('changed_floor_reappraises_shared_route',__starts==2 and __cancels==1
    and SAO.Locomotion.jobs.runner.goal.z==1)

a,b,job=escaped();__threat=nil;decide(a,b,true)
check('absent_threat_releases_native_route',a.state=='IDLE' and __starts==1
    and __cancels==1 and SAO.Locomotion.jobs.runner==nil)
a,b,job=escaped();__blockAll=true;decide(a,b,true)
check('no_lawful_route_keeps_uncertain_watch',a.state=='ALERT' and __starts==1
    and __cancels==1 and SAO.Locomotion.jobs.runner==nil
    and SAO.ProceduralPlanning.conflictSnapshot('runner').kind=='watch')

local priorRead=SAO.Needs.read
local function reachesNeeds(agent,native)
    local reached=false
    SAO.Needs.read=function()reached=true;error('NEEDS_BOUNDARY_REACHED')end
    local ok,why=pcall(function()SAO.Controller.__fleeProbeDecide('runner',agent,native)end)
    SAO.Needs.read=priorRead
    check('decision_reaches_expected_needs_boundary',ok or reached
        and tostring(why):find('NEEDS_BOUNDARY_REACHED',1,true)~=nil)
    return reached
end
for _,state in ipairs({'HOMEWARD','WATERWARD','FOLLOW','WORKWARD'}) do
    a,b=fresh();a.state=state
    SAO.Locomotion.order('runner',b,10,0,0,true);job=SAO.Locomotion.jobs.runner
    SAO.Disposition.fleeDistance=function()return 8 end
    __threat={x=-13.5,y=.5,dist=14,source='observed',track='runner:contact:1',at=1}
    for turn=1,4 do
        check('distant_'..state..'_reaches_needs',reachesNeeds(a,b))
        check('distant_'..state..'_preserves_unrelated_route',SAO.Locomotion.jobs.runner==job
            and __starts==1 and __cancels==0 and a.state==state)
        local awareness=SAO.ProceduralPlanning.conflictSnapshot('runner')
        check('distant_'..state..'_retains_private_appraisal',awareness and awareness.kind=='watch'
            and awareness.threat.key==__threat.track and awareness.threat.source=='observed'
            and awareness.threat.distance==14 and awareness.reason and #awareness.alternatives>1
            and not awareness.admission and not awareness.lastOutcome)
    end
end
a,b=fresh();a.state='ALERT';SAO.Disposition.fleeDistance=function()return 8 end
__threat={x=-13.5,y=.5,dist=14,source='told',teller='fellow',at=1}
check('old_alert_reaches_needs_same_turn',reachesNeeds(a,b) and a.state=='IDLE')
check('distant_belief_is_not_clear',a.pressure.detail:find('believed threat',1,true)~=nil
    and not a.pressure.detail:find('clear',1,true))
local toldAwareness=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('distant_report_remains_told_in_appraisal',toldAwareness and toldAwareness.kind=='watch'
    and toldAwareness.threat.source=='told' and not toldAwareness.admission)
a.state='ALERT';SAO.SourceUse={beforeStateChange=function()return false end}
check('reconciliation_keeps_ownership',not reachesNeeds(a,b) and a.state=='ALERT')

-- A crossing owns physical continuation, not the availability of a private
-- appraisal. The decision cannot cancel it or claim a new executor admission.
for _,crossing in ipairs({'ClimbOverFenceState','ClimbThroughWindowState','pending-window'}) do
    a,b=fresh();a.state='HOMEWARD'
    SAO.Locomotion.order('runner',b,10,0,0,true);job=SAO.Locomotion.jobs.runner
    SAO.Disposition.fleeDistance=function()return 8 end
    __threat={x=-13.5,y=.5,dist=14,source='observed',track='runner:contact:1',at=1}
    if crossing=='pending-window' then job.lastVerdict='Transition:STARTED_WINDOW_CLIMB'
    else b.nativeState=crossing end
    check('crossing_keeps_native_decision_turn',not reachesNeeds(a,b))
    local awareness=SAO.ProceduralPlanning.conflictSnapshot('runner')
    check('crossing_retains_private_appraisal',awareness and awareness.kind=='watch'
        and awareness.threat.source=='observed' and not awareness.admission)
    check('crossing_preserves_ordinary_owner',SAO.Locomotion.jobs.runner==job
        and __starts==1 and __cancels==0 and not a.conflictRoute)
end

a,b,job=escaped();SAO.Disposition.fleeDistance=function()return 8 end
__threat={x=-13.5,y=.5,dist=14,source='observed',track='runner:contact:1',at=1}
check('beyond_trigger_keeps_current_shared_route',not reachesNeeds(a,b)
    and SAO.Locomotion.jobs.runner==job and __starts==1 and __cancels==0)
__forbidden['10,0']=true
check('beyond_trigger_reappraises_revoked_route',not reachesNeeds(a,b)
    and SAO.Locomotion.jobs.runner~=job and __cancels==1)

for _,kind in ipairs({'close','crowd','pathogen'}) do
    a,b=fresh();a.state='HOMEWARD'
    SAO.Disposition.fleeDistance=function()return 8 end
    __threat={x=-13.5,y=.5,dist=14,source='observed',track='runner:contact:1',at=1}
    local count=1
    if kind=='close' then __threat.dist=7;__threat.x=-6.5
    elseif kind=='crowd' then count=3;SAO.Disposition.overwhelmThreshold=function()return 2 end
    else
        SAO.PathogenPressure=nativePathogen
        __threat.form='sprinter';__threat.formPerformance=1
        __threat.attributeMutations={strength=1,speed=1,senses=1,resilience=1}
    end
    check(kind..'_still_owns_threat_turn',SAO.Controller.__threatProbeDecide('runner',a,b,1,
        __threat,count,nil,nil)==true and a.state=='FLEE')
end

-- The same actor, contact, distance, ordinary route and available actions.
-- Only personally recognized danger changes. Native route admission still
-- owns the response; deliberation cannot manufacture an encounter receipt.
a,b=fresh();a.state='HOMEWARD'
SAO.Locomotion.order('runner',b,10,0,0,true);job=SAO.Locomotion.jobs.runner
SAO.Disposition.fleeDistance=function()return 8 end
SAO.PathogenPressure=nativePathogen
__threat={x=-13.5,y=.5,dist=14,source='observed',track='runner:contact:1',at=1}
check('unrecognized_distant_contact_preserves_ordinary_route',reachesNeeds(a,b)
    and SAO.Locomotion.jobs.runner==job and not a.conflictRoute)
local beforeRisk=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('unrecognized_distant_contact_is_appraised',beforeRisk and beforeRisk.kind=='watch')
__threat.form='sprinter';__threat.formPerformance=1
__threat.attributeMutations={strength=1,speed=1,senses=1,resilience=1}
check('recognized_risk_changes_actual_response',not reachesNeeds(a,b)
    and a.state=='FLEE' and a.conflictRoute and a.conflictRoute.body==b)
local afterRisk=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('recognized_risk_revises_retained_appraisal',afterRisk and afterRisk.kind=='withdraw'
    and afterRisk.frameId~=beforeRisk.frameId and afterRisk.threat.key==beforeRisk.threat.key
    and afterRisk.threat.distance==beforeRisk.threat.distance
    and afterRisk.admission and afterRisk.admission.owner=='Locomotion')
local ownPremise=false
for _,alternative in ipairs(afterRisk and afterRisk.alternatives or {}) do
    for _,argument in ipairs(alternative.arguments or {}) do
        for _,premise in ipairs(argument.premises or {}) do
            if premise.kind=='personally-appraised-danger' and premise.actorId=='runner'
                and premise.contactKey==__threat.track and premise.form=='sprinter'
                and premise.elevated and premise.withinConcern
                and premise.provenance and premise.provenance.knowledgeOwner=='runner'
                and premise.provenance.observationSource=='observed' then ownPremise=true end
        end
    end
end
check('recognized_risk_has_personal_conditional_basis',ownPremise)
check('appraisal_does_not_grant_pathogen_experience',records.runner.mutationKnowledge==nil
    and records.fellow.mutationKnowledge==nil)

-- Attempt 3 showed withdrawal cycling between nearby destinations as the
-- nearest of two remembered contacts changed. All records below belong to
-- this person's Perception; native movement admission remains controlled.
SAO.Perception.nearestBelievedZombie=privateNearest
SAO.Perception.believedThreatCount=privateCount
local function contactScene(second)
    local actor,native=fresh()
    local planning=records.runner.proceduralPlanning
    planning.spatial={};planning.spatialOrder={}
    SAO.Perception.beliefs.runner.zombies={north={x=-4,y=-6,z=0,at=0,
        source='observed',track='north'}}
    if second then SAO.Perception.beliefs.runner.zombies.south=second end
    SAO.Perception.beliefs.fellow.zombies={}
    moves='MOVE\t-0.5\t1.5\t0\nMOVE\t1.5\t0.5\t0\nMOVE\t-0.5\t-0.5\t0'
    return actor,native
end
local function south()
    return {x=-4,y=7.1,z=0,at=0,source='observed',track='south'}
end
local function selectedX(actor,native)
    decide(actor,native,false)
    local current=SAO.Locomotion.jobs.runner
    return current and current.goal.x,current
end
local x
a,b=contactScene();x=selectedX(a,b)
check('single_contact_preserves_escape_choice',x==-1)
local priorJob=SAO.Locomotion.jobs.runner
local priorRoute=a.conflictRoute.routeKey
SAO.Perception.beliefs.runner.zombies.south=south()
x=selectedX(a,b)
check('new_private_contact_revises_actual_route',x==1 and SAO.Locomotion.jobs.runner~=priorJob
    and __starts==2 and __cancels==1)
check('changed_contact_cancellation_is_not_failure',not SAO.ProceduralPlanning.conflictRouteBlocked('runner',priorRoute,now))
a,b=contactScene(south());x,job=selectedX(a,b)
check('multiple_contacts_change_actual_escape',x==1 and a.state=='FLEE')
local context=SAO.ProceduralPlanning.conflictSnapshot('runner')
local objection=false
for _,offer in ipairs(context.alternatives) do
    if offer.id=='route:0:0:0:-1:1:0' then
        for _,value in ipairs(offer.objections) do
            if value=='approaches-another-believed-threat' then objection=true end
        end
    end
end
check('other_contact_remains_conditional_objection',objection and context.kind=='withdraw'
    and context.threat.key=='north' and context.admission.owner=='Locomotion')
local firstToken=context.admission.id
-- A small northward change makes south the nearest contact. Both remain
-- known, and the eastward native job remains a usable personally chosen exit.
b.x=.65;b.y=.7
check('nearest_contact_actually_switches',privateNearest('runner',__tick,b.x,b.y).track=='south')
selectedX(a,b)
check('nearest_switch_retains_actual_escape_owner',SAO.Locomotion.jobs.runner==job
    and __starts==1 and __cancels==0
    and SAO.ProceduralPlanning.conflictSnapshot('runner').admission.id==firstToken)

for _,case in ipairs({'expired','future','other_floor','unidentified_sound','foreign'}) do
    local second=south()
    if case=='expired' then second.at=-601
    elseif case=='future' then second.at=50
    elseif case=='other_floor' then second.z=1
    elseif case=='unidentified_sound' then second.source='heard' end
    a,b=contactScene(case~='foreign' and second or nil)
    if case=='foreign' then SAO.Perception.beliefs.fellow.zombies.south=second end
    x=selectedX(a,b)
    check(case..'_contact_does_not_change_escape',x==-1)
    if case=='unidentified_sound' then check('unidentified_sound_does_not_change_escape',x==-1) end
end

a,b=contactScene(south())
local original=SAO.Perception.beliefs.runner.zombies.south
local contacts=SAO.Perception.believedZombieContacts('runner',1,b.x,b.y,0)
check('private_contacts_preserve_source_and_age',#contacts==2 and contacts[2].at==0
    and contacts[2].source=='observed' and contacts[2].track=='south')
contacts[2].x=900;contacts[2].at=900
check('private_contacts_are_detached',original.x==-4 and original.at==0)
SAO.Conditions={memoryFactor=function(id)return id=='runner' and .5 or 2 end}
original.at=-301
check('contact_reader_uses_personal_memory_horizon',#SAO.Perception.believedZombieContacts('runner',1,b.x,b.y,0)==1)
SAO.Conditions=nil
original.at=0;original.source='told';original.teller='fellow';original.track=nil
contacts=SAO.Perception.believedZombieContacts('runner',1,b.x,b.y,0)
check('report_remains_report_without_native_identity',contacts[2].source=='told'
    and contacts[2].teller=='fellow' and contacts[2].track==nil)
x=selectedX(a,b)
check('received_location_informs_possible_route_harm',x==1)

-- Repeated records at the same position remain uncertain records. Their
-- multiplicity neither stacks the route objection nor rewrites the beliefs.
a,b=contactScene(south())
for n=1,20 do SAO.Perception.beliefs.runner.zombies['duplicate'..n]=south() end
local countBefore=privateCount('runner',1,10,b.x,b.y)
x=selectedX(a,b)
local projected=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('duplicate_contact_records_keep_choice',x==1)
for _,offer in ipairs(projected.alternatives) do
    if offer.id=='route:0:0:0:-1:1:0' then
        local harms=0
        for _,value in ipairs(offer.objections) do if value=='bodily-harm' then harms=harms+1 end end
        check('repeated_sightings_add_one_route_objection',harms==1)
    end
end
check('route_appraisal_does_not_rewrite_contact_count',privateCount('runner',1,10,b.x,b.y)==countBefore)

a,b=contactScene(south())
local north=SAO.Perception.beliefs.runner.zombies.north
SAO.Perception.beliefs.runner.zombies={zzz=south(),aaa=north}
x=selectedX(a,b)
check('contact_map_order_does_not_choose_escape',x==1)
a,b=contactScene(south())
SAO.Perception.beliefs.runner.zombies.third={x=20,y=.5,z=0,at=0,source='observed',track='third'}
selectedX(a,b)
local thirdIncluded=false
for _,offer in ipairs(SAO.ProceduralPlanning.conflictSnapshot('runner').alternatives) do
    if offer.id=='route:0:0:0:1:0:0' then
        for _,value in ipairs(offer.objections) do
            if value=='approaches-another-believed-threat' then thirdIncluded=true end
        end
    end
end
check('third_fresh_contact_informs_route_consequence',thirdIncluded)

-- Exercise the real acquisition producer across a failed scan. The native
-- receiver retains one continuous track, while lastScanAt advances through
-- the unavailable result. Both historical rows survive in the private store.
a,b=contactScene()
for key,value in pairs(privatePerception) do
    if key~='beliefs' then SAO.Perception[key]=value end
end
SAO.Perception.beliefs.runner=nil
local seen='Z:-4:7.1:8:track:continuous-contact:floor:0'
SAOJavaBridge.perceive=function()return seen end
SAO.Perception.observe('runner',b,100,false)
seen=nil;SAO.Perception.observe('runner',b,120,false)
seen='Z:-4:-6:8:track:continuous-contact:floor:0'
SAO.Perception.observe('runner',b,140,false)
local sourceRows=0
for _,belief in pairs(SAO.Perception.beliefs.runner.zombies) do
    if belief.track=='continuous-contact' then sourceRows=sourceRows+1 end
end
check('failed_scan_produces_two_same_track_records',sourceRows==2)
contacts=SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)
check('latest_continuous_track_supersedes_older_location',#contacts==1
    and contacts[1].at==140 and contacts[1].y==-6)
__tick=140;x=selectedX(a,b)
check('failed_scan_old_position_does_not_reverse_escape',x==-1)
local latestRow,olderRow
for _,belief in pairs(SAO.Perception.beliefs.runner.zombies) do
    if belief.at==140 then latestRow=belief else olderRow=belief end
end
latestRow.z=1
check('same_track_precedence_precedes_floor_filter',#SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)==0)
latestRow.at=142
contacts=SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)
check('future_same_track_cannot_supersede_acquired_position',#contacts==1 and contacts[1].at==100)
latestRow.at=140;latestRow.x=0/0
contacts=SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)
check('invalid_same_track_cannot_supersede_acquired_position',#contacts==1 and contacts[1].at==100)
latestRow.x=-4;latestRow.z=0;latestRow.at=100
check('same_time_conflicting_locations_remain_uncertain',#SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)==2)
latestRow.at=140;latestRow.track='reacquired-contact'
check('different_tracks_do_not_invent_shared_identity',#SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)==2)
latestRow.track='continuous-contact';latestRow.source='told';latestRow.teller='fellow'
check('reported_track_does_not_supersede_personal_sight',#SAO.Perception.believedZombieContacts('runner',141,b.x,b.y,0)==2)
check('reader_keeps_original_private_history',olderRow.at==100 and olderRow.y==7.1
    and SAO.Perception.beliefs.runner.lastScanAt==140)
__result='PASS '..table.concat(checks,',')
