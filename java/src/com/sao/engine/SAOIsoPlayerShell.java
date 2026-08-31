package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.lang.reflect.Field;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.component.CharacterInputComponent;
import zombie.iso.IsoCell;
import zombie.iso.Vector2;

/**
 * The NPC body class. Construction alone is not enough for a drawn, safe NPC:
 * the body must be registered with ModelManager and hold an off-slot
 * playerIndex (SAOBridge does both), and this subclass must patch the four
 * behaviors below, whose semantics were established against a working
 * IsoPlayer-NPC implementation and this build's engine:
 *
 * - isLocalPlayer() -> true: zombie target/attack checks gate on it; cursor
 *   safety comes from the off-slot playerIndex, not from this flag.
 * - getAimVector -> forward direction: an off-slot body has no mouse or
 *   controller aim source; its controller sets facing explicitly.
 * - updateLOS -> no-op: the inherited implementation writes per-player alpha
 *   channels from this character's viewpoint and would fade the real player.
 * - update() -> preserve the engine's global "the player" reference:
 *   IsoPlayer.updateInternal2 assigns the receiver to it even when the
 *   receiver is an NPC; camera/UI/Lua would then resolve an NPC as the player.
 */
public final class SAOIsoPlayerShell extends IsoPlayer {

    private static Field instanceField;
    private static boolean instanceFieldFailed;

    private final CharacterInputComponent isolatedInput = new CharacterInputComponent();

    public SAOIsoPlayerShell(IsoCell cell, SurvivorDesc desc, int x, int y, int z) {
        super(cell, desc, x, y, z, false);
    }

    @Override
    public boolean isLocalPlayer() {
        return true;
    }

    @Override
    public Vector2 getAimVector(Vector2 out) {
        return getForwardDirection(out);
    }

    @Override
    public void updateLOS() {
        // Deliberate no-op; see class comment.
    }

    @Override
    public CharacterInputComponent getCharacterInputComponent() {
        return isolatedInput;
    }

    @Override
    public void update() {
        IsoPlayer keep = IsoPlayer.getInstance();
        try {
            super.update();
        } finally {
            restoreGlobalInstance(keep);
        }
    }

    private static void restoreGlobalInstance(IsoPlayer keep) {
        if (instanceFieldFailed) {
            return;
        }
        try {
            if (instanceField == null) {
                instanceField = IsoPlayer.class.getDeclaredField("instance");
                instanceField.setAccessible(true);
            }
            if (IsoPlayer.getInstance() != keep) {
                instanceField.set(null, keep);
            }
        } catch (Throwable throwable) {
            instanceFieldFailed = true;
            SAOAgent.log("shell: cannot restore IsoPlayer.instance (" + throwable
                + ") - override disabled");
        }
    }
}
