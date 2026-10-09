print=function(s)__lastPrint=s;__proofPrint(s)end
local A=SAO.LeisureArt;local checks=0
local function check(name,v)if not v then error('D2_MATERIALS:'..name)end;checks=checks+1;print('CHECK '..name)end
getScriptManager=function()return __scriptManager end
ItemTag=__nativeItemTag
local function preview(itemType,activity)
 for _,r in ipairs(A.materialRequirementsForType(nil,itemType))do if not activity or r.activity==activity then return r end end
end
local function available(id,b,r)return A.materialRequirementAvailable(id,b,r)end
local function missing(id,style,level,name)
 local b,o=fixture(id,style,level)
 for i=#b.items,1,-1 do if b.items[i]:getType()==name then table.remove(b.items,i)end end
 return b,o
end
local expected={['Lifestyle.oldPaintBrush']=1,['Lifestyle.paintPalette']=1,['Base.Saw']=2,
 ['Base.Hammer']=3,['Base.CarpentryChisel']=1,['Base.MasonsChisel']=1,['Base.BlowTorch']=1,['Base.WeldingMask']=1}
local oldCarried,oldInfer=SAOJavaBridge.privateCarriedItems,SAO.ConceptKnowledge.infer
SAOJavaBridge.privateCarriedItems=function()error('pure preview read private inventory')end
SAO.ConceptKnowledge.infer=function()error('pure preview read private knowledge')end
for itemType,n in pairs(expected)do
 local rows=A.materialRequirementsForType(nil,itemType)
 check('art_native_definition_'..itemType,#rows==n)
 check('art_native_aggregate_'..itemType,#__requirements(nil,itemType)==n)
 check('art_world_category_'..itemType,__categories(__nativeItems[itemType]):find('leisure%-material')~=nil)
end
check('art_unknown_type_refused',#A.materialRequirementsForType(nil,'Missing.Unknown')==0)
check('art_nonmaterial_refused',#A.materialRequirementsForType(nil,'Lifestyle.paintPaletteEmpty')==0)
local rows=A.materialRequirementsForType({},'Base.Hammer');check('art_preview_body_ignored',#rows==3)
local first=rows[1];first.revision='changed';check('art_preview_detached',preview('Base.Hammer',first.activity).revision~='changed')
local nativePreview=A.materialRequirementsForType;local rawRows
A.materialRequirementsForType=function(body,itemType)
 check('native_category_preview_nil_body',body==nil)
 rawRows=nativePreview(nil,itemType);local good=copy(rawRows[1]);local bad=copy(good);bad.owner='SAO.Foreign';bad.requirementId='foreign-owner'
 local wrongType=copy(good);wrongType.itemType='Base.Battery';wrongType.requirementId='wrong-type'
 local badRevision=copy(good);badRevision.revision='forged';badRevision.requirementId='wrong-revision'
 local badRole=copy(good);badRole.role='leaked-private-station';badRole.requirementId='wrong-role'
 local incomplete=copy(good);incomplete.activity=nil;incomplete.requirementId='missing-activity'
 return {good,copy(good),bad,wrongType,badRevision,badRole,incomplete}
end
local canonical=__requirements(nil,'Lifestyle.oldPaintBrush')
check('native_aggregate_rejects_forged_owner_fields',#canonical==1 and canonical[1].owner=='SAO.LeisureArt')
rawRows[1].revision='mutated';check('native_aggregate_detached',canonical[1].revision~='mutated')
local entering=false;local inner
A.materialRequirementsForType=function(body,itemType)
 if not entering then entering=true;inner=__requirements(nil,itemType);entering=false end
 return nativePreview(nil,itemType)
end
check('native_aggregate_reentrancy_refused',#__requirements(nil,'Lifestyle.oldPaintBrush')==1 and inner==nil)
A.materialRequirementsForType=function()error('controlled owner unavailable')end
check('native_aggregate_owner_failure_closed',#__requirements(nil,'Lifestyle.oldPaintBrush')==0)
A.materialRequirementsForType=nativePreview
check('native_category_original_owner_restored',__categories(__nativeItems['Lifestyle.oldPaintBrush']):find('leisure%-material')~=nil)
SAOJavaBridge.privateCarriedItems,SAO.ConceptKnowledge.infer=oldCarried,oldInfer
local r=assert(preview('Lifestyle.paintPalette'))
local b,o=missing('canvas',nil,4,'paintPalette')
check('art_missing_palette_current_station',available('canvas',b,r))
check('art_foreign_body_refused',not available('foreign',b,r))
check('art_nil_body_refused',not available('canvas',nil,r))
local changed=copy(r);changed.revision=string.rep('0',64);check('art_forged_revision_refused',not available('canvas',b,changed))
changed=copy(r);changed.extra=true;check('art_extra_field_refused',not available('canvas',b,changed))
check('art_malformed_refused',not available('canvas',b,{}))
local observations=b.observations;b.observations={};check('art_no_private_station_refused',not available('canvas',b,r));b.observations=observations
b.observations[1].at=__tick-121;check('art_stale_station_refused',not available('canvas',b,r));b.observations[1].at=__tick
local resolver=SAO.Perception.resolveLeisureObject;SAO.Perception.resolveLeisureObject=function()return nil end
check('art_replaced_instance_refused',not available('canvas',b,r));SAO.Perception.resolveLeisureObject=resolver
local enter=SAO.Standing.mayEnterCurrent;SAO.Standing.mayEnterCurrent=function()return false end
check('art_permission_refused',not available('canvas',b,r));SAO.Standing.mayEnterCurrent=enter
o.data.SAOArtAuthorId='other';check('art_foreign_author_refused',not available('canvas',b,r));o.data.SAOArtAuthorId=nil
o.data.stage=4;check('art_completed_station_refused',not available('canvas',b,r));o.data.stage=nil
local ownedAvailable=SAO.SourceIntegration.available;SAO.SourceIntegration.available=function()return false end
check('art_owned_source_missing_refused',not available('canvas',b,r));SAO.SourceIntegration.available=ownedAvailable
SAO.ConceptKnowledge.infer=function()return nil end;check('art_unknown_concept_refused',not available('canvas',b,r));SAO.ConceptKnowledge.infer=oldInfer
local oldSprite=o.sprite;o.sprite=sprite('LS_Painting_50',{CustomName='Painting',GroupName='EaselCanvasLarge',Facing='S'})
b.observations[1].spriteName='LS_Painting_50';check('art_canvas_skill_refused',not available('canvas',b,r));b.level=5
check('art_canvas_skill_threshold',available('canvas',b,r));o.sprite=oldSprite;b.observations[1].spriteName=oldSprite:getName()
b.items[#b.items+1]=item('paintPalette',98);check('art_fulfilled_refused',not available('canvas',b,r))
for _,style in ipairs({'Hedge','Wood','Metal','Stone','Ice'})do
 local tool=style=='Wood'and'CarpentryChisel'or style=='Stone'and'MasonsChisel'or style=='Metal'and'BlowTorch'or'Saw'
 local req=assert(preview('Base.'..tool,'sculpt-'..style));local sb,so=missing('sculpt-'..style,style,10,tool)
 check('art_source_sculpture_missing_'..style,available('sculpt-'..style,sb,req))
 sb.level=0;check('art_source_sculpture_skill_'..style,not available('sculpt-'..style,sb,req))
end
-- The installed LSUtil executes real native palette consumption; body/station/queue receivers remain controlled.
local pb,po=fixture('spent-palette');local spent=__nativeItems['Lifestyle.paintPalette'];spent:setCurrentUses(0)
local fresh=__newItem('Lifestyle.paintPalette');fresh:setCurrentUses(60)
__body:getInventory():AddItem(spent);__body:getInventory():AddItem(fresh)
pb.items={item('oldPaintBrush',99),spent}
check('art_spent_palette_is_missing',available('spent-palette',pb,r)and #A.offers('spent-palette',pb)==0)
pb.items[#pb.items+1]=fresh
local offer=assert(A.offers('spent-palette',pb)[1]);check('art_spent_palette_does_not_obscure_fresh',offer.materials.palette.id==tostring(fresh:getID()))
check('art_acquired_palette_closes_need',not available('spent-palette',pb,r))
check('art_palette_source_begin',A.begin('spent-palette',pb,offer,'purpose:spent'))
local action=ISTimedActionQueue.queues[pb];local before=fresh:getCurrentUses()
native(action,.4);action:update();action.currentState='Brush';action:update();action.delta=1;action:update();action:perform();action:complete()
check('art_original_consumes_selected_native_palette',fresh:getCurrentUses()<before and spent:getCurrentUses()==0)
check('art_source_completed_after_acquisition',A.outcome('spent-palette',1).status=='completed'and po.data.stage==4)
check('art_material_preview_no_skill_credit',(__records.canvas.artSkillSequence or 0)==0)
SAO.LeisureGames={materialRequirementsForType=function(body,itemType)
 check('native_games_type_preview_nil_body',body==nil)
 if itemType~='Base.SilverCoin'then return {}end
 return {{owner='SAO.LeisureGames',family='games',activity='arcade-ArcadeStreetFighter',
  sourceId='ProjectArcade:ProjectArcade_PlayArcadeTimedAction:ArcadeStreetFighter',
  revision=string.rep('a',64),requirementId='arcade-currency:ArcadeStreetFighter',
  itemType=itemType,role='material'}}
end}
local gameRows=__requirements(nil,'Base.SilverCoin')
check('native_games_owner_registration',#gameRows==1 and gameRows[1].owner=='SAO.LeisureGames')
check('native_games_world_category',__categories(__nativeItems['Base.SilverCoin']):find('leisure%-material')~=nil)
print('PASS D2 materials art '..checks)
