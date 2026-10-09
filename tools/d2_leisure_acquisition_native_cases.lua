local A,W,P,G=SAO.LeisureAcquisition,SAO.WorldSources,SAO.ProceduralPlanning,SAO.LeisureGames
local checks=0
local function check(name,value)assert(value,"D2_NATIVE_ACQUISITION:"..name);checks=checks+1;print("CASE "..name)end
local originalBridge=SAOJavaBridge
SAOJavaBridge=setmetatable({observeWorldChunk=function()return __materialSnapshot()end},
 {__index=function(_,k)return function(_,...)return originalBridge[k](originalBridge,...)end end})
local sourceRuntime=SAO.SourceUse
SAO.Body={get=function(id)return __bodies[id]end,active={},foreign={}}
SAO.Standing={mayAttemptBelieved=function()return true end,mayTakeCurrent=function()return true end,
 provisioningContextAt=function()return "personal"end}
SAO.Places={at=function()end}
SAO.Perception.knownPlaces=function(id)return __known[id]or{}end
SAO.Perception.learnInspectedSource=function()return true end
SAO.Locomotion={order=function()return true end,cancel=function()end}
SAO.Controller.agents={}
ModData={get=function(k)return __stores[k]end,getOrCreate=function(k)__stores[k]=__stores[k]or{};return __stores[k]end}
SAO.Needs.busy=function()return __queue~=nil end
getPlayerData=function()return nil end;getPlayerLoot=function()return nil end
removeItemTransaction=function()end;sendRemoveItemFromContainer=function()end;sendAddItemToContainer=function()end
triggerEvent=function()end;ISInventoryPage={};ISInventoryPaneContextMenu={}
Events.OnTick={Add=function()end};ISInventoryTransferAction.soundDelay=0
for sequence,test in ipairs({{"CardDeck","draw-card",false},{"Dice_20","roll-dice",false},{"CardDeck","draw-card",true},{"Dice_20","roll-dice",true}})do
 local name,kind,ground=test[1],test[2],test[3];local label=name..tostring(ground)
 G.reset("material-proof");__clearInventory();__queue=nil;__stores={};__hours=10
 __records={person={id="person",bodyOwnerToken="material-proof",gamesSequence=sequence-1},other={id="other"}};__bodies={person=__body,other=__other};__known={}
 SAO.Body.active=__bodies
 __body:getModData().SAOPersonId="person";__body:getModData().SAOExternalToken="material-proof";__body:setAsleep(false);__body:setHealth(100)
 local item=__items[name];local snapshot=assert(W.parse(__setMaterialSource(item,ground)));assert(W.applySnapshot(snapshot))
 local sourceId=ground and "G:acquisition-native"or"C:acquisition-native:0";local fact=W.beliefFact(sourceId,ground and "visible-ground"or nil)
 local placeId="source:"..sourceId
 __known.person={[placeId]={sourceId=sourceId,cx=__body:getX(),cy=__body:getY(),z=math.floor(__body:getZ()),
  minX=math.floor(__body:getX()),minY=math.floor(__body:getY()),maxX=math.floor(__body:getX())+1,maxY=math.floor(__body:getY())+1,
  sources={["leisure-material"]=true},sourceRevision=sourceId.."@"..fact.revision,sourceFacts={[sourceId]=fact}}}
 SAO.Controller.agents.person={rec=__records.person}
 local rows=A.offers("person",__body);local selected
 for _,row in ipairs(rows)do if row.requirement.activity==kind then selected=row end end
 check("native_preview_and_source_"..label,selected and selected.option.parameters.itemId==item:getID()
  and selected.requirement.owner=="SAO.LeisureGames" and not __body:getInventory():contains(item))
 check("personally_unobserved_source_refused_"..label,#A.offers("other",__other)==0)
 check("native_unknown_use_refused_"..label,#A.requirements("person",__body,"Base.ChessWhite")==0)
 local token=__body:getModData().SAOExternalToken;__body:getModData().SAOExternalToken="foreign-generation"
 check("changed_body_generation_refused_"..label,not A.begin("person",__body,selected))
 __body:getModData().SAOExternalToken=token
 SAO.Standing.mayAttemptBelieved=function()return false end
 check("private_permission_refused_"..label,not A.begin("person",__body,selected) and not __records.person.worldSourceReservation)
 SAO.Standing.mayAttemptBelieved=function()return true end
 check("unacquired_item_has_no_native_game_"..label,#G.offers("person",__body)==0)
 check("selected_original_sourceuse_"..label,A.begin("person",__body,selected)==true)
 local reservation=W.pendingActionFor("person");local purpose=__records.person.proceduralPlanning.purposes[reservation.purposeId]
 check("native_transfer_queued_"..label,sourceRuntime.onMovementDone("person",__body,"arrived")=="using" and __queue~=nil)
 local transfer=__queue
 __nativeAction(transfer.action,"start");__nativeAction(transfer.action,"progress",.4)
 check("native_partial_no_custody_"..label,not __body:getInventory():contains(item) and purpose.cursor==1)
 __nativeAction(transfer.action,"progress",1);__nativeAction(transfer.action,"perform");__queue=nil
 check("original_native_transfer_custody_"..label,__body:getInventory():contains(item) and item:getContainer()==__body:getInventory())
 check("native_source_receipt_"..label,sourceRuntime.tick("person",__body)=="completed")
 local receipt=W.actionOutcome(reservation.id,"person")
 check("native_result_advances_acquisition_only_"..label,P.consumeSourceResult(receipt) and purpose.cursor==2
  and receipt.measurement=="native-item-transfer" and not purpose.hobby)
 local events=#purpose.events
 check("native_receipt_exact_once_"..label,P.consumeSourceResult(receipt) and purpose.cursor==2 and #purpose.events==events)
 local fresh
 for _,offer in ipairs(G.offers("person",__body))do if offer.activity==kind and offer.itemId==item:getID()then fresh=offer end end
 check("actual_original_hobby_requery_"..label,fresh and A.acquiredPurpose("person",__body,"SAO.LeisureGames",fresh).id==purpose.id)
 local bound=P.planLeisure("person",{activity=fresh.activity,activityKey=fresh.id,owner="SAO.LeisureGames",itemKey=fresh.itemKey,
  acquiredPurposeId=purpose.id,affordance=fresh.sourceId,atLocation=true,locationKey="native-current-square"})
 check("same_purpose_native_hobby_admission_"..label,bound==purpose and G.begin("person",__body,fresh,purpose.id))
 local action=__queue;__nativeAction(action.action,"start");__nativeAction(action.action,"progress",.4)
 check("original_hobby_partial_no_result_"..label,G.outcome("person",sequence)==nil)
 __nativeAction(action.action,"progress",1);__nativeAction(action.action,"perform");__nativeAction(action.action,"complete")
 local result=G.outcome("person",sequence)
 check("original_hobby_actual_result_"..label,result and result.status=="completed" and result.purposeId==purpose.id
  and purpose.status=="completed" and result.sourceResult and __body:getInventory():contains(item))
end
do
 G.reset("material-choice-proof");__clearInventory();__queue=nil;__stores={};__hours=10
 __records={person={id="person",bodyOwnerToken="material-proof"},other={id="other"}};__bodies={person=__body,other=__other};__known={}
 SAO.Body.active=__bodies
 __body:getModData().SAOPersonId="person";__body:getModData().SAOExternalToken="material-proof"
 __setMaterialSource(__items.CardDeck,false);local snapshot=W.parse(__addAlternateMaterial(__items.Dice_6));assert(W.applySnapshot(snapshot))
 local sourceId="C:acquisition-native:0";local fact=W.beliefFact(sourceId)
 __known.person={["source:"..sourceId]={sourceId=sourceId,cx=__body:getX(),cy=__body:getY(),z=math.floor(__body:getZ()),
  sources={["leisure-material"]=true},sourceRevision=sourceId.."@"..fact.revision,sourceFacts={[sourceId]=fact}}}
 local Ctl=SAO.Controller;local agent={rec=__records.person};Ctl.agents.person=agent
 assert(SAO.Cognition.configure(0,12,3))
 local candidates,receivers=Ctl.leisureOffers("person",agent,__body,10000)
 check("actual_main_chooser_keeps_unselected_native_material",#candidates==2 and __records.person.proceduralPlanning==nil)
 local views=SAO.Cognition.interpretPlans("person",candidates,{domain="ordinary-purpose",pressure=0})
 local chosen=views and receivers[views.selected]
 check("private_model_selects_material_receiver",chosen and chosen.kind=="acquire-hobby-material")
 check("only_selected_exact_source_admitted",Ctl.beginLeisureOffer("person",agent,__body,10000,{key=views.selected,payload=chosen})
  and W.pendingActionFor("person").itemId==chosen.offer.option.parameters.itemId and #__records.person.proceduralPlanning.order==1)
end
print("PASS D2 native acquisition "..checks)
