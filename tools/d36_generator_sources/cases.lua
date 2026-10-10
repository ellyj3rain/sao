local W=SAO.WorldSources
local count=0
local function check(name,value)assert(value,"D36_LUA:"..name);count=count+1;print("CHECK "..name)end
local function empty(value)for _ in pairs(value)do return false end;return true end
local phase=__far
local id="generator-person"
local function body(personId)return{getModData=function()return{SAOPersonId=personId}end,
 isExistInTheWorld=function()return true end,isDead=function()return false end,isAsleep=function()return false end}end
local a,b=body(id),body("other-person")
local records={[id]={id=id},["other-person"]={id="other-person"}}
SAO.Identity={get=function(key)return records[key]end}
SAO.Body={get=function(key)return key==id and a or key=="other-person" and b end,active={[id]=a,["other-person"]=b},foreign={}}
SAOJavaBridge={worldGeneratorCandidates=function()return phase end,worldGeneratorConsumer=function()return phase end}
local anchors=W.observeGenerators(id,a)
check("actual_partial_packet_admitted",#anchors==1)
local sourceId=anchors[1].sourceId
local partial=W.beliefFact(sourceId,nil,id)
check("partial_has_no_hidden_state",partial.kind=="generator" and partial.inspected==false and partial.condition==nil and partial.fuel==nil)
check("other_actor_has_no_fact",W.beliefFact(sourceId,nil,"other-person")==nil and W.beliefFact(sourceId)==nil)
check("wrong_actor_body_not_admitted",#W.observeGenerators(id,b)==0)
phase=__full;anchors=W.observeGenerators(id,a)
local inspected=W.beliefFact(sourceId,nil,id)
check("reached_state_retained",inspected.inspected==true and inspected.condition==100 and inspected.fuel==1 and inspected.connected==true and inspected.active==false and inspected.outside==true)
inspected.condition=0
check("private_fact_detached",W.beliefFact(sourceId,nil,id).condition==100)
phase=__far;W.observeGenerators(id,a)
check("farther_sight_retains_acquired_information",W.beliefFact(sourceId,nil,id).inspected==true)
__stores.SurvivorAwareness_WorldSources=__roundTrip(__stores.SurvivorAwareness_WorldSources)
check("native_save_retains_private_generator",W.beliefFact(sourceId,nil,id).fuel==1 and W.sourceProjection(sourceId,id).condition==100)
phase=__cold;local consumer=W.observeGeneratorConsumer(id,a,{})
check("reached_consumer_anchor",consumer and consumer.sourceId:sub(1,2)=="E:")
local cold=W.beliefFact(consumer.sourceId,nil,id)
check("consumer_power_separate_from_stock",cold.kind=="power-consumer" and cold.powered==false and empty(cold.quantities) and empty(cold.candidates))
phase=__hot;W.observeGeneratorConsumer(id,a,{})
check("fresh_private_consumer_power",W.beliefFact(consumer.sourceId,nil,id).powered==true and W.beliefFact(consumer.sourceId,nil,"other-person")==nil)
check("malformed_generator_boolean_refused",W.parse(__full:gsub("connected=1","connected=yes"))==nil)
check("uninspected_hidden_numbers_refused",W.parse(__far:gsub("inspected=0","inspected=0|fuel=10"))==nil)
check("generator_ground_namespace_refused",W.parse(__full:gsub("id=J:","id=G:"))==nil)
check("invalid_condition_refused",W.parse(__full:gsub("condition=100","condition=101"))==nil)
print("PASS D36 private sources "..count)
