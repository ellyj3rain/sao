local C,W,SU,P=SAO.Cognition,SAO.WorldSources,SAO.SourceUse,SAO.Perception
local n=0
local function check(name,v)assert(v,"PRODUCER:"..name);n=n+1 end
local function count(id)return __records[id].cognition and #__records[id].cognition.experiences or 0 end
C.configure(0,60,3)
local action,episode=C.choose("a",{actorId="a",worldHours=48,hunger=.8,thirst=0,fatigue=.1,eatAt=.3,drinkAt=.3,
    foodAllowed=true,waterAllowed=false,inspectionAllowed=false,knownFood=1,knownWater=0,knownPlaces=1,
    capabilities={cook=true,forage=false,treat=false}})
check("food_choice",action=="food" and episode)
__offerText=__acquire_row.."\n"..__acquire_pre;__carriedText=__acquire_row;__observeText=__acquire_pre
local began,res=SU.beginTransfer("a",bodyA,"food","standing",__item,__container,"acquire")
check("source_admission_token",began and res and res.cognitionToken and res.cognitionToken.episodeId==episode)
check("queue_is_not_acquisition",count("a")==0 and not W.finishAction(res.id,"a"))
__carried=__item
check("actual_transfer_observation",SU.observeNativeTransfer("a",bodyA,res.id,__container))
check("witness_capability_at_event",res.transferObservation.cognitionCapabilities.b.forage==true
    and res.transferObservation.cognitionCapabilities.b.cook==false)
__witnessSkilled=false;__observeText=__acquire_post;__busy=false
local status=SU.tick("a",bodyA)
local receipt=ModData.get("SurvivorAwareness_WorldSources").results[res.id]
check("completed_transfer_one_actor_event",status=="completed" and receipt.status=="completed" and count("a")==1)
local own=__records.a.cognition.experiences[1]
check("actor_exact_result",own.kind=="acquire" and own.sourceId==res.sourceId and own.itemType==res.itemType
    and own.episodeId==episode and own.status=="completed" and own.perspective=="performed")
check("provisioning_stream_untouched",receipt.acknowledgements.provisioning==nil)
check("captured_witness_only",P.receiveTransferResult(receipt) and count("b")==1 and count("c")==0 and count("a")==1)
local seen=__records.b.cognition.experiences[1]
check("witness_own_frozen_capability",seen.actorId=="a" and seen.observerId=="b" and seen.capabilities.forage
    and not seen.capabilities.cook and seen.hungerDelta==nil and seen.foodPresent==nil and seen.episodeId==nil)
local revision=__records.b.cognition.models.ordinary.revision
check("reconciled_duplicate_no_relearning",P.receiveTransferResult(receipt) and count("a")==1 and count("b")==1
    and __records.b.cognition.models.ordinary.revision==revision)
local reflected=W.completedResults("provisioning")[1]
check("receipt_copy_preserves_capabilities",reflected and reflected.transferObservation.cognitionCapabilities.b.forage==true)
reflected.transferObservation.cognitionCapabilities.b.forage=false
check("receipt_capabilities_detached",res.transferObservation.cognitionCapabilities.b.forage==true)
local forged={reservationId="unproved",actorId="a",operation="acquire",category="food",status="completed",at=48,
    itemType="Base.Apple",sourceId=res.sourceId,transferObservation={nativeTransferProven=false,actorId="a",at=48,
    witnesses={"c"},x=8,y=8,z=0}}
check("unproved_witness_refused",not P.receiveTransferResult(forged) and count("c")==0)

-- A new exact admission refused by the real queue path is censored; no
-- native observed result or counterexample is created by the refusal.
__records.d={id="d"};__bodies.d=bodyD
__offerText=__acquire_row.."\n"..__acquire_pre;__observeText=__acquire_pre;__carried=nil;__rejectQueue=true
local admitted=SU.beginTransfer("d",bodyD,"food","standing",__item,__container,"acquire")
local refused=__records.d.cognition and __records.d.cognition.experiences[1]
check("refused_queue_is_censored",not admitted and refused and refused.status=="unavailable"
    and __records.d.cognition.models.ordinary.revision==0)
RESULT="PASS cognition transfer "..n
