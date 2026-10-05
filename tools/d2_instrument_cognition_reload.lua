-- Re-execute actual production modules after installed serialization, preserving
-- the person-private record and owner ledger. This is a Lua module reload;
-- fresh native-world reconstruction belongs to the separate owner proof.
local s=records.a.cognition
local revision=s.models.ordinary.revision
local ok,reason=SAO.Cognition.instrumentOutcome('a',260)
assert(ok and reason=='duplicate' and s.models.ordinary.revision==revision,
 'D2_INSTRUMENT:module_reload_duplicate')
ok,reason=SAO.Cognition.instrumentOutcome('a',1)
assert(not ok and reason=='retired-native-receipt',
 'D2_INSTRUMENT:module_reload_evicted')
assert(SAO.Cognition.settings().enabled and s.nativeExperienceCursors.instrument==260,
 'D2_INSTRUMENT:module_reload_custody')
__result='PASS D2 instrument cognition module reload 3'
