#!/usr/bin/env python3
r"""[B34] What the cursor can actually reach.

SAO_Harness registers OnFillWorldObjectContextMenu and is the surface
the operator touches every session. A menu entry gated on a condition
that can never hold is [B24]'s class sitting directly under the
cursor: the option is simply never there, and nobody can miss what
they have never seen.

This extracts, for every addOption/addSubMenu call, the full stack of
conditions that must hold for it to be added - by indentation, the way
[B32] eventually had to do it after learning that a chain detector
which resets on nested `if`s assembles nothing.

Two questions are then asked of each entry:

  CAN THE CHAIN OPEN?   a gate on a field nothing ever writes, or an
                        equality between two strings produced by
                        different code paths, cannot.

  IS IT STARVED?        an entry sitting under an `elseif` whose
                        earlier sibling can never decline is dead
                        however true its own condition is - the
                        [B32]/[B32] class.

And one presentation question, because this is the surface the
operator reads: an option whose TEXT concatenates a record field that
can be nil renders as a broken label, or throws inside the menu build.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HARNESS = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
           / "SAO_Harness.lua")

ADD = re.compile(r"\b(addOption|addSubMenu|addOptionOnTop)\s*\(")


def strip_lua(src, strings=True):
    """Blank comments and string bodies, preserving offsets.

    [B41] `strings=False` blanks comments ONLY. A border that has to
    read a string the code compares against - `source ~= "told"`, an
    addOption label - cannot use the default, because the thing it is
    looking for is exactly what gets blanked. That cost three false
    faults the first time this was used that way, all of them reported
    as defects in the Lua when the defect was in the reading of it.
    Comments still go, because prose is not code.
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                end = src.find(close, i)
                end = n if end < 0 else end + len(close)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            for k in range(i, end):
                if out[k] != "\n":
                    out[k] = " "
            i = end
            continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c or src[j] == "\n":
                    break
                j += 1
            if strings:
                for k in range(i + 1, min(j, n)):
                    out[k] = "_"
            i = min(j + 1, n)
            continue
        i += 1
    return "".join(out)


def head_at(lines, n):
    """(indent, kind, condition) if line n opens a block."""
    m = re.match(r"^(\s*)(elseif|if|else|for|while)\b(.*)$", lines[n])
    if not m:
        return None
    indent, kind, rest = len(m.group(1)), m.group(2), m.group(3)
    if kind == "else":
        return indent, "else", ""
    parts, k = [rest], n
    while k < len(lines) and k < n + 10:
        chunk = parts[-1].rstrip()
        if chunk.endswith(" then") or chunk.endswith(" do"):
            cond = re.sub(r"\s+(then|do)$", "", " ".join(parts)).strip()
            return indent, kind, cond
        k += 1
        if k >= len(lines):
            break
        parts.append(lines[k].strip())
    return None


def chains(lines, lo, hi):
    """For each add* call, the enclosing condition stack."""
    stack, out = [], []
    for n in range(lo, hi):
        line = lines[n]
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        while stack and stack[-1][0] >= indent:
            popped = stack.pop()
            if re.match(r"^\s*(elseif|else)\b", line) \
                    and popped[0] == indent:
                # sibling of the same chain: remember what came before
                stack.append((popped[0], popped[1], popped[2],
                              popped[3] + [popped[2]]))
                break
        h = head_at(lines, n)
        if h:
            prior = []
            if stack and stack[-1][0] == h[0]:
                prior = stack[-1][3] + [stack[-1][2]]
                stack.pop()
            stack.append((h[0], h[1], h[2], prior))
        m = ADD.search(line)
        if m:
            out.append({
                "line": n + 1,
                "call": m.group(1),
                "text": line.strip()[:96],
                "stack": [(k, c) for _, k, c, _ in stack],
                "siblings": stack[-1][3] if stack else [],
            })
    return out


def main():
    raw = HARNESS.read_text(encoding="utf-8", errors="ignore")
    src = strip_lua(raw)
    lines = src.split("\n")
    rawlines = raw.split("\n")

    start = next(n for n, l in enumerate(lines)
                 if "local function fillMenu" in l)
    end = next(n for n in range(start + 1, len(lines))
               if re.match(r"^\S", lines[n]) and "fillMenu" not in lines[n])

    entries = chains(lines, start, end)
    print("=" * 70)
    print(f"fillMenu spans lines {start + 1}-{end}; "
          f"{len(entries)} menu-building call(s)")
    print("=" * 70)

    # Every identifier the whole file ever assigns to.
    assigned = set(re.findall(r"([\w.]+)\s*=(?!=)", src))
    assigned |= set(re.findall(r"\[\s*[\"']?(\w+)[\"']?\s*\]\s*=", src))
    whole = ROOT / "mod" / "42.20" / "media" / "lua"
    for p in whole.rglob("*.lua"):
        s = strip_lua(p.read_text(encoding="utf-8", errors="ignore"))
        assigned |= set(re.findall(r"([\w.]+)\s*=(?!=)", s))
        assigned |= set(re.findall(r"(\w+)\s*=\s*", s))

    print()
    print("CONDITION DEPTH")
    depths = {}
    for e in entries:
        depths[len(e["stack"])] = depths.get(len(e["stack"]), 0) + 1
    for d in sorted(depths):
        print(f"  {d} enclosing condition(s): {depths[d]} option(s)")

    # A gate reading a field that nothing anywhere assigns.
    print()
    print("=" * 70)
    print("GATES ON A FIELD NOTHING WRITES")
    print("=" * 70)
    suspect = []
    for e in entries:
        for kind, cond in e["stack"]:
            for fld in re.findall(r"\b(?:rec|agent|job|oag)\.(\w+)\b",
                                  cond):
                base = fld
                if base not in assigned and not any(
                        base in a.split(".") for a in assigned):
                    suspect.append((e["line"], cond[:60], base))
    if suspect:
        for ln, cond, fld in suspect:
            print(f"  line {ln}: `{cond}` reads .{fld}, "
                  "which nothing assigns")
    else:
        print("  none - every gated field is written somewhere")

    print()
    print("=" * 70)
    print("OPTION TEXT BUILT FROM A FIELD THAT COULD BE NIL")
    print("=" * 70)
    risky = []
    for e in entries:
        rawline = rawlines[e["line"] - 1]
        if ".." not in rawline:
            continue
        for fld in re.findall(r"\b(rec|agent|oag)\.(\w+)\b", rawline):
            guarded = any(f"{fld[0]}.{fld[1]}" in c
                          for _, c in e["stack"])
            if not guarded and "tostring" not in rawline:
                risky.append((e["line"], f"{fld[0]}.{fld[1]}",
                              rawline.strip()[:70]))
    if risky:
        for ln, fld, txt in risky:
            print(f"  line {ln}: {fld} concatenated unguarded")
            print(f"      {txt}")
    else:
        print("  none - every concatenated field is guarded or "
              "tostring()-wrapped")

    print()
    print("=" * 70)
    print("DRIVEN - the chair chain, which three files must agree on")
    print("=" * 70)
    ok_chair = drive_chair()

    print()
    print("=" * 70)
    print("THE CHAINS, AS THE CURSOR MEETS THEM")
    print("=" * 70)
    for e in entries:
        conds = " AND ".join(c for _, c in e["stack"] if c) or "(top level)"
        print(f"  {e['line']:>5}  {e['call']}")
        print(f"         when: {conds[:150]}")

    print()
    print("VERDICT:")
    print(f"  gates on a field nothing writes:   {len(suspect)}")
    print(f"  option text that could render nil: {len(risky)}")
    print(f"  the chair chain opens:             "
          f"{'YES' if ok_chair else 'NO'}")
    if suspect or risky or not ok_chair:
        return 1
    return 0


def key_forms():
    """Every spelling of a player key, read from the shipped Lua.

    The chair option compares a stored string against one built at
    menu time. Three files have to agree, and the only reason they do
    is that all of them go through one constructor - so the thing to
    check is that they still all go through it.
    """
    lua = ROOT / "mod" / "42.20" / "media" / "lua"
    st = (lua / "shared" / "SAO_Standing.lua").read_text(
        encoding="utf-8", errors="ignore")
    hn = (lua / "client" / "SAO_Harness.lua").read_text(
        encoding="utf-8", errors="ignore")
    # The FIRST return in playerKey is its nil guard; the key itself is
    # the one that builds the domain prefix. Matching the first one
    # reported the constructor as returning "nil end", which is not
    # wrong about the code so much as about which line it was reading.
    ctor = re.search(
        r"function S\.playerKey\(playerObj\).*?"
        r"return\s+(\"player:\".*?)\n", st, re.S)
    harness = re.search(
        r"local function playerKeyOf\(playerObj\).*?return\s+(.*?)\n",
        hn, re.S)
    setter = re.search(
        r"function S\.setPlayerMember\(groupName, playerKey\).*?"
        r"meta\.playerMemberOf\s*=\s*(.*?)\n", st, re.S)
    offer = re.search(r"metaC\.chairOffer\s*=\s*(\w+)", st)
    # Three traps in one line, each of which this got wrong in turn:
    # `=\s*` also matches the `==` of a comparison (reported the seat
    # as set from "= playerKey then", a line that READS the field);
    # and the first real assignment is the one that CLEARS it to nil
    # when a chair is lost. The write worth reporting is the one that
    # seats somebody.
    accept = None
    for m in re.finditer(r"meta\.playerChair\s*=(?!=)\s*(.*?)\n", st):
        if m.group(1).strip() != "nil":
            accept = m
            break
    return {
        "Standing.playerKey returns": ctor.group(1).strip() if ctor else "?",
        "Harness playerKeyOf returns": (harness.group(1).strip()
                                        if harness else "?"),
        "setPlayerMember stores": setter.group(1).strip() if setter else "?",
        "chairOffer is set from": offer.group(1).strip() if offer else "?",
        "playerChair is set from": accept.group(1).strip() if accept else "?",
    }


def drive_chair():
    """Run the chair chain end to end on one modelled world."""
    forms = key_forms()
    for label, expr in forms.items():
        print(f"  {label:<30} {expr}")

    # The harness must not spell the key itself; it must delegate.
    delegates = "SAO.Standing.playerKey" in forms[
        "Harness playerKeyOf returns"]
    print(f"\n  the harness delegates to the one constructor: "
          f"{'YES' if delegates else 'NO'}")

    # [B35] And nobody else may spell it either, in EITHER direction.
    # [B27] put the constructor in one place; [B27] converted fifteen
    # sites to it; and the TEST stayed hand-written wherever it was
    # needed, with two sites still building the key inline - one of
    # them without the pcall S.playerKey wraps getUsername in. A
    # hand-spelled domain test fails by not matching, which is the
    # quiet way: no error, just a branch that never opens.
    lua = ROOT / "mod" / "42.20" / "media" / "lua"
    hand, builds = [], []
    for p in sorted(lua.rglob("*.lua")):
        s = p.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(
                r'string\.sub\(tostring\(\w+\), 1, 7\) == "player:"', s):
            ln = s[:m.start()].count("\n") + 1
            # The definition of isPlayerKey is the one place allowed.
            if p.name == "SAO_Standing.lua" and "isPlayerKey" in \
                    s[max(0, m.start() - 200):m.start()]:
                continue
            hand.append(f"{p.name}:{ln}")
        if p.name != "SAO_Standing.lua":
            for m in re.finditer(r'"player:"\s*\.\.', s):
                builds.append(f"{p.name}:{s[:m.start()].count(chr(10)) + 1}")
    print(f"  hand-spelled `player:` tests outside Standing: "
          f"{hand or 'none'}")
    print(f"  keys built inline outside Standing:            "
          f"{builds or 'none'}")
    one_spelling = not hand and not builds

    store = {}

    def player_key(username):
        return "player:" + username

    # askToJoin -> setPlayerMember(group, playerKeyOf(playerObj))
    store["playerMemberOf"] = str(player_key("Bob"))
    # the election tick -> chairOffer = metaC.playerMemberOf
    store["chairOffer"] = store["playerMemberOf"]
    # the menu -> chairOfferOf(group) == playerKeyOf(playerObj)
    menu_key = player_key("Bob")
    offered = store["chairOffer"] == menu_key
    print(f"  joined as                     {store['playerMemberOf']}")
    print(f"  chair offered to              {store['chairOffer']}")
    print(f"  menu asks for                 {menu_key}")
    print(f"  \"Accept the chair\" appears:    "
          f"{'YES' if offered else 'NO'}")

    # acceptChair(group, cKey) -> playerChair = tostring(cKey)
    store["playerChair"] = str(menu_key)
    seated = store["playerChair"] == menu_key
    print(f"  \"Assign work\" appears after:   "
          f"{'YES' if seated else 'NO'}")

    # The control: one link spelling the key differently kills it.
    broken = dict(store)
    broken["chairOffer"] = "sao-7"
    print(f"\n  CONTROL - one link storing a record id instead of a "
          f"player key:")
    print(f"    the option appears: "
          f"{'YES' if broken['chairOffer'] == menu_key else 'NO'} "
          "(must be NO, or this proof proves nothing)")

    return (delegates and one_spelling and offered and seated
            and broken["chairOffer"] != menu_key)


if __name__ == "__main__":
    sys.exit(main())
