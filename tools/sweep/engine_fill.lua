-- [C86] The game's own name pools, filled by the game's own
-- functions. This chunk loads directly after the game's
-- MainCreationMethods.lua, whose top level defines the table and
-- registers these fills on OnGameBoot - an event a headless county
-- never fires, so they are called here by name instead.
--
-- Unguarded on purpose. If the game ever renames one of these, this
-- chunk throws at load, the run reports itself, and the harness's own
-- check (the ENGINE line LuaRun prints after the pools) fails loudly -
-- rather than a county that names nobody sailing through as if it had.
-- That is the same argument as the sweep's module check: twice a whole
-- set of numbers meant nothing because something loaded was silently
-- absent, and an absence that is correct has to be declared while an
-- absence that is broken has to be loud.
BaseGameCharacterDetails.DoMaleForename()
BaseGameCharacterDetails.DoFemaleForename()
BaseGameCharacterDetails.DoSurname()