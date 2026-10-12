-- Real source ledger/admission/reservation and installed native timed transfer.
-- Controlled ports: retained purpose verdict, Standing verdict, locomotion/queue
-- acceptance, SP/UI/sound clocks. Body, item, holder, inventory and transfer are native.
local function check(name,value) __check(name,value==true);assert(value,name) end
local body,item,container=__ingredientBody,__ingredientDonor,__ingredientContainer
local records=__nativeModData("SurvivorAwareness_Records").records
local rec=records["ingredient-person"]
ModData={get=function(key)return __nativeModData(key)end,getOrCreate=function(key)return __nativeModData(key)end}
SAO.Identity={get=function(id)return records[tostring(id)]end}
SAO.Body.get=function(id)return SAO.Body.active[tostring(id)]end
SAO.Standing={mayAttemptBelieved=function()return true end,mayTakeCurrent=function()return true end,mayEnterCurrent=function()return true end}
SAO.Perception.knownPlaces=function(id)local mind=SAO.Perception.beliefs[tostring(id)];return mind and mind.known or {}end
SAO.History={countyHours=function()return 100 end}
SAO.ProceduralPlanning.noteAdmission=function()return true end
SAO.Locomotion={order=function()return true end}
SAO.Places={at=function()return {id=1,cx=11,cy=20,z=0,minX=8,minY=16,maxX=16,maxY=24}end}
local snapshot=SAO.WorldSources.parse((string.gsub(__ingredientInspection,"^I|[^\n]+\n","",1)))
check("lua_native_snapshot_with_emptycat",snapshot~=nil and SAO.WorldSources.applySnapshot(snapshot)==true)
local source=SAO.WorldSources.sourceProjection(__ingredientSourceId)
local fact=SAO.WorldSources.beliefFact(__ingredientSourceId)
local place=SAO.Places.at()
place.sourceId=source.id
SAO.Perception.beliefs["ingredient-person"]={known={[1]={cx=11,cy=20,sourceFacts={[source.id]=fact},sourceRevision=source.id.."@"..source.revision}}}
local input=__nativeInputRecipe:getInputs():get(1)
local requirement={recipeId=__nativeInputRecipe:getScriptObjectFullType(),index=__nativeInputRecipe:getIndexForIO(input),
    declaration=input:getOriginalLine(),sourceRevision="native-request-1",demandId="demand-1",purposeId="purpose-1",stepId="acquire-1"}
local offered,why=SAO.WorldSources.recipeSlotOptions(place,"recipe-input","ingredient-person",body,requirement,"standing")
print("INGREDIENT_OFFER",why,source.id,source.fingerprint,source.revision,fact.kind,fact.state)
local observed=SAOJavaBridge:recipeInputObservation(body,source.id,source.fingerprint,source.revision,requirement.recipeId,requirement.index,requirement.declaration,requirement.demandId,requirement.purposeId,requirement.stepId)
print("INGREDIENT_NATIVE",type(observed),observed and observed.actorId,observed and #observed.items,SAO.Material.recipeObservedType(requirement,item:getFullType()))
check("lua_emptycat_exact_demand_offer",offered~=nil and #offered.options==1)
fact.state="spent"
local spent=SAO.WorldSources.recipeSlotOptions(place,"recipe-input","ingredient-person",body,requirement,"standing")
check("lua_signed_spent_source_has_exact_ingredient",spent~=nil and #spent.options==1)
fact.state="available"
local generic,genericWhy=SAO.WorldSources.actionOptions(place,"recipe-input","ingredient-person",body,1,"standing","acquire")
check("lua_relation_is_not_generic_category",generic==nil and genericWhy=="unsupported-category")
__demandCurrent=false
local stale=SAO.WorldSources.beginAction(place,"recipe-input","ingredient-person",body,1,"standing",offered.options[1],"acquire",requirement)
check("lua_reenumeration_rejects_changed_demand",stale==nil)
__demandCurrent=true
local reservation=SAO.WorldSources.beginAction(place,"recipe-input","ingredient-person",body,1,"standing",offered.options[1],"acquire",requirement)
check("lua_exact_role_reserved",reservation~=nil and reservation.recipeRequirement.demandId=="demand-1")
check("lua_native_current_transfer_admission",SAO.SourceUse.recipeTransferCurrent(reservation,item,body)==true)
reservation.recipeRequirement.declaration=reservation.recipeRequirement.declaration.." "
check("lua_changed_slot_declaration_refused",SAO.SourceUse.recipeTransferCurrent(reservation,item,body)==false)
reservation.recipeRequirement.declaration=requirement.declaration
__demandCurrent=false
check("lua_stale_demand_mutation_refused",SAO.SourceUse.recipeTransferCurrent(reservation,item,body)==false)
__demandCurrent=true
local old=reservation.status;reservation.status="released"
check("lua_retired_reservation_refused",SAO.SourceUse.recipeTransferCurrent(reservation,item,body)==false);reservation.status=old
local saved=__roundtrip(reservation)
check("lua_saved_exact_demand_binding",saved.recipeRequirement.demandId=="demand-1" and saved.recipeRequirement.index==requirement.index and saved.recipeRequirement.declaration==requirement.declaration)
-- Construct the production verified timed transfer class with real containers.
isClient=function()return false end;isServer=function()return true end;instanceof=__nativeInstanceOf
getTimestampMs=function()return 1 end;getCore=function()return {getGameMode=function()return "Sandbox" end}end
getPlayerData=function()return nil end;getCell=function()return body:getCell()end
ItemPicker={updateOverlaySprite=function()end};sendRemoveItemFromContainer=function()end
local action=SAO.Needs.worldSourceTransferAction(body,item,container,container)
action.saoSourceReservation=reservation.id;action.saoSourceActor="ingredient-person"
check("lua_actual_native_timed_action_valid",action:isValid()==true)
__demandCurrent=false
action:transferItem(item)
check("lua_actual_mutation_refuses_stale_demand",container:contains(item) and not body:getInventory():containsRecursive(item))
__demandCurrent=true
action:transferItem(item)
check("lua_actual_native_inventory_transfer",not container:contains(item) and body:getInventory():containsRecursive(item))
__demandCurrent=false
local before=body:getInventory():getItems():size();action:transferItem(item)
check("lua_replay_has_no_second_mutation",body:getInventory():getItems():size()==before)
