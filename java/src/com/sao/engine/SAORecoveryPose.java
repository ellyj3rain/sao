package com.sao.engine;

/** Pure observation of the installed ground-recovery animation, never a pose request. */
public final class SAORecoveryPose {
    private SAORecoveryPose() {}

    public static boolean isRecoveryPose(SAOIsoPlayerShell body, String kind) {
        String nodeName;
        String clipName;
        if ("sleep".equals(kind)) {
            nodeName = "sit_loop_Sleep";
            clipName = "Bob_Asleep";
        } else if ("rest".equals(kind)) {
            nodeName = "sit_loop_Awake";
            clipName = "Bob_Awake";
        } else return false;
        try {
            boolean onBed=body!=null && body.isOnBed();
            if(onBed) {
                if(body.getSitOnFurnitureObject()==null)return false;
                nodeName="sleep".equals(kind)?"OnBedAsleep":"OnBedAwake";
            }
            // The public native getter can allocate/release a player. Reuse the pure reader.
            var player = SAOOrientationAnimation.nativePlayer(body);
            if (player == null || !player.hasSkinningData()) return false;
            var tracks = player.getMultiTrack().getTracks();
            for (int i = 0; i < tracks.size(); i++) {
                var track = tracks.get(i);
                if (track == null || track.animLayer == null || track.getClip() == null
                        || !clipName.equals(track.getClip().name)) continue;
                float trackWeight = track.getBlendWeight();
                if (!Float.isFinite(trackWeight) || trackWeight <= 0) continue;
                var nodes = track.animLayer.getLiveAnimNodes();
                for (int j = 0; j < nodes.size(); j++) {
                    var node = nodes.get(j);
                    var source = node.getSourceNode();
                    if (source == null || !nodeName.equals(source.name) || source.parentState == null
                            || (onBed ? !"onbed".equals(source.parentState.name)
                                : !"sitonground-sitting".equals(source.parentState.name))
                            || !node.isActive() || !node.isMainAnimActive()
                            || !node.containsMainAnimationTrack(track)) continue;
                    float nodeWeight = node.getWeight();
                    if (Float.isFinite(nodeWeight) && nodeWeight > 0) return true;
                }
            }
        } catch (RuntimeException unavailable) { return false; }
        return false;
    }
}
