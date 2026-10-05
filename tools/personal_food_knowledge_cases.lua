local checks=0
local function check(name,value)
    if not value then error("PERSONAL_FOOD:"..name) end
    checks=checks+1
end
local K,P,N=SAO.ConceptKnowledge,SAO.Perception,SAO.Needs
local clock,person,body,view,queued,choiceCalls,changedAtDispatch
local function copy(value)
    if type(value)~="table" then return value end
    local out={} for k,v in pairs(value)do out[k]=copy(v) end return out
end
local function fresh(known)
    clock=12;queued=nil;choiceCalls=0;changedAtDispatch=false
    person={id="reader"};body={data={SAOPersonId="reader"},getModData=function(self)return self.data end,
        isDead=function()return false end,isExistInTheWorld=function()return true end}
    SAO.Identity.get=function(id)return id==person.id and person or nil end
    SAO.Body.get=function(id)return id==person.id and body or nil end
    SAO.Body.active={reader=body};SAO.Body.foreign={}
    SAO.Controller.agents={reader={rec=person}}
    SAO.History.countyHours=function()return clock end
    view={schema="sao.personal-food-knowledge/1",actorId="reader",status="available",omitted=0,
        foods={{itemId=81,itemType="Base.Berry",relief=.2,recognizedPoison=known==true,
            basis=known and "known-recipe:Herbalist" or "unrecognized"},
            {itemId=82,itemType="Base.Meal",relief=.1,recognizedPoison=false,basis="unrecognized"}}}
    SAOJavaBridge.personalFoodKnowledge=function()return copy(view)end
    SAOJavaBridge.personalFoodChoice=function(_,b,id,fullType,recognized,basis)
        choiceCalls=choiceCalls+1
        if changedAtDispatch then return nil end
        for _,row in ipairs(view.foods)do
            if row.itemId==id and row.itemType==fullType and row.recognizedPoison==recognized and row.basis==basis then
                return {id=id,type=fullType,getRequireInHandOrInventory=function()return nil end}
            end
        end
    end
    N.queueVerified=function(action)queued=action;return true end
end
fresh(false)
local unknown=K.infer("reader","carried-food:81","bodily-harm","carried-food")
check("unknown_remains_unresolved",unknown.status=="unresolved")
local selected,reasoning=K.chooseCarriedFood("reader",body)
check("unknown_uses_same_material_utility",selected.itemId==81 and reasoning.selected=="eat:81")
check("pure_query_no_knowledge_or_outcome",person.conceptKnowledge==nil and person.cognition==nil
    and person.proceduralPlanning==nil and queued==nil and choiceCalls==0)
check("unknown_actual_native_action",N.eatCarried("reader",body)==true and queued.item.id==81)
fresh(true)
local recognized=K.infer("reader","carried-food:81","bodily-harm","carried-food")
check("authentic_background_supplies_semantic_root",recognized.status=="expectation"
    and recognized.paths[1].roots[1].sourceId=="known-recipe:Herbalist"
    and recognized.paths[1].roots[1].sourceOwner=="IsoGameCharacter.isKnownPoison"
    and recognized.paths[1].roots[1].acquisitionTime=="unrecorded-native-acquisition")
selected,reasoning=K.chooseCarriedFood("reader",body)
check("same_utilities_private_knowledge_changes_choice",selected.itemId==82 and reasoning.selected=="eat:82")
check("both_shared_models_consume_private_risk",reasoning.models[1].selected=="eat:82"
    and reasoning.models[2].selected=="eat:82")
check("known_actual_native_action",N.eatCarried("reader",body)==true and queued.item.id==82
    and SAO.Controller.agents.reader.foodReasoning.selected=="eat:82")
local danger
for _,row in ipairs(reasoning.models[1].ranked)do if row.id=="eat:81" then danger=row.appraisal.danger end end
check("selected_comparison_retains_causal_root",danger.ordinal==1 and danger.basis.roots[1].sourceId=="known-recipe:Herbalist")
danger.basis.roots[1].sourceId="tampered"
check("detached_view_cannot_change_native_knowledge",K.infer("reader","carried-food:81","bodily-harm","carried-food").paths[1].roots[1].sourceId=="known-recipe:Herbalist")
view.foods[1].recognizedPoison=false;view.foods[1].basis="unrecognized"
check("current_contrary_recognition_reappraises_choice",N.eatCarried("reader",body)==true and queued.item.id==81)
fresh(true);person=__nativeRoundtrip(person)
SAO.Controller.agents.reader.rec=person
check("reload_uses_native_custody_not_copied_prediction",N.eatCarried("reader",body)==true and queued.item.id==82
    and person.conceptKnowledge==nil)
fresh(true);view.foods[1].relief=.4;view.foods[2].relief=.05
ModData={get=function()return{settings={enabled=true,opponentShare=1,opportunitiesPerHour=12,maxDepth=3}}end}
check("configured_shared_model_reaches_actual_choice",N.eatCarried("reader",body)==true and queued.item.id==81
    and SAO.Controller.agents.reader.foodReasoning.selectedModelId=="associative")
ModData=nil
fresh(true);person.dead=true
check("dead_person_refused",not N.eatCarried("reader",body) and queued==nil)
fresh(true);body.data.SAOPersonId="other"
check("foreign_body_identity_refused",not N.eatCarried("reader",body) and queued==nil)
fresh(true);person.bodyOwnerToken="replacement"
check("replaced_body_token_refused",not N.eatCarried("reader",body) and queued==nil)
fresh(true);view.actorId="other"
check("foreign_native_view_refused",not N.eatCarried("reader",body) and queued==nil)
fresh(true);view.foods[1].basis="forged-education-score"
check("forged_content_source_refused",not N.eatCarried("reader",body) and queued==nil)
fresh(false);person.age=70;person.occupation="doctor";person.originRegion="Knox";person.education=99;person.culture="expert"
check("labels_do_not_invent_semantics",N.eatCarried("reader",body)==true and queued.item.id==81)
fresh(false);person.conceptKnowledge={schema=1,sequence=1,order={"fake"},relations={fake={id="fake",actorId="reader",
    from="carried-food:81",relation="may-cause",into="bodily-harm",contextId="carried-food",affirmed=true,
    basis="native-personal-recognition",sourceId="known-recipe:Herbalist",acquiredAt=clock+1}},omitted=0}
check("forged_retained_native_root_refused",N.eatCarried("reader",body)==true and queued.item.id==81)
person.conceptKnowledge.relations.fake.basis="personal-association"
check("future_personal_claim_refused",N.eatCarried("reader",body)==true and queued.item.id==81)
fresh(true);view.foods[2]=nil
check("can_decline_only_recognized_harm",not N.eatCarried("reader",body) and queued==nil
    and SAO.Controller.agents.reader.foodReasoning.selected=="defer-food")
fresh(true);changedAtDispatch=true
check("changed_native_input_refuses_dispatch",not N.eatCarried("reader",body) and queued==nil and choiceCalls==1)
fresh(true);SAOJavaBridge.personalFoodKnowledge=nil
check("missing_reader_does_not_fallback_to_omniscience",not N.eatCarried("reader",body) and queued==nil)
fresh(false);view.omitted=3;selected,reasoning=K.chooseCarriedFood("reader",body)
check("bounded_omission_visible",reasoning.omittedFoods==3)
fresh(true)
view.foods={}
for i=1,15 do view.foods[i]={itemId=100+i,itemType="Base.Berry",relief=.2,recognizedPoison=true,basis="known-recipe:Herbalist"} end
view.foods[16]={itemId=200,itemType="Base.Meal",relief=.1,recognizedPoison=false,basis="unrecognized"}
check("late_lower_risk_candidate_reaches_actual_action",N.eatCarried("reader",body)==true and queued.item.id==200
    and SAO.Controller.agents.reader.foodReasoning.omittedAlternatives==1)
__result="PASS personal food Lua "..checks
