local n=0
local function check(name,v)assert(v,'D2_BINDING:'..name);n=n+1;print('CASE '..name)end
SandboxVars.Debug={DanceAnim=false};Metabolics.Fitness='Fitness';CharacterTrait.PARTYANIMAL='PARTYANIMAL'
local function fresh()
 fixture('placed',true);__body:getModData().SAOPersonId='person';__body:getModData().PlayerVoice=0
 __body.isTimedActionInstant=function()return false end;__body.isDead=function()return false end
 __body.setMetabolicTarget=function()end
 __items={__instrument}
 __body.getPrimaryHandItem=function()return __instrument end;__body.getSecondaryHandItem=function()return __instrument end
 __body.setPrimaryHandItem=function()end;__body.setSecondaryHandItem=function()end
 __body.isItemInBothHands=function(_,item)assert(item~=nil,'borrowed-or-missing-primary-argument');return item==__instrument end
 __seconds=1;__sourceTick();ZombRand=function(a,b)if b then return a end;return 0 end
end
local function begin()
 local offer;for _,v in ipairs(M.offers('person',__body))do if v.activity=='dance'then offer=v end end
 local ok,w=M.begin('person',__body,assert(offer),'purpose:1');assert(ok,tostring(w));return w,__queued
end
fresh();handItemP={foreign=true};AnimTime=999
local w,a=begin();a:start()
check('live_start_uses_own_primary',a.handItemP==__instrument and a.handItemS==0)
check('canonical_begin_preserves_nonzero_source_default',a.actionType=='Bob_PreDancingDefault')
a:update();check('canonical_nonzero_uses_source_40',a.AnimDelayEnd==40)
-- Public source zero-type path: the canonical caller still supplies its original
-- nonzero default above. Here only the source-public parameter is varied.
a.actionType=0;a.AnimTime=0;a:update()
check('public_zero_type_ignores_foreign_ambient_time',a.AnimDelayEnd==120)
a.AnimTime=17;a:update();check('public_zero_type_uses_own_anim_time',a.AnimDelayEnd==17)
check('bindings_never_write_ambient_globals',handItemP.foreign==true and AnimTime==999)
local work=M.work('person');local adapt=work.sourceAdaptations
check('raw_source_revision_preserved',adapt.rawRevision==work.revision and adapt.rawRevision=='6cdd500807d05edbf4d9e2f4c8c2036920d858c2d7887a477c6fb337e48e845c')
check('four_audio_and_two_action_sites_recorded',#adapt.sites==4 and #adapt.ownershipSites==2)
local code=__sources['LifestyleHobbies:shared/TimedActions/PlayerIsDancingToMusic.lua']:gsub('\r\n','\n')
if code:sub(-1)~='\n' then code=code..'\n'end
code=code:gsub('elseif AnimTime ~= 0','elseif self.AnimTime ~= 0')
code=code:gsub('not self.character:isItemInBothHands%(handItemP%)','not self.character:isItemInBothHands(self.handItemP)')
for _,arg in ipairs({'self.fallSoundScream','self.fallSound','voiceSoundF','voiceSound'})do
 local site='self.character:getEmitter():playSound('..arg..')'
 code=code:gsub(site:gsub('([^%w])','%%%1'),'__dancePlaySound(self.character,'..arg..')')
end
local h1,h2=0,0;for i=1,#code do local b=string.byte(code,i);h1=(h1*31+b)%2147483647;h2=(h2*131+b)%2147483647 end
check('derived_exact_executable_fingerprints_recorded',adapt.derivedRevision.h1==h1 and adapt.derivedRevision.h2==h2 and adapt.derivedRevision.bytes==#code)
check('preparation_does_not_grant_completion_or_XP',M.outcome('person',w.sequence)==nil and __skillRequests==0)
M.interrupt('person',__body,'fixture-end')
local key='LifestyleHobbies:shared/TimedActions/PlayerIsDancingToMusic.lua';local original=__sources[key]
__sources[key]=original..'\n-- changed original source\n';fresh()
local candidate;for _,v in ipairs(M.offers('person',__body))do if v.activity=='dance'then candidate=v end end
local admitted,reason=M.begin('person',__body,assert(candidate),'purpose:1')
check('raw_source_tamper_refuses_before_callbacks',not admitted and tostring(reason):find('source%-revision%-changed'))
__sources[key]=original
print('PASS private action bindings '..n)
