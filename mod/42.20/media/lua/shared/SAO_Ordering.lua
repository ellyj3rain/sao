-- Iterative ordering for complete candidate pools. Kahlua's recursive native
-- table.sort can exhaust its frame stack on an otherwise valid large pool.
SAO = SAO or {}
SAO.Ordering = SAO.Ordering or {}
local O = SAO.Ordering

function O.sort(rows, before)
    assert(type(rows) == "table" and type(before) == "function",
        "ordering-requires-array-and-comparator")
    local count, width, buffer = #rows, 1, {}
    while width < count do
        local start = 1
        while start <= count do
            local middle = math.min(start + width - 1, count)
            local last = math.min(start + width * 2 - 1, count)
            local left, right = start, middle + 1
            for index = start, last do
                if left <= middle and (right > last
                    or not before(rows[right], rows[left])) then
                    buffer[index] = rows[left]
                    left = left + 1
                else
                    buffer[index] = rows[right]
                    right = right + 1
                end
            end
            start = last + 1
        end
        for index = 1, count do rows[index] = buffer[index] end
        width = width * 2
    end
end

return O
