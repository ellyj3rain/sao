if not ItemTweaker then ItemTweaker = {} end
if not TweakItemData then TweakItemData = {} end

function ItemTweaker.tweakItems()
    local item
    for itemName, props in pairs(TweakItemData) do
        item = ScriptManager.instance:getItem(itemName)
        if item then
            for prop, value in pairs(props) do
                item:DoParam(prop .. " = " .. value)
            end
        end
    end
end

function TweakItem(itemName, itemProperty, propertyValue)
    TweakItemData[itemName] = TweakItemData[itemName] or {}
    TweakItemData[itemName][itemProperty] = propertyValue
end

TweakItem("Base.SilverCoin", "Weight", "0.001")

Events.OnGameBoot.Add(ItemTweaker.tweakItems)
