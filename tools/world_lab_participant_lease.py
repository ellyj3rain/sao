"""One attempt-owned input broker; native physical input remains independent.

Requests are immutable local inbox files. They grant at most two seconds of
leased input to the exact, freshly observed native body. Each renewal is explicit;
the broker never renews cached input merely because its own process is alive.
"""
from __future__ import annotations
import ctypes
import json
import math
import os
from pathlib import Path
import time
import uuid

SCHEMA = 'sao.participant-input-lease/1'
REQUEST = 'sao.participant-input-request/1'
MAX_TTL_MS = 2000
MAX_STATE_AGE_MS = 1000
IDENTITY = ('sessionId', 'pid', 'attempt', 'save', 'playerIndex', 'playerSqlId')


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError('duplicate input field')
        result[key] = value
    return result


def read(path, maximum=65536):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > maximum:
        raise ValueError('invalid participant input file')
    value = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=_object,
                       parse_constant=lambda _: (_ for _ in ()).throw(ValueError('nonfinite input')))
    if not isinstance(value, dict): raise ValueError('input must be an object')
    return value


def integer(value, lo, hi):
    if type(value) is not int or not lo <= value <= hi: raise ValueError('input integer differs')
    return value


def text(value, maximum=180, *, empty=False):
    if not isinstance(value, str) or not (0 if empty else 1) <= len(value) <= maximum or any(ord(c) < 32 for c in value):
        raise ValueError('input string differs')
    return value


def process_live(pid):
    if type(pid) is not int or pid <= 0: return False
    if os.name == 'nt':
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.argtypes = (ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.GetExitCodeProcess.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong))
        kernel.CloseHandle.argtypes = (ctypes.c_void_p,)
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle: return False
        try:
            code = ctypes.c_ulong()
            return bool(kernel.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259
        finally: kernel.CloseHandle(handle)
    try: os.kill(pid, 0); return True
    except (OSError, OverflowError): return False


def atomic(path, value):
    data = (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode()
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_bytes(data)
    for attempt in range(20):
        try: os.replace(temporary, path); return
        except PermissionError:
            if attempt == 19: raise
            time.sleep(.01)


def binding(run, state, now, live=process_live, *, require_focus=True):
    if run.get('host') != 'player' or run.get('participantInput') is not True or run.get('status') != 'running':
        raise ValueError('native participant is not running')
    if state.get('schema') != 'sao-native-participant/1' or state.get('ready') is not True or state.get('alive') is not True:
        raise ValueError('native participant body is unavailable')
    stamp = integer(state.get('capturedAtUnixMs'), 0, 2**53 - 1)
    if not 0 <= now - stamp <= MAX_STATE_AGE_MS: raise ValueError('native participant identity is stale')
    expected = {'sessionId':run['sessionId'], 'pid':run['pid'], 'attempt':run['launchNumber'],
                'save':run.get('save') or state.get('save'), 'playerIndex':state.get('playerIndex'), 'playerSqlId':state.get('playerSqlId')}
    if str(uuid.UUID(expected['sessionId'])) != expected['sessionId']: raise ValueError('native session differs')
    integer(expected['pid'], 1, 2**31-1); integer(expected['attempt'], 1, 2**31-1)
    integer(expected['playerIndex'], 0, 0); integer(expected['playerSqlId'], 1, 2**31-1); text(expected['save'])
    if any(state.get(key) != value for key, value in expected.items()): raise ValueError('native participant identity differs')
    if not live(expected['pid']): raise ValueError('native participant process is gone')
    if require_focus and state.get('displayFocused') is not True: raise ValueError('native participant is not focused')
    body = state.get('body')
    if not isinstance(body, dict) or any(type(body.get(k)) not in (int,float) or not math.isfinite(body[k]) for k in ('x','y','z')):
        raise ValueError('native participant pose is unavailable')
    text(body.get('label'),160,empty=True)
    return expected


def validate_lease(value, expected, now, live=process_live):
    required = {'schema', *IDENTITY, 'holderPid','leaseId','generation','expiresAtUnixMs','released','keys','mouse'}
    if set(value) - required - {'releaseReason'} or not required <= set(value): raise ValueError('lease fields differ')
    if value['schema'] != SCHEMA or any(value[k] != expected[k] for k in IDENTITY): raise ValueError('lease identity differs')
    integer(value['holderPid'],1,2**31-1); text(value['leaseId']); integer(value['generation'],0,2**53-1)
    expiry = integer(value['expiresAtUnixMs'],0,2**53-1)
    if type(value['released']) is not bool: raise ValueError('lease release differs')
    keys, mouse = value['keys'], value['mouse']
    if not isinstance(keys,list) or len(keys)>256 or len(set(keys))!=len(keys): raise ValueError('lease keys differ')
    for key in keys: integer(key,0,9999)
    if not isinstance(mouse,dict) or set(mouse)!= {'x','y','buttons'}: raise ValueError('lease pointer differs')
    integer(mouse['x'],-100000,100000); integer(mouse['y'],-100000,100000)
    buttons=mouse['buttons']
    if not isinstance(buttons,list) or len(buttons)>32 or len(set(buttons))!=len(buttons): raise ValueError('lease buttons differ')
    for button in buttons: integer(button,0,31)
    if value['released'] and (keys or buttons): raise ValueError('released input remains held')
    return not value['released'] and 0 < expiry-now <= MAX_TTL_MS and live(value['holderPid'])


class ParticipantLeaseBroker:
    def __init__(self, run_root, *, clock=None, live=process_live):
        self.root=Path(run_root).resolve()
        self.clock=clock or (lambda:int(time.time()*1000)); self.live=live
        self.path=self.root/'participant-input-lease.json'
        self.inbox=self.root/'participant-input-requests'; self.inbox.mkdir(exist_ok=True)
        self.lock=self.root/'participant-input-owner.lock'
        self.owner=self.lock.open('x',encoding='utf-8'); self.owner.write(str(os.getpid())); self.owner.flush()
        self.lease_id=str(uuid.uuid4()); self.generation=0; self.current=None; self.client=None; self.sequences={}
        self.run_stamp=None; self.run_value=None

    def identity(self):
        path=self.root/'run.json'; stat=path.stat(); stamp=(stat.st_mtime_ns,stat.st_size)
        if self.run_stamp!=stamp:
            self.run_value=read(path,32*1024*1024); self.run_stamp=stamp
        run=self.run_value
        attempt=integer(run.get('launchNumber'),1,2**31-1)
        state=read(self.root/'attempts'/f'{attempt:04d}'/'participant-state.json')
        return binding(run,state,self.clock(),self.live)

    def record(self, value):
        with (self.root/'participant-input-events.jsonl').open('a',encoding='utf-8') as out:
            out.write(json.dumps(value,sort_keys=True,allow_nan=False)+'\n')

    def accept(self, request):
        now=self.clock(); expected=self.identity()
        fields={'schema','requestId','clientPid','sequence','expiresAtUnixMs','released','keys','mouse',*IDENTITY}
        if set(request)!=fields or request['schema']!=REQUEST: raise ValueError('request fields differ')
        request_id=request['requestId']
        if str(uuid.UUID(request_id))!=request_id: raise ValueError('request id differs')
        if any(request[k]!=expected[k] for k in IDENTITY): raise ValueError('request native identity differs')
        for key in ('pid','attempt','playerIndex','playerSqlId'):
            if type(request[key]) is not int: raise ValueError('request native identity type differs')
        client=integer(request['clientPid'],1,2**31-1); seq=integer(request['sequence'],1,2**53-1)
        if not self.live(client): raise ValueError('input client is gone')
        if seq<=self.sequences.get(client,0): raise ValueError('input request replay')
        if self.client is not None and self.client!=client and self.current and validate_lease(self.current,expected,now,self.live):
            raise ValueError('native participant input already has a holder')
        value={'schema':SCHEMA,**expected,'holderPid':os.getpid(),'leaseId':self.lease_id,
               'generation':self.generation+1,'expiresAtUnixMs':request['expiresAtUnixMs'],
               'released':request['released'],'keys':request['keys'],'mouse':request['mouse']}
        held=validate_lease(value,expected,now,self.live)
        if not value['released'] and not held: raise ValueError('input request expired or exceeds bounded lifetime')
        atomic(self.path,value)
        self.current=value; self.client=None if value['released'] else client
        self.generation=value['generation']; self.sequences[client]=seq
        self.record({'schema':'sao.participant-input-event/1','atUnixMs':now,'requestId':request_id,
                     'clientPid':client,'sequence':seq,'binding':expected,'generation':self.generation,
                     'status':'released' if value['released'] else 'held'})
        return value

    def release(self, reason='session-stop'):
        if self.current is None or self.current['released']: return
        value={**self.current,'generation':self.generation+1,'released':True,
               'expiresAtUnixMs':self.clock(),'keys':[], 'mouse':{**self.current['mouse'],'buttons':[]},
               'releaseReason':text(reason,80)}
        atomic(self.path,value); self.current=value; self.generation=value['generation']; self.client=None
        self.record({'schema':'sao.participant-input-event/1','atUnixMs':self.clock(),
                     'generation':self.generation,'status':'released','reason':reason,
                     'binding':{k:value[k] for k in IDENTITY}})

    def poll(self):
        if self.current and not self.current['released']:
            try:
                expected=self.identity()
                if not self.live(self.client) or not validate_lease(self.current,expected,self.clock(),self.live):
                    self.release('holder-expired')
            except (ValueError,KeyError,OSError,TypeError): self.release('native-identity-or-focus-lost')
        for path in sorted(self.inbox.glob('*.json'))[:64]:
            try:
                request=read(path)
                if path.name!=request.get('requestId','')+'.json': raise ValueError('input request filename differs')
                self.accept(request)
            except (ValueError,KeyError,OSError,TypeError) as error:
                self.record({'schema':'sao.participant-input-event/1','atUnixMs':self.clock(),
                             'file':path.name,'status':'refused','reason':str(error)[:180]})
            finally: path.unlink(missing_ok=True)

    def close(self):
        try: self.release('broker-disconnect')
        finally:
            self.owner.close(); self.lock.unlink(missing_ok=True)
