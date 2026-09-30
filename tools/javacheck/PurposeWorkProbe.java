import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOWorldSources;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoObject;
import zombie.iso.sprite.IsoSprite;
import zombie.scripting.ScriptManager;
import zombie.world.WorldDictionary;

/** Installed native objects in a controlled cell; no gameplay or save loading. */
public final class PurposeWorkProbe {
    private static void check(String name, boolean condition) {
        System.out.println("CHECK " + name + "=" + condition);
        if (!condition) throw new AssertionError(name);
    }
    public static void main(String[] args) throws Exception {
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        var cell = (IsoCell) boot.invoke(null);
        var create = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class); create.setAccessible(true);
        var body = (SAOIsoPlayerShell) create.invoke(null, cell); body.playerIndex = 99;
        cell.getObjectList().add(body); body.setSquare(body.getCurrentSquare());
        body.getCurrentSquare().getMovingObjects().add(body);
        body.getModData().rawset("SAOPersonId", "purpose-native");
        for (int i = 0; i < IsoPlayer.players.length; i++) IsoPlayer.players[i] = null;
        LuaManager.platform = new J2SEPlatform(); LuaManager.env = LuaManager.platform.newEnvironment();
        LuaManager.thread = new KahluaThread(LuaManager.platform, LuaManager.env);
        LuaManager.thread.debugOwnerThread = Thread.currentThread();
        zombie.ui.UIManager.defaultthread = LuaManager.thread;
        zombie.Lua.LuaEventManager.register(LuaManager.platform, LuaManager.env);
        var init = ResourceApproachProbe.class.getDeclaredMethod("initFluids"); init.setAccessible(true); init.invoke(null);
        var dictionaryClass = Class.forName("CognitionUseProbe$Dictionary");
        var constructor = dictionaryClass.getDeclaredConstructor(); constructor.setAccessible(true);
        var dictionary = constructor.newInstance();
        var data = WorldDictionary.class.getDeclaredField("data"); data.setAccessible(true); data.set(null, dictionary);
        var module = ScriptManager.instance.getModule("Base");
        var factory = CognitionUseProbe.class.getDeclaredMethod("item", Path.class,
            zombie.scripting.objects.ScriptModule.class, dictionaryClass, String.class, String.class, short.class);
        factory.setAccessible(true);
        var book = (InventoryItem) factory.invoke(null, Path.of(args[0]), module, dictionary, "literature.txt", "BookCooking1", (short) 2901);
        var hammer = (InventoryItem) factory.invoke(null, Path.of(args[0]), module, dictionary, "weapon.txt", "Hammer", (short) 2902);
        var plank = (InventoryItem) factory.invoke(null, Path.of(args[0]), module, dictionary, "weapon.txt", "Plank", (short) 2903);
        var square = body.getCurrentSquare();
        var object = new IsoObject(cell, square, new IsoSprite());
        var container = new ItemContainer("counter", square, object);
        object.setContainer(container); square.getObjects().add(object);
        container.setExplored(true); container.setCapacity(100);
        body.getInventory().setCapacity(100);
        var permits = SAOWorldSources.class.getDeclaredMethod("transferPermitted", IsoPlayer.class,
            InventoryItem.class, ItemContainer.class, boolean.class);
        permits.setAccessible(true);
        for (var item : new InventoryItem[] {book, hammer, plank}) {
            container.AddItem(item);
            check("native_acquire_" + item.getType(), (Boolean) permits.invoke(null, body, item, container, false));
            check("native_offer_" + item.getType(), !SAOWorldSources.transferOffer(body, item, container, "acquire").isEmpty());
            check("offer_does_not_move_" + item.getType(), item.getContainer() == container && !body.getInventory().contains(item));
        }
        var script = ScriptManager.instance.getItem("Base.BookCooking1");
        check("installed_book_metadata_matches_range", script.getNumberOfPages() > 0 && "Cooking".equals(script.getSkillTrained())
            && script.getLevelSkillTrained() == 1 && script.getNumLevelsTrained() == 2
            && script.getLevelSkillTrained() + script.getNumLevelsTrained() - 1
                == ((zombie.inventory.types.Literature) book).getMaxLevelTrained());
        container.setExplored(false);
        check("uninspected_holder_refused", !(Boolean) permits.invoke(null, body, book, container, false));
        container.setExplored(true);
        container.DoRemoveItem(book); body.getInventory().AddItem(book);
        check("native_book_store_allowed", (Boolean) permits.invoke(null, body, book, container, true));
        check("acquire_cannot_retake_carried_book", !(Boolean) permits.invoke(null, body, book, container, false));
        System.out.println("PURPOSE_WORK_NATIVE_OK");
    }
}
