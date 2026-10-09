# NPC art source adaptation

`SAO.LeisureArt` owns canvas painting, Hedge/Wood/Metal/Stone/Ice sculpture, and
fallible appraisal of unfinished paintings and sculptures. Offers require
person-private art/painting/sculpture recreation knowledge, privately observed
stations, Standing permission, actual carried source materials, the source's
skill requirements, and an available front square. Only the selected opportunity
becomes prepared work after `ProceduralPlanning.admitHobbyWork` accepts it.

The API is `offers` / `intentOffers`, `begin`, `work`, `advance`, `outcome`,
`interrupt`, `reset`, and the transient-authority query `skillRequest`. Work,
terminal outcomes, and skill request queries return detached bounded data.
Completed and interrupted outcomes enter `consumeHobbyOutcome` after canonical
storage. Runtime body/station pointers stay outside persistent records.

The production owner embeds five generated, tagged source profiles from installed
Lifestyle package 3403870858. Constructors, durations, source selection and
quality RNG, update/perform/complete, animations, materials, source mood calls,
physical overlays, sculpture discovery metadata, and appraisal margin/cooldown
remain source operations. Private lexical receivers capture source UI notes and
consume the same UI RNG draws, silence local-player UI sound, measure immediate
source mood/material calls, and route exact source-issued AddXP requests to
`SAO.LeisureSkill`. Player globals and the installed source files stay intact.

Two explicit source adaptations accompany the private class identity and UI
receivers: selected library templates are copied before adding per-art quality
and duration; sculpture appraisal uses the actual `sculpture` record where its
menu incorrectly checks `painting`. NPC appraisal initializes the original
source-owned `LSCooldowns` table because the player's initialization hook is
absent. Native work selection still requires all source prerequisites.

Pending AddXP requests preserve the actual source amount, perk, callback,
invocation count, delta, and work identity. `skillRequest` authenticates requests
only during the bound source update/perform callback. Stored pending rows cannot
authorize replay after retirement or reload. Each provider uses a monotonic
request sequence across works. The source receiver preserves native XP rates;
this owner adds no XP itself.

The source's interrupted remaining duration and unfinished artifact persist on
the physical station. Each callback revalidates the exact acquired station with
Perception's native runtime-instance resolver. Foreign station mutation blocks
progress. Cleanup removes only this action's own transient splash/sound handles.
Reload closes attempted work as interrupted and preserves the unfinished source
artifact. Completion requires a started native action, actual source update,
delta 1, source perform/complete, stage 4 and the exact result overlay; appraisal
requires its actual source completion and leaves the art intact.

Run `python tools/d2_leisure_art_test.py --output <new-private-output-directory>`.
The proof pins original source bytes, all selected source libraries, production
Lua, test code, installed base actions, jar and stdlib. It checks all five source
profile blocks and executes the original installed actions against the private
adapter with identical controlled receivers/RNG. It compares physical artifacts,
mood, material use, XP requests and random draws for canvas, all five sculpture
styles and appraisal. Ten restored defects must fail their named controls.

The proof uses installed Kahlua and its real table serialization. Body, station,
native action delta, queue, stats and item receivers are controlled. Native SP
XP authority has its separate owner proof. Loaded NPC timing, physical art
rendering, real inventory mutation and full planner/cognition integration are
additional joins. Runtime source byte sealing is unavailable and is carried
explicitly as `revisionAuthority`; action revisions and proof input hashes do
not claim a sealed loaded source package. Interval mood changes remain
unassigned; only immediate source calls enter `sourceDeltas`. This art family
does not establish broad D2 completion or calibrated pleasure/mastery.
