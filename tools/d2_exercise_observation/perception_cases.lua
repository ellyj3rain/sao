local checks=0
local function check(name,value)assert(value,'CONCEPT_JOIN:'..name);checks=checks+1 end
local function view(rows,frontiers)
 __view={schema='sao.concept-observation/1',actorId='person',observations=rows or {},frontiers=frontiers or {}}
end
local object={key='world-item:11:19:0:0',kind='object',concept='placed-item',x=11.5,y=19.5,z=0,
 objectCollection='worldObjects',objectIndex=0,runtimeInstance='exact-world-item',itemKey='8301',itemType='NewMusic.BoomboxBlue',className='zombie.iso.objects.IsoWorldInventoryObject'}
view({object})
check('outdoor_object_admitted',P.observeConcepts('person',body,100))
local row=P.conceptObservation('person',object.key)
check('outdoor_no_invented_room',row and row.roomId==nil and row.buildingId==nil)
check('personal_identity_and_native_locator',row.actorId=='person' and row.source=='native-personal-visibility' and row.itemKey=='8301' and row.objectCollection=='worldObjects')
check('current_outdoor_context',#P.conceptContext('person',100).observations==1)
check('placed_audio_source_exported',(P.leisureAudioSources('person',body)[1] or {}).sourceKind=='placed')
row.itemKey='forged';check('detached_row_cannot_mutate_fact',P.conceptObservation('person',object.key).itemKey=='8301')
check('foreign_body_admission_refused',not P.observeConcepts('person',{},101))
__view.actorId='other';check('foreign_native_view_refused',not P.observeConcepts('person',body,101))
check('unavailable_reader_withholds_sources',#P.leisureAudioSources('person',body)==0)
view({object});P.observeConcepts('person',body,100)
check('stale_current_context_withheld',#P.conceptContext('person',221).observations==0)
check('future_current_context_withheld',#P.conceptContext('person',99).observations==0)
view({{key='room:bad',kind='room',concept='room',x=11.5,y=19.5,z=0}},{{key='doorway:bad',kind='doorway',x=11.5,y=19.5,z=0,entryX=12.5,entryY=19.5,entryZ=0}})
P.observeConcepts('person',body,102)
check('rooms_still_require_metadata',P.conceptObservation('person','room:bad')==nil)
check('frontiers_still_require_metadata',#P.conceptContext('person',102).frontiers==0)
view({{key='vehicle-radio:73:8302:v:p',kind='object',concept='audio-device',x=11.5,y=19.5,z=0,
 objectCollection='vehicle',runtimeInstance='p',vehicleRuntimeInstance='v',partRuntimeInstance='p',partId='Radio',vehicleId=73,vehicleSqlId=8302,itemKey='8301',itemType='NewMusic.BoomboxBlue'}})
P.beliefs={};P.observeConcepts('person',body,100)
row=P.leisureAudioSources('person',body)[1]
check('vehicle_audio_without_object_index',row and row.sourceKind=='vehicle' and row.objectIndex==nil and row.vehicleSqlId==8302)
check('plain_new_schema_persists',__nativeRoundtrip(P.beliefs).person.concepts.observations[row.key].partRuntimeInstance=='p')
P.beliefs={};view({object});P.observeConcepts('person',body,100)
__target={controlledNativeTarget=true};__resolved=0
SAOJavaBridge.resolveLeisureAudioSource=function()__resolved=__resolved+1;return __target end
SAOJavaBridge.canHearLeisureSource=function()return true end
local prior=P.conceptObservation('person',object.key)
check('canonical_audio_source_resolved',P.resolveLeisureAudioSource('person',body,object.key)==__target and __resolved==1)
object.itemKey='8302'
check('swapped_private_item_refused_before_native_dispatch',P.resolveLeisureAudioSource('person',body,object.key)==nil and __resolved==1)
check('old_descriptor_cannot_borrow_new_item_hearing',not P.canHearLeisureSource('person',body,prior,10))
object.itemKey='8301';P.observeConcepts('person',body,100);object.runtimeInstance='replacement'
check('replaced_private_native_instance_refused',P.resolveLeisureAudioSource('person',body,object.key)==nil)
object.runtimeInstance='exact-world-item';P.observeConcepts('person',body,100);view({});__tick=101
check('missing_current_audio_source_refused',P.resolveLeisureAudioSource('person',body,object.key)==nil)
check('foreign_audio_body_refused',P.resolveLeisureAudioSource('person',{},object.key)==nil)
__conceptJoinChecks=checks
