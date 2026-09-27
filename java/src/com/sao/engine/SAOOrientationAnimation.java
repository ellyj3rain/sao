package com.sao.engine;

import java.io.File;
import java.lang.reflect.Field;
import java.util.WeakHashMap;
import zombie.ZomboidFileSystem;
import zombie.characters.action.ActionGroup;
import zombie.core.skinnedmodel.advancedanimation.AnimNode;
import zombie.core.skinnedmodel.advancedanimation.AnimState;
import zombie.core.skinnedmodel.advancedanimation.AnimationSet;

/** Additive native head layer. No native player head-input flag is enabled. */
public final class SAOOrientationAnimation {
    public static final String STATE = "sao-orienting";
    public static final String ACTIVE = "saoOrientationActive";
    public static final String HORIZONTAL = "saoLookHorizontal";
    public static final String VERTICAL = "saoLookVertical";
    private static final String ROOT = "media/SAOOrienting/";
    private static final String[] ROOT_STATES = {"idle", "movement", "run", "sprint"};
    private static final String[] CLIPS = {"Bob_LookLeft", "Bob_LookRight", "Bob_LookUp", "Bob_LookDown"};
    private static final WeakHashMap<ActionGroup, Boolean> GROUPS = new WeakHashMap<>();
    private static final WeakHashMap<AnimationSet, Boolean> SETS = new WeakHashMap<>();
    private static volatile String readFailure;
    private static final Field PLAYER = playerField();

    private SAOOrientationAnimation() {}
    private static Field playerField() {
        try {
            Field field = zombie.characters.IsoGameCharacter.class.getDeclaredField("animPlayer");
            field.setAccessible(true); return field;
        } catch (ReflectiveOperationException | RuntimeException failure) {
            readFailure = "native-animation-read-unavailable:" + failure.getClass().getSimpleName();
            return null;
        }
    }
    /** getAnimationPlayer can release/allocate on a model change; no public pure getter exists. */
    static zombie.core.skinnedmodel.animation.AnimationPlayer nativePlayer(zombie.characters.IsoGameCharacter shell) {
        if (shell == null || PLAYER == null) return null;
        try { return (zombie.core.skinnedmodel.animation.AnimationPlayer)PLAYER.get(shell); }
        catch (IllegalAccessException | RuntimeException failure) {
            readFailure = "native-animation-read-unavailable:" + failure.getClass().getSimpleName();
            return null;
        }
    }
    static String readFailure() { return readFailure; }
    private static File asset(String name) {
        return new File(ZomboidFileSystem.instance.getString(ROOT + name));
    }

    public static boolean admittedRoot(String name) {
        for (String root : ROOT_STATES) if (root.equals(name)) return true;
        return false;
    }

    /** Native parse appends; native tags, transitions, actions and state mappings survive. */
    public static synchronized boolean ensure(SAOIsoPlayerShell shell) {
        try {
            var player = nativePlayer(shell);
            if (player == null || !player.hasSkinningData()) return false;
            for (String clip : CLIPS) if (!player.getSkinningData().animationClips.containsKey(clip)) return false;
            var animator = shell.getAdvancedAnimator();
            AnimationSet set = animator == null ? null : animator.animSet;
            ActionGroup group = shell.getActionContext().getGroup();
            if (set == null || group == null || !"player".equals(group.getName())) return false;
            for (String file : new String[]{"look.xml", "tags.xml", "children.xml", "enter.xml", "exit.xml"}) {
                if (!asset(file).isFile()) return false;
            }
            if (!SETS.containsKey(set)) {
                AnimNode node = AnimNode.Parse(asset("look.xml").getPath());
                if (node == null || node.blends2d.size() != 4 || node.blend2dPicker == null) return false;
                AnimState state = new AnimState(); state.name = STATE; state.set = set;
                node.parentState = state; state.addNode(node);
                set.states.put(STATE, state); SETS.put(set, true);
            }
            if (!GROUPS.containsKey(group)) {
                var child = group.getOrCreate(STATE);
                child.parse(asset("tags.xml")); child.parse(asset("exit.xml")); child.sortTransitions();
                for (String name : ROOT_STATES) {
                    var parent = group.findState(name);
                    if (parent == null) continue;
                    parent.parse(asset("children.xml")); parent.parse(asset("enter.xml")); parent.sortTransitions();
                }
                GROUPS.put(group, true);
            }
            return true;
        } catch (Throwable unavailable) { return false; }
    }

    /** Read only tracks actually admitted by the native animator, including fade-out. */
    public static float physicalHeadOffset(SAOIsoPlayerShell shell) {
        var player = nativePlayer(shell);
        if (player == null || !player.hasSkinningData()) return 0;
        float horizontal = 0;
        for (var track : player.getMultiTrack().getTracks()) {
            if (track == null || track.animLayer == null || !ownedTrack(track)
                    || track.getClip() == null || !track.hasBoneMask()) continue;
            float weight = track.getBlendWeight();
            if (!Float.isFinite(weight) || weight <= 0) continue;
            if ("Bob_LookRight".equals(track.getClip().name)) horizontal += weight;
            if ("Bob_LookLeft".equals(track.getClip().name)) horizontal -= weight;
        }
        // PZ's getLookAngleRadians adds native head-look scalar to body+twist.
        // Here the scalar is the actual layer blend, never the requested target.
        return Math.max(-1, Math.min(1, horizontal));
    }

    private static boolean ownedTrack(zombie.core.skinnedmodel.animation.AnimationTrack track) {
        // A layer's current state can already be empty while its old node fades out.
        for (var node : track.animLayer.getLiveAnimNodes()) {
            var source = node.getSourceNode();
            if (source != null && source.parentState != null && STATE.equals(source.parentState.name)
                    && node.containsMainAnimationTrack(track)) return true;
        }
        return false;
    }
}
