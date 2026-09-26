package com.sao.engine;

import java.lang.reflect.Field;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.component.CharacterInputComponent;
import zombie.iso.IsoCell;
import zombie.iso.IsoCamera;
import zombie.iso.Vector2;

/**
 * The NPC body class. Construction alone is not enough for a drawn, safe NPC:
 * the body must be registered with ModelManager and hold an off-slot
 * playerIndex (SAOBridge does both), and this subclass must patch the following
 * behaviors below, whose semantics were established against a working
 * IsoPlayer-NPC implementation and this build's engine:
 *
 * - isLocalPlayer() -> true: zombie target/attack checks gate on it; cursor
 *   safety comes from the off-slot playerIndex, not from this flag.
 * - getAimVector -> forward direction: an off-slot body has no mouse or
 *   controller aim source; its controller sets facing explicitly.
 * - updateLOS -> no-op: the inherited implementation writes per-player alpha
 *   channels from this character's viewpoint and would fade the real player.
 * - update()/postupdate() -> preserve the global player and camera owners.
 *   Native updates assign local-player receivers to these globals even when
 *   the receiver is an off-slot NPC; camera/UI/Lua must keep their prior owners.
 */
public final class SAOIsoPlayerShell extends IsoPlayer {

    private static Field cameraCharacterField;

    private final CharacterInputComponent isolatedInput = new CharacterInputComponent();

    /** [C29] The body's size, 1 for an adult. Read on the render path by
     *  SAOBodyScale after the animation player builds this body's model
     *  transforms; written by the bridge (setBodyScale) from the
     *  person's age. A public field because the advice reads it per
     *  frame and a shell is the only kind of character that carries one. */
    public volatile float bodyScale = 1f;

    /** [C31] How fast this body learns: 1 for anyone grown, a quarter
     *  under ten and a half under fourteen (Growing Up's throttle,
     *  CREDITS.md). Read by the bridge's grantXP on every grant;
     *  written once at materialize from the person's age. */
    public volatile float xpScale = 1f;

    /** A captured body awaiting removal must not advance beyond its snapshot. */
    public boolean removalPending;
    public boolean populationAccounted;

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
        if (removalPending) return;
        IsoPlayer keep = IsoPlayer.getInstance();
        IsoGameCharacter camera = IsoCamera.getCameraCharacter();
        try {
            super.update();
        } finally {
            restoreGlobalOwners(keep, camera);
        }
    }

    @Override
    public void postupdate() {
        if (removalPending) return;
        IsoPlayer keep = IsoPlayer.getInstance();
        IsoGameCharacter camera = IsoCamera.getCameraCharacter();
        try {
            super.postupdate();
        } finally {
            restoreGlobalOwners(keep, camera);
        }
    }

    private static void restoreGlobalOwners(IsoPlayer keep, IsoGameCharacter camera) {
        IsoPlayer.setInstance(keep);
        if (IsoCamera.getCameraCharacter() == camera || IsoCamera.setCameraCharacter(camera)) return;
        // The native setter refuses IsoDummyCameraCharacter even though the
        // follow API can install one. Restore that exact prior owner without
        // replaying follow's UI side effects.
        try {
            if (cameraCharacterField == null) {
                cameraCharacterField = IsoCamera.class.getDeclaredField("isoCameraGameCharacter");
                cameraCharacterField.setAccessible(true);
            }
            cameraCharacterField.set(null, camera);
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("Cannot restore native camera owner", failure);
        }
    }
}
