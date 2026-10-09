NMDeviceUiTime = NMDeviceUiTime or {}

function NMDeviceUiTime.nowMs()
    if getNowMs then
        local nowMs = tonumber(getNowMs())
        if nowMs then
            return nowMs
        end
    end
    if getTimestampMs then
        local timestampMs = tonumber(getTimestampMs())
        if timestampMs then
            return timestampMs
        end
    end
    if getTimeInMillis then
        local timeInMillis = tonumber(getTimeInMillis())
        if timeInMillis then
            return timeInMillis
        end
    end
    if getTimestamp then
        local timestamp = tonumber(getTimestamp())
        if timestamp then
            return timestamp * 1000
        end
    end
    return 0
end

return NMDeviceUiTime
