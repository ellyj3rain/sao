local C,W,P=SAO.Cognition,SAO.WorldSources,SAO.Perception
local n=0
local function check(name,v)assert(v,"PRODUCER:"..name);n=n+1 end
local function count(id)return records[id].cognition and #records[id].cognition.experiences or 0 end
C.configure(1,60,3)
local function select(id)
    local action,ep=C.choose(id,{actorId=id,worldHours=hours,hunger=.8,thirst=.8,fatigue=.1,eatAt=.3,drinkAt=.3,
        foodAllowed=false,waterAllowed=false,inspectionAllowed=true,knownFood=0,knownWater=0,knownPlaces=1,
        capabilities={cook=false,forage=false,treat=false}})
    assert(action=="inspect" and ep,"inspection opportunity")
    return records[id].cognition.episodes[#records[id].cognition.episodes]
end
local ep=select("a")
local context=W.inspectionCandidate("a",bodies.a,"standing",12)
check("offer_does_not_observe",context and count("a")==0 and ep.status=="proposed")
local ok,why=W.inspectContainer("a",bodies.a,context)
check("exact_empty_inspection",ok and count("a")==1 and inspectCalls==1)
local fact=records.a.cognition.experiences[1]
check("empty_is_known_not_failure",fact.kind=="inspection" and fact.foodPresent==false and fact.waterPresent==false
    and fact.perspective=="performed" and ep.status=="observed" and ep.outcome.success==true)
check("inspection_not_transfer",fact.kind~="acquire" and #W.completedResults("provisioning")==0)
check("no_private_contents_leak",count("b")==0 and P.beliefs.b==nil)
check("exact_inspection_not_repeated",not W.inspectContainer("a",bodies.a,context) and count("a")==1
    and W.inspectionCandidate("a",bodies.a,"standing",12)==nil)
local second=W.inspectionCandidate("b",bodies.b,"standing",12)
permitted=false
check("permission_refusal_not_evidence",second and not W.inspectContainer("b",bodies.b,second)
    and count("b")==0 and inspectCalls==1)
permitted=true
second=W.inspectionCandidate("b",bodies.b,"standing",12)
local saved=snapshotText;snapshotText=string.gsub(saved,"|x=11|","|x=12|")
check("stale_holder_not_evidence",not W.inspectContainer("b",bodies.b,second) and count("b")==0)
snapshotText=saved;second=W.inspectionCandidate("b",bodies.b,"standing",12)
check("second_actor_own_inspection",W.inspectContainer("b",bodies.b,second) and count("b")==1 and count("a")==1)
RESULT="PASS cognition inspection "..n
