-- [B52] Does the ten-field pattern match what SAOSettlement actually
-- builds? A pattern that fails returns nil and the scout silently
-- stops finding bases - the exact failure shape [B42] and [B44] each
-- cost a batch, and one this could not be tested for in a running game
-- without shipping it first.
P = {}
local PAT = "^(%-?%d+):(%-?%d+):(%d+):(%d+):(%-?%d+):"
    .. "(%-?%d+):(%d+):(%d+):([01]):([%d%.%-]+)$"

function P.check(found)
    local bx, by, bw, bh, cx, cy, rooms, area, water, score =
        string.match(found, PAT)
    if not bx then return "NO MATCH" end
    return bx .. "|" .. by .. "|" .. bw .. "|" .. bh .. "|" .. cx .. "|"
        .. cy .. "|" .. rooms .. "|" .. area .. "|" .. water .. "|" .. score
end
