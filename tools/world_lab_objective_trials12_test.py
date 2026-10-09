#!/usr/bin/env python3
"""Objective-cycle controls. Fixture producer/media/reviews are synthetic.

The optional retained-native test reads original bytes only; it fabricates no
assigned past objective, body event, return, human review or decoded frame.
All test output stays in the separately owned ignored qualification directory.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid
from unittest import mock

TOOLS = Path(__file__).resolve().parent
BASE = TOOLS.parent / '_scratch/d2-leisure-01/participant-integration21/native-play04/resolution12/objective-trials12'
OUT = Path(os.environ.get('OBJECTIVE_TRIALS12_EVIDENCE', BASE / 'test-work')).resolve()
assert OUT.is_relative_to(BASE.resolve()), 'test output escapes owned evidence'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = Path(os.environ.get('OBJECTIVE_TRIALS12_SOURCE', TOOLS / 'world_lab_objective_trials.py')).resolve()
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location('objective_trials12_under_test', SOURCE)
Trial = importlib.util.module_from_spec(spec); spec.loader.exec_module(Trial)


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(Trial.encoded(value))


class ObjectiveCycle(unittest.TestCase):
    def setUp(self):
        self.directory = OUT / (self._testMethodName + '-' + uuid.uuid4().hex[:8])
        self.root = self.directory / 'synthetic-session'; self.root.mkdir(parents=True)
        self.study = str(uuid.uuid4()); self.session = str(uuid.uuid4()); self.stream = str(uuid.uuid4())
        self.run = {'schema': 'sao-study-run/1', 'sessionId': self.session, 'pid': 12345, 'launchNumber': 1,
                    'observerDirectory': 'attempts/0001', 'host': 'player', 'participantInput': True,
                    'window': 'visible', 'watch': True, 'status': 'completed', 'launchMode': 'native-menu',
                    'save': 'synthetic-save', 'saveMode': 'Sandbox', 'packageSha256': 'a'*64,
                    'definitionSha256': 'b'*64, 'engineJarSha256': 'c'*64,
                    'terminal': 'native-exit'}
        save(self.root / 'participant-run/run.json', self.run)
        self.body = {'schema': 'sao-native-participant/1', 'sessionId': self.session, 'pid': 12345,
                     'attempt': 1, 'save': 'synthetic-save', 'saveMode': 'Sandbox', 'playerIndex': 0,
                     'playerSqlId': 7, 'capturedAtUnixMs': 1000, 'worldHours': 10.0,
                     'ready': True, 'displayFocused': True, 'alive': True,
                     'body': {'x': 4, 'y': 5, 'z': 0, 'label': 'Synthetic test actor'}}
        save(self.root / 'body-samples/initial.json', self.body)
        later = {**self.body, 'capturedAtUnixMs': 1500, 'worldHours': 10.5,
                 'body': {**self.body['body'], 'x': 9}}
        save(self.root / 'body-samples/later.json', later)
        save(self.root / 'video-archive/archive.json', {'schema': Trial.Video.SCHEMA,
             'studyId': self.study, 'source': str(self.root.resolve()), 'status': 'stopped'})
        self.media = self.root / f'video-archive/0001/{self.stream}'; self.media.mkdir(parents=True)
        # Synthetic media bytes exercise custody and hash checks, not decoding.
        init = {'file': f'video-{self.stream}-init.mp4', 'sha256': hashlib.sha256(b'synthetic-init').hexdigest()}
        row = {'sequence': 1, 'file': f'video-{self.stream}-0000000000000001.m4s',
               'sha256': hashlib.sha256(b'synthetic-segment').hexdigest(), 'ptsStartMs': 0, 'durationMs': 1000,
               'capturedAtUnixMs': 1000, 'endCapturedAtUnixMs': 2000, 'observerSequence': 0,
               'worldHours': 10.0, 'endWorldHours': 11.0, 'firstFrameSequence': 1, 'lastFrameSequence': 20,
               'crops': [{'id': 'participant-viewport', 'slot': 0, 'left': 0, 'top': 0, 'width': 2488, 'height': 1566}],
               'sites': []}
        (self.media / init['file']).write_bytes(b'synthetic-init')
        (self.media / row['file']).write_bytes(b'synthetic-segment')
        self.segment = self.media / row['file']
        manifest = {'schema': 'sao-study-video/1', 'streamId': self.stream, 'state': 'ended',
                    'width': 2488, 'height': 1566, 'fps': 20, 'mimeType': 'video/mp4', 'codecs': 'synthetic',
                    'init': init, 'segments': [row], 'stats': {}}
        raw = Trial.encoded(manifest); digest = hashlib.sha256(raw).hexdigest()
        self.manifest_file = f'video-archive/0001/{self.stream}/manifests/{digest}.json'
        p = self.root / self.manifest_file; p.parent.mkdir(); p.write_bytes(raw)
        report = {'schema': Trial.Video.SCHEMA, 'studyId': self.study, 'attempt': 1, 'streamId': self.stream,
                  'coverage': 'complete-published-segments', 'nativeProvenance': {k: self.run[k] for k in
                   ('sessionId', 'launchNumber', 'packageSha256', 'definitionSha256', 'status')}}
        save(self.media / 'stream.json', report)
        self.source = Trial.build_source_manifest(self.root, 'body-samples/initial.json', evidence_origin='synthetic-control')
        self.actor = Trial.actor_binding(self.source, 'synthetic:actor-7', 'synthetic:controller', 'Synthetic test producer; no actual persona.')
        self.objective = {'instruction': 'Walk to the marked supply location and return to the starting point.',
                          'successCriteria': 'Human checks actual arrival and the supply observation.',
                          'returnCriteria': 'Human checks arrival at the recorded starting position.',
                          'assignedBy': 'synthetic:test-human', 'assignedAtUnixMs': 900, 'mode': 'prospective'}
        self.destination = self.directory / 'trial'
        Trial.create_trial(self.source, self.actor, self.objective, self.destination)

    def qualified_recording_shape(self):
        """Build controlled linked receipts; no native game or encoded-media claim."""
        self.study = self.session
        sample_raw = Trial.encoded(self.body)
        sample_sha = hashlib.sha256(sample_raw).hexdigest()
        sample_file = 'body-samples/' + sample_sha + '.json'
        (self.root / sample_file).write_bytes(sample_raw)
        later = {**self.body, 'capturedAtUnixMs': 1500, 'worldHours': 10.5,
                 'body': {**self.body['body'], 'x': 9}}
        later_raw = Trial.encoded(later)
        later_sha = hashlib.sha256(later_raw).hexdigest()
        self.later_qualified_file = 'body-samples/' + later_sha + '.json'
        (self.root / self.later_qualified_file).write_bytes(later_raw)
        events = [
            {'schema': 'sao.native-play-event/1', 'sessionId': self.session, 'atUnixMs': 990,
             'kind': 'native-started', 'pid': self.run['pid'], 'nativeMenu': True},
            {'schema': 'sao.native-play-event/1', 'sessionId': self.session, 'atUnixMs': 1001,
             'kind': 'native-player-interval-started', 'interval': 1,
             'saveMode': self.body['saveMode'], 'save': self.body['save'],
             'playerIndex': self.body['playerIndex'], 'playerSqlId': self.body['playerSqlId'],
             'label': self.body['body']['label'], 'sampleSha256': sample_sha,
             'sourceObservedAtUnixMs': self.body['capturedAtUnixMs']},
            {'schema': 'sao.native-play-event/1', 'sessionId': self.session, 'atUnixMs': 1501,
             'kind': 'native-body-sample', 'pid': self.run['pid'], 'attempt': 1,
             'saveMode': later['saveMode'], 'save': later['save'],
             'playerIndex': later['playerIndex'], 'playerSqlId': later['playerSqlId'],
             'sampleSha256': later_sha, 'sourceObservedAtUnixMs': later['capturedAtUnixMs']},
            {'schema': 'sao.native-play-event/1', 'sessionId': self.session, 'atUnixMs': 2600,
             'kind': 'native-ended', 'exitCode': 0, 'nativeSaveReturned': True,
             'recordingComplete': True},
        ]
        event_path = self.root / 'events.jsonl'
        event_path.write_bytes(b''.join(Trial.encoded(row) for row in events))
        attempt = self.root / 'participant-run/attempts/0001'
        attempt.mkdir(parents=True, exist_ok=True)
        stdout = b'[StudyLaunch] native-save-returned attempt=1\\n'
        stderr = b''
        (attempt / 'stdout.log').write_bytes(stdout)
        (attempt / 'stderr.log').write_bytes(stderr)
        plan = {'schema': 'sao.native-play-launch/1', 'sessionId': self.session, 'mode': 'native-menu',
                'command': ['-Dstudy.nativePlay=true', '-Dstudy.participantSession='+self.session,
                            '-Dstudy.attempt=1'], 'saveSelection': 'native-LoadGameScreen',
                'nativeModsOverride': False, 'nativeSoundDisabled': False,
                'sourcePins': {'StudyLaunch.java': 'd'*64}, 'engineSha256': 'e'*64,
                'adapterSha256': 'f'*64, 'launcherSha256': '0'*64}
        save(self.root / 'launch.json', plan)
        self.run.update(sourceSchema=Trial.NativePlay.RUN_SCHEMA, evidenceScope='native-player-recording',
                        authoredStudy=False, launcher=plan, exitCode=0, nativeSaveReturned=True,
                        recordingError=None, terminal='native-exit',
                        logs={'stdout.log': hashlib.sha256(stdout).hexdigest(),
                              'stderr.log': hashlib.sha256(stderr).hexdigest()})
        save(self.root / 'participant-run/run.json', self.run)
        run_raw = (self.root / 'participant-run/run.json').read_bytes()
        run_sha = hashlib.sha256(run_raw).hexdigest()

        row = json.loads((self.root / self.manifest_file).read_bytes())['segments'][0]
        provenance = {key: self.run.get(key) for key in
                      ('sessionId', 'launchNumber', 'packageSha256', 'definitionSha256', 'status', 'terminal')}
        report = {'schema': Trial.Video.SCHEMA, 'studyId': self.session, 'attempt': 1,
                  'streamId': self.stream, 'nativeProvenance': provenance,
                  'coverage': 'complete-published-segments', 'tailConfirmed': True,
                  'lateAttachment': False, 'retainedSegments': 1, 'firstSegment': row,
                  'lastSegment': row}
        report_path = self.media / 'stream.json'
        save(report_path, report)
        report_raw = report_path.read_bytes()
        report_sha = hashlib.sha256(report_raw).hexdigest()
        epoch = {'attempt': 1, 'streamId': self.stream, 'coverage': 'complete-published-segments',
                 'tailConfirmed': True, 'lateAttachment': False, 'retainedSegments': 1}
        archive = {'schema': Trial.Video.SCHEMA, 'studyId': self.session, 'source': str(self.root),
                   'status': 'stopped', 'error': None, 'priorFailureCount': 0,
                   'attempts': [{'attempt': 1, 'nativeProvenance': provenance, 'video': 'observed'}],
                   'streams': [epoch]}
        save(self.root / 'video-archive/archive.json', archive)
        retained = self.root / ('video-archive/0001/provenance/' + run_sha + '.json')
        retained.parent.mkdir(parents=True, exist_ok=True)
        retained.write_bytes(run_raw)

        feed = self.root / 'feeds/0001'
        feed.mkdir(parents=True)
        index = {'schema': 'mousecat.native-video-archive/1', 'sessionId': self.session,
                 'studyId': self.session, 'attempt': 1, 'streamId': self.stream,
                 'coverage': 'complete-published-segments', 'tailConfirmed': True,
                 'segmentCount': 1, 'pages': [{'file': 'controlled-page.json'}],
                 'generation': 1, 'ptsStartMs': 0, 'ptsEndMs': 1000}
        save(feed / 'archive-index.json', index)
        index_raw = (feed / 'archive-index.json').read_bytes()
        index_file = 'archive-index-' + self.stream + '.json'
        (feed / index_file).write_bytes(index_raw)
        index_sha = hashlib.sha256(index_raw).hexdigest()
        report_file = f'archive-report-{self.stream}-{report_sha}.json'
        (feed / report_file).write_bytes(report_raw)
        coverage = {'schema': 'mousecat.native-video-archive-coverage/1', 'epochCount': 1,
                    'publishedCount': 1, 'unavailableCount': 0, 'complete': True,
                    'epochs': [{'streamId': self.stream, 'reportFile': report_file,
                                'reportSha256': report_sha, 'coverage': epoch['coverage'],
                                'tailConfirmed': True, 'lateAttachment': False,
                                'retainedSegments': 1, 'firstCapturedAtUnixMs': 1000,
                                'published': True}]}
        catalog = {'schema': 'mousecat.native-video-archive-catalog/1', 'sessionId': self.session,
                   'recordingId': self.session, 'attempt': 1, 'finalStreamId': self.stream,
                   'streams': [{'streamId': self.stream, 'indexFile': index_file,
                                'indexSha256': index_sha, 'generation': 1}],
                   'aggregateCoverage': coverage}
        save(feed / 'archive-catalog.json', catalog)
        catalog_ref = {'file': 'archive-catalog.json',
                       'sha256': hashlib.sha256((feed / 'archive-catalog.json').read_bytes()).hexdigest()}
        view = {'schema': 'mousecat.native-view/1', 'sessionId': self.session, 'state': 'ended',
                'video': {'state': 'ended', 'streamId': self.stream, 'segments': [row]},
                'recording': {'schema': 'mousecat.native-recording/1', 'id': self.session,
                              'attempt': 1},
                'archiveCatalog': catalog_ref}
        save(feed / 'latest.json', view)
        recording = Trial.ParticipantSession.require_recording(feed, self.session, self.session)
        completion = {'schema': 'sao.native-play-recording-completion/1',
                      'sessionId': self.session, 'complete': True, 'recording': recording,
                      'nativeSaveReturned': True, 'archiveError': None}
        save(self.root / 'recording-completion.json', completion)
        completion_raw = (self.root / 'recording-completion.json').read_bytes()
        completion_sha = hashlib.sha256(completion_raw).hexdigest()
        (feed / ('archive-run-final-' + run_sha + '.json')).write_bytes(run_raw)
        (feed / ('archive-completion-final-' + completion_sha + '.json')).write_bytes(completion_raw)
        finality = {'schema': 'sao.native-play-archive-finality/1', 'sessionId': self.session,
                    'recordingId': self.session, 'attempt': 1, 'finalStreamId': self.stream,
                    'catalog': catalog_ref, 'projectionRunReceiptSha256': run_sha,
                    'runReceipt': {'file': 'archive-run-final-' + run_sha + '.json',
                                   'sha256': run_sha, 'status': 'completed'},
                    'completionReceipt': {'file': 'archive-completion-final-' + completion_sha + '.json',
                                          'sha256': completion_sha},
                    'recordingComplete': True, 'qualification': {'complete': True, 'reason': None}}
        save(feed / 'archive-finality.json', finality)
        view['archiveFinality'] = {'file': 'archive-finality.json',
                                   'sha256': hashlib.sha256((feed / 'archive-finality.json').read_bytes()).hexdigest()}
        save(feed / 'latest.json', view)
        return sample_file, event_path, events

    def observation(self, name, kind, body='later.json', *, replay=True):
        reference = Trial.source_reference(self.root, 'body-samples/'+body)
        return {'id': name, 'kind': kind, 'source': reference, 'bodySource': reference,
                'replay': [Trial.replay_reference(self.root, self.manifest_file, 1)] if replay else [],
                'annotation': 'Synthetic interpretation; original facts remain separate.',
                'measurements': {'position-x': '/body/x'}}

    def native_review_observation(self):
        sample = Trial.encoded(self.body).decode('utf-8')
        row = {'processId': 'process-1', 'revision': 2,
               'playerId': self.actor['actorId'], 'helperId': 'helper-1',
               'commitmentId': 'commitment-1', 'outboundReceiptId': 'route-out',
               'watchReceiptId': 'watch-1', 'returnReceiptId': 'route-home',
               'report': {'status': 'completed', 'channel': 'spoken', 'deliveredAt': 9.5},
               'review': {'status': 'inspected', 'reviewedAt': 9.75,
                   'attempts': [{'id': 'route-home', 'stepId': 'return', 'owner': 'ManualRoute',
                                 'status': 'arrived', 'x': 4, 'y': 5, 'z': 0,
                                 'startedAt': 9, 'endedAt': 9.4}]}}
        source = {'schema': Trial.NativePlay.OBJECTIVE_REVIEW_SCHEMA,
                  'captureEpoch': 1,
                  **{key: self.body[key] for key in ('sessionId', 'pid', 'attempt', 'save',
                  'saveMode', 'playerIndex', 'playerSqlId', 'capturedAtUnixMs', 'worldHours')},
                  'countyHours': self.body['worldHours'],
                  'sampleSha256': hashlib.sha256(sample.encode()).hexdigest(),
                  'bodySample': sample, 'omittedReviews': 0, 'reviews': [row]}
        path = self.root / 'participant-run/attempts/0001/objective-review-state.json'
        save(path, source)
        events = []
        archive = Trial.NativePlay.ObjectiveReviewArchive(self.root, self.run,
            lambda kind, **fields: events.append({'schema': 'sao.native-play-event/1',
                'sessionId': self.session, 'atUnixMs': 1001, 'kind': kind, **fields}))
        self.assertTrue(archive.collect(path))
        (self.root / 'events.jsonl').write_bytes(Trial.encoded(events[0]))
        event_raw = Trial.encoded(events[0])
        event_file = 'objective-reviews/events/' + hashlib.sha256(event_raw).hexdigest() + '.json'
        (self.root / event_file).parent.mkdir(parents=True, exist_ok=True)
        (self.root / event_file).write_bytes(event_raw)
        body_ref = Trial.source_reference(self.root, 'body-samples/initial.json')
        observation = {'id': 'source-review', 'kind': 'review',
                       'source': Trial.source_reference(self.root, event_file),
                       'bodySource': body_ref,
                       'replay': [Trial.replay_reference(self.root, self.manifest_file, 1)],
                       'annotation': 'Synthetic source review; human outcome remains separately judged.',
                       'measurements': {'process': '/processId', 'returned-receipt': '/returnReceiptId'}}
        return observation, events[0]

    def test_native_review_source_supports_replay_and_requires_human_candidate_review(self):
        observation, event = self.native_review_observation()
        value = Trial.append_observation(self.destination, observation)
        row = value['observations'][0]
        self.assertEqual(row['objectiveReviewSource']['sha256'], event['objectiveSourceSha256'])
        self.assertEqual(row['sourceClock'], {'countyHours': 10.0, 'reviewedAtHours': 9.75})
        self.assertEqual(row['measurementsObserved']['returned-receipt']['value'], 'route-home')
        self.assertEqual(row['replayObserved'][0]['association'], 'independent source clocks; actor visibility unverified')
        self.filled()
        completion = self.completion('met')
        completion['outcome']['evidence'] = ['source-review']
        completion['return']['evidence'] = ['source-review']
        Trial.complete_trial(self.destination, completion)
        with self.assertRaisesRegex(ValueError, 'explicit candidate review'):
            Trial.export_candidate(self.destination, self.directory / 'unreviewed.json')
        evaluation = self.evaluation()
        evaluation['evidence'].append('source-review')
        Trial.evaluate_trial(self.destination, evaluation)
        candidate = Trial.export_candidate(self.destination, self.directory / 'reviewed.json')
        self.assertEqual(candidate['trainingStatus'], 'not-run')

    def test_native_review_event_requires_exact_detached_receipt_and_actor(self):
        observation, event = self.native_review_observation()
        for field, wrong, expected in (
                ('objectiveSourceFile', 'other.json', 'source file differs'),
                ('objectiveReviewSha256', '0'*64, 'record hash differs'),
                ('reviewedAtHours', 8.0, 'event binding differs'),
                ('playerId', 'player:foreign', 'event binding differs'),
                ('sampleSha256', '0'*64, 'body sample differs')):
            changed = {**event, field: wrong}
            (self.root / 'events.jsonl').write_bytes(Trial.encoded(changed))
            attempt = {**observation, 'source': Trial.source_reference(self.root, 'events.jsonl', line=1)}
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, expected):
                Trial.append_observation(self.destination, attempt)
        (self.root / 'events.jsonl').write_bytes(Trial.encoded(event))
        other = {**observation, 'kind': 'outcome',
                 'source': Trial.source_reference(self.root, 'events.jsonl', line=1)}
        with self.assertRaisesRegex(ValueError, 'observation kind differs'):
            Trial.append_observation(self.destination, other)

    def filled(self, *, replay=True):
        for name, kind, body in [('attempt-1', 'attempt', 'initial.json'), ('cost-1', 'cost', 'later.json'),
                                  ('outcome-1', 'outcome', 'later.json'), ('return-1', 'return', 'later.json')]:
            Trial.append_observation(self.destination, self.observation(name, kind, body, replay=replay))

    def completion(self, outcome='not-met'):
        return {'reportedBy': 'synthetic:test-assessor',
                'outcome': {'status': outcome, 'evidence': ['outcome-1'],
                            'interpretation': 'Synthetic control says the objective criterion was not met.'},
                'return': {'status': 'returned', 'evidence': ['return-1'],
                           'interpretation': 'Synthetic control return interpretation for review.'},
                'costs': {'status': 'observed', 'evidence': ['cost-1']},
                'uncertainties': ['No actual body, frame, human review or gameplay success is asserted by this control.']}

    def evaluation(self, disposition='candidate'):
        return {'reviewer': {'kind': 'human', 'id': 'synthetic:test-human'}, 'disposition': disposition,
                'evidence': ['attempt-1', 'outcome-1', 'return-1', 'cost-1'],
                'rationale': 'Explicit synthetic review used only to exercise the research gate.', 'reviewedAtUnixMs': 2500}

    def reviewed(self, *, replay=True, outcome='not-met'):
        self.filled(replay=replay); Trial.complete_trial(self.destination, self.completion(outcome))
        Trial.evaluate_trial(self.destination, self.evaluation())

    def test_reviewed_failed_attempt_exports_truthful_candidate(self):
        self.reviewed()
        path = self.directory / 'candidate.json'
        export = Trial.export_candidate(self.destination, path)
        candidate = json.loads(path.read_bytes())
        self.assertEqual(candidate['completion']['outcome']['status'], 'not-met')
        self.assertEqual(candidate['source']['evidenceOrigin'], 'synthetic-control')
        self.assertEqual(candidate['trainingStatus'], 'not-run')
        self.assertEqual(candidate['observations'][1]['measurementsObserved']['position-x']['value'], 9)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), export['sha256'])
        self.assertEqual(Trial.export_candidate(self.destination, path), export)

    def test_synthetic_fixture_cannot_be_labeled_actual_native_by_default_or_override(self):
        auto = Trial.build_source_manifest(self.root, 'body-samples/initial.json')
        self.assertEqual(auto['evidenceOrigin'], 'unverified')
        with self.assertRaisesRegex(ValueError, 'qualified native launch and recording provenance'):
            Trial.build_source_manifest(self.root, 'body-samples/initial.json',
                                        evidence_origin='actual-native')
        forged = {**auto, 'evidenceOrigin': 'actual-native'}
        with self.assertRaisesRegex(ValueError, 'lacks qualified native launch and recording provenance'):
            Trial.create_trial(forged, self.actor, self.objective, self.directory / 'forged-trial')

        command = [sys.executable, str(SOURCE), 'source', str(self.root), 'body-samples/initial.json']
        env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}
        default = subprocess.run(command, cwd=str(TOOLS.parent), env=env, capture_output=True, timeout=15)
        self.assertEqual(default.returncode, 0, default.stderr.decode())
        self.assertEqual(json.loads(default.stdout)['evidenceOrigin'], 'unverified')
        forced = subprocess.run([*command, '--origin', 'actual-native'], cwd=str(TOOLS.parent),
                                env=env, capture_output=True, timeout=15)
        self.assertEqual(forced.returncode, 2)
        self.assertIn(b'qualified native launch and recording provenance', forced.stderr)

        self.source = auto
        self.actor = Trial.actor_binding(auto, self.actor['actorId'], self.actor['controllerId'],
                                         self.actor['origin'])
        self.destination = self.directory / 'unverified-trial'
        Trial.create_trial(auto, self.actor, self.objective, self.destination)
        self.reviewed()
        output = self.directory / 'unverified-candidate.json'
        receipt = Trial.export_candidate(self.destination, output)
        self.assertEqual(receipt['evidenceOrigin'], 'unverified')
        candidate = json.loads(output.read_bytes())
        self.assertEqual(candidate['source']['evidenceOrigin'], 'unverified')
        self.assertIn('Native launch and recording origin are unverified.', candidate['uncertainties'])

    def test_completed_native_shape_refuses_grafted_body_and_rechecks_export(self):
        # Controlled metadata exercises custody joins only; no game or MP4 decode runs.
        sample_file, event_path, events = self.qualified_recording_shape()
        qualified = Trial.build_source_manifest(self.root, sample_file)
        self.assertEqual(qualified['evidenceOrigin'], 'actual-native')
        later_source = Trial.build_source_manifest(self.root, self.later_qualified_file)
        self.assertEqual(later_source['evidenceOrigin'], 'actual-native')
        for field, wrong in (('pid', 54321), ('playerSqlId', 8)):
            altered = [*events]
            altered[2] = {**events[2], field: wrong}
            event_path.write_bytes(b''.join(Trial.encoded(row) for row in altered))
            Trial._clear_source_cache(self.root.resolve())
            with self.subTest(field=field):
                self.assertEqual(Trial.build_source_manifest(
                    self.root, self.later_qualified_file)['evidenceOrigin'], 'unverified')
                with self.assertRaisesRegex(ValueError, 'qualified native launch and recording provenance'):
                    Trial.build_source_manifest(self.root, self.later_qualified_file,
                                                evidence_origin='actual-native')
        event_path.write_bytes(b''.join(Trial.encoded(row) for row in events))
        Trial._clear_source_cache(self.root.resolve())
        actor = Trial.actor_binding(qualified, self.actor['actorId'], self.actor['controllerId'],
                                    self.actor['origin'])
        target = self.directory / 'qualified-shape-trial'
        Trial.create_trial(qualified, actor, self.objective, target)

        graft = {**self.body, 'capturedAtUnixMs': 1750, 'worldHours': 10.75,
                 'body': {**self.body['body'], 'x': 11}}
        graft_raw = Trial.encoded(graft)
        graft_sha = hashlib.sha256(graft_raw).hexdigest()
        graft_file = 'body-samples/' + graft_sha + '.json'
        (self.root / graft_file).write_bytes(graft_raw)
        auto = Trial.build_source_manifest(self.root, graft_file)
        self.assertEqual(auto['evidenceOrigin'], 'unverified')
        with self.assertRaisesRegex(ValueError, 'qualified native launch and recording provenance'):
            Trial.build_source_manifest(self.root, graft_file, evidence_origin='actual-native')
        forged = {**qualified, 'bodySource': Trial.source_reference(self.root, graft_file)}
        with self.assertRaisesRegex(ValueError, 'lacks qualified native launch and recording provenance'):
            Trial.create_trial(forged, actor, self.objective, self.directory / 'grafted-source')
        graft_observation = self.observation('graft', 'attempt')
        graft_observation['source'] = Trial.source_reference(self.root, graft_file)
        graft_observation['bodySource'] = graft_observation['source']
        with self.assertRaisesRegex(ValueError, 'lacks recorded body custody'):
            Trial.append_observation(target, graft_observation)

        body_ref = Trial.source_reference(self.root, sample_file)
        for name, kind in [('attempt-1', 'attempt'), ('cost-1', 'cost'),
                           ('outcome-1', 'outcome'), ('return-1', 'return')]:
            observation = self.observation(name, kind, 'initial.json')
            observation['source'] = body_ref
            observation['bodySource'] = body_ref
            Trial.append_observation(target, observation)
        later_ref = Trial.source_reference(self.root, self.later_qualified_file)
        later_observation = self.observation('later-genuine', 'context')
        later_observation['source'] = later_ref
        later_observation['bodySource'] = later_ref
        Trial.append_observation(target, later_observation)
        Trial.complete_trial(target, self.completion())
        Trial.evaluate_trial(target, self.evaluation())
        event_path.write_bytes(Trial.encoded(events[0]) + Trial.encoded(events[-1]))
        with self.assertRaisesRegex(ValueError, 'lacks qualified native launch and recording provenance'):
            Trial.export_candidate(target, self.directory / 'removed-custody-candidate.json')
        self.assertFalse((self.directory / 'removed-custody-candidate.json').exists())

    def test_actual_native_detached_review_requires_same_event_in_main_log(self):
        sample_file, event_path, events = self.qualified_recording_shape()
        source = Trial.build_source_manifest(self.root, sample_file)
        actor = Trial.actor_binding(source, self.actor['actorId'], self.actor['controllerId'],
                                    self.actor['origin'])
        target = self.directory / 'review-custody-trial'
        Trial.create_trial(source, actor, self.objective, target)
        observation, event = self.native_review_observation()
        observation['bodySource'] = Trial.source_reference(self.root, sample_file)
        event_path.write_bytes(b''.join(Trial.encoded(row) for row in events))
        with self.assertRaisesRegex(ValueError, 'review event is absent from native events'):
            Trial.append_observation(target, observation)
        self.assertEqual(Trial.read_trial(target)['observations'], [])
        event_path.write_bytes(b''.join(Trial.encoded(row) for row in [*events[:-1], event, events[-1]]))
        admitted = Trial.append_observation(target, observation)
        self.assertEqual(admitted['observations'][0]['objectiveReviewSource']['sha256'],
                         event['objectiveSourceSha256'])
        event_path.write_bytes(b''.join(Trial.encoded(row) for row in events))
        Trial._clear_source_cache(self.root.resolve())
        with self.assertRaisesRegex(ValueError, 'review event is absent from native events'):
            Trial._validate_timeline(Trial.read_trial(target))

    def test_idempotent_append_and_conflicting_id(self):
        observation = self.observation('one', 'attempt', 'initial.json')
        first = Trial.append_observation(self.destination, observation)
        before = (self.destination / 'trial.json').read_bytes()
        self.assertEqual(Trial.append_observation(self.destination, observation), first)
        self.assertEqual((self.destination / 'trial.json').read_bytes(), before)
        observation['annotation'] = 'Different interpretation.'
        with self.assertRaisesRegex(ValueError, 'id reused'):
            Trial.append_observation(self.destination, observation)

    def test_create_and_completion_retries_are_idempotent(self):
        before = Trial.read_trial(self.destination)
        self.assertEqual(Trial.create_trial(self.source, self.actor, self.objective, self.destination), before)
        self.filled(); first = Trial.complete_trial(self.destination, self.completion())
        self.assertEqual(Trial.complete_trial(self.destination, self.completion()), first)
        different = self.completion('met')
        with self.assertRaisesRegex(ValueError, 'another result'):
            Trial.complete_trial(self.destination, different)

    def test_objective_can_follow_body_binding_but_attempt_cannot_predate_assignment(self):
        objective = {**self.objective, 'assignedAtUnixMs': 1200}
        target = self.directory / 'later-assigned-objective'
        Trial.create_trial(self.source, self.actor, objective, target)
        with self.assertRaisesRegex(ValueError, 'predates its objective'):
            Trial.append_observation(target, self.observation('earlier', 'attempt', 'initial.json'))
        value = Trial.append_observation(target, self.observation('later', 'attempt'))
        self.assertEqual(value['observations'][0]['clock']['capturedAtUnixMs'], 1500)

    def test_multiline_human_criteria_and_review_are_preserved(self):
        objective = {**self.objective, 'instruction': 'Retrieve the supplies.\nReturn to the recorded starting point.',
                     'successCriteria': 'Inspect the source.\nExplain what changed.'}
        target = self.directory / 'multiline-objective'
        Trial.create_trial(self.source, self.actor, objective, target)
        original = self.destination; self.destination = target
        try:
            self.filled(); completion = self.completion()
            completion['outcome']['interpretation'] += '\nThe synthetic source shows only position.'
            Trial.complete_trial(target, completion)
            evaluation = self.evaluation(); evaluation['rationale'] += '\nKeep the original uncertainty.'
            value = Trial.evaluate_trial(target, evaluation)
            self.assertEqual(value['objective']['instruction'], objective['instruction'])
            self.assertEqual(value['evaluation']['rationale'], evaluation['rationale'])
            Trial.export_candidate(target, self.directory / 'multiline-candidate.json')
        finally:
            self.destination = original

    def test_missing_attempt_or_outcome_refuses_completion(self):
        with self.assertRaisesRegex(ValueError, 'attempt not observed'):
            Trial.complete_trial(self.destination, self.completion())
        Trial.append_observation(self.destination, self.observation('attempt-1', 'attempt', 'initial.json'))
        with self.assertRaisesRegex(ValueError, 'another trial or kind'):
            Trial.complete_trial(self.destination, self.completion())

    def test_no_return_evidence_and_unknowns_stay_explicit(self):
        self.filled(); completion = self.completion(); completion['return']['evidence'] = []
        with self.assertRaisesRegex(ValueError, 'missing observation evidence'):
            Trial.complete_trial(self.destination, completion)
        completion = self.completion(); completion['costs'] = {'status': 'unmeasured', 'evidence': []}
        completion['uncertainties'] = []
        with self.assertRaisesRegex(ValueError, 'explicit uncertainty'):
            Trial.complete_trial(self.destination, completion)

    def test_candidate_requires_explicit_human_review(self):
        self.filled(); Trial.complete_trial(self.destination, self.completion())
        with self.assertRaisesRegex(ValueError, 'explicit candidate review'):
            Trial.export_candidate(self.destination, self.directory / 'candidate.json')
        evaluation = self.evaluation(); evaluation['reviewer']['kind'] = 'agent'
        with self.assertRaisesRegex(ValueError, 'explicit human reviewer'):
            Trial.evaluate_trial(self.destination, evaluation)

    def test_candidate_review_must_cover_results_and_costs(self):
        self.filled(); Trial.complete_trial(self.destination, self.completion())
        for missing in ('attempt-1', 'outcome-1', 'return-1', 'cost-1'):
            evaluation = self.evaluation(); evaluation['evidence'].remove(missing)
            with self.assertRaisesRegex(ValueError, 'review omits'):
                Trial.evaluate_trial(self.destination, evaluation)

    def test_retained_disposition_does_not_admit_candidate(self):
        self.filled(); Trial.complete_trial(self.destination, self.completion())
        Trial.evaluate_trial(self.destination, self.evaluation('retain'))
        with self.assertRaisesRegex(ValueError, 'explicit candidate review'):
            Trial.export_candidate(self.destination, self.directory / 'candidate.json')

    def test_no_replay_cannot_export(self):
        self.reviewed(replay=False)
        with self.assertRaisesRegex(ValueError, 'lacks replay'):
            Trial.export_candidate(self.destination, self.directory / 'candidate.json')

    def test_altered_and_missing_replay_are_refused(self):
        self.reviewed(); before = self.segment.read_bytes(); self.segment.write_bytes(before+b'altered')
        with self.assertRaisesRegex(ValueError, 'altered replay artifact'):
            Trial.export_candidate(self.destination, self.directory / 'altered.json')
        self.segment.unlink()
        with self.assertRaises(FileNotFoundError):
            Trial.export_candidate(self.destination, self.directory / 'missing.json')

    def test_foreign_native_stream_and_study_are_refused(self):
        for field, wrong in [('sessionId', str(uuid.uuid4())), ('launchNumber', 2), ('packageSha256', 'd'*64)]:
            path = self.media / 'stream.json'; report = json.loads(path.read_bytes())
            original = deepcopy(report); report['nativeProvenance'][field] = wrong; save(path, report)
            with self.assertRaisesRegex(ValueError, 'foreign replay native source'):
                Trial.append_observation(self.destination, self.observation('one', 'attempt', 'initial.json'))
            save(path, original)
        report = json.loads((self.media / 'stream.json').read_bytes()); report['studyId'] = str(uuid.uuid4())
        save(self.media / 'stream.json', report)
        with self.assertRaisesRegex(ValueError, 'foreign replay study'):
            Trial.append_observation(self.destination, self.observation('one', 'attempt', 'initial.json'))

    def test_unmatched_clock_and_missing_manifest_segment(self):
        body = {**self.body, 'capturedAtUnixMs': 3000, 'worldHours': 10.5}
        save(self.root / 'body-samples/outside.json', body)
        with self.assertRaisesRegex(ValueError, 'outside replay clocks'):
            Trial.append_observation(self.destination, self.observation('one', 'attempt', 'outside.json'))
        observation = self.observation('one', 'attempt', 'initial.json'); observation['replay'][0]['sequence'] = 99
        with self.assertRaisesRegex(ValueError, 'absent from pinned manifest'):
            Trial.append_observation(self.destination, observation)

    def test_actor_sql_save_mode_pid_attempt_and_slot_are_exact(self):
        for field, wrong in [('playerSqlId', 8), ('save', 'foreign'), ('saveMode', 'Multiplayer'),
                              ('pid', 54321), ('attempt', 2), ('playerIndex', 1), ('sessionId', str(uuid.uuid4()))]:
            with self.subTest(field=field):
                save(self.root / 'body-samples/foreign.json', {**self.body, field: wrong})
                with self.assertRaises(ValueError):
                    Trial.append_observation(self.destination, self.observation('foreign', 'attempt', 'foreign.json', replay=False))

    def test_clock_and_world_hour_regression_are_refused(self):
        Trial.append_observation(self.destination, self.observation('later', 'attempt'))
        with self.assertRaisesRegex(ValueError, 'clocks regressed'):
            Trial.append_observation(self.destination, self.observation('earlier', 'context', 'initial.json'))
        save(self.root / 'body-samples/regressed.json', {**self.body, 'capturedAtUnixMs': 1600, 'worldHours': 9.9})
        with self.assertRaisesRegex(ValueError, 'clocks regressed'):
            Trial.append_observation(self.destination, self.observation('regressed', 'context', 'regressed.json', replay=False))

    def test_first_observation_cannot_precede_or_regress_its_binding_epoch(self):
        for stamp, hours in ((500, 10.0), (1500, 9.9)):
            save(self.root / 'body-samples/wrong-epoch.json', {**self.body, 'capturedAtUnixMs': stamp, 'worldHours': hours})
            with self.assertRaisesRegex(ValueError, 'regressed before binding epoch'):
                Trial.append_observation(self.destination, self.observation('wrong-epoch', 'attempt', 'wrong-epoch.json', replay=False))

    def test_source_hashes_refuse_post_binding_changes(self):
        body = deepcopy(self.body); body['displayFocused'] = False
        save(self.root / 'body-samples/initial.json', body)
        with self.assertRaisesRegex(ValueError, 'stale or altered source'):
            Trial.append_observation(self.destination, self.observation('one', 'attempt'))

    def test_source_producer_and_archive_owner_cannot_be_forged(self):
        source = deepcopy(self.source); source['producerPins']['engineJarSha256'] = 'd'*64
        with self.assertRaisesRegex(ValueError, 'source pins differ'):
            Trial.create_trial(source, self.actor, self.objective, self.directory / 'wrong-pins')
        source = deepcopy(self.source); source['studyId'] = str(uuid.uuid4())
        with self.assertRaisesRegex(ValueError, 'archive owner differs'):
            Trial.create_trial(source, self.actor, self.objective, self.directory / 'wrong-study')

    def test_unsafe_paths_duplicate_fields_nonfinite_and_oversized_json(self):
        with self.assertRaisesRegex(ValueError, 'unsafe source relative path'):
            Trial.source_reference(self.root, '../foreign.json')
        path = self.root / 'duplicate.json'; path.write_bytes(b'{"schema":1,"schema":2}')
        with self.assertRaisesRegex(ValueError, 'duplicate source JSON field'):
            Trial._read_ref(self.root.resolve(), Trial.source_reference(self.root, 'duplicate.json'))
        path = self.root / 'nonfinite.json'; path.write_bytes(b'{"value":NaN}')
        with self.assertRaisesRegex(ValueError, 'nonfinite JSON source'):
            Trial._read_ref(self.root.resolve(), Trial.source_reference(self.root, 'nonfinite.json'))
        with mock.patch.object(Trial, 'MAX_JSON', 10):
            with self.assertRaisesRegex(ValueError, 'oversized JSON source'):
                Trial._bytes(self.root / 'duplicate.json', Trial.MAX_JSON)

    def test_failed_atomic_update_preserves_current_state(self):
        before = (self.destination / 'trial.json').read_bytes()
        with mock.patch.object(Trial.os, 'replace', side_effect=PermissionError('synthetic replace refusal')):
            with self.assertRaises(PermissionError):
                Trial.append_observation(self.destination, self.observation('one', 'attempt', 'initial.json'))
        self.assertEqual((self.destination / 'trial.json').read_bytes(), before)
        self.assertFalse(list(self.destination.glob('*.tmp')))

    def test_source_read_race_is_refused(self):
        original = Trial._regular; calls = [0]
        def racing(path):
            result = original(path); calls[0] += 1
            return result if calls[0] < 2 else (*result[:-1], result[-1]+1)
        with mock.patch.object(Trial, '_regular', side_effect=racing):
            with self.assertRaisesRegex(ValueError, 'changed during read'):
                Trial._bytes(self.root / 'participant-run/run.json')

    def test_trial_custody_is_checked_before_lock_file_creation(self):
        copied = self.root / 'forbidden-trial.json'; copied.write_bytes((self.destination / 'trial.json').read_bytes())
        with self.assertRaisesRegex(ValueError, 'would alter retained source'):
            Trial.append_observation(copied, self.observation('one', 'attempt', 'initial.json'))
        self.assertFalse((self.root / 'trial.lock').exists())
        with self.assertRaisesRegex(ValueError, 'would alter retained source'):
            Trial.create_trial(self.source, self.actor, self.objective, self.root / 'forbidden')
        self.assertFalse((self.root / 'forbidden').exists())

    def test_concurrent_cli_appends_preserve_both_records(self):
        commands = []
        for name in ('concurrent-a', 'concurrent-b'):
            path = self.directory / (name+'.json'); save(path, self.observation(name, 'attempt', 'initial.json'))
            commands.append([sys.executable, str(SOURCE), 'append', str(self.destination), str(path)])
        env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}
        processes = [subprocess.Popen(c, cwd=str(TOOLS.parent), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)) for c in commands]
        for process in processes:
            stdout, stderr = process.communicate(timeout=15)
            self.assertEqual(process.returncode, 0, stderr.decode())
            self.assertEqual(json.loads(stdout)['schema'], Trial.TRIAL_SCHEMA)
        value = Trial.read_trial(self.destination)
        self.assertEqual({r['id'] for r in value['observations']}, {'concurrent-a', 'concurrent-b'})
        self.assertEqual(value['revision'], 2)

    def test_jsonl_native_event_joins_exact_body_sample(self):
        ref = Trial.source_reference(self.root, 'body-samples/initial.json')
        event = {'schema': 'sao.native-play-event/1', 'sessionId': self.session, 'kind': 'native-player-interval-started',
                 'sampleSha256': ref['sha256'], 'sourceObservedAtUnixMs': 1000, 'atUnixMs': 1001}
        path = self.root / 'events.jsonl'; path.write_bytes(Trial.encoded(event)+Trial.encoded(event))
        observation = self.observation('event', 'attempt', 'initial.json')
        observation['source'] = Trial.source_reference(self.root, 'events.jsonl', line=2)
        observation['measurements'] = {'event-kind': '/kind'}
        value = Trial.append_observation(self.destination, observation)
        self.assertEqual(value['observations'][0]['measurementsObserved']['event-kind']['value'], event['kind'])
        event['sampleSha256'] = 'd'*64; path.write_bytes(Trial.encoded(event))
        observation['source'] = Trial.source_reference(self.root, 'events.jsonl', line=1); observation['id'] = 'bad'
        with self.assertRaisesRegex(ValueError, 'body sample differs'):
            Trial.append_observation(self.destination, observation)

    def test_native_event_identity_fields_and_interval_are_exact(self):
        for field, wrong in [('playerSqlId', 99), ('save', 'other'), ('saveMode', 'other'),
                             ('playerIndex', 1), ('attempt', 2)]:
            event = {'schema': 'sao.native-play-event/1', 'sessionId': self.session, 'kind': 'synthetic-cost', field: wrong}
            save(self.root / 'event.json', event)
            observation = self.observation('foreign-event', 'cost', 'initial.json')
            observation['source'] = Trial.source_reference(self.root, 'event.json'); observation['measurements'] = {}
            with self.assertRaisesRegex(ValueError, 'event native body identity differs'):
                Trial.append_observation(self.destination, observation)
        save(self.root / 'event.json', {'schema': 'sao.native-play-event/1', 'sessionId': self.session,
             'kind': 'synthetic-cost', 'identity': ['Sandbox', 'other', 0, 7]})
        observation['source'] = Trial.source_reference(self.root, 'event.json')
        with self.assertRaisesRegex(ValueError, 'event native body interval differs'):
            Trial.append_observation(self.destination, observation)

    def test_native_event_clock_and_interval_types_are_exact(self):
        for fields, message in (({'sourceObservedAtUnixMs': 1000.0}, 'event body clock differs'),
                                ({'identity': ['Sandbox', 'synthetic-save', False, 7]}, 'event native body interval differs')):
            save(self.root / 'event.json', {'schema': 'sao.native-play-event/1', 'sessionId': self.session,
                                          'kind': 'synthetic-cost', **fields})
            observation = self.observation('typed-event', 'cost', 'initial.json')
            observation['source'] = Trial.source_reference(self.root, 'event.json'); observation['measurements'] = {}
            with self.assertRaisesRegex(ValueError, message):
                Trial.append_observation(self.destination, observation)

    def test_unchanged_source_parse_is_reused_and_changed_source_rejected(self):
        ref = self.source['runReceipt']; Trial._clear_source_cache(self.root.resolve())
        original = Trial._json
        with mock.patch.object(Trial, '_json', wraps=original) as parse:
            first = Trial._read_ref(self.root.resolve(), ref)
            second = Trial._read_ref(self.root.resolve(), ref)
            self.assertIs(first, second); self.assertEqual(parse.call_count, 1)
        run_path = self.root / ref['file']; run = deepcopy(self.run); run['status'] = 'failed'; save(run_path, run)
        with self.assertRaisesRegex(ValueError, 'stale or altered source'):
            Trial._read_ref(self.root.resolve(), ref)

    def test_source_cache_race_never_installs_unstable_snapshot(self):
        Trial._clear_source_cache(self.root.resolve())
        original = Trial.Participant.source_version; calls = [0]
        def racing(path, maximum):
            info = original(path, maximum); calls[0] += 1
            return info if calls[0] == 1 else (info[0], info[1], info[2]+1, *info[3:])
        with mock.patch.object(Trial.Participant, 'source_version', side_effect=racing):
            with self.assertRaisesRegex(ValueError, 'changed during read'):
                Trial._read_ref(self.root.resolve(), self.source['runReceipt'])
        self.assertFalse(any(key[0] == str(self.root / self.source['runReceipt']['file']) for key in Trial._SOURCE_CACHE))

    def test_measurement_is_copied_from_original_not_annotation(self):
        observation = self.observation('one', 'attempt', 'initial.json')
        observation['annotation'] = 'x is 999 (an intentionally wrong synthetic interpretation)'
        value = Trial.append_observation(self.destination, observation)
        self.assertEqual(value['observations'][0]['measurementsObserved']['position-x']['value'], 4)
        observation['id'] = 'unavailable'; observation['measurements']['position-x'] = '/absent'
        with self.assertRaisesRegex(ValueError, 'measurement field unavailable'):
            Trial.append_observation(self.destination, observation)

    def test_review_clock_and_foreign_evidence_are_refused(self):
        self.filled(); Trial.complete_trial(self.destination, self.completion())
        evaluation = self.evaluation(); evaluation['reviewedAtUnixMs'] = 100
        with self.assertRaisesRegex(ValueError, 'review predates'):
            Trial.evaluate_trial(self.destination, evaluation)
        evaluation = self.evaluation(); evaluation['evidence'] = ['another-trial']
        with self.assertRaisesRegex(ValueError, 'another trial or kind'):
            Trial.evaluate_trial(self.destination, evaluation)

    def test_trial_integrity_and_foreign_destination_are_refused(self):
        path = self.destination / 'trial.json'; value = json.loads(path.read_bytes())
        value['actor']['playerSqlId'] = 999; save(path, value)
        with self.assertRaisesRegex(ValueError, 'state was altered'):
            Trial.read_trial(path)

    def test_inverse_hash_guard_would_admit_altered_media(self):
        self.reviewed(); self.segment.write_bytes(b'corrupted synthetic segment')
        with self.assertRaisesRegex(ValueError, 'altered replay artifact'):
            Trial.export_candidate(self.destination, self.directory / 'guarded.json')
        with mock.patch.object(Trial, '_media_hash', return_value=None):
            result = Trial.export_candidate(self.destination, self.directory / 'inverse-no-media-check.json')
        self.assertEqual(result['evidenceOrigin'], 'synthetic-control')

    @unittest.skipUnless(os.environ.get('OBJECTIVE_TRIALS12_RECORDED_SOURCE'), 'retained native source explicitly supplied')
    def test_actual_native03_read_only_identity_and_replay_gap(self):
        root = Path(os.environ['OBJECTIVE_TRIALS12_RECORDED_SOURCE']).resolve()
        before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in
                  (root/'participant-run/run.json', root/'participant-run/attempts/0001/participant-identity.json',
                   root/'video-archive/archive.json')}
        source = Trial.build_source_manifest(root, 'participant-run/attempts/0001/participant-identity.json')
        actor = Trial.actor_binding(source, 'recorded-native-player:'+str(Trial._source(source)[3]['playerSqlId']), None,
                                    'Actual native03 retained participant; controller attribution unavailable.')
        objective = {**self.objective, 'assignedBy': 'research-tool-retrospective', 'mode': 'retrospective',
                     'assignedAtUnixMs': int(time.time()*1000),
                     'instruction': 'Investigate the retained attempt to play and interact normally; no prior objective assignment is recorded.'}
        target = self.directory / 'actual-native03-research'
        Trial.create_trial(source, actor, objective, target)
        body_ref = source['bodySource']
        event = {'id': 'actual-final-body', 'kind': 'context', 'source': body_ref, 'bodySource': body_ref,
                 'replay': [], 'annotation': 'Actual final body sample; objective/outcome/return/review remain unrecorded.',
                 'measurements': {'alive': '/alive', 'final-x': '/body/x'}}
        value = Trial.append_observation(target, event)
        self.assertEqual(value['status'], 'collecting')
        self.assertIn(value['source']['evidenceOrigin'], ('actual-native', 'unverified'))
        if not (root / 'feeds/0001/archive-finality.json').is_file():
            self.assertEqual(value['source']['evidenceOrigin'], 'unverified')
        with self.assertRaisesRegex(ValueError, 'explicit candidate review'):
            Trial.export_candidate(target, self.directory / 'actual-unreviewed-candidate.json')
        # Read an actual manifest row and verify original artifact hashes. This
        # is an archive comparison, not an invented earlier participant event.
        report_path = sorted((root/'video-archive/0001').glob('*/stream.json'))[-1]
        report = json.loads(report_path.read_bytes()); last_sequence = report['lastSegment']['sequence']
        choices = []
        for p in (report_path.parent/'manifests').glob('*.json'):
            manifest = json.loads(p.read_bytes())
            if any(r['sequence'] == last_sequence for r in manifest['segments']):
                choices.append(p)
        manifest_path = sorted(choices)[-1]
        replay = Trial.replay_reference(root, str(manifest_path.relative_to(root)).replace('\\','/'), last_sequence)
        row = next(r for r in json.loads(manifest_path.read_bytes())['segments'] if r['sequence'] == last_sequence)
        original_check = Trial._replay(source, replay, {'capturedAtUnixMs': row['capturedAtUnixMs'], 'worldHours': row['worldHours']})
        self.assertEqual(original_check['segment']['sha256'], row['sha256'])
        event['id'] = 'actual-unmatched-final-frame'; event['replay'] = [replay]
        with self.assertRaisesRegex(ValueError, 'outside replay clocks'):
            Trial.append_observation(target, event)
        for path, digest in before.items():
            self.assertEqual(hashlib.sha256(Path(path).read_bytes()).hexdigest(), digest)
        save(self.directory/'actual-native03-result.json', {'source': source, 'trialId': value['trialId'],
             'trialFile': str(target/'trial.json'), 'trialStatus': value['status'], 'candidateExported': False,
             'evidenceOrigin': value['source']['evidenceOrigin'],
             'actualReplayArtifactVerified': original_check['segment']['sha256'],
             'gaps': ['No recorded objective assignment, observed return or human review.',
                      'Final body sample falls after the retained video interval.', 'Legacy save namespace unrecorded.'],
             'originalSourceHashesBeforeAndAfter': before})


if __name__ == '__main__':
    unittest.main()
