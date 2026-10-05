local models,cognition,organization=SAO.CognitiveModels,SAO.Cognition,SAO.Organization
local checks=0
local function check(name,ok)if not ok then error('OUTCOME:'..name)end;checks=checks+1 end
local function fixture()
    newFixture();SAO.CognitiveModels=models;SAO.Cognition=cognition;SAO.Organization=organization
    organization.processes={};organization.processOrder={};organization.processMeta={sequence=0};organization.workReceipts={}
    local data={};ModData={get=function(k)return data[k]end,getOrCreate=function(k)data[k]=data[k]or{};return data[k]end}
    SAO.Hash={unit=function()return .2 end};cognition.configure(1,12,3)
end
fixture()
local offer=SAO.Cooking.expectationOffer(F.rec.id,F.body,{privateFood=true})
check('private_means_read_is_not_action',offer and offer.sourceId=='oven-1' and offer.itemId==71
    and F.rec.cookingWork==nil and F.rec.cognition==nil and F.queueCalls==0)
check('expected_different_source_is_refused',not SAO.Cooking.begin(F.rec.id,F.body,{privateFood=true,expectedSourceId='other-oven'}))
check('expected_different_item_is_refused',not SAO.Cooking.begin(F.rec.id,F.body,{privateFood=true,acquiredItemId=72}))
heatSetup()
check('heat_admission_does_not_teach',F.rec.cognition==nil)
F.food.cooked=true;tickCooking()
check('cooked_flag_alone_does_not_teach',F.rec.cognition==nil)
fixture();heatSetup()
nativeCooked();tickCooking();settleTransfer();completeToggle();tickCooking()
local receipt=SAO.Cooking.outcome(F.rec.id,1)
check('exact_native_preparation_retained',receipt and receipt.detail=='native-food-cooked-and-retrieved'
    and receipt.nativeCredit==receipt.id and receipt.retrieved and receipt.heatObserved)
check('actual_preparation_callback_teaches',F.rec.cognition and #F.rec.cognition.experiences==1
    and F.rec.cognition.experiences[1].kind=='preparation' and F.rec.cognition.experiences[1].sourceId=='oven-1')
local n=#F.rec.cognition.experiences;cognition.preparationOutcome(F.rec.id,receipt)
check('preparation_replay_exact_once',#F.rec.cognition.experiences==n)
F.rec=__nativeRoundtrip(F.rec)
check('preparation_native_reload_retains_evidence',SAO.Cooking.outcome(F.rec.id,1).nativeCredit==receipt.id
    and F.rec.cognition.nativeExperienceCursors.preparation==1)
fixture();beginCooking();SAO.Cooking.interrupt(F.rec.id,F.body,'needs water')
check('interrupted_cooking_cannot_teach_success',F.rec.cognition==nil
    and SAO.Cooking.outcome(F.rec.id,1).status=='interrupted')
fixture();F.allowed=false
check('permission_refuses_even_expected_source',not SAO.Cooking.expectationOffer(F.rec.id,F.body,{privateFood=true})
    and not SAO.Cooking.begin(F.rec.id,F.body,{expectedSourceId='oven-1',acquiredItemId=71}))
fixture()
local process=organization.raiseMatter(F.rec.id,'cooperative-action',nil,{cooperative=true,procedure={
    {id='prepare-meal',verb='prepare',capability='prepare',completesOn='cooking:prepared'}
}}, {},{})
local commitment=process and organization.commitOriginator(process.id,F.rec.id,
    {capabilities={prepare=true},stepIds={'prepare-meal'}})
check('personal_assent_creates_owned_preparation',commitment and commitment.actorId==F.rec.id
    and commitment.acceptedAt==F.at and F.rec.fulfilledWorkOutcomes==nil)
local originalBegin=beginCooking
beginCooking=function()
    check('committed_preparation_enters_native_owner',SAO.Cooking.begin(F.rec.id,F.body,
        {commitmentId=commitment.id,processId=process.id,processRevision=1,stepId='prepare-meal'}))
    organization.startWork(commitment.id,'SAO','preparing')
    organization.noteWorkAdmission(commitment.id,'Cooking',F.rec.cookingWork.id,{stepId='prepare-meal'})
end
heatSetup();beginCooking=originalBegin
check('accepted_heat_admission_is_not_fulfillment',F.rec.fulfilledWorkOutcomes==nil)
nativeCooked();tickCooking();settleTransfer();completeToggle();tickCooking()
local completed=organization.fulfilledWorkOutcome(F.rec.id,1)
check('performed_accepted_preparation_teaches',completed and completed.workKind=='prepare'
    and completed.nativeReceiptId=='cooking/cook-a/1' and completed.commitmentId==commitment.id
    and F.rec.cognition and #F.rec.cognition.experiences==2
    and F.rec.cognition.experiences[1].kind=='commitment-outcome')
SAO.Cooking.onOutcome(F.rec.id,SAO.Cooking.outcome(F.rec.id,1))
check('accepted_preparation_replay_exact_once',#F.rec.fulfilledWorkOutcomes==1 and #F.rec.cognition.experiences==2)
__result='PASS cooking outcomes '..checks
