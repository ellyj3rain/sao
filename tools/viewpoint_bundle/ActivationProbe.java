package com.sao;

import java.util.ArrayList;
import java.util.List;

public final class ActivationProbe {
    private static int passed;

    private static void check(String name, boolean valid) {
        if (!valid) {
            throw new AssertionError(name);
        }
        passed++;
        System.out.println("PASS " + name);
    }

    private static final class Runtime implements SAOViewpointBootstrap.Runtime {
        final List<String> calls = new ArrayList<>();
        boolean dedicated;
        boolean supported;
        String failAt;

        Runtime(boolean dedicated, boolean supported, String failAt) {
            this.dedicated = dedicated;
            this.supported = supported;
            this.failAt = failAt;
        }

        private void called(String name) {
            calls.add(name);
            if (name.equals(failAt)) {
                throw new IllegalStateException(name);
            }
        }

        @Override public boolean dedicated() {
            called("server");
            return dedicated;
        }

        @Override public boolean supportedBuild() {
            called("pin");
            return supported;
        }

        @Override public void initialize() {
            called("main");
        }

        @Override public void registerPatches() {
            called("patches");
        }
    }

    public static void main(String[] args) {
        var server = new SAOViewpointBootstrap.Activation();
        var serverRuntime = new Runtime(true, true, null);
        check("dedicated refused", "dedicated-server".equals(server.start(serverRuntime)));
        check("dedicated never touches renderer", serverRuntime.calls.equals(List.of("server")));

        var unsupported = new SAOViewpointBootstrap.Activation();
        var unsupportedRuntime = new Runtime(false, false, null);
        check("unsupported build refused", "unsupported-game-build".equals(unsupported.start(unsupportedRuntime)));
        check("unsupported build never initializes", unsupportedRuntime.calls.equals(List.of("server", "pin")));

        var client = new SAOViewpointBootstrap.Activation();
        var clientRuntime = new Runtime(false, true, null);
        check("supported client registered", "registered".equals(client.start(clientRuntime)));
        check("client order", clientRuntime.calls.equals(List.of("server", "pin", "main", "patches")));
        check("client only once", "already-attempted".equals(client.start(clientRuntime))
            && clientRuntime.calls.size() == 4);

        var badMain = new SAOViewpointBootstrap.Activation();
        var badMainRuntime = new Runtime(false, true, "main");
        check("main failure contained", "failed".equals(badMain.start(badMainRuntime)));
        check("main failure has no patch", badMainRuntime.calls.equals(List.of("server", "pin", "main")));
        check("main failure no retry", "already-attempted".equals(badMain.start(badMainRuntime)));

        var badPatch = new SAOViewpointBootstrap.Activation();
        var badPatchRuntime = new Runtime(false, true, "patches");
        check("patch failure contained", "failed".equals(badPatch.start(badPatchRuntime)));
        check("patch failure no retry", "already-attempted".equals(badPatch.start(badPatchRuntime)));

        var badGuard = new SAOViewpointBootstrap.Activation();
        var badGuardRuntime = new Runtime(false, true, "server");
        check("server guard failure contained", "failed".equals(badGuard.start(badGuardRuntime)));
        check("server guard failure never initializes", badGuardRuntime.calls.equals(List.of("server")));

        System.out.println("PASS TOTAL " + passed);
    }
}
