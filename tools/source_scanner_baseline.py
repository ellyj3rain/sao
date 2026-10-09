"""Exact original source sites for static SAO policy scanners.

The sealed scanner inventory verifies current and original bytes first. A
preserved source site retains its source domain; additions and changes are
scanned as current authored work. Ordered line matching admits each original
occurrence once, so copying an old line does not admit an extra occurrence.
"""
import difflib
import json
import pathlib
import re
from functools import lru_cache

from lua_read import strip_lua
from scanner_inventory import ROOT, current, safe_path, sha


def matching_lines(original, runtime, *, comments=False):
    """One-based runtime lines that preserve ordered original source text."""
    if not comments:
        original = strip_lua(original, strings=False)
        runtime = strip_lua(runtime, strings=False)
    old = [line.strip() for line in original.splitlines()]
    new = [line.strip() for line in runtime.splitlines()]
    matched = set()
    for block in difflib.SequenceMatcher(None, old, new).get_matching_blocks():
        matched.update(range(block.b + 1, block.b + block.size + 1))
    return matched


class Baseline:
    def __init__(self, inventory=None):
        controls()
        self.inventory = current() if inventory is None else inventory
        self._lines = {}
        self._consumers = json.loads((ROOT / 'tools/source_scanner_consumers.json').read_text())['consumers']

    def preserved(self, path, line, *, comments=False):
        path = pathlib.Path(path).resolve()
        row = self.inventory.row(path)
        key = (path, comments)
        if key not in self._lines:
            runtime = path.read_text(encoding='utf-8', errors='ignore')
            if row:
                self._lines[key] = matching_lines(
                    row['original'].read_text(encoding='utf-8', errors='ignore'),
                    runtime, comments=comments)
            elif path in self.inventory.originals:
                # Inventory construction already checked these retained
                # original bytes against the source row and family seal.
                self._lines[key] = set(range(1, len(runtime.splitlines()) + 1))
            elif not comments and path.is_relative_to(ROOT):
                consumer = self._consumers.get(path.relative_to(ROOT).as_posix())
                self._lines[key] = set()
                if consumer and sha(path.read_bytes()) == consumer['sha256']:
                    lines = normalised(path)
                    for offset in range(len(lines) - 14):
                        window = lines[offset:offset + 15]
                        block = '\n'.join(text for _, text in window)
                        if self.inventory.original_block(path, block, normalised):
                            self._lines[key].update(line for line, _ in window)
            else:
                self._lines[key] = set()
        return line in self._lines[key]

    def authored_matches(self, path, source, pattern):
        for match in pattern.finditer(source):
            first = source.count('\n', 0, match.start()) + 1
            last = source.count('\n', 0, match.end()) + 1
            if not all(self.preserved(path, line) for line in range(first, last + 1)):
                yield match


def normalised(path):
    code = strip_lua(path.read_text(encoding='utf-8', errors='ignore'), strings=False)
    return [(line, re.sub(r'\s+', ' ', text.strip()))
            for line, text in enumerate(code.splitlines(), 1) if text.strip()]


def source_translation_values(relative, inventory=None):
    """Exact retained source locale values from the qualified merge inputs."""
    inventory = current() if inventory is None else inventory
    rows = [row for row in inventory.manifest['files'] if row['selectedPath'] == relative]
    values = {}
    for row in rows:
        source = inventory.manifest['sources'][row['sourceId']]
        original = safe_path(inventory.package, source['originalRoot'] + '/' + relative)
        destination = safe_path(inventory.package, row['destination'])
        if sha(original.read_bytes()) != row['sourceSha256'] or sha(destination.read_bytes()) != row['destinationSha256']:
            raise ValueError('source locale provenance differs: ' + relative)
        # The premerged destination carries the conflict-checked common values;
        # original bytes and each source owner remain pinned in the manifest.
        values.update(json.loads(destination.read_text(encoding='utf-8-sig')))
    return values


def source_registration_present(relative, inventory=None):
    inventory = current() if inventory is None else inventory
    rows = [row for row in inventory.manifest['mergeRequired'] if row['enginePath'] == relative]
    if len(rows) != 1:
        return False
    row = rows[0]
    original = safe_path(inventory.package, row['fragment'])
    runtime = safe_path(inventory.package, relative)
    return (runtime.is_file() and sha(runtime.read_bytes()) == row['sha256']
            and sha(original.read_bytes()) == row['sha256'])


@lru_cache(maxsize=1)
def controls():
    original = 'local items = {}\nprint("old")\ntable.sort(items)\n'
    assert matching_lines(original, '-- integrated\n' + original) >= {2, 3, 4}
    changed = original.replace('print("old")', 'print("new")')
    assert 2 not in matching_lines(original, changed)
    added = original + 'print("new")\n'
    assert 4 not in matching_lines(original, added)
    duplicate = original + 'print("old")\n'
    admitted = matching_lines(original, duplicate)
    assert sum(line in admitted for line in (2, 4)) == 1
    assert 1 not in matching_lines('-- old\nprint("old")\n', '-- new\nprint("old")\n', comments=True)
    assert matching_lines('x = 1\ny = 2\n', 'y = 2\nx = 1\n') != {1, 2}
    return 6
