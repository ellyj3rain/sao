import com.sao.bridge.SAOBridge;
import com.sao.engine.*;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;
import zombie.characters.skills.PerkFactory;
import zombie.inventory.types.Food;
import zombie.iso.IsoCell;
import zombie.scripting.objects.ItemTag;

/** Installed engine recognition and production projection; controlled native food. */
public final class PersonalFoodKnowledgeProbe {
    private static int checks;
    private static void check(String name, boolean value) {
        if (!value) throw new AssertionError("PERSONAL_FOOD:" + name);
        checks++; System.out.println("CHECK " + name);
    }
    private static Object fixture(String name, Class<?>[] types, Object... args) throws Exception {
        var method=MovementCrossingProbe.class.getDeclaredMethod(name,types);
        method.setAccessible(true); return method.invoke(null,args);
    }
    private static SAOIsoPlayerShell body(IsoCell cell,String id) throws Exception {
        var body=(SAOIsoPlayerShell)fixture("person",new Class<?>[]{IsoCell.class},cell);
        body.getModData().rawset("SAOPersonId",id);
        body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);
        cell.getObjectList().add(body);return body;
    }
    private static Food food(SAOIsoPlayerShell body,int id,float hunger,boolean herbal) {
        var food=new Food("Base","ControlledFood","ControlledFood","none");
        var script=new zombie.scripting.objects.Item();
        var module=new zombie.scripting.objects.ScriptModule();module.name="Base";script.setModule(module);
        script.setName("ControlledFood");script.setItemType(zombie.scripting.objects.ItemType.FOOD);
        food.setScriptItem(script);
        food.setID(id);food.setHungChange(-hunger);food.setAge(0);food.setPoisonPower(herbal?10:0);
        food.setHerbalistType(herbal?"Berry":null);food.setPoisonDetectionLevel(-1);
        body.getInventory().AddItem(food);return food;
    }
    private static KahluaTable row(SAOIsoPlayerShell body,int id) {
        var view=SAOConceptObservation.foodKnowledge(body);
        if(view==null)return null;
        var rows=(KahluaTable)view.rawget("foods");
        for(int i=1;i<=rows.len();i++) {
            var row=(KahluaTable)rows.rawget((double)i);
            if(Double.valueOf(id).equals(row.rawget("itemId")))return row;
        }
        return null;
    }
    private static String basis(SAOIsoPlayerShell body,int id) { return (String)row(body,id).rawget("basis"); }
    public static void main(String[] args) throws Exception {
        var cell=(IsoCell)fixture("boot",new Class<?>[0]);
        var actor=body(cell,"herbalist");var other=body(cell,"other");
        var berry=food(actor,81,.20f,true);var meal=food(actor,82,.10f,false);
        check("native_unknown_is_not_safe",!actor.isKnownPoison(berry)
            && basis(actor,81).equals("unrecognized") && row(actor,81).rawget("safe")==null);
        check("person_facing_filter_has_no_omniscient_poison",SAONeeds.bestCarriedFood(actor)==berry);
        check("unknown_spare_food_uses_personal_recognition",SAONeeds.spareFood(actor)==meal);
        check("material_classifier_unchanged",!SAONeeds.isEdibleMaterial(berry));
        actor.getKnownRecipes().add("Unknown.ForgedHerbalist");
        check("unresolved_recipe_has_no_meaning",basis(actor,81).equals("unrecognized"));
        other.getKnownRecipes().add("Herbalist");
        check("other_person_knowledge_not_used",basis(actor,81).equals("unrecognized"));
        check("canonical_native_recipe_learning",actor.learnRecipe("Herbalist",false));
        check("native_herbalist_meaning",actor.isKnownPoison(berry) && basis(actor,81).equals("known-recipe:Herbalist"));
        check("known_poison_native_choice_changes",SAONeeds.bestCarriedFood(actor)==meal);
        check("known_poison_not_counted_as_spare",SAONeeds.spareFood(actor)==null);
        check("scalar_recognition_contains_no_hidden_poison_quantity",row(actor,81).rawget("poisonPower")==null);
        int recipes=actor.getKnownRecipes().size();int items=actor.getInventory().getItems().size();
        SAOConceptObservation.foodKnowledge(actor);
        check("query_does_not_grant_knowledge_or_material",recipes==actor.getKnownRecipes().size()
            && items==actor.getInventory().getItems().size());
        check("native_choice_revalidates_exact_knowledge",SAOConceptObservation.foodChoice(actor,81,
            berry.getFullType(),false,"unrecognized")==null);
        check("native_choice_returns_exact_carried_item",SAOConceptObservation.foodChoice(actor,82,
            meal.getFullType(),false,"unrecognized")==meal);
        check("another_inventory_not_available",SAOConceptObservation.foodChoice(other,82,
            meal.getFullType(),false,"unrecognized")==null);
        check("wrong_exact_type_refused",SAOConceptObservation.foodChoice(actor,82,"Base.Other",false,"unrecognized")==null);
        berry.getTags().add(ItemTag.NO_DETECT);
        check("native_no_detect_preserved",basis(actor,81).equals("unrecognized"));berry.getTags().remove(ItemTag.NO_DETECT);
        actor.getKnownRecipes().clear();berry.getTags().add(ItemTag.SHOW_POISON);
        check("native_visible_warning_preserved",basis(actor,81).equals("visible-warning"));berry.getTags().remove(ItemTag.SHOW_POISON);
        berry.setHerbalistType(null);berry.setPoisonDetectionLevel(10);
        check("native_cooking_provenance_distinct",basis(actor,81).equals("native-perk:Cooking"));
        berry.setPoisonDetectionLevel(-1);berry.getModData().rawset("addedPoisonBy",actor.getFullName());
        check("native_own_addition_provenance_distinct",basis(actor,81).equals("own-poison-addition"));
        berry.getModData().rawset("addedPoisonBy",null);berry.setHerbalistType("Berry");actor.getKnownRecipes().add("Herbalist");
        // Exercise the canonical native snapshot's exact learning serializer,
        // without requiring unrelated full-world body reconstruction in this probe.
        var write=SAONativeSnapshot.class.getDeclaredMethod("writeLearning",IsoPlayer.class);write.setAccessible(true);
        var restore=SAONativeSnapshot.class.getDeclaredMethod("restoreLearning",IsoPlayer.class,byte[].class);restore.setAccessible(true);
        byte[] saved=(byte[])write.invoke(null,actor);actor.getKnownRecipes().clear();
        check("forgotten_knowledge_changes_current_recognition",basis(actor,81).equals("unrecognized"));
        restore.invoke(null,actor,saved);
        check("canonical_learning_reload_restores_recognition",basis(actor,81).equals("known-recipe:Herbalist"));
        berry.setPoisonPower(0);
        check("changed_exact_food_removes_old_objection",basis(actor,81).equals("unrecognized"));berry.setPoisonPower(10);
        actor.getModData().rawset("SAOExternalOwner","foreign");
        check("foreign_body_refused",SAOConceptObservation.foodKnowledge(actor)==null);actor.getModData().rawset("SAOExternalOwner",null);
        actor.setAsleep(true);check("sleeping_body_refused",SAOConceptObservation.foodKnowledge(actor)==null);actor.setAsleep(false);
        IsoPlayer.players[0]=actor;check("player_slot_refused",SAOConceptObservation.foodKnowledge(actor)==null);IsoPlayer.players[0]=null;
        check("bridge_rejects_unowned_type",SAOBridge.INSTANCE.personalFoodKnowledge(new Object())==null);
        check("bridge_joins_actual_reader",SAOBridge.INSTANCE.personalFoodKnowledge(actor)!=null);
        for(int i=0;i<63;i++)food(actor,1000+i,.05f,false);
        var bounded=SAOConceptObservation.foodKnowledge(actor);
        check("native_bound_retains_later_private_candidates",row(actor,1015)!=null
            && ((KahluaTable)bounded.rawget("foods")).len()==64
            && Double.valueOf(1).equals(bounded.rawget("omitted")));
        System.out.println("PASS personal food native "+checks);
    }
}
