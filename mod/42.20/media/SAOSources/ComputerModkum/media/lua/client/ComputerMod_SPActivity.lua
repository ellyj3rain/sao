require "ComputerMod_Mail"
require "ComputerMod_Chat"
require "ComputerMod_Posts"
require "ComputerMod_Network"
require "ComputerMod_ContentData"
require "ComputerMod_Sandbox"

ComputerModSPActivity = ComputerModSPActivity or {}

local translationDefaults = {}

local function registerTranslation(key, fallback)
    translationDefaults[key] = fallback
    return key
end

local function localizedText(key, fallback)
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return tostring(value) end
    end
    return tostring(fallback or "")
end

local function localizedFormat(key, fallback, ...)
    local ok, value = pcall(string.format, localizedText(key, fallback), ...)
    if ok then return value end
    return string.format(fallback, ...)
end

function ComputerModSPActivity.getTranslationCatalog()
    return translationDefaults
end

local boardPools = {
    normal = {
        {name = "Megan", body = "Did anyone else lose cable for a minute? Mine came back, but every local channel is showing the same county notice."},
        {name = "Dale", body = "Traffic is backed up past the school. If you are heading into town, take the long way around."},
        {name = "Katie R.", body = "The pharmacy line is out the door. People keep saying it is just a bad flu, so why is everyone buying masks?"},
        {name = "Tom W.", body = "Is tonight's game cancelled or not? The radio keeps cutting away before they say anything useful."},
        {name = "Linda", body = "Power blinked twice on our block. Save whatever you are working on before it happens again."},
        {name = "countywatch", body = "The emergency broadcast says to stay calm and avoid unnecessary travel. No evacuation order has been issued."},
        {name = "Ray P.", body = "My brother works near the hospital. He says ambulances have been arriving nonstop since before sunrise."},
        {name = "Nora", body = "Does anyone know why the pay phones are all busy? I cannot get through to my parents in Louisville."},
        {name = "Marcus", body = "The gas station has a line around the block. Half the people there are filling spare cans."},
        {name = "Sarah J.", body = "Our grocery delivery never arrived this morning. The manager says the truck was turned around at the county line."},
        {name = "old_timer", body = "County used to run emergency drills every summer. This does not look like any drill I remember."},
        {name = "Jenny", body = "Rumor at school says classes might be cancelled tomorrow. Teachers were told not to discuss it with students."},
        {name = "Bobby", body = "Long-distance calls connect for a few seconds and then drop. Local calls still work sometimes."},
        {name = "pharmacist99", body = "We sold out of masks before lunch. Please stop shouting at the counter staff; we do not have more in the back."},
        {name = "weatherdesk", body = "There is no severe weather in the forecast. Whatever is causing the outages, it is not a storm."},
        {name = "garage_mike", body = "Highway patrol came through asking every shop how many tow trucks were running. They would not say why."},
        {name = "rosewood_mom", body = "The daycare called for early pickup. They said several employees failed to arrive for work."},
        {name = "westpoint_local", body = "Three helicopters crossed town heading south. Too high to see markings, but they were moving fast."},
        {name = "Alan C.", body = "Our office sent everyone home before noon. They told us to take our files but leave the computers on."},
        {name = "diner_sue", body = "Lunch crowd is full of people trading rumors. Nobody has heard the same story twice."},
        {name = "library_desk", body = "The library is closing early. Do not worry about due dates until regular hours resume."},
        {name = "county_courier", body = "Package routes east of town are suspended. Anything already on a truck may be returned to the depot."},
        {name = "Rick M.", body = "If you own a battery radio, check it now. Local stations are already having trouble staying on air."}
    },
    outbreak = {
        {name = "Megan", body = "The school sent everyone home. One of the buses never arrived and nobody at the office will answer."},
        {name = "Dale", body = "Police closed the main road. I saw people running between cars near the checkpoint."},
        {name = "Katie R.", body = "Do not go to the clinic. The doors are locked and the parking lot is completely full."},
        {name = "Tom W.", body = "They are saying bites now. Not fever, bites. What kind of sickness spreads through bites?"},
        {name = "Linda", body = "Someone is pounding on the house across the street. The owners will not open the door."},
        {name = "hamradio_ky", body = "Shortwave traffic reports trouble in more than one town. This is not limited to Knox County."},
        {name = "Nora", body = "The television signal is gone. If anyone still has radio news, please post what you hear."},
        {name = "Ray P.", body = "My brother finally called. He said to lock every door and not let anyone inside, even if they look injured."},
        {name = "westpoint_local", body = "Soldiers are checking cars near the bridge. They turned us back without explaining where we should go."},
        {name = "rosewood_mom", body = "My son has a fever but no bites. The emergency number rings once and disconnects. What am I supposed to do?"},
        {name = "garage_mike", body = "An abandoned car rolled into our lot with blood on the driver's door. Nobody has come looking for it."},
        {name = "Sarah J.", body = "There is screaming behind the clinic and something keeps hitting the side entrance from inside."},
        {name = "Marcus", body = "Both roads toward the county line are blocked now. People are turning around and driving across fields."},
        {name = "Jenny", body = "The emergency shelter at the school is locked. A note on the door says to remain at home."},
        {name = "old_timer", body = "Television keeps repeating the same message, but the footage behind the anchor is getting worse."},
        {name = "pharmacist99", body = "Antibiotics will not fix this. We tried to explain that before the crowd broke the front windows."},
        {name = "Alan C.", body = "A coworker collapsed in the parking lot and attacked the people helping him. Police never arrived."},
        {name = "diner_sue", body = "Power has been off for an hour. We are cooking what will spoil and giving it away at the back door."},
        {name = "county_courier", body = "My delivery van was surrounded near the courthouse. I left it running and got out through an alley."},
        {name = "library_desk", body = "Families are sheltering in the reading room. We pushed shelves against the glass doors."},
        {name = "Bobby", body = "Every dog on our street has been barking since sunset. Now some of them have stopped all at once."},
        {name = "weatherdesk", body = "The dark column north of town is smoke, not cloud cover. Wind is carrying it east."},
        {name = "Rick M.", body = "The AM station ended mid-sentence. One weak signal is still repeating instructions to boil water."}
    },
    chaos = {
        {name = "Megan", body = "There are people in the street attacking anyone who falls. This is real. Turn off your lights and stay quiet."},
        {name = "Dale", body = "The checkpoint is gone. Cars are burning on both sides of the road and nobody is directing traffic."},
        {name = "Katie R.", body = "We are leaving through the back roads. If the bridge is blocked, we will try the old service road."},
        {name = "Tom W.", body = "They do not stay down unless the head is destroyed. I wish I was making this up."},
        {name = "Linda", body = "Water pressure just stopped. Fill every container you have while anything is still coming from the tap."},
        {name = "hamradio_ky", body = "Military frequencies are mostly silent. A repeating transmission says major routes are compromised."},
        {name = "Nora", body = "Is anyone on this board actually safe? Please answer with your town, not your address."},
        {name = "Ray P.", body = "The hospital is burning. I cannot reach my brother anymore."},
        {name = "roadside_jim", body = "Do not use sirens or car horns. The noise pulls them in from blocks away."},
        {name = "unknown_user", body = "If this post goes through, the network is still alive somewhere. People are not answering anymore."},
        {name = "Marcus", body = "We barricaded the store, but the glass will not hold another rush. Moving upstairs while we still can."},
        {name = "Sarah J.", body = "Fire jumped from the clinic roof to the building next door. There are no crews left to stop it."},
        {name = "Bobby", body = "Someone keeps calling for help from the intersection. Every time a person goes out, more of them appear."},
        {name = "Jenny", body = "The last school bus is overturned by the rail crossing. Do not take that road."},
        {name = "old_timer", body = "Gunshots solve one problem and bring twenty more. Use them only if you have no other choice."},
        {name = "pharmacist99", body = "No ambulances, no police, no fire department. Whatever supplies you have are all you are getting."},
        {name = "garage_mike", body = "Our shop doors gave way. I am leaving tools behind and taking only water, fuel and the truck."},
        {name = "rosewood_mom", body = "We are trapped above the second floor. The stairwell is full of them and the fire escape is damaged."},
        {name = "westpoint_local", body = "A helicopter circled twice without landing. People ran into the street and drew a crowd of infected behind them."},
        {name = "Rick M.", body = "Save your radio batteries. Most stations are dead and the few remaining signals repeat old recordings."},
        {name = "county_courier", body = "The evacuation convoy never made it past the interchange. Do not follow the abandoned buses."},
        {name = "diner_sue", body = "The supermarket is completely overrun. There is food in smaller houses if you can enter without making noise."},
        {name = "Alan C.", body = "My neighbor died last night and stood back up this morning. Stop waiting for this to make sense."},
        {name = "weatherdesk", body = "The eastern bridge is burning and part of the span has collapsed. There is no route through downtown."},
        {name = "library_desk", body = "This board takes longer to load every hour. Copy down useful addresses before the connection disappears."},
        {name = "hamradio_ky", body = "If your generator is outside, shut it down before refueling. The sound carries farther than you think."},
        {name = "Nora", body = "We waited as long as we could. My family is leaving before sunrise. I hope somebody reading this gets out too."}
    },
    aftermath = {
        {name = "relay_7", body = "Signal check. If anyone can read this, one relay is still carrying traffic east of the county."},
        {name = "ashwood", body = "We found clean water, but the road south is packed with wrecks. Travel on foot and stay off the pavement."},
        {name = "greenriver", body = "Three of us are still here. We only connect when the generator is running, so replies may take a while."},
        {name = "nightowl", body = "Saw lights in an upstairs window last night. If that was you, cover them before dark."},
        {name = "fieldnote", body = "Canned food is getting hard to find. Gardens and rain barrels matter more every day."},
        {name = "hamradio_ky", body = "Long-range radio has gone quiet again. Local relays may be all that remains of the network."},
        {name = "still_here", body = "Another week, another signal check. Leave a short post if you are alive."},
        {name = "northbound", body = "Do not follow the highway signs north. The road ends in a wall of abandoned cars."},
        {name = "roofgarden", body = "Potatoes are growing in buckets on the roof. It is not much, but it proves we can make food without leaving the building."},
        {name = "tradepost", body = "Looking to trade lamp oil and clean jars for batteries. I check this board every second evening."},
        {name = "mapmaker", body = "Mark blocked roads in pencil. Wrecks move, fires spread and yesterday's safe route may be closed tomorrow."},
        {name = "quiet_steps", body = "Large groups of infected drift west after heavy rain. The fields are quieter for now."},
        {name = "wellhouse", body = "The shallow well tastes wrong after the last storm. Boil everything, even if it looks clear."},
        {name = "winterprep", body = "Cold weather will come eventually. Collect blankets and seal broken windows before supplies are buried under snow."},
        {name = "relay_7", body = "Replaced a burned fuse at the relay. Connection should hold until the generator needs fuel again."},
        {name = "scavenger_lee", body = "Someone is leaving empty cans as trail markers near the warehouses. It may be a trap, so watch the rooftops."},
        {name = "field_medic", body = "Clean wounds immediately and keep bandages dry. Infection from dirty cuts is still dangerous even without a bite."},
        {name = "seedkeeper", body = "Saving cabbage and tomato seed for spring. Leave a reply if you have packets worth trading."},
        {name = "hamradio_ky", body = "I transmit at noon when fuel allows. If you answer, keep it short and never give an exact location."},
        {name = "deadzone_map", body = "No network signal remains south of the rail yard. This relay is probably the edge of the connected area."},
        {name = "still_here", body = "Weekly check-in: two voices answered on radio, one new light seen at night, no safe road east."},
        {name = "ashwood", body = "Found fresh footprints near the creek that were not ours. Someone else is surviving out there."}
    }
}

local boardExpansionSets = {
    normal = {
        limit = 7,
        speakers = {"bank_clerk", "busdriver_lee", "county_worker", "market_jane", "phone_tech", "radio_bill", "animal_aid"},
        scenes = {
            "The bank closed its lobby before lunch and moved every employee away from the front windows.",
            "The bus depot cancelled two routes without posting a replacement schedule.",
            "County offices are stacking file boxes in the hallway and sending temporary staff home.",
            "The grocery store limited water and canned food to two cases per customer.",
            "Telephone repair crews were called back to their yard before finishing today's service calls.",
            "The local radio station asked volunteers to bring spare batteries and extension cords.",
            "The animal shelter stopped accepting strays and asked owners to keep pets indoors."
        },
        details = {
            "People are treating it like a temporary inconvenience, but the mood is changing."
        }
    },
    outbreak = {
        limit = 22,
        speakers = {"checkpoint_watch", "clinic_runner", "school_guard", "market_jane", "scanner_listener", "tower_tech", "backroad_ann"},
        scenes = {
            "A second checkpoint appeared on the highway and officers are searching every vehicle.",
            "Hospital staff put tents in the parking lot, then moved everyone back inside without warning.",
            "The school shelter opened for less than an hour before guards locked the outer gates.",
            "The supermarket stopped selling food after a fight spread from the checkout line.",
            "Sheriff cars keep passing toward downtown with lights on and no sirens.",
            "Technicians climbed the radio tower this morning and came down carrying equipment cases."
        },
        details = {
            "Nobody in charge will explain what triggered the response.",
            "The crowd gets more frightened each time another emergency vehicle passes.",
            "People are leaving on foot because traffic is no longer moving.",
            "Anyone nearby should keep their distance and find another route."
        }
    },
    chaos = {
        limit = 48,
        speakers = {"downtown_eye", "roadblock_6", "upper_floor", "warehouse_cam", "convoy_lost", "switchboard", "railwatch", "cedar_street", "quiet_runner", "last_dispatch"},
        scenes = {
            "Fire has crossed the downtown block and the smoke is hiding movement at street level.",
            "The infected packed against the road barrier until the fencing folded into the traffic lane.",
            "People in the apartment building pulled furniture into the stairwell and cut the lights.",
            "The warehouse doors are open and armed groups are dragging crates into pickup trucks.",
            "The evacuation line broke apart when the lead vehicles tried to turn around.",
            "The telephone exchange is dark, but one pay phone outside keeps ringing by itself.",
            "Freight cars are blocking the rail yard while infected move between them in large groups.",
            "Every house on Cedar Street is silent except one alarm that has been sounding for hours."
        },
        details = {
            "There are no emergency crews left in sight.",
            "Noise draws more of them before anyone can clear a path.",
            "Anyone still moving through the area should stay out of the open.",
            "We watched several survivors turn back and disappear between the buildings.",
            "The safest route from yesterday is already unusable.",
            "If this board stays online, post a warning before anyone else walks into it."
        }
    },
    aftermath = {
        limit = 123,
        speakers = {"raincatcher", "generator_log", "fieldwalker", "clinic_cache", "warehouse_note", "bridge_scout", "relay_7", "ridge_smoke", "coldfront", "seedkeeper", "pedal_power", "creekwatch", "night_shift", "tradepost", "mapmaker", "field_medic"},
        scenes = {
            "Rain barrels behind the brick apartments are full and the upper lids are still sealed.",
            "The backup generator at the service building runs cleanly after replacing its cracked fuel line.",
            "The western fields are quiet at dawn, with only a few infected near the tree line.",
            "A locked cabinet in the small clinic still holds bandages, disinfectant and sealed gloves.",
            "The north warehouse has useful hand tools, but the loading floor is unstable near the office wall.",
            "The old bridge can be crossed on foot if you stay beside the southern railing.",
            "The relay mast is working again after cleaning corrosion from the battery contacts.",
            "Thin cooking smoke appeared on the ridge for three evenings and vanished before sunrise.",
            "Cold nights are arriving earlier, and several empty houses still have intact fireplaces.",
            "Dry seed packets were found inside metal drawers at the farm supply office.",
            "Bicycles can pass the vehicle pileup beside the highway without drawing much attention.",
            "The creek north of the tracks is clear upstream but contaminated below the wrecked tanker.",
            "A two-person watch rotation kept the courtyard quiet through the last three nights.",
            "A covered trade cache has been placed beneath the fallen sign near the county road."
        },
        details = {
            "We will check the location again after the next weather change.",
            "Mark it on paper because the route may not remain safe.",
            "Travel quietly and leave before the light starts to fade.",
            "A small group can use it, but a crowd would attract trouble.",
            "Fuel and clean water are still the limits on how long anyone can stay.",
            "Leave a short reply if conditions change before our next connection.",
            "We are not sharing an exact camp location over the board.",
            "The infected wander through irregularly, so wait and watch before approaching.",
            "This may help someone who reaches the area later in the season."
        }
    }
}

local function appendBoardExpansions()
    for phase, config in pairs(boardExpansionSets) do
        local pool = boardPools[phase]
        local added = 0
        for sceneIndex = 1, #config.scenes do
            for detailIndex = 1, #config.details do
                if added >= config.limit then break end
                added = added + 1
                local scene = config.scenes[sceneIndex]
                local detail = config.details[detailIndex]
                local sceneKey = registerTranslation("IGUI_ComputerMod_SP_Board_" .. phase .. "_Scene_" .. tostring(sceneIndex), scene)
                local detailKey = registerTranslation("IGUI_ComputerMod_SP_Board_" .. phase .. "_Detail_" .. tostring(detailIndex), detail)
                pool[#pool + 1] = {
                    name = config.speakers[((added - 1) % #config.speakers) + 1],
                    body = scene .. " " .. detail,
                    group = phase .. ":generated:" .. tostring(sceneIndex),
                    scene = scene,
                    detail = detail,
                    sceneKey = sceneKey,
                    detailKey = detailKey
                }
            end
            if added >= config.limit then break end
        end
    end
end

appendBoardExpansions()

local boardMessageKeyByBody = {}
local boardEntryByKey = {}
local boardMainDialogueCount = 0
local boardUniqueDialogueCount = 0
for phase, pool in pairs(boardPools) do
    for i = 1, #pool do
        local entry = pool[i]
        entry.key = phase .. ":" .. tostring(i)
        entry.group = entry.group or entry.key
        if not entry.sceneKey then
            entry.textKey = registerTranslation("IGUI_ComputerMod_SP_Board_" .. phase .. "_" .. tostring(i), entry.body)
        end
        boardEntryByKey[entry.key] = entry
        local body = tostring(entry.body or "")
        if boardMessageKeyByBody[body] == nil then
            boardUniqueDialogueCount = boardUniqueDialogueCount + 1
        end
        boardMessageKeyByBody[body] = entry.key
        boardMainDialogueCount = boardMainDialogueCount + 1
    end
end

local secretBoardBodies = {
    "The public mirrors are failing, but the old archive at %s still answers. Save what you need while it is up.",
    "Someone on radio mentioned %s. It looks abandoned, but the downloads still work.",
    "If you are looking for the missing manuals, try %s before the relays go dark.",
    "The board at %s is still reachable. Do not waste bandwidth downloading everything.",
    "I found useful scans at %s. Writing the address here in case I do not get another connection."
}

local secretBoardMessages = {}
local secretMessageKeyByBody = {}
local secretEntryByKey = {}
if ComputerModSecretSiteHints then
    for siteIndex = 1, #ComputerModSecretSiteHints do
        for templateIndex = 1, #secretBoardBodies do
            local key = "secret:" .. tostring(siteIndex) .. ":" .. tostring(templateIndex)
            local body = string.format(secretBoardBodies[templateIndex], ComputerModSecretSiteHints[siteIndex])
            local textKey = registerTranslation("IGUI_ComputerMod_SP_Board_Secret_" .. tostring(templateIndex), secretBoardBodies[templateIndex])
            local entry = {
                key = key,
                body = body,
                site = ComputerModSecretSiteHints[siteIndex],
                fallbackTemplate = secretBoardBodies[templateIndex],
                textKey = textKey
            }
            secretBoardMessages[#secretBoardMessages + 1] = entry
            secretMessageKeyByBody[body] = key
            secretEntryByKey[key] = entry
        end
    end
end

function ComputerModSPActivity.getBoardMainDialogueCount()
    return boardMainDialogueCount
end

function ComputerModSPActivity.getBoardDialogueCount()
    return boardMainDialogueCount + #secretBoardBodies
end

function ComputerModSPActivity.getBoardUniqueDialogueCount()
    return boardUniqueDialogueCount
end

function ComputerModSPActivity.getBoardSecretVariantCount()
    return #secretBoardMessages
end

function ComputerModSPActivity.getBoardPoolCounts()
    return {
        normal = #boardPools.normal,
        outbreak = #boardPools.outbreak,
        chaos = #boardPools.chaos,
        aftermath = #boardPools.aftermath,
        main = boardMainDialogueCount,
        secret = #secretBoardBodies,
        total = boardMainDialogueCount + #secretBoardBodies
    }
end

local advertisementMails = {
    {from = "offers@valuclub.local", subject = "Member Savings This Week", body = "Your Value Club account qualifies for special prices on batteries, bottled water and household storage. Bring this message to any participating location."},
    {from = "travel@bluegrass.local", subject = "A Weekend Away", body = "Summer cabins are still available near the lake. Reserve two nights and receive the third night free. Telephone confirmation required."},
    {from = "catalog@homebox.local", subject = "July Home Catalog", body = "New kitchen organizers, tool cabinets and weather radios are now available by mail order. Ask about our twelve-month payment plan."},
    {from = "auto@knoxmotors.local", subject = "Free Vehicle Inspection", body = "Schedule a complimentary tire and battery inspection this week. Offer valid while appointment slots remain."},
    {from = "video@movienight.local", subject = "Two Rentals for One", body = "Rent any new release and choose a second tape at no charge. Late fees and membership rules still apply."}
}

local professionMails = {
    police = {
        {from = "dispatch@county.local", subject = "Shift Coverage", body = "Several patrol shifts still need coverage. Confirm your availability with the desk before this afternoon's briefing."},
        {from = "training@county.local", subject = "Evidence Procedure Update", body = "The revised evidence intake sheet is now in use. Old forms will not be accepted after Friday."}
    },
    medical = {
        {from = "staffing@knoxhealth.local", subject = "Open Clinical Shift", body = "Additional clinical coverage is needed this week. Reply with your certification and the hours you can work."},
        {from = "education@knoxhealth.local", subject = "Infection Control Seminar", body = "The infection control refresher has been moved to the main conference room. Attendance will be recorded."}
    },
    fire = {
        {from = "station@county.local", subject = "Equipment Check", body = "Complete the engine and breathing apparatus checklist before the next shift change. Report missing seals immediately."},
        {from = "training@county.local", subject = "Mutual Aid Drill", body = "Saturday's mutual aid drill begins at 0700. Bring turnout gear and a working portable radio."}
    },
    outdoors = {
        {from = "fieldoffice@county.local", subject = "Field Conditions", body = "Recent rain has damaged several access roads. Use the north trail and report fallen trees when you return."},
        {from = "outdoors@bluegrass.local", subject = "Seasonal Supply Bulletin", body = "Line, seed, gloves and water purification tablets are discounted for registered field workers this week."}
    },
    trades = {
        {from = "workorders@county.local", subject = "Pending Work Orders", body = "Three maintenance calls remain unassigned. Check the work board for locations and required parts."},
        {from = "supply@knoxtrade.local", subject = "Trade Counter Notice", body = "Wire, fasteners and replacement blades arrived this morning. Professional account holders may reserve stock by phone."}
    },
    food = {
        {from = "manager@countyfoods.local", subject = "Delivery and Prep Schedule", body = "The morning delivery is expected early. Cold items must be checked and stored before regular preparation begins."},
        {from = "kitchen@bluegrass.local", subject = "Food Safety Refresher", body = "The county food safety refresher is scheduled for Thursday. Bring your current certification card."}
    },
    fitness = {
        {from = "members@fitlife.local", subject = "Class Substitution", body = "An instructor is needed for two evening classes this week. Reply if you can cover either session."},
        {from = "training@fitlife.local", subject = "Summer Conditioning Notes", body = "The new conditioning plan is available at the front desk. Review hydration guidance before outdoor sessions."}
    },
    veteran = {
        {from = "services@veterans.local", subject = "Benefits Appointment", body = "Your regional services office has opened additional appointment times. Call before Friday to reserve a slot."},
        {from = "legion@knox.local", subject = "Post Meeting", body = "The monthly post meeting begins at 1900. Volunteers are also needed to organize the storage room beforehand."}
    },
    general = {
        {from = "jobs@knoxcounty.local", subject = "Local Job Listings", body = "New clerical, warehouse and maintenance openings were posted this morning. Applications are available at the county office."},
        {from = "library@county.local", subject = "Community Courses", body = "Registration is open for evening courses in first aid, home repair and basic computing. Space is limited."}
    }
}

local mailEntries = {}
local mailEntryBySource = {}
local mailEntryBySubjectKey = {}

local function registerMailEntry(entry, keyPrefix)
    entry.subjectKey = registerTranslation(keyPrefix .. "_Subject", entry.subject)
    entry.bodyKey = registerTranslation(keyPrefix .. "_Body", entry.body)
    mailEntries[#mailEntries + 1] = entry
    mailEntryBySource[entry.subject .. "\30" .. entry.body] = entry
    mailEntryBySubjectKey[entry.subjectKey] = entry
end

for i = 1, #advertisementMails do
    local entry = advertisementMails[i]
    registerMailEntry(entry, "IGUI_ComputerMod_SP_Mail_Advertisement_" .. tostring(i))
end

for category, pool in pairs(professionMails) do
    for i = 1, #pool do
        local entry = pool[i]
        registerMailEntry(entry, "IGUI_ComputerMod_SP_Mail_" .. category .. "_" .. tostring(i))
    end
end

local chatUsers = {
    {username = "amy_k", displayName = "Amy K."},
    {username = "dale73", displayName = "Dale"},
    {username = "megan_r", displayName = "Megan R."},
    {username = "tomwest", displayName = "Tom West"},
    {username = "nora_b", displayName = "Nora B."},
    {username = "rayp", displayName = "Ray P."},
    {username = "katie92", displayName = "Katie"},
    {username = "roadside_jim", displayName = "Jim"},
    {username = "hamradio_ky", displayName = "KY Radio"},
    {username = "linda_m", displayName = "Linda M."}
}

local chatMessagePools = {
    day1 = {
        "Hey, random add, but do I know you from the county board? Everything around town is acting strange today.",
        "Sorry if I added the wrong person. Have you heard why the roads near the hospital are blocked?",
        "Hi. The phone lines are busy and this is the only service that still connects. Is it normal where you are?"
    },
    day2 = {
        "Thanks for accepting. People here are saying the sickness makes them violent. Lock your doors tonight.",
        "The news stopped giving details. If you hear anything reliable, stay inside and keep a radio nearby.",
        "I added anyone who looked local. My family is trying to decide whether to leave before the roads close."
    },
    day3 = {
        "The phones are dead here. We are leaving town before dark. Do not go near anyone who has been bitten.",
        "I can hear sirens everywhere and nobody is answering emergency calls. Find somewhere quiet and stay there.",
        "They broke through the store entrance. I am moving to the back roads now. Good luck, whoever you are."
    },
    day4 = {
        "This may be my last connection. They are in the street and the power keeps failing. Do not come looking for me.",
        "We are shutting the generator down after this message. Noise brings them closer. Stay alive.",
        "Almost everyone on my contact list has gone offline. If you can read this, keep moving and avoid the main roads."
    }
}

local chatEntryByBody = {}
local chatEntryByKey = {}
local firstChatEntry = nil
for phase, pool in pairs(chatMessagePools) do
    for i = 1, #pool do
        local key = registerTranslation("IGUI_ComputerMod_SP_Chat_" .. phase .. "_" .. tostring(i), pool[i])
        local entry = {key = key, body = pool[i]}
        chatEntryByBody[pool[i]] = entry
        chatEntryByKey[key] = entry
        if not firstChatEntry then firstChatEntry = entry end
    end
end
firstChatEntry = chatEntryByKey.IGUI_ComputerMod_SP_Chat_day1_1 or firstChatEntry

local function isSinglePlayer()
    if isClient and isClient() then return false end
    if isServer and isServer() then return false end
    return true
end

local function getWorldAgeHours()
    if not getGameTime then return 0 end
    local okTime, gameTime = pcall(getGameTime)
    if not okTime or not gameTime or not gameTime.getWorldAgeHours then return 0 end
    local okAge, age = pcall(function() return gameTime:getWorldAgeHours() end)
    if not okAge then return 0 end
    return math.max(0, tonumber(age or 0) or 0)
end

local function randomHours(minimum, maximum)
    local low = math.floor(tonumber(minimum or 0) or 0)
    local high = math.max(low, math.floor(tonumber(maximum or low) or low))
    if high <= low then return low end
    return ZombRand(high - low + 1) + low
end

local function internetEnabled()
    if ComputerModNetwork and ComputerModNetwork.isInternetEnabled then
        return ComputerModNetwork.isInternetEnabled()
    end
    return true
end

local function selectDifferent(pool, previousIndex)
    if type(pool) ~= "table" or #pool == 0 then return nil, nil end
    local index = ZombRand(#pool) + 1
    if #pool > 1 and index == previousIndex then
        index = (index % #pool) + 1
    end
    return pool[index], index
end

local function selectUnusedBoardEntry(pool, used, lastGroup)
    if type(pool) ~= "table" or #pool == 0 then return nil, nil end
    local startIndex = ZombRand(#pool) + 1
    local fallbackEntry = nil
    local fallbackIndex = nil
    for offset = 0, #pool - 1 do
        local index = ((startIndex + offset - 1) % #pool) + 1
        local entry = pool[index]
        if type(entry) == "table" and not used[entry.key] then
            if not fallbackEntry then
                fallbackEntry = entry
                fallbackIndex = index
            end
            if entry.group ~= lastGroup then
                return entry, index
            end
        end
    end
    return fallbackEntry, fallbackIndex
end

local function selectSecretBoardMessage(store, age)
    if #secretBoardMessages == 0 then return nil end
    if age < 168 then
        return secretBoardMessages[ZombRand(#secretBoardMessages) + 1]
    end
    local startIndex = ZombRand(#secretBoardMessages) + 1
    for offset = 0, #secretBoardMessages - 1 do
        local index = ((startIndex + offset - 1) % #secretBoardMessages) + 1
        local entry = secretBoardMessages[index]
        if not store.spUsedBoardSecretMessages[entry.key] then
            return entry
        end
    end
    return nil
end

local function getBoardEntryText(entry)
    if entry.sceneKey then
        return localizedText(entry.sceneKey, entry.scene) .. " " .. localizedText(entry.detailKey, entry.detail)
    end
    return localizedText(entry.textKey, entry.body)
end

local function refreshBoardPostText(post)
    local secretEntry = secretEntryByKey[post.spSecretMessageKey]
    if secretEntry then
        post.body = localizedFormat(secretEntry.textKey, secretEntry.fallbackTemplate, secretEntry.site)
        return
    end
    local entry = boardEntryByKey[post.spMessageKey]
    if entry then
        post.body = getBoardEntryText(entry)
    end
end

local function getProfessionId(player)
    player = player or (getPlayer and getPlayer() or nil)
    if not player then return "unemployed" end
    if player.getProfession then
        local okProfession, profession = pcall(function() return player:getProfession() end)
        if okProfession and profession then return string.lower(tostring(profession)) end
    end
    if player.getDescriptor then
        local okDescriptor, descriptor = pcall(function() return player:getDescriptor() end)
        if okDescriptor and descriptor and descriptor.getProfession then
            local okProfession, profession = pcall(function() return descriptor:getProfession() end)
            if okProfession and profession then return string.lower(tostring(profession)) end
        end
    end
    return "unemployed"
end

local function getProfessionCategory(profession)
    local value = string.lower(tostring(profession or ""))
    if string.find(value, "police", 1, true) or string.find(value, "security", 1, true) then return "police" end
    if string.find(value, "doctor", 1, true) or string.find(value, "nurse", 1, true) or string.find(value, "medical", 1, true) then return "medical" end
    if string.find(value, "fire", 1, true) then return "fire" end
    if string.find(value, "ranger", 1, true) or string.find(value, "farmer", 1, true) or string.find(value, "fisher", 1, true) or string.find(value, "lumber", 1, true) then return "outdoors" end
    if string.find(value, "carpenter", 1, true) or string.find(value, "construction", 1, true) or string.find(value, "repair", 1, true) or string.find(value, "electric", 1, true) or string.find(value, "engineer", 1, true) or string.find(value, "metal", 1, true) or string.find(value, "mechanic", 1, true) then return "trades" end
    if string.find(value, "chef", 1, true) or string.find(value, "burger", 1, true) or string.find(value, "cook", 1, true) then return "food" end
    if string.find(value, "fitness", 1, true) then return "fitness" end
    if string.find(value, "veteran", 1, true) then return "veteran" end
    return "general"
end

local function getSecretSiteChance()
    if ComputerModSandbox and ComputerModSandbox.getPercent then
        return math.max(0, math.min(100, tonumber(ComputerModSandbox.getPercent("SecretSiteHintChance") or 0) or 0))
    end
    return 12
end

local function addBoardPost(store, age)
    local phase = "normal"
    if age >= 168 then
        phase = "aftermath"
    elseif age >= 72 then
        phase = "chaos"
    elseif age >= 24 then
        phase = "outbreak"
    end
    local canUseSecret = #secretBoardMessages > 0
    local useSecret = canUseSecret and ZombRand(100) < getSecretSiteChance()
    local name = nil
    local body = nil
    local selectedEntry = nil
    local selectedSecret = nil
    if useSecret then
        selectedSecret = selectSecretBoardMessage(store, age)
    end
    if not selectedSecret then
        selectedEntry = selectUnusedBoardEntry(boardPools[phase], store.spUsedBoardMessages, store.spLastBoardGroup)
        if not selectedEntry and canUseSecret then
            selectedSecret = selectSecretBoardMessage(store, age)
        end
    end
    if selectedSecret then
        name = age >= 168 and "archive_signal" or "dialup_dan"
        body = localizedFormat(selectedSecret.textKey, selectedSecret.fallbackTemplate, selectedSecret.site)
    else
        if not selectedEntry then return false end
        name = selectedEntry.name
        body = getBoardEntryText(selectedEntry)
    end
    local success, post = ComputerModPosts.addPost(name, body)
    if success and type(post) == "table" then
        post.spGenerated = true
        post.spPhase = phase
        if selectedEntry then
            post.spMessageKey = selectedEntry.key
            store.spUsedBoardMessages[selectedEntry.key] = true
            store.spLastBoardGroup = selectedEntry.group
        end
        if selectedSecret then
            post.spSecretMessageKey = selectedSecret.key
            store.spUsedBoardSecretMessages[selectedSecret.key] = true
        end
    end
    return success == true
end

local function getBoardDelay(age)
    if age < 24 then return randomHours(3, 5) end
    if age < 72 then return randomHours(2, 4) end
    if age < 168 then return randomHours(1, 3) end
    return randomHours(18, 36)
end

function ComputerModSPActivity.updateBoard(age)
    local store = ComputerModPosts.getStore()
    if type(store.spUsedBoardMessages) ~= "table" then
        store.spUsedBoardMessages = {}
    end
    if type(store.spUsedBoardSecretMessages) ~= "table" then
        store.spUsedBoardSecretMessages = {}
    end
    local needsMigration = (tonumber(store.spActivityVersion or 0) or 0) < 3
    local translationSignature = localizedText(boardPools.normal[1].textKey, boardPools.normal[1].body)
    local needsTranslationRefresh = store.spBoardTranslationSignature ~= translationSignature
    if needsMigration or needsTranslationRefresh then
        for i = 1, #(store.posts or {}) do
            local post = store.posts[i]
            if type(post) == "table" and post.spGenerated == true then
                if needsMigration then
                    local key = post.spMessageKey or boardMessageKeyByBody[tostring(post.body or "")]
                    if key then
                        post.spMessageKey = key
                        store.spUsedBoardMessages[key] = true
                    end
                    local secretKey = post.spSecretMessageKey or secretMessageKeyByBody[tostring(post.body or "")]
                    if secretKey then
                        post.spSecretMessageKey = secretKey
                        store.spUsedBoardSecretMessages[secretKey] = true
                    end
                end
                refreshBoardPostText(post)
            end
        end
        if needsMigration then store.spActivityVersion = 3 end
        store.spBoardTranslationSignature = translationSignature
    end
    if store.spNextPostAge == nil then
        store.spNextPostAge = age
    end
    local nextAge = tonumber(store.spNextPostAge or age) or age
    if age < nextAge then return false end
    if not addBoardPost(store, age) then
        store.spNextPostAge = age + getBoardDelay(age)
        return false
    end
    store.spNextPostAge = age + getBoardDelay(age)
    return true
end

function ComputerModSPActivity.registerMailAccount(account, player)
    if not isSinglePlayer() or type(account) ~= "table" then return end
    local age = getWorldAgeHours()
    account.spPlayerAccount = true
    account.spProfession = account.spProfession or getProfessionId(player)
    account.spCreatedAge = tonumber(account.spCreatedAge or age) or age
    account.spMailCount = tonumber(account.spMailCount or 0) or 0
    if age >= 48 then
        account.spMailComplete = true
        account.spNextMailAge = nil
    elseif account.spMailComplete ~= true and account.spNextMailAge == nil then
        account.spNextMailAge = age + randomHours(2, 5)
    end
end

function ComputerModSPActivity.registerMailForComputer(ui)
    if not isSinglePlayer() or not ui or not ui.getComputerData then return end
    local data = ui:getComputerData()
    if not data or data.ComputerModMailPlayerCreated ~= true then return end
    local address = ComputerModMail.normalizeAddress(data.ComputerModMailAddress or data.ComputerModMailSessionAddress or "")
    if address == "" then return end
    ComputerModSPActivity.registerMailAccount(ComputerModMail.getAccount(address), ui.playerObj)
end

local function generateMail(account, age)
    local category = getProfessionCategory(account.spProfession)
    local pool = ZombRand(100) < 48 and advertisementMails or (professionMails[category] or professionMails.general)
    local entry, index = selectDifferent(pool, account.spLastMailIndex)
    if not entry then return false end
    account.spLastMailIndex = index
    local subject = localizedText(entry.subjectKey, entry.subject)
    local body = localizedText(entry.bodyKey, entry.body)
    local success, message = ComputerModMail.sendMessage(entry.from, account.address, subject, body)
    if success and type(message) == "table" then
        message.spGenerated = true
        message.spSubjectKey = entry.subjectKey
        message.spBodyKey = entry.bodyKey
        message.spSubjectFallback = entry.subject
        message.spBodyFallback = entry.body
        account.spMailCount = (tonumber(account.spMailCount or 0) or 0) + 1
        account.spNextMailAge = age + randomHours(7, 13)
        return true
    end
    return false
end

local function refreshMailTranslations(store)
    local firstEntry = mailEntries[1]
    if not firstEntry then return end
    local signature = localizedText(firstEntry.subjectKey, firstEntry.subject)
    if store.spActivityTranslationSignature == signature then return end
    for _, account in pairs(store.accounts or {}) do
        if type(account) == "table" then
            for i = 1, #(account.messages or {}) do
                local message = account.messages[i]
                if type(message) == "table" and message.spGenerated == true then
                    local entry = mailEntryBySubjectKey[message.spSubjectKey]
                    if not entry then
                        entry = mailEntryBySource[tostring(message.subject or "") .. "\30" .. tostring(message.body or "")]
                    end
                    if entry then
                        message.spSubjectKey = entry.subjectKey
                        message.spBodyKey = entry.bodyKey
                        message.spSubjectFallback = entry.subject
                        message.spBodyFallback = entry.body
                        message.subject = localizedText(entry.subjectKey, entry.subject)
                        message.body = localizedText(entry.bodyKey, entry.body)
                    end
                end
            end
        end
    end
    store.spActivityTranslationSignature = signature
end

function ComputerModSPActivity.updateMail(age)
    local changed = false
    local store = ComputerModMail.getStore()
    refreshMailTranslations(store)
    for _, account in pairs(store.accounts or {}) do
        if type(account) == "table" and account.spPlayerAccount == true then
            if age >= 48 then
                account.spMailComplete = true
                account.spNextMailAge = nil
            elseif account.spMailComplete ~= true then
                if account.spNextMailAge == nil then account.spNextMailAge = age + randomHours(2, 5) end
                if age >= (tonumber(account.spNextMailAge or age + 1) or age + 1) then
                    changed = generateMail(account, age) or changed
                end
            end
        end
    end
    return changed
end

function ComputerModSPActivity.registerChatAccount(account)
    if not isSinglePlayer() or type(account) ~= "table" or account.spNPC == true then return end
    local age = getWorldAgeHours()
    account.spPlayerAccount = true
    account.spCreatedAge = tonumber(account.spCreatedAge or age) or age
    account.spRequestCount = tonumber(account.spRequestCount or 0) or 0
    account.spRequestLimit = tonumber(account.spRequestLimit or randomHours(2, 4)) or 3
    if age >= 96 then
        account.spRequestsComplete = true
        account.spNextRequestAge = nil
    elseif account.spRequestsComplete ~= true and account.spNextRequestAge == nil then
        account.spNextRequestAge = age + randomHours(3, 8)
    end
end

function ComputerModSPActivity.registerChatForUI(ui)
    if not isSinglePlayer() or not ui or not ui.getActiveChatUser then return end
    local username = ui:getActiveChatUser()
    if username == "" then return end
    ComputerModSPActivity.registerChatAccount(ComputerModChat.getAccount(username))
end

local function ensureNPC(candidate)
    local account = ComputerModChat.getAccount(candidate.username)
    if account and account.spNPC ~= true then return nil end
    if not account then
        local success, created = ComputerModChat.createAccount(candidate.username, "offline_" .. tostring(ZombRand(10000, 99999)), nil, true)
        if not success then return nil end
        account = created
    end
    account.spNPC = true
    account.displayName = candidate.displayName
    return account
end

local function addChatRequest(account)
    local start = ZombRand(#chatUsers) + 1
    for offset = 0, #chatUsers - 1 do
        local candidate = chatUsers[((start + offset - 1) % #chatUsers) + 1]
        local username = ComputerModChat.normalizeUsername(candidate.username)
        if username ~= ComputerModChat.normalizeUsername(account.username or "") and not ComputerModChat.hasContact(account, username) and not ComputerModChat.findRequestIndex(account, username) then
            local npc = ensureNPC(candidate)
            if npc then
                local success = ComputerModChat.sendRequest(npc.username, account.username)
                if success then
                    account.spRequestCount = (tonumber(account.spRequestCount or 0) or 0) + 1
                    return true
                end
            end
        end
    end
    return false
end

local function refreshChatTranslations(store)
    if not firstChatEntry then return end
    local signature = localizedText(firstChatEntry.key, firstChatEntry.body)
    if store.spActivityTranslationSignature == signature then return end
    for _, account in pairs(store.accounts or {}) do
        if type(account) == "table" then
            for _, conversation in pairs(account.conversations or {}) do
                if type(conversation) == "table" then
                    for i = 1, #conversation do
                        local message = conversation[i]
                        if type(message) == "table" then
                            local entry = chatEntryByKey[message.spBodyKey]
                            if not entry then
                                local sender = store.accounts[ComputerModChat.normalizeUsername(message.from or "")]
                                if type(sender) == "table" and sender.spNPC == true then
                                    entry = chatEntryByBody[tostring(message.body or "")]
                                end
                            end
                            if entry then
                                message.spGenerated = true
                                message.spBodyKey = entry.key
                                message.spBodyFallback = entry.body
                                message.body = localizedText(entry.key, entry.body)
                            end
                        end
                    end
                end
            end
        end
    end
    store.spActivityTranslationSignature = signature
end

function ComputerModSPActivity.updateChat(age)
    local changed = false
    local store = ComputerModChat.getStore()
    refreshChatTranslations(store)
    for _, account in pairs(store.accounts or {}) do
        if type(account) == "table" and account.spPlayerAccount == true and account.spNPC ~= true then
            if age >= 96 or (tonumber(account.spRequestCount or 0) or 0) >= (tonumber(account.spRequestLimit or 3) or 3) then
                account.spRequestsComplete = true
                account.spNextRequestAge = nil
            elseif account.spRequestsComplete ~= true then
                if account.spNextRequestAge == nil then account.spNextRequestAge = age + randomHours(3, 8) end
                if age >= (tonumber(account.spNextRequestAge or age + 1) or age + 1) then
                    if ZombRand(100) < 78 then
                        changed = addChatRequest(account) or changed
                    end
                    account.spNextRequestAge = age + randomHours(10, 20)
                end
            end
        end
    end
    return changed
end

function ComputerModSPActivity.onChatRequestAccepted(username, fromUser)
    if not isSinglePlayer() or not internetEnabled() then return false end
    local age = getWorldAgeHours()
    if age >= 96 then return false end
    local account = ComputerModChat.getAccount(username)
    local sender = ComputerModChat.getAccount(fromUser)
    if not account or not sender or sender.spNPC ~= true then return false end
    account.spNPCMessages = type(account.spNPCMessages) == "table" and account.spNPCMessages or {}
    local senderName = ComputerModChat.normalizeUsername(fromUser)
    if account.spNPCMessages[senderName] then return false end
    local phase = age < 24 and "day1" or age < 48 and "day2" or age < 72 and "day3" or "day4"
    local pool = chatMessagePools[phase]
    local index = ZombRand(#pool) + 1
    local bodyKey = "IGUI_ComputerMod_SP_Chat_" .. phase .. "_" .. tostring(index)
    local body = localizedText(bodyKey, pool[index])
    local success, message = ComputerModChat.sendMessage(senderName, username, body)
    if success then
        if type(message) == "table" then
            message.spGenerated = true
            message.spBodyKey = bodyKey
            message.spBodyFallback = pool[index]
        end
        account.spNPCMessages[senderName] = true
        return true
    end
    return false
end

function ComputerModSPActivity.update()
    if not isSinglePlayer() or not internetEnabled() then return false end
    local age = getWorldAgeHours()
    local changed = ComputerModSPActivity.updateBoard(age)
    changed = ComputerModSPActivity.updateMail(age) or changed
    changed = ComputerModSPActivity.updateChat(age) or changed
    return changed
end

function ComputerModSPActivity.onInitGlobalModData()
    if not isSinglePlayer() then return end
    ComputerModMail.getStore()
    ComputerModChat.getStore()
    ComputerModPosts.getStore()
    ComputerModSPActivity.update()
end

if Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(ComputerModSPActivity.onInitGlobalModData)
end

if Events and Events.EveryTenMinutes then
    Events.EveryTenMinutes.Add(ComputerModSPActivity.update)
end
