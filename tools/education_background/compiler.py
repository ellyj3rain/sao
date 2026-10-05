"""Extend the existing source-reconstructed registry with dated exposure meanings.

The Speakeasy owner reconstructs schooling and any assessment ledger. This
adapter adds an explicitly authored meaning of one literal source passage.
Exposure can support a defeasible expectation; it does not certify retention.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import argparse
import sys

SPEC = Path(__file__).with_name('household-stove-cooking-v1.json')
EXPOSURE_SPECS = [Path(__file__).with_name(name) for name in
                  ('workshop-tools-v1.json', 'civic-mutual-assistance-v1.json', 'workbench-tools-v1.json')]


def project_authored_meaning(projection, receipt, history_sha, bindings, person_id, admitted_at_tick, archive):
    """Project exact held content from an already reconstructed personal receipt.

    The caller owns history reconstruction. This pure content adapter checks its
    selected source again, so adding a reviewed projection to a retained receipt
    does not require generating the same personal history or assessment twice.
    """
    import decision_authoring as A
    import education_backgrounds as B
    import education_corpus as C
    receipt = B.seal(B.checked(receipt, 'authored exposure receipt'))
    event, unit = receipt['event'], receipt['unit']
    A.require(receipt['personId'] == person_id and projection['unit'] == unit
              and projection['courseId'] == event['courseId'] and unit['id'] == event['unitId'],
              'authored meaning source selection differs')
    source = next(s for s in C.verified_sources(archive) if s['id'] == unit['sourceId'])
    selected = next(f for f in source['files'] if f['path'] == unit['selector']['sourcePath'])
    _, text, _ = next(C.texts({**source, 'files': [selected]}, archive))
    selection = unit['selector']
    excerpt = text[selection['startCharacter']:selection['endCharacter']]
    A.require(hashlib.sha256(excerpt.encode()).hexdigest() == selection['excerptSha256']
              and projection['statementText'] in ' '.join(excerpt.split())
              and hashlib.sha256(projection['statementText'].encode()).hexdigest() == projection['statementSha256'],
              'authored meaning literal source differs')
    return B.seal({'schema': 'sao-person-background-meaning/2',
        'personId': person_id, 'bindings': copy.deepcopy(bindings),
        'projection': copy.deepcopy(projection), 'projectionSha256': A.digest(projection),
        'contentExposureHistorySha256': history_sha, 'acquisition': copy.deepcopy(receipt),
        'admittedAtTick': admitted_at_tick,
        'standing': 'defeasible-exposure-prior; retention-mastery-and-assent-unassessed'})


def build(world_definition, world_owner, entries, authored_histories=None):
    # Import only after the caller selects the existing, pinned Speakeasy owner.
    import decision_authoring as A
    import education_backgrounds as B
    import education_corpus as C
    import education_curriculum as K
    import education_learning as L
    import education_runtime_registry as R
    registry = R.build_registry(world_definition, world_owner, entries)
    specification = json.loads(SPEC.read_text(encoding='utf-8'))
    contexts = {entry['context']['profile']['id']: entry for entry in entries}
    if authored_histories is not None:
        A.require(type(authored_histories) is dict and set(authored_histories) <= set(contexts),
                  'authored histories select an unknown person')
    rows = []
    for original in registry['rows']:
        row = B.checked(original, 'existing registry row')
        entry = contexts[row['personId']]
        context = entry['context']
        # This is deliberately source reconstruction, not trust in a passed label.
        refs = L.verified_context(context)
        A.require(all(row['bindings'][key] == value for key, value in refs.items()),
                  'background context differs from registered person')
        roots = []
        for exposure in context['education']['exposureCandidates']:
            if exposure['courseId'] != specification['courseId'] or exposure['unitId'] != specification['unit']['id']:
                continue
            A.require(exposure['personId'] == row['personId'] and exposure['attendance'] == 'attended',
                      'background exposure belongs to another person or was not attended')
            curriculum = next((value for value in [context['curriculum'], *context['sourceCurricula']]
                               if K.reference(value) == exposure['sourceCurriculumRef']), None)
            A.require(curriculum is not None, 'background curriculum unavailable')
            unit = next((unit for course in curriculum['courses'] if course['id'] == exposure['courseId']
                         for unit in course['units'] if unit['id'] == exposure['unitId']), None)
            A.require(unit == specification['unit'], 'background meaning source selection differs')
            source = next(value for value in C.verified_sources(context['archive']) if value['id'] == unit['sourceId'])
            selected_file = next(value for value in source['files'] if value['path'] == unit['selector']['sourcePath'])
            _, text, _ = next(C.texts({**source, 'files': [selected_file]}, context['archive']))
            selection = unit['selector']
            excerpt = text[selection['startCharacter']:selection['endCharacter']]
            A.require(hashlib.sha256(excerpt.encode()).hexdigest() == selection['excerptSha256'],
                      'background literal excerpt differs')
            A.require(specification['statementText'] in ' '.join(excerpt.split())
                      and hashlib.sha256(specification['statementText'].encode()).hexdigest() == specification['statementSha256'],
                      'background meaning lacks cited literal content')
            receipt = next((value for value in context['person']['receipts']
                            if value['contentSha256'] == exposure['educationEntryId']), None)
            A.require(receipt is not None and receipt['personId'] == row['personId']
                      and receipt['attended'] is True and exposure['unitId'] in receipt['exposedUnitIds']
                      and receipt['contentSha256'] in exposure['evidenceRefs']
                      and receipt['startYear'] == exposure['startYear'] and receipt['endYear'] == exposure['endYear']
                      and unit['editionYear'] <= receipt['startYear'] < receipt['endYear'] <= context['profile']['asOfYear'],
                      'background meaning lacks dated personal exposure')
            roots.append(B.seal({'schema': 'sao-person-background-meaning/1',
                'meaningId': specification['id'], 'personId': row['personId'],
                'bindings': copy.deepcopy(row['bindings']), 'curriculumRef': copy.deepcopy(exposure['sourceCurriculumRef']),
                'courseId': exposure['courseId'], 'unitId': exposure['unitId'],
                'sourceId': unit['sourceId'], 'sourceVersion': unit['sourceVersion'],
                'selector': copy.deepcopy(selection), 'publicationYear': unit['editionYear'],
                'statementText': specification['statementText'], 'statementSha256': specification['statementSha256'],
                'relations': copy.deepcopy(specification['relations']), 'conditions': copy.deepcopy(specification['conditions']),
                'acquisition': {'kind': 'generated-schooling-exposure', 'receiptSha256': receipt['contentSha256'],
                    'personId': row['personId'], 'profileSha256': row['sourceProfileSha256'],
                    'startYear': receipt['startYear'], 'endYear': receipt['endYear'],
                    'ageAtStart': receipt['ageAtStart'], 'regionId': exposure['sourceRegionId'],
                    'cohortId': exposure['sourceCohortId'], 'institutionId': exposure['sourceInstitutionId'],
                    'unitId': exposure['unitId'], 'attended': True},
                'admittedAtTick': L.moment(entry['asOfTime'], entry['policy']) * R.TICKS_PER_DAY,
                'standing': 'defeasible-exposure-prior; retention-and-mastery-unassessed'}))
        A.require(len(roots) <= 16, 'background meaning bound exceeded')
        if authored_histories is not None:
            history = authored_histories.get(row['personId'])
            compiled = B.compile_authored_exposures(context, history) if history is not None else None
            if compiled:
                for receipt in compiled['receipts']:
                    event, unit = receipt['event'], receipt['unit']
                    for path in EXPOSURE_SPECS:
                        projection = A.read(path)
                        if projection['courseId'] != event['courseId'] or projection['unit']['id'] != event['unitId']:
                            continue
                        roots.append(project_authored_meaning(projection, receipt, compiled['contentSha256'],
                            row['bindings'], row['personId'],
                            L.moment(entry['asOfTime'], entry['policy']) * R.TICKS_PER_DAY, context['archive']))
            A.require(len(roots) <= 16, 'background meaning bound exceeded')
            row.update(schema='speakeasy-person-education-runtime-registry-row/3',
                       backgroundRelations=roots, contentExposureHistory=compiled)
        else:
            row.update(schema='speakeasy-person-education-runtime-registry-row/2', backgroundRelations=roots)
        rows.append(B.seal(row))
    body = B.checked(registry, 'existing registry')
    version = '3' if authored_histories is not None else '2'
    body.update(schema='speakeasy-person-education-runtime-registry/'+version,
                producer='education-runtime-registry-'+version, rows=rows)
    return B.seal(body)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-owner',type=Path,required=True)
    parser.add_argument('--world-definition',type=Path,required=True)
    parser.add_argument('--world-owner',type=Path,required=True)
    parser.add_argument('--persons',type=Path,required=True,
                        help='Existing education_runtime_registry explicit person input paths')
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--exposure-events',type=Path,
                        help='Explicit person-keyed authored work/community content histories')
    args=parser.parse_args(argv)
    sys.path.insert(0,str(args.source_owner.resolve()/'tools'))
    import decision_authoring as A
    import education_backgrounds as B
    import education_runtime_registry as R
    value=build(args.world_definition.read_bytes(),A.read(args.world_owner),R.read_entries(args.persons),
                A.read(args.exposure_events) if args.exposure_events else None)
    result=B.write_immutable(args.out,value)
    print(result+' '+str(args.out)+' '+value['contentSha256'])
    return 0


if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print('REFUSED background compilation: '+str(error),file=sys.stderr)
        raise SystemExit(1)
