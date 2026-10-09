#!/usr/bin/env python3
"""Focused native proof for ordering complete D2 and loaded-person pools."""
import pathlib
import shutil
import subprocess
import sys
import tempfile

from gmatch_progress_test import JDK, OUT, PZ, SRC, STDLIB, build
from lua_read import function_body

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / 'mod/42.20/media/lua'
CALLS = {
    'client/SAO_Controller.lua': ('ranked',),
    'client/SAO_WeekOneContinuity.lua': ('found', 'candidates'),
    'client/SAO_MousecatInteraction.lua': ('candidates',),
}


def probe(source):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / 'stdlib.lua')
        for cls in OUT.glob('*.class'):
            shutil.copy2(cls, work / cls.name)
        done = subprocess.run(
            [str(JDK / 'java.exe'), '-cp', str(PZ) + ';.', 'LuaRun', '--', source],
            cwd=work, capture_output=True, text=True, timeout=120)
    lines = [line[6:] for line in done.stdout.splitlines() if line.startswith('VALUE ')]
    return lines[-1].strip() if done.returncode == 0 and lines else None


def expression(helper, controller):
    return '(function()\n' + helper.rsplit('return O', 1)[0] + '''
    local checks = 0
    local function checked(value) assert(value, "ordering-control"); checks=checks+1 end
    local function before(a,b) return a.score>b.score or a.score==b.score and a.id<b.id end
    local function rows(n,mode)
        local out={}
        for i=1,n do
            local index=mode=="reverse" and n-i+1 or mode=="scattered" and (i*613)%n+1 or i
            out[i]={id="modx:Fabricated"..index,score=index%37,ordinal=i}
        end
        return out
    end
    for _,n in ipairs({0,1,2,15,16,17,127,128,1500,8192})do
        for _,mode in ipairs({"sorted","reverse","scattered"})do
            local pool=rows(n,mode)
            local expected={};for i,row in ipairs(pool)do expected[i]=row end
            if n<129 then table.sort(expected,before)end
            SAO.Ordering.sort(pool,before)
            checked(#pool==n)
            for i,row in ipairs(pool)do
                if i>1 then checked(not before(row,pool[i-1]))end
                if n<129 then checked(row==expected[i])end
            end
        end
    end
    local same={{key=1,ordinal=1},{key=1,ordinal=2},{key=1,ordinal=3}}
    SAO.Ordering.sort(same,function(a,b)return a.key<b.key end)
    checked(same[1].ordinal==1 and same[3].ordinal==3)
    SAO.Cognition={scorePlan=function(id,row,ctx)return row.utility end}
    local Ctl={}
    function Ctl.limitPurposeComparison(''' + controller + '''end
    for _,n in ipairs({8,16,128,8192})do
        local pool={}
        for i=n,1,-1 do pool[#pool+1]={id=string.format("candidate-%05d",i),kind="purpose",
            utility=i,group="group-"..i}end
        local selected,receipt=Ctl.limitPurposeComparison("test",pool,{})
        checked(#pool==n and receipt.offered==n and receipt.compared==math.min(n,16))
        checked(#selected==math.min(n,16) and #receipt.omitted==math.max(0,n-16))
        if n>16 then
            for i=1,16 do checked(selected[i].utility==n-i+1)end
        else
            checked(selected==pool)
        end
    end
    return tostring(checks)
end)()'''


def main():
    if not SRC.is_file():
        print('nonrecursive ordering: missing owned native runner: ' + str(SRC), file=sys.stderr)
        return 1
    for relative, pools in CALLS.items():
        source = (LUA / relative).read_text(encoding='utf-8')
        for pool in pools:
            assert source.count('SAO.Ordering.sort(' + pool + ',') == 1, (relative, pool)
            assert 'table.sort(' + pool + ',' not in source, (relative, pool)
    helper = (LUA / 'shared/SAO_Ordering.lua').read_text(encoding='utf-8')
    source = (LUA / 'client/SAO_Controller.lua').read_text(encoding='utf-8')
    controller = function_body(source, 'Ctl.limitPurposeComparison')
    assert controller
    if not (JDK.exists() and PZ.exists() and STDLIB.exists()):
        print('nonrecursive ordering: four production routes checked; native probe SKIPPED (engine unavailable)')
        return 0
    assert build(), 'native runner did not compile'
    result = probe(expression(helper, controller))
    assert result and result.isdigit(), 'native ordering proof failed'
    # Removing iterative growth must leave a valid but incorrectly ordered
    # pool. The same proof must reject that mutation.
    mutated = helper.replace('width = width * 2', 'width = count')
    assert mutated != helper
    assert probe(expression(mutated, controller)) is None, 'single-pass mutation survived'
    print('nonrecursive ordering: PASS ' + result + ' native assertions, four production routes, one rejected growth mutation')
    return 0


if __name__ == '__main__':
    sys.exit(main())
