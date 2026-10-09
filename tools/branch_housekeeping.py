"""Archive-first SAO Git maintenance; coordinate active writers before recentering."""
from __future__ import annotations
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

SOURCE = Path(__file__).resolve().parents[1]
BASE = SOURCE/"_scratch"/f"branch-housekeeping-{datetime.now(timezone.utc):%Y%m%d}"
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
OUT = BASE

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def save(name, value):
    path = OUT/name
    if path.exists():
        raise RuntimeError(f"Immutable receipt already exists: {path}")
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")

def read(name):
    return json.loads((OUT/name).read_text(encoding="utf-8"))

def run(args, cwd=SOURCE, data=None, allowed=(0,)):
    result = subprocess.run(args, cwd=cwd, env=ENV, input=data, capture_output=True)
    row = {"time": datetime.now(timezone.utc).isoformat(), "args": args, "cwd": str(cwd),
           "exit": result.returncode, "stdout": result.stdout.decode("utf-8", "replace"),
           "stderr": result.stderr.decode("utf-8", "replace")}
    with (OUT/"commands.jsonl").open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(row, ensure_ascii=False)+"\n")
    if result.returncode not in allowed:
        raise RuntimeError(json.dumps(row))
    return result.stdout

def git(*args, cwd=SOURCE, data=None, allowed=(0,)):
    return run(["git", "-C", str(cwd), *args], cwd=cwd, data=data, allowed=allowed).decode("utf-8", "replace").strip()

def refs(cwd=SOURCE):
    raw = git("for-each-ref", "--format=%(refname)%09%(objectname)%09%(upstream)%09%(symref)", cwd=cwd)
    return [dict(zip(("ref", "oid", "upstream", "symref"), line.split("\t"))) for line in raw.splitlines()]

def worktrees():
    rows = []
    for block in git("worktree", "list", "--porcelain").split("\n\n"):
        row = dict(line.partition(" ")[::2] for line in block.splitlines())
        if row:
            path = Path(row["worktree"])
            if path.is_dir():
                index = Path(git("rev-parse", "--git-path", "index", cwd=path))
                if not index.is_absolute():
                    index = path/index
                row.update(index=str(index), index_sha256=digest(index) if index.is_file() else None)
            rows.append(row)
    return rows

def remote_heads():
    return {line.split("\t")[1]: line.split("\t")[0] for line in git("ls-remote", "--heads", "origin").splitlines()}

def status():
    return run(["git", "-C", str(SOURCE), "status", "--porcelain=v1", "--untracked-files=no"]).decode("utf-8", "replace").splitlines()

def pin(relative):
    path = SOURCE/relative
    return {"path": relative, "exists": path.is_file(), "size": path.stat().st_size if path.is_file() else None,
            "sha256": digest(path) if path.is_file() else None}

def select_refs(current_refs, current_worktrees, prs, public, remote):
    owned_names = {row.get("branch") for row in current_worktrees}
    owned_tips = {row["HEAD"] for row in current_worktrees}
    candidates, retained, merge_results = [], [], []
    for row in current_refs:
        if not row["ref"].startswith("refs/heads/"):
            continue
        name = row["ref"][11:]
        matches = [pr for pr in prs if pr["state"]=="MERGED" and pr["baseRefName"]=="main"
                   and pr["headRefOid"]==row["oid"] and pr["mergeCommit"]]
        reason = None
        if row["ref"] in owned_names or row["oid"] in owned_tips:
            reason = "registered/checked-out branch or checked-out tip alias"
        elif name in ("main", "master") or name.startswith(("archive/", "snapshot/")):
            reason = "main or preserved provenance namespace"
        elif not matches:
            reason = "no exact merged-PR tip; active, closed-unmerged, open or ownership unresolved"
        else:
            valid = []
            for pr in matches:
                commit = pr["mergeCommit"]["oid"]
                result = subprocess.run(["git", "-C", str(SOURCE), "merge-base", "--is-ancestor", commit, public], env=ENV, capture_output=True)
                merge_results.append({"pr": pr["number"], "merge": commit, "public": public, "exit": result.returncode})
                if result.returncode==0:
                    valid.append(pr)
            if valid:
                candidates.append({**row, "prs": valid})
            else:
                reason = "merged PR is absent from present public main"
        if reason:
            retained.append({**row, "reason": reason})
    stale = [row for row in current_refs if row["ref"].startswith("refs/remotes/origin/") and not row["symref"]
             and row["ref"].replace("refs/remotes/origin/", "refs/heads/", 1) not in remote]
    # Hand-check the motivating ownership case and every selected candidate.
    require(not ({row["ref"] for row in candidates} & owned_names), 'Maintenance guard failed: not ({row["ref"] for row in candidates} & owned_names)')
    require(not ({row["oid"] for row in candidates} & owned_tips), 'Maintenance guard failed: not ({row["oid"] for row in candidates} & owned_tips)')
    require(all(row["prs"] and row["ref"].startswith("refs/heads/") for row in candidates), 'Maintenance guard failed: all(row["prs"] and row["ref"].startswith("refs/heads/") for row in candidates)')
    return candidates, retained, merge_results, stale

def archive():
    if (OUT/"archive-receipt.json").exists():
        raise RuntimeError("Use the recorded archive or a new run directory")
    current_refs = refs()
    current_worktrees = worktrees()
    remote = remote_heads()
    public = remote["refs/heads/main"]
    require(git("rev-parse", "origin/main")==public, "Reconcile remote main before archiving")
    prs = json.loads(run(["gh", "pr", "list", "--repo", "ellyj3rain/sao", "--state", "all", "--limit", "200",
                         "--json", "number,state,headRefName,headRefOid,baseRefName,mergedAt,mergeCommit,title,url"]))
    candidates, retained, merge_results, stale = select_refs(current_refs, current_worktrees, prs, public, remote)
    save("refs-pre-mutation.json", current_refs)
    save("worktrees-pre-mutation.json", current_worktrees)
    save("remote-pre-mutation.json", remote)
    save("prs-pre-mutation.json", prs)
    save("ancestry.json", merge_results)
    save("prune-plan.json", {"local": candidates, "stale_tracking": stale, "retained_local": retained,
                             "retained_remote": [{"ref": ref, "oid": oid, "prs": [p for p in prs if "refs/heads/"+p["headRefName"]==ref]}
                                                 for ref, oid in remote.items()]})
    common = Path(git("rev-parse", "--git-common-dir"))
    index = Path(git("rev-parse", "--git-path", "index"))
    backup = OUT/"source-index-pre-mutation.bin"
    backup.write_bytes(index.read_bytes())
    require(digest(backup)==digest(index), 'Maintenance guard failed: digest(backup)==digest(index)')
    names = set()
    for revision in ("HEAD", "origin/main"):
        names.update(run(["git", "-C", str(SOURCE), "ls-tree", "-r", "--name-only", "-z", revision]).decode().split("\0"))
    names.update(run(["git", "-C", str(SOURCE), "ls-files", "--others", "--exclude-standard", "-z"]).decode().split("\0"))
    names.discard("")
    print(f"Hashing {len(names)} tracked/public-main/untracked working-file paths", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        pins = list(pool.map(pin, sorted(names)))
    save("source-working-pins-pre-mutation.json", pins)
    raw_paths = [common/name for name in ("config", "packed-refs", "HEAD") if (common/name).is_file()]
    raw_paths.extend((common/"logs").rglob("*"))
    for directory in (common/"worktrees").iterdir():
        raw_paths.extend(path for path in (directory/"HEAD", directory/"logs"/"HEAD") if path.is_file())
    raw_paths = sorted({path for path in raw_paths if path.is_file()})
    reflog_objects = set()
    with zipfile.ZipFile(OUT/"git-metadata-before.zip", "x", compression=zipfile.ZIP_DEFLATED) as zipped:
        for path in raw_paths:
            content = path.read_bytes()
            zipped.writestr(path.relative_to(common).as_posix(), content)
            if "logs" in path.parts:
                for line in content.splitlines():
                    for part in line.split(b" ", 2)[:2]:
                        if len(part)==40 and part!=b"0"*40:
                            reflog_objects.add(part.decode("ascii"))
    bundle = OUT/"refs-and-reflogs-before.bundle"
    git("bundle", "create", str(bundle), "--all", "--reflog")
    git("bundle", "verify", str(bundle))
    restore = OUT/"restore-check.git"
    git("clone", "--mirror", "--no-hardlinks", str(bundle), str(restore))
    qualify_archive()

def qualify_archive():
    current_refs = read("refs-pre-mutation.json")
    current_worktrees = read("worktrees-pre-mutation.json")
    public = read("remote-pre-mutation.json")["refs/heads/main"]
    bundle, restore = OUT/"refs-and-reflogs-before.bundle", OUT/"restore-check.git"
    index, backup = Path(git("rev-parse", "--git-path", "index")), OUT/"source-index-pre-mutation.bin"
    require(digest(index)==digest(backup), "Source index changed during archival")
    reflog_objects = set()
    with zipfile.ZipFile(OUT/"git-metadata-before.zip") as zipped:
        require(zipped.testzip() is None, 'Maintenance guard failed: zipped.testzip() is None')
        for name in zipped.namelist():
            if "logs" in Path(name).parts:
                for line in zipped.read(name).splitlines():
                    for part in line.split(b" ", 2)[:2]:
                        if len(part)==40 and part!=b"0"*40:
                            reflog_objects.add(part.decode("ascii"))
    owned_tips = {row["HEAD"] for row in current_worktrees}
    restored = {row["ref"]: row["oid"] for row in refs(restore)}
    require(all(restored.get(row["ref"])==row["oid"] for row in current_refs), "Restore ref mismatch")
    objects = sorted(reflog_objects | {row["oid"] for row in current_refs} | owned_tips)
    checked = git("cat-file", "--batch-check=%(objectname) %(objecttype)", cwd=restore,
                  data=("\n".join(objects)+"\n").encode()).splitlines()
    source_types = git("cat-file", "--batch-check=%(objectname) %(objecttype)",
                       data=("\n".join(objects)+"\n").encode()).splitlines()
    require(len(checked)==len(objects) and checked==source_types and all(line.split(" ")[-1] in ("commit", "tree", "blob", "tag") for line in checked), "Restore objects incomplete or types differ")
    require({row["ref"]: row["oid"] for row in refs()}=={row["ref"]: row["oid"] for row in current_refs}, "Refs changed during archival")
    plan = read("prune-plan.json")
    save("archive-receipt.json", {"time": datetime.now(timezone.utc).isoformat(), "source": str(SOURCE),
         "head": git("rev-parse", "HEAD"), "branch": git("symbolic-ref", "--short", "HEAD"), "public_main": public,
         "index": str(index), "index_sha256": digest(index), "index_backup": str(backup),
         "staged": git("diff", "--cached", "--name-only"), "tracked_dirty_before": status(),
         "working_pins": len(read("source-working-pins-pre-mutation.json")), "refs": len(current_refs), "worktrees": len(current_worktrees),
         "local_prune": len(plan["local"]), "stale_tracking": len(plan["stale_tracking"]), "bundle": str(bundle),
         "bundle_bytes": bundle.stat().st_size, "bundle_sha256": digest(bundle), "metadata_sha256": digest(OUT/"git-metadata-before.zip"),
         "restore_check": str(restore), "restored_original_refs": len(current_refs), "restored_objects": len(objects),
         "restored_object_types": {kind: sum(line.endswith(" "+kind) for line in checked) for kind in ("commit", "tree", "blob", "tag")},
         "verifier_sha256": digest(Path(__file__)),
         "scope": "Exact refs, reflog-reachable histories and registered worktree tips restored in an isolated bare repo; no worktree deletion"})
    print(json.dumps({key: value for key, value in read("archive-receipt.json").items() if key!="tracked_dirty_before"}, indent=2), flush=True)

def prune():
    archived, plan = read("archive-receipt.json"), read("prune-plan.json")
    require(digest(Path(archived["bundle"]))==archived["bundle_sha256"], 'Maintenance guard failed: digest(Path(archived["bundle"]))==archived["bundle_sha256"]')
    require(git("rev-parse", "HEAD")==archived["head"] and digest(Path(archived["index"]))==archived["index_sha256"], 'Maintenance guard failed: git("rev-parse", "HEAD")==archived["head"] and digest(Path(archived["index"]))==archived["index_sha256"]')
    fresh = worktrees()
    require(not {row["ref"] for row in plan["local"]} & {row.get("branch") for row in fresh}, 'Maintenance guard failed: not {row["ref"] for row in plan["local"]} & {row.get("branch") for row in fresh}')
    require(not {row["oid"] for row in plan["local"]} & {row["HEAD"] for row in fresh}, 'Maintenance guard failed: not {row["oid"] for row in plan["local"]} & {row["HEAD"] for row in fresh}')
    transaction = "start\n"+"".join(f"delete {row['ref']} {row['oid']}\n" for row in plan["local"])+"prepare\ncommit\n"
    (OUT/"delete-refs-transaction.txt").write_text(transaction, encoding="utf-8")
    git("update-ref", "--stdin", data=transaction.encode())
    for row in plan["local"]:
        git("config", "--remove-section", "branch."+row["ref"][11:], allowed=(0, 128))
    git("fetch", "--prune", "--no-tags", "origin")
    after = refs()
    before = {row["ref"]: row["oid"] for row in read("refs-pre-mutation.json")}
    after_map = {row["ref"]: row["oid"] for row in after}
    removed = sorted(set(before)-set(after_map))
    expected = sorted({row["ref"] for row in plan["local"]+plan["stale_tracking"]})
    require(removed==expected, "Unexpected removed ref set")
    require(git("rev-parse", "HEAD")==archived["head"] and digest(Path(archived["index"]))==archived["index_sha256"], 'Maintenance guard failed: git("rev-parse", "HEAD")==archived["head"] and digest(Path(archived["index"]))==archived["index_sha256"]')
    save("refs-after-prune.json", after)
    save("prune-receipt.json", {"time": datetime.now(timezone.utc).isoformat(), "removed": removed,
         "local_deleted": len(plan["local"]), "tracking_deleted": len(plan["stale_tracking"]), "remote_heads_deleted": 0,
         "changed_retained_refs": [{"ref": ref, "before": before[ref], "after": after_map[ref]} for ref in before.keys() & after_map.keys() if before[ref]!=after_map[ref]],
         "source_head_index_unchanged": True, "worktrees_deleted": 0})
    print(json.dumps(read("prune-receipt.json"), indent=2), flush=True)

def recenter(target):
    archived = read("archive-receipt.json")
    require((OUT/"prune-receipt.json").exists(), 'Maintenance guard failed: (OUT/"prune-receipt.json").exists()')
    require(git("rev-parse", "HEAD")==archived["head"] and digest(Path(archived["index"]))==archived["index_sha256"], 'Maintenance guard failed: git("rev-parse", "HEAD")==archived["head"] and digest(Path(archived["index"]))==archived["index_sha256"]')
    require(not git("diff", "--cached", "--name-only"), "Preserve existing staged work")
    require(git("rev-list", "--count", "origin/main..HEAD")=="0", "Private source history must remain owned")
    public = remote_heads()["refs/heads/main"]
    require(git("rev-parse", "origin/main")==public==archived["public_main"], "Public main changed; reconcile before recenter")
    old = git("symbolic-ref", "--short", "HEAD")
    names = {row["ref"] for row in refs()}
    require(old==target or "refs/heads/"+target not in names, "Target branch collision")
    if old!=target:
        git("branch", "-m", target)
    git("reset", "--mixed", "origin/main")
    git("branch", "--set-upstream-to=origin/main", target)
    require(git("rev-parse", "HEAD")==git("rev-parse", "origin/main")==remote_heads()["refs/heads/main"]==public, 'Maintenance guard failed: git("rev-parse", "HEAD")==git("rev-parse", "origin/main")==remote_heads()["refs/heads/main"]==public')
    require(not git("diff", "--cached", "--name-only"), 'Maintenance guard failed: not git("diff", "--cached", "--name-only")')
    expected = read("source-working-pins-pre-mutation.json")
    print(f"Verifying all {len(expected)} working-file pins after recenter", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        actual = list(pool.map(pin, [row["path"] for row in expected]))
    differences = [{"before": left, "after": right} for left, right in zip(expected, actual) if left!=right]
    save("source-pin-postflight.json", {"checked": len(expected), "differences": differences})
    require(not differences, "Working bytes changed; report and inspect without reverting")
    previous = read("worktrees-pre-mutation.json")
    following = worktrees()
    require(len(previous)==len(following), 'Maintenance guard failed: len(previous)==len(following)')
    source_index = archived["index"]
    require(all(old_row["index_sha256"]==new_row["index_sha256"] for old_row, new_row in zip(previous, following)
               if old_row.get("index") and old_row["index"]!=source_index), "Another worktree index changed")
    after_refs = refs()
    save("refs-after-recenter.json", after_refs)
    save("worktrees-after-recenter.json", following)
    save("recenter-receipt.json", {"time": datetime.now(timezone.utc).isoformat(), "old_branch": old, "new_branch": target,
         "old_head": archived["head"], "new_head": public, "upstream": git("rev-parse", "--abbrev-ref", "@{upstream}"),
         "old_index_sha256": archived["index_sha256"], "new_index_sha256": digest(Path(source_index)),
         "tracked_dirty_before": archived["tracked_dirty_before"], "tracked_dirty_after": status(),
         "working_file_pins_unchanged": len(expected), "staged_files": 0, "other_worktree_indexes_unchanged": len(previous)-1,
         "local_heads_after": sum(row["ref"].startswith("refs/heads/") for row in after_refs),
         "remote_tracking_after": sum(row["ref"].startswith("refs/remotes/") for row in after_refs),
         "rollback": "Recover original branch objects from the local bundle; restore source-index-pre-mutation.bin only during a coordinated checkpoint. Current working bytes were never rewritten."})
    receipt = read("recenter-receipt.json")
    print(json.dumps({key: value for key, value in receipt.items() if not key.startswith("tracked_dirty")}, indent=2), flush=True)

def main():
    global OUT, BASE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", nargs="?", default="report", choices=("report", "archive", "verify", "prune", "recenter"))
    parser.add_argument("--records", default=str(BASE.relative_to(SOURCE)), help="Receipt root within the source worktree scratch directory")
    parser.add_argument("--run", default=datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ"), help="Immutable receipt run; repeat this exact value for later phases")
    parser.add_argument("--branch", help="Current batch branch following NEO.md; otherwise keep the current branch")
    parser.add_argument("--apply", action="store_true", help="Perform the explicitly coordinated ref/index mutation")
    args = parser.parse_args()
    BASE = (SOURCE/args.records).resolve()
    require(BASE.is_relative_to((SOURCE/"_scratch").resolve()), 'Maintenance guard failed: BASE.is_relative_to((SOURCE/"_scratch").resolve())')
    BASE.mkdir(parents=True, exist_ok=True)
    OUT = (BASE/args.run).resolve()
    require(OUT.is_relative_to(BASE) and OUT!=BASE, 'Maintenance guard failed: OUT.is_relative_to(BASE) and OUT!=BASE')
    OUT.mkdir(exist_ok=True)
    if args.phase=="report":
        present = refs()
        remote = remote_heads()
        registered = worktrees()
        prs = json.loads(run(["gh", "pr", "list", "--repo", "ellyj3rain/sao", "--state", "all", "--limit", "200", "--json", "number,state,headRefName,headRefOid,baseRefName,mergedAt,mergeCommit,title,url"]))
        selected, retained, ancestry, stale = select_refs(present, registered, prs, remote["refs/heads/main"], remote)
        reasons = {}
        for row in retained:
            reasons[row["reason"]] = reasons.get(row["reason"], 0)+1
        print(json.dumps({"source": str(SOURCE), "branch": git("symbolic-ref", "--short", "HEAD"),
             "head": git("rev-parse", "HEAD"), "public_main": remote["refs/heads/main"],
             "tracking_main": git("rev-parse", "origin/main"),
             "tracking_main_matches_remote": git("rev-parse", "origin/main")==remote["refs/heads/main"],
             "pr_inventory_rows": len(prs), "pr_inventory_limit": 200,
             "local_ahead": git("rev-list", "--count", "origin/main..HEAD"),
             "local_behind": git("rev-list", "--count", "HEAD..origin/main"),
             "local_heads": sum(row["ref"].startswith("refs/heads/") for row in present),
             "remote_tracking": sum(row["ref"].startswith("refs/remotes/") for row in present),
             "registered_worktrees": len(registered), "staged": git("diff", "--cached", "--name-only"),
             "eligible_completed_local_refs": len(selected), "stale_remote_tracking_refs": len(stale),
             "retained_local_reasons": reasons,
             "retained_remote_pr_states": {ref: [pr["state"] for pr in prs if "refs/heads/"+pr["headRefName"]==ref] for ref in remote},
             "receipt_run": str(OUT),
             "operation": "report only; choose an immutable run and coordinate active writers before prune/recenter"}, indent=2))
        return
    if args.phase in ("prune", "recenter") and not args.apply:
        parser.error("prune/recenter require an explicit --apply during the coordinated operation window")
    {"archive": archive, "verify": qualify_archive, "prune": prune, "recenter": lambda: recenter(args.branch or git("symbolic-ref", "--short", "HEAD"))}[args.phase]()

if __name__=="__main__":
    main()
