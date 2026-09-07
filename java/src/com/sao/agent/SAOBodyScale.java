package com.sao.agent;

import com.sao.engine.SAOIsoPlayerShell;
import org.lwjgl.util.vector.Matrix4f;
import zombie.characters.IsoGameCharacter;
import zombie.core.skinnedmodel.animation.AnimationPlayer;

/**
 * [C29] A body's size, applied from inside the animation player.
 *
 * The vanilla renderer scales no character on its own: the model
 * instance's scale field is read by the vehicle class alone, and the
 * model script's scale only by the world-object and item drawers
 * (ENGINE_CONTRACT Addendum F). What the renderer DOES read is the
 * animation player's per-bone model transforms - built in
 * updateModelTransformsInternal from each bone's local transform times
 * its parent's, then multiplied by the skinning bone offsets in
 * getSkinTransforms and drawn by Model. So the one place a body can
 * change size is right after those model transforms are built, and
 * SAOBodyScaleWeave puts a call to {@link #apply(Object)} there.
 *
 * Only SAO's own people carry a scale ({@link SAOIsoPlayerShell#bodyScale});
 * every other character costs one instanceof and returns. The scale is
 * uniform about the model origin, which is at the feet, so a scaled
 * body stands where it stood.
 */
public final class SAOBodyScale {
    public static final float MIN = 0.30f;
    public static final float MAX = 2.00f;

    private static volatile long calls;
    private static volatile long scaled;
    private static volatile String lastError;

    private SAOBodyScale() {
    }

    /** Woven into AnimationPlayer.updateModelTransformsInternal (exit).
     *  Takes Object so the advice needs no game type on its own. */
    public static void apply(Object playerObject) {
        calls++;
        try {
            if (!(playerObject instanceof AnimationPlayer player)) {
                return;
            }
            float scale = scaleFor(player);
            if (scale == 1f) {
                return;
            }
            int count = player.getModelTransformsCount();
            for (int index = 0; index < count; index++) {
                Matrix4f matrix = player.getModelTransformAt(index);
                if (matrix != null) {
                    scaleMatrix(matrix, scale);
                }
            }
            scaled++;
        } catch (Throwable throwable) {
            lastError = String.valueOf(throwable);
        }
    }

    /** The scale a player's character asks for: 1 unless it is one of
     *  ours. An attached player without a character of its own takes
     *  its parent's, so what a body holds is drawn at the body's size. */
    static float scaleFor(AnimationPlayer player) {
        IsoGameCharacter character = player.getIsoGameCharacter();
        if (character == null && player.parentPlayer != null) {
            character = player.parentPlayer.getIsoGameCharacter();
        }
        if (character instanceof SAOIsoPlayerShell shell) {
            return clamp(shell.bodyScale);
        }
        return 1f;
    }

    /** S times M, in place: every entry except the homogeneous row.
     *  lwjgl's Matrix4f is column-major - mCR is column C, row R - so
     *  the homogeneous row is m03, m13, m23, m33 and stays; the
     *  translation column m30..m32 scales with the rest, which is what
     *  makes the scale uniform about the model origin. */
    public static void scaleMatrix(Matrix4f matrix, float scale) {
        matrix.m00 *= scale;
        matrix.m01 *= scale;
        matrix.m02 *= scale;
        matrix.m10 *= scale;
        matrix.m11 *= scale;
        matrix.m12 *= scale;
        matrix.m20 *= scale;
        matrix.m21 *= scale;
        matrix.m22 *= scale;
        matrix.m30 *= scale;
        matrix.m31 *= scale;
        matrix.m32 *= scale;
    }

    /** NaN, zero and negatives are not sizes; out-of-range asks are held
     *  to the range rather than refused, so a bad curve shows as a very
     *  small or very large person and not as an invisible one. */
    public static float clamp(float scale) {
        if (Float.isNaN(scale) || scale <= 0f) {
            return 1f;
        }
        return Math.max(MIN, Math.min(MAX, scale));
    }

    /** "calls=..|scaled=..[|error=..]": calls is every exit of the woven
     *  method, scaled the ones that found one of ours below or above 1. */
    public static String report() {
        String error = lastError;
        return "calls=" + calls + "|scaled=" + scaled
            + (error == null ? "" : "|error=" + error);
    }
}
