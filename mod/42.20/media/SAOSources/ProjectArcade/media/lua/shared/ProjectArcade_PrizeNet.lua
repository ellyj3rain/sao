ProjectArcade_PrizeNet = ProjectArcade_PrizeNet or {}

ProjectArcade_PrizeNet.MODULE = "ProjectArcade"
ProjectArcade_PrizeNet.CMD_ROLL  = "RollPrize"
ProjectArcade_PrizeNet.CMD_RESULT = "RollPrizeResult"

ProjectArcade_PrizeNet.Pending = ProjectArcade_PrizeNet.Pending or {}

function ProjectArcade_PrizeNet.makeNonce()
    -- nonce suficientemente único para MP
    return tostring((getTimestampMs and getTimestampMs()) or 0) .. "-" .. tostring(ZombRand(1000000))
end
