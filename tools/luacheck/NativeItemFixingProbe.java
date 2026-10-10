import java.io.Reader;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import sun.misc.Unsafe;
import zombie.characters.*;
import zombie.characters.skills.PerkFactory;
import zombie.inventory.*;
import zombie.inventory.types.*;
import zombie.scripting.*;
import zombie.scripting.objects.*;

/** Real installed definitions/factories/FixingManager; unattached controlled actor. */
public final class NativeItemFixingProbe {
    static J2SEPlatform platform;static KahluaTable env;static KahluaThread thread;
    static ScriptModule module;static Receiver actor;static HandWeapon target,donor;
    static Fixing definition;static Fixing.Fixer fixer;static int skill=5,callbacks;
    static final ArrayList<Fixing> definitions=new ArrayList<>();
    static final HashMap<Integer,InventoryItem> items=new HashMap<>();
    static Unsafe unsafe() throws Exception {Field f=Unsafe.class.getDeclaredField("theUnsafe");f.setAccessible(true);return (Unsafe)f.get(null);}
    public static class Receiver extends IsoPlayer {
        ItemContainer inv;IsoGameCharacter.XP testXp;BaseCharacterSoundEmitter sound;
        public Receiver(){super((zombie.iso.IsoCell)null);}
        @Override public ItemContainer getInventory(){return inv;}
        @Override public int getPerkLevel(PerkFactory.Perk p){return skill;}
        @Override public IsoGameCharacter.XP getXp(){return testXp;}
        @Override public BaseCharacterSoundEmitter getEmitter(){return sound;}
        @Override public boolean isLocalPlayer(){return false;}
    }
    public static class Xp extends IsoGameCharacter.XP {
        Xp(Receiver a){a.super(a);}
        @Override public void AddXP(PerkFactory.Perk p,float amount){}
        @Override public void AddXP(PerkFactory.Perk p,float amount,boolean a,boolean b,boolean c,boolean d){}
    }
    static String block(Path p,String kind,String name)throws Exception{
        String source=Files.readString(p);
        Matcher m=Pattern.compile("(?m)^\\s*"+kind+"\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(source);
        if(!m.find())throw new IllegalArgumentException("missing native "+kind+" "+name);
        int brace=source.indexOf('{',m.start()),end=brace+1,depth=1;
        while(depth>0){char c=source.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}
        return source.substring(m.start(),end);
    }
    static void loadItem(Path game,String name,String file)throws Exception{
        Item i=new Item();i.setModule(module);i.setModID("pz-vanilla");i.InitLoadPP(name);
        i.Load(name,block(game.resolve("media/scripts/generated/items/"+file+".txt"),"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$",""));
        i.setDisplayName(name);module.items.getScriptMap().put(name,i);
    }
    static void initialise(Path game)throws Exception{
        zombie.core.random.RandStandard.INSTANCE.init();PerkFactory.init();zombie.entity.components.attributes.Attribute.init();
        zombie.network.GameServer.server=true;
        Field f=ScriptManager.class.getDeclaredField("currentLoadFileMod");f.setAccessible(true);f.set(null,"pz-vanilla");
        module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);ScriptManager.instance.moduleList.add(module);
        for(Field field:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(field.getType())){
            field.setAccessible(true);((ScriptBucketCollection<?>)field.get(ScriptManager.instance)).registerModule(module);
        }
        String script=Files.readString(game.resolve("media/scripts/generated/fixing.txt"));
        Matcher matches=Pattern.compile("(?m)^\\s*fixing\\s+([^\\r\\n{]+)").matcher(script);
        LinkedHashSet<String> types=new LinkedHashSet<>();
        while(matches.find()){
            String name=matches.group(1).trim();Fixing def=new Fixing();def.setModule(module);def.InitLoadPP(name);
            def.Load(name,block(game.resolve("media/scripts/generated/fixing.txt"),"fixing",name));
            module.fixings.getScriptMap().put(name,def);definitions.add(def);
            for(String type:def.getRequiredItem())types.add(type.substring(type.indexOf('.')+1));
            for(Fixing.Fixer x:def.getFixers())types.add(x.getFixerName().substring(x.getFixerName().indexOf('.')+1));
        }
        for(String type:types)loadItem(game,type,"weapon");
        for(String type:List.of("Bullets9mm","9mmClip"))loadItem(game,type,"normal");
        loadItem(game,"Laser","weaponpart");
        for(Field field:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(field.getType())){
            field.setAccessible(true);ScriptBucketCollection collection=(ScriptBucketCollection)field.get(ScriptManager.instance);
            ScriptBucket bucket=collection.getBucketFromModule(module);
            for(Object value:bucket.getScriptMap().values()){
                BaseScriptObject object=(BaseScriptObject)value;
                collection.getFullTypeToScriptMap().put(object.getScriptObjectFullType(),object);
                if(!bucket.getScriptList().contains(object))bucket.getScriptList().add(object);
                if(!collection.getAllScripts().contains(object))collection.getAllScripts().add(object);
            }
        }
        ItemTags.Init(ScriptManager.instance.getAllItems());zombie.network.GameServer.server=false;
    }
    static InventoryItem make(String type,int id)throws Exception{
        boolean server=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        InventoryItem i=module.getItem(type).InstanceItem(null);zombie.network.GameServer.server=server;
        i.setID(id);items.put(id,i);return i;
    }
    static void reset(String type)throws Exception{
        actor=(Receiver)unsafe().allocateInstance(Receiver.class);actor.inv=new ItemContainer();actor.inv.setType("inventory");
        actor.testXp=new Xp(actor);actor.sound=new DummyCharacterSoundEmitter(actor);
        items.clear();skill=5;callbacks=0;
        target=(HandWeapon)make(type,701);donor=(HandWeapon)make(type,702);
        target.setConditionNoSound(2);target.setHaveBeenRepaired(0);donor.setConditionNoSound(0);
        target.setCurrentAmmoCount(0);target.setContainsClip(false);target.setRoundChambered(false);
        donor.setCurrentAmmoCount(0);donor.setContainsClip(false);donor.setRoundChambered(false);
        actor.inv.AddItemBlind(target);actor.inv.AddItemBlind(donor);target.setContainer(actor.inv);donor.setContainer(actor.inv);
        definition=FixingManager.getFixes(target).get(0);fixer=definition.getFixers().get(0);
    }
    static void seed(long value)throws Exception{
        Field f=zombie.core.random.RandAbstract.class.getDeclaredField("rand");f.setAccessible(true);
        f.set(zombie.core.random.RandStandard.INSTANCE,new org.uncommons.maths.random.CellularAutomatonRNG(ByteBuffer.allocate(4).putInt((int)value).array()));
    }
    static KahluaTable list(Collection<?> values){
        KahluaTable t=platform.newTable();int index=1;for(Object v:values)t.rawset((double)index++,v instanceof Number?((Number)v).doubleValue():v);return t;
    }
    static KahluaTable descriptor(InventoryItem item){
        KahluaTable t=platform.newTable();
        t.rawset("id",(double)item.getID());t.rawset("fullType",item.getFullType());
        t.rawset("condition",(double)item.getCondition());t.rawset("maximum",(double)item.getConditionMax());
        t.rawset("repairCount",(double)item.getHaveBeenRepaired());t.rawset("ammo",(double)item.getCurrentAmmoCount());
        if(item instanceof HandWeapon w){
            t.rawset("swingAnim",w.getSwingAnim());t.rawset("ranged",w.isRanged());t.rawset("twoHands",w.isTwoHandWeapon());t.rawset("requiresBoth",w.isRequiresEquippedBothHands());
            t.rawset("magazine",w.getMagazineType());t.rawset("clip",w.isContainsClip());
            t.rawset("chamber",w.haveChamber()&&w.isRoundChambered());
            t.rawset("ammoType",w.getAmmoType()!=null?w.getAmmoType().getItemKey():null);
            ArrayList<Object> parts=new ArrayList<>();for(WeaponPart part:w.getAllWeaponParts())parts.add(descriptor(part));
            t.rawset("parts",list(parts));
        }
        return t;
    }
    static Object op(String name,Object value)throws Exception{
        switch(name){
        case "definitions": {
            ArrayList<Object> defs=new ArrayList<>();
            for(Fixing def:definitions){
                KahluaTable t=platform.newTable();t.rawset("name",def.getName());t.rawset("module",def.getModule().getName());
                t.rawset("required",list(def.getRequiredItem()));t.rawset("global",def.getGlobalItem()!=null);
                ArrayList<Object> fixers=new ArrayList<>();
                for(Fixing.Fixer x:def.getFixers()){
                    KahluaTable f=platform.newTable();f.rawset("name",x.getFixerName());f.rawset("uses",(double)x.getNumberOfUse());
                    ArrayList<Object> skills=new ArrayList<>();
                    if(x.getFixerSkills()!=null)for(Fixing.FixerSkill sk:x.getFixerSkills()){
                        KahluaTable p=platform.newTable();p.rawset("name",sk.getSkillName());p.rawset("level",(double)sk.getSkillLevel());skills.add(p);
                    }
                    f.rawset("skills",list(skills));fixers.add(f);
                }
                t.rawset("fixers",list(fixers));defs.add(t);
            }return list(defs);
        }
        case "reset":reset(value==null?"Pistol":(String)value);return true;
        case "select": {
            String key=(String)value;
            for(Fixing d:FixingManager.getFixes(target))for(int i=0;i<d.getFixers().size();i++)
                if(key.equals("fixing:"+d.getModule().getName()+"."+d.getName()+":"+i)){definition=d;fixer=d.getFixers().get(i);return true;}
            return false;
        }
        case "donorType":{
            actor.inv.Remove(donor);donor=(HandWeapon)make((String)value,702);donor.setConditionNoSound(0);
            donor.setCurrentAmmoCount(0);donor.setContainsClip(false);donor.setRoundChambered(false);
            actor.inv.AddItemBlind(donor);donor.setContainer(actor.inv);return true;
        }
        case "targetLoaded":target.setContainsClip(true);target.setCurrentAmmoCount(3);target.setRoundChambered(true);return true;
        case "contents": {
            donor.attachWeaponPart((WeaponPart)make("Laser",703),false);
            donor.setContainsClip(true);donor.setCurrentAmmoCount(4);donor.setRoundChambered(true);return true;
        }
        case "skill":skill=((Number)value).intValue();return true;
        case "condition":target.setConditionNoSound(((Number)value).intValue());return true;
        case "repairCount":target.setHaveBeenRepaired(((Number)value).intValue());return true;
        case "chance":return FixingManager.getChanceOfFail(target,actor,definition,fixer);
        case "perform":{
            long selected=0;boolean failed=Boolean.TRUE.equals(value);
            double chance=FixingManager.getChanceOfFail(target,actor,definition,fixer);
            for(long i=0;i<100000;i++){
                seed(i);boolean failure=zombie.core.random.Rand.Next(100)<chance;
                if(failure==failed){selected=i;break;}
            }
            if(failed)System.out.println("native fail chance="+chance+" seed="+selected);seed(selected);callbacks++;FixingManager.fixItem(target,actor,definition,fixer);return true;
        }
        case "target":return descriptor(target);
        case "donor":return descriptor(donor);
        case "inventory": {
            ArrayList<Object> rows=new ArrayList<>();for(InventoryItem i:actor.inv.getItems())rows.add(descriptor(i));return list(rows);
        }
        case "required": {
            ArrayList<InventoryItem> r=definition.getRequiredItems(actor,fixer,target);
            return r!=null&&r.size()==1&&r.get(0)==donor;
        }
        case "callbacks":return callbacks;
        case "donorHeld":return actor.inv.contains(donor);
        default:throw new IllegalArgumentException(name);
        }
    }
    public static void main(String[] args)throws Exception{
        platform=new J2SEPlatform();env=platform.newEnvironment();thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",new JavaFunction(){public int call(LuaCallFrame f,int n){for(int i=0;i<n;i++)System.out.print((i>0?"\t":"")+f.get(i));System.out.println();return 0;}});
        initialise(Path.of(args[0]));reset("Pistol");System.out.println("native_registered_definition_count="+definitions.size());System.out.println("native_registered_fixer_count="+definitions.stream().mapToInt(d->d.getFixers().size()).sum());
        env.rawset("__nativeFix",new JavaFunction(){public int call(LuaCallFrame f,int n){try{
            Object r=op((String)f.get(0),n>1?f.get(1):null);return f.push(r instanceof Number?((Number)r).doubleValue():r);
        }catch(Exception e){e.printStackTrace();throw new IllegalStateException(e);}}});
        env.rawset("__nativeRoundtrip",new JavaFunction(){public int call(LuaCallFrame f,int n){try{
            ByteBuffer bytes=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);bytes.flip();KahluaTable r=platform.newTable();r.load(bytes,zombie.iso.IsoWorld.WorldVersion);return f.push(r);
        }catch(Exception e){throw new IllegalStateException(e);}}});
        Path source=null;for(String a:args)if(Path.of(a).getFileName().toString().equals("production.lua"))source=Path.of(a);
        final Path production=source;
        env.rawset("__reloadProduction",new JavaFunction(){public int call(LuaCallFrame f,int n){try(Reader r=Files.newBufferedReader(production)){
            Object[] result=thread.pcall(LuaCompiler.loadis(r,"production-reload",env),new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new IllegalStateException(Arrays.toString(result));return f.push(true);
        }catch(Exception e){throw new IllegalStateException(e);}}});
        for(int i=1;i<args.length;i++)try(Reader r=Files.newBufferedReader(Path.of(args[i]))){
            Object[] result=thread.pcall(LuaCompiler.loadis(r,args[i],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR chunk="+args[i]);System.out.println(Arrays.toString(result));System.exit(1);}
        }
    }
}
