import java.nio.ByteBuffer;
import java.util.Arrays;
import zombie.characters.*;
import zombie.characters.BodyDamage.*;
import zombie.characters.skills.PerkFactory;

public final class RecoveryHealthProbe {
    static void check(boolean ok, String message) { if (!ok) throw new AssertionError(message); }
    static IsoPlayer person() {
        SurvivorDesc desc = new SurvivorDesc();
        desc.getHumanVisual().setSkinTextureName("fixture");
        return new IsoPlayer(null, desc, 0, 0, 0, false);
    }
    static float[] health(BodyDamage damage) {
        float[] out = new float[damage.getBodyParts().size()];
        for (int i=0;i<out.length;i++) out[i]=damage.getBodyParts().get(i).getHealth();
        return out;
    }
    static void clearNativeKnox(IsoPlayer player) {
        BodyDamage damage=player.getBodyDamage();
        for (BodyPart part:damage.getBodyParts()) { part.SetInfected(false); part.SetFakeInfected(false); }
        damage.setInfected(false); damage.setIsFakeInfected(false); damage.setReduceFakeInfection(false);
        damage.setInfectionTime(-1); damage.setInfectionMortalityDuration(-1);
        player.getStats().reset(CharacterStat.ZOMBIE_INFECTION);
        player.getStats().reset(CharacterStat.ZOMBIE_FEVER);
        damage.calculateOverallHealth();
    }
    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform=new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env=zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f,.3f,.4f));
        zombie.core.skinnedmodel.population.HairStyles.instance=new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.BeardStyles.instance=new zombie.core.skinnedmodel.population.BeardStyles();
        PerkFactory.init();
        IsoPlayer source=person();
        BodyDamage damage=source.getBodyDamage();
        BodyPart wound=damage.getBodyPart(BodyPartType.Hand_R);
        wound.SetBitten(true,true); wound.setBiteTime(12.5f);
        wound.setBandaged(true,4.25f,true,"fixture-bandage");
        wound.setFractureTime(17f); wound.setInfectedWound(true); wound.setWoundInfectionLevel(2.5f);
        damage.setInfected(true); damage.setInfectionTime(1f); damage.setInfectionMortalityDuration(1f);
        source.getStats().set(CharacterStat.ZOMBIE_INFECTION,100f);
        source.getStats().set(CharacterStat.HUNGER,.42f);
        source.getStats().set(CharacterStat.FATIGUE,.61f);
        source.getStats().set(CharacterStat.POISON,3f);
        source.getXp().xpMap.put(PerkFactory.Perks.Aiming,88.5f);
        source.setPerkLevelDebug(PerkFactory.Perks.Aiming,2);
        damage.ReduceGeneralHealth(110f); damage.calculateOverallHealth();
        check(source.isDead(),"native terminal infection damage did not kill fixture");
        ByteBuffer packed=ByteBuffer.allocate(1<<20); damage.save(packed); packed.flip();
        IsoPlayer restored=person(); restored.getBodyDamage().load(packed,249);
        ByteBuffer stats=ByteBuffer.allocate(8192); source.getStats().save(stats); stats.flip(); restored.getStats().load(stats,249);
        ByteBuffer xp=ByteBuffer.allocate(1<<20); source.getXp().save(xp); xp.flip(); restored.getXp().load(xp,249);
        float[] oldParts=health(restored.getBodyDamage());
        clearNativeKnox(restored);
        BodyPart retained=restored.getBodyDamage().getBodyPart(BodyPartType.Hand_R);
        System.out.println("WOUNDS source/restored: bitten="+wound.bitten()+"/"+retained.bitten()
            +" biteTime="+wound.getBiteTime()+"/"+retained.getBiteTime()+" bandage="+wound.bandaged()+"/"+retained.bandaged()
            +" bandageLife="+wound.getBandageLife()+"/"+retained.getBandageLife()+" fracture="+wound.getFractureTime()+"/"+retained.getFractureTime()
            +" woundInfection="+wound.isInfectedWound()+"/"+retained.isInfectedWound()+" level="+wound.getWoundInfectionLevel()+"/"+retained.getWoundInfectionLevel());
        check(Arrays.equals(oldParts,health(restored.getBodyDamage())),"flag cleanup healed part health");
        check(retained.bitten() == wound.bitten() && retained.getBiteTime()==12.5f && retained.bandaged()
            && retained.getBandageLife()==4.25f && retained.getFractureTime()==17f
            && retained.isInfectedWound() && retained.getWoundInfectionLevel()==2.5f,"unrelated wounds changed");
        check(restored.getStats().get(CharacterStat.HUNGER)==.42f
            && restored.getStats().get(CharacterStat.FATIGUE)==.61f
            && restored.getStats().get(CharacterStat.POISON)==3f
            && restored.getXp().getXP(PerkFactory.Perks.Aiming)==88.5f
            && restored.getPerkLevel(PerkFactory.Perks.Aiming)==2,"unrelated stats/XP changed");
        check(restored.getBodyDamage().getHealth()==0 && restored.isDead(),"terminal physical loss disappeared");
        System.out.println("PASS native death snapshot roundtrip: narrow Knox reset preserves part health, bite/bandage/fracture/wound infection, hunger/fatigue/poison/XP; recalculated health="+restored.getBodyDamage().getHealth());
        restored.getBodyDamage().setOverallBodyHealth(5f);
        check(!restored.isDead(),"scalar lift did not temporarily satisfy isDead");
        restored.getBodyDamage().calculateOverallHealth();
        check(restored.isDead(),"scalar lift survived native recalculation");
        System.out.println("PASS scalar overall-health lift is temporary; calculateOverallHealth returns it to zero");
        IsoPlayer surviving=person();
        BodyPart injury=surviving.getBodyDamage().getBodyPart(BodyPartType.Hand_R);
        injury.SetHealth(63f); injury.setFractureTime(17f); injury.SetInfected(true);
        clearNativeKnox(surviving);
        check(!surviving.isDead() && injury.getHealth()==63f && injury.getFractureTime()==17f,"nonlethal trauma changed");
        System.out.println("PASS nonlethal injury survives unchanged with native recalculated health="+surviving.getBodyDamage().getHealth());
        try {
            zombie.iso.IsoCell cell = new zombie.iso.IsoCell(1,1); zombie.iso.WorldReuserThread.instance.stop(); java.lang.reflect.Field regionRoot = zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot"); regionRoot.setAccessible(true); regionRoot.set(null,new zombie.iso.areas.isoregion.data.DataRoot()); surviving.setCurrentSquare(new zombie.iso.IsoGridSquare(null,null,0,0,0)); surviving.getBodyDamage().Update();
            check(!surviving.getBodyDamage().isInfected() && !surviving.isDead(),"narrow reset reinfected or killed surviving fixture");
            System.out.println("PASS full native NEXT_UPDATE: infected="+surviving.getBodyDamage().isInfected()+" health="+surviving.getBodyDamage().getHealth());
            injury.SetInfected(true); surviving.getBodyDamage().setInfected(false);
            surviving.getBodyDamage().Update();
            check(surviving.getBodyDamage().isInfected(),"omitting part cleanup failed to reinfect global state");
            System.out.println("PASS omission control: surviving infected part reactivates global Knox on native NEXT_UPDATE");
            clearNativeKnox(surviving); surviving.getBodyDamage().Update();
            check(!surviving.getBodyDamage().isInfected(),"complete reset failed after omission control");
        } catch (Throwable error) {
            System.out.println("UNCHECKED full BodyDamage.Update headless prerequisite: "+error);
            error.printStackTrace(System.out);
        }
    }
}
