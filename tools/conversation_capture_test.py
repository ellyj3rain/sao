#!/usr/bin/env python3
"""Border 189: immutable authored conversation evidence and source failures."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import conversation_evidence as E


class ConversationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.capture = E.run()

    def run_lua(self, code):
        return E.run('(function() ' + code + ' end)()')

    def test_production_capture_has_personal_acquisition_and_all_topics(self):
        E.validate(self.capture)
        v = self.capture
        self.assertEqual(v['coverage']['topics'], E.TOPICS)
        self.assertEqual(v['calendar']['atInstant'], '1993-07-11T00:00:00')
        self.assertEqual(v['sourceState']['worldRetention'][0]['acquisition']['path'], 'read')
        self.assertEqual(v['sourceState']['worldRetention'][0]['acquisition']['acquiredHour'], 24)
        world = [c for c in v['catalogue']['claims'] if c['topic'] == 'world']
        self.assertEqual(len(world), 1)
        self.assertEqual(world[0]['sourceClaimId'], 'knox-telecommunications-outage-1993-07-02')
        self.assertFalse(v['trainingEligible'])

    def test_reader_failure_cannot_be_an_empty_topic(self):
        for replacement, reader in (
            ('SAO.WorldKnowledge=nil', 'WorldKnowledge.state'),
            ('SAO.Perception.transferFacts=function() error("broken") end', 'perception.transfers'),
            ('SAO.Disposition.traits=nil', 'disposition.traits')):
            value = self.run_lua(replacement + '; return SAOConversationCapture.take(__conversationRequest)')
            with self.subTest(reader=reader):
                self.assertEqual(value['schema'], 'sao-conversation-capture-refusal')
                self.assertIn(reader, [x['reader'] for x in value['coverage']['failures']])

    def test_listener_does_not_inherit_the_speakers_read_report(self):
        value = self.run_lua('''__conversationRequest.personId=__conversationListener.id
            __conversationRequest.listenerRef=__conversationPerson.id
            return SAOConversationCapture.take(__conversationRequest)''')
        E.validate(value)
        self.assertEqual([c for c in value['catalogue']['claims'] if c['topic']=='world'], [])

    def test_global_chronicle_is_not_personal_memory(self):
        value = self.run_lua('''local s=ModData.getOrCreate("SurvivorAwareness_Standing")
            s.outbreakAtHours=4; s.firstTurnedAtHours=6; s.tapsDryAtHours=8
            return SAOConversationCapture.take(__conversationRequest)''')
        self.assertEqual([c for c in value['catalogue']['claims'] if c['topic']=='started'], [])

    def test_received_history_uses_receipt_time_and_provenance(self):
        value = self.run_lua('''assert(SAO.Perception.recordRadioReception(__conversationPerson.id,
            "broadcast-one", "county-wire", 100, 24,
            {representation="dormant",deviceItemId=3,deviceType="Base.Radio",
            channel=100,power=1}, {{kind="outbreak"}}))
            return SAOConversationCapture.take(__conversationRequest)''')
        rows = [c['fact'] for c in value['catalogue']['claims'] if c['topic']=='started']
        fact = next(r for r in rows if r['fact']=='county')
        self.assertEqual(fact['receivedAt'],24)
        self.assertEqual(fact['broadcastId'],'broadcast-one')
        self.assertEqual(fact['teller'],'county-wire')
        self.assertNotIn('day',fact)  # Reception date is not the event's date.

    def test_serialized_result_survives_later_owner_mutation(self):
        value = self.run_lua('''local frozen=SAOConversationCapture.take(__conversationRequest)
            __conversationPerson.originRegion="changed"
            SAO.Perception.beliefs[__conversationPerson.id].people={}
            return frozen''')
        self.assertEqual(value,self.capture)

    def test_capture_does_not_change_person_or_beliefs(self):
        value = self.run_lua('''local encode=SAODecisionCapture.encode
            local before=encode({__conversationPerson,__conversationListener,
                SAO.Perception.beliefs})
            SAOConversationCapture.take(__conversationRequest)
            return encode({unchanged=before==encode({__conversationPerson,
                __conversationListener,SAO.Perception.beliefs})})''')
        self.assertTrue(value['unchanged'])

    def refusal(self, setup, reason):
        value = self.run_lua(setup + '''
            local ok=pcall(SAOConversationCapture.take,__conversationRequest)
            return SAODecisionCapture.encode({accepted=ok,reason=SAOConversationCapture.failureReason})''')
        self.assertFalse(value['accepted'])
        self.assertEqual(value['reason'],reason)

    def test_absent_person_listener_beliefs_calendar_and_world_are_explicit(self):
        for setup, reason in (
            ('__conversationRequest.personId="absent"','person missing'),
            ('__conversationRequest.listenerRef="absent"','listener missing'),
            ('SAO.Perception.beliefs[__conversationPerson.id]=nil','private beliefs unavailable'),
            ('SAOJavaBridge.countyInstant=function() return nil end','calendar unavailable'),
            ('__conversationPerson.worldKnowledge=nil','world knowledge unavailable'),
            ('__conversationPerson.worldKnowledge.schemaVersion=99','world knowledge unsupported')):
            with self.subTest(reason=reason): self.refusal(setup,reason)

    def test_mutation_during_capture_refuses(self):
        self.refusal('''local old=SAO.Knowledge.catalogueEvidence
            SAO.Knowledge.catalogueEvidence=function(...)
                local a,b=old(...); __conversationPerson.x=17; return a,b
            end''','source changed during capture')

    def test_clock_advance_during_capture_refuses(self):
        self.refusal('''local old=SAO.Knowledge.catalogueEvidence
            SAO.Knowledge.catalogueEvidence=function(...)
                local a,b=old(...); __hours=49; return a,b
            end''','source changed during capture')

    def test_player_speech_origin_refuses(self):
        self.refusal('__conversationRequest.inputOrigin="player-recording"',
                     'authored conversation input required')

    def test_trace_is_cleared_after_refusal(self):
        value = self.run_lua('''local old=SAO.WorldKnowledge
            SAO.WorldKnowledge=nil; SAOConversationCapture.take(__conversationRequest)
            SAO.WorldKnowledge=old
            return SAOConversationCapture.take(__conversationRequest)''')
        self.assertEqual(value, self.capture)

    def test_export_binds_bytes_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            target=Path(tmp)/'example'
            manifest=E.generate(target)
            capture=json.loads((target/'capture.json').read_text(encoding='utf-8'))
            self.assertEqual(manifest['captureSha256'],E.digest(capture))
            before=(target/'capture.json').read_bytes()
            with self.assertRaisesRegex(ValueError,'destination exists'): E.generate(target)
            self.assertEqual((target/'capture.json').read_bytes(),before)

    def test_invalid_capture_never_publishes(self):
        with tempfile.TemporaryDirectory() as tmp:
            target=Path(tmp)/'bad'
            with patch.object(E,'run',return_value={'schema':'refused'}):
                with self.assertRaisesRegex(ValueError,'capture refused'): E.generate(target)
            self.assertFalse(target.exists())

    def test_changed_host_sources_never_publish(self):
        with tempfile.TemporaryDirectory() as tmp:
            target=Path(tmp)/'drift'
            with patch.object(E,'source_hashes',side_effect=[{'a':'one'},{'a':'two'}]):
                with self.assertRaisesRegex(ValueError,'source changed'): E.generate(target)
            self.assertFalse(target.exists())

    def test_known_bad_reader_mutation_flips_named_verdict(self):
        source=E.LUA/'shared/SAO_Knowledge.lua'
        text=source.read_text(encoding='utf-8')
        old='if not ok then evidenceReads.failures[name] = "reader-failed" end'
        self.assertEqual(text.count(old),1)
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/source.name
            path.write_text(text.replace(old,'if false then evidenceReads.failures[name] = "reader-failed" end'),encoding='utf-8')
            expr='(function() SAO.Disposition.traits=function() error("broken") end; return SAOConversationCapture.take(__conversationRequest) end)()'
            good=E.run(expr); bad=E.run(expr,knowledge=path)
            self.assertEqual(good['coverage']['reason'],'source-reader-failed')
            self.assertEqual(bad['schema'],'sao-conversation-capture')

    def test_known_bad_freeze_mutation_flips_named_verdict(self):
        text=E.CAPTURE.read_text(encoding='utf-8')
        old='and encode(readOwners()) == before'
        self.assertEqual(text.count(old),1)
        expr='''(function() local old=SAO.Knowledge.catalogueEvidence
            SAO.Knowledge.catalogueEvidence=function(...)
                local a,b=old(...); __conversationPerson.x=17; return a,b end
            local ok=pcall(SAOConversationCapture.take,__conversationRequest)
            return SAODecisionCapture.encode({accepted=ok,reason=SAOConversationCapture.failureReason}) end)()'''
        good=E.run(expr)
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/E.CAPTURE.name
            path.write_text(text.replace(old,'and true'),encoding='utf-8')
            bad=E.run(expr,capture=path)
        self.assertEqual(good['reason'],'source changed during capture')
        self.assertFalse(good['accepted']); self.assertTrue(bad['accepted'])

    def test_returned_identity_must_match_request(self):
        self.refusal('__conversationPerson.id=__conversationListener.id',
                     'participant identity differs')

    def test_replaced_beliefs_and_changed_standing_refuse(self):
        for mutation in ('SAO.Perception.beliefs[__conversationPerson.id]={}',
                         '__md.SurvivorAwareness_Standing.groups[__conversationPerson.id]="other"'):
            with self.subTest(mutation=mutation):
                self.refusal('''local old=SAO.Knowledge.catalogueEvidence
                    SAO.Knowledge.catalogueEvidence=function(...)
                        local a,b=old(...); ''' + mutation + '; return a,b end',
                    'source changed during capture')

    def test_different_question_gets_different_content_reference(self):
        value=self.run_lua('''__conversationRequest.utterance="Where is Jon?"
            return SAOConversationCapture.take(__conversationRequest)''')
        E.validate(value)
        self.assertNotEqual(value['snapshotRef'],self.capture['snapshotRef'])
        self.assertNotEqual(value['catalogue']['claims'][0]['ref'],
                            self.capture['catalogue']['claims'][0]['ref'])

    def test_soft_refusal_and_malformed_owner_state_cannot_claim_completeness(self):
        for mutation, reader in (
            ('SAO.WorldKnowledge.claimsOf=function() return nil,"unavailable" end','worldKnowledge.claims'),
            ('SAO.WorldKnowledge.claimsOf=function() return false,"unavailable" end','worldKnowledge.claims'),
            ('__md.SurvivorAwareness_Standing.schema=999','Standing.state'),
            ('__md.SurvivorAwareness_Standing.relations=nil','Standing.state'),
            ('__md.SurvivorAwareness_WorldSources.schema=999','WorldSources.state'),
            ('__conversationPerson.worldKnowledge.acquisitions={bad={}}','WorldKnowledge.state')):
            value=self.run_lua(mutation+'; return SAOConversationCapture.take(__conversationRequest)')
            with self.subTest(reader=reader):
                self.assertEqual(value['schema'],'sao-conversation-capture-refusal')
                self.assertIn(reader,[r['reader'] for r in value['coverage']['failures']])

    def test_malformed_radio_memory_is_not_silently_omitted(self):
        for claims in ('{{kind="outbreak",unsupported=true}}',
                       '{lost={kind="outbreak"}}', 'nil', '{[2]={kind="outbreak"}}'):
            value=self.run_lua('''SAO.Perception.beliefs[__conversationPerson.id].radioReceptions={
                broken={broadcastId="broken",sourceId="wire",receivedAt=1,
                    claims='''+claims+'''}}
                return SAOConversationCapture.take(__conversationRequest)''')
            with self.subTest(claims=claims):
                self.assertEqual(value['schema'],'sao-conversation-capture-refusal')
                self.assertIn('perception.radio',[r['reader'] for r in value['coverage']['failures']])

    def test_catalogue_refusal_does_not_normalize_standing(self):
        value=self.run_lua('''__md.SurvivorAwareness_Standing.relations=nil
            SAO.Knowledge.catalogueEvidence(__conversationPerson.id,__conversationListener.id,
                SAO.History.ticks(),"refused")
            return SAODecisionCapture.encode({unchanged=
                __md.SurvivorAwareness_Standing.relations==nil})''')
        self.assertTrue(value['unchanged'])

    def test_behavior_scenarios_execute_owners_and_preserve_unknown_channels(self):
        values = {name: E.run(scenario=name) for name in E.SCENARIOS}
        for value in values.values():
            E.validate(value)
            channels = value['behavior']['channels']
            self.assertEqual(channels['needs']['reason'], 'body-not-loaded')
            self.assertEqual(channels['activity']['status'], 'unavailable')
            self.assertEqual(channels['movementGoal']['status'], 'unavailable')
            self.assertEqual(channels['alternatives']['status'], 'unavailable')
        base = values['baseline']['behavior']['channels']
        self.assertEqual(base['cognition']['value']['load'], 0)
        self.assertEqual(values['trusted']['behavior']['channels']['relationship']['value']['trust'], .6)
        self.assertEqual(values['trusted']['behavior']['channels']['temperament'], base['temperament'])
        learned = values['learned']['behavior']['channels']
        self.assertLess(learned['temperament']['value']['nerve']['effective'], base['temperament']['value']['nerve']['effective'])
        self.assertEqual(learned['experience']['value']['provenance']['measure-the-danger']['src'], 'told')
        strained = values['strain']['behavior']['channels']['cognition']['value']
        self.assertGreater(strained['load'], 0)
        self.assertGreater(strained['decisionTicks'], strained['baseDecisionTicks'])
        self.assertGreater(values['threat']['behavior']['channels']['threat']['value']['pressure'], 0)
        self.assertEqual(base['threat']['value']['pressure'], 0)
        for value in values.values():
            reports = [r['fact'] for r in value['catalogue']['claims'] if r['topic']=='world']
            self.assertEqual(reports, [r['fact'] for r in values['baseline']['catalogue']['claims'] if r['topic']=='world'])

    def test_behavior_missing_observation_and_stale_observation_are_not_health(self):
        for setup, expected in [('', 'no-recorded-observation'),
                ('SAO.Neuro.observe(__conversationPerson,47,"old",{wound=false});', 'observation-not-current')]:
            result = self.run_lua(setup + '''__conversationRequest.includeBehavior=true;
                return SAOConversationCapture.take(__conversationRequest)''')
            self.assertEqual(result['behavior']['channels']['cognition']['reason'], expected)
            self.assertNotIn('value', result['behavior']['channels']['cognition'])

    def test_behavior_owner_failure_and_mutation_refuse(self):
        self.refusal('''__conversationRequest.includeBehavior=true;
            SAO.Conditions.bend=function() error("broken") end''', 'behavior-reader-failed:temperament')
        self.refusal('''__conversationRequest.includeBehavior=true;
            SAO.Disposition.traitEvidence=function() return {} end''', 'behavior-reader-failed:temperament')
        self.refusal('''__conversationRequest.includeBehavior=true;
            SAO.Perception.beliefs[__conversationPerson.id].zombies.bad={x=10601,y=9700,dist=1,at=999999,source="observed"}''',
            'behavior-reader-failed:threat')
        self.refusal('''__conversationRequest.includeBehavior=true;
            local old=SAO.Disposition.traitEvidence
            SAO.Disposition.traitEvidence=function(id)
                local v=old(id); __conversationPerson.x=1; return v end''', 'source changed during capture')

    def test_behavior_binding_and_contribution_mutations_refuse_after_resealing(self):
        value = E.run(scenario='baseline')
        for change, reason in [
                (lambda v: v['behavior'].update(personId='other'), 'binding'),
                (lambda v: v['behavior']['channels']['temperament'].update(value={}), 'axes'),
                (lambda v: v['behavior']['channels']['temperament']['value']['nerve'].update(condition=0), 'temperament')]:
            broken = copy.deepcopy(value)
            change(broken)
            broken = E.freeze(E.observation(broken))
            with self.assertRaisesRegex(ValueError, reason): E.validate(broken)

    def test_behavior_loaded_reader_binds_body_controller_and_movement(self):
        # Controlled boundary objects exercise the read API, not native play or captures.
        setup = '''local id=__conversationPerson.id
            local body={hasModData=function() return true end,
                getModData=function() return {SAOPersonId=id} end}
            SAO.Body.get=function(key) if key==id then return body end end
            SAO.Needs={read=function() return {hunger=.2,thirst=.3,fatigue=.7,endurance=.2} end}
            SAO.Controller={agents={}}
            SAO.Controller.agents[id]={rec=__conversationPerson,state="FORAGE",
                pressure={answer="need",detail="food",at=432000}}
            SAO.Locomotion={jobs={}}
            SAO.Locomotion.jobs[id]={body=body,done=false,goal={x=10603,y=9700,z=0}}
        '''
        query = '''local value,reason=SAO.Knowledge.behaviorEvidence(id,__conversationListener.id,432000)
            return SAODecisionCapture.encode({value=value,reason=reason})'''
        good = self.run_lua(setup + query)['value']['channels']
        self.assertEqual(good['needs']['value']['fatigue'], .7)
        self.assertEqual(good['activity']['value']['answer'], 'need')
        self.assertEqual(good['movementGoal']['value']['goal']['x'], 10603)
        absent = '''body.hasModData=function() return false end
            body.getModData=function() error("read allocated metadata") end;'''
        self.assertEqual(self.run_lua(setup + absent + query)['reason'], 'behavior-body-owner-differs')
        # IsoObject.getModData allocates when absent; hasModData reads only.
        # Remove the actual guard and observe allocation, not just a code match.
        source = E.LUA / 'shared/SAO_Knowledge.lua'
        text = source.read_text(encoding='utf-8')
        guard = 'if not body:hasModData() then return nil end'
        self.assertEqual(text.count(guard), 1)
        probe = setup + '''local allocated=false
            body.hasModData=function() return false end
            body.getModData=function() allocated=true; return {SAOPersonId=id} end
            SAO.Knowledge.behaviorEvidence(id,__conversationListener.id,432000)
            return SAODecisionCapture.encode({allocated=allocated})'''
        self.assertFalse(self.run_lua(probe)['allocated'])
        with tempfile.TemporaryDirectory() as temp:
            bad = Path(temp) / source.name
            bad.write_text(text.replace(guard, ''), encoding='utf-8')
            self.assertTrue(E.run('(function() ' + probe + ' end)()', knowledge=bad)['allocated'])
        for change, reason in [
                ('SAO.Controller.agents[id].rec=__conversationListener;', 'behavior-reader-failed:activity'),
                ('SAO.Locomotion.jobs[id].body={};', 'behavior-reader-failed:movementGoal'),
                ('body.getModData=function() return {SAOPersonId="other"} end;', 'behavior-body-owner-differs')]:
            self.assertEqual(self.run_lua(setup + change + query)['reason'], reason)

    def test_actual_trait_contribution_mutation_changes_named_verdict(self):
        source = E.LUA / 'shared/SAO_Disposition.lua'
        text = source.read_text(encoding='utf-8')
        old = 'condition = carried, effective = value'
        self.assertEqual(text.count(old), 1)
        with tempfile.TemporaryDirectory() as temp:
            bad = Path(temp) / source.name
            bad.write_text(text.replace(old, 'condition = 0, effective = value'), encoding='utf-8')
            with self.assertRaisesRegex(RuntimeError, 'behavior-reader-failed:temperament'):
                E.run(scenario='baseline', disposition=bad)

    def test_behavior_does_not_elect_a_branch(self):
        result = self.run_lua('''SAO.Branching.select=function() error("must not elect") end
            __conversationRequest.includeBehavior=true
            return SAOConversationCapture.take(__conversationRequest)''')
        E.validate(result)

    def test_direct_behavior_reader_refuses_nonfinite_threat_time(self):
        result = self.run_lua('''SAO.Perception.beliefs[__conversationPerson.id].zombies.bad={
            x=10601,y=9700,dist=1,at=0/0,source="observed"}
            local value,reason=SAO.Knowledge.behaviorEvidence(__conversationPerson.id,__conversationListener.id,432000)
            return SAODecisionCapture.encode({value=value,reason=reason})''')
        self.assertEqual(result['reason'], 'behavior-reader-failed:threat')


if __name__ == '__main__':
    if not (E.Sweep.PZ.exists() and E.Sweep.JDK.exists()):
        print('189) conversation capture: SKIPPED - engine or JDK absent')
        sys.exit(0)
    program = unittest.main(verbosity=1, exit=False)
    sys.exit(0 if program.result.wasSuccessful() else 1)
