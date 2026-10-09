"""Read-only native identity/save and archive namespace checks using isolated fixtures."""
import copy,json,os,sqlite3,struct,tempfile,time,unittest,uuid
from pathlib import Path
from contextlib import closing
from types import SimpleNamespace
import world_lab_run as Run
import world_lab_participant_feed as Feed
import world_lab_video_archive as Archive
import world_lab_video_archive_test as ArchiveFixtures


class SavedParticipantIdentity(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='sao-saved-identity-');self.root=Path(self.temp.name)
        self.cache=self.root/'participant-run/cache';self.save=self.cache/'Saves/Sandbox/ControlledSave'
        self.save.mkdir(parents=True);self.identity=self.cache.parent/'attempts/0001/participant-identity.json'
        self.receipt={'sessionId':str(uuid.uuid4()),'pid':os.getpid(),'launchNumber':1,'save':'ControlledSave',
                      'host':'player','participantInput':True,'mods':{'ControlledMod':{}},'mapName':'ControlledMap'}
        self.state={'schema':'sao-native-participant/1','sessionId':self.receipt['sessionId'],'pid':os.getpid(),
                    'attempt':1,'save':'ControlledSave','playerIndex':0,'playerSqlId':27,
                    'capturedAtUnixMs':int(time.time()*1000)-5000,'worldHours':2.5,'ready':True,
                    'displayFocused':False,'alive':False,'body':{'x':10.,'y':20.,'z':0.,'label':''}}
        self.definition={'seed':'controlled','extent':{'minCellX':1,'minCellY':2,'cellsX':3,'cellsY':4}}
        for name in ('map.bin','map_t.bin','map_sand.bin','map_meta.bin','map_zone.bin','global_mod_data.bin','WorldDictionary.bin'):(self.save/name).write_bytes(b'controlled save fixture')
        (self.save/'mods.txt').write_text('mod=ControlledMod,\n');(self.save/'map').mkdir();(self.save/'map/chunk.bin').write_bytes(b'controlled')
        label='ControlledMap';(self.save/'map_ver.bin').write_bytes(struct.pack('>ii',249,len(label))+label.encode('utf-16-be'))
        seed=self.definition['seed'].encode();(self.save/'map_worldgen.bin').write_bytes(struct.pack('>4sih',b'WGEN',249,len(seed))+seed+struct.pack('>iiii',1,2,3,5))
        with closing(sqlite3.connect(self.save/'players.db')) as database:
            database.execute('CREATE TABLE localPlayers(id INTEGER PRIMARY KEY,isDead INTEGER,data BLOB)')
            database.executemany('INSERT INTO localPlayers VALUES(?,?,?)',[(1,0,b'foreign legacy row'),(27,1,b'actual bound row')])
            database.commit()
        Feed.atomic(self.identity,self.state)
    def tearDown(self):self.temp.cleanup()
    def test_actual_sqlite_row27_not_foreign_legacy1(self):
        original=self.identity.read_bytes();value=Run.saved_state(self.cache,self.receipt,self.definition)
        self.assertEqual(value,{'id':27,'alive':False});self.assertEqual(self.identity.read_bytes(),original)
        self.assertEqual(self.receipt['participantIdentityEvidence']['playerSqlId'],27)
        self.assertEqual(self.receipt['participantIdentityEvidence']['sha256'],Run.digest(self.identity))
    def test_missing_actual_row_does_not_fall_back_to1(self):
        with closing(sqlite3.connect(self.save/'players.db')) as database:
            database.execute('DELETE FROM localPlayers WHERE id=27');database.commit()
        with self.assertRaisesRegex(ValueError,'store is empty'):Run.saved_state(self.cache,self.receipt,self.definition)
    def test_native_identity_foreign_bindings_and_sql_types_refused(self):
        cases=[('sessionId',str(uuid.uuid4())),('pid',os.getpid()+1),('attempt',2),('save','Other'),
               ('playerIndex',1),('playerSqlId',-1),('playerSqlId',0),('playerSqlId',True),
               ('playerSqlId',2**31),('ready',False),('capturedAtUnixMs',int(time.time()*1000)+10000)]
        for key,value in cases:
            with self.subTest(key=key,value=value):
                state=copy.deepcopy(self.state);state[key]=value;Feed.atomic(self.identity,state)
                with self.assertRaises(ValueError):Run.participant_player_identity(self.cache,dict(self.receipt))
    def test_missing_identity_snapshot_refused(self):
        self.identity.unlink()
        with self.assertRaisesRegex(ValueError,'invalid participant input file'):Run.participant_player_identity(self.cache,self.receipt)
    def test_timestamped_snapshot_byte_mutation_refused_after_pin(self):
        self.assertEqual(Run.participant_player_identity(self.cache,self.receipt),27)
        for key,value in [('playerSqlId',1),('capturedAtUnixMs',self.state['capturedAtUnixMs']+1),('worldHours',3.)]:
            with self.subTest(key=key):
                changed=copy.deepcopy(self.state);changed[key]=value;Feed.atomic(self.identity,changed)
                with self.assertRaisesRegex(ValueError,'identity evidence changed'):Run.participant_player_identity(self.cache,self.receipt)
    def test_unready_current_exit_state_preserves_last_actual_identity(self):
        current=copy.deepcopy(self.state);current.update(ready=False,playerSqlId=-1,alive=False,save='');current.pop('body')
        Feed.atomic(self.identity.with_name('participant-state.json'),current)
        self.assertEqual(Run.saved_state(self.cache,self.receipt,self.definition)['id'],27)
        self.assertEqual(Feed.read(self.identity.with_name('participant-state.json'))[1]['ready'],False)
    def test_nonparticipant_sql1_and_empty_observer_defaults_retained(self):
        legacy=dict(self.receipt,participantInput=False)
        self.assertEqual(Run.saved_state(self.cache,legacy,self.definition),{'id':1,'alive':True})
        with closing(sqlite3.connect(self.save/'players.db')) as database:
            database.execute('DELETE FROM localPlayers');database.commit()
        observer=dict(self.receipt,participantInput=False,host='observer')
        self.assertEqual(Run.saved_state(self.cache,observer,self.definition),{'count':0,'observerPersisted':False})
    def test_encoder_validation_actual_function_without_launch(self):
        args=SimpleNamespace(host='player',participant_input=True,video_fps=120,video_encoder=self.root/'absent.exe')
        with self.assertRaisesRegex(ValueError,'local executable'):Run.video_options(args)
        path=self.root/'protocol.txt';path.write_bytes(b'not executable');args.video_encoder=path
        with self.assertRaisesRegex(ValueError,'Windows executable'):Run.video_options(args)


class ArchiveNamespace(unittest.TestCase):
    def test_actual_collector_reads_participant_run_preserving_default_observer_route(self):
        # Hash/provenance collector fixture assets are labeled arbitrary bytes,
        # not MP4/native game footage. This verifies real collector namespace.
        with tempfile.TemporaryDirectory(prefix='sao-participant-archive-') as temporary:
            root=Path(temporary);source,value,session=ArchiveFixtures.fixture(root)
            ArchiveFixtures.publish(source,value,[1,2],'ended')
            (root/'native-run').rename(root/'participant-run')
            owner=Archive.Archive(root,'controlled-study',run_name='participant-run',min_free_bytes=0)
            owner.initialize();owner.poll()
            report=ArchiveFixtures.report(owner,value)
            self.assertEqual(report['nativeProvenance']['sessionId'],session)
            self.assertEqual(report['retainedSegments'],2);self.assertTrue(report['tailConfirmed'])
            self.assertEqual(Path(report['source']),root/'participant-run/attempts/0001/native-view')
            self.assertEqual((owner.root/'0001'/value['streamId']/value['segments'][0]['file']).read_bytes(),b'native-fragment-1')
        with tempfile.TemporaryDirectory(prefix='sao-observer-archive-') as temporary:
            root=Path(temporary);source,value,session=ArchiveFixtures.fixture(root);ArchiveFixtures.publish(source,value,[1],'ended')
            owner=Archive.Archive(root,'controlled-study',min_free_bytes=0);self.assertEqual(owner.run_name,'native-run')
            owner.initialize();owner.poll();self.assertEqual(ArchiveFixtures.report(owner,value)['retainedSegments'],1)
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(ValueError):Archive.Archive(Path(temporary),'controlled-study',run_name='../other')


if __name__=='__main__':unittest.main(verbosity=2)
