package com.sao;

import com.sao.agent.SAOAgent;
import com.sao.agent.SAOViewpointShellVisibilityWeave;
import com.sao.agent.SAOViewpointFrameTelemetry;
import me.zed_0xff.zombie_buddy.PatchEngine;
import zombie.network.GameServer;

/** Starts the bundled viewpoint renderer from SAO's sole ZombieBuddy entry. */
public final class SAOViewpointBootstrap {
    private static final Activation ACTIVATION = new Activation();

    private SAOViewpointBootstrap() {
    }

    public static void start() {
        String result = ACTIVATION.start(new NativeRuntime());
        SAOAgent.log("viewpoint bundle: " + result);
    }

    interface Runtime {
        boolean dedicated();

        boolean supportedBuild();

        void initialize();

        void registerPatches();
    }

    static final class Activation {
        private boolean attempted;

        synchronized String start(Runtime runtime) {
            if (attempted) {
                return "already-attempted";
            }
            try {
                // The same SAO.jar loads on a dedicated server. The renderer
                // must never initialize there or on an unsupported game JAR.
                if (runtime.dedicated()) {
                    return "dedicated-server";
                }
                if (!runtime.supportedBuild()) {
                    return "unsupported-game-build";
                }
                attempted = true;
                runtime.initialize();
                runtime.registerPatches();
                return "registered";
            } catch (Throwable failure) {
                attempted = true;
                SAOAgent.log("viewpoint bundle activation failed: " + failure);
                return "failed";
            }
        }
    }

    private static final class NativeRuntime implements Runtime {
        @Override
        public boolean dedicated() {
            return GameServer.server;
        }

        @Override
        public boolean supportedBuild() {
            return viewpoint.platform.BuildPin.supported();
        }

        @Override
        public void initialize() {
            viewpoint.Main.main(new String[0]);
        }

        @Override
        public void registerPatches() {
            // ZombieBuddy scans only javaPkgName=com.sao for SAO.jar. Its
            // normal patch registry therefore needs this explicit package.
            if (!SAOViewpointShellVisibilityWeave.install()) {
                throw new IllegalStateException("Viewpoint staged-body capture weave "
                    + SAOViewpointShellVisibilityWeave.report());
            }
            if (!SAOViewpointFrameTelemetry.install()) {
                // Native capture will mark camera provenance unavailable. A
                // missing observation weave must not disable normal gameplay.
                SAOAgent.log("viewpoint frame telemetry unavailable: "
                    + SAOViewpointFrameTelemetry.report());
            }
            PatchEngine.applyPatches("viewpoint", null);
        }
    }
}
