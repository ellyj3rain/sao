#!/usr/bin/env python3
r"""Border 128 - a border that cannot run says so ([C56]).

The CI workflow states the design in its own comment: a border that
reads the installed game reports SKIPPED, because a check that cannot
run must never look like a check that passed. Fifteen borders did not.
They exited 1 - a finding about the repository - so `check.sh` refused
and CI would have gone red on any machine without Project Zomboid
installed, which is every machine but the operator's. The workflow's
comment said "the six that read the installed game"; that was true
when it was written and the C era added eleven more, so nobody looking
at the comment could see it had stopped being true.

Nothing had checked the property, so it drifted silently for eleven
borders. This checks it.

Standing checks that execute against the installed game run with their
game-install paths redirected to somewhere that does not exist. Their
actual registered CLI arguments are retained and installed path bindings
are redirected before executing each tool's guarded entry block. Each must:

  * return 0, because a missing game is not a defect in this tree; and
  * report SKIP or SKIPPED, because silence would be indistinguishable from
    having run.

Paths INSIDE the repository are left alone: a tool whose own Java
source or prelude is missing is a real fault and must stay one. The
distinction is the whole point - the game is absent on CI, the
repository is not.

Named qualification tools retain their scoped inputs and receipts.
Optional engine helpers do not turn a source inventory command into a
native check. The census prints the standing checks it exercised.
"""
import ast
import contextlib
import importlib.util
import io
import os
import pathlib
import re
import sys
import tempfile
import gate_reach_test as gate

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"

# Redirected by what a path IS, not by what it is called. A list of
# names was tried first and was wrong twice over: it missed the names
# a tool happened to invent (`places_test` binds GAME, `queue_drop_
# test` binds VANILLA), and it could never have caught a path DERIVED
# from one at import - `places_test` computes its Distributions.lua
# out of GAME on the line below it, so redirecting GAME afterwards
# left the derived path pointing at the real install and the tool ran
# in full. Both looked like defects in those tools and were defects
# here. Every module-level Path that points inside the install is
# redirected; every other path the tool holds is left alone, because a
# tool missing its OWN Java source is a real fault and must stay one.
INSIDE_THE_INSTALL = "ProjectZomboid"

ABSENT = pathlib.Path("/nonexistent/no-game-installed-here")


def game_path_bindings(path, seen=(), cache=None):
    """Trace installed path constants, including owned imported bindings."""
    path = path.resolve()
    cache = {} if cache is None else cache
    if path in cache:
        return cache[path]
    if path in seen:
        return set()
    tree = ast.parse(path.read_text(encoding="utf-8-sig", errors="ignore"))
    assignments = [node for node in tree.body if isinstance(node, ast.Assign)]
    game_names = set()
    for node in tree.body:
        if isinstance(node, ast.ImportFrom) and node.module:
            imported = path.parent.joinpath(*node.module.split('.')).with_suffix('.py')
            if imported.is_file():
                names = game_path_bindings(imported, (*seen, path), cache)
                game_names.update(alias.asname or alias.name for alias in node.names
                                  if alias.name in names)
    for node in assignments:
        constructor = node.value
        is_path = isinstance(constructor, ast.Call) and (
            isinstance(constructor.func, ast.Name) and constructor.func.id in ("Path", "installed_path")
            or isinstance(constructor.func, ast.Attribute) and constructor.func.attr == "Path")
        if is_path and any(isinstance(value, ast.Constant) and isinstance(value.value, str)
                           and "ProjectZomboid" in value.value for value in ast.walk(constructor)):
            game_names.update(target.id for target in node.targets if isinstance(target, ast.Name))
    for _ in assignments:
        for node in assignments:
            if any(isinstance(value, ast.Name) and value.id in game_names for value in ast.walk(node.value)):
                game_names.update(target.id for target in node.targets if isinstance(target, ast.Name))
    cache[path] = game_names
    return game_names


def reads_the_game(path):
    source = path.read_text(encoding="utf-8-sig", errors="ignore")
    tree = ast.parse(source)
    functions = {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}
    imports = {alias.asname or alias.name for node in tree.body
               if isinstance(node, ast.ImportFrom) and node.module == "native_proof_preflight"
               for alias in node.names if alias.name == "installed_presence"}
    game_names = game_path_bindings(path)
    visited = set()

    def walk(node):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda)):
            return False
        if isinstance(node, ast.Name) and node.id in game_names:
            return True
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id in imports:
                return True
            if node.func.id in functions and node.func.id not in visited:
                visited.add(node.func.id)
                if any(walk(child) for child in functions[node.func.id].body):
                    return True
        return any(walk(child) for child in ast.iter_child_nodes(node))

    # Binding a path is metadata. Its use from an executable entry point
    # establishes a native border; optional inventory helpers stay helpers.
    return any(walk(node) for node in tree.body
               if not isinstance(node, (ast.Assign, ast.Import, ast.ImportFrom)))


def declared_commands(path):
    """Retain standing arguments; failed-check diagnostic retries do not run."""
    source = (ROOT / 'tools/check.sh').read_text(encoding='utf-8')
    commands = [row for row in gate.shell_invocations(source)
                if (ROOT / row['path']).resolve() == path.resolve()]
    lines = source.replace('\\\n', ' ').splitlines()
    standing = [row for row in commands
                if re.match(r'^\s*if\b', lines[row['line'] - 1])]
    return standing or commands


def said_skipped(output):
    """SKIP and SKIPPED both explicitly report an unavailable native proof."""
    return 'SKIPPED' in output or bool(re.search(r'^\s*SKIP\b', output, re.M))


@contextlib.contextmanager
def cli_context(path, args, engine, jdk):
    previous_argv = sys.argv
    previous_path = sys.path[:]
    previous_modules = sys.modules.copy()
    changes = {'PZ_DIR': str(engine), 'PZ_GAME_DIR': str(engine), 'JDK_BIN': str(jdk)}
    previous_env = {key: os.environ.get(key) for key in changes}
    sys.argv = [str(path), *args]
    os.environ.update(changes)
    try:
        yield
    finally:
        sys.argv = previous_argv
        sys.path[:] = previous_path
        for name in list(sys.modules):
            if name not in previous_modules:
                del sys.modules[name]
        sys.modules.update(previous_modules)
        for key, value in previous_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def absent_paths(value):
    """Keep related installed paths related, including stored input lists."""
    if isinstance(value, pathlib.Path) and INSIDE_THE_INSTALL in str(value):
        if value.is_absolute() and value.is_relative_to(ROOT):
            return value
        for index, part in enumerate(value.parts):
            if part == INSIDE_THE_INSTALL:
                return ABSENT.joinpath(*value.parts[index + 1:])
        return ABSENT
    if isinstance(value, list):
        return [absent_paths(item) for item in value]
    if isinstance(value, tuple):
        return tuple(absent_paths(item) for item in value)
    if isinstance(value, dict):
        return {absent_paths(key): absent_paths(item) for key, item in value.items()}
    return value


def probe_absent(path, args, engine, jdk):
    """Execute the actual CLI entry with owned inputs and unavailable install."""
    name = 'skipprobe_' + path.stem
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    output = io.StringIO()
    with cli_context(path, args, engine, jdk), contextlib.redirect_stdout(output), \
            contextlib.redirect_stderr(output):
        sys.modules[name] = module
        try:
            spec.loader.exec_module(module)
        except SystemExit as exc:
            return 0 if exc.code is None else exc.code, said_skipped(output.getvalue())
        except Exception as exc:
            return 'LOAD:%s' % type(exc).__name__, False

        for attr, held in list(vars(module).items()):
            if not attr.startswith('__'):
                setattr(module, attr, absent_paths(held))

        tree = ast.parse(path.read_text(encoding='utf-8-sig'))
        blocks = [node for node in tree.body
                  if isinstance(node, ast.If) and isinstance(node.test, ast.Compare)
                  and isinstance(node.test.left, ast.Name) and node.test.left.id == '__name__'
                  and len(node.test.ops) == 1 and isinstance(node.test.ops[0], ast.Eq)
                  and len(node.test.comparators) == 1
                  and isinstance(node.test.comparators[0], ast.Constant)
                  and node.test.comparators[0].value == '__main__']
        try:
            if blocks:
                module.__dict__['__name__'] = '__main__'
                exec(compile(ast.Module(body=blocks, type_ignores=[]), str(path), 'exec'), module.__dict__)
                code = 0
            elif callable(getattr(module, 'main', None)):
                code = module.main()
            else:
                return None, False
        except SystemExit as exc:
            code = exc.code
        except Exception as exc:
            code = 'EXC:%s' % type(exc).__name__
    return 0 if code is None else code, said_skipped(output.getvalue())


def run_declared_absent(path):
    """Exercise actual registered arguments and compound CLI entry blocks."""
    commands = declared_commands(path)
    if not commands:
        if path.name in gate.ONE_OFF or path.name in gate.SCOPED:
            return None, False
        return 'UNREGISTERED', False
    with tempfile.TemporaryDirectory(prefix='sao-absence-audit-') as directory:
        root = pathlib.Path(directory)
        serial = 0
        for command in commands:
            serial += 1
            original = command['args'];args = []
            for slot, value in enumerate(original):
                if '$' in value or (slot and original[slot-1] in ('--output', '--output-dir', '--out')):
                    value = str(root/f'output-{serial}-{slot}')
                args.append(value)
            code, said = probe_absent(path, args, root/'ProjectZomboid', root/'absent-jdk')
            if code != 0 or not said:
                return code, said
    return 0, True


def run_absent(path):
    """(exit code, said SKIPPED) with the game made absent."""
    standing = bool(declared_commands(path))
    if not standing and (path.name in gate.ONE_OFF or path.name in gate.SCOPED):
        return None, False
    if standing:
        return run_declared_absent(path)
    with tempfile.TemporaryDirectory(prefix='sao-absence-audit-') as directory:
        root = pathlib.Path(directory)
        return probe_absent(path, [], root/'ProjectZomboid', root/'absent-jdk')


def main():
    faults = []
    print("=" * 74)
    print("A BORDER THAT CANNOT RUN SAYS SO")
    print("=" * 74)
    if not TOOLS.is_dir():
        print("  FAULT: no tools directory at %s" % TOOLS)
        return 1

    looked, checked, skipping = 0, 0, 0
    for path in sorted(TOOLS.glob("*.py")):
        if path.name == pathlib.Path(__file__).name:
            continue
        if not reads_the_game(path):
            continue
        looked += 1
        code, said = run_absent(path)
        if code is None:
            continue
        checked += 1
        if said:
            skipping += 1
        if code != 0:
            faults.append("%s exits %s with the game absent - a machine "
                          "without Project Zomboid is not a machine with a "
                          "defect, and this reads as the gate refusing"
                          % (path.name, code))
        elif not said:
            faults.append("%s returns 0 with the game absent and says nothing "
                          "- silence there cannot be told apart from having "
                          "run" % path.name)

    print("     %d tools name the installed game, %d of them are borders"
          % (looked, checked))
    print("     %d explicitly reported SKIP or SKIPPED with it absent" % skipping)
    if checked == 0:
        faults.append("no border was actually exercised; the census is not "
                      "finding them and this border proves nothing")

    workflow = ROOT / ".github" / "workflows" / "ci-verify.yml"
    text = workflow.read_text(encoding="utf-8", errors="ignore") \
        if workflow.exists() else ""
    # The comment wraps across lines with a `#` on each, so the count
    # has to be looked for with the wrapping flattened. The first
    # spelling searched line by line and missed a stale count that was
    # sitting there in two pieces.
    flat = " ".join(part.strip().lstrip("#").strip()
                    for part in text.split("\n"))
    stale = re.search(r"the (six|seven|eight|nine|ten|eleven|twelve) that "
                      r"read the installed", flat)
    if stale:
        faults.append("the workflow still says \"the %s that read the "
                      "installed game\" and there are %d - a count in prose "
                      "goes stale in silence, which is how this drifted"
                      % (stale.group(1), checked))
    print()
    ok = "yes" if text and not stale else "NO "
    print("  %s  the workflow does not carry a stale count" % ok)

    print()
    print("VERDICT:")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  128) skips cleanly: all %d borders that read the installed game "
          "return 0 and report SKIP or SKIPPED without it, so CI reports what ran rather "
          "than refusing" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
