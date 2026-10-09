local env = _G.NMContextMenusEnv
setfenv(1, env)

function addRootDeviceOption(context, player, item, profile, state)
    local root = context:addOption(resolveDeviceMenuLabel(item, profile), player, nil)
    setOptionIcon(root, NMContextMenus.resolveMenuIconTexture(item, profile, state))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    addDeviceUiLifecycleOption(sub, player, item, profile, state)

    if canShowDeviceDisassemble(player, item, profile) then
        local disOption = sub:addOption(NMTranslations.ui("DismantleElectronicDevice", "Dismantle Electronic Device"), player, function(p, targetItem)
            if not targetItem then
                return
            end
            queueDeviceDisassembleAction(p, targetItem)
        end, item)
        setOptionIcon(disOption, resolveTextureByFullType("Base.ElectronicsScrap"))
    end

    local supportsBattery = NMDeviceProfiles.supportsBattery(profile)
    if supportsBattery and state and state.batteryPresent == true then
        local removeBatteryOption = sub:addOption(NMTranslations.ui("RemoveBattery", "Remove Battery"), player, function(p, targetItem)
            NMClientIntentDispatch.performIntent(p, targetItem, "eject_battery", {})
        end, item)
        setOptionIcon(removeBatteryOption, resolveTextureByFullType("Base.Battery"))
    end
end

function addContainerSubmenu(context, player, item, profile, state)
    local root = context:addOption(resolveDeviceMenuLabel(item, profile), player, nil)
    setOptionIcon(root, NMContextMenus.resolveMenuIconTexture(item, profile, state))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    addContainerCoverViewAction(sub, player, item, state)
    addCaseMediaActions(sub, player, item, profile, state)
end

function addCaseCoverOnlySubmenu(context, player, item, profile, state, displayName)
    local root = context:addOption(tostring(displayName or resolveDeviceMenuLabel(item, profile)), player, nil)
    setOptionIcon(root, NMContextMenus.resolveMenuIconTexture(item, profile, state))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    addContainerCoverViewAction(sub, player, item, state)
end

function addMenuByProfile(context, player, item, profile, state)
    if profile and profile.isMediaContainerOnly == true then
        addContainerSubmenu(context, player, item, profile, state)
        return
    end
    addRootDeviceOption(context, player, item, profile, state)
end

function addLooseMediaSubmenu(context, player, item)
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    local carrier = NMMediaContract.resolveMediaCarrier(fullType)
    local label = NMTranslations.ui("Cassette", "Cassette")
    if tostring(carrier or "") == tostring(NMMediaContract and NMMediaContract.VINYL_CARRIER or "") then
        label = NMTranslations.ui("Vinyl", "Vinyl")
    elseif tostring(carrier or "") == tostring(NMMediaContract and NMMediaContract.CD_CARRIER or "") then
        label = NMTranslations.ui("CD", "CD")
    end
    local root = context:addOption(label, player, nil)
    setOptionIcon(root, resolveTextureByFullType(item and item.getFullType and item:getFullType() or ""))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    addLooseMediaActions(sub, player, item)
end

