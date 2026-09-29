local HorseRegistries = {}

-- Keep Horse's item-tag vocabulary inside its ordinary shared module. The
-- engine loads every mod's media/registries.lua in one registry pass, so one
-- failure there would prevent unrelated mods from registering at all.
HorseRegistries.HorseAccessory = ItemTag.register("horsemod:horseaccessory")

return HorseRegistries
