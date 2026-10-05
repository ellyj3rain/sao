"""Prepare explicitly authored people through the existing source owners.

Inputs describe generated schooling exposure. The empty learning ledger grants
no assessed mastery. This command preserves standard context/entry files so the
existing registry compiler can independently reconstruct the same result.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sys


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source-owner', 'archive', 'bank', 'curriculum', 'plan', 'profiles',
                 'policy', 'as-of-time', 'world-definition', 'world-owner', 'out'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--source-curriculum', type=Path, action='append', default=[])
    parser.add_argument('--exposure-events', type=Path,
                        help='Explicit person-keyed authored content histories; each pins its reconstructed profile/history')
    args = parser.parse_args(argv)
    source = args.source_owner.resolve() / 'tools'
    sys.path.insert(0, str(source))
    import decision_authoring as A
    import education_backgrounds as B
    import education_learning as L
    import education_runtime_registry as R
    from compiler import build, SPEC, EXPOSURE_SPECS

    out = args.out.resolve()
    receipt_path = out / 'preparation-receipt.json'
    A.require(not receipt_path.exists(), 'use a new output directory; retain the previous preparation receipt')
    out.mkdir(parents=True, exist_ok=True)
    input_paths = [args.curriculum, args.plan, args.profiles, args.policy, args.as_of_time,
                   args.world_definition, args.world_owner, *args.source_curriculum,
                   args.archive / 'acquisition.json', args.bank / 'manifest.json',
                   Path(__file__), Path(__file__).with_name('compiler.py'), SPEC]
    if args.exposure_events:
        input_paths += [args.exposure_events, *EXPOSURE_SPECS]
    input_paths += [source / (name + '.py') for name in ('decision_authoring', 'education_backgrounds',
        'education_curriculum', 'education_corpus', 'education_learning', 'education_runtime_registry',
        'education_assessment')]
    def pins():
        return {str(path.resolve()): sha(path) for path in input_paths}
    receipt = {'schema': 'sao-background-preparation-receipt/1', 'status': 'RUNNING',
        'command': [sys.executable, str(Path(__file__).resolve()), *(argv if argv is not None else sys.argv[1:])],
        'inputsBefore': pins(), 'completedPeople': [],
        'standing': 'explicit generated schooling exposure; empty assessed-learning ledgers; no native skill grant'}
    def save():
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    save()
    try:
        curriculum = A.read(args.curriculum)
        curricula = [curriculum, *[A.read(path) for path in args.source_curriculum]]
        plan, profiles, policy = A.read(args.plan), A.read(args.profiles), A.read(args.policy)
        world, moment = A.read(args.world_owner), A.read(args.as_of_time)
        A.require(plan['worldOwner'] == world, 'authored plan and runtime world owner differ')
        A.require(type(profiles) is list and 1 <= len(profiles) <= R.MAX_ROWS, 'explicit profiles must be bounded')
        A.require(len({profile['id'] for profile in profiles}) == len(profiles), 'person profiles repeat an identity')
        backgrounds = B.generate_backgrounds(plan, curricula, args.archive)
        backgrounds_path = out / 'backgrounds.json'
        B.write_immutable(backgrounds_path, backgrounds)
        entries, entry_paths = [], []
        for index, profile in enumerate(profiles):
            folder = out / ('person-' + str(index + 1))
            history = B.generate_person(profile, backgrounds, plan, curricula, args.archive)
            exposure = B.compile_generated(curriculum, args.archive, plan, backgrounds, profile, history,
                                           source_curricula=curricula[1:])
            context = {'archive': args.archive.resolve(), 'curriculum': curriculum,
                'sourceCurricula': curricula[1:], 'plan': plan, 'backgrounds': backgrounds,
                'profile': profile, 'person': history, 'education': exposure}
            ledger = L.initialize(context, policy, args.bank, moment)
            for name, value in (('profile', profile), ('person', history), ('education', exposure), ('ledger', ledger)):
                B.write_immutable(folder / (name + '.json'), value)
            paths = {'archive': str(args.archive.resolve()), 'curriculum': str(args.curriculum.resolve()),
                'sourceCurricula': [str(path.resolve()) for path in args.source_curriculum],
                'plan': str(args.plan.resolve()), 'backgrounds': str(backgrounds_path),
                **{name: str(folder / (name + '.json')) for name in ('profile', 'person', 'education')}}
            B.write_immutable(folder / 'context.json', paths)
            entries.append({'context': context, 'ledger': ledger, 'policy': policy, 'bank': args.bank,
                'asOfTime': moment, 'teachers': None, 'maximumConcepts': 128})
            entry_paths.append({'context': str(folder / 'context.json'), 'ledger': str(folder / 'ledger.json'),
                'policy': str(args.policy.resolve()), 'bank': str(args.bank.resolve()),
                'asOfTime': str(args.as_of_time.resolve()), 'teachers': None, 'maximumConcepts': 128})
            receipt['completedPeople'].append({'personId': profile['id'], 'birthYear': profile['birthYear'],
                'asOfYear': profile['asOfYear'], 'exposureCandidates': len(exposure['exposureCandidates'])})
            save()
            print('PREPARED generated exposure: ' + profile['id'], flush=True)
        B.write_immutable(out / 'persons.json', entry_paths)
        registry = build(args.world_definition.read_bytes(), world, entries,
                         A.read(args.exposure_events) if args.exposure_events else None)
        B.write_immutable(out / 'registry.json', registry)
        receipt['inputsAfter'] = pins()
        A.require(receipt['inputsAfter'] == receipt['inputsBefore'], 'preparation input drift')
        receipt['registrySha256'] = sha(out / 'registry.json')
        receipt['sourceBankSha256'] = registry['sourceBankSha256']
        receipt['sourceArchiveSha256'] = registry['sourceArchiveSha256']
        receipt['personalMeaningCounts'] = {row['personId']: len(row['backgroundRelations']) for row in registry['rows']}
        receipt['outputs'] = {str(path.relative_to(out)): sha(path) for path in out.rglob('*.json') if path != receipt_path}
        receipt.update(status='PASS', exit=0)
        save()
        print('PASS prepared registry: ' + receipt['registrySha256'], flush=True)
        return 0
    except Exception as error:
        receipt.update(status='FAIL', exit=1, failure=str(error))
        save()
        raise


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print('REFUSED background preparation: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
