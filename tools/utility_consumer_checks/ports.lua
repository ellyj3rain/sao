-- Isolated scene/time/Standing/route/animation/network endpoints; production personal owners run.
isClient=function()return false end;isServer=function()return false end
__utilityHours=100
SandboxVars={SurvivorAwareness={Desperation=.95}}
triggerEvent=raise
function getTimestampMs()return __nativeTimestamp()end
function getTimestamp()return math.floor(__nativeTimestamp()/1000)end
function getText(s)return s end
function getDebug()return false end
function getSpecificPlayer()return body end -- same native offslot actor lookup for original SP actions
function getPlayerData()return nil end
function sendServerCommand()end;function sendClientCommand()end
function sendAddItemToContainer()end;function sendRemoveItemFromContainer()end;function sendItemStats()end;function syncItemFields()end
function addXp(chr,perk,amount)chr:getXp():AddXP(perk,amount)end
function ZombRand(...)return __nativeRandom(...)end
function createItemTransaction()return 1 end;function removeItemTransaction()end
ISInventoryPage={dirtyUI=function()end};ItemPicker={updateOverlaySprite=function()end}
HaloTextHelper={addText=function()end,addBadText=function()end,addGoodText=function()end}
Perks=PerkFactory.Perks;SkillBook=SkillBook or{}
local existingSAO=SAO
SAO={Pharmacology={},Body={active={['utility-owner']=body},foreign={}},Log={line=function(...)print("UTILITY_LOG",...)end,tally=function()end},History={countyHours=function()return __utilityHours end,ticks=function()return math.floor(__utilityHours*9000)end,ticksFromHours=function(h)return h*9000 end},Standing={mayTakeCurrent=function()return __standing~=false end,mayAttemptBelieved=function()return __standing~=false end,mayEnterBelieved=function()return __standing~=false end,provisioningContextAt=function()return "personal"end},Lessons={desperationBump=function()return 0 end},Locomotion={jobs={},cancel=function(id)SAO.Locomotion.jobs[id]=nil end,order=function(id,b,x,y,z)__moveUtilityBody(x,y,z);SAO.Locomotion.jobs[id]={body=b,done=true,result="arrived",goal={x=x,y=y,z=z}};return true end}}

if existingSAO and existingSAO.HouseholdService then SAO.HouseholdService=existingSAO.HouseholdService end
-- Declared native loaded route endpoint port; original Controller consumes its verdict.
SAO.Locomotion.tick=function(id)return SAO.Locomotion.jobs[id]end
SAO.Locomotion.status=function(id)local job=SAO.Locomotion.jobs[id];return job and job.done and("done:"..job.result)or job and"walking"or"none"end

function sendSyncPlayerFields()end -- Original SP complete already owns recipe/read-book effect; network notification endpoint only.

function getPlayerHotbar()return nil end -- Offslot NPC has no player HUD hotbar; original native equip remains owner.
