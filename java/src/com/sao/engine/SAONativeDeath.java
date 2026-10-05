package com.sao.engine;

import java.lang.reflect.Field;
import zombie.characters.IsoGameCharacter;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.objects.IsoDeadBody;

/** Read-only evidence of this shell's completed native corpse construction. */
public final class SAONativeDeath {
    private static final Field DIED_BODY = corpseField();

    private SAONativeDeath() { }

    private static Field corpseField() {
        try {
            Field field = IsoGameCharacter.class.getDeclaredField("diedBody");
            field.setAccessible(true);
            return field;
        } catch (ReflectiveOperationException | RuntimeException unavailable) {
            return null;
        }
    }

    private static IsoDeadBody corpse(SAOIsoPlayerShell shell) {
        // die() sets onDeathDone even on an exception or a pending client
        // handoff. Only its receiver's native corpse pointer proves creation.
        if (shell == null || !shell.isDead() || !shell.isOnDeathDone() || DIED_BODY == null) return null;
        try {
            return (IsoDeadBody) DIED_BODY.get(shell);
        } catch (IllegalAccessException unavailable) {
            return null;
        }
    }

    public static boolean hasCorpse(SAOIsoPlayerShell shell) {
        return corpse(shell) != null;
    }

    /** Creation and relinquished living-body ownership are separate events. */
    public static boolean isDetached(SAOIsoPlayerShell shell) {
        IsoDeadBody body = corpse(shell);
        if (body == null || shell.getCurrentSquare() != null || shell.getLastSquare() != null) return false;
        IsoCell cell = shell.getCell();
        if (cell == null || cell.getObjectList().contains(shell)
                || cell.getAddList().contains(shell) || cell.getRemoveList().contains(shell)) return false;
        // getSquare() may retain the old location after native removal; actual
        // list membership, rather than that location hint, owns representation.
        return absent(shell, shell.getSquare()) && absent(shell, body.getSquare());
    }

    private static boolean absent(SAOIsoPlayerShell shell, IsoGridSquare square) {
        return square == null || (!square.getMovingObjects().contains(shell)
                && !square.getStaticMovingObjects().contains(shell));
    }
}
