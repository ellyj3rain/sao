#!/usr/bin/env python3
r"""Border 176 - private, current activity participants.

A nearby body is not automatically a participant. The actor must first hold a
fresh firsthand person belief, then the use path rechecks the current bodies
against the scanner's same-floor, facing, range and occlusion law. Controls
remove provenance, use-time visibility, floor and occlusion in turn. C67 runs
the production transfer-witness and directed-conversation methods against
controlled engine ports; jar compilation checks the installed API boundary.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
PERCEPTION = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / \
    "SAO_Perception.lua"
CONTROLLER = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / \
    "SAO_Controller.lua"
SCANNER = ROOT / "java" / "src" / "com" / "sao" / "engine" / \
    "SAOPerceptionScanner.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / \
    "SAOBridge.java"
SNAPSHOT = ROOT / "java" / "src" / "com" / "sao" / "engine" / \
    "SAONativeSnapshot.java"


def lua_function(src, name):
    match = re.search(r"(?:local\s+)?function\s+" + re.escape(name)
                      + r"\s*\([^)]*\)", src)
    if not match:
        return ""
    # These functions contain nested blocks. Stop at the next file-level
    # declaration; source assertions below are deliberately local to it.
    tail = src[match.start():]
    next_decl = re.search(r"\n(?:local\s+)?function\s+[A-Za-z_]", tail[1:])
    return tail if not next_decl else tail[:next_decl.start() + 1]


def java_method(src, name):
    match = re.search(r"^\s{4}(?:public|private|protected)\s+.*?\b"
                      + re.escape(name) + r"\s*\([^)]*\)\s*\{", src, re.M)
    if not match:
        return ""
    start = match.end() - 1
    depth = 0
    for at in range(start, len(src)):
        if src[at] == "{":
            depth += 1
        elif src[at] == "}":
            depth -= 1
            if depth == 0:
                return src[start:at]
    return ""


def source_faults(perception, controller, scanner, bridge):
    faults = []
    fresh = lua_function(perception, "P.freshObservedPerson")
    at_hand = lua_function(controller, "activityParticipantAtHand")
    visible = java_method(scanner, "visibleFrom")
    current = java_method(scanner, "canSeePersonNow")
    port = java_method(bridge, "canSeePersonNow")
    activity_at = controller.find("-- [C119] The counter")
    activity_end = controller.find('if agent.state == "SEARCHWARD"', activity_at)
    activity = controller[activity_at:activity_end] \
        if activity_at >= 0 and activity_end >= 0 else ""

    for seam, message in (
        ('belief.source ~= "observed"', "participant candidates need firsthand provenance"),
        ("belief.dead", "dead person beliefs can become participants"),
        ("SCAN_INTERVAL * 2", "participant beliefs have no fresh bound"),
    ):
        if seam not in fresh:
            faults.append(message)
    for seam, message in (
        ("SAO.Identity.beliefKey(rec)", "active children bypass their belief identity"),
        ("otherBody:getUsername()", "the player cannot resolve to the scanner key"),
        ("freshObservedPerson(id, key, tick)", "the activity ignores private acquisition"),
        ("SAOJavaBridge:canSeePersonNow", "the activity skips use-time visibility"),
        ("actionRange", "activity-specific physical reach is not preserved"),
    ):
        if seam not in at_hand:
            faults.append(message)
    if activity.count("activityParticipantAtHand(") < 4:
        faults.append("cashier and playmate paths do not share the guarded reader")
    if "pdx * pdx + pdy * pdy" in activity \
            or "cdx * cdx + cdy * cdy" in activity:
        faults.append("raw nearby coordinates still authorize an activity partner")

    for seam, message in (
        ("Math.abs(other.getZ() - sz) >= 0.5f", "current visibility ignores floors"),
        ("dist > maxRange", "current visibility ignores action range"),
        ("alignment < CONE_COS", "current visibility ignores the observer's facing"),
        ("!eye.isSomethingTo(target)", "current visibility ignores occlusion"),
    ):
        if seam not in visible:
            faults.append(message)
    if "visibleFrom(" not in current or "other instanceof IsoAnimal" not in current:
        faults.append("current participant visibility bypasses scanner classification")
    if "SAOPerceptionScanner.canSeePersonNow" not in port:
        faults.append("the bridge does not expose the scanner's use-time verdict")
    return faults


def candidate(source, dead, age, fresh_for=40):
    return source == "observed" and not dead and 0 <= age <= fresh_for


def java_declaration(src, name):
    match = re.search(r"^\s{4}(?:public|private|protected)\s+.*?\b"
                      + re.escape(name) + r"\s*\([^)]*\)\s*\{", src, re.M)
    if not match:
        raise ValueError("missing production admission method " + name)
    start = match.end() - 1
    depth = 0
    for at in range(start, len(src)):
        depth += (src[at] == "{") - (src[at] == "}")
        if depth == 0:
            return src[match.start():at + 1]
    raise ValueError("unclosed production admission method " + name)


# Execute the exact production methods with controlled native port doubles.
# This establishes admission behavior, not loaded-engine ray casting or sound
# rendering. The normal jar build verifies the actual installed API types.
ADMISSION_PROBE = r'''
import java.util.*;
public final class ActivityAdmissionProbe {
    static final float RANGE = 14.0f, NEAR_SENSE = 2.5f;
    static final double CONE_COS = Math.cos(Math.toRadians(72.0));
    static int checks;
    static boolean isProneOrCrawling(IsoGameCharacter person) { return person.prone; }
    enum CharacterTrait { DEAF }
    static class IsoGameCharacter {
        float x, y, z, fx = 1, fy, hearing = 1, weather = 1;
        boolean dead, asleep, deaf, prone;
        IsoCell cell; IsoGridSquare square;
        float getX() { return x; } float getY() { return y; } float getZ() { return z; }
        float getForwardDirectionX() { return fx; }
        float getForwardDirectionY() { return fy; }
        boolean isDead() { return dead; } boolean isAsleep() { return asleep; }
        boolean hasTrait(CharacterTrait trait) { return deaf; }
        float getWornItemsHearingMultiplier() { return hearing; }
        float getWeatherHearingMultiplier() { return weather; }
        IsoCell getCell() { return cell; }
        IsoGridSquare getCurrentSquare() { return square; }
    }
    static class IsoPlayer extends IsoGameCharacter {}
    static class IsoAnimal extends IsoPlayer {}
    static class IsoZombie extends IsoGameCharacter { boolean human; }
    static class SAOKnox { static boolean isKnoxHuman(IsoZombie person) { return person.human; } }
    static class ClimateManager {
        static ClimateManager current;
        float rain, fog;
        static ClimateManager getInstance() { return current; }
        float getRainIntensity() { return rain; }
        float getFogIntensity() { return fog; }
    }
    static class IsoCell {
        Map<String,IsoGridSquare> squares = new HashMap<>();
        Set<BaseVehicle> vehicles = new HashSet<>();
        IsoGridSquare getGridSquare(int x, int y, int z) { return squares.get(key(x,y,z)); }
        Set<BaseVehicle> getVehicles() { return vehicles; }
    }
    static String key(int x,int y,int z) { return x+":"+y+":"+z; }
    static class IsoGridSquare {
        int x,y,z; IsoCell cell;
        List<IsoObject> objects = new ArrayList<>();
        Set<IsoGridSquare> blocked = new HashSet<>();
        int getX() { return x; } int getY() { return y; } int getZ() { return z; }
        IsoCell getCell() { return cell; }
        List<IsoObject> getObjects() { return objects; }
        boolean isSomethingTo(IsoGridSquare target) { return blocked.contains(target); }
    }
    static class IsoObject {
        IsoGridSquare square; List<ItemContainer> containers = new ArrayList<>();
        IsoGridSquare getSquare() { return square; }
        int getContainerCount() { return containers.size(); }
        ItemContainer getContainerByIndex(int i) { return containers.get(i); }
    }
    static class ItemContainer {
        IsoObject parent; BaseVehicle vehicle; VehiclePart part;
        boolean isVehiclePart() { return part != null; }
        BaseVehicle getVehicle() { return vehicle; }
        VehiclePart getVehiclePart() { return part; }
        IsoObject getParent() { return parent; }
    }
    static class VehiclePart {
        ItemContainer container; String area;
        ItemContainer getItemContainer() { return container; }
        String getArea() { return area; }
    }
    static class BaseVehicle {
        boolean removed; IsoGridSquare square, area;
        boolean isRemovedFromWorld() { return removed; }
        IsoGridSquare getSquare() { return square; }
        IsoGridSquare getSquareForArea(String name) { return area; }
    }
    static class LosUtil {
        enum TestResults { Clear, ClearThroughOpenDoor, ClearThroughWindow,
            ClearThroughClosedDoor, Blocked }
        static Map<String,TestResults> paths = new HashMap<>();
        static TestResults lineClear(IsoCell cell,int x,int y,int z,
                int tx,int ty,int tz,boolean ignoreDoors) {
            if (ignoreDoors) throw new AssertionError("closed doors were ignored");
            return paths.getOrDefault(key(tx,ty,tz), TestResults.Clear);
        }
    }
    // PRODUCTION_METHODS
    static IsoGridSquare square(IsoCell cell,int x,int y,int z) {
        String key=key(x,y,z); IsoGridSquare s=cell.squares.get(key);
        if (s == null) { s=new IsoGridSquare(); s.cell=cell; s.x=x; s.y=y; s.z=z;
            cell.squares.put(key,s); }
        return s;
    }
    static <T extends IsoGameCharacter> T at(T person,IsoCell cell,float x,float y,float z) {
        person.cell=cell; person.x=x; person.y=y; person.z=z;
        person.square=square(cell,(int)Math.floor(x),(int)Math.floor(y),(int)Math.floor(z));
        return person;
    }
    static class Fixture {
        IsoCell cell = new IsoCell();
        IsoPlayer observer=at(new IsoPlayer(),cell,0.5f,0.5f,0);
        IsoPlayer actor=at(new IsoPlayer(),cell,3.5f,0.5f,0);
        ItemContainer container=new ItemContainer();
        Fixture() {
            ClimateManager.current=new ClimateManager();
            LosUtil.paths.clear(); container.parent=new IsoObject();
            container.parent.square=square(cell,3,1,0);
            container.parent.square.objects.add(container.parent);
            container.parent.containers.add(container);
        }
        boolean witness() { return canWitnessWorldTransfer(observer,actor,container,6); }
        boolean converse() { return canConverseNow(actor,observer,6); }
        void vehicle() {
            container.part=new VehiclePart(); container.vehicle=new BaseVehicle();
            container.part.container=container; container.part.area="trunk";
            container.vehicle.square=square(cell,3,0,0);
            container.vehicle.area=square(cell,3,1,0); cell.vehicles.add(container.vehicle);
        }
    }
    static void check(boolean accepted,String label) {
        if (!accepted) throw new AssertionError(label); checks++;
    }
    public static void main(String[] args) {
        Fixture f=new Fixture(); check(f.witness(),"visible actor and holder refused");
        check(f.converse(),"awake nearby conversation refused");
        f.observer.fx=-1; check(!f.witness(),"actor behind observer admitted");
        check(f.converse(),"conversation incorrectly requires facing");
        f=new Fixture(); f.observer.asleep=true;
        check(!f.witness(),"sleeping witness admitted"); check(!f.converse(),"sleeping listener admitted");
        f=new Fixture(); f.actor.asleep=true;
        check(!f.witness(),"sleeping actor admitted"); check(!f.converse(),"sleeping speaker admitted");
        f=new Fixture(); f.observer.dead=true;
        check(!f.witness(),"dead witness admitted"); check(!f.converse(),"dead listener admitted");
        f=new Fixture(); f.actor.dead=true;
        check(!f.witness(),"dead actor admitted"); check(!f.converse(),"dead speaker admitted");
        f=new Fixture(); f.observer.deaf=true;
        check(!f.converse(),"deaf listener admitted"); check(f.witness(),"deaf witness lost sight");
        f=new Fixture(); f.actor.deaf=true; check(f.converse(),"deaf speaker forbidden to speak");
        f=new Fixture(); f.observer.hearing=0.4f;
        check(!f.converse(),"hearing protection failed to reduce reach");
        f=new Fixture(); at(f.actor,f.cell,5.0f,0.5f,0); ClimateManager.current.rain=1;
        check(!f.converse(),"weather failed to reduce hearing reach");
        ClimateManager.current.fog=1;
        check(Math.abs(speechWeatherHearing()-0.57f)<0.000001f,"native rain/fog formula changed");
        f=new Fixture(); f.observer.hearing=Float.NaN;
        check(!f.converse(),"nonfinite hearing admitted");
        f=new Fixture(); ClimateManager.current.fog=Float.POSITIVE_INFINITY;
        check(!f.converse(),"nonfinite weather admitted");
        f=new Fixture(); ClimateManager.current.rain=Float.NaN;
        check(!f.converse(),"NaN rain admitted");
        f=new Fixture(); ClimateManager.current.rain=-0.1f;
        check(!f.converse(),"negative rain admitted");
        f=new Fixture(); ClimateManager.current.fog=1.1f;
        check(!f.converse(),"out-of-range fog admitted");
        f=new Fixture(); ClimateManager.current=null;
        check(!f.converse(),"unavailable weather became clear weather");
        f=new Fixture(); at(f.actor,f.cell,3.5f,0.5f,1);
        check(!f.witness(),"other-floor actor admitted"); check(!f.converse(),"other-floor speech admitted");
        f=new Fixture(); at(f.actor,f.cell,9.5f,0.5f,0);
        check(!f.witness(),"out-of-range actor admitted"); check(!f.converse(),"out-of-range speech admitted");
        f=new Fixture(); LosUtil.paths.put("3:0:0",LosUtil.TestResults.Blocked);
        check(!f.witness(),"intervening actor wall ignored");
        f=new Fixture(); LosUtil.paths.put("3:1:0",LosUtil.TestResults.Blocked);
        check(!f.witness(),"intervening holder wall ignored");
        LosUtil.paths.put("3:1:0",LosUtil.TestResults.ClearThroughOpenDoor);
        f.observer.square.blocked.add(f.container.parent.square);
        check(f.witness(),"open doorway flag suppressed visible delivery");
        LosUtil.paths.put("3:1:0",LosUtil.TestResults.ClearThroughWindow);
        check(f.witness(),"transparent window suppressed visible delivery");
        f=new Fixture(); LosUtil.paths.put("0:0:0",LosUtil.TestResults.Blocked);
        check(!f.converse(),"intervening speech wall ignored");
        LosUtil.paths.put("0:0:0",LosUtil.TestResults.ClearThroughClosedDoor);
        check(!f.converse(),"closed-door speech admitted");
        LosUtil.paths.put("0:0:0",LosUtil.TestResults.ClearThroughWindow);
        check(!f.converse(),"closed-window speech admitted");
        LosUtil.paths.put("0:0:0",LosUtil.TestResults.ClearThroughOpenDoor);
        f.actor.square.blocked.add(f.observer.square);
        check(f.converse(),"open-door speech refused");
        f=new Fixture(); f.container.parent.containers.clear();
        check(!f.witness(),"detached static container admitted");
        f=new Fixture(); f.container.parent.square.objects.clear();
        check(!f.witness(),"removed holder admitted");
        f=new Fixture(); f.cell.squares.remove("3:1:0");
        check(!f.witness(),"unloaded holder admitted");
        f=new Fixture(); f.cell.squares.remove("3:0:0");
        check(!f.witness(),"unloaded actor admitted"); check(!f.converse(),"unloaded speech participant admitted");
        f=new Fixture(); f.actor.cell=new IsoCell();
        check(!f.witness(),"different-cell actor admitted"); check(!f.converse(),"different-cell conversation admitted");
        f=new Fixture(); f.actor.x=Float.NaN;
        check(!f.witness(),"nonfinite actor admitted"); check(!f.converse(),"nonfinite speaker admitted");
        f=new Fixture(); f.observer.fx=Float.NaN;
        check(!f.witness(),"nonfinite witness facing admitted");
        f=new Fixture();
        check(!canWitnessWorldTransfer(f.observer,f.actor,f.container,Float.NaN),"nonfinite witness range admitted");
        check(!canWitnessWorldTransfer(f.observer,f.actor,f.container,Float.POSITIVE_INFINITY),"infinite witness range admitted");
        check(!canConverseNow(f.actor,f.observer,Float.POSITIVE_INFINITY),"nonfinite speech range admitted");
        check(!canWitnessWorldTransfer(f.actor,f.actor,f.container,6),"actor became own witness");
        check(!canConverseNow(f.actor,f.actor,6),"self conversation admitted");
        IsoAnimal animal=at(new IsoAnimal(),f.cell,0.5f,0.5f,0);
        check(!canWitnessWorldTransfer(animal,f.actor,f.container,6),"animal witness admitted");
        check(!canConverseNow(f.actor,animal,6),"animal listener admitted");
        IsoZombie zombie=at(new IsoZombie(),f.cell,0.5f,0.5f,0);
        check(!canWitnessWorldTransfer(zombie,f.actor,f.container,6),"zombie witness admitted");
        zombie.human=true;
        check(canWitnessWorldTransfer(zombie,f.actor,f.container,6),"recognized legacy human refused");
        f=new Fixture(); f.vehicle(); check(f.witness(),"current vehicle holder refused");
        f.container.vehicle.area=square(f.cell,9,1,0);
        check(!f.witness(),"vehicle origin substituted for actual part area");
        f=new Fixture(); f.vehicle(); f.container.vehicle.removed=true;
        check(!f.witness(),"removed vehicle admitted");
        f=new Fixture(); f.vehicle(); f.container.part.container=new ItemContainer();
        check(!f.witness(),"replaced vehicle container admitted");
        f=new Fixture(); f.vehicle(); f.container.vehicle.area=null;
        check(!f.witness(),"unknown vehicle part area admitted");
        check(!canConverseNow(null,null,6),"absent speakers admitted");
        System.out.println("PASS production admission methods "+checks+" checks");
    }
}
'''


ADMISSION_METHODS = (
    "canSeePersonNow", "visibleFrom", "canWitnessWorldTransfer", "canConverseNow",
    "awakeHuman", "sameLoadedCell", "currentSquare", "transferSquare",
    "visibleWorldPoint", "visibleTransferPoint", "withinSameFloorRange", "clearPath",
    "speechWeatherHearing",
)


HEARING_PROBE = r'''
import java.util.*;
import java.nio.*;
import java.io.*;
public final class SavedHearingProbe {
    static final String PREFIX_V3="v3;", PREFIX_V4="v4;";
    static final int MAX_ITEMS=32767;
    static int checks;
    enum CharacterTrait { DEAF, OTHER }
    record ResourceLocation(String name) {
        static ResourceLocation of(String name) { return new ResourceLocation(name); }
    }
    static class Registries {
        static Map<ResourceLocation,CharacterTrait> CHARACTER_TRAIT=Map.of(
            ResourceLocation.of("base:deaf"),CharacterTrait.DEAF,
            ResourceLocation.of("base:other"),CharacterTrait.OTHER);
    }
    record ItemFact(String type) {}
    record Slot(int item) {}
    record Equipment(List<Slot> worn) {}
    record Manifest(Map<Integer,ItemFact> items,Equipment equipment) {}
    record Snapshot(byte[][] sections,Manifest manifest) {}
    static class Script {
        float hearing; Script(float value) { hearing=value; }
        float getHearingModifier() { return hearing; }
    }
    static Map<String,Snapshot> packs=new HashMap<>();
    static Map<String,Script> scripts=new HashMap<>();
    static class zombie {
        static class GameWindow {
            static String ReadString(ByteBuffer input) {
                byte[] bytes=new byte[input.getInt()];input.get(bytes);
                return new String(bytes,java.nio.charset.StandardCharsets.UTF_8);
            }
        }
        static class scripting {
            static class ScriptManager {
                static ScriptManager instance=new ScriptManager();
                Script FindItem(String name) { return scripts.get(name); }
            }
        }
    }
    static int bounded(int value,int maximum,String label) throws IOException {
        if(value<0||value>maximum)throw new IOException(label);return value;
    }
    static Snapshot parse(String packed) throws IOException {
        Snapshot snapshot=packs.get(packed);
        if(snapshot==null)throw new IOException("invalid fixture envelope");return snapshot;
    }
    // PRODUCTION_METHODS
    static Snapshot pack(String[] traits,Map<Integer,ItemFact> items,List<Slot> worn) {
        ByteBuffer xp=ByteBuffer.allocate(256);xp.putInt(traits.length);
        for(String trait:traits) {
            byte[] bytes=trait.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            xp.putInt(bytes.length);xp.put(bytes);
        }
        return new Snapshot(new byte[][] {null,null,null,Arrays.copyOf(xp.array(),xp.position())},
            new Manifest(items,new Equipment(worn)));
    }
    static void check(boolean value,String label) {
        if(!value)throw new AssertionError(label);checks++;
    }
    static void available(String packed,float expected,String label) {
        String result=hearingAccess(packed);
        check(result.startsWith("AVAILABLE:")
            &&Math.abs(Float.parseFloat(result.substring(10))-expected)<0.000001f,label+": "+result);
    }
    static void unknown(String packed,String label) {
        check(hearingAccess(packed).startsWith("UNKNOWN:"),label+": "+hearingAccess(packed));
    }
    public static void main(String[] args) {
        Snapshot empty=pack(new String[0],Map.of(),List.of());
        packs.put("v4;empty",empty);packs.put("v3;empty",empty);
        available("v4;empty",1,"v4 empty traits lost hearing");
        available("v3;empty",1,"v3 supported hearing refused");
        packs.put("v4;deaf",pack(new String[]{"base:other","base:deaf"},Map.of(),List.of()));
        check("REFUSED:deaf".equals(hearingAccess("v4;deaf")),"saved Deaf bypassed on unloading");
        scripts.put("Base.Earmuffs",new Script(0.5f));scripts.put("Base.Hood",new Script(0.2f));
        Map<Integer,ItemFact> gear=Map.of(1,new ItemFact("Base.Earmuffs"),2,new ItemFact("Base.Hood"));
        packs.put("v4;worn",pack(new String[0],gear,List.of(new Slot(1),new Slot(2))));
        available("v4;worn",0.1f,"saved worn hearing differs from native reciprocal law");
        packs.put("v4;carried",pack(new String[0],gear,List.of()));
        available("v4;carried",1,"unworn carried gear muted speech");
        scripts.remove("Base.Hood");unknown("v4;worn","missing worn script became can-hear");
        scripts.put("Base.Hood",new Script(Float.NaN));unknown("v4;worn","NaN modifier became can-hear");
        scripts.put("Base.Hood",new Script(Float.POSITIVE_INFINITY));
        unknown("v4;worn","infinite modifier became can-hear");
        scripts.put("Base.Hood",new Script(-1));unknown("v4;worn","negative modifier became can-hear");
        scripts.put("Base.Hood",new Script(0));available("v4;worn",0.5f,"native zero modifier semantics drifted");
        scripts.put("Base.Hood",new Script(Float.MIN_VALUE));unknown("v4;worn","modifier overflow became can-hear");
        packs.put("v4;missing-id",pack(new String[0],Map.of(),List.of(new Slot(9))));
        unknown("v4;missing-id","missing worn identity became can-hear");
        unknown("v4;broken","invalid snapshot became can-hear");
        unknown(null,"absent snapshot became can-hear");
        packs.put("v1;legacy",empty);packs.put("v2;legacy",empty);
        unknown("v1;legacy","v1 invented native traits");unknown("v2;legacy","v2 invented native traits");
        check(scripts.size()==2&&packs.get("v4;worn").manifest().equipment().worn().size()==2,
            "saved hearing read mutated inventory or script ownership");
        System.out.println("PASS saved hearing methods "+checks+" checks");
    }
}
'''


def hearing_source_faults(snapshot, bridge):
    body = java_method(snapshot, "hearingAccess")
    faults = []
    for seam in ("parse(packed)", "snapshot.sections()[3]", "CharacterTrait.DEAF",
                 "snapshot.manifest().equipment().worn()", "FindItem(fact.type())",
                 "getHearingModifier()", "UNKNOWN:"):
        if seam not in body:
            faults.append("saved hearing lost native evidence seam: " + seam)
    if any(seam in body for seam in (".load(", "InventoryItem(", ".restore(", "IsoPlayer(")):
        faults.append("saved hearing read creates native possessions or a body")
    if "SAONativeSnapshot.hearingAccess(SAODurableText.unpack(packed))" not in java_method(bridge, "hibernationHearingAccess"):
        faults.append("durable hearing bridge bypasses canonical snapshot reader")
    return faults


def hearing_behavior(snapshot):
    jdk = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
    javac = str(jdk / "javac.exe") if (jdk / "javac.exe").exists() else shutil.which("javac")
    java = str(jdk / "java.exe") if (jdk / "java.exe").exists() else shutil.which("java")
    if not java or not javac:
        print("SKIPPED: saved Java hearing probe requires a JDK")
        return []
    def run(source, work):
        methods = "\n".join(java_declaration(source, name) for name in ("isNative", "hearingAccess"))
        fixture = work / "SavedHearingProbe.java"
        fixture.write_text(HEARING_PROBE.replace("// PRODUCTION_METHODS", methods), encoding="utf-8")
        compiled = subprocess.run([javac, "-d", str(work), str(fixture)],
            capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise RuntimeError("saved hearing probe compilation failed: " + compiled.stderr)
        return subprocess.run([java, "-cp", str(work), "SavedHearingProbe"],
            capture_output=True, text=True, timeout=60)
    mutations = (
        ("== CharacterTrait.DEAF", "== null", "saved Deaf bypassed on unloading"),
        ("modifier /= itemModifier", "modifier *= itemModifier",
         "saved worn hearing differs from native reciprocal law"),
        ('return "UNKNOWN:invalid-snapshot";', 'return "AVAILABLE:1.0";',
         "invalid snapshot became can-hear"),
    )
    faults = []
    try:
        with tempfile.TemporaryDirectory(prefix="sao-saved-hearing-") as directory:
            work = pathlib.Path(directory)
            baseline = run(snapshot, work)
            if baseline.returncode:
                return ["saved hearing probe failed: " + baseline.stdout + baseline.stderr]
            print(baseline.stdout.strip())
            for old, new, expected in mutations:
                if old not in snapshot:
                    faults.append("CONTROL mutation did not land: " + expected)
                    continue
                broken = run(snapshot.replace(old, new), work)
                if broken.returncode == 0 or expected not in broken.stdout + broken.stderr:
                    faults.append("CONTROL did not detect " + expected + ": " + broken.stdout + broken.stderr)
            if not faults:
                print("PASS three saved-hearing defects fail their named production cases")
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        faults.append(str(exc))
    return faults


def admission_source_faults(scanner, bridge):
    faults = []
    for name in ADMISSION_METHODS:
        if not java_method(scanner, name):
            faults.append("missing production admission method " + name)
    for name in ("canWitnessWorldTransfer", "canConverseNow"):
        port = java_method(bridge, name)
        if "SAOPerceptionScanner." + name not in port or "Double.isFinite(range)" not in port:
            faults.append("bridge does not preserve finite " + name + " admission")
    if "float weather = speechWeatherHearing();" not in java_method(scanner, "canConverseNow"):
        faults.append("loaded conversation bypasses shared speech weather")
    if "SAOPerceptionScanner.speechWeatherHearing()" not in java_method(bridge, "speechWeatherHearing"):
        faults.append("dormant weather bridge bypasses shared speech weather")
    return faults


def admission_behavior(scanner):
    jdk = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
    javac = str(jdk / "javac.exe") if (jdk / "javac.exe").exists() else shutil.which("javac")
    java = str(jdk / "java.exe") if (jdk / "java.exe").exists() else shutil.which("java")
    if not java or not javac:
        print("SKIPPED: production Java admission probe requires a JDK")
        return []
    def run(source, work):
        methods = "\n".join(java_declaration(source, name) for name in ADMISSION_METHODS)
        fixture = work / "ActivityAdmissionProbe.java"
        fixture.write_text(ADMISSION_PROBE.replace("// PRODUCTION_METHODS", methods), encoding="utf-8")
        compiled = subprocess.run([javac, "-d", str(work), str(fixture)],
            capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise RuntimeError("admission probe compilation failed: " + compiled.stderr)
        return subprocess.run([java, "-cp", str(work), "ActivityAdmissionProbe"],
            capture_output=True, text=True, timeout=60)
    mutations = (
        ("&& !person.isAsleep()", "", "sleeping witness admitted"),
        ("|| listener.hasTrait(CharacterTrait.DEAF)", "", "deaf listener admitted"),
        ("target != null && visibleWorldPoint(observer, target,\n                Math.min(RANGE, actionRange))",
         "target != null", "intervening holder wall ignored"),
        ("return result == LosUtil.TestResults.Clear", "return true || result == LosUtil.TestResults.Clear",
         "intervening actor wall ignored"),
        ("if (!owns) return null;", "if (false) return null;", "detached static container admitted"),
        ("vehicle.getSquareForArea(area)", "vehicle.getSquare()",
         "vehicle origin substituted for actual part area"),
        ("!Float.isFinite(actionRange)", "false", "infinite witness range admitted"),
        ("float weather = speechWeatherHearing();", "float weather = 1.0f;",
         "weather failed to reduce hearing reach"),
        ("if (climate == null) return Float.NaN;", "if (climate == null) return 1.0f;",
         "unavailable weather became clear weather"),
    )
    faults = []
    try:
        with tempfile.TemporaryDirectory(prefix="sao-admission-") as directory:
            work = pathlib.Path(directory)
            baseline = run(scanner, work)
            if baseline.returncode:
                return ["production admission probe failed: " + baseline.stdout + baseline.stderr]
            print(baseline.stdout.strip())
            for old, new, expected in mutations:
                if old not in scanner:
                    faults.append("CONTROL mutation did not land: " + expected)
                    continue
                broken = run(scanner.replace(old, new), work)
                if broken.returncode == 0 or expected not in broken.stdout + broken.stderr:
                    faults.append("CONTROL did not detect " + expected + ": " + broken.stdout + broken.stderr)
            if not faults:
                print("PASS nine admission defects fail their named production cases")
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        faults.append(str(exc))
    return faults


def main():
    paths = (PERCEPTION, CONTROLLER, SCANNER, BRIDGE)
    if any(not path.exists() for path in paths + (SNAPSHOT,)):
        print("FAULT: an activity-participant source surface is missing")
        return 1
    sources = [path.read_text(encoding="utf-8", errors="ignore") for path in paths]
    faults = source_faults(*sources)
    faults.extend(admission_source_faults(sources[2], sources[3]))
    snapshot = SNAPSHOT.read_text(encoding="utf-8", errors="ignore")
    faults.extend(hearing_source_faults(snapshot, sources[3]))

    if not candidate("observed", False, 20):
        faults.append("CONTROL model refused a fresh observed participant")
    for case in (("told", False, 20), ("observed", True, 20),
                 ("observed", False, 41), ("observed", False, -1)):
        if candidate(*case):
            faults.append("CONTROL model admitted a told, dead, stale or future belief")

    perception, controller, scanner, bridge = sources
    mutations = (
        (perception.replace('belief.source ~= "observed"', "false", 1),
         controller, scanner, bridge, "firsthand provenance"),
        (perception, controller.replace(
            "return SAOJavaBridge:canSeePersonNow(body, otherBody, actionRange)",
            "return true", 1), scanner, bridge, "use-time visibility"),
        (perception, controller, scanner.replace(
            "Math.abs(other.getZ() - sz) >= 0.5f", "false", 1), bridge,
         "same-floor check"),
        (perception, controller, scanner.replace(
            "!eye.isSomethingTo(target)", "true", 1), bridge, "occlusion check"),
    )
    for p, c, s, b, label in mutations:
        if not source_faults(p, c, s, b):
            faults.append("CONTROL removed %s but the border passed" % label)

    if "--source-only" not in sys.argv:
        faults.extend(admission_behavior(scanner))
        faults.extend(hearing_behavior(snapshot))
    else:
        # Parse every extracted declaration even when another worker owns the
        # serial Java validation slot.
        for name in ADMISSION_METHODS:
            java_declaration(scanner, name)

    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1
    print("176) activity partners require fresh private sight and current physical visibility")
    return 0


if __name__ == "__main__":
    sys.exit(main())
