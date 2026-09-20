#!/usr/bin/env python3
"""Border 76: canonical counts distinguish labels, test files and gate scripts.

Count the gate's direct Python calls and named mirror loop, including command
substitution calls. Comments and prose mentions are not invocations. The highest
printed border label is a sequence coordinate, not a count of active borders.
"""
import ast
import pathlib
import re
import shlex
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
CLAIMS = (
    ("A-batch documents", "a", "{n} A-batches"),
    ("B-batch records", "b", "{n} B-batches"),
    ("gated test files", "tests", "gate invokes {n} `*_test.py` files"),
    ("other gate scripts", "other", "{n} other Python entry points"),
    ("distinct gate scripts", "scripts", "{n} distinct scripts"),
    ("highest border label", "highest", "Border labels extend through {n}"),
)
# These are the executable call forms in check.sh: a direct command, `if !`,
# and a command substitution assigned to a variable. Anchor the command so
# a note quoting an example cannot become an invocation.
CALL = r'^\s*(?:if\s+!\s+)?(?:[A-Za-z_][A-Za-z_0-9]*=\$\()?"\$PY"\s+'
DIRECT = re.compile(CALL + r'"?tools/([a-z_0-9]+)\.py(?=["\s;)]|$)', re.M)
LOOP_CALL = re.compile(CALL + r'"tools/\$mirror\.py"', re.M)
LABEL = re.compile(r"^\s*(?:(\d+)\)\s|Border\s+(\d+)\b)")


def entry_points(source):
    code = "\n".join(line for line in source.splitlines()
                     if not line.lstrip().startswith("#"))
    names = set(DIRECT.findall(code))
    for loop in re.finditer(r"^for mirror in\s+(.*?)\ndo\s*\n(.*?)^done\s*$",
                            code, re.M | re.S):
        if LOOP_CALL.search(loop.group(2)):
            entries = shlex.split(loop.group(1).replace("\\\n", " "), comments=True)
            if any(not re.fullmatch(r"[a-z_0-9]+", name) for name in entries):
                raise RuntimeError("Gate mirror loop contains an unsupported entry")
            names.update(entries)
    return names


def printed_labels(source):
    """Read literal print prefixes; do not count examples or unused strings."""
    labels = set()
    for node in ast.walk(ast.parse(source)):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == "print" and node.args):
            continue
        value = node.args[0]
        if isinstance(value, ast.Constant) and isinstance(value.value, str):
            prefix = value.value
        elif isinstance(value, ast.JoinedStr):
            prefix = ""
            for part in value.values:
                if not isinstance(part, ast.Constant):
                    break
                prefix += part.value
        else:
            continue
        match = LABEL.match(prefix)
        if match:
            labels.add(int(match.group(1) or match.group(2)))
    return labels


def counts(root=ROOT):
    tools = root / "tools"
    names = entry_points((tools / "check.sh").read_text(encoding="utf-8-sig"))
    labels = set()
    for name in names:
        path = tools / (name + ".py")
        if not path.is_file():
            raise RuntimeError("Invoked gate script missing: " + path.name)
        labels.update(printed_labels(path.read_text(encoding="utf-8-sig")))
    tests = sum(name.endswith("_test") for name in names)
    # A records predate the log's current format. B records use the chronology,
    # including historical records whose document lived outside Batches/.
    a = sum(bool(re.match(r"^A\d+", path.name)) for path in (root / "Batches").glob("A*.md"))
    log = (root / "BATCH_LOG.md").read_text(encoding="utf-8-sig")
    b = len(set(re.findall(r"^\| \[(B\d+)\]", log, re.M)))
    return {"a": a, "b": b, "highest": max(labels, default=0),
            "tests": tests, "other": len(names) - tests, "scripts": len(names)}


def claim_faults(text, got):
    normalized = " ".join(text.split())
    return [f"SESSION_STATE.md must state `{phrase.format(n=got[key])}` ({label})"
            for label, key, phrase in CLAIMS
            if re.search(r"(?<!\d)" + re.escape(phrase.format(n=got[key])) + r"(?!\d)",
                         normalized) is None]


def controls():
    fixture = ('# "$PY" tools/comment_test.py\n'
               'note \'"$PY" tools/mentioned_test.py\'\n'
               'if ! "$PY" tools/direct_test.py; then\nfi\n'
               'if ! value=$("$PY" tools/helper.py); then\nfi\n'
               'for mirror in \\\n    loop_test\ndo\n'
               '    if ! "$PY" "tools/$mirror.py"; then\n    true\n    fi\ndone\n')
    with tempfile.TemporaryDirectory(prefix="sao-state-counts-") as tmp:
        root = pathlib.Path(tmp)
        tools = root / "tools"
        tools.mkdir()
        (root / "Batches").mkdir()
        (root / "Batches/A1.md").write_text("fixture", encoding="utf-8")
        (root / "BATCH_LOG.md").write_text("| [B1] | fixture |\n", encoding="utf-8")
        gate = tools / "check.sh"
        gate.write_text(fixture, encoding="utf-8")
        (tools / "direct_test.py").write_text('print("  170) PASS old form")\n', encoding="utf-8")
        loop = tools / "loop_test.py"
        loop.write_text('print("Border 175 PASS: current form")\n', encoding="utf-8")
        (tools / "helper.py").write_text('example = "  999) not printed"\n', encoding="utf-8")
        for name in ("comment_test", "mentioned_test", "ungated_test"):
            (tools / (name + ".py")).write_text('print("Border 999 PASS: not invoked")\n', encoding="utf-8")
        expected = {"a": 1, "b": 1, "highest": 175, "tests": 2, "other": 1, "scripts": 3}
        if counts(root) != expected:
            raise RuntimeError("State-count baseline miscounts executable scripts or printed labels")
        state = "\n".join(phrase.format(n=expected[key]) for _, key, phrase in CLAIMS)
        if claim_faults(state, counts(root)):
            raise RuntimeError("State-count fixture rejects its accurate claims")
        # Real file mutations change the reading and make the formerly correct
        # canonical claims fail, including the two defects found in C57.
        mutations = [
            (gate, fixture.replace('if ! "$PY" tools/direct_test.py; then\nfi\n', ""), "gated test files"),
            (gate, fixture.replace('if ! value=$("$PY" tools/helper.py); then\nfi\n', ""), "other gate scripts"),
            (loop, 'print("Border 176 PASS: advanced label")\n', "highest border label"),
        ]
        for path, changed, reason in mutations:
            original = path.read_text(encoding="utf-8")
            if original == changed:
                raise RuntimeError("State-count mutation did not land")
            path.write_text(changed, encoding="utf-8")
            try:
                if not any(reason in fault for fault in claim_faults(state, counts(root))):
                    raise RuntimeError("State-count control failed to reject changed " + reason)
            finally:
                path.write_text(original, encoding="utf-8")
    return 3


def main():
    print("THE DOCUMENT THAT SAYS WHERE THINGS STAND")
    try:
        control_count = controls()
        got = counts()
        if not all(got[key] for key in ("highest", "scripts", "b")):
            raise RuntimeError("State-count reading found no labels, gate scripts or B records")
        text = (ROOT / "SESSION_STATE.md").read_text(encoding="utf-8-sig")
        faults = claim_faults(text, got)
        for label, key, _ in CLAIMS:
            print(f"  {label}: {got[key]}")
        if faults:
            for fault in faults:
                print("  FAULT: " + fault)
            return 1
        print(f"  76) state counts: all {len(CLAIMS)} canonical figures match; {control_count} mutation controls refuse")
        return 0
    except (OSError, RuntimeError, SyntaxError, ValueError) as error:
        print("  FAULT: " + str(error))
        return 1


if __name__ == "__main__":
    sys.exit(main())
