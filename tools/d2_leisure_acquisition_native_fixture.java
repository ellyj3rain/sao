import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOWorldSources;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.inventory.*;
import zombie.iso.*;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.iso.sprite.IsoSprite;

/** Native isolated objects; original source snapshot encoder and transfer owners. */
class AcquisitionFixture {
 static IsoObject holder;static ItemContainer container;static IsoWorldInventoryObject loose;static boolean ground;
 static SAOIsoPlayerShell body;
 static Object invoke(Class<?> owner,String name,Class<?>[] types,Object...args)throws Exception{
  var m=owner.getDeclaredMethod(name,types);m.setAccessible(true);return m.invoke(null,args);
 }
 static String snapshot()throws Exception{
  var square=body.getCurrentSquare();var cls=Class.forName("com.sao.engine.SAOWorldSources$Snapshot");
  var constructor=cls.getDeclaredConstructor(int.class,int.class);constructor.setAccessible(true);
  var snapshot=constructor.newInstance(Math.floorDiv(square.getX(),8),Math.floorDiv(square.getY(),8));
  Object source=null;
  if(ground){if(loose!=null&&loose.getSquare()!=null)source=invoke(SAOWorldSources.class,"groundSourceKnown",
   new Class<?>[]{IsoGridSquare.class,IsoWorldInventoryObject.class,String.class},square,loose,"acquisition-native");}
  else source=invoke(SAOWorldSources.class,"containerSourceKnown",new Class<?>[]{IsoGridSquare.class,IsoObject.class,ItemContainer.class,int.class,String.class},square,holder,container,0,"acquisition-native");
  if(source!=null){var add=cls.getDeclaredMethod("add",source.getClass());add.setAccessible(true);add.invoke(snapshot,source);}
  var finish=cls.getDeclaredMethod("finish");finish.setAccessible(true);finish.invoke(snapshot);
  var status=cls.getDeclaredField("status");status.setAccessible(true);status.set(snapshot,"OBSERVED");
  return (String)invoke(SAOWorldSources.class,"encode",new Class<?>[]{cls},snapshot);
 }
 static void install(KahluaTable env,SAOIsoPlayerShell actor)throws Exception{
  body=actor;var square=body.getCurrentSquare();holder=new IsoObject(body.getCell(),square,new IsoSprite());
  container=new ItemContainer("counter",square,holder);container.setCapacity(100);container.setExplored(true);
  holder.setContainer(container);holder.getModData().rawset("SAOWorldSourceId","acquisition-native");square.getObjects().add(holder);
  body.getInventory().setCapacity(100);env.rawset("__sourceContainer",container);
  env.rawset("__setMaterialSource",(JavaFunction)(frame,count)->{
   try{
    var item=(InventoryItem)frame.get(0);ground=Boolean.TRUE.equals(frame.get(1));
    if(loose!=null){square.getWorldObjects().remove(loose);square.getObjects().remove(loose);loose.setSquare(null);loose.getItem().setWorldItem(null);loose=null;}
    container.getItems().clear();body.getInventory().getItems().clear();item.setContainer(null);item.setWorldItem(null);
    if(ground){item.getModData().rawset("SAOWorldItemSourceId","acquisition-native");
     // The cell constructor avoids the absent headless GPU texture receiver.
     loose=new IsoWorldInventoryObject(body.getCell());loose.item=item;loose.setSquare(square);item.setWorldItem(loose);
     square.getWorldObjects().add(loose);square.getObjects().add(loose);}
    else container.AddItem(item);
    SAOWorldSources.resetRuntimeForWorld();return frame.push(snapshot());
   }catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__materialSnapshot",(JavaFunction)(f,n)->{try{return f.push(snapshot());}catch(Exception e){throw new IllegalStateException(e);}});
  env.rawset("__addAlternateMaterial",(JavaFunction)(f,n)->{try{container.AddItem((InventoryItem)f.get(0));return f.push(snapshot());}catch(Exception e){throw new IllegalStateException(e);}});
 }
}
