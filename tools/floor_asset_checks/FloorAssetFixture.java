import java.util.ArrayList;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.scripting.ScriptManager;

/** Fixture placement and callback scheduling, never a production observation/result. */
public final class FloorAssetFixture {
    public static void install(KahluaTable env, LuaManager.Exposer exposer, IsoCell cell) {
        for (Class<?> type : new Class<?>[]{IsoWorldInventoryObject.class,zombie.inventory.types.Literature.class,
                ScriptManager.class,zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.ItemBodyLocation.class,
                zombie.characters.CharacterActionAnims.class,java.util.HashMap.class,
                zombie.characters.WornItems.WornItems.class}) {
            exposer.setExposed(type);exposer.exposeLikeJava(type,env);
        }
        ArrayList<IsoWorldInventoryObject> placed=new ArrayList<>();
        env.rawset("getScriptManager",(JavaFunction)(frame,count)->frame.push(ScriptManager.instance));
        env.rawset("__cloneItem",(JavaFunction)(frame,count)->frame.push(zombie.inventory.InventoryItemFactory.CreateItem(((InventoryItem)frame.get(0)).getFullType())));
        env.rawset("__fluid",(JavaFunction)(frame,count)->{
            var item=(InventoryItem)frame.get(0);var fluid=item.getFluidContainer();fluid.Empty();
            fluid.addFluid(Boolean.TRUE.equals(frame.get(1))?zombie.entity.components.fluids.Fluid.TaintedWater:zombie.entity.components.fluids.Fluid.Water,1);
            return 0;
        });
        env.rawset("__clearGround",(JavaFunction)(frame,count)->{
            for(var object:placed){var square=object.getSquare();if(square!=null){square.getWorldObjects().remove(object);square.getObjects().remove(object);}
                if(object.getItem()!=null)object.getItem().setWorldItem(null);object.setSquare(null);}
            placed.clear();com.sao.engine.SAOWorldSources.resetRuntimeForWorld();return 0;
        });
        env.rawset("__place",(JavaFunction)(frame,count)->{
            var item=(InventoryItem)frame.get(0);int x=((Double)frame.get(1)).intValue(),y=((Double)frame.get(2)).intValue(),z=((Double)frame.get(3)).intValue();
            var square=cell.getGridSquare(x,y,z);
            if(square==null){var chunk=cell.getGridSquare(x,y,0).getChunk();square=new IsoGridSquare(cell,null,x,y,z);square.chunk=chunk;
                square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);chunk.setSquare(x%8,y%8,z,square);}
            if(item.getContainer()!=null)item.getContainer().Remove(item);item.setContainer(null);
            var object=new IsoWorldInventoryObject(cell);object.item=item;object.setSquare(square);item.setWorldItem(object);
            square.getWorldObjects().add(object);square.getObjects().add(object);placed.add(object);return frame.push(object);
        });
        env.rawset("__nativeAction",(JavaFunction)(frame,count)->{
            var action=(zombie.characters.CharacterTimedActions.LuaTimedActionNew)frame.get(0);
            String operation=(String)frame.get(1);
            if(operation.equals("progress")){action.setJobDelta(((Double)frame.get(2)).floatValue());action.update();}
            else if(operation.equals("perform"))action.perform();
            else if(operation.equals("complete"))action.complete();
            else if(operation.equals("stop"))action.stop();
            else throw new AssertionError(operation);
            return 0;
        });
    }
}
