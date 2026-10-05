-- Existing population admission proof adapted to the actual source registry.
SAO.EducationRegistry.clear()
_people={}

local checks=0
local function check(name,value) checks=checks+1;assert(value,'EDUCATION_ADMISSION:'..name) end
local stores={}
ModData={getOrCreate=function(k)stores[k]=stores[k] or {};return stores[k]end}
SAO.Log={line=function()end,tally=function()end}
SAO.Body={get=function()return nil end}
SAO.Identity.all=function()return _people end
SAO.Identity.livingCount=function()local n=0;for id,p in pairs(_people)do if not p.dead then n=n+1 end end;return n end
local births={['runner']=1960,['unexposed']=1960}
local ids={'runner','unexposed'}
local nextId=0
local generated={}
SAO.Identity.create=function(_,_,x,y,z)
 nextId=nextId+1;local rec={id=ids[nextId],x=x,y=y,z=z,nativeXP=9};_people[rec.id]=rec;return rec
end
SAO.History.ticks=function()return _tick end
SAO.History.countyHours=function()return _tick/9000 end
SAO.History.generate=function(id,rec)generated[id]=true;rec.historyGenerated=true end
SAO.History.birthYearOf=function(id)assert(generated[id],'native history queried before generation');return births[id]end
SAO.Rand={int=function(maximum)if maximum==100 then return 50 end;return 0 end}
SpawnRegionMgr={getSpawnRegions=function()return {{name='native-residence',points={unemployed={{posX=128,posY=128,posZ=0}}}}}end}

SAO.Identity.get=function(id)return _people[id]end
local A,R=SAO.PopulationAdmissions,SAO.EducationRegistry
local save='controlled-education-admission'
local sites={{id='home',x=128,y=128,z=0}}
check('no-unstaged-world-import',not A.stageEducationRegistry(_raw,_rawSha,_worldSha,save,_bankSha,_archiveSha))
check('initial-cohort-staged',A.stageInitialPeople(_worldSha,save,{home=2},sites,2))
check('foreign-definition-refused',not A.stageEducationRegistry(_raw,_rawSha,string.rep('d',64),save,_bankSha,_archiveSha))
check('foreign-save-refused',not A.stageEducationRegistry(_raw,_rawSha,_worldSha,'other-save',_bankSha,_archiveSha))
check('source-registry-staged',A.stageEducationRegistry(_raw,_rawSha,_worldSha,save,_bankSha,_archiveSha))
check('staging-created-no-people',nextId==0 and SAO.Identity.livingCount()==0)
A.ensurePopulation({population=2,newcomers=2,refillDays=1},_tick)
check('native-population-created',nextId==2 and SAO.Identity.livingCount()==2)
local leader,mate=_people['runner'],_people['unexposed']
check('leader-history-then-prior',leader.historyGenerated and leader.educationAdmission and leader.educationAdmission.status=='attached' and leader.education)
check('mate-history-then-prior',mate.historyGenerated and mate.educationAdmission and mate.educationAdmission.status=='attached' and mate.education)
check('source-profile-not-residence',R.profile(mate.id).birthRegionId=='unexposed-region' and mate.originRegion=='native-residence')
check('native-skills-unchanged',leader.nativeXP==9 and mate.nativeXP==9)
check('source-practice-not-manufactured',#SAO.Education.conditioning(leader.id,_tick).concepts==0 and #SAO.Education.backgroundRelations(leader.id)==2 and #SAO.Education.backgroundRelations(mate.id)==0)
check('post-genesis-staging-refused',not A.stageEducationRegistry(_raw,_rawSha,_worldSha,save,_bankSha,_archiveSha))
local absent={id='unknown-person',nativeXP=7}
check('missing-source-explicit',not A.attachEducationRecord(absent) and absent.educationAdmission.status=='unavailable' and absent.education==nil)
local lookup=R.currentBindings;R.currentBindings=function()error('controlled unavailable registry')end
local fault={id=leader.id}
check('registry-reader-failure-contained',not A.attachEducationRecord(fault) and fault.educationAdmission.reason=='education-reader-failed')
R.currentBindings=lookup
local retained=leader.education
births[leader.id]=1961
check('actual-native-birth-refused',not A.attachEducationRecord(leader) and leader.educationAdmission.reason=='education-registry-birth-mismatch')
check('native-birth-refusal-preserves-prior',leader.education==retained and births[leader.id]==1961)
check('native-birth-refusal-withholds-meaning',SAO.Education.backgroundRelations(leader.id)==nil
    and SAO.ConceptKnowledge.infer(leader.id,'stove','relief-from-hunger','house:A').status=='unresolved')
births[leader.id]=1960
local birthReader=SAO.History.birthYearOf
SAO.History.birthYearOf=function()error('controlled unavailable native history')end
check('unavailable-native-history-withholds-meaning',SAO.Education.backgroundRelations(leader.id)==nil and leader.education==retained)
SAO.History.birthYearOf=birthReader
check('corrected-native-history-restores-meaning',#SAO.Education.backgroundRelations(leader.id)==2 and leader.education==retained)
local world=stores['SurvivorAwareness_Standing']
A.rebindWorld()
check('world-rebind-clears-source-owner',R.currentBindings(leader.id)==nil and SAO.Education.conditioning(leader.id,_tick)==nil)
check('world-rebind-retains-source-prior',leader.education==retained)
check('initial-cohort-restored',A.stageInitialPeople(_worldSha,save,{home=2},sites,2))
check('saved-registry-self-authentication-refused',not A.bindEducationRegistry(string.rep('d',64),_worldSha,save,_bankSha,_archiveSha))
check('source-owned-rebind',A.bindEducationRegistry(_rawSha,_worldSha,save,_bankSha,_archiveSha))
check('both-records-restored-without-practice',leader.educationAdmission.status=='attached' and mate.educationAdmission.status=='attached' and leader.education.revision==1 and mate.education.revision==1)
_persistedWorld=__roundtrip(world);_persistedActor=__roundtrip(leader)
__registryChecks=checks
__result=__result.."; admission "..checks
