import java.lang.reflect.Method;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOPerceptionScanner;
import zombie.iso.*;

/** Production visibility and installed LOS on controlled loaded geometry. */
public final class UpperFloorSightProbe {
    private static int checks;
    private static void check(String name, boolean result) {
        System.out.println("CHECK " + name + "=" + result);
        if (!result) throw new AssertionError(name);
        checks++;
    }
    private static void position(SAOIsoPlayerShell body, IsoCell cell, float x, float y, int z) {
        body.setX(x); body.setY(y); body.setZ(z);
        body.setCurrent(cell.getGridSquare((int) x, (int) y, z));
        body.setForwardDirection(1,0);
    }
    public static void main(String[] args) throws Exception {
        Method boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        IsoCell cell = (IsoCell) boot.invoke(null);
        Method person = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class); person.setAccessible(true);
        SAOIsoPlayerShell eye = (SAOIsoPlayerShell) person.invoke(null, cell);
        SAOIsoPlayerShell target = (SAOIsoPlayerShell) person.invoke(null, cell);
        for (int x=9; x<=25; x++) for (int y=19; y<=22; y++) {
            IsoGridSquare ground = cell.getGridSquare(x,y,0);
            IsoGridSquare upper = new IsoGridSquare(cell,null,x,y,1);
            upper.chunk=ground.chunk;
            ground.chunk.setSquare(x%8,y%8,1,upper);
        }
        position(eye,cell,10.5f,20.5f,0); position(target,cell,14.5f,20.5f,0);
        check("same_floor_visible",SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        position(eye,cell,10.5f,20.5f,1);
        check("native_upper_floor_clear",LosUtil.lineClear(cell,10,20,1,14,20,0,false)==LosUtil.TestResults.Clear);
        check("upper_floor_can_acquire_person",SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        check("lower_floor_opposite_facing_refuses",!SAOPerceptionScanner.canSeePersonNow(target,eye,14));
        target.setForwardDirection(-1,0);
        check("lower_floor_facing_upper_person",SAOPerceptionScanner.canSeePersonNow(target,eye,14));
        eye.setForwardDirection(-1,0);
        check("upper_floor_retains_facing_limit",!SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        eye.setForwardDirection(1,0);
        check("upper_floor_retains_action_range",!SAOPerceptionScanner.canSeePersonNow(eye,target,3));
        position(target,cell,25.5f,20.5f,0);
        check("upper_floor_retains_sight_range",!SAOPerceptionScanner.canSeePersonNow(eye,target,99));
        position(target,cell,14.5f,20.5f,0);
        for (int x=9; x<=25; x++) for (int y=19; y<=22; y++) for(int z=0;z<=1;z++)
            cell.getGridSquare(x,y,z).visionMatrix=-1;
        check("native_upper_floor_blocked",LosUtil.lineClear(cell,10,20,1,14,20,0,false)==LosUtil.TestResults.Blocked);
        check("upper_floor_occlusion_refuses",!SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        for (int x=9; x<=25; x++) for (int y=19; y<=22; y++) for(int z=0;z<=1;z++)
            cell.getGridSquare(x,y,z).visionMatrix=0;
        check("upper_floor_reopened_visible",SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        target.getModData().rawset("SAOPersonId","sao-ground-person");
        target.getDescriptor().setForename("Ground"); target.getDescriptor().setSurname("Person");
        cell.getObjectList().add(target);
        String acquired=SAOPerceptionScanner.scan(eye);
        check("upper_floor_scanner_emits_person",acquired.contains("P:Ground Person:"));
        check("scanner_retains_actual_target_floor",acquired.contains(":floor:0"));
        check("invalid_range_refused",!SAOPerceptionScanner.canSeePersonNow(eye,target,Float.NaN));
        target.setX(Float.NaN);
        check("invalid_position_refused",!SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        position(target,cell,14.5f,20.5f,0);
        target.setCurrent(new IsoGridSquare(cell,null,14,20,0));
        check("unloaded_square_refused",!SAOPerceptionScanner.canSeePersonNow(eye,target,14));
        System.out.println("PASS upper-floor-sight checks="+checks);
        System.exit(0);
    }
}
