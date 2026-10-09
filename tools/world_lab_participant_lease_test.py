"""Native input authority controls using actual broker and explicitly simulated bodies."""
import copy,json,os,tempfile,unittest,uuid
from pathlib import Path
import world_lab_participant_lease as L


class BrokerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.root=Path(self.tmp.name)
        self.now=10000; self.native=111; self.client=222; self.live={111,222,os.getpid()}
        self.run={'host':'player','participantInput':True,'status':'running','sessionId':str(uuid.uuid4()),
                  'pid':111,'launchNumber':1,'save':'FreshParticipant'}
        self.state={'schema':'sao-native-participant/1','ready':True,'alive':True,'displayFocused':True,
                    'sessionId':self.run['sessionId'],'pid':111,'attempt':1,'save':'FreshParticipant',
                    'playerIndex':0,'playerSqlId':17,'capturedAtUnixMs':10000,'worldHours':1.2,
                    'body':{'x':12.,'y':13.,'z':0.,'label':'Actual test body'}}
        (self.root/'attempts/0001').mkdir(parents=True); self.save()
        self.b=L.ParticipantLeaseBroker(self.root,clock=lambda:self.now,live=lambda pid:pid in self.live)
    def tearDown(self): self.b.close(); self.tmp.cleanup()
    def save(self):
        L.atomic(self.root/'run.json',self.run); L.atomic(self.root/'attempts/0001/participant-state.json',self.state)
    def request(self,seq=1):
        return {'schema':L.REQUEST,'requestId':str(uuid.uuid4()),'clientPid':222,'sequence':seq,
                **{k:self.state[k] for k in L.IDENTITY},'expiresAtUnixMs':self.now+1000,
                'released':False,'keys':[17,31],'mouse':{'x':20,'y':30,'buttons':[0]}}
    def test_exact_actual_sql_id(self):
        held=self.b.accept(self.request()); self.assertEqual(held['playerSqlId'],17)
        self.assertEqual(held['holderPid'],os.getpid()); self.assertTrue(L.validate_lease(held,self.b.identity(),self.now,lambda _:True))
    def test_current_body_save_before_running_receipt_has_final_save(self):
        self.run.pop('save');self.save()
        held=self.b.accept(self.request())
        self.assertEqual(held['save'],'FreshParticipant')
        self.state['save']='';self.save()
        with self.assertRaises(ValueError):self.b.identity()
    def test_empty_observed_label_does_not_block_real_identity(self):
        self.state['body']['label']='';self.save()
        held=self.b.accept(self.request())
        self.assertEqual(held['playerSqlId'],17)
        self.assertEqual(self.state['body']['label'],'')
    def test_foreign_bindings_refused(self):
        for key,value in [('sessionId',str(uuid.uuid4())),('pid',112),('attempt',2),('save','Other'),('playerIndex',1),('playerSqlId',18)]:
            with self.subTest(key=key):
                request=self.request(); request[key]=value
                with self.assertRaises(ValueError):self.b.accept(request)
        self.assertFalse(self.b.path.exists())
    def test_unready_stale_dead_unfocused_identity_refused(self):
        for key,value in [('ready',False),('alive',False),('displayFocused',False),('capturedAtUnixMs',8999),('capturedAtUnixMs',10001),('playerSqlId',-1)]:
            with self.subTest(key=key):
                original=self.state[key]; self.state[key]=value; self.save()
                with self.assertRaises(ValueError):self.b.accept(self.request())
                self.state[key]=original
        self.save(); self.live.remove(111)
        with self.assertRaises(ValueError):self.b.accept(self.request())
    def test_no_cached_automatic_renewal(self):
        initial=self.b.accept(self.request()); self.b.poll()
        self.assertEqual(initial,L.read(self.b.path))
        self.now+=1001; self.state['capturedAtUnixMs']=self.now; self.save(); self.b.poll()
        value=L.read(self.b.path); self.assertTrue(value['released']); self.assertFalse(value['keys']); self.assertFalse(value['mouse']['buttons'])
    def test_focus_loss_release(self):
        self.b.accept(self.request()); self.state['displayFocused']=False; self.save(); self.b.poll()
        self.assertTrue(L.read(self.b.path)['released'])
    def test_client_exit_release(self):
        self.b.accept(self.request()); self.live.remove(222); self.b.poll()
        self.assertTrue(L.read(self.b.path)['released'])
    def test_body_replacement_release(self):
        self.b.accept(self.request()); self.state['playerSqlId']=18; self.save(); self.b.poll()
        self.assertTrue(L.read(self.b.path)['released'])
    def test_native_exit_release(self):
        self.b.accept(self.request()); self.run['status']='exited'; self.save(); self.b.poll()
        self.assertTrue(L.read(self.b.path)['released'])
    def test_replay_and_competing_client_refused(self):
        self.b.accept(self.request())
        with self.assertRaises(ValueError):self.b.accept(self.request())
        request=self.request(2); request['clientPid']=os.getpid()
        with self.assertRaises(ValueError):self.b.accept(request)
    def test_lifetime_and_typing_types(self):
        for key,value in [('expiresAtUnixMs',self.now),('expiresAtUnixMs',self.now+2001),('released',1),('attempt',True),('sequence',True),('keys',[True]),('keys',[17,17]),('mouse',{'x':False,'y':1,'buttons':[]})]:
            with self.subTest(key=key):
                request=self.request();request[key]=value
                with self.assertRaises(ValueError):self.b.accept(request)
    def test_duplicate_nonfinite_json_refused(self):
        path=self.root/'bad.json'
        for raw in ['{"schema":"x","schema":"y"}','{"x":NaN}','[]']:
            path.write_text(raw)
            with self.assertRaises(ValueError):L.read(path)
    def test_partial_foreign_filename_and_unknown_field_refused(self):
        for raw in ['{"schema":',json.dumps({**self.request(),'unknown':True})]:
            path=self.b.inbox/(str(uuid.uuid4())+'.json');path.write_text(raw);self.b.poll()
            self.assertFalse(path.exists());self.assertFalse(self.b.path.exists())
    def test_inbox_consumption_and_durable_receipt(self):
        request=self.request(); path=self.b.inbox/(request['requestId']+'.json');L.atomic(path,request);self.b.poll()
        self.assertFalse(path.exists());self.assertEqual(L.read(self.b.path)['generation'],1)
        event=json.loads((self.root/'participant-input-events.jsonl').read_text().splitlines()[-1])
        self.assertEqual(event['requestId'],request['requestId']);self.assertEqual(event['binding']['playerSqlId'],17)
    def test_release_generation_and_zero_input(self):
        self.b.accept(self.request());self.b.release('human-left')
        value=L.read(self.b.path);self.assertTrue(value['released']);self.assertEqual(value['generation'],2)
        self.assertEqual(value['keys'],[]);self.assertEqual(value['mouse']['buttons'],[])
        self.b.accept(self.request(2));self.assertEqual(L.read(self.b.path)['generation'],3)
    def test_actual_process_check(self):
        self.assertTrue(L.process_live(os.getpid()));self.assertFalse(L.process_live(0))
    def test_single_writer_and_large_receipt(self):
        with self.assertRaises(FileExistsError):L.ParticipantLeaseBroker(self.root)
        self.run['retainedCopiedSourceManifest']='x'*100000;self.save()
        self.b.accept(self.request());self.assertEqual(L.read(self.b.path)['playerSqlId'],17)


if __name__=='__main__':unittest.main()
