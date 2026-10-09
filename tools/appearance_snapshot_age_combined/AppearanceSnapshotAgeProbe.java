import com.sao.engine.SAONativeSnapshot;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.core.ImmutableColor;
import zombie.core.skinnedmodel.population.BeardStyle;
import zombie.core.skinnedmodel.population.BeardStyles;
import zombie.core.skinnedmodel.population.HairStyle;
import zombie.core.skinnedmodel.population.HairStyles;
import zombie.core.skinnedmodel.population.OutfitManager;
import zombie.core.skinnedmodel.visual.HumanVisual;

/** A headless installed IsoPlayer and Kahlua share one restored body. */
public final class AppearanceSnapshotAgeProbe {
    private static void check(boolean yes, String label) {
        if (!yes) throw new AssertionError(label);
        System.out.println("PASS " + label);
    }

    private static void boot() throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        LuaManager.platform = new J2SEPlatform();
        LuaManager.env = LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(LuaManager.platform, LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new ImmutableColor(.2f, .3f, .4f));
        HairStyles.instance = new HairStyles();
        BeardStyles.instance = new BeardStyles();
        OutfitManager.instance = new OutfitManager();
        HairStyle hair = new HairStyle();
        hair.name = "Short";
        hair.model = "ShortModel";
        hair.texture = "ShortTexture";
        HairStyles.instance.maleStyles.add(hair);
        BeardStyle beard = new BeardStyle();
        beard.name = "Stubble";
        beard.model = "StubbleModel";
        beard.texture = "StubbleTexture";
        BeardStyles.instance.styles.add(beard);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.skills.PerkFactory.init();
    }

    private static IsoPlayer person() {
        SurvivorDesc desc = new SurvivorDesc();
        desc.setFemale(false);
        HumanVisual visual = desc.getHumanVisual();
        visual.setSkinTextureName("fixture");
        visual.setHairModel("Short");
        visual.setBeardModel("Stubble");
        visual.setHairColor(new ImmutableColor(.2f, .1f, .05f));
        visual.setBeardColor(new ImmutableColor(.25f, .13f, .08f));
        return new IsoPlayer(null, desc, 0, 0, 0, false);
    }

    private static boolean close(ImmutableColor a, ImmutableColor b) {
        return a != null && b != null
            && Math.abs(a.getRedFloat() - b.getRedFloat()) < .006f
            && Math.abs(a.getGreenFloat() - b.getGreenFloat()) < .006f
            && Math.abs(a.getBlueFloat() - b.getBlueFloat()) < .006f;
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("source.lua cases.lua");
        boot();
        IsoPlayer source = person();
        String packed = SAONativeSnapshot.capture(source);
        check(SAONativeSnapshot.validate(packed)
            && SAONativeSnapshot.formatVersion(packed) == 4, "native/v4-capture");
        IsoPlayer restored = person();
        check(restored != source && restored.getHumanVisual() != source.getHumanVisual(),
            "native/new-body");
        restored.getHumanVisual().setHairColor(new ImmutableColor(.6f, .05f, .03f));
        check(!close(restored.getHumanVisual().getHairColor(),
                     source.getHumanVisual().getHairColor()),
            "native/stale-display-before-restore");
        check(SAONativeSnapshot.restore(restored, packed) == 0, "native/v4-restore");
        check(close(restored.getHumanVisual().getHairColor(),
                    source.getHumanVisual().getHairColor()), "native/display-restored");
        check(restored.getDescriptor().getHumanVisual() != restored.getHumanVisual(),
            "native/descriptor-distinct");

        J2SEPlatform platform = new J2SEPlatform();
        var env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform;
        LuaManager.env = env;
        LuaManager.thread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        Class<?>[] types = {IsoPlayer.class, zombie.characters.IsoGameCharacter.class,
            SurvivorDesc.class, HumanVisual.class, ImmutableColor.class};
        for (Class<?> type : types) exposer.setExposed(type);
        for (Class<?> type : types) exposer.exposeLikeJava(type, env);
        zombie.Lua.LuaEventManager.register(platform, env);
        env.rawset("__nativeBody", restored);
        env.rawset("__isSameBody", (JavaFunction)(frame, count) ->
            frame.push(frame.get(0) == restored));
        env.rawset("__reloadBody", (JavaFunction)(frame, count) -> {
            try {
                IsoPlayer current = (IsoPlayer)frame.get(0);
                String state = SAONativeSnapshot.capture(current);
                if (!SAONativeSnapshot.validate(state)
                    || SAONativeSnapshot.formatVersion(state) != 4)
                    throw new AssertionError("reload capture is not v4");
                IsoPlayer reload = person();
                if (SAONativeSnapshot.restore(reload, state) != 0)
                    throw new AssertionError("reload restore count");
                return frame.push(reload);
            } catch (Exception error) {
                throw new IllegalStateException(error);
            }
        });
        env.rawset("__isNativeBody", (JavaFunction)(frame, count) ->
            frame.push(frame.get(0) instanceof IsoPlayer));
        env.rawset("__nativeColour", (JavaFunction)(frame, count) ->
            frame.push(new ImmutableColor(.04f, .12f, .84f)));
        env.rawset("__newBody", (JavaFunction)(frame, count) -> frame.push(person()));
        String prelude = "SAO={Hash={of=function() return 0 end},"
            + "History={ageOf=function(id) return __age end},Log={line=function() end}}";
        thread.call(LuaCompiler.loadstring(prelude, "age-fixture", env), null, null, null);
        for (String file : args)
            thread.call(LuaCompiler.loadstring(Files.readString(Path.of(file)), file, env),
                null, null, null);
        Object result = thread.call(LuaCompiler.loadstring(
            "return appearanceSnapshotAgeCases()", "combined-verdict", env),
            null, null, null);
        System.out.println("VALUE " + result);
    }
}
