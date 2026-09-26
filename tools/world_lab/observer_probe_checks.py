"""Installed-engine observer method checks, with production-source controls.

This starts only short-lived Java probe processes. It does not initialize a
native game world, OpenGL context, game window, or physical simulation loop.
"""
from pathlib import Path
import os
import re
import subprocess


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools" / "world_lab"


def _execute(command, prefix, *, expected=None):
    result = subprocess.run([str(arg) for arg in command], cwd=ROOT, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=90)
    prefix.with_suffix(".stdout.log").write_text(result.stdout, encoding="utf-8")
    prefix.with_suffix(".stderr.log").write_text(result.stderr, encoding="utf-8")
    output = result.stdout + result.stderr
    if expected is not None:
        if result.returncode == 0 or expected not in output:
            raise AssertionError(f"observer control survived or failed for another reason: {prefix.name}\n{output}")
    elif result.returncode:
        raise AssertionError(f"observer native command failed: {prefix.name}\n{output}")
    return output


def run(tmp, GAME, JDK):
    """Compile the actual host/probe and require each stated defect to be caught."""
    game, jdk = Path(GAME), Path(JDK)
    work = Path(tmp).resolve() / "observer-native"
    classes = work / "classes"
    classes.mkdir(parents=True)
    suffix = ".exe" if os.name == "nt" else ""
    javac, java, jar = (jdk / (name + suffix) for name in ("javac", "java", "jar"))
    native = os.pathsep.join(str(game / name) for name in ("projectzomboid.jar", "ZombieBuddy.jar"))
    _execute([javac, "-encoding", "UTF-8", "-cp", native, "-d", classes,
              *(SOURCE / name for name in ("StudyObserver.java", "StudyLoadingAgent.java",
                                           "StudyViewCapture.java", "NativeObserverProbe.java",
                                           "NativeObserverPreload.java"))], work / "compile")
    manifest, agent = work / "MANIFEST.MF", work / "observer-agent.jar"
    manifest.write_text("Manifest-Version: 1.0\nPremain-Class: StudyLoadingAgent\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
    _execute([jar, "cfm", agent, manifest, "-C", classes, "."], work / "jar")
    preload_manifest, preload = work / "PRELOAD.MF", work / "preload-agent.jar"
    preload_manifest.write_text("Manifest-Version: 1.0\nPremain-Class: NativeObserverPreload\n\n", encoding="utf-8")
    _execute([jar, "cfm", preload, preload_manifest, "-C", classes, "NativeObserverPreload.class"], work / "preload-jar")

    def probe(directory, extra=None, expected=None, preloaded=False):
        directory.mkdir(exist_ok=True)
        user = directory / "home"
        user.mkdir(exist_ok=True)
        dump = directory / "dump"
        dump.mkdir(exist_ok=True)
        classpath = os.pathsep.join(str(p) for p in ([extra] if extra else []) + [classes]) + os.pathsep + native
        return _execute([java, f"-Duser.home={user}", f"-Dnet.bytebuddy.dump={dump}", "-Dstudy.observer=true",
                         *([f"-javaagent:{preload}"] if preloaded else []),
                         f"-javaagent:{agent}=isolated-study", "--enable-native-access=ALL-UNNAMED",
                         "-cp", classpath, "NativeObserverProbe"], directory / "probe", expected=expected)

    output = probe(work / "baseline")
    def binding(directory):
        dumped = [p for p in (directory / "dump").glob("zombie.iso.IsoChunkMap.*.class") if "-original" not in p.name]
        if not dumped:
            raise AssertionError("transformed native chunk map unavailable")
        code = _execute([jdk / ("javap" + suffix), "-p", "-c", max(dumped, key=lambda p: p.stat().st_mtime_ns)],
                        directory / "chunk-binding")
        body = re.split(r"\n  (?:public|private|protected) ", code.split(
            "public void ProcessChunkPos(zombie.characters.IsoGameCharacter);", 1)[1], maxsplit=1)[0]
        if "StudyObserver.admitChunkActor:(Ljava/util/Set;Ljava/lang/Object;)Z" not in body or "java/util/Set.add:" in body:
            raise AssertionError("native far-chunk insertion bypasses observer guard")
        dumped = [p for p in (directory / "dump").glob("zombie.iso.IsoCell.*.class") if "-original" not in p.name]
        if not dumped:
            raise AssertionError("transformed native cell unavailable")
        code = _execute([jdk / ("javap" + suffix), "-p", "-c", max(dumped, key=lambda p: p.stat().st_mtime_ns)],
                        directory / "cell-binding")
        body = re.split(r"\n  (?:public|private|protected) ", code.split(
            "private void updateInternal();", 1)[1], maxsplit=1)[0]
        if "StudyObserver.deadForStreaming:(Lzombie/characters/IsoGameCharacter;)Z" not in body or "IsoPlayer.isDead:" in body:
            raise AssertionError("native chunk delivery bypasses observer eligibility")
    binding(work / "baseline")
    preload_output = probe(work / "preloaded", preloaded=True)
    if "[StudyProbe] IsoChunkMap loaded before observer premain" not in preload_output:
        raise AssertionError("native preload probe did not exercise the stated load order")
    binding(work / "preloaded")
    if "PASS native observer:" not in output:
        raise AssertionError("observer probe returned without its verification receipt")
    # A fixture intentionally asks for a native debugger breakpoint and verifies
    # that it remains a failed state while subsequent controls are still handled.
    # Its explicit FAILED log is expected only in this standalone method probe.
    if "[StudyObserver] FAILED native Lua debugger requested at intentional-probe.lua:7" not in output:
        raise AssertionError("observer native debugger failure was not visible")

    controls = (
        ("scan_basement", "StudyObserver.java", "int z = chunk.getMinLevel();", "int z = 0;", 1,
         "observer scan omitted basement or roof membership"),
        ("scan_roof", "StudyObserver.java", "z <= chunk.getMaxLevel();", "z < chunk.getMaxLevel();", 1,
         "observer scan omitted basement or roof membership"),
        ("scan_loaded", "StudyObserver.java", "chunk == null || !chunk.loaded", "chunk == null", 2,
         "observer scan included undelivered chunks"),
        ("state_transient", "StudyObserver.java", "stateDeferrals >= MAX_STATE_DEFERRALS", "stateDeferrals >= 1", 1,
         "transient state publication poisoned the run"),
        ("state_persistent", "StudyObserver.java", "stateDeferrals >= MAX_STATE_DEFERRALS", "false", 1,
         "persistent state publication denial was hidden"),
        ("state_stop", "StudyObserver.java", "if (published || statePublicationFailed) finishStop();", "finishStop();", 2,
         "stop quit before final state publication"),
        ("owner_admission", "StudyObserver.java", "if (!isObserver(value)) return delegate.add(value);",
         "if (value != this) return delegate.add(value);", 1, "native direct actor publication accepted observer"),
        ("delivery_eligibility", "StudyObserver.java", "streamingChecks++;\n        return false;",
         "streamingChecks++;\n        return value.isDead();", 1, "observer excluded from native chunk delivery"),
        ("delivery_binding", "StudyLoadingAgent.java", '.replaceWith(streaming).on(ElementMatchers.named("updateInternal")))',
         '.replaceWith(streaming).on(ElementMatchers.named("MissingCellMethod")))', 1, "native cell skipped observer chunk delivery"),
        ("streaming", "StudyObserver.java", "return !isObserver(value) && actors.add(value);",
         "return actors.add(value);", 1, "far streaming admitted observer actor"),
        ("birth", "StudyLoadingAgent.java", "return StudyObserver.suppressBirth(event, actor);", "return false;", 1,
         "native constructor birth event was not suppressed before dispatch"),
        ("save", "StudyLoadingAgent.java", "return StudyObserver.suppressSave(actor);", "return false;", 1,
         "native player DB attempted to persist observer"),
        ("camera", "StudyLoadingAgent.java", "actor = StudyObserver.cameraFor(actor);", "actor = actor;", 1,
         "native camera setter conflated view with residency"),
        ("eligibility", "StudyObserver.java", "@Override public boolean isDead() { return true; }",
         "@Override public boolean isDead() { return false; }", 2,
         "anchor eligible for native alive-player scans"),
        ("bounds", "StudyObserver.java", "|| x < minX || x >= maxX", "", 1,
         "out-of-bounds command acknowledged"),
        ("model", "StudyObserver.java", "@Override public void setSceneCulled(boolean value) { }",
         "@Override public void setSceneCulled(boolean value) { super.setSceneCulled(value); }", 2,
         "native scene unculling entered model publication"),
        ("partial", "StudyObserver.java", "if (!ready || GameWindow.closeRequested) return;",
         "if (anchor == null || GameWindow.closeRequested) return;", 1,
         "partially initialized poll reached native world"),
        ("debugger", "StudyObserver.java", "runtimeFailure = failure;", "runtimeFailure = null;", 1,
         "debugger suppression concealed native failure"),
    )
    for name, filename, old, new, count, why in controls:
        directory = work / name
        directory.mkdir()
        source = (SOURCE / filename).read_text(encoding="utf-8")
        if source.count(old) != count:
            raise AssertionError(f"observer control no longer matches production source: {name}")
        mutant = directory / filename
        mutant.write_text(source.replace(old, new), encoding="utf-8")
        _execute([javac, "-encoding", "UTF-8", "-cp", str(classes) + os.pathsep + native,
                  "-d", directory, mutant], directory / "compile")
        probe(directory, extra=directory, expected=why)
    directory = work / "streaming_binding"
    directory.mkdir()
    source = (SOURCE / "StudyLoadingAgent.java").read_text(encoding="utf-8")
    seam = '.replaceWith(admission).on(ElementMatchers.named("ProcessChunkPos")))'
    if source.count(seam) != 1:
        raise AssertionError("native streaming binding control seam differs")
    mutant = directory / "StudyLoadingAgent.java"
    mutant.write_text(source.replace(seam, '.replaceWith(admission).on(ElementMatchers.named("MissingChunkMethod")))'), encoding="utf-8")
    _execute([javac, "-encoding", "UTF-8", "-cp", str(classes) + os.pathsep + native,
              "-d", directory, mutant], directory / "compile")
    probe(directory, extra=directory)
    try:
        binding(directory)
    except AssertionError as error:
        if str(error) != "native far-chunk insertion bypasses observer guard":
            raise
    else:
        raise AssertionError("missing native streaming binding control survived")
    directory = work / "preloaded_binding"
    directory.mkdir()
    source = (SOURCE / "StudyLoadingAgent.java").read_text(encoding="utf-8")
    seam = "return new AgentBuilder.Default().disableClassFormatChanges()\n            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)"
    if source.count(seam) != 1:
        raise AssertionError("native preload binding control seam differs")
    mutant = directory / "StudyLoadingAgent.java"
    mutant.write_text(source.replace(seam, seam.replace("RETRANSFORMATION", "DISABLED")), encoding="utf-8")
    _execute([javac, "-encoding", "UTF-8", "-cp", str(classes) + os.pathsep + native,
              "-d", directory, mutant], directory / "compile")
    probe(directory, extra=directory, preloaded=True)
    try:
        binding(directory)
    except AssertionError as error:
        if str(error) != "transformed native chunk map unavailable":
            raise
    else:
        raise AssertionError("missing loaded-class observer hook control survived")
    print(f"PASS native observer method checks; {len(controls) + 2} production-source defects rejected for their stated reasons")
    return {"controls": [control[0] for control in controls], "renderedWorld": False}


def run_startup(tmp, GAME, JDK):
    """Cold bundled-JRE agent ordering and installed ZombieBuddy startup scan."""
    game, jdk = Path(GAME), Path(JDK)
    work = Path(tmp).resolve() / "observer-startup-native"
    classes = work / "classes"
    classes.mkdir(parents=True)
    suffix = ".exe" if os.name == "nt" else ""
    javac, jar = (jdk / (name + suffix) for name in ("javac", "jar"))
    java = game / "jre64" / "bin" / ("java" + suffix)
    if not java.is_file():
        raise AssertionError("bundled engine JVM unavailable for cold startup probe")
    native = os.pathsep.join(str(game / name) for name in ("projectzomboid.jar", "ZombieBuddy.jar"))
    probe_source = work / "NativeStudyStartupProbe.java"
    probe_source.write_text(r'''
import java.lang.instrument.*;
import java.util.*;
import java.util.jar.JarFile;

/** Method-only agent startup; never enters the engine's game main or a world. */
public final class NativeStudyStartupProbe implements Instrumentation {
    private final Instrumentation delegate;
    private static NativeStudyStartupProbe instance;
    private static Throwable startupFailure;
    private int transformers;

    private NativeStudyStartupProbe(Instrumentation instrumentation) { delegate = instrumentation; }

    private boolean randomLoaded() {
        for (Class<?> type : delegate.getAllLoadedClasses())
            if (type.getName().equals("java.util.concurrent.ThreadLocalRandom")) return true;
        return false;
    }

    public static void premain(String arguments, Instrumentation instrumentation) {
        instance = new NativeStudyStartupProbe(instrumentation);
        try {
            if (instance.randomLoaded()) throw new AssertionError("startup probe was not cold");
            StudyLoadingAgent.premain("isolated-study", instance);
            if (instance.transformers < 3) throw new AssertionError("production study hooks were not installed");
        } catch (Throwable failure) {
            // Preserve the actual cause, but avoid an agent-init JVM abort/core dump
            // for an intentional negative ordering control.
            startupFailure = failure;
        }
    }

    public static void main(String[] arguments) {
        if (startupFailure != null) throw new AssertionError("production startup failed", startupFailure);
        if (instance == null) throw new AssertionError("startup probe agent did not run");
        me.zed_0xff.zombie_buddy.Agent.premain(null, instance.delegate);
        var patches = me.zed_0xff.zombie_buddy.PatchEngine.collectPatches(
            "me.zed_0xff.zombie_buddy.patches", null);
        if (patches.isEmpty()) throw new AssertionError("installed ZombieBuddy patch scan returned no patches");
        System.out.println("PASS native startup: cold bootstrap dependency warmed before "
            + instance.transformers + " production transformers; installed ZombieBuddy patches=" + patches.size());
    }

    private void beforeTransformer() {
        if (transformers++ == 0 && !randomLoaded())
            throw new AssertionError("bootstrap random unresolved at first study transformer");
    }

    public void addTransformer(ClassFileTransformer t, boolean retransform) {
        beforeTransformer(); delegate.addTransformer(t, retransform);
    }
    public void addTransformer(ClassFileTransformer t) { beforeTransformer(); delegate.addTransformer(t); }
    public boolean removeTransformer(ClassFileTransformer t) { return delegate.removeTransformer(t); }
    public boolean isRetransformClassesSupported() { return delegate.isRetransformClassesSupported(); }
    public void retransformClasses(Class<?>... types) throws UnmodifiableClassException { delegate.retransformClasses(types); }
    public boolean isRedefineClassesSupported() { return delegate.isRedefineClassesSupported(); }
    public void redefineClasses(ClassDefinition... definitions) throws ClassNotFoundException, UnmodifiableClassException {
        delegate.redefineClasses(definitions);
    }
    public boolean isModifiableClass(Class<?> type) { return delegate.isModifiableClass(type); }
    public Class<?>[] getAllLoadedClasses() { return delegate.getAllLoadedClasses(); }
    public Class<?>[] getInitiatedClasses(ClassLoader loader) { return delegate.getInitiatedClasses(loader); }
    public long getObjectSize(Object value) { return delegate.getObjectSize(value); }
    public void appendToBootstrapClassLoaderSearch(JarFile file) { delegate.appendToBootstrapClassLoaderSearch(file); }
    public void appendToSystemClassLoaderSearch(JarFile file) { delegate.appendToSystemClassLoaderSearch(file); }
    public boolean isNativeMethodPrefixSupported() { return delegate.isNativeMethodPrefixSupported(); }
    public void setNativeMethodPrefix(ClassFileTransformer t, String prefix) { delegate.setNativeMethodPrefix(t, prefix); }
    public void redefineModule(Module module, Set<Module> reads, Map<String, Set<Module>> exports,
            Map<String, Set<Module>> opens, Set<Class<?>> uses, Map<Class<?>, List<Class<?>>> provides) {
        delegate.redefineModule(module, reads, exports, opens, uses, provides);
    }
    public boolean isModifiableModule(Module module) { return delegate.isModifiableModule(module); }
}
''', encoding="utf-8")
    _execute([javac, "-encoding", "UTF-8", "-cp", native, "-d", classes, probe_source,
              *(SOURCE / name for name in ("StudyObserver.java", "StudyLoadingAgent.java", "StudyViewCapture.java"))],
             work / "compile")
    manifest, agent = work / "MANIFEST.MF", work / "startup-probe-agent.jar"
    manifest.write_text("Manifest-Version: 1.0\nPremain-Class: NativeStudyStartupProbe\nCan-Retransform-Classes: true\nCan-Redefine-Classes: true\n\n", encoding="utf-8")
    _execute([jar, "cfm", agent, manifest, "-C", classes, "."], work / "jar")

    def probe(directory, extra=None, expected=None):
        directory.mkdir(exist_ok=True)
        user = directory / "home"
        user.mkdir(exist_ok=True)
        classpath = os.pathsep.join(str(p) for p in ([extra] if extra else []) + [classes]) + os.pathsep + native
        output = _execute([java, f"-Duser.home={user}", "-Dstudy.observer=true", "-Dstudy.showWindow=false",
            f"-Dstudy.viewDirectory={directory / 'native-view'}", "-Djava.awt.headless=true",
            "-XX:-CreateCoredumpOnCrash", f"-javaagent:{agent}", "--enable-native-access=ALL-UNNAMED",
            "-cp", classpath, "NativeStudyStartupProbe"], directory / "probe", expected=expected)
        if expected is None:
            if "PASS native startup:" not in output or "ClassCircularityError" in output or "Uncaught exception during scan" in output:
                raise AssertionError("native startup scan did not complete cleanly\n" + output)
        return output

    probe(work / "baseline")
    source = (SOURCE / "StudyLoadingAgent.java").read_text(encoding="utf-8")
    warmup = "        java.util.concurrent.ThreadLocalRandom.current();\n"
    install = '        if (Boolean.getBoolean("study.observer")) installObserver(instrumentation);\n'
    if source.count(warmup) != 1 or source.count(install) != 1:
        raise AssertionError("bootstrap warmup control seam differs")
    controls = {
        "missing_warmup": source.replace(warmup, ""),
        "late_warmup": source.replace(warmup, "").replace(install, install + warmup),
    }
    for name, altered in controls.items():
        directory = work / name
        directory.mkdir()
        mutant = directory / "StudyLoadingAgent.java"
        mutant.write_text(altered, encoding="utf-8")
        _execute([javac, "-encoding", "UTF-8", "-cp", str(classes) + os.pathsep + native,
                  "-d", directory, mutant], directory / "compile")
        probe(directory, extra=directory, expected="bootstrap random unresolved at first study transformer")
    print("PASS native cold startup: installed bundled JVM and ZombieBuddy premain/patch discovery; 2 production-source ordering defects rejected")
    return {"controls": list(controls), "renderedWorld": False}


def run_visibility(tmp, GAME, JDK):
    """Exercise native God-view rendering and unchanged native lighting output."""
    game, jdk = Path(GAME), Path(JDK)
    work = Path(tmp).resolve() / "observer-visibility-native"
    classes = work / "classes"
    classes.mkdir(parents=True)
    suffix = ".exe" if os.name == "nt" else ""
    javac, java, jar = (jdk / (name + suffix) for name in ("javac", "java", "jar"))
    native = os.pathsep.join(str(game / name) for name in ("projectzomboid.jar", "ZombieBuddy.jar"))
    _execute([javac, "-encoding", "UTF-8", "-cp", native, "-d", classes,
              *(SOURCE / name for name in ("StudyObserver.java", "StudyLoadingAgent.java", "StudyViewCapture.java",
                                           "NativeObserverLightingProbe.java", "NativeObserverPreload.java"))], work / "compile")
    for label, main in (("observer", "StudyLoadingAgent"), ("capture", "NativeObserverLightingProbe"),
                        ("preload", "NativeObserverPreload")):
        manifest = work / (label + ".MF")
        manifest.write_text(f"Manifest-Version: 1.0\nPremain-Class: {main}\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
        _execute([jar, "cfm", work / (label + ".jar"), manifest, "-C", classes, "."], work / (label + "-jar"))

    def probe(directory, kind, wall, extra=None, expected=None):
        directory.mkdir(exist_ok=True)
        user = directory / "home"
        user.mkdir(exist_ok=True)
        classpath = os.pathsep.join(str(p) for p in ([extra] if extra else []) + [classes]) + os.pathsep + native
        output = _execute([java, f"-Duser.home={user}", "-Dstudy.observer=true",
            f"-javaagent:{work / 'capture.jar'}", f"-javaagent:{work / 'preload.jar'}",
            f"-javaagent:{work / 'observer.jar'}=isolated-study", "--enable-native-access=ALL-UNNAMED",
            "-cp", classpath, "NativeObserverLightingProbe", game / "Lighting64.dll", kind, str(wall).lower()],
            directory / "probe", expected=expected)
        if expected is None and ("PASS production observer lighting:" not in output
                or "[StudyProbe] IsoChunkMap loaded before observer premain" not in output):
            raise AssertionError("native observer visibility probe omitted its receipts")

    for kind in ("observer", "foreign", "extra-slot"):
        for wall in (False, True):
            probe(work / f"{kind}-wall-{int(wall)}", kind, wall)
    controls = (
        ("dark-display", "StudyObserver.java", "options.fboRenderChunk.nolighting.setValue(true);",
         "options.fboRenderChunk.nolighting.setValue(false);", "observer",
         "native God-view floor remained dark or altered ordinary display"),
        ("vision-mask", "StudyObserver.java", "options.fboRenderChunk.renderVisionPolygon.setValue(false);",
         "options.fboRenderChunk.renderVisionPolygon.setValue(true);", "observer",
         "God-view still uses an observer vision polygon"),
        ("faded-display", "StudyObserver.java", "options.terrain.renderTiles.forceFullAlpha.setValue(true);",
         "options.terrain.renderTiles.forceFullAlpha.setValue(false);", "observer", "native God-view fading differs"),
        ("wrong-owner", "StudyObserver.java", "if (!ownsSlots()) return false;",
         "if (anchor == null) return false;", "foreign", "God-view configuration accepted the wrong owner"),
        ("extra-owner", "StudyObserver.java", "if (!ownsSlots()) return false;",
         "if (anchor == null) return false;", "extra-slot", "God-view configuration accepted the wrong owner"),
        ("canopy-path", "StudyLoadingAgent.java", "cutaway = true;", "cutaway = false;", "observer",
         "native canopy did not select the trunk/treetop path"),
        ("canopy-alpha", "StudyLoadingAgent.java", "alpha = 0;", "alpha = 1;", "observer",
         "native canopy alpha concealed people or altered ordinary trees"),
        ("canopy-owner", "StudyObserver.java", "playerIndex == 0 && hostOnly() &&",
         "playerIndex == 0 &&", "foreign", "native canopy did not select the trunk/treetop path"),
        ("canopy-slot", "StudyObserver.java", "playerIndex == 0 && hostOnly() &&",
         "hostOnly() &&", "observer", "native canopy did not select the trunk/treetop path"),
    )
    for name, filename, old, new, kind, why in controls:
        directory = work / name
        directory.mkdir()
        source = (SOURCE / filename).read_text(encoding="utf-8")
        if source.count(old) != 1:
            raise AssertionError(f"native visibility control seam differs: {name}")
        changed = directory / filename
        changed.write_text(source.replace(old, new), encoding="utf-8")
        _execute([javac, "-encoding", "UTF-8", "-cp", str(classes) + os.pathsep + native,
                  "-d", directory, changed], directory / "compile")
        probe(directory, kind, True, extra=directory, expected=why)
    print(f"PASS native God-view: six native render/DLL/canopy cases, nonzero RGB/dark, {len(controls)} source defects rejected; preloaded engine classes")
    return {"cases": 6, "controls": [row[0] for row in controls], "nativeLighting": True, "renderedWorld": False}


def run_capture(tmp, GAME, JDK):
    """Exercise production PNG publication, command binding and retention."""
    game, jdk = Path(GAME), Path(JDK)
    work = Path(tmp).resolve() / "capture-native"
    classes = work / "classes"
    classes.mkdir(parents=True)
    suffix = ".exe" if os.name == "nt" else ""
    javac, java = (jdk / (name + suffix) for name in ("javac", "java"))
    native = os.pathsep.join(str(game / name) for name in ("projectzomboid.jar", "ZombieBuddy.jar"))
    _execute([javac, "-encoding", "UTF-8", "-cp", native, "-d", classes,
              SOURCE / "StudyViewCapture.java", SOURCE / "StudyObserver.java",
              SOURCE / "NativeViewCaptureProbe.java"], work / "compile")

    def probe(directory, extra=None, expected=None):
        directory.mkdir(exist_ok=True)
        user = directory / "home"
        user.mkdir(exist_ok=True)
        classpath = os.pathsep.join(str(p) for p in ([extra] if extra else []) + [classes]) + os.pathsep + native
        return _execute([java, "-Djava.awt.headless=true", f"-Duser.home={user}",
                         "-cp", classpath, "NativeViewCaptureProbe"], directory / "probe", expected=expected)

    output = probe(work / "baseline")
    if "PASS capture PNG publication:" not in output:
        raise AssertionError("capture probe returned without its verification receipt")
    controls = (
        ("unbounded_publication", (("pending != null || now < nextCapture", "now < nextCapture"),),
         "busy publisher admitted another capture"),
        ("pixel_orientation", (("(height - y - 1) * width * 3", "y * width * 3"),),
         "native RGB orientation or color changed"),
        ("encoding_timestamp", (("pendingCapturedAt > 0 ? pendingCapturedAt : System.currentTimeMillis()",
                                  "System.currentTimeMillis()"),),
         "capture timestamp describes encoding completion"),
        ("header_only", (
            ("if (length < 33 || length > MAX_CAPTURE_BYTES)", "if (length < 24 || length > MAX_CAPTURE_BYTES)"),
            ("int[] dimensions = validatePng(bytes);",
             "int[] dimensions = {ByteBuffer.wrap(bytes).getInt(16), ByteBuffer.wrap(bytes).getInt(20)};")),
         "24-byte header capture was published"),
        ("zlib_completion", (("if (!inflater.finished() || inflated != expected)", "if (inflated != expected)"),),
         "truncated zlib checksum capture was published"),
        ("image_decode", (("BufferedImage image = reader.read(0);",
                           "BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);"),),
         "invalid decoded filter capture was published"),
        ("stale_command", (
            ("frame == null || frame.observerSequence() != StudyObserver.commandSequence()", "frame == null"),
            ("if (frame.observerSequence() != StudyObserver.commandSequence()) {", "if (false) {")),
         "stale observer command capture was published"),
        ("gapped_retention", (("retainPublished(root);",
             'if (sequence > 8) Files.deleteIfExists(root.resolve(PREFIX + String.format("%016d", sequence - 8) + ".png"));'),),
         "published image retention exceeded 8 after sequence gaps"),
        ("transient_denial", (("publicationDeferrals >= MAX_PUBLICATION_DEFERRALS", "publicationDeferrals >= 1"),),
         "transient publication denial poisoned the run"),
        ("persistent_denial", (("publicationDeferrals >= MAX_PUBLICATION_DEFERRALS", "false"),),
         "persistent publication denial was hidden"),
    )
    for name, replacements, why in controls:
        directory = work / name
        directory.mkdir()
        source = (SOURCE / "StudyViewCapture.java").read_text(encoding="utf-8")
        for old, new in replacements:
            if source.count(old) != 1:
                raise AssertionError(f"capture control no longer matches production source: {name}")
            source = source.replace(old, new)
        mutant = directory / "StudyViewCapture.java"
        mutant.write_text(source, encoding="utf-8")
        _execute([javac, "-encoding", "UTF-8", "-cp", str(classes) + os.pathsep + native,
                  "-d", directory, mutant], directory / "compile")
        probe(directory, extra=directory, expected=why)
    print(f"PASS complete PNG publication, bounded async encoding, command/time binding, retention and Windows sharing recovery; {len(controls)} production-source controls rejected")
    return {"controls": [control[0] for control in controls], "renderedWorld": False}
