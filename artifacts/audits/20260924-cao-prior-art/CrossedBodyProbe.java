import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import zombie.characters.IsoZombie;
import sun.misc.Unsafe;

// Isolated type-boundary probe. No game, window, save or world is created.
public final class CrossedBodyProbe {
    public static void main(String[] args) throws Exception {
        var field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        var unsafe = (Unsafe) field.get(null);
        Object zombie = unsafe.allocateInstance(IsoZombie.class);
        Object shell = unsafe.allocateInstance(SAOIsoPlayerShell.class);
        if (!SAOBridge.INSTANCE.isShell(shell)) throw new AssertionError("shell control rejected");
        if (SAOBridge.INSTANCE.isShell(zombie)) throw new AssertionError("zombie treated as shell");
        String move = SAOBridge.INSTANCE.moveTo(zombie, 1, 1, 0);
        if (!"NOT_A_SHELL".equals(move)) throw new AssertionError("unexpected move result: " + move);
        System.out.println("SHELL_CONTROL=true ZOMBIE_SHELL=false ZOMBIE_MOVE=" + move);
    }
}
