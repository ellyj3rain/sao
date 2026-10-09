"""Source-only installed-metadata and real Instrumentation loader qualification.

Installed game classes are read as bytes, never initialized. Runtime cases load
the small zombie.ZomboidFileSystem fixture from isolated JVM classpaths that
deliberately omit projectzomboid.jar. Outputs are fresh ignored directories.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
WEAVE = Path("java/src/com/sao/agent/SAOZombieBuddyLoadWeave.java")
EVIDENCE = ROOT / "_scratch/d2-leisure-01/participant-integration21/native-play04/resolution12/mod-loader13"

TARGET = r'''
package zombie;
import java.util.*;
public final class ZomboidFileSystem {
    public static int nativeCalls, stringCalls, arrayCalls;
    public static List<String> received;
    public static final RuntimeException NATIVE = new IllegalArgumentException("fixture native body failure");
    public void loadMods(List<String> mods) { nativeCalls++; received=mods; if(mods!=null&&mods.contains("native-error"))throw NATIVE; }
    public void loadMods(String mods) { stringCalls++; }
    public void loadMods(ArrayList<String> mods) { arrayCalls++; received=mods; }
}
'''

COMPATIBLE_PATCH = r'''
package me.zed_0xff.zombie_buddy.patches;
import java.util.List;
import me.zed_0xff.zombie_buddy.Patch;
public final class Patch_ZomboidFileSystem {
    @Patch(className="zombie.ZomboidFileSystem",methodName="loadMods")
    public static final class Patch_loadMods2 {
        static { System.setProperty("sao.fixture.patch.initialized","true"); }
        @Patch.OnEnter
        public static void enter(List<String> mods, @Patch.Local("t0") long t0) { }
    }
}
'''

LOADER_FIELDS = r'''
    public static int calls;
    public static Object last;
    public static final IllegalStateException POLICY = new IllegalStateException("fixture policy refusal");
    public static final LinkageError LOAD = new LinkageError("fixture load failure");
'''
LOADER_BODY = r'''
    public static void loadMods(ArrayList<String> mods) {
        calls++; last=mods;
        if (mods.contains("policy-error")) throw POLICY;
        if (mods.contains("load-error")) throw LOAD;
        Collections.reverse(mods);
        mods.remove("refuse");
    }
'''

AGENT = r'''
package com.sao.agent;
import java.lang.instrument.Instrumentation;
import java.util.*;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;
public final class ModLoaderFixtureAgent {
    public static final class Upstream {
        @Advice.OnMethodEnter
        public static void enter(@Advice.Argument(value=0,readOnly=false) List<String> mods) {
            if(mods==null) return;
            ArrayList<String> work = mods instanceof ArrayList<String> ? (ArrayList<String>)mods : new ArrayList<>(mods);
            me.zed_0xff.zombie_buddy.Loader.loadMods(work);
            mods=work;
        }
    }
    public static void premain(String mode, Instrumentation instrumentation) {
        if ("omitted-hook".equals(mode)) return;
        if ("upstream-after".equals(mode)) SAOZombieBuddyLoadWeave.install(instrumentation);
        if ("upstream".equals(mode)||"upstream-after".equals(mode)) {
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .type(ElementMatchers.named(SAOZombieBuddyLoadWeave.TARGET))
                .transform((builder,type,loader,module,domain) -> builder.visit(
                    Advice.to(Upstream.class).on(SAOZombieBuddyLoadWeave.nativeMethod())))
                .installOn(instrumentation);
        }
        SAOZombieBuddyLoadWeave.install(instrumentation);
        SAOZombieBuddyLoadWeave.install(instrumentation);
    }
}
'''

RUNNER = r'''
package com.sao.agent;
import java.util.*;
import java.lang.reflect.*;
import java.net.*;
import zombie.ZomboidFileSystem;
public final class ModLoaderFixtureRunner {
    private static int passed,failed;
    private static void check(String id,boolean ok) {
        System.out.println((ok?"PASS ":"FAIL ")+id); if(ok)passed++;else failed++;
    }
    private static Object field(Class<?> type,String name)throws Exception { Field field=type.getField(name);field.setAccessible(true);return field.get(null); }
    public static void main(String[] args)throws Throwable {
        String mode=args[0];
        ZomboidFileSystem nativeFixture=new ZomboidFileSystem();
        check("fixture-target-source",ZomboidFileSystem.class.getProtectionDomain().getCodeSource().getLocation().toString().contains("fixtures"));
        Class<?> loader=null;
        try { loader=Class.forName(SAOZombieBuddyLoadWeave.LOADER,false,ZomboidFileSystem.class.getClassLoader()); }
        catch(ClassNotFoundException expected) { }
        List<String> mods=new ArrayList<>(List.of("alpha","refuse","omega"));
        nativeFixture.loadMods(mods);
        boolean available="supported".equals(mode)||"upstream".equals(mode)||"upstream-after".equals(mode)||"preexisting".equals(mode)||"omitted-hook".equals(mode);
        if(available) {
            check("loader-called-once",((Integer)field(loader,"calls"))==1);
            check("arraylist-identity",field(loader,"last")==mods && ZomboidFileSystem.received==mods);
            check("ordering-and-refused-removal",ZomboidFileSystem.received.equals(List.of("omega","alpha")));
            check("native-body-once",ZomboidFileSystem.nativeCalls==1);
            if(!"omitted-hook".equals(mode)) {
                List<String> immutable=List.of("left","refuse","right");
                nativeFixture.loadMods(immutable);
                check("working-list-returned",ZomboidFileSystem.received instanceof ArrayList && ZomboidFileSystem.received!=immutable);
                check("immutable-source-preserved",immutable.equals(List.of("left","refuse","right")));
                check("working-order-and-removal",ZomboidFileSystem.received.equals(List.of("right","left")));
                check("working-loader-identity",field(loader,"last")==ZomboidFileSystem.received);
                for(String failure:List.of("policy-error","load-error")) {
                    int before=ZomboidFileSystem.nativeCalls;
                    Object sentinel=field(loader,failure.equals("policy-error")?"POLICY":"LOAD");
                    Throwable observed=null;
                    try { nativeFixture.loadMods((List<String>)new ArrayList<>(List.of(failure))); }
                    catch(Throwable actual) { observed=actual; }
                    check(failure+"-exact-cause",observed==sentinel);
                    check(failure+"-native-withheld",ZomboidFileSystem.nativeCalls==before);
                }
                int nativeBefore=ZomboidFileSystem.nativeCalls;
                Throwable nativeObserved=null;
                try { nativeFixture.loadMods((List<String>)new ArrayList<>(List.of("native-error"))); }
                catch(Throwable actual) { nativeObserved=actual; }
                check("native-body-exact-cause-preserved",nativeObserved==ZomboidFileSystem.NATIVE);
                check("native-body-failure-not-retried",ZomboidFileSystem.nativeCalls==nativeBefore+1);
                int before=(Integer)field(loader,"calls");
                nativeFixture.loadMods("existing-lifecycle");
                nativeFixture.loadMods(new ArrayList<>(List.of("array-overload")));
                check("string-and-array-overloads-refused",(Integer)field(loader,"calls")==before && ZomboidFileSystem.stringCalls==1 && ZomboidFileSystem.arrayCalls==1);
                nativeFixture.loadMods((List<String>)null);
                check("null-native-argument-retained",ZomboidFileSystem.received==null && (Integer)field(loader,"calls")==before);
                if("upstream".equals(mode)||"preexisting".equals(mode)) check("upstream-detected-no-added-advice",SAOZombieBuddyLoadWeave.report().contains("upstream=true") && SAOZombieBuddyLoadWeave.report().contains("applied=false"));
                else if("upstream-after".equals(mode)) check("later-canonical-entry-bridge-withheld",SAOZombieBuddyLoadWeave.report().contains("upstream-declared=true") && SAOZombieBuddyLoadWeave.report().contains("applied=false"));
                else check("own-list-advice-applied",SAOZombieBuddyLoadWeave.report().contains("applied=true") && !SAOZombieBuddyLoadWeave.report().contains("failure="));
                if("supported".equals(mode)) {
                    URL fixtureUrl=ZomboidFileSystem.class.getProtectionDomain().getCodeSource().getLocation();
                    try(URLClassLoader namespace=new URLClassLoader(new URL[]{fixtureUrl},ModLoaderFixtureRunner.class.getClassLoader()) {
                        @Override protected synchronized Class<?> loadClass(String name,boolean resolve)throws ClassNotFoundException {
                            if(name.equals(SAOZombieBuddyLoadWeave.TARGET)||name.equals(SAOZombieBuddyLoadWeave.LOADER)) {
                                Class<?> result=findLoadedClass(name);
                                if(result==null) result=findClass(name);
                                if(resolve)resolveClass(result);
                                return result;
                            }
                            return super.loadClass(name,resolve);
                        }
                    }) {
                        int parentCalls=(Integer)field(loader,"calls");
                        Class<?> childOwner=Class.forName(SAOZombieBuddyLoadWeave.TARGET,true,namespace);
                        Class<?> childLoader=Class.forName(SAOZombieBuddyLoadWeave.LOADER,false,namespace);
                        List<String> childMods=new ArrayList<>(List.of("child-left","refuse","child-right"));
                        childOwner.getMethod("loadMods",List.class).invoke(childOwner.getConstructor().newInstance(),childMods);
                        check("native-owner-namespace-loader",childLoader!=loader&&(Integer)field(childLoader,"calls")==1&&(Integer)field(loader,"calls")==parentCalls);
                        check("native-owner-namespace-working-list",field(childLoader,"last")==childMods&&field(childOwner,"received")==childMods&&childMods.equals(List.of("child-right","child-left")));
                    }
                }
            }
        } else {
            check("unavailable-native-list-retained",ZomboidFileSystem.received==mods && mods.equals(List.of("alpha","refuse","omega")));
            check("unavailable-native-body-runs",ZomboidFileSystem.nativeCalls==1);
            check("unavailable-loader-never-called",loader==null || ((Integer)field(loader,"calls"))==0);
            check("unavailable-status-honest",SAOZombieBuddyLoadWeave.report().contains("loader-unavailable") || SAOZombieBuddyLoadWeave.report().contains("unsupported-loader-signature") || ("advertised-only".equals(mode) && SAOZombieBuddyLoadWeave.report().contains("declared-upstream-unverified") && SAOZombieBuddyLoadWeave.report().contains("applied=false")));
        }
        check("upstream-metadata-never-initialized",System.getProperty("sao.fixture.patch.initialized")==null);
        System.out.println("RESULT {\"passed\":"+passed+",\"failed\":"+failed+"}");
        if(failed!=0)System.exit(1);
    }
}
'''

METADATA = r'''
package com.sao.agent;
import java.io.*;
import java.util.*;
import java.util.jar.*;
import java.lang.reflect.*;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.matcher.ElementMatcher;
import net.bytebuddy.pool.TypePool;
public final class ModLoaderMetadata {
    static int passed,failed;
    static void check(String id,boolean value){System.out.println((value?"PASS ":"FAIL ")+id);if(value)passed++;else failed++;}
    @SuppressWarnings("unchecked")
    static ElementMatcher<MethodDescription> upstream(Class<?> inferred)throws Exception {
        Constructor<?> ctor=Class.forName("me.zed_0xff.zombie_buddy.PatchEngine$2",false,ModLoaderMetadata.class.getClassLoader())
            .getDeclaredConstructor(boolean.class,boolean.class,List.class,List.class,int.class);
        ctor.setAccessible(true);
        return (ElementMatcher<MethodDescription>)ctor.newInstance(false,false,List.of(Map.of(0,inferred)),List.of(true),1);
    }
    public static void main(String[] args)throws Exception {
        ClassFileLocator locator=new ClassFileLocator.Compound(
            ClassFileLocator.ForJarFile.of(new File(args[0])),ClassFileLocator.ForClassLoader.ofSystemLoader());
        TypeDescription target=new TypePool.Default.WithLazyResolution(TypePool.CacheProvider.NoOp.INSTANCE,locator,TypePool.Default.ReaderMode.FAST)
            .describe(SAOZombieBuddyLoadWeave.TARGET).resolve();
        List<MethodDescription.InDefinedShape> exact=new ArrayList<>(), string=new ArrayList<>();
        for(MethodDescription.InDefinedShape m:target.getDeclaredMethods()) {
            if(SAOZombieBuddyLoadWeave.nativeMethod().matches(m))exact.add(m);
            if(m.getName().equals("loadMods")&&m.getParameters().size()==1&&m.getParameters().get(0).getType().asErasure().represents(String.class))string.add(m);
        }
        check("installed-exact-list-one",exact.size()==1);
        check("installed-string-one-refused",string.size()==1&&!SAOZombieBuddyLoadWeave.nativeMethod().matches(string.get(0)));
        check("actual-installed-arraylist-advice-misses",!upstream(ArrayList.class).matches(exact.get(0)));
        check("actual-installed-list-advice-matches",upstream(List.class).matches(exact.get(0)));
        check("actual-existing-string-advice-matches",upstream(String.class).matches(string.get(0)));
        byte[] original=locator.locate(SAOZombieBuddyLoadWeave.TARGET).resolve();
        check("installed-original-has-no-list-callback",!SAOZombieBuddyLoadWeave.hasCallback(original));
        byte[] woven=new ByteBuddy().redefine(target,locator).visit(Advice.to(SAOZombieBuddyLoadWeave.Enter.class)
            .on(SAOZombieBuddyLoadWeave.nativeMethod())).make().getBytes();
        check("installed-bytecode-offline-weaves",SAOZombieBuddyLoadWeave.hasCallback(woven));
        ClassFileLocator zb=ClassFileLocator.ForJarFile.of(new File(args[1]));
        TypeDescription loader=TypePool.Default.of(new ClassFileLocator.Compound(zb,ClassFileLocator.ForClassLoader.ofSystemLoader()))
            .describe(SAOZombieBuddyLoadWeave.LOADER).resolve();
        int api=0;
        for(MethodDescription.InDefinedShape m:loader.getDeclaredMethods()) {
            if(m.getName().equals("loadMods")&&m.isPublic()&&m.isStatic()&&m.getReturnType().asErasure().represents(void.class)
                    &&m.getParameters().size()==1&&m.getParameters().get(0).getType().asErasure().represents(ArrayList.class))api++;
        }
        check("installed-loader-public-static-void-arraylist",api==1);
        check("installed-canonical-arraylist-entry-incompatible",!SAOZombieBuddyLoadWeave.declaredCompatibleUpstream(ModLoaderMetadata.class.getClassLoader()));
        check("native-class-unavailable-on-runtime-classpath",ModLoaderMetadata.class.getClassLoader().getResource("zombie/ZomboidFileSystem.class")==null);
        System.out.println("RESULT {\"passed\":"+passed+",\"failed\":"+failed+"}");
        if(failed!=0)System.exit(1);
    }
}
'''


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_java(base: Path, name: str, text: str) -> Path:
    path = base / (name.replace(".", "/") + ".java")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--control", choices=("none", "omitted-hook", "copy-identity", "duplicate", "swallow"), default="none")
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(EVIDENCE.resolve()):
        parser.error("Output must be a new ignored mod-loader13 sibling")
    output.mkdir(parents=True, exist_ok=False)
    logs = output / "logs"
    logs.mkdir()
    commands = []
    failures = []
    tests = []
    control_source = None
    sources = sorted((ROOT / "java/src").rglob("*.java"))
    pins = {str(p.relative_to(ROOT)): sha(p) for p in sources}
    inputs = {str(p): sha(p) for p in (GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", JDK / "java.exe", JDK / "javac.exe", ROOT / "VERSION", Path(__file__))}

    def run(label: str, command: list[str], *, check: bool = True) -> subprocess.CompletedProcess:
        result = subprocess.run(command, cwd=output, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=150)
        (logs / f"{label}.stdout.txt").write_text(result.stdout, encoding="utf-8")
        (logs / f"{label}.stderr.txt").write_text(result.stderr, encoding="utf-8")
        commands.append({"label": label, "command": command, "cwd": str(output), "exitCode": result.returncode})
        if check and result.returncode:
            raise RuntimeError(f"{label} failed ({result.returncode}); see {logs}")
        return result

    def compile_sources(label: str, items: list[Path], directory: Path, cp: str) -> None:
        directory.mkdir(parents=True, exist_ok=True)
        argument = output / f"{label}.sources.txt"
        argument.write_text("\n".join('"' + str(p).replace("\\", "/") + '"' for p in items), encoding="utf-8")
        run(label, [str(JDK / "javac.exe"), "-cp", cp, "-d", str(directory), "@" + str(argument)])

    def jvm_case(label: str, mode: str, fixture: Path | None, agent: Path | None, cp: str) -> None:
        command = [str(JDK / "java.exe"), "-Duser.home=" + str(output / "isolated-home")]
        if agent is not None:
            command.append("-javaagent:" + str(agent) + "=" + (mode if mode in ("upstream", "upstream-after") else ("omitted-hook" if args.control == "omitted-hook" else "own")))
        command.extend(["-cp", cp, "com.sao.agent.ModLoaderFixtureRunner", mode])
        result = run(label, command, check=False)
        lines = [line[7:] for line in result.stdout.splitlines() if line.startswith("RESULT ")]
        tally = json.loads(lines[-1]) if lines else {"passed": 0, "failed": 0, "error": "missing RESULT"}
        tests.append({"case": label, "mode": mode, "exitCode": result.returncode, **tally})

    try:
        compile_items = list(sources)
        if args.control in ("copy-identity", "duplicate", "swallow"):
            text = (ROOT / WEAVE).read_text(encoding="utf-8")
            replacements = {
                "copy-identity": ("mods instanceof ArrayList<String>\n            ? (ArrayList<String>) mods : new ArrayList<>(mods)", "false\n            ? (ArrayList<String>) mods : new ArrayList<>(mods)"),
                "duplicate": ("if (hasCallback(builder.make().getBytes()))", "if (false && hasCallback(builder.make().getBytes()))"),
                "swallow": ("@Advice.OnMethodEnter\n", "@Advice.OnMethodEnter(suppress = Throwable.class)\n"),
            }
            old, new = replacements[args.control]
            if text.count(old) != 1:
                raise RuntimeError("Inverse source anchor changed")
            altered = write_java(output / "control-source", "com.sao.agent.SAOZombieBuddyLoadWeave", text.replace(old, new))
            control_source = {"path": str(altered), "sha256": sha(altered), "baseSha256": sha(ROOT / WEAVE), "old": old, "new": new}
            compile_items = [altered if p == ROOT / WEAVE else p for p in compile_items]
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        generated = write_java(output / "generated", "com.sao.SAOVersion", 'package com.sao; public final class SAOVersion { public static final String VALUE=' + json.dumps(version) + '; private SAOVersion(){} }')
        cohort = output / "cohort"
        dependencies = str(GAME / "projectzomboid.jar") + ";" + str(GAME / "ZombieBuddy.jar")
        compile_sources("actual-sao-cohort", compile_items + [generated], cohort, dependencies)
        for source in compile_items:
            if source.is_relative_to(ROOT / "java/src"):
                relative = source.relative_to(ROOT / "java/src")
            else:
                relative = Path("com/sao/agent/SAOZombieBuddyLoadWeave.java")
            retained = output / "retained-source/java/src" / relative
            retained.parent.mkdir(parents=True, exist_ok=True)
            retained.write_bytes(source.read_bytes())
        # Runtime JVM classpaths deliberately omit the installed game jar.
        runtime_cp = str(cohort) + ";" + str(GAME / "ZombieBuddy.jar")
        harness_src = output / "harness-source"
        metadata = write_java(harness_src, "com.sao.agent.ModLoaderMetadata", METADATA)
        harness = output / "harness"
        compile_sources("metadata-harness", [metadata], harness, runtime_cp)
        metadata_result = run("installed-metadata", [str(JDK / "java.exe"), "-Duser.home=" + str(output / "isolated-home"), "-cp", str(harness) + ";" + runtime_cp, "com.sao.agent.ModLoaderMetadata", str(GAME / "projectzomboid.jar"), str(GAME / "ZombieBuddy.jar")], check=False)
        summary = [json.loads(line[7:]) for line in metadata_result.stdout.splitlines() if line.startswith("RESULT ")]
        tests.append({"case": "installed-metadata", "exitCode": metadata_result.returncode, **(summary[-1] if summary else {"error": "missing RESULT"})})

        fixture_sources = output / "fixture-source"
        target = write_java(fixture_sources, "zombie.ZomboidFileSystem", TARGET)
        supported = write_java(fixture_sources, "me.zed_0xff.zombie_buddy.Loader", "package me.zed_0xff.zombie_buddy; import java.util.*; public final class Loader {" + LOADER_FIELDS + LOADER_BODY + "}")
        fixtures = output / "fixtures-supported"
        compile_sources("fixture-supported", [target, supported], fixtures, runtime_cp)
        fixture_agent = write_java(harness_src, "com.sao.agent.ModLoaderFixtureAgent", AGENT)
        runner = write_java(harness_src, "com.sao.agent.ModLoaderFixtureRunner", RUNNER)
        compile_sources("instrumentation-harness", [fixture_agent, runner], harness, str(fixtures) + ";" + runtime_cp)
        manifest = output / "MANIFEST.MF"
        manifest.write_text("Manifest-Version: 1.0\nPremain-Class: com.sao.agent.ModLoaderFixtureAgent\nCan-Retransform-Classes: true\nCan-Redefine-Classes: true\n\n", encoding="utf-8")
        agent = output / "fixture-agent.jar"
        run("fixture-agent-pack", [str(JDK / "jar.exe"), "--create", "--file", str(agent), "--manifest", str(manifest), "-C", str(harness), "com/sao/agent"])
        cp = str(fixtures) + ";" + str(harness) + ";" + runtime_cp
        if args.control == "duplicate":
            jvm_case("upstream-compatible-control", "upstream", fixtures, agent, cp)
        elif args.control == "omitted-hook":
            jvm_case("original-missing-hook-control", "omitted-hook", fixtures, agent, cp)
        else:
            jvm_case("native-list-instrumented", "supported", fixtures, agent, cp)
            if args.control == "none":
                jvm_case("upstream-compatible", "upstream", fixtures, agent, cp)
                compatible_patch = write_java(output / "source-canonical-compatible", "me.zed_0xff.zombie_buddy.patches.Patch_ZomboidFileSystem", COMPATIBLE_PATCH)
                compatible_fixtures = output / "fixtures-canonical-compatible"
                compile_sources("fixture-canonical-compatible", [target, supported, compatible_patch], compatible_fixtures, runtime_cp)
                compatible_cp = str(compatible_fixtures) + ";" + str(harness) + ";" + runtime_cp
                jvm_case("upstream-installed-before-bridge-canonical", "upstream", compatible_fixtures, agent, compatible_cp)
                jvm_case("upstream-installed-after-bridge-canonical", "upstream-after", compatible_fixtures, agent, compatible_cp)
                jvm_case("canonical-advertised-not-transformed", "advertised-only", compatible_fixtures, agent, compatible_cp)
                preexisting = write_java(output / "source-preexisting", "zombie.ZomboidFileSystem", TARGET.replace(
                    "public void loadMods(List<String> mods) { nativeCalls++; received=mods; if(mods!=null&&mods.contains(\"native-error\"))throw NATIVE; }",
                    "public void loadMods(List<String> mods) { if(mods!=null) { ArrayList<String> work = mods instanceof ArrayList<String> ? (ArrayList<String>)mods : new ArrayList<>(mods); me.zed_0xff.zombie_buddy.Loader.loadMods(work); mods=work; } nativeCalls++; received=mods; if(mods!=null&&mods.contains(\"native-error\"))throw NATIVE; }"))
                preexisting_fixtures = output / "fixtures-preexisting"
                compile_sources("fixture-preexisting", [preexisting, supported], preexisting_fixtures, runtime_cp)
                jvm_case("preexisting-emitted-callback", "preexisting", preexisting_fixtures, agent, str(preexisting_fixtures) + ";" + str(harness) + ";" + runtime_cp)
        if args.control == "none":
            variants = {
                "missing": None,
                "wrong-parameter": "public static void loadMods(List<String> mods) { calls++; }",
                "nonstatic": "public void loadMods(ArrayList<String> mods) { calls++; }",
                "wrong-return": "public static int loadMods(ArrayList<String> mods) { calls++; return 1; }",
                "private-method": "private static void loadMods(ArrayList<String> mods) { calls++; }",
            }
            for mode, body in variants.items():
                directory = output / ("fixtures-" + mode)
                items = [target]
                if body:
                    variant = write_java(output / ("source-" + mode), "me.zed_0xff.zombie_buddy.Loader", "package me.zed_0xff.zombie_buddy; import java.util.*; public final class Loader {" + LOADER_FIELDS + body + "}")
                    items.append(variant)
                compile_sources("fixture-" + mode, items, directory, runtime_cp)
                # Missing Loader needs a classloader that hides the installed ZB Loader.
                if mode == "missing":
                    # Run in the normal loader namespace but remove Loader.class from
                    # a copied dependency jar. No installed jar is edited.
                    import zipfile
                    isolated_zb = output / "ZombieBuddy-without-Loader.fixture.jar"
                    with zipfile.ZipFile(GAME / "ZombieBuddy.jar") as original, zipfile.ZipFile(isolated_zb, "w", compression=zipfile.ZIP_DEFLATED) as isolated:
                        for entry in original.infolist():
                            if not entry.filename.startswith("me/zed_0xff/zombie_buddy/Loader"):
                                isolated.writestr(entry, original.read(entry.filename))
                    variant_cp = str(directory) + ";" + str(harness) + ";" + str(cohort) + ";" + str(isolated_zb)
                else:
                    variant_cp = str(directory) + ";" + str(harness) + ";" + runtime_cp
                jvm_case("unsupported-" + mode, mode, directory, agent, variant_cp)
    except Exception as exc:
        failures.append(f"{type(exc).__name__}: {exc}")
    stable_sources = all((ROOT / name).exists() and sha(ROOT / name) == expected for name, expected in pins.items())
    stable_inputs = all(Path(name).exists() and sha(Path(name)) == expected for name, expected in inputs.items())
    ordinary_failures = [test for test in tests if test.get("exitCode") or test.get("failed") or test.get("error")]
    expected_ids = {
        "omitted-hook": {"loader-called-once", "arraylist-identity", "ordering-and-refused-removal"},
        "copy-identity": {"arraylist-identity", "native-owner-namespace-working-list"},
        "duplicate": {"loader-called-once", "ordering-and-refused-removal", "working-order-and-removal", "upstream-detected-no-added-advice"},
        "swallow": {"policy-error-exact-cause", "policy-error-native-withheld", "load-error-exact-cause", "load-error-native-withheld"},
    }.get(args.control, set())
    observed_ids = {line[5:] for test in ordinary_failures for line in (logs / (test["case"] + ".stdout.txt")).read_text().splitlines() if line.startswith("FAIL ")}
    expected_control_failures = args.control != "none" and observed_ids == expected_ids and not failures and all(not test.get("error") for test in tests) and all(test.get("exitCode") == 0 for test in tests if test not in ordinary_failures)
    accepted = not failures and stable_sources and stable_inputs and (not ordinary_failures if args.control == "none" else expected_control_failures)
    receipt = {
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "status": "PASS" if accepted else "FAIL",
        "control": args.control, "output": str(output),
        "controlSource": control_source, "expectedDefectIds": sorted(expected_ids), "observedDefectIds": sorted(observed_ids),
        "sourcePins": pins, "inputPins": inputs, "sourceCount": len(sources),
        "sourcesUnchangedDuringRun": stable_sources, "inputsUnchangedDuringRun": stable_inputs,
        "commands": commands, "tests": tests, "harnessFailures": failures,
        "expectedInverseFailure": expected_control_failures,
        "limits": ["Installed engine classes metadata/offline bytes only; runtime target is a fixture.",
                   "Fixture Loader records delegated ordering/refusal/exception semantics; actual installed approvals are not executed.",
                   "No native launch, game initialization, deployment, installed jar/default/approval/Workshop/save change.",
                   "Ordinary Steam without SAO premain is outside this correction.",
                   "Existing direct callbacks in incoming List overload and canonical annotated compatible upstream entries are recognized.",
                   "A merely declared canonical entry is withheld/unverified; arbitrary later unadvertised transformers are not coordinated."]
    }
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "receipt": str(output / "receipt.json"), "tests": tests, "failures": failures}, indent=2))
    return 0 if accepted else 1


if __name__ == "__main__":
    sys.exit(main())
