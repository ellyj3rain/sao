"""Actual acquisition CLIs classify absent owned fixtures and installed inputs.

Disposable CLI trees use exact runners/preflight-helper bytes with presence-only
owned fixtures. No native action, physical custody or hobby outcome is exercised.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / 'tools'
LUA = ROOT / 'mod/42.20/media/lua'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    helper = HERE / 'native_proof_preflight.py'
    if not helper.is_file():
        print('FAILED D2 acquisition portability: owned proof inputs absent: ' + str(helper))
        return 1
    from native_proof_preflight import presence, causal_controls
    common = [LUA / 'shared/SAO_WorldSources.lua', LUA / 'shared/SAO_ProceduralPlanning.lua',
              LUA / 'client/SAO_SourceUse.lua', LUA / 'client/SAO_LeisureAcquisition.lua']
    native_runner = HERE / 'd2_leisure_acquisition_native_test.py'
    native_owned = [native_runner, helper, *common, LUA / 'client/SAO_Needs.lua',
                    LUA / 'client/SAO_LeisureGames.lua', LUA / 'client/SAO_Controller.lua',
                    LUA / 'shared/SAO_CognitiveModels.lua', LUA / 'shared/SAO_Cognition.lua',
                    HERE / 'instrument_checks/InstrumentProbe.java',
                    HERE / 'd2_leisure_games/tabletop_fixture.java',
                    HERE / 'd2_leisure_acquisition_native_fixture.java',
                    HERE / 'luacheck/MovementCrossingProbe.java',
                    HERE / 'luacheck/ResourceApproachProbe.java',
                    HERE / 'cognition_checks/CognitionUseProbe.java',
                    HERE / 'd2_leisure_games/tabletop_prelude.lua',
                    HERE / 'd2_leisure_acquisition_native_cases.lua',
                    ROOT / 'mod/42.20/media/java/SAO.jar']
    controlled_runner = HERE / 'd2_leisure_acquisition_test.py'
    controlled_owned = [controlled_runner, helper, *common,
                        HERE / 'd2_leisure_acquisition_cases.lua', HERE / 'source_use_test.py',
                        HERE / 'luacheck/LuaRun.java']
    art_runner = HERE / 'd2_leisure_acquisition_art_test.py'
    art_owned = [art_runner, helper, *common, LUA / 'client/SAO_LeisureArt.lua',
                 HERE / 'd2_leisure_acquisition_art_cases.lua', HERE / 'source_use_test.py',
                 HERE / 'instrument_checks/InstrumentProbe.java',
                 HERE / 'd2_leisure_materials/metadata.java.inc', HERE / 'd2_leisure_art/fixture.lua',
                 HERE / 'luacheck/MovementCrossingProbe.java', HERE / 'luacheck/ResourceApproachProbe.java',
                 HERE / 'cognition_checks/CognitionUseProbe.java', ROOT / 'mod/42.20/media/java/SAO.jar']
    ready = presence([Path(__file__), *native_owned, *controlled_owned, *art_owned], [], True,
                     'D2 acquisition portability')
    if ready is not None:
        return ready
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    receipt = {'status': 'INCOMPLETE', 'boundary': __doc__, 'controls': []}
    try:
        for runner, owned, candidates in [
            (native_runner, native_owned, [HERE / 'd2_leisure_acquisition_native_fixture.java',
                                          HERE / 'd2_leisure_acquisition_native_cases.lua',
                                          LUA / 'client/SAO_LeisureAcquisition.lua']),
            (controlled_runner, controlled_owned, [HERE / 'd2_leisure_acquisition_cases.lua',
                                                   HERE / 'source_use_test.py']),
            (art_runner, art_owned, [HERE / 'd2_leisure_acquisition_art_cases.lua',
                                    HERE / 'd2_leisure_materials/metadata.java.inc']),
        ]:
            for candidate in candidates:
                result = causal_controls(ROOT, runner, owned,
                                         child_args=['--output', '{absent-engine}/proof'],
                                         missing_owned=candidate)
                result['runner'] = str(runner)
                receipt['controls'].append(result)
        receipt['status'] = 'PASS'
    except Exception as error:
        receipt['failure'] = str(error)
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(receipt['status'], 'D2 acquisition portability', len(receipt['controls']))
    return 0 if receipt['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
