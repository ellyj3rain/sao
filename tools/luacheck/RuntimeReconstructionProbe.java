import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;

/** Installed-Kahlua proof for C55's durable/runtime reconstruction boundary. */
public final class RuntimeReconstructionProbe {
    private static final J2SEPlatform PLATFORM = new J2SEPlatform();
    private static KahluaTable environment;
    private static KahluaThread thread;

    private static Object run(String source) throws Exception {
        return thread.call(
            LuaCompiler.loadstring(source, "runtime-reconstruction", environment),
            null, null, null);
    }

    private static void load(Path root, String name) throws Exception {
        run(Files.readString(root.resolve(
            "mod/42.20/media/lua/shared/SAO_" + name + ".lua")));
    }

    private static void initialize(Path root, KahluaTable stores) throws Exception {
        environment = PLATFORM.newEnvironment();
        thread = new KahluaThread(PLATFORM, environment);
        thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.platform = PLATFORM;
        environment.rawset("_stores", stores == null ? PLATFORM.newTable() : stores);
        run("""
            local function event()
                local slot = { handlers = {} }
                function slot.Add(fn)
                    for _, known in ipairs(slot.handlers) do
                        if known == fn then return end
                    end
                    slot.handlers[#slot.handlers + 1] = fn
                end
                function slot.Remove(fn)
                    for index = #slot.handlers, 1, -1 do
                        if slot.handlers[index] == fn then
                            table.remove(slot.handlers, index)
                        end
                    end
                end
                function slot.fire()
                    local copy = {}
                    for index, fn in ipairs(slot.handlers) do copy[index] = fn end
                    for _, fn in ipairs(copy) do fn() end
                end
                function slot.count() return #slot.handlers end
                return slot
            end
            Events = {
                OnInitGlobalModData = event(),
                OnGameStart = event(),
            }
            ModData = { getOrCreate = function(key)
                _stores[key] = _stores[key] or {}
                return _stores[key]
            end }
            GameTime = { getInstance = function() return {
                getWorldAgeHours = function() return 0 end,
                getMonth = function() return 6 end,
                getTimeOfDay = function() return 0 end,
            } end }
            SandboxVars = { SurvivorAwareness = { DayZero = false } }
            SAOJavaBridge = {
                daysBehindAtStart = function() return 0 end,
                recordDayToday = function() return -100000 end,
                countyMonth = function() return 6 end,
            }
            SAO = {
                Log = { line = function() end, tally = function() end },
                Hash = { of = function() return 123456 end },
                Pressure = {
                    total = function() return 0 end,
                    threat = function() return 0 end,
                    needs = function() return 0 end,
                    injury = function() return 0 end,
                    infection = function() return 0 end,
                    weather = function() return 0 end,
                },
                Labor = {}, PathogenPressure = {}, Organization = {},
                Settlement = {}, Material = {}, Communication = {},
                PlayerInteraction = {},
            }
            """);
        for (String module : new String[]{
                "Branching", "GraphPersistence", "Integration", "History",
                "Identity", "Rand", "Places"}) {
            load(root, module);
        }
    }

    private static KahluaTable serialize(KahluaTable source) throws Exception {
        ByteBuffer bytes = ByteBuffer.allocate(4 * 1024 * 1024);
        source.save(bytes);
        bytes.flip();
        KahluaTable restored = PLATFORM.newTable();
        restored.load(bytes, 249);
        return restored;
    }

    public static void main(String[] arguments) throws Exception {
        Path root = Path.of(arguments[0]);
        initialize(root, null);
        run("""
            local graph = ModData.getOrCreate('SurvivorAwareness_Graph')
            graph.branching = {
                surfaces = { legacy = true },
                pressures = { legacy = true },
                branches = { legacy = { id = 'legacy' } },
                patterns = {}, offices = {},
            }
            local standing = ModData.getOrCreate('SurvivorAwareness_Standing')
            standing.yearsAsked = true standing.yearsOwed = 1
            standing.yearsRun = 0 standing.yearsTicks = 9000
            standing.randSeed = 'world-one' standing.randCount = 7
            local records = ModData.getOrCreate('SurvivorAwareness_Records')
            records.records = { p1 = { id = 'p1', forename = 'Alice', surname = 'Able' } }

            Events.OnInitGlobalModData.fire()
            assert(graph.branching.surfaces == nil, 'runtime surfaces entered durable store')
            assert(graph.branching.pressures == nil, 'runtime pressures entered durable store')
            assert(graph.branching.branches == nil, 'runtime branches entered durable store')
            assert(SAO.History.countyHours() == 1, 'world-one history did not bind')
            assert(SAO.Identity.idByName('Alice Able') == 'p1', 'world-one name index did not bind')
            local seed, count = SAO.Rand.state()
            assert(seed == 'world-one' and count == 7, 'world-one random stream did not bind')
            SAO.Places.cache.old = true

            __oldInstaller = 0 __newInstaller = 0
            for i = 1, 127 do
                assert(SAO.Integration.registerExtension('bounded-' .. tostring(i),
                    function() return true end), 'bounded extension refused')
            end
            assert(SAO.Integration.registerExtension('fixture', function(branching)
                __oldInstaller = __oldInstaller + 1
            end))
            assert(SAO.Integration.registerExtension('fixture', function(branching)
                __newInstaller = __newInstaller + 1
                branching.registerSurface('fixture', function() return 'fixture' end)
                branching.registerBranch({ id = 'fixture', weight = function() return 2 end })
            end))
            assert(not SAO.Integration.registerExtension('overflow', function() return true end),
                'extension registry exceeded its sort-safe ceiling')
            Events.OnGameStart.fire()
            assert(__oldInstaller == 0 and __newInstaller == 1,
                'stable extension id did not replace installer')
            assert(type(SAO.Branching.surfaces.person) == 'function'
                and type(SAO.Branching.surfaces.fixture) == 'function'
                and type(SAO.Branching.branches.fixture.weight) == 'function',
                'runtime graph was not built')
            assert(not SAO.Integration.registerExtension('fixture', function(branching)
                branching.registerSurface('fixture', function() return 'false replacement' end)
                return false
            end), 'false replacement was accepted')
            assert(SAO.Integration.ready
                and SAO.Branching.surfaces.fixture() == 'fixture'
                and SAO.Branching.branches.fixture.weight() == 2,
                'false replacement destroyed the last valid graph')
            assert(not SAO.Integration.registerExtension('fixture', function(branching)
                branching.registerSurface('fixture', function() return 'throwing replacement' end)
                error('replacement fault')
            end), 'throwing replacement was accepted')
            assert(SAO.Integration.ready
                and SAO.Branching.surfaces.fixture() == 'fixture'
                and SAO.Branching.branches.fixture.weight() == 2,
                'throwing replacement destroyed the last valid graph')
            SAO.Branching.record('p1', 'work', 123)
            """);

        KahluaTable firstStores = (KahluaTable) environment.rawget("_stores");
        KahluaTable restored = serialize(firstStores);
        initialize(root, restored);
        run("""
            local graph = ModData.getOrCreate('SurvivorAwareness_Graph')
            assert(graph.branching.surfaces == nil
                and graph.branching.pressures == nil
                and graph.branching.branches == nil,
                'serialized graph retained runtime registries')
            assert(graph.branching.patterns['p1:work'].count == 1,
                'serialized graph lost durable pattern')
            __installs = 0
            assert(SAO.Integration.registerExtension('fixture', function(branching)
                __installs = __installs + 1
                branching.registerSurface('fixture', function() return 'fixture' end)
                branching.registerBranch({ id = 'fixture', weight = function() return 2 end })
            end))
            Events.OnInitGlobalModData.fire()
            Events.OnGameStart.fire()
            assert(__installs == 1 and type(SAO.Branching.surfaces.fixture) == 'function',
                'extension did not reconstruct after reload')
            """);

        // Re-evaluating shipped modules in the same environment must replace
        // their named event handlers rather than accumulating callbacks.
        for (String module : new String[]{
                "GraphPersistence", "Integration", "History", "Identity", "Rand", "Places"}) {
            load(root, module);
        }
        run("""
            assert(Events.OnGameStart.count() == 1, 'duplicate game-start callback')
            assert(Events.OnInitGlobalModData.count() == 5, 'duplicate init callback')

            _stores = {
                SurvivorAwareness_Standing = {
                    yearsAsked = true, yearsOwed = 1, yearsRun = 0,
                    yearsTicks = 18000, randSeed = 'world-two', randCount = 3,
                },
                SurvivorAwareness_Records = {
                    records = { p2 = { id = 'p2', forename = 'Bob', surname = 'Baker' } },
                    nextId = 3,
                },
            }
            Events.OnInitGlobalModData.fire()
            Events.OnGameStart.fire()
            assert(SAO.History.countyHours() == 2, 'history cache crossed world')
            assert(SAO.Identity.idByName('Alice Able') == nil
                and SAO.Identity.idByName('Bob Baker') == 'p2',
                'identity index crossed world')
            local seed, count = SAO.Rand.state()
            assert(seed == 'world-two' and count == 3, 'random stream crossed world')
            assert(SAO.Places.cache.old == nil, 'place cache crossed world')
            assert(SAO.Branching.patterns['p1:work'] == nil,
                'prior-world graph record crossed world')
            assert(type(SAO.Branching.surfaces.person) == 'function'
                and type(SAO.Branching.surfaces.fixture) == 'function',
                'runtime graph did not rebuild for second world')
            assert(__installs == 2, 'extension installed more or less than once per rebuild')
            """);
        System.out.println("RUNTIME_RECONSTRUCTION_OK");
    }
}
