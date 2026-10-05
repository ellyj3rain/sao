-- Appended to the production conflict-response fixture.
local floorChecks=0
local function floorCheck(name,value)if not value then error("CROSSFLOOR:"..name)end;floorChecks=floorChecks+1 end
local M,C,Per=SAO.CognitiveModels,SAO.Cognition,__floorPerception
local function premise(view,kind)
    for _,alternative in ipairs(view.alternatives)do for _,argument in ipairs(alternative.arguments)do
        for _,p in ipairs(argument.premises)do if p.kind==kind then return p end end
    end end
end
local a,b,t=fresh();b.z=1
local frame={actorId="runner",atHours=now,values=SAO.Disposition.conflictValues("runner"),fear=.1,
    overwhelmed=false,escapeBlocked=false,threat={kind="person",key="Neighbor",source="observed",distance=1,count=1,at=1,z=0,observerZ=1}}
local watch={{id="watch",kind="watch",available=true,reason="Retain awareness while reach is unresolved.",effects={},objections={}}}
local across=C.appraiseConflict("runner",frame,watch)
local crossPremise=across and premise(across,"private-situation")
floorCheck("shared_close_excludes_known_other_floor",crossPremise and crossPremise.close==false
    and crossPremise.z==0 and crossPremise.observerZ==1 and crossPremise.floorKnown and crossPremise.sameFloor==false
    and crossPremise.reachability=="unknown")
frame.threat.z=1
local same=C.appraiseConflict("runner",frame,watch)
floorCheck("same_floor_private_close_retained",same and premise(same,"private-situation").close==true
    and premise(same,"private-situation").sameFloor==true)
floorCheck("floor_revision_changes_continuity",across.evidenceKey~=same.evidenceKey)
frame.threat.z=nil
local legacy=C.appraiseConflict("runner",frame,watch)
floorCheck("legacy_floor_remains_unknown",legacy and premise(legacy,"private-situation").floorKnown==false
    and premise(legacy,"private-situation").sameFloor==nil and premise(legacy,"private-situation").close==true)
frame.threat.z=0;frame.threat.observerZ=0
floorCheck("foreign_observer_floor_refused",C.appraiseConflict("runner",frame,watch)==nil)
frame.threat.observerZ=1;frame.threat.z=.5
floorCheck("fractional_contact_floor_refused",C.appraiseConflict("runner",frame,watch)==nil)
frame.threat.z=0/0
floorCheck("nan_contact_floor_refused",C.appraiseConflict("runner",frame,watch)==nil)
frame.threat.z=0;frame.threat.floorKnown=false
floorCheck("contradictory_geometry_refused",C.appraiseConflict("runner",frame,watch)==nil)
floorCheck("basement_geometry_preserved",M.contactGeometry({distance=1,z=-1,observerZ=0}).sameFloor==false)

a,b,t=fresh();b.z=1;t.z=0;t.dist=1;moves="";native="REFUSED\tdifferent-floor"
decide(a,b,t)
local retained=SAO.ProceduralPlanning.conflictSnapshot("runner")
floorCheck("executor_preserves_floor_evidence",retained and retained.threat.z==0 and retained.threat.observerZ==1
    and retained.threat.floorKnown and retained.threat.sameFloor==false and retained.threat.reachability=="unknown")
floorCheck("visibility_does_not_grant_native_attack",attacks==0 and not a.conflictCombat)
a,b,t=fresh();b.z=1;t.z=0;t.dist=1;moves="";native="AVAILABLE\tranged\t1\t20"
local savedValues=SAO.Disposition.conflictValues
SAO.Disposition.conflictValues=function(id)return {actorId=id,selfPreservation=.5,aggression=.85,nerve=.85,discipline=.5,compassion=.5}end
decide(a,b,t)
floorCheck("actual_native_ranged_still_admitted",attacks==1 and __attack.mode=="ranged" and __attack.key==t.track)
SAO.Disposition.conflictValues=savedValues

a,b,t=fresh();b.z=1
SAO.Perception=Per;Per.beliefs={}
SAOJavaBridge.perceive=function()return "P:Neighbor:0.5:0.5:1:ok:zao:afflicted:0.7:floor:0"end
Per.observe("runner",b,100,false)
local formed=Per.nearestFormedPerson("runner",100,b.x,b.y)
floorCheck("actual_p_row_retains_floor",Per.beliefs.runner.people.Neighbor.z==0 and formed.z==0 and formed.fromPerson)
SAO.Standing.keyForObserved=function(name)return name end
SAO.Standing.isHostileTo=function()return true end
local hostile=SAO.Controller.__floorProbeHostile("runner",100,b.x,b.y)
floorCheck("hostile_reader_preserves_floor",hostile and hostile.z==0)
Per.beliefs={};SAOJavaBridge.perceive=function()return "P:Neighbor:0.5:0.5:1:ok:zao:afflicted:0.7"end
Per.observe("runner",b,100,false)
floorCheck("legacy_p_row_does_not_inherit_floor",Per.nearestFormedPerson("runner",100,b.x,b.y).z==nil)
Per.beliefs={};SAOJavaBridge.perceive=function()return "P:Neighbor:0.5:0.5:1:ok:zao:afflicted:0.7:floor:0.5"end
Per.observe("runner",b,100,false)
floorCheck("malformed_p_floor_stays_unknown",Per.nearestFormedPerson("runner",100,b.x,b.y).z==nil)

SAO.Census={skillOf=function()return 0 end}
SAO.Perception.believedThreatCount=function()return 1 end
SAO.Perception.nearestBelievedThreat=function()return {dist=1,z=0,at=100,source="observed",fromPerson=true}end
local labor=SAO.Labor.assess("runner",{category="food",tick=100,atHours=now,position={x=b.x,y=b.y,z=1},
    carriedRawItems={{itemId=12,itemType="Base.Chicken",cookable=true}},needs={fatigue=.1,health=1}})
local danger=labor and labor.options[1] and labor.options[1].appraisal.danger
floorCheck("labor_keeps_floor_and_unknown_reach",danger and danger.nearest.z==0 and danger.nearest.observerZ==1
    and danger.nearest.floorKnown and danger.nearest.sameFloor==false and danger.nearest.reachability=="unknown")
__result="PASS crossfloor consumers: "..floorChecks.." checks; inherited conflict "..checks
