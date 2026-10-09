local n=0
local function check(name,v)n=n+1;assert(v,'OWNED_CALLER:'..name);print('CASE '..name)end
local registry=SAO.SourceIntegration
for id in pairs(SAO.SourcePackageManifest.sources)do check('packaged_ready_'..id,registry.active(id))end
check('unknown_refused',not registry.active('not-a-source'))
local savedManifest=SAO.SourcePackageManifest;SAO.SourcePackageManifest={schema='unknown',packageId='SurvivorAwareness',sources=savedManifest.sources};check('changed_manifest_schema_refused',not registry.active('LifestyleHobbies'))
SAO.SourcePackageManifest={schema=savedManifest.schema,packageId='SurvivorAwareness',sources={}};check('replaced_manifest_generation_refused',not registry.active('LifestyleHobbies'));SAO.SourcePackageManifest=savedManifest
for _,path in ipairs({'../secret','media/../secret','media/lua/../lua/shared/core/NMCore.lua','/media/x','C:/media/x','media\\x','media/x'..string.char(0)})do check('unsafe_path_refused',registry.reader('NewMusic',path)==nil)end
check('creation_refused',registry.reader('NewMusic','media/lua/shared/core/NMCore.lua',true)==nil)
__externalSource='LifestyleHobbies';check('duplicate_external_refused',not registry.active('LifestyleHobbies')and registry.loadReport.LifestyleHobbies=='duplicate-external-source-refused')
check('private_source_available_with_external',registry.available('LifestyleHobbies'))
local sharedReader=registry.reader('LifestyleHobbies','media/lua/shared/LSUtil.lua')
check('private_original_readable_with_external',sharedReader~=nil)
if sharedReader then sharedReader:close()end
check('packaged_autoload_still_refused',not registry.active('LifestyleHobbies'))
__externalSource=nil
__fresh();local M=SAO.LeisureMusic
check('owned_source_actor_initialize',M.prepareActor('person',__body))
local offer
for _,row in ipairs(M.offers('person',__body))do if row.activity=='practice-instrument'then offer=row end end
check('owned_source_real_offer',offer and offer.instrumentType=='Harmonica')
local ok,w=M.begin('person',__body,offer,'purpose:1');check('owned_source_begin',ok)
__queued:start();__queued:update();check('original_sound_callback',__played[1]=='Harmonica00FarewellWaltz')
__seconds=61;__delta=.5;__queued:update();check('native_stats_effect',__stats:get(CharacterStat.ENDURANCE)<.8)
__delta=1;__queued:perform();check('actual_owner_terminal',M.outcome('person',w.sequence).status=='completed')
local env=setmetatable({},{__index=_G});check('owned_supply_original_inventory_owner',SAO.LeisureMusicSupply.prepareEnvironment(env)and type(env.NMIntentInventoryOps)=='table')
local sourcePath='media/SAOSources/NewMusic/media/lua/shared/intent/NMIntentInventoryOps.lua'
__hideOriginal=sourcePath;local valid,reason=pcall(SAO.LeisureMusicSupply.prepareEnvironment,setmetatable({},{__index=_G}));check('missing_owned_original_refused',not valid and tostring(reason):find('supply%-source%-unavailable'))
__hideOriginal=nil;__tamperOriginal=sourcePath;valid,reason=pcall(SAO.LeisureMusicSupply.prepareEnvironment,setmetatable({},{__index=_G}));check('altered_owned_original_refused',not valid and tostring(reason):find('supply%-source%-revision%-changed'))
__tamperOriginal=nil
__fresh();__externalSource='LifestyleHobbies';local externalOffer
for _,row in ipairs(M.offers('person',__body))do if row.activity=='practice-instrument'then externalOffer=row end end
check('music_private_offer_with_external',externalOffer~=nil)
local externalAccepted,externalWork=M.begin('person',__body,externalOffer,'purpose:1')
check('music_private_begin_with_external',externalAccepted)
__queued:start();__queued:update();__delta=1;__queued:perform()
check('music_private_terminal_with_external',M.outcome('person',externalWork.sequence).status=='completed')
__externalSource=nil
__hideSentinel=true;__loadPackageRegistry();check('missing_owned_seal_refused',not SAO.SourceIntegration.active('LifestyleHobbies'));__hideSentinel=false
__tamperSentinel=true;__loadPackageRegistry();check('bad_owned_seal_refused',not SAO.SourceIntegration.active('LifestyleHobbies'))
__tamperSentinel=false;__loadPackageRegistry()
check('registry_restored',SAO.SourceIntegration.active('LifestyleHobbies'))
local paths={};for _,path in ipairs(__ownedReads)do assert(path:sub(1,17)=='media/SAOSources/','nonowned source route '..path);paths[path]=true end
check('actual_owned_paths_used',paths[sourcePath]and paths['media/SAOSources/LifestyleHobbies/media/lua/shared/TimedActions/PlayInstrumentTraining.lua']and paths['media/SAOSources/LifestyleHobbies/media/lua/shared/LSUtil.lua'])
print('PASS owned source callers '..n)
