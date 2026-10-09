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
import argparse
import hashlib
import itertools
import json
import os
import shlex
import pathlib
import re
import subprocess
import sys
import tempfile

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


# These standing scans measure repository maintenance across historical records
# or the whole tree. Their findings remain visible without becoming a product
# publication veto. The standing shell commands and their verdicts remain intact.
CI_MAINTENANCE = frozenset("""
scope_split_audit.py invariant_sweep.py engine_literals.py duplicate_blocks.py
pcall_audit.py undeclared_audit.py placeholder_test.py squared_scale_test.py
toplevel_function_test.py sort_bound_test.py tick_literal_test.py
reach_census_test.py reach_collision_test.py key_domain_test.py copy_ratified_test.py
receipts_test.py era_test.py version_replay.py version_stamp_test.py
development_graph_test.py session_state_test.py operator_speech_test.py
doc_currency_test.py source_integration_gate.py skips_cleanly_test.py
gate_reach_test.py scanner_boundary_controls_test.py vacuous_pass_test.py
catalogue_test.py claim_catalogue_test.py globals_census_test.py state_counts_test.py
""".split())
CI_PACKAGE = frozenset("""
scanner_inventory.py shipped_jar.py modinfo_check.py self_contained_test.py
mod_integration_inventory_test.py
""".split())
CI_FULL_SUITE_ONLY = frozenset("""
skips_cleanly_test.py vacuous_pass_test.py development_graph_test.py
catalogue_test.py claim_catalogue_test.py
""".split())
CI_RUNTIME_SCANS = frozenset("""
scope_split_audit.py invariant_sweep.py engine_literals.py duplicate_blocks.py
pcall_audit.py undeclared_audit.py placeholder_test.py
""".split())
CI_SHARED = frozenset("""
SAO_Bridge.lua SAO_Controller.lua SAO_Body.lua SAO_Integration.lua
SAO_Cognition.lua SAO_Persistence.lua SAOBridge.java SAOAgent.java
""".split())


def ci_standing(root):
    """Reuse primary shell invocations, including each declared flag variant."""
    source = (root / "tools/check.sh").read_text(encoding="utf-8")
    lines = source.replace("\\\n", " ").splitlines()
    rows, seen = [], set()
    # Redirection descriptors are shell syntax, not Python arguments. The
    # original census only needs command names; CI must preserve exact argv.
    commands = re.sub(r"(?<![\w'\"])\d+(?=[<>])", "", source)
    for row in shell_invocations(commands):
        line = lines[row["line"] - 1].lstrip()
        if not (line.startswith("if ") or re.search(r"=\$\(", line)):
            continue  # The shell's diagnostic retry is not another qualification.
        if row["path"] == "tools/scanner_inventory.py" and row["args"]:
            continue  # Inventory/filter helper roles are invoked with their inputs below.
        key = (row["path"], tuple(row["args"]))
        if key not in seen:
            seen.add(key)
            rows.append(row)
    return rows


def ci_imports(path, root):
    """Resolve repository imports without executing a module's top-level code."""
    tree = ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
    found = set()
    for node in ast.walk(tree):
        names = []
        if isinstance(node, ast.Import):
            names = [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            names = [node.module or ""]
            names += [(node.module + "." if node.module else "") + alias.name
                      for alias in node.names]
        for name in names:
            relative = pathlib.Path(*name.split("."))
            parents = [path.parent, root / "tools", root]
            if isinstance(node, ast.ImportFrom) and node.level:
                parent = path.parent
                for _ in range(node.level - 1):
                    parent = parent.parent
                parents.insert(0, parent)
            for parent in parents:
                for candidate in (parent / relative.with_suffix(".py"),
                                  parent / relative / "__init__.py"):
                    if candidate.is_file() and candidate.resolve().is_relative_to(root.resolve()):
                        found.add(candidate.relative_to(root).as_posix())
                        break
    return found, tree


def ci_footprint(name, root, cache):
    if name in cache:
        return cache[name]
    files, tokens, import_tokens, queue = set(), set(), set(), [name]
    while queue:
        item = queue.pop()
        if item in files or not (root / item).is_file():
            continue
        files.add(item)
        direct = ("direct", item)
        if direct not in cache:
            try:
                imports, tree = ci_imports(root / item, root)
            except (SyntaxError, UnicodeError):
                continue  # The selected command/changed-Python parse reports it.
            own_tokens, own_imports = set(), set()
            for node in ast.walk(tree):
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    own_tokens.update(re.findall(r"[\w.-]+\.(?:lua|java|json|txt|info|jar|py|sh)", node.value))
                    own_tokens.update(re.findall(r"\bSAO[A-Za-z_0-9]+\b", node.value))
                elif isinstance(node, ast.Import):
                    own_imports.update(alias.name.rsplit(".", 1)[-1] + ".py" for alias in node.names)
                elif isinstance(node, ast.ImportFrom) and node.module:
                    own_imports.add(node.module.rsplit(".", 1)[-1] + ".py")
            cache[direct] = (imports, own_tokens, own_imports)
        imports, own_tokens, own_imports = cache[direct]
        tokens.update(own_tokens)
        import_tokens.update(own_imports)
        queue.extend(imports - files)
    cache[name] = (files, tokens, import_tokens)
    return cache[name]


def ci_security_changed(changes):
    return any(path.endswith((".py", ".sh")) or path.startswith(".github/") or
               pathlib.PurePosixPath(path).name in {
                   "requirements.txt", "pyproject.toml", "poetry.lock", "uv.lock",
                   "Pipfile", "Pipfile.lock", "setup.cfg", "setup.py", "SECURITY.md"}
               for path in changes)


def ci_plan(changes, root=ROOT):
    """Select from the standing registry and its actual source/import inputs."""
    changes = sorted(set(path.replace("\\", "/") for path in changes))
    rows = ci_standing(root)
    required, advisory, cache = [], [], {}
    production = [p for p in changes if p.startswith(("mod/", "java/", "world/"))]
    python = [p for p in changes if p.endswith(".py") and (root / p).is_file()]
    shared = any(pathlib.PurePosixPath(p).name in CI_SHARED for p in production)
    package = bool(production) or any(
        p in {".gitattributes", "tools/scanner_inventory.py"} or
        p.startswith("data/source_") for p in changes)
    native_code = [p for p in production if p.endswith((".lua", ".java", ".json", ".txt", ".xml", ".properties", ".jar"))]
    matched = set()
    selected = []
    for row in rows:
        name = pathlib.PurePosixPath(row["path"]).name
        if name in CI_FULL_SUITE_ONLY:
            continue  # Full graph/catalogue/absence censuses remain manual/scheduled.
        if name == "lua_check.py":
            continue  # Its standing $files loop receives changed Lua below.
        files, tokens, import_tokens = ci_footprint(row["path"], root, cache)
        inputs = []
        for path in changes:
            basename = pathlib.PurePosixPath(path).name
            if path in files or (path.endswith(".py") and basename in import_tokens):
                inputs.append(path)
            elif not path.startswith("tools/") or not path.endswith((".py", ".sh")):
                if basename in tokens or pathlib.PurePosixPath(path).stem in tokens:
                    inputs.append(path)
            # A test mentioning check.sh for its historical registration is
            # not a changed product dependency. CI routing has its own controls.
        matched.update(p for p in inputs if p in native_code)
        reasons = []
        if inputs:
            reasons.append("source/import input: " + ", ".join(inputs))
        if production and name in CI_RUNTIME_SCANS:
            reasons.append("affected repository maintenance scan")
        if package and name in CI_PACKAGE:
            reasons.append("changed package/source-ownership contract")
        if shared and name not in CI_MAINTENANCE:
            reasons.append("shared native runtime interface")
        if reasons:
            selected.append({**row, "reasons": reasons})
    unknown = sorted(set(native_code) - matched)
    if unknown:
        # An unresolved production dependency expands product checks. It never
        # promotes the historical/whole-tree maintenance scans into a veto.
        selected_paths = {(r["path"], tuple(r["args"])) for r in selected}
        for row in rows:
            name = pathlib.PurePosixPath(row["path"]).name
            key = (row["path"], tuple(row["args"]))
            if name not in CI_MAINTENANCE and name != "lua_check.py" and key not in selected_paths:
                selected.append({**row, "reasons": ["unresolved native dependency: " + ", ".join(unknown)]})
    for row in selected:
        (advisory if pathlib.PurePosixPath(row["path"]).name in CI_MAINTENANCE else required).append(row)
    lua = [p for p in production if p.endswith(".lua") and (root / p).is_file()]
    controls = any(p in {"tools/check.sh", "tools/gate_reach_test.py"} or
                   p.startswith(".github/workflows/") for p in changes)
    if controls:
        required.insert(0, {"path": "tools/gate_reach_test.py", "args": ["--ci-controls"],
                            "reasons": ["changed executable CI routing contract"]})
    return {"schema": 1, "comparison": "full base...HEAD", "changedInputs": changes,
            "pythonParse": python, "changedLua": lua, "required": required,
            "advisory": advisory, "unresolvedNativeDependencies": unknown,
            "securityAnalysis": ci_security_changed(changes),
            "reuse": "none; each required run qualifies the complete PR diff"}


def ci_changed(base, root=ROOT):
    result = subprocess.run(["git", "diff", "--name-only", "-z", "--no-renames",
                             base + "...HEAD"], cwd=root, capture_output=True, check=True)
    return [name for name in result.stdout.decode("utf-8").split("\0") if name]


def ci_verdict(path, code, stdout):
    if code:
        return False
    name = pathlib.PurePosixPath(path).name
    if name in {"duplicate_blocks.py", "engine_literals.py"}:
        return all("none" in line or "SKIPPED" in line for line in stdout.splitlines())
    if name == "invariant_sweep.py":
        labels = ("MOVEMENT keys missing", "tick states not in MOVEMENT", "takePurpose written but never handled",
                  "verbs missing in SAOBridge", "voice events used but undefined", "TAKE states entered with no queued work",
                  "sensor scale disagreement", "states with no exit dispatcher", "claim fields read but never written",
                  "news kinds written but rendered by nobody", "designation literals nothing can ever be",
                  "wants Lua asks for that Java cannot answer")
        return not any(any(label in line for label in labels) and "none" not in line
                       for line in stdout.splitlines())
    if name == "protocol_arity.py":
        return all("none" in line or "SKIPPED" in line for line in stdout.splitlines() if line.startswith("15)"))
    return True


def ci_argv(row, output):
    args = list(row["args"])
    for index, arg in enumerate(args):
        if index and args[index - 1] in {"--output", "--out", "--output-dir"}:
            args[index] = str(output / ("proofs/" + str(row["id"])))
        elif "$" in arg:
            raise ValueError("unresolved standing command argument: " + arg)
    if row.get("unittestDiscovery"):
        path = pathlib.PurePosixPath(row["path"])
        return [sys.executable, "-m", "unittest", "discover", "-s", str(path.parent), "-p", path.name]
    return [sys.executable, row["path"], *args]


def ci_execute(plan, lane, output, root=ROOT):
    output.mkdir(parents=True, exist_ok=True)
    (output / "proofs").mkdir(exist_ok=True)
    results = []
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    def run(row, argv):
        result = subprocess.run(argv, cwd=root, env=env, text=True, errors="replace", capture_output=True)
        text = result.stdout + result.stderr
        log = output / (str(row["id"]) + ".log")
        log.write_text(text, encoding="utf-8")
        ok = ci_verdict(row["path"], result.returncode, text)
        results.append({**row, "argv": argv, "exitCode": result.returncode, "passed": ok,
                        "observedSkip": "SKIP" in text, "log": log.name,
                        "sha256": hashlib.sha256(text.encode()).hexdigest()})
        print(("PASS " if ok else "FAIL ") + row["path"] + " -> " + str(log), flush=True)
    if lane == "required":
        faults = []
        for path in plan["pythonParse"]:
            try:
                ci_imports(root / path, root)
            except (SyntaxError, UnicodeError) as error:
                faults.append(str(error))
        results.append({"path": "changed Python parse/import resolution", "passed": not faults,
                        "files": plan["pythonParse"], "faults": faults})
        if plan["changedLua"]:
            # The existing source inventory distinguishes executable Lua from
            # original evidence; location alone cannot waive structural checks.
            inventory = subprocess.run([sys.executable, "tools/scanner_inventory.py", "--filter"],
                                       cwd=root, env=env, input="\n".join(plan["changedLua"]),
                                       text=True, capture_output=True)
            (output / "lua-inventory.log").write_text(inventory.stderr, encoding="utf-8")
            results.append({"path": "changed Lua source qualification", "passed": inventory.returncode == 0,
                            "exitCode": inventory.returncode})
            if inventory.returncode == 0:
                for index, path in enumerate(inventory.stdout.splitlines()):
                    row = {"id": "lua-" + str(index), "path": "tools/lua_check.py", "args": [path],
                           "reasons": ["changed executable Lua"]}
                    run(row, ci_argv(row, output))
    for index, original in enumerate(plan[lane]):
        row = {**original, "id": lane + "-" + str(index)}
        run(row, ci_argv(row, output))
    report = {"lane": lane, "blocking": lane == "required", "passed": all(r["passed"] for r in results),
              "results": results, "plan": plan}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    summary = ["### " + lane + " affected checks", "", str(len(plan["changedInputs"])) +
               " changed inputs from the full PR diff; " + str(len(results)) + " results.", "",
               "| Check | Result |", "| --- | --- |"]
    summary += ["| " + r["path"] + " | " + ("failed" if not r["passed"] else
                "skipped native input reported" if r.get("observedSkip") else "passed") + " |" for r in results]
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write("\n".join(summary) + "\n")
    return 0 if report["passed"] else 1


def ci_controls():
    """Focused executable controls for the routing contract, without game input."""
    with tempfile.TemporaryDirectory(prefix="sao-ci-control-") as folder:
        root = pathlib.Path(folder)
        def write(name, text):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        write("tools/check.sh", 'if ! "$PY" tools/product_test.py --mode contract; then\nfi\n'
              'dups=$("$PY" tools/duplicate_blocks.py 2>&1)\n')
        write("tools/helper.py", "VALUE = 1\n")
        write("tools/product_test.py", 'from helper import VALUE\nfrom pathlib import Path\n'
              'assert VALUE == 1\nassert Path("tools/check.sh").exists()\n'
              'assert Path("mod/runtime.lua").read_text() == "good"\n')
        write("tools/duplicate_blocks.py", 'print("unrelated repeated block")\n')
        write("mod/runtime.lua", "good")
        docs = ci_plan(["README.md"], root)
        assert not docs["required"] and not docs["advisory"] and not docs["securityAnalysis"]
        tool = ci_plan(["tools/helper.py"], root)
        assert [r["path"] for r in tool["required"]] == ["tools/product_test.py"]
        assert not tool["changedLua"] and tool["securityAnalysis"]
        routing = ci_plan(["tools/check.sh"], root)
        assert [(r["path"], r["args"]) for r in routing["required"]] == [
            ("tools/gate_reach_test.py", ["--ci-controls"])]
        (root / "tools/helper.py").unlink()
        removed = ci_plan(["tools/helper.py"], root)
        assert [r["path"] for r in removed["required"]] == ["tools/product_test.py"]
        write("tools/helper.py", "VALUE = 1\n")
        native = ci_plan(["mod/runtime.lua"], root)
        assert native["required"][0]["args"] == ["--mode", "contract"]
        assert native["advisory"][0]["path"] == "tools/duplicate_blocks.py"
        assert native["advisory"][0]["args"] == []
        unknown = ci_plan(["mod/new-interface.java"], root)
        assert unknown["unresolvedNativeDependencies"] and unknown["required"]
        assert all(pathlib.PurePosixPath(r["path"]).name not in CI_MAINTENANCE for r in unknown["required"])
        shared = ci_plan(["mod/SAO_Bridge.lua"], root)
        assert any("shared native runtime interface" in r["reasons"] for r in shared["required"])
        assert ci_security_changed([".github/workflows/codeql.yml"])
        # Execute the same selected commands/runner: a product fault blocks, an
        # unrelated maintenance finding is preserved in its own result lane.
        executable = {**tool, "changedLua": []}
        assert ci_execute(executable, "required", root / "pass", root) == 0
        maintenance = {**native, "changedLua": []}
        assert ci_execute(maintenance, "advisory", root / "advisory", root) == 1
        write("mod/runtime.lua", "bad")
        assert ci_execute(executable, "required", root / "fail", root) == 1
        # A later documentation commit does not erase an earlier failed input.
        def git(*args):
            return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True).stdout.strip()
        git("init", "-q")
        git("config", "user.email", "ci-control@example.invalid")
        git("config", "user.name", "CI routing control")
        git("add", "tools", "mod")
        git("commit", "-qm", "base")
        base = git("rev-parse", "HEAD")
        write("mod/runtime.lua", "earlier fault")
        git("add", "mod/runtime.lua")
        git("commit", "-qm", "earlier changed runtime")
        write("README.md", "later documentation")
        git("add", "README.md")
        git("commit", "-qm", "later documentation")
        assert ci_changed(base, root) == ["README.md", "mod/runtime.lua"]
    print("PASS CI controls: docs, tooling/imports, native/shared/unknown inputs, security, "
          "required failure, advisory finding, and full PR base comparison")
    return 0


def cli():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ci-controls", action="store_true")
    parser.add_argument("--ci-plan", action="store_true")
    parser.add_argument("--ci-run", choices=("required", "advisory"))
    parser.add_argument("--base")
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    if args.ci_controls:
        return ci_controls()
    if args.ci_plan or args.ci_run:
        if not args.base or not args.output:
            parser.error("CI routing requires --base and --output")
        plan = ci_plan(ci_changed(args.base))
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "plan.json").write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
                stream.write("security=" + str(plan["securityAnalysis"]).lower() + "\n")
        return ci_execute(plan, args.ci_run, args.output.resolve()) if args.ci_run else 0
    return main()


if __name__ == "__main__":
    sys.exit(cli())
