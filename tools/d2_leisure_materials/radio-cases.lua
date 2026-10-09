local R=SAO.LeisureRadio;local checks=0
local function check(name,v)if not v then error('D2_MATERIALS:'..name)end;checks=checks+1;print('CHECK '..name)end
getScriptManager=function()return __scriptManager end
RecordedMedia=__nativeRecordedMedia
local function req(t,a)for _,r in ipairs(R.materialRequirementsForType(nil,t))do if not a or r.activity==a then return r end end end
__fresh()
local oldItems,oldInfer=SAOJavaBridge.privateCarriedItems,SAO.ConceptKnowledge.infer
SAOJavaBridge.privateCarriedItems=function()error('pure preview read private inventory')end
SAO.ConceptKnowledge.infer=function()error('pure preview read private knowledge')end
for t,n in pairs({['Base.Battery']=2,['Base.Disc_Retail']=1,['Base.VHS_Retail']=1,['Base.VHS_Home']=1})do
 check('radio_native_definition_'..t,#R.materialRequirementsForType(nil,t)==n)
 check('radio_native_aggregate_'..t,#__requirements(nil,t)==n)
 check('radio_world_category_'..t,__categories(__nativeItems[t]):find('leisure%-material')~=nil)
end
check('radio_unknown_type_refused',#R.materialRequirementsForType(nil,'Missing.Radio')==0)
check('radio_nonmedia_refused',#R.materialRequirementsForType(nil,'Base.RadioRed')==0)
check('radio_preview_body_ignored',#R.materialRequirementsForType({},'Base.Battery')==2)
SAOJavaBridge.privateCarriedItems,SAO.ConceptKnowledge.infer=oldItems,oldInfer
local battery=assert(req('Base.Battery','listen-native-radio'));local disc=assert(req('Base.Disc_Retail'));local vhs=assert(req('Base.VHS_Retail'))
local function available(r)return R.materialRequirementAvailable('person',__body,r)end
check('radio_charged_need_refused',not available(battery))
__power=0;check('radio_depleted_battery_need',available(battery))
check('radio_foreign_body_refused',not R.materialRequirementAvailable('other',__body,battery))
check('radio_nil_body_refused',not R.materialRequirementAvailable('person',nil,battery))
local row={}for k,v in pairs(battery)do row[k]=v end;row.revision=string.rep('0',64)
check('radio_forged_requirement_refused',not available(row));check('radio_malformed_refused',not available({}))
__items={};check('radio_no_private_device_refused',not available(battery));__items={__radio}
__familiar=false;check('radio_unknown_concept_refused',not available(battery));__familiar=true
__owned=false;check('radio_retired_body_refused',not available(battery));__owned=true
__volume=0;check('radio_muted_source_refused',not available(battery));__volume=.6
local charged={class='DrainableComboItem',getFullType=function()return'Base.Battery'end,getCurrentUsesFloat=function()return .6 end,
 getMediaType=function()return -1 end,getMediaData=function()return nil end}
__items={__radio,charged};check('radio_carried_spare_closes_need',not available(battery));__items={__radio}
__items={__radio,{class='DrainableComboItem',getFullType=function()return'Base.Battery'end,getCurrentUsesFloat=function()return 0 end,
 getMediaType=function()return -1 end,getMediaData=function()return nil end}};check('radio_empty_spare_still_unmet',available(battery));__items={__radio}
check('radio_compatible_media_need',available(disc));check('radio_incompatible_media_refused',not available(vhs))
__hasMedia=true;check('radio_loaded_media_closes_need',not available(disc));__hasMedia=false
__items={__radio,{getFullType=function()return'Base.Disc_Retail'end,getMediaType=function()return 0 end,getMediaData=function()return __mediaData end}}
check('radio_carried_compatible_media_closes_need',not available(disc));__items={__radio}
__items={__radio,{getFullType=function()return'Base.VHS_Retail'end,getMediaType=function()return 1 end,getMediaData=function()return __mediaData end}}
check('radio_incompatible_carried_media_still_unmet',available(disc));__items={__radio}
__items={};__objects={{key='object:radio'}};__object={getObjectName=function()return'Radio'end,getDeviceData=function()return __data end,
 getSpriteName=function()return'appliances_radio_01_0'end}
check('radio_observed_placed_device_need',available(battery));__visible=false
check('radio_hidden_replaced_placed_device_refused',not available(battery));__visible=true
__data.getIsBatteryPowered=function()return false end;check('radio_mains_device_battery_refused',not available(battery))
check('radio_material_preview_no_work_credit',R.work('person')==nil and __requests==0 and __consumed==0)
print('PASS D2 materials radio '..checks)
