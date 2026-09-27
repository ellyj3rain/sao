import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaThread;
import zombie.GameTime;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.iso.IsoCamera;
import zombie.ui.SpeedControls;
import zombie.ui.UIElement;
import zombie.ui.UIManager;

/** Production command polling and native UI dispatch with bounded Lua receivers. */
public final class NativeObserverInspectionProbe {
    private static Field field(String name) throws Exception {
        Field f = StudyObserver.class.getDeclaredField(name); f.setAccessible(true); return f;
    }
    private static void check(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
    }
    private static void command(Path path, String properties, boolean applied) throws Exception {
        long before = StudyObserver.commandSequence();
        long next = Math.max(before, field("rejectedSequence").getLong(null)) + 1;
        Files.writeString(path, "sequence=" + next + "\n" + properties);
        field("nextPoll").setLong(null, 0); StudyObserver.poll();
        check(StudyObserver.commandSequence() == (applied ? next : before),
            applied ? "inspection command not acknowledged after dispatch" : "invalid inspection command acknowledged");
    }
    public static void run(Path control, SpeedControls speed) throws Exception {
        LuaManager.thread = new KahluaThread(LuaManager.platform, LuaManager.env);
        LuaManager.thread.debugOwnerThread = Thread.currentThread();
        LuaManager.caller = new LuaCaller(new KahluaConverterManager());
        int[] draws = {0, 0};
        UIElement inspector = new UIElement() { @Override public void render() { draws[0]++; } };
        UIElement avatar = new UIElement() { @Override public void render() { draws[1]++; } };
        inspector.setVisible(true); avatar.setVisible(true); UIManager.UI.add(avatar);
        LuaManager.env.rawset("probePanel", inspector);
        var setup = LuaCompiler.loadstring("calls=0; permit=true; shown=false; SAO={Observation={"
            + "validatePerson=function(id) return id=='sao-probe' end,"
            + "select=function(id) calls=calls+1; selected=id; return permit end,"
            + "panel=function(panel,id,visible) calls=calls+1; selected=id; shown=visible; return permit end,"
            + "cognition=function(share,rate,depth) calls=calls+1; modelShare=share; modelRate=rate; modelDepth=depth; return permit end,"
            + "nativePanel=function() if shown then return probePanel end end}}", "inspection-probe.lua", LuaManager.env);
        LuaManager.thread.call(setup, null, null, null);
        command(control, "paused=true\nspeed=2\n", true);
        Object player = IsoPlayer.getInstance(), camera = IsoCamera.getCameraCharacter();
        float px = IsoPlayer.players[0].getX(), py = IsoPlayer.players[0].getY();
        float vx = IsoCamera.getCameraCharacter().getX(), vy = IsoCamera.getCameraCharacter().getY();
        float multiplier = GameTime.getInstance().getTrueMultiplier();
        command(control, "selectedPersonId=sao-probe\n", true);
        check("sao-probe".equals(LuaManager.env.rawget("selected")), "selection did not reach Lua receiver");
        command(control, "selectedPersonId=missing\n", false);
        check(((Double) LuaManager.env.rawget("calls")) == 1.0, "unknown person reached inspection receiver");
        command(control, "selectedPersonId=sao-probe\nviewX=44\n", false);
        command(control, "panelId=person-inspection\npanelPersonId=sao-probe\npanelVisible=wrong\n", false);
        check(((Double) LuaManager.env.rawget("calls")) == 1.0, "partial inspection validation dispatched work");
        LuaManager.env.rawset("permit", false);
        command(control, "selectedPersonId=sao-probe\n", false);
        LuaManager.env.rawset("permit", true);
        command(control, "panelId=person-inspection\npanelPersonId=sao-probe\npanelVisible=true\n", true);
        check(StudyObserver.snapshot().contains("\"inspectionPanelVisible\":true"), "panel visibility was not reported");
        UIManager.useUiFbo = false; UIManager.suspend = false;
        UIManager.render();
        check(draws[0] == 1 && draws[1] == 0, "native inspector rendering did not isolate its UI element");
        command(control, "panelId=person-inspection\npanelPersonId=sao-probe\npanelVisible=false\n", true);
        UIManager.render();
        check(draws[0] == 1 && draws[1] == 0, "closed inspector still rendered");
        check(speed.getCurrentGameSpeed() == 0 && GameTime.getInstance().getTrueMultiplier() == multiplier,
            "inspection command changed native time owners");
        check(IsoPlayer.getInstance() == player && IsoCamera.getCameraCharacter() == camera
            && IsoPlayer.players[0].getX() == px && IsoPlayer.players[0].getY() == py
            && IsoCamera.getCameraCharacter().getX() == vx && IsoCamera.getCameraCharacter().getY() == vy,
            "inspection command changed native camera or residency owners");
        command(control, "opponentShare=0.75\nopportunitiesPerHour=30\nmaxDepth=4\n", true);
        check(Double.valueOf(0.75).equals(LuaManager.env.rawget("modelShare"))
            && Double.valueOf(30).equals(LuaManager.env.rawget("modelRate"))
            && Double.valueOf(4).equals(LuaManager.env.rawget("modelDepth")), "cognition settings did not reach Lua receiver");
        double cognitiveCalls = (Double) LuaManager.env.rawget("calls");
        command(control, "opponentShare=0.5\nopportunitiesPerHour=61\nmaxDepth=4\n", false);
        command(control, "opponentShare=NaN\nopportunitiesPerHour=30\nmaxDepth=4\n", false);
        command(control, "opponentShare=0.5\nopportunitiesPerHour=30\nmaxDepth=5\n", false);
        command(control, "opponentShare=0.5\nopportunitiesPerHour=30\n", false);
        command(control, "opponentShare=0.5\nopportunitiesPerHour=30\nmaxDepth=4\nviewX=44\n", false);
        check(((Double) LuaManager.env.rawget("calls")) == cognitiveCalls, "invalid cognition request reached Lua receiver");
        LuaManager.env.rawset("permit", false);
        command(control, "opponentShare=0.5\nopportunitiesPerHour=30\nmaxDepth=4\n", false);
        LuaManager.env.rawset("permit", true);
        check(speed.getCurrentGameSpeed() == 0 && GameTime.getInstance().getTrueMultiplier() == multiplier
            && IsoPlayer.getInstance() == player && IsoCamera.getCameraCharacter() == camera
            && IsoPlayer.players[0].getX() == px && IsoPlayer.players[0].getY() == py
            && IsoCamera.getCameraCharacter().getX() == vx && IsoCamera.getCameraCharacter().getY() == vy,
            "cognition settings changed camera, residency or time");
        UIManager.UI.remove(avatar);
        System.out.println("PASS native inspection: paused selection; complete validation before dispatch; failed Lua acknowledgement rejected; only explicit native UI element rendered; camera, residency and time preserved. No pixel or live inventory claim.");
    }
}
