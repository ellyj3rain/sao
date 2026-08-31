#!/usr/bin/env python3
r"""Border 75 - the one protocol that is written to the save, unchecked.

Border 15 pairs every delimited protocol the Java side speaks against
the Lua that parses it, and it has printed the same line on every run:

    15) delimited protocols whose ends disagree: none (7 paired,
        1 unchecked)
           unchecked: hibernate -> hibernate (2 fields, '@') -
           no field parse found

It is right to say so. There is no Lua end. `SAO_Body` takes the packed
string straight from `SAOJavaBridge:hibernate(body)` and stores it on
the record; `SAO_Population` hands it straight back to
`SAOJavaBridge:awaken(body, rec.hibernation, elapsed)`. Lua carries the
string and never looks inside it.

So this protocol is **Java to the save to Java**, and it was the one
protocol with nothing checking that its two ends agree - while being,
as [B50] put it, the one where a corrupted row is somebody's inventory
rather than a bad frame the next tick replaces.

A survivor hibernates when the player walks away and awakens when they
come back, so the write and the read are separated by minutes of play,
by a save, and by however many versions of this mod. Adding a key to
the packer and forgetting the reader loses that field silently: the
switch has no default that complains, and `awaken` returns what it
managed to restore.

WHAT IS CHECKED
---------------
  * every `key=` the packer writes has a `case "key"` in the reader
  * every `case "key"` the reader handles is a key the packer writes
  * the version prefix the packer stamps is one the reader accepts
  * the nested separators - `worn` is comma-separated, `items` is
    `type@condition*count` - are split by the reader on the same
    characters the packer joins them with

The last is what [B50]'s Border 70 protects from the OUTSIDE (nothing
foreign carries a delimiter into the string); this protects it from the
inside (both ends mean the same thing by it).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOHibernation.java"
PACK = "hibernate"
READ = "awaken"

# Keys the packer may write and the reader may skip, with why. Empty:
# every key must be paired both ways. It exists so that a deliberate
# one-way field has to be written down rather than argued in a commit.
ONE_WAY = {}


def method(src, name):
    """One Java method's body, by brace balance."""
    m = re.search(r"\b(?:public|private|protected|static)[^;{}]*?\b"
                  + re.escape(name) + r"\s*\(", src)
    if not m:
        return None
    start = src.find("{", m.end())
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start:i]
    return None


def main():
    faults = []
    print("=" * 74)
    print("THE ONE PROTOCOL THAT IS WRITTEN TO THE SAVE")
    print("=" * 74)

    if not SRC.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAOHibernation.java is gone, and it is both ends of "
              "this protocol")
        return 1
    src = SRC.read_text(encoding="utf-8", errors="ignore")

    packer, reader = method(src, PACK), method(src, READ)
    if packer is None or reader is None:
        print()
        print("VERDICT:")
        missing = PACK if packer is None else READ
        print(f"  FAULT: SAOHibernation.java has no `{missing}` - either it "
              "was renamed, in which case this border has been reading the "
              "wrong half, or one end of the protocol is gone")
        return 1

    # The packer writes `";key="` or `"v2;primary="`. Take the key out
    # of every appended literal that ends in `=`.
    written = set()
    version = None
    for lit in re.findall(r'append\(\s*"([^"]*)"', packer):
        m = re.match(r"^(v\d+);(\w+)=$", lit)
        if m:
            version = m.group(1)
            written.add(m.group(2))
            continue
        m = re.match(r"^;(\w+)=$", lit)
        if m:
            written.add(m.group(1))

    handled = set(re.findall(r'case\s+"(\w+)"', reader))
    accepts = set(re.findall(r'startsWith\("(v\d+);"\)', reader))

    print(f"  keys the packer writes : {len(written)}  "
          f"({', '.join(sorted(written)) or 'none'})")
    print(f"  keys the reader handles: {len(handled)}  "
          f"({', '.join(sorted(handled)) or 'none'})")
    print(f"  version stamped/accepted: {version} / "
          f"{', '.join(sorted(accepts)) or 'none'}")

    if not written or not handled:
        faults.append(
            "one side of this protocol read as empty - no keys written, or "
            "none handled - which cannot be true of a record that restores "
            "an inventory. The reading failed rather than the code being "
            "clean")

    for key in sorted(written - handled - set(ONE_WAY)):
        faults.append(
            f"the packer writes `{key}=` into the hibernation record and "
            "nothing reads it back. The reader's switch has no default that "
            "complains, so this field is written to the SAVE and dropped on "
            "the way out, in silence, for every survivor who hibernates")
    for key in sorted(handled - written - set(ONE_WAY)):
        faults.append(
            f"the reader handles `{key}` and the packer never writes it. "
            "Either a field was dropped from the packer - in which case "
            "every hibernating survivor is losing it - or this case is dead "
            "and says the record carries something it does not")
    for key, why in sorted(ONE_WAY.items()):
        if key in written and key in handled:
            faults.append(
                f"`{key}` is declared as one-way ({why}) and both ends now "
                "speak it, so the exemption is describing nothing")

    if version is None:
        faults.append(
            "the packer stamps no version prefix. The record is in the save "
            "and outlives the code that wrote it; without a version the "
            "reader cannot tell an old row from a corrupt one")
    elif version not in accepts:
        faults.append(
            f"the packer stamps `{version};` and the reader accepts "
            f"{sorted(accepts)}. Every record written from now on would be "
            "rejected whole - a survivor walks away and comes back with an "
            "empty inventory")

    # The nested shapes: what the packer joins with, the reader splits
    # on. `items` is `type@cond*count` and `worn` is a plain list.
    # Every punctuation character in any literal the packer writes -
    # not just single-character `append` calls. The first draft looked
    # only at those and reported two faults of its own making: the
    # packer writes `;` inside `";h="` and `@` by concatenation
    # (`packType(type) + "@" + condPct`), neither of which is an
    # `append('x')`. `=` and `-` are excluded because `=` joins a key
    # to its value on every field and `-` is the marker for an empty
    # hand, so neither separates records.
    joins = {c for lit in re.findall(r"'(.)'|\"([^\"]*)\"", packer)
             for c in (lit[0] + lit[1])
             if not c.isalnum() and c not in "=- "}
    splits = set(re.findall(r'split\("(?:\\\\)?(.)"\)', reader))
    splits |= set(re.findall(r"indexOf\('(.)'\)", reader))
    splits |= set(re.findall(r"lastIndexOf\('(.)'\)", reader))
    print(f"  packer joins on        : {sorted(joins) or 'none'}")
    print(f"  reader splits on       : {sorted(splits) or 'none'}")
    for ch in sorted(joins - splits):
        faults.append(
            f"the packer joins on {ch!r} and the reader never splits or "
            "searches on it, so whatever that character separates arrives "
            "back as one run of text")
    for ch in sorted(splits - joins - {"=", "-"}):
        faults.append(
            f"the reader splits on {ch!r} and the packer never joins with "
            "it. It is parsing a shape this packer does not write")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  75) hibernation pact: all {len(written)} fields of the record "
          "written to the save are read back, on a version the reader "
          "accepts, with the same separators at both ends")
    return 0


if __name__ == "__main__":
    sys.exit(main())
