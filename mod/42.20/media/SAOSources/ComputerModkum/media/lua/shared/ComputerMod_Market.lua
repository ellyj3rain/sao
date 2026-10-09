require "ComputerMod_Sandbox"
require "ComputerMod_Mail"

ComputerModMarket = ComputerModMarket or {}

ComputerModMarket.storeName = "ComputerModMarketDB"
ComputerModMarket.defaultShopRefreshHours = 24
ComputerModMarket.defaultJobRefreshHours = 24

function ComputerModMarket.trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

function ComputerModMarket.normalizeUsername(username)
    return string.lower(ComputerModMarket.trim(username))
end

function ComputerModMarket.isValidUsername(username)
    local normalized = ComputerModMarket.normalizeUsername(username)
    if normalized == "" then return false end
    if string.len(normalized) < 3 or string.len(normalized) > 64 then return false end
    if string.find(normalized, "[%c]") then return false end
    return true
end

function ComputerModMarket.getStore()
    local store = ModData.getOrCreate(ComputerModMarket.storeName)
    if type(store.accounts) ~= "table" then
        store.accounts = {}
    end
    return store
end

function ComputerModMarket.getWorldAgeHours()
    if getGameTime then
        local ok, gameTime = pcall(getGameTime)
        if ok and gameTime and gameTime.getWorldAgeHours then
            local okAge, age = pcall(function() return gameTime:getWorldAgeHours() end)
            if okAge and age then
                return tonumber(age) or 0
            end
        end
    end
    return 0
end

function ComputerModMarket.getRefreshHours(kind)
    local key = kind == "jobs" and "MarketJobRefreshHours" or "MarketShopRefreshHours"
    local fallback = kind == "jobs" and ComputerModMarket.defaultJobRefreshHours or ComputerModMarket.defaultShopRefreshHours
    if ComputerModSandbox and ComputerModSandbox.getNumber then
        local value = ComputerModSandbox.getNumber(key, fallback)
        if value and value > 0 then return value end
    end
    return fallback
end

function ComputerModMarket.getCycleIndex(kind, store)
    store = store or ComputerModMarket.getStore()
    local prefix = kind == "jobs" and "job" or "shop"
    local startAge = tonumber(store[prefix .. "StartAge"] or 0) or 0
    local serial = tonumber(store[prefix .. "Serial"] or 0) or 0
    local elapsed = math.max(0, ComputerModMarket.getWorldAgeHours() - startAge)
    return serial * 100000 + math.floor(elapsed / ComputerModMarket.getRefreshHours(kind))
end

function ComputerModMarket.getHoursUntilNext(kind)
    local refresh = ComputerModMarket.getRefreshHours(kind)
    local store = ComputerModMarket.getStore()
    local prefix = kind == "jobs" and "job" or "shop"
    local startAge = tonumber(store[prefix .. "StartAge"] or 0) or 0
    local age = ComputerModMarket.getWorldAgeHours()
    local elapsed = math.max(0, age - startAge)
    local nextAt = startAge + (math.floor(elapsed / refresh) + 1) * refresh
    return math.max(0, nextAt - age)
end

function ComputerModMarket.hash(value)
    value = tostring(value or "")
    local total = 0
    for i = 1, string.len(value) do
        total = (total * 33 + string.byte(value, i)) % 2147483647
    end
    return total
end

ComputerModMarket.categories = {
    {id = "all", label = "All"},
    {id = "weapons", label = "Weapons"},
    {id = "medical", label = "Medical"},
    {id = "food", label = "Food"},
    {id = "tools", label = "Tools"},
    {id = "materials", label = "Materials"},
    {id = "electronics", label = "Electronics"},
    {id = "clothing", label = "Clothing"}
}

ComputerModMarket.shopPool = {
    {id = "hammer", category = "tools", label = "Hammer", fullTypes = {"Base.Hammer"}, icon = "Hammer", basePrice = 24, rarity = 2},
    {id = "saw", category = "tools", label = "Saw", fullTypes = {"Base.Saw"}, icon = "Saw", basePrice = 28, rarity = 3},
    {id = "screwdriver", category = "tools", label = "Screwdriver", fullTypes = {"Base.Screwdriver"}, icon = "Screwdriver", basePrice = 18, rarity = 2},
    {id = "wrench", category = "tools", label = "Wrench", fullTypes = {"Base.Wrench"}, icon = "Wrench", basePrice = 22, rarity = 3},
    {id = "crowbar", category = "tools", label = "Crowbar", fullTypes = {"Base.Crowbar"}, icon = "Crowbar", basePrice = 54, rarity = 4},
    {id = "handaxe", category = "tools", label = "Hand Axe", fullTypes = {"Base.HandAxe"}, icon = "HandAxe", basePrice = 72, rarity = 5},
    {id = "gardenfork", category = "tools", label = "Garden Fork", fullTypes = {"Base.GardenFork"}, icon = "GardenFork", basePrice = 60, rarity = 4},
    {id = "shovel", category = "tools", label = "Shovel", fullTypes = {"Base.Shovel", "Base.Shovel2"}, icon = "Shovel", basePrice = 42, rarity = 3},
    {id = "trowel", category = "tools", label = "Garden Trowel", fullTypes = {"Base.HandShovel", "Base.GardenTrowel"}, icon = "HandShovel", basePrice = 20, rarity = 2},
    {id = "scissors", category = "tools", label = "Scissors", fullTypes = {"Base.Scissors"}, icon = "Scissors", basePrice = 14, rarity = 1},
    {id = "axe", category = "weapons", label = "Axe", fullTypes = {"Base.Axe"}, icon = "Axe", basePrice = 120, rarity = 6},
    {id = "baseballbat", category = "weapons", label = "Baseball Bat", fullTypes = {"Base.BaseballBat"}, icon = "BaseballBat", basePrice = 58, rarity = 4},
    {id = "kitchenknife", category = "weapons", label = "Kitchen Knife", fullTypes = {"Base.KitchenKnife"}, icon = "KitchenKnife", basePrice = 34, rarity = 3},
    {id = "huntingknife", category = "weapons", label = "Hunting Knife", fullTypes = {"Base.HuntingKnife"}, icon = "HuntingKnife", basePrice = 72, rarity = 5},
    {id = "machete", category = "weapons", label = "Machete", fullTypes = {"Base.Machete"}, icon = "Machete", basePrice = 150, rarity = 7},
    {id = "pipewrench", category = "weapons", label = "Pipe Wrench", fullTypes = {"Base.PipeWrench"}, icon = "PipeWrench", basePrice = 44, rarity = 3},
    {id = "nightstick", category = "weapons", label = "Nightstick", fullTypes = {"Base.Nightstick"}, icon = "Nightstick", basePrice = 88, rarity = 5},
    {id = "leadpipe", category = "weapons", label = "Lead Pipe", fullTypes = {"Base.LeadPipe"}, icon = "LeadPipe", basePrice = 42, rarity = 3},
    {id = "metalbar", category = "weapons", label = "Metal Bar", fullTypes = {"Base.MetalBar"}, icon = "MetalBar", basePrice = 46, rarity = 3},
    {id = "meatcleaver", category = "weapons", label = "Meat Cleaver", fullTypes = {"Base.MeatCleaver"}, icon = "MeatCleaver", basePrice = 48, rarity = 4},
    {id = "bandage", category = "medical", label = "Bandage", fullTypes = {"Base.Bandage", "Base.RippedSheets"}, icon = "Bandage", basePrice = 10, rarity = 1},
    {id = "alcoholwipes", category = "medical", label = "Alcohol Wipes", fullTypes = {"Base.AlcoholWipes"}, icon = "AlcoholWipes", basePrice = 16, rarity = 2},
    {id = "disinfectant", category = "medical", label = "Disinfectant", fullTypes = {"Base.Disinfectant"}, icon = "Disinfectant", basePrice = 38, rarity = 4},
    {id = "painkillers", category = "medical", label = "Painkillers", fullTypes = {"Base.Pills"}, icon = "Pills", basePrice = 32, rarity = 4},
    {id = "vitamins", category = "medical", label = "Vitamins", fullTypes = {"Base.PillsVitamins"}, icon = "PillsVitamins", basePrice = 26, rarity = 3},
    {id = "firstaid", category = "medical", label = "First Aid Kit", fullTypes = {"Base.FirstAidKit"}, icon = "FirstAidKit", basePrice = 92, rarity = 6},
    {id = "antibiotics", category = "medical", label = "Antibiotics", fullTypes = {"Base.PillsAntiDep", "Base.Antibiotics"}, icon = "PillsAntiDep", basePrice = 72, rarity = 6},
    {id = "beta", category = "medical", label = "Beta Blockers", fullTypes = {"Base.PillsBeta"}, icon = "PillsBeta", basePrice = 42, rarity = 4},
    {id = "sleepingtablets", category = "medical", label = "Sleeping Tablets", fullTypes = {"Base.PillsSleepingTablets"}, icon = "PillsSleepingTablets", basePrice = 38, rarity = 4},
    {id = "suture", category = "medical", label = "Suture Needle", fullTypes = {"Base.SutureNeedle"}, icon = "SutureNeedle", basePrice = 34, rarity = 4},
    {id = "tweezers", category = "medical", label = "Tweezers", fullTypes = {"Base.Tweezers"}, icon = "Tweezers", basePrice = 18, rarity = 2},
    {id = "cottonballs", category = "medical", label = "Cotton Balls", fullTypes = {"Base.CottonBalls"}, icon = "CottonBalls", basePrice = 12, rarity = 1},
    {id = "chips", category = "food", label = "Chips", fullTypes = {"Base.Crisps"}, icon = "Crisps", basePrice = 8, rarity = 1},
    {id = "chocolate", category = "food", label = "Chocolate", fullTypes = {"Base.Chocolate"}, icon = "Chocolate", basePrice = 10, rarity = 1},
    {id = "water", category = "food", label = "Water Bottle", fullTypes = {"Base.WaterBottleFull", "Base.WaterBottle"}, icon = "WaterBottleFull", basePrice = 12, rarity = 1},
    {id = "cannedsoup", category = "food", label = "Canned Soup", fullTypes = {"Base.CannedSoup"}, icon = "CannedSoup", basePrice = 18, rarity = 2},
    {id = "tuna", category = "food", label = "Canned Tuna", fullTypes = {"Base.TunaTin", "Base.CannedTuna"}, icon = "TunaTin", basePrice = 18, rarity = 2},
    {id = "cornedbeef", category = "food", label = "Corned Beef", fullTypes = {"Base.CannedCornedBeef"}, icon = "CannedCornedBeef", basePrice = 22, rarity = 3},
    {id = "beans", category = "food", label = "Canned Beans", fullTypes = {"Base.CannedBakedBeans", "Base.BakedBeans"}, icon = "CannedBakedBeans", basePrice = 18, rarity = 2},
    {id = "tomato", category = "food", label = "Canned Tomato", fullTypes = {"Base.CannedTomato", "Base.TinnedBeans"}, icon = "CannedTomato", basePrice = 16, rarity = 2},
    {id = "oats", category = "food", label = "Oats", fullTypes = {"Base.OatsRaw", "Base.Oats"}, icon = "OatsRaw", basePrice = 20, rarity = 2},
    {id = "cereal", category = "food", label = "Cereal", fullTypes = {"Base.Cereal"}, icon = "Cereal", basePrice = 24, rarity = 3},
    {id = "peanutbutter", category = "food", label = "Peanut Butter", fullTypes = {"Base.PeanutButter"}, icon = "PeanutButter", basePrice = 28, rarity = 3},
    {id = "jerky", category = "food", label = "Beef Jerky", fullTypes = {"Base.BeefJerky"}, icon = "BeefJerky", basePrice = 24, rarity = 3},
    {id = "nails", category = "materials", label = "Box of Nails", fullTypes = {"Base.NailsBox", "Base.Nails"}, icon = "NailsBox", basePrice = 18, rarity = 2},
    {id = "screws", category = "materials", label = "Box of Screws", fullTypes = {"Base.ScrewsBox", "Base.Screws"}, icon = "ScrewsBox", basePrice = 20, rarity = 2},
    {id = "ducttape", category = "materials", label = "Duct Tape", fullTypes = {"Base.DuctTape"}, icon = "DuctTape", basePrice = 24, rarity = 3},
    {id = "glue", category = "materials", label = "Glue", fullTypes = {"Base.Glue"}, icon = "Glue", basePrice = 14, rarity = 2},
    {id = "woodglue", category = "materials", label = "Wood Glue", fullTypes = {"Base.Woodglue", "Base.WoodGlue"}, icon = "Woodglue", basePrice = 22, rarity = 3},
    {id = "twine", category = "materials", label = "Twine", fullTypes = {"Base.Twine"}, icon = "Twine", basePrice = 12, rarity = 1},
    {id = "rope", category = "materials", label = "Rope", fullTypes = {"Base.Rope"}, icon = "Rope", basePrice = 26, rarity = 3},
    {id = "wirematerial", category = "materials", label = "Wire", fullTypes = {"Base.Wire"}, icon = "Wire", basePrice = 16, rarity = 2},
    {id = "thread", category = "materials", label = "Thread", fullTypes = {"Base.Thread"}, icon = "Thread", basePrice = 10, rarity = 1},
    {id = "needle", category = "materials", label = "Needle", fullTypes = {"Base.Needle"}, icon = "Needle", basePrice = 12, rarity = 2},
    {id = "sheetrope", category = "materials", label = "Sheet Rope", fullTypes = {"Base.SheetRope"}, icon = "SheetRope", basePrice = 12, rarity = 1},
    {id = "plank", category = "materials", label = "Plank", fullTypes = {"Base.Plank"}, icon = "Plank", basePrice = 12, rarity = 1},
    {id = "battery", category = "electronics", label = "AA Battery", fullTypes = {"Base.Battery"}, icon = "Battery", basePrice = 7, rarity = 1},
    {id = "wire", category = "electronics", label = "Electric Wire", fullTypes = {"Base.ElectricWire"}, icon = "ElectricWire", basePrice = 28, rarity = 4},
    {id = "scrap", category = "electronics", label = "Electronics Scrap", fullTypes = {"Base.ElectronicsScrap"}, icon = "ElectronicsScrap", basePrice = 16, rarity = 2},
    {id = "bulb", category = "electronics", label = "Light Bulb", fullTypes = {"Base.LightBulb"}, icon = "LightBulb", basePrice = 13, rarity = 1},
    {id = "torch", category = "electronics", label = "Flashlight", fullTypes = {"Base.Torch", "Base.Flashlight"}, icon = "Torch", basePrice = 34, rarity = 4},
    {id = "walkietalkie", category = "electronics", label = "Walkie Talkie", fullTypes = {"Base.WalkieTalkie1", "Base.WalkieTalkie2"}, icon = "WalkieTalkie1", basePrice = 64, rarity = 5},
    {id = "radio", category = "electronics", label = "Radio Receiver", fullTypes = {"Base.RadioReceiver"}, icon = "RadioReceiver", basePrice = 56, rarity = 4},
    {id = "amplifier", category = "electronics", label = "Amplifier", fullTypes = {"Base.Amplifier"}, icon = "Amplifier", basePrice = 52, rarity = 4},
    {id = "motion", category = "electronics", label = "Motion Sensor", fullTypes = {"Base.MotionSensor"}, icon = "MotionSensor", basePrice = 72, rarity = 5},
    {id = "timer", category = "electronics", label = "Timer", fullTypes = {"Base.Timer"}, icon = "Timer", basePrice = 42, rarity = 4},
    {id = "remote", category = "electronics", label = "Remote Controller", fullTypes = {"Base.Remote"}, icon = "Remote", basePrice = 46, rarity = 4},
    {id = "cordlessphone", category = "electronics", label = "Cordless Phone", fullTypes = {"Base.CordlessPhone"}, icon = "CordlessPhone", basePrice = 30, rarity = 3},
    {id = "bag", category = "clothing", label = "School Bag", fullTypes = {"Base.Bag_Schoolbag"}, icon = "Bag_Schoolbag", basePrice = 42, rarity = 3},
    {id = "gloves", category = "clothing", label = "Leather Gloves", fullTypes = {"Base.Gloves_LeatherGloves", "Base.Gloves_Leather"}, icon = "Gloves_LeatherGloves", basePrice = 36, rarity = 4},
    {id = "jacket", category = "clothing", label = "Denim Shirt", fullTypes = {"Base.Shirt_Denim"}, icon = "Shirt_Denim", basePrice = 28, rarity = 2},
    {id = "poncho", category = "clothing", label = "Poncho", fullTypes = {"Base.PonchoYellowDOWN", "Base.PonchoGreenDOWN"}, icon = "PonchoYellowDOWN", basePrice = 46, rarity = 4},
    {id = "duffelbag", category = "clothing", label = "Duffel Bag", fullTypes = {"Base.Bag_DuffelBag"}, icon = "Bag_DuffelBag", basePrice = 70, rarity = 5},
    {id = "satchel", category = "clothing", label = "Satchel", fullTypes = {"Base.Bag_Satchel"}, icon = "Bag_Satchel", basePrice = 48, rarity = 4},
    {id = "raincoat", category = "clothing", label = "Raincoat", fullTypes = {"Base.Jacket_Ranger", "Base.JacketLong_Random"}, icon = "Jacket_Ranger", basePrice = 46, rarity = 4},
    {id = "boots", category = "clothing", label = "Work Boots", fullTypes = {"Base.Shoes_BlackBoots", "Base.Shoes_ArmyBoots"}, icon = "Shoes_BlackBoots", basePrice = 54, rarity = 4},
    {id = "hardhat", category = "clothing", label = "Hard Hat", fullTypes = {"Base.Hat_HardHat"}, icon = "Hat_HardHat", basePrice = 34, rarity = 3},
    {id = "belt", category = "clothing", label = "Belt", fullTypes = {"Base.Belt2", "Base.Belt"}, icon = "Belt2", basePrice = 24, rarity = 2},
    {id = "clubhammer", category = "tools", label = "Club Hammer", fullTypes = {"Base.ClubHammer", "Base.Hammer"}, icon = "ClubHammer", basePrice = 38, rarity = 3},
    {id = "ballpeen", category = "tools", label = "Ball Peen Hammer", fullTypes = {"Base.BallPeenHammer", "Base.Hammer"}, icon = "BallPeenHammer", basePrice = 32, rarity = 3},
    {id = "woodaxe", category = "tools", label = "Wood Axe", fullTypes = {"Base.WoodAxe", "Base.Axe"}, icon = "WoodAxe", basePrice = 148, rarity = 7},
    {id = "pickaxe", category = "tools", label = "Pickaxe", fullTypes = {"Base.PickAxe", "Base.Pickaxe", "Base.Axe"}, icon = "PickAxe", basePrice = 118, rarity = 6},
    {id = "gardenhoe", category = "tools", label = "Garden Hoe", fullTypes = {"Base.GardenHoe", "Base.GardenFork"}, icon = "GardenHoe", basePrice = 48, rarity = 4},
    {id = "fishingrod", category = "tools", label = "Fishing Rod", fullTypes = {"Base.FishingRod", "Base.FishingRodBreak"}, icon = "FishingRod", basePrice = 44, rarity = 4},
    {id = "propane", category = "tools", label = "Propane Torch", fullTypes = {"Base.PropaneTorch"}, icon = "PropaneTorch", basePrice = 92, rarity = 6},
    {id = "weldingmask", category = "tools", label = "Welding Mask", fullTypes = {"Base.WeldingMask"}, icon = "WeldingMask", basePrice = 64, rarity = 5},
    {id = "plunger", category = "weapons", label = "Plunger", fullTypes = {"Base.Plunger", "Base.LeadPipe"}, icon = "Plunger", basePrice = 18, rarity = 1},
    {id = "rollingpin", category = "weapons", label = "Rolling Pin", fullTypes = {"Base.RollingPin", "Base.BaseballBat"}, icon = "RollingPin", basePrice = 22, rarity = 2},
    {id = "fryingpan", category = "weapons", label = "Frying Pan", fullTypes = {"Base.Pan", "Base.FryingPan"}, icon = "Pan", basePrice = 28, rarity = 2},
    {id = "griddlepan", category = "weapons", label = "Griddle Pan", fullTypes = {"Base.GriddlePan", "Base.Pan"}, icon = "GriddlePan", basePrice = 30, rarity = 2},
    {id = "letteropener", category = "weapons", label = "Letter Opener", fullTypes = {"Base.LetterOpener", "Base.KitchenKnife"}, icon = "LetterOpener", basePrice = 20, rarity = 2},
    {id = "spear", category = "weapons", label = "Wooden Spear", fullTypes = {"Base.SpearCrafted", "Base.Spear"}, icon = "SpearCrafted", basePrice = 36, rarity = 3},
    {id = "sledge", category = "weapons", label = "Sledgehammer", fullTypes = {"Base.Sledgehammer"}, icon = "Sledgehammer", basePrice = 260, rarity = 9},
    {id = "splint", category = "medical", label = "Splint", fullTypes = {"Base.Splint"}, icon = "Splint", basePrice = 18, rarity = 2},
    {id = "bandaid", category = "medical", label = "Adhesive Bandages", fullTypes = {"Base.Bandaid", "Base.Bandage"}, icon = "Bandaid", basePrice = 12, rarity = 1},
    {id = "iodine", category = "medical", label = "Bottle of Disinfectant", fullTypes = {"Base.Disinfectant", "Base.AlcoholWipes"}, icon = "Disinfectant", basePrice = 42, rarity = 4},
    {id = "scalpel", category = "medical", label = "Scalpel", fullTypes = {"Base.Scalpel", "Base.KitchenKnife"}, icon = "Scalpel", basePrice = 30, rarity = 3},
    {id = "sutureholder", category = "medical", label = "Suture Holder", fullTypes = {"Base.SutureNeedleHolder", "Base.SutureNeedle"}, icon = "SutureNeedleHolder", basePrice = 46, rarity = 4},
    {id = "medicalmask", category = "medical", label = "Medical Mask", fullTypes = {"Base.Hat_SurgicalMask", "Base.Hat_DustMask"}, icon = "Hat_SurgicalMask", basePrice = 16, rarity = 2},
    {id = "orangepop", category = "food", label = "Orange Soda", fullTypes = {"Base.Pop3", "Base.PopBottle"}, icon = "Pop3", basePrice = 10, rarity = 1},
    {id = "colasoda", category = "food", label = "Cola", fullTypes = {"Base.Pop", "Base.PopBottle"}, icon = "Pop", basePrice = 10, rarity = 1},
    {id = "ramen", category = "food", label = "Instant Noodles", fullTypes = {"Base.Ramen", "Base.Noodles"}, icon = "Ramen", basePrice = 12, rarity = 1},
    {id = "rice", category = "food", label = "Rice", fullTypes = {"Base.Rice"}, icon = "Rice", basePrice = 22, rarity = 2},
    {id = "pasta", category = "food", label = "Pasta", fullTypes = {"Base.Pasta"}, icon = "Pasta", basePrice = 20, rarity = 2},
    {id = "macandcheese", category = "food", label = "Mac and Cheese", fullTypes = {"Base.Macandcheese", "Base.MacAndCheese"}, icon = "Macandcheese", basePrice = 18, rarity = 2},
    {id = "cannedchili", category = "food", label = "Canned Chili", fullTypes = {"Base.CannedChili", "Base.CannedSoup"}, icon = "CannedChili", basePrice = 22, rarity = 3},
    {id = "cannedcorn", category = "food", label = "Canned Corn", fullTypes = {"Base.CannedCorn"}, icon = "CannedCorn", basePrice = 16, rarity = 2},
    {id = "yeast", category = "food", label = "Yeast", fullTypes = {"Base.Yeast"}, icon = "Yeast", basePrice = 18, rarity = 2},
    {id = "flour", category = "food", label = "Flour", fullTypes = {"Base.Flour"}, icon = "Flour", basePrice = 18, rarity = 2},
    {id = "weldingrods", category = "materials", label = "Welding Rods", fullTypes = {"Base.WeldingRods"}, icon = "WeldingRods", basePrice = 36, rarity = 4},
    {id = "metalsheet", category = "materials", label = "Metal Sheet", fullTypes = {"Base.SheetMetal"}, icon = "SheetMetal", basePrice = 34, rarity = 4},
    {id = "smallmetal", category = "materials", label = "Small Metal Sheet", fullTypes = {"Base.SmallSheetMetal"}, icon = "SmallSheetMetal", basePrice = 24, rarity = 3},
    {id = "scrapmetal", category = "materials", label = "Scrap Metal", fullTypes = {"Base.ScrapMetal"}, icon = "ScrapMetal", basePrice = 16, rarity = 2},
    {id = "leatherstrips", category = "materials", label = "Leather Strips", fullTypes = {"Base.LeatherStrips"}, icon = "LeatherStrips", basePrice = 16, rarity = 2},
    {id = "denimstrips", category = "materials", label = "Denim Strips", fullTypes = {"Base.DenimStrips"}, icon = "DenimStrips", basePrice = 10, rarity = 1},
    {id = "rubberband", category = "materials", label = "Rubber Bands", fullTypes = {"Base.RubberBand", "Base.Twine"}, icon = "RubberBand", basePrice = 9, rarity = 1},
    {id = "paintbrush", category = "materials", label = "Paint Brush", fullTypes = {"Base.Paintbrush"}, icon = "Paintbrush", basePrice = 14, rarity = 2},
    {id = "paintbucket", category = "materials", label = "Paint Bucket", fullTypes = {"Base.PaintbucketEmpty", "Base.Paintbucket"}, icon = "Paintbucket", basePrice = 20, rarity = 2},
    {id = "sensor", category = "electronics", label = "Sensor Kit", fullTypes = {"Base.MotionSensor", "Base.ElectronicsScrap"}, icon = "MotionSensor", basePrice = 78, rarity = 5},
    {id = "transmitter", category = "electronics", label = "Radio Transmitter", fullTypes = {"Base.RadioTransmitter"}, icon = "RadioTransmitter", basePrice = 76, rarity = 5},
    {id = "receiver", category = "electronics", label = "Radio Receiver", fullTypes = {"Base.RadioReceiver"}, icon = "RadioReceiver", basePrice = 58, rarity = 4},
    {id = "hamradio", category = "electronics", label = "Ham Radio", fullTypes = {"Base.HamRadio1", "Base.HamRadio2"}, icon = "HamRadio1", basePrice = 130, rarity = 7},
    {id = "headphones", category = "electronics", label = "Headphones", fullTypes = {"Base.Headphones"}, icon = "Headphones", basePrice = 24, rarity = 2},
    {id = "earbuds", category = "electronics", label = "Earbuds", fullTypes = {"Base.Earbuds", "Base.Headphones"}, icon = "Earbuds", basePrice = 14, rarity = 1},
    {id = "cassette", category = "electronics", label = "Cassette", fullTypes = {"Base.CDplayer", "Base.CordlessPhone"}, icon = "CDplayer", basePrice = 18, rarity = 2},
    {id = "watch", category = "electronics", label = "Digital Watch", fullTypes = {"Base.DigitalWatch2", "Base.DigitalWatch"}, icon = "DigitalWatch2", basePrice = 26, rarity = 3},
    {id = "militaryboots", category = "clothing", label = "Military Boots", fullTypes = {"Base.Shoes_ArmyBoots", "Base.Shoes_BlackBoots"}, icon = "Shoes_ArmyBoots", basePrice = 76, rarity = 5},
    {id = "leatherjacket", category = "clothing", label = "Leather Jacket", fullTypes = {"Base.Jacket_LeatherBarrelDogs", "Base.JacketLong_Random"}, icon = "Jacket_LeatherBarrelDogs", basePrice = 88, rarity = 6},
    {id = "longcoat", category = "clothing", label = "Long Coat", fullTypes = {"Base.JacketLong_Random", "Base.Jacket_Ranger"}, icon = "JacketLong_Random", basePrice = 64, rarity = 5},
    {id = "dustmask", category = "clothing", label = "Dust Mask", fullTypes = {"Base.Hat_DustMask", "Base.Hat_SurgicalMask"}, icon = "Hat_DustMask", basePrice = 18, rarity = 2},
    {id = "woolhat", category = "clothing", label = "Wool Hat", fullTypes = {"Base.Hat_WoolyHat", "Base.Hat_BonnieHat"}, icon = "Hat_WoolyHat", basePrice = 18, rarity = 2},
    {id = "fannypack", category = "clothing", label = "Fanny Pack", fullTypes = {"Base.Bag_FannyPackFront", "Base.Bag_FannyPackBack"}, icon = "Bag_FannyPackFront", basePrice = 36, rarity = 3},
    {id = "hikingbag", category = "clothing", label = "Hiking Bag", fullTypes = {"Base.Bag_NormalHikingBag", "Base.Bag_BigHikingBag"}, icon = "Bag_NormalHikingBag", basePrice = 110, rarity = 6},
    {id = "apron", category = "clothing", label = "Apron", fullTypes = {"Base.Apron_White", "Base.Apron_Black"}, icon = "Apron_White", basePrice = 20, rarity = 2}
}

ComputerModMarket.jobPool = {
    {id = "kill_3", type = "kill", label = "Clear 3 nearby infected", target = 3, reward = 28},
    {id = "kill_5", type = "kill", label = "Clear 5 nearby infected", target = 5, reward = 44},
    {id = "kill_8", type = "kill", label = "Clear 8 nearby infected", target = 8, reward = 72},
    {id = "deliver_bandage", type = "deliver", label = "Deliver bandages", target = 2, fullTypes = {"Base.Bandage", "Base.RippedSheets"}, icon = "Bandage", reward = 24},
    {id = "deliver_battery", type = "deliver", label = "Deliver AA batteries", target = 2, fullTypes = {"Base.Battery"}, icon = "Battery", reward = 26},
    {id = "deliver_nails", type = "deliver", label = "Deliver nails", target = 1, fullTypes = {"Base.NailsBox", "Base.Nails"}, icon = "NailsBox", reward = 32},
    {id = "deliver_food", type = "deliver", label = "Deliver canned food", target = 2, fullTypes = {"Base.TinnedBeans", "Base.CannedBolognese", "Base.CannedCarrots2", "Base.CannedChili", "Base.CannedCorn", "Base.CannedCornedBeef", "Base.CannedFruitBeverage", "Base.CannedFruitCocktail", "Base.CannedMilk", "Base.CannedMushroomSoup", "Base.CannedPeaches", "Base.CannedPeas", "Base.CannedPineapple", "Base.CannedPotato2", "Base.CannedSardines", "Base.CannedTomato2", "Base.Dogfood", "Base.DentedCan", "Base.MysteryCan", "Base.TinnedSoup", "Base.TunaTin", "Base.WaterRationCan", "Base.CannedBellPepper", "Base.CannedBroccoli", "Base.CannedCabbage", "Base.CannedCarrots", "Base.CannedEggplant", "Base.CannedLeek", "Base.CannedPotato", "Base.CannedRedRadish", "Base.CannedTomato", "Base.CannedRoe", "Base.CannedSoup", "Base.CannedBakedBeans", "Base.BakedBeans"}, icon = "CannedSoup", reward = 34},
    {id = "deliver_wire", type = "deliver", label = "Deliver electrical parts", target = 2, fullTypes = {"Base.ElectricWire", "Base.ElectronicsScrap"}, icon = "ElectricWire", reward = 42},
    {id = "deliver_tape", type = "deliver", label = "Deliver duct tape", target = 1, fullTypes = {"Base.DuctTape"}, icon = "DuctTape", reward = 30},
    {id = "paperwork_inventory", type = "paperwork", label = "Type inventory list", target = 1, reward = 10},
    {id = "paperwork_receipts", type = "paperwork", label = "Sort receipt archive", target = 1, reward = 12},
    {id = "paperwork_ledger", type = "paperwork", label = "Balance ledger page", target = 1, reward = 18},
    {id = "paperwork_prices", type = "paperwork", label = "Enter shelf prices", target = 1, reward = 14}
}

function ComputerModMarket.isValidFullType(fullType)
    if not fullType or fullType == "" then return false end
    if getScriptManager and getScriptManager() and getScriptManager().FindItem then
        local ok, item = pcall(function() return getScriptManager():FindItem(fullType) end)
        if ok then return item ~= nil end
    end
    if ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem then
        local ok, item = pcall(function() return ScriptManager.instance:FindItem(fullType) end)
        if ok then return item ~= nil end
    end
    return getScriptManager == nil and ScriptManager == nil
end

function ComputerModMarket.resolveFullType(item)
    if not item then return nil end
    local candidates = {}
    if item.fullType then candidates[#candidates + 1] = item.fullType end
    if type(item.fullTypes) == "table" then
        for i = 1, #item.fullTypes do
            candidates[#candidates + 1] = item.fullTypes[i]
        end
    end
    for i = 1, #candidates do
        if ComputerModMarket.isValidFullType(candidates[i]) then
            return candidates[i]
        end
    end
    return nil
end

function ComputerModMarket.isValidItem(fullType)
    return ComputerModMarket.isValidFullType(fullType)
end

function ComputerModMarket.getUsableShopPool()
    local pool = {}
    for i = 1, #ComputerModMarket.shopPool do
        local item = ComputerModMarket.shopPool[i]
        local resolved = ComputerModMarket.resolveFullType(item)
        if resolved then
            local copy = {}
            for key, value in pairs(item) do
                copy[key] = value
            end
            copy.fullType = resolved
            pool[#pool + 1] = copy
        end
    end
    return pool
end

function ComputerModMarket.getUsableJobPool()
    local pool = {}
    for i = 1, #ComputerModMarket.jobPool do
        local job = ComputerModMarket.jobPool[i]
        local copy = {}
        for key, value in pairs(job) do
            copy[key] = value
        end
        if job.type == "deliver" then
            copy.fullType = ComputerModMarket.resolveFullType(job)
            if copy.fullType then
                pool[#pool + 1] = copy
            end
        else
            pool[#pool + 1] = copy
        end
    end
    return pool
end

function ComputerModMarket.pickDaily(pool, day, prefix, count)
    local result = {}
    local poolSize = #pool
    if poolSize == 0 then return result end
    local ranked = {}
    for i = 1, poolSize do
        ranked[#ranked + 1] = {
            index = i,
            score = ComputerModMarket.hash(tostring(day or 0) .. ":" .. tostring(prefix or "") .. ":" .. tostring(pool[i].id or i))
        }
    end
    table.sort(ranked, function(a, b) return a.score < b.score end)
    for i = 1, math.min(count, #ranked) do
        local source = pool[ranked[i].index]
        local rarity = tonumber(source.rarity or 1) or 1
        local stockSeed = ComputerModMarket.hash(tostring(day or 0) .. ":stock:" .. tostring(source.id or i))
        local stock = math.max(1, (7 - rarity) + (stockSeed % 3))
        local price = source.price or math.floor((tonumber(source.basePrice or 10) or 10) * (0.78 + rarity * 0.32) + 0.5)
        result[#result + 1] = {
            id = source.id,
            label = source.label,
            category = source.category or "misc",
            type = source.type,
            target = source.target,
            fullType = source.fullType,
            fullTypes = source.fullTypes,
            icon = source.icon,
            rarity = rarity,
            price = price,
            reward = source.reward,
            stock = source.fullType and stock or nil
        }
    end
    return result
end

function ComputerModMarket.needsShopRefresh(list)
    if type(list) ~= "table" or #list < 8 then return true end
    for i = 1, #list do
        local item = list[i]
        if type(item) ~= "table" or not item.category or not item.fullType or not ComputerModMarket.isValidFullType(item.fullType) then
            return true
        end
    end
    return false
end

function ComputerModMarket.needsJobRefresh(list)
    if type(list) ~= "table" or #list < 5 then return true end
    for i = 1, #list do
        local job = list[i]
        if type(job) ~= "table" or not job.type or not job.target or not job.reward then
            return true
        end
        if job.type == "deliver" and (not job.fullType or not ComputerModMarket.isValidFullType(job.fullType)) then
            return true
        end
    end
    return false
end

function ComputerModMarket.refreshStoreDaily()
    local store = ComputerModMarket.getStore()
    local shopCycle = ComputerModMarket.getCycleIndex("shop", store)
    local jobCycle = ComputerModMarket.getCycleIndex("jobs", store)
    if tonumber(store.shopCycle or -1) ~= shopCycle or ComputerModMarket.needsShopRefresh(store.dailyShop) then
        store.shopCycle = shopCycle
        store.dailyShop = ComputerModMarket.pickDaily(ComputerModMarket.getUsableShopPool(), shopCycle, "shop", 18)
    end
    if tonumber(store.jobCycle or -1) ~= jobCycle or ComputerModMarket.needsJobRefresh(store.dailyJobs) then
        store.jobCycle = jobCycle
        store.dailyJobs = ComputerModMarket.pickDaily(ComputerModMarket.getUsableJobPool(), jobCycle, "jobs", 6)
    end
    return store
end

function ComputerModMarket.resetDaily(kind)
    local store = ComputerModMarket.getStore()
    local prefix = kind == "jobs" and "job" or "shop"
    store[prefix .. "StartAge"] = ComputerModMarket.getWorldAgeHours()
    store[prefix .. "Serial"] = (tonumber(store[prefix .. "Serial"] or 0) or 0) + 1
    if kind == "jobs" then
        store.jobCycle = -999999
        store.dailyJobs = nil
    else
        store.shopCycle = -999999
        store.dailyShop = nil
    end
    ComputerModMarket.refreshStoreDaily()
end

function ComputerModMarket.ensureAccountShape(account)
    if not account then return nil end
    if type(account.purchases) ~= "table" then account.purchases = {} end
    if type(account.completedJobs) ~= "table" then account.completedJobs = {} end
    if type(account.jobProgress) ~= "table" then account.jobProgress = {} end
    account.money = tonumber(account.money or 24) or 24
    return account
end

function ComputerModMarket.refreshDaily(account)
    account = ComputerModMarket.ensureAccountShape(account)
    if not account then return nil end
    local store = ComputerModMarket.refreshStoreDaily()
    account.dailyShop = store.dailyShop or {}
    account.dailyJobs = store.dailyJobs or {}
    if tonumber(account.completedJobCycle or -1) ~= tonumber(store.jobCycle or 0) then
        account.completedJobCycle = tonumber(store.jobCycle or 0) or 0
        account.completedJobs = {}
        account.jobProgress = {}
    end
    return account
end

function ComputerModMarket.getAccount(username)
    local normalized = ComputerModMarket.normalizeUsername(username)
    if normalized == "" then return nil end
    local store = ComputerModMarket.getStore()
    return ComputerModMarket.refreshDaily(store.accounts[normalized])
end

function ComputerModMarket.createAccount(username, password, recoveryEmail)
    local normalized = ComputerModMarket.normalizeUsername(username)
    password = ComputerModMarket.trim(password)
    recoveryEmail = ComputerModMail.normalizeAddress(recoveryEmail or "")
    if not ComputerModMarket.isValidUsername(normalized) then
        return false, "invalid"
    end
    if password == "" then
        return false, "password"
    end
    if not ComputerModMail.isValidAddress(recoveryEmail) or not ComputerModMail.getAccount(recoveryEmail) then
        return false, "mail"
    end
    local store = ComputerModMarket.getStore()
    if store.accounts[normalized] then
        return false, "exists"
    end
    local account = {
        username = normalized,
        displayName = ComputerModMarket.trim(username),
        password = password,
        recoveryEmail = recoveryEmail,
        money = 24,
        purchases = {},
        completedJobs = {},
        jobProgress = {}
    }
    store.accounts[normalized] = account
    ComputerModMarket.refreshDaily(account)
    return true, account
end

function ComputerModMarket.login(username, password)
    local normalized = ComputerModMarket.normalizeUsername(username)
    local account = ComputerModMarket.getAccount(normalized)
    if not account then
        return false, "missing"
    end
    if tostring(account.password or "") ~= ComputerModMarket.trim(password) then
        return false, "password"
    end
    return true, account
end

function ComputerModMarket.findShopItem(account, itemId)
    account = ComputerModMarket.refreshDaily(account)
    if not account then return nil end
    local store = ComputerModMarket.refreshStoreDaily()
    for i = 1, #(store.dailyShop or {}) do
        if store.dailyShop[i].id == itemId then return store.dailyShop[i] end
    end
    return nil
end

function ComputerModMarket.findJob(account, jobId)
    account = ComputerModMarket.refreshDaily(account)
    if not account then return nil end
    for i = 1, #account.dailyJobs do
        if account.dailyJobs[i].id == jobId then return account.dailyJobs[i] end
    end
    return nil
end

function ComputerModMarket.getJobProgress(account, jobId)
    account = ComputerModMarket.ensureAccountShape(account)
    if not account or not jobId then return nil end
    account.jobProgress[jobId] = account.jobProgress[jobId] or {}
    return account.jobProgress[jobId]
end

function ComputerModMarket.prepareJobProgress(username, currentKills)
    local account = ComputerModMarket.getAccount(username)
    if not account then return nil end
    local jobs = account.dailyJobs or {}
    for i = 1, #jobs do
        local job = jobs[i]
        if job and job.type == "kill" then
            local progress = ComputerModMarket.getJobProgress(account, job.id)
            if progress and progress.startKills == nil then
                progress.startKills = tonumber(currentKills or 0) or 0
            end
        end
    end
    return account
end

function ComputerModMarket.validatePurchase(username, itemId)
    local account = ComputerModMarket.getAccount(username)
    local item = ComputerModMarket.findShopItem(account, itemId)
    if not account or not item then return false, "missing" end
    if (tonumber(item.stock or 0) or 0) <= 0 then return false, "stock" end
    if account.money < item.price then return false, "money" end
    if not ComputerModMarket.isValidFullType(item.fullType) then return false, "item" end
    return true, account, item
end

function ComputerModMarket.applyPurchase(username, itemId)
    local valid, account, item = ComputerModMarket.validatePurchase(username, itemId)
    if not valid then return false, account end
    account.money = account.money - item.price
    item.stock = math.max(0, (tonumber(item.stock or 0) or 0) - 1)
    table.insert(account.purchases, 1, item.label)
    return true, item
end

function ComputerModMarket.buyItem(username, itemId)
    return ComputerModMarket.applyPurchase(username, itemId)
end

function ComputerModMarket.getInventoryItemCount(inventory, fullType)
    if not inventory or not fullType then return 0 end
    local count = 0
    if inventory.getCountTypeRecurse then
        local ok, value = pcall(function() return inventory:getCountTypeRecurse(fullType) end)
        if ok and value and (tonumber(value) or 0) > 0 then return tonumber(value) or 0 end
    end
    if inventory.getItems then
        local ok, items = pcall(function() return inventory:getItems() end)
        if ok and items and items.size and items.get then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and item.getFullType and item:getFullType() == fullType then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function ComputerModMarket.getInventoryJobItemCount(inventory, job)
    if not job then return 0 end
    local total = 0
    if type(job.fullTypes) == "table" then
        for i = 1, #job.fullTypes do
            if ComputerModMarket.isValidFullType(job.fullTypes[i]) then
                total = total + ComputerModMarket.getInventoryItemCount(inventory, job.fullTypes[i])
            end
        end
    elseif job.fullType then
        total = ComputerModMarket.getInventoryItemCount(inventory, job.fullType)
    end
    return total
end

function ComputerModMarket.removeInventoryItems(inventory, fullType, amount)
    amount = tonumber(amount or 1) or 1
    if not inventory or not fullType or amount <= 0 then return false end
    if ComputerModMarket.getInventoryItemCount(inventory, fullType) < amount then return false end
    local removed = 0
    local matches = nil
    if inventory.getAllTypeRecurse then
        local ok, items = pcall(function() return inventory:getAllTypeRecurse(fullType) end)
        if ok then matches = items end
    end
    if matches and matches.size and matches.get then
        for i = matches:size() - 1, 0, -1 do
            local item = matches:get(i)
            local container = item and item.getContainer and item:getContainer() or inventory
            local okRemove = false
            if item and container and container.Remove then
                okRemove = pcall(function() container:Remove(item) end)
            end
            if okRemove and sendRemoveItemFromContainer then
                pcall(function() sendRemoveItemFromContainer(container, item) end)
            end
            if okRemove then
                removed = removed + 1
                if removed >= amount then return true end
            end
        end
    elseif inventory.getItems then
        local ok, items = pcall(function() return inventory:getItems() end)
        if ok and items and items.size and items.get then
            for i = items:size() - 1, 0, -1 do
                local item = items:get(i)
                if item and item.getFullType and item:getFullType() == fullType then
                    local okRemove = inventory.Remove and pcall(function() inventory:Remove(item) end) or false
                    if okRemove and sendRemoveItemFromContainer then
                        pcall(function() sendRemoveItemFromContainer(inventory, item) end)
                    end
                    if okRemove then
                        removed = removed + 1
                        if removed >= amount then return true end
                    end
                end
            end
        end
    end
    return removed >= amount
end

function ComputerModMarket.removeInventoryItemsForJob(inventory, job)
    local amount = tonumber(job and job.target or 1) or 1
    if not inventory or not job or amount <= 0 then return false end
    if ComputerModMarket.getInventoryJobItemCount(inventory, job) < amount then return false end
    local candidates = {}
    if type(job.fullTypes) == "table" then
        for i = 1, #job.fullTypes do
            if ComputerModMarket.isValidFullType(job.fullTypes[i]) then
                candidates[#candidates + 1] = job.fullTypes[i]
            end
        end
    elseif job.fullType then
        candidates[#candidates + 1] = job.fullType
    end
    local remaining = amount
    for i = 1, #candidates do
        while remaining > 0 and ComputerModMarket.getInventoryItemCount(inventory, candidates[i]) > 0 do
            if ComputerModMarket.removeInventoryItems(inventory, candidates[i], 1) then
                remaining = remaining - 1
            else
                break
            end
        end
        if remaining <= 0 then return true end
    end
    return remaining <= 0
end

function ComputerModMarket.getPlayerZombieKills(player)
    if not player then return 0 end
    if player.getZombieKills then
        local ok, value = pcall(function() return player:getZombieKills() end)
        if ok and value then return tonumber(value) or 0 end
    end
    if player.getModData then
        local ok, data = pcall(function() return player:getModData() end)
        if ok and data then return tonumber(data.ZombieKills or data.zombieKills or 0) or 0 end
    end
    return 0
end

function ComputerModMarket.canCompleteJob(username, jobId, player, requestedStartKills, minigamePassed)
    local account = ComputerModMarket.getAccount(username)
    local job = ComputerModMarket.findJob(account, jobId)
    if not account or not job then return false, "missing" end
    if account.completedJobs[job.id] then return false, "done" end
    if job.type == "kill" then
        local kills = ComputerModMarket.getPlayerZombieKills(player)
        local progress = ComputerModMarket.getJobProgress(account, job.id)
        if progress and progress.startKills == nil then
            progress.startKills = kills
        end
        local startKills = tonumber(progress and progress.startKills or kills) or kills
        if kills - startKills < (tonumber(job.target or 1) or 1) then
            return false, "progress"
        end
    elseif job.type == "deliver" then
        if not player or not player.getInventory then return false, "inventory" end
        local inventory = player:getInventory()
        if ComputerModMarket.getInventoryJobItemCount(inventory, job) < (tonumber(job.target or 1) or 1) then
            return false, "items"
        end
    elseif job.type == "paperwork" and minigamePassed ~= true then
        return false, "minigame"
    end
    return true, account, job
end

function ComputerModMarket.completeJob(username, jobId, player, requestedStartKills, minigamePassed)
    local valid, account, job = ComputerModMarket.canCompleteJob(username, jobId, player, requestedStartKills, minigamePassed)
    if not valid then return false, account end
    if job.type == "deliver" then
        if not ComputerModMarket.removeInventoryItemsForJob(player and player:getInventory(), job) then
            return false, "items"
        end
    end
    account.completedJobs[job.id] = true
    account.money = account.money + job.reward
    return true, job
end

function ComputerModMarket.addDebugMoney(username, amount)
    local account = ComputerModMarket.getAccount(username)
    if not account then return false end
    account.money = account.money + (tonumber(amount or 0) or 0)
    return true
end
