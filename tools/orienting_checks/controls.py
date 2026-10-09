def replace(text, old, new):
    assert text.count(old)==1, f'mutation match count {text.count(old)}: {old[:100]}'
    return text.replace(old,new,1)

def scoped(text, start, end, old, new):
    a=text.index(start); b=text.index(end,a+len(start))
    return text[:a]+replace(text[a:b],old,new)+text[b:]

def controls():
    engine='java/src/com/sao/engine/'
    simple=[
        ('cue-replay','SAOOrientation.java','if (state.active || cue.sequence() <= state.consumed) return false;',
         'if (false) return false;','duplicate_cue_refused'),
        ('movement-owner','SAOOrientation.java','boolean pivot = state.bodyTurn && !moving(shell);',
         'boolean pivot = state.bodyTurn;','moving_route_direction_preserved'),
        ('virtual-head','SAOSenses.java','angle += SAOOrientationAnimation.physicalHeadOffset(shell);',
         'angle += shell.getVariableFloat(SAOOrientationAnimation.HORIZONTAL, 0);','head_request_without_layer_cannot_change_gaze'),
        ('snapped-body','SAOOrientation.java','if (pivot) shell.faceLocationF(state.x, state.y);',
         'if (pivot) shell.setTargetAndCurrentDirection(dx,dy);','body_not_snapped_before_native_interpolation'),
        ('unbounded-cue','SAOOrientation.java','if (state.elapsed >= DURATION)',
         'if (false)','native_time_expires_orientation'),
        ('readiness-ignored','SAOOrientation.java','float delay = .10f + (1 - state.readiness) * .55f;',
         'float delay = .10f;','readiness_delays_response'),
        ('steadiness-ignored','SAOOrientation.java','? .3f + .7f * state.steadiness : 1;',
         '? 1 : 1;','steadiness_scales_native_turn'),
        ('timed-owner','SAOOrientation.java','if (!shell.getCharacterActions().isEmpty()) return "timed-action";',
         'if (false) return "timed-action";','action_yields'),
        ('combat-owner','SAOOrientation.java','if (shell.isAiming() || shell.isAttackStarted() || shell.isCharging || shell.isInitiateAttack()) return "combat";',
         'if (false) return "combat";','combat_yields'),
        ('cue-identity','SAOWorldSoundPulses.java','if (!(value instanceof WorldSound sound)) return;',
         'if (!(value instanceof WorldSound sound)) return; if (PULSES.containsKey(sound)) return;','pooled_reinit_new_occurrence'),
        ('unheard-cue','SAOOrientation.java','if (cue == null) return false;',
         'if (cue == null) cue = new SAOWorldSoundPulses.Pulse(cueId, Long.MAX_VALUE, (int)x, (int)y, 0);','unheard_other_body_refused'),
        ('deaf-access','SAOSenses.java','if (!awakeHuman(body) || body.hasTrait(CharacterTrait.DEAF)) return 0;',
         'if (!awakeHuman(body)) return 0;','native_hearing_modifiers'),
        ('hearing-modifier','SAOSenses.java','float distanceModifier = body.getHearDistanceModifier();',
         'float distanceModifier = 1;','native_hearing_modifiers'),
        ('scan-heading','SAOPerceptionScanner.java','float faceX = SAOSenses.gazeX(shell);\n        float faceY = SAOSenses.gazeY(shell);',
         'float faceX = shell.getForwardDirectionX();\n        float faceY = shell.getForwardDirectionY();','scan_actual_gaze'),
        ('person-heading','SAOPerceptionScanner.java','SAOSenses.gazeX(observer), SAOSenses.gazeY(observer),',
         'observer.getForwardDirectionX(), observer.getForwardDirectionY(),','person_recheck_actual_gaze'),
        ('intervening-wall','SAOPerceptionScanner.java','return clearPath(eye, target, true);',
         'return !eye.isSomethingTo(target);','person_occluded_by_native_wall'),
        ('impure-animator-read','SAOOrientationAnimation.java',
         'try { return (zombie.core.skinnedmodel.animation.AnimationPlayer)PLAYER.get(shell); }',
         'try { if (shell.hasAnimationPlayer()) return shell.getAnimationPlayer(); return (zombie.core.skinnedmodel.animation.AnimationPlayer)PLAYER.get(shell); }',
         'inspection_model_mismatch_no_mutation'),
    ]
    for name,file,old,new,verdict in simple:
        yield name,engine+file,lambda text,o=old,n=new:replace(text,o,n),verdict
    for name,start,end,verdict in [
        ('transfer-heading','    private static boolean visibleTransferPoint(', '    private static boolean withinSightCone(', 'transfer_witness_actual_gaze'),
        ('tile-heading','    private static boolean withinSightCone(', '    private static boolean withinSameFloorRange(', 'known_tile_actual_gaze')]:
        old='SAOSenses.gazeX(observer)\n                + dy * SAOSenses.gazeY(observer)'
        new='observer.getForwardDirectionX()\n                + dy * observer.getForwardDirectionY()'
        yield name,engine+'SAOPerceptionScanner.java',lambda text,a=start,b=end:scoped(text,a,b,old,new),verdict
    yield 'head-mask','mod/42.20/media/SAOOrienting/look.xml',lambda text:replace(text,
        '<boneName>Bip01_Head</boneName><weight>1</weight>', '<boneName>Bip01_Head</boneName><weight>0</weight>'),'idle_native_head_pose_changes'
    yield 'head-admission','mod/42.20/media/SAOOrienting/enter.xml',lambda text:replace(text,
        '<isTrue>saoOrientationActive</isTrue>', '<isFalse>saoOrientationActive</isFalse>'),'native_head_child_admitted'
    def remove_crossing(text):
        text=scoped(text,'        var current = shell.getCurrentState();','        if (!SAOOrientationAnimation.admittedRoot(',
            'if (shell.isClimbing() || current == ClimbOverFenceState.instance()',
            'if (false && (shell.isClimbing() || current == ClimbOverFenceState.instance()')
        return replace(text,'hasEventOccurred("EventClimbWindow")) return "crossing";',
            'hasEventOccurred("EventClimbWindow"))) return "crossing";')
    yield 'native-crossing',engine+'SAOOrientation.java',remove_crossing,'fence_yields'
