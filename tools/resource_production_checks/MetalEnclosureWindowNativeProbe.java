import java.io.Reader;
import java.lang.reflect.*;
import java.nio.*;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.iso.*;
import zombie.iso.objects.*;
import zombie.inventory.*;
import zombie.scripting.*;
import zombie.scripting.objects.*;

/** Actual installed movable producer exposed through bounded Lua native receivers. */
public final class MetalEnclosureWindowNativeProbe {
    private static final Map<Integer,Object> objects=new HashMap<>();
    private static final IdentityHashMap<Object,Integer> ids=new IdentityHashMap<>();
    private static int next=1;
    private static ItemContainer hammerSource;
    private static com.sao.engine.SAORouteState chooser;
    private static Object call(Class<?> c,String name,Class<?>[] types,Object...args)throws Exception {var m=c.getDeclaredMethod(name,types);m.setAccessible(true);return m.invoke(null,args);}
    private static Object get(String name)throws Exception {var f=ShelterConstructionNativeProbe.class.getDeclaredField(name);f.setAccessible(true);return f.get(null);}
    private static void set(Class<?> c,String name,Object value)throws Exception {var f=c.getDeclaredField(name);f.setAccessible(true);f.set(null,value);}
    private static Object value(Object o){if(o instanceof KahluaTable t&&t.rawget("__handle") instanceof Number n)return objects.get(n.intValue());return o;}
    private static Object out(Object o){if(o==null||o instanceof String||o instanceof Boolean)return o;if(o instanceof Number n)return n.doubleValue();if(o instanceof Enum<?> e)return e.name();if(o instanceof KahluaTable)return o;int id=ids.computeIfAbsent(o,k->{int n=next++;objects.put(n,k);return n;});var t=zombie.Lua.LuaManager.platform.newTable();t.rawset("__nativeId",(double)id);return t;}
    private static Object convert(Object arg,Class<?> type){Object o=value(arg);if(o==null)return null;if(type.isInstance(o))return o;
        if(o instanceof KahluaTable t&&zombie.characters.IsoGameCharacter.class.isAssignableFrom(type))try{var body=(com.sao.engine.SAOIsoPlayerShell)get("sceneBody");var md=(KahluaTable)t.rawget("md");if(md!=null&&Objects.equals(md.rawget("SAOPersonId"),body.getModData().rawget("SAOPersonId")))return body;}catch(Exception e){throw new IllegalStateException(e);}
        if(o instanceof Number n){if(type==int.class||type==Integer.class)return n.intValue();if(type==float.class)return n.floatValue();if(type==double.class)return n.doubleValue();if(type==long.class)return n.longValue();}if(type==boolean.class&&o instanceof Boolean)return o;if(type.isEnum()&&o instanceof String s)return Enum.valueOf((Class)type,s);return o;}
    private static Object invoke(Object target,String name,KahluaTable args)throws Exception {
        var list=new ArrayList<Object>();for(int n=1;args.rawget((double)n)!=null;n++)list.add(args.rawget((double)n));
        for(var m:target.getClass().getMethods())if(m.getName().equals(name)&&m.getParameterCount()==list.size())try{var a=new Object[list.size()];for(int n=0;n<a.length;n++)a[n]=convert(list.get(n),m.getParameterTypes()[n]);return m.invoke(target,a);}catch(IllegalArgumentException ignored){}catch(InvocationTargetException e){throw new IllegalStateException(name,e.getCause());}
        throw new IllegalStateException(target.getClass()+"."+name+" args="+list);
    }
    private static Object op(String name,Object a,Object b,Object c)throws Exception {
        var body=(com.sao.engine.SAOIsoPlayerShell)get("sceneBody");
        switch(name){
        case "invoke":return invoke(value(a),(String)b,(KahluaTable)c);
        case "sprite":return zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)a);
        case "kind":{for(String prefix:List.of("zombie.iso.objects.","zombie.iso.","zombie.inventory.types.","zombie.inventory.","zombie.characters."))try{return Class.forName(prefix+b).isInstance(value(a));}catch(ClassNotFoundException ignored){}return false;}
        case "inventory":return body.getInventory();
        case "bodySquare":return body.getCurrentSquare();
        case "tagItems":return ScriptManager.instance.getItemsTag((ItemTag)ItemTag.class.getField((String)a).get(null));
        case "hammer":{var i=ScriptManager.instance.getModule("Base").getItem("Hammer").InstanceItem(null,false);i.setID(8888);body.getInventory().AddItem(i);return i;}
        case "withdrawHammer":{var item=body.getInventory().getFirstTypeRecurse("Base.Hammer");body.getInventory().Remove(item);hammerSource=new ItemContainer();hammerSource.setType("counter");hammerSource.AddItem(item);return item;}
        case "hammerSource":return hammerSource;
        case "chooserSetup":{var window=(IsoWindow)value(a);boolean open=Boolean.TRUE.equals(b);if(window.IsOpen()!=open)window.ToggleWindow(body);body.changeState(zombie.ai.states.IdleState.instance());body.getActionContext().clearActionContextEvents();body.clearVariable("StopAfterAnimLooped");
            body.getAnimationPlayer().setAngle(window.getNorth()?-(float)Math.PI/2:(float)Math.PI);body.setForwardDirection(window.getNorth()?0:-1,window.getNorth()?-1:0);
            chooser=new com.sao.engine.SAORouteState();chooser.setRoute(List.of(new float[]{window.getSquare().getX()-(window.getNorth()?0:1)+.5f,window.getSquare().getY()-(window.getNorth()?1:0)+.5f,0}));chooser.requested=true;return true;}
        case "chooserTick":return com.sao.engine.SAOMovement.tick(body,chooser);
        case "chooserAperture":{var f=com.sao.engine.SAORouteState.class.getDeclaredField("apertureCrossing");f.setAccessible(true);var edge=f.get(chooser);if(edge==null)return false;var aperture=edge.getClass().getDeclaredField("aperture");aperture.setAccessible(true);return aperture.get(edge)==value(a);}
        case "chooserWindowEvent":return body.getActionContext().hasEventOccurred("EventClimbWindow");
        case "chooserFenceEvent":return body.getActionContext().hasEventOccurred("EventClimbFence");
        case "nativeHoppable":{var window=(IsoWindow)value(a);var here=body.getCurrentSquare();var to=body.getCell().getGridSquare(window.getSquare().getX()-(window.getNorth()?0:1),window.getSquare().getY()-(window.getNorth()?1:0),0);return here.getHoppableTo(to);}
        case "windowBarricade":{var bar=IsoBarricade.AddBarricadeToObject((IsoWindow)value(a),false);if(bar==null)return false;bar.addPlank(body);return ((IsoWindow)value(a)).isBarricaded();}
        case "square":return body.getCell().getGridSquare(10,20,0);
        case "frame":return get("created");
        case "item":{String name2=((String)a).endsWith("_25")||((String)a).endsWith("_24")?"Mov_WindowWhite":"Mov_WindowWooden";var module=ScriptManager.instance.getModule("Base");var item=module.getItem(name2).InstanceItem(null,false);item.setID(next+6000);return item;}
        case "windowNew":return new IsoWindow(body.getCell(),(IsoGridSquare)value(a),(zombie.iso.sprite.IsoSprite)value(b),Boolean.TRUE.equals(c));
        case "glazed":return com.sao.engine.SAOShelterConstruction.glazed(body,(IsoThumpable)value(a),(IsoWindow)value(b),(String)((KahluaTable)c).rawget(1.0),Boolean.TRUE.equals(((KahluaTable)c).rawget(2.0)));
        case "windowFrame":return com.sao.engine.SAOShelterConstruction.windowFrame(body,(String)a,(String)b);
        case "windowLookup":return com.sao.engine.SAOShelterConstruction.window(body,(String)a,(String)b);
        case "toggle":{var w=((IsoGridSquare)value(a)).getWindow(Boolean.TRUE.equals(b)?GridSquareEdgeFacingDirection.NORTH_SOUTH:GridSquareEdgeFacingDirection.EAST_WEST);w.ToggleWindow(body);return w.IsOpen();}
        case "requestToggle":{var w=(IsoWindow)value(a);if(Boolean.TRUE.equals(b))body.openWindow(w);else body.closeWindow(w);return true;}
        case "factoryLoading":zombie.entity.GameEntityFactory.CreateIsoEntityFromCellLoading((IsoObject)value(a));return true;
        case "factoryTransfer":zombie.entity.GameEntityFactory.TransferComponents((InventoryItem)value(a),(IsoObject)value(b));return true;
        case "generator":IsoGenerator.updateGenerator((IsoGridSquare)value(a));return true;
        case "passageBegin":{var p=(KahluaTable)c;set(ShelterConstructionNativeProbe.class,"sceneCaptureKey",b);set(ShelterConstructionNativeProbe.class,"sceneCaptureRevision",p.rawget(1.0));return com.sao.engine.SAOShelterConstruction.beginPassage(body,(IsoWindow)value(a),(String)b,(String)p.rawget(1.0),Boolean.TRUE.equals(p.rawget(2.0)));}
        case "windowPass":{
            var w=(IsoWindow)value(a);boolean inward=Boolean.TRUE.equals(b);var sq=w.getSquare();
            int x=sq.getX()-(inward||w.getNorth()?0:1),y=sq.getY()-(inward||!w.getNorth()?0:1);
            var from=body.getCurrentSquare();if(from==body.getCell().getGridSquare(x,y,0))return true;
            if(!w.IsOpen()||!w.canClimbThrough(body))return false;
            var climb=zombie.ai.states.ClimbThroughWindowState.instance();body.climbThroughWindow(w);
            climb.setParams(body,w);body.changeState(climb);body.setVariable("ClimbWindowStarted",true);
            int ticks=0;while(body.getCurrentSquare()!=body.getCell().getGridSquare(x,y,0)&&ticks++<300){
                body.setLastX(body.getX());body.setLastY(body.getY());body.setLastZ(body.getZ());body.preupdate();climb.execute(body);body.postupdate();
            }
            boolean crossed=body.getCurrentSquare()==body.getCell().getGridSquare(x,y,0)&&from!=body.getCurrentSquare();
            body.changeState(zombie.ai.states.IdleState.instance());body.getActionContext().clearActionContextEvents();body.preupdate();body.postupdate();
            boolean arrived=crossed&&(Boolean)call(ShelterConstructionNativeProbe.class,"sceneMove",new Class<?>[]{double.class,double.class,double.class},x+.5,y+.5,0.0);
            if(crossed){var f=ShelterConstructionNativeProbe.class.getDeclaredField("passageCount");f.setAccessible(true);f.setInt(null,f.getInt(null)+1);}
            System.out.println("NATIVE_WINDOW_PASS "+crossed+" ticks="+ticks+" pos="+body.getX()+","+body.getY());
            return arrived;
        }
        }
        throw new IllegalStateException("window op "+name);
    }
    public static void main(String[] args)throws Exception {
        var game=Path.of(args[0]);var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function()return {queue={}}end}","empty",env),null,null,null);
        set(MetalShelterNativeProbe.class,"game",game);set(MetalShelterNativeProbe.class,"enclosureMode",true);call(MetalShelterNativeProbe.class,"initialise",new Class<?>[]{});zombie.ZomboidFileSystem.instance.init();Class.forName("zombie.SandboxOptions");zombie.SandboxOptions.instance.seeNotLearntRecipe.setValue(true);
        // Native boot adds offset alias values before tile definitions derive facing links.
        var custom=IsoWorld.class.getDeclaredMethod("SetCustomPropertyValues");custom.setAccessible(true);custom.invoke(IsoWorld.instance);
        zombie.core.TilePropertyAliasMap.instance.Generate(IsoWorld.PropertyValueMap);
        boolean tileServer=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        IsoWorld.instance.LoadTileDefinitions(zombie.iso.sprite.IsoSpriteManager.instance,game.resolve("media/newtiledefinitions.tiles").toString(),0);zombie.network.GameServer.server=tileServer;
        var module=ScriptManager.instance.getModule("Base");boolean old=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        for(String name:List.of("Mov_WindowWooden","Mov_WindowWhite")){String block=(String)call(ShelterConstructionNativeProbe.class,"block",new Class<?>[]{Path.class,String.class,String.class},game.resolve("media/scripts/generated/items/moveable.txt"),"item",name);var item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,block);item.setDisplayName(name);module.items.getScriptMap().put(name,item);}call(ShelterConstructionNativeProbe.class,"indexBuckets",new Class<?>[]{});ItemTags.Init(ScriptManager.instance.getAllItems());zombie.network.GameServer.server=old;
        env.rawset("__nativeShelter",(JavaFunction)(f,n)->{try{return f.push(out(call(MetalShelterNativeProbe.class,"op",new Class<?>[]{String.class,Object.class,Object.class},(String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null)));}catch(Throwable e){e.printStackTrace();throw new IllegalStateException(e);}});
        env.rawset("__nativeWindow",(JavaFunction)(f,n)->{try{return f.push(out(op((String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null,n>3?f.get(3):null)));}catch(Throwable e){e.printStackTrace();throw new IllegalStateException(e);}});
        env.rawset("__recipeNative",(JavaFunction)(f,n)->{try{return f.push(out(call(MetalShelterNativeProbe.class,"recipeCall",new Class<?>[]{LuaCallFrame.class},f)));}catch(Throwable e){throw new IllegalStateException(e);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(f,n)->{try{var buf=ByteBuffer.allocate(2097152);((KahluaTable)f.get(0)).save(buf);buf.flip();var t=platform.newTable();t.load(buf,IsoWorld.WorldVersion);return f.push(t);}catch(Exception e){throw new IllegalStateException(e);}});
        Path source=null;for(String arg:args)if(Path.of(arg).getFileName().toString().equals("production.lua"))source=Path.of(arg);final Path reload=source;
        env.rawset("__reloadProduction",(JavaFunction)(f,n)->{try(Reader r=Files.newBufferedReader(reload)){Object[] result=thread.pcall(LuaCompiler.loadis(r,"reload",env),new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new IllegalStateException(Arrays.toString(result));return f.push(true);}catch(Exception e){throw new IllegalStateException(e);}});
        for(int n=1;n<args.length;n++)try(Reader r=Files.newBufferedReader(Path.of(args[n]))){Object[] result=thread.pcall(LuaCompiler.loadis(r,args[n],env),new Object[0]);if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR "+args[n]);for(int i=1;i<result.length;i++)System.out.println(result[i]);System.exit(1);}}
    }
}
