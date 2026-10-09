#!/usr/bin/env python3
r"""Border 32 - a mirror nobody runs is a claim nobody checks.

This project writes a mirror per batch and cites it in the batch
record as though writing it were the same as running it. It is not.

Measured at [B41]: **thirty-three mirrors in `tools/`, eleven in the
gate.** Twenty-two had never been invoked by anything, among them

  * `key_domain_test`, where [B37] and [B40] both put standing laws
  * `save_compat_test`, whose own record ([B36]) says *"this makes it
    a gate"* - it did not, and every "0 dropped" reported for twenty-six
    batches was a number somebody went and fetched by hand

And the cost was already paid. `belief_life_test` reads
`PLACE_SIGHT` out of `SAO_Perception`. [B40] exported that constant
from a file-level local to `P.PLACE_SIGHT` so both halves of the county
would read one reach - and blinded the mirror in the same edit. The
mirror said so, in its own output, to nobody, for as long as it stayed
out of the gate.

WHAT THIS REQUIRES
------------------
1. Standing checks have actual invocations in `check.sh`. Other
   qualification tools have named scopes or dated one-off ownership
   here. GOVERNANCE.md selects them when their inputs or contracts
   change and preserves applicable receipts.

2. Every standing check has a path that can FAIL. [B36]'s second clause at
   fleet scale: a mirror whose every path returns zero is a REPORT. It
   may be worth reading and it is not a check, and gating it buys
   runtime in exchange for a guaranteed pass.

3. Every scoped or one-off declaration names an existing file and its
   reason. A declaration that outlives its subject stops describing
   current ownership.
"""
import ast
import itertools
import shlex
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
CHECK = TOOLS / "check.sh"

# Standing borders run in check.sh. Scoped qualification tools are selected
# for affected contracts under GOVERNANCE.md; dated staging proofs retain
# the exact predecessor inputs their receipts qualified.
ONE_OFF = {'d2_newmusic_loot_diagnostic_test.py': 'D2 loot repair qualification requires the recorded pre-repair '
                                        'source through --before.',
 'd2_newmusic_track_context_test.py': 'D2 exact lexical repair stages its selected source generation; '
                                      'current playback has separate source/consumer receipts.',
 'd2_newmusic_track_package_test.py': 'D2 single-leaf package repair qualifies its captured predecessor and '
                                      'importer installation.',
 'd2_source_registration_test.py': 'D2 parser qualification consumes a specific sealed registration merge '
                                   'through --merge; package inventory retains the current registration '
                                   'contract.',
 'd2_source_residual_lifestyle_test.py': 'D2 staging proof qualifies captured Lifestyle namespace residuals '
                                         'and selected modes.',
 'd2_source_residual_music_arcade_test.py': 'D2 staging proof qualifies the recorded NewMusic/Arcade '
                                            'namespace generation.',
 'd2_source_temporary_importer_test.py': 'D2 importer proof joins a particular staged source/native '
                                         'qualification by byte identity.',
 'd2_source_temporary_test.py': 'D2 staged temporary-local repair qualifies its captured source generation '
                                'and native callers.',
 'weekone_poll_cursor_test.py': 'D2 cursor repair explicitly compares the shipped jar to its preserved '
                                'rejected predecessor.',
 'world_lab_start_cache05_test.py': 'C120/D2 cache repair compares selected compiled cohorts and optional '
                                    'recorded preimages.'}

SCOPED = {'age_visual_transition_test.py': 'C120/D1/D2 contract qualification: Run age presentation and inverse '
                                  'controls in the installed Kahlua VM. Select when its owned source or '
                                  'contract changes; preserve applicable receipts.',
 'appearance_base_visual_test.py': 'C120/D1/D2 contract qualification: Verify native visual ownership and '
                                   'production age updates on installed Kahlua. Select when its owned source '
                                   'or contract changes; preserve applicable receipts.',
 'appearance_snapshot_age_combined_test.py': 'C120/D1/D2 contract qualification: Installed headless v4 '
                                             'snapshot then production Kahlua age on one native body. Select '
                                             'when its owned source or contract changes; preserve applicable '
                                             'receipts.',
 'civil_hour_join_test.py': 'C120/D1/D2 contract qualification: Exercise the historical/live civil-hour join '
                            'in installed Kahlua. Select when its owned source or contract changes; preserve '
                            'applicable receipts.',
 'companion_execution_test.py': 'C120/D1/D2 contract qualification: Exercise the source companion lease in '
                                'installed Kahlua with inverses. Select when its owned source or contract '
                                'changes; preserve applicable receipts.',
 'd2_arcade_consumer_bindings_test.py': 'D2 source qualification: Lazy exact Arcade consumer owners; full '
                                        'native source-inactive/tabletop qualification. Select when its '
                                        'owned source or contract changes; preserve applicable receipts.',
 'd2_art_sound_interval_test.py': 'D2 source qualification: Three full source action repeat schedules in '
                                  'native Kahlua, exact package custody. Select when its owned source or '
                                  'contract changes; preserve applicable receipts.',
 'd2_callback_bindings_test.py': 'D2 source qualification: Installed native event lifecycles and exact '
                                 'eight-leaf source/package custody. Select when its owned source or '
                                 'contract changes; preserve applicable receipts.',
 'd2_claw_menu_test.py': 'D2 source qualification: Exercise the packaged ProjectArcade claw menu in '
                         'installed Kahlua. Select when its owned source or contract changes; preserve '
                         'applicable receipts.',
 'd2_claw_mp_client_test.py': 'D2 source qualification: Execute packaged ProjectArcade client payment and '
                              'claw Lua in installed Kahlua. Select when its owned source or contract '
                              'changes; preserve applicable receipts.',
 'd2_claw_mp_server_test.py': 'D2 source qualification: Execute packaged ProjectArcade server authority with '
                              'controlled Kahlua receivers. Select when its owned source or contract '
                              'changes; preserve applicable receipts.',
 'd2_lifestyle_coexistence_test.py': 'D2 source qualification: Actual imported global + original private '
                                     'source callbacks; physical/emitter hosts controlled, native '
                                     'Kahlua/Stats. Select when its owned source or contract changes; '
                                     'preserve applicable receipts.',
 'd2_lifestyle_dj_coexistence_test.py': 'D2 source qualification: Pinned Lifestyle DJ menu coexistence in '
                                        'native Kahlua with controlled actors. Select when its owned source '
                                        'or contract changes; preserve applicable receipts.',
 'd2_locale_compatibility_test.py': 'D2 source qualification: Current native locale loading/source callback '
                                    'and exact imported-generation custody. Select when its owned source or '
                                    'contract changes; preserve applicable receipts.',
 'd2_music_action_binding_test.py': 'D2 source qualification: Exact private Music caller -> pinned original '
                                    'dance -> action-owned fields. Select when its owned source or contract '
                                    'changes; preserve applicable receipts.',
 'd2_player_dj_action_test.py': 'D2 source qualification: Owned DJ action lifecycle in native Kahlua with '
                                'controlled game objects. Select when its owned source or contract changes; '
                                'preserve applicable receipts.',
 'd2_player_dj_menu_test.py': 'D2 source qualification: SAO-owned DJ player menu against a controlled native '
                              'Kahlua context. Select when its owned source or contract changes; preserve '
                              'applicable receipts.',
 'd2_source_callers_test.py': 'D2 source qualification: Actual owned vault/registry caller qualification; '
                              'native Kahlua/Stats, controlled physical host. Select when its owned source '
                              'or contract changes; preserve applicable receipts.',
 'd2_source_invention_test.py': 'D2 source qualification: Three exact source bindings: actual native '
                                'Lua/visual/moddata and original callers. Select when its owned source or '
                                'contract changes; preserve applicable receipts.',
 'd2_source_namespace_lifetimes_test.py': 'D2 source qualification: Exact imported call locals and lazy '
                                          'provider lifetimes, native compilation/event. Select when its '
                                          'owned source or contract changes; preserve applicable receipts.',
 'd2_source_package_test.py': 'D2 source qualification: Owned package import/custody controls. No game '
                              'runtime or rendering claim. Select when its owned source or contract changes; '
                              'preserve applicable receipts.',
 'd2_source_sandbox_ui_test.py': 'D2 source qualification: SAO source sandbox grouping and dual-mod screen '
                                 'controls in native Kahlua. Select when its owned source or contract '
                                 'changes; preserve applicable receipts.',
 'd2_source_state_lifetimes_test.py': 'D2 source qualification: Exact source state lifetimes on native '
                                      'Event/light/moddata/WornItems receivers. Select when its owned source '
                                      'or contract changes; preserve applicable receipts.',
 'd2_source_utility_test.py': 'D2 source qualification: Two exact packaged source leaves: native Event, '
                              'fluid receiver and refusal text. Select when its owned source or contract '
                              'changes; preserve applicable receipts.',
 'dormant_civil_rest_test.py': 'C120/D1/D2 contract qualification: Run actual History and Dormant rest '
                               'across native and catch-up civil time. Select when its owned source or '
                               'contract changes; preserve applicable receipts.',
 'external_adult_chronology_test.py': 'C120/D1/D2 contract qualification: Installed Kahlua proof of '
                                      'SAO-authored chronology for external adults. Select when its owned '
                                      'source or contract changes; preserve applicable receipts.',
 'generated_birth_admission_test.py': 'C120/D1/D2 contract qualification: Run the real Identity and '
                                      'Admissions producer against historical birth boundaries. Select when '
                                      'its owned source or contract changes; preserve applicable receipts.',
 'player_character_identity_test.py': 'C120/D1/D2 contract qualification: Exercise saved player character '
                                      'keys in the production Standing module. Select when its owned source '
                                      'or contract changes; preserve applicable receipts.',
 'player_creator_layout_test.py': 'C120/D1/D2 contract qualification: Installed Kahlua layout and input '
                                  'exercise for the owned creator panel. Select when its owned source or '
                                  'contract changes; preserve applicable receipts.',
 'player_creator_test.py': "C120/D1/D2 contract qualification: Exact Kahlua checks for SAO's owned creation "
                           'draft and native apply edge. Select when its owned source or contract changes; '
                           'preserve applicable receipts.',
 'player_creator_weekone_test.py': 'C120/D1/D2 contract qualification: Cross-repository Kahlua exercise of '
                                   "P005 and SAO's applied creator. Select when its owned source or contract "
                                   'changes; preserve applicable receipts.',
 'player_objectives_test.py': 'C120/D1/D2 contract qualification: Exercise the native player request against '
                              'real social-process Lua owners. Select when its owned source or contract '
                              'changes; preserve applicable receipts.',
 'scanner_inventory_test.py': 'C120/D1/D2 contract qualification: Focused source '
                              'inventory/lexical/provenance guards; no game or broad gate. Select when its '
                              'owned source or contract changes; preserve applicable receipts.',
 'source_namespace_contracts_test.py': 'C120/D1/D2 contract qualification: Exact publisher policy controls; '
                                       'this test neither mutates source nor launches a game. Select when '
                                       'its owned source or contract changes; preserve applicable receipts.',
 'viewpoint_bridge_test.py': "C120/D1/D2 contract qualification: Exercise SAO's represented-body menu bridge "
                             "through Viewpoint's own collector. Select when its owned source or contract "
                             'changes; preserve applicable receipts.',
 'viewpoint_bundle_test.py': 'C120/D1/D2 contract qualification: Offline Viewpoint bundle and activation '
                             'qualification; never starts the game. Select when its owned source or contract '
                             'changes; preserve applicable receipts.',
 'viewpoint_frame_telemetry_test.py': 'C120/D1/D2 contract qualification: Qualify pinned Viewpoint render '
                                      'telemetry and strict native-feed acceptance. Select when its owned '
                                      'source or contract changes; preserve applicable receipts.',
 'viewpoint_mouse_test.py': 'C120/D1/D2 contract qualification: Exercise Viewpoint mouse readiness and '
                            'coordinate fallback under installed Kahlua. Select when its owned source or '
                            'contract changes; preserve applicable receipts.',
 'viewpoint_options_test.py': 'C120/D1/D2 contract qualification: Controlled SAO-owned Viewpoint options '
                              'registration under installed Kahlua. Select when its owned source or contract '
                              'changes; preserve applicable receipts.',
 'viewpoint_shell_visibility_test.py': 'C120/D1/D2 contract qualification: Exercise the pinned Viewpoint '
                                       "capture method with SAO's visibility advice. Select when its owned "
                                       'source or contract changes; preserve applicable receipts.',
 'weekone_active_program_test.py': 'C120/D1/D2 contract qualification: Installed BWO Active.Main through the '
                                   'SAO Week One person adapter. Select when its owned source or contract '
                                   'changes; preserve applicable receipts.',
 'weekone_chat_continuity_test.py': 'C120/D1/D2 contract qualification: Week One source chat enters one '
                                    'heard person before source actuation. Select when its owned source or '
                                    'contract changes; preserve applicable receipts.',
 'weekone_common_speech_test.py': 'C120/D1/D2 contract qualification: Exact Week One body and native speech '
                                  'through the common person surface. Select when its owned source or '
                                  'contract changes; preserve applicable receipts.',
 'weekone_companion_program_test.py': 'C120/D1/D2 contract qualification: Installed Bandits Companion '
                                      'callbacks under Week One person authority. Select when its owned '
                                      'source or contract changes; preserve applicable receipts.',
 'weekone_continuity_native_test.py': 'C120/D1/D2 contract qualification: Installed-engine Week One visual '
                                      'transfer and proxy perception proof. Select when its owned source or '
                                      'contract changes; preserve applicable receipts.',
 'weekone_continuity_test.py': 'C120/D1/D2 contract qualification: Run the Week One identity and retirement '
                               'contract on installed Kahlua. Select when its owned source or contract '
                               'changes; preserve applicable receipts.',
 'weekone_evening_parity_test.py': 'C120/D1/D2 contract qualification: Exercise the loaded Week One '
                                   'street-leg/home choice in installed Kahlua. Select when its owned source '
                                   'or contract changes; preserve applicable receipts.',
 'weekone_explosive_action_test.py': 'C120/D1/D2 contract qualification: Check the bounded SAO Week One '
                                     'explosive action on installed Kahlua. Select when its owned source or '
                                     'contract changes; preserve applicable receipts.',
 'weekone_fallback_consumer_test.py': 'C120/D1/D2 contract qualification: Exercise the actual SAO Week One '
                                      'plan through the selected BWO consumer. Select when its owned source '
                                      'or contract changes; preserve applicable receipts.',
 'weekone_interperson_combat_test.py': 'C120/D1/D2 contract qualification: Installed Kahlua proof of SAO '
                                       'owned interperson conflict for Week One proxies. Select when its '
                                       'owned source or contract changes; preserve applicable receipts.',
 'weekone_listener_cognition_test.py': 'C120/D1/D2 contract qualification: Exact private Week One hearing '
                                       'into the SAO cognition models on Kahlua. Select when its owned '
                                       'source or contract changes; preserve applicable receipts.',
 'weekone_material_test.py': 'C120/D1/D2 contract qualification: Installed-engine Week One gear transfer and '
                             'selected Bandits source proof. Select when its owned source or contract '
                             'changes; preserve applicable receipts.',
 'weekone_native_signal_test.py': 'C120/D1/D2 contract qualification: Native Week One shout/horn state and '
                                  'sound-only person contact. Select when its owned source or contract '
                                  'changes; preserve applicable receipts.',
 'weekone_night_order_test.py': 'C120/D1/D2 contract qualification: Execute the loaded IDLE decision tail, '
                                'native night hold, and full roam. Select when its owned source or contract '
                                'changes; preserve applicable receipts.',
 'weekone_nuke_owner_test.py': 'C120/D1/D2 contract qualification: Qualify a single persisted strike owner '
                               'in the shipped SAO Nuke module. Select when its owned source or contract '
                               'changes; preserve applicable receipts.',
 'weekone_owned_impact_test.py': "C120/D1/D2 contract qualification: Bounded Kahlua proof of SAO's saved "
                                 'Week One physical impact input. Select when its owned source or contract '
                                 'changes; preserve applicable receipts.',
 'weekone_performance_hearing_test.py': 'C120/D1/D2 contract qualification: Installed Week One performance '
                                        'sound custody and private SAO hearing proof. Select when its owned '
                                        'source or contract changes; preserve applicable receipts.',
 'weekone_private_hearing_test.py': 'C120/D1/D2 contract qualification: Installed-engine Week One scanner '
                                    'hearing with source inverses. Select when its owned source or contract '
                                    'changes; preserve applicable receipts.',
 'weekone_private_signal_test.py': 'C120/D1/D2 contract qualification: Installed Kahlua proof for native '
                                   'Week One sound into private Perception. Select when its owned source or '
                                   'contract changes; preserve applicable receipts.',
 'weekone_private_store_java_test.py': 'C120/D1/D2 contract qualification: Compile the Week One private '
                                       'store against the installed game and test save IO with stubs. Select '
                                       'when its owned source or contract changes; preserve applicable '
                                       'receipts.',
 'weekone_program_ownership_test.py': 'C120/D1/D2 contract qualification: Exact installed Week One stage '
                                      'ownership under the SAO person record. Select when its owned source '
                                      'or contract changes; preserve applicable receipts.',
 'weekone_repeated_callout_test.py': 'C120/D1/D2 contract qualification: Installed Callout occurrence proof '
                                     'with two compiled native inverses. Select when its owned source or '
                                     'contract changes; preserve applicable receipts.',
 'weekone_retirement_handoff_test.py': 'C120/D1/D2 contract qualification: Exact Week One chat handoff into '
                                       'the ordinary SAO person and controller. Select when its owned source '
                                       'or contract changes; preserve applicable receipts.',
 'weekone_sandbox_controls_test.py': 'C120/D1/D2 contract qualification: Exact Week One options, D2 reseal '
                                     'composition, native registry and UI. Select when its owned source or '
                                     'contract changes; preserve applicable receipts.',
 'weekone_scan_budget_test.py': 'C120/D1/D2 contract qualification: Bounded Week One cache and person-row '
                                'scans on installed Kahlua. Select when its owned source or contract '
                                'changes; preserve applicable receipts.',
 'weekone_scenario_owner_test.py': 'C120/D1/D2 contract qualification: P008 selected-character provenance '
                                   'survives a Week One source retirement. Select when its owned source or '
                                   'contract changes; preserve applicable receipts.',
 'weekone_shahid_event_test.py': 'C120/D1/D2 contract qualification: Installed-Kahlua Week One hit evidence '
                                 'without source-directed explosion. Select when its owned source or '
                                 'contract changes; preserve applicable receipts.',
 'weekone_source_inquiry_test.py': 'C120/D1/D2 contract qualification: Exercise Week One inquiry dispatch '
                                   'and read-only native follow-up in Kahlua. Select when its owned source '
                                   'or contract changes; preserve applicable receipts.',
 'weekone_source_proxy_hearing_test.py': 'C120/D1/D2 contract qualification: Actual Week One source callback '
                                         'into private hearing, without game launch. Select when its owned '
                                         'source or contract changes; preserve applicable receipts.',
 'weekone_source_spawn_test.py': 'C120/D1/D2 contract qualification: Exercise selected Week One source entry '
                                 'without inventing birth or Standing. Select when its owned source or '
                                 'contract changes; preserve applicable receipts.',
 'weekone_target_combat_test.py': 'C120/D1/D2 contract qualification: Installed Kahlua checks for Week One '
                                  'player-specific physical combat. Select when its owned source or contract '
                                  'changes; preserve applicable receipts.',
 'weekone_target_combat_wiring_test.py': 'C120/D1/D2 contract qualification: Exercise the person decision to '
                                         'exact player attack task handoff. Select when its owned source or '
                                         'contract changes; preserve applicable receipts.',
 'world_lab_capture_diagnostics_test.py': 'C120/D1/D2 contract qualification: Native Java capture '
                                          'accounting/timing proof, without launching a game. Select when '
                                          'its owned source or contract changes; preserve applicable '
                                          'receipts.',
 'world_lab_mod_loader13_test.py': 'C120/D1/D2 contract qualification: Source-only installed-metadata and '
                                   'real Instrumentation loader qualification. Select when its owned source '
                                   'or contract changes; preserve applicable receipts.',
 'world_lab_mousecat_readiness_test.py': 'C120/D1/D2 contract qualification: Focused production readiness '
                                         'races, source custody controls and optional read-only UIA '
                                         'evidence. Select when its owned source or contract changes; '
                                         'preserve applicable receipts.',
 'world_lab_native_capture04_test.py': 'C120/D1/D2 contract qualification: Qualify native-play capture '
                                       'methods with synthetic pixels, no game or encoder. Select when its '
                                       'owned source or contract changes; preserve applicable receipts.',
 'world_lab_native_capture_context13_test.py': 'C120/D1/D2 contract qualification: Native capture-context '
                                               'and terminal receipt controls; no game or encoder runs. '
                                               'Select when its owned source or contract changes; preserve '
                                               'applicable receipts.',
 'world_lab_native_communication12_test.py': 'C120/D1/D2 contract qualification: Source-qualified speech '
                                             'boundary checks. All bodies, inputs and pixels are synthetic. '
                                             'Select when its owned source or contract changes; preserve '
                                             'applicable receipts.',
 'world_lab_native_interaction_thread13_test.py': 'C120/D1/D2 contract qualification: Qualify the production '
                                                  'Lua ownership guard against installed Kahlua. Select when '
                                                  'its owned source or contract changes; preserve applicable '
                                                  'receipts.',
 'world_lab_native_menu21_test.py': 'C120/D1/D2 contract qualification: Compile real capture sources and '
                                    'exercise menu/body epochs under controlled stubs. Select when its owned '
                                    'source or contract changes; preserve applicable receipts.',
 'world_lab_native_play04_test.py': 'C120/D1/D2 contract qualification: Focused native-menu/participant '
                                    'controls. No native process is executed. Select when its owned source '
                                    'or contract changes; preserve applicable receipts.',
 'world_lab_native_start_feed04_test.py': 'C120/D1/D2 contract qualification: Consumer controls for passive '
                                          'start records; all body fixtures are synthetic. Select when its '
                                          'owned source or contract changes; preserve applicable receipts.',
 'world_lab_objective_trials12_test.py': 'C120/D1/D2 contract qualification: Objective-cycle controls. '
                                         'Fixture producer/media/reviews are synthetic. Select when its '
                                         'owned source or contract changes; preserve applicable receipts.',
 'world_lab_participant_geometry_test.py': 'C120/D1/D2 contract qualification: Execute participant video '
                                           'geometry epochs against the installed Java cohort. Select when '
                                           'its owned source or contract changes; preserve applicable '
                                           'receipts.',
 'world_lab_participant_java_test.py': 'C120/D1/D2 contract qualification: Compile native cohorts and '
                                       'exercise real participant code with labeled engine stubs. Select '
                                       'when its owned source or contract changes; preserve applicable '
                                       'receipts.',
 'world_lab_participant_lease_test.py': 'C120/D1/D2 contract qualification: Native input authority controls '
                                        'using actual broker and explicitly simulated bodies. Select when '
                                        'its owned source or contract changes; preserve applicable receipts.',
 'world_lab_participant_performance_test.py': 'C120/D1/D2 contract qualification: Receipt/source-event '
                                              'controls on the actual participant production methods. Select '
                                              'when its owned source or contract changes; preserve '
                                              'applicable receipts.',
 'world_lab_participant_pipeline_test.py': 'C120/D1/D2 contract qualification: Controlled participant bridge '
                                           'checks; these do not launch a native game. Select when its owned '
                                           'source or contract changes; preserve applicable receipts.',
 'world_lab_participant_publisher04_test.py': 'C120/D1/D2 contract qualification: Qualify the asynchronous '
                                              'native participant publisher without starting PZ. Select when '
                                              'its owned source or contract changes; preserve applicable '
                                              'receipts.',
 'world_lab_participant_run_test.py': 'C120/D1/D2 contract qualification: Read-only native identity/save and '
                                      'archive namespace checks using isolated fixtures. Select when its '
                                      'owned source or contract changes; preserve applicable receipts.',
 'world_lab_start_context04_test.py': 'C120/D1/D2 contract qualification: Focused passive native-start '
                                      'provenance controls using installed PZ APIs. Select when its owned '
                                      'source or contract changes; preserve applicable receipts.',
 'world_lab_video_archive_catalog_test.py': 'C120/D1/D2 contract qualification: Synthetic multi-stream '
                                            'projection controls; fragment bytes are not decoded video. '
                                            'Select when its owned source or contract changes; preserve '
                                            'applicable receipts.',
 'world_lab_video_archive_context_test.py': 'C120/D1/D2 contract qualification: Controlled menu/body stream '
                                            'sidecars through the real archive producer. Select when its '
                                            'owned source or contract changes; preserve applicable receipts.',
 'world_lab_video_archive_projection_test.py': 'C120/D1/D2 contract qualification: Bounded projection '
                                               'controls. Byte fixtures are labelled synthetic, not H264. '
                                               'Select when its owned source or contract changes; preserve '
                                               'applicable receipts.',
 'world_lab_video_camera_archive_test.py': 'C120/D1/D2 contract qualification: Encoded-byte camera '
                                           'provenance at the participant archive boundary. Select when its '
                                           'owned source or contract changes; preserve applicable receipts.'}

FAILS = re.compile(r"return 1\b|sys\.exit\(1\)|else 1\b")


def assertion_failure_path(src):
    """Recognize assertions reached from module execution or unittest.main.

    Defining an unused assertion helper does not execute it. Follow local
    calls from the entry point, and let the unittest owner discover actual
    TestCase test methods only when its main runner is called.
    """
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return False
    functions = {node.name: node for node in tree.body
                 if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    modules = {alias.asname or alias.name for node in tree.body
               if isinstance(node, ast.Import) for alias in node.names
               if alias.name == "unittest"}
    imported = {alias.asname or alias.name: alias.name for node in tree.body
                if isinstance(node, ast.ImportFrom) and node.module == "unittest"
                for alias in node.names}
    visited = set()

    def owner(node, name):
        return (isinstance(node, ast.Attribute) and node.attr == name
                and isinstance(node.value, ast.Name) and node.value.id in modules
                or isinstance(node, ast.Name) and imported.get(node.id) == name)

    def walk(node, test_method=False):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda)):
            return False
        if isinstance(node, ast.Assert):
            return not (isinstance(node.test, ast.Constant) and bool(node.test.value))
        if isinstance(node, ast.Raise):
            if isinstance(node.exc, ast.Call) and isinstance(node.exc.func, ast.Name) and node.exc.func.id == "SystemExit":
                if node.exc.args and isinstance(node.exc.args[0], ast.Constant):
                    return bool(node.exc.args[0].value)
            else:
                return True
        if isinstance(node, ast.If) and isinstance(node.test, ast.Constant):
            return any(walk(child, test_method) for child in
                       (node.body if node.test.value else node.orelse))
        if isinstance(node, ast.Call):
            if test_method and isinstance(node.func, ast.Attribute):
                import unittest
                if node.func.attr.startswith("assert") and hasattr(unittest.TestCase, node.func.attr):
                    return True
            if isinstance(node.func, ast.Name) and node.func.id in functions and node.func.id not in visited:
                visited.add(node.func.id)
                if any(walk(child) for child in functions[node.func.id].body):
                    return True
            if owner(node.func, "main"):
                for cls in tree.body:
                    if isinstance(cls, ast.ClassDef) and any(owner(base, "TestCase") for base in cls.bases):
                        for method in cls.body:
                            if isinstance(method, ast.FunctionDef) and method.name.startswith("test"):
                                if any(walk(child, True) for child in method.body):
                                    return True
        return any(walk(child, test_method) for child in ast.iter_child_nodes(node))

    return any(walk(node) for node in tree.body)


def imported_failure_path(src, seen=()):
    """Follow executed local calls to owned imported runners and child scripts."""
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return False
    functions = {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}
    imported = {alias.asname or alias.name: (node.module, alias.name)
                for node in tree.body if isinstance(node, ast.ImportFrom) and node.module
                for alias in node.names}
    visited = set()

    def helper(path):
        path = path.resolve()
        if not path.is_relative_to(TOOLS.resolve()) or not path.is_file() or path in seen:
            return False
        return can_fail(path.read_text(encoding="utf-8"), (*seen, path))

    def walk(node):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda)):
            return False
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                name = node.func.id
                if name in functions and name not in visited:
                    visited.add(name)
                    if any(walk(child) for child in functions[name].body):
                        return True
                if name in imported:
                    module, target = imported[name]
                    path = TOOLS.joinpath(*module.split(".")).with_suffix(".py")
                    if helper(path):
                        return True
            if isinstance(node.func, ast.Attribute) and node.func.attr == "run":
                for value in ast.walk(node):
                    if isinstance(value, ast.Constant) and isinstance(value.value, str) and value.value.startswith("tools/") and value.value.endswith(".py"):
                        if helper(ROOT / value.value):
                            return True
        return any(walk(child) for child in ast.iter_child_nodes(node))

    return any(walk(node) for node in tree.body)


def can_fail(src, seen=()):
    """Keep explicit verdict paths and recognize real Python check owners."""
    return bool(FAILS.search(src)) or assertion_failure_path(src) or imported_failure_path(src, seen)


def shell_invocations(source):
    """Read actual Python commands and their enclosing literal shell loops."""
    lines = source.replace("\\\n", " ").splitlines()
    loops = []
    commands = []
    for line_number, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        try:
            lexer = shlex.shlex(re.sub(r"\$\(\s*", "$( ", line), posix=True, punctuation_chars=";&|<>")
            lexer.whitespace_split = True
            lexer.commenters = "#"
            tokens = list(lexer)
        except ValueError:
            continue
        if not tokens:
            continue
        if tokens[0] == "done":
            if loops:
                loops.pop()
            continue
        if tokens[0] == "for" and len(tokens) > 3 and tokens[2] == "in":
            values = []
            for value in tokens[3:]:
                if value in (";", "do"):
                    break
                values.append(value)
            loops.append((tokens[1], values))
            continue
        py = next((i for i, token in enumerate(tokens) if token in ("$PY", "${PY}")), None)
        if py is None:
            continue
        args = []
        for token in tokens[py + 1:]:
            if token in (";", "then") or re.match(r"^[;&|<>]", token):
                break
            args.append(token)
        if not args:
            continue
        choices = itertools.product(*(values for _, values in loops)) if loops else [()]
        for selected in choices:
            expanded = list(args)
            for (variable, _), value in zip(loops, selected):
                expanded = [token.replace("${" + variable + "}", value).replace("$" + variable, value)
                            for token in expanded]
            if expanded[0].startswith("tools/") and expanded[0].endswith(".py"):
                commands.append({"path": expanded[0], "args": expanded[1:], "line": line_number})
            elif expanded[:2] == ["-m", "unittest"] and "-p" in expanded:
                pattern = expanded[expanded.index("-p") + 1]
                directory = expanded[expanded.index("-s") + 1] if "-s" in expanded else "tools"
                for path in (ROOT / directory).glob(pattern):
                    commands.append({"path": path.relative_to(ROOT).as_posix(),
                                     "args": [], "line": line_number, "unittestDiscovery": True})
    return commands


def invoked(source=None):
    """Names of checks that have an actual standing shell invocation."""
    source = CHECK.read_text(encoding="utf-8", errors="ignore") if source is None else source
    return {pathlib.PurePosixPath(row["path"]).stem for row in shell_invocations(source)}



def main():
    runs = invoked()
    mirrors = sorted(p.name for p in TOOLS.glob("*_test.py"))

    print("=" * 74)
    print(f"MIRRORS AND THE GATE - {len(mirrors)} mirrors")
    print("=" * 74)

    faults, gated, declared, reports = [], 0, 0, []
    for name in mirrors:
        stem = name[:-3]
        src = (TOOLS / name).read_text(encoding="utf-8", errors="ignore")
        failure_path = can_fail(src)
        if not failure_path:
            reports.append(name)
        if not failure_path and (stem in runs or name not in ONE_OFF and name not in SCOPED):
            faults.append(
                f"{name} has no path that can fail - it is a report, and "
                "a report in the gate is runtime bought for a guaranteed "
                "pass. Give it a verdict or retain it as a named scoped report.")
        if stem in runs:
            gated += 1
        elif name in ONE_OFF or name in SCOPED:
            declared += 1
        else:
            faults.append(
                f"{name} has no check.sh invocation or named qualification scope")

    print(f"  invoked by check.sh : {gated}")
    print(f"  declared scoped     : {declared}")
    print(f"  neither             : {len(mirrors) - gated - declared}")
    print(f"  cannot fail         : {len(reports)}  "
          f"{', '.join(reports) or 'none'}")

    for name, why in sorted({**ONE_OFF, **SCOPED}.items()):
        exists = (TOOLS / name).exists()
        kind = "one-off" if name in ONE_OFF else "scoped"
        print(f"  {'yes' if exists else 'NO '}  {kind}: {name} - {why}")
        if not why or not why.strip():
            faults.append(f"{name} has no qualification ownership reason")
        if not exists:
            faults.append(f"{name} is declared scoped/one-off and does not "
                          "exist - the exemption outlived its subject")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  32) gate reach: {gated} standing checks run; {declared} scoped/one-off tools retain named ownership")
    return 0


if __name__ == "__main__":
    sys.exit(main())
