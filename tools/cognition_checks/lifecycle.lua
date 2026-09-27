local C,Ctl,I=SAO.Cognition,SAO.Controller,SAO.Identity
local n=0
local function check(name,v)assert(v,"LIFECYCLE:"..name);n=n+1 end
local function prepare(id,passive)
    local rec={id=id,forename=id,surname="Fixture",x=0,y=0,z=0}
    records[id]=rec
    bodies[id]={dead=false,isDead=function(self)return self.dead end,getX=function()return 0 end,
        getY=function()return 0 end,getZ=function()return 0 end}
    if passive then Ctl.adoptPassive(rec)else Ctl.adopt(rec)end
    hours=hours+1
    local action,ep=C.choose(id,{actorId=id,worldHours=hours,hunger=.8,thirst=0,fatigue=.1,eatAt=.3,drinkAt=.3,
        foodAllowed=true,waterAllowed=false,inspectionAllowed=false,knownFood=1,knownWater=0,knownPlaces=1,
        capabilities={cook=true,forage=false,treat=false}})
    assert(action=="food" and ep,"lifecycle admission")
    C.started(id,ep,true,"travelling")
    Ctl.agents[id].state="TRAVEL"
    return rec,rec.cognition.episodes[#rec.cognition.episodes],bodies[id]
end
C.configure(0,60,3)
local rec,episode=prepare("route")
local original=C.capture("route","native-use")
local agent=Ctl.agents.route
sourceClosed=false
check("refused_drop_retains_episode",Ctl.drop("route")==false and Ctl.agents.route==agent
    and episode.status=="attempted" and rec.cognition.pendingEpisode==episode.id)
sourceClosed=true
check("successful_drop_censors",Ctl.drop("route") and Ctl.agents.route==nil and episode.status=="censored"
    and episode.reason=="controller-drop" and rec.cognition.pendingEpisode==nil)
check("adopted_ordinary_does_not_inherit",Ctl.adopt(rec) and C.capture("route","native-use").episodeId==nil)
local ordinary=C.capture("route","native-use")
check("new_same_goal_not_old_experiment",C.publish("route",ordinary,{kind="consume",category="food",status="completed",hungerDelta=.1})
    and episode.status=="censored" and episode.outcome==nil)
check("late_original_preserves_terminal",C.publish("route",original,{kind="consume",category="food",status="completed",hungerDelta=.1})
    and episode.status=="censored" and episode.outcome==nil)

rec,episode=prepare("orphan");Ctl.agents.orphan=nil
check("fresh_adoption_closes_orphan",Ctl.adopt(rec) and episode.status=="censored"
    and C.capture("orphan","native-use").episodeId==nil)
rec,episode=prepare("source");Ctl.agents.source=nil
sourceOwner={actorId="source",unavailable=true}
check("adoption_retains_source_owner",Ctl.adopt(rec) and episode.status=="attempted"
    and C.capture("source","native-use").episodeId==episode.id)
sourceOwner=nil
rec,episode=prepare("unknown");Ctl.agents.unknown=nil;sourceUnknown=true
check("unreadable_source_owner_retained",Ctl.adopt(rec) and episode.status=="attempted")
sourceUnknown=false
rec,episode=prepare("already")
check("idempotent_adoption_preserves_execution",Ctl.adopt(rec) and episode.status=="attempted")
rec,episode=prepare("passive");Ctl.agents.passive=nil
check("passive_adoption_closes_orphan",Ctl.adoptPassive(rec) and episode.status=="censored")

rec,episode=prepare("canonical-death")
local revision=rec.cognition.models.ordinary.revision
check("canonical_death_censors_after_dead",I.markDead(rec,0,"fixture") and rec.dead and episode.status=="censored"
    and episode.reason=="death" and rec.cognition.pendingEpisode==nil)
check("dead_history_retained",C.snapshot(rec.id).episodes[1].id==episode.id and rec.cognition.models.ordinary.revision==revision)
rec,episode=prepare("refused-death");rec.returnTransition={}
check("refused_death_retains_episode",not I.markDead(rec,0,"fixture") and not rec.dead
    and episode.status=="attempted" and rec.cognition.pendingEpisode==episode.id)
for _,passive in ipairs({false,true})do
    Ctl.agents={}
    local id=passive and "loaded-passive-death" or "loaded-death"
    local rec,ep,body=prepare(id,passive);body.dead=true
    Ctl.__cognitionLifecycleUpdate(id,Ctl.agents[id])
    check(id,rec.dead and Ctl.agents[id]==nil and ep.status=="censored" and ep.reason=="death")
end
RESULT="PASS cognition lifecycle "..n
