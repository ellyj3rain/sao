-- SAO_Voice - the inhabitants speak (Execution-layer expression only).
-- ---------------------------------------------------------------------------
-- Terse lines through the engine's own speech bubbles at moments the pillars
-- already decided. Voice never decides anything: it renders decisions
-- audible. A talkativeness trait and a per-agent cooldown keep the world
-- murmuring instead of narrating; repeated lines are swallowed.

SAO = SAO or {}
SAO.Voice = SAO.Voice or {}
local V = SAO.Voice

-- [B49] Ten seconds, in REAL time, and not in ticks.
--
-- A tick is one rendered FRAME. Measured from the operator's own
-- session log: the boot digest fires at `tickCounter % 240 == 0` and
-- appears at frame 240, so the two counters are the same counter - and
-- that machine ran at 64.5 frames a second, not 60.
--
-- So `600 ticks` was never ten seconds. It was 9.3s there, 20s on a
-- 30fps machine and 4.2s on a 144Hz one: the survivors got chattier
-- the better your hardware was. A cooldown that exists so a person
-- does not talk over themselves is about the player's ears, and ears
-- keep real time.
--
-- `getTimestampMs` is the engine's own wall clock and is already read
-- by the Ledger. If it ever fails, this falls open rather than shut -
-- a missing clock should not silence the county ([B33]).
local COOLDOWN_MS = 10000     -- ten seconds between lines per person
local lastSpokeMs = {}        -- [id] = wall-clock ms
local lastLine = {}           -- [id] = line

local function nowMs()
    local ok, ms = pcall(function() return getTimestampMs() end)
    return (ok and type(ms) == "number") and ms or nil
end

-- What a person says stepping into a state. Multiple options read less
-- mechanical; the pick is hashed off the tick so it stays deterministic
-- enough to not need randomness plumbing.
local LINES = {
    FLEE     = { "Run!", "No no no-", "Too many!", "Not like this!",
                 "Go go go!", "Not today. NOT today." },
    ALERT    = { "Something's out there.", "You hear that?", "Hold on.",
                 "Quiet. Quiet!", "Where. WHERE." },
    ENGAGE   = { "Come on then!", "Stay back!", "I've got this one." },
    HOMEWARD = { "Getting dark.", "Time to head back.", "Home. Now." },
    FORAGE   = { "I need to eat something.", "There has to be food somewhere." },
    WATERWARD= { "So thirsty.", "Water first." },
    GEARWARD = { "That'll do nicely.", "Better than this thing." },
    EAT      = { "Finally.", "Not much, but it's something.",
                 "Could be worse.", "Beans again." },
    DRINK    = { "Better.", "Needed that." },
    FOLLOW   = { "Right behind you.", "Wait up.", "Coming.",
                 "Lead on.", "Slow down, will you." },
    TREAT    = { "Hold on. Bleeding.", "Patch it up. Keep moving.", "Just a scratch. Just a scratch." },
    MEDICWARD = { "Coming - hold on.", "Don't move, I'm on my way." },
    PLAYERFOLLOW = { "Right behind you.", "Lead on." },
    RIP      = { "This'll have to do.", "Sorry, shirt." },
    RELOAD   = { "Loading!", "Come on, come on-" },
    AMMOWARD = { "Need rounds for this thing.", "There has to be a box somewhere." },
    TAKE     = { "Let's see what's in here.", "This'll help." },
    -- [A21] audit: SETTLEWARD is a STATE - it was misfiled in EVENTS
    -- where its lines were dead; the walk to a candidate base speaks now.
    SETTLEWARD = { "Checking a place out.", "Might be the one." },
}

-- Social moments outside the state machine.
local EVENTS = {
    warned    = { "They're close. Be careful.", "Dead nearby. Keep your eyes open." },
    briefing = { "Two streets past the church, watch the lot.",
                 "I know that ground. Listen before you go.",
                 "There were three of them by the fence last week." },
    turnedSeen = { "That's... that WAS them. God.",
                   "Don't look. You don't want that face in your head.",
                   "That's their coat. That's THEIR coat." },
    promiseKept = { "I promised.", "Look away. This is mine to do.",
                    "Rest now. It's done." },
    scratchDenial = { "It's just a scratch. Barely broke skin.",
                      "I've had worse from a fence nail.",
                      "Don't look at me like that. I'm FINE." },
    promiseMe = { "If I turn, you do it. Promise me.",
                  "We both know what this is. Sit with me a while.",
                  "Day or two, we'll know. Keep your distance till then." },
    nurse = { "Sit still. Let me look at it.",
              "We don't leave people over a wound.",
              "Clean it, bind it, and we wait together." },
    bittenWary = { "Keep that arm covered. And keep back.",
                   "I'm sorry. I can't be near you right now.",
                   "The house has to think about everyone." },
    stayPut = { "They'll walk back in on their own. Don't get"
                .. " yourself killed.",
                "It's not time yet. Sit down.",
                "You go out there worried, you come back bitten." },
    notAlone = { "Fine. But you're not going alone.",
                 "I'm coming. Shut up.",
                 "Two sets of eyes. Walk." },
    searchOut = { "Nobody's seen them in two days. I'm going to look.",
                  "They'd come looking for me.",
                  "Last seen by the crossing. That's where I start." },
    reunion = { "You're alive?! They told me you were dead.",
                "We mourned you. We actually mourned you.",
                "Don't do that again. Whatever you did." },
    winterLean = { "Counted the shelves. Winter will eat half of it.",
                   "Thin shelves and the cold coming. Bad math.",
                   "We need more put by before the snow." },
    deal = { "Deal. Good trading with you.",
             "That'll do. Take this.",
             "Fair's fair. Here." },
    noDeal = { "No use to me. Sorry.",
               "I've got nothing spare to trade for it.",
               "Not today." },
    waitForLight = { "Not in the dark. Not without a lamp.",
                     "It'll keep till morning.",
                     "You go out there blind, you don't come back." },
    scavenge = { "They don't need it. I do.",
                 "Sorry, friend. It's this or nothing.",
                 "Waste not." },
    leaveTheDead = { "Leave them be. They've had enough taken.",
                     "Not from the dead. Not yet." },
    notThem = { "No. Not them. I knew them.",
                "I'm not going through their pockets. Find another way.",
                "God. I knew them." },
    stepUp = { "Somebody has to. Might as well be me.",
               "I don't know how yet. I'll learn.",
               "We need one. I'll do it." },
    studies = { "There's a way to do this properly.",
                "Should've read this a month ago.",
                "Says here I've been doing it wrong." },
    passItOn = { "Here. I'm done with it.",
                 "Read that. It's better than sitting.",
                 "Give it back when you're through." },
    workDoubted = { "Fine. Someone else can do it.",
                    "I never said I was any good at it.",
                    "Don't look at me like that." },
    answered = { "They asked. We had it.",
                 "Somebody's got to be first.",
                 "They'd do it for us. Probably." },
    cooks = { "Don't eat that raw. Give it here.",
              "Ten minutes. It'll be worth it.",
              "This is the one thing I'm still good for." },
    unanswered = { "Nobody came.",
                   "I'll remember that.",
                   "Right. On my own, then." },
    cryForHelp = { "Help - somebody!",
                   "I'm hit! I need a hand!",
                   "Over here - please." },
    sitUp = { "Go on up. I've got it.",
              "I'll wake you if it's anything.",
              "Someone should have eyes." },
    report = { "You'll want to hear where they are.",
               "It's worse up there than we thought.",
               "Draw it while I remember it." },
    comeAlong = { "I'll come with you.",
                  "Not on your own, you're not.",
                  "Two sets of eyes." },
    noRoom = { "No room. I'll be here.",
               "Go on - I'll hold the place.",
               "Next one, then." },
    wheels = { "I'll take the car.",
               "Keys are in it. We can get further today.",
               "Beats walking." },
    learning = { "Show me that again?",
                 "Huh. I'd have done it the hard way.",
                 "You've done this before." },
    teaching = { "Here - hold it like this. You'll get it.",
                 "Watch me once, then you do it.",
                 "You're doing it the hard way. Try this." },
    walkOut = { "Too many people in that house. I'm done.",
                "I didn't sign on for a crowd.",
                "No hard feelings. I just can't stay." },
    goodWord = { "If you meet them, they're solid. I'd vouch.",
                 "They shared when they didn't have to. Remember that.",
                 "Not everyone out there is the worst of it." },
    sick = { "It's just a cold. It had better be just a cold.",
             "Whole county's coughing. Sleep it off.",
             "Take these before it turns into something." },
    cleanWound = { "This is going bad. Hold still.",
                   "Should have cleaned it the first day.",
                   "Burns. That means it's working." },
    abandon = { "There's nothing left here. We're going.",
                "Pack what walks. This place is finished.",
                "I liked it here. Doesn't matter now." },
    woodRun = { "Anything that burns. Grab it.",
                "The hearth's dark at ours. This'll do." },
    lightFire = { "There. Let it catch.",
                  "Fire's up. Get close.",
                  "Should have done this an hour ago." },
    feedFire = { "Keep it burning. Cold kills quieter than they do.",
                 "One more log. We'll want it tonight.",
                 "A fire nobody feeds is a fire nobody has." },
    dryStore = { "We're low on water. That's the one that kills you.",
                 "Bottles are empty. Somebody fill them.",
                 "Food we can find. Water we need TODAY." },
    waterRun = { "Filling everything I've got.",
                 "Water first. Always water first." },
    lean = { "Shelves are thin. Eat light.",
             "We're short. I counted.",
             "Somebody better bring something back." },
    ownCompany = { "I keep my own company. No offense.",
                   "Small circles stay alive.",
                   "You're alright. I still walk alone." },
    warpath = { "Their ground. Our answer.",
                "Somebody has to walk over there.",
                "The feud doesn't keep itself." },
    chairYes = { "The chair's yours. Stand tall.",
                 "The house looked at each other and nodded.",
                 "Don't make us regret the vote." },
    paid = { "Paid is paid.", "We're square.",
             "The house thanks you. Debt's done." },
    pactKept = { "Bread's on your shelf. As agreed.",
                 "Delivery from our house to yours.",
                 "The pact holds. Here's ours." },
    pact = { "Bread for watch. Shake on it.",
             "Your walls, our bread. Deal.",
             "The county just got smaller. Good." },
    grumble = { "This isn't how we should be feeding people.",
                "The policy's wrong and everyone knows it.",
                "I didn't agree to this arrangement." },
    colors = { "Not with your colors.", "Trade with your own camp.",
               "We don't deal with yours." },
    peace = { "It's done. Tell your people.",
              "Enough blood over words. We're square." },
    feud = { "This is bigger than you and me now.",
             "Your people and mine are done talking.",
             "Tell your camp to stay off our roads." },
    aid = { "Hold still - this needs binding.", "Take it. Bind that arm.",
            "You're bleeding. Here." },
    creedAligned = { "Your lot sees it right.", "We run things the same way.",
                     "Good outfit, yours." },
    creedOpposed = { "We don't run things your way.",
                     "Your people and mine won't mix.",
                     "Keep your rules on your side of the road." },
    grudgeTold= { "Watch yourself around them.", "They can't be trusted." },
    company   = { "Stick together?", "Better with two of us." },
    witnessed = { "What are you doing?!", "Hey! HEY!" },
    confront  = { "You! I remember you.", "This is for what you did." },
    trespass  = { "That's my place. Out.", "You don't live here. Leave.",
                  "I see you in there." },
    pardon    = { "...You didn't know. Now you do.", "First one's free. Remember it." },
    introduce = { "We hold the place up the road. Ask before you wander in.",
                  "You'll want to know who we are before you need to." },
    aloneAgain= { "Just me now.", "The house is quiet. I'll keep it anyway." },
    greet     = { "Hey. Still alive, then.", "Good to see a friendly face.",
                  "You again. Glad it's you.", "Careful out there, yeah?",
                  "Thought you were dead. Glad I was wrong." },
    movein    = { "Plenty of room at mine.", "We hold the place together now." },
    share     = { "Here. Eat.", "You need it more than I do.", "Take it. Don't argue." },
    thanks    = { "For me? Thank you.", "I won't forget this.", "You didn't have to. Thank you." },
    grief     = { "Oh no. No, no.", "I knew them. God.", "They deserved better than this.",
                  "Somebody should say something. ...Rest now." },
    barter    = { "Trade you.", "Fair's fair.", "Even swap?" },
    settle    = { "We're square now.", "Told you I'd make it right.", "Debt's paid." },
    lessonTold= { "Learned this one the hard way - listen.", "Somebody died teaching me this." },
    takePoint = { "I'll take point from here.", "Follow my lead.", "On me." },
    factionBorn = { "We're something now. We need a name.", "Three of us. That's a start." },
    settleScout = { "We should find somewhere to settle.", "We need walls of our own." },
    settled   = { "This is home now.", "We hold this place.",
                  "Rules go up tomorrow. Watches tonight.",
                  "Light footprint. We can leave it in an hour.",
                  "Anyone who needs a roof knows where we are.",
                  "Walls first. Everything else after." },
    talkBack  = { "Stay off the main roads.", "Watch the tree lines.",
                  "You look like you're managing." },
    joinYes   = { "Alright. You're one of ours now.", "We can use you. Welcome." },
    joinNo    = { "Not yet. We don't know you.", "Earn it first." },
    walkNudge = { "...Alright, I was thinking it anyway.", "You beat me to asking." },
    walkNo    = { "Not yet. Maybe when I know you better." },
    smokeShare= { "Here. Bad habit, good company.", "Last pack in Knox County, probably." },
    bonded    = { "You and me, then. To the end of it.", "Whatever comes, we split it." },
    traumaRage= { "No. NO. They don't get to keep breathing." },
    traumaBreak= { "...no. Please, no." },
    companion = { "Mind if I walk with you?", "I'll come along, if that's alright.",
                  "Two sets of eyes beat one." },
    parting   = { "I'll manage from here.", "Take care of yourself." },
}

local function pick(list, tick)
    return list[(tick % #list) + 1]
end

local function chatty(id)
    -- Talkativeness is a disposition trait like any other.
    local ok, value = pcall(function()
        return SAO.Disposition.talkativeness(id)
    end)
    return ok and value or 0.5
end

-- [B46] Whether a line is an ANSWER is a fact about who asked, and
-- the only thing that knows that is the call site.
--
-- The first attempt named the events - `talkBack`, `joinYes`, and so
-- on - and Border 53 killed it in one run: `company`, `ownCompany` and
-- `parting` are each raised BOTH from a menu handler and from the tick
-- loop. The same words are a reply when you asked and a murmur when
-- nobody did, so no set of names can be right.
--
-- So the surface says so instead. `V.answer` is the player's entry
-- point and `V.onEvent` is everyone else's; the difference is one
-- gate:
--
--     if not force and ZombRand(100) >= chatty(id) * 100 then return end
--
-- `D.talkativeness` runs 0.20 to 0.85, so under that roll a reserved
-- survivor ignored a direct question four times in five, in silence,
-- and from outside that is identical to a mod that does not work.
-- Temperament still decides whether anyone VOLUNTEERS anything and
-- which line comes out of the rotation. It does not decide whether
-- being spoken to registers, because the player performed a
-- deliberate act and a click that does nothing is [B33] again.
--
-- The cooldown still applies to both, so a second click inside ten
-- seconds of real time is still quiet - and that silence is legible,
-- because they
-- have just spoken.
local function speak(id, body, line, tick, force, answering)
    if not body or not line then return end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if sv and sv.Voice == false then return end
    if lastLine[id] == line and not force then return end
    local ms = nowMs()
    local last = ms and lastSpokeMs[id] or nil
    if not force and ms and last and (ms - last) < COOLDOWN_MS then
        return
    end
    -- The quiet ones keep more to themselves: talkativeness scales the
    -- chance a non-urgent line is voiced at all.
    if not force and not answering
        and ZombRand(100) >= math.floor(chatty(id) * 100) then
        return
    end
    local ok = pcall(function() body:Say(line) end)
    if ok then
        if ms then lastSpokeMs[id] = ms end
        lastLine[id] = line
    end
end

-- [B46] The tick is resolved HERE, not typed by the caller.
--
-- Nineteen call sites passed the literal `0`, and every one of them was
-- a reply to the player: talking back, agreeing to walk with you,
-- refusing, letting you into the group, turning you away, taking a
-- deal, refusing one, accepting the chair, being paid, parting.
--
-- `speak` then gated on `(tick - lastSpokeAt[id]) < COOLDOWN` - both
-- names since replaced by [B49]'s wall clock, kept here because this
-- paragraph is describing what went wrong rather than what is. With a
-- real last-spoke stamp and a zero `tick` that subtraction is hugely
-- negative,
-- so it is ALWAYS under the cooldown and ALWAYS returns silently. A
-- survivor who had never spoken since load answered once - and that
-- answer set `lastSpokeAt[id] = 0`, after which `0 - 0` is under the
-- cooldown too, forever.
--
-- So every spoken answer the player could get worked at most once per
-- person per session, and usually not at all. [B27] built
-- `SAO.Controller.tick()` for this exact reason and wired it to the
-- two belief-stamping sites; the voice replies kept the zero.
--
-- Fixed at the one place that can know rather than at nineteen places
-- that have to remember. A caller inside the tick loop still passes
-- its own; everyone else leaves it out.
local function nowTick(tick)
    if type(tick) == "number" then return tick end
    local ok, t = pcall(function() return SAO.Controller.tick() end)
    if ok and type(t) == "number" then return t end
    return 0
end

-- State transitions: urgent states force through cooldown; leisure murmurs.
function V.onTransition(id, state, tick)
    local list = LINES[state]
    if not list then return end
    local body = SAO.Body.get(id)
    if not body then return end
    local urgent = state == "FLEE" or state == "ENGAGE"
    tick = nowTick(tick)
    speak(id, body, pick(list, tick), tick, urgent)
end

-- Social events: always allowed to try (cooldown still applies unless urgent).
local function raise(id, event, tick, answering)
    local list = EVENTS[event]
    if not list then return end
    local body = SAO.Body.get(id)
    if not body then return end
    tick = nowTick(tick)
    speak(id, body, pick(list, tick), tick,
        event == "witnessed" or event == "confront", answering)
end

function V.onEvent(id, event, tick)
    raise(id, event, tick, false)
end

-- The player's entry point. Everything in SAO_Harness.lua is a menu
-- handler, so everything it raises is somebody answering a click.
function V.answer(id, event, tick)
    raise(id, event, tick, true)
end

function V.forget(id)
    lastSpokeMs[id] = nil
    lastLine[id] = nil
end

SAO.Log.line("VOICE", "voice module loaded")

return V
