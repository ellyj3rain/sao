-- Real Admissions and PersonalMemory; identity genesis, History, Neuro and
-- native spawn geometry are controlled. Serialization uses installed Kahlua.
local checks=0
local function check(name,value) checks=checks+1;assert(value,'MEMORY_ADMISSION:'..name) end
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local sha,save,start=string.rep('a',64),'controlled-memory-save','1993-01-01'
local sites={{id='home',x=128,y=128,z=0},{id='other',x=384,y=128,z=0}}
local function episode(id,subject,action,description)
 return {id=id,occurredOn='1989-02-03',acquiredOn='1989-02-03',participants={'loved-one'},
 subject=subject,action=action,description=description,valence=0.8,salience=0.9,
 sourceId='authored-life-history',sourceSha256=string.rep('c',64),provenance='authored-synthetic',
 relations={{from=subject,relation='supports',into='belonging',confidence=0.7}}}
end
local function authored()
 return {{siteId='home',actorOrdinal=1,startDate=start,birthYear=1960,episodes={}},
 {siteId='home',actorOrdinal=2,startDate=start,birthYear=1960,episodes={
 episode('shared-movie','cinema','watched','Watched a film with a loved one.'),
 episode('first-job','workplace','worked','Started a first job beside a patient coworker.')}}}
end
local people,stores,births,created,clarity,now,calendarYear,calendarMonth,calendarDay
local function setup()
 people,stores,births,created,clarity,now={},{},{},0,1,2
 calendarYear,calendarMonth,calendarDay=1993,1,1
 local ids={'native-zeta','native-alpha','native-outside'}
 SAO={PopulationAdmissions={},PersonalMemory={},Identity={},History={},Neuro={},Body={active={},foreign={}},
 Log={line=function()end,tally=function()end},Standing={}}
 ModData={get=function(k)return stores[k]end,getOrCreate=function(k)stores[k]=stores[k]or{};return stores[k]end}
 SAO.Identity.all=function()return people end;SAO.Identity.get=function(id)return people[id]end
 SAO.Identity.livingCount=function()local n=0;for _,p in pairs(people)do if not p.dead then n=n+1 end end;return n end
 SAO.Identity.create=function(_,_,x,y,z)created=created+1;local p={id=ids[created],x=x,y=y,z=z,nativeXP=9};people[p.id]=p;return p end
 SAO.History.ticks=function()return now*9000 end;SAO.History.countyHours=function()return now end
 -- Controlled single-month calendar, independently supplied by History.
 SAO.History.countyInstant=function(hours)
  assert(type(hours)=='number' and hours>=0 and calendarDay+math.floor(hours/24)<=31,'fixture calendar outside controlled month')
  local seconds=math.floor(hours*3600)
  return string.format('%04d-%02d-%02dT%02d:%02d:%02d',calendarYear,calendarMonth,calendarDay+math.floor(seconds/86400),
   math.floor(seconds/3600)%24,math.floor(seconds/60)%60,seconds%60)
 end
 SAO.History.generate=function(id,p)check('history-precedes-memory-'..id,p.personalMemory==nil);births[id]=1960;p.historyGenerated=true end
 SAO.History.birthYearOf=function(id)assert(births[id],'birth queried before History');return births[id]end
 SAO.Neuro.clarityOf=function()return clarity end
 SAO.Body.get=function()return nil end;SAO.Rand={int=function(n)if n==100 then return 50 end;return 0 end}
 SpawnRegionMgr={getSpawnRegions=function()return{{name='native-origin',points={unemployed={{posX=128,posY=128,posZ=0},{posX=384,posY=128,posZ=0}}}}}end}
 __loadOwners()
end
local function stage()check('cohort-staged',SAO.PopulationAdmissions.stageInitialPeople(sha,save,{home=2,other=1},sites,3))end
local function bind(rows,date)return SAO.PopulationAdmissions.stageInitialLifeHistory(sha,save,rows or authored(),date or start)end
local function generate()SAO.PopulationAdmissions.ensurePopulation({population=3,newcomers=3,refillDays=1},18000)end
local function known(id)return SAO.PersonalMemory.query(id)end
setup()
check('unstaged-world-refused',not bind());stage()
check('foreign-world-refused',not SAO.PopulationAdmissions.stageInitialLifeHistory(string.rep('b',64),save,authored(),start))
check('foreign-save-refused',not SAO.PopulationAdmissions.stageInitialLifeHistory(sha,'foreign-save',authored(),start))
local invalid={}
local function bad(name,mutate)local rows=authored();mutate(rows);invalid[#invalid+1]={name=name,rows=rows}end
bad('future-acquisition-refused',function(r)r[2].episodes[1].acquiredOn='1993-01-02'end)
bad('prebirth-episode-refused',function(r)r[2].episodes[1].occurredOn='1959-01-01'end)
bad('impossible-date-refused',function(r)r[2].episodes[1].occurredOn='1989-02-29'end)
bad('acquisition-before-occurrence-refused',function(r)r[2].episodes[1].acquiredOn='1988-01-01'end)
bad('foreign-owner-field-refused',function(r)r[2].episodes[1].ownerId='native-alpha'end)
bad('foreign-site-refused',function(r)r[2].siteId='foreign'end)
bad('wrong-ordinal-refused',function(r)r[2].actorOrdinal=3 end)
bad('duplicate-person-refused',function(r)r[2]=copy(r[1])end)
bad('duplicate-episode-refused',function(r)r[2].episodes[2]=copy(r[2].episodes[1])end)
bad('foreign-source-field-refused',function(r)r[2].episodes[1].futureOutcome='survived'end)
bad('malformed-source-refused',function(r)r[2].episodes[1].sourceSha256='bad'end)
bad('invalid-valence-refused',function(r)r[2].episodes[1].valence=math.huge end)
bad('sparse-list-refused',function(r)r[4]=copy(r[2])end)
for _,row in ipairs(invalid)do check(row.name,not bind(row.rows));check(row.name..'-before-persist',stores.SurvivorAwareness_Standing.initialStudyLifeHistory==nil and created==0)end
check('native-start-date-authority',not bind(authored(),'1993-02-01'))
local after=authored();for _,r in ipairs(after)do r.startDate='1994-01-01'end
check('post1993-start-refused',not bind(after,'1994-01-01'))
local rows=authored();check('memory-staged',bind(rows));rows[2].episodes[1].description='caller mutation'
check('staging-detached',stores.SurvivorAwareness_Standing.initialStudyLifeHistory.rows[2].episodes[1].description~='caller mutation')
check('staging-no-genesis',created==0);generate()
local empty,held,omitted=people['native-zeta'],people['native-alpha'],people['native-outside']
check('actual-native-ids',created==3 and empty.historyGenerated and held.historyGenerated and omitted.historyGenerated)
check('ordinal-ledger-binding',#empty.personalMemory.initial.episodes==0 and #held.personalMemory.initial.episodes==2)
check('actual-id-stamped',held.personalMemory.initial.episodes[1].ownerId==held.id and held.personalMemory.initial.personId==held.id)
check('authored-owner-stays-absent',stores.SurvivorAwareness_Standing.initialStudyLifeHistory.rows[2].episodes[1].ownerId==nil)
check('omitted-person-unconfigured',omitted.personalMemory==nil and known(omitted.id).status=='unconfigured')
check('omitted-admission-status-unconfigured',omitted.personalMemoryAdmission.status=='unconfigured')
check('explicit-empty-admission-status-attached',empty.personalMemoryAdmission.status=='attached')
check('broader-lifelong-recall',#known(held.id).episodes==2 and known(held.id).episodes[2].action=='worked')
check('no-native-grant',held.nativeXP==9 and held.education==nil and not SAO.Body.get(held.id))
local retained=copy(stores);local person=copy(held);local query=known(held.id);query.episodes[1].description='returned mutation'
check('query-detached-and-pure',equal(stores,retained) and equal(held,person) and known(held.id).episodes[1].description~='returned mutation')
check('forged-person-refused',not SAO.PersonalMemory.attachInitial(copy(held)))
births[held.id]=1961;check('history-mismatch-withheld',known(held.id).status=='unavailable' and held.personalMemory.initial.birthYear==1960);births[held.id]=1960
SAO.EducationRegistry={profile=function()return{birthYear=1961}end}
check('education-birth-mismatch-withheld',known(held.id).status=='unavailable');SAO.EducationRegistry=nil
clarity=0;check('zero-clarity-inaccessible',known(held.id).status=='inaccessible');clarity=1
local ledger=stores.SurvivorAwareness_Standing.initialStudyPeople.actualIds.home;ledger[2]=nil
check('missing-ordinal-ledger-withheld',known(held.id).status=='unavailable');ledger[2]=held.id
local saved=stores.SurvivorAwareness_Standing;stores.SurvivorAwareness_Standing=nil
check('missing-source-query-pure',known(held.id).status=='unavailable' and stores.SurvivorAwareness_Standing==nil);stores.SurvivorAwareness_Standing=saved
saved.initialStudyLifeHistory.rows[2].episodes[1].description='saved-source-forgery'
held.personalMemory.initial.episodes[1].description='saved-source-forgery'
check('altered-saved-source-withheld',known(held.id).status=='unavailable');saved.initialStudyLifeHistory.rows=authored()
held.personalMemory.initial.episodes[1].description=person.personalMemory.initial.episodes[1].description
local changed=authored();changed[2].episodes[1].valence=-1
check('changed-source-rebind-refused',not bind(changed) and equal(held,person))
local wire=__nativeRoundtrip({people=people,stores=stores});people,stores=wire.people,wire.stores
held=people['native-alpha'];local bytes=copy(held.personalMemory)
SAO.PopulationAdmissions={};SAO.PersonalMemory={};__loadOwners()
check('reload-awaits-original-custody',known(held.id).status=='unavailable');stage()
check('reload-original-source-restores',bind() and #known(held.id).episodes==2)
check('reload-person-bytes-retained',equal(bytes,held.personalMemory));local count=created;generate();check('reload-no-new-genesis',count==created)
SAO.PopulationAdmissions.rebindWorld();check('world-rebind-withholds-source',known(held.id).status=='unavailable')
stage();check('world-rebind-source-restored',bind() and equal(bytes,held.personalMemory))
stores.SurvivorAwareness_Standing.initialStudyLifeHistory.saveName='foreign-save'
check('saved-foreign-save-withheld',known(held.id).status=='unavailable')
setup();stage();generate();check('late-stage-refused',not bind() and stores.SurvivorAwareness_Standing.initialStudyLifeHistory==nil)
setup();stage();local mismatch=authored();mismatch[2].birthYear=1961;check('declared-history-staged',bind(mismatch));generate()
check('actual-history-mismatch-refuses-attachment',people['native-alpha'].personalMemory==nil and known('native-alpha').status=='unavailable' and births['native-alpha']==1960)
setup();stage();local early=authored();for _,r in ipairs(early)do r.startDate='1990-01-01'end
calendarYear=1990
check('earlier-start-date-supported',bind(early,'1990-01-01'));generate();check('earlier-start-episodes-retained',#known('native-alpha').episodes==2)
-- Execute the real StudyWorld producer with controlled native calendar/options.
setup()
local config={definitionSha256=sha,mapName='MemoryFixture',seed='fixture-seed',
 extent={minCellX=0,minCellY=0,cellsX=2,cellsY=2},sandbox={['SurvivorAwareness.Population']=3},
 observation={sites=sites},situation={initialPeopleBySite={home=2,other=1},initialLifeHistory=authored()}}
local grid={getMinX=function()return 0 end,getMinY=function()return 0 end,getMaxX=function()return 1 end,getMaxY=function()return 1 end}
getWorld=function()return{getMap=function()return config.mapName end,getMetaGrid=function()return grid end,getWorld=function()return save end}end
getSandboxOptions=function()return{getOptionByName=function(_,key)return{asConfigOption=function()return{getValueAsObject=function()return config.sandbox[key]end}end}end}end
GameTime={getInstance=function()return{getStartYear=function()return 1993 end,getStartMonth=function()return 0 end,getStartDay=function()return 0 end}end}
getGameTime=GameTime.getInstance
WorldGenParams={INSTANCE={getSeedString=function()return config.seed end}}
isClient=function()return false end;isServer=isClient;getTimestampMs=function()return 1000 end
Events=setmetatable({}, {__index=function(t,key)local row={Add=function()end};rawset(t,key,row);return row end})
stores.StudyWorld={definitionSha256=sha}
local study=__loadStudy(config);study.prepared=true;study.configured=true
check('actual-study-start-stages-memory',study.start() and stores.SurvivorAwareness_Standing.initialStudyLifeHistory~=nil)
generate();check('actual-study-start-attaches-memory',#known('native-alpha').episodes==2)
-- Study configuration runs at native start before population replay rebases
-- county hours. Dated knowledge remains withheld until its actual acquisition.
setup();stage();now=264;calendarMonth,calendarDay=7,9
local replayRows=authored()
for _,r in ipairs(replayRows)do r.startDate='1993-07-20'end
for _,e in ipairs(replayRows[2].episodes)do e.occurredOn='1993-07-18';e.acquiredOn='1993-07-18'end
check('pre-replay-source-staged',bind(replayRows,'1993-07-20'))
local configuration=copy(stores.SurvivorAwareness_Standing.initialStudyLifeHistory)
now=0;SAO.PopulationAdmissions.rebindWorld();stage()
check('replay-rebind-before-genesis',bind(replayRows,'1993-07-20'))
check('replay-rebind-config-stamp-unchanged',equal(configuration,stores.SurvivorAwareness_Standing.initialStudyLifeHistory))
generate();local replayPerson=people['native-alpha']
check('replay-rebase-attaches-memory',replayPerson.personalMemory~=nil and replayPerson.personalMemory.initial.admittedAtHours==0)
check('configuration-phase-stamp-retained',stores.SurvivorAwareness_Standing.initialStudyLifeHistory.stagedAtHours==264)
check('replay-keeps-actual-native-identity',replayPerson.personalMemory.initial.episodes[1].ownerId==replayPerson.id and births[replayPerson.id]==1960)
check('replay-withholds-future-acquisition',known(replayPerson.id).status=='not-yet-acquired' and #known(replayPerson.id).episodes==0)
local replayMemory=copy(replayPerson.personalMemory)
local reload=__nativeRoundtrip({people=people,stores=stores});people,stores=reload.people,reload.stores
replayPerson=people['native-alpha'];SAO.PopulationAdmissions={};SAO.PersonalMemory={};__loadOwners();stage()
check('replay-reload-before-staging-coordinate',bind(replayRows,'1993-07-20') and equal(replayMemory,replayPerson.personalMemory))
check('replay-reload-retains-config-phase-record',equal(configuration,stores.SurvivorAwareness_Standing.initialStudyLifeHistory))
check('replay-reload-still-withholds-future',known(replayPerson.id).status=='not-yet-acquired')
now=216
check('replay-calendar-acquisition-arrives',known(replayPerson.id).status=='available' and #known(replayPerson.id).episodes==2)
check('replay-original-episode-bytes-retained',equal(replayMemory,replayPerson.personalMemory))
__result='PASS personal memory admission '..checks
