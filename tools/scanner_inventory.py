"""Source-qualified scanner inventory. Original vaults are evidence, not autoload.

Privileges are exact destination/original byte pairs from the sealed package;
an unknown file or changed byte receives no imported-source classification.
"""
import argparse
import hashlib
import json
import pathlib
import re
from functools import lru_cache

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGE = ROOT / 'mod/42.20'
GAME = pathlib.Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(root, relative):
    if not isinstance(relative, str) or '\\' in relative or ':' in relative or '\0' in relative:
        raise ValueError('invalid package path')
    parts = pathlib.PurePosixPath(relative)
    if parts.is_absolute() or '..' in parts.parts:
        raise ValueError('package path escapes owner')
    path = root / relative
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('package path escapes owner')
    return path


class Inventory:
    def __init__(self, package=PACKAGE):
        self.package = pathlib.Path(package)
        path = self.package / 'media/SAOSources/manifest.json'
        self.manifest = json.loads(path.read_text(encoding='utf-8'))
        m = self.manifest
        if m.get('schema') != 'sao.owned-source-package/1' or m.get('packageId') != 'SurvivorAwareness':
            raise ValueError('unrecognized source package')
        self.runtime, self.originals = {}, {}
        self._blocks = {}
        self._consumer_blocks = {}
        self._environments = {}
        grouped = {key: [] for key in m['sources']}
        for row in m['files']:
            source = m['sources'].get(row['sourceId'])
            if source is None:
                raise ValueError('unregistered source owner')
            grouped[row['sourceId']].append(row)
            if not row['selectedPath'].startswith('media/lua/'):
                continue
            original = safe_path(self.package, source['originalRoot'] + '/' + row['selectedPath'])
            if not original.is_file() or sha(original.read_bytes()) != row['sourceSha256']:
                raise ValueError('original source mismatch: ' + str(original))
            self.originals.setdefault(original.resolve(), row)
            if row['kind'] == 'runtime-lua':
                destination = safe_path(self.package, row['destination'])
                if not destination.is_file() or sha(destination.read_bytes()) != row['destinationSha256']:
                    raise ValueError('runtime source mismatch: ' + str(destination))
                if not row['destination'].startswith('media/lua/'):
                    raise ValueError('runtime outside autoload namespace')
                prior = self.runtime.get(destination.resolve())
                if prior and prior['sourceId'] != row['sourceId']:
                    raise ValueError('competing source producers: ' + str(destination))
                self.runtime[destination.resolve()] = dict(row, original=original)
        for key, source in m['sources'].items():
            seal = sha(json.dumps(grouped[key], sort_keys=True, separators=(',', ':')).encode())
            sentinel = safe_path(self.package, source['sentinel'])
            if seal != source['seal'] or sentinel.read_bytes() != ('SAO-OWNED-SOURCE/1 ' + key + ' ' + seal + '\n').encode():
                raise ValueError('source generation seal mismatch: ' + key)
        # A new vault Lua file cannot hide from scanners by merely living there.
        for path in (self.package / 'media/SAOSources').rglob('*.lua'):
            if '/registration/' in path.as_posix():
                rows = [r for r in m['mergeRequired'] if r['fragment'] == path.relative_to(self.package).as_posix()]
                if len(rows) != 1 or sha(path.read_bytes()) != rows[0]['sha256']:
                    raise ValueError('unqualified registration evidence: ' + str(path))
            elif path.resolve() not in self.originals:
                raise ValueError('unqualified original vault Lua: ' + str(path))

    def row(self, path):
        return self.runtime.get(pathlib.Path(path).resolve())

    def original(self, path):
        row = self.row(path)
        return row['original'] if row else None

    def environment(self, path):
        path = pathlib.Path(path).resolve()
        if path in self._environments:
            return self._environments[path]
        row = self.row(path)
        if row is None:
            return None
        original = row['original'].read_text(encoding='utf-8', errors='ignore')
        binding = source_environment(original, include_setup=True)
        runtime_binding = source_environment(path.read_text(encoding='utf-8', errors='ignore'), include_setup=True)
        result = (row['sourceId'], binding[0]) if binding and binding == runtime_binding else None
        self._environments[path] = result
        return result

    def environment_fields(self):
        from menu_reach import strip_lua
        fields = {}
        for row in self.runtime.values():
            code = strip_lua(row['original'].read_text(encoding='utf-8', errors='ignore'))
            binding = re.search(r'local\s+env\s*=\s*_G\.(\w+)', code)
            if binding:
                for name in re.findall(r'\benv\.(\w+)\s*=(?!=)', code):
                    fields.setdefault(((row['sourceId'], binding.group(1)), name), set()).add(row['original'].resolve())
        return fields

    def global_exports(self):
        from menu_reach import strip_lua
        exports = {}
        for row in self.runtime.values():
            text = row['original'].read_text(encoding='utf-8', errors='ignore')
            code = strip_lua(text)
            for name in re.findall(r'\b_G\.(\w+)\s*=(?!=)', code):
                exports.setdefault(name, set()).add(row['original'].resolve())
        return exports

    def public_namespace(self, path, name):
        """A source's public declaration, distinct from a leaked temporary.

        Native SET remains mandatory in the caller. Here both original and
        current text must declare the same bare name at module scope, outside
        a private setfenv owner. Function-body temporary writes do not become
        approved namespaces merely because the original source contained them.
        """
        from menu_reach import strip_lua
        original = self.original(path)
        if not original or self.environment(path):
            return False
        pattern = re.compile(r'(?<![\w.:])(?:\bfunction\s+(' + re.escape(name)
                             + r')\s*\(|\b(' + re.escape(name) + r')\s*=(?!=))')
        def declared(text):
            code = strip_lua(text)
            return any(not re.search(r'\blocal\s+(?:\w+\s*,\s*)*$', code[:match.start()])
                       and lexical_context(code[:match.start()], include_depth=True)[2] == 0
                       and not lexical_context(code[:match.start()])[1]
                       for match in pattern.finditer(code))
        return declared(original.read_text(encoding='utf-8', errors='ignore')) and declared(
            pathlib.Path(path).read_text(encoding='utf-8', errors='ignore'))

    def _namespace_file(self, path, expected=None):
        path = pathlib.Path(path).resolve()
        digest = sha(path.read_bytes())
        if expected is not None and digest != expected:
            raise ValueError('namespace evidence changed: ' + str(path))
        self._namespace_evidence[str(path)] = digest
        return json.loads(path.read_text(encoding='utf-8'))

    def _namespace_negative(self, receipt_path, receipt, name, expected_log=None):
        if not any(row.get('name') == name for row in receipt['controls']):
            raise ValueError('missing named namespace negative control')
        runs = [row for row in receipt['runs'] if row['name'] == name]
        if len(runs) != 1 or runs[0]['exitCode'] == 0:
            raise ValueError('namespace negative run did not fail')
        log = pathlib.Path(receipt_path).parent / (name + '.log')
        digest = sha(log.read_bytes())
        if digest != runs[0]['logSha256'] or (expected_log is not None and digest != expected_log):
            raise ValueError('namespace negative log changed')
        self._namespace_evidence[str(log.resolve())] = digest

    def _namespace_receipt(self, proof, unrelated=None):
        receipt_path = safe_path(ROOT, proof['receiptPath'])
        receipt = self._namespace_file(receipt_path, proof['receiptSha256'])
        pins = receipt['inputsAfter']
        if (receipt.get('status') != 'PASS' or pins != receipt['inputsBefore']
                or not pins or receipt['checks'] != proof['checks']
                or len(receipt['controls']) != proof['restoredControls']):
            raise ValueError('namespace receipt qualification differs')
        unrelated = unrelated or {}
        if any(pins.get(p) != h for p, h in unrelated.items()):
            raise ValueError('namespace excluded input was not recorded')
        for p, h in pins.items():
            digest = sha(pathlib.Path(p).read_bytes())
            self._namespace_evidence[str(pathlib.Path(p).resolve())] = digest
            if p not in unrelated and digest != h:
                raise ValueError('namespace receipt input changed: ' + p)
        for name in proof.get('requiredControls', []):
            self._namespace_negative(receipt_path, receipt, name)
        return receipt, pins

    def _namespace_control_join(self, contract, fresh):
        negative = contract['restoredControl']
        prior_path = pathlib.Path(negative['receipt']).resolve()
        prior = self._namespace_file(prior_path, negative['receiptSha256'])
        metadata = {'receiptPath': prior_path.relative_to(ROOT).as_posix(),
                    'receiptSha256': negative['receiptSha256'], 'checks': prior['checks'],
                    'restoredControls': len(prior['controls'])}
        prior, pins = self._namespace_receipt(metadata)
        self._namespace_negative(prior_path, prior, negative['name'], negative['logSha256'])
        join_meta = contract['scopedControlJoin']
        join = self._namespace_file(safe_path(ROOT, join_meta['path']), join_meta['sha256'])
        if (join.get('schema') != 'sao.applied-music-arcade-evidence-join/1'
                or join.get('status') != 'PASS'
                or join['currentManifestSha256'] != sha((self.package / 'media/SAOSources/manifest.json').read_bytes())
                or pathlib.Path(join['proof11Reuse']['receipt']).resolve() != prior_path
                or join['proof11Reuse']['sha256'] != negative['receiptSha256']
                or join['proof11Reuse']['verifiedPinCount'] != len(pins)
                or join['proof11Reuse']['restoredControls'] != len(prior['controls'])
                or join['freshMusic']['sha256'] != contract['qualification']['receiptSha256']
                or pathlib.Path(join['freshMusic']['receipt']).resolve() != safe_path(ROOT, contract['qualification']['receiptPath']).resolve()):
            raise ValueError('namespace scoped control join differs')
        matches = [row for row in join['currentProductionRows']
                   if row['path'] == contract['path'] and row['sha256'] == contract['runtimeSha256']]
        staged_join = (len(matches) == 1
                       and pins.get(matches[0]['qualifiedPath']) == contract['runtimeSha256'])
        unchanged_guard = (not matches and contract['classification'] == 'engine-guard'
                           and pins.get(str((ROOT/contract['path']).resolve())) == contract['runtimeSha256'])
        if not staged_join and not unchanged_guard:
            raise ValueError('namespace restored source does not join current postimage')
        for row in join['currentProductionRows']:
            for path in (safe_path(ROOT, row['path']), pathlib.Path(row['qualifiedPath'])):
                digest = sha(path.read_bytes());self._namespace_evidence[str(path.resolve())] = digest
                if digest != row['sha256']:
                    raise ValueError('namespace joined source changed')

    def _namespace_generation_join(self, qualification, historical):
        metadata = qualification['scopedGenerationJoin']
        join = self._namespace_file(safe_path(ROOT, metadata['path']), metadata['sha256'])
        if join.get('status') != 'PASS':
            raise ValueError('namespace generation join did not pass')
        scope = join['proofs']['namespace-generation-join']
        excluded = qualification.get('unrelatedInputs', {})
        if (scope['status'] != 'PASS_SCOPED_GENERATION_JOIN'
                or scope['historicalReceiptSha256'] != qualification['receiptSha256']
                or pathlib.Path(scope['historicalReceipt']).resolve() != safe_path(ROOT, qualification['receiptPath']).resolve()
                or scope['unchangedInputs'] != {p: h for p, h in historical['inputsAfter'].items() if p not in excluded}
                or set(excluded) != {scope['changedModule']}
                or scope['combinedChecks'] != qualification['checks']
                or scope['combinedControls'] != qualification['restoredControls']):
            raise ValueError('namespace generation scope differs')
        fresh_meta = {'receiptPath': pathlib.Path(scope['currentReceipt']).relative_to(ROOT).as_posix(),
                      'receiptSha256': scope['currentReceiptSha256'],
                      'checks': scope['refreshedChecks'], 'restoredControls': scope['refreshedControls']}
        fresh, pins = self._namespace_receipt(fresh_meta)
        if (pins != scope['currentInputs']
                or fresh['checksByMode'] != {'interaction': 3}
                or scope['reusedChecks'] + fresh['checks'] != qualification['checks']
                or scope['reusedControls'] + len(fresh['controls']) != qualification['restoredControls']):
            raise ValueError('namespace refreshed source scope differs')

    def namespace_evidence_inputs(self):
        """Exact dependencies of admitted source access, captured by the census."""
        if not hasattr(self, '_namespace_contracts'):
            self.qualified_namespace_access('GET', ROOT / 'missing.lua', 'missing')
            # Missing paths refuse before loading; use one declared current row.
            for path in self.runtime:
                self.qualified_namespace_access('GET', path, 'missing')
                break
        return dict(getattr(self, '_namespace_evidence', {}))

    def qualified_namespace_access(self, kind, path, name):
        """An exact lifetime-qualified publisher or engine-extension access.

        The contract names one source, destination, original/current byte pair
        and compiler access kind. It grants no name-wide or family permission.
        """
        if kind not in ('GET', 'SET'):
            return False
        path = pathlib.Path(path).resolve()
        row = self.row(path)
        if not row or not path.is_relative_to(ROOT):
            return False
        if not hasattr(self, '_namespace_contracts'):
            contract_path = ROOT / 'tools/source_namespace_contracts.json'
            try:
                data = json.loads(contract_path.read_text(encoding='utf-8'))
                qualification = data['qualification']
                self._namespace_evidence = {str(contract_path.resolve()): sha(contract_path.read_bytes())}
                valid = (data.get('schema') == 'sao.source-namespace-contracts/1'
                         and qualification['inputs']
                         and all(sha(safe_path(ROOT, p).read_bytes()) == h
                                 for p, h in qualification['inputs'].items()))
                self._namespace_proofs = {}
                if valid:
                    publishers = [c for c in data['contracts'] if c['classification'] in ('owned-publisher', 'engine-extension')]
                    unrelated = qualification.get('unrelatedInputs', {})
                    if set(unrelated) & {str((ROOT/c['path']).resolve()) for c in publishers}:
                        raise ValueError('namespace publisher source cannot be excluded')
                    publisher_receipt, publisher_pins = self._namespace_receipt(qualification, unrelated)
                    self._namespace_generation_join(qualification, publisher_receipt)
                    for c in publishers:
                        if (publisher_pins.get(str((ROOT/c['path']).resolve())) != c['runtimeSha256']
                                or c['proofMode'] not in publisher_receipt['checksByMode']):
                            raise ValueError('namespace publisher lacks exact native proof')
                    for contract in data['contracts']:
                        proof = contract.get('qualification')
                        if not proof:
                            continue
                        receipt, pins = self._namespace_receipt(proof)
                        if contract.get('restoredControl'):
                            self._namespace_control_join(contract, receipt)
                        elif not proof.get('requiredControls'):
                            raise ValueError('namespace optional proof lacks negative controls')
                        self._namespace_proofs[proof['receiptPath']] = (proof, pins)
                self._namespace_contract_fingerprints = {
                    (c['path'], c['name']): sha(json.dumps(c, sort_keys=True, separators=(',', ':')).encode())
                    for c in data['contracts']} if valid else {}
                self._namespace_contracts = data['contracts'] if valid else []
            except (OSError, ValueError, KeyError, TypeError):
                self._namespace_contracts = []
        relative = path.relative_to(ROOT).as_posix()
        for contract in self._namespace_contracts:
            if contract.get('path') != relative or contract.get('name') != name:
                continue
            fingerprint = sha(json.dumps(contract, sort_keys=True, separators=(',', ':')).encode())
            if getattr(self, '_namespace_contract_fingerprints', {}).get((relative, name)) != fingerprint:
                continue
            classification = contract.get('classification')
            if (classification not in ('owned-publisher', 'engine-extension',
                                       'optional-provider', 'engine-guard')
                    or not contract.get('routine') or not contract.get('lifetime')
                    or contract.get('sourceId') != row['sourceId']
                    or contract.get('sourceSha256') != row['sourceSha256']
                    or contract.get('runtimeSha256') != row['destinationSha256']
                    or not isinstance(contract.get('accesses', {}).get(kind), int)
                    or contract['accesses'][kind] <= 0):
                continue
            if classification in ('optional-provider', 'engine-guard'):
                proof = contract.get('qualification')
                if kind != 'GET' or not proof:
                    continue
                verified, pins = getattr(self, '_namespace_proofs', {}).get(
                    proof.get('receiptPath'), (None, {}))
                if verified != proof or pins.get(str(path)) != contract['runtimeSha256']:
                    continue
            return (sha(path.read_bytes()) == contract['runtimeSha256']
                    and sha(row['original'].read_bytes()) == contract['sourceSha256'])
        return False

    def runtime_lua(self):
        return sorted((self.package / 'media/lua').rglob('*.lua'))

    def structural_lua(self):
        vault = self.package / 'media/SAOSources'
        return sorted(p for p in self.package.parent.rglob('*.lua') if not p.is_relative_to(vault))

    def original_block(self, path, block, normalise, width=15):
        path = pathlib.Path(path).resolve()
        original = path if path in self.originals else self.original(path)
        if original is None:
            # A qualified SAO adapter can retain original source mechanics.
            # Its full revision is pinned; a changed/new caller gains no
            # permission merely by containing an imported source block.
            key = (path, width)
            if key in self._consumer_blocks:
                return block in self._consumer_blocks[key]
            baseline = json.loads((ROOT / 'tools/source_scanner_consumers.json').read_text())
            if baseline.get('schema') != 'sao.source-scanner-consumers/1' or not path.is_relative_to(ROOT):
                return False
            consumer = baseline['consumers'].get(path.relative_to(ROOT).as_posix())
            if not consumer or sha(path.read_bytes()) != consumer['sha256']:
                return False
            permitted = set()
            for row in self.runtime.values():
                if row['sourceId'] in consumer['sourceIds']:
                    self.original_block(row['original'], '', normalise, width)
                    permitted.update(self._blocks.get((row['original'], width), set()))
            self._consumer_blocks[key] = permitted
            return block in permitted
        # Header/import adaptations grant no new duplicate baseline.
        key = (original, width)
        if key not in self._blocks:
            lines = normalise(original)
            self._blocks[key] = {'\n'.join(s for _, s in lines[i:i + width])
                                 for i in range(len(lines) - width + 1)}
        return block in self._blocks[key]

    def preserved_original_text(self, path):
        path = pathlib.Path(path).resolve()
        if path in self.originals:
            return path.read_text(encoding='utf-8', errors='ignore')
        original = self.original(path)
        return original.read_text(encoding='utf-8', errors='ignore') if original else None


@lru_cache(maxsize=1)
def current():
    return Inventory()


def declarations(text):
    # This is a candidate declaration inventory, not a scope verdict. Compiler
    # GET/SET remains authoritative in the namespace census.
    from menu_reach import strip_lua
    code = strip_lua(text)
    return set(re.findall(r'^\s*(?!local\b)([A-Za-z_]\w*)\s*=(?!=)', code, re.M)) | set(
        re.findall(r'^\s*function\s+([A-Za-z_]\w*)\s*\(', code, re.M))


def lexical_context(prefix, include_depth=False):
    """Active function parameters and constructor context in stripped Lua.

    Functions open a new lexical body inside an enclosing constructor, so an
    assignment within a callback is not mistaken for a constructor field.
    This supplies scanner candidates; installed compiler tests remain truth.
    """
    blocks, braces = [], []
    for token in re.finditer(r'\b(?:function|if|do|repeat|end|until)\b|[{}]', prefix):
        word = token.group()
        if word == 'function':
            header = re.match(r'\s*[\w.:]*\s*\(([^)]*)\)', prefix[token.end():])
            params = {p.strip() for p in header.group(1).split(',')} if header else set()
            blocks.append(('function', params))
        elif word in ('if', 'do', 'repeat'):
            blocks.append((word, set()))
        elif word in ('end', 'until'):
            if blocks:
                blocks.pop()
        elif word == '{':
            braces.append(sum(kind == 'function' for kind, _ in blocks))
        elif braces:
            braces.pop()
    params = set().union(*(names for kind, names in blocks if kind == 'function'))
    function_depth = sum(kind == 'function' for kind, _ in blocks)
    constructor = bool(braces and braces[-1] == function_depth
                       and prefix.rstrip().endswith(('{', ',', ';')))
    return (params, constructor, function_depth) if include_depth else (params, constructor)


def guarded_local_fallbacks(text):
    """Top-level local initialization may read an absent optional old value.

    This recognizes only literal empty-table/nil/false fallback, with no prior
    local binding of that name. The census additionally requires one actual
    native GET and no SET in both original and current file, so an extra
    unguarded access never inherits this classification.
    """
    from menu_reach import strip_lua
    code = strip_lua(text)
    result = set()
    for match in re.finditer(r'\blocal\s+(\w+)\s*=\s*\1\s+or\s*(?:\{\s*\}|nil\b|false\b)', code):
        name = match.group(1)
        prefix = code[:match.start()]
        if re.search(r'\blocal\s+[^\n=]*\b' + re.escape(name) + r'\b', prefix):
            continue
        if lexical_context(prefix, include_depth=True)[2] == 0:
            result.add(name)
    return result


def source_declarations(inventory):
    result = {}
    for row in inventory.runtime.values():
        for name in declarations(row['original'].read_text(encoding='utf-8', errors='ignore')):
            result.setdefault(name, set()).add(row['sourceId'])
    return result


def engine_lua_declarations(game=GAME):
    result = set()
    for path in (game / 'media/lua').rglob('*.lua'):
        result.update(declarations(path.read_text(encoding='utf-8', errors='ignore')))
    return result


def engine_java_names(game=GAME):
    import subprocess
    javap = pathlib.Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin/javap.exe')
    jar = game / 'projectzomboid.jar'
    names = set()
    expose = subprocess.run([str(javap), '-c', '-p', '-cp', str(jar),
                             'zombie.Lua.LuaManager$Exposer'], capture_output=True, text=True, timeout=30)
    if expose.returncode:
        raise ValueError('native class exposure inventory unavailable')
    for cls in re.findall(r'// class ([\w/$]+)\s*\n\s*\d+: invokevirtual[^\n]*setExposed:', expose.stdout):
        names.add(cls.rsplit('/', 1)[-1].rsplit('$', 1)[-1])
    functions = subprocess.run([str(javap), '-v', '-p', '-cp', str(jar),
                                'zombie.Lua.LuaManager$GlobalObject'], capture_output=True, text=True, timeout=30)
    if functions.returncode:
        raise ValueError('native function annotation inventory unavailable')
    names.update(annotated_global_names(functions.stdout))
    # The installed platform registers compiler functions separately from
    # GlobalObject. Restrict this evidence to its actual register call and the
    # compiler's names array, rather than every string in the class.
    def bytecode(cls):
        result = subprocess.run([str(javap), '-c', '-p', '-cp', str(jar), cls],
                                capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise ValueError('native bootstrap exposure unavailable: ' + cls)
        return result.stdout
    platform = bytecode('se.krka.kahlua.j2se.J2SEPlatform')
    compiler = bytecode('se.krka.kahlua.luaj.compiler.LuaCompiler')
    util = bytecode('se.krka.kahlua.vm.KahluaUtil')
    random = bytecode('se.krka.kahlua.stdlib.RandomLib')
    names.update(bootstrap_global_names(platform, compiler, util, random))
    return names


def source_environment(text, include_setup=False):
    """Exact original private environment setup, with its optional guard.

    No intervening assignment/call other than the original metatable guard is
    admitted. The caller also compares original and current runtime bindings.
    """
    from menu_reach import strip_lua
    code = strip_lua(text)
    guard = (r'(?:if\s+getmetatable\(\s*env\s*\)\s*==\s*nil\s+then\s*'
             r'setmetatable\(\s*env\s*,\s*\{\s*__index\s*=\s*_G\s*\}\s*\)\s*end\s*)?')
    # Some original split modules bind a public table into the private
    # environment before switching. The caller compares the complete exact
    # original/current setup, including both sides of each alias assignment.
    # This proves the environment, without granting ownership of alias values.
    aliases = r'(?:env\.\w+\s*=\s*_G\.\w+\s*)*'
    match = re.search(r'local\s+env\s*=\s*_G\.(\w+)\s*' + guard + aliases
                      + r'setfenv\(\s*1\s*,\s*env\s*\)', code)
    if not match:
        return None
    return (match.group(1), re.sub(r'\s+', '', match.group())) if include_setup else match.group(1)


def annotated_global_names(dump):
    """Names exposed by GlobalObject's actual global LuaMethod annotation."""
    names = set()
    for block in re.split(r'(?=\n  (?:public|private|protected) )', dump):
        header = re.match(r'\n  public (?:static )?[^\n]*?\b(\w+)\([^\n]*\)', block)
        if not header or 'se.krka.kahlua.integration.annotations.LuaMethod(' not in block:
            continue
        annotation = block.split('se.krka.kahlua.integration.annotations.LuaMethod(', 1)[1].split(')', 1)[0]
        if not re.search(r'\bglobal=true\b', annotation):
            continue
        name = re.search(r'name="([^"]+)"', annotation)
        names.add(name.group(1) if name else header.group(1))
    return names


def bootstrap_global_names(platform, compiler, util, random=''):
    names = set()
    if 'LuaCompiler.register:' in platform:
        initializer = compiler.split('static {};', 1)
        if len(initializer) == 2:
            array = initializer[1].split('// Field names:', 1)[0]
            names.update(re.findall(r'// String ([A-Za-z_]\w*)\s*$', array, re.M))
    method = re.search(r'public static [^\n]* getClassMetatables\([^\n]*\);\s*Code:(.*?)(?=\n  (?:public|private|protected) |\Z)', util, re.S)
    if method and '// String __classmetatables' in method.group(1) and 'getOrCreateTable:' in method.group(1):
        names.add('__classmetatables')
    # RandomLib also installs random/randomseed on userdata metatables. Only
    # the separately installed environment function newrandom is a global.
    if 'RandomLib.register:' in platform and re.search(
            r'aload_1\s*\n[^\n]*// String newrandom\s*\n[^\n]*// Field NEWRANDOM_FUN:[^\n]*\n'
            r'[^\n]*KahluaTable.rawset:', random):
        names.add('newrandom')
    return names


def locale_keys(folder):
    keys = set()
    for path in pathlib.Path(folder).glob('*'):
        if path.suffix == '.json':
            keys.update(json.loads(path.read_text(encoding='utf-8-sig')))
        elif path.suffix == '.txt':
            # Original PZ table translation syntax: keys are actual assignments.
            keys.update(re.findall(r'^\s*([A-Za-z_]\w*)\s*=', path.read_text(encoding='utf-8-sig', errors='ignore'), re.M))
    return keys


# Exact source calls intentionally pass display text to native getText fallback.
# No other file/string receives this allowance, and the original call must exist.
LITERAL_LABELS = {
    ('LifestyleHobbies', 'media/lua/client/LSIsListeningEffects.lua'): {'Disturbed Sleep', 'Disturbed Focus'},
    ('LifestyleHobbies', 'media/lua/client/ISUI/LSDebugBTYConfirm.lua'): {'Edit Beauty', 'Is Negative'},
    ('LifestyleHobbies', 'media/lua/client/Painting/EaselCanvasContextMenu.lua'): {' / 100 %%'},
    ('LifestyleHobbies', 'media/lua/client/Painting/Sculpting/SculptingWorkContextMenu.lua'): {' / 100 %%'},
}


def source_literal_label(inventory, path, label):
    row = inventory.row(path)
    if not row or label not in LITERAL_LABELS.get((row['sourceId'], row['selectedPath']), set()):
        return False
    original = row['original'].read_text(encoding='utf-8', errors='ignore')
    return bool(re.search(r'\bgetText\(\s*["\']' + re.escape(label) + r'["\']\s*\)', original))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    parser.add_argument('--filter', action='store_true')
    args = parser.parse_args()
    inventory = current()
    if args.lua:
        for path in inventory.structural_lua():
            print(path.relative_to(ROOT).as_posix())
    elif args.filter:
        import sys
        allowed = {p.resolve() for p in inventory.structural_lua()}
        for name in sys.stdin.read().splitlines():
            if (ROOT / name).resolve() in allowed:
                print(name)
    else:
        print('PASS source scanner inventory:', len(inventory.runtime), 'sealed runtime destinations,',
              len(inventory.originals), 'original text rows,', len(inventory.runtime_lua()), 'executable Lua')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
