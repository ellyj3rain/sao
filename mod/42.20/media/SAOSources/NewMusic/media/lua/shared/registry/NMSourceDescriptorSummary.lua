NMSourceDescriptorSummary = NMSourceDescriptorSummary or {}

function NMSourceDescriptorSummary.describeArgs(args, prefix)
    local readFn = NMInventoryHelpers and NMInventoryHelpers.readSourceDescriptorFromArgs or nil
    local descriptor = readFn and readFn(args, prefix or "mediaSource") or nil
    if type(descriptor) ~= "table" then
        return "none"
    end
    return string.format(
        "kind=%s itemId=%s itemUuid=%s vehicleId=%s partId=%s parentItemId=%s square=%s,%s,%s objectIndex=%s deadBodyIndex=%s",
        tostring(descriptor.kind or ""),
        tostring(descriptor.itemId or ""),
        tostring(descriptor.itemUuid or ""),
        tostring(descriptor.vehicleId or ""),
        tostring(descriptor.partId or ""),
        tostring(descriptor.parentItemId or ""),
        tostring(descriptor.squareX or ""),
        tostring(descriptor.squareY or ""),
        tostring(descriptor.squareZ or ""),
        tostring(descriptor.objectIndex or ""),
        tostring(descriptor.deadBodyIndex or "")
    )
end

return NMSourceDescriptorSummary
