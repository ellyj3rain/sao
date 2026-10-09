-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
require 'KA_Core'
require 'TimedActions/Fishing/TimedActions/ISPickupFishAction'
-- Mark just before the vanilla inventory insertion so its network packet includes our data.
local original = ISPickupFishAction.PickupFishUpdate
function ISPickupFishAction:PickupFishUpdate()
    if not isClient() and self.item and not self.fishInInv then
        local progress = isServer() and self.netAction:getProgress() or self:getJobDelta()
        if progress >= self.finishShowModel and self.item:getModData().fishing_FishSize then
            local md = self.item:getModData()
            if not md.KnoxAquariumFish then
                local now = KnoxAquarium.now()
                md.KnoxAquariumFish = {caught=now, expires=KnoxAquarium.deadline(now, self.character:getPerkLevel(Perks.Fishing))}
            end
        end
    end
    return original(self)
end
