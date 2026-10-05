-- Real Admissions, PersonalAwareness and StudyWorld.start; native identity,
-- history, spawn geometry and perception delivery are controlled boundaries.
local checks=0
local function check(name,value) checks=checks+1;assert(value,'INITIAL_AWARENESS:'..name) end
local function copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
local function equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local sha,save=string.rep('a',64),'controlled-awareness-admission'
local sites={{id='home',x=128,y=128,z=0},{id='other',x=384,y=128,z=0}}
local requested={home=2,other=1}
local function report()
    return {id='radio-before-genesis',kind='outbreak',affirmed=true,sourceId='local-radio',
        sourceAtHours=1,receivedAtHours=1.5,certainty='reported'}
end
local function authored()
    return {{siteId='home',actorOrdinal=1,entries={}},
        {siteId='home',actorOrdinal=2,entries={report()}}}
end
local people,stores,bodies,now,tick,created,witness
local function setup()
    people,stores,bodies,now,tick,created={},{},{},2,18000,0
    local ids={'native-zeta','native-alpha','native-outside'}
    SAO={Log={line=function()end,tally=function()end},PopulationAdmissions={},PersonalAwareness={},
        Knowledge={},Standing={},Body={active={},foreign={}},Identity={},History={},Perception={}}
    ModData={getOrCreate=function(key)stores[key]=stores[key]or{};return stores[key]end,
        get=function(key)return stores[key]end}
    SAO.Identity.all=function()return people end
    SAO.Identity.get=function(id)return people[id]end
    SAO.Identity.beliefKey=function(rec)return rec.id end
    SAO.Identity.livingCount=function()local n=0;for _,rec in pairs(people)do if not rec.dead then n=n+1 end end;return n end
    SAO.Identity.create=function(_,_,x,y,z)
        created=created+1;local rec={id=ids[created],x=x,y=y,z=z,nativeXP=9}
        people[rec.id]=rec;return rec
    end
    SAO.Body.get=function(id)return bodies[id]end
    SAO.History.ticks=function()return tick end
    SAO.History.countyHours=function()return now end
    SAO.History.generate=function(id,rec)check('history-before-awareness-'..id,rec.personalAwareness==nil);rec.historyGenerated=true end
    SAO.Rand={int=function(maximum)if maximum==100 then return 50 end;return 0 end}
    SAO.Perception.radioReceptions=function()return{}end
    SAO.Perception.bindAwarenessReceiver=function(owner,receiver)
        if owner~=SAO.PersonalAwareness then return false end;witness=receiver;return true
    end
    SpawnRegionMgr={getSpawnRegions=function()return{{name='native-origin',points={unemployed={
        {posX=128,posY=128,posZ=0},{posX=384,posY=128,posZ=0}}}}}end}
    __loadOwners()
end
local function stage()
    check('stage-native-cohort',SAO.PopulationAdmissions.stageInitialPeople(sha,save,requested,sites,3))
end
local function generate()
    SAO.PopulationAdmissions.ensurePopulation({population=3,newcomers=3,refillDays=1},tick)
end
local function known(id)return SAO.PersonalAwareness.query(id)end

setup()
check('unstaged-awareness-refused',not SAO.PopulationAdmissions.stageInitialAwareness(sha,save,authored()))
stage()
check('wrong-world-refused',not SAO.PopulationAdmissions.stageInitialAwareness(string.rep('b',64),save,authored()))
check('wrong-save-refused',not SAO.PopulationAdmissions.stageInitialAwareness(sha,'foreign-save',authored()))
local invalid={}
local function bad(label,change)local rows=authored();change(rows);invalid[#invalid+1]={label=label,rows=rows}end
bad('future-reception-refused',function(r)r[2].entries[1].receivedAtHours=3 end)
bad('source-after-reception-refused',function(r)r[2].entries[1].sourceAtHours=1.75 end)
bad('foreign-site-refused',function(r)r[1].siteId='foreign' end)
bad('wrong-ordinal-refused',function(r)r[1].actorOrdinal=3 end)
bad('duplicate-person-refused',function(r)r[2]=copy(r[1]) end)
bad('duplicate-entry-refused',function(r)r[2].entries[2]=copy(r[2].entries[1]) end)
bad('foreign-person-field-refused',function(r)r[2].personId='native-zeta' end)
bad('malformed-source-refused',function(r)r[2].entries[1].sourceId='' end)
bad('nonfinite-time-refused',function(r)r[2].entries[1].receivedAtHours=math.huge end)
bad('sparse-person-list-refused',function(r)r[4]=copy(r[2])end)
for _,row in ipairs(invalid)do
    check(row.label,not SAO.PopulationAdmissions.stageInitialAwareness(sha,save,row.rows))
    check(row.label..'-no-admission',stores.SurvivorAwareness_Standing.initialStudyAwareness==nil and created==0)
end
local rows=authored()
check('awareness-staged',SAO.PopulationAdmissions.stageInitialAwareness(sha,save,rows))
rows[2].entries[1].sourceId='changed-caller-copy'
check('authored-source-detached',stores.SurvivorAwareness_Standing.initialStudyAwareness.rows[2].entries[1].sourceId=='local-radio')
check('staging-does-not-generate',created==0)
generate()
check('actual-native-ids-created',created==3 and people['native-zeta'] and people['native-alpha'] and people['native-outside'])
local naive,aware,legacy=people['native-zeta'],people['native-alpha'],people['native-outside']
check('actual-history-attached',naive.historyGenerated and aware.historyGenerated and legacy.historyGenerated)
check('ordinal-ledger-not-name-order',naive.initialStudyOrigin.siteId=='home' and aware.initialStudyOrigin.siteId=='home'
    and known(naive.id).configured and not known(naive.id).possible and known(aware.id).possible)
check('explicit-empty-is-naive',naive.personalAwareness and #naive.personalAwareness.initial.entries==0
    and known(naive.id).propositions.outbreak=='unknown')
check('omitted-person-is-legacy',legacy.personalAwareness==nil and known(legacy.id).status=='legacy-unconfigured')
check('reported-not-observed',known(aware.id).propositions.outbreak=='reported'
    and known(aware.id).evidence[1].certainty=='reported')
check('no-native-skills-or-body-granted',naive.nativeXP==9 and aware.nativeXP==9 and not SAO.Body.get(naive.id))
check('recognition-only-no-physical-target',SAO.Knowledge.contactRecognition(naive.id).kind=='unidentified-contact'
    and SAO.Knowledge.contactRecognition(aware.id).kind=='possible-outbreak-contact'
    and SAO.Knowledge.contactRecognition(aware.id).targetId==nil)
local forged=copy(aware)
check('foreign-record-refused',not SAO.PersonalAwareness.attachInitial(forged))
local detached=known(aware.id);detached.evidence[1].sourceId='forged-return'
check('query-detached',known(aware.id).evidence[1].sourceId=='local-radio')
local worldBefore,personBefore=copy(stores),copy(aware)
known(aware.id);SAO.Knowledge.contactRecognition(aware.id)
check('query-pure',equal(worldBefore,stores) and equal(personBefore,aware))
local retainedWorld=stores.SurvivorAwareness_Standing
stores.SurvivorAwareness_Standing=nil
check('missing-source-query-does-not-create-store',not known(aware.id).possible and stores.SurvivorAwareness_Standing==nil)
stores.SurvivorAwareness_Standing=retainedWorld
local retainedAwareness=aware.personalAwareness
aware.personalAwareness=nil
local actualIds=retainedWorld.initialStudyPeople.actualIds.home
actualIds[2]=nil
check('missing-preinitial-ledger-is-unavailable',known(aware.id).configured and known(aware.id).status=='unavailable'
    and not SAO.PersonalAwareness.attachInitial(aware) and aware.personalAwareness==nil)
actualIds[2]=aware.id;aware.personalAwareness=retainedAwareness
local prior=copy(aware.personalAwareness)
local changed=authored();changed[2].entries[1].affirmed=false
check('changed-authored-reload-refused',not SAO.PopulationAdmissions.stageInitialAwareness(sha,save,changed))
check('retained-initial-not-overwritten',known(aware.id).possible and aware.personalAwareness.initial.entries[1].affirmed)

now=2.5;tick=22500
naive.bodyOwnerToken='owned-generation'
local body={getModData=function()return{SAOPersonId=naive.id,SAOExternalToken=naive.bodyOwnerToken}end}
bodies[naive.id]=body;SAO.Body.active[naive.id]=body
check('later-private-witness-admitted',witness(naive.id,body,'familiar-person',tick))
check('later-private-evidence-changes-association',known(naive.id).propositions.turned=='witnessed-association')
local evidence=naive.personalAwareness.observations[1]
local encoded=__nativeRoundtrip({world=stores,people=people})
stores,people=encoded.world,encoded.people
naive,aware,legacy=people['native-zeta'],people['native-alpha'],people['native-outside']
bodies={};SAO.Body.active={}
-- Re-run actual module loading, then bind the original authored world/source.
SAO.PopulationAdmissions={};SAO.PersonalAwareness={};SAO.Knowledge={};__loadOwners()
stage()
check('native-reload-source-rebound',SAO.PopulationAdmissions.stageInitialAwareness(sha,save,authored()))
check('native-reload-private-evidence-retained',#naive.personalAwareness.observations==1
    and naive.personalAwareness.observations[1].sourceId==evidence.sourceId
    and naive.personalAwareness.observations[1].receivedAtHours==2.5)
check('native-reload-initial-still-empty',#naive.personalAwareness.initial.entries==0 and known(aware.id).possible)
local count=created;generate();check('reload-does-not-generate-again',created==count)
SAO.PopulationAdmissions.rebindWorld()
check('rebind-withholds-authored-source',known(aware.id).status=='unavailable' and not known(aware.id).possible)
check('rebind-retains-private-bytes',#naive.personalAwareness.observations==1 and naive.personalAwareness.observations[1].sourceId==evidence.sourceId)
stage()
check('original-source-restores-binding',SAO.PopulationAdmissions.stageInitialAwareness(sha,save,authored()) and known(aware.id).possible)
local origin=aware.initialStudyOrigin
for _,entry in ipairs({{'definitionSha256',string.rep('c',64)},{'saveName','wrong-save'},{'admittedAtHours',99}})do
    local key,value=entry[1],entry[2];local old=origin[key];origin[key]=value
    check('altered-origin-withheld-'..key,not known(aware.id).possible)
    origin[key]=old
end
check('authentic-origin-restores',known(aware.id).possible)

setup();stage();generate()
check('late-genesis-awareness-refused',not SAO.PopulationAdmissions.stageInitialAwareness(sha,save,authored()))
check('whole-plan-omission-is-legacy',known('native-zeta').status=='legacy-unconfigured'
    and people['native-zeta'].personalAwareness==nil)

-- Execute the actual StudyWorld.start producer, after controlled native
-- preparation acknowledges its map/bounds/options. No template extraction.
setup()
local config={definitionSha256=sha,mapName='AwarenessFixture',seed='fixture-seed',
    extent={minCellX=0,minCellY=0,cellsX=2,cellsY=2},sandbox={['SurvivorAwareness.Population']=3},
    observation={sites=sites},situation={initialPeopleBySite=requested,initialAwareness=authored()}}
local grid={getMinX=function()return 0 end,getMinY=function()return 0 end,getMaxX=function()return 1 end,getMaxY=function()return 1 end}
getWorld=function()return{getMap=function()return config.mapName end,getMetaGrid=function()return grid end,getWorld=function()return save end}end
getSandboxOptions=function()return{getOptionByName=function(_,key)return{asConfigOption=function()
    return{getValueAsObject=function()return config.sandbox[key]end}end}end}end
WorldGenParams={INSTANCE={getSeedString=function()return config.seed end}}
isClient=function()return false end;isServer=isClient;getTimestampMs=function()return 1000 end
Events=setmetatable({}, {__index=function(t,key)local row={Add=function()end};rawset(t,key,row);return row end})
stores.StudyWorld={definitionSha256=sha}
local study=__loadStudy(config);study.prepared=true;study.configured=true
check('actual-study-start-stages-awareness',study.start() and stores.SurvivorAwareness_Standing.initialStudyAwareness~=nil)
generate()
check('actual-study-start-reaches-person-attachment',known('native-zeta').configured and not known('native-zeta').possible
    and known('native-alpha').possible)
__result='PASS initial awareness admission '..checks
