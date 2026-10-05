"""Controlled personal histories through actual source/background/registry owners.

Uses existing rights-clean archive and bank bytes, no model or assessment event.
The explicit two-region plan supplies institutional exposure, not competence.
"""
from pathlib import Path
import copy
import json
import sys


def generate(source_owner, rights_owner, output, authored=False):
    sys.path.insert(0, str(Path(source_owner) / 'tools'))
    import decision_authoring as A
    import education_backgrounds as B
    import education_curriculum as K
    import education_learning as L
    from compiler import build
    corpus = Path(rights_owner) / 'runs/r84-rights-clean-foundation'
    archive, bank = corpus / 'source-archive-v1', corpus / 'assessment-bank-v1'
    curriculum = A.read(corpus / 'curriculum-v1.json')
    reference = K.reference(curriculum)
    world = {'id': 'd1-background-proof-world', 'seed': 'controlled-schooling-source-1'}
    participation = {'enrolmentProbability': 1, 'attendanceProbability': 1,
        'interruptionProbability': 0, 'completionProbability': 0,
        'minimumInterruptedExposureFraction': 0}
    regions = []
    for region, attendance in [('source-region', 1), ('unexposed-region', 0)]:
        regions.append({'id': region, 'cohorts': [{'id': region + '-cohort', 'startYear': 1930, 'endYear': 1993,
            'curriculumRef': reference, 'institutions': [{'id': region + '-school', 'levelIds': ['grade-8'],
                'offeredCourseIds': [course['id'] for course in curriculum['courses'] if course['level']=='grade-8'], 'authoredOptionalUnits': {},
                'participation': {**participation, 'attendanceProbability': attendance}}]}]})
    plan = {'schema': 'speakeasy-education-background-plan/1', 'id': 'explicit-household-exposure',
        'worldOwner': world, 'curriculumRef': reference, 'regions': regions}
    backgrounds = B.generate_backgrounds(plan, [curriculum], archive)
    policy = {'schema': 'speakeasy-person-learning-policy/1', 'owner': 'controlled-background-proof',
        'version': '1', 'clock': 'county-day', 'ticksPerDay': 216000,
        'rates': {'independent-retrieval': .4, 'hinted-retrieval': .08, 'tutoring': .1, 'passive-learning': .02, 'cross-learning': .01},
        'familiarityRate': .1, 'baseHalfLifeDays': 30, 'familiarityHalfLifeMultiplier': 4,
        'ageDecayPerYear': .005, 'ageLearningPerYear': .003, 'interestLearningBoost': .5,
        'interestDecayProtection': .4, 'practiceProtection': .5, 'successfulRetrievalProtection': .4,
        'maximumProtection': 10, 'wrongRecallPenalty': .15, 'unknownRecallPenalty': .01,
        'assistedRetentionCap': .3, 'crossPrimingRate': .05, 'maximumPriming': .2,
        'teacherRetentionThreshold': .2, 'interests': {}, 'eventLimit': 512}
    entries = []
    for person, region in [('runner', 'source-region'), ('unexposed', 'unexposed-region')]:
        profile = {'schema': 'speakeasy-simulated-education-profile/1', 'id': person, 'birthYear': 1960,
            'asOfYear': 1993, 'birthRegionId': region, 'currentRegionId': 'source-region',
            'migrations': [] if region == 'source-region' else [{'year': 1980, 'fromRegionId': region, 'toRegionId': 'source-region'}],
            'collegeYears': 0, 'electiveCourseIds': []}
        history = B.generate_person(profile, backgrounds, plan, [curriculum], archive)
        exposure = B.compile_generated(curriculum, archive, plan, backgrounds, profile, history)
        context = {'archive': archive, 'curriculum': curriculum, 'sourceCurricula': [],
            'plan': plan, 'backgrounds': backgrounds, 'profile': profile, 'person': history, 'education': exposure}
        ledger = L.initialize(context, policy, bank, {'clock': 'county-day', 'value': 0})
        entries.append({'context': context, 'ledger': ledger, 'policy': policy, 'bank': bank,
            'asOfTime': {'clock': 'county-day', 'value': 0}, 'teachers': None, 'maximumConcepts': 128})
    definition = A.encoded({'schema': 'controlled-world-definition/1', 'worldOwner': world})
    histories = None
    if authored:
        context = entries[0]['context']
        events = []
        for identity, kind, channel, carrier, course, unit in [
            ('work-reading-1982', 'work-training', 'guided-practice', 'explicit-workshop',
             'grade-9-practical-arts', 'practical-mechanics-24761-36722-grade-9-practical-arts'),
            ('community-reading-1983', 'community-literary', 'heard', 'explicit-community-reading',
             'grade-11-social-studies', 'civil-government-13278-18666-grade-11-social-studies')]:
            year = 1982 + len(events)
            events.append({'id': identity, 'kind': kind, 'channel': channel, 'carrierId': carrier,
                'regionId': 'source-region', 'startYear': year, 'endYear': year+1,
                'curriculumRef': reference, 'courseId': course, 'unitId': unit})
        histories = {'runner': {'schema': 'speakeasy-authored-content-exposure-history/1',
            'personId': 'runner', 'worldOwner': world, 'profileSha256': A.digest(context['profile']),
            'personEducationSha256': context['person']['contentSha256'], 'events': events}}
    registry = build(definition, world, entries, histories)
    output = Path(output); output.mkdir(parents=True, exist_ok=True)
    (output / 'registry.json').write_bytes(A.encoded(registry))
    (output / 'world-definition.json').write_bytes(definition)
    if histories is not None:
        (output / 'authored-exposure-histories.json').write_bytes(A.encoded(histories))
    # Full generated person/receipt rows retain that completion was not granted.
    (output / 'source-evidence.json').write_bytes(A.encoded({'world': world, 'plan': plan,
        'backgrounds': backgrounds, 'persons': [e['context']['person'] for e in entries],
        'exposures': [e['context']['education'] for e in entries], 'ledgers': [e['ledger'] for e in entries],
        'sourceOwner': str(source_owner), 'rightsOwner': str(rights_owner),
        'meaning': json.loads(Path(__file__).with_name('household-stove-cooking-v1.json').read_text(encoding='utf-8'))}))
    return registry


if __name__ == '__main__':
    try:
        registry = generate(*sys.argv[1:])
        print('PASS actual source reconstruction: ' + str([len(row['backgroundRelations']) for row in registry['rows']]))
    except Exception as error:
        print('FAIL actual source reconstruction: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
