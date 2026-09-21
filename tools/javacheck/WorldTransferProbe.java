import com.sao.engine.SAOWorldSources;
import java.lang.reflect.Method;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.InventoryContainer;

/** Runs the production holder proof against installed native inventory objects. */
public final class WorldTransferProbe {
    private static Method proof;
    private static int checks;

    private static InventoryItem item(String type, int id) {
        InventoryItem item = new InventoryItem("C66", type, type, "");
        item.setID(id);
        return item;
    }

    private static void check(boolean condition, String detail) {
        if (!condition) throw new AssertionError(detail);
        checks++;
    }

    private static void expect(ItemContainer carried, ItemContainer destination,
            String expected, String detail) throws Exception {
        String actual = (String) proof.invoke(null, carried, destination, 761,
            "C66.Supplies");
        check(expected.equals(actual), detail + ": " + actual);
    }

    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        proof = SAOWorldSources.class.getDeclaredMethod("transferHolderState",
            ItemContainer.class, ItemContainer.class, int.class, String.class);
        proof.setAccessible(true);
        ItemContainer carried = new ItemContainer();
        ItemContainer destination = new ItemContainer();
        InventoryItem selected = item("Supplies", 761);
        carried.AddItem(selected);
        expect(carried, destination, "CARRIED", "unperformed action gained completion");
        check(carried.contains(selected) && destination.getItems().isEmpty(),
            "holder inspection changed an inventory");
        carried.DoRemoveItem(selected);
        destination.AddItem(selected);
        expect(carried, destination, "TRANSFERRED", "actual transfer was not observed");
        expect(carried, destination, "TRANSFERRED", "repeated delivery changed proof");
        check(destination.getItems().size() == 1 && carried.getItems().isEmpty(),
            "repeated proof duplicated goods");
        InventoryItem duplicate = item("Supplies", 761);
        carried.AddItem(duplicate);
        expect(carried, destination, "CONFLICT", "both holders accepted");
        carried.DoRemoveItem(duplicate);
        // Native AddItem itself refuses duplicate IDs. Deliberately corrupt
        // its exposed backing list to exercise the recovery refusal.
        destination.getItems().add(duplicate);
        duplicate.setContainer(destination);
        check(destination.getItems().size() == 2, "duplicate control did not land");
        expect(carried, destination, "CONFLICT", "duplicate destination identity accepted");
        destination.DoRemoveItem(duplicate);
        destination.DoRemoveItem(selected);
        expect(carried, destination, "CONFLICT", "missing item inferred as delivered");
        InventoryItem impostor = item("Other", 761);
        destination.AddItem(impostor);
        expect(carried, destination, "CONFLICT", "wrong type accepted at destination");
        destination.DoRemoveItem(impostor);
        carried.AddItem(impostor);
        expect(carried, destination, "CONFLICT", "wrong carried type accepted");
        carried.DoRemoveItem(impostor);
        InventoryContainer bag = new InventoryContainer("C66", "Bag", "Bag", "");
        bag.setID(762);
        carried.AddItem(bag);
        bag.getInventory().AddItem(selected);
        expect(carried, destination, "CARRIED", "nested carried holder lost");
        bag.getInventory().DoRemoveItem(selected);
        destination.AddItem(selected);
        expect(carried, destination, "TRANSFERRED", "nested-origin deposit lost");
        destination.DoRemoveItem(selected);
        carried.DoRemoveItem(bag);
        destination.AddItem(bag);
        bag.getInventory().AddItem(selected);
        expect(carried, destination, "CONFLICT", "different destination bag accepted");
        check("UNAVAILABLE".equals(SAOWorldSources.storeTransferState(null,
                "C:missing:0", "fp", 761, "C66.Supplies", 1, 1, 0)),
            "absent body invented transfer state");
        check(SAOWorldSources.transferOffer(null, selected, destination, "store").isEmpty(),
            "absent body offered a native transfer");
        System.out.println("PASS native transfer holders " + checks + " checks");
    }
}
