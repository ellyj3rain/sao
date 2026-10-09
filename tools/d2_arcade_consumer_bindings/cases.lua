local G=SAO.LeisureGames;local checks=0
local function check(name,value)if not value then error('ARCADE_BINDING:'..name)end checks=checks+1 end
local function specialCalls()return(__helperRequires.ProjectArcade_SoundPolicy or 0)+(__helperRequires.ProjectArcade_ArcadeAmbientSound or 0)end
check('full_source_inactive_load_no_new_require',specialCalls()==0)
local b,o=arcadeFixture('inactive','pa_arcades_0',2)
check('source_inactive_arcade_not_offered',#G.offers('inactive',b)==0)
check('source_inactive_queries_no_new_require',specialCalls()==0)
check('broad_consumer_api_preserved',type(G.reset)=='function'and type(G.outcome)=='function'and type(G.offers)=='function'and type(G.begin)=='function')
__forbidNewModules=false
SAO.SourceIntegration.active=function(name)return name=='ProjectArcade'end
SAO.SourceIntegration.available=SAO.SourceIntegration.active
local allObjects={}
local function fresh(id,sprite,offset)
 local body,obj=arcadeFixture(id,sprite,2);offset=offset or 0;obj.square.x=obj.square.x+offset;body.current.x=body.current.x+offset
 obj.square.getX=function(self)return self.x end;body.current.getX=function(self)return self.x end
 obj.getX=function(self)return self.square:getX()end
 local fact=body.observations[1];fact.x=obj.square:getX();fact.key='object:'..fact.x..':10:0:0:arcade-machine';__objects={[fact.key]=obj}
 for key,value in pairs(__objects)do allObjects[key]=value end;__objects=allObjects
 local selected;for _,v in ipairs(G.offers(id,body))do selected=v;break end
 check('active_available_'..id,selected~=nil);check('active_admitted_'..id,G.begin(id,body,selected,'purpose:'..id))
 local payment=ISTimedActionQueue.queues[body];native(payment,0);payment:perform();payment:complete()
 return body,obj,ISTimedActionQueue.queues[body]
end
local b1,o1,a1=fresh('one','pa_arcades_0',0)
local b2,o2,a2=fresh('two','pa_arcades_4',20)
check('offers_admission_no_new_module',specialCalls()==0)
native(a1,0);check('exact_first_ambient_target',#__ambientTargets==1 and __ambientTargets[1]==o1)
native(a2,0);check('exact_second_ambient_target',#__ambientTargets==2 and __ambientTargets[2]==o2)
check('one_cached_ambient_owner',__helperLoads.ProjectArcade_ArcadeAmbientSound==1 and __eventAdds.OnTickEvenPaused==1 and __eventAdds.OnPostMapLoad==1)
local startClock=__hours*3600000
a1:update();a2:update()
check('actual_update_bound_duration_module',(__helperRequires.ProjectArcade_SoundPolicy or 0)>=2 and __helperLoads.ProjectArcade_SoundPolicy==1)
check('initial_clip_durations_exact',a1.nextLoopAtMs==startClock+46000-200 and a2.nextLoopAtMs==startClock+25000-200)
check('distinct_captured_emitters',a1.emitter~=a2.emitter and a1.emitter.pos[1]==10 and a2.emitter.pos[1]==30)
local e1,e2=a1.emitter,a2.emitter;local id1,id2=a1.soundId,a2.soundId
check('both_emitters_owned_live',e1:isPlaying(id1)and e2:isPlaying(id2))
local expected={PAMsfplay=46000,PAMdroidsplay=30000,PAMpinballplay=29000,PAddplay=58000,PAsiplay=38000,PAafplay=50000,PAtzplay=53000,PAijplay=60500,PAdkplay=55000,PAt2play=60000,PAcenplay=60000,PAdigplay=64000,PAnbaplay=62000,PAtmntplay=62000,PAmkplay=60000,PAfhplay=60000,PAbk2000play=70000,PAetpmplay=60000,PAswplay=60000,PAmbplay=60000,unknown=25000}
for sound,duration in pairs(expected)do
 a1.loopSoundName=sound;a1.nextLoopAtMs=startClock;a1:update()
 check('exact_shared_policy_'..sound,a1.nextLoopAtMs==startClock+duration-200)
 check('other_instance_unmodified_'..sound,a2.emitter==e2 and a2.soundId==id2 and e2:isPlaying(id2))
end
local exactCaptured=a1.emitter;local activeSound=a1.soundId;local secondClock=a2.nextLoopAtMs
check('foreign_interrupt_refused',not G.interrupt('one',b2,'foreign'))
check('foreign_interrupt_retains_both',exactCaptured:isPlaying(activeSound)and e2:isPlaying(id2))
G.interrupt('one',b1,'done')
check('first_lifetime_released_exact_audio',G.outcome('one',1).status=='interrupted'and not exactCaptured:isPlaying(activeSound))
check('second_lifetime_audio_and_clock_retained',G.work('two')~=nil and e2:isPlaying(id2)and a2.nextLoopAtMs==secondClock)
local calls=specialCalls();a1:update();check('retired_update_no_helper_call',specialCalls()==calls)
G.interrupt('two',b2,'done');check('second_exact_lifetime_release',not e2:isPlaying(id2)and G.outcome('two',1).status=='interrupted')
G.reset('proof-finished');check('module_cache_and_events_stable',__helperLoads.ProjectArcade_ArcadeAmbientSound==1 and __helperLoads.ProjectArcade_SoundPolicy==1 and __eventAdds.OnTickEvenPaused==1)
__result='PASS Arcade consumer bindings '..checks
