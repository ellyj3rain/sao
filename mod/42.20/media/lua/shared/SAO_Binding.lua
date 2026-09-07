-- SAO_Binding.lua - the mod's key bindings ([C6]), in the engine's own
-- idiom (shared/keyBinding.lua: start with bind = {}, end with
-- table.insert). The options screen owns the key from here on; the
-- default is J because vanilla leaves it free, and anyone may move it.

local bind = {}
bind.value = "[SAO]"
table.insert(keyBinding, bind)
bind = {}
bind.value = "SAOInspect"
bind.key = Keyboard.KEY_J
table.insert(keyBinding, bind)
