import com.sao.engine.SAOEquipment;
import com.sao.engine.SAONeeds;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.WeaponType;
import zombie.iso.IsoCell;
import zombie.iso.IsoObject;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Actual installed weapon definitions and native query/equip consumers.
 * The cell/body are isolated method fixtures; no world update or attack runs.
 */
public final class WeaponEligibilityProbe {
    private static int checks;
    private static int nextId = 71000;

    private static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name = item.getName(); moduleName = "Base"; fullType = "Base." + name;
            registryId = id; isLoaded = true; scriptItem = item; entityScript = item;
            modId = "pz-vanilla";
        }
    }

    private static final class Dictionary extends DictionaryData {
        void register(Item item, short id) {
            var info = new Info(item, id);
            itemIdToInfoMap.put(id, info);
            itemTypeToInfoMap.put(info.getFullType(), info);
        }
    }

    private static HandWeapon load(Path game, ScriptModule module,
            Dictionary dictionary, String name, short id) throws Exception {
        return load(game, module, dictionary, name, name, id);
    }

    private static HandWeapon load(Path game, ScriptModule module,
            Dictionary dictionary, String sourceName, String name, short id) throws Exception {
        String text = ScriptParser.stripComments(Files.readString(game.resolve(
            "media/scripts/generated/items/weapon.txt")));
        var match = Pattern.compile("\\bitem\\s+" + Pattern.quote(sourceName)
            + "\\s*\\{").matcher(text);
        if (!match.find()) throw new AssertionError("Installed item missing: " + name);
        int end = match.end(), depth = 1;
        while (depth > 0 && end < text.length()) {
            char c = text.charAt(end++);
            if (c == '{') depth++; else if (c == '}') depth--;
        }
        if (depth != 0) throw new AssertionError("Unclosed installed item: " + name);
        var definition = new Item();
        definition.setModule(module); definition.setName(name);
        String block = text.substring(match.start(), end).replaceFirst(
            "\\bitem\\s+" + Pattern.quote(sourceName), "item " + name);
        definition.Load(name, block);
        definition.setRegistry_id(id);
        module.items.getScriptMap().put(name, definition);
        dictionary.register(definition, id);
        return item(name);
    }

    private static HandWeapon item(String name) {
        InventoryItem value = InventoryItemFactory.CreateItem("Base." + name);
        if (!(value instanceof HandWeapon weapon)) {
            throw new AssertionError("Native item factory did not create weapon: " + name);
        }
        weapon.setID(nextId++);
        return weapon;
    }

    private static void check(String name, boolean condition) {
        System.out.println("CHECK " + name + "=" + condition);
        if (!condition) throw new AssertionError(name);
        checks++;
    }

    private static boolean refused(HandWeapon weapon) {
        return SAOEquipment.meleeScore(weapon) == Float.NEGATIVE_INFINITY;
    }

    public static void main(String[] args) throws Exception {
        // Existing native cell/container fixture. It uses actual IsoPlayer,
        // IsoGridSquare and ItemContainer receivers, not Java/Lua stand-ins.
        var boot = ResourceApproachProbe.class.getDeclaredMethod("boot");
        boot.setAccessible(true);
        var cell = (IsoCell) boot.invoke(null);
        var create = ResourceApproachProbe.class.getDeclaredMethod("person", IsoCell.class);
        create.setAccessible(true);
        var person = (IsoPlayer) create.invoke(null, cell);
        var shelf = ResourceApproachProbe.class.getDeclaredMethod("holder",
            IsoCell.class, int.class, int.class, int.class);
        shelf.setAccessible(true);
        ItemContainer container = ((IsoObject) shelf.invoke(null, cell, 12, 20, 0)).getContainer();
        var inspect = ResourceApproachProbe.class.getDeclaredMethod("inspect", IsoPlayer.class, IsoObject.class);
        inspect.setAccessible(true);

        var dictionary = new Dictionary();
        var data = WorldDictionary.class.getDeclaredField("data");
        data.setAccessible(true); data.set(null, dictionary);
        var module = new ScriptModule(); module.name = "Base";
        ScriptManager.instance.moduleMap.put("Base", module);
        Path game = Path.of(args[0]);
        HandWeapon firecracker = load(game, module, dictionary, "Firecracker", (short) 1801);
        HandWeapon barbell = load(game, module, dictionary, "BarBell", (short) 1802);
        HandWeapon wrench = load(game, module, dictionary, "Wrench", (short) 1803);

        check("installed_firecracker_native_throw_contract", !firecracker.isRanged()
            && WeaponType.getWeaponType(firecracker) == WeaponType.THROWING
            && firecracker.getPhysicsObject() != null && firecracker.getMaxDamage() == 0.0f);
        check("firecracker_not_melee", refused(firecracker));
        check("native_barbell_remains_melee", WeaponType.getWeaponType(barbell) == WeaponType.HEAVY
            && barbell.isTwoHandWeapon() && SAOEquipment.meleeScore(barbell) > 0);
        check("native_wrench_remains_melee", SAOEquipment.meleeScore(wrench) > 0);
        float ordinaryScore = (wrench.getMinDamage() + wrench.getMaxDamage()) * 5.0f
            + (wrench.getCondition() / (float) wrench.getConditionMax()) * 5.0f
            + wrench.getMaxRange() + wrench.getBaseSpeed() + wrench.getCriticalChance() * .02f;
        check("ordinary_scoring_unchanged", SAOEquipment.meleeScore(wrench) == ordinaryScore);

        // Independent native properties model unnamed/modded candidates.
        // Each has only the tested exclusion; removing another guard cannot
        // mask a bad result. No item-name filter can satisfy these controls.
        HandWeapon thrown = load(game, module, dictionary, "Wrench", "ControlThrown", (short) 1804);
        thrown.getScriptItem().setSwingAnim("Throw");
        check("throw_animation_not_melee", refused(thrown));
        HandWeapon projectile = item("Wrench"); projectile.setPhysicsObject("Base.Firecracker");
        check("physics_projectile_not_melee", refused(projectile));
        HandWeapon harmless = item("Wrench"); harmless.setMinDamage(0); harmless.setMaxDamage(0);
        check("zero_damage_not_melee", refused(harmless));
        HandWeapon ranged = item("Wrench"); ranged.setRanged(true);
        check("ranged_not_melee", refused(ranged));
        HandWeapon broken = item("Wrench"); broken.setCondition(0);
        check("broken_not_melee", refused(broken));
        check("missing_item_not_melee", SAOEquipment.meleeScore(null) == Float.NEGATIVE_INFINITY);

        for (HandWeapon bad : new HandWeapon[] {firecracker, thrown, projectile, harmless, ranged, broken}) {
            container.AddItem(bad);
        }
        inspect.invoke(null, person, container.getParent());
        check("no_invalid_source_upgrade", SAONeeds.findWeaponUpgradeNear(person, 5).isEmpty()
            && SAONeeds.weaponSourceItem(person) == null);
        container.AddItem(wrench);
        inspect.invoke(null, person, container.getParent());
        check("source_skips_invalid_candidates", SAONeeds.findWeaponUpgradeNear(person, 5).startsWith("12:20:0:")
            && SAONeeds.weaponSourceItem(person) == wrench);
        container.Remove(wrench);
        container.AddItem(barbell);
        inspect.invoke(null, person, container.getParent());
        check("source_keeps_native_barbell", SAONeeds.findWeaponUpgradeNear(person, 5).startsWith("12:20:0:")
            && SAONeeds.weaponSourceItem(person) == barbell);
        check("selection_does_not_transfer", container.contains(barbell)
            && !person.getInventory().contains(barbell));

        for (HandWeapon bad : new HandWeapon[] {firecracker, thrown, projectile, harmless, ranged, broken}) {
            container.Remove(bad); person.getInventory().AddItem(bad);
        }
        check("equip_refuses_invalid_candidates", "NO_MELEE_WEAPON".equals(SAOEquipment.equipBestMelee(person))
            && person.getPrimaryHandItem() == null);
        person.getInventory().AddItem(wrench);
        check("equip_keeps_native_wrench", SAOEquipment.equipBestMelee(person).startsWith("EQUIPPED Base.Wrench")
            && person.getPrimaryHandItem() == wrench && person.getSecondaryHandItem() == null);
        container.Remove(barbell); person.getInventory().AddItem(barbell);
        check("equip_keeps_native_barbell", SAOEquipment.equipBestMelee(person).startsWith("EQUIPPED Base.BarBell")
            && person.getPrimaryHandItem() == barbell && person.getSecondaryHandItem() == barbell);
        check("invalid_items_not_destroyed", person.getInventory().contains(firecracker)
            && person.getInventory().contains(projectile));
        System.out.println("PASS installed melee eligibility checks=" + checks);
    }
}
