package com.sao.agent;

import com.sao.bridge.SAOBridgeBootstrap;
import java.io.IOException;
import java.lang.instrument.Instrumentation;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;

/**
 * Java-agent entry point for the Survivor Awareness Overhaul engine seam.
 *
 * Exists because two things cannot be done from Kahlua: defining an IsoPlayer
 * subclass (required by Build 42's exact-class render filter, F-009) and
 * exposing new classes into the Lua environment. Everything else stays in Lua.
 */
public final class SAOAgent {
    private static final String LOG_NAME = "SAOAgent.log";

    private SAOAgent() {
    }

    public static void premain(String arguments, Instrumentation instrumentation) {
        log("agent start arguments=" + arguments);
        try {
            Class.forName("zombie.characters.IsoPlayer", false, ClassLoader.getSystemClassLoader());
            log("verified zombie.characters.IsoPlayer on system classpath");
        } catch (ClassNotFoundException exception) {
            log("ERROR IsoPlayer not loadable: " + exception);
            return;
        }
        instrumentation.addTransformer(new SAOMeleeTransformer(), false);
        log("melee callback transformer installed");
        SAOBridgeBootstrap.start();
    }

    public static void agentmain(String arguments, Instrumentation instrumentation) {
        premain(arguments, instrumentation);
    }

    public static void log(String message) {
        Path logFile = Path.of(System.getProperty("user.home"), "Zomboid", LOG_NAME);
        String line = Instant.now() + " [SAO] " + message + System.lineSeparator();
        try {
            Files.createDirectories(logFile.getParent());
            Files.writeString(logFile, line, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException exception) {
            System.err.print(line);
        }
    }
}
