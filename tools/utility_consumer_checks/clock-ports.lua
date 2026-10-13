-- Actual SAO_History is loaded unchanged. Only declared isolated time surfaces
-- are overridden here; literacyOf/ageOf/calendar/record/default provenance stay owned.
if not SAO.History or type(SAO.History.literacyOf)~="function"then error("actual History dependency absent")end
SAO.History.countyHours=function()return __utilityHours end
SAO.History.ticks=function()return math.floor(__utilityHours*SAO.History.TICKS_PER_HOUR)end
-- ticksFromHours is the original source conversion, no replacement.
