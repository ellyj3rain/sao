import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOMovement;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.component.AIComponent;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.iso.IsoCell;
import zombie.iso.Vector2;
import zombie.iso.sprite.IsoSprite;

/** Controlled native body only: no attach, camera command, save or live mutation. */
public final class MotionIntentProbe {
    /** Only input is controlled; the installed private input transform runs unchanged. */
    static final class HumanInput extends IsoPlayer {
        float inputX, inputY;
        HumanInput(IsoCell cell, SurvivorDesc desc) { super(cell, desc, 10, 20, 0, false); }
        @Override public Vector2 getInputMoveVector(Vector2 out) { return out.set(inputX, inputY); }
        @Override public Vector2 getAimVector(Vector2 out) { return getForwardDirection(out); }
        // The last input-method branch resets the player UI speed control.
        // This fixture has no UI; retain the native justMoved write and test
        // only the movement transform before that unrelated final branch.
        @Override public boolean isJustMoved() { return false; }
    }
    static Field field(Class<?> type, String name) throws Exception {
        Field value = type.getDeclaredField(name); value.setAccessible(true); return value;
    }
    static void check(String name, boolean value) {
        System.out.println("CHECK " + name + "=" + value);
        if (!value) throw new AssertionError(name);
    }
    public static void main(String[] args) throws Exception {
        Method boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        IsoCell cell = (IsoCell)boot.invoke(null);
        Method person = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class);
        person.setAccessible(true);
        SAOIsoPlayerShell shell = (SAOIsoPlayerShell)person.invoke(null, cell);
        AnimationPlayer animation = (AnimationPlayer)field(IsoGameCharacter.class, "animPlayer").get(shell);
        SkinningData skin = new SkinningData(new HashMap<>(), new ArrayList<>(), new ArrayList<>(),
            new ArrayList<>(), new ArrayList<>(), new HashMap<>());
        field(AnimationPlayer.class, "skinningData").set(animation, skin);
        field(AnimationPlayer.class, "boneTransformsNeedFirstFrame").setBoolean(animation, false);
        SurvivorDesc humanDesc = new SurvivorDesc(false);
        humanDesc.getHumanVisual().setSkinTextureName("fixture");
        HumanInput human = new HumanInput(cell, humanDesc);
        human.setCurrent(cell.getGridSquare(10, 20, 0));
        human.setIsAiming(true);
        var model = new zombie.core.skinnedmodel.model.ModelInstance(); model.animPlayer = animation;
        var sprite = new IsoSprite();
        sprite.modelSlot = new zombie.core.skinnedmodel.ModelManager.ModelSlot(0, model, human);
        field(IsoGameCharacter.class, "legsSprite").set(human, sprite);
        field(IsoGameCharacter.class, "animPlayer").set(human, animation);
        Method nativeInput = IsoPlayer.class.getDeclaredMethod("updateMovementFromInput", IsoPlayer.MoveVars.class);
        nativeInput.setAccessible(true);
        check("native_human_is_strafing", human.isStrafing() && !human.isNpc());
        Method drive = SAOMovement.class.getDeclaredMethod("drive", SAOIsoPlayerShell.class,
            float.class, float.class, boolean.class); drive.setAccessible(true);
        check("installed_animation_ready", animation.isReady() && !animation.isBoneTransformsNeedFirstFrame());
        int parity = 0;
        for (int angle = 0; angle < 8; angle++) {
            float radians = (float)(angle * Math.PI / 4);
            animation.setAngle(radians);
            check("native_rendered_angle_offset_" + angle,
                Math.abs(animation.getRenderedAngle() - radians - (float)(Math.PI / 2)) < .00001f);
            for (int target = 0; target < 8; target++) {
                float heading = (float)(target * Math.PI / 4);
                float dx = (float)Math.cos(heading), dy = (float)Math.sin(heading);
                boolean running = target % 2 == 1;
                drive.invoke(null, shell, shell.getX() + dx * 4, shell.getY() + dy * 4, running);
                check("native_direction_degrees_" + angle + "_" + target,
                    Math.abs(shell.getForwardDirection().x - dx) < .0001f
                    && Math.abs(shell.getForwardDirection().y - dy) < .0001f);
                Vector2 nativeExpected = new Vector2(dx, -dy);
                nativeExpected.normalize(); nativeExpected.rotate(animation.getRenderedAngle());
                human.inputX = (dx - dy) / 2; human.inputY = (dx + dy) / 2;
                human.setDirectionAngle((float)Math.toDegrees(heading));
                IsoPlayer.MoveVars nativeVars = new IsoPlayer.MoveVars();
                nativeInput.invoke(human, nativeVars);
                check("actual_human_input_moved_" + angle + "_" + target,
                    field(IsoPlayer.class, "justMoved").getBoolean(human));
                check("actual_human_input_basis_" + angle + "_" + target,
                    Math.hypot(nativeVars.strafeX - nativeExpected.x, nativeVars.strafeY - nativeExpected.y) < .0001f);
                var actual = shell.getECSComponent(AIComponent.class).getHumanControlVars();
                float error = (float)Math.hypot(actual.strafeX - nativeVars.strafeX,
                    actual.strafeY - nativeVars.strafeY);
                float dot = actual.strafeX * nativeExpected.x + actual.strafeY * nativeExpected.y;
                System.out.printf("PARITY angle=%d target=%d actual=%.6f,%.6f native=%.6f,%.6f error=%.6f dot=%.6f%n",
                    angle, target, actual.strafeX, actual.strafeY, nativeExpected.x, nativeExpected.y, error, dot);
                check("native_control_basis_" + angle + "_" + target, error < .0001f);
                check("native_pace_" + angle + "_" + target, actual.justMoved && actual.running == running);
                parity++;
            }
        }
        System.out.println("MOTION INTENT PASS parityCases=" + parity);
    }
}
