-- SAO_Log.lua - one door out to the console ([B47]).
--
-- Measured from the operator's own session log, 28 August:
--
--     Lua log lines total : 2353
--     ours                : 898  (38%)
--
-- Thirty-eight per cent of everything written by every mod in that
-- game was this one. And the shape of it is worse than the share:
--
--     234  [SAO][IDENTITY] created sao-N
--     234  [SAO][HISTORY]  sao-N contact ...
--     129  [SAO][POP]      the world gained a survivor in ...
--     120  [SAO][POP]      sao-N and sao-M kept company on the road
--
-- One line per person, in a county of two hundred and thirty-four.
-- Raise the population and it grows with it; there is no ceiling in
-- there anywhere.
--
-- [B44] is two days old and is exactly this cost paid in full: our
-- own flood pushed the mod-loading phase out of console.txt, and the
-- operator's report was that some of their mods did not load. The
-- answer to that question was in the file and we had written over it.
--
-- WHAT THIS IS NOT
--
-- Not a mute. Those lines are how the county is legible from outside,
-- and [B33]'s whole finding is that a world running differently with
-- nothing saying so is the worst state there is. Going quiet would
-- trade one invisible failure for another.
--
-- The distinction is between a REPORT and a SIGNAL. Two hundred and
-- thirty-four lines saying a person was created is a report: it is
-- true, and nobody reads it, and it costs the next reader the thing
-- they came for. One line saying two hundred and thirty-four people
-- were created is a signal - same fact, and the log still fits in the
-- file with everyone else's.
--
-- So: `line` for something that happened once, `tally` for something
-- that happens once per person. A tally is counted and flushed as a
-- single line per kind, and the count is the interesting part anyway.

SAO = SAO or {}
SAO.Log = SAO.Log or {}
local L = SAO.Log

L.pending = L.pending or {}     -- tag -> kind -> count
L.held = L.held or 0
L.BURST = 200                   -- held lines that force an early flush
L.EVERY = 600                   -- frames (~10s at 60fps) between flushes

-- Something that happened once. Straight out, as before.
function L.line(tag, msg)
    print("[SAO][" .. tostring(tag) .. "] " .. tostring(msg))
end

-- Something that happens once per person. Counted, not printed. The
-- kind is the sentence WITHOUT the name in it, because the name is
-- what makes two hundred lines out of one fact.
function L.tally(tag, kind)
    tag, kind = tostring(tag), tostring(kind)
    local bucket = L.pending[tag]
    if not bucket then
        bucket = {}
        L.pending[tag] = bucket
    end
    bucket[kind] = (bucket[kind] or 0) + 1
    L.held = L.held + 1
    -- A burst must not sit unreported waiting for a tick that may be
    -- a while off - seeding a county happens faster than the loop
    -- runs. Two hundred held is one summary line, immediately.
    if L.held >= L.BURST then L.flush() end
end

-- One line per kind, then the slate is clean. Returns how many lines
-- were spared, so a caller can decide the flush was worth doing.
function L.flush()
    local spared = 0
    for tag, bucket in pairs(L.pending) do
        for kind, n in pairs(bucket) do
            if n > 0 then
                L.line(tag, kind .. " x" .. n)
                spared = spared + (n - 1)
            end
        end
    end
    L.pending = {}
    L.held = 0
    return spared
end

L.line("LOG", "one door out: line() for the once, tally() for the each")
