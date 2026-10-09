import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.core.skinnedmodel.visual.HumanVisual;

// Installed native constructor check. No world, game state, or save is opened.
public final class AppearanceBaseVisualProbe {
    private static void check(boolean condition, String name) {
        if (!condition) throw new AssertionError(name);
        System.out.println("PASS " + name);
    }

    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,
                zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        zombie.core.skinnedmodel.population.HairStyles.instance =
                new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.BeardStyles.instance =
                new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle();
        hair.name = "Short";
        hair.model = "ShortModel";
        hair.texture = "ShortTexture";
        zombie.core.skinnedmodel.population.HairStyles.instance.maleStyles.add(hair);
        var changedHair = new zombie.core.skinnedmodel.population.HairStyle();
        changedHair.name = "CrewCut";
        changedHair.model = "CrewCutModel";
        changedHair.texture = "CrewCutTexture";
        zombie.core.skinnedmodel.population.HairStyles.instance.maleStyles.add(changedHair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle();
        beard.name = "Stubble";
        beard.model = "StubbleModel";
        beard.texture = "StubbleTexture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        SurvivorDesc desc = new SurvivorDesc();
        desc.setFemale(false);
        HumanVisual from = desc.getHumanVisual();
        from.setSkinTextureName("fixture");
        from.setHairModel("Short");
        from.setBeardModel("Stubble");
        from.setHairColor(new zombie.core.ImmutableColor(.2f, .1f, .05f));
        IsoPlayer body = new IsoPlayer(null, desc, 0, 0, 0, false);
        HumanVisual base = body.getHumanVisual();
        check(base != from && body.getDescriptor() == desc,
                "native/constructor-distinct-baseVisual");
        check("Short".equals(base.getHairModel()),
                "native/constructor-copied-style");
        check(Math.abs(base.getHairColor().getRedFloat() - .2f) < .001f,
                "native/constructor-copied-colour");
        from.setHairModel("MohawkFan");
        from.setHairColor(new zombie.core.ImmutableColor(.9f, .1f, .05f));
        check("Short".equals(base.getHairModel()),
                "native/descriptor-mutation-does-not-change-body");
        check(Math.abs(base.getHairColor().getRedFloat() - .2f) < .001f,
                "native/descriptor-colour-does-not-change-body");
        base.setHairModel("CrewCut");
        base.setHairColor(new zombie.core.ImmutableColor(.7f, .1f, .05f));
        check("CrewCut".equals(body.getHumanVisual().getHairModel()),
                "native/body-visual-is-display-authority");
        check(Math.abs(body.getHumanVisual().getHairColor().getRedFloat() - .7f)
                < .001f, "native/body-colour-is-display-authority");
    }
}
