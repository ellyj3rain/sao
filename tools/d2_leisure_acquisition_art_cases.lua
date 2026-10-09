local A,P,W,Art=SAO.LeisureAcquisition,SAO.ProceduralPlanning,SAO.WorldSources,SAO.LeisureArt
local checks=0
local function check(name,v)assert(v,"D2_ACQUISITION_ART:"..name);checks=checks+1;print("CASE "..name)end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local body,station=fixture("artist");body.items={};body.getX=function()return 8 end;body.getY=function()return 8 end
SAO.Body.active=__bodies;SAO.Controller.agents.artist={rec=__records.artist};__hours=10
local brush=__nativeItems["Lifestyle.oldPaintBrush"];local palette=__nativeItems["Lifestyle.paintPalette"];palette:setCurrentUses(60)
local bid,pid=brush:getID(),palette:getID()
local function snapshot(revision,includeBrush,includePalette)
 local text="H|protocol=SAOWS1|status=OBSERVED|detail=|mode=test|cx=1|cy=1|revision="..revision.."|sources=1\n"
 -- Wire format matches the production native source snapshot codec.
 local quantity=(includeBrush and 1 or 0)+(includePalette and 1 or 0)
 text=text.."S|id=C:art:0|fp=art|rev="..revision.."|kind=container|x=8|y=8|z=0|building=42|explored=1|state=available|access=unknown|container=counter|q:leisure-material="..quantity.."\n"
 if includeBrush then text=text.."I|source=C:art:0|id="..bid.."|type=Lifestyle.oldPaintBrush|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material\n"end
 if includePalette then text=text.."I|source=C:art:0|id="..pid.."|type=Lifestyle.paintPalette|uses=60|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material\n"end
 return text.."E\n"
end
local place={id=42,cx=8,cy=8,z=0,minX=8,minY=8,maxX=16,maxY=16};__places={[42]=place}
local function observe(text)
 __observeText=text;assert(W.applySnapshot(assert(W.parse(text))))
 local q,r,_,facts=W.beliefSnapshot(place)
 __known.artist={[42]={cx=8,cy=8,z=0,minX=8,minY=8,maxX=16,maxY=16,sources=q,sourceRevision=r,sourceFacts=facts}}
end
__targetAnswer="READY:8:8:0:8:8:0";__bindAnswer="BOUND:8:8:0";__sourceContainer={};__permissionContainer={};__busy=false
observe(snapshot("r1",true,true))
local rows=A.offers("artist",body);local selected
for _,r in ipairs(rows)do if r.itemType==brush:getFullType()then selected=r end end
check("native_material_preview_personal_station",#rows==2 and selected and selected.requirement.owner=="SAO.LeisureArt")
__sourceItem=brush;assert(A.begin("artist",body,selected),"brush-begin");local first=W.pendingActionFor("artist")
local purpose=__records.artist.proceduralPlanning.purposes[first.purposeId]
assert(SAO.SourceUse.onMovementDone("artist",body,"arrived")=="using","brush-movement")
body.items[#body.items+1]=brush;__body:getInventory():AddItem(brush);__carriedItem=brush;__busy=false
__transfer="T|operation=acquire|source=C:art:0|id="..bid.."|type=Lifestyle.oldPaintBrush|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material"
__observeText=snapshot("r2",false,true)
local brushTick=SAO.SourceUse.tick("artist",body);assert(brushTick=="completed","brush-settle:"..tostring(brushTick));assert(P.consumeSourceResult(W.actionOutcome(first.id,"artist")),"brush-consume")
check("brush_receipt_actual_source_correlation",purpose.leisureAcquisition.resultId==first.id and purpose.cursor==2 and #Art.offers("artist",body)==0)
observe(__observeText);__sourceItem=palette;__carriedItem=nil
selected=assert(A.offers("artist",body)[1]);assert(A.begin("artist",body,selected));local failedReservation=W.pendingActionFor("artist")
assert(SAO.SourceUse.onMovementDone("artist",body,"arrived")=="using");SAO.SourceUse.interrupt("artist",body,"urgent-need")
local failed=W.actionOutcome(failedReservation.id,"artist");assert(P.consumeSourceResult(failed));local saved=copy(failed)
check("palette_failure_no_custody_or_outcome",failed.status~="completed" and #body.items==1 and not purpose.leisureAcquisition.resultId and Art.outcome("artist",1)==nil)
__busy=false;check("palette_failure_retry_delay",#A.offers("artist",body)==0)
__hours=11;selected=assert(A.offers("artist",body)[1]);assert(A.begin("artist",body,selected));local retry=W.pendingActionFor("artist")
check("palette_retry_same_original_purpose",retry.purposeId==first.purposeId and #__records.artist.proceduralPlanning.order==1
 and #purpose.leisureAcquisitions==1 and purpose.leisureAcquisitions[1].resultId==first.id)
assert(SAO.SourceUse.onMovementDone("artist",body,"arrived")=="using")
body.items[#body.items+1]=palette;__body:getInventory():AddItem(palette);__carriedItem=palette;__busy=false
__transfer="T|operation=acquire|source=C:art:0|id="..pid.."|type=Lifestyle.paintPalette|uses=60|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material"
__observeText=snapshot("r3",false,false)
assert(SAO.SourceUse.tick("artist",body)=="completed");assert(P.consumeSourceResult(W.actionOutcome(retry.id,"artist")))
check("palette_retry_exact_completed_source_receipt",purpose.leisureAcquisition.resultId==retry.id and purpose.cursor==3
 and purpose.steps[1].status=="completed" and purpose.steps[2].status=="completed")
local fresh=assert(Art.offers("artist",body)[1]);local acquired=assert(A.acquiredPurpose("artist",body,"SAO.LeisureArt",fresh))
local bound=P.planLeisure("artist",{activity=fresh.activity,activityKey=fresh.id,owner="SAO.LeisureArt",itemKey=fresh.itemKey,
 acquiredPurposeId=acquired.id,affordance=fresh.sourceId,atLocation=true,locationKey="private-canvas"})
check("art_use_same_original_purpose",bound==purpose and acquired.id==first.purposeId and Art.begin("artist",body,fresh,purpose.id))
local action=ISTimedActionQueue.queues[body];local before=palette:getCurrentUses()
native(action,.4);action:update()
check("art_partial_no_invented_outcome",Art.outcome("artist",1)==nil and purpose.status~="completed")
action.currentState="Brush";action:update();action.delta=1;action:update();action:perform();action:complete()
check("original_palette_native_consumption",palette:getCurrentUses()<before)
local result=Art.outcome("artist",1)
check("original_art_native_outcome_completes_original_chain",result and result.status=="completed" and result.purposeId==first.purposeId
 and station.data.stage==4 and purpose.status=="completed")
local retained=W.actionOutcome(failedReservation.id,"artist")
check("failed_receipt_remains_failed_after_actual_art",retained.status~="completed" and same(retained,saved))
print("PASS D2 acquisition Art "..checks)
